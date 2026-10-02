class_name SgTournamentProtocol
extends RefCounted
## Exact bounded schemas for tournament views and private local checkpoints.


static func context(value: Variant) -> bool:
	return value is Dictionary and SgProtocol.exact(value, ["id", "name", "round", "pair", "game", "wins", "target", "hold"]) \
		and SgProtocol.token(value.id) and SgProtocol.short_text(value.name) \
		and SgProtocol.integer(value.round, 1, SgTournament.MAX_ROUNDS) and SgProtocol.integer(value.pair, 1, SgTournament.MAX_PAIR_ID) \
		and SgProtocol.integer(value.game, 1, SgTournament.MAX_GAMES) \
		and scores(value.wins, 3) and SgProtocol.integer(value.target, 1, 3) and value.hold in SgTournamentHost.HOLDS


static func scores(value: Variant, maximum: int) -> bool:
	return value is Array and value.size() == 2 and SgProtocol.integer(value[0], 0, maximum) \
		and SgProtocol.integer(value[1], 0, maximum)


static func rows(value: Variant, ids: Array, target: int, withdrawn: Array = []) -> bool:
	if not value is Array or value.size() > SgTournament.MAX_ROUNDS: return false
	var previous: Array = ids
	for r in value.size():
		var row: Variant = value[r]
		if not row is Array or row.is_empty() or row.size() > SgTournament.MAX_PAIRINGS: return false
		var seen: Array = []
		var winners: Array = []
		var byes := 0
		for i in row.size():
			var pair: Variant = row[i]
			if not pair is Dictionary or not SgProtocol.exact(pair, ["id", "players", "wins", "draws", "game", "status", "winner", "reason"]) \
				or not SgProtocol.integer(pair.id, 1, SgTournament.MAX_PAIR_ID) \
				or pair.id != r * SgTournament.MAX_PLAYERS + i + 1 \
				or not scores(pair.players, 1000000) or pair.players[0] == 0 or pair.players[0] == pair.players[1] \
				or not scores(pair.wins, target) or not SgProtocol.integer(pair.draws, 0, SgTournament.MAX_GAMES) \
				or not SgProtocol.integer(pair.game, 0, SgTournament.MAX_GAMES) \
				or pair.status not in ["waiting", "playing", "finished", "bye"] \
				or pair.reason not in SgTournament.REASONS \
				or not SgProtocol.integer(pair.winner) or (pair.winner != 0 and not pair.players.has(pair.winner)): return false
			if int(pair.wins[0]) + int(pair.wins[1]) + int(pair.draws) > int(pair.game): return false
			if pair.wins[0] == target and pair.wins[1] == target: return false
			if pair.status in ["waiting", "playing"] and (pair.winner != 0 or pair.reason != "" \
				or pair.wins[0] >= target or pair.wins[1] >= target): return false
			if pair.status == "playing" and pair.game < 1: return false
			if pair.status == "bye" and (pair.players[1] != 0 or pair.winner != pair.players[0] \
				or pair.game != 0 or pair.reason != "Bye"): return false
			if pair.status == "bye": byes += 1
			if pair.status != "bye" and pair.players[1] == 0: return false
			if pair.status == "finished":
				if pair.reason not in ["Series won", "Withdrawal", SgTournament.RULED, SgTournament.CORRECTED]: return false
				if pair.reason == "Series won" and (pair.winner == 0 \
					or pair.wins[pair.players.find(pair.winner)] != target): return false
				# A ruling always names its winner; only a double withdrawal leaves none.
				if pair.reason in [SgTournament.RULED, SgTournament.CORRECTED] and pair.winner == 0: return false
			if r < value.size() - 1 and pair.status not in ["finished", "bye"]: return false
			for pid in pair.players:
				if pid == 0: continue
				if not ids.has(pid) or not previous.has(pid) or seen.has(pid): return false
				seen.append(pid)
			if pair.winner != 0: winners.append(pair.winner)
		# A shape with legal individual pairs may still omit an entrant or
		# silently skip an advancing winner. Account for the entire draw.
		for pid in previous:
			if (r == 0 or not withdrawn.has(pid)) and not seen.has(pid): return false
		var bracket := 2
		while bracket < seen.size(): bracket *= 2
		if seen.size() < 2 or row.size() * 2 != bracket or byes != bracket - seen.size(): return false
		previous = winners
	return true


static func checkpoint(value: Variant) -> bool:
	# A checkpoint is a file on disk: type-check every field before comparing
	# it, or a corrupted one raises where it should simply be refused.
	if not value is Dictionary or not SgProtocol.exact(value, ["schema", "build", "id", "config", "entrants", "rounds", "phase", "revision", "champion", "next_entrant"]) \
		or not SgProtocol.integer(value.schema, 1, 1) or not SgProtocol.token(value.build) \
		or value.build != SgCompatibility.fingerprint() or not SgProtocol.token(value.id) \
		or not SgTournament.valid_config(value.config) or not SgProtocol.integer(value.revision, 1) \
		or not SgProtocol.integer(value.next_entrant, 1) or not roster(value.entrants, true): return false
	var ids: Array = []
	var hashes: Array = []
	var withdrawn: Array = []
	for player: Dictionary in value.entrants:
		if player.id >= value.next_entrant or hashes.has(player.recovery_hash): return false
		hashes.append(player.recovery_hash)
		ids.append(player.id)
		if player.withdrawn: withdrawn.append(player.id)
		if not player.deck.is_empty():
			if not SgTournament.valid_deck(player.deck): return false
			if value.config.policy != "own":
				var approved := false
				for deck: Dictionary in value.config.decks:
					if SgTournament.same_list(player.deck, deck): approved = true
				if not approved: return false
		elif value.phase in ["running", "complete"]: return false
	if value.entrants.size() > value.config.limit or not rows(value.rounds, ids, int(value.config.wins), withdrawn): return false
	return lifecycle(value, ids)


static func lifecycle(value: Dictionary, ids: Array) -> bool:
	if value.phase not in ["registration", "running", "complete", "cancelled"] \
		or not SgProtocol.integer(value.champion) or (value.champion != 0 and not ids.has(value.champion)): return false
	if value.phase == "registration" and not value.rounds.is_empty(): return false
	if value.phase in ["running", "complete"] and value.rounds.is_empty(): return false
	if value.phase != "complete" and value.champion != 0: return false
	if value.phase == "complete":
		var remaining: Array = []
		for pair: Dictionary in value.rounds.back():
			if pair.status not in ["finished", "bye"]: return false
			for player: Dictionary in value.entrants:
				if player.id == pair.winner and not player.withdrawn: remaining.append(player.id)
		if remaining.size() > 1 or value.champion != (0 if remaining.is_empty() else remaining[0]): return false
	return true


static func roster(value: Variant, private_data: bool) -> bool:
	if not value is Array or value.size() > SgTournament.MAX_PLAYERS: return false
	var ids: Array = []
	for player in value:
		var fields := ["id", "name", "ready", "withdrawn"] + (["deck", "recovery_hash"] if private_data else ["deck_name", "connected"])
		if player is Dictionary and player.has("bot"):
			fields.append("bot")
			if not SgBotPlayer.valid(player.bot): return false
		if not player is Dictionary or not SgProtocol.exact(player, fields) \
			or not SgProtocol.integer(player.id, 1) or ids.has(player.id) \
			or not SgViewProtocol.text(player.name, 40) or not player.ready is bool or not player.withdrawn is bool: return false
		ids.append(player.id)
		if private_data:
			if not SgViewProtocol.deck(player.deck) or not SgProtocol.token(player.recovery_hash): return false
			if player.has("bot") and player.deck.is_empty(): return false
		else:
			if not SgViewProtocol.text(player.deck_name, 128) or not player.connected is bool: return false
	return true


## The last config a view carried that read valid. A client checks every
## state message, and the config — sixteen approved decks against the card
## pool — changes only in registration: an equal one (a deep compare, in
## the engine) is not walked again (2026-10-02).
static var _valid_config: Dictionary = {}


static func valid_view_config(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not _valid_config.is_empty() and value == _valid_config: return true
	if not SgTournament.valid_config(value): return false
	_valid_config = value.duplicate(true)
	return true


static func view(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not SgProtocol.exact(value, ["id", "config", "phase", "revision", "champion", "entrants", "rounds", "you", "deck", "code", "organiser", "save_error", "paused", "tables"]) \
		or not SgProtocol.token(value.id) or not valid_view_config(value.config) \
		or not SgProtocol.integer(value.revision, 1) or not roster(value.entrants, false) \
		or not SgProtocol.integer(value.you) or not SgViewProtocol.deck(value.deck) \
		or not value.code is String or (value.code != "" and not SgProtocol.token(value.code)) \
		or not value.organiser is bool or not SgViewProtocol.text(value.save_error, 256) \
		or not value.paused is bool: return false
	var ids: Array = []
	var withdrawn: Array = []
	for player in value.entrants:
		ids.append(player.id)
		if player.withdrawn: withdrawn.append(player.id)
	if value.entrants.size() > value.config.limit: return false
	if value.you != 0 and not ids.has(value.you): return false
	if value.you == 0 and (not value.deck.is_empty() or value.code != ""): return false
	if not rows(value.rounds, ids, int(value.config.wins), withdrawn) or not lifecycle(value, ids): return false
	if not value.tables is Array or value.tables.size() > SgLocalServer.MAX_ROOMS: return false
	if value.phase in ["registration", "cancelled"] and not value.tables.is_empty(): return false
	var seen: Array = []
	for table in value.tables:
		if not table is Dictionary or not SgProtocol.exact(table, ["pair", "life", "turn", "step"]) \
			or not SgProtocol.integer(table.pair, 1, SgTournament.MAX_PAIR_ID) or seen.has(table.pair) \
			or not table.life is Array or table.life.size() != 2 or not SgProtocol.integer(table.life[0], -1000000) \
			or not SgProtocol.integer(table.life[1], -1000000) or not SgProtocol.integer(table.turn) \
			or table.step not in Mtg.Step: return false
		var known := false
		if not value.rounds.is_empty():
			for pair: Dictionary in value.rounds.back():
				if pair.id == table.pair and pair.status != "bye" and pair.game > 0: known = true
		if not known: return false
		seen.append(table.pair)
	return true
