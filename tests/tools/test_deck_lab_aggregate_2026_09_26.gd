extends GutTest
## The aggregate after the games (2026-09-26): the run's records grouped
## by pair in ONE pass over the tasks. It used to scan the whole task
## list once per pair — nothing for a duel, 18.5 billion dictionary
## reads for a thousand-deck tournament: the first one's parent sat at
## 100% for twenty-two minutes after its last game, with three and a
## half hours of records in memory and nothing to tell it from a hang.
## The tournament tables had the same shape over the pair list (once per
## deck) and take it in one pass too. The report is byte for byte what
## the scans wrote: records stay in task order inside a pair, pairs in
## pair order.


func _lab():
	return autofree(load("res://DeckLab/simulate.gd").new())


func test_records_are_grouped_by_pair_in_task_order() -> void:
	var lab = _lab()
	# Pairs interleaved the way a run never lays them out, so that the
	# order inside a bucket is provably the TASK order, not the pair's.
	for i in 6:
		lab._tasks.append({"pair": i % 3, "seed": 100 + i})
	lab._results.resize(6)
	for i in 6:
		lab._results[i] = {"seed": 100 + i}
	var by_pair: Array = lab._records_by_pair(4)
	assert_eq(by_pair.size(), 4, "one bucket per pair, whether or not it played")
	assert_eq(by_pair[0], [{"seed": 100}, {"seed": 103}])
	assert_eq(by_pair[1], [{"seed": 101}, {"seed": 104}])
	assert_eq(by_pair[2], [{"seed": 102}, {"seed": 105}])
	assert_eq(by_pair[3], [], "a pair with no task is an empty record list, not a crash")


func test_the_grouping_is_one_pass_however_many_pairs_there_are() -> void:
	# THE BITE: 200,000 tasks over 20,000 pairs. The scan this replaced
	# is four billion reads — five minutes at the 14 M/s a probe measured
	# — and one pass is a tenth of a second; the bound below is a hundred
	# times that, so a slow runner passes and the scan never does.
	var lab = _lab()
	var pairs := 20000
	for i in 200000:
		lab._tasks.append({"pair": i / 10, "seed": i})
	lab._results.resize(200000)
	for i in 200000:
		lab._results[i] = {"seed": i}
	var started := Time.get_ticks_msec()
	var by_pair: Array = lab._records_by_pair(pairs)
	var ms := Time.get_ticks_msec() - started
	assert_lt(ms, 10000, "grouped in %d ms" % ms)
	assert_eq(by_pair.size(), pairs)
	assert_eq(by_pair[19999].size(), 10)
	assert_eq(int(by_pair[19999][9]["seed"]), 199999, "the last record, in its place")


func test_the_tournament_tables_read_the_same_off_the_one_pass() -> void:
	# Two field decks against three gauntlet decks, pairs in the order
	# `_main` lays them out (row-major), with records that make every
	# row and column distinct — so a bucket put in the wrong place shows
	# in a rank or a record.
	var lab = _lab()
	var decks: Array[DeckList] = []
	for name in ["F1", "F2", "G1", "G2", "G3"]:
		var deck := DeckList.new()
		deck.deck_name = name
		decks.append(deck)
	var pairs: Array = []
	var per_pair_records: Array = []
	var per_pair_stats: Array = []
	var wins := {"0,2": 3, "0,3": 1, "0,4": 2, "1,2": 0, "1,3": 3, "1,4": 3}
	for i in 2:
		for j in range(2, 5):
			pairs.append([i, j])
			var records: Array = []
			var won: int = wins["%d,%d" % [i, j]]
			for g in 3:
				records.append({"a_won": g < won, "a_on_play": g % 2 == 0,
					"turns": 10 + g, "stalled": false, "drawn": false})
			per_pair_records.append(records)
			per_pair_stats.append(SimStats.summarize(records))
	var field_paths: Array[String] = ["f1.deck", "f2.deck"]
	var tables: Dictionary = lab._tournament_tables(decks, 2, field_paths, pairs,
		per_pair_records, per_pair_stats, 2)
	var standings: Array = tables["standings"]
	assert_eq(standings[0]["name"], "F1", "6 of 9 beats 6 of 9 on the name")
	assert_eq(int(standings[0]["stats"]["a_wins"]), 6)
	assert_eq(int(standings[1]["stats"]["a_wins"]), 6)
	assert_eq(standings[0]["opponents"].map(func(o): return o["name"]), ["G1", "G2", "G3"],
		"a field deck's opponents in pair order")
	var gauntlet: Array = tables["gauntlet"]
	# G1 took 3 of 6 from the field, G2 2 of 6, G3 1 of 6.
	assert_eq(gauntlet.map(func(g): return g["name"]), ["G1", "G2", "G3"])
	assert_eq(gauntlet.map(func(g): return int(g["stats"]["a_wins"])), [3, 2, 1],
		"each opponent's own wins are the field's losses against it")
	assert_eq(gauntlet.map(func(g): return int(g["stats"]["games"])), [6, 6, 6])
