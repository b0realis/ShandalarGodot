extends GutTest
## Multiple real TLS clients, whole knockout lifecycle and private recovery.

var server: SgLocalServer
var clients: Array[SgLocalClient] = []
var scratch := ""
var refusals: Array = []
var campaign_journal: FileAccess
const Pilot = preload("res://tests/support/sg_network_pilot.gd")

class SeededServer extends SgLocalServer:
	var duel_seed := 4242
	var vary_seeds := false
	func _create_match(decks: Array, names: Array, rules: Dictionary = {}) -> SgPracticeMatch:
		var seed_value := duel_seed
		if vary_seeds: duel_seed += 1
		return SgPracticeMatch.new(seed_value, decks, names, rules)


func before_each() -> void:
	clients.clear()
	refusals.clear()
	scratch = "user://tournament-tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	server = SeededServer.new()
	add_child_autofree(server)
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)


func after_each() -> void:
	if campaign_journal != null:
		campaign_journal.close()
		campaign_journal = null
	for client in clients: client.forget()
	server.stop()
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := DirAccess.open(scratch)
	if dir != null:
		for filename in dir.get_files(): dir.remove(filename)
		DirAccess.remove_absolute(scratch)


func _until(predicate: Callable, frames := 800) -> bool:
	for i in frames:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "tournament network operation exceeded its frame budget")
	return false


func _client(name_value := "Guest") -> SgLocalClient:
	var client := SgLocalClient.new()
	add_child_autofree(client)
	clients.append(client)
	client.refused.connect(func(reason: String) -> void: refusals.append(reason))
	assert_eq(client.connect_invitation(server.invitation(), name_value), OK)
	await _until(func() -> bool: return client.online)
	return client


func _act(client: SgLocalClient, op: String, fields := {}) -> void:
	var action := fields.duplicate(true)
	action.op = op
	if op.begins_with("t_"): action.event = server.tournament.event.id
	assert_true(client.command(action), op + ": " + client.command_error)
	await _until(func() -> bool: return not client.busy())
	for i in 3: await get_tree().process_frame
	assert_true(client.online, client.status)
	assert_true(SgViewProtocol.valid(client.state))


func _open(owner: SgLocalClient, wins := 1, policy := "fixed", limit := 8) -> void:
	var options := {"name": "LAN Cup", "limit": limit, "wins": wins, "policy": policy,
		"decks": [] if policy == "own" else [{"name": "Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]}
	assert_eq(server.open_tournament(options, owner._resume, scratch), "")
	await _until(func() -> bool: return owner.state.has("tournament"))


func _register(count: int, wins := 1) -> SgLocalClient:
	var owner := await _client("Organiser")
	await _open(owner, wins, "fixed", maxi(8, count))
	for i in count:
		var client := await _client("Entrant %d" % (i + 1))
		await _act(client, "t_join")
		await _act(client, "t_ready", {"value": true})
	await _act(owner, "t_start")
	assert_eq(server.tournament.event.phase, "running")
	return owner


func _by_member(pid: int) -> SgLocalClient:
	for client in clients:
		if int(client.state.get("tournament", {}).get("you", 0)) == pid: return client
	return null


func test_capacity_cleanup_preserves_the_disconnected_organiser_session() -> void:
	var owner := await _client("Organiser")
	await _open(owner)
	var owner_sid := server.tournament.organiser
	owner.set_process(false)
	owner._socket.close(-1)
	await _until(func() -> bool: return not server._connected(owner_sid))
	# Fill the roomless session cache, not the live connection limit. The
	# oldest entry is the reserved organiser and must never be scavenged.
	for i in SgLocalServer.MAX_SESSIONS - 1:
		var sid := 1000 + i
		server._sessions[sid] = {"peer": 0, "room": "", "seq": 0, "acks": {}, "nickname": "Expired",
			"disconnected_at": Time.get_ticks_msec(), "token_hash": str(sid).sha256_text()}
	var guest := await _client("Visitor")
	assert_true(guest.online)
	assert_true(server._sessions.has(owner_sid), "capacity cleanup must preserve tournament authority")
	owner.set_process(true)


func test_simultaneous_registration_and_readiness_do_not_conflict_between_players() -> void:
	var owner := await _client("Organiser")
	await _open(owner)
	var a := await _client("A")
	var b := await _client("B")
	for client in [a, b]: assert_true(client.command({"op": "t_join", "event": owner.state.tournament.id}))
	await _until(func() -> bool: return not a.busy() and not b.busy())
	for i in 4: await get_tree().process_frame
	assert_eq(server.tournament.event.entrants.size(), 2, "different entrants may register in the same frame")
	if server.tournament.event.entrants.size() != 2: return
	for client in [a, b]: assert_true(client.command({"op": "t_ready", "event": owner.state.tournament.id, "value": true}))
	await _until(func() -> bool: return not a.busy() and not b.busy())
	assert_true(server.tournament.event.entrants[0].ready)
	assert_true(server.tournament.event.entrants[1].ready, "different entrants may become ready in the same frame")
	assert_eq(refusals, [])
	await _act(owner, "t_start")
	await _act(a, "t_ready", {"value": true, "round": 0, "game": 0})
	assert_false(server.tournament.event.entrant(int(a.state.tournament.you)).ready, "an old registration click cannot ready a game")
	assert_eq(refusals.size(), 1)
	refusals.clear()
	for client in [a, b]: assert_true(client.command({"op": "t_ready", "event": owner.state.tournament.id, "value": true}))
	await _until(func() -> bool: return not a.busy() and not b.busy())
	assert_eq(server._rooms.size(), 1, "simultaneous game readiness opens exactly one table")
	assert_eq(refusals, [])


func test_twenty_entrants_and_separate_organiser_play_a_complete_knockout() -> void:
	var owner := await _register(20)
	assert_eq(server._sessions.size(), 21)
	for round_index in 5:
		var row: Array = server.tournament.event.rounds.back().duplicate(true)
		for pair: Dictionary in row:
			if pair.status == "bye": continue
			for pid: int in pair.players: await _act(_by_member(pid), "t_ready", {"value": true})
		assert_eq(server._rooms.size(), [4, 8, 4, 2, 1][round_index])
		assert_true(SgTournamentProtocol.view(owner.state.tournament), "the master accepts every live table")
		for pair: Dictionary in row:
			if pair.status == "bye": continue
			var a := _by_member(pair.players[0])
			var b := _by_member(pair.players[1])
			assert_eq(a.state.room.game.hand.size(), 7)
			assert_true(a.state.room.has("tournament"))
			assert_false(owner.state.has("hand"))
			assert_true(owner.state.room.is_empty(), "organiser cannot see a participant hand")
			await _act(b, "concede")
			await _act(a, "t_return")
			await _act(b, "t_return")
		assert_true(server._rooms.is_empty())
		if round_index < 4: await _act(owner, "t_next")
	assert_eq(server.tournament.event.phase, "complete")
	assert_gt(server.tournament.event.champion, 0)
	assert_eq(server.tournament.event.rounds.size(), 5)
	assert_eq(owner.state.tournament.tables.size(), 0)
	assert_eq(SgTournamentResults.standings(owner.state.tournament).size(), 20)
	assert_eq(SgTournamentResults.advancement(owner.state.tournament).links.size(), 30)
	assert_true(SgTournamentProtocol.checkpoint(server.tournament.event.checkpoint()))


func test_twenty_simultaneous_entrants_fill_registration_without_losing_ready_clicks() -> void:
	var owner := await _client("Organiser")
	await _open(owner, 1, "fixed", 20)
	var entrants: Array = []
	for i in 20: entrants.append(await _client("Entrant %d" % (i + 1)))
	for client: SgLocalClient in entrants:
		assert_true(client.command({"op": "t_join", "event": owner.state.tournament.id}))
	await _until(func() -> bool: return entrants.all(func(client: SgLocalClient) -> bool: return not client.busy()))
	assert_eq(server.tournament.event.entrants.size(), 20)
	for client: SgLocalClient in entrants:
		assert_true(client.command({"op": "t_ready", "event": owner.state.tournament.id, "value": true}))
	await _until(func() -> bool: return entrants.all(func(client: SgLocalClient) -> bool: return not client.busy()))
	for player: Dictionary in server.tournament.event.entrants: assert_true(player.ready)
	assert_eq(refusals, [])
	var late := await _client("Late visitor")
	await _act(late, "t_join")
	assert_eq(server.tournament.event.entrants.size(), 20)
	assert_eq(int(late.state.tournament.you), 0, "a twenty-first entrant stays an observer")
	assert_eq(refusals.size(), 1)
	assert_true(String(refusals[0]).contains("full"))
	refusals.clear()
	await _act(owner, "t_start")
	assert_eq(server.tournament.event.phase, "running")
	assert_eq(refusals, [])


func test_series_duplicate_concession_does_not_score_twice_and_next_game_is_fresh() -> void:
	await _register(2, 2)
	var pair: Dictionary = server.tournament.event.rounds[0][0]
	var a := _by_member(pair.players[0])
	var b := _by_member(pair.players[1])
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	var first_room: String = a.state.room.id
	assert_true(b.command({"op": "concede"}))
	var duplicate := b._pending_wire
	await _until(func() -> bool: return not b.busy())
	b._socket.send_text(duplicate)
	for i in 12: await get_tree().process_frame
	assert_eq(pair.wins, [1, 0])
	assert_eq(server.tournament.event.phase, "running")
	for client in [a, b]: await _act(client, "t_return")
	await _act(a, "t_ready", {"value": true, "round": 1, "game": 0})
	assert_false(server.tournament.event.entrant(int(a.state.tournament.you)).ready, "an old click cannot ready the next game in the same series")
	assert_eq(refusals.size(), 1)
	refusals.clear()
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	assert_ne(a.state.room.id, first_room)
	assert_eq(int(a.state.room.tournament.game), 2)
	assert_eq(a.state.room.game.hand.size(), 7)
	await _act(b, "concede")
	assert_eq(pair.wins, [2, 0])
	assert_eq(server.tournament.event.phase, "complete")


func test_authority_hidden_decks_recovery_and_organiser_forfeit() -> void:
	var owner := await _client("Same name")
	await _open(owner, 2, "own")
	var a := await _client("Same name")
	var b := await _client("Same name")
	for client in [a, b]:
		await _act(client, "t_join")
		await _act(client, "t_deck", {"name": "Private", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": ["Terror"]})
		await _act(client, "t_ready", {"value": true})
	var code: String = a.state.tournament.code
	var pid := int(a.state.tournament.you)
	assert_false(SgProtocol.encode(owner.state).contains("Savannah Lions"))
	assert_false(SgProtocol.encode(b.state).contains(code))
	assert_ne(a.state.tournament.code, b.state.tournament.code)
	await _act(a, "t_start")
	assert_eq(server.tournament.event.phase, "registration", "visitor cannot start event")
	await _act(owner, "t_start")
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	var room_id: String = a.state.room.id
	var cards: Array = a.state.room.game.hand.duplicate(true)
	a.forget()
	await _until(func() -> bool: return not server.tournament.connected(pid))
	var replacement := await _client("Same name")
	await _act(replacement, "t_recover", {"code": "a".repeat(64)})
	assert_eq(int(replacement.state.tournament.you), 0)
	await _act(replacement, "t_recover", {"code": code})
	assert_eq(int(replacement.state.tournament.you), pid)
	assert_eq(replacement.state.room.id, room_id)
	assert_eq(replacement.state.room.game.hand, cards)
	await _act(b, "t_remove", {"player": pid})
	assert_false(server.tournament.event.entrant(pid).withdrawn)
	await _act(owner, "t_remove", {"player": pid})
	assert_true(server.tournament.event.entrant(pid).withdrawn)
	assert_eq(server.tournament.event.rounds[0][0].wins, [0, 0])
	assert_eq(server.tournament.event.phase, "complete")


func test_host_restart_preserves_series_scores_and_reclaims_only_with_codes() -> void:
	var owner := await _register(2, 2)
	var pair: Dictionary = server.tournament.event.rounds[0][0]
	var a := _by_member(pair.players[0])
	var b := _by_member(pair.players[1])
	var code_a: String = a.state.tournament.code
	var code_b: String = b.state.tournament.code
	var old_id: String = server.tournament.event.id
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	await _act(b, "concede")
	for client in [a, b]: await _act(client, "t_return")
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	var path := scratch.path_join(old_id + ".json")
	var checkpoint := SgTournamentStore.read_checkpoint(path)
	assert_eq(checkpoint.rounds[0][0].wins, [1.0, 0.0])
	var encoded := SgProtocol.encode(checkpoint)
	for secret in [code_a, code_b, server.access_code, owner._resume, a._resume]: assert_false(encoded.contains(secret))
	server.stop()
	for client in clients: client.forget()
	await get_tree().process_frame
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)
	assert_eq(owner.connect_invitation(server.invitation(), "Organiser"), OK)
	await _until(func() -> bool: return owner.online)
	assert_eq(server.open_tournament({}, owner._resume, scratch, path), "")
	for client in [a, b]: assert_eq(client.connect_invitation(server.invitation(), "New display name"), OK)
	await _until(func() -> bool: return a.online and b.online and owner.state.has("tournament"))
	await _act(a, "t_recover", {"code": code_a})
	await _act(b, "t_recover", {"code": code_b})
	assert_true(a.state.room.is_empty())
	assert_eq(a.state.tournament.id, old_id)
	assert_eq(a.state.tournament.rounds[0][0].wins, [1.0, 0.0])
	assert_eq(a.state.tournament.entrants[0].name, "Entrant 1 (Guest 2)")
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	assert_false(a.state.room.is_empty(), "restored game starts: " + str(refusals))
	if a.state.room.is_empty(): return
	assert_eq(a.state.room.game.mode, "opening")
	assert_eq(int(a.state.room.tournament.game), 3, "interrupted attempt is not silently reused")
	await _act(b, "concede")
	assert_eq(server.tournament.event.phase, "complete")


func test_failed_save_blocks_advancement_and_retry_is_explicit() -> void:
	var owner := await _register(2)
	var pair: Dictionary = server.tournament.event.rounds[0][0]
	var a := _by_member(pair.players[0])
	var b := _by_member(pair.players[1])
	# A file cannot be used as a directory. This produces a checked return
	# code without modifying permissions or any real player folder.
	var blocked_path := scratch.path_join("blocked")
	var file := FileAccess.open(blocked_path, FileAccess.WRITE)
	file.store_string("test fixture")
	file.close()
	server.tournament.folder = blocked_path
	await _act(a, "t_ready", {"value": true})
	assert_false(server.tournament.save_error.is_empty())
	await _act(b, "t_ready", {"value": true})
	assert_true(server._rooms.is_empty())
	server.tournament.folder = scratch
	await _act(owner, "t_retry")
	assert_true(server.tournament.save_error.is_empty())
	await _act(b, "t_ready", {"value": true})
	assert_eq(server._rooms.size(), 1)
	await _act(owner, "t_cancel")
	assert_true(server._rooms.is_empty())
	assert_eq(server.tournament.event.phase, "cancelled")
	await _act(owner, "t_close")
	assert_null(server.tournament)
	assert_false(owner.state.has("tournament"))
	await _act(owner, "host", {"name": "Friendly duel", "decks": "own", "deck": {}})
	assert_false(owner.state.room.is_empty(), "ordinary hosting is still available")


func test_participating_organiser_keeps_host_alive_on_result_and_can_open_master_panel() -> void:
	var owner := await _client("Organiser")
	await _open(owner)
	var guest := await _client("Guest")
	for client in [owner, guest]:
		await _act(client, "t_join")
		await _act(client, "t_ready", {"value": true})
	await _act(owner, "t_start")
	for client in [owner, guest]: await _act(client, "t_ready", {"value": true})
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	viewport.add_child(screen)
	screen.present(owner.state.room, true, false, true)
	for i in 4: await get_tree().process_frame
	var tournament_button: Button
	for node in screen._qol_reserve.get_children():
		if node is Button and node.text == "Tournament": tournament_button = node
	assert_not_null(tournament_button)
	assert_false(tournament_button.get_global_rect().intersects(screen._log_button.get_global_rect()), "Tournament control cannot cover the duel log")
	watch_signals(screen)
	tournament_button.pressed.emit()
	assert_signal_emitted(screen, "tournament_requested")
	var panel := SgTournamentPanel.new()
	viewport.add_child(panel)
	panel.present(owner.state.tournament, true, false, true)
	assert_true(panel._view.organiser)
	assert_false(panel._own().is_empty(), "organiser is also an entrant")
	await _act(owner, "concede")
	screen.present(owner.state.room, true, false, true)
	screen._on_game_over_dismissed()
	assert_signal_emitted(screen, "hall_requested")
	assert_signal_not_emitted(screen, "exit_requested")
	assert_true(server._listener.is_listening())
	for i in 4: await get_tree().process_frame


func _campaign_record(kind: String, details: Dictionary) -> void:
	var entry := details.duplicate(true)
	entry.event = kind
	if campaign_journal != null:
		campaign_journal.store_line(JSON.stringify(entry))
		campaign_journal.flush()
	if kind != "command": print("SG tournament ", JSON.stringify(entry))


func _campaign_roster(count: int, seed_value: int, varied: bool) -> SgLocalClient:
	var owner := await _client("Organiser")
	await _open(owner, 1, "own" if varied else "fixed", maxi(8, count))
	# Referee-only draw seed. No seed or privileged observation goes to a bot.
	server.tournament.event._draw_game.rng.seed = seed_value
	var paths := ["white_knights", "black_red_raiders", "blue_skies", "big_green", "mountain_artillery",
		"1997/duels/merfolk_shaman", "1997/duels/goblin_warlord", "1997/duels/nether_fiend"]
	for i in count:
		var client := await _client("Pilot %d" % (i + 1))
		await _act(client, "t_join")
		if varied:
			var deck := DeckList.load_file("res://decks/%s.deck" % paths[i % paths.size()])
			assert_eq(deck.errors, [])
			await _act(client, "t_deck", {"name": deck.deck_name, "cards": Array(deck.cards), "sideboard": Array(deck.sideboard)})
		await _act(client, "t_ready", {"value": true})
	assert_eq(refusals, [])
	await _act(owner, "t_start")
	return owner


func test_full_games_through_parallel_tables_and_final_use_only_seat_views() -> void:
	var count := clampi(int(OS.get_environment("SG_TOURNAMENT_CAMPAIGN_PLAYERS")), 4, 20)
	var varied := OS.get_environment("SG_TOURNAMENT_CAMPAIGN_VARIETY") == "1"
	var faults := OS.get_environment("SG_TOURNAMENT_CAMPAIGN_FAULTS") == "1"
	var seed_value := 4242
	if not OS.get_environment("SG_TOURNAMENT_CAMPAIGN_SEED").is_empty(): seed_value = int(OS.get_environment("SG_TOURNAMENT_CAMPAIGN_SEED"))
	var journal_path := OS.get_environment("SG_TOURNAMENT_CAMPAIGN_LOG")
	if not journal_path.is_empty():
		campaign_journal = FileAccess.open(journal_path, FileAccess.WRITE)
		assert_not_null(campaign_journal)
		if campaign_journal == null: return
	server.duel_seed = seed_value
	server.vary_seeds = varied
	var owner := await _campaign_roster(count, seed_value, varied)
	var total_commands := 0
	var finished_games := 0
	var totals := {"submit": 0, "blockers": 0, "damage": 0, "choice": 0, "cancel": 0, "duplicate": 0, "lost_ack": 0}
	_campaign_record("start", {"players": count, "seed": seed_value, "varied": varied, "faults": faults})
	for round_index in SgTournament.MAX_ROUNDS:
		var row: Array = server.tournament.event.rounds.back().duplicate(true)
		var pilots := {}
		var played := {}
		for pair: Dictionary in row:
			if pair.status == "bye": continue
			pilots[pair.id] = [Pilot.new(), Pilot.new()]
			played[pair.id] = {"commands": 0, "seed": server.duel_seed}
			for pid: int in pair.players: await _act(_by_member(pid), "t_ready", {"value": true})
		var deadline := Time.get_ticks_msec() + 240000
		var finished := false
		while not finished and total_commands < 30000 and Time.get_ticks_msec() < deadline:
			finished = true
			for pair: Dictionary in row:
				if pair.status == "bye": continue
				var a := _by_member(pair.players[0])
				var b := _by_member(pair.players[1])
				if a.state.room.game.mode == "finished": continue
				finished = false
				var seat := int(a.state.room.game.actor)
				var client: SgLocalClient = a if seat == 0 else b
				# This pilot sees one authorised DTO only, never another client's
				# hand, the tournament checkpoint or the host referee.
				var action: Dictionary = pilots[pair.id][seat].choose(client.state.room.game.duplicate(true), seat)
				var before := refusals.size()
				var fault := ""
				if faults:
					if int(played[pair.id].commands) % 97 == 13: fault = "duplicate"
					elif int(played[pair.id].commands) % 193 == 35: fault = "lost_ack"
				if not fault.is_empty(): client.set_process(false)
				var accepted := client.command(action)
				assert_true(accepted, client.command_error)
				if not accepted:
					client.set_process(true)
					return
				if not fault.is_empty():
					totals[fault] += 1
					var pending := client._pending_wire
					await get_tree().create_timer(0.09).timeout
					if fault == "duplicate": assert_eq(client._socket.send_text(pending), OK)
					else:
						client._socket.close(-1)
						client.reconnect()
					client.set_process(true)
				if not await _until(func() -> bool: return a.online and b.online and not client.busy() \
					and a.state.room.revision == b.state.room.revision and a.state.room.connected == [true, true] and b.state.room.connected == [true, true]): return
				assert_eq(refusals.size(), before, str(refusals))
				var table := Pilot.public_table(a.state.room.game)
				assert_eq(table, Pilot.public_table(b.state.room.game))
				for peer in [a, b]: assert_true(SgViewProtocol.valid(peer.state))
				_campaign_record("command", {"round": round_index + 1, "pair": pair.id, "number": played[pair.id].commands,
					"seat": seat, "action": action, "fault": fault, "public_hash": JSON.stringify(table).sha256_text(), "refusals": refusals.slice(before)})
				if refusals.size() != before or table != Pilot.public_table(b.state.room.game): return
				if action.op in ["submit", "damage", "choice", "cancel"]: totals[action.op] += 1
				if action.op == "block": totals.blockers += action.pairs.size()
				await get_tree().create_timer(0.025).timeout
				total_commands += 1
				played[pair.id].commands += 1
				if total_commands % 250 == 0: print("SG tournament campaign seed=", seed_value, " commands=", total_commands)
		assert_true(finished, "every tournament game finishes within bounds")
		if not finished: return
		for pair: Dictionary in row:
			if pair.status == "bye": continue
			var room: Dictionary = _by_member(pair.players[0]).state.room
			_campaign_record("game_finished", {"round": round_index + 1, "pair": pair.id, "seed": played[pair.id].seed,
				"names": room.names, "decks": room.deck_names, "commands": played[pair.id].commands,
				"turn": room.game.turn, "winner": room.game.winner, "draw": room.game.draw,
				"life": [room.game.players[0].life, room.game.players[1].life]})
			for pid: int in pair.players: await _act(_by_member(pid), "t_return")
			finished_games += 1
		assert_true(server._rooms.is_empty(), "finished tournament tables are reclaimed")
		assert_eq(server._sessions.size(), count + 1, "reconnects reuse their entrant session")
		if server.tournament.event.phase == "complete": break
		await _act(owner, "t_next")
	assert_eq(server.tournament.event.phase, "complete")
	assert_eq(finished_games, count - 1)
	assert_eq(refusals, [])
	var standings := SgTournamentResults.standings(owner.state.tournament)
	assert_eq(standings.size(), count)
	assert_eq(standings[0].id, int(owner.state.tournament.champion))
	for peer: SgLocalClient in clients:
		assert_eq(SgTournamentResults.standings(peer.state.tournament), standings, "all players and organiser agree on final standings")
	var restored := SgTournament.new()
	assert_eq(restored.restore(SgTournamentStore.read_checkpoint(scratch.path_join(server.tournament.event.id + ".json"))), "")
	# Compare both through the wire representation: Godot's JSON numbers
	# are floats, whereas restored ledger IDs/scores are normalized integers.
	var restored_wire := SgProtocol.decode_payload(SgProtocol.encode(restored.checkpoint()).to_ascii_buffer())
	assert_eq(SgTournamentResults.advancement(restored_wire), SgTournamentResults.advancement(owner.state.tournament))
	if faults:
		assert_gt(totals.duplicate, 0)
		assert_gt(totals.lost_ack, 0)
	_campaign_record("complete", {"seed": seed_value, "games": finished_games, "commands": total_commands, "counts": totals, "standings": standings})


func test_lobby_configuration_opens_registration_without_creating_a_duel() -> void:
	var had_folder := Settings.has_value(GamePaths.KEY_TOURNAMENTS)
	var saved_folder: Variant = Settings.get_value(GamePaths.KEY_TOURNAMENTS, null) if had_folder else null
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	lobby.service = server
	lobby._code.text = server.invitation()
	lobby._connect_local()
	await _until(func() -> bool: return lobby.client.online)
	lobby._show_page("tournament")
	lobby._tournament_panel._name_edit.text = "UI Cup"
	lobby._tournament_panel._welcome_edit.text = "Welcome to our LAN cup!"
	lobby._tournament_panel._folder_edit.text = scratch
	lobby._tournament_panel._limit.select(4)
	lobby._tournament_panel._wins.select(2)
	lobby._tournament_panel.find_child("TournamentOpenRegistration", true, false).pressed.emit()
	await _until(func() -> bool: return server.tournament != null and lobby.client.state.has("tournament"))
	assert_eq(server.tournament.event.config.wins, 3)
	assert_eq(server.tournament.event.config.limit, 6)
	assert_eq(server.tournament.folder, scratch)
	assert_eq(server.tournament.event.config.welcome, "Welcome to our LAN cup!")
	assert_false(JSON.stringify(lobby.client.state).contains(scratch), "the save folder remains host-local")
	assert_true(server._rooms.is_empty())
	assert_eq(lobby._page, "tournament")
	# Delete only this test-created event's own checkpoint, not other saves.
	var path := GamePaths.tournaments_folder().path_join(server.tournament.event.id + ".json")
	lobby._open_master()
	assert_true(is_instance_valid(lobby._master_overlay))
	await _act(lobby.client, "t_cancel")
	assert_true(is_instance_valid(lobby._master_overlay), "cancellation remains visible until the organiser closes the event")
	await _act(lobby.client, "t_close")
	assert_false(is_instance_valid(lobby._master_overlay), "closing the event must close the expanded Master Panel")
	assert_true(lobby._tournament_panel._setup_built, "the ordinary Tournament page is ready to host a new event")
	lobby.client.forget()
	server.stop()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	if had_folder: Settings.set_value(GamePaths.KEY_TOURNAMENTS, saved_folder)
	else: Settings.clear_value(GamePaths.KEY_TOURNAMENTS)


func test_normal_browser_discovers_named_tournament_and_invited_player_joins_with_welcome() -> void:
	var owner := await _client("Organiser")
	var options := {"name": "Friday LAN Cup", "welcome": "Welcome, duelists! Please be ready at 19:00.",
		"limit": 8, "wins": 1, "policy": "own", "decks": []}
	assert_eq(server.open_tournament(options, owner._resume, scratch), "")
	var advertiser := SgLanDiscovery.new()
	server.add_child(advertiser)
	server.discovery = advertiser
	assert_eq(advertiser.advertise({"address": "127.0.0.1", "port": server.port, "name": "Organiser",
		"fingerprint": server._lan_pem.sha256_text(), "rooms": 0, "access": "invitation", "tables": [],
		"build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp()}, 0), OK)
	server.poll()
	var lobby := SgLobby.new()
	add_child_autofree(lobby)
	clients.append(lobby.client)
	lobby._show_page("browser")
	lobby._scan_lan()
	lobby._discovery.query("127.0.0.1", advertiser._socket.get_local_port())
	await _until(func() -> bool: return lobby._discovery.hosts.size() == 1)
	var discovered: Dictionary = lobby._discovery.hosts.values()[0].host
	assert_eq(discovered.tournament, options.name)
	assert_false(JSON.stringify(discovered).contains(server.access_code))
	assert_false(discovered.has("welcome"), "welcome is shared inside the invited hall, not broadcast")
	lobby._refresh()
	var rows := ""
	for label: Label in lobby._body.find_children("*", "Label", true, false): rows += label.text + "\n"
	assert_string_contains(rows, "Tournament · Friday LAN Cup")
	var listed: Button
	for button: Button in lobby._body.find_children("*", "Button", true, false):
		if button.text == "Join": listed = button
	assert_not_null(listed)
	if listed == null: return
	listed.pressed.emit()
	assert_eq(lobby._selected_host.tournament, options.name)
	assert_false(lobby.client.online, "discovery does not grant access")
	assert_true(lobby._window_open(), "an invitation-only tournament asks for its invitation")
	assert_string_contains(lobby._invite_prompt.text, "Organiser hosts by invitation only")
	lobby._code.text = server.invitation()
	lobby._connect_local()
	await _until(func() -> bool: return lobby.client.online and lobby.client.state.has("tournament"))
	for i in 6: await get_tree().process_frame
	assert_eq(lobby._page, "tournament")
	assert_eq(lobby.client.state.tournament.config.welcome, options.welcome)
	assert_false(JSON.stringify(lobby.client.state).contains(ProjectSettings.globalize_path(scratch)))
	var message := lobby._tournament_panel.find_child("TournamentWelcome", true, false) as Label
	assert_not_null(message)
	assert_eq(message.text, options.welcome)
	var join: Button
	for button: Button in lobby._tournament_panel.find_children("*", "Button", true, false):
		if button.text == "Join tournament": join = button
	assert_not_null(join)
	if join == null: return
	join.pressed.emit()
	await _until(func() -> bool: return int(lobby.client.state.tournament.you) != 0 and not lobby.client.busy())
	var entrant := int(lobby.client.state.tournament.you)
	assert_eq(server.tournament.event.entrants.size(), 1)
	lobby.client.reconnect()
	await _until(func() -> bool: return lobby.client.online)
	assert_eq(int(lobby.client.state.tournament.you), entrant)
	assert_eq(lobby.client.state.tournament.config.welcome, options.welcome)
	assert_eq(SgTournamentStore.read_checkpoint(scratch.path_join(server.tournament.event.id + ".json")).config.welcome, options.welcome)
	assert_true(lobby.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text == "Local network only"))
	assert_eq(refusals, [])


func test_duplicate_draw_hostile_views_and_approved_deck_enforcement() -> void:
	var owner := await _client("Organiser")
	await _open(owner, 1, "selection")
	var a := await _client("A")
	var b := await _client("B")
	for client in [a, b]:
		await _act(client, "t_join")
		await _act(client, "t_choose", {"index": 0})
		await _act(client, "t_ready", {"value": true})
	var old_deck: Dictionary = a.state.tournament.deck.duplicate(true)
	await _act(a, "t_deck", {"name": "Different deck", "cards": Array(StarterDecks.BLACK_RED_RAIDERS), "sideboard": []})
	assert_eq(a.state.tournament.deck, old_deck, "another deck cannot bypass an approved list")
	assert_true(owner.command({"op": "t_start", "event": owner.state.tournament.id}))
	var duplicate := owner._pending_wire
	await _until(func() -> bool: return not owner.busy())
	var rounds: Array = owner.state.tournament.rounds.duplicate(true)
	owner._socket.send_text(duplicate)
	for i in 12: await get_tree().process_frame
	assert_eq(owner.state.tournament.rounds, rounds, "published draw cannot be rerolled by a replay")
	var view: Dictionary = owner.state.tournament.duplicate(true)
	for key in view.keys():
		var broken := view.duplicate(true)
		broken.erase(key)
		assert_false(SgTournamentProtocol.view(broken), "required tournament view field " + key)
	view.entrants[0]["hand"] = ["Black Lotus"]
	assert_false(SgTournamentProtocol.view(view), "extra hidden fields are rejected")
	view = owner.state.tournament.duplicate(true)
	view.rounds[0][0].players[1] = view.rounds[0][0].players[0]
	assert_false(SgTournamentProtocol.view(view), "self-pairing cannot enter the UI")
	view = owner.state.tournament.duplicate(true)
	view.tables.append({"pair": 81, "life": [20, 20], "turn": 1, "step": "UNTAP"})
	assert_false(SgTournamentProtocol.view(view), "a phantom final table cannot enter a first-round view")
	view.tables[0].pair = view.rounds[0][0].id
	assert_false(SgTournamentProtocol.view(view), "a table cannot claim a game before readiness starts it")


func test_result_save_failure_is_not_acknowledged_as_durable_success() -> void:
	var owner := await _register(2)
	var pair: Dictionary = server.tournament.event.rounds[0][0]
	var a := _by_member(pair.players[0])
	var b := _by_member(pair.players[1])
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	var blocked := scratch.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("test fixture")
	file.close()
	server.tournament.folder = blocked
	await _act(b, "concede")
	assert_false(refusals.is_empty(), "unsaved result reports the storage failure")
	assert_eq(a.state.room.tournament.hold, "storage")
	assert_eq(pair.wins, [1, 0], "in-memory result is retained exactly once")
	var path := scratch.path_join(server.tournament.event.id + ".json")
	assert_eq(SgTournamentStore.read_checkpoint(path).rounds[0][0].wins, [0.0, 0.0])
	server.tournament.folder = scratch
	await _act(owner, "t_retry")
	assert_eq(a.state.room.tournament.hold, "")
	assert_eq(SgTournamentStore.read_checkpoint(path).rounds[0][0].wins, [1.0, 0.0])


func test_checkpoint_backup_survives_a_damaged_primary_and_recovery_save() -> void:
	var owner := await _register(2)
	var path := scratch.path_join(server.tournament.event.id + ".json")
	assert_true(FileAccess.file_exists(path + ".bak"))
	var backup := SgTournamentStore.read_checkpoint(path + ".bak")
	assert_false(backup.is_empty())
	# A primary that still reads as what this process wrote rotates on its
	# digest, without the read-back validation (2026-10-02); the damaged
	# one below no longer matches and is read back — and found wanting.
	assert_eq(SgTournamentStore._written.get(path, ""), FileAccess.get_sha256(path), "the digest of the last write")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{interrupted")
	file.close()
	assert_ne(SgTournamentStore._written.get(path, ""), FileAccess.get_sha256(path))
	assert_eq(SgTournamentStore.read_checkpoint(path), backup)
	assert_eq(server.tournament.save(), "")
	assert_eq(SgTournamentStore.read_checkpoint(path + ".bak"), backup, "bad primary did not replace the last good backup")
	assert_true(SgTournamentProtocol.checkpoint(SgTournamentStore.read_checkpoint(path)))
	assert_true(owner.online)


func test_master_panel_prints_the_host_answer_to_a_refused_organiser_control() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	lobby.service = server
	clients.append(lobby.client)
	lobby.client.refused.connect(func(reason: String) -> void: refusals.append(reason))
	assert_eq(lobby.client.connect_invitation(server.invitation(), "Organiser"), OK)
	await _until(func() -> bool: return lobby.client.online)
	assert_eq(server.open_tournament({"name": "LAN Cup", "limit": 8, "wins": 1, "policy": "fixed",
		"decks": [{"name": "Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]},
		lobby.client._resume, scratch), "")
	await _until(func() -> bool: return lobby.client.state.has("tournament"))
	for i in 3:
		var entrant := await _client("Entrant %d" % (i + 1))
		await _act(entrant, "t_join")
		await _act(entrant, "t_ready", {"value": true})
	await _act(lobby.client, "t_start")
	var pair: Dictionary = {}
	for row: Dictionary in server.tournament.event.rounds[0]:
		if row.status == "waiting": pair = row
	assert_false(pair.is_empty())
	if pair.is_empty(): return
	var a := _by_member(int(pair.players[0]))
	var b := _by_member(int(pair.players[1]))
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	await _act(b, "concede")
	for client in [a, b]: await _act(client, "t_return")
	assert_true(server.tournament.event.round_finished())
	lobby._open_master()
	for i in 4: await get_tree().process_frame
	# The expanded panel is opaque and covers the lobby notice line, so the
	# organiser must read the host's refusal inside the panel itself.
	var notice := lobby._master_overlay.find_child("MasterPanelNotice", true, false) as Label
	assert_not_null(notice, "the expanded Master Panel has somewhere to print the host answer")
	if notice == null: return
	a.forget()
	await _until(func() -> bool: return not server.tournament.connected(int(pair.players[0])))
	for i in 4: await get_tree().process_frame
	var draw: Button
	for button: Button in lobby._master_panel.find_children("*", "Button", true, false):
		if button.text == "Draw next round": draw = button
	assert_not_null(draw)
	if draw == null: return
	assert_false(draw.disabled, "every pairing has finished, so the draw is offered")
	refusals.clear()
	draw.pressed.emit()
	await _until(func() -> bool: return not lobby.client.busy())
	for i in 4: await get_tree().process_frame
	assert_eq(refusals, ["Wait for advancing players to reconnect, or withdraw them explicitly."])
	assert_eq(notice.text, "Wait for advancing players to reconnect, or withdraw them explicitly.")
	assert_eq(server.tournament.event.rounds.size(), 1, "the refused draw published no second round")
	refusals.clear()


func _tournament_lobby(name_value: String) -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	clients.append(lobby.client)
	lobby.client.refused.connect(func(reason: String) -> void: refusals.append(reason))
	assert_eq(lobby.client.connect_invitation(server.invitation(), name_value), OK)
	await _until(func() -> bool: return lobby.client.online)
	return lobby


func test_a_playing_organiser_reaches_the_master_panel_from_their_own_duel() -> void:
	var owner := await _tournament_lobby("Organiser")
	owner.service = server
	assert_eq(server.open_tournament({"name": "LAN Cup", "limit": 8, "wins": 1, "policy": "fixed",
		"decks": [{"name": "Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]},
		owner.client._resume, scratch), "")
	await _until(func() -> bool: return owner.client.state.has("tournament"))
	var guest := await _tournament_lobby("Guest")
	for lobby in [owner, guest]:
		await _act(lobby.client, "t_join")
		await _act(lobby.client, "t_ready", {"value": true})
	await _act(owner.client, "t_start")
	for lobby in [owner, guest]: await _act(lobby.client, "t_ready", {"value": true})
	await _until(func() -> bool: return not owner.client.state.room.is_empty() and not guest.client.state.room.is_empty())
	for i in 8: await get_tree().process_frame
	assert_true(is_instance_valid(owner._duel), "the organiser plays their own seat")
	if not is_instance_valid(owner._duel): return
	assert_eq(owner._duel._network_badge.text, "Tournament")
	assert_false(owner._duel._tournament_panel_open, "no panel covers the table yet")
	owner._duel._network_badge.pressed.emit()
	for i in 4: await get_tree().process_frame
	assert_true(is_instance_valid(owner._master_overlay), "the badge opens the panel without leaving the duel")
	assert_true(owner._master_panel._view.organiser)
	var captions := PackedStringArray()
	for button: Button in owner._master_panel.find_children("*", "Button", true, false): captions.append(button.text)
	assert_true(captions.has("Cancel tournament"), "the organiser keeps their controls inside their own duel")
	assert_true(owner._duel._tournament_panel_open)
	assert_true(owner._duel._modal_open(), "the organiser's table stands still behind the open panel")
	assert_eq(server._rooms.size(), 1, "the table and the host survive the open panel")
	assert_true(server._listener.is_listening())
	var back: Button
	for button: Button in owner._master_overlay.find_children("*", "Button", true, false):
		if button.text == "Back to duel": back = button
	assert_not_null(back)
	if back == null: return
	back.pressed.emit()
	for i in 4: await get_tree().process_frame
	assert_false(is_instance_valid(owner._master_overlay))
	assert_false(owner._duel._tournament_panel_open, "returning to the duel gives the seat back its clicks")
	# The other seat reaches the same hall and is given no organiser power.
	assert_true(is_instance_valid(guest._duel))
	if not is_instance_valid(guest._duel): return
	guest._duel._network_badge.pressed.emit()
	for i in 4: await get_tree().process_frame
	assert_true(is_instance_valid(guest._master_panel))
	assert_false(guest._master_panel._view.organiser)
	captions.clear()
	for button: Button in guest._master_panel.find_children("*", "Button", true, false): captions.append(button.text)
	for forbidden in ["Start tournament", "Draw next round", "Cancel tournament", "Retry save", "Withdraw"]:
		assert_false(captions.has(forbidden), "a guest is offered no organiser control: " + forbidden)
	assert_eq(refusals, [])


func _hall_of(halls: Array, pid: int) -> SgLobby:
	for lobby: SgLobby in halls:
		if int(lobby.client.state.get("tournament", {}).get("you", 0)) == pid: return lobby
	return null


func _show_entry(lobby: SgLobby) -> void:
	lobby._tournament_panel._choose_section("entry")


func _hall_line(lobby: SgLobby) -> String:
	var line := lobby._tournament_panel.find_child("TournamentEntryStatus", true, false) as Label
	assert_not_null(line, "a waiting player's hall states their own situation")
	return "" if line == null else line.text


func test_the_hall_tells_a_waiting_player_what_the_round_is_waiting_for() -> void:
	var owner := await _client("Organiser")
	await _open(owner, 1, "fixed", 8)
	var halls: Array = []
	for i in 4:
		var lobby := await _tournament_lobby("Entrant %d" % (i + 1))
		halls.append(lobby)
		await _act(lobby.client, "t_join")
		await _act(lobby.client, "t_ready", {"value": true})
	await _act(owner, "t_start")
	for lobby: SgLobby in halls: _show_entry(lobby)
	var first: Dictionary = server.tournament.event.rounds[0][0]
	var second: Dictionary = server.tournament.event.rounds[0][1]
	var winner := _hall_of(halls, int(first.players[0]))
	var loser := _hall_of(halls, int(first.players[1]))
	assert_not_null(winner)
	assert_not_null(loser)
	if winner == null or loser == null: return
	assert_eq(_hall_line(winner), "Round 1, table %d against %s. Select Ready for next game."
		% [SgTournament.table_number(int(first.id)), server.tournament.event.entrant(int(first.players[1])).name])
	for lobby in [winner, loser]: await _act(lobby.client, "t_ready", {"value": true})
	await _act(loser.client, "concede")
	for lobby in [winner, loser]: await _act(lobby.client, "t_return")
	for i in 6: await get_tree().process_frame
	assert_eq(_hall_line(winner), "You won your round 1 series. Waiting for the other tables to finish.")
	assert_eq(_hall_line(loser), "%s won your round 1 series. You are out of the tournament."
		% server.tournament.event.entrant(int(first.players[0])).name)
	# The other pairing finishes. Nobody at the first table touches anything:
	# the sentence has to change on its own.
	var third := _hall_of(halls, int(second.players[0]))
	var fourth := _hall_of(halls, int(second.players[1]))
	assert_not_null(third)
	assert_not_null(fourth)
	if third == null or fourth == null: return
	for lobby in [third, fourth]: await _act(lobby.client, "t_ready", {"value": true})
	await _act(fourth.client, "concede")
	for lobby in [third, fourth]: await _act(lobby.client, "t_return")
	for i in 6: await get_tree().process_frame
	assert_eq(_hall_line(winner), "You won your round 1 series. Waiting for the organiser to draw round 2.")
	assert_eq(winner._page, "tournament", "a waiting player sits in the hall, not on an empty screen")
	winner.client.reconnect()
	await _until(func() -> bool: return winner.client.online)
	for i in 8: await get_tree().process_frame
	assert_eq(winner._page, "tournament", "a reconnect lands back in the hall")
	assert_eq(_hall_line(winner), "You won your round 1 series. Waiting for the organiser to draw round 2.")
	await _act(owner, "t_next")
	for i in 6: await get_tree().process_frame
	var final_pair: Dictionary = server.tournament.event.rounds[1][0]
	var seat: int = 0 if int(final_pair.players[0]) == int(winner.client.state.tournament.you) else 1
	assert_eq(_hall_line(winner), "Round 2, table %d against %s. Select Ready for next game."
		% [SgTournament.table_number(int(final_pair.id)),
		server.tournament.event.entrant(int(final_pair.players[1 - seat])).name])
	assert_eq(_hall_line(loser), "You were knocked out. The hall stays open — the rest of the event is in Standings.")
	assert_eq(refusals, [])


func test_a_playing_organiser_pauses_every_table_from_their_own_duel_and_resumes_it() -> void:
	var owner := await _tournament_lobby("Organiser")
	owner.service = server
	assert_eq(server.open_tournament({"name": "LAN Cup", "limit": 8, "wins": 1, "policy": "fixed",
		"decks": [{"name": "Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]},
		owner.client._resume, scratch), "")
	await _until(func() -> bool: return owner.client.state.has("tournament"))
	var guest := await _tournament_lobby("Guest")
	var third := await _client("Third")
	var fourth := await _client("Fourth")
	for client in [owner.client, guest.client, third, fourth]:
		await _act(client, "t_join")
		await _act(client, "t_ready", {"value": true})
	await _act(owner.client, "t_start")
	assert_eq(server.tournament.event.rounds[0].size(), 2, "two tables to tell apart")
	var own_pair := server.tournament.event.pairing_for(int(owner.client.state.tournament.you))
	var mate := _by_member(int(own_pair.players[1 - own_pair.players.find(int(owner.client.state.tournament.you))]))
	for client in [owner.client, mate]: await _act(client, "t_ready", {"value": true})
	await _until(func() -> bool: return not owner.client.state.room.is_empty() and not mate.state.room.is_empty())
	for i in 8: await get_tree().process_frame
	assert_true(is_instance_valid(owner._duel))
	if not is_instance_valid(owner._duel): return
	owner._duel._network_badge.pressed.emit()
	for i in 4: await get_tree().process_frame
	var pause: Button
	for button: Button in owner._master_panel.find_children("*", "Button", true, false):
		if button.text == "Pause tournament": pause = button
	assert_not_null(pause, "the playing organiser finds the pause over their own table")
	if pause == null: return
	pause.pressed.emit()
	await _until(func() -> bool: return not owner.client.busy())
	for i in 6: await get_tree().process_frame
	assert_true(owner.client.state.tournament.paused)
	assert_eq(owner.client.state.room.tournament.hold, "organiser")
	assert_true(owner._duel.projection.locked, "the organiser's own table stands still too")
	assert_eq(owner._duel._connection_message(), "Tournament paused by the organiser. Play resumes when they continue the event.")
	var table: Dictionary = server._rooms.values()[0]
	var actor := int(table.match.decision_state().actor)
	var mover: SgLocalClient = owner.client if int(table.seats[actor]) == server.tournament.organiser else mate
	var refused_before := refusals.size()
	assert_true(mover.command({"op": "keep"}))
	await _until(func() -> bool: return not mover.busy())
	assert_eq(refusals.size(), refused_before + 1, "a game action at a paused table is refused")
	assert_eq(refusals.back(), SgTournamentHost.PAUSE_NOTICE)
	# The waiting pair readies up meanwhile: its table opens only on resume.
	for other: Dictionary in server.tournament.event.rounds[0]:
		if int(other.id) == int(own_pair.id): continue
		for pid: int in other.players: await _act(_by_member(pid), "t_ready", {"value": true})
	assert_eq(server._rooms.size(), 1, "no new table opens while the event is paused")
	await _act(mate, "t_pause")
	assert_eq(refusals.back(), "Only the organiser can use this control.")
	await _act(owner.client, "t_next")
	assert_eq(refusals.back(), "Resume the tournament before drawing the next round.")
	var resume: Button
	for button: Button in owner._master_panel.find_children("*", "Button", true, false):
		if button.text == "Resume tournament": resume = button
	assert_not_null(resume)
	if resume == null: return
	resume.pressed.emit()
	await _until(func() -> bool: return not owner.client.busy())
	for i in 6: await get_tree().process_frame
	assert_false(owner.client.state.tournament.paused)
	assert_eq(owner.client.state.room.tournament.hold, "")
	assert_eq(server._rooms.size(), 2, "the readied table opens the moment play resumes")
	refused_before = refusals.size()
	await _act(mover, "keep")
	assert_eq(refusals.size(), refused_before, "play continues where it stood")
	assert_true(server._listener.is_listening())


func test_the_organisers_ruling_ends_a_live_table_and_a_correction_is_flagged_everywhere() -> void:
	var owner := await _register(2, 2)
	var pair: Dictionary = server.tournament.event.rounds[0][0]
	var a := _by_member(pair.players[0])
	var b := _by_member(pair.players[1])
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	var table: Dictionary = server._rooms.values()[0]
	await _act(b, "t_rule", {"pair": int(pair.id), "winner": int(pair.players[1])})
	assert_eq(refusals.back(), "Only the organiser can use this control.")
	assert_eq(pair.status, "playing")
	await _act(owner, "t_rule", {"pair": int(pair.id), "winner": int(pair.players[1])})
	assert_eq(pair.status, "finished")
	assert_eq(pair.reason, "Organiser's ruling")
	assert_eq(pair.winner, pair.players[1])
	assert_eq(pair.wins, [0, 0], "no played win is invented")
	assert_true(table.match.game.game_over, "the live game ends with the ruling")
	assert_eq(server.tournament.event.phase, "complete")
	assert_eq(server.tournament.event.champion, pair.players[1])
	assert_eq(a.state.tournament.rounds[0][0].reason, "Organiser's ruling", "both seats see the flag")
	assert_eq(b.state.tournament.rounds[0][0].reason, "Organiser's ruling")
	var before := refusals.size()
	await _act(owner, "t_rule", {"pair": int(pair.id), "winner": int(pair.players[1])})
	assert_eq(refusals.size(), before + 1, "the recorded winner cannot be re-declared")
	await _act(owner, "t_rule", {"pair": int(pair.id), "winner": int(pair.players[0])})
	assert_eq(pair.reason, "Corrected by organiser")
	assert_eq(pair.winner, pair.players[0])
	assert_eq(server.tournament.event.champion, pair.players[0], "the championship follows the correction")
	var path := scratch.path_join(server.tournament.event.id + ".json")
	var saved := SgTournamentStore.read_checkpoint(path)
	assert_eq(saved.rounds[0][0].reason, "Corrected by organiser", "the flag is on disk")
	assert_eq(SgTournament.new().restore(saved), "", "and the checkpoint restores")
	for client in [a, b]: await _act(client, "t_return")
	assert_true(server._rooms.is_empty())
	await _act(owner, "t_close")
	assert_null(server.tournament)


func test_an_organiser_who_abandons_the_host_session_leaves_the_event_running_for_a_reclaim() -> void:
	var owner := await _register(2)
	var pair: Dictionary = server.tournament.event.rounds[0][0]
	var a := _by_member(pair.players[0])
	var b := _by_member(pair.players[1])
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	assert_eq(server._rooms.size(), 1)
	var room_id: String = a.state.room.id
	var hand: Array = a.state.room.game.hand.duplicate(true)
	var revision := int(a.state.tournament.revision)
	assert_eq(server.reclaim_tournament(a._resume), "The organiser is still connected.")
	# `forget` is the abandon message: the organiser's session and its
	# resume code are gone for good. The chair empties; the event, its
	# table and its checkpoint do not.
	owner.forget()
	assert_true(await _until(func() -> bool: return server.tournament.organiser == 0))
	assert_eq(server.tournament.event.phase, "running")
	assert_eq(server._rooms.size(), 1, "the table plays on")
	assert_true(await _until(func() -> bool: return int(a.state.tournament.revision) > revision))
	assert_eq(a.state.room.id, room_id, "the entrants are still at their table")
	assert_eq(a.state.room.game.hand, hand)
	assert_eq(SgTournamentStore.read_checkpoint(scratch.path_join(server.tournament.event.id + ".json")).phase, "running")
	# The host's own lobby takes the chair back with the session it holds
	# now — the local entry point, never a wire command — and the controls
	# answer again. Nothing at the table moved.
	var back := await _client("Organiser")
	await _act(back, "t_pause")
	assert_eq(refusals.back(), "Only the organiser can use this control.")
	assert_eq(server.reclaim_tournament(back._resume), "")
	assert_true(await _until(func() -> bool: return bool(back.state.tournament.organiser)))
	await _act(back, "t_pause")
	assert_true(server.tournament.paused, str(refusals))
	assert_eq(a.state.room.id, room_id)
	assert_eq(server.reclaim_tournament(a._resume), "The organiser is still connected.")


func test_the_hosts_own_lobby_takes_an_empty_organiser_chair_back() -> void:
	var owner := await _register(2)
	owner.forget()
	assert_true(await _until(func() -> bool: return server.tournament.organiser == 0))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	lobby.service = server
	clients.append(lobby.client)
	assert_eq(lobby.client.connect_invitation(server.invitation(), "Organiser"), OK)
	assert_true(await _until(func() -> bool: return bool(lobby.client.state.get("tournament", {}).get("organiser", false))))
	assert_eq(lobby._notice.text, "Tournament controls recovered for this seat.")
	assert_eq(server.tournament.event.phase, "running")
	# An entrant's lobby has no service of its own and never reaches the
	# entry point; the hall it sees is the same running event.
	var hall := await _tournament_lobby("Visitor")
	assert_null(hall.service)
	assert_false(bool(hall.client.state.tournament.organiser))
	assert_true(bool(lobby.client.state.tournament.organiser))


func test_an_organiser_who_abandons_a_cancelled_event_leaves_a_chair_the_host_takes_back_to_close_it() -> void:
	# The chair of a finished or cancelled event used to stay with the
	# erased session (2026-10-02): nobody could Close, and every host or
	# join on this service answered "Use the Tournament Hall" for good.
	var owner := await _register(2)
	await _act(owner, "t_cancel")
	assert_eq(server.tournament.event.phase, "cancelled")
	owner.forget()
	assert_true(await _until(func() -> bool: return server.tournament.organiser == 0), "the chair empties on a cancelled event too")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	lobby.service = server
	clients.append(lobby.client)
	assert_eq(lobby.client.connect_invitation(server.invitation(), "Organiser"), OK)
	assert_true(await _until(func() -> bool: return bool(lobby.client.state.get("tournament", {}).get("organiser", false))),
		"the host's own lobby takes the chair of the cancelled event back")
	await _act(lobby.client, "t_close")
	assert_null(server.tournament, "and Close is reachable again")
	assert_eq(server.reclaim_tournament(lobby.client._resume), "No tournament is under way on this host.")


func test_the_hosts_network_drop_keeps_the_tournament_saved_and_resumable() -> void:
	# The host's own network goes away for longer than any duel's reconnect
	# grace: every connection is lost at once, the organiser's included.
	# Nothing expires and nothing restarts — the sessions are held for their
	# resume codes, the checkpoint on disk is current, and when the network
	# is back every seat is where it was, hands and controls included.
	var owner := await _register(2, 2)
	var pair: Dictionary = server.tournament.event.rounds[0][0]
	var a := _by_member(pair.players[0])
	var b := _by_member(pair.players[1])
	for client in [a, b]: await _act(client, "t_ready", {"value": true})
	var room_id: String = a.state.room.id
	var hands := [a.state.room.game.hand.duplicate(true), b.state.room.game.hand.duplicate(true)]
	var sids := [server.tournament.organiser, int(server.tournament.bindings[pair.players[0]]),
		int(server.tournament.bindings[pair.players[1]])]
	for client in [owner, a, b]:
		client.set_process(false)
		client._socket.close(-1)
	for sid in sids: assert_true(await _until(func() -> bool: return not server._connected(sid)))
	var now := Time.get_ticks_msec()
	for sid in sids: server._sessions[sid].disconnected_at = now - SgLocalServer.RECONNECT_GRACE_MS - 1
	server._expire_disconnected(now)
	for sid in sids: assert_true(server._sessions.has(sid), "a tournament seat is held past the duel grace")
	assert_eq(server.tournament.event.phase, "running")
	assert_eq(server._rooms.size(), 1, "the table waits")
	var checkpoint := SgTournamentStore.read_checkpoint(scratch.path_join(server.tournament.event.id + ".json"))
	assert_eq(checkpoint.phase, "running")
	assert_eq(checkpoint.entrants.size(), 2)
	for client in [owner, a, b]:
		client.set_process(true)
		client._retry_at = 0
	# Each client notices its dead socket first, then resumes its own seat.
	assert_true(await _until(func() -> bool: return not (owner.online or a.online or b.online)))
	assert_true(await _until(func() -> bool: return owner.online and a.online and b.online))
	assert_true(await _until(func() -> bool: return not a.state.room.is_empty() and not b.state.room.is_empty()))
	assert_eq(a.state.room.id, room_id, "the same table, not a new game")
	assert_eq([a.state.room.game.hand, b.state.room.game.hand], hands)
	assert_true(bool(owner.state.tournament.organiser), "the organiser's seat came back with its controls")
	await _act(owner, "t_pause")
	assert_true(server.tournament.paused, str(refusals))
	await _act(owner, "t_resume")
	assert_false(server.tournament.paused)


func test_a_failed_save_still_lets_the_organiser_cancel_and_close() -> void:
	var owner := await _register(2)
	var pair: Dictionary = server.tournament.event.rounds[0][0]
	var a := _by_member(pair.players[0])
	var blocked := scratch.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("test fixture")
	file.close()
	server.tournament.folder = blocked
	await _act(a, "t_ready", {"value": true})
	assert_false(server.tournament.save_error.is_empty())
	await _act(owner, "t_next")
	assert_eq(refusals.back(), server.tournament.save_error, "advancement still waits on storage")
	# Storage that never comes back must not trap the event: cancel takes
	# effect in memory (the save of it fails and says so), and close follows.
	await _act(owner, "t_cancel")
	assert_eq(server.tournament.event.phase, "cancelled")
	assert_true(server._rooms.is_empty())
	await _act(owner, "t_close")
	assert_true(await _until(func() -> bool: return server.tournament == null))
	assert_true(await _until(func() -> bool: return not owner.state.has("tournament")))
