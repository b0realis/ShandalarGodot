extends GutTest
## THE TOOLS, FOR A PROGRAM — SECOND HALF (2026-09-27): what a program
## reads AFTER a run and asks BEFORE one, pinned in-process:
##
##   * `--record losses|stalls|all` writes each admitted game's engine
##     log to OUT/records/, named by pair, seed (and arm, duel) and
##     outcome, with a `#` header a program can read; `--record-max`
##     caps the count; results.json and sweep.json say how many;
##   * every `--out` ends with run.json — the argv, the version and the
##     commit, the packs, the seed, the exit code, the files written,
##     and `next`: the argv of the run that would settle what this one
##     left open, or null when nothing is open;
##   * DeckLab/lab_query.gd answers `check`, `packs` and `cards` as one
##     JSON document, exit 0 for an answer and 2 for a line it cannot
##     answer — kept in `last_answer` / `last_error` like the Lab's own
##     records, since a GUT test cannot read stdout;
##   * shandalar.sh is the one door, and the skin-pack scan talks on
##     stderr like the card-pack scan (the 0.40.28 play copy found it
##     ahead of the JSON on stdout).

var _made: Array[String] = []
var _before: Array[String] = []
var _had_value := false


func before_each() -> void:
	_had_value = Settings.has_value("enabled_card_packs")
	_before = Settings.enabled_card_packs()


func after_each() -> void:
	for path in _made:
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute):
			_remove_tree(absolute)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
	_made.clear()
	if _had_value:
		Settings.set_value("enabled_card_packs", _before, false)
	elif Settings.has_value("enabled_card_packs"):
		Settings.set_value("enabled_card_packs", [] as Array[String], false)
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()


## A run with records has a folder inside its folder.
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


func _query():
	return autofree(load("res://DeckLab/lab_query.gd").new())


func _scratch(kind: String) -> String:
	var path := "user://records_%s_%d_%d" % [kind, Time.get_ticks_usec(), _made.size()]
	_made.append(path)
	return path


func _json(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "expected " + path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "a JSON object in " + path)
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
const QUIET := ["--games", "2", "--procs", "1", "--jobs", "1", "--quiet", "--no-elo", "--no-svg"]
const CONTROL := ["--control-deck-a", "big_green.deck", "--control-deck-b", "white_knights.deck"]


# ----------------------------------------------------------- stderr --

func test_the_skin_pack_scan_talks_on_stderr() -> void:
	var source := FileAccess.get_file_as_string("res://game/skin_pack.gd")
	assert_true(source.contains('printerr("skin pack: mounted %s'), "the mount line is stderr")
	assert_true(source.contains('printerr("skin pack: moved %s'), "and the moved line")
	assert_false(source.contains('print("skin pack:'), "nothing of the scan on stdout")


# ----------------------------------------------------------- records --

func test_record_is_a_documented_switch_with_a_cap() -> void:
	var lab = _lab()
	assert_true(lab.FLAG_HINTS.has("--record"))
	assert_true(lab.FLAG_HINTS.has("--record-max"))
	assert_true(String(lab.HELP).contains("--record FILTER"))
	assert_true(String(lab.HELP).contains("--record-max N"))
	var opts: Dictionary = lab._parse_args(PackedStringArray(DUEL))
	assert_eq(opts.record, "", "off by default")
	assert_eq(opts.record_max, lab.RECORD_MAX_DEFAULT)
	opts = lab._parse_args(PackedStringArray(DUEL + ["--record", "stalls", "--record-max", "0"]))
	assert_eq(opts.record, "stalls")
	assert_eq(opts.record_max, 0, "0 is no cap")
	var out := _scratch("record_bad")
	var code: int = lab._main(PackedStringArray(DUEL + QUIET + ["--record", "wins", "--out", out]))
	assert_eq(code, 2, "a filter the Lab does not know is a refusal")
	assert_eq(lab.last_error.flag, "--record", str(lab.last_error))
	assert_true(String(lab.last_error.message).contains("losses, stalls, all"))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(out)))
	var again = _lab()
	code = again._main(PackedStringArray(DUEL + QUIET + ["--record-max", "-1", "--out", out]))
	assert_eq(code, 2)
	assert_eq(again.last_error.flag, "--record-max", str(again.last_error))


func test_what_a_filter_admits_and_how_a_log_is_named() -> void:
	var lab = _lab()
	for outcome in ["a_won", "a_lost", "drawn", "stalled"]:
		assert_true(lab.record_admits("all", outcome), outcome)
	assert_true(lab.record_admits("losses", "a_lost"))
	assert_false(lab.record_admits("losses", "a_won"))
	assert_false(lab.record_admits("losses", "stalled"), "a stall is not a loss")
	assert_true(lab.record_admits("stalls", "stalled"))
	assert_false(lab.record_admits("stalls", "a_lost"))
	assert_false(lab.record_admits("", "a_lost"), "no filter, nothing")
	var context := {"pair": 3, "seed": 41, "a_seat": 0, "name_a": "A", "name_b": "B",
		"arm": -1, "duel": 0}
	assert_eq(lab.record_file_name(context, "a_lost"), "pair3_seed41_a_lost.log")
	context.arm = 2
	context.duel = 3
	assert_eq(lab.record_file_name(context, "stalled"), "pair3_seed41_arm2_duel3_stalled.log",
		"a sweep arm and a match's duel number keep two logs of one seed apart")


func test_a_recorded_duel_writes_one_log_per_game() -> void:
	var lab = _lab()
	var out := _scratch("record_all")
	var argv := PackedStringArray(DUEL + QUIET + ["--seed", "5", "--record", "all", "--out", out])
	var code: int = lab._main(argv)
	assert_eq(code, 0, str(lab.last_error))
	var logs := _logs_in(out)
	assert_eq(logs.size(), 2, "two games, two logs: " + str(logs))
	if logs.size() == 2:
		assert_true(logs[0].begins_with("pair0_seed5_"), logs[0])
		assert_true(logs[1].begins_with("pair0_seed6_"), logs[1])
		var text := FileAccess.get_file_as_string(out.path_join("records").path_join(logs[0]))
		var lines := text.split("\n")
		assert_eq(lines[0], "# deck_a: Big Green")
		assert_eq(lines[1], "# deck_b: White Knights")
		assert_eq(lines[2], "# pair: 0")
		assert_eq(lines[3], "# seed: 5")
		assert_true(lines[4].begins_with("# a_on_play: "), lines[4])
		assert_true(lines[5].begins_with("# outcome: "), lines[5])
		assert_true(logs[0].ends_with("_" + lines[5].trim_prefix("# outcome: ") + ".log"),
			"the file is named by the outcome the header states")
		assert_true(lines[6].begins_with("# turns: "), lines[6])
		assert_true(lines[7].begins_with("# lines: "), lines[7])
		assert_eq(int(lines[7].trim_prefix("# lines: ")), lines.size() - 9,
			"the count is the engine lines after the header (the file ends in a newline)")
		assert_true(text.contains("== Turn 1"), "the engine's own log")
	var results := _json(out.path_join("results.json"))
	assert_true(results.has("records"), "results.json names the records")
	if results.has("records"):
		assert_eq(results.records.filter, "all")
		assert_eq(int(results.records.max), lab.RECORD_MAX_DEFAULT)
		assert_eq(int(results.records.written), 2)
		assert_eq(results.records.dir, "records")
	var run := _json(out.path_join("run.json"))
	assert_true(Array(run.get("files", [])).has("records/"), str(run.get("files")))


func test_record_max_caps_and_losses_filters() -> void:
	var lab = _lab()
	var out := _scratch("record_cap")
	var code: int = lab._main(PackedStringArray(DUEL + QUIET + ["--seed", "5", "--record", "all",
		"--record-max", "1", "--out", out]))
	assert_eq(code, 0, str(lab.last_error))
	assert_eq(_logs_in(out).size(), 1, "the cap")
	var results := _json(out.path_join("results.json"))
	assert_eq(int(results.get("records", {}).get("written", -1)), 1)
	var losses = _lab()
	var out_losses := _scratch("record_losses")
	code = losses._main(PackedStringArray(DUEL + QUIET + ["--seed", "5", "--record", "losses",
		"--out", out_losses]))
	assert_eq(code, 0, str(losses.last_error))
	for name in _logs_in(out_losses):
		assert_true(name.ends_with("_a_lost.log"), "only the losses: " + name)
	var plain = _lab()
	var out_plain := _scratch("record_off")
	code = plain._main(PackedStringArray(DUEL + QUIET + ["--seed", "5", "--out", out_plain]))
	assert_eq(code, 0)
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(out_plain.path_join("records"))),
		"no switch, no folder")
	assert_false(_json(out_plain.path_join("results.json")).has("records"), "and no key")


# ---------------------------------------------------------- run.json --

func test_a_duel_leaves_run_json_with_its_next_step() -> void:
	var lab = _lab()
	var out := _scratch("run_json")
	var argv := PackedStringArray(DUEL + QUIET + ["--seed", "9", "--out", out])
	var code: int = lab._main(argv)
	assert_eq(code, 0, str(lab.last_error))
	var run := _json(out.path_join("run.json"))
	assert_eq(run.get("tool"), "deck_lab")
	assert_eq(run.get("version"), LabConsole.version())
	assert_eq(run.get("git"), LabConsole.git_sha())
	assert_eq(run.get("argv"), Array(argv), "the line as typed")
	assert_eq(run.get("mode"), "duel")
	assert_eq(int(run.get("seed", -1)), 9)
	assert_eq(int(run.get("exit", -1)), 0)
	assert_eq(run.get("out"), out)
	assert_true(String(run.get("started", "")).ends_with("Z"), "UTC, spelled so: " + str(run.get("started")))
	assert_true(run.has("packs"))
	assert_eq(run.get("packs_on"), Array(Settings.enabled_card_packs()))
	assert_true(float(run.get("elapsed_seconds", -1.0)) >= 0.0)
	assert_eq(run.get("files"), ["report.txt", "results.json", "matchups.csv"])
	assert_true(run.has("next"), "the next step, or null")
	var next = run.get("next")
	if next != null:
		assert_true(next.has("why"), str(next))
		var again: Array = next.get("argv", [])
		assert_true(again.has("--games"), str(again))
		assert_eq(again[again.find("--games") + 1], "8", "four times the games")
		assert_eq(again[again.find("--out") + 1], out + "_more")
		assert_true(again.has("--no-elo"), "unrated")
		assert_eq(again.count("--no-elo"), 1, "and only once, though this run had it too")
		assert_false(again.has("--dry-run"))
		assert_eq(again[again.find("--seed") + 1], "9", "the rest of the line rides along")
	else:
		var results := _json(out.path_join("results.json"))
		assert_true(results.has("pairs"), "no next step: nothing straddled even")


func test_a_refused_run_leaves_no_run_json_and_a_broken_one_does() -> void:
	var lab = _lab()
	var out := _scratch("run_json_refused")
	var code: int = lab._main(PackedStringArray(["--deck-a", "big_gren.deck", "--deck-b",
		"white_knights.deck"] + QUIET + ["--out", out]))
	assert_eq(code, 2)
	assert_false(FileAccess.file_exists(out.path_join("run.json")), "a refusal makes no folder")


func test_a_tournament_run_json_points_at_its_top() -> void:
	var lab = _lab()
	var out := _scratch("run_json_tournament")
	var argv := PackedStringArray(["--field", "big_green.deck,blue_skies.deck",
		"--gauntlet", "white_knights.deck", "--group", "tournament"] + QUIET + ["--seed", "3", "--out", out])
	var code: int = lab._main(argv)
	assert_eq(code, 0, str(lab.last_error))
	var run := _json(out.path_join("run.json"))
	assert_eq(run.get("mode"), "tournament")
	assert_true(FileAccess.file_exists(out.path_join("top.txt")))
	var next = run.get("next")
	assert_true(next is Dictionary, "a tournament always has a next step: its top, at more games")
	if next is Dictionary:
		var again: Array = next.argv
		assert_eq(again[again.find("--field") + 1], out.path_join("top.txt"))
		assert_eq(again.count("--field"), 1, "the typed field is stripped")
		assert_eq(again[again.find("--games") + 1], "10", "five times the games")
		assert_eq(again[again.find("--out") + 1], out + "_top")
		assert_eq(again[again.find("--gauntlet") + 1], "white_knights.deck", "the same gauntlet")
		assert_true(String(next.why).contains("five times"))


func test_a_sweep_run_json_reports_its_control() -> void:
	var lab = _lab()
	var out := _scratch("run_json_sweep")
	var argv := PackedStringArray(DUEL + ["--sweep", "pays_the_rent=on,off", "--null", "off"]
		+ CONTROL + QUIET + ["--seed", "3", "--out", out])
	var code: int = lab._main(argv)
	assert_true(code == 0 or code == lab.EXIT_CONTROL_MOVED, "played: " + str(lab.last_error))
	var run := _json(out.path_join("run.json"))
	assert_eq(run.get("mode"), "sweep")
	assert_eq(int(run.get("exit", -1)), code, "run.json says how the run ended")
	assert_eq(run.get("control_pass"), code == 0)
	assert_eq(run.get("argv"), Array(argv))
	assert_true(Array(run.get("files", [])).has("sweep.json"))
	if code == lab.EXIT_CONTROL_MOVED:
		assert_null(run.get("next"), "a moved control is not settled by more games of the same")
	elif run.get("next") != null:
		var again: Array = run.next.argv
		assert_eq(again[again.find("--games") + 1], "8")
		assert_eq(again[again.find("--out") + 1], out + "_more")
		assert_true(again.has("--sweep"), "the sweep line rides along")


func test_argv_without_strips_valued_flags_and_toggles() -> void:
	var lab = _lab()
	var argv := PackedStringArray(["--deck-a", "a.deck", "--games", "4", "--dry-run", "--out", "x",
		"--no-elo", "--seed", "1"])
	assert_eq(lab.argv_without(argv, ["--games", "--out"], ["--dry-run"]),
		["--deck-a", "a.deck", "--no-elo", "--seed", "1"])
	assert_eq(lab.argv_without(argv, [], []), Array(argv), "nothing named, nothing stripped")
	assert_eq(lab.argv_without(PackedStringArray(["--games"]), ["--games"], []), [],
		"a valued flag at the end, with no value, still goes")


func test_git_sha_reads_the_checkout() -> void:
	var sha := LabConsole.git_sha()
	assert_eq(sha.length(), 40, "a full commit id: '%s'" % sha)
	assert_true(sha.is_valid_hex_number(false), sha)


func test_an_autodeck_run_leaves_run_json_with_the_lab_line_as_argv() -> void:
	var cli = _auto()
	var out := _scratch("auto_run_json")
	var argv := PackedStringArray(["--count", "2", "--seed", "11", "--colors", "G", "--quiet", "--out", out])
	var code: int = cli._main(argv)
	assert_eq(code, 0, str(cli.last_error))
	var run := _json(out.path_join("run.json"))
	assert_eq(run.get("tool"), "auto_deck")
	assert_eq(run.get("version"), LabConsole.version())
	assert_eq(run.get("git"), LabConsole.git_sha())
	assert_eq(run.get("argv"), Array(argv))
	assert_eq(int(run.get("seed", -1)), 11)
	assert_false(bool(run.get("seed_rolled", true)))
	assert_eq(int(run.get("count", -1)), 2)
	assert_eq(int(run.get("exit", -1)), 0)
	assert_eq(int(run.get("files", {}).get("decks", -1)), 2)
	assert_eq(run.get("files", {}).get("manifest"), out.path_join("decks.csv"))
	assert_eq(run.get("packs_on"), Array(Settings.enabled_card_packs()))
	assert_true(String(run.get("started", "")).ends_with("Z"))
	var next: Dictionary = run.get("next", {})
	assert_eq(next.get("argv"), cli.next_step_argv(out, cli._packs_in_force, ""))
	assert_eq(cli.next_step_line(out, cli._packs_in_force, ""),
		"next: DeckLab/deck_lab.sh " + " ".join(PackedStringArray(next.get("argv", []))),
		"the printed line and the argv are the same words")
	var rolled = _auto()
	var out_rolled := _scratch("auto_run_json_rolled")
	assert_eq(rolled._main(PackedStringArray(["--count", "1", "--quiet", "--out", out_rolled])), 0)
	var run_rolled := _json(out_rolled.path_join("run.json"))
	assert_true(bool(run_rolled.get("seed_rolled", false)), "no --seed: run.json says it rolled one")
	assert_true(int(run_rolled.get("seed", 0)) != 0, "and which")


func test_next_step_argv_names_the_packs_and_the_held_deck() -> void:
	var cli = _auto()
	assert_eq(cli.next_step_argv("mine", null),
		["--field", "mine", "--gauntlet", "decks/", "--group", "tournament", "--games", "20", "--no-elo"])
	assert_eq(cli.next_step_argv("mine", ["pack-3", "pack-7"], "keep.deck"),
		["--field", "mine", "--field", "keep.deck", "--gauntlet", "decks/", "--group", "tournament",
			"--games", "20", "--packs", "3,7", "--no-elo"])
	assert_eq(cli.next_step_argv("mine", []),
		["--field", "mine", "--gauntlet", "decks/", "--group", "tournament", "--games", "20",
			"--packs", "none", "--no-elo"])


# --------------------------------------------------------- lab_query --

func test_check_reports_a_deck_instead_of_refusing_it() -> void:
	var query = _query()
	var code: int = query._main(PackedStringArray(["check", "big_green.deck", "--format", "tournament"]))
	assert_eq(code, 0, str(query.last_error))
	var answer: Dictionary = query.last_answer
	assert_eq(answer.tool, "lab_query")
	assert_eq(answer.query, "check")
	assert_eq(answer.decks.size(), 1)
	var deck: Dictionary = answer.decks[0]
	assert_eq(deck.file, "big_green.deck")
	assert_eq(deck.path, "decks/big_green.deck", "where it was found")
	assert_eq(deck.name, "Big Green")
	assert_eq(deck.cards, 40)
	assert_eq(deck.sideboard, 15)
	assert_eq(deck.errors, [])
	assert_eq(deck.unknown, [])
	assert_eq(deck.packs_needed, [])
	assert_eq(deck.packs_missing, [])
	assert_false(deck.format.ok, "Regrowth is restricted")
	assert_true(String(deck.format.problem).contains("Regrowth"))
	assert_false(deck.playable, "an unplayable deck is an answer, exit 0")
	assert_false(answer.playable)
	assert_eq(answer.packs_on, Array(Settings.enabled_card_packs()))
	var plain = _query()
	assert_eq(plain._main(PackedStringArray(["check", "big_green.deck", "white_knights.deck"])), 0)
	assert_eq(plain.last_answer.decks.size(), 2)
	assert_true(plain.last_answer.playable, "no format asked: both play")
	assert_false(plain.last_answer.decks[0].has("format"))


func test_check_lists_unknown_names_with_their_pack_or_their_neighbours() -> void:
	var path := _scratch("probe") + ".deck"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("name: Probe\n4 Jester's Cap\n4 Sera Angel\n20 Island\nnot a line\nSB: 2 Jester's Cap\n")
	f.close()
	var query = _query()
	var code: int = query._main(PackedStringArray(["check", path, "--packs", "none"]))
	assert_eq(code, 0, str(query.last_error))
	var deck: Dictionary = query.last_answer.decks[0]
	assert_eq(deck.name, "Probe")
	assert_eq(deck.cards, 28)
	assert_eq(deck.sideboard, 2)
	assert_eq(deck.errors.size(), 1, str(deck.errors))
	assert_true(String(deck.errors[0]).contains("not a line"))
	assert_eq(deck.unknown.size(), 2, str(deck.unknown))
	var by_name := {}
	for entry in deck.unknown:
		by_name[entry.name] = entry
	assert_true(by_name.has("Jester's Cap") and by_name.has("Sera Angel"), str(by_name.keys()))
	if by_name.has("Jester's Cap"):
		assert_eq(by_name["Jester's Cap"].pack, "pack-3", "Ice Age supplies it")
		assert_eq(int(by_name["Jester's Cap"].count), 6, "main and side together")
		assert_eq(by_name["Jester's Cap"].where, "both")
		assert_false(by_name["Jester's Cap"].has("near"), "a packed card needs no neighbours")
	if by_name.has("Sera Angel"):
		assert_eq(by_name["Sera Angel"].pack, "", "no pack: misspelled")
		assert_eq(by_name["Sera Angel"].where, "main")
		assert_eq(Array(by_name["Sera Angel"].near), ["Serra Angel"])
	assert_eq(deck.packs_needed, ["pack-3"])
	assert_eq(deck.packs_missing, ["pack-3"], "--packs none: off")
	assert_false(deck.playable)
	assert_eq(query.last_answer.packs, [], "the switch's own value")


func test_check_refuses_a_missing_deck_naming_what_it_tried() -> void:
	var query = _query()
	var code: int = query._main(PackedStringArray(["check", "big_gren.deck"]))
	assert_eq(code, 2)
	assert_eq(query.last_error.tool, "lab_query")
	assert_eq(query.last_error.kind, "deck")
	assert_eq(query.last_error.path, "big_gren.deck")
	assert_eq(query.last_error.tried.size(), 3)
	assert_true(Array(query.last_error.suggestions).has("decks/big_green.deck"), str(query.last_error))
	assert_true(query.last_answer.is_empty())
	var none = _query()
	assert_eq(none._main(PackedStringArray(["check"])), 2, "no deck named")
	var packs = _query()
	assert_eq(packs._main(PackedStringArray(["check", "big_green.deck", "--packs", "99"])), 2)
	assert_eq(packs.last_error.kind, "packs")
	var format = _query()
	assert_eq(format._main(PackedStringArray(["check", "big_green.deck", "--format", "vintage"])), 2)
	assert_eq(format.last_error.flag, "--format")


func test_packs_lists_every_pack_this_build_knows() -> void:
	var query = _query()
	assert_eq(query._main(PackedStringArray(["packs"])), 0, str(query.last_error))
	var answer: Dictionary = query.last_answer
	assert_eq(answer.query, "packs")
	assert_eq(answer.known, Array(CardPacks.known_ids()))
	assert_eq(answer.packs.size(), CardPacks.known_ids().size())
	assert_eq(answer.enabled, Array(Settings.enabled_card_packs()))
	for row in answer.packs:
		assert_true(row.has("id") and row.has("label") and row.has("available")
			and row.has("enabled") and row.has("path") and row.has("rejection"), str(row))
		assert_eq(row.label, CardPacks.label_for(String(row.id)))
		assert_eq(bool(row.available), Array(answer.available).has(row.id))
		if row.available:
			assert_true(int(row.cards) > 0, "a found pack counts its cards")
			assert_true(row.sets.size() > 0)
		else:
			assert_false(row.has("cards"))


func test_cards_records_a_known_and_an_unknown_card() -> void:
	var query = _query()
	assert_eq(query._main(PackedStringArray(["cards", "Serra Angel", "Sera Angel"])), 0,
		str(query.last_error))
	var rows: Array = query.last_answer.cards
	assert_eq(rows.size(), 2)
	var angel: Dictionary = rows[0]
	assert_true(angel.known)
	assert_eq(angel.name, "Serra Angel")
	assert_eq(angel.cost, "{3}{W}{W}")
	assert_eq(int(angel.mana_value), 5)
	assert_eq(angel.colors, ["White"])
	assert_eq(angel.types, ["Creature"])
	assert_eq(angel.subtypes, ["angel"])
	assert_eq(int(angel.power), 4)
	assert_eq(int(angel.toughness), 4)
	assert_true(Array(angel.keywords).has("Flying"), str(angel.keywords))
	assert_true(Array(angel.keywords).has("Vigilance"))
	assert_true(String(angel.text).to_lower().contains("flying"))
	assert_eq(angel.set, "2ed")
	assert_true(Array(angel.sets).has("2ed"))
	assert_eq(angel.rarity, "uncommon")
	assert_eq(angel.pack, "", "a base card")
	var typo: Dictionary = rows[1]
	assert_false(typo.known)
	assert_eq(typo.name, "Sera Angel")
	assert_eq(Array(typo.near), ["Serra Angel"])
	assert_false(typo.has("cost"))
	var land = _query()
	assert_eq(land._main(PackedStringArray(["cards", "Island"])), 0)
	var island: Dictionary = land.last_answer.cards[0]
	assert_eq(island.types, ["Land"])
	assert_eq(island.supertypes, ["Basic"])
	assert_false(island.has("power"), "a land has no power")
	assert_eq(land._main(PackedStringArray(["cards"])), 2, "no name asked")


func test_an_unknown_query_or_option_is_a_refusal() -> void:
	var query = _query()
	assert_eq(query._main(PackedStringArray(["chekc", "x.deck"])), 2)
	assert_eq(query.last_error.kind, "option")
	assert_eq(query.last_error.verb, "chekc")
	assert_eq(Array(query.last_error.suggestions), ["check"])
	var option = _query()
	assert_eq(option._main(PackedStringArray(["cards", "Island", "--games", "2"])), 2)
	assert_eq(option.last_error.flag, "--games")
	var value = _query()
	assert_eq(value._main(PackedStringArray(["packs", "--packs"])), 2, "a value missing")
	assert_eq(value.last_error.flag, "--packs")
	var help = _query()
	assert_eq(help._main(PackedStringArray([])), 0, "a bare line is the manual")
	assert_eq(help._main(PackedStringArray(["--help"])), 0)
	assert_true(String(help.HELP).contains("check") and String(help.HELP).contains("packs")
		and String(help.HELP).contains("cards"))


func test_the_one_door_and_the_launchers() -> void:
	assert_true(FileAccess.file_exists("res://shandalar.sh"))
	var door := FileAccess.get_file_as_string("res://shandalar.sh")
	for line in ['lab) exec DeckLab/deck_lab.sh "$@" ;;', 'autodeck) exec DeckLab/auto_deck_cli.sh "$@" ;;',
			'check | packs | cards) exec DeckLab/lab_query.sh "$verb" "$@" ;;',
			'convert) exec ./deck_convert.sh "$@" ;;', '{"error":{"tool":"shandalar","exit":2']:
		assert_true(door.contains(line), line)
	assert_true(FileAccess.file_exists("res://DeckLab/lab_query.sh"))
	assert_true(FileAccess.get_file_as_string("res://DeckLab/lab_query.sh").contains(
		"--script res://DeckLab/lab_query.gd"))
	var main_script := FileAccess.get_file_as_string("res://game/main.gd")
	assert_true(main_script.contains('const LAB_QUERY_FLAG := "--lab-query"'))
	assert_true(main_script.contains('_run_headless_tool(LAB_QUERY_FLAG, "res://DeckLab/lab_query.gd")'),
		"a release hosts the query through the game binary, like the Lab")
