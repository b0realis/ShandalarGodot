extends GameTest
## Pack 9 (the Tempest block), batch B3: the ten Spikes of
## cards/sets/tmp/_spikes.gd, sth/_spikes.gd and exo/_spikes.gd.
##
## Each enters with its +1/+1 counters on a 0/0 body; every "Remove a
## +1/+1 counter from this creature" is a cost paid at activation; Spike
## Rogue's "from a creature you control" is Pack 9 E7's object cost. Both
## rules presets: +1/+1 and -1/-1 counters annihilate under the modern
## ones and coexist under 1997 rules, which changes what a Spike can pay.

const COUNTERS := {
	"Spike Drone": 1, "Spike Breeder": 3, "Spike Colony": 4, "Spike Feeder": 2,
	"Spike Soldier": 3, "Spike Worker": 2, "Spike Cannibal": 1, "Spike Hatcher": 6,
	"Spike Rogue": 2, "Spike Weaver": 3,
}
const MOVE := "{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature."

## Answers a card question with [member pick] when it is offered.
class Picker extends DecisionAgent:
	var pick: CardInstance
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if candidates.has(pick): return pick
		return null if candidates.is_empty() else candidates[0]

## Asks for the 1997 damage-prevention and regeneration windows.
class Windowed extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _fresh() -> void:
	super.before_each()
	advance_to_step(Mtg.Step.MAIN1)


func _is_pending(c: CardData) -> bool:
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"


func _plus(inst: CardInstance) -> int:
	return int(inst.counters.get("+1/+1", 0))


func _index(inst: CardInstance, text: String) -> int:
	for i in inst.cur_activated_abilities.size():
		if inst.cur_activated_abilities[i].text == text: return i
	return -1


func _use(inst: CardInstance, text: String, generic: int, targets: Array = []) -> String:
	var pid := inst.controller_id
	g.priority_player = pid
	if generic > 0: add_mana(pid, Mtg.ManaColor.C, generic)
	var index := _index(inst, text)
	assert_ne(index, -1, "%s has \"%s\"" % [inst.data.card_name, text])
	return g.activate_ability(pid, inst, index, targets)


# ----------------------------------------------------------------- claimed --

func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in COUNTERS:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(_is_pending(c), "%s is still pending" % card_name)
		assert_eq([c.power, c.toughness], [0, 0], "%s is printed 0/0" % card_name)
		assert_eq(int(c.enters_with_counters.get("+1/+1", 0)), COUNTERS[card_name], card_name)
		if card_name != "Spike Cannibal":
			assert_eq(c.activated_abilities[0].text, MOVE, "%s moves counters" % card_name)
			assert_eq(c.activated_abilities[0].counter_cost_kind, "+1/+1")
			assert_eq(c.activated_abilities[0].effects[0].ai_role, &"stat_counter")


func test_every_spike_cast_from_hand_enters_with_its_counters() -> void:
	for card_name in COUNTERS:
		if card_name == "Spike Cannibal":
			continue   # it takes every other Spike's counters as it enters: below
		var spike := give_hand(0, card_name)
		add_mana(0, Mtg.ManaColor.G, 3)
		add_mana(0, Mtg.ManaColor.C, 4)
		assert_ok(g.cast_spell(0, spike))
		resolve_stack()
		assert_eq(spike.zone, Mtg.Zone.BATTLEFIELD, card_name)
		var n: int = COUNTERS[card_name]
		assert_eq(_plus(spike), n, card_name)
		assert_eq([spike.cur_power, spike.cur_toughness], [n, n], card_name)
		g.players[0].mana_pool.clear()   # setup: the next cast starts from an empty pool


# -------------------------------------------------------------- the move --

func test_the_move_costs_two_and_a_counter_and_reaches_any_creature() -> void:
	var worker := put_battlefield(0, "Spike Worker")
	var theirs := put_battlefield(1, "Grizzly Bears")
	assert_refused(_use(worker, MOVE, 0, [TargetRef.card(theirs)]), "")
	assert_eq(_plus(worker), 2, "a refused activation removes nothing")
	assert_ok(_use(worker, MOVE, 2, [TargetRef.card(theirs)]))
	assert_eq(_plus(worker), 1, "the counter is a cost: gone at once")
	assert_eq(_plus(theirs), 0, "nothing until it resolves")
	resolve_stack()
	assert_eq(_plus(theirs), 1)
	assert_eq([theirs.cur_power, theirs.cur_toughness], [3, 3])
	assert_eq([worker.cur_power, worker.cur_toughness], [1, 1])


func test_a_spike_with_no_counter_left_cannot_pay() -> void:
	var drone := put_battlefield(0, "Spike Drone")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_pump(drone.id, 0, 2)   # keeps the drone alive at 0 counters
	g.recalculate()
	assert_ok(_use(drone, MOVE, 2, [TargetRef.card(bear)]))
	assert_refused(_use(drone, MOVE, 2, [TargetRef.card(bear)]), "")
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(_plus(bear), 1)


func test_a_spike_paying_its_last_counter_dies_and_the_move_still_resolves() -> void:
	var drone := put_battlefield(0, "Spike Drone")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(_use(drone, MOVE, 2, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(drone.zone, Mtg.Zone.GRAVEYARD, "a 0/0 (CR 704.5f)")
	assert_eq(_plus(bear), 1, "the ability resolved without its source")


func test_a_spike_may_move_a_counter_onto_itself() -> void:
	var colony := put_battlefield(0, "Spike Colony")
	assert_ok(_use(colony, MOVE, 2, [TargetRef.card(colony)]))
	resolve_stack()
	assert_eq(_plus(colony), 4, "removed as the cost, put back on resolution")


func test_what_a_spike_can_pay_under_both_presets() -> void:
	# A -1/-1 counter on a two-counter Spike Worker: under the modern rules
	# the two kinds annihilate (CR 704.5q) and one +1/+1 counter is left to
	# pay with; under 1997 rules both +1/+1 counters stay and can be spent.
	for preset in ["modern", "fifth"]:
		_fresh()
		g.rules.set_preset(preset)
		var worker := put_battlefield(0, "Spike Worker")
		var bear := put_battlefield(0, "Grizzly Bears")
		g.add_counters(worker, "-1/-1", 1)
		g.check_state_based_actions()
		assert_eq([worker.cur_power, worker.cur_toughness], [1, 1], preset)
		var expected := 1 if preset == "modern" else 2
		assert_eq(_plus(worker), expected, preset)
		g.continuous.add_until_eot_pump(worker.id, 0, 3)
		g.recalculate()
		for i in expected:
			assert_ok(_use(worker, MOVE, 2, [TargetRef.card(bear)]))
		assert_refused(_use(worker, MOVE, 2, [TargetRef.card(bear)]), "")
		resolve_stack()
		assert_eq(_plus(bear), expected, preset)


# ---------------------------------------------------- each Spike's extra --

func test_spike_breeder_makes_green_spike_tokens() -> void:
	var breeder := put_battlefield(0, "Spike Breeder")
	var text := "{2}, Remove a +1/+1 counter from this creature: Create a 1/1 green Spike creature token."
	assert_refused(_use(breeder, text, 0), "")
	assert_ok(_use(breeder, text, 2))
	resolve_stack()
	assert_eq(_plus(breeder), 2)
	var tokens: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		if inst.is_token: tokens.append(inst)
	assert_eq(tokens.size(), 1)
	assert_true(tokens[0].has_subtype("spike"))
	assert_eq(tokens[0].cur_colors, Mtg.ManaColor.G)
	assert_eq([tokens[0].cur_power, tokens[0].cur_toughness], [1, 1])
	assert_ok(_use(breeder, MOVE, 2, [TargetRef.card(tokens[0])]))
	resolve_stack()
	assert_eq(tokens[0].cur_power, 2, "a token takes a moved counter like any creature")


func test_spike_feeder_trades_counters_for_life_without_mana() -> void:
	var feeder := put_battlefield(0, "Spike Feeder")
	var text := "Remove a +1/+1 counter from this creature: You gain 2 life."
	assert_ok(_use(feeder, text, 0))
	assert_ok(_use(feeder, text, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 24)
	assert_eq(feeder.zone, Mtg.Zone.GRAVEYARD, "both counters spent: a 0/0")


func test_spike_soldier_pumps_itself_until_end_of_turn() -> void:
	var soldier := put_battlefield(0, "Spike Soldier")
	var text := "Remove a +1/+1 counter from this creature: This creature gets +2/+2 until end of turn."
	assert_ok(_use(soldier, text, 0))
	resolve_stack()
	assert_eq([soldier.cur_power, soldier.cur_toughness], [4, 4], "two counters and +2/+2")
	advance_to_next_turn()
	assert_eq([soldier.cur_power, soldier.cur_toughness], [2, 2])


func test_spike_hatcher_regenerates_itself_with_a_counter() -> void:
	var hatcher := put_battlefield(0, "Spike Hatcher")
	var text := "{1}, Remove a +1/+1 counter from this creature: Regenerate this creature."
	assert_refused(_use(hatcher, text, 0), "")
	assert_ok(_use(hatcher, text, 1))
	resolve_stack()
	assert_eq(_plus(hatcher), 5)
	assert_eq(hatcher.regeneration_shields, 1)
	g.destroy(hatcher)
	g.check_state_based_actions()
	assert_eq(hatcher.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(hatcher.tapped)


func test_spike_hatcher_regenerates_in_the_1997_window() -> void:
	g.rules.set_preset("fifth")
	g.set_agent(0, Windowed.new())
	g.set_agent(1, Windowed.new())
	var hatcher := put_battlefield(0, "Spike Hatcher")
	var wurm := put_battlefield(1, "Craw Wurm")
	g.add_counters(wurm, "+1/+1", 3)   # a 9/7: lethal to the 6/6 Hatcher
	var text := "{1}, Remove a +1/+1 counter from this creature: Regenerate this creature."
	assert_true(hatcher.cur_activated_abilities[_index(hatcher, text)].effects[0].is_regeneration)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hatcher.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wurm.id: hatcher.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	var guard := 0
	while g.awaiting_damage_prevention and guard < 10:
		assert_ok(g.end_damage_prevention(g.priority_player))
		guard += 1
	assert_true(g.awaiting_regeneration, "the window opens for a regenerator")
	assert_ok(_use(hatcher, text, 1))
	resolve_stack()
	guard = 0
	while (g.awaiting_regeneration or g.awaiting_damage_prevention) and guard < 10:
		assert_ok(g.end_damage_prevention(g.priority_player))
		guard += 1
	assert_eq(hatcher.zone, Mtg.Zone.BATTLEFIELD, "regenerated")


func test_spike_weaver_fogs_the_combat() -> void:
	advance_to_next_turn()   # theirs
	var giant := put_battlefield(1, "Hill Giant")
	var weaver := put_battlefield(0, "Spike Weaver")
	var text := "{1}, Remove a +1/+1 counter from this creature: Prevent all combat damage that would be dealt this turn."
	assert_true(weaver.cur_activated_abilities[_index(weaver, text)].effects[0].is_damage_prevention)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {}))
	assert_ok(_use(weaver, text, 1))
	resolve_stack()
	assert_eq(_plus(weaver), 2)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "no combat damage this turn")


# ---------------------------------------------------------- Spike Cannibal --

func test_spike_cannibal_takes_every_plus_counter_on_the_battlefield() -> void:
	var worker := put_battlefield(0, "Spike Worker")
	var colony := put_battlefield(1, "Spike Colony")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.add_counters(bear, "+1/+1", 1)
	var shrunk := put_battlefield(1, "Grizzly Bears")
	g.add_counters(shrunk, "-1/-1", 1)
	var cannibal := give_hand(0, "Spike Cannibal")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, cannibal))
	resolve_stack()
	assert_eq(_plus(cannibal), 1 + 2 + 4 + 1, "its own, the Worker's, their Colony's and the bear's")
	assert_eq([cannibal.cur_power, cannibal.cur_toughness], [8, 8])
	assert_eq(worker.zone, Mtg.Zone.GRAVEYARD, "a 0/0 Spike dies")
	assert_eq(colony.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_plus(bear), 0)
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2])
	assert_eq(int(shrunk.counters.get("-1/-1", 0)), 1, "only +1/+1 counters move")


func test_spike_cannibal_gone_before_its_trigger_resolves_moves_nothing() -> void:
	var worker := put_battlefield(1, "Spike Worker")
	var cannibal := give_hand(0, "Spike Cannibal")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, cannibal))
	var guard := 0
	while cannibal.zone != Mtg.Zone.BATTLEFIELD and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.stack.size(), 1, "its enters trigger waits on the stack")
	g.return_to_hand(cannibal)
	resolve_stack()
	assert_eq(_plus(worker), 2, "CR 122.5: nowhere to move them, nothing moves")
	assert_eq(worker.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------- Spike Rogue --

const ROGUE := "{2}, Remove a +1/+1 counter from a creature you control: Put a +1/+1 counter on this creature."

func test_spike_rogue_takes_a_counter_from_a_creature_you_choose() -> void:
	var rogue := put_battlefield(0, "Spike Rogue")
	var worker := put_battlefield(0, "Spike Worker")
	var seat := Picker.new()
	seat.pick = worker
	g.set_agent(0, seat)
	assert_ok(_use(rogue, ROGUE, 2))
	assert_eq(_plus(worker), 1, "the chosen creature paid at activation")
	resolve_stack()
	assert_eq(_plus(rogue), 3)
	assert_eq([rogue.cur_power, rogue.cur_toughness], [3, 3])


func test_spike_rogue_cannot_take_an_opponents_counter() -> void:
	var rogue := put_battlefield(0, "Spike Rogue")
	g.continuous.add_until_eot_pump(rogue.id, 0, 3)
	g.recalculate()
	g.remove_counters(rogue, "+1/+1", 2)
	var theirs := put_battlefield(1, "Spike Colony")
	assert_refused(_use(rogue, ROGUE, 2), "")
	assert_eq(_plus(theirs), 4)
	assert_eq(g.players[0].mana_pool.total(), 2, "refused before the mana")
	assert_true(g.stack.is_empty())


func test_spike_rogue_may_pay_with_its_own_counter() -> void:
	var rogue := put_battlefield(0, "Spike Rogue")
	assert_ok(_use(rogue, ROGUE, 2))
	assert_eq(_plus(rogue), 1)
	resolve_stack()
	assert_eq(_plus(rogue), 2, "back where it was, two mana poorer")
	assert_ok(_use(rogue, MOVE, 2, [TargetRef.card(rogue)]))
	resolve_stack()
	assert_eq(_plus(rogue), 2, "its first ability is the ordinary move")
