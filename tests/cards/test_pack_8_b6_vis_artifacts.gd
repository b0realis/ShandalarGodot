extends GameTest
## Pack 8 (the Mirage block), batch B6: the Visions artifacts in
## cards/sets/vis/_artifacts.gd — Anvil of Bogardan, Diamond Kaleidoscope,
## Dragon Mask, Helm of Awakening, Juju Bubble, Magma Mine, Sands of Time,
## Snake Basket, Teferi's Puzzle Box, Triangle of War and Wand of Denial.

const CLAIMED := ["Anvil of Bogardan", "Diamond Kaleidoscope", "Dragon Mask",
	"Helm of Awakening", "Juju Bubble", "Magma Mine", "Sands of Time", "Snake Basket",
	"Teferi's Puzzle Box", "Triangle of War", "Wand of Denial"]

class Seat extends DecisionAgent:
	var yes := true
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes

func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

func _to_next_step_of(pid: int, step: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == step) and guard < 800:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid)
	assert_eq(g.current_step(), step)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ----------------------------------------------------------- Anvil of Bogardan --

func test_anvil_of_bogardan_draws_an_extra_card_then_discards_one() -> void:
	put_battlefield(0, "Anvil of Bogardan")
	_to_next_step_of(1, Mtg.Step.DRAW)
	var library := g.players[1].library.size()
	var graveyard := g.players[1].graveyard.size()
	resolve_stack()
	assert_eq(g.players[1].library.size(), library - 1, "each player's draw step: one more card")
	assert_eq(g.players[1].graveyard.size(), graveyard + 1, "then a discard")
	assert_eq(g.players[1].hand.size(), 1)

func test_anvil_of_bogardan_lifts_the_hand_limit() -> void:
	put_battlefield(1, "Anvil of Bogardan")
	advance_to_step(Mtg.Step.MAIN1)
	for n in 10: give_hand(0, "Forest")
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), 10, "no discard to hand size")


# -------------------------------------------------------- Diamond Kaleidoscope --

func test_diamond_kaleidoscope_makes_prisms_that_pay_any_color() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var scope := put_battlefield(0, "Diamond Kaleidoscope")
	assert_refused(g.tap_for_mana(0, scope, 0, Mtg.ManaColor.R), "")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, scope, 0))
	resolve_stack()
	var prisms: Array[CardInstance] = []
	for i in g.players[0].battlefield:
		if i.is_token: prisms.append(i)
	assert_eq(prisms.size(), 1)
	var prism := prisms[0]
	assert_true(prism.is_creature() and prism.is_type(Mtg.CardType.ARTIFACT))
	assert_eq([prism.cur_power, prism.cur_toughness], [0, 1])
	assert_eq(prism.cur_colors, 0, "colorless")
	assert_ok(g.tap_for_mana(0, scope, 0, Mtg.ManaColor.R))
	assert_false(g.players[0].battlefield.has(prism), "the Prism was the cost")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1)


# ----------------------------------------------------------------- Dragon Mask --

func test_dragon_mask_pumps_then_returns_the_creature_at_the_end_step() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mask := put_battlefield(0, "Dragon Mask")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, mask, 0, [TargetRef.card(theirs)]), "")
	assert_ok(g.activate_ability(0, mask, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	run_combat([bear.id])
	assert_eq(g.players[1].life, 16)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND, "returned at the beginning of the next end step")


# ------------------------------------------------------------ Helm of Awakening --

func test_helm_of_awakening_discounts_every_spell_by_one_generic() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Helm of Awakening")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, bear))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "{1}{G} for {G}, even under the opponent's Helm")
	var bolt := give_hand(0, "Lightning Bolt")
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]), "")


# ----------------------------------------------------------------- Juju Bubble --

func test_juju_bubble_pops_when_you_play_a_card() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bubble := put_battlefield(0, "Juju Bubble")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, bubble, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "{2}: You gain 1 life")
	var land := give_hand(0, "Forest")
	assert_ok(g.play_land(0, land))
	resolve_stack()
	assert_eq(bubble.zone, Mtg.Zone.GRAVEYARD, "playing a land is playing a card")

func test_juju_bubble_ignores_the_opponents_spells_but_not_yours() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bubble := put_battlefield(0, "Juju Bubble")
	assert_ok(g.pass_priority(0))
	var theirs := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, theirs, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(bubble.zone, Mtg.Zone.BATTLEFIELD)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bubble.zone, Mtg.Zone.GRAVEYARD)

func test_juju_bubble_has_cumulative_upkeep_one() -> void:
	var seat := _seat(0)
	seat.yes = false
	var bubble := put_battlefield(0, "Juju Bubble")
	_to_next_step_of(0, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(bubble.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------------ Magma Mine --

func test_magma_mine_blasts_for_its_pressure() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mine := put_battlefield(0, "Magma Mine")
	for n in 3:
		add_mana(0, Mtg.ManaColor.C, 4)
		assert_ok(g.activate_ability(0, mine, 0))
		resolve_stack()
	assert_eq(int(mine.counters.get("pressure", 0)), 3)
	assert_ok(g.activate_ability(0, mine, 1, [TargetRef.player(1)]))
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 17, "the counters it had when it was sacrificed")


# --------------------------------------------------------------- Sands of Time --

func test_sands_of_time_replaces_untapping_with_a_swap() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Sands of Time")
	var tapped_bear := put_battlefield(1, "Grizzly Bears")
	var ready_giant := put_battlefield(1, "Hill Giant")
	var forest := put_battlefield(1, "Forest")
	g.tap_permanent(tapped_bear)
	_to_next_step_of(1, Mtg.Step.UPKEEP)
	assert_true(tapped_bear.tapped, "no untap step")
	resolve_stack()
	assert_false(tapped_bear.tapped, "untapped by the swap")
	assert_true(ready_giant.tapped, "and the untapped ones tapped")
	assert_true(forest.tapped)


# ---------------------------------------------------------------- Snake Basket --

func test_snake_basket_makes_x_snakes_at_sorcery_speed() -> void:
	var basket := put_battlefield(0, "Snake Basket")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, basket, 0, [], 3), "sorcery")
	advance_to_step(Mtg.Step.MAIN2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, basket, 0, [], 3))
	resolve_stack()
	var snakes := 0
	for i in g.players[0].battlefield:
		if i.is_token and i.has_subtype("snake") and i.cur_power == 1 and (i.cur_colors & Mtg.ManaColor.G) != 0:
			snakes += 1
	assert_eq(snakes, 3)
	assert_eq(basket.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Teferi's Puzzle Box --

func test_teferis_puzzle_box_cycles_the_hand_through_the_library_bottom() -> void:
	put_battlefield(0, "Teferi's Puzzle Box")
	var bolt := give_hand(1, "Lightning Bolt")
	var giant := give_hand(1, "Hill Giant")
	_to_next_step_of(1, Mtg.Step.DRAW)
	assert_eq(g.players[1].hand.size(), 3, "the normal draw first")
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 3, "puts three on the bottom, draws three")
	assert_eq(bolt.zone, Mtg.Zone.LIBRARY)
	assert_eq(giant.zone, Mtg.Zone.LIBRARY)
	var bottom: Array = g.players[1].library.slice(0, 3)
	assert_true(bottom.has(bolt) and bottom.has(giant), "on the bottom")


# ------------------------------------------------------------- Triangle of War --

func test_triangle_of_war_makes_two_creatures_fight() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var triangle := put_battlefield(0, "Triangle of War")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, triangle, 0, [TargetRef.card(bear), TargetRef.card(giant)]), "")
	assert_ok(g.activate_ability(0, triangle, 0, [TargetRef.card(giant), TargetRef.card(bear)]))
	assert_eq(triangle.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 2, "each deals damage equal to its power to the other")

func test_triangle_of_war_no_fight_if_your_creature_is_gone() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var triangle := put_battlefield(0, "Triangle of War")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, triangle, 0, [TargetRef.card(bear), TargetRef.card(giant)]))
	g.destroy(bear)
	resolve_stack()
	assert_eq(giant.damage, 0, "no blow is struck (CR 701.12b)")


# -------------------------------------------------------------- Wand of Denial --

func test_wand_of_denial_mills_a_nonland_for_two_life() -> void:
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	var wand := put_battlefield(0, "Wand of Denial")
	var dragon := _on_library_top(1, "Shivan Dragon")
	assert_ok(g.activate_ability(0, wand, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 18, "paid 2 life")
	assert_eq(seat.asked.size(), 1)

func test_wand_of_denial_leaves_a_land_and_a_declined_card() -> void:
	var seat := _seat(0)
	seat.yes = false
	advance_to_step(Mtg.Step.MAIN1)
	var wand := put_battlefield(0, "Wand of Denial")
	var forest: CardInstance = g.players[1].library.back()
	assert_ok(g.activate_ability(0, wand, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.LIBRARY, "a land: nothing to pay for")
	assert_eq(seat.asked.size(), 0)
	advance_to_next_turn()
	advance_to_next_turn()
	var dragon := _on_library_top(1, "Shivan Dragon")
	assert_ok(g.activate_ability(0, wand, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.LIBRARY, "declined")
	assert_eq(g.players[0].life, 20)
