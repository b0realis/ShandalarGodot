extends GutTest
## THE TOOLS, FOR A PROGRAM (2026-09-27) — the Deck Lab and the AutoDeck
## CLI as a program drives them, pinned in-process (a GUT test cannot
## read the tools' stdout, so each tool keeps its last refusal and its
## last plan in `last_error` / `last_plan`, the very records it printed):
##
##   * every refusal before a game or a deck is ONE line of JSON on
##     stdout — {"error": {"tool", "exit", "kind", "message", "flag",
##     "suggestions", ...}} — `kind` the thing to branch on, `flag` the
##     flag the message names, `suggestions` what "did you mean" said;
##   * `--dry-run` runs every check, prints the plan as JSON, makes no
##     folder and exits 0 — the plan's `total` is the games (or matches)
##     the run would play, the sweep's is arms × pairs × games;
##   * the AutoDeck CLI's `--dry-run` reports the seed it would roll,
##     the files it would write and the disk they take, before
##     `_prepare_out_dir` could clear anything.

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
			var dir := DirAccess.open(absolute)
			dir.include_hidden = true
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(absolute)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
	_made.clear()
	if _had_value:
		Settings.set_value("enabled_card_packs", _before, false)
	elif Settings.has_value("enabled_card_packs"):
		Settings.set_value("enabled_card_packs", [] as Array[String], false)
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()


func _lab():
	return autofree(load("res://DeckLab/simulate.gd").new())


func _auto():
	return autofree(load("res://DeckLab/auto_deck_cli.gd").new())


func _scratch(kind: String) -> String:
	var path := "user://for_machines_%s_%d_%d" % [kind, Time.get_ticks_usec(), _made.size()]
	_made.append(path)
	return path


func _exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))


const DUEL := ["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck"]
const QUIET := ["--games", "2", "--procs", "1", "--jobs", "1", "--quiet", "--no-elo", "--no-svg"]
const CONTROL := ["--control-deck-a", "big_green.deck", "--control-deck-b", "white_knights.deck"]


# ------------------------------------------------------- the envelope --

func test_the_flag_a_message_names() -> void:
	assert_eq(LabConsole.flag_named("unknown option '--gmes' — did you mean --games?"), "--gmes",
		"the typed flag, not the suggested one")
	assert_eq(LabConsole.flag_named("--games needs a value  (--games N)"), "--games")
	assert_eq(LabConsole.flag_named("--sweep needs --control-deck-a and --control-deck-b"), "--sweep")
	assert_eq(LabConsole.flag_named("deck file not found: 'x.deck'"), "", "no flag, no key")
	assert_eq(LabConsole.flag_named("a-b--c"), "", "a hyphen inside a word is not a flag")
	assert_eq(LabConsole.flag_named("-h is the help"), "-h")
	assert_eq(LabConsole.flag_named("/tmp/-scratch/x.deck cannot be played: proxies"), "",
		"a path segment that begins with a hyphen is a path, not a flag")
	assert_eq(LabConsole.flag_named("/tmp/-scratch/x.deck: --packs needs a value"), "--packs")


func test_the_record_and_the_line() -> void:
	var record: Dictionary = LabConsole.error_record("deck_lab", 2,
		"unknown option '--gmes' — did you mean --games?", {"suggestions": ["--games"]})
	assert_eq(record.tool, "deck_lab")
	assert_eq(record.exit, 2)
	assert_eq(record.kind, "option", "the default kind")
	assert_eq(record.flag, "--gmes")
	assert_eq(record.suggestions, ["--games"])
	var deck: Dictionary = LabConsole.error_record("deck_lab", 2, "deck file not found: 'x'",
		{"kind": "deck", "path": "x", "flag": "--deck-a"})
	assert_eq(deck.kind, "deck")
	assert_eq(deck.flag, "--deck-a", "an explicit flag wins over the scan")
	assert_eq(deck.path, "x")
	var line := LabConsole.error_line("auto_deck", 1, "no pool", {"kind": "pool"})
	var back = JSON.parse_string(line)
	assert_not_null(back, "one line of JSON")
	assert_true(back.has("error") and back.error.kind == "pool" and back.error.exit == 1)
	assert_false(back.error.has("flag"), "no flag named, no flag key")
	assert_eq(line.count("\n"), 0, "ONE line")


func test_the_estimate_is_labelled_a_guess() -> void:
	var guess: Dictionary = LabConsole.estimate(100)
	assert_eq(guess.seconds, 5)
	assert_true(String(guess.note).contains("nominal"))
	assert_eq(LabConsole.estimate(1).seconds, 1, "rounded up, never 0 for a game")
	var plan := LabConsole.plan_line({"mode": "duel", "total": 4})
	var back = JSON.parse_string(plan)
	assert_true(back.dry_run, "the plan says it is a plan")
	assert_eq(back.mode, "duel")


# ------------------------------------------------- the lab's refusals --

func test_an_unknown_lab_option_is_a_refusal_with_suggestions() -> void:
	var lab = _lab()
	var out := _scratch("gmes")
	var code: int = lab._main(PackedStringArray(DUEL + ["--gmes", "2", "--quiet", "--out", out]))
	assert_eq(code, 2)
	assert_eq(lab.last_error.kind, "option")
	assert_eq(lab.last_error.exit, 2)
	assert_eq(lab.last_error.flag, "--gmes")
	assert_true(lab.last_error.suggestions.has("--games"), str(lab.last_error))
	assert_false(_exists(out), "no folder on a refusal")


func test_a_missing_deck_is_a_refusal_naming_what_was_tried() -> void:
	var lab = _lab()
	var out := _scratch("nodeck")
	var code: int = lab._main(PackedStringArray(["--deck-a", "big_gren.deck", "--deck-b",
		"white_knights.deck"] + QUIET + ["--out", out]))
	assert_eq(code, 2)
	assert_eq(lab.last_error.kind, "deck")
	assert_eq(lab.last_error.path, "big_gren.deck")
	assert_eq(lab.last_error.tried.size(), 3, "the three places a deck is looked for")
	var near := PackedStringArray()
	for path in lab.last_error.suggestions:
		near.append(String(path).get_file())
	assert_true(near.has("big_green.deck"), str(lab.last_error))
	assert_false(_exists(out))


func test_a_sweep_without_its_control_is_a_refusal_of_kind_option() -> void:
	var lab = _lab()
	var out := _scratch("sweep_no_control")
	var code: int = lab._main(PackedStringArray(DUEL + ["--sweep", "pays_the_rent=on,off"]
		+ QUIET + ["--out", out]))
	assert_eq(code, 2)
	assert_eq(lab.last_error.kind, "option")
	assert_eq(lab.last_error.flag, "--sweep", str(lab.last_error))


func test_an_out_that_is_a_file_is_a_refusal_of_kind_out() -> void:
	var lab = _lab()
	var out := _scratch("outfile")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var code: int = lab._main(PackedStringArray(DUEL + QUIET + ["--out", out]))
	assert_eq(code, 1)
	assert_eq(lab.last_error.kind, "out")
	assert_eq(lab.last_error.path, out)


# ------------------------------------------------------ the lab's plan --

func test_a_duel_dry_run_plans_and_plays_nothing() -> void:
	var lab = _lab()
	var out := _scratch("plan")
	var code: int = lab._main(PackedStringArray(DUEL + QUIET + ["--dry-run", "--seed", "7", "--out", out]))
	assert_eq(code, 0)
	assert_true(lab.last_plan.dry_run)
	assert_eq(lab.last_plan.mode, "duel")
	assert_eq(lab.last_plan.matchups, 1)
	assert_eq(lab.last_plan.total, 2)
	assert_eq(lab.last_plan.seed, 7)
	assert_eq(lab.last_plan.decks.size(), 2)
	assert_eq(lab.last_plan.decks[0].name, "Big Green")
	assert_true(String(lab.last_plan.decks[0].file).ends_with("big_green.deck"), str(lab.last_plan.decks[0]))
	assert_eq(lab.last_plan.decks[0].cards, 40)
	assert_false(lab.last_plan.rated, "--no-elo")
	assert_eq(lab.last_plan.out, out)
	assert_true(lab.last_plan.has("packs_on"), "the packs the settings put on, named")
	assert_eq(lab.last_plan.packs_on, Array(Settings.enabled_card_packs()))
	assert_true(lab.last_plan.estimate.has("seconds"))
	assert_false(_exists(out), "a dry run makes no folder")
	assert_false(FileAccess.file_exists(out.path_join("results.json")))


func test_a_dry_run_still_refuses_what_a_run_refuses() -> void:
	var lab = _lab()
	var out := _scratch("plan_refused")
	var code: int = lab._main(PackedStringArray(["--deck-a", "big_gren.deck", "--deck-b",
		"white_knights.deck", "--dry-run"] + QUIET + ["--out", out]))
	assert_eq(code, 2, "the plan comes after every check")
	assert_eq(lab.last_error.kind, "deck")
	assert_true(lab.last_plan.is_empty())


func test_a_tournament_dry_run_counts_its_matchups() -> void:
	var lab = _lab()
	var out := _scratch("plan_tournament")
	var code: int = lab._main(PackedStringArray(["--field", "big_green.deck,blue_skies.deck",
		"--gauntlet", "white_knights.deck,mountain_artillery.deck", "--group", "tournament",
		"--dry-run"] + QUIET + ["--out", out]))
	assert_eq(code, 0)
	assert_eq(lab.last_plan.mode, "tournament")
	assert_eq(lab.last_plan.matchups, 4)
	assert_eq(lab.last_plan.total, 8)
	assert_false(lab.last_plan.rated, "a tournament is never rated")
	assert_eq(lab.last_plan.field.size(), 2)
	assert_eq(lab.last_plan.gauntlet.size(), 2)
	assert_false(_exists(out))


func test_a_sweep_dry_run_counts_arms_times_pairs() -> void:
	var lab = _lab()
	var out := _scratch("plan_sweep")
	var code: int = lab._main(PackedStringArray(DUEL + ["--sweep", "pays_the_rent=on,off",
		"--null", "off"] + CONTROL + QUIET + ["--dry-run", "--out", out]))
	assert_eq(code, 0, str(lab.last_error))
	assert_eq(lab.last_plan.mode, "sweep")
	assert_eq(lab.last_plan.knob, "pays_the_rent")
	assert_eq(lab.last_plan.arms.size(), 3, "on, off and the null")
	assert_eq(lab.last_plan.matchups, 2, "the pair and its control")
	assert_eq(lab.last_plan.pairs, ["Big Green vs White Knights"], "the tested pairs")
	assert_eq(lab.last_plan.total, 3 * 2 * 2)
	assert_eq(lab.last_plan.control, "Big Green vs White Knights")
	assert_eq(lab.last_plan.packs_on, Array(Settings.enabled_card_packs()))
	assert_false(_exists(out), "a sweep dry run makes no folder either")


func test_dry_run_is_a_documented_toggle() -> void:
	var lab = _lab()
	assert_true(lab.TOGGLE_HINTS.has("--dry-run"))
	assert_true(String(lab.HELP).contains("--dry-run"))
	assert_true(String(lab.HELP).contains("\"error\""), "the exit codes name the JSON line")
	var opts: Dictionary = lab._parse_args(PackedStringArray(DUEL + ["--dry-run"]))
	assert_true(opts.dry_run)
	var plain: Dictionary = lab._parse_args(PackedStringArray(DUEL))
	assert_false(plain.dry_run)
	var typo: Dictionary = lab._parse_args(PackedStringArray(DUEL + ["--dry-rn"]))
	assert_eq(typo.suggestions, ["--dry-run"])


# ------------------------------------------------- the autodeck's side --

func test_an_unknown_autodeck_option_is_a_refusal_with_suggestions() -> void:
	var cli = _auto()
	var out := _scratch("auto_gold")
	var code: int = cli._main(PackedStringArray(["--gld", "--quiet", "--out", out]))
	assert_eq(code, 2)
	assert_eq(cli.last_error.tool, "auto_deck")
	assert_eq(cli.last_error.kind, "option")
	assert_eq(cli.last_error.flag, "--gld")
	assert_eq(cli.last_error.suggestions, ["--gold"], "once, though --gold sits in both tables")
	assert_false(_exists(out))


func test_a_missing_kept_deck_is_a_refusal_of_kind_keep() -> void:
	var cli = _auto()
	var out := _scratch("auto_keep")
	var code: int = cli._main(PackedStringArray(["--keep", "decks/nowhere.deck", "--quiet", "--out", out]))
	assert_eq(code, 2)
	assert_eq(cli.last_error.kind, "keep")
	assert_eq(cli.last_error.path, "decks/nowhere.deck")
	assert_eq(cli.last_error.flag, "--keep")
	assert_false(_exists(out))
	var list = _auto()
	assert_eq(list._main(PackedStringArray(["--list", "nowhere.txt", "--quiet", "--out", out])), 2)
	assert_eq(list.last_error.kind, "list")
	assert_eq(list.last_error.path, "nowhere.txt")


func test_a_bad_set_is_a_refusal_of_kind_sets() -> void:
	var cli = _auto()
	var out := _scratch("auto_sets")
	var code: int = cli._main(PackedStringArray(["--sets", "ZZZ", "--quiet", "--out", out]))
	assert_eq(code, 2)
	assert_eq(cli.last_error.kind, "sets")
	assert_false(_exists(out))


func test_an_autodeck_dry_run_plans_the_files_and_writes_none() -> void:
	var cli = _auto()
	var out := _scratch("auto_plan")
	var code: int = cli._main(PackedStringArray(["--count", "3", "--seed", "11", "--colors", "G,W",
		"--dry-run", "--quiet", "--out", out]))
	assert_eq(code, 0, str(cli.last_error))
	assert_true(cli.last_plan.dry_run)
	assert_eq(cli.last_plan.tool, "auto_deck")
	assert_eq(cli.last_plan.count, 3)
	assert_eq(cli.last_plan.combinations, 2, "G and W")
	assert_eq(cli.last_plan.seed, 11)
	assert_false(cli.last_plan.seed_rolled)
	assert_eq(cli.last_plan.files.decks, 3)
	assert_eq(cli.last_plan.files.manifest, out.path_join("decks.csv"))
	assert_eq(cli.last_plan.disk_bytes, 3 * cli.DECK_FILE_BYTES)
	assert_false(cli.last_plan.out_exists)
	assert_eq(cli.last_plan.packs_on, Array(Settings.enabled_card_packs()))
	assert_true(String(cli.last_plan.next).begins_with("DeckLab/deck_lab.sh --field"))
	assert_false(_exists(out), "nothing written")
	var rolled = _auto()
	assert_eq(rolled._main(PackedStringArray(["--count", "1", "--dry-run", "--quiet", "--out", out])), 0)
	assert_true(rolled.last_plan.seed_rolled, "no --seed: the run would roll one")
	assert_eq(rolled.last_plan.seed, 0)


func test_an_autodeck_dry_run_reports_a_folder_that_holds_files() -> void:
	var cli = _auto()
	var out := _scratch("auto_held")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var f := FileAccess.open(out.path_join("old.deck"), FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var code: int = cli._main(PackedStringArray(["--count", "1", "--dry-run", "--quiet", "--out", out]))
	assert_eq(code, 0, "the plan is not the refusal: --force is the caller's call")
	assert_true(cli.last_plan.out_exists)
	assert_eq(cli.last_plan.out_holds, 1)
	assert_false(cli.last_plan.force)
	assert_true(FileAccess.file_exists(out.path_join("old.deck")), "and nothing was cleared")
	var run = _auto()
	assert_eq(run._main(PackedStringArray(["--count", "1", "--quiet", "--out", out])), 1,
		"the run itself refuses the held folder")
	assert_eq(run.last_error.kind, "out")
	assert_eq(run.last_error.path, out)
	assert_eq(run.last_error.flag, "--out", "the flag at fault, not the remedy the prose names")


func test_autodeck_dry_run_is_a_documented_toggle() -> void:
	var cli = _auto()
	assert_true(cli.TOGGLE_HINTS.has("--dry-run"))
	assert_true(String(cli.HELP).contains("--dry-run"))
	assert_true(String(cli.HELP).contains("\"error\""))
	var opts: Dictionary = cli.parse_args(PackedStringArray(["--dry-run", "--count", "2", "--out", "x"]))
	assert_true(opts.dry_run)
	assert_eq(int(opts.count), 2)
	assert_false(cli.parse_args(PackedStringArray(["--count", "1", "--out", "x"])).dry_run)
	var typo: Dictionary = cli.parse_args(PackedStringArray(["--dry-rn", "--out", "x"]))
	assert_eq(typo.suggestions, ["--dry-run"])
