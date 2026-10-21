extends GutTest
## Both seats download the same neutral archive over actual WebSockets;
## no room/record substitution, private view or file path is accepted.
var server: RecordingServer
var a: SgLocalClient
var b: SgLocalClient
var received_a: Array = []
var received_b: Array = []
var failures: Array = []

class RecordingServer extends SgLocalServer:
	var folder := "user://mpn-network-" + MpnArchive.new_id()
	func _create_match(decks: Array, names: Array, rules: Dictionary = {}) -> SgPracticeMatch:
		var result := super._create_match(decks, names, rules)
		result.public_archive = MpnArchive.new()
		result.public_archive.start(result.game, MpnArchive.metadata(result.game, "lan-host"), folder)
		return result

func before_each() -> void:
	server = RecordingServer.new()
	add_child_autofree(server)
	assert_eq(server.start_local(0), OK)
	a = SgLocalClient.new()
	b = SgLocalClient.new()
	add_child_autofree(a)
	add_child_autofree(b)
	received_a = []
	received_b = []
	failures = []
	a.mpn.completed.connect(func(bytes: PackedByteArray) -> void: received_a.append(bytes))
	b.mpn.completed.connect(func(bytes: PackedByteArray) -> void: received_b.append(bytes))
	a.mpn.failed.connect(func(message: String) -> void: failures.append(message))
	b.mpn.failed.connect(func(message: String) -> void: failures.append(message))

func after_each() -> void:
	for room in server._rooms.values():
		if room.match != null and room.match.public_archive != null: room.match.public_archive.close()
	a.forget()
	b.forget()
	server.stop()
	for path in MpnArchive.files(server.folder): DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(server.folder)

func _until(condition: Callable) -> void:
	for i in 900:
		if condition.call(): return
		await get_tree().process_frame
	assert_true(false, "network action exceeded the frame budget")

func _act(client: SgLocalClient, action: Dictionary) -> void:
	assert_true(client.command(action))
	await _until(func() -> bool: return not client.busy())

func _start() -> void:
	assert_eq(a.connect_local(server.port, server.access_code, "One"), OK)
	assert_eq(b.connect_local(server.port, server.access_code, "Two"), OK)
	await _until(func() -> bool: return a.online and b.online)
	await _act(a, {"op": "host", "name": "MPN table", "decks": "own", "deck": {}})
	await _act(b, {"op": "join", "room": a.state.room.id})
	await _act(a, {"op": "ready", "value": true})
	await _act(b, {"op": "ready", "value": true})
	await _until(func() -> bool: return not a.state.room.game.is_empty() and not b.state.room.game.is_empty())

func test_both_players_can_save_identical_multi_chunk_public_record() -> void:
	await _start()
	var room: Dictionary = server._rooms[a.state.room.id]
	# Public engine mutations create a record larger than a wire chunk.
	for i in 200:
		room.match.game.adjust_life(0, 1)
		room.match.public_archive.recorder.observe()
	await _act(a, {"op": "concede"})
	await _until(func() -> bool: return b.state.room.game.mode == "finished")
	assert_eq(a.state.room.mpn, b.state.room.mpn)
	a.mpn.start(a.state.room.id, a.state.room.mpn)
	b.mpn.start(b.state.room.id, b.state.room.mpn)
	await _until(func() -> bool: return not received_a.is_empty() and not received_b.is_empty())
	assert_eq(failures, [])
	assert_eq(received_a[0], received_b[0])
	assert_gt(received_a[0].size(), MpnDownload.CHUNK)
	var parsed := MpnCodec.parse(received_a[0].get_string_from_utf8())
	assert_eq(parsed.error, "")
	assert_true(parsed.finished)
	assert_eq(parsed.records.back().data.result, "0-1")
	assert_eq(MpnCodec.state_at(parsed.records, 0).objects, {}, "opening hands are not in the public record")
	for secret in [server.access_code, a._resume, b._resume]:
		assert_false(received_a[0].get_string_from_utf8().contains(secret))

func test_unfinished_foreign_and_stale_games_are_refused() -> void:
	await _start()
	var room: Dictionary = server._rooms[a.state.room.id]
	var request := {"room": room.id, "record": "", "offset": 0}
	assert_ne(server._mpn_reply(room.seats[0], request).error, "")
	await _act(a, {"op": "concede"})
	assert_eq(server._mpn_reply(room.seats[0], request).error, "")
	assert_ne(server._mpn_reply(9999, request).error, "")
	request.room = "another-table"
	assert_ne(server._mpn_reply(room.seats[0], request).error, "")
	request.room = room.id
	request.record = "different-record"
	assert_ne(server._mpn_reply(room.seats[0], request).error, "")
	request.record = ""
	request.offset = MpnCodec.MAX_BYTES
	assert_ne(server._mpn_reply(room.seats[0], request).error, "")

func test_request_and_response_limits_and_out_of_order_chunks() -> void:
	var request := {"v": SgProtocol.VERSION, "type": "mpn", "room": "r1", "record": "", "offset": 0}
	assert_true(SgProtocol.valid(request))
	request.offset = -1
	assert_false(SgProtocol.valid(request))
	request.offset = MpnCodec.MAX_BYTES + 1
	assert_false(SgProtocol.valid(request))
	var download := MpnDownload.new()
	var errors: Array = []
	download.failed.connect(func(message: String) -> void: errors.append(message))
	download.start("r1")
	assert_false(download.next(0).is_empty())
	download.receive({"type": "mpn", "record": "example", "offset": 1, "total": 2, "data": "YQ==", "error": ""})
	assert_false(download.active)
	assert_eq(errors.size(), 1)
	download.start("r1")
	download.next(0)
	download.receive({"type": "mpn", "record": "example", "offset": 0, "total": 2, "data": "!!!!", "error": ""})
	assert_false(download.active)
	assert_eq(errors.size(), 2)
	download.start("r1", "expected-record")
	download.next(0)
	download.receive({"type": "mpn", "record": "other-record", "offset": 0, "total": 1, "data": "YQ==", "error": ""})
	assert_false(download.active)
	assert_eq(errors.size(), 3)
	download.start("r1")
	download.next(0)
	download.next(15000)
	assert_false(download.active)
	assert_eq(errors.size(), 4)
