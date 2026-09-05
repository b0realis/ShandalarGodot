extends GameTest
## ADVERSARIAL AUDIT of the §1.3 rewind point — the tests that try to BREAK
## [GameSnapshot] rather than confirm it.
##
## `test_choice_preflight.gd` proves the pre-flight does what it says on a
## handful of hand-picked cards. This file attacks the mechanism itself,
## because the failure mode is silent: a piece of state the reflective walk
## misses is a piece of state a probe MUTATES FOR REAL, and the symptom is a
## card that duplicates its effect on the one board where that state matters.
##
## The weapon is a FINGERPRINT: every script variable of every scripted
## object reachable from the game, rendered as text. It is deliberately
## WIDER than [constant GameSnapshot.STATE_CLASSES] — it walks the
## DEFINITIONS too (CardData, the abilities, the effects), because
## [CardRegistry] is process-global and static, so a probe that writes to a
## definition corrupts every other game in the process, tests included.
##
## Anything the fingerprint sees that a rewind does not put back is a bug.


# ---------------------------------------------------------- the fingerprint --

## "<class>#<id>.<property>" -> rendered value, for every scripted object
## reachable from [param root]. Objects render as their instance id, so
## IDENTITY is compared here and CONTENT is compared by that object's own
## entries — which is exactly the property a rewind that writes in place has
## to keep.
func _fingerprint(root: Object) -> Dictionary:
	var out := {}
	var seen := {}
	var queue: Array = [root]
	while not queue.is_empty():
		var obj: Object = queue.pop_back()
		if obj == null:
			continue
		var oid := obj.get_instance_id()
		if seen.has(oid):
			continue
		var script: Script = obj.get_script()
		if script == null:
			continue   # built-ins (RandomNumberGenerator) — see _rng_line
		seen[oid] = true
		var cls := script.get_global_name()
		if cls == "":
			cls = script.resource_path.get_file()
		var label := "%s#%d" % [cls, oid]
		for p in obj.get_property_list():
			if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var pname := String(p["name"])
			out["%s.%s" % [label, pname]] = _render(obj.get(pname), queue)
	return out


func _render(value: Variant, queue: Array) -> String:
	var t := typeof(value)
	if t == TYPE_OBJECT:
		if value == null:
			return "<null>"
		queue.append(value)
		return "@%d" % (value as Object).get_instance_id()
	if t == TYPE_ARRAY:
		var parts := PackedStringArray()
		for e in (value as Array):
			parts.append(_render(e, queue))
		return "[%s]" % ",".join(parts)
	if t == TYPE_DICTIONARY:
		var d := value as Dictionary
		var parts2 := PackedStringArray()
		for k in d:
			parts2.append("%s=%s" % [_render(k, queue), _render(d[k], queue)])
		return "{%s}" % ",".join(parts2)
	if t == TYPE_CALLABLE:
		var c := value as Callable
		if not c.is_valid():
			return "call:<invalid>"
		return "call:%s@%d" % [c.get_method(), c.get_object_id()]
	if t == TYPE_SIGNAL:
		return "signal:%s" % (value as Signal).get_name()
	return str(value)


## The whole game state, fingerprint plus the two things the walk cannot
## see: the RNG (a built-in with no script) and the stack's own shape.
func _state_of(game: MtgGame) -> Dictionary:
	var out := _fingerprint(game)
	out["<rng>.state"] = str(game.rng.state)
	out["<rng>.seed"] = str(game.rng.seed)
	return out


## The first [param limit] keys whose values differ, as readable lines.
## Keys present on one side only count as differences too.
func _diff(before: Dictionary, after: Dictionary, limit := 8) -> PackedStringArray:
	var out := PackedStringArray()
	var keys := before.keys()
	keys.append_array(after.keys())
	var seen := {}
	var ordered: Array = []
	for k in keys:
		if not seen.has(k):
			seen[k] = true
			ordered.append(k)
	ordered.sort()
	for k in ordered:
		var b: Variant = before.get(k, "<absent>")
		var a: Variant = after.get(k, "<absent>")
		if str(b) != str(a):
			if out.size() < limit:
				out.append("%s: %s -> %s" % [k, b, a])
	return out


func _assert_same(before: Dictionary, after: Dictionary, what: String) -> void:
	var diffs := _diff(before, after)
	assert_eq(diffs.size(), 0, "%s\n  %s" % [what, "\n  ".join(diffs)])


# --------------------------------------------------------- a busy board --

## A board with something of every kind on it: permanents with counters and
## damage, an aura, a token, cards in every zone, floating until-end-of-turn
## effects, a live combat, mana in a pool and a stack item waiting.
func _busy_board() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Bad Moon")
	var wall := put_battlefield(1, "Wall of Stone")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	give_hand(0, "Lightning Bolt")
	give_hand(0, "Giant Growth")
	give_hand(1, "Dark Ritual")
	g.players[0].graveyard.append(_grave(0, "Healing Salve"))
	g.players[1].exile.append(_exiled(1, "Ornithopter"))
	bear.counters["+1/+1"] = 2
	bear.damage = 1
	wall.damage = 2
	g.continuous.add_until_eot_pump(bear.id, 1, 1, [])
	g.create_token(0, CardRegistry.get_card("Ornithopter"))
	g.players[0].mana_pool.add(Mtg.ManaColor.G, 2)
	g.players[1].mana_pool.add(Mtg.ManaColor.B, 1)
	g.recalculate()


func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	return inst


func _exiled(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.EXILE
	return inst


# ================================================== the rewind, attacked ==

func test_a_rewind_restores_every_script_variable_reachable_from_the_game() -> void:
	# The blunt instrument: fingerprint EVERYTHING, churn the game hard,
	# rewind, and demand the fingerprint back. Any state the reflective walk
	# does not reach shows up here as a diff, whatever card put it there.
	_busy_board()
	var before := _state_of(g)
	var snap := GameSnapshot.take(g)

	var bear := g.players[0].battlefield[0]
	g.adjust_life(0, -6)
	g.adjust_life(1, 3)
	g.draw_cards(0, 3)
	g.draw_cards(1, 2)
	g.discard_cards(0, [g.players[0].hand[0]])
	g.destroy(bear)
	g.create_token(1, CardRegistry.get_card("Grizzly Bears"))
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 5)
	g.players[1].poison += 4
	g.combat.attackers[99] = true
	g.combat.blocks[98] = 99
	g.continuous.add_until_eot_pump(7, 3, 3, [Mtg.Keyword.FLYING])
	g.rng.randi()
	g.rng.randi()
	g.turn_number += 4
	g.log_line("noise")
	g.recalculate()
	g.check_state_based_actions()

	snap.restore()
	_assert_same(before, _state_of(g), "a rewind did not put everything back")


func test_a_rewind_restores_a_shuffled_library_exactly() -> void:
	# Fisher-Yates through game.rng: the array order AND the rng stream both
	# have to come back, or the real resolution draws a different card than
	# the probe promised.
	_busy_board()
	var before := _state_of(g)
	var snap := GameSnapshot.take(g)
	g._shuffle(g.players[0].library)
	g._shuffle(g.players[1].library)
	snap.restore()
	_assert_same(before, _state_of(g), "a rewound shuffle is not the same library")


func test_a_rewind_survives_a_whole_turn_of_real_play() -> void:
	# Not surgery — the turn machine itself: untap, upkeep, draw, combat,
	# cleanup, all of it undone.
	_busy_board()
	var before := _state_of(g)
	var snap := GameSnapshot.take(g)
	advance_to_next_turn()
	advance_to_next_turn()
	snap.restore()
	_assert_same(before, _state_of(g), "two turns of play did not rewind")


func test_a_rewind_does_not_sever_the_stack_items_shared_effect_list() -> void:
	# StackItem.effects is ASSIGNED from CardData.spell_effects, so the two
	# alias one Array until a rewind copies it. The rewind is allowed to hand
	# back a different Array object — what it may never do is change what is
	# IN it, or let a write through one reach the shared definition.
	var bolt := give_hand(0, "Lightning Bolt")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	var item: StackItem = g.stack[0]
	var definition: Array = bolt.data.spell_effects
	var snap := GameSnapshot.take(g)
	snap.restore()
	assert_eq(item.effects.size(), definition.size(),
		"the item still runs the same effects")
	for i in definition.size():
		assert_eq(item.effects[i], definition[i],
			"and they are the same effect objects")


# ======================================= the probe, in the real machinery ==

func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func test_a_probe_changes_nothing_but_the_hold_counter() -> void:
	# The sharpest form of the whole audit: run the pre-flight ITSELF over a
	# fingerprinted game and demand that the only thing that moved is the
	# liveness counter the pre-flight owns.
	_human_seat(0)
	_busy_board()
	put_battlefield(0, "Junún Efreet")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	_to_upkeep_of_turn(3)
	assert_gt(g.stack.size(), 0, "an upkeep trigger is waiting")
	var before := _state_of(g)
	var question := g._preflight()
	assert_not_null(question, "the probe found the Efreet's question")
	var after := _state_of(g)
	# _held_answered is the one variable the pre-flight is allowed to move.
	before.erase("MtgGame#%d._held_answered" % g.get_instance_id())
	after.erase("MtgGame#%d._held_answered" % g.get_instance_id())
	_assert_same(before, after, "a probe left a trace in the game state")


func test_a_probe_does_not_touch_a_shared_card_definition() -> void:
	# CardRegistry is static and process-global: one write to a CardData
	# from inside a probe would poison every later game in this run.
	_human_seat(0)
	put_battlefield(0, "Junún Efreet")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	_to_upkeep_of_turn(3)
	var names := ["Junún Efreet", "Swamp", "Grizzly Bears", "Lightning Bolt"]
	var before := {}
	for n in names:
		before.merge(_fingerprint(CardRegistry.get_card(n)))
	g._preflight()
	var after := {}
	for n in names:
		after.merge(_fingerprint(CardRegistry.get_card(n)))
	_assert_same(before, after, "a probe wrote to a shared card definition")


func test_a_probe_consumes_and_returns_the_agents_mailbox() -> void:
	# The seat being probed must not be able to tell. HumanAgent's mailbox is
	# pop_front()ed by the probe and has to come back full.
	var human := _human_seat(0)
	put_battlefield(0, "Junún Efreet")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	_to_upkeep_of_turn(3)
	human.park(PlayerChoice.Kind.YES_NO, true, "Junún Efreet")
	assert_true(human.has_parked_for("Junún Efreet"))
	var question := g._preflight()
	assert_null(question, "the parked answer means nothing is left to ask")
	assert_true(human.has_parked_for("Junún Efreet"),
		"and the answer is still parked for the real resolution")


func test_a_probe_does_not_disturb_an_open_combat_hold() -> void:
	# NESTED HOLDS. The four awaiting_* flags are plain script variables, so a
	# probe that ran while one was set would have to put it back exactly.
	_human_seat(0)
	put_battlefield(0, "Junún Efreet")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	_to_upkeep_of_turn(3)
	# Force every other hold on at once and probe underneath them.
	g.awaiting_attackers = true
	g.awaiting_blockers = true
	g.awaiting_discard = true
	g.discard_count = 3
	g.awaiting_damage_assignment = true
	var before := _state_of(g)
	g._preflight()
	var after := _state_of(g)
	before.erase("MtgGame#%d._held_answered" % g.get_instance_id())
	after.erase("MtgGame#%d._held_answered" % g.get_instance_id())
	_assert_same(before, after, "a probe disturbed another hold")
	assert_true(g.awaiting_attackers and g.awaiting_blockers
		and g.awaiting_discard and g.awaiting_damage_assignment,
		"all four holds are still up")
	assert_eq(g.discard_count, 3)


func _to_upkeep_of_turn(turn: int) -> void:
	var guard := 0
	while not (g.turn_number == turn and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "did not reach turn %d's upkeep" % turn)


# ============================================== the instrument, checked ==

func test_the_fingerprint_would_notice_a_missed_object() -> void:
	# THE META-TEST. Every assertion above is worth exactly as much as the
	# fingerprint's reach, and a fingerprint that quietly walked nothing
	# would pass all of them. So: reach past [GameSnapshot] on purpose —
	# write to a shared CardData, which is a DEFINITION and deliberately
	# outside STATE_CLASSES — and demand that the diff sees it.
	_busy_board()
	var data := CardRegistry.get_card("Grizzly Bears")
	var before := _state_of(g)
	var snap := GameSnapshot.take(g)
	var was := data.power
	data.power = was + 99
	snap.restore()
	var diffs := _diff(before, _state_of(g))
	data.power = was   # the registry is process-global: put it back at once
	assert_gt(diffs.size(), 0,
		"the fingerprint saw nothing when a definition was corrupted")
	assert_gt(before.size(), 400,
		"and it is walking a real graph, not an empty one (%d entries)"
			% before.size())


func test_the_fingerprint_covers_the_rng_stream() -> void:
	# The RNG is a built-in with no script, so the reflective walk cannot
	# see it; _state_of adds it by hand. Prove that hand-add works.
	var before := _state_of(g)
	g.rng.randi()
	assert_gt(_diff(before, _state_of(g)).size(), 0, "an rng draw is visible")


# ================================================== the liveness counter ==

func test_the_hold_counter_resets_when_a_resolution_is_abandoned() -> void:
	# MtgGame._held_answered is the pre-flight's LIVENESS GUARD: "did the
	# last hold's answer actually get served?" It is scoped to ONE item's
	# hold cycle, so an abandoned one must not leave a count standing —
	# the next item's first probe compares against it, and a stale count
	# reads as "the parked answer is not being served", which resolves that
	# item on the heuristic instead of asking the player.
	var human := _human_seat(0)
	put_battlefield(0, "Junún Efreet")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	_to_upkeep_of_turn(3)
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice, "the Efreet's question is open")
	assert_eq(g._held_answered, 0, "and the counter is standing at zero")
	# The stack empties under the open hold — a caller that set the hold by
	# hand, or a front end that reset the duel. The answer has nowhere to go.
	g.stack.clear()
	assert_ok(g.answer_choice(true))
	assert_eq(g._held_answered, -1, "an abandoned hold leaves no count behind")
	# And the next probe is free to hold again rather than fall through to
	# the heuristic — which is what a stale count would have made it do.
	human._parked.clear()
	var efreet: CardInstance = g.players[0].battlefield[0]
	var item := StackItem.new()
	item.kind = Mtg.StackKind.TRIGGER
	item.card = efreet
	item.controller = 0
	item.trigger = efreet.data.triggered_abilities[0]
	item.event = GameEvent.new(Mtg.EventType.UPKEEP_START, {"player": 0})
	item.description = "Junún Efreet — upkeep"
	g.stack.append(item)
	assert_not_null(g._preflight(), "the next question still reaches the player")


# ============================== the trigger-listener gate, on the hot path ==
#
# `MtgGame.has_trigger_listener(type)` is the guard that keeps
# `Mtg.EventType.ABILITY_ACTIVATED` off the cost of every land tap of every
# turn: `tap_for_mana` only builds and dispatches the event when SOMEBODY
# is listening. It reads `_trigger_index`, which is rebuilt with the
# battlefield cache — so the whole guard rests on one invariant: every path
# that changes what is on the battlefield, or what a permanent on it IS,
# marks the cache stale.
#
# A stale FALSE is the dangerous direction: a listener nobody dispatches to,
# silently, on the one board where it arrived by the path that forgot to
# mark. (A stale TRUE only costs a wasted dispatch — `dispatch_event` still
# re-checks each ability, and a silenced permanent is skipped there.)

func test_the_listener_gate_sees_a_permanent_the_moment_it_arrives() -> void:
	assert_false(g.has_trigger_listener(Mtg.EventType.ABILITY_ACTIVATED),
		"an empty board listens for nothing")
	var leech := put_battlefield(0, "Powerleech")
	assert_true(g.has_trigger_listener(Mtg.EventType.ABILITY_ACTIVATED),
		"and hears it the moment the listener arrives")
	g.destroy(leech)
	assert_false(g.has_trigger_listener(Mtg.EventType.ABILITY_ACTIVATED),
		"and stops the moment it leaves")


func test_the_listener_gate_sees_a_permanent_that_phased_in() -> void:
	# phase_out / phase_in move a permanent off and back onto the battlefield
	# arrays WITHOUT a zone change, which is the one arrival path that does
	# not go through _put_on_battlefield.
	var leech := put_battlefield(0, "Powerleech")
	g.phase_out(leech)
	assert_false(g.has_trigger_listener(Mtg.EventType.ABILITY_ACTIVATED),
		"a phased-out permanent is treated as though it doesn't exist")
	g.phase_in(leech)
	assert_true(g.has_trigger_listener(Mtg.EventType.ABILITY_ACTIVATED),
		"and is heard again the instant it phases in")


func test_the_listener_gate_sees_a_permanent_that_became_a_copy() -> void:
	# become_copy changes what a permanent IS without touching the
	# battlefield arrays at all — the index is derived from `data`, so this
	# path has to mark the cache stale on its own.
	var leech := put_battlefield(1, "Powerleech")
	var blank := put_battlefield(0, "Grizzly Bears")
	g.destroy(leech)
	assert_false(g.has_trigger_listener(Mtg.EventType.ABILITY_ACTIVATED))
	g.become_copy(blank, CardRegistry.get_card("Powerleech"))
	assert_true(g.has_trigger_listener(Mtg.EventType.ABILITY_ACTIVATED),
		"a permanent that BECAME a listener is heard")
