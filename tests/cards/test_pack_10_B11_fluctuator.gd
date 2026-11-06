extends GameTest
## Pack 10 (the Urza block), batch B11: FLUCTUATOR — "Cycling abilities you
## activate cost {2} less to activate." (cards/sets/usg/_cycling.gd). Its
## engine shape (with_ability_cost_reduction reading the cycling marker) is
## pinned on a synthetic card by test_pack_10_engine_E2_cycling.gd; here the
## real card meets the real cycling cards.


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


static func _cycling_index(inst: CardInstance) -> int:
	for i in inst.cur_activated_abilities.size():
		if inst.cur_activated_abilities[i].is_cycling:
			return i
	return -1


func _due(pid: int, inst: CardInstance, index: int) -> int:
	var due := g.ability_payment(pid, inst, index)
	return int(due["cost"].mana_value()) + int(due["extra"])


func test_fluctuator_makes_your_cycling_free() -> void:
	put_battlefield(0, "Fluctuator")
	var clear := give_hand(0, "Clear")
	assert_eq(_due(0, clear, _cycling_index(clear)), 0)
	var hand_before := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, clear, _cycling_index(clear)))
	assert_eq(clear.zone, Mtg.Zone.GRAVEYARD, "cycled for nothing but the card")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand_before)


func test_two_fluctuators_never_go_below_zero() -> void:
	put_battlefield(0, "Fluctuator")
	put_battlefield(0, "Fluctuator")
	var land := give_hand(0, "Remote Isle")
	assert_eq(_due(0, land, _cycling_index(land)), 0)
	assert_ok(g.activate_ability(0, land, _cycling_index(land)))


func test_the_opponents_fluctuator_does_not_help_you() -> void:
	put_battlefield(1, "Fluctuator")
	var clear := give_hand(0, "Clear")
	assert_eq(_due(0, clear, _cycling_index(clear)), 2)
	assert_refused(g.activate_ability(0, clear, _cycling_index(clear)), "not enough mana")


func test_fluctuator_reduces_cycling_and_nothing_else() -> void:
	put_battlefield(0, "Fluctuator")
	var rune := put_battlefield(0, "Rune of Protection: Red")
	assert_eq(_due(0, rune, 0), 1, "the Rune's {W} shield is no cycling ability")
	var rod := put_battlefield(0, "Rod of Ruin")
	assert_eq(_due(0, rod, 0), 3)


func test_a_tapped_fluctuator_does_nothing_under_the_1997_rule() -> void:
	g.rules.set_edition("fifth")
	var fluctuator := put_battlefield(0, "Fluctuator")
	var clear := give_hand(0, "Clear")
	assert_eq(_due(0, clear, _cycling_index(clear)), 0, "untapped, it works")
	fluctuator.tapped = true
	g.recalculate()
	assert_eq(_due(0, clear, _cycling_index(clear)), 2)


func test_the_ai_plans_the_reduced_price() -> void:
	# The fair AI's affordability reads ability_payment under
	# forecasts_tactics, so a Fluctuator's free cycling needs no land.
	put_battlefield(0, "Fluctuator")
	var scrap := give_hand(0, "Scrap")
	var payment := g.ability_payment(0, scrap, _cycling_index(scrap))
	assert_eq(int(payment["extra"]), -2)
	assert_eq(payment["cost"].text, "{2}")
