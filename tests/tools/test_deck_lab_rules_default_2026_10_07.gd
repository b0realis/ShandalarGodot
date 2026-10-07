extends GutTest
## THE LAB PLAYS THE PLAYER'S TABLE (owner, 2026-10-07). The Deck Lab's
## `--rules` defaulted to plain `modern` — no mana burn — while a player's
## own duel starts at RulesOptions.DEFAULT_PRESET, modern rules with mana
## burn on; the whole-game campaign found Lab measurements blind to the
## AI's mana-burn mistakes because of it. The default is the player's
## preset now, `--rules` takes every preset id the Options screen and the
## referee know, and a run started before the change resumes under the
## plain `modern` it started with.


const BASE := ["--deck-a", "white_knights.deck", "--deck-b", "big_green.deck"]


func _lab() -> Object:
	return autofree(load("res://DeckLab/simulate.gd").new())


func _parse(args: Array) -> Dictionary:
	return _lab()._parse_args(PackedStringArray(args))


func _rules_for(args: Array) -> RulesOptions:
	var lab := _lab()
	var opts: Dictionary = lab._parse_args(PackedStringArray(args))
	assert_false(opts.has("error"), str(opts.get("error", "")))
	var rules := RulesOptions.new()
	lab.apply_rules(rules, lab._duel_options(opts))
	return rules


func test_the_default_is_the_players_own_table() -> void:
	assert_eq(RulesOptions.DEFAULT_PRESET, "modern_mana_burn",
		"the player's default this test pins the Lab to")
	assert_eq(_parse(BASE).rules, RulesOptions.DEFAULT_PRESET)
	var rules := _rules_for(BASE)
	assert_eq(rules.preset(), "modern_mana_burn")
	assert_true(rules.get_fork("mana_burn"), "a Lab duel burns floating mana by default")


func test_every_preset_id_is_taken_and_played() -> void:
	for preset in RulesOptions.PRESETS:
		var id := String(preset["id"])
		assert_eq(_parse(BASE + ["--rules", id]).rules, id, id)
		assert_eq(_rules_for(BASE + ["--rules", id]).preset(), id, id)
	assert_false(_rules_for(BASE + ["--rules", "modern"]).get_fork("mana_burn"),
		"plain modern is still there, mana burn off")
	assert_eq(_parse(BASE + ["--rules", "FIFTH"]).rules, "fifth", "any case")


func test_an_unknown_preset_names_the_three() -> void:
	var error := String(_parse(BASE + ["--rules", "sixth"]).get("error", ""))
	for preset in RulesOptions.PRESETS:
		assert_string_contains(error, String(preset["id"]))


func test_a_rule_override_still_lands_on_top() -> void:
	var rules := _rules_for(BASE + ["--rule", "mana_burn=off"])
	assert_false(rules.get_fork("mana_burn"))
	assert_eq(rules.preset(), "modern", "the default with burn turned off is plain modern")


func test_the_settings_line_names_only_a_move_from_the_default() -> void:
	var lab := _lab()
	assert_false(String(lab._settings_line(lab._parse_args(PackedStringArray(BASE)))).contains("rules"),
		"the default table is not a setting worth a line")
	assert_string_contains(String(lab._settings_line(lab._parse_args(PackedStringArray(BASE + ["--rules", "modern"])))),
		"rules modern")


func test_a_run_from_before_the_change_resumes_under_plain_modern() -> void:
	var lab := _lab()
	var old_line := PackedStringArray(BASE)
	assert_eq(Array(lab.resume_rules(old_line, {"argv": BASE})), BASE + ["--rules", "modern"],
		"no rules in run.json and none on the line: it played plain modern")
	assert_eq(Array(lab.resume_rules(old_line, {"argv": BASE, "rules": "modern_mana_burn"})), BASE,
		"a run.json that names its rules is read back as its line")
	var explicit := PackedStringArray(BASE + ["--rules", "fifth"])
	assert_eq(Array(lab.resume_rules(explicit, {"argv": Array(explicit)})), Array(explicit),
		"a line that chose its rules keeps them")


func _remove_tree(absolute: String) -> void:
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	dir.include_hidden = true
	for sub in dir.get_directories():
		_remove_tree(absolute.path_join(sub))
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(absolute)


func test_a_real_run_writes_its_rules_into_run_json() -> void:
	const QUIET := ["--procs", "1", "--jobs", "1", "--quiet", "--no-elo", "--no-svg", "--games", "1"]
	for case in [[[], "modern_mana_burn"], [["--rules", "modern"], "modern"]]:
		var out := "user://lab_rules_%d" % Time.get_ticks_usec()
		var lab := _lab()
		var argv := PackedStringArray(["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck"]
			+ QUIET + case[0] + ["--out", out])
		assert_eq(lab._main(argv), 0, str(lab.last_error))
		var path := out.path_join(lab.RUN_JSON)
		assert_true(FileAccess.file_exists(path), path)
		var run: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(run is Dictionary)
		if run is Dictionary:
			assert_eq(String(run.get("rules", "")), case[1],
				"a resume reads the run's rules back from here")
		_remove_tree(ProjectSettings.globalize_path(out))
