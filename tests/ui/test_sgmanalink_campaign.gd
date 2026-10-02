extends GameTest
## Reproducible self-play over TLS, with paired baseline/fault transcripts.
const Pilot = preload("res://tests/support/sg_network_pilot.gd")
const MAX_COMMANDS := 2400
var server: SgLocalServer
var peers: Array[SgLocalClient] = []
var failures: Array = []
var journal: FileAccess

class SeededServer extends SgLocalServer:
	var duel_seed := 4242
	var fixture: SgPracticeMatch
	func _create_match(decks: Array, names: Array, rules: Dictionary = {}) -> SgPracticeMatch:
		if fixture != null: return fixture
		return SgPracticeMatch.new(duel_seed, decks, names, rules)


func after_each() -> void:
	for peer in peers:
		peer.set_process(true)
		peer.forget()
	if server != null: server.stop()
	if journal != null:
		journal.close()
		journal = null
	peers.clear()
	failures.clear()
	server = null


func _until(predicate: Callable, description: String) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, description)
	return false


func _settled() -> bool:
	if not peers[0].online or not peers[1].online or peers[0].busy() or peers[1].busy(): return false
	var a: Dictionary = peers[0].state.room
	var b: Dictionary = peers[1].state.room
	return a.is_empty() or b.is_empty() or (a.revision == b.revision and a.connected == [true, true] and b.connected == [true, true])


func _command(seat: int, action: Dictionary, fault := "") -> bool:
	var peer := peers[seat]
	var before := failures.size()
	if not fault.is_empty(): peer.set_process(false)
	var accepted := peer.command(action)
	assert_true(accepted, "client accepts " + str(action))
	if not accepted:
		peer.set_process(true)
		return false
	if not fault.is_empty():
		var pending := peer._pending_wire
		await get_tree().create_timer(0.09).timeout
		if fault == "duplicate":
			assert_eq(peer._socket.send_text(pending), OK)
		elif fault == "lost_ack":
			peer._socket.close(-1)
			peer.reconnect()
		peer.set_process(true)
	if not await _until(_settled, "both clients settle after " + str(action)): return false
	# Real clients obey the service's per-connection rate limit.
	await get_tree().create_timer(0.025).timeout
	assert_eq(failures.size(), before, "unexpected referee refusal: " + str(failures))
	return failures.size() == before


func _record(entry: Dictionary) -> void:
	if journal != null:
		journal.store_line(JSON.stringify(entry))
		journal.flush()


func _decks(index: int) -> Array:
	var decks: Array = [Array(StarterDecks.WHITE_KNIGHTS), Array(StarterDecks.BLACK_RED_RAIDERS)]
	if index % 3 == 1:
		decks[0] = []
		for name in ["Counterspell", "Unsummon", "Phantom Monster", "Wall of Air", "Ancestral Recall", "Control Magic"]:
			for i in 4: decks[0].append(name)
		for i in 16: decks[0].append("Island")
	elif index % 3 == 2:
		decks[1] = []
		for name in ["Grizzly Bears", "Giant Spider", "War Mammoth", "Giant Growth", "Llanowar Elves", "Hurricane"]:
			for i in 4: decks[1].append(name)
		for i in 16: decks[1].append("Forest")
	if index % 2 == 1: decks.reverse()
	return decks


func test_seeded_tls_games_replay_identically_through_network_faults() -> void:
	var path := OS.get_environment("SGMANALINK_CAMPAIGN_LOG")
	if not path.is_empty():
		journal = FileAccess.open(path, FileAccess.WRITE)
		assert_not_null(journal, "campaign log can be created")
		if journal == null: return
	server = SeededServer.new()
	add_child_autofree(server)
	var addresses := SgLanInvite.local_addresses()
	var address := "127.0.0.1" if addresses.is_empty() else String(addresses[0])
	var started := server.start_lan(address, 0, false)
	assert_eq(started, OK)
	if started != OK: return
	for seat in 2:
		var peer := SgLocalClient.new()
		add_child_autofree(peer)
		peer.refused.connect(func(reason: String) -> void: failures.append(reason))
		peers.append(peer)
		assert_eq(peer.connect_invitation(server.invitation(), "Pilot %d" % (seat + 1)), OK)
	if not await _until(_settled, "TLS clients connect"): return
	for peer in peers:
		assert_not_null(peer._tls_options)
		assert_eq(peer._socket.get_connected_host(), address)
	var cases := clampi(int(OS.get_environment("SGMANALINK_CAMPAIGN_CASES")), 1, 20)
	var first_seed := 4242
	if not OS.get_environment("SGMANALINK_CAMPAIGN_SEED").is_empty():
		first_seed = int(OS.get_environment("SGMANALINK_CAMPAIGN_SEED"))
	var totals := {"commands": 0, "submit": 0, "blocks": 0, "damage": 0, "choice": 0, "duplicate": 0, "lost_ack": 0, "cancel": 0}
	for case_index in cases:
		var baseline: Array = []
		for stressed in [false, true]:
			server.duel_seed = first_seed + case_index
			var decks := _decks(case_index)
			if not await _command(0, {"op": "host", "name": "Campaign", "decks": "own", "deck": {}}): return
			if not await _command(1, {"op": "join", "room": peers[0].state.room.id}): return
			for seat in 2:
				if not await _command(seat, {"op": "deck", "name": "Fixture %d" % seat, "cards": decks[seat], "sideboard": []}): return
			if not await _command(0, {"op": "ready", "value": true}): return
			if not await _command(1, {"op": "ready", "value": true}): return
			var pilots := [Pilot.new(), Pilot.new()]
			var projections := [SgDuelProjection.new(), SgDuelProjection.new()]
			var transcript: Array = []
			var commands := 0
			var deadline := Time.get_ticks_msec() + 180000
			_record({"event": "start", "seed": server.duel_seed, "case": case_index, "stressed": stressed})
			while peers[0].state.room.game.mode != "finished" and commands < MAX_COMMANDS and Time.get_ticks_msec() < deadline:
				var seat := int(peers[0].state.room.game.actor)
				assert_true(seat in [0, 1], "live decision has a player")
				if seat not in [0, 1]: return
				# Never give this pilot the other peer, room/deck or referee.
				var action: Dictionary = pilots[seat].choose(peers[seat].state.room.game.duplicate(true), seat)
				var fault := ""
				if stressed:
					if commands % 43 == 13: fault = "duplicate"
					elif commands % 89 == 35: fault = "lost_ack"
				if not fault.is_empty(): totals[fault] += 1
				_record({"event": "command", "number": commands, "seat": seat, "action": action, "fault": fault})
				if not await _command(seat, action, fault):
					_record({"event": "failure", "refusals": failures})
					return
				for pid in 2:
					var room: Dictionary = peers[pid].state.room
					assert_true(SgViewProtocol.room(room), "seat DTO remains valid")
					projections[pid].ingest(room)
					assert_eq(projections[pid].players[0].hand.size(), room.game.hand.size())
					assert_eq(projections[pid].players[1].hand.size(), int(room.game.players[1 - pid].hand_count))
				var table: Dictionary = Pilot.public_table(peers[0].state.room.game)
				var other: Dictionary = Pilot.public_table(peers[1].state.room.game)
				assert_eq(table, other, "public table agrees after " + str(action))
				if table != other: return
				var digest := JSON.stringify(table).sha256_text()
				transcript.append(digest)
				_record({"event": "state", "number": commands, "hash": digest, "table": table})
				commands += 1
				totals.commands += 1
				if action.op in ["submit", "damage", "choice", "cancel"]: totals[action.op] += 1
				if action.op == "block": totals.blocks += action.pairs.size()
				if commands % 200 == 0: print("SG campaign seed=", server.duel_seed, " stressed=", stressed, " commands=", commands)
			assert_eq(peers[0].state.room.game.mode, "finished", "campaign game must finish, not time out")
			assert_lt(commands, MAX_COMMANDS)
			if stressed: assert_eq(transcript, baseline, "faults cannot change any accepted-action public state")
			else: baseline = transcript
			var result := {"event": "finished", "seed": server.duel_seed, "stressed": stressed, "commands": commands,
				"turn": peers[0].state.room.game.turn, "winner": peers[0].state.room.game.winner}
			_record(result)
			print("SG campaign ", JSON.stringify(result))
			if peers[0].state.room.game.mode != "finished": return
			for seat in 2:
				if not await _command(seat, {"op": "leave"}): return
			assert_true(server._rooms.is_empty(), "rematch reclaims the room")
			assert_eq(server._sessions.size(), 2, "faults reuse the two seats")
	assert_gt(totals.submit, 10)
	assert_gt(totals.blocks, 0, "not a no-blocking race")
	if cases >= 3: assert_gt(totals.damage, 0, "extended campaign must assign interactive combat damage")
	assert_gt(totals.duplicate, 0)
	assert_gt(totals.lost_ack, 0)
	assert_eq(failures, [])
	_record({"event": "totals", "counts": totals})
	print("SG campaign totals ", JSON.stringify(totals))


func _start_fixture() -> SgPracticeMatch:
	# Situational setup is referee-side only. The move under test still comes
	# from the DTO-only pilot and travels through real TLS and deduplication.
	server = SeededServer.new()
	add_child_autofree(server)
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)
	var referee := SgPracticeMatch.new(42)
	referee.game = g
	referee.view(0)
	server.fixture = referee
	for seat in 2:
		var peer := SgLocalClient.new()
		add_child_autofree(peer)
		peer.refused.connect(func(reason: String) -> void: failures.append(reason))
		peers.append(peer)
		assert_eq(peer.connect_invitation(server.invitation()), OK)
	if not await _until(_settled, "fixture clients connect"): return null
	if not await _command(0, {"op": "host", "name": "Coverage fixture", "decks": "own", "deck": {}}): return null
	if not await _command(1, {"op": "join", "room": peers[0].state.room.id}): return null
	if not await _command(0, {"op": "ready", "value": true}): return null
	if not await _command(1, {"op": "ready", "value": true}): return null
	return referee


func _interactive() -> void:
	g.rules.free_damage_assignment = true
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func test_pilot_divided_damage_reconnects_without_reapplying_points() -> void:
	_interactive()
	var attacker := put_battlefield(0, "Craw Wurm")
	var first := put_battlefield(1, "Grizzly Bears")
	var second := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	for i in 8:
		if g.awaiting_blockers: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.declare_blockers(1, {first.id: attacker.id, second.id: attacker.id}))
	for i in 8:
		if g.awaiting_damage_assignment: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_damage_assignment)
	if await _start_fixture() == null: return
	assert_true(peers[1].state.room.game.damage_request.is_empty())
	var action: Dictionary = Pilot.new().choose(peers[0].state.room.game, 0)
	assert_eq(action.op, "damage")
	assert_eq(action.points.size(), 2)
	if not await _command(0, action, "lost_ack"): return
	assert_eq(first.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 20)
	assert_eq(Pilot.public_table(peers[0].state.room.game), Pilot.public_table(peers[1].state.room.game))
	assert_eq(server._sessions.size(), 2)


func test_pilot_private_search_answer_is_exactly_once_and_stays_private() -> void:
	_interactive()
	advance_to_step(Mtg.Step.MAIN1)
	var hidden := give_hand(0, "Black Lotus")
	g.put_from_hand_on_top_of_library(hidden)
	var tutor := give_hand(0, "Demonic Tutor")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, tutor))
	for i in 8:
		if g.awaiting_choice != null: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice)
	if await _start_fixture() == null: return
	assert_false(SgProtocol.encode(peers[1].state).contains("Black Lotus"))
	var action: Dictionary = Pilot.new().choose(peers[0].state.room.game, 0)
	assert_eq(action.op, "choice")
	if not await _command(0, action, "lost_ack"): return
	assert_null(g.awaiting_choice)
	assert_eq(hidden.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), 1)
	assert_false(SgProtocol.encode(peers[1].state).contains("Black Lotus"))
	assert_eq(Pilot.public_table(peers[0].state.room.game), Pilot.public_table(peers[1].state.room.game))
