extends GameTest
## Pack 8 (the Mirage block), batch B8: the Mirage cost cards of
## cards/sets/mir/_costs.gd — additional costs refused before anything
## moves, the payer's held choice, undo of a paid cost, cumulative upkeep
## (age counters, no partial payment) and each card's own clause.

const CLAIMED := ["Prismatic Circle", "Carrion", "Phyrexian Tribute", "Withering Boon",
	"Cycle of Life", "Malignant Growth", "Phyrexian Purge"]


class Scripted extends DecisionAgent:
	var answers: Array = []   # bool
	var picks: Array = []     # CardInstance
	var colors: Array = []    # Mtg.ManaColor mask
	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint
	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		if not picks.is_empty():
			var want: Variant = picks.pop_front()
			if want == null: return null
			for c in candidates:
				if c == want: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_color(_g: MtgGame, _p: int, _prompt: String, hint: int) -> int:
		return int(colors.pop_front()) if not colors.is_empty() else hint


## Opens the 1997 damage-prevention window for its seat (with the fork on).
class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _own_upkeep() -> void:
	# From P0's main phase to P0's NEXT turn, stopping in its upkeep.
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)

func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


func test_claimed_cards_are_no_longer_pending() -> void:
	for name in CLAIMED:
		var c := CardRegistry.get_card(name)
		assert_not_null(c, name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", name)


# --- Prismatic Circle ---------------------------------------------------------

func test_circle_chooses_a_color_and_shields_only_that_color() -> void:
	var seat := Scripted.new()
	seat.colors = [Mtg.ManaColor.R]
	g.agents[0] = seat
	var circle := put_battlefield(0, "Prismatic Circle")
	assert_eq(int(circle.memory.get("circle_color", 0)), Mtg.ManaColor.R)
	# A red Bolt aimed at P0: the Circle names it and the damage is prevented.
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, circle, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the red source of P0's choice was shielded")

func test_circle_does_not_stop_a_source_of_another_color() -> void:
	var seat := Scripted.new()
	seat.colors = [Mtg.ManaColor.B]
	g.agents[0] = seat
	var circle := put_battlefield(0, "Prismatic Circle")
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, circle, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "black was chosen; the red Bolt still hits")

func test_circle_answers_a_red_packet_inside_the_1997_window() -> void:
	# Fifth-edition rules: the Circle names the waiting PACKET (its 1997
	# form) and the colour it checks is the one this Circle chose.
	g.rules.set_edition("fifth")
	g.set_agent(1, Duelist.new())
	var giant := put_battlefield(0, "Hill Giant")         # red
	var circle := put_battlefield(1, "Prismatic Circle")  # the hint: P0's colour
	assert_eq(int(circle.memory.get("circle_color", 0)), Mtg.ManaColor.R)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(1, circle, 0))
	resolve_stack()
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(g.players[1].life, 20, "the red Giant's damage never landed")

func test_circle_cumulative_upkeep_grows_and_cannot_be_paid_in_part() -> void:
	var circle := put_battlefield(0, "Prismatic Circle")
	var plains := put_battlefield(0, "Plains")
	_own_upkeep()
	resolve_stack()
	assert_eq(int(circle.counters.get("age", 0)), 1)
	assert_eq(circle.zone, Mtg.Zone.BATTLEFIELD, "{1} for one age counter, paid")
	assert_true(plains.tapped, "the Plains paid it")
	_own_upkeep()
	resolve_stack()
	# Two age counters = {2}; one Plains cannot pay half of it.
	assert_eq(circle.zone, Mtg.Zone.GRAVEYARD)
	assert_false(plains.tapped, "nothing was paid towards an unpayable upkeep")


# --- Carrion -------------------------------------------------------------------

func test_carrion_makes_insects_equal_to_the_sacrificed_power() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var carrion := give_hand(0, "Carrion")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, carrion, []))
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the spell was cast")
	resolve_stack()
	var insects := 0
	for i in g.players[0].battlefield:
		if i.data.card_name == "Insect":
			insects += 1
			assert_eq(i.cur_power, 0)
			assert_eq(i.cur_toughness, 1)
			assert_true(i.has_color(Mtg.ManaColor.B))
	assert_eq(insects, 3)

func test_carrion_refuses_without_a_creature_and_spends_nothing() -> void:
	var carrion := give_hand(0, "Carrion")
	put_battlefield(0, "Swamp")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, carrion, []))
	assert_eq(carrion.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 3)
	assert_true(g.stack.is_empty())

func test_carrion_human_chooses_the_creature_and_nothing_moves_while_asked() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var carrion := give_hand(0, "Carrion")
	add_mana(0, Mtg.ManaColor.B, 3)
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.cast_spell(0, carrion, []))
	assert_not_null(g.awaiting_choice)
	assert_true(g.awaiting_choice.is_cost)
	assert_eq(carrion.zone, Mtg.Zone.HAND)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.answer_choice(bear.id))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(carrion.zone, Mtg.Zone.STACK)

func test_carrion_cost_is_undone_by_the_journal() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var carrion := give_hand(0, "Carrion")
	add_mana(0, Mtg.ManaColor.B, 3)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, carrion, []))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.players[0].battlefield.has(bear))
	assert_eq(carrion.zone, Mtg.Zone.HAND)
	assert_true(g.stack.is_empty())
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 3)


# --- Phyrexian Tribute ---------------------------------------------------------

func test_tribute_needs_two_creatures_and_destroys_an_artifact() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var orb := put_battlefield(1, "Winter Orb")
	var tribute := give_hand(0, "Phyrexian Tribute")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, tribute, [TargetRef.card(orb)]))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "one creature cannot pay for two")
	var giant := put_battlefield(0, "Hill Giant")
	assert_ok(g.cast_spell(0, tribute, [TargetRef.card(orb)]))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(orb.zone, Mtg.Zone.GRAVEYARD)

func test_tribute_cannot_target_a_creature() -> void:
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	var tribute := give_hand(0, "Phyrexian Tribute")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, tribute, [TargetRef.card(wurm)]))


# --- Withering Boon ------------------------------------------------------------

func test_withering_boon_counters_only_creature_spells() -> void:
	advance_to_next_turn()   # P1's turn
	var bear := give_hand(1, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(1, bear, []))
	assert_ok(g.pass_priority(1))
	var boon := give_hand(0, "Withering Boon")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, boon, [TargetRef.card(bear)]))
	assert_eq(g.players[0].life, 17, "3 life is paid as the spell is cast")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	# A non-creature spell is not a legal target.
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	var second := give_hand(0, "Withering Boon")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, second, [TargetRef.card(bolt)]))
	assert_eq(g.players[0].life, 17)

func test_withering_boon_refused_below_three_life() -> void:
	advance_to_next_turn()
	var bear := give_hand(1, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(1, bear, []))
	assert_ok(g.pass_priority(1))
	g.players[0].life = 2
	var boon := give_hand(0, "Withering Boon")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, boon, [TargetRef.card(bear)]))
	assert_eq(g.players[0].life, 2)
	assert_eq(boon.zone, Mtg.Zone.HAND)


# --- Cycle of Life ---------------------------------------------------------------

func test_cycle_of_life_returns_itself_and_shrinks_a_creature_cast_this_turn() -> void:
	var cycle := put_battlefield(0, "Cycle of Life")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.activate_ability(0, cycle, 0, [TargetRef.card(bear)]))
	assert_eq(cycle.zone, Mtg.Zone.HAND, "returning it is the cost")
	resolve_stack()
	assert_eq(bear.cur_power, 0)
	assert_eq(bear.cur_toughness, 1)
	# Still 0/1 through the opponent's turn ...
	advance_to_next_turn()
	assert_eq(bear.cur_power, 0)
	# ... and at P0's next upkeep the base comes back and a +1/+1 counter lands.
	advance_to_next_turn()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1)
	assert_eq(bear.cur_power, 3)
	assert_eq(bear.cur_toughness, 3)

func test_cycle_of_life_refuses_a_creature_not_cast_this_turn() -> void:
	var cycle := put_battlefield(0, "Cycle of Life")
	var bear := put_battlefield(0, "Grizzly Bears")   # put, not cast
	assert_refused(g.activate_ability(0, cycle, 0, [TargetRef.card(bear)]))
	assert_eq(cycle.zone, Mtg.Zone.BATTLEFIELD, "a refused activation returns nothing")
	# Nor one an opponent cast.
	advance_to_next_turn()
	var their := give_hand(1, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(1, their, []))
	resolve_stack()
	assert_refused(g.activate_ability(0, cycle, 0, [TargetRef.card(their)]))


# --- Malignant Growth -----------------------------------------------------------

func test_malignant_growth_feeds_the_opponent_cards_and_burns_them() -> void:
	var growth := put_battlefield(0, "Malignant Growth")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	_own_upkeep()
	resolve_stack()
	assert_eq(int(growth.counters.get("growth", 0)), 1)
	assert_eq(int(growth.counters.get("age", 0)), 1)
	var hand := g.players[1].hand.size()
	advance_to_next_turn()   # P1's turn: draw step trigger
	# One normal draw plus one per growth counter, and 1 damage per extra card.
	assert_eq(g.players[1].hand.size(), hand + 2)
	assert_eq(g.players[1].life, 19)
	# P0's own draw step is not an opponent's.
	var mine := g.players[0].hand.size()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), mine + 1)


# --- Phyrexian Purge -------------------------------------------------------------

func test_purge_costs_three_life_per_target() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var purge := give_hand(0, "Phyrexian Purge")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, purge, [TargetRef.card(a), TargetRef.card(b)]))
	assert_eq(g.players[0].life, 14, "two targets cost 6 life")
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)

func test_purge_refused_when_life_cannot_cover_every_target_and_zero_targets_cost_none() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var purge := give_hand(0, "Phyrexian Purge")
	g.players[0].life = 5
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, purge, [TargetRef.card(a), TargetRef.card(b)]))
	assert_eq(g.players[0].life, 5)
	assert_eq(purge.zone, Mtg.Zone.HAND)
	assert_ok(g.cast_spell(0, purge, []))
	assert_eq(g.players[0].life, 5, "no target, no life")
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD)
