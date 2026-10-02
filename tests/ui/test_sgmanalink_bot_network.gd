extends GutTest
## Real TLS clients control rooms/events; genuine engine players occupy bots.

var server: SgLocalServer
var clients: Array[SgLocalClient] = []
var scratch := ""
var refusals: Array = []

class SeededServer extends SgLocalServer:
	var next_seed := 4250
	var rate_drops := 0
	func _drop(id: int) -> void:
		if _peers.has(id) and int(_peers[id].count) > 64:
			rate_drops += 1
			print("BOT RATE LIMIT: ", _peers[id].count, " commands in one second")
		super._drop(id)
	func _create_match(decks: Array, names: Array, rules: Dictionary = {}) -> SgPracticeMatch:
		var result := SgPracticeMatch.new(next_seed, decks, names, rules)
		next_seed += 1
		return result


func before_each() -> void:
	clients.clear()
	refusals.clear()
	scratch = "user://tournament-tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	server = SeededServer.new()
	server.bot_pace_override = 0
	add_child_autofree(server)
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)


func after_each() -> void:
	for client in clients: client.forget()
	server.stop()
	for i in 3: await get_tree().process_frame
	var dir := DirAccess.open(scratch)
	if dir != null:
		for filename in dir.get_files(): dir.remove(filename)
		DirAccess.remove_absolute(scratch)


func _until(predicate: Callable, frames := 800) -> bool:
	for i in frames:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "network bot operation exceeded its frame budget")
	return false


func _client(nickname := "Organiser") -> SgLocalClient:
	var client := SgLocalClient.new()
	add_child_autofree(client)
	clients.append(client)
	client.refused.connect(func(reason: String) -> void: refusals.append(reason))
	assert_eq(client.connect_invitation(server.invitation(), nickname), OK)
	await _until(func() -> bool: return client.online)
	return client


func _act(client: SgLocalClient, action: Dictionary) -> void:
	assert_true(client.command(action), client.command_error)
	await _until(func() -> bool: return not client.busy())
	for i in 3: await get_tree().process_frame
	assert_true(client.online, client.status)
	assert_true(SgViewProtocol.valid(client.state))


func _deck(path := "res://decks/white_knights.deck") -> Dictionary:
	var deck := DeckList.load_file(path)
	assert_eq(deck.errors.size(), 0)
	return {"name": deck.deck_name, "cards": Array(deck.cards), "sideboard": Array(deck.sideboard)}


func _open(owner: SgLocalClient, wins := 1, policy := "fixed", limit := 8) -> void:
	var options := {"name": "Wizard Cup", "limit": limit, "wins": wins, "policy": policy,
		"decks": [] if policy == "own" else [_deck()]}
	assert_eq(server.open_tournament(options, owner._resume, scratch), "")
	server.tournament.event._draw_game.rng.seed = 4250
	await _until(func() -> bool: return owner.state.has("tournament"))


func test_room_bot_is_a_real_wizard_private_pausable_and_cleaned_after_departure() -> void:
	var player := await _client("Player")
	await _act(player, {"op": "host", "name": "Computer duel", "decks": "own", "deck": {}})
	await _act(player, {"op": "add_bot", "bot": SgBotPlayer.defaults(), "deck": _deck()})
	assert_eq(int(player.state.room.bots[1].level), 3)
	assert_eq(player.state.room.ready, [false, true])
	assert_true(server._tokens.size() == 1, "bot has no bearer capability")
	var deck := _deck()
	deck.op = "deck"
	await _act(player, deck)
	assert_eq(player.state.room.ready, [false, true], "human deck selection must not unready the bot forever")
	await _act(player, {"op": "ready", "value": true})
	var room: Dictionary = server._rooms.values()[0]
	assert_true(room.match.bots[1] is AiPlayer)
	assert_false(room.match.bots[1] is UnfairPlayer)
	assert_eq(player.state.room.game.players[1].revealed, [])
	await _act(player, {"op": "remove_bot"})
	assert_eq(refusals.size(), 1, "bot settings cannot change during play")
	refusals.clear()
	player.set_process(false)
	player._socket.close(-1)
	await _until(func() -> bool: return not server._connected(room.seats[0]))
	var generation: int = room.match.state_generation
	for i in 30: await get_tree().process_frame
	assert_eq(room.match.state_generation, generation, "bot pauses for disconnected human")
	player.set_process(true)
	player.reconnect()
	await _until(func() -> bool: return player.online)
	await _act(player, {"op": "concede"})
	await _act(player, {"op": "leave"})
	await _until(func() -> bool: return server._rooms.is_empty() and server._sessions.size() == 1)
	assert_eq(refusals, [])


func test_only_organiser_can_fill_seats_and_bot_settings_survive_restart() -> void:
	var owner := await _client()
	var guest := await _client("Guest")
	await _open(owner, 2)
	var action := {"op": "t_bots", "event": owner.state.tournament.id, "count": 2,
		"bot": SgBotPlayer.defaults(), "deck": _deck()}
	await _act(guest, action)
	assert_eq(server.tournament.event.entrants.size(), 0)
	assert_eq(refusals.size(), 1)
	refusals.clear()
	action.bot.unfair = true
	await _act(owner, action)
	assert_eq(server.tournament.event.entrants.size(), 2)
	assert_true(owner.state.tournament.entrants[0].bot.unfair)
	assert_eq(owner.state.tournament.code, "")
	await _act(owner, {"op": "t_start", "event": action.event})
	await _until(func() -> bool: return server._rooms.size() == 1)
	var path := scratch.path_join(String(action.event) + ".json")
	server.stop()
	for client in clients: client.forget()
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)
	var resumed := await _client("Returning organiser")
	assert_eq(server.open_tournament({}, resumed._resume, scratch, path), "")
	await _until(func() -> bool: return server._rooms.size() == 1)
	assert_eq(server.tournament.event.entrants.size(), 2)
	assert_eq(server._sessions.size(), 3)
	var room: Dictionary = server._rooms.values()[0]
	for pid in 2:
		assert_true(room.match.bots[pid] is UnfairPlayer)
	assert_eq(server._tokens.size(), 1)
	assert_eq(refusals, [])


func test_restore_refuses_insufficient_bot_capacity_without_installing_a_partial_event() -> void:
	var owner := await _client()
	await _open(owner)
	var event_id: String = owner.state.tournament.id
	await _act(owner, {"op": "t_bots", "event": event_id, "count": 2,
		"bot": SgBotPlayer.defaults(), "deck": _deck()})
	var path := scratch.path_join(event_id + ".json")
	server.stop()
	owner.forget()
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)
	var resumed := await _client()
	# Synchronous capacity fixture: do not let a poll expire the disconnected
	# guests before testing whether the restore is all-or-nothing.
	while server._sessions.size() < SgLocalServer.MAX_SESSIONS - 1:
		var sid := server._next_session
		server._next_session += 1
		server._sessions[sid] = {"peer": 0, "token_hash": "", "room": "", "seat": -1,
			"nickname": "Guest", "seen": Time.get_ticks_msec()}
	var error := server.open_tournament({}, resumed._resume, scratch, path)
	assert_false(error.is_empty(), "restore needs capacity for every saved computer player")
	assert_null(server.tournament, "failed restore must not install an event with missing bots")
	# Remove only the synthetic entries before normal network polling resumes.
	for sid in server._sessions.keys():
		if int(server._sessions[sid].peer) == 0: server._sessions.erase(sid)
	assert_eq(refusals, [])


func test_eight_real_wizards_complete_a_tournament_and_publish_final_standings() -> void:
	var owner := await _client()
	await _open(owner, 1, "own")
	var event := server.tournament.event
	for path in ["white_knights", "black_red_raiders", "blue_skies", "big_green",
		"mountain_artillery", "white_knights", "blue_skies", "big_green"]:
		await _act(owner, {"op": "t_bots", "event": event.id, "count": 1,
			"bot": SgBotPlayer.defaults(), "deck": _deck("res://decks/%s.deck" % path)})
	assert_eq(event.entrants.size(), 8)
	assert_eq(server._sessions.size(), 9)
	assert_eq(server._tokens.size(), 1)
	for round_index in 3:
		await _act(owner, {"op": "t_start" if round_index == 0 else "t_next", "event": event.id})
		if not await _until(func() -> bool: return event.round_finished() and server._rooms.is_empty(), 5000): return
		for pair: Dictionary in event.rounds.back():
			assert_eq(pair.status, "finished")
			assert_eq(pair.reason, "Series won")
			assert_eq(int(pair.wins[0]) + int(pair.wins[1]), 1)
			print("WIZARD CUP seed-base=4250 round=%d pair=%d winner=%s games=%d draws=%d" % [
				round_index + 1, int(pair.id), event.entrant(pair.winner).name, int(pair.game), int(pair.draws)])
		assert_true(SgTournamentProtocol.checkpoint(event.checkpoint()))
	await _until(func() -> bool: return owner.state.tournament.phase == "complete")
	assert_eq(event.phase, "complete")
	assert_gt(event.champion, 0)
	assert_eq(event.rounds.size(), 3)
	assert_true(SgTournamentProtocol.view(owner.state.tournament))
	assert_true(owner.state.room.is_empty(), "organiser receives no private hand")
	var standings := SgTournamentResults.standings(owner.state.tournament)
	assert_eq(standings.size(), 8)
	assert_eq(standings[0].place, 1)
	assert_eq(standings[0].series_won, 3)
	assert_eq(refusals, [])
	await _act(owner, {"op": "t_close", "event": event.id})
	await _until(func() -> bool: return server._sessions.size() == 1)


func test_human_bot_series_waits_for_the_human_and_save_failure_pauses_bot_play() -> void:
	var player := await _client("Player")
	await _open(player, 2)
	var event := server.tournament.event
	await _act(player, {"op": "t_join", "event": event.id})
	await _act(player, {"op": "t_ready", "event": event.id, "value": true})
	await _act(player, {"op": "t_bots", "event": event.id, "count": 1, "bot": SgBotPlayer.defaults(), "deck": _deck()})
	await _act(player, {"op": "t_start", "event": event.id})
	assert_true(server._rooms.is_empty(), "bot does not ready the human")
	await _act(player, {"op": "t_ready", "event": event.id, "value": true})
	await _until(func() -> bool: return not player.state.room.is_empty())
	# The human seat's commands travel through TLS; the real Wizard remains
	# installed on the other side. This test pilot stands in only for clicks.
	var pilot = preload("res://tests/support/sg_network_pilot.gd").new()
	var commands := 0
	var sent_revision := -1
	var next_command_ms := 0
	for i in 4000:
		if player.state.room.game.mode == "finished": break
		var view: Dictionary = player.state.room.game
		# Match SgDuelView's ACK + newer-snapshot gate. An ACK alone can
		# arrive before its state frame; acting on that old view repeats a click.
		# The zero-delay server test override must not make this click driver
		# exceed the unchanged 64 messages/s abuse limit (reproduced at 65).
		if not player.busy() and int(player.state.room.revision) > sent_revision and view.actor == player.state.room.seat \
			and Time.get_ticks_msec() >= next_command_ms:
			sent_revision = int(player.state.room.revision)
			next_command_ms = Time.get_ticks_msec() + 40
			assert_true(player.command(pilot.choose(view, int(player.state.room.seat))))
			commands += 1
		await get_tree().process_frame
	assert_eq(player.state.room.game.mode, "finished", "mixed human-command/Wizard game completes")
	assert_gt(commands, 20)
	assert_eq(server.rate_drops, 0)
	assert_eq(refusals, [])
	await _act(player, {"op": "t_return", "event": event.id})
	assert_true(server._rooms.is_empty())
	assert_eq(event.phase, "running", "first-to-two needs another game")
	var blocked := scratch.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("test fixture")
	file.close()
	server.tournament.folder = blocked
	await _act(player, {"op": "t_ready", "event": event.id, "value": true})
	assert_false(server.tournament.save_error.is_empty())
	for i in 20: await get_tree().process_frame
	assert_true(server._rooms.is_empty(), "no bot game starts on an unsaved result/readiness")
	server.tournament.folder = scratch
	refusals.clear()
	await _act(player, {"op": "t_retry", "event": event.id})
	await _until(func() -> bool: return not player.state.room.is_empty())
	assert_eq(int(player.state.room.tournament.game), 2)
	assert_true(server._rooms.values()[0].match.bots.size() == 1)
	await _act(player, {"op": "concede"})
	await _act(player, {"op": "t_return", "event": event.id})
	if event.phase == "running": await _act(player, {"op": "t_cancel", "event": event.id})
	await _act(player, {"op": "t_close", "event": event.id})
	assert_true(server._rooms.is_empty())
	assert_eq(refusals, [])


func test_full_capacity_mixed_levels_and_removing_registration_bots_releases_sessions() -> void:
	var owner := await _client()
	await _open(owner, 1, "fixed", 20)
	var event := server.tournament.event
	for level in 4:
		var options := SgBotPlayer.defaults()
		options.level = level
		await _act(owner, {"op": "t_bots", "event": event.id, "count": 5, "bot": options, "deck": _deck()})
	assert_eq(event.entrants.size(), 20)
	assert_eq(server._sessions.size(), 21)
	await _act(owner, {"op": "t_bots", "event": event.id, "count": 1, "bot": SgBotPlayer.defaults(), "deck": _deck()})
	assert_eq(event.entrants.size(), 20)
	assert_eq(refusals.size(), 1)
	refusals.clear()
	await _act(owner, {"op": "t_remove", "event": event.id, "player": event.entrants[0].id})
	assert_eq(event.entrants.size(), 19)
	await _until(func() -> bool: return server._sessions.size() == 20)
	await _act(owner, {"op": "t_start", "event": event.id})
	await _until(func() -> bool: return server._rooms.size() == 3)
	for room: Dictionary in server._rooms.values():
		for pid in 2:
			var options: Dictionary = room.match.bot_options[pid]
			assert_eq(room.match.bots[pid].profile.profile_name, SgBotPlayer.LEVELS[int(options.level)])
	await _act(owner, {"op": "t_cancel", "event": event.id})
	await _act(owner, {"op": "t_close", "event": event.id})
	await _until(func() -> bool: return server._sessions.size() == 1)
	assert_eq(refusals, [])


func test_failed_bot_readiness_save_cannot_advance_another_live_table() -> void:
	var owner := await _client()
	await _open(owner, 2)
	var event := server.tournament.event
	await _act(owner, {"op": "t_bots", "event": event.id, "count": 4, "bot": SgBotPlayer.defaults(), "deck": _deck()})
	await _act(owner, {"op": "t_start", "event": event.id})
	await _until(func() -> bool: return server._rooms.size() == 2)
	var rooms := server._rooms.values()
	assert_eq(rooms[0].match.game.concede(0), "")
	assert_eq(server.tournament.collect_result(rooms[0]), "")
	var generation: int = rooms[1].match.state_generation
	var revision: int = rooms[1].revision
	# Bot return/readiness attempts the failing save inside this very poll,
	# before the scheduler would otherwise act at the other live table.
	var blocked := scratch.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("test fixture")
	file.close()
	server.tournament.folder = blocked
	server._poll_bots(Time.get_ticks_msec() + 2000)
	assert_false(server.tournament.save_error.is_empty())
	assert_eq(rooms[1].match.state_generation, generation, "failed bot-readiness save pauses the other live game immediately")
	assert_eq(rooms[1].revision, revision, "no bot action may follow the failed save in this poll")
	await _until(func() -> bool: return int(owner.state.tournament.revision) == event.revision)
	server.tournament.folder = scratch
	await _act(owner, {"op": "t_retry", "event": event.id})
	await _act(owner, {"op": "t_cancel", "event": event.id})
	assert_eq(refusals, [])
