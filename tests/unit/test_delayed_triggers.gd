extends GameTest
## DELAYED TRIGGERED ABILITIES (CR 603.7) — MtgGame.delayed_triggers, the
## queue a resolving spell or ability puts "at the beginning of your next
## upkeep, ..." into. What is pinned: the trigger fires on its event and
## only once (CR 603.7c) unless it repeats; it belongs to the GAME, so it
## survives its source being exiled or bounced (CR 603.7a); "your" is the
## controller fixed when it was created (CR 603.7d); a player's delayed
## triggers take that player's APNAP slot (CR 603.3b); a repeating entry
## keeps state between firings through MtgGame.current_delayed, which the
## journal and the pre-flight rewind both cover; and an entry with a
## settlement can be paid off early by the player it names (Nafs Asp's
## "unless they pay {1} before that draw step").
##
## One synthetic card pins the mechanism: Test Seer, an artifact whose ETB
## schedules "at the beginning of your next upkeep, you gain 3 life".


class Seer:
	static func data() -> CardData:
		return CardData.new("Test Seer", "{1}", Mtg.CardType.ARTIFACT) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.ENTERS_BATTLEFIELD, Seer.foresee,
				"When Test Seer enters, you gain 3 life at the beginning of your next upkeep.",
				Seer.is_self))

	static func is_self(_game: MtgGame, source: CardInstance,
			event: GameEvent) -> bool:
		return event.data.get("instance") == source

	static func foresee(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
		var who := source.controller_id
		game.schedule_delayed_trigger(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, Seer.pay_out.bind(who),
			"At the beginning of your next upkeep, you gain 3 life.",
			Seer.your_upkeep.bind(who)), who, source)

	static func your_upkeep(_game: MtgGame, _source: CardInstance,
			event: GameEvent, who: int) -> bool:
		return int(event.data["player"]) == who

	static func pay_out(game: MtgGame, _source: CardInstance, _event: GameEvent,
			who: int) -> void:
		game.adjust_life(who, 3)


## A permanent that names every one of its controller's upkeeps.
class Bell:
	static func data() -> CardData:
		return CardData.new("Test Bell", "{1}", Mtg.CardType.ARTIFACT) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.UPKEEP_START, Bell.ring,
				"At the beginning of your upkeep, you gain 1 life.",
				Bell.own_upkeep))

	static func own_upkeep(_game: MtgGame, source: CardInstance,
			event: GameEvent) -> bool:
		return int(event.data["player"]) == source.controller_id

	static func ring(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
		game.adjust_life(source.controller_id, 1)


## Asks a yes/no question as it resolves, then schedules — so a human
## seat's pre-flight probes it once and runs it once.
class Oracle:
	static func data() -> CardData:
		return CardData.new("Test Oracle", "{1}", Mtg.CardType.ARTIFACT) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.ENTERS_BATTLEFIELD, Oracle.consult,
				"When Test Oracle enters, you may have it foresee.",
				Seer.is_self))

	static func consult(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
		if game.agents[source.controller_id].choose_yes_no(game,
				source.controller_id, "Foresee?", true):
			Seer.foresee(game, source, event)


func _next_own_upkeep() -> void:
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 0)


func _counting_repeater(pid: int, source: CardInstance) -> Dictionary:
	return g.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, _count_up,
		"At the beginning of each of your upkeeps, count.",
		Seer.your_upkeep.bind(pid)), pid, source, true, {"fired": 0})


static func _count_up(game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
	var entry := game.current_delayed()
	entry["memory"]["fired"] = int(entry["memory"]["fired"]) + 1


func test_a_delayed_trigger_fires_at_its_event_and_only_once() -> void:
	put_synthetic(0, Seer.data())
	resolve_stack()   # the ETB
	assert_eq(g.delayed_triggers.size(), 1, "queued, not resolved")
	assert_eq(g.players[0].life, 20)
	advance_to_next_turn()   # P1's upkeep: not "your" upkeep
	assert_eq(g.players[0].life, 20)
	assert_eq(g.delayed_triggers.size(), 1)
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.stack.size(), 1)
	assert_true(g.stack.back().description.contains("Test Seer — At the beginning"))
	assert_true(g.delayed_triggers.is_empty(), "left the queue as it triggered (CR 603.7c)")
	resolve_stack()
	assert_eq(g.players[0].life, 23)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].life, 23, "once")


func test_a_delayed_trigger_survives_its_source_leaving() -> void:
	var seer := put_synthetic(0, Seer.data())
	resolve_stack()
	g.exile_permanent(seer)
	assert_eq(seer.zone, Mtg.Zone.EXILE)
	_next_own_upkeep()
	resolve_stack()
	assert_eq(g.players[0].life, 23, "CR 603.7a — independent of its source")


func test_a_delayed_trigger_keeps_the_controller_it_was_created_with() -> void:
	var seer := put_synthetic(0, Seer.data())
	resolve_stack()
	g.change_control(seer, 1)   # stolen before the upkeep
	assert_eq(seer.controller_id, 1)
	advance_to_next_turn()   # P1's upkeep — the thief's
	assert_eq(g.players[1].life, 20, "not the thief's upkeep to gain on")
	advance_to_step(Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(g.players[0].life, 23, "CR 603.7d — 'you' is who created it")


func test_delayed_triggers_take_their_controllers_apnap_slot() -> void:
	# P1 (non-active on turn 3) has a delayed trigger; P0 (active) has a
	# permanent's upkeep trigger. P0's goes on the stack first and
	# resolves LAST (CR 603.3b).
	put_synthetic(0, Bell.data())
	var seer := put_synthetic(1, Seer.data())
	resolve_stack()
	# P1's "next upkeep" is turn 2; make the queue entry fire on P0's
	# upkeep instead by scheduling one for P0's turn by hand.
	g.delayed_triggers.clear()
	g.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, Seer.pay_out.bind(1),
		"At the beginning of the next upkeep, P1 gains 3 life.",
		Seer.your_upkeep.bind(0)), 1, seer)
	_next_own_upkeep()
	assert_eq(g.stack.size(), 2)
	assert_true(g.stack[0].description.begins_with("Test Bell"), "P0's went on first")
	assert_true(g.stack[1].description.begins_with("Test Seer"), "P1's on top")
	assert_eq(g.stack[1].controller, 1)
	resolve_stack()
	assert_eq(g.players[1].life, 23)
	assert_eq(g.players[0].life, 21)


func test_a_repeating_delayed_trigger_stays_and_keeps_its_memory() -> void:
	var seer := put_synthetic(0, Seer.data())
	resolve_stack()
	g.delayed_triggers.clear()
	var entry := _counting_repeater(0, seer)
	_next_own_upkeep()
	resolve_stack()
	assert_eq(g.delayed_triggers.size(), 1, "a repeating entry stays")
	assert_eq(int(entry["memory"]["fired"]), 1)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(int(g.delayed_triggers[0]["memory"]["fired"]), 2)
	advance_to_next_turn()
	assert_eq(int(g.delayed_triggers[0]["memory"]["fired"]), 2, "not on P1's upkeep")


func test_current_delayed_is_empty_outside_a_delayed_resolution() -> void:
	assert_true(g.current_delayed().is_empty())
	put_synthetic(0, Bell.data())
	_next_own_upkeep()
	resolve_stack()
	assert_true(g.current_delayed().is_empty())


func test_a_search_rewind_puts_the_queue_back() -> void:
	var seer := put_synthetic(0, Seer.data())
	resolve_stack()
	assert_eq(g.delayed_triggers.size(), 1)
	var mark := g.make_mark()
	var entry := _counting_repeater(0, seer)
	entry["memory"]["fired"] = 5
	assert_eq(g.delayed_triggers.size(), 2)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.delayed_triggers.size(), 1, "the searched entry is gone")
	assert_false(bool(g.delayed_triggers[0]["repeats"]))
	# And a firing inside a search is undone too: the entry is back.
	mark = g.make_mark()
	g.dispatch_event(Mtg.EventType.UPKEEP_START, {"player": 0})
	assert_true(g.delayed_triggers.is_empty())
	assert_eq(g.stack.size(), 1)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.delayed_triggers.size(), 1, "the original entry is back")
	assert_true(g.stack.is_empty())


func test_a_pre_flight_probe_does_not_schedule_twice() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	put_synthetic(0, Oracle.data())
	assert_eq(g.stack.size(), 1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_not_null(g.awaiting_choice, "the probe found the question")
	assert_true(g.delayed_triggers.is_empty(), "and the probe's schedule was rewound")
	assert_ok(g.answer_choice(true))
	assert_eq(g.delayed_triggers.size(), 1, "scheduled exactly once")
	g.agents[0] = DecisionAgent.new()
	g.interactive_choices = false
	_next_own_upkeep()
	resolve_stack()
	assert_eq(g.players[0].life, 23)


# ------------------------------------------------------------- settlement --

func _debt(pid: int, source: CardInstance) -> Dictionary:
	var entry := g.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, Seer.pay_out.bind(pid),
		"At the beginning of your next upkeep, you gain 3 life.",
		Seer.your_upkeep.bind(pid)), pid, source, false, {}, "the Seer's debt")
	entry["settle_cost"] = ManaCost.parse("{1}")
	entry["settle_by"] = pid
	return entry


func test_settling_a_delayed_trigger_pays_and_drops_it() -> void:
	var seer := put_synthetic(0, Seer.data())
	resolve_stack()
	g.delayed_triggers.clear()
	var entry := _debt(0, seer)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.settleable_delayed_triggers(0), [entry] as Array[Dictionary])
	assert_true(g.settleable_delayed_triggers(1).is_empty())
	assert_refused(g.settle_delayed_trigger(0, int(entry["id"])), "not enough mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.settle_delayed_trigger(0, int(entry["id"])))
	assert_eq(g.players[0].mana_pool.total(), 0, "the {1} was spent")
	assert_true(g.delayed_triggers.is_empty())
	assert_true(String(g.log_lines[g.log_lines.size() - 1]).contains("the Seer's debt"))
	_next_own_upkeep()
	resolve_stack()
	assert_eq(g.players[0].life, 20, "it never fired")


func test_settling_refuses_the_wrong_player_the_wrong_moment_and_a_plain_entry() -> void:
	var seer := put_synthetic(0, Seer.data())
	resolve_stack()
	var plain: Dictionary = g.delayed_triggers[0]
	var entry := _debt(0, seer)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	add_mana(1, Mtg.ManaColor.C)
	assert_refused(g.settle_delayed_trigger(1, int(entry["id"])), "priority")
	assert_refused(g.settle_delayed_trigger(0, int(plain["id"])), "can't be paid off")
	assert_refused(g.settle_delayed_trigger(0, 999), "no such")
	assert_ok(g.pass_priority(0))   # P1 has priority now
	assert_refused(g.settle_delayed_trigger(1, int(entry["id"])), "not yours")
	assert_refused(g.settle_delayed_trigger(0, int(entry["id"])), "priority")
	assert_eq(g.delayed_triggers.size(), 2)
