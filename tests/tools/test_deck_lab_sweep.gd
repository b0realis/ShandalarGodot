extends GutTest
## THE SWEEP — `--sweep KNOB=V1,V2,...` in DeckLab/simulate.gd: the
## three-pair measurement every AI knob in docs/ROADMAP.md was measured
## with (candidate, null, control), as one command. These pin the flag's
## parsing and its refusals, the arms it builds, the control verdict's
## honesty — it is reached from the games' own fingerprints, never from a
## constant — and one real, tiny sweep end to end: the rows of the
## report, the files, the exit code on a PASS and on a FAIL.


func _lab() -> Object:
	return autofree(load("res://DeckLab/simulate.gd").new())


func _parse(args: Array) -> Dictionary:
	return _lab()._parse_args(PackedStringArray(args))


const BASE := ["--deck-a", "white_knights.deck", "--deck-b", "big_green.deck"]
const CONTROL := ["--control-deck-a", "big_green.deck", "--control-deck-b", "white_knights.deck"]
const SWEEP := BASE + ["--sweep", "pays_sacrifices=on,off"] + CONTROL


# ------------------------------------------------------------- the flags --

func test_the_sweep_flag_parses_and_defaults_its_null() -> void:
	var opts := _parse(SWEEP)
	assert_false(opts.has("error"), str(opts.get("error", "")))
	assert_eq(opts.sweep.knob, "pays_sacrifices")
	assert_eq(opts.sweep.values, PackedStringArray(["on", "off"]))
	assert_eq(opts.sweep_null, "off", "a boolean knob's null is off unless --null says")
	assert_eq(opts.control_a, "big_green.deck")
	assert_eq(opts.control_b, "white_knights.deck")
	assert_true(opts.no_elo, "an experiment never rates: the ledger is off without asking")
	# The spellings AiProfile.apply_overrides reads, normalised to the
	# two the report prints — `TRUE` and `0` are `on` and `off`.
	var spelt := _parse(BASE + ["--sweep", "pays_sacrifices=TRUE,0"] + CONTROL)
	assert_eq(spelt.sweep.values, PackedStringArray(["on", "off"]))


func test_a_number_knobs_null_is_the_presets_own_value() -> void:
	# "Candidate against the null" means "against the shipped pilot"
	# unless --null says otherwise, so the default follows the preset
	# on seat A — the Wizard's counter_threshold is 5.0, the Magician's
	# 7.0 — and a whole-number knob prints as one.
	var wizard := _parse(BASE + ["--sweep", "counter_threshold=4,6"] + CONTROL)
	assert_eq(wizard.sweep_null, "5.0")
	var magician := _parse(BASE + ["--profile-a", "magician",
		"--sweep", "counter_threshold=4,6"] + CONTROL)
	assert_eq(magician.sweep_null, "7.0")
	var chump := _parse(BASE + ["--sweep", "chump_threshold=3"] + CONTROL)
	assert_eq(chump.sweep_null, "6")
	var named := _parse(BASE + ["--sweep", "counter_threshold=4,6", "--null", "3"] + CONTROL)
	assert_eq(named.sweep_null, "3")


func test_an_unknown_knob_is_refused_with_exit_2() -> void:
	# The same refusal --profile-a makes, at parse time — and through
	# `_main`, so the exit code is the one the shell sees.
	var opts := _parse(BASE + ["--sweep", "no_such_knob=1,2"] + CONTROL)
	assert_true(opts.has("error"))
	assert_string_contains(str(opts.error), "unknown knob 'no_such_knob'")
	assert_eq(_lab()._main(PackedStringArray(
		BASE + ["--sweep", "no_such_knob=1,2", "--quiet"] + CONTROL)), 2)
	# The display name is a String on the profile, not a knob.
	assert_string_contains(str(_parse(BASE + ["--sweep", "profile_name=x"] + CONTROL).error),
		"unknown knob")
	# No `=` is not a sweep of anything.
	assert_string_contains(str(_parse(BASE + ["--sweep", "pays_sacrifices"] + CONTROL).error),
		"KNOB=V1,V2")


func test_a_value_the_knob_cannot_read_is_refused() -> void:
	# `apply_overrides` reads `counter_threshold=abc` as 0 and
	# `pays_sacrifices=maybe` as off, silently; a sweep over a typo is
	# a sweep over the wrong thing, so the values are checked against
	# the knob's TYPE before a game is played.
	assert_string_contains(str(_parse(BASE + ["--sweep", "counter_threshold=abc,4"] + CONTROL).error),
		"'abc' is not a number")
	assert_string_contains(str(_parse(BASE + ["--sweep", "pays_sacrifices=maybe"] + CONTROL).error),
		"'maybe' is not a boolean")
	assert_string_contains(str(_parse(BASE + ["--sweep", "chump_threshold=2.5"] + CONTROL).error),
		"'2.5' is not a whole number")
	assert_string_contains(str(_parse(BASE + ["--sweep", "pays_sacrifices=on,true"] + CONTROL).error),
		"'on' is listed twice")
	assert_string_contains(str(_parse(BASE + ["--sweep", "pays_sacrifices=", ] + CONTROL).error),
		"no values")
	assert_string_contains(str(_parse(SWEEP + ["--null", "maybe"]).error),
		"--null: 'maybe' is not a boolean")


func test_the_sweep_and_its_companions_need_each_other() -> void:
	# A flag that is silently ignored is a flag that lies about the run.
	assert_string_contains(str(_parse(BASE + CONTROL).error),
		"only mean something with --sweep")
	assert_string_contains(str(_parse(BASE + ["--null", "off"]).error),
		"--null only means something with --sweep")
	var no_control := _parse(BASE + ["--sweep", "pays_sacrifices=on"])
	assert_string_contains(str(no_control.error), "--control-deck-a DECK --control-deck-b DECK")
	var half := _parse(BASE + ["--sweep", "pays_sacrifices=on", "--control-deck-a", "big_green.deck"])
	assert_true(half.has("error"), "one control deck is not a control pair")


func test_a_sweep_refuses_what_it_would_otherwise_ignore() -> void:
	# --matrix has no seat A to put a candidate on; `random` is a
	# different opponent per game on each arm, which a game-for-game
	# control cannot read; a --profile that already names the knob would
	# be overridden by every arm; and the Elo ledger is never written by
	# an experiment, so --elo-file would be a lie.
	assert_string_contains(str(_parse(["--matrix", "decks/", "--sweep",
		"pays_sacrifices=on"] + CONTROL).error), "--matrix")
	assert_string_contains(str(_parse(["--deck-a", "white_knights.deck", "--deck-b", "random",
		"--sweep", "pays_sacrifices=on"] + CONTROL).error), "random")
	assert_string_contains(str(_parse(SWEEP + ["--profile-a", "wizard:pays_sacrifices=on"]).error),
		"also set in --profile")
	assert_string_contains(str(_parse(SWEEP + ["--elo-file", "user://x.txt"]).error),
		"never writes the Elo ledger")
	# --no-elo agrees with what the sweep does anyway, so it is welcome;
	# so is a --profile override of a DIFFERENT knob.
	assert_false(_parse(SWEEP + ["--no-elo"]).has("error"))
	assert_false(_parse(SWEEP + ["--profile-a", "wizard:aggression=0.7"]).has("error"))


func test_the_sweep_flags_are_in_the_manual_and_the_hint_table() -> void:
	# The rule test_deck_lab.gd pins for every flag, spelled out for
	# the four this file is about, plus the exit code the sweep adds.
	var lab := _lab()
	for flag in ["--sweep", "--null", "--control-deck-a", "--control-deck-b"]:
		assert_true(lab.FLAG_HINTS.has(flag), "%s is in the parser's table" % flag)
		assert_true(String(lab.HELP).contains(flag), "--help documents %s" % flag)
	assert_eq(lab.EXIT_CONTROL_MOVED, 4)
	assert_true(String(lab.HELP).contains("\n  4  "), "--help lists exit 4")


# ------------------------------------------------------------- the arms --

func test_the_arms_are_the_three_pairs_of_the_method() -> void:
	var lab := _lab()
	var arms: Array = lab.sweep_arms("pays_sacrifices",
		PackedStringArray(["on", "off"]), "off", "wizard", "wizard")
	assert_eq(arms.size(), 3, "the null, then one candidate per value")
	assert_true(arms[0].is_null)
	assert_eq(arms[0].profile_a, "wizard:pays_sacrifices=off", "the null: off on seat A")
	assert_eq(arms[0].profile_b, "wizard:pays_sacrifices=off", "and off on seat B")
	assert_false(arms[1].is_null)
	assert_eq(arms[1].value, "on")
	assert_eq(arms[1].profile_a, "wizard:pays_sacrifices=on", "the candidate on seat A")
	assert_eq(arms[1].profile_b, "wizard:pays_sacrifices=off", "against the null on seat B")
	assert_eq(arms[2].profile_a, "wizard:pays_sacrifices=off")
	# A preset that already carries overrides keeps them; the knob is
	# appended, so every arm is that pilot plus one knob.
	var tuned: Array = lab.sweep_arms("counter_threshold",
		PackedStringArray(["4"]), "5.0", "wizard:aggression=0.7", "sorcerer")
	assert_eq(tuned[1].profile_a, "wizard:aggression=0.7,counter_threshold=4")
	assert_eq(tuned[1].profile_b, "sorcerer:counter_threshold=5.0")
	assert_eq(lab.arm_label(arms[0]), "null (off)")
	assert_eq(lab.arm_label(arms[1]), "on")


# ---------------------------------------------------------- the verdict --

func _game(fingerprint: String, a_won := true, turns := 12) -> Dictionary:
	return {"a_won": a_won, "a_on_play": true, "turns": turns,
		"stalled": false, "drawn": false, "fingerprint": fingerprint}


func test_the_control_verdict_reads_the_games_and_never_a_constant() -> void:
	var lab := _lab()
	var seeds := [11, 12, 13]
	var null_arm := [_game("aaa"), _game("bbb", false, 20), _game("ccc")]
	var same := [_game("aaa"), _game("bbb", false, 20), _game("ccc")]
	var verdict: Dictionary = lab.control_verdict(same, null_arm, seeds)
	assert_true(verdict.pass)
	assert_eq(verdict.differing, 0)
	assert_eq(verdict.games, 3)
	assert_eq(verdict.first, "")
	# One game whose LOG differs is a FAIL, even with the same result —
	# two games can share a winner and a turn count and not be the same
	# game, which is exactly what a summary-row comparison misses.
	var moved := [_game("aaa"), _game("bbb", false, 20), _game("ccX")]
	verdict = lab.control_verdict(moved, null_arm, seeds)
	assert_false(verdict.pass)
	assert_eq(verdict.differing, 1)
	assert_string_contains(str(verdict.first), "game 2 (seed 13): the game log")
	# When the result moved too, the FAIL names what a reader wants named.
	var lost := [_game("aaa"), _game("bbX", true, 15), _game("ccc")]
	verdict = lab.control_verdict(lost, null_arm, seeds)
	assert_string_contains(str(verdict.first), "game 1 (seed 12): the game log, a_won true vs false, turns 15 vs 20")
	# A record WITHOUT a fingerprint can never pass: the verdict is only
	# worth anything when it was reached through the games' artefacts.
	var blind := [_game(""), _game("", false, 20), _game("")]
	var blind_null := [_game(""), _game("", false, 20), _game("")]
	verdict = lab.control_verdict(blind, blind_null, seeds)
	assert_false(verdict.pass, "no artefact, no pass")
	assert_string_contains(str(verdict.first), "no fingerprint")
	# And a different number of games is not the same run.
	assert_false(lab.control_verdict([_game("aaa")], null_arm, seeds).pass)


func test_a_games_fingerprint_is_the_game() -> void:
	# The fingerprint is the engine's log, hashed. Pinned: the same seed
	# gives the same one twice (deterministic — a control can only work
	# if this holds), a different seed gives a different one (it is the
	# GAME, not a constant), and a plain run's record has none at all
	# (the record shape every other test and tool reads is untouched).
	var lab := _lab()
	var deck := DeckList.load_file("res://decks/mountain_artillery.deck")
	assert_eq(deck.errors, [] as Array[String])
	lab._duel_opts = {"lives": [20, 20], "names": ["A", "B"], "rules": "modern",
		"rule_overrides": {}, "ante": 0, "mulligan": false, "fingerprint": true}
	var task := {"pair": 0, "seed": 4242, "a_on_play": true,
		"deck_a": deck.cards, "deck_b": deck.cards, "dealt": "",
		"profile_a": "wizard", "profile_b": "wizard"}
	var first: Dictionary = lab._play_task(task)
	var again: Dictionary = lab._play_task(task)
	assert_eq(String(first.fingerprint).length(), 32, "an md5, as hex")
	assert_eq(first.fingerprint, again.fingerprint, "the same seed is the same game")
	var other := task.duplicate()
	other.seed = 4243
	assert_ne(lab._play_task(other).fingerprint, first.fingerprint,
		"another seed is another game")
	lab._duel_opts.erase("fingerprint")
	assert_false(lab._play_task(task).has("fingerprint"),
		"a plain run's records keep their shape")


# ------------------------------------------------- one real, tiny sweep --

func _remove_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path))


func _rows_of(csv_path: String) -> Array:
	var rows: Array = []
	for line in FileAccess.get_file_as_string(csv_path).split("\n", false):
		rows.append(line.split(","))
	return rows


func test_a_small_sweep_writes_the_table_and_its_control_passes() -> void:
	# Two games an arm, in process, on the pair the ROADMAP's own
	# measurement used as its control (no sacrifice card in either
	# deck). It pins the SHAPE of the run — one row per value plus the
	# null, the control's rows, the files, exit 0 — and that the PASS was
	# reached from the games' fingerprints, by reading them back.
	var lab := _lab()
	var out := "user://deck_lab_sweep_test_%d" % Time.get_ticks_usec()
	var code: int = lab._main(PackedStringArray(SWEEP + ["--games", "2",
		"--seed", "4242", "--procs", "1", "--quiet", "--out", out]))
	assert_eq(code, 0, "the sweep ran and its control passed")
	var report := FileAccess.get_file_as_string(out + "/report.txt")
	assert_string_contains(report, "Deck Lab sweep: pays_sacrifices = on, off   null: off")
	assert_string_contains(report, "White Knights vs Big Green: White Knights's win rate with pays_sacrifices")
	var lines := report.split("\n")
	var null_rows := 0
	var on_rows := 0
	var off_rows := 0
	var passes := 0
	for line in lines:
		if line.begins_with("  null (off)  "):
			null_rows += 1
		elif line.begins_with("  on  "):
			on_rows += 1
		elif line.begins_with("  off  "):
			off_rows += 1
		if line.contains("PASS  byte-identical to the null, 2 of 2 games"):
			passes += 1
	assert_eq(null_rows, 2, "a null row in the matchup table and in the control's")
	assert_eq(on_rows, 2, "an `on` row in each")
	assert_eq(off_rows, 2, "an `off` row in each")
	assert_eq(passes, 2, "the control's verdict, per value")
	assert_string_contains(report, "control: PASS -- every arm replays the null game for game")
	assert_string_contains(report, "reading these numbers:")
	assert_string_contains(report, "2 games per arm:")
	# The files, and the verdict as data.
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out + "/sweep.json"))
	assert_true(json.control_pass)
	assert_eq(json.knob, "pays_sacrifices")
	assert_eq((json.matchups as Array).size(), 1)
	assert_eq((json.matchups[0].arms as Array).size(), 3, "the null and two values")
	assert_true(json.control.arms[1].verdict.pass)
	assert_eq(_rows_of(out + "/sweep.csv").size(), 7, "a header and 3 arms x 2 pairs")
	# THE ARTEFACTS: games.csv carries every game's fingerprint, and the
	# control's `on` rows carry the null's, game for game — which is the
	# fact the PASS above was computed from, read back from the file.
	var by_arm := {}
	for row in _rows_of(out + "/games.csv"):
		if row[0] != "control":
			continue
		by_arm["%s/%s" % [row[3], row[4]]] = by_arm.get("%s/%s" % [row[3], row[4]], []) + [row[12]]
	assert_eq(by_arm["on/candidate"], by_arm["off/null"],
		"the control's candidate games are the null's, fingerprint for fingerprint")
	assert_eq(String(by_arm["off/null"][0]).length(), 32, "a real md5, not an empty cell")
	assert_ne(by_arm["off/null"][0], by_arm["off/null"][1], "two seeds, two games")
	_remove_dir(out)


func test_a_control_the_knob_can_fire_on_is_exit_4() -> void:
	# The other half of "not a constant": a knob that changes every game
	# — a Wizard fumbling half its actions — on a control it CAN fire
	# on. The report is still written, the verdict is FAIL naming the
	# first game, and the exit code is the sweep's own 4, not 0 and not
	# the 1 of a run that broke.
	var lab := _lab()
	var out := "user://deck_lab_sweep_test_%d" % Time.get_ticks_usec()
	var code: int = lab._main(PackedStringArray(BASE + ["--sweep", "mistake_chance=0.5"]
		+ CONTROL + ["--games", "1", "--seed", "4242", "--procs", "1", "--quiet", "--out", out]))
	assert_eq(code, lab.EXIT_CONTROL_MOVED)
	assert_eq(code, 4)
	var report := FileAccess.get_file_as_string(out + "/report.txt")
	assert_string_contains(report, "FAIL  1 of 1 games differ; first: game 0 (seed 4242): the game log")
	assert_string_contains(report, "control: FAIL -- 0.5 moved the control (exit 4)")
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out + "/sweep.json"))
	assert_false(json.control_pass)
	_remove_dir(out)
