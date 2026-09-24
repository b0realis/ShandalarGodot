class_name SgTournamentHost
extends Node
## Tournament orchestration on the host only. Never instantiated by a client.

## Why every table stands still, as one word on the duel wire: "" when play
## is open, "storage" while a save has failed, "organiser" during their pause.
const HOLDS := ["", "storage", "organiser"]
const PAUSE_NOTICE := "The organiser paused the tournament. Every table stands still until the organiser resumes play."
var event: SgTournament
var organiser := 0
var bindings: Dictionary = {} # entrant -> temporary session; not persisted
var codes: Dictionary = {} # session -> its own plaintext recovery code; memory only
var folder := ""
var save_error := ""
var paused := false # the organiser's own pause; memory only, a host restart lifts it


func server() -> SgLocalServer:
	return get_parent() as SgLocalServer


func member(sid: int) -> int:
	if sid == 0: return 0
	for pid: int in bindings:
		if bindings[pid] == sid: return pid
	return 0


func holds(sid: int) -> bool:
	return sid == organiser or member(sid) != 0


func connected(pid: int) -> bool:
	return server()._connected(int(bindings.get(pid, 0)))


func save() -> String:
	var result := SgTournamentStore.save(event, folder)
	save_error = "" if result == OK else "Progress could not be saved. Tournament play is paused. Check storage, then Retry save in the Master Panel."
	return save_error


## The reason no table may move right now, or "" while play is open. A failed
## save comes first: it is the one the organiser has to act on in storage.
func hold() -> String:
	if not save_error.is_empty(): return save_error
	if paused: return PAUSE_NOTICE
	return ""


func restore_bots() -> void:
	for player: Dictionary in event.entrants:
		if not player.has("bot") or player.withdrawn or bindings.has(player.id): continue
		bindings[player.id] = server()._new_bot(player.bot, player.name)


func prepare_bots() -> void:
	if not hold().is_empty(): return
	var changed := false
	for player: Dictionary in event.entrants:
		if not player.has("bot"): continue
		var sid := int(bindings.get(player.id, 0))
		if not server()._is_bot(sid): continue
		var session: Dictionary = server()._sessions[sid]
		var room: Dictionary = server()._rooms.get(session.room, {})
		if not room.is_empty() and room.match != null and room.match.game.game_over:
			session.room = ""
			changed = true
		var pair := event.pairing_for(player.id)
		if not player.withdrawn and not player.ready and session.room.is_empty() \
			and (event.phase == "registration" or (event.phase == "running" and pair.get("status", "") == "waiting")):
			event.set_ready(player.id, true)
			changed = true
	retire_empty_tables()
	if changed:
		if save().is_empty(): launch_ready_games()
		server()._publish("*", 0, true)


func command(sid: int, action: Dictionary, revision: int) -> String:
	var op: String = action.op
	# Commands concerning separate entrants may arrive together. Global
	# revision equality rejected the second Join/Ready in the same frame.
	# Destructive organiser controls retain exact revision checks; readiness
	# additionally names its own round/game so an old click cannot ready a rematch.
	var independent: bool = op in ["t_join", "t_recover", "t_deck", "t_choose", "t_ready", "t_return"]
	if action.event != event.id or revision > event.revision or (not independent and revision != event.revision):
		return "The tournament changed. Review the hall and try again."
	var pid := member(sid)
	var room: Dictionary = server()._rooms.get(server()._sessions[sid].room, {})
	if op in ["t_start", "t_next", "t_remove", "t_cancel", "t_retry", "t_clear", "t_close", "t_bots", "t_pause", "t_resume", "t_rule"] and sid != organiser:
		return "Only the organiser can use this control."
	if op == "t_retry":
		var error := save()
		if error.is_empty(): launch_ready_games()
		server()._publish("", 0, true)
		return error
	if op == "t_return":
		if room.is_empty() or not room.has("t_pair") or room.match == null or not room.match.game.game_over:
			return "Finish the game before returning to the hall."
		server()._sessions[sid].room = ""
		retire_empty_tables()
		server()._publish("", 0, true)
		return ""
	# A failed save holds play, not the way out: cancelling and closing are
	# how the organiser ends an event whose storage will not come back.
	if not save_error.is_empty() and op not in ["t_cancel", "t_close"]: return save_error
	if op == "t_close":
		if event.phase not in ["complete", "cancelled"] or not server()._rooms.is_empty():
			return "Finish or cancel the tournament and return all tables to the hall first."
		server().tournament = null
		server()._publish("*", 0, true)
		queue_free()
		return ""
	var error := ""
	match op:
		"t_bots":
			if server()._sessions.size() + int(action.count) > SgLocalServer.MAX_SESSIONS: return "Host is full."
			error = event.register_bots(int(action.count), action.bot, action.deck)
			if error.is_empty(): restore_bots()
		"t_clear":
			for session: Dictionary in server()._sessions.values():
				var table: Dictionary = server()._rooms.get(session.room, {})
				if table.has("t_pair") and table.match.game.game_over: session.room = ""
			retire_empty_tables()
			event.revision += 1
		"t_join":
			if pid != 0 or not room.is_empty(): return "Leave your duel or recover your existing tournament entry."
			var code := Crypto.new().generate_random_bytes(32).hex_encode()
			if not SgProtocol.token(code): return "Cannot generate a private recovery code. Try again."
			pid = event.register(server()._guest_name(sid), code.sha256_text())
			if pid == 0: return "Registration is closed or the tournament is full."
			bindings[pid] = sid
			codes[sid] = code
		"t_recover":
			if pid != 0 or not room.is_empty(): return "This session already has an entry or a duel."
			var recovered := 0
			for player: Dictionary in event.entrants:
				if not player.has("bot") and player.recovery_hash == String(action.code).sha256_text() and not player.withdrawn: recovered = int(player.id)
			if recovered == 0: return "Recovery code unavailable for this tournament."
			var old_sid := int(bindings.get(recovered, 0))
			if server()._connected(old_sid): return "This entrant is still connected. Disconnect that player first."
			bindings[recovered] = sid
			codes.erase(old_sid)
			codes[sid] = action.code
			# A code reclaims the existing live table, not just the display name.
			for table: Dictionary in server()._rooms.values():
				if not table.has("t_pair"): continue
				var pair := event.pairing(table.t_pair)
				var seat: int = pair.players.find(recovered)
				if seat >= 0:
					table.seats[seat] = sid
					table.revision += 1
					server()._sessions[sid].room = table.id
			if old_sid != 0 and server()._sessions.has(old_sid): server()._abandon(old_sid)
			event.revision += 1
		"t_deck", "t_choose":
			var deck: Dictionary
			if op == "t_choose":
				if action.index >= event.config.decks.size(): return "Approved deck unavailable."
				deck = event.config.decks[int(action.index)]
			else: deck = SgDeckCatalog.payload(action)
			error = event.select_deck(pid, deck)
		"t_ready":
			if not room.is_empty(): return "Return to the Tournament Hall first."
			var pair := event.pairing_for(pid)
			if action.round != event.rounds.size() or action.game != pair.get("game", 0):
				return "Your next game changed. Review the round and confirm readiness again."
			error = event.set_ready(pid, action.value)
		"t_pause", "t_resume":
			if event.phase != "running": return "There is no round in play to pause."
			if (op == "t_pause") == paused: return "The tournament is already paused." if paused else "The tournament is not paused."
			paused = op == "t_pause"
			event.revision += 1
		"t_rule":
			var pair := event.pairing(int(action.pair))
			error = event.rule(int(action.pair), int(action.winner))
			if error.is_empty():
				# A live game at that table ends now, the way a withdrawal ends
				# one; the referee has nothing left to score on a ruled pairing.
				for table: Dictionary in server()._rooms.values():
					if table.get("t_pair", -1) != pair.get("id", 0) or table.match.game.game_over: continue
					table.match.game.concede(1 - pair.players.find(int(action.winner)))
					table.revision += 1
		"t_start", "t_next":
			if paused: return "Resume the tournament before drawing the next round."
			if not server()._rooms.is_empty(): return "Wait for players to return from their completed games."
			if (op == "t_start") != (event.phase == "registration"): return "This round has already been drawn."
			for player: Dictionary in event.entrants:
				if not player.withdrawn and (event.phase == "registration" or event.survivors().has(player.id)) \
					and not connected(player.id): return "Wait for advancing players to reconnect, or withdraw them explicitly."
			error = event.draw_round()
		"t_withdraw", "t_remove":
			var target := int(action.player) if op == "t_remove" else pid
			if event.entrant(target).is_empty(): return "Entrant unavailable."
			# A withdrawal is a series forfeit, not a fabricated played-game score.
			var pair := event.pairing_for(target)
			error = event.withdraw(target)
			if error.is_empty():
				for table: Dictionary in server()._rooms.values():
					if table.get("t_pair", -1) != pair.get("id", 0): continue
					if not table.match.game.game_over: table.match.game.concede(pair.players.find(target))
					table.revision += 1
				if event.phase == "registration":
					codes.erase(bindings.get(target, 0))
					bindings.erase(target)
		"t_cancel":
			if event.phase not in ["registration", "running"]: return "This tournament has already ended."
			event.cancel()
			for session: Dictionary in server()._sessions.values(): session.room = ""
			server()._rooms.clear()
			server()._view_cache.clear()
		_: return "Tournament action unavailable."
	if not error.is_empty(): return error
	if event.phase != "running": paused = false
	error = save()
	if error.is_empty(): launch_ready_games()
	server()._publish("*", 0, true)
	return error


func launch_ready_games() -> void:
	if event.phase != "running" or not hold().is_empty() or event.rounds.is_empty(): return
	for pair: Dictionary in event.rounds.back():
		if pair.status != "waiting": continue
		var seats: Array = []
		var ready := true
		for pid: int in pair.players:
			var sid := int(bindings.get(pid, 0))
			if not connected(pid) or not event.entrant(pid).ready or not server()._sessions[sid].room.is_empty(): ready = false
			seats.append(sid)
		if not ready or server()._rooms.size() >= SgLocalServer.MAX_ROOMS: continue
		if not event.begin_game(pair.id).is_empty(): continue
		if not save().is_empty():
			pair.status = "waiting"
			pair.game -= 1
			for pid: int in pair.players: event.entrant(pid).ready = true
			event.revision += 1
			return
		var decks: Array = []
		var names: Array = []
		for pid: int in pair.players:
			decks.append(event.entrant(pid).deck.duplicate(true))
			names.append(event.entrant(pid).name)
		var room_id := "r%d" % server()._next_room
		server()._next_room += 1
		server()._rooms[room_id] = {"id": room_id, "name": "Round %d Table %d" % [event.rounds.size(), SgTournament.table_number(pair.id)],
			"seats": seats, "ready": [true, true], "revision": 1, "decks": decks,
			"match": server()._create_match(decks, names), "t_pair": pair.id, "t_game": pair.game}
		server()._attach_bots(server()._rooms[room_id])
		for sid: int in seats: server()._sessions[sid].room = room_id


func collect_result(room: Dictionary) -> String:
	if not room.has("t_pair") or room.match == null or not room.match.game.game_over: return ""
	var winner: int = -1 if room.match.game.is_draw else room.match.game.winner
	if event.record_game(room.t_pair, room.t_game, winner):
		save()
		server()._publish("", 0, true)
	return save_error


## The organiser's session abandoned with a live event: the CHAIR is
## vacated, never the event. The tables keep playing, the checkpoint stays
## current and the event stays resumable — the host's own lobby takes the
## chair back through [method SgLocalServer.reclaim_tournament] without a
## table restarting, and a host restart restores the checkpoint. The
## organiser's own pause stands until then: it is theirs to lift. A dropped
## connection is not this — the session is held for its resume code.
func vacated_by_organiser() -> void:
	if event.phase not in ["registration", "running"]: return
	organiser = 0
	event.revision += 1
	save()


func departed(sid: int) -> void:
	# Losing an application is not an automatic elimination. A saved private
	# code can reclaim this entry; the organiser may explicitly withdraw it.
	var pid := member(sid)
	if pid == 0: return
	bindings[pid] = 0
	codes.erase(sid)
	event.entrant(pid).ready = false
	event.revision += 1
	for table: Dictionary in server()._rooms.values():
		var seat: int = table.seats.find(sid)
		if seat >= 0:
			table.seats[seat] = 0
			table.revision += 1
	save()


func retire_empty_tables() -> void:
	for room_id in server()._rooms.keys():
		var room: Dictionary = server()._rooms[room_id]
		if not room.has("t_pair") or not room.match.game.game_over: continue
		var held := false
		for session: Dictionary in server()._sessions.values():
			if session.room == room_id: held = true
		if not held:
			server()._rooms.erase(room_id)
			server()._view_cache.erase(room_id)


func context(room: Dictionary) -> Dictionary:
	var pair := event.pairing(room.t_pair)
	return {"id": event.id, "name": event.config.name, "round": event.rounds.size(), "pair": pair.id,
		"game": room.t_game, "wins": pair.wins.duplicate(), "target": event.config.wins,
		"hold": "storage" if not save_error.is_empty() else ("organiser" if paused else "")}


func view(sid: int) -> Dictionary:
	var roster: Array = []
	for player: Dictionary in event.entrants:
		roster.append({"id": player.id, "name": player.name, "ready": player.ready, "withdrawn": player.withdrawn,
			"deck_name": player.deck.get("name", "Not selected"), "connected": connected(player.id)})
		if player.has("bot"): roster.back().bot = player.bot.duplicate(true)
	var pid := member(sid)
	var tables: Array = []
	for room: Dictionary in server()._rooms.values():
		if not room.has("t_pair"): continue
		var game: MtgGame = room.match.game
		tables.append({"pair": room.t_pair, "life": [game.players[0].life, game.players[1].life],
			"turn": game.turn_number, "step": Mtg.Step.keys()[game.current_step()]})
	return {"id": event.id, "config": event.config.duplicate(true), "phase": event.phase,
		"revision": event.revision, "champion": event.champion, "entrants": roster, "rounds": event.rounds.duplicate(true),
		"you": pid, "deck": {} if pid == 0 else event.entrant(pid).deck.duplicate(true),
		"code": codes.get(sid, ""), "organiser": sid == organiser, "save_error": save_error, "paused": paused, "tables": tables}
