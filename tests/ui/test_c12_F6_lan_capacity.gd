extends GutTest
## AN OPEN LAN HOST CANNOT BE FILLED BY IDLE SESSIONS (the bug campaign
## c12, h6-1), and Export MPN is offered only for a record the host really
## has (h5-5). Real TLS clients against a real LAN host on loopback.
##
## h6-1. The open host publishes its invitation to the whole LAN. A probe
## connected 87 idle clients from one address, which never joined a room:
## the host was full for good (connected sessions never expire), and the
## next real player's connection was dropped at the door, before a word
## could travel, so it read "Host unavailable… reconnecting" forever. Now:
##   * there are spare sockets, so a refused player reads "Host is full" at
##     the hello and stops retrying;
##   * one LAN address holds a few seats, and registers a few tournament
##     entrants (the host's own machine is not counted);
##   * when every session is taken, the connected lobby guest idle longest
##     gives way, and is told why.
## Loopback is the host's own machine; the tests that play a LAN
## neighbour empty [member SgLocalServer.own_addresses] first.

var server: RecordingServer
var clients: Array[SgLocalClient] = []
var scratch := ""


## A host that records its duels into a scratch folder — or, with
## [member broken], one whose recorder never started (an unwritable
## records folder): a record id, and no file.
class RecordingServer extends SgLocalServer:
	var folder := ""
	var broken := false
	func _create_match(decks: Array, names: Array, rules: Dictionary = {}) -> SgPracticeMatch:
		var result := super._create_match(decks, names, rules)
		result.public_archive = MpnArchive.new()
		if broken:
			result.public_archive.error = "Past Games: cannot open a recording file."
		else:
			result.public_archive.start(result.game, MpnArchive.metadata(result.game, "lan-host"), folder)
		return result


func before_each() -> void:
	clients.clear()
	scratch = "user://c12-f6-lan-" + Crypto.new().generate_random_bytes(6).hex_encode()
	server = RecordingServer.new()
	server.folder = scratch.path_join("records")
	add_child_autofree(server)
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)


func after_each() -> void:
	for room: Dictionary in server._rooms.values():
		if room.match != null and room.match.public_archive != null: room.match.public_archive.close()
	for client in clients: client.forget()
	server.stop()
	await get_tree().process_frame
	await get_tree().process_frame
	_remove_tree(ProjectSettings.globalize_path(scratch))


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _until(predicate: Callable, ms := 8000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	return predicate.call()


## A client that has started to connect with the open invitation.
func _start(name_value := "") -> SgLocalClient:
	var client := SgLocalClient.new()
	add_child_autofree(client)
	clients.append(client)
	assert_eq(client.connect_invitation(server.invitation(), name_value), OK)
	return client


## A client that is in: welcomed, with its first state.
func _join(name_value := "") -> SgLocalClient:
	var client := _start(name_value)
	assert_true(await _until(func() -> bool: return client.online), "joined: " + client.status)
	return client


## A client that the host turned away: it stopped retrying, and why is
## its status.
func _refused(name_value := "") -> SgLocalClient:
	var client := _start(name_value)
	await _until(func() -> bool: return not client._wanted)
	assert_false(client.online, "not let in")
	assert_false(client._wanted, "told, so it stopped retrying: " + client.status)
	return client


func _act(client: SgLocalClient, action: Dictionary) -> void:
	assert_true(client.command(action), client.command_error)
	await _until(func() -> bool: return not client.busy())
	for i in 3: await get_tree().process_frame


## A session that holds the host's place without a socket of this test:
## connected, in the lobby, from [param address], last heard from at
## [param last_command].
func _held_seat(address: String, last_command: int) -> int:
	var sid := server._next_session
	server._next_session += 1
	server._sessions[sid] = {"peer": 900000 + sid, "room": "", "seq": 0, "acks": {},
		"nickname": "Held", "disconnected_at": 0, "token_hash": str(sid).sha256_text(),
		"address": address, "last_command": last_command}
	return sid


# ------------------------------------------------------------- h6-1 --

func test_a_full_host_says_so_at_the_hello() -> void:
	# The probe's own shape: every session taken by idle guests on the
	# host's machine (never reclaimed — they are the organiser's), every
	# one with its socket.
	for i in SgLocalServer.MAX_SESSIONS:
		_start("Idle %d" % i)
	assert_true(await _until(func() -> bool:
		return clients.all(func(c: SgLocalClient) -> bool: return c.online), 30000),
		"%d idle guests in" % SgLocalServer.MAX_SESSIONS)
	assert_eq(server._sessions.size(), SgLocalServer.MAX_SESSIONS)
	var player := await _refused("Real player")
	assert_eq(player.status, SgLocalServer.HOST_FULL,
		"a spare socket carries the reason, not a silent drop read as 'Host unavailable'")
	assert_eq(server._sessions.size(), SgLocalServer.MAX_SESSIONS, "no session was made for it")


func test_one_lan_neighbour_holds_a_few_seats() -> void:
	server.own_addresses = PackedStringArray()
	var seats: Array[SgLocalClient] = []
	for i in SgLocalServer.SEATS_PER_ADDRESS:
		seats.append(await _join("Seat %d" % i))
	var one_more := await _refused("One more")
	assert_eq(one_more.status, SgLocalServer.ADDRESS_FULL % SgLocalServer.SEATS_PER_ADDRESS)
	assert_eq(server._sessions.size(), SgLocalServer.SEATS_PER_ADDRESS)
	# A seat given up is a seat free again.
	seats[0].forget()
	assert_true(await _until(func() -> bool: return server._sessions.size() == SgLocalServer.SEATS_PER_ADDRESS - 1))
	var next := await _join("Next")
	assert_true(next.online)


func test_the_host_machine_is_not_counted() -> void:
	# Loopback is the host's own machine: its lobby and windows are the
	# organiser's, and no cap applies.
	for i in SgLocalServer.SEATS_PER_ADDRESS + 2:
		await _join("Window %d" % i)
	assert_eq(server._sessions.size(), SgLocalServer.SEATS_PER_ADDRESS + 2)


func test_the_lobby_guest_idle_longest_gives_way_at_a_full_host() -> void:
	server.own_addresses = PackedStringArray()
	var idle := await _join("Idle")
	var seated := await _join("Seated")
	await _act(seated, {"op": "host", "name": "Busy table", "decks": "own", "deck": {}})
	var long_ago := Time.get_ticks_msec() - SgLocalServer.IDLE_RECLAIM_MS - 1000
	for sid: int in server._sessions:
		# Both last heard from long ago; only the one in the lobby may go.
		server._sessions[sid].last_command = long_ago
	# Everyone else on the LAN, connected, and busy a moment ago.
	var n := 0
	while server._sessions.size() < SgLocalServer.MAX_SESSIONS:
		_held_seat("10.0.%d.%d" % [n / 200, n % 200 + 1], Time.get_ticks_msec())
		n += 1
	var newcomer := await _join("Newcomer")
	assert_true(newcomer.online, "the newcomer is in")
	assert_true(await _until(func() -> bool: return not idle._wanted), "the idle guest is told")
	assert_eq(idle.status, SgLocalServer.IDLE_RECLAIMED)
	assert_true(seated.online, "a guest at a table never gives way")
	assert_eq(server._sessions.size(), SgLocalServer.MAX_SESSIONS)
	for sid: int in server._sessions.keys():
		if int(server._sessions[sid].peer) >= 900000: server._sessions.erase(sid)


func test_no_guest_gives_way_while_everyone_is_busy() -> void:
	server.own_addresses = PackedStringArray()
	var recent := await _join("Recent")
	var n := 0
	while server._sessions.size() < SgLocalServer.MAX_SESSIONS:
		_held_seat("10.1.%d.%d" % [n / 200, n % 200 + 1], Time.get_ticks_msec())
		n += 1
	var newcomer := await _refused("Newcomer")
	assert_eq(newcomer.status, SgLocalServer.HOST_FULL, "nobody was idle long enough to give way")
	assert_true(recent.online)
	for sid: int in server._sessions.keys():
		if int(server._sessions[sid].peer) >= 900000: server._sessions.erase(sid)


func test_one_computer_registers_a_few_tournament_entrants() -> void:
	server.own_addresses = PackedStringArray()
	var owner := await _join("Organiser")
	var options := {"name": "LAN Cup", "limit": 8, "wins": 1, "policy": "fixed",
		"decks": [{"name": "Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]}
	assert_eq(server.open_tournament(options, owner._resume, scratch), "")
	await _until(func() -> bool: return owner.state.has("tournament"))
	var event := server.tournament.event
	# One session after another from the same computer, each registering
	# and walking away: the entry stays when the session goes.
	for i in SgLocalServer.SEATS_PER_ADDRESS:
		var joiner := await _join("Joiner %d" % i)
		await _act(joiner, {"op": "t_join", "event": event.id})
		assert_eq(event.entrants.size(), i + 1, "entry %d taken" % (i + 1))
		joiner.forget()
		var sessions := 1
		assert_true(await _until(func() -> bool: return server._sessions.size() == sessions))
	var refusals: Array = []
	var last := await _join("Joiner again")
	last.refused.connect(func(reason: String) -> void: refusals.append(reason))
	await _act(last, {"op": "t_join", "event": event.id})
	assert_eq(event.entrants.size(), SgLocalServer.SEATS_PER_ADDRESS, "no fifth entrant from one computer")
	assert_eq(refusals, [SgLocalServer.ENTRIES_FULL % SgLocalServer.SEATS_PER_ADDRESS])


# ------------------------------------------------------------- h5-5 --

## Two guests at one table, the duel over (the first conceded).
func _finished_duel() -> Array[SgLocalClient]:
	var a := await _join("One")
	var b := await _join("Two")
	await _act(a, {"op": "host", "name": "Record table", "decks": "own", "deck": {}})
	await _act(b, {"op": "join", "room": a.state.room.id})
	await _act(a, {"op": "ready", "value": true})
	await _act(b, {"op": "ready", "value": true})
	await _until(func() -> bool: return not a.state.room.get("game", {}).is_empty())
	await _act(a, {"op": "concede"})
	await _until(func() -> bool: return String(b.state.room.get("game", {}).get("mode", "")) == "finished")
	return [a, b]


func test_a_recorded_duel_names_its_record() -> void:
	var pair := await _finished_duel()
	var room: Dictionary = server._rooms[pair[0].state.room.id]
	assert_eq(String(pair[0].state.room.get("mpn", "")), room.match.public_archive.record_id)
	var reply := server._mpn_reply(room.seats[0], {"room": room.id, "record": "", "offset": 0})
	assert_eq(reply.error, "")


func test_a_host_without_a_record_offers_none() -> void:
	server.broken = true
	var pair := await _finished_duel()
	var room: Dictionary = server._rooms[pair[0].state.room.id]
	assert_false(pair[0].state.room.has("mpn"), "a recorder that never started names no record")
	assert_false(pair[1].state.room.has("mpn"))
	var reply := server._mpn_reply(room.seats[0], {"room": room.id, "record": "", "offset": 0})
	assert_eq(reply.error, SgLocalServer.MPN_UNAVAILABLE)
	assert_false(reply.error.contains("before leaving"), "said to a player still at the table")


func test_a_record_whose_file_is_gone_is_not_offered() -> void:
	var pair := await _finished_duel()
	var room: Dictionary = server._rooms[pair[0].state.room.id]
	var archive: MpnArchive = room.match.public_archive
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive.path))
	assert_false(server._state(room.seats[0]).room.has("mpn"))


func test_export_mpn_is_offered_only_when_the_room_names_a_record() -> void:
	var view := SgDuelView.new()
	autofree(view)
	var finished := SgDuelProjection.new()
	finished.game_over = true
	view.game = finished
	view._room = {"id": "r1"}
	assert_false(view.mpn_available(), "over, but the host has no record to send")
	view._room = {"id": "r1", "mpn": "0123456789abcdef01234567"}
	assert_true(view.mpn_available())
	finished.game_over = false
	assert_false(view.mpn_available(), "not before the duel is over")
