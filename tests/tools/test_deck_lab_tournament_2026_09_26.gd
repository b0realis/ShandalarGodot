extends GutTest
## Tournament mode (2026-09-26): one or many decks under test (--field)
## against one or many defined good decks (--gauntlet / --deck-b), every
## field deck against every gauntlet deck, the field ranked. In the
## owner's words: "one deck or list of decks tested on one deck or list
## of defined good decks ... in a single / tournament or multiple
## gauntlet style." With it: `--group all` (the whole library), a deck
## list as a FILE.txt, `--top`, standings.csv and top.txt, the worker
## payload's pile table, and the AutoDeck CLI's pack-aware set refusal.

const FIELD := ["--field", "big_green.deck,blue_skies.deck"]
const GAUNTLET := ["--gauntlet", "white_knights.deck,mountain_artillery.deck"]

var _made: Array[String] = []


func after_each() -> void:
	for path in _made:
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute):
			var dir := DirAccess.open(absolute)
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(absolute)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
	_made.clear()


func _lab():
	return autofree(load("res://DeckLab/simulate.gd").new())


func _parse(args: Array) -> Dictionary:
	return _lab()._parse_args(PackedStringArray(args))


func _scratch(kind: String) -> String:
	var path := "user://deck_lab_tournament_%s_%d" % [kind, Time.get_ticks_usec()]
	_made.append(path)
	return path


# ---------------------------------------------------------------- parser --

func test_a_field_and_a_gauntlet_make_a_tournament() -> void:
	var opts := _parse(FIELD + GAUNTLET)
	assert_false(opts.has("error"), str(opts.get("error", "")))
	assert_eq(opts.field, ["big_green.deck", "blue_skies.deck"])
	assert_eq(opts.opponents, ["white_knights.deck", "mountain_artillery.deck"])
	assert_eq(opts.deck_a, "", "the field is the deck-A side")
	assert_eq(opts.top, 10)
	# One deck against one deck is a tournament too — ranked and unrated.
	var one := _parse(["--field", "big_green.deck", "--deck-b", "blue_skies.deck"])
	assert_false(one.has("error"))
	assert_eq(one.field, ["big_green.deck"])
	assert_eq(one.opponents, ["blue_skies.deck"])


func test_what_a_tournament_refuses() -> void:
	assert_string_contains(str(_parse(["--field", "big_green.deck"]).error),
		"--field needs the decks to play against")
	assert_string_contains(str(_parse(FIELD + GAUNTLET + ["--deck-a", "big_green.deck"]).error),
		"--field replaces --deck-a")
	assert_string_contains(str(_parse(FIELD + ["--deck-b", "random"]).error),
		"DEFINED decks")
	assert_string_contains(str(_parse(["--field", "random"] + GAUNTLET).error),
		"--field does not take `random`")
	assert_string_contains(str(_parse(FIELD + GAUNTLET + ["--deck-pool", "decks/"]).error),
		"--deck-pool")
	assert_string_contains(str(_parse(FIELD + ["--matrix", "decks/"]).error),
		"--matrix does not combine with --field")
	assert_string_contains(str(_parse(FIELD + GAUNTLET + ["--sweep", "pays_sacrifices=on"]).error),
		"--sweep does not combine with --field")
	assert_string_contains(str(_parse(["--field", "user://no_such_list.txt"] + GAUNTLET).error),
		"no decks found in the field")


func test_top_is_a_tournament_switch() -> void:
	assert_eq(_parse(FIELD + GAUNTLET + ["--top", "3"]).top, 3)
	assert_string_contains(str(_parse(FIELD + GAUNTLET + ["--top", "0"]).error),
		"--top must be >= 1")
	assert_string_contains(str(_parse(FIELD + GAUNTLET + ["--top", "x"]).error),
		"whole number")
	assert_string_contains(str(_parse(["--deck-a", "big_green.deck",
		"--deck-b", "blue_skies.deck", "--top", "3"]).error),
		"--top only means something in tournament mode")


func test_the_new_switches_are_in_the_help_and_the_hint_tables() -> void:
	var lab = _lab()
	for flag in ["--field", "--top"]:
		assert_true(lab.FLAG_HINTS.has(flag), flag)
		assert_true(String(lab.HELP).contains(flag), "--help names %s" % flag)
	assert_true(String(lab.HELP).contains("tournament  ONE OR MANY decks"),
		"MODES has the tournament")
	assert_true(String(lab.HELP).contains("TOURNAMENTS (one or many decks"),
		"and its own section")
	assert_true(String(lab.HELP).contains("or `all`"), "--group documents all")
	assert_string_contains(String(lab.FLAG_HINTS["--group"]), "`all`")
	# The stale --procs numbers went with it.
	assert_true(String(lab.HELP).contains("80s in one process and 39s"))
	assert_false(String(lab.HELP).contains("19.0s in one process"))


func test_group_all_walks_every_subfolder_and_keeps_every_group() -> void:
	var lab = _lab()
	var opts: Dictionary = lab._parse_args(PackedStringArray(
		["--field", "big_green.deck", "--gauntlet", "decks/", "--group", "all"]))
	assert_false(opts.has("error"), str(opts.get("error", "")))
	assert_true(lab._walk_every_group)
	assert_eq(lab._group_filter, "", "no one group is kept")
	assert_eq(opts.group, "all")
	# More than any one group holds: the starters plus every subfolder.
	assert_gt(opts.opponents.size(), 100, "the library, not one folder")
	var groups := {}
	for path in opts.opponents:
		groups[DeckGroups.of(path)] = true
	assert_true(groups.has(DeckGroups.STARTER))
	assert_true(groups.has(DeckGroups.ANCIENTS))
	assert_true(groups.has(DeckGroups.ORIGINALS))
	# The unknown-group refusal now offers the word.
	assert_string_contains(str(_parse(["--field", "big_green.deck",
		"--gauntlet", "decks/", "--group", "nonsense"]).error), ", or all)")
	# And `--group all` makes the settings line.
	assert_string_contains(lab._settings_line(opts), "group all")


func test_a_field_folder_is_taken_whole_while_group_narrows_the_gauntlet() -> void:
	var folder := _scratch("field")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)), OK)
	for name in ["big_green.deck", "blue_skies.deck"]:
		assert_eq(DirAccess.copy_absolute(
			ProjectSettings.globalize_path("res://decks/" + name),
			ProjectSettings.globalize_path(folder + "/" + name)), OK)
	var lab = _lab()
	var opts: Dictionary = lab._parse_args(PackedStringArray(
		["--field", folder, "--gauntlet", "decks/", "--group", "ancients"]))
	assert_false(opts.has("error"), str(opts.get("error", "")))
	assert_eq(opts.field.size(), 2, "the field folder is not group-filtered")
	assert_eq(opts.opponents.size(), 55, "the gauntlet is")
	for path in opts.opponents:
		assert_eq(DeckGroups.of(path), DeckGroups.ANCIENTS)


func test_a_deck_list_text_file_names_the_field() -> void:
	var folder := _scratch("list")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)), OK)
	var listed := folder + "/decklist.txt"
	var absolute := ProjectSettings.globalize_path("res://decks/blue_skies.deck")
	var lab = _lab()
	assert_true(lab._write(listed, "# the field\n\nbig_green.deck\n%s\n  # indented comment\nres://decks/white_knights.deck\n" % absolute))
	var paths: Array = lab.deck_list_file(listed)
	assert_eq(paths.size(), 3, "comments and blank lines are not decks")
	assert_eq(paths[0], folder + "/big_green.deck", "a relative name is read beside the file")
	assert_eq(paths[1], absolute, "an absolute path is taken as typed")
	assert_eq(paths[2], "res://decks/white_knights.deck", "and so is a res:// one")
	assert_eq(lab.deck_list_file("user://no_such_list.txt"), [], "a missing file is an empty pool")
	# Through the parser: a FILE.txt is a pool like a folder is.
	assert_true(lab._write(listed, "big_green.deck\nblue_skies.deck\n"))
	var opts: Dictionary = lab._parse_args(PackedStringArray(
		["--field", listed, "--deck-b", "white_knights.deck"]))
	assert_false(opts.has("error"), str(opts.get("error", "")))
	assert_eq(opts.field, [folder + "/big_green.deck", folder + "/blue_skies.deck"])


func test_an_empty_field_says_when_its_decks_were_skipped_as_proxies() -> void:
	var folder := _scratch("proxies")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)), OK)
	var lab = _lab()
	assert_true(lab._write(folder + "/needs_a_pack.deck",
		"name: Needs A Pack\n40 Zuran Orb\n20 Mountain\n"))
	var file := folder + "/needs_a_pack.deck"
	_made.append(file)
	# Only meaningful while that card is a proxy — i.e. the pack is off.
	if not DeckList.load_file(folder + "/needs_a_pack.deck", false).proxies.is_empty():
		var opts: Dictionary = lab._parse_args(PackedStringArray(
			["--field", folder, "--deck-b", "white_knights.deck"]))
		assert_string_contains(str(opts.error), "no decks found in the field")
		assert_string_contains(str(opts.error), "1 deck file skipped for proxy cards")
		assert_string_contains(str(opts.error), "played with the same --packs X")


# ---------------------------------------------------------------- tables --

func test_a_flipped_record_is_the_same_game_from_the_other_seat() -> void:
	var lab = _lab()
	var won: Dictionary = lab.flipped_record({"a_won": true, "a_on_play": true, "turns": 9,
		"stalled": false, "drawn": false})
	assert_false(won.a_won)
	assert_false(won.a_on_play)
	assert_eq(won.turns, 9)
	var stalled: Dictionary = lab.flipped_record({"a_won": false, "a_on_play": false,
		"turns": 40, "stalled": true, "drawn": false})
	assert_true(stalled.stalled)
	assert_false(stalled.a_won, "a stall is nobody's win from either seat")
	assert_true(stalled.a_on_play)


func test_best_first_orders_by_win_rate_then_wins_then_name() -> void:
	var lab = _lab()
	var rows := [
		{"name": "Zed", "stats": {"winrate": {"mid": 0.5}, "a_wins": 5}},
		{"name": "Amy", "stats": {"winrate": {"mid": 0.5}, "a_wins": 5}},
		{"name": "Big", "stats": {"winrate": {"mid": 0.5}, "a_wins": 50}},
		{"name": "Top", "stats": {"winrate": {"mid": 0.9}, "a_wins": 9}},
	]
	rows.sort_custom(lab.best_first)
	var names := []
	for row in rows:
		names.append(row.name)
	assert_eq(names, ["Top", "Big", "Amy", "Zed"])


func test_the_tournament_tables_rank_the_field_and_the_gauntlet() -> void:
	var lab = _lab()
	var decks: Array[DeckList] = []
	for name in ["Field One", "Field Two", "Gauntlet A", "Gauntlet B"]:
		var deck := DeckList.new()
		deck.deck_name = name
		decks.append(deck)
	var paths: Array[String] = ["f1.deck", "f2.deck"]
	var pairs := [[0, 2], [0, 3], [1, 2], [1, 3]]
	# Field One: 3-1 vs A, 4-0 vs B; Field Two: 0-4 vs A, 1-3 vs B.
	var per_pair_records := [_records(3, 1), _records(4, 0), _records(0, 4), _records(1, 3)]
	var per_pair_stats := []
	for records in per_pair_records:
		per_pair_stats.append(SimStats.summarize(records))
	var t: Dictionary = lab._tournament_tables(decks, 2, paths, pairs,
		per_pair_records, per_pair_stats, 1)
	assert_eq(t.shown, 1, "--top 1")
	assert_eq(t.standings.size(), 2, "every field deck is ranked")
	assert_eq(t.standings[0].name, "Field One")
	assert_eq(t.standings[0].rank, 1)
	assert_eq(t.standings[0].stats.a_wins, 7)
	assert_eq(t.standings[0].stats.b_wins, 1)
	assert_eq(t.standings[1].name, "Field Two")
	assert_eq(t.standings[1].stats.a_wins, 1)
	assert_eq(t.standings[1].stats.b_wins, 7)
	# The gauntlet from its own side: A went 5-3 against the field, B 3-5.
	assert_eq(t.gauntlet[0].name, "Gauntlet A")
	assert_eq(t.gauntlet[0].stats.a_wins, 5)
	assert_eq(t.gauntlet[0].stats.b_wins, 3)
	assert_eq(t.gauntlet[1].name, "Gauntlet B")
	assert_eq(t.gauntlet[1].stats.a_wins, 3)
	# The files.
	var csv: PackedStringArray = String(t.standings_csv).strip_edges().split("\n")
	assert_eq(csv.size(), 3, "a header and every field deck")
	assert_eq(csv[0], "rank,deck,file,games,wins,losses,stalled,winrate,ci_low,ci_high,avg_turns,median_turns")
	assert_true(csv[1].begins_with("1,Field One,f1.deck,8,7,1,0,0.8750,"))
	assert_true(csv[2].begins_with("2,Field Two,f2.deck,8,1,7,0,0.1250,"))
	var top: PackedStringArray = String(t.top_txt).strip_edges().split("\n")
	assert_eq(top[top.size() - 1], "f1.deck", "top.txt ends in the best deck's path")
	assert_false(String(t.top_txt).contains("f2.deck"), "and lists only --top of them")
	assert_true(top[0].begins_with("#"), "its commentary is comments")
	assert_eq(t.standings_json.size(), 2)
	assert_eq(t.standings_json[0].file, "f1.deck")
	# The next round's reading of top.txt: a library deck by its res://
	# path, wherever the list sits; a full path as it is.
	assert_eq(lab.resolved_deck_path("big_green.deck"), "res://decks/big_green.deck")
	assert_eq(lab.resolved_deck_path("decks/big_green.deck"), "res://decks/big_green.deck")
	assert_eq(lab.resolved_deck_path("res://decks/big_green.deck"), "res://decks/big_green.deck")
	assert_eq(lab.resolved_deck_path("/abs/mine/0001.deck"), "/abs/mine/0001.deck")
	assert_eq(lab.resolved_deck_path("user://mine/0001.deck"), "user://mine/0001.deck")
	assert_eq(t.standings_json[0].rank, 1)
	assert_false(t.gauntlet_json[0].has("file"), "the gauntlet's rows have no field file")


func _records(wins: int, losses: int) -> Array:
	var out := []
	for i in wins:
		out.append({"a_won": true, "a_on_play": i % 2 == 0, "turns": 10, "stalled": false, "drawn": false})
	for i in losses:
		out.append({"a_won": false, "a_on_play": i % 2 == 1, "turns": 12, "stalled": false, "drawn": false})
	return out


func test_the_report_block_names_both_sizes_and_says_nothing_is_rated() -> void:
	var lab = _lab()
	var decks: Array[DeckList] = []
	for name in ["Field One", "Gauntlet A", "Gauntlet B"]:
		var deck := DeckList.new()
		deck.deck_name = name
		decks.append(deck)
	var paths: Array[String] = ["f1.deck"]
	var pairs := [[0, 1], [0, 2]]
	var per_pair_records := [_records(3, 1), _records(4, 0)]
	var per_pair_stats := []
	for records in per_pair_records:
		per_pair_stats.append(SimStats.summarize(records))
	var t: Dictionary = lab._tournament_tables(decks, 1, paths, pairs,
		per_pair_records, per_pair_stats, 10)
	var opts := _parse(FIELD + GAUNTLET + ["--games", "4"])
	var text := "\n".join(lab._tournament_block(opts, t, decks, 1, pairs, per_pair_stats, "games"))
	assert_string_contains(text, "TOURNAMENT: 1 field deck vs 2 gauntlet decks — 2 matchups x 4 games = 8 games")
	assert_string_contains(text, "STANDINGS — each field deck's record over the whole gauntlet, best first")
	assert_string_contains(text, "THE GAUNTLET — each opponent's record against the whole field, hardest first")
	assert_string_contains(text, "a field deck's record is 8 games (2 opponents x 4 games)")
	assert_string_contains(text, "one matchup is 4 games")
	assert_string_contains(text, "Elo: not written")
	assert_false(text.contains("THE BEST"), "best/worst opponents need a gauntlet of six")
	# A long title is cut to the column, never the row pushed off it.
	assert_eq(lab._fit("a name of twelve", 8), "a name..")
	assert_eq(lab._fit("short", 8), "short")
	assert_eq(lab._name_width([{"name": "x"}]), lab.NAME_WIDTH_MIN)
	assert_eq(lab._name_width([{"name": "x".repeat(90)}]), lab.NAME_WIDTH_MAX)


# ----------------------------------------------------------------- wire --

func test_the_worker_payload_carries_each_pile_once() -> void:
	var lab = _lab()
	var green := DeckList.load_file("res://decks/big_green.deck")
	var blue := DeckList.load_file("res://decks/blue_skies.deck")
	for i in 3:
		lab._tasks.append({"pair": 0, "seed": i, "a_on_play": true,
			"deck_a": green.cards, "deck_b": blue.cards,
			"sb_a": green.sideboard, "sb_b": blue.sideboard,
			"dealt": "", "profile_a": "wizard", "profile_b": "wizard"})
	var payload: Dictionary = lab._worker_payload(0, 3)
	assert_eq(payload.tasks.size(), 3)
	# Two decks and (at most) two sideboards, whatever the task count —
	# an empty sideboard is one pile too, shared by both seats.
	assert_true(payload.piles.size() <= 4 and payload.piles.size() >= 3,
		"the piles: %d" % payload.piles.size())
	for task in payload.tasks:
		for key in lab.PILE_KEYS:
			assert_eq(typeof(task[key]), TYPE_INT, "%s travels as an index" % key)
	assert_eq(payload.piles[int(payload.tasks[0].deck_a)], green.cards)
	assert_eq(payload.piles[int(payload.tasks[0].deck_b)], blue.cards)
	assert_eq(payload.tasks[0].deck_a, payload.tasks[2].deck_a, "the same deck, the same slot")
	assert_true(lab._tasks[0].deck_a is Array, "the parent's own tasks are untouched")
	# On the wire and back: the child plays the very game the parent would.
	lab._duel_opts = {"fingerprint": true, "best_of": 0, "sideboard": false}
	var direct: Dictionary = lab._play_task(lab._tasks[1])
	var in_path := _scratch("slice") + ".json"
	var out_path := in_path + ".out"
	_made.append(out_path)
	assert_true(lab._write(in_path, JSON.stringify(lab._worker_payload(1, 2))))
	var child = _lab()
	assert_eq(child._run_worker(in_path, out_path), 0)
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(out_path))
	assert_eq(records.size(), 1)
	assert_eq(records[0].fingerprint, direct.fingerprint, "same game")


# ------------------------------------------------------------------ e2e --

func test_a_small_tournament_end_to_end() -> void:
	var lab = _lab()
	var out := _scratch("run")
	var ledger := _scratch("ledger") + ".txt"
	# Big Green is on both sides: it does not play itself.
	var args := ["--field", "big_green.deck,blue_skies.deck",
		"--gauntlet", "white_knights.deck,big_green.deck",
		"--games", "1", "--procs", "1", "--jobs", "1", "--quiet", "--top", "1",
		"--elo-file", ledger, "--out", out]
	assert_eq(lab._main(PackedStringArray(args)), 0)
	var report := FileAccess.get_file_as_string(out + "/report.txt")
	assert_string_contains(report, "Deck Lab report (tournament mode)")
	assert_string_contains(report, "TOURNAMENT: 2 field decks vs 2 gauntlet decks — 3 matchups x 1 games = 3 games")
	assert_string_contains(report, "STANDINGS")
	assert_string_contains(report, "(the best 1 of 2; every deck is in standings.csv, and top.txt names these 1)")
	assert_string_contains(report, "THE GAUNTLET")
	assert_string_contains(report, "settings: top 1")
	assert_string_contains(report, "Elo: not written")
	assert_false(report.contains(" vs White Knights "), "no per-matchup lines in the report")
	assert_false(FileAccess.file_exists(ledger), "a tournament never writes the ledger")
	var results: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out + "/results.json"))
	assert_eq(results.mode, "tournament")
	assert_eq(results.rated, false)
	assert_eq(results.matchups.size(), 3, "the self-pair is skipped")
	assert_eq(results.standings.size(), 2)
	assert_eq(results.gauntlet.size(), 2)
	assert_eq(int(results.standings[0].rank), 1)
	var standings := FileAccess.get_file_as_string(out + "/standings.csv").strip_edges().split("\n")
	assert_eq(standings.size(), 3)
	var top := FileAccess.get_file_as_string(out + "/top.txt").strip_edges().split("\n")
	var paths := []
	for line in top:
		if not line.begins_with("#"):
			paths.append(line)
	assert_eq(paths.size(), 1, "--top 1")
	assert_true(FileAccess.file_exists(out + "/winrates.svg"))
	assert_true(FileAccess.file_exists(out + "/matchups.csv"))
	for name in ["report.txt", "results.json", "matchups.csv", "standings.csv",
			"top.txt", "winrates.svg", ".gdignore"]:
		var file: String = out + "/" + name
		if FileAccess.file_exists(file):
			_made.append(file)
	# Round two reads round one's top.txt as its field.
	var again = _lab()
	var opts: Dictionary = again._parse_args(PackedStringArray(
		["--field", out + "/top.txt", "--deck-b", "mountain_artillery.deck"]))
	assert_false(opts.has("error"), str(opts.get("error", "")))
	assert_eq(opts.field, paths)
	assert_eq(paths, ["res://decks/blue_skies.deck"] if paths[0].ends_with("blue_skies.deck")
		else ["res://decks/big_green.deck"], "top.txt names the deck where it is")


# ------------------------------------------------------- the AutoDeck CLI --

func test_a_set_from_a_pack_not_in_play_is_refused_by_pack_number() -> void:
	assert_eq(CardPacks.pack_of_set("ice"), "pack-3")
	assert_eq(CardPacks.pack_of_set("fem"), "pack-2")
	assert_eq(CardPacks.pack_of_set("hml"), "pack-4")
	assert_eq(CardPacks.pack_of_set("all"), "pack-5")
	assert_eq(CardPacks.pack_of_set("por"), "pack-6")
	assert_eq(CardPacks.pack_of_set("p02"), "pack-6")
	assert_eq(CardPacks.pack_of_set("5ed"), "pack-7")
	assert_eq(CardPacks.pack_of_set("4ed"), "", "a base set is in no pack")
	assert_eq(CardPacks.pack_of_set("zzz"), "")
	var cli = autofree(load("res://DeckLab/auto_deck_cli.gd").new())
	var opts: Dictionary = cli.parse_args(PackedStringArray(["--out", "x", "--sets", "ice"]))
	var message: String = cli.unknown_sets_message(opts)
	if CardRegistry.active_set_order().has("ice"):
		assert_eq(message, "", "the pack is in play here")
	else:
		assert_string_contains(message, "set 'ice' (Ice Age) is in card pack 3, which is not in play")
		assert_string_contains(message, "add `--packs 3`, or `--packs all`")
	assert_string_contains(cli.unknown_sets_message(
		cli.parse_args(PackedStringArray(["--out", "x", "--sets", "zzz"]))),
		"unknown set code 'zzz'")
	assert_true(String(cli.HELP).contains("THIS TOOL BUILDS DECKS AND PLAYS NO GAME"))
	assert_true(String(cli.HELP).contains("THE COUPLING, in one sentence"))
	# The tool's last line is the tournament to run on what it built,
	# with the packs it built from.
	var plain: String = cli.next_step_line("mine/", null)
	assert_string_contains(plain, "deck_lab.sh --field mine/ --gauntlet decks/ --group tournament --games 20 --no-elo")
	assert_false(plain.contains("--packs"), "no --packs given, none passed on")
	assert_string_contains(cli.next_step_line("mine/", ["pack-3", "pack-7"]), "--games 20 --packs 3,7 --no-elo")
	assert_string_contains(cli.next_step_line("mine/", []), "--games 20 --packs none --no-elo")
