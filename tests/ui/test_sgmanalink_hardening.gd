extends GameTest
## Second LAN pass: message completion, bounded sends, membership and view safety.

class GateServer extends SgLocalServer:
	var hold_states := false
	var held := {}
	var acknowledgements := 0
	var states_sent := 0
	func _send(id: int, message: Dictionary) -> void:
		if message.type == "ack": acknowledgements += 1
		if message.type == "state":
			if hold_states:
				held[id] = message.duplicate(true)
				return
			states_sent += 1
		super._send(id, message)
	func release_states() -> void:
		hold_states = false
		for id in held: _send(id, held[id])
		held.clear()

class CountingMatch extends SgPracticeMatch:
	var views_built := 0
	func view(pid: int) -> Dictionary:
		views_built += 1
		return super.view(pid)

var server: GateServer
var a: SgLocalClient
var b: SgLocalClient

func before_each() -> void:
	super.before_each()
	server = GateServer.new()
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

func _until(predicate: Callable) -> bool:
	for i in 400:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "Network hardening test exceeded its frame budget")
	return false

func _act(client: SgLocalClient, action: Dictionary) -> void:
	assert_true(client.command(action))
	await _until(func() -> bool: return not client.busy())
	for i in 4: await get_tree().process_frame

func _pair() -> void:
	assert_eq(a.connect_local(server.port, server.access_code), OK)
	assert_eq(b.connect_local(server.port, server.access_code), OK)
	await _until(func() -> bool: return a.online and b.online)

func _room() -> void:
	await _pair()
	await _act(a, {"op": "host", "name": "Robustness", "decks": "own", "deck": {}})
	await _act(b, {"op":"join", "room":a.state.room.id})

func _sid(client: SgLocalClient) -> int:
	return int(server._tokens[client._resume.sha256_text()])

func test_acknowledgement_waits_for_its_resulting_snapshot() -> void:
	await _pair()
	server.hold_states = true
	assert_true(a.command({"op": "host", "name": "Delayed state", "decks": "own", "deck": {}}))
	await _until(func() -> bool: return server.acknowledgements > 0)
	for i in 12: await get_tree().process_frame
	assert_true(a.busy(), "an acknowledgement alone must not unlock stale state")
	assert_false(a.command({"op": "host", "name": "Too early", "decks": "own", "deck": {}}))
	server.release_states()
	await _until(func() -> bool: return not a.busy())
	assert_false(a.state.room.is_empty())

func test_oversized_command_is_refused_before_consuming_a_sequence() -> void:
	await _pair()
	var names: Array = []
	for i in 250: names.append("x".repeat(128))
	var sequence := a._seq
	assert_false(a.command({"op":"deck", "name":"Too large", "cards":names, "sideboard":[]}))
	assert_eq(a._seq, sequence)
	assert_false(a.busy())
	assert_true(a.online)

func test_replacement_opponent_does_not_inherit_readiness() -> void:
	await _room()
	var id: String = a.state.room.id
	await _act(a, {"op":"ready", "value":true})
	await _act(b, {"op":"leave"})
	assert_eq(a.state.room.ready, [false, false])
	await _act(b, {"op":"join", "room":id})
	await _act(b, {"op":"ready", "value":true})
	assert_true(a.state.room.game.is_empty(), "both seats must approve the new pairing")

func test_roomless_departure_does_not_rebuild_an_unrelated_duel() -> void:
	await _room()
	var duel := CountingMatch.new(42)
	server._rooms[a.state.room.id].match = duel
	server._publish()
	for i in 6: await get_tree().process_frame
	assert_eq(duel.views_built, 2)
	var visitor := SgLocalClient.new()
	add_child_autofree(visitor)
	assert_eq(visitor.connect_local(server.port, server.access_code), OK)
	await _until(func() -> bool: return visitor.online)
	visitor.forget()
	await _until(func() -> bool: return server._sessions.size() == 2)
	for i in 6: await get_tree().process_frame
	assert_eq(duel.views_built, 2, "roomless churn must not invalidate duel caches")

func test_duplicate_commands_coalesce_their_state_refresh() -> void:
	await _pair()
	assert_true(a.command({"op": "host", "name": "Duplicate replies", "decks": "own", "deck": {}}))
	var duplicate := SgProtocol.decode(SgProtocol.encode(a._pending).to_ascii_buffer())
	await _until(func() -> bool: return not a.busy())
	for i in 4: await get_tree().process_frame
	var sent := server.states_sent
	var peer: int = server._sessions[_sid(a)].peer
	for i in 12: server._receive(peer, duplicate)
	server._flush_publish()
	assert_eq(server.states_sent - sent, 1, "one snapshot per recipient per polling batch")

## THE REPLAY CACHE HOLDS DIGESTS, NOT COMMANDS (bug pass 2026-10-03): it
## kept the last ACK_WINDOW command texts of every session, refused ones
## too — 128 x 32 KiB x 4 bytes a character, ~15 MiB a session, and one LAN
## peer holding an open host's advertised access code could open dozens.
## The replay rule itself is unchanged: the same sequence number with the
## same command answers with the recorded acknowledgement; with a different
## command it is refused.
func test_acknowledgement_cache_keeps_digests_and_the_replay_rule() -> void:
	await _pair()
	var names: Array = []
	for i in 200: names.append("Unsent card name %03d" % i)
	assert_true(a.command({"op": "deck", "name": "Cached digest deck", "cards": names, "sideboard": []}))
	var duplicate := SgProtocol.decode(SgProtocol.encode(a._pending).to_ascii_buffer())
	await _until(func() -> bool: return not a.busy())
	for i in 4: await get_tree().process_frame
	var session: Dictionary = server._sessions[_sid(a)]
	var cached: Dictionary = session.acks[int(duplicate.seq)]
	assert_false(cached.ack.ok, "a refused command is cached all the same")
	var stored := JSON.stringify(session.acks)
	assert_false(stored.contains("Unsent card name"), "no command text survives in the cache")
	assert_lt(stored.length(), 1024, "one acknowledgement and one digest, not the command")
	# Same sequence, same command: the recorded acknowledgement again.
	var acknowledgements := server.acknowledgements
	var peer: int = session.peer
	server._receive(peer, duplicate)
	assert_eq(server.acknowledgements, acknowledgements + 1)
	assert_false(server._peers[peer].has("reject_until"), "a faithful retry keeps its connection")
	assert_eq(int(session.seq), int(duplicate.seq), "the retry consumed no sequence number")
	# Same sequence, a different command: refused, connection closing.
	var conflicting: Dictionary = duplicate.duplicate(true)
	conflicting.action.name = "Another deck"
	server._receive(peer, conflicting)
	assert_eq(server.acknowledgements, acknowledgements + 1, "no acknowledgement for a conflict")
	assert_true(server._peers[peer].has("reject_until"))
	await _until(func() -> bool: return not a._wanted)
	assert_string_contains(a.status, "Expired or conflicting command")

func test_host_view_rejects_aliases_and_impossible_combat_references() -> void:
	put_battlefield(0, "Grizzly Bears")
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	var base := duel.view(0)
	assert_true(SgViewProtocol.game(base))
	var alias := base.duplicate(true)
	alias.players[1].battlefield.append(alias.players[0].battlefield[0].duplicate(true))
	assert_false(SgViewProtocol.game(alias), "a card handle cannot occupy two zones or seats")
	var invalid := base.duplicate(true)
	invalid.presentation.blocks = [["missing", "also-missing"]]
	assert_false(SgViewProtocol.game(invalid), "combat cannot reference absent cards")
	invalid = base.duplicate(true)
	invalid.presentation.bands = [["missing"]]
	assert_false(SgViewProtocol.game(invalid))
	invalid = base.duplicate(true)
	invalid.players[0].battlefield[0].keywords = [4095]
	assert_false(SgViewProtocol.game(invalid), "only known keyword enum values reach widgets")

func test_stalled_snapshot_reconnects_without_repeating_the_applied_action() -> void:
	await _pair()
	server.hold_states = true
	assert_true(a.command({"op": "host", "name": "Stalled state", "decks": "own", "deck": {}}))
	var sequence: int = a._pending.seq
	await _until(func() -> bool: return not a._pending_ack.is_empty())
	a._pending_started = Time.get_ticks_msec() - SgLocalClient.COMMAND_TIMEOUT_MS
	a.poll()
	assert_false(a.online)
	assert_true(a.busy(), "an uncertain result is retained for same-sequence replay")
	assert_string_contains(a.status, "stalled")
	server.release_states()
	a.reconnect()
	await _until(func() -> bool: return a.online and not a.busy())
	assert_eq(server._sessions[_sid(a)].seq, sequence)
	assert_eq(server._rooms.size(), 1)
	assert_eq(a.state.room.name, "Stalled state")

func test_rejected_action_reports_once_after_the_fresh_snapshot() -> void:
	await _pair()
	var errors: Array = []
	a.refused.connect(func(reason: String) -> void: errors.append(reason))
	server.hold_states = true
	assert_true(a.command({"op":"pass"}))
	await _until(func() -> bool: return not a._pending_ack.is_empty())
	assert_true(a.busy())
	assert_true(errors.is_empty())
	server.release_states()
	await _until(func() -> bool: return not a.busy())
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "Join a room")

func test_malformed_host_snapshot_is_stopped_before_replacing_client_state() -> void:
	await _room()
	put_battlefield(0, "Grizzly Bears")
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	server._rooms[a.state.room.id].match = duel
	server._publish()
	await _until(func() -> bool: return not a.state.room.game.is_empty())
	var previous := a.state.duplicate(true)
	var invalid := previous.duplicate(true)
	invalid.room.game.presentation.blocks = [["missing", "also-missing"]]
	server._send(int(server._sessions[_sid(a)].peer), invalid)
	await _until(func() -> bool: return not a._wanted)
	assert_false(a.online)
	assert_eq(a.state, previous, "untrusted data must never reach the presentation")
	assert_string_contains(a.status, "invalid response")

func test_departed_attacker_does_not_recreate_a_hidden_card_handle() -> void:
	await _room()
	var attacker := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Savannah Lions")
	g.combat.attackers[attacker.id] = true
	g.combat.blocks[blocker.id] = attacker.id
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	server._rooms[a.state.room.id].match = duel
	server._publish()
	await _until(func() -> bool: return not b.state.room.game.is_empty())
	g.return_to_hand(attacker)
	assert_true(g.combat.blocks.has(blocker.id), "the blocker remains a blocking creature")
	for pid in 2:
		var snapshot := duel.view(pid)
		assert_true(SgViewProtocol.game(snapshot), "a departed attacker must not break a valid view")
		var projection := SgDuelProjection.new()
		projection.ingest({"seat":pid, "game":snapshot, "names":["One", "Two"], "deck":{}})
		var local_blocker := projection.players[projection.local_seat(1)].battlefield[0]
		assert_true(projection.combat.blocks.has(local_blocker.id))
		assert_eq(projection.combat.blocks[local_blocker.id], -1, "no live link to a departed attacker")
	assert_false(duel._handles[1].has(attacker.id), "a combat remnant cannot reacquire a hidden identity")
	g.put_on_bottom_of_library(attacker)
	assert_true(SgViewProtocol.game(duel.view(0)))
	assert_true(SgViewProtocol.game(duel.view(1)))
	assert_false(duel._handles[0].has(attacker.id))
	assert_false(duel._handles[1].has(attacker.id))
	server._publish()
	await _until(func() -> bool:
		return b.state.room.game.players[0].library_count == g.players[0].library.size())
	assert_true(a.online and b.online, "both real clients accept the departed-attacker snapshot")

func test_departed_primary_attacker_preserves_additional_live_blocks() -> void:
	var first := put_battlefield(0, "Grizzly Bears")
	var second := put_battlefield(0, "Gray Ogre")
	var blocker := put_battlefield(1, "Two-Headed Giant of Foriys")
	g.combat.attackers[first.id] = true
	g.combat.attackers[second.id] = true
	g.combat.blocks[blocker.id] = first.id
	g.combat.extra_blocks[blocker.id] = [second.id]
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	duel.view(1)
	g.return_to_hand(first)
	var snapshot := duel.view(1)
	assert_true(SgViewProtocol.game(snapshot))
	assert_eq(snapshot.presentation.blocks, [[duel._handle(1, blocker), duel._handle(1, second)]])
	assert_false(duel._handles[1].has(first.id))
	var projection := SgDuelProjection.new()
	projection.ingest({"seat":1, "game":snapshot, "names":["One", "Two"], "deck":{}})
	assert_eq(projection.combat.blocks[projection.local_id(duel._handle(1, blocker))],
		projection.local_id(duel._handle(1, second)))

func test_departed_token_attacker_keeps_a_valid_blocking_snapshot() -> void:
	var attacker: CardInstance = g.create_token(0, CardRegistry.get_card("Grizzly Bears"))[0]
	var blocker := put_battlefield(1, "Savannah Lions")
	g.combat.attackers[attacker.id] = true
	g.combat.blocks[blocker.id] = attacker.id
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	duel.view(1)
	g.return_to_hand(attacker)
	g.recalculate()
	assert_null(g.find_instance(attacker.id), "tokens cease to exist after leaving play")
	for pid in 2:
		var snapshot := duel.view(pid)
		assert_true(SgViewProtocol.game(snapshot))
		assert_eq(snapshot.presentation.blocks, [[duel._handle(pid, blocker), ""]])
		assert_false(duel._handles[pid].has(attacker.id))
