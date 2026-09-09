extends GameTest
## OSAI VULTURES WEARING HOLY STRENGTH (2026-09-08). The owner, from a
## playtest: *"Osai Vultures with Holy Strength really deal 3 damage
## instead of two?"* — a 1/1 flier in a +1/+2 aura is a 2/3 and should hit
## for 2; the table showed 3.
##
## Two honest ways to a 3 exist, and both are printed on the Vultures:
## *"Remove two carrion counters from this creature: This creature gets
## +1/+1 until end of turn"*, fed by *"At the beginning of each end step,
## if a creature died this turn, put a carrion counter on this creature"*
## — one counter per turn, so the pump is a two-death, two-turn affair.
## Every other road to a 3 is a bug: the aura's static counted twice
## (CR 613.2 — a static's effect is re-derived from scratch on every
## pass, never accumulated), a pump surviving the cleanup step it was
## meant to end at (CR 514.2), a counter cost paid once and the pump
## resolving twice, or a probe/rewind leaving a second copy of the bonus
## behind (CR 400.7 / docs/duel-todo.md §1.3). This file walks each of
## those roads with the number the owner wrote down and pins the 2 at the
## end of each, and the 3 only where the counters were spent.
##
## Every case reads the DEFENDER'S LIFE (or the damage marked on the
## blocker), not `cur_power`: the damage a creature deals is what the
## player saw, and a power that displays right while the packet carries
## something else is exactly the shape of bug a `cur_power` assertion
## cannot catch (`tests/cards/test_auras_2026_09_06.gd` learnt that the
## hard way).
##
## FOR THE RECORD, the table the report most likely came from: the 1997
## enemy that runs Osai Vultures beside Holy Strength is Lord of Fate
## (`decks/1997/originals/lord_of_fate.deck`), whose deck also holds
## Unholy Strength (+2/+1 — a 3/2 Vultures), a second Holy Strength for
## the same host (a 3/5), and Pestilence, whose {B} deals its point to
## each player in the same turn the Vultures connect for 2. None of the
## three is a 3 the Vultures dealt, and the AI cannot spend carrion
## counters at all ([method AiPlayer._ability_available] leaves counter
## costs alone).


## The board the owner described: seat [param pid]'s Osai Vultures wearing
## a Holy Strength, checked to be the 2/3 it should be.
func _dressed_vultures(pid := 0) -> CardInstance:
	var vultures := put_battlefield(pid, "Osai Vultures")
	g.attach_aura_from_anywhere(give_hand(pid, "Holy Strength"), vultures, pid)
	assert_eq(vultures.cur_power, 2, "1/1 + Holy Strength's +1/+2")
	assert_eq(vultures.cur_toughness, 3)
	return vultures


func _assert_two_three(vultures: CardInstance, why: String) -> void:
	assert_eq(vultures.cur_power, 2, why)
	assert_eq(vultures.cur_toughness, 3, why)


## Seat 0's Vultures swing alone into an empty board; returns what seat 1
## lost — the number the owner read off the table.
func _swing(vultures: CardInstance) -> int:
	var before: int = g.players[1].life
	run_combat([vultures.id])
	return before - g.players[1].life


func _human_seat(pid: int) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


# ======================================================= the plain board --

func test_the_dressed_vultures_hit_for_two() -> void:
	var vultures := _dressed_vultures()
	assert_eq(_swing(vultures), 2, "a 2/3 deals 2, not 3")
	_assert_two_three(vultures, "and is still a 2/3 after combat")


func test_one_carrion_counter_is_not_a_pump() -> void:
	# The feed is one counter per END STEP with a death in it: after one
	# creature dies the Vultures wear ONE counter, the pump wants two, and
	# the swing next turn is still a 2.
	var vultures := _dressed_vultures()
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(bear, false)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(vultures.counters.get("carrion", 0), 1, "one death, one counter")
	advance_to_next_turn()   # seat 1's turn
	advance_to_next_turn()   # seat 0's again
	assert_eq(vultures.counters.get("carrion", 0), 1,
		"a turn with no death feeds nothing (the intervening 'if', CR 603.4)")
	assert_refused(g.activate_ability(0, vultures, 0, []), "carrion counters")
	assert_eq(vultures.counters.get("carrion", 0), 1,
		"a refused activation costs nothing (CR 601.2h)")
	assert_eq(_swing(vultures), 2)
	_assert_two_three(vultures, "one counter is a 2/3 with a counter on it")


func test_two_carrion_counters_spent_is_the_three() -> void:
	# The one honest road to the owner's 3: two deaths on two turns, the
	# pump activated, both counters gone and +1/+1 until end of turn.
	var vultures := _dressed_vultures()
	var first := put_battlefield(1, "Grizzly Bears")
	var second := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(first, false)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	advance_to_next_turn()   # seat 1's turn
	g.destroy(second, false)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	advance_to_next_turn()   # seat 0's again
	assert_eq(vultures.counters.get("carrion", 0), 2, "two deaths, two turns")
	_assert_two_three(vultures, "the counters are not a pump by themselves")
	assert_ok(g.activate_ability(0, vultures, 0, []))
	assert_eq(vultures.counters.get("carrion", 0), 0,
		"both counters came off as the COST, before the pump resolved")
	_assert_two_three(vultures, "nothing changes until the pump resolves")
	resolve_stack()
	assert_eq(vultures.cur_power, 3, "2/3 + 1/+1")
	assert_eq(vultures.cur_toughness, 4)
	assert_eq(_swing(vultures), 3, "the 3 the owner saw takes two counters")
	# The counters are spent: the pump cannot be paid for twice.
	assert_refused(g.activate_ability(0, vultures, 0, []), "carrion counters")


func test_the_pump_ends_with_the_turn() -> void:
	# Holy Strength attached, then the pump: a 3/4 for THIS turn only.
	# The cleanup step drops it (CR 514.2) and the aura's +1/+2 is all
	# that is left on the next turn — not a 3/4 remembered, not a 4/6.
	var vultures := _dressed_vultures()
	g.add_counters(vultures, "carrion", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, vultures, 0, []))
	resolve_stack()
	assert_eq(vultures.cur_power, 3)
	assert_eq(vultures.cur_toughness, 4)
	advance_to_next_turn()
	_assert_two_three(vultures, "the pump ended at cleanup; the aura stayed")
	advance_to_next_turn()
	_assert_two_three(vultures, "and it is still just the aura a turn later")
	assert_eq(_swing(vultures), 2, "back to hitting for 2")


func test_the_aura_does_not_grow_across_turns() -> void:
	# The bug shape the report points at hardest: a static re-applied on
	# every pass. Two full turn cycles — untap, upkeep, draw, combat, end,
	# cleanup, twice for each seat — and the bonus is +1/+2 exactly, not
	# +1/+2 per pass.
	var vultures := _dressed_vultures()
	for _i in 4:
		advance_to_next_turn()
		_assert_two_three(vultures, "turn %d: still 2/3" % g.turn_number)
	assert_eq(_swing(vultures), 2)


func test_the_aura_cast_through_the_real_path_is_the_same_two() -> void:
	# `attach_aura_from_anywhere` is the setup shortcut; the owner CAST the
	# aura. Casting targets the Vultures and the spell enters attached to
	# it (CR 303.4a), and that road must land on the same 2/3.
	var vultures := put_battlefield(0, "Osai Vultures")
	var strength := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(vultures)]))
	resolve_stack()
	assert_eq(strength.attached_to, vultures.id)
	_assert_two_three(vultures, "cast, resolved, attached: a 2/3")
	assert_eq(_swing(vultures), 2)


# ======================================= every road that re-reads the aura --

func test_a_death_beside_it_does_not_reapply_the_aura() -> void:
	# A zone change on the table (a bear dies) recalculates every
	# permanent; the Vultures' bonus is re-derived, not added again. The
	# end step's feed then puts the counter on a 2/3, not a 3/5.
	var vultures := _dressed_vultures()
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(bear, false)
	_assert_two_three(vultures, "the recalculation after a death")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(vultures.counters.get("carrion", 0), 1)
	_assert_two_three(vultures, "a carrion counter has no +N/+N in its name")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(_swing(vultures), 2)


func test_a_snapshot_rewind_leaves_the_bonus_at_plus_one_plus_two() -> void:
	# The pre-flight probe (docs/duel-todo.md §1.3) runs a resolution and
	# rewinds it through [GameSnapshot]. Taking the pump through that
	# rewind — resolve, restore, resolve for real — must leave ONE pump on
	# the Vultures and the aura's bonus at exactly +1/+2.
	var vultures := _dressed_vultures()
	g.add_counters(vultures, "carrion", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, vultures, 0, []))
	var snapshot := GameSnapshot.take(g)
	resolve_stack()
	assert_eq(vultures.cur_power, 3, "the probe saw the pump land")
	snapshot.restore()
	g.recalculate()
	assert_eq(g.stack.size(), 1, "the pump is back on the stack")
	_assert_two_three(vultures, "the rewound pump is gone from the Vultures")
	resolve_stack()
	assert_eq(vultures.cur_power, 3, "resolved once for real: 3/4")
	assert_eq(vultures.cur_toughness, 4)
	assert_eq(vultures.counters.get("carrion", 0), 0, "paid ONCE")
	assert_eq(_swing(vultures), 3)
	advance_to_next_turn()
	_assert_two_three(vultures, "and only the aura remains next turn")


func test_the_search_journal_unmakes_the_pump_and_keeps_the_aura() -> void:
	# The AI's combat search plays moves through the make/unmake journal
	# ([UndoLog]): a pump activated and resolved inside a search node is
	# unmade with the node, counters and all, and the aura is re-derived
	# by the recalculation that follows — still +1/+2, never doubled.
	var vultures := _dressed_vultures()
	g.add_counters(vultures, "carrion", 2)
	advance_to_step(Mtg.Step.MAIN1)
	var mark := g.make_mark()
	assert_ok(g.activate_ability(0, vultures, 0, []))
	resolve_stack()
	assert_eq(vultures.cur_power, 3, "inside the node: 3/4")
	assert_eq(vultures.counters.get("carrion", 0), 0)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(vultures.counters.get("carrion", 0), 2, "the counters are back")
	_assert_two_three(vultures, "the pump is unmade; the aura is one +1/+2")
	assert_eq(_swing(vultures), 2, "nothing was really spent")


func test_the_pre_flight_probe_lands_the_pump_and_the_feed_once() -> void:
	# The human seat's game: every resolution is PROBED first (the engine
	# runs it, notes what it asked, rewinds — docs/duel-todo.md §1.3) and
	# then run for real. The feed's trigger and the pump both go through
	# that door here: one counter per fed end step, one +1/+1 per pump.
	_human_seat(0)
	var vultures := _dressed_vultures()
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(bear, false)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(vultures.counters.get("carrion", 0), 1, "probed, then fed ONCE")
	advance_to_next_turn()
	advance_to_next_turn()
	g.add_counters(vultures, "carrion", 1)
	assert_ok(g.activate_ability(0, vultures, 0, []))
	resolve_stack()
	assert_eq(vultures.cur_power, 3, "probed, then pumped ONCE: 3/4, not 4/5")
	assert_eq(vultures.cur_toughness, 4)
	assert_eq(vultures.counters.get("carrion", 0), 0)
	assert_eq(_swing_through_window(vultures), 3)
	advance_to_next_turn()
	_assert_two_three(vultures, "and the aura alone the turn after")


func test_a_blocked_dressed_vultures_marks_two_on_the_blocker() -> void:
	# The other number a player reads: the damage marked on a blocker.
	# A 2/3 flier into a 1/5 flying Wall of Air marks 2 on the wall and
	# takes 1, and stays a 2/3 with that one point marked.
	var vultures := _dressed_vultures()
	var wall := put_battlefield(1, "Wall of Air")
	var before: int = g.players[1].life
	run_combat([vultures.id], {wall.id: vultures.id})
	assert_eq(wall.damage, 2, "a 2/3 marks 2 on its blocker")
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(vultures.damage, 1, "and takes the wall's 1")
	assert_eq(vultures.zone, Mtg.Zone.BATTLEFIELD, "1 < 3")
	assert_eq(g.players[1].life, before, "blocked: nothing at the player")
	_assert_two_three(vultures, "the block changed nothing on the Vultures")


func test_the_pump_and_the_aura_through_the_1997_damage_window() -> void:
	# The owner's likely table: the 1997 ruleset, a human on both seats,
	# damage waiting in the prevention window before it lands. With the
	# pump active the packet carries 3 and lands once; without it, 2.
	g.rules.set_edition("fifth")
	_human_seat(0)
	_human_seat(1)
	var vultures := _dressed_vultures()
	give_hand(1, "Healing Salve")   # something the window could use
	assert_eq(_swing_through_window(vultures), 2, "2 through the window")
	_assert_two_three(vultures, "the window changed nothing on the Vultures")


func test_the_owner_reads_the_number_off_the_card_the_engine_deals() -> void:
	# The table's P/T label is `cur_power`/`cur_toughness` (mini_card.gd,
	# `Show power/toughness on small cards`); the packet is `cur_power`
	# ([method MtgGame._collect_damage_requests]). The two cannot disagree
	# — pinned so that the label a player reads is the number they lose.
	var vultures := _dressed_vultures()
	g.add_counters(vultures, "carrion", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, vultures, 0, []))
	resolve_stack()
	var shown := "%d/%d" % [vultures.cur_power, vultures.cur_toughness]
	assert_eq(shown, "3/4")
	assert_eq(_swing(vultures), vultures.cur_power, "the label IS the damage")


## The human-seat swing: attackers declared, no blocks, every window the
## 1997 rules open closed by the seat holding it, damage landed.
func _swing_through_window(vultures: CardInstance) -> int:
	var before: int = g.players[1].life
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [vultures.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	var guard := 0
	while g.current_step() != Mtg.Step.COMBAT_END and not g.game_over \
			and guard < 200:
		guard += 1
		if g.awaiting_damage_assignment:
			var request := g.damage_assignment_request()
			assert_ok(g.assign_combat_damage(int(request["assigner"]),
				g.default_damage_split(request["source"], request["targets"],
					int(request["amount"]), bool(request["trample"]),
					request["assigned"], bool(request.get("free_order", false)))))
		elif g.awaiting_damage_prevention or g.awaiting_regeneration:
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
	assert_lt(guard, 200, "the combat did not finish")
	return before - g.players[1].life


# ============================================================ the AI seat --

## Seat 0's AI plays its own turn through to the end step; seat 1 blocks
## nothing and passes everything.
func _ai_plays_its_turn(ai: AiPlayer) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and g.current_step() != Mtg.Step.END \
			and not g.game_over and guard < 400:
		guard += 1
		if g.awaiting_blockers:
			assert_ok(g.declare_blockers(1, {}))
		elif g.awaiting_attackers or g.priority_player == 0:
			ai.act(g)
		elif g.awaiting_damage_prevention or g.awaiting_regeneration:
			assert_ok(g.end_damage_prevention(1))
		else:
			assert_ok(g.pass_priority(1))
	assert_lt(guard, 400, "the AI's turn did not finish")


func test_the_ai_pays_the_pump_once_or_not_at_all() -> void:
	# The AI wearing the Vultures with two counters and the aura. Whether
	# its policy spends the counters is its own affair ([member
	# AiProfile.spends_counters] since 2026-09-09 — before that [method
	# AiPlayer._ability_available] refused every counter cost outright);
	# what this pins is the ARITHMETIC either way: 2 with the counters
	# kept, 3 with both spent, and never a 3 with counters still on or a
	# single counter left behind.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var vultures := _dressed_vultures()
	g.add_counters(vultures, "carrion", 2)
	var before: int = g.players[1].life
	advance_to_step(Mtg.Step.MAIN1)
	_ai_plays_its_turn(ai)
	var lost: int = before - g.players[1].life
	var counters: int = vultures.counters.get("carrion", 0)
	assert_true(counters == 0 or counters == 2,
		"the cost is two counters: %d left is a half-paid pump" % counters)
	if counters == 2:
		assert_eq(lost, 2, "counters kept: the aura's 2")
		_assert_two_three(vultures, "an unpumped 2/3")
	else:
		assert_eq(lost, 3, "counters spent: the pump's 3, once")
		assert_eq(vultures.cur_power, 3)
	advance_to_next_turn()
	_assert_two_three(vultures, "whatever the AI did, next turn is the aura's 2/3")
