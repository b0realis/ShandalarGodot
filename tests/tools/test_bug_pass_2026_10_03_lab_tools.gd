extends GutTest
## The tools' bug pass of 2026-10-03 — DeckLab/simulate.gd,
## DeckLab/auto_deck_cli.gd, DeckLab/elo_ledger.gd, tools/duel_soak.gd and
## tools/screenshot_tour.gd. Each test names the bug it pins:
##
##   * a fresh run appended to an older run's checkpoint.jsonl, and a
##     `--resume` of the new run then took the older run's games as its own;
##   * a reused `--out` kept an older run's records/, which the cap counted
##     and results.json reported;
##   * `--deck-a random` against several opponents booked every field game
##     against the first of them, in the ledger and in the caption;
##   * a negative `--seed` made every game roll its own, so the run could
##     not be repeated, and a seed near the top of int64 overflowed;
##   * a sweep whose control deck was refused left a folder with
##     `exit: null`, which is what an interrupted run looks like;
##   * an unfair `--dry-run` printed its warning on stdout ahead of the
##     plan, so stdout was not one JSON document;
##   * `.gdignore` went into any in-project `--out`, the project's own
##     folders included; a field deck that played nobody ranked at 50%
##     and went into top.txt; two default `--out` folders of one second
##     were one folder; `_write` trusted a write that failed;
##   * `--force` deleted the user's own `deck_*.deck` in a folder the
##     AutoDeck CLI never wrote; `--dry-run` passed an `--out` that is a
##     file; an empty pool exited 1 with no JSON; a basics-only sealed deal
##     passed the parser; `--distinct` retry seeds wrapped onto the run's
##     own;
##   * a ledger deck name with `|` was cut, one starting with `#` vanished;
##   * the soak took `--seeds 1,2,` and `--seeds ''` without a word;
##   * the screenshot tour erased the player's saved Stops.

var _made: Array[String] = []


func after_each() -> void:
	for path in _made:
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute):
			_remove_tree(absolute)
		elif FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	_made.clear()


static func _remove_tree(absolute: String) -> void:
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	dir.include_hidden = true
	for sub in dir.get_directories():
		_remove_tree(absolute.path_join(sub))
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(absolute)


func _lab():
	return autofree(load("res://DeckLab/simulate.gd").new())


func _auto():
	return autofree(load("res://DeckLab/auto_deck_cli.gd").new())


func _soak() -> GDScript:
	return load("res://tools/duel_soak.gd") as GDScript


func _scratch(kind: String) -> String:
	var path := "user://bug_pass_1003_%s_%d_%d" % [kind, Time.get_ticks_usec(), _made.size()]
	_made.append(path)
	return path


func _exists(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	return DirAccess.dir_exists_absolute(absolute) or FileAccess.file_exists(absolute)


func _put(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "cannot write " + path)
	if file != null:
		file.store_string(text)
		file.close()


func _json(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "expected " + path)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _logs_in(out: String) -> PackedStringArray:
	var names := PackedStringArray()
	var dir := DirAccess.open(out.path_join("records"))
	if dir == null:
		return names
	for file_name in dir.get_files():
		if file_name.ends_with(".log"):
			names.append(file_name)
	names.sort()
	return names


const DUEL := ["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck"]
const QUIET := ["--procs", "1", "--jobs", "1", "--quiet", "--no-elo", "--no-svg"]
const RECORD := {"a_won": true, "a_on_play": true, "turns": 5, "stalled": false, "drawn": false}


# ------------------------------------------------------ the checkpoint --

func test_a_fresh_run_truncates_an_older_runs_checkpoint() -> void:
	var lab = _lab()
	var out := _scratch("stale_cp")
	var absolute := ProjectSettings.globalize_path(out)
	assert_eq(DirAccess.make_dir_recursive_absolute(absolute), OK)
	var stale := RECORD.duplicate()
	stale["turns"] = 999
	_put(out.path_join(lab.CHECKPOINT),
		JSON.stringify({"arm": -1, "pair": 0, "seed": 2, "record": stale}) + "\n")
	lab._out_absolute = absolute
	lab._tasks = [{"pair": 0, "seed": 1}]
	lab._results = [RECORD.duplicate()]
	lab._checkpoint_open()
	lab._checkpoint_record(0)
	lab._checkpoint_close()
	var records: Dictionary = lab.checkpoint_records(out.path_join(lab.CHECKPOINT))
	assert_eq(records.keys(), ["-1/0/1"], "this run's game and nothing of the older run's")


func test_a_checkpoint_line_names_its_run_and_another_runs_lines_are_skipped() -> void:
	var lab = _lab()
	var out := _scratch("stamp")
	var absolute := ProjectSettings.globalize_path(out)
	assert_eq(DirAccess.make_dir_recursive_absolute(absolute), OK)
	lab._run_id = "run-B"
	lab._out_absolute = absolute
	lab._tasks = [{"pair": 0, "seed": 3}]
	lab._results = [RECORD.duplicate()]
	lab._checkpoint_open()
	lab._checkpoint_record(0)
	lab._checkpoint_close()
	var text := FileAccess.get_file_as_string(out.path_join(lab.CHECKPOINT))
	assert_string_contains(text, '"run":"run-B"', "the line says which run made it")
	var path := out.path_join("mixed.jsonl")
	_put(path, JSON.stringify({"run": "run-A", "arm": -1, "pair": 0, "seed": 1, "record": RECORD}) + "\n"
		+ JSON.stringify({"run": "run-B", "arm": -1, "pair": 0, "seed": 2, "record": RECORD}) + "\n"
		+ JSON.stringify({"arm": -1, "pair": 0, "seed": 4, "record": RECORD}) + "\n")
	var mine: Dictionary = lab.checkpoint_records(path, "run-B")
	assert_false(mine.has("-1/0/1"), "another run's line is not this run's game")
	assert_true(mine.has("-1/0/2"))
	assert_true(mine.has("-1/0/4"), "an unstamped line (an older build's) is still read")
	assert_eq(lab.checkpoint_records(path).size(), 3, "no run named: every line, as before")


func test_resume_takes_only_the_games_its_own_run_checkpointed() -> void:
	var lab = _lab()
	var out := _scratch("resume_own")
	var argv := PackedStringArray(DUEL + QUIET + ["--games", "4", "--seed", "5", "--out", out])
	assert_eq(lab._main(argv), 0, str(lab.last_error))
	var run := _json(out.path_join(lab.RUN_JSON))
	assert_true(String(run.get("run_id", "")) != "", "run.json names the run: " + str(run.keys()))
	run["exit"] = null
	_put(out.path_join(lab.RUN_JSON), JSON.stringify(run, "  ") + "\n")
	var own := String(run.run_id)
	var stale := RECORD.duplicate()
	stale["turns"] = 999
	_put(out.path_join(lab.CHECKPOINT),
		JSON.stringify({"run": own, "arm": -1, "pair": 0, "seed": 5, "record": RECORD}) + "\n"
		+ JSON.stringify({"run": own, "arm": -1, "pair": 0, "seed": 6, "record": RECORD}) + "\n"
		+ JSON.stringify({"run": "an-older-run", "arm": -1, "pair": 0, "seed": 7, "record": stale}) + "\n"
		+ JSON.stringify({"run": "an-older-run", "arm": -1, "pair": 0, "seed": 8, "record": stale}) + "\n")
	var again = _lab()
	assert_eq(again._main(PackedStringArray(["--resume", out])), 0, str(again.last_error))
	assert_eq(again._resumed, {"reused": 2, "played": 2}, "the older run's two are played again")
	var results := _json(out.path_join("results.json"))
	assert_true(float(results.matchups[0].avg_turns) < 500.0,
		"no 999-turn stale record in the average: %s" % results.matchups[0].avg_turns)
	assert_eq(String(_json(out.path_join(lab.RUN_JSON)).get("run_id", "")), own,
		"a resumed run keeps its run's name, so a second resume reads both halves")


# ---------------------------------------------------------- records/ --

func test_a_reused_out_starts_with_an_empty_records_folder() -> void:
	var out := _scratch("records")
	var first = _lab()
	assert_eq(first._main(PackedStringArray(DUEL + QUIET + ["--games", "3", "--seed", "1",
		"--record", "all", "--out", out])), 0, str(first.last_error))
	assert_eq(_logs_in(out).size(), 3)
	var second = _lab()
	assert_eq(second._main(PackedStringArray(["--deck-a", "blue_skies.deck", "--deck-b",
		"mountain_artillery.deck"] + QUIET + ["--games", "2", "--seed", "100",
		"--record", "all", "--out", out])), 0, str(second.last_error))
	var logs := _logs_in(out)
	assert_eq(logs.size(), 2, "only this run's games: " + str(logs))
	for name in logs:
		assert_true(name.contains("seed100_") or name.contains("seed101_"), name)
	assert_eq(int(_json(out.path_join("results.json")).records.written), 2)


# ------------------------------------------------- the field and Elo --

func test_a_random_deck_a_books_each_field_game_against_its_own_opponent() -> void:
	var lab = _lab()
	var out := _scratch("random_elo")
	var ledger_path := _scratch("ledger") + ".txt"
	assert_eq(lab._main(PackedStringArray(["--deck-a", "random",
		"--gauntlet", "big_green.deck,white_knights.deck",
		"--deck-pool", "decks/blue_skies.deck,decks/mountain_artillery.deck",
		"--games", "4", "--procs", "1", "--jobs", "1", "--quiet", "--no-svg",
		"--elo-file", ledger_path, "--out", out])), 0, str(lab.last_error))
	var ledger := EloLedger.load_from(ledger_path)
	var results := _json(out.path_join("results.json"))
	var decided := {}
	for matchup in results.matchups:
		decided[String(matchup.deck_b)] = int(matchup.a_wins) + int(matchup.b_wins)
	assert_true(ledger.entries.has("White Knights"), "the second opponent is rated: " + str(ledger.entries.keys()))
	for name in ["Big Green", "White Knights"]:
		if ledger.entries.has(name):
			assert_eq(int(ledger.entries[name].games), int(decided[name]),
				"%s is booked its own pair's games and no other's" % name)
	var against := {}
	for row in results.field:
		against[String(row.against)] = true
	assert_eq(against.keys().size(), 2, "each field row names the deck it played: " + str(results.field))
	var report := FileAccess.get_file_as_string(out.path_join("report.txt"))
	assert_string_contains(report, "each deck's win rate against Big Green")
	assert_string_contains(report, "each deck's win rate against White Knights")


# -------------------------------------------------------------- seeds --

func test_a_negative_or_overflowing_seed_is_refused() -> void:
	var lab = _lab()
	var out := _scratch("seed")
	assert_eq(lab._main(PackedStringArray(DUEL + QUIET + ["--games", "6", "--seed", "-6",
		"--out", out])), 2)
	assert_eq(lab.last_error.kind, "option", str(lab.last_error))
	assert_eq(lab.last_error.flag, "--seed")
	assert_false(_exists(out), "nothing made")
	var ceiling: int = lab.SEED_CEILING
	var high = _lab()
	assert_eq(high._main(PackedStringArray(DUEL + QUIET + ["--games", "10",
		"--seed", str(ceiling - 5), "--out", out])), 2, "the last games' seeds would pass the ceiling")
	assert_eq(high.last_error.flag, "--seed", str(high.last_error))
	assert_false(_exists(out))
	var edge = _lab()
	assert_eq(edge._main(PackedStringArray(DUEL + QUIET + ["--games", "10",
		"--seed", str(ceiling - 10), "--dry-run", "--out", out])), 0,
		"the highest seed that fits: " + str(edge.last_error))
	# The ceiling is where a JSON round trip (the checkpoint's) still
	# gives every seed back exactly.
	assert_eq(int(JSON.parse_string(str(ceiling))), ceiling)


# -------------------------------------------------- refusals and stdout --

func test_a_refused_sweep_control_deck_leaves_no_folder() -> void:
	var lab = _lab()
	var out := _scratch("sweep")
	assert_eq(lab._main(PackedStringArray(DUEL + QUIET + ["--sweep", "pays_sacrifices=on",
		"--control-deck-a", "decks/no_such_deck.deck", "--control-deck-b", "blue_skies.deck",
		"--games", "2", "--out", out])), 2)
	assert_eq(lab.last_error.kind, "deck", str(lab.last_error))
	assert_false(_exists(out), "no run.json that reads as an interrupted run")


func test_an_unfair_dry_run_prints_one_json_document() -> void:
	var out := _scratch("unfair_dry")
	var output: Array = []
	var status := OS.execute(OS.get_executable_path(), ["--headless", "--no-header",
		"--path", ProjectSettings.globalize_path("res://"),
		"--log-file", ProjectSettings.globalize_path(_scratch("child") + ".log"),
		"--script", "res://DeckLab/simulate.gd", "--",
		"--deck-a", "big_green.deck", "--deck-b", "white_knights.deck",
		"--profile-a", "unfair", "--dry-run", "--out", out], output, false)
	assert_eq(status, 0, "".join(PackedStringArray(output)))
	var stdout := "".join(PackedStringArray(output))
	var plan = JSON.parse_string(stdout)
	assert_true(plan is Dictionary, "stdout is the plan and nothing else: " + stdout)
	if plan is Dictionary:
		assert_true(bool(plan.get("dry_run", false)))


# ---------------------------------------------------------- the folder --

func test_the_importer_marker_goes_only_into_a_folder_the_lab_owns() -> void:
	var stamp := Time.get_ticks_usec()
	var foreign := "res://DeckLab/results/bug_pass_foreign_%d" % stamp
	_made.append(foreign)
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(foreign)), OK)
	_put(foreign.path_join("theirs.txt"), "x")
	var lab = _lab()
	assert_eq(lab._main(PackedStringArray(DUEL + QUIET + ["--games", "1", "--out", foreign])), 0,
		str(lab.last_error))
	assert_false(FileAccess.file_exists(foreign.path_join(".gdignore")),
		"a folder that held somebody else's files gets no marker")
	var made := "res://DeckLab/results/bug_pass_made_%d" % stamp
	_made.append(made)
	var second = _lab()
	assert_eq(second._main(PackedStringArray(DUEL + QUIET + ["--games", "1", "--out", made])), 0)
	assert_true(FileAccess.file_exists(made.path_join(".gdignore")), "a folder it made")
	var third = _lab()
	assert_eq(third._main(PackedStringArray(DUEL + QUIET + ["--games", "1", "--out", made])), 0)
	assert_true(FileAccess.file_exists(made.path_join(".gdignore")), "and one of its own runs")


func test_two_default_folders_of_one_second_are_two_folders() -> void:
	var lab = _lab()
	var base := _scratch("default_out")
	var first: String = lab.fresh_out_dir(base, true)
	var second: String = lab.fresh_out_dir(base, true)
	_made.append(second)
	assert_eq(first, base, "the plain name first")
	assert_ne(second, first, "the second run of the same second gets its own")
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(first)), "claimed")
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(second)), "claimed")
	var planned: String = lab.fresh_out_dir(base, false)
	_made.append(planned)
	assert_false(planned in [first, second], "a plan names a folder no run holds")
	assert_false(_exists(planned), "and makes nothing")


func test_a_failed_write_is_a_failure() -> void:
	# A file that opens and then refuses the bytes: procfs takes the open
	# and answers the write with EINVAL. (`/dev/full` is no use — Godot
	# will not open a device at all, so `_write` never reached its write.)
	var refusing := "/proc/self/oom_score_adj"
	if OS.get_name() != "Linux" or not FileAccess.file_exists(refusing):
		pending("needs Linux procfs")
		return
	var lab = _lab()
	assert_false(lab._write(refusing, "x".repeat(100000)), "the write itself failed")


func test_a_field_deck_that_played_nobody_is_ranked_last_and_not_listed() -> void:
	var lab = _lab()
	var decks: Array[DeckList] = []
	for name in ["Field One", "Field Two", "Gauntlet A"]:
		var deck := DeckList.new()
		deck.deck_name = name
		decks.append(deck)
	# Field One IS Gauntlet A's file, so its only pair was skipped.
	var pairs := [[1, 2]]
	var records := [[{"stalled": false, "a_on_play": true, "a_won": false, "turns": 7},
		{"stalled": false, "a_on_play": false, "a_won": false, "turns": 8}]]
	var stats := [SimStats.summarize(records[0])]
	var t: Dictionary = lab._tournament_tables(decks, 2,
		["f1.deck", "f2.deck"] as Array[String], pairs, records, stats, 10)
	assert_eq(String(t.standings[0].name), "Field Two", "the deck with games ranks first, at 0%")
	assert_eq(String(t.standings[1].name), "Field One")
	assert_eq(int(t.standings[1].stats.games), 0)
	assert_eq(int(t.shown), 1, "top.txt shows only what played")
	assert_false(String(t.top_txt).contains("f1.deck"), String(t.top_txt))
	assert_true(String(t.top_txt).contains("f2.deck"))


# ------------------------------------------------------------ AutoDeck --

func test_force_leaves_a_folder_without_a_manifest_alone() -> void:
	var cli = _auto()
	var out := _scratch("auto_foreign")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)), OK)
	_put(out.path_join("deck_my_favourite.deck"), "name: Mine\n4 Llanowar Elves\n")
	assert_eq(cli._main(PackedStringArray(["--out", out, "--count", "1", "--seed", "7",
		"--force", "--quiet"])), 0, str(cli.last_error))
	assert_true(FileAccess.file_exists(out.path_join("deck_my_favourite.deck")),
		"a deck file this tool never wrote stays")


func test_force_clears_only_what_the_old_manifest_lists() -> void:
	var out := _scratch("auto_listed")
	var first = _auto()
	assert_eq(first._main(PackedStringArray(["--out", out, "--count", "3", "--seed", "4242",
		"--quiet"])), 0, str(first.last_error))
	_put(out.path_join("deck_hand_made.deck"), "name: Mine\n4 Llanowar Elves\n")
	var second = _auto()
	assert_eq(second._main(PackedStringArray(["--out", out, "--count", "1", "--seed", "9",
		"--force", "--quiet"])), 0, str(second.last_error))
	var decks := PackedStringArray()
	for name in DirAccess.open(out).get_files():
		if name.begins_with("deck_") and name.ends_with(".deck"):
			decks.append(name)
	assert_eq(decks.size(), 2, "the three listed are gone; the new one and the unlisted one: " + str(decks))
	assert_true(FileAccess.file_exists(out.path_join("deck_hand_made.deck")))


func test_an_autodeck_dry_run_refuses_an_out_that_is_a_file() -> void:
	var out := _scratch("auto_file")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out)), OK)
	var file := out.path_join("a_file.txt")
	_put(file, "hi")
	var dry = _auto()
	assert_eq(dry._main(PackedStringArray(["--out", file, "--count", "1", "--dry-run",
		"--quiet"])), 1, "the run's own answer")
	assert_eq(dry.last_error.kind, "out", str(dry.last_error))
	var real = _auto()
	assert_eq(real._main(PackedStringArray(["--out", file, "--count", "1", "--quiet"])), 1)
	assert_eq(real.last_error.kind, "out")


func test_an_empty_pool_is_a_refusal_with_its_envelope() -> void:
	var cli = _auto()
	var inputs := _scratch("auto_inputs")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(inputs)), OK)
	var list := inputs.path_join("pool.txt")
	_put(list, "4 Lightning Bolt\n")
	var out := _scratch("auto_empty")
	assert_eq(cli._main(PackedStringArray(["--out", out, "--count", "1", "--seed", "4242",
		"--list", list, "--keep", "decks/mountain_artillery.deck",
		"--vary", "Lightning Bolt", "--quiet"])), 1)
	assert_false(cli.last_error.is_empty(), "the JSON line a driving program reads")
	assert_eq(cli.last_error.get("kind", ""), "pool", str(cli.last_error))
	assert_eq(int(cli.last_error.get("exit", 0)), 1)


func test_a_basics_only_sealed_deal_is_refused_by_the_parser() -> void:
	var cli = _auto()
	var opts: Dictionary = cli.parse_args(PackedStringArray(["--out", "x", "--source", "sealed",
		"--boosters", "0", "--starters", "0", "--free-lands", "2", "--extras", "0"]))
	assert_true(opts.has("error"), "basics are free in every deck: nothing to build from")
	assert_string_contains(str(opts.get("error", "")), "only basic lands")


func test_distinct_retry_seeds_never_wrap_onto_the_runs_own() -> void:
	var cli = _auto()
	var span: int = cli.SEED_MOST - cli.SEED_LEAST + 1
	assert_eq(cli.deck_seed(4242, span), cli.deck_seed(4242, 0), "the space is a ring")
	assert_eq(cli.retry_seed(4242, 10, 0), cli.deck_seed(4242, 10), "the first seed past the run's")
	assert_eq(cli.retry_seed(4242, span - 1, 0), cli.deck_seed(4242, span - 1), "the last fresh one")
	assert_eq(cli.retry_seed(4242, span - 1, 1), 0, "then none: every seed of the space is dealt")
	assert_eq(cli.retry_seed(4242, 3, span), 0)


# ------------------------------------------------------------- ledger --

func test_a_ledger_name_with_a_pipe_or_a_hash_round_trips() -> void:
	var path := _scratch("ledger_names") + ".txt"
	var ledger := EloLedger.new()
	ledger.path = path
	ledger.record_matchup("Burn | v2", "#1 Sligh", 30, 10)
	ledger.record_matchup("\\Slash", "Plain", 2, 2)
	assert_true(ledger.save())
	var back := EloLedger.load_from(path)
	assert_eq(back.entries.size(), 4, str(back.entries.keys()))
	for name in ["Burn | v2", "#1 Sligh", "\\Slash", "Plain"]:
		assert_true(back.entries.has(name), "%s is read back by its own name: %s" % [name, back.entries.keys()])
		if back.entries.has(name):
			assert_almost_eq(float(back.entries[name].elo), float(ledger.entries[name].elo), 0.05)
			assert_eq(int(back.entries[name].games), int(ledger.entries[name].games))


# --------------------------------------------------------- soak and tour --

func test_the_soak_refuses_an_empty_seed() -> void:
	assert_eq(_soak().parse_seeds("3,4"), {"seeds": [3, 4]})
	for bad in ["1,2,", "", ",", "1,,2", " "]:
		var read: Dictionary = _soak().parse_seeds(bad)
		assert_true(read.has("error"), "'%s' is refused, not shortened" % bad)


func test_the_tour_leaves_the_players_stops_alone() -> void:
	var source := FileAccess.get_file_as_string("res://tools/screenshot_tour.gd")
	assert_false(source.contains("clear_value(PhaseStops.SETTING_KEY)"),
		"erasing the key hands the player the defaults back over their own choice")
	assert_false(source.contains("stops.save()"), "the tour marks Stops for the camera only")
	assert_true(source.contains("duel.stops.clear_all()"), "in memory, which is all a screenshot needs")
