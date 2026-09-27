extends GutTest
## THE REFEREE (2026-09-27): one duel played through a pipe, a program
## in a seat — DeckLab/referee.gd hosted by the game's `--referee`. In
## here the pipe is two Callables: `writer` collects the JSON lines the
## referee prints, `reader` answers each decision from a script of
## lines or from the coverage pilot (tests/support/sg_network_pilot.gd)
## reading `last_decision.view` — the very view a program would read.
##
## Pinned: hello, decision, refused and result shapes; the options per
## mode; a refused answer asks the same decision again from a fresh
## view; twenty refusals in a row, a closed pipe, the turn limit and the
## decision cap each end the duel with their reason; the journal is
## sent once; self-play seats two agents; a joined table is played
## through anything with the lobby client's face; every refusal before
## play is one error line, exit 2; the three doors and the docs.

const Pilot := preload("res://tests/support/sg_network_pilot.gd")
const REFEREE := "res://DeckLab/referee.gd"
const DECKS := ["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck"]

var _lines: Array = []
var _queue: Array = []
var _pilot_on := true
var _pilots: Dictionary = {}
var _made: Array[String] = []


func before_each() -> void:
	_lines.clear()
	_queue.clear()
	_pilots.clear()
	_pilot_on = true


func after_each() -> void:
	for path in _made:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made.clear()


## The referee with the pipe replaced: what it writes lands parsed in
## `_lines`; what it reads comes from `_queue` first (a String, or null
## for a closed pipe), then from a pilot per seat, or null once the
## pilot is off.
func _referee():
	var ref = autofree(load(REFEREE).new())
	ref.writer = func(line: String) -> void: _lines.append(JSON.parse_string(line))
	ref.reader = func() -> Variant: return _answer(ref)
	return ref


func _answer(ref) -> Variant:
	if not _queue.is_empty():
		return _queue.pop_front()
	if not _pilot_on or ref.last_decision.is_empty():
		return null
	var seat := int(ref.last_decision.seat)
	if not _pilots.has(seat):
		_pilots[seat] = Pilot.new()
	return JSON.stringify(_pilots[seat].choose(ref.last_decision.view, seat))


func _of(type: String) -> Array:
	var found: Array = []
	for line in _lines:
		if line is Dictionary and line.get("type", "") == type:
			found.append(line)
	return found


func _errors() -> Array:
	var found: Array = []
	for line in _lines:
		if line is Dictionary and line.has("error"):
			found.append(line.error)
	return found


## JSON.parse_string hands keys back sorted; the referee's records keep
## their insertion order — compare the sets.
static func _keys(record: Dictionary) -> Array:
	var keys := record.keys()
	keys.sort()
	return keys


func _scratch(name: String) -> String:
	var path := "user://%s" % name
	_made.append(path)
	return path


# --------------------------------------------------- before the duel --

func test_help_names_every_switch_and_each_needs_a_value() -> void:
	var ref = _referee()
	assert_eq(ref._main(PackedStringArray(["--help"])), 0)
	assert_eq(ref._main(PackedStringArray(["-V"])), 0)
	assert_eq(_lines.size(), 0, "help and the version go to stdout as text, not JSON")
	for flag in ref.FLAG_HINTS:
		assert_true(ref.HELP.contains(flag), "%s is in the help" % flag)
		assert_true(String(ref.FLAG_HINTS[flag]).begins_with(flag), "the hint begins with %s" % flag)
		var parsed: Dictionary = ref._parse_args(PackedStringArray([flag]))
		assert_true(parsed.has("error") and String(parsed.error.message).contains("needs a value"),
			"%s alone is refused" % flag)
	assert_true(ref.HELP.contains("--dry-run"))
	for op in ref.DUEL_OPS:
		assert_true(SgProtocol.FIELDS.has(op), "%s is a wire op" % op)
	for seat in ref.SEATS:
		assert_true(ref.HELP.contains(seat), "seat %s is in the help" % seat)


func test_a_dry_run_is_one_plan_line() -> void:
	var ref = _referee()
	var code: int = ref._main(PackedStringArray(DECKS + ["--seed", "7", "--seat-b", "unfair", "--turns", "50", "--dry-run"]))
	assert_eq(code, 0)
	assert_eq(_lines.size(), 1)
	var plan: Dictionary = _lines[0]
	assert_eq(_keys(plan), _keys(ref.last_plan), "last_plan is the line")
	assert_true(bool(plan.dry_run))
	assert_eq(plan.tool, "referee")
	assert_eq(int(plan.protocol), ref.PROTOCOL)
	assert_eq(plan.version, LabConsole.version())
	assert_eq(int(plan.seed), 7)
	assert_eq(int(plan.turns), 50)
	assert_eq(Array(plan.ops), ref.DUEL_OPS)
	assert_eq(plan.seats.size(), 2)
	assert_eq(plan.seats[0].player, "agent")
	assert_eq(plan.seats[0].name, "Agent")
	assert_eq(plan.seats[0].deck, "Big Green")
	assert_true(String(plan.seats[0].file).ends_with("big_green.deck"))
	assert_eq(plan.seats[1].player, "unfair")
	assert_eq(plan.seats[1].name, SgBotPlayer.label({"level": 3, "unfair": true}))
	assert_eq(ref._bot_options("unfair"), {"level": 3, "unfair": true, "pace_ms": ref.BOT_PACE_MS})
	assert_eq(ref._bot_options("apprentice").level, 0)
	assert_eq(ref._seat_name("agent", "agent", "B"), "Agent B")
	assert_null(plan.packs)
	assert_true(plan.has("packs_on"))


func test_every_refusal_before_play_is_one_error_line_exit_2() -> void:
	var cases := [
		[["--deck-b", "white_knights.deck"], "option", "--deck-a", ""],
		[["--deck-a", "big_gren.deck", "--deck-b", "white_knights.deck"], "deck", "--deck-a", "big_green"],
		[DECKS + ["--seat-b", "wizzard"], "option", "--seat-b", "wizard"],
		[DECKS + ["--seat-a", "wizard"], "option", "--seat-a", "nobody on the pipe"],
		[DECKS + ["--dry-rn"], "option", "--dry-rn", "--dry-run"],
		[DECKS + ["--seed"], "option", "--seed", "needs a value"],
		[DECKS + ["--seed", "x"], "option", "--seed", "non-negative integer"],
		[DECKS + ["--turns", "-3"], "option", "--turns", "non-negative integer"],
		[["--join", "abc"], "option", "--deck", "--deck is required"],
		[["--join", "abc", "--deck", "big_green.deck", "--name", ""], "option", "--name", ""],
		[["--join", "abc", "--deck", "big_green.deck", "--wait", "0"], "join", "--join", ""],
	]
	for row in cases:
		before_each()
		var ref = _referee()
		var code: int = ref._main(PackedStringArray(row[0]))
		assert_eq(code, 2, "%s exits 2" % " ".join(row[0]))
		assert_eq(_lines.size(), 1, "%s writes one line" % " ".join(row[0]))
		var errors := _errors()
		assert_eq(errors.size(), 1)
		var error: Dictionary = errors[0]
		assert_eq(_keys(error), _keys(ref.last_error), "last_error is the line")
		assert_eq(error.tool, "referee")
		assert_eq(int(error.exit), 2)
		assert_eq(error.kind, row[1], " ".join(row[0]))
		assert_eq(error.get("flag", ""), row[2], " ".join(row[0]))
		if row[3] != "":
			var text := String(error.message) + " " + JSON.stringify(error.get("suggestions", []))
			assert_true(text.contains(row[3]), "%s says %s: %s" % [" ".join(row[0]), row[3], text])
	before_each()
	var ref = _referee()
	ref._main(PackedStringArray(DECKS + ["--seat-b", "wizzard"]))
	assert_eq(Array(ref.last_error.suggestions), ["wizard"])
	assert_eq(Array(ref.last_error.seats), ref.SEATS.keys())
	before_each()
	ref = _referee()
	ref._main(PackedStringArray(["--deck-a", "big_gren.deck", "--deck-b", "white_knights.deck"]))
	assert_eq(Array(ref.last_error.tried), ["big_gren.deck", "decks/big_gren.deck", "res://decks/big_gren.deck"])


func test_an_unplayable_deck_is_refused_with_the_check_report() -> void:
	var path := _scratch("referee_bad.deck")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("name: Broken\n4 Not A Card\n56 Forest\n")
	file.close()
	var ref = _referee()
	var one: Dictionary = ref._load_deck(path, "--deck-a")
	assert_true(one.has("error"))
	assert_eq(one.error.detail.kind, "deck")
	assert_true(one.error.detail.has("report"))
	assert_true(one.error.detail.problems.size() >= 1)
	assert_true(String(one.error.message).contains("cannot be played"))
	var good: Dictionary = ref._load_deck("big_green.deck", "--deck-a")
	assert_eq(good.deck.name, "Big Green")
	assert_true(good.deck.cards.size() >= 40)
	assert_true(good.deck.has("sideboard") and good.deck.has("printings"))


func test_parse_action_keeps_the_pipe_honest() -> void:
	var ref = _referee()
	var parse := func(text: String) -> Dictionary: return ref._parse_action(text, 0)
	assert_true(String(parse.call("nonsense").refusal).begins_with("not a JSON object"))
	assert_true(String(parse.call("[1, 2]").refusal).begins_with("not a JSON object"))
	assert_true(String(parse.call('{"op": "pas"}').refusal).contains("did you mean pass"))
	assert_true(String(parse.call('{"op": "pass", "extra": 1}').refusal).contains("takes exactly the keys op"))
	assert_true(String(parse.call('{"op": "play"}').refusal).contains("takes exactly the keys op, card"))
	assert_true(String(parse.call('{"op": "play", "card": 5}').refusal).contains("wire would not carry"))
	assert_true(String(parse.call('{"op": "host", "name": "x", "decks": "own", "deck": {}}').refusal).begins_with("unknown op 'host'"))
	assert_eq(String(parse.call('{"seat": 1, "op": "pass"}').refusal), "this decision is seat 0's, not seat 1's")
	assert_eq(String(parse.call('{"seat": "b", "op": "pass"}').refusal), "this decision is seat 0's, not seat b's")
	var own: Dictionary = parse.call('{"seat": 0, "op": "pass"}')
	assert_false(own.has("refusal"))
	assert_eq(own.action, {"op": "pass"})
	assert_eq(parse.call('{"op": "prepare", "card": "c3", "kind": "spell", "index": 0, "x": 0, "mode": 0}').action.card, "c3")


# ------------------------------------------------------- the duel --

func test_an_agent_plays_the_wizard_to_a_result() -> void:
	var log_path := _scratch("referee_duel.log")
	var ref = _referee()
	var code: int = ref._main(PackedStringArray(DECKS + ["--seed", "7", "--log", log_path]))
	assert_eq(code, 0)
	var hello: Dictionary = _lines[0]
	assert_eq(hello.type, "hello")
	assert_eq(_keys(hello), _keys(ref.last_hello), "last_hello is the line")
	assert_eq(hello.tool, "referee")
	assert_eq(int(hello.protocol), 1)
	assert_eq(hello.version, LabConsole.version())
	assert_eq(int(hello.seed), 7)
	assert_true(int(hello.toss) in [0, 1])
	assert_eq(int(hello.turns), ref.DEFAULT_TURNS)
	assert_eq(int(hello.limits.decisions), ref.MAX_DECISIONS)
	assert_eq(int(hello.limits.refusals), ref.MAX_REFUSALS)
	assert_eq(Array(hello.ops), ref.DUEL_OPS)
	assert_eq(hello.seats[0].name, "Agent")
	assert_eq(hello.seats[1].player, "wizard")
	assert_eq(hello.log, log_path)
	var results := _of("result")
	assert_eq(results.size(), 1)
	var result: Dictionary = results[0]
	assert_eq(_lines.back().type, "result", "the result is the last line")
	assert_eq(_keys(result), _keys(ref.last_result), "last_result is the line")
	assert_eq(int(ref.last_result.winner), int(result.winner))
	assert_eq(result.reason, "concluded")
	assert_true(int(result.winner) in [0, 1])
	assert_false(bool(result.draw))
	assert_true(int(result.turns) > 1)
	assert_eq(int(result.seed), 7)
	assert_eq(int(result.refusals), 0, "the pilot is never refused")
	assert_eq(result.names, ["Agent", SgBotPlayer.label({"level": 3, "unfair": false})])
	assert_eq(result.life.size(), 2)
	assert_eq(result.log, log_path)
	assert_true(FileAccess.get_file_as_string(log_path).length() > 100, "the engine log was written")
	var decisions := _of("decision")
	assert_eq(int(result.decisions), decisions.size())
	assert_true(decisions.size() > 20)
	assert_eq(_of("refused").size(), 0)
	var n := 0
	var modes := {}
	var serials := {}
	for decision in decisions:
		n += 1
		assert_eq(int(decision.n), n)
		assert_eq(int(decision.seat), 0)
		assert_eq(int(decision.view.actor), 0)
		assert_eq(decision.view.mode, decision.mode)
		assert_eq(decision.options.mode, decision.mode)
		assert_true(bool(decision.options.concede))
		assert_false(decision.options.has("waiting"))
		assert_eq(int(decision.turn), int(decision.view.turn))
		assert_eq(decision.step, decision.view.step)
		modes[decision.mode] = decision.options
		for entry in decision.view.journal:
			assert_false(serials.has(entry.serial), "journal entry %d is sent once" % int(entry.serial))
			serials[entry.serial] = true
	for mode in ["opening", "priority", "attack"]:
		assert_true(modes.has(mode), "a duel of %d turns had a %s decision" % [int(result.turns), mode])
	assert_true(modes.opening.has("keep") and modes.opening.has("mulligan"))
	assert_true(modes.priority.has("pass") and modes.priority.has("play") and modes.priority.has("prepare"))
	assert_true(modes.priority.play.has("lands") and modes.priority.prepare.has("casts") and modes.priority.prepare.has("abilities"))
	assert_true(modes.attack.attack.has("attackable") and modes.attack.has("attack_bands"))
	if modes.has("block"):
		assert_true(modes.block.block.has("blockable") and modes.block.block.has("pairs"))
	if modes.has("discard"):
		assert_true(modes.discard.has("count") and modes.discard.has("hand"))
	if modes.has("choice"):
		assert_true(modes.choice.has("prompt") and modes.choice.has("options"))
	assert_true(serials.size() > 10, "the journal reached the program")


func test_self_play_seats_two_agents() -> void:
	var ref = _referee()
	var code: int = ref._main(PackedStringArray(DECKS + ["--seed", "11", "--seat-b", "agent"]))
	assert_eq(code, 0)
	var result: Dictionary = ref.last_result
	assert_eq(result.reason, "concluded")
	assert_eq(result.names, ["Agent A", "Agent B"])
	assert_eq(int(result.refusals), 0)
	var seats := {}
	for decision in _of("decision"):
		seats[int(decision.seat)] = true
		assert_eq(int(decision.view.actor), int(decision.seat))
	assert_eq(seats.keys().size(), 2, "both seats decided")
	assert_eq(_pilots.size(), 2)
	assert_eq(_lines[0].seats[1].name, "Agent B")


func test_the_options_wait_when_it_is_not_this_seats_decision() -> void:
	var ref = _referee()
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck-a").deck
	var m := SgPracticeMatch.new(3, [deck, deck], ["A", "B"])
	var waiting: int = 1 - int(m.decision_state().actor)
	var options: Dictionary = ref.options_for(m.view(waiting), waiting)
	assert_true(bool(options.waiting))
	assert_true(bool(options.concede))
	assert_eq(options.mode, "opening")
	var acting: Dictionary = ref.options_for(m.view(m.toss_winner), m.toss_winner)
	assert_false(acting.has("waiting"))
	assert_true(acting.has("order"), "the toss winner chooses the order")
	assert_eq(acting.order.play, [true, false])


func test_a_closed_pipe_concedes_the_seat() -> void:
	_pilot_on = false
	var ref = _referee()
	var code: int = ref._main(PackedStringArray(DECKS + ["--seed", "7"]))
	assert_eq(code, 0)
	var result: Dictionary = ref.last_result
	assert_eq(result.reason, "eof")
	assert_eq(int(result.winner), 1, "the seat on the pipe conceded")
	assert_eq(int(result.decisions), 1)
	assert_eq(_of("decision").size(), 1)


func test_twenty_refusals_in_a_row_end_the_duel() -> void:
	_pilot_on = false
	var bad := ["nonsense", '{"op": "fly"}', '{"op": "pass", "extra": 1}', '{"seat": 1, "op": "pass"}', "[1, 2]"]
	for i in 25:
		_queue.append(bad[i % bad.size()])
	var ref = _referee()
	var code: int = ref._main(PackedStringArray(DECKS + ["--seed", "7"]))
	assert_eq(code, 0)
	var result: Dictionary = ref.last_result
	assert_eq(result.reason, "refusals")
	assert_eq(int(result.refusals), ref.MAX_REFUSALS)
	assert_eq(int(result.decisions), 1)
	assert_eq(int(result.winner), 1)
	assert_eq(_queue.size(), 5, "the referee stopped reading")
	var refused := _of("refused")
	assert_eq(refused.size(), 20)
	var decisions := _of("decision")
	assert_eq(decisions.size(), 20, "the decision is asked again after every refusal but the last")
	for decision in decisions:
		assert_eq(int(decision.n), 1)
	for i in refused.size():
		assert_eq(int(refused[i].n), 1)
		assert_eq(int(refused[i].seat), 0)
		assert_eq(int(refused[i].left), 19 - i)
	assert_true(String(refused[0].reason).begins_with("not a JSON object"))
	assert_true(String(refused[1].reason).begins_with("unknown op 'fly'"))
	assert_eq(refused[1].action, {"op": "fly"})
	assert_true(String(refused[2].reason).contains("takes exactly the keys"))
	assert_true(String(refused[3].reason).contains("seat 0's, not seat 1's"))
	# refused and decision lines alternate: hello, d, r, d, r, ... d, result
	assert_eq(_lines[1].type, "decision")
	assert_eq(_lines[2].type, "refused")
	assert_eq(_lines[3].type, "decision")
	assert_eq(_lines[-2].type, "refused")
	assert_eq(_lines.back().type, "result")


func test_a_refused_answer_asks_the_same_decision_again() -> void:
	# An attack is a duel op, but not one the opening takes: the engine
	# refuses it, the decision comes again with the same n, and the
	# pilot answers it.
	_queue.append('{"op": "attack", "cards": []}')
	var ref = _referee()
	assert_eq(ref._main(PackedStringArray(DECKS + ["--seed", "7"])), 0)
	assert_eq(ref.last_result.reason, "concluded")
	assert_eq(int(ref.last_result.refusals), 1)
	assert_eq(_lines[1].type, "decision")
	assert_eq(int(_lines[1].n), 1)
	assert_eq(_lines[2].type, "refused")
	assert_eq(int(_lines[2].n), 1)
	assert_eq(_lines[2].action, {"op": "attack", "cards": []})
	assert_true(String(_lines[2].reason) != "")
	assert_eq(_lines[3].type, "decision")
	assert_eq(int(_lines[3].n), 1, "the same decision, asked again")
	assert_eq(int(_lines[4].n), 2)


func test_a_blank_line_is_skipped_and_a_seat_may_be_named() -> void:
	_queue.append("")
	_queue.append("   ")
	_queue.append('{"seat": 0, "op": "concede"}')
	var ref = _referee()
	assert_eq(ref._main(PackedStringArray(DECKS + ["--seed", "7"])), 0)
	assert_eq(ref.last_result.reason, "conceded")
	assert_eq(int(ref.last_result.winner), 1)
	assert_eq(int(ref.last_result.refusals), 0)
	assert_eq(int(ref.last_result.decisions), 1)


func test_the_turn_limit_and_the_decision_cap_stop_the_duel() -> void:
	var ref = _referee()
	assert_eq(ref._main(PackedStringArray(DECKS + ["--seed", "7", "--turns", "2"])), 0)
	assert_eq(ref.last_result.reason, "limit")
	assert_eq(int(ref.last_result.winner), -1)
	assert_true(bool(ref.last_result.draw))
	assert_eq(int(ref.last_result.turns), 3)
	before_each()
	ref = _referee()
	ref.decisions = ref.MAX_DECISIONS - 1
	assert_eq(ref._main(PackedStringArray(DECKS + ["--seed", "7"])), 0)
	assert_eq(ref.last_result.reason, "decisions")
	assert_eq(int(ref.last_result.winner), -1)
	assert_eq(int(ref.last_result.decisions), ref.MAX_DECISIONS)
	assert_eq(_of("decision").size(), 1)


# ------------------------------------------------------ the table --

## A table held in this process, with the lobby client's face: the
## host seat is a wizard, the referee joins the open room as seat 1.
class FakeClient:
	extends RefCounted
	signal refused(reason: String)
	var online := false
	var status := "Connecting"
	var command_error := ""
	var state := {"rooms": [], "room": {}}
	var open := true
	var host_deck: Dictionary
	var commands: Array = []
	var match_seed := 5
	var m: SgPracticeMatch
	var _busy := 0
	var _polls := 0
	var _own: Dictionary

	func poll() -> void:
		_polls += 1
		if _polls >= 2 and not online:
			online = true
			status = "Online"
			state.rooms = [{"id": "t1", "name": "Wizard's table", "host": "Host", "open": open,
				"decks": "own", "deck": ""}]
		if _busy > 0:
			_busy -= 1
		_advance()

	func busy() -> bool:
		return _busy > 0

	func command(action: Dictionary) -> bool:
		commands.append(action.op)
		_busy = 1
		match String(action.op):
			"join":
				state.room = {"id": "t1", "name": "Wizard's table", "seat": 1, "names": ["Host", "Pilot"],
					"revision": 1, "ready": [false, false], "connected": [true, true], "game": {},
					"deck_names": ["Host deck", ""], "deck": "", "decks": "own", "fixed_deck": ""}
			"deck":
				_own = {"name": action.name, "cards": action.cards, "sideboard": action.sideboard,
					"printings": action.get("printings", {})}
				state.room.deck_names[1] = action.name
			"ready":
				m = SgPracticeMatch.new(match_seed, [host_deck, _own], ["Host", "Pilot"])
				assert(m.set_bot(0, {"level": 3, "unfair": false, "pace_ms": 50}))
				_refresh()
			"leave":
				state.room = {}
			_:
				var refusal := m.act(1, action)
				if refusal != "":
					refused.emit(refusal)
				else:
					_refresh()
		return true

	func _refresh() -> void:
		state.room.revision = int(state.room.revision) + 1
		state.room.game = m.view(1)

	func _advance() -> void:
		if m == null or state.room.is_empty():
			return
		var steps := 0
		while steps < 400:
			var decision := m.decision_state()
			if decision.mode == "finished" or int(decision.actor) != 0:
				return
			SgBotPlayer.step(m, m.bots[0])
			_refresh()
			steps += 1


func test_a_joined_table_is_played_through_the_client() -> void:
	var ref = _referee()
	var fake := FakeClient.new()
	fake.host_deck = ref._load_deck("white_knights.deck", "--deck-a").deck
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck").deck
	var outcome: Dictionary = ref._referee_table(fake, deck, {"wait": 60, "turns": 200}, null)
	assert_false(outcome.has("error"), str(outcome))
	assert_eq(outcome.reason, "concluded")
	assert_true(int(outcome.winner) in [0, 1])
	assert_eq(int(outcome.seat), 1)
	assert_eq(outcome.table, {"id": "t1", "name": "Wizard's table"})
	assert_eq(outcome.names, ["Host", "Pilot"])
	assert_true(int(outcome.turns) > 1)
	assert_eq(ref.refusals, 0)
	assert_true(ref.decisions > 10)
	assert_eq(fake.commands.slice(0, 3), ["join", "deck", "ready"])
	assert_eq(fake.commands.back(), "leave")
	assert_true(fake.state.room.is_empty(), "the seat was left")
	var hello: Dictionary = _lines[0]
	assert_eq(hello.type, "hello")
	assert_eq(hello.table.id, "t1")
	assert_eq(hello.table.name, "Wizard's table")
	assert_eq(int(hello.table.seat), 1)
	assert_eq(hello.seats[1].player, "agent")
	assert_eq(hello.seats[0].player, "table")
	assert_eq(hello.seats[1].deck, "Big Green")
	assert_eq(int(hello.seed), -1)
	for decision in _of("decision"):
		assert_eq(int(decision.seat), 1)
		assert_eq(int(decision.view.actor), 1)
	assert_null(ref._pump, "the pump stopped")
	assert_eq(_of("result").size(), 0, "_referee_table returns the record; _join emits it")


func test_a_closed_pipe_at_a_table_concedes_and_leaves() -> void:
	_pilot_on = false
	var ref = _referee()
	var fake := FakeClient.new()
	fake.host_deck = ref._load_deck("white_knights.deck", "--deck-a").deck
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck").deck
	var outcome: Dictionary = ref._referee_table(fake, deck, {"wait": 60, "turns": 200}, null)
	assert_eq(outcome.reason, "eof")
	assert_eq(int(outcome.winner), 0, "the pipe's seat conceded")
	assert_eq(fake.commands.slice(-2), ["concede", "leave"])
	assert_eq(fake.m.view(1).mode, "finished")


func test_a_table_that_never_opens_is_an_error_not_a_duel() -> void:
	var ref = _referee()
	var fake := FakeClient.new()
	fake.open = false
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck").deck
	var outcome: Dictionary = ref._referee_table(fake, deck, {"wait": 1, "turns": 200}, null)
	assert_true(outcome.has("error"))
	assert_true(String(outcome.error).begins_with("no open table appeared"), outcome.error)
	assert_eq(outcome.status, "Online")
	assert_eq(_lines.size(), 0, "nothing was said on the pipe")
	assert_eq(fake.commands, [])


# ------------------------------------------------------- the doors --

func test_the_doors_and_the_docs_know_the_referee() -> void:
	var main_script := FileAccess.get_file_as_string("res://game/main.gd")
	assert_true(main_script.contains('const REFEREE_FLAG := "--referee"'))
	assert_true(main_script.contains('_run_headless_tool(REFEREE_FLAG, "res://DeckLab/referee.gd")'))
	var door := FileAccess.get_file_as_string("res://shandalar.sh")
	assert_true(door.contains('referee) exec DeckLab/referee.sh "$@" ;;'))
	assert_true(door.contains("cards, referee, convert"), "the unknown-verb line lists it")
	assert_true(door.contains("./shandalar.sh referee ARGS..."))
	var launcher := FileAccess.get_file_as_string("res://DeckLab/referee.sh")
	assert_true(launcher.contains('-- --referee "$@"'))
	assert_false(launcher.contains("--script res://DeckLab/referee.gd"), "the referee has no --script door (the lobby classes name autoloads)")
	var release := FileAccess.get_file_as_string("res://build_release.sh")
	assert_true(release.contains('cat > "$STAGE/referee.sh"'))
	assert_true(release.contains('exec ./Shandalar.x86_64 --headless --no-header -- --referee "$@"'))
	assert_true(release.contains('referee) exec ./referee.sh "$@" ;;'))
	var package := FileAccess.get_file_as_string("res://tools/package_release.py")
	assert_true(package.contains('extra["referee.sh"]'))
	assert_true(package.contains('referee) exec ./referee.sh "$@" ;;'))
	var agents := FileAccess.get_file_as_string("res://AGENTS.md")
	assert_true(agents.contains("## The referee"))
	assert_true(agents.contains("--join"))
	assert_true(agents.contains("## The referee") and agents.contains("`refused` — `n`"))
	var readme := FileAccess.get_file_as_string("res://DeckLab/README.md")
	assert_true(readme.contains("referee.sh"))
	var header := FileAccess.get_file_as_string(REFEREE)
	assert_true(header.contains("extends SceneTree"))
	assert_false(header.contains("func _initialize"), "hosted by main.gd, never a main loop")
