class_name SgTournament
extends RefCounted
## [QoL] LAN knockout ledger. No sockets, engine snapshots or client results.
## Only the referee calls begin_game/record_game. Draws never award a win.
## The organiser's one other pen is [method rule], and every mark it makes is
## flagged on the pairing as a ruling or a correction, never as a played win.

const RULED := "Organiser's ruling"
const CORRECTED := "Corrected by organiser"
const REASONS := ["", "Bye", "Series won", "Withdrawal", RULED, CORRECTED]

const MAX_PLAYERS := 20
const MAX_ROUNDS := 5
const MAX_PAIRINGS := 16 # A 20-entrant first draw includes twelve byes.
const MAX_PAIR_ID := MAX_PLAYERS * MAX_ROUNDS
const MAX_DECKS := 16
const MAX_GAMES := 1000
const MAX_WELCOME := 280
var id := ""
var config: Dictionary = {}
var entrants: Array = []
var rounds: Array = []
var phase := "registration"
var revision := 1
var champion := 0
var _next_entrant := 1
var _draw_game := MtgGame.new()


static func valid_config(value: Variant) -> bool:
	if not value is Dictionary: return false
	var fields := ["name", "limit", "wins", "policy", "decks"]
	if value.has("welcome"):
		fields.append("welcome")
		if not SgViewProtocol.text(value.welcome, MAX_WELCOME) or String(value.welcome).count("\n") > 3: return false
	if not SgProtocol.exact(value, fields): return false
	if not SgProtocol.short_text(value.name) or not SgProtocol.integer(value.limit, 2, MAX_PLAYERS) \
		or not SgProtocol.integer(value.wins, 1, 3) or value.policy not in ["own", "fixed", "selection"] \
		or not value.decks is Array or value.decks.size() > MAX_DECKS: return false
	if (value.policy == "own" and not value.decks.is_empty()) \
		or (value.policy == "fixed" and value.decks.size() != 1) \
		or (value.policy == "selection" and value.decks.is_empty()): return false
	for deck in value.decks:
		if not valid_deck(deck): return false
	return true


static func valid_deck(value: Variant) -> bool:
	return SgDeckCatalog.valid_payload(value, false)


func configure(options: Dictionary, seed_value := -1) -> String:
	if not id.is_empty(): return "This tournament is already configured."
	if not valid_config(options): return "Choose a name, 2–20 players, 1–3 wins and valid tournament decks."
	id = Crypto.new().generate_random_bytes(32).hex_encode()
	if not SgProtocol.token(id): return "Cannot create a tournament identity."
	config = options.duplicate(true)
	if seed_value < 0: _draw_game.rng.randomize()
	else: _draw_game.rng.seed = seed_value
	return ""


func entrant(pid: int) -> Dictionary:
	for item: Dictionary in entrants:
		if item.id == pid: return item
	return {}


func register(player_name: String, recovery_hash: String) -> int:
	if phase != "registration" or entrants.size() >= int(config.limit) \
		or not SgViewProtocol.text(player_name, 40) or not SgProtocol.token(recovery_hash): return 0
	for item: Dictionary in entrants:
		if item.recovery_hash == recovery_hash: return 0
	entrants.append({"id": _next_entrant, "name": player_name, "deck": config.decks[0].duplicate(true) \
		if config.policy == "fixed" else {}, "ready": false, "withdrawn": false, "recovery_hash": recovery_hash})
	_next_entrant += 1
	revision += 1
	return _next_entrant - 1


func select_deck(pid: int, deck: Dictionary) -> String:
	var player := entrant(pid)
	if phase != "registration" or player.is_empty(): return "Decks are locked after registration closes."
	if not valid_deck(deck): return "Choose an implemented deck with 40–250 cards."
	if config.policy != "own":
		var approved := false
		for allowed: Dictionary in config.decks:
			if same_list(deck, allowed):
				deck = allowed
				approved = true
				break
		if not approved: return "Choose a deck from the host's approved selection."
	player.deck = deck.duplicate(true)
	player.ready = false
	revision += 1
	return ""


func register_bots(count: int, options: Dictionary, deck: Dictionary) -> String:
	if phase != "registration": return "Computer seats can only be added during registration."
	if not SgProtocol.integer(count, 1, MAX_PLAYERS) or entrants.size() + count > int(config.limit):
		return "Choose a bot count that fits the remaining tournament seats."
	if not SgBotPlayer.valid(options) or not valid_deck(deck): return "Choose a computer level and valid deck."
	if config.policy != "own":
		var approved := false
		for allowed: Dictionary in config.decks:
			if same_list(deck, allowed):
				approved = true
				deck = allowed
				break
		if not approved: return "Computer players must use an approved tournament deck."
	# Validate the entire batch before changing the roster. Bot recovery hashes
	# are random bookkeeping identifiers; no plaintext capability is issued.
	var hashes: Array = []
	for i in count:
		var code := Crypto.new().generate_random_bytes(32).hex_encode()
		if not SgProtocol.token(code): return "Cannot create computer seats. Try again."
		hashes.append(code.sha256_text())
	for hash_value: String in hashes:
		var pid := register("%s bot %d" % [SgBotPlayer.label(options), _next_entrant], hash_value)
		var player := entrant(pid)
		player.bot = options.duplicate(true)
		player.deck = deck.duplicate(true)
		player.ready = true
	return ""


static func same_list(a: Dictionary, b: Dictionary) -> bool:
	for key in ["cards", "sideboard"]:
		var left: Array = a[key].duplicate()
		var right: Array = b[key].duplicate()
		left.sort()
		right.sort()
		if left != right: return false
	return true


func set_ready(pid: int, value: bool) -> String:
	var player := entrant(pid)
	if player.is_empty() or player.withdrawn or player.deck.is_empty(): return "Register and choose your deck first."
	if phase == "running":
		var pair := pairing_for(pid)
		if pair.is_empty() or pair.status != "waiting": return "Your next game is not waiting for readiness."
	elif phase != "registration": return "This tournament has ended."
	player.ready = value
	revision += 1
	return ""


func pairing_for(pid: int) -> Dictionary:
	if rounds.is_empty(): return {}
	for pair: Dictionary in rounds.back():
		if pair.players.has(pid): return pair
	return {}


func pairing(pair_id: int) -> Dictionary:
	for row: Array in rounds:
		for pair: Dictionary in row:
			if pair.id == pair_id: return pair
	return {}


static func table_number(pair_id: int) -> int:
	return (pair_id - 1) % MAX_PLAYERS + 1


func can_withdraw(pid: int) -> bool:
	var player := entrant(pid)
	if player.is_empty() or player.withdrawn: return false
	if phase == "registration": return true
	if phase != "running": return false
	var pair := pairing_for(pid)
	return not pair.is_empty() and (pair.status in ["waiting", "playing"] or pair.winner == pid)


func round_finished() -> bool:
	if rounds.is_empty(): return false
	for pair: Dictionary in rounds.back():
		if pair.status not in ["finished", "bye"]: return false
	return true


func draw_round() -> String:
	var pool: Array = []
	if phase == "registration":
		if entrants.size() < 2: return "At least two players must register."
		for player: Dictionary in entrants:
			if not player.ready or player.deck.is_empty(): return "Every entrant must choose a deck and be ready."
			pool.append(player.id)
	elif phase == "running" and round_finished():
		pool = survivors()
	else: return "Finish every pairing before drawing the next round."
	if pool.size() < 2:
		finish_if_decided()
		return ""
	if rounds.size() >= MAX_ROUNDS: return "The final round has already been drawn."
	# Fisher-Yates, separate from every duel's random stream. Persist this draw
	# before opening a table; reconnects never call this method again.
	for i in range(pool.size() - 1, 0, -1):
		var j := _draw_game.rng.randi_range(0, i)
		var swap: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var bracket := 2
	while bracket < pool.size(): bracket *= 2
	var byes := bracket - pool.size()
	var row: Array = []
	var next_id := rounds.size() * MAX_PLAYERS + 1
	while not pool.is_empty():
		var players: Array = [pool.pop_back(), 0 if byes > 0 else pool.pop_back()]
		var bye := byes > 0
		if bye: byes -= 1
		row.append({"id": next_id, "players": players, "wins": [0, 0], "draws": 0,
			"game": 0, "status": "bye" if bye else "waiting", "winner": players[0] if bye else 0,
			"reason": "Bye" if bye else ""})
		next_id += 1
	rounds.append(row)
	for player: Dictionary in entrants: player.ready = false
	phase = "running"
	revision += 1
	return ""


func begin_game(pair_id: int) -> String:
	var pair := pairing(pair_id)
	if phase != "running" or pair.is_empty() or pair.status != "waiting": return "This pairing is not waiting for a game."
	for pid: int in pair.players:
		var player := entrant(pid)
		if player.withdrawn or not player.ready: return "Both players must be ready."
	if pair.game >= MAX_GAMES: return "Game limit reached. The organiser must resolve withdrawals or cancel the event."
	pair.game += 1
	pair.status = "playing"
	for pid: int in pair.players: entrant(pid).ready = false
	revision += 1
	return ""


func record_game(pair_id: int, game_number: int, winner_seat: int) -> bool:
	var pair := pairing(pair_id)
	if phase != "running" or pair.is_empty() or pair.status != "playing" \
		or pair.game != game_number or winner_seat not in [-1, 0, 1]: return false
	if winner_seat < 0: pair.draws += 1
	else: pair.wins[winner_seat] += 1
	pair.status = "waiting"
	if winner_seat >= 0 and pair.wins[winner_seat] >= config.wins:
		pair.winner = pair.players[winner_seat]
		pair.status = "finished"
		pair.reason = "Series won"
	revision += 1
	finish_if_decided()
	return true


## The organiser's word over one pairing of the current round: a declared
## winner where the referee had none yet, or a correction that overturns a
## recorded outcome. The played scores stay as they were played; the flag on
## the pairing says which of the two this was. A correction of the final
## moves the championship with it.
func rule(pair_id: int, winner: int) -> String:
	if phase not in ["running", "complete"] or rounds.is_empty(): return "No round is in play to rule on."
	var pair: Dictionary = {}
	for candidate: Dictionary in rounds.back():
		if candidate.id == pair_id: pair = candidate
	if pair.is_empty(): return "Only a pairing of the current round can be ruled on."
	if pair.status == "bye" or not pair.players.has(winner): return "Choose one of the two players at this table."
	if entrant(winner).withdrawn: return "A withdrawn player cannot be ruled the winner."
	if pair.status == "finished":
		if pair.winner == winner: return "That player is already the recorded winner."
		pair.reason = CORRECTED
	else: pair.reason = RULED
	pair.winner = winner
	pair.status = "finished"
	for pid: int in pair.players: entrant(pid).ready = false
	if phase == "complete":
		phase = "running"
		champion = 0
	revision += 1
	finish_if_decided()
	return ""


func withdraw(pid: int) -> String:
	var player := entrant(pid)
	if player.is_empty(): return "Entrant unavailable."
	if not can_withdraw(pid): return "This entrant has already finished or withdrawn."
	if phase == "registration":
		entrants.erase(player)
	elif phase == "running":
		player.withdrawn = true
		player.ready = false
		var pair := pairing_for(pid)
		if not pair.is_empty() and pair.status in ["waiting", "playing"]:
			var other := int(pair.players[1 - pair.players.find(pid)])
			pair.winner = 0 if entrant(other).withdrawn else other
			pair.status = "finished"
			pair.reason = "Withdrawal"
	else: return "This tournament has ended."
	revision += 1
	finish_if_decided()
	return ""


func survivors() -> Array:
	var result: Array = []
	if not round_finished(): return result
	for pair: Dictionary in rounds.back():
		if pair.winner != 0 and not entrant(pair.winner).withdrawn: result.append(pair.winner)
	return result


func finish_if_decided() -> void:
	if phase != "running" or not round_finished(): return
	var remaining := survivors()
	if remaining.size() <= 1:
		champion = 0 if remaining.is_empty() else int(remaining[0])
		phase = "complete"


func cancel() -> void:
	phase = "cancelled"
	for player: Dictionary in entrants: player.ready = false
	revision += 1


func checkpoint() -> Dictionary:
	return {"schema": 1, "build": SgCompatibility.fingerprint(), "id": id, "config": config.duplicate(true),
		"entrants": entrants.duplicate(true), "rounds": rounds.duplicate(true), "phase": phase,
		"revision": revision, "champion": champion, "next_entrant": _next_entrant}


func restore(data: Dictionary) -> String:
	if not SgTournamentProtocol.checkpoint(data): return "Invalid or incompatible tournament checkpoint. Use the same game build and enabled card packs."
	id = data.id
	config = data.config.duplicate(true)
	entrants = data.entrants.duplicate(true)
	rounds = data.rounds.duplicate(true)
	phase = data.phase
	revision = int(data.revision) + 1
	champion = int(data.champion)
	_next_entrant = int(data.next_entrant)
	# JSON numbers arrive as floats. Array.has/find distinguish them from
	# integer entrant IDs even though scalar equality compares them equally.
	# The restart test refused both players' Ready before this normalization.
	config.limit = int(config.limit)
	config.wins = int(config.wins)
	for player: Dictionary in entrants:
		player.id = int(player.id)
		player.ready = false
	for row: Array in rounds:
		for pair: Dictionary in row:
			for key in ["id", "game", "winner", "draws"]: pair[key] = int(pair[key])
			for seat in 2:
				pair.players[seat] = int(pair.players[seat])
				pair.wins[seat] = int(pair.wins[seat])
			if pair.status == "playing": pair.status = "waiting"
	_draw_game.rng.randomize()
	return ""
