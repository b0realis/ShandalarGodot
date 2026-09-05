class_name EloLedger
extends RefCounted
## The persistent Elo ledger — each deck's rating and lifetime record,
## kept in a human-readable TEXT file (default decks/ratings.txt, made to
## be committed) and updated by Deck Lab runs, so performance accumulates
## ACROSS runs exactly as requested by the community workflow.
##
## File format (pipe-separated, # comments, safe to hand-edit):
##   # deck | elo | games | wins | losses | updated
##   White Knights | 1536.2 | 800 | 512 | 288 | 2026-08-30
##
## Rating math: standard Elo, K=8 PER GAME, applied game-by-game with the
## matchup's wins/losses interleaved evenly (Bresenham spread) so the
## result is order-stable and deterministic. New decks start at 1500.
## Zero-sum: what A gains, B loses. With enough games a matchup converges
## to the gap its winrate implies (67% ≈ +123 Elo) and further identical
## runs move ratings only marginally — but re-running the SAME seed does
## re-count those games in the win/loss tallies, so give experimental
## reruns --no-elo or a scratch --elo-file (documented in docs/deck-lab.md).

const DEFAULT_PATH := "decks/ratings.txt"
const STARTING_ELO := 1500.0
const K := 8.0

var path := DEFAULT_PATH
## deck name -> {elo: float, games: int, wins: int, losses: int, updated: String}
var entries: Dictionary = {}


static func load_from(p_path: String) -> EloLedger:
	var ledger := EloLedger.new()
	ledger.path = p_path
	var file := FileAccess.open(p_path, FileAccess.READ)
	if file == null:
		return ledger   # first run: empty ledger, created on save
	for raw_line in file.get_as_text().split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("|")
		if parts.size() < 6:
			continue
		ledger.entries[parts[0].strip_edges()] = {
			"elo": parts[1].strip_edges().to_float(),
			"games": parts[2].strip_edges().to_int(),
			"wins": parts[3].strip_edges().to_int(),
			"losses": parts[4].strip_edges().to_int(),
			"updated": parts[5].strip_edges(),
		}
	return ledger


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("EloLedger: cannot write %s" % path)
		return
	file.store_line("# Shandalar Deck Lab — Elo ledger (see docs/deck-lab.md)")
	file.store_line("# Standard Elo, K=%d per game, start %d. Safe to hand-edit." % [
		int(K), int(STARTING_ELO)])
	file.store_line("# deck | elo | games | wins | losses | updated")
	var names := entries.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return entries[a].elo > entries[b].elo)
	for deck_name in names:
		var e: Dictionary = entries[deck_name]
		file.store_line("%s | %.1f | %d | %d | %d | %s" % [
			deck_name, e.elo, e.games, e.wins, e.losses, e.updated])


func rating(deck_name: String) -> float:
	return entries[deck_name].elo if entries.has(deck_name) else STARTING_ELO


func _entry(deck_name: String) -> Dictionary:
	if not entries.has(deck_name):
		entries[deck_name] = {"elo": STARTING_ELO, "games": 0, "wins": 0,
			"losses": 0, "updated": ""}
	return entries[deck_name]


## Fold one matchup's result into both decks' ratings and records.
func record_matchup(a_name: String, b_name: String, a_wins: int, b_wins: int) -> void:
	var total := a_wins + b_wins
	if total == 0 or a_name == b_name:
		return
	var a := _entry(a_name)
	var b := _entry(b_name)
	# Bresenham interleave of A-wins among the games: order-stable and as
	# evenly spread as possible, so sequential Elo has no streak bias.
	var accumulator := 0.0
	var ratio := float(a_wins) / total
	for _i in total:
		accumulator += ratio
		var a_won := accumulator >= 1.0 - 0.000001
		if a_won:
			accumulator -= 1.0
		var expected_a: float = 1.0 / (1.0 + pow(10.0, (b.elo - a.elo) / 400.0))
		var delta := K * ((1.0 if a_won else 0.0) - expected_a)
		a.elo += delta
		b.elo -= delta
	a.games += total
	a.wins += a_wins
	a.losses += b_wins
	b.games += total
	b.wins += b_wins
	b.losses += a_wins
	var date := Time.get_date_string_from_system()
	a.updated = date
	b.updated = date
