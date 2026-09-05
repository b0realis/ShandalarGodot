extends GameTest
## Wave-64 tests: LIVE rampage (CardInstance.cur_rampage +
## ContinuousEffects.add_until_eot_rampage) and the two Legends cards that
## needed it — Gabriel Angelfire, who chooses one of four abilities every
## upkeep, and Rapid Fire, which hands out first strike and rampage 2.


## Picks a fixed OPTION index and says yes to everything else.
class ModeAgent extends DecisionAgent:
	var want := 0

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], _hint: int) -> int:
		return clampi(want, 0, options.size() - 1)


func _modes(pid: int, want: int) -> ModeAgent:
	var agent := ModeAgent.new()
	agent.want = want
	g.set_agent(pid, agent)
	return agent


func test_registry_loaded_wave64() -> void:
	for name in ["Gabriel Angelfire", "Rapid Fire"]:
		assert_not_null(CardRegistry.get_card(name), name)


# --------------------------------------------------------- live rampage --

func test_printed_rampage_is_read_from_the_live_value() -> void:
	# Marhault Elsdragon has rampage 1 printed; combat must read cur_rampage.
	var rager := put_battlefield(0, "Marhault Elsdragon")
	assert_eq(rager.cur_rampage, 1)
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	var base := rager.cur_power
	run_combat([rager.id], {a.id: rager.id, b.id: rager.id})
	assert_eq(rager.cur_power, base + 1, "rampage 1 for the second blocker")


func test_a_granted_rampage_expires_with_the_turn() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_rampage(bear.id, 2)
	g.recalculate()
	assert_eq(bear.cur_rampage, 2)
	advance_to_next_turn()
	assert_eq(bear.cur_rampage, 0, "cleanup swept it")


func test_a_granted_rampage_dies_with_its_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_rampage(bear.id, 2)
	g.recalculate()
	g.destroy(bear)
	assert_eq(g.continuous._rampage_grants.size(), 0, "CR 400.7 — forgotten")


# ---------------------------------------------------- Gabriel Angelfire --

func test_gabriel_has_nothing_before_his_first_upkeep() -> void:
	var gabriel := put_battlefield(0, "Gabriel Angelfire")
	assert_false(gabriel.has_keyword(Mtg.Keyword.FLYING))
	assert_false(gabriel.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_false(gabriel.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_eq(gabriel.cur_rampage, 0)


func test_gabriel_takes_to_the_air_against_a_grounded_board() -> void:
	put_battlefield(1, "Grizzly Bears")
	var gabriel := put_battlefield(0, "Gabriel Angelfire")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(gabriel.has_keyword(Mtg.Keyword.FLYING), "nothing can block a flier")


func test_gabriel_takes_rampage_against_a_crowd() -> void:
	for i in 3:
		put_battlefield(1, "Wall of Air")     # 1/5 fliers: they CAN block him
	var gabriel := put_battlefield(0, "Gabriel Angelfire")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(gabriel.cur_rampage, 3, "three bodies means a gang block")
	assert_false(gabriel.has_keyword(Mtg.Keyword.FLYING))


func test_gabriel_gains_the_ability_his_controller_names() -> void:
	_modes(0, 1)                              # First strike
	var gabriel := put_battlefield(0, "Gabriel Angelfire")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(gabriel.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_false(gabriel.has_keyword(Mtg.Keyword.FLYING))


func test_gabriels_choice_lasts_until_his_next_upkeep_and_is_then_replaced() -> void:
	var agent := _modes(0, 2)                 # Trample
	var gabriel := put_battlefield(0, "Gabriel Angelfire")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(gabriel.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_next_turn()                    # their turn: still trample
	assert_true(gabriel.has_keyword(Mtg.Keyword.TRAMPLE))
	agent.want = 3                            # Rampage 3
	advance_to_next_turn()                    # ours again
	assert_false(gabriel.has_keyword(Mtg.Keyword.TRAMPLE), "replaced, not stacked")
	assert_eq(gabriel.cur_rampage, 3)


func test_gabriels_rampage_actually_bites() -> void:
	_modes(0, 3)                              # Rampage 3
	var gabriel := put_battlefield(0, "Gabriel Angelfire")
	advance_to_next_turn()
	advance_to_next_turn()
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	run_combat([gabriel.id], {a.id: gabriel.id, b.id: gabriel.id})
	assert_eq(gabriel.cur_power, 7, "4/4 plus rampage 3 for the second blocker")
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)


func test_gabriel_forgets_his_choice_when_he_leaves() -> void:
	_modes(0, 0)
	var gabriel := put_battlefield(0, "Gabriel Angelfire")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(gabriel.has_keyword(Mtg.Keyword.FLYING))
	g.destroy(gabriel)
	assert_false(gabriel.memory.has("gift"), "CR 400.7")


# ------------------------------------------------------------ Rapid Fire --

func test_rapid_fire_grants_first_strike_and_rampage_two() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var fire := give_hand(0, "Rapid Fire")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.W, 4)
	assert_ok(g.cast_spell(0, fire, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(bear.cur_rampage, 2)


func test_rapid_fire_leaves_an_existing_rampage_alone() -> void:
	var rager := put_battlefield(0, "Marhault Elsdragon")   # rampage 1
	var fire := give_hand(0, "Rapid Fire")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.W, 4)
	assert_ok(g.cast_spell(0, fire, [TargetRef.card(rager)]))
	resolve_stack()
	assert_true(rager.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(rager.cur_rampage, 1, "'if it doesn't have rampage' — it does")


func test_rapid_fire_cannot_be_cast_once_blockers_are_declared() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var fire := give_hand(0, "Rapid Fire")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	add_mana(0, Mtg.ManaColor.W, 4)
	assert_refused(g.cast_spell(0, fire, [TargetRef.card(bear)]),
		"before blockers are declared")


func test_rapid_fire_turns_a_gang_block_into_a_massacre() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var fire := give_hand(0, "Rapid Fire")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.W, 4)
	assert_ok(g.cast_spell(0, fire, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: bear.id, b.id: bear.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.cur_power, 4, "2/2 plus rampage 2 for the second blocker")
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD, "first strike killed one outright")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "and it lived: 4/4 against 2 power")
