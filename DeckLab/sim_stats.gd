class_name SimStats
extends RefCounted
## Statistics for the Deck Lab — pure static math, unit-tested in
## tests/tools/test_deck_lab.gd.
##
## Methodology notes (documented because the community will quote these
## numbers):
## - Win rates carry a WILSON 95% confidence interval, not the naive
##   normal approximation — correct behavior near 0%/100% and for small
##   samples. z = 1.96.
## - Games alternate who is on the play; the play/draw split is reported
##   separately because first-player advantage is real and a deck's
##   aggregate winrate hides it.
## - Stalled games (the AI driver bailing — should be zero) and DRAWS are
##   counted and excluded from winrate denominators, never silently mixed
##   into either side. A draw is `MtgGame.is_draw` (CR 104.4b — both
##   duelists losing at once, e.g. an Orcish Artillery ping that takes its
##   controller to 0 alongside its target); the game record carries it as
##   `drawn`. This paragraph was aspirational until 2026-09-01: with no
##   `drawn` in the record, "not a_won" meant "B won" and every draw was
##   scored as a win for deck B (and fed to the Elo ledger as one).


## Wilson score interval for [param wins] out of [param n] at 95%.
## Returns {low, high, mid} as fractions (0..1); n = 0 → {0, 1, 0.5}.
static func wilson_interval(wins: int, n: int) -> Dictionary:
	if n <= 0:
		return {"low": 0.0, "high": 1.0, "mid": 0.5}
	var z := 1.96
	var p := float(wins) / n
	var z2 := z * z
	var denominator := 1.0 + z2 / n
	var center := (p + z2 / (2.0 * n)) / denominator
	var margin := (z * sqrt(p * (1.0 - p) / n + z2 / (4.0 * n * n))) / denominator
	return {
		"low": clampf(center - margin, 0.0, 1.0),
		"high": clampf(center + margin, 0.0, 1.0),
		"mid": p,
	}


## Aggregate one matchup's game records (see simulate.gd's record shape).
static func summarize(records: Array) -> Dictionary:
	var s := {
		"games": records.size(), "a_wins": 0, "b_wins": 0, "stalled": 0,
		"draws": 0,
		"a_wins_on_play": 0, "a_games_on_play": 0,
		"a_wins_on_draw": 0, "a_games_on_draw": 0,
		"turns": [],
	}
	for r in records:
		if r.stalled:
			s.stalled += 1
			continue
		# A drawn game still took turns, so it counts toward the game
		# length — but it leaves EVERY winrate denominator, the play/draw
		# splits included, so the splits stay consistent with the
		# aggregate. `get` with a default: records written before `drawn`
		# existed (and the chart tests) simply have no draws.
		s.turns.append(r.turns)
		if r.get("drawn", false):
			s.draws += 1
			continue
		if r.a_on_play:
			s.a_games_on_play += 1
		else:
			s.a_games_on_draw += 1
		if r.a_won:
			s.a_wins += 1
			if r.a_on_play:
				s.a_wins_on_play += 1
			else:
				s.a_wins_on_draw += 1
		else:
			s.b_wins += 1
	var decided: int = s.a_wins + s.b_wins
	s["winrate"] = wilson_interval(s.a_wins, decided)
	s["winrate_on_play"] = wilson_interval(s.a_wins_on_play, s.a_games_on_play)
	s["winrate_on_draw"] = wilson_interval(s.a_wins_on_draw, s.a_games_on_draw)
	s["avg_turns"] = 0.0
	s["median_turns"] = 0
	if not s.turns.is_empty():
		var total := 0
		for t in s.turns:
			total += t
		s["avg_turns"] = float(total) / s.turns.size()
		var sorted_turns: Array = s.turns.duplicate()
		sorted_turns.sort()
		s["median_turns"] = sorted_turns[sorted_turns.size() / 2]
	return s


## Turn-count histogram as {turn: int -> games: int}, for charts.
static func turn_histogram(records: Array) -> Dictionary:
	var histogram := {}
	for r in records:
		if not r.stalled:
			histogram[r.turns] = int(histogram.get(r.turns, 0)) + 1
	return histogram


static func percent(fraction: float) -> String:
	return "%5.1f%%" % (fraction * 100.0)


## Is this win rate DIFFERENT FROM EVEN at 95%? — i.e. does its interval
## clear 50% entirely?
##
## THE LESSON THIS ENCODES: a raw percentage over a couple of hundred
## games invites a conclusion the sample cannot support, and reading
## "44.0%" as "this deck is worse" has cost this project three separate AI
## passes. 200 games is +-6.9 points at an even win rate, so 44.0% and
## 50.0% are the same measurement. The report says so in words rather than
## leaving the reader to compare the interval against 0.5 by eye.
static func is_decided(interval: Dictionary) -> bool:
	return float(interval["low"]) > 0.5 or float(interval["high"]) < 0.5


## The half-width of the Wilson 95% interval at an even win rate over
## [param games] games, as a FRACTION — "how big an edge does this many
## games even let me see?". Same formula as [method wilson_interval] with
## p = 0.5.
static func margin_at(games: int) -> float:
	if games <= 0:
		return 0.5
	var z := 1.96
	var z2 := z * z
	return (z * sqrt(0.25 / games + z2 / (4.0 * games * games))) / (1.0 + z2 / games)


## The other direction, which is the one people ask out loud: the fewest
## games whose interval is no wider than +-[param margin] at an even win
## rate. Binary search on [method margin_at], which is monotone.
static func games_for_margin(margin: float) -> int:
	if margin <= 0.0:
		return 0
	var low := 1
	var high := 2
	while margin_at(high) > margin and high < 100000000:
		high *= 2
	while low < high:
		var mid := (low + high) / 2
		if margin_at(mid) > margin:
			low = mid + 1
		else:
			high = mid
	return low


## EVERY DECK'S RECORD ACROSS A WHOLE RUN, best first — the table a
## gauntlet or a matrix is actually read for, and the one the Deck Lab's
## own README used to have to work out by hand from the per-pair rows.
##
## [param pairs] is the run's [row_index, col_index] list and
## [param per_pair_stats] its summaries, index-matched; the tally is kept
## BY INDEX because two deck files may carry the same name. A deck's wins
## are its own whichever side of the pairing it sat on.
static func standings(names: Array, pairs: Array, per_pair_stats: Array) -> Array:
	var wins := []
	var losses := []
	wins.resize(names.size())
	losses.resize(names.size())
	wins.fill(0)
	losses.fill(0)
	for index in pairs.size():
		var stats: Dictionary = per_pair_stats[index]
		var row: int = pairs[index][0]
		var col: int = pairs[index][1]
		wins[row] = int(wins[row]) + int(stats["a_wins"])
		losses[row] = int(losses[row]) + int(stats["b_wins"])
		wins[col] = int(wins[col]) + int(stats["b_wins"])
		losses[col] = int(losses[col]) + int(stats["a_wins"])
	var table: Array = []
	for i in names.size():
		var decided: int = int(wins[i]) + int(losses[i])
		table.append({
			"name": String(names[i]),
			"wins": int(wins[i]), "losses": int(losses[i]),
			"games": decided,
			"winrate": wilson_interval(int(wins[i]), decided),
		})
	# Best first, ties by name so the table is stable run to run.
	table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(a["winrate"]["mid"], b["winrate"]["mid"]):
			return String(a["name"]) < String(b["name"])
		return float(a["winrate"]["mid"]) > float(b["winrate"]["mid"]))
	return table
