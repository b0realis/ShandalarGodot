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
##
## THE KEPT GAME AND THE TABLE BY NAME (2026-10-03): `--listen` serves
## the lines on a loopback socket — the handshake file, the token, one
## client at a time, the replay (hello, resume, the awaited decision
## with the whole journal) to a client that comes back, the idle
## concession; `--table` finds an open LAN table's invitation through
## anything with SgLanDiscovery's face; `--log` with a joined table
## writes the journal the seat saw.
##
## THE TABLE THE REFEREE HOSTS (2026-10-03): `--host NAME` runs the
## game's own LAN host in the referee's process — the `table` line (the
## name, the access rule, the invitation, the advert), the chair held
## ready through the lobby's resets, a guest with the real client
## played to a result, the empty chair given up after `--wait`; and
## each wait has the whole `--wait` to itself, so a duel longer than
## that is not lost to "never answered" refusals.

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
		[["--join", "abc", "--table", "T", "--deck", "big_green.deck"], "option", "--table", "give one"],
		[["--table", "T"], "option", "--deck", "--deck is required"],
		[DECKS + ["--idle", "-1"], "option", "--idle", "non-negative integer"],
		[["--host", "Kitchen"], "option", "--deck", "--deck is required with --host"],
		[["--host", "Kitchen", "--deck", "big_green.deck", "--join", "abc"], "option", "--host", "does not go with"],
		[["--host", "Kitchen", "--deck", "big_green.deck", "--table", "T"], "option", "--host", "does not go with"],
		[["--host", "Kitchen", "--deck", "big_green.deck", "--access", "secret"], "option", "--access", "open or invitation"],
		[["--host", "Kitchen!", "--deck", "big_green.deck"], "option", "--host", "table name"],
		[["--host", "Kitchen", "--deck", "big_green.deck", "--address", "8.8.8.8"], "host", "--address", "private IPv4"],
		[["--host", "Kitchen", "--deck", "big_green.deck", "--address", "not-an-ip"], "host", "--address", "private IPv4"],
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
	assert_eq(one.error.detail.report.errors.size(), 0,
		"the check report's own errors are not grown by the unknown names (the problems list is a copy)")
	assert_eq(one.error.detail.problems.size(), one.error.detail.report.unknown.size())
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
		# THE HAND IS THE HAND (2026-10-02): as many rows as the seat's
		# hand count, every one of them the seat's own card in no zone
		# the boards list. The options reader used to append both boards
		# to the view's hand while it read them.
		var hand: Array = decision.view.hand
		assert_eq(hand.size(), int(decision.view.players[0].hand_count),
			"decision %d: the view's hand has hand_count rows" % n)
		var on_table := {}
		for player in decision.view.players:
			for zone in ["battlefield", "graveyard", "exile"]:
				for card in player.get(zone, []):
					on_table[card.id] = true
		for card in hand:
			assert_eq(int(card.controller), 0, "decision %d: %s in the hand is the seat's" % [n, card.name])
			assert_false(on_table.has(card.id), "decision %d: %s is in the hand, not on the table" % [n, card.name])
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
	## Milliseconds each poll takes while an answer is on its way.
	var slow_ms := 0
	## Lobby ops refused once each as "The room changed" (the host's
	## mark landing under them), then taken.
	var moved_under: Array = []
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
			if slow_ms > 0:
				OS.delay_msec(slow_ms)
			_busy -= 1
		_advance()

	func busy() -> bool:
		return _busy > 0

	func command(action: Dictionary) -> bool:
		commands.append(action.op)
		_busy = 1
		if moved_under.has(action.op):
			moved_under.erase(action.op)
			if not state.room.is_empty():
				state.room.revision = int(state.room.revision) + 1
			refused.emit("The room changed. Please try again.")
			return true
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


# ------------------------------------------------- the table by name --

## SgLanDiscovery's face, without the LAN: the adverts appear after a
## few pumps, so the search is seen to wait.
class FakeDiscovery:
	extends RefCounted
	var hosts: Dictionary = {}
	var adverts: Dictionary = {}
	var after := 3
	var pumps := 0
	var scans := 0
	var stops := 0

	func scan() -> Error:
		scans += 1
		return OK

	func pump() -> void:
		pumps += 1
		if pumps >= after:
			for key in adverts:
				hosts[key] = {"host": adverts[key], "seen": Time.get_ticks_msec()}

	func stop() -> void:
		stops += 1
		hosts.clear()


static func _advert(host_name: String, access: String, tables: Array) -> Dictionary:
	var advert := {"address": "192.168.1.9", "port": 17897, "name": host_name, "access": access, "tables": tables}
	if access == "open":
		advert["invitation"] = "sglan1:%s" % host_name
	return advert


static func _table(table_name: String, open: bool) -> Dictionary:
	return {"name": table_name, "decks": "own", "deck": "", "open": open}


func test_an_open_table_is_found_by_name_and_the_rest_are_named_back() -> void:
	var ref = _referee()
	var lan := FakeDiscovery.new()
	lan.adverts = {
		"192.168.1.9:17897": _advert("Wizard", "open", [_table("Wizard's table", true), _table("Full table", false)]),
		"192.168.1.9:17898": _advert("Sorcerer", "invitation", [_table("Private table", true)]),
	}
	var found: Dictionary = ref._find_table("Wizard's table", 5, lan)
	assert_eq(found, {"invitation": "sglan1:Wizard", "host": "Wizard"})
	assert_eq(lan.scans, 1)
	assert_eq(lan.stops, 1, "the search stops the discovery")
	assert_true(lan.pumps >= 3, "the adverts came after a few pumps")
	lan.hosts.clear()
	lan.pumps = 0
	var private: Dictionary = ref._find_table("Private table", 1, lan)
	assert_true(private.has("error"))
	assert_true(String(private.error).contains("hosted with an invitation"), private.error)
	assert_true(String(private.error).contains("--join"))
	assert_eq(Array(private.seen), ["Full table", "Private table", "Wizard's table"])
	lan.hosts.clear()
	lan.pumps = 0
	var full: Dictionary = ref._find_table("Full table", 1, lan)
	assert_true(String(full.error).contains("no free seat"), full.error)
	lan.hosts.clear()
	lan.pumps = 0
	var started := Time.get_ticks_msec()
	var absent: Dictionary = ref._find_table("Nobody's table", 1, lan)
	assert_true(Time.get_ticks_msec() - started >= 1000, "the search waited the whole second")
	assert_true(String(absent.error).begins_with("no open table called 'Nobody's table'"), absent.error)
	assert_true(String(absent.error).contains("saw: Full table, Private table, Wizard's table"), absent.error)
	assert_eq(lan.stops, 4)
	var empty := FakeDiscovery.new()
	var nothing: Dictionary = ref._find_table("Any", 0, empty)
	assert_true(String(nothing.error).ends_with("waited 0 s"), nothing.error)
	assert_eq(Array(nothing.seen), [])


func test_the_real_discovery_pumps_by_hand() -> void:
	var lan := SgLanDiscovery.new()
	assert_true(lan.has_method("pump"), "the referee drives it without a frame")
	lan.pump()
	assert_eq(lan.hosts.size(), 0, "idle until scanning or advertising")
	lan.free()
	var source := FileAccess.get_file_as_string("res://game/sgmanalink/lan_discovery.gd")
	assert_true(source.contains("func _process(_delta: float) -> void:\n\tpump()"), "the frame calls the same pump")


func test_a_joined_table_hands_back_the_journal_for_the_log() -> void:
	var ref = _referee()
	var fake := FakeClient.new()
	fake.host_deck = ref._load_deck("white_knights.deck", "--deck-a").deck
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck").deck
	var log_path := _scratch("referee_table.log")
	var outcome: Dictionary = ref._referee_table(fake, deck, {"wait": 60, "turns": 200, "log": log_path}, null)
	assert_false(outcome.has("error"), str(outcome))
	assert_true(outcome.journal.size() > 10, "the journal the seat saw")
	for line in outcome.journal:
		assert_true(line is String)
	assert_eq(_lines[0].log, log_path, "hello names the log")
	assert_eq(ref._write_log(log_path, outcome.journal), "")
	var written := FileAccess.get_file_as_string(log_path)
	assert_eq(written, "\n".join(PackedStringArray(outcome.journal)) + "\n")
	assert_true(String(ref._write_log("user://no_such_dir/x.log", ["a"])).begins_with("cannot write the log"))


## A fake client whose every answer takes a poll to arrive, with
## `--wait 1`: the duel outlasts the wait many times over, and no answer
## is ever "never answered" — each wait starts its own clock.
func test_each_wait_at_a_table_has_the_whole_wait_to_itself() -> void:
	var ref = _referee()
	var fake := FakeClient.new()
	fake.host_deck = ref._load_deck("white_knights.deck", "--deck-a").deck
	fake.slow_ms = 15
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck").deck
	var started := Time.get_ticks_msec()
	var outcome: Dictionary = ref._referee_table(fake, deck, {"wait": 1, "turns": 200}, null)
	assert_true(Time.get_ticks_msec() - started > 1000, "the duel outlasted --wait")
	assert_false(outcome.has("error"), str(outcome))
	assert_eq(outcome.reason, "concluded")
	assert_eq(ref.refusals, 0, "no answer was refused as never answered")
	assert_eq(_of("refused").size(), 0)


## The lobby refuses a command that carried an old revision and asks
## for it again — the host's ready mark lands under a guest's deck in
## the real lobby. A lobby command is sent again; the duel is unharmed.
func test_a_lobby_command_the_room_moved_under_is_sent_again() -> void:
	var ref = _referee()
	var fake := FakeClient.new()
	fake.host_deck = ref._load_deck("white_knights.deck", "--deck-a").deck
	fake.moved_under = ["join", "deck", "ready", "leave"]
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck").deck
	var outcome: Dictionary = ref._referee_table(fake, deck, {"wait": 5, "turns": 200}, null)
	assert_false(outcome.has("error"), str(outcome))
	assert_eq(outcome.reason, "concluded")
	assert_eq(fake.moved_under, [], "each refusal was spent")
	assert_eq(fake.commands.slice(0, 6), ["join", "join", "deck", "deck", "ready", "ready"])
	assert_eq(fake.commands.slice(-2), ["leave", "leave"])
	assert_eq(ref.refusals, 0, "a lobby retry is not a refused answer")
	assert_eq(_of("refused").size(), 0)


# ------------------------------------------- the table the referee hosts --

## The lobby client's face over the real one, the ops it was given
## written down: the host's own seat, watched.
class HostClient:
	extends RefCounted
	signal refused(reason: String)
	var inner: SgLocalClient
	var ops: Array = []
	var online: bool:
		get: return inner.online
	var status: String:
		get: return inner.status
	var command_error: String:
		get: return inner.command_error
	var state: Dictionary:
		get: return inner.state

	func _init(client: SgLocalClient) -> void:
		inner = client
		inner.refused.connect(func(reason: String) -> void: refused.emit(reason))

	func poll() -> void:
		inner.poll()

	func busy() -> bool:
		return inner.busy()

	func command(action: Dictionary) -> bool:
		ops.append(String(action.op))
		return inner.command(action)


## A person at the hosted table, played by the coverage pilot through
## the real lobby client, driven by hand from the referee's own tick:
## finds the table by name in the listing, sits down, brings a deck,
## marks ready, plays its seat, leaves when the duel is over.
class Guest:
	extends RefCounted
	var client: SgLocalClient
	var table_name: String
	var deck: Dictionary
	var pilot := Pilot.new()
	var joined := false
	var left := false
	var acted_revision := -1
	var ready_seen: Array = []

	func pump() -> void:
		client.poll()
		if not client.online or client.busy():
			return
		var room: Dictionary = client.state.room
		if room.is_empty():
			if joined:
				return
			for listed in client.state.rooms:
				if String(listed.name) == table_name and bool(listed.open):
					client.command({"op": "join", "room": listed.id})
			return
		joined = true
		var game: Dictionary = room.get("game", {})
		if game.is_empty():
			ready_seen.append(Array(room.ready))
			if room.deck.is_empty():
				client.command({"op": "deck", "name": deck.name, "cards": deck.cards, "sideboard": deck.sideboard})
			elif not bool(room.ready[1]):
				client.command({"op": "ready", "value": true})
			return
		if String(game.mode) == "finished":
			if not left:
				left = true
				client.command({"op": "leave"})
			return
		if int(game.actor) != 1 or int(room.revision) <= acted_revision:
			return
		acted_revision = int(room.revision)
		client.command(pilot.choose(game, 1))


func test_a_hosted_table_is_played_by_a_guest_to_a_result() -> void:
	var ref = _referee()
	var server := SgLocalServer.new()
	autofree(server)
	assert_eq(server.start_lan("127.0.0.1", 0, true, "Agent", 0, true), OK)
	assert_eq(server.discovery_error, OK)
	var own := SgLocalClient.new()
	autofree(own)
	assert_eq(own.connect_invitation(server.invitation(), "Agent"), OK)
	var host := HostClient.new(own)
	var guest := Guest.new()
	guest.client = SgLocalClient.new()
	autofree(guest.client)
	guest.table_name = "Kitchen"
	guest.deck = ref._load_deck("white_knights.deck", "--deck").deck
	assert_eq(guest.client.connect_invitation(server.invitation(), "Owner"), OK)
	var hosting := {"name": "Kitchen", "access": "open", "host": "Agent", "address": "127.0.0.1",
		"port": int(server.port), "invitation": server.invitation(), "discovery": true}
	var company := func() -> void:
		server.poll()
		server.discovery.pump()
		guest.pump()
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck").deck
	var outcome: Dictionary = ref._referee_table(host, deck, {"wait": 60, "turns": 200}, null, hosting, company)
	assert_false(outcome.has("error"), str(outcome))
	assert_eq(outcome.reason, "concluded")
	assert_true(int(outcome.winner) in [0, 1])
	assert_eq(int(outcome.seat), 0, "the host holds seat 0")
	assert_eq(outcome.table, {"id": "r1", "name": "Kitchen"})
	assert_true(String(outcome.names[0]).begins_with("Agent"), outcome.names[0])
	assert_true(String(outcome.names[1]).begins_with("Owner"), outcome.names[1])
	assert_true(int(outcome.turns) > 1)
	assert_eq(ref.refusals, 0)
	assert_true(ref.decisions > 10)
	assert_true(outcome.journal.size() > 10, "the journal the host's seat saw")
	# the table line came first, once the room existed, before hello
	var table: Dictionary = _lines[0]
	assert_eq(table.type, "table")
	assert_eq(table.id, "r1")
	assert_eq(table.name, "Kitchen")
	assert_eq(table.access, "open")
	assert_eq(table.host, "Agent")
	assert_eq(table.address, "127.0.0.1")
	assert_eq(int(table.port), int(server.port))
	assert_true(String(table.invitation).begins_with(SgLanInvite.PREFIX))
	assert_true(bool(table.discovery))
	assert_eq(_keys(table), _keys(ref.last_table), "last_table is the line")
	var hello: Dictionary = _lines[1]
	assert_eq(hello.type, "hello")
	assert_eq(hello.table.id, "r1")
	assert_eq(hello.table.name, "Kitchen")
	assert_eq(int(hello.table.seat), 0)
	assert_true(bool(hello.table.hosted))
	assert_eq(hello.seats[0].player, "agent")
	assert_eq(hello.seats[0].deck, "Big Green")
	assert_eq(hello.seats[1].player, "table")
	assert_eq(hello.seats[1].deck, "White Knights")
	for decision in _of("decision"):
		assert_eq(int(decision.seat), 0)
		assert_eq(int(decision.view.actor), 0)
	# the host opened the room, readied, and readied again once the
	# guest's arrival (and deck) cleared the marks — once or twice,
	# as the two landed
	assert_eq(host.ops.slice(0, 3), ["host", "deck", "ready"])
	assert_true(host.ops.count("ready") >= 2, str(host.ops))
	assert_eq(host.ops.back(), "leave")
	assert_true(guest.ready_seen.has([false, false]), "the guest saw the marks cleared")
	assert_true(guest.left)
	assert_null(ref._pump, "the pump stopped")
	assert_eq(_of("result").size(), 0, "_referee_table returns the record; _host emits it")
	server.stop()


## `_host` end to end on the loopback with nobody coming: the table
## line, then the empty chair given up after --wait, exit 2.
func test_hosting_an_empty_chair_gives_it_up_after_the_wait() -> void:
	var ref = _referee()
	ref.discovery_port = 0
	var code: int = ref._main(PackedStringArray(["--host", "Kitchen", "--deck", "big_green.deck",
		"--address", "127.0.0.1", "--port", "0", "--wait", "1", "--access", "invitation", "--name", "Ref"]))
	assert_eq(code, 2)
	assert_eq(_lines.size(), 2, str(_lines))
	var table: Dictionary = _lines[0]
	assert_eq(table.type, "table")
	assert_eq(table.id, "r1")
	assert_eq(table.name, "Kitchen")
	assert_eq(table.access, "invitation")
	assert_eq(table.host, "Ref")
	assert_eq(table.address, "127.0.0.1")
	assert_true(int(table.port) > 0)
	var invitation: Dictionary = SgLanInvite.parse(String(table.invitation))
	assert_eq(invitation.get("address", ""), "127.0.0.1")
	assert_eq(int(invitation.get("port", 0)), int(table.port))
	assert_true(bool(table.discovery))
	var error: Dictionary = _errors()[0]
	assert_eq(error.kind, "host")
	assert_eq(error.flag, "--host")
	assert_true(String(error.message).begins_with("no guest sat down at 'Kitchen' — waited 1 s"), error.message)
	assert_eq(ref.last_table.id, "r1")


## A kept hosted table: the client that knocks while the chair is held
## is seated then and there (not at hello, when the knock would be
## stale) and is told the table, then the refusal when the wait is up.
func test_a_kept_hosted_table_seats_its_client_while_the_chair_is_held() -> void:
	var path := _scratch("referee_host_keep.json")
	var ref = _referee()
	ref.discovery_port = 0
	var client := KeptClient.new()
	var knocked := {"at": -1}
	ref.writer = func(line: String) -> void:
		var record = JSON.parse_string(line)
		_lines.append(record)
		if record is Dictionary and record.get("type", "") == "table" and knocked.at < 0:
			var handshake: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			assert_true(client.open(int(handshake.port)))
			client.send(JSON.stringify({"token": handshake.token, "client": "test"}))
			knocked.at = Time.get_ticks_msec()
	var code: int = ref._main(PackedStringArray(["--host", "Kitchen", "--deck", "big_green.deck",
		"--address", "127.0.0.1", "--port", "0", "--wait", "1", "--listen", path]))
	assert_eq(code, 2)
	assert_true(knocked.at > 0, "the table line was written")
	client.wait_lines(3)
	assert_eq(client.lines.size(), 3, str(client.lines))
	assert_eq(client.lines[0].type, "table")
	assert_eq(client.lines[0].name, "Kitchen")
	assert_eq(client.lines[0].access, "open")
	assert_eq(client.lines[1].type, "resume")
	assert_false(bool(client.lines[1].awaiting))
	assert_eq(int(client.lines[1].decisions), 0)
	assert_true(client.lines[2].has("error"))
	assert_eq(client.lines[2].error.kind, "host")
	assert_eq(_of("table").size(), 1, "the transcript has the table line once")


# ------------------------------------------------------ the kept game --

## A client of the kept game's socket, held by the test: one peer, the
## lines it has read, the token it was given.
class KeptClient:
	extends RefCounted
	var peer := StreamPeerTCP.new()
	var buffer := ""
	var lines: Array = []
	var sent: Array = []
	var pumps := 0

	func open(port: int) -> bool:
		if peer.connect_to_host("127.0.0.1", port) != OK:
			return false
		var deadline := Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < deadline:
			peer.poll()
			if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				return true
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTING:
				return false
			OS.delay_msec(5)
		return false

	func send(text: String) -> void:
		sent.append(text)
		peer.put_data((text + "\n").to_utf8_buffer())

	func pump() -> void:
		pumps += 1
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		var pending := peer.get_available_bytes()
		if pending > 0:
			var chunk: Array = peer.get_data(pending)
			buffer += PackedByteArray(chunk[1]).get_string_from_utf8()
		while true:
			var cut := buffer.find("\n")
			if cut < 0:
				break
			lines.append(JSON.parse_string(buffer.substr(0, cut)))
			buffer = buffer.substr(cut + 1)

	## Pumps until [param count] lines have been read, or a second passed.
	func wait_lines(count: int) -> void:
		var deadline := Time.get_ticks_msec() + 1000
		while lines.size() < count and Time.get_ticks_msec() < deadline:
			pump()
			OS.delay_msec(5)

	func close() -> void:
		peer.disconnect_from_host()


func _handshake(ref, path: String) -> Dictionary:
	assert_eq(ref._listen_start(path, 0), "")
	assert_not_null(ref._server)
	assert_false(FileAccess.file_exists(path + ".part"), "the part was renamed")
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(_keys(record), ["pid", "port", "started", "token", "version"])
	assert_eq(int(record.pid), OS.get_process_id())
	assert_eq(record.version, LabConsole.version())
	assert_eq(int(record.port), ref._server.get_local_port())
	assert_true(int(record.port) > 0)
	assert_eq(String(record.token).length(), 32)
	return record


func test_a_kept_game_serves_its_lines_on_the_loopback() -> void:
	var path := _scratch("referee_keep.json")
	var ref = _referee()
	var record := _handshake(ref, path)
	ref.decisions = 7
	ref.last_hello = {"type": "hello", "tool": "referee", "seats": []}
	ref._journal_sent[0] = 1
	var view := {"mode": "priority", "actor": 0, "turn": 3, "step": "MAIN1",
		"journal": [{"serial": 1, "text": "turn 1", "turn": 1}, {"serial": 2, "text": "turn 3", "turn": 3}]}
	ref._decision(7, 0, "priority", view)
	assert_true(ref._awaiting)
	assert_eq(_lines.size(), 1, "the decision went to the writer")
	assert_eq(_lines[0].view.journal.size(), 1, "the pipe's decision carries the fresh entry only")
	# The first client: the token, then the replay — hello, resume, the
	# decision with BOTH journal entries — then its answer is the line read.
	var first := KeptClient.new()
	assert_true(first.open(int(record.port)))
	first.send(JSON.stringify({"token": record.token, "client": "test"}))
	var tick := func() -> void:
		first.pump()
		if first.lines.size() >= 3 and first.sent.size() == 1:
			first.send('{"op": "pass"}')
	assert_eq(ref._read_socket(tick), '{"op": "pass"}')
	assert_eq(first.lines.size(), 3)
	assert_eq(first.lines[0].type, "hello")
	assert_eq(first.lines[1].type, "resume")
	assert_eq(_keys(first.lines[1]), ["awaiting", "decisions", "finished", "n", "refusals", "type"])
	assert_eq(int(first.lines[1].decisions), 7)
	assert_eq(int(first.lines[1].n), 7)
	assert_true(bool(first.lines[1].awaiting))
	assert_false(bool(first.lines[1].finished))
	assert_eq(first.lines[2].type, "decision")
	assert_eq(int(first.lines[2].n), 7)
	assert_eq(first.lines[2].view.journal.size(), 2, "the replay carries the whole journal")
	assert_eq(first.lines[2].options.mode, "priority")
	assert_eq(_lines.size(), 1, "the replay is the socket's alone — the transcript has the decision once")
	# A line emitted now reaches both the writer and the seated client.
	ref._emit({"type": "refused", "n": 7})
	first.wait_lines(4)
	assert_eq(first.lines.size(), 4)
	assert_eq(first.lines[3].type, "refused")
	assert_eq(_lines.size(), 2)
	# A knock without the token is dropped; the first client keeps its seat.
	var impostor := KeptClient.new()
	assert_true(impostor.open(int(record.port)))
	impostor.send(JSON.stringify({"token": "nope", "client": "test"}))
	# (A lambda's captured int is a copy: the count lives on the client.)
	var later := func() -> void:
		first.pump()
		impostor.pump()
		if impostor.pumps == 30:
			first.send('{"op": "tap", "card": "c1"}')
	assert_eq(ref._read_socket(later), '{"op": "tap", "card": "c1"}')
	assert_null(ref._knock, "the impostor was dropped")
	assert_eq(impostor.lines.size(), 0, "and told nothing")
	# A second client with the token replaces the first and gets the replay.
	var second := KeptClient.new()
	assert_true(second.open(int(record.port)))
	second.send(JSON.stringify({"token": record.token, "client": "test"}))
	var again := func() -> void:
		second.pump()
		if second.lines.size() >= 3 and second.sent.size() == 1:
			second.send('{"op": "concede"}')
	assert_eq(ref._read_socket(again), '{"op": "concede"}')
	assert_eq(second.lines.size(), 3)
	assert_eq(second.lines[1].type, "resume")
	assert_eq(second.lines[2].view.journal.size(), 2)
	ref._emit({"type": "result"})
	second.wait_lines(4)
	assert_eq(second.lines.back().type, "result")
	first.wait_lines(5)
	assert_eq(first.lines.size(), 4, "the first client is off the socket — the result never reached it")
	# Nobody connected and a decision awaited: idle concedes after --idle.
	second.close()
	ref._idle_ms = 300
	var started := Time.get_ticks_msec()
	assert_null(ref._read_socket(func() -> void: pass))
	assert_eq(ref._eof_reason, "idle")
	assert_true(Time.get_ticks_msec() - started >= 300)
	assert_null(ref._peer)
	ref._listen_stop()
	assert_null(ref._server)
	assert_true(FileAccess.file_exists(path), "the handshake file is the registry's to remove")
	first.close()
	impostor.close()


func test_a_kept_duel_is_played_through_the_socket_to_a_result() -> void:
	# The whole duel over the socket: a pilot answers from the lines it
	# reads there, as the pipe's pilot does from `last_decision`.
	var path := _scratch("referee_keep_duel.json")
	var ref = _referee()
	ref.reader = func() -> Variant: return null
	var record := _handshake(ref, path)
	ref._idle_ms = 20000  # a bug ends the test as `idle`, not a hung suite
	var client := KeptClient.new()
	assert_true(client.open(int(record.port)))
	client.send(JSON.stringify({"token": record.token, "client": "test"}))
	var pilot := Pilot.new()
	var answered := {"lines": 0}
	# The socket is written before the writer is called: by the time the
	# collector sees a decision, the client can read it there and answer.
	ref.writer = func(line: String) -> void:
		_lines.append(JSON.parse_string(line))
		for _i in 200:
			client.pump()
			if not client.lines.is_empty() and client.lines.back().get("type", "") == "decision" and client.lines.size() > int(answered.lines):
				break
			OS.delay_msec(5)
		if not client.lines.is_empty() and client.lines.back().get("type", "") == "decision" and client.lines.size() > int(answered.lines):
			answered.lines = client.lines.size()
			var decision: Dictionary = client.lines.back()
			client.send(JSON.stringify(pilot.choose(decision.view, int(decision.seat))))
	var code: int = ref._play(ref._parse_args(PackedStringArray(DECKS + ["--seed", "7", "--turns", "40"])))
	assert_eq(code, 0)
	var result: Dictionary = _of("result")[0]
	assert_true(result.reason in ["concluded", "limit"], result.reason)
	assert_true(ref.decisions > 10)
	assert_eq(ref.refusals, 0)
	client.wait_lines(_lines.size() + 1)
	assert_eq(client.lines[0].type, "resume", "the client connected before hello: the resume came first")
	assert_eq(int(client.lines[0].decisions), 0)
	assert_eq(client.lines[1].type, "hello")
	assert_eq(client.lines.back().type, "result", "the result reached the socket")
	assert_eq(client.lines.size(), _lines.size() + 1, "every line but the resume is on the transcript too")
	ref._listen_stop()
	client.close()


func test_a_kept_duel_nobody_comes_back_for_is_conceded_idle() -> void:
	var path := _scratch("referee_keep_idle.json")
	var ref = _referee()
	ref.reader = func() -> Variant: return null
	assert_eq(ref._listen_start(path, 1), "")
	assert_eq(ref._idle_ms, 1000)
	var code: int = ref._play(ref._parse_args(PackedStringArray(DECKS + ["--seed", "7"])))
	assert_eq(code, 0)
	var result: Dictionary = _of("result")[0]
	assert_eq(result.reason, "idle")
	assert_eq(int(result.winner), 1, "the agent's seat conceded")
	assert_eq(_of("decision").size(), 1)
	assert_false(ref._awaiting)
	ref._listen_stop()


# ------------------------------------------------------- the doors --

## A kept game's socket reads BYTES and decodes whole lines (2026-10-03):
## each read used to be decoded on its own, so a character whose UTF-8
## bytes straddled two reads came out as two replacement marks.
func test_a_socket_line_split_inside_a_character_is_read_whole() -> void:
	var Referee: GDScript = load(REFEREE)
	var text := "{\"op\": \"pass\", \"name\": \"Lim-D\u00fbl\"}"
	var bytes := (text + "\n").to_utf8_buffer()
	var split := bytes.find(0xC3) + 1
	assert_gt(split, 0, "the fixture holds a two-byte character")
	var server := TCPServer.new()
	assert_eq(server.listen(0, "127.0.0.1"), OK)
	var client := StreamPeerTCP.new()
	assert_eq(client.connect_to_host("127.0.0.1", server.get_local_port()), OK)
	var deadline := Time.get_ticks_msec() + 5000
	while not server.is_connection_available() and Time.get_ticks_msec() < deadline:
		client.poll()
		OS.delay_msec(5)
	var peer := server.take_connection()
	assert_not_null(peer)
	while client.get_status() != StreamPeerTCP.STATUS_CONNECTED and Time.get_ticks_msec() < deadline:
		client.poll()
		OS.delay_msec(5)
	var buffer := PackedByteArray()
	client.put_data(bytes.slice(0, split))
	while buffer.size() < split and Time.get_ticks_msec() < deadline:
		buffer = Referee._drain(peer, buffer).bytes
		OS.delay_msec(5)
	assert_eq(buffer.size(), split, "the first read ends inside the character")
	assert_true(Referee._cut_line(buffer).is_empty(), "no line before its newline")
	client.put_data(bytes.slice(split))
	while buffer.size() < bytes.size() and Time.get_ticks_msec() < deadline:
		buffer = Referee._drain(peer, buffer).bytes
		OS.delay_msec(5)
	var cut: Dictionary = Referee._cut_line(buffer)
	assert_eq(String(cut.get("line", "")), text)
	assert_eq(PackedByteArray(cut.get("rest", PackedByteArray([1]))).size(), 0)
	client.disconnect_from_host()
	peer.disconnect_from_host()
	server.stop()


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
	assert_true(agents.contains("--host NAME"), "the hosted table is in the contract")
	assert_true(agents.contains("- `table` — only with `--host`"), "the table line is in the contract")
	assert_true(agents.contains("`referee_host {table, deck, access"), "the MCP tool is in the contract")
	assert_true(agents.contains("## The referee") and agents.contains("`refused` — `n`"))
	var readme := FileAccess.get_file_as_string("res://DeckLab/README.md")
	assert_true(readme.contains("referee.sh"))
	var header := FileAccess.get_file_as_string(REFEREE)
	assert_true(header.contains("extends SceneTree"))
	assert_false(header.contains("func _initialize"), "hosted by main.gd, never a main loop")
