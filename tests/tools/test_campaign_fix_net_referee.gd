extends GutTest
## THE REFEREE AT A TABLE THAT BLINKS, AND THREE SMALLER HOLES (whole-game
## campaign, 2026-10-07 — fix-net; DeckLab/referee.gd).
##
## A LAN table is not whole while this seat's own client reconnects or the
## other seat is away. The referee ended the duel at the first offline tick
## (`offline`) and counted every answer sent meanwhile as the program's
## refusal — twenty, and the seat conceded (`refusals`): a person's brief
## drop lost the agent its game (w7-2). Pinned here with a table held in
## this process: the other seat away, this seat's own connection blinking,
## a client that stops retrying, a table that never comes back, and a seat
## the host gives up while the answer waits.
##
## Also: `--table NAME` sits at the table of that name, not at the host's
## first open table (w7-10); an unseeded duel's hello does not name the seed
## that deals both hands (w7-11); a kept game's client that goes away keeps
## the whole lines it sent — `referee_stop`'s concession (w7-9); and the
## hand's special-action discard (Circling Vultures) is a referee op and an
## option (w7 brief LOW).

const Pilot := preload("res://tests/support/sg_network_pilot.gd")
const REFEREE := "res://DeckLab/referee.gd"

var _lines: Array = []
var _pilots: Dictionary = {}
var _made: Array[String] = []


func before_each() -> void:
	_lines.clear()
	_pilots.clear()


func after_each() -> void:
	for path in _made:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made.clear()


func _referee():
	var ref = autofree(load(REFEREE).new())
	ref.writer = func(line: String) -> void: _lines.append(JSON.parse_string(line))
	ref.reader = func() -> Variant: return _answer(ref)
	return ref


func _answer(ref) -> Variant:
	if ref.last_decision.is_empty():
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


## A table held in this process with the lobby client's face (as
## tests/tools/test_referee_2026_09_27.gd's FakeClient): seat 0 a wizard,
## the referee joins as seat 1. On the game command numbered [member
## drop_at] the OTHER seat drops for [member away_polls] polls — that very
## answer is refused as the host refuses it (SEAT_AWAY), and so is every
## game action meanwhile; on the one numbered [member blip_at] THIS
## client's connection drops for [member offline_polls] polls (the command
## is never sent, NOT_CONNECTED), and with [member gives_up] it never
## comes back and stops retrying. [member abandon_after] polls into an
## absence the host gives the absent seat up (it concedes it).
class FlakyTable:
	extends RefCounted
	signal refused(reason: String)
	var online := false
	var status := "Connecting"
	var command_error := ""
	var state := {"rooms": [], "room": {}}
	var host_deck: Dictionary
	var commands: Array = []
	var game_commands := 0
	var drop_at := -1
	var away_polls := 0
	var blip_at := -1
	var offline_polls := 0
	var gives_up := false
	var abandon_after := -1
	var refused_away := 0
	var refused_offline := 0
	var m: SgPracticeMatch
	var _busy := 0
	var _polls := 0
	var _own: Dictionary
	var _away := 0
	var _offline := 0
	var _absent_polls := 0
	var _retrying := true

	func connecting() -> bool:
		return _retrying and not online

	func poll() -> void:
		_polls += 1
		if _polls >= 2 and status == "Connecting":
			online = true
			status = "Online"
			state.rooms = [{"id": "t1", "name": "Wizard's table", "host": "Host", "open": true,
				"decks": "own", "deck": ""}]
		if _offline > 0 or (not online and status != "Connecting"):
			_absent()
			if gives_up:
				_retrying = false
				status = "The host closed the connection."
				return
			_offline -= 1
			if _offline <= 0 and offline_polls >= 0:
				online = true
				status = "Online"
				_refresh()
			return
		if _away > 0:
			_absent()
			_away -= 1
			if _away == 0 and not state.room.is_empty():
				state.room.connected = [true, true]
				_refresh()
			return
		if _busy > 0:
			_busy -= 1
		_advance()

	func _absent() -> void:
		_absent_polls += 1
		if abandon_after >= 0 and _absent_polls == abandon_after and m != null and not m.game.game_over:
			# The host's grace ran out: it concedes the seat that is away.
			m.act(0 if _away > 0 else 1, {"op": "concede"})
			_away = 0
			if not state.room.is_empty():
				state.room.connected = [true, true]
			_refresh()

	func busy() -> bool:
		return _busy > 0

	func command(action: Dictionary) -> bool:
		if not online:
			command_error = SgLocalClient.NOT_CONNECTED
			refused_offline += 1
			return false
		command_error = ""
		match String(action.op):
			"join":
				commands.append(action.op)
				_busy = 1
				state.room = {"id": "t1", "name": "Wizard's table", "seat": 1, "names": ["Host", "Pilot"],
					"revision": 1, "ready": [false, false], "connected": [true, true], "game": {},
					"deck_names": ["Host deck", ""], "deck": "", "decks": "own", "fixed_deck": ""}
				return true
			"deck":
				commands.append(action.op)
				_busy = 1
				_own = {"name": action.name, "cards": action.cards, "sideboard": action.sideboard,
					"printings": action.get("printings", {})}
				state.room.deck_names[1] = action.name
				return true
			"ready":
				commands.append(action.op)
				_busy = 1
				m = SgPracticeMatch.new(5, [host_deck, _own], ["Host", "Pilot"])
				assert(m.set_bot(0, {"level": 3, "unfair": false, "pace_ms": 50}))
				_refresh()
				return true
			"leave":
				commands.append(action.op)
				_busy = 1
				state.room = {}
				return true
		game_commands += 1
		if game_commands == blip_at:
			online = false
			status = "Connection lost; reconnecting..."
			_offline = offline_polls
			command_error = SgLocalClient.NOT_CONNECTED
			refused_offline += 1
			return false
		commands.append(action.op)
		_busy = 1
		if game_commands == drop_at:
			_away = away_polls
			state.room.connected = [false, true]
			state.room.revision = int(state.room.revision) + 1
		if _away > 0 and action.op != "concede":
			refused_away += 1
			refused.emit(SgLocalServer.SEAT_AWAY)
			return true
		var refusal := m.act(1, action)
		if refusal != "":
			refused.emit(refusal)
		else:
			_refresh()
		return true

	func _refresh() -> void:
		if state.room.is_empty() or m == null:
			return
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


func _table(ref) -> FlakyTable:
	var table := FlakyTable.new()
	table.host_deck = ref._load_deck("white_knights.deck", "--deck-a").deck
	return table


func _play(ref, table: FlakyTable) -> Dictionary:
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck").deck
	return ref._referee_table(table, deck, {"wait": 60, "turns": 200}, null)


# ------------------------------------------- the table reconnecting --

func test_the_same_refusal_texts_as_the_host_and_the_client() -> void:
	var ref = _referee()
	assert_eq(ref.SEAT_AWAY, SgLocalServer.SEAT_AWAY, "the host's refusal while a seat is away")
	assert_eq(ref.NOT_CONNECTED, SgLocalClient.NOT_CONNECTED, "the client's while its link is down")
	assert_true(ref.RECONNECT_PATIENCE_MS > SgLocalServer.RECONNECT_GRACE_MS,
		"the referee outwaits the host's own grace for a disconnected seat")


func test_the_other_seat_away_is_waited_for_and_never_counted() -> void:
	var ref = _referee()
	var table := _table(ref)
	table.drop_at = 4
	table.away_polls = 40
	var outcome := _play(ref, table)
	assert_false(outcome.has("error"), str(outcome))
	assert_true(table.refused_away >= 1, "control: an answer met the table with the other seat away")
	assert_eq(String(outcome.reason), "concluded", "the duel was played to its end, not given up")
	assert_eq(ref.refusals, 0, "a refusal the absence caused is not the program's")
	assert_eq(_of("refused").size(), 0, "nor is it reported as one")
	assert_true(int(outcome.winner) in [0, 1])


func test_this_seat_s_own_connection_blinking_is_waited_for() -> void:
	var ref = _referee()
	var table := _table(ref)
	table.blip_at = 4
	table.offline_polls = 40
	var outcome := _play(ref, table)
	assert_false(outcome.has("error"), str(outcome))
	assert_true(table.refused_offline >= 1, "control: an answer met this client reconnecting")
	assert_ne(String(outcome.reason), "offline", "a transient reconnect is not the end of the duel")
	assert_eq(String(outcome.reason), "concluded")
	assert_eq(ref.refusals, 0)
	assert_eq(_of("refused").size(), 0)


func test_a_client_that_stops_retrying_ends_the_duel_offline_at_once() -> void:
	var ref = _referee()
	var table := _table(ref)
	table.blip_at = 4
	table.offline_polls = 1
	table.gives_up = true
	var started := Time.get_ticks_msec()
	var outcome := _play(ref, table)
	assert_false(outcome.has("error"), str(outcome))
	assert_eq(String(outcome.reason), "offline")
	assert_eq(ref.refusals, 0, "the seat was not conceded for refusals")
	assert_false(table.commands.has("concede"), "nothing could be sent, nothing was")
	assert_true(Time.get_ticks_msec() - started < 30000, "no patience is spent on a client that gave up")


func test_a_table_that_never_comes_back_is_given_up_after_the_patience() -> void:
	var ref = _referee()
	ref.reconnect_patience_ms = 400
	var table := _table(ref)
	table.blip_at = 4
	table.offline_polls = 1000000
	var outcome := _play(ref, table)
	assert_false(outcome.has("error"), str(outcome))
	assert_eq(String(outcome.reason), "offline")
	assert_eq(ref.refusals, 0)


func test_a_seat_the_host_gives_up_while_the_answer_waits_concludes_the_duel() -> void:
	var ref = _referee()
	var table := _table(ref)
	table.drop_at = 4
	table.away_polls = 1000000
	table.abandon_after = 30
	var outcome := _play(ref, table)
	assert_false(outcome.has("error"), str(outcome))
	assert_eq(String(outcome.reason), "concluded", "the host's concession of the absent seat ends it")
	assert_eq(int(outcome.winner), 1, "the seat that stayed wins")
	assert_eq(ref.refusals, 0)


# ------------------------------------------------- the table by name --

class TwoTables:
	extends RefCounted
	signal refused(reason: String)
	var online := false
	var status := "Connecting"
	var command_error := ""
	var state := {"rooms": [], "room": {}}
	var joined := ""

	func poll() -> void:
		if not online:
			online = true
			status = "Online"
			state.rooms = [
				{"id": "r1", "name": "Garage", "host": "Someone", "open": true, "decks": "own", "deck": "", "rules": ""},
				{"id": "r2", "name": "Kitchen", "host": "Owner", "open": true, "decks": "own", "deck": "", "rules": ""}]

	func busy() -> bool:
		return false

	func command(action: Dictionary) -> bool:
		if action.op == "join":
			joined = String(action.room)
			# A seat, then nothing more: the duel never starts here.
			state.room = {"id": action.room, "name": "?", "seat": 1, "names": ["Host", "Agent"],
				"revision": 1, "ready": [false, false], "connected": [true, true], "game": {},
				"deck_names": ["", ""], "deck": {}, "decks": "own", "fixed_deck": ""}
		elif action.op == "leave":
			state.room = {}
		return true


func test_the_table_named_is_the_table_joined() -> void:
	var ref = _referee()
	var deck: Dictionary = ref._load_deck("big_green.deck", "--deck").deck
	var named := TwoTables.new()
	ref._referee_table(named, deck, {"wait": 1, "turns": 200, "table": "Kitchen"}, null)
	assert_eq(named.joined, "r2", "--table Kitchen sits at Kitchen, not at the first open table")
	var invited := TwoTables.new()
	ref._referee_table(invited, deck, {"wait": 1, "turns": 200, "table": ""}, null)
	assert_eq(invited.joined, "r1", "an invitation names no table: the first open one")
	var missing := TwoTables.new()
	var outcome: Dictionary = ref._referee_table(missing, deck, {"wait": 1, "turns": 200, "table": "Attic"}, null)
	assert_eq(missing.joined, "", "no table of that name: no seat taken")
	assert_true(String(outcome.get("error", "")).begins_with("no open table appeared called 'Attic'"), str(outcome))


# ------------------------------------------------ the seed of a duel --

func test_an_unseeded_duel_names_its_seed_in_the_result_not_in_hello() -> void:
	var ref = _referee()
	ref.reader = func() -> Variant: return null   # the seat concedes at once
	assert_eq(ref._main(PackedStringArray(["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck"])), 0)
	var hello: Dictionary = _of("hello")[0]
	assert_eq(int(hello.seed), -1, "the seed that deals both hands is not told before play")
	var result: Dictionary = _of("result")[0]
	assert_true(int(result.seed) >= 0, "the result names it, for the replay")
	_lines.clear()
	ref = _referee()
	ref.reader = func() -> Variant: return null
	assert_eq(ref._main(PackedStringArray(["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck",
		"--seed", "7"])), 0)
	assert_eq(int(_of("hello")[0].seed), 7, "a seed the caller chose is echoed")
	assert_eq(int(_of("result")[0].seed), 7)


# ------------------------------------------- the kept game's leavings --

func test_a_line_sent_just_before_the_client_left_is_still_read() -> void:
	var path := "user://campaign_fix_net_kept.json"
	_made.append(path)
	var ref = _referee()
	assert_eq(ref._listen_start(path, 0), "")
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	ref.last_hello = {"type": "hello", "tool": "referee", "seats": []}
	var peer := StreamPeerTCP.new()
	assert_eq(peer.connect_to_host("127.0.0.1", int(record.port)), OK)
	var deadline := Time.get_ticks_msec() + 5000
	while peer.get_status() != StreamPeerTCP.STATUS_CONNECTED and Time.get_ticks_msec() < deadline:
		peer.poll()
		OS.delay_msec(5)
	peer.put_data((JSON.stringify({"token": record.token, "client": "test"}) + "\n").to_utf8_buffer())
	deadline = Time.get_ticks_msec() + 3000
	while ref._peer == null and Time.get_ticks_msec() < deadline:
		ref._serve()
		OS.delay_msec(10)
	assert_not_null(ref._peer, "the client was seated")
	# referee_stop with no decision pending: the concession, half a line
	# more, and the socket closes.
	peer.put_data('{"op": "concede"}\n{"op": "pa'.to_utf8_buffer())
	for i in 30:
		ref._serve()
		OS.delay_msec(10)
	peer.disconnect_from_host()
	deadline = Time.get_ticks_msec() + 3000
	while ref._peer != null and Time.get_ticks_msec() < deadline:
		ref._serve()
		OS.delay_msec(10)
	assert_null(ref._peer, "the client went away")
	ref._decision(9, 0, "priority", {"mode": "priority", "actor": 0, "turn": 4, "step": "MAIN1", "journal": []})
	ref._idle_ms = 500
	ref._idle_since = Time.get_ticks_msec()
	assert_eq(ref._read_socket(func() -> void: pass), '{"op": "concede"}', "the whole line is the next answer")
	assert_null(ref._read_socket(func() -> void: pass), "the cut-off line is not; the idle wait follows")
	assert_eq(ref._eof_reason, "idle")
	ref._listen_stop()
