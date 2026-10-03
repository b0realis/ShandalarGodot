extends GutTest
## Actual loopback/LAN WebSocket, TLS and UDP exchanges plus hostile DTO checks.

var server: SgLocalServer
var a: SgLocalClient
var b: SgLocalClient

class CountingMatch extends SgPracticeMatch:
	var views_built := 0
	func view(pid: int) -> Dictionary:
		views_built += 1
		return super.view(pid)


class SnapshotGateServer extends SgLocalServer:
	var hold_states := false
	var held: Dictionary = {}
	func _send(id: int, message: Dictionary) -> void:
		if hold_states and message.type == "state":
			held[id] = message.duplicate(true)
			return
		super._send(id, message)
	func release_states() -> void:
		hold_states = false
		for id in held: _send(id, held[id])
		held.clear()


func before_each() -> void:
	server = SgLocalServer.new()
	add_child_autofree(server)
	assert_eq(server.start_local(0), OK)
	a = SgLocalClient.new()
	b = SgLocalClient.new()
	add_child_autofree(a)
	add_child_autofree(b)


func after_each() -> void:
	a.forget()
	b.forget()
	server.stop()


func _until(predicate: Callable, frames := 400) -> bool:
	for i in frames:
		if predicate.call():
			return true
		await get_tree().process_frame
	assert_true(false, "network operation did not finish within its frame budget")
	return false


func _pair() -> void:
	if server.lan_address.is_empty():
		assert_eq(a.connect_local(server.port, server.access_code), OK)
		assert_eq(b.connect_local(server.port, server.access_code), OK)
	else:
		assert_eq(a.connect_invitation(server.invitation()), OK)
		assert_eq(b.connect_invitation(server.invitation()), OK)
	await _until(func() -> bool: return a.online and b.online)


func _act(client: SgLocalClient, action: Dictionary) -> bool:
	var accepted := client.command(action)
	assert_true(accepted, "command accepted by client: " + str(action))
	if not accepted:
		return false
	if not await _until(func() -> bool: return not client.busy()):
		return false
	for i in 3:
		await get_tree().process_frame
	return true


func _start_duel() -> void:
	await _pair()
	await _act(a, {"op": "host", "name": "Practice room", "decks": "own", "deck": {}})
	await _act(b, {"op": "join", "room": a.state.room.id})
	await _act(a, {"op": "ready", "value": true})
	await _act(b, {"op": "ready", "value": true})
	await _until(func() -> bool: return not a.state.room.game.is_empty() \
		and not b.state.room.game.is_empty())


func test_browser_host_join_ready_and_seat_filtered_duel() -> void:
	await _start_duel()
	assert_eq(int(a.state.room.seat), 0)
	assert_eq(int(b.state.room.seat), 1)
	assert_eq(a.state.rooms.size(), 1)
	assert_false(a.state.rooms[0].open)
	assert_eq(a.state.room.game.hand.size(), 7)
	assert_eq(b.state.room.game.hand.size(), 7)
	assert_false(a.state.room.game.players[1].has("hand"))
	assert_false(b.state.room.game.players[0].has("hand"))
	assert_false(JSON.stringify(a.state).contains(server.access_code))
	assert_false(JSON.stringify(a.state).contains(b._resume))
	assert_false(JSON.stringify(a.state).contains("seed"))
	assert_eq(a.state.room.deck_names, ["Forest practice", "Forest practice"])
	assert_ne(a._resume, b._resume)
	var actor: SgLocalClient = a if int(a.state.room.game.actor) == 0 else b
	var other: SgLocalClient = b if actor == a else a
	await _act(actor, {"op": "keep"})
	await _act(other, {"op": "keep"})
	assert_eq(a.state.room.game.mode, "priority")


func test_encrypted_full_decks_are_private_and_changes_reset_readiness() -> void:
	server.stop()
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)
	await _pair()
	await _act(a, {"op": "host", "name": "Full pool", "decks": "own", "deck": {}})
	await _act(b, {"op": "join", "room": a.state.room.id})
	await _act(a, {"op": "deck", "name": "Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": ["Terror"]})
	assert_eq(a.state.room.deck.cards.size(), 40)
	assert_eq(a.state.room.deck.sideboard, ["Terror"])
	assert_true(b.state.room.deck.is_empty())
	assert_false(SgProtocol.encode(b.state).contains("Savannah Lions"))
	await _act(a, {"op": "ready", "value": true})
	await _act(b, {"op": "deck", "name": "Raiders", "cards": Array(StarterDecks.BLACK_RED_RAIDERS), "sideboard": []})
	assert_eq(a.state.room.ready, [false, false])
	assert_eq(a.state.room.deck_names, ["Knights", "Raiders"])
	assert_false(SgProtocol.encode(a.state).contains("Hypnotic Specter"))
	var revision: int = int(b.state.room.revision)
	var bad: Array = StarterDecks.BLACK_RED_RAIDERS.duplicate()
	bad[0] = "unimplemented card"
	await _act(b, {"op": "deck", "name": "Bad deck", "cards": bad, "sideboard": []})
	assert_eq(int(b.state.room.revision), revision)
	assert_eq(b.state.room.deck.name, "Raiders")
	await _act(a, {"op": "ready", "value": true})
	await _act(b, {"op": "ready", "value": true})
	await _until(func() -> bool: return not a.state.room.game.is_empty())
	assert_true(SgViewProtocol.room(a.state.room))
	assert_true(SgViewProtocol.room(b.state.room))
	assert_eq(a.state.room.game.hand.size(), 7)
	assert_eq(a.state.room.game.players[1].hand_count, 7.0)
	for card in a.state.room.game.hand: assert_has(StarterDecks.WHITE_KNIGHTS, card.name)
	for card in b.state.room.game.hand: assert_has(StarterDecks.BLACK_RED_RAIDERS, card.name)
	var owner_deck: Dictionary = b.state.room.deck.duplicate(true)
	b._socket.close()
	assert_true(await _until(func() -> bool: return not b.online))
	assert_true(await _until(func() -> bool: return b.online and not b.state.room.game.is_empty()))
	assert_eq(b.state.room.deck, owner_deck)
	await _act(a, {"op": "concede"})
	assert_eq(int(a.state.room.game.winner), 1)
	assert_eq(int(b.state.room.game.winner), 1)
	await _act(a, {"op": "leave"})
	await _act(b, {"op": "leave"})
	assert_eq(server._rooms.size(), 0)


func test_duplicate_host_and_concede_are_not_executed_twice() -> void:
	await _pair()
	assert_true(a.command({"op": "host", "name": "One room", "decks": "own", "deck": {}}))
	var duplicate := a._pending.duplicate(true)
	await _until(func() -> bool: return not a.busy())
	a._socket.send_text(JSON.stringify(duplicate))
	for i in 12:
		await get_tree().process_frame
	assert_eq(server._rooms.size(), 1)
	assert_eq(server._next_room, 2)
	await _act(b, {"op": "join", "room": a.state.room.id})
	await _act(a, {"op": "ready", "value": true})
	await _act(b, {"op": "ready", "value": true})
	assert_true(a.command({"op": "concede"}))
	duplicate = a._pending.duplicate(true)
	await _until(func() -> bool: return not a.busy())
	var revision := int(server._rooms[a.state.room.id].revision)
	a._socket.send_text(JSON.stringify(duplicate))
	for i in 12:
		await get_tree().process_frame
	assert_eq(server._rooms[a.state.room.id].revision, revision)
	assert_eq(int(a.state.room.game.winner), 1)


func test_lost_ack_reconnect_resumes_same_seat_and_retries_same_command() -> void:
	await _start_duel()
	var resume := a._resume
	var room_id := String(a.state.room.id)
	# Send but prevent the client from consuming the response before disconnection.
	a.set_process(false)
	assert_true(a.command({"op": "concede"}))
	await _until(func() -> bool: return server._rooms[room_id].match.game.game_over)
	a._socket.close(-1)
	a._retry_at = 0
	a.set_process(true)
	await _until(func() -> bool: return a.online and not a.busy())
	assert_eq(a._resume, resume)
	assert_eq(a.state.room.id, room_id)
	assert_eq(int(a.state.room.seat), 0)
	assert_eq(int(a.state.room.game.winner), 1)
	assert_eq(server._sessions.size(), 2, "reconnect did not create another identity")


func test_outsider_and_wrong_room_cannot_modify_a_match() -> void:
	# A stale revision refuses an ordinary move and lets a concession
	# through; that pair is pinned below. Here the room's NAME is the gate:
	# a stranger outside it and a seat naming another room are both refused,
	# concession included.
	await _start_duel()
	var room_id := String(a.state.room.id)
	var stranger := SgLocalClient.new()
	add_child_autofree(stranger)
	assert_eq(stranger.connect_local(server.port, server.access_code), OK)
	await _until(func() -> bool: return stranger.online)
	await _act(stranger, {"op": "join", "room": room_id})
	assert_true(stranger.state.room.is_empty())
	await _act(stranger, {"op": "concede"})
	assert_false(server._rooms[room_id].match.game.game_over)
	var revision := int(server._rooms[room_id].revision)
	a.state.room.id = "r999"
	await _act(a, {"op": "concede"})
	assert_eq(server._rooms[room_id].revision, revision)
	assert_false(server._rooms[room_id].match.game.game_over, "a command names its room, not just its revision")
	stranger.forget()


func test_invalid_access_or_resume_never_creates_a_session() -> void:
	assert_eq(a.connect_local(server.port, "0".repeat(64)), OK)
	for i in 30:
		await get_tree().process_frame
	assert_false(a.online)
	assert_eq(server._sessions.size(), 0)
	assert_false(a._wanted, "invalid invitations are not retried forever")
	assert_string_contains(a.status, "Invalid invitation")
	a.forget()
	assert_eq(a.connect_local(server.port, server.access_code), OK)
	a._resume = "0".repeat(64)
	for i in 30:
		await get_tree().process_frame
	assert_false(a.online)
	assert_eq(server._sessions.size(), 0)
	assert_false(a._wanted)
	assert_string_contains(a.status, "expired")


func test_departing_guests_do_not_exhaust_host_capacity() -> void:
	assert_eq(a.connect_local(server.port, server.access_code), OK)
	await _until(func() -> bool: return a.online)
	await _act(a, {"op": "host", "name": "Stable host", "decks": "own", "deck": {}})
	for i in SgLocalServer.MAX_SESSIONS + 4:
		assert_eq(b.connect_local(server.port, server.access_code), OK)
		await _until(func() -> bool: return b.online)
		b.forget()
		await _until(func() -> bool: return server._sessions.size() == 1)
	assert_eq(server._tokens.size(), 1)
	assert_true(a.online)
	assert_eq(b.connect_local(server.port, server.access_code), OK)
	await _until(func() -> bool: return b.online)


func test_expired_seat_is_reclaimed_and_retry_explains_the_failure() -> void:
	await _start_duel()
	var room_id: String = a.state.room.id
	var sid := int(server._rooms[room_id].seats[1])
	b.set_process(false)
	b._socket.close(-1)
	await _until(func() -> bool: return not server._connected(sid))
	var disconnected_at := int(server._sessions[sid].disconnected_at)
	server._expire_disconnected(disconnected_at + SgLocalServer.RECONNECT_GRACE_MS - 1)
	assert_true(server._sessions.has(sid), "running seat survives its grace interval")
	server._expire_disconnected(disconnected_at + SgLocalServer.RECONNECT_GRACE_MS + 1)
	assert_false(server._sessions.has(sid))
	assert_true(server._rooms[room_id].match.game.game_over)
	b.set_process(true)
	b.reconnect()
	await _until(func() -> bool: return not b._wanted)
	assert_string_contains(b.status, "expired")
	await _act(a, {"op": "leave"})
	assert_true(server._rooms.is_empty())


func test_host_can_remove_only_a_disconnected_waiting_guest() -> void:
	await _pair()
	await _act(a, {"op": "host", "name": "Waiting room", "decks": "own", "deck": {}})
	await _act(b, {"op": "join", "room": a.state.room.id})
	await _act(a, {"op": "remove_guest"})
	assert_true(server._connected(int(server._rooms[a.state.room.id].seats[1])))
	b.set_process(false)
	b._socket.close(-1)
	await _until(func() -> bool: return a.state.room.connected == [true, false])
	await _act(a, {"op": "remove_guest"})
	assert_eq(a.state.room.names[1], "Empty seat")
	assert_eq(server._sessions.size(), 1)
	b.set_process(true)


func test_incompatible_build_fails_before_allocating_a_seat() -> void:
	assert_eq(a.connect_local(server.port, server.access_code), OK)
	a.build_fingerprint = "0".repeat(64)
	await _until(func() -> bool: return not a._wanted)
	assert_string_contains(a.status, "card catalogue differs", "equal stamps, different digest: modified files")
	assert_false(a.online)
	assert_true(server._sessions.is_empty())
	assert_true(server._tokens.is_empty())
	# The refusal names what differs, read from the guest's side.
	assert_eq(b.connect_local(server.port, server.access_code), OK)
	b.build_fingerprint = "0".repeat(64)
	b.build_stamp = {"game": "0.31.0", "rules": SgCompatibility.RULES_REVISION, "packs": SgCompatibility.enabled_packs()}
	await _until(func() -> bool: return not b._wanted)
	assert_string_contains(b.status, "The host runs Shandalar %s; you run 0.31.0" % SgCompatibility.game_version())
	assert_true(server._sessions.is_empty())
	var c := SgLocalClient.new()
	add_child_autofree(c)
	assert_eq(c.connect_local(server.port, server.access_code), OK)
	c.build_fingerprint = "0".repeat(64)
	c.build_stamp = {"game": SgCompatibility.game_version(), "rules": SgCompatibility.RULES_REVISION,
		"packs": SgCompatibility.enabled_packs() + ["pack-9"]}
	await _until(func() -> bool: return not c._wanted)
	assert_string_contains(c.status, "You have Pack 9 enabled; the host does not")
	assert_true(server._sessions.is_empty())


## A guest of another build, exactly as its own code connects: its version's
## subprotocol, and on opening the hello. Returns what the host answered.
func _foreign_hello(subprotocol: String, hello: Dictionary) -> Array:
	var socket := WebSocketPeer.new()
	socket.supported_protocols = PackedStringArray([subprotocol])
	assert_eq(socket.connect_to_url("ws://127.0.0.1:%d" % server.port), OK)
	var answers: Array = []
	var sent := false
	for i in 400:
		socket.poll()
		var state := socket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN and not sent:
			sent = true
			socket.send_text(SgProtocol.encode(hello))
		while socket.get_available_packet_count() > 0:
			answers.append(SgProtocol.decode_payload(socket.get_packet()))
		if state == WebSocketPeer.STATE_CLOSED or not answers.is_empty(): break
		await get_tree().process_frame
	socket.close()
	return answers


## THE OTHER VERSION HEARS WHY (bug pass 2026-10-03). Every protocol bump
## renames the WebSocket subprotocol, so a guest one version behind failed
## the handshake itself and retried forever under "Host unavailable"; the
## readable build comparison after the hello could never run. The host now
## completes the older handshake to say which versions differ, in the fatal
## shape every client since protocol 6 reads, and never seats it.
func test_a_guest_of_another_protocol_version_hears_which_versions_differ() -> void:
	var older := SgProtocol.VERSION - 1
	var stamp := SgCompatibility.stamp()
	stamp.game = "0.49.0"
	var hello := {"v": older, "type": "hello", "access": server.access_code, "resume": "", "nickname": "",
		"build": "0".repeat(64), "stamp": stamp}
	var expected := "The host runs Shandalar %s (SGManalink protocol %d); you run Shandalar 0.49.0 (protocol %d). Both players need the same version." \
		% [SgCompatibility.game_version(), SgProtocol.VERSION, older]
	var answers := await _foreign_hello("sgmanalink-local-v%d" % older, hello)
	assert_eq(answers.size(), 1, "the older handshake completes and the guest hears a reason")
	if answers.is_empty(): return
	assert_true(SgViewProtocol.valid(answers[0]) and SgProtocol.exact(answers[0], ["type", "error"]))
	assert_eq(String(answers[0].get("error")), expected)
	# Its own `v` on this version's subprotocol: named the same way.
	answers = await _foreign_hello(SgProtocol.SUBPROTOCOL, hello)
	assert_eq(String(answers[0].get("error", "")) if not answers.is_empty() else "", expected)
	# A hello from before the readable stamp still hears the protocols.
	hello.erase("stamp")
	hello.erase("build")
	answers = await _foreign_hello("sgmanalink-local-v%d" % older, hello)
	assert_eq(String(answers[0].get("error", "")) if not answers.is_empty() else "",
		"The host runs Shandalar %s (SGManalink protocol %d); your game uses protocol %d. Both players need the same version." \
		% [SgCompatibility.game_version(), SgProtocol.VERSION, older])
	# Without the access code, nothing about this host but the refusal.
	hello.access = "0".repeat(64)
	answers = await _foreign_hello("sgmanalink-local-v%d" % older, hello)
	assert_string_contains(String(answers[0].get("error", "")) if not answers.is_empty() else "", "Invalid invitation")
	# Another version's handshake never seats a guest, whatever its hello claims.
	answers = await _foreign_hello("sgmanalink-local-v%d" % older, {"v": SgProtocol.VERSION, "type": "hello",
		"access": server.access_code, "resume": "", "nickname": "", "build": SgCompatibility.fingerprint(),
		"stamp": SgCompatibility.stamp()})
	assert_string_contains(String(answers[0].get("error", "")) if not answers.is_empty() else "", "protocol %d" % older)
	assert_true(server._sessions.is_empty())
	assert_true(server._tokens.is_empty())


## A stand-in for a host of another build: it completes only its own
## version's handshake and, with [param hang_up], closes on the first packet.
## Polls until [param done] holds; returns the connections it accepted.
func _foreign_host(subprotocol: String, client: SgLocalClient, done: Callable, hang_up := false) -> int:
	var listener := TCPServer.new()
	assert_eq(listener.listen(0, "127.0.0.1"), OK)
	assert_eq(client.connect_local(listener.get_local_port(), "0".repeat(64)), OK)
	var peers: Array[WebSocketPeer] = []
	for i in 600:
		if listener.is_connection_available():
			var peer := WebSocketPeer.new()
			peer.supported_protocols = PackedStringArray([subprotocol])
			peer.accept_stream(listener.take_connection())
			peers.append(peer)
		for peer in peers:
			peer.poll()
			if hang_up and peer.get_available_packet_count() > 0:
				peer.get_packet()
				peer.close(-1)
		# Retry at once: the backoff is not under test.
		if client._socket != null and client._socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			client._retry_at = 0
		if done.call(): break
		await get_tree().process_frame
	listener.stop()
	return peers.size()


func test_a_host_of_another_protocol_version_is_named_and_not_retried() -> void:
	# This client offers every earlier subprotocol beside its own, so an
	# older host completes the handshake by choosing its own — which names it.
	var older := SgProtocol.VERSION - 1
	var attempts := await _foreign_host("sgmanalink-local-v%d" % older, a, func() -> bool: return not a._wanted)
	assert_false(a._wanted, "a different version is not retried")
	assert_eq(attempts, 1)
	assert_eq(a.status, "The host runs an older version of Shandalar (SGManalink protocol %d; you run %d). Both players need the same version." \
		% [older, SgProtocol.VERSION])
	assert_eq(SgProtocol.subprotocols()[0], SgProtocol.SUBPROTOCOL, "its own version first, so a current host picks it")


func test_a_host_that_hangs_up_on_the_hello_is_not_retried_forever() -> void:
	# A host that closes on the hello without a word — an earlier build
	# that cannot read it — is given a few attempts, then named a suspect.
	var attempts := await _foreign_host(SgProtocol.SUBPROTOCOL, a, func() -> bool: return not a._wanted, true)
	assert_false(a._wanted)
	assert_eq(attempts, SgLocalClient.UNANSWERED_LIMIT)
	assert_string_contains(a.status, "may run a different version of Shandalar")
	# A host that is simply not there is still retried (unchanged).
	var listener := TCPServer.new()
	assert_eq(listener.listen(0, "127.0.0.1"), OK)
	var port := listener.get_local_port()
	listener.stop()
	a.forget()
	assert_eq(a.connect_local(port, "0".repeat(64)), OK)
	for i in 60: await get_tree().process_frame
	assert_true(a._wanted, "an unreachable host is retried")


## An invitation from another version cannot be parsed, and used to be
## refused as incomplete; the lobby now says which versions differ.
func test_an_invitation_from_another_version_names_both_versions() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	for i in 4: await get_tree().process_frame
	var older := SgProtocol.VERSION - 1
	lobby._code.text = SgLanInvite.PREFIX + Marshalls.raw_to_base64(JSON.stringify({"v": older,
		"address": "192.168.1.2", "port": 17897, "access": "a".repeat(64),
		"certificate": "-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n"}).to_utf8_buffer())
	lobby._connect_local()
	assert_eq(lobby._notice.text, "This invitation is from an older version of Shandalar (SGManalink protocol %d; you run %d). Both players need the same version." \
		% [older, SgProtocol.VERSION])
	assert_false(lobby.client.connecting())


func test_reconnect_waits_for_fresh_snapshot_before_enabling_input() -> void:
	server.stop()
	var gate := SnapshotGateServer.new()
	add_child_autofree(gate)
	server = gate
	assert_eq(server.start_local(0), OK)
	await _start_duel()
	var revision := int(a.state.room.revision)
	gate.hold_states = true
	a.reconnect()
	await _until(func() -> bool: return a._welcomed)
	assert_false(a.online, "welcome alone must not expose the stale room revision")
	assert_false(a.command({"op":"concede"}), "no new action before the fresh snapshot")
	assert_eq(int(a.state.room.revision), revision)
	assert_string_contains(a.status, "Synchronizing")
	gate.release_states()
	await _until(func() -> bool: return a.online)
	assert_gt(int(a.state.room.revision), revision)
	assert_eq(int(a.state.room.revision), int(server._rooms[a.state.room.id].revision))


func test_unrelated_and_refused_commands_reuse_the_cached_room_views() -> void:
	await _start_duel()
	var match_state := CountingMatch.new(42)
	server._rooms[a.state.room.id].match = match_state
	server._publish()
	for i in 4: await get_tree().process_frame
	assert_eq(match_state.views_built, 2)
	var visitor := SgLocalClient.new()
	add_child_autofree(visitor)
	assert_eq(visitor.connect_local(server.port, server.access_code), OK)
	await _until(func() -> bool: return visitor.online)
	await _act(visitor, {"op": "host", "name": "Other room", "decks": "own", "deck": {}})
	await _act(visitor, {"op":"concede"})
	assert_eq(match_state.views_built, 2, "unrelated room does not rebuild either duel view")
	a.state.room.revision = 0
	await _act(a, {"op":"pass"})
	assert_eq(match_state.views_built, 2, "stale refusal refreshes only its sender from cache")
	visitor.forget()


func test_temporary_names_are_disambiguated_and_cannot_reclaim_a_seat() -> void:
	assert_eq(a.connect_local(server.port, server.access_code, "  Forest Fox  "), OK)
	assert_eq(b.connect_local(server.port, server.access_code, "Forest Fox"), OK)
	await _until(func() -> bool: return a.online and b.online)
	var first_name := a.guest
	var second_name := b.guest
	assert_true(first_name.begins_with("Forest Fox (Guest "))
	assert_true(second_name.begins_with("Forest Fox (Guest "))
	assert_ne(first_name, second_name)
	await _act(a, {"op": "host", "name": "Guest table", "decks": "own", "deck": {}})
	await _act(b, {"op": "join", "room": a.state.room.id})
	assert_eq(a.state.room.names, [first_name, second_name])
	assert_eq(b.state.room.names, a.state.room.names)
	assert_eq(b.state.rooms[0].host, first_name)
	b._nickname = "Different name"
	b.reconnect()
	await _until(func() -> bool: return b.online)
	assert_eq(b.guest, second_name, "resuming preserves the server's accepted label")
	assert_eq(server._sessions.size(), 2)
	var room_id := String(a.state.room.id)
	b.forget()
	assert_eq(b.guest, "")
	assert_eq(b._nickname, "")
	await _until(func() -> bool: return server._sessions.size() == 1)
	assert_eq(b.connect_local(server.port, server.access_code, "Forest Fox"), OK)
	await _until(func() -> bool: return b.online)
	assert_ne(b.guest, second_name, "the same nickname is not the old identity")
	await _act(b, {"op": "join", "room": room_id})
	assert_eq(b.state.room.id, room_id, "explicit departure released the old seat, not its identity")
	assert_eq(server._sessions.size(), 2)


func test_invalid_nickname_is_refused_locally_and_over_the_wire() -> void:
	assert_eq(a.connect_local(server.port, server.access_code, "[b]Fox[/b]"), ERR_INVALID_PARAMETER)
	assert_false(a._wanted)
	assert_eq(server._sessions.size(), 0)
	assert_eq(a.connect_local(server.port, server.access_code), OK)
	a._nickname = "Fox (Guest 1)"
	for i in 30:
		await get_tree().process_frame
	assert_false(a.online)
	assert_eq(server._sessions.size(), 0, "server validates names from modified clients too")


func test_lobby_opens_without_network_and_fits_small_window() -> void:
	var host := Control.new()
	add_child_autofree(host)
	host.size = Vector2(960, 600)
	var lobby := SgLobby.new()
	host.add_child(lobby)
	for i in 8:
		await get_tree().process_frame
	assert_null(lobby.service)
	assert_false(lobby.client.online)
	assert_eq(lobby.size, host.size)
	assert_lte(lobby.get_child(1).size.x, host.size.x)
	assert_lte(lobby.get_child(1).size.y, host.size.y)
	assert_not_null(lobby.find_child("StartService", true, false))
	assert_not_null(lobby.find_child("TemporaryName", true, false))
	assert_true(lobby._nickname.editable)
	assert_null(lobby._discovery, "opening the lobby does not start a search")
	for label: Label in lobby._connection_controls.find_children("*", "Label", true, false):
		if label.text in ["Temporary name", "Port"]:
			assert_lte(label.size.y, 38.0, "field labels must not wrap one syllable per line")


func _click(lobby: SgLobby, text: String) -> void:
	for node in lobby.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree():
			assert_false(node.disabled, text + " is enabled")
			node.pressed.emit()
			for i in 4:
				await get_tree().process_frame
			return
	assert_true(false, "missing button: " + text)


func test_gui_host_browser_join_and_ready_reach_a_private_table() -> void:
	# Independent viewports reproduce two windows' sizing and keyboard focus.
	# Hiding one root suppresses layout, so it cannot be used as a size probe.
	var lobbies: Array[SgLobby] = []
	for i in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(960, 600)
		add_child_autofree(viewport)
		var host := Control.new()
		viewport.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var lobby := SgLobby.new()
		host.add_child(lobby)
		lobbies.append(lobby)
	var first := lobbies[0]
	var second := lobbies[1]
	first._nickname.text = "Forest Fox"
	second._nickname.text = "W".repeat(SgProtocol.NICKNAME_LIMIT)
	first._port.min_value = 0
	first._port.value = 0
	await _click(first, "Host Game")
	await _click(first, "Network settings…")
	await _click(first, "Start local service")
	assert_not_null(first.service)
	if first.service == null:
		return
	assert_false(first._window_open(), "starting the service closes the settings window")
	second._port.value = first.service.port
	await _click(second, "Game Browser")
	await _click(second, "Join by invitation…")
	second._code.text = first.service.access_code
	await _click(second, "Connect")
	await _until(func() -> bool: return first.client.online and second.client.online)
	assert_true(first.client.guest.begins_with("Forest Fox (Guest "))
	assert_true(second.client.guest.begins_with("W".repeat(SgProtocol.NICKNAME_LIMIT)))
	assert_false(first._nickname.editable)
	assert_false(second._nickname.editable)
	await _click(first, "Host a duel")
	await _until(func() -> bool: return second.client.state.rooms.size() == 1)
	await _click(second, "Join")
	await _until(func() -> bool: return not second.client.state.room.is_empty())
	await _click(first, "Ready")
	await _click(second, "Ready")
	await _until(func() -> bool: return not first.client.state.room.game.is_empty())
	for i in 8:
		await get_tree().process_frame
	assert_false(first._connection_controls.visible)
	assert_false(second._connection_controls.visible)
	for lobby in lobbies:
		assert_lte(lobby.get_child(1).size.x, 960.0)
		assert_lte(lobby.get_child(1).size.y, 600.0)
	assert_false(first.client.state.room.game.players[1].has("hand"))
	assert_false(second.client.state.room.game.players[0].has("hand"))
	for lobby in lobbies:
		var captions := PackedStringArray()
		assert_not_null(lobby._duel)
		for label: Label in lobby._duel.find_children("*", "Label", true, false):
			captions.append(label.text)
		assert_true("\n".join(captions).contains(first.client.guest), "first nickname visible in duel")
		assert_true("\n".join(captions).contains(second.client.guest), "second nickname visible in duel")
	first.client.forget()
	second.client.forget()
	first.service.stop()


## OK ON A FRIENDLY RESULT LEAVES THE ROOM, NOT SGMANALINK (bug pass
## 2026-10-03). It used to free the whole lobby: the guest lost its
## connection, and on the host the server stopped with it — every other
## table's running duel ended, past the confirmation Close asks for.
func test_ok_on_a_friendly_result_returns_both_players_to_the_lobby() -> void:
	var lobbies: Array[SgLobby] = []
	for i in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(960, 600)
		add_child_autofree(viewport)
		var lobby := SgLobby.new()
		viewport.add_child(lobby)
		lobbies.append(lobby)
	var host := lobbies[0]
	var guest := lobbies[1]
	host._port.min_value = 0
	host._port.value = 0
	host._start_service()
	assert_not_null(host.service)
	if host.service == null: return
	var service := host.service
	guest._port.value = service.port
	guest._code.text = service.access_code
	guest._connect_local()
	await _until(func() -> bool: return host.client.online and guest.client.online)
	# Another table on the same host, mid-duel throughout.
	server.stop()
	assert_eq(a.connect_local(service.port, service.access_code), OK)
	assert_eq(b.connect_local(service.port, service.access_code), OK)
	await _until(func() -> bool: return a.online and b.online)
	await _act(a, {"op": "host", "name": "Other table", "decks": "own", "deck": {}})
	await _act(b, {"op": "join", "room": a.state.room.id})
	await _act(a, {"op": "ready", "value": true})
	await _act(b, {"op": "ready", "value": true})
	assert_false(a.state.room.game.is_empty(), "the other table's duel runs")
	# The host's own friendly table.
	await _act(host.client, {"op": "host", "name": "Friendly", "decks": "own", "deck": {}})
	await _act(guest.client, {"op": "join", "room": host.client.state.room.id})
	await _act(host.client, {"op": "ready", "value": true})
	await _act(guest.client, {"op": "ready", "value": true})
	await _until(func() -> bool: return is_instance_valid(host._duel) and is_instance_valid(guest._duel))
	await _act(guest.client, {"op": "concede"})
	await _until(func() -> bool: return int(host.client.state.room.game.get("winner", -1)) == 0 \
		and int(guest.client.state.room.game.get("winner", -1)) == 0)
	for i in 4: await get_tree().process_frame
	for lobby in lobbies: watch_signals(lobby._duel)
	var guest_duel := guest._duel
	guest_duel._on_game_over_dismissed()
	assert_signal_not_emitted(guest_duel, "exit_requested")
	await _until(func() -> bool: return guest.client.state.room.is_empty() and not is_instance_valid(guest._duel))
	assert_true(is_instance_valid(guest), "the guest's lobby stays open")
	assert_true(guest.client.online, "with its connection")
	assert_true(guest._shell.visible)
	var host_duel := host._duel
	host_duel._on_game_over_dismissed()
	assert_signal_not_emitted(host_duel, "exit_requested")
	await _until(func() -> bool: return host.client.state.room.is_empty() and not is_instance_valid(host._duel))
	assert_true(is_instance_valid(host))
	assert_true(service._listener.is_listening(), "the host keeps hosting")
	assert_true(service._rooms.size() == 1, "the finished room is gone; the other table stays")
	for i in 30: await get_tree().process_frame
	assert_true(a.online and b.online, "the other table's players stay connected")
	assert_false(a.state.room.game.is_empty())
	assert_eq(int(a.state.room.game.winner), -1, "their duel keeps running")
	host.client.forget()
	guest.client.forget()
	service.stop()


## The OK above leaves with whatever revision the player last saw; the
## opponent leaving first has already moved it on. A finished duel has
## nothing left that a fresher room could change, like a concession.
func test_leaving_a_finished_duel_needs_no_fresh_revision() -> void:
	await _start_duel()
	var room_id := String(a.state.room.id)
	a.state.room.revision = 0
	await _act(a, {"op": "leave"})
	assert_eq(String(a.state.room.get("id", "")), room_id, "a running duel is still left only by its rules")
	await _act(b, {"op": "concede"})
	await _act(b, {"op": "leave"})
	a.state.room.revision = 0
	await _act(a, {"op": "leave"})
	assert_true(a.state.room.is_empty())
	assert_false(server._rooms.has(room_id))


func test_disconnect_pauses_play_and_resuming_replaces_the_old_connection() -> void:
	await _start_duel()
	a.set_process(false)
	a._socket.close(-1)
	await _until(func() -> bool: return b.state.room.connected == [false, true])
	var revision := int(server._rooms[b.state.room.id].revision)
	await _act(b, {"op": "keep"})
	assert_eq(server._rooms[b.state.room.id].revision, revision)
	a.set_process(true)
	await _until(func() -> bool: return a.online and b.state.room.connected == [true, true])
	var replacement := SgLocalClient.new()
	add_child_autofree(replacement)
	assert_eq(replacement.connect_local(server.port, server.access_code), OK)
	replacement._resume = a._resume
	await _until(func() -> bool: return replacement.online and not a._wanted)
	assert_eq(int(replacement.state.room.seat), 0)
	assert_eq(server._sessions.size(), 2)
	replacement.forget()


func test_two_network_clients_finish_a_duel_using_only_their_views() -> void:
	server.stop()
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)
	await _start_duel()
	var screens: Array[SgDuelView] = []
	for peer in [a, b]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(960, 600)
		add_child_autofree(viewport)
		var screen := SgDuelView.new()
		screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
		viewport.add_child(screen)
		peer.refused.connect(screen.show_notice)
		screen.action_requested.connect(func(action: Dictionary) -> void:
			assert_true(peer.command(action), "UI command accepted by the client"))
		peer.changed.connect(func() -> void:
			if not peer.state.room.is_empty():
				screen.present(peer.state.room, peer.online, peer.busy()))
		screen.present(peer.state.room, peer.online, peer.busy())
		assert_not_null(screen._intro_overlay)
		screen._intro_overlay.go_pressed.emit()
		screens.append(screen)
	var played_land: Dictionary = {}
	var commands := 0
	var casts := 0
	while a.state.room.game.mode != "finished" and commands < 2000:
		var actor := int(a.state.room.game.actor)
		assert_true(actor in [0, 1], "practice pool must not produce unsupported choices")
		if actor not in [0, 1]:
			break
		var pilot: SgLocalClient = a if actor == 0 else b
		var action := _practice_action(pilot.state.room.game, actor, played_land)
		if action.op == "play":
			casts += 1
		var screen := screens[actor]
		match String(action.op):
			"order": screen._opening_answer(0)
			"keep": screen._opening_answer(1)
			"play", "tap":
				screen._on_card_clicked(screen.game.find_instance(screen.projection.local_id(action.card)))
			"attack", "discard":
				for handle: String in action.cards:
					screen._on_card_clicked(screen.game.find_instance(screen.projection.local_id(handle)))
				screen._on_done()
			_:
				assert_false(screen._pass_button.disabled)
				screen._on_done()
		assert_true(pilot.busy(), "duel interface emitted a network action")
		if not await _until(func() -> bool: return not pilot.busy()):
			break
		for i in 3:
			await get_tree().process_frame
		# Stay below the same per-connection rate limit as human clients.
		await get_tree().create_timer(0.025).timeout
		commands += 1
	assert_eq(a.state.room.game.mode, "finished")
	assert_eq(b.state.room.game.mode, "finished")
	assert_lt(commands, 2000)
	assert_gt(casts, 5, "real spells and lands were played, not just passing to deck-out")
	assert_eq(int(a.state.room.game.winner), int(b.state.room.game.winner))


func test_encrypted_private_lan_invitation_reconnect_and_fresh_host_secrets() -> void:
	server.stop()
	var addresses := SgLanInvite.local_addresses()
	var address := String(addresses[0]) if not addresses.is_empty() else "127.0.0.1"
	assert_eq(server.start_lan(address, 0, false, "Forest Fox"), OK)
	assert_null(server.discovery, "invitation-only hosts do not bind the discovery port")
	var invitation := server.invitation()
	var parsed := SgLanInvite.parse(invitation)
	assert_eq(parsed.address, address)
	assert_lt(invitation.length(), SgLanInvite.MAX_LENGTH)
	assert_false(invitation.contains("PRIVATE KEY"))
	await _start_duel()
	assert_not_null(a._tls_options)
	assert_false(a._tls_options.is_unsafe_client())
	assert_eq(SgLanInvite.public_pem(a._tls_options.get_trusted_ca_chain()), server._lan_pem)
	assert_eq(a._socket.get_connected_host(), address)
	var resume := a._resume
	a.reconnect()
	await _until(func() -> bool: return a.online)
	assert_eq(a._resume, resume)
	assert_eq(server._sessions.size(), 2)
	await _act(a, {"op": "concede"})
	a.forget()
	b.forget()
	assert_null(a._tls_options)
	server.stop()
	assert_eq(server.invitation(), "")
	assert_eq(server.start_lan(address, 0, false), OK)
	var fresh := SgLanInvite.parse(server.invitation())
	assert_ne(fresh.access, parsed.access)
	assert_ne(fresh.fingerprint, parsed.fingerprint)


func test_lan_discovery_real_udp_reply_has_no_credentials_and_stops() -> void:
	var advertiser := SgLanDiscovery.new()
	var scanner := SgLanDiscovery.new()
	add_child_autofree(advertiser)
	add_child_autofree(scanner)
	var advert := {"address": "127.0.0.1", "port": server.port, "name": "Forest Fox", "access": "invitation", "tables": [],
		"fingerprint": "a".repeat(64), "rooms": 1, "build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp()}
	assert_eq(advertiser.advertise(advert, 0), OK)
	assert_eq(scanner.scan(), OK)
	scanner.query("127.0.0.1", advertiser._socket.get_local_port())
	await _until(func() -> bool: return scanner.hosts.size() == 1)
	var entry: Dictionary = scanner.hosts.values()[0]
	assert_eq(entry.host.name, "Forest Fox")
	assert_eq(int(entry.host.rooms), 1)
	assert_false(JSON.stringify(scanner.hosts).contains(server.access_code))
	var probe := PacketPeerUDP.new()
	assert_eq(probe.bind(0, "127.0.0.1"), OK)
	assert_eq(probe.set_dest_address("127.0.0.1", advertiser._socket.get_local_port()), OK)
	assert_eq(probe.put_packet(JSON.stringify({"v": SgProtocol.VERSION,
		"type": "sg-lan-query", "nonce": scanner._nonce}).to_ascii_buffer()), OK)
	await _until(func() -> bool: return probe.get_available_packet_count() > 0)
	probe.get_packet()
	assert_eq(probe.get_packet_port(), advertiser._socket.get_local_port(),
		"discovery replies use the queried port for stateful firewall compatibility")
	probe.close()
	advertiser.update_rooms(0)
	scanner.query("127.0.0.1", advertiser._socket.get_local_port())
	await _until(func() -> bool: return int(scanner.hosts.values()[0].host.rooms) == 0)
	advertiser.stop()
	assert_false(advertiser._socket.is_bound())
	scanner.expire(Time.get_ticks_msec() + SgLanDiscovery.EXPIRES_MS)
	assert_true(scanner.hosts.is_empty())
	scanner.stop()
	assert_false(scanner._socket.is_bound())


## A HOST OF ANOTHER VERSION IS LISTED AS SUCH (bug pass 2026-10-03). A
## query and a reply each carry their version, and both ends used to drop
## any other one unread: two builds apart simply never saw each other.
func test_lan_discovery_lists_a_host_of_another_version_as_such() -> void:
	var advertiser := SgLanDiscovery.new()
	add_child_autofree(advertiser)
	var advert := {"address": "127.0.0.1", "port": server.port, "name": "Forest Fox", "access": "invitation", "tables": [],
		"fingerprint": "a".repeat(64), "rooms": 1, "build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp()}
	assert_eq(advertiser.advertise(advert, 0), OK)
	# A browser of the next version asks; this host answers in its own words.
	var newer := PacketPeerUDP.new()
	assert_eq(newer.bind(0, "127.0.0.1"), OK)
	assert_eq(newer.set_dest_address("127.0.0.1", advertiser._socket.get_local_port()), OK)
	assert_eq(newer.put_packet(JSON.stringify({"v": SgProtocol.VERSION + 1,
		"type": "sg-lan-query", "nonce": "c".repeat(64)}).to_ascii_buffer()), OK)
	await _until(func() -> bool: return newer.get_available_packet_count() > 0)
	var reply := SgProtocol.decode_payload(newer.get_packet(), 4)
	newer.close()
	assert_eq(int(reply.get("v", 0)), SgProtocol.VERSION)
	assert_eq(String(reply.get("nonce", "")), "c".repeat(64))
	# This browser hears an older host's reply: listed, not joinable.
	var lobby := SgLobby.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	viewport.add_child(lobby)
	for i in 4: await get_tree().process_frame
	lobby._show_page("browser")
	lobby._scan_lan()
	var scanner: SgLanDiscovery = lobby._discovery
	assert_true(scanner.scanning)
	var older := SgProtocol.VERSION - 1
	var stamp := SgCompatibility.stamp()
	stamp.game = "0.49.0"
	var old_reply := {"v": older, "type": "sg-lan-host", "nonce": scanner._nonce,
		"host": {"address": "192.168.0.7", "port": 17897, "name": "Amber Owl", "stamp": stamp, "shape": "of its own"}}
	assert_false(scanner.accept_reply(old_reply, "192.168.0.7", Time.get_ticks_msec()), "never a joinable listing")
	assert_true(scanner.hosts.is_empty())
	assert_eq(scanner.others.size(), 1)
	for i in 4: await get_tree().process_frame
	var texts := PackedStringArray()
	for label: Label in lobby._body.find_children("*", "Label", true, false): texts.append(label.text)
	assert_true(texts.has("Amber Owl"))
	assert_true(texts.has("Shandalar 0.49.0"))
	var other: Button
	for button: Button in lobby._body.find_children("*", "Button", true, false):
		if button.text == "Other version": other = button
	assert_not_null(other)
	if other == null: return
	other.pressed.emit()
	assert_eq(lobby._notice.text, "This host runs Shandalar 0.49.0 (SGManalink protocol %d); you run Shandalar %s (protocol %d). Both players need the same version." \
		% [older, SgCompatibility.game_version(), SgProtocol.VERSION])
	assert_false(lobby.client.connecting())
	advertiser.stop()


func test_hostile_server_view_is_refused_without_exposing_it_to_ui() -> void:
	await _pair()
	var sid := int(server._tokens[a._resume.sha256_text()])
	server._send(int(server._sessions[sid].peer), {"type": "state", "rooms": [],
		"room": {"seat": 999, "game": {"players": []}}})
	await _until(func() -> bool: return not a._wanted)
	assert_false(a.online)
	assert_true(a.state.room.is_empty())
	assert_true(a.status.contains("invalid response"))


func test_gui_lan_invitation_flow_and_discovery_selection_mismatch() -> void:
	var lobbies: Array[SgLobby] = []
	for i in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(960, 600)
		add_child_autofree(viewport)
		var lobby := SgLobby.new()
		viewport.add_child(lobby)
		lobbies.append(lobby)
	var host := lobbies[0]
	var guest := lobbies[1]
	# Loopback exercises the LAN TLS/UI path even on machines without an adapter.
	host._interfaces.clear()
	host._interfaces.add_item("127.0.0.1")
	host._port.min_value = 0
	host._port.value = 0
	host._advertise.button_pressed = false
	# The production GUI only offers actual LAN addresses. Start the test service explicitly.
	host.service = SgLocalServer.new()
	host.add_child(host.service)
	assert_eq(host.service.start_lan("127.0.0.1", 0, false, "Host"), OK)
	host._code.text = host.service.invitation()
	host._connect_local()
	guest._code.text = host.service.invitation()
	guest._selected_host = {"address": "127.0.0.1", "port": host.service.port,
		"fingerprint": "0".repeat(64), "name": "Impostor"}
	guest._connect_local()
	assert_false(guest.client._wanted)
	assert_true(guest._notice.text.contains("does not match"))
	guest._selected_host = {}
	await _click(guest, "Game Browser")
	await _click(guest, "Join by invitation…")
	await _click(guest, "Connect")
	await _until(func() -> bool: return host.client.online and guest.client.online)
	await _click(host, "Host Game")
	await _click(host, "Host a duel")
	await _until(func() -> bool: return guest.client.state.rooms.size() == 1)
	await _click(guest, "Join")
	await _until(func() -> bool: return not guest.client.state.room.is_empty())
	await _click(host, "Ready")
	await _click(guest, "Ready")
	await _until(func() -> bool: return not host.client.state.room.game.is_empty())
	for lobby in lobbies:
		assert_lte(lobby.get_child(1).size.x, 960.0)
		assert_lte(lobby.get_child(1).size.y, 600.0)
		lobby.client.forget()
	host.service.stop()


func _practice_action(view: Dictionary, seat: int, played_land: Dictionary) -> Dictionary:
	# Test driver sees the same value-only state as the UI, never the server game.
	match String(view.mode):
		"opening": return {"op": "keep"} if view.presentation.order else {"op": "order", "play": true}
		"attack":
			var cards: Array = []
			for card: Dictionary in view.players[seat].battlefield:
				if not card.land and not card.sick and not card.tapped:
					cards.append(card.id)
			return {"op": "attack", "cards": cards}
		"block": return {"op": "block", "pairs": []}
		"discard":
			var cards: Array = []
			for i in int(view.discard_count):
				cards.append(view.hand[i].id)
			return {"op": "discard", "cards": cards}
		"priority":
			if int(view.active) != seat or view.step not in ["MAIN1", "MAIN2"] or not view.stack.is_empty():
				return {"op": "pass"}
			for card: Dictionary in view.hand:
				if card.land and played_land.get(seat, -1) != int(view.turn):
					played_land[seat] = int(view.turn)
					return {"op": "play", "card": card.id}
			var lands: Array = []
			for card: Dictionary in view.players[seat].battlefield:
				if card.land and not card.tapped:
					lands.append(card)
			for card: Dictionary in view.hand:
				if card.land:
					continue
				var cost := ManaCost.parse(_announced_cost(view, card.id)).mana_value()
				var pool := int(view.players[seat].mana)
				if cost <= pool:
					return {"op": "play", "card": card.id}
				if cost <= pool + lands.size():
					return {"op": "tap", "card": lands[0].id}
	return {"op": "pass"}


## What casting the hand card [param handle] is announced at, where
## protocol 20 leaves it: on the presentation row's own spell option,
## which is where the seat's UI reads a cost from, rather than on the
## face — the face's copy was dead weight nothing consumed.
func _announced_cost(view: Dictionary, handle: String) -> String:
	for row in view.presentation.cards:
		if row.id != handle: continue
		for option in row.abilities:
			if option.kind == "spell": return String(option.cost)
	return ""


func test_varied_deck_rematches_with_latency_disconnects_and_duplicate_commands() -> void:
	await _pair()
	var decks := [StarterDecks.WHITE_KNIGHTS, StarterDecks.BLACK_RED_RAIDERS]
	var rounds := maxi(2, mini(20, int(OS.get_environment("SGMANALINK_SOAK_ROUNDS"))))
	var casts := 0
	for round_index in rounds:
		await _act(a, {"op": "host", "name": "Soak duel", "decks": "own", "deck": {}})
		await _act(b, {"op":"join", "room":a.state.room.id})
		for seat in 2:
			await _act(a if seat == 0 else b, {"op":"deck", "name":"Shipped deck",
				"cards":Array(decks[(seat + round_index) % 2]), "sideboard":[]})
		await _act(a, {"op":"ready", "value":true})
		await _act(b, {"op":"ready", "value":true})
		var skipped := {}
		var errors: Array = []
		var record := func(reason: String) -> void: errors.append(reason)
		a.refused.connect(record)
		b.refused.connect(record)
		var commands := 0
		while a.state.room.game.mode != "finished" and commands < 2400:
			var seat := int(a.state.room.game.actor)
			var pilot: SgLocalClient = a if seat == 0 else b
			var state: Dictionary = pilot.state.room.game
			var action := _soak_action(state, seat, skipped)
			var pending_card: String = state.presentation.draft.get("card", action.get("card", ""))
			if action.op == "cancel": skipped[pending_card] = true
			var errors_before := errors.size()
			# Delayed processing adds latency without bypassing the wire or rules.
			if commands % 37 == 0:
				pilot.set_process(false)
				assert_true(pilot.command(action))
				var duplicate := pilot._pending.duplicate(true)
				await get_tree().create_timer(0.08).timeout
				pilot._socket.send_text(SgProtocol.encode(duplicate))
				pilot.set_process(true)
				await _until(func() -> bool: return not pilot.busy())
				for i in 3: await get_tree().process_frame
			else: await _act(pilot, action)
			if errors.size() != errors_before:
				skipped[pending_card] = true
				if not pilot.state.room.game.announcement.is_empty(): await _act(pilot, {"op":"cancel"})
			elif action.op == "submit": casts += 1
			if commands % 71 == 35:
				var old_identity := pilot.guest
				pilot._socket.close(-1)
				pilot.reconnect()
				await _until(func() -> bool: return pilot.online and not pilot.busy())
				for i in 3: await get_tree().process_frame
				assert_eq(pilot.guest, old_identity)
			assert_true(a.online and b.online)
			assert_eq(a.state.room.game.winner, b.state.room.game.winner)
			commands += 1
			if commands % 200 == 0: print("SGManalink soak: round ", round_index + 1, ", commands ", commands, ", turn ", a.state.room.game.turn, ", step ", state.step, ", action ", action.op)
			await get_tree().create_timer(0.025).timeout
		assert_eq(a.state.room.game.mode, "finished", "varied-deck soak must finish")
		assert_lt(commands, 2400)
		print("SGManalink soak: round ", round_index + 1, " finished in ", commands, " commands")
		if a.state.room.game.mode != "finished":
			await _act(a, {"op":"concede"})
		a.refused.disconnect(record)
		b.refused.disconnect(record)
		await _act(a, {"op":"leave"})
		await _act(b, {"op":"leave"})
		assert_true(server._rooms.is_empty())
		assert_eq(server._sessions.size(), 2, "rematches reuse both sessions")
	assert_gt(casts, rounds * 2)


func _soak_action(view: Dictionary, seat: int, skipped: Dictionary) -> Dictionary:
	# Deliberately simple test driver, exclusively consuming the seat's DTO.
	match String(view.mode):
		"opening": return {"op":"keep"} if view.presentation.order else {"op":"order", "play":true}
		"choice":
			var picks: Array = []
			for i in int(view.choice.count): picks.append(i)
			return {"op":"choice", "picks":picks}
		"damage": return {"op":"damage", "points":[[view.damage_request.targets[0].id, view.damage_request.amount]]}
		"attack": return {"op":"attack", "cards":view.presentation.attackable.duplicate()}
		"block": return {"op":"block", "pairs":[]}
		"discard":
			var cards: Array = []
			for i in int(view.discard_count): cards.append(view.hand[i].id)
			return {"op":"discard", "cards":cards}
	if not view.announcement.is_empty():
		var targets: Array = []
		for slot in view.announcement.slots:
			if slot.targets.size() < int(slot.min): return {"op":"cancel"}
			for i in int(slot.min): targets.append([slot.targets[i].id, int(slot.divided) if i == 0 else 0])
		return {"op":"submit", "targets":targets}
	if view.active == seat and view.step in ["MAIN1", "MAIN2"] and view.stack.is_empty():
		for card in view.hand:
			if card.land and card.playable: return {"op":"play", "card":card.id}
		for row in view.presentation.cards:
			if not row.castable or skipped.has(row.id): continue
			for option in row.abilities:
				if option.kind == "spell":
					return {"op":"autoprepare", "card":row.id, "kind":"spell", "index":0, "mode":0, "count":1, "excluded":[]}
	return {"op":"pass"}


func test_a_concession_is_accepted_over_a_revision_the_client_has_not_seen() -> void:
	# A bot's polling bumps the room while a human is still deciding to
	# give up; the one move a fresher room cannot make wrong is that one.
	var refused: Array = []
	a.refused.connect(func(reason: String) -> void: refused.append(reason))
	await _pair()
	await _act(a, {"op": "host", "name": "Practice room", "decks": "own", "deck": {}})
	await _act(b, {"op": "join", "room": a.state.room.id})
	await _act(a, {"op": "ready", "value": true})
	await _act(b, {"op": "ready", "value": true})
	await _until(func() -> bool: return not a.state.room.game.is_empty())
	server._rooms[a.state.room.id].revision += 1
	await _act(a, {"op": "keep"})
	assert_eq(refused, ["The room changed. Please try again."], "an ordinary move still waits for the fresh room")
	refused.clear()
	server._rooms[a.state.room.id].revision += 1
	await _act(a, {"op": "concede"})
	assert_eq(refused, [], "the concession went through over the stale revision")
	assert_eq(int(a.state.room.game.winner), 1)
	assert_eq(int(b.state.room.game.winner), 1)
