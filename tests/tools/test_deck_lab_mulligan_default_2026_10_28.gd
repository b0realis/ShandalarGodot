extends GutTest
## THE LAB MULLIGANS BY DEFAULT (owner, 2026-10-28, round "open items":
## *"Deck Lab: mulligan on by default"*). Every real duel offers the
## mulligan before turn 1 (`OpeningHand.run`), so a Lab measurement that
## never offered it was measured on hands no player keeps. `--mulligan`
## now defaults ON, `--mulligan off` still turns it off, the settings line
## names only the move away from the default, and a run started before the
## change resumes with the mulligan off it started with.


const BASE := ["--deck-a", "white_knights.deck", "--deck-b", "big_green.deck"]
const QUIET := ["--procs", "1", "--jobs", "1", "--quiet", "--no-elo", "--no-svg", "--games", "1"]


func _lab() -> Object:
	return autofree(load("res://DeckLab/simulate.gd").new())


func _parse(args: Array) -> Dictionary:
	return _lab()._parse_args(PackedStringArray(args))


func _forests(count: int) -> Array[String]:
	var out: Array[String] = []
	for _i in count:
		out.append("Forest")
	return out


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


## One duel through the Lab's own duel body, recorded, with seat 0 on a
## deck of forty Forests — a hand every pilot throws back, so whether the
## offer was made is the whole question. Returns the game's log text.
func _all_land_duel(args: Array) -> String:
	var lab := _lab()
	var opts: Dictionary = lab._parse_args(PackedStringArray(args))
	assert_false(opts.has("error"), str(opts.get("error", "")))
	lab._duel_opts = lab._duel_options(opts)
	var dir := "user://lab_mulligan_%d" % Time.get_ticks_usec()
	lab._duel_opts["record"] = "all"
	lab._duel_opts["record_dir"] = dir
	var deck_b := DeckList.load_file("res://decks/white_knights.deck")
	assert_eq(deck_b.errors, [] as Array[String])
	var context := {"pair": 0, "seed": 31, "a_seat": 0, "name_a": "Forests",
		"name_b": "White Knights", "arm": -1, "duel": 0}
	lab._play_duel([_forests(40), deck_b.cards], ["wizard", "wizard"], 31, [null, null], context)
	var text := ""
	var found := DirAccess.get_files_at(dir)
	assert_eq(found.size(), 1, "the one game was recorded")
	if found.size() == 1:
		text = FileAccess.get_file_as_string(dir.path_join(found[0]))
	_remove_tree(ProjectSettings.globalize_path(dir))
	return text


func test_the_default_is_on() -> void:
	assert_true(_parse(BASE).mulligan, "the mulligan is offered unless the line says off")
	assert_false(_parse(BASE + ["--mulligan", "off"]).mulligan, "off still turns it off")
	assert_true(_parse(BASE + ["--mulligan", "ON"]).mulligan, "any case")
	assert_true(bool(_lab()._duel_options(_parse(BASE)).mulligan),
		"and the default reaches the duel options every worker plays from")


func test_a_default_duel_offers_the_mulligan_and_an_off_duel_does_not() -> void:
	var on := _all_land_duel(BASE)
	assert_string_contains(on, "has chosen to take a mulligan",
		"an all-land seven goes back when nobody said --mulligan")
	var off := _all_land_duel(BASE + ["--mulligan", "off"])
	assert_false(off.contains("has chosen to take a mulligan"),
		"--mulligan off: the seven is played as dealt")


func test_the_help_says_on() -> void:
	var lab := _lab()
	assert_string_contains(String(lab.FLAG_HINTS["--mulligan"]), "default on")
	assert_false(String(lab.FLAG_HINTS["--mulligan"]).contains("default off"))
	assert_string_contains(String(lab.HELP), "(default ON",
		"the long help's own line for the switch")


func test_the_settings_line_names_only_the_move_off() -> void:
	var lab := _lab()
	var plain := String(lab._settings_line(lab._parse_args(PackedStringArray(BASE))))
	assert_false(plain.contains("mulligan"), "the default is not a setting worth a line: " + plain)
	assert_string_contains(String(lab._settings_line(lab._parse_args(
		PackedStringArray(BASE + ["--mulligan", "off"])))), "mulligan off")


func test_a_run_from_before_the_change_resumes_with_the_mulligan_off() -> void:
	var lab := _lab()
	var old_line := PackedStringArray(BASE)
	assert_eq(Array(lab.resume_mulligan(old_line, {"argv": BASE})), BASE + ["--mulligan", "off"],
		"no mulligan in run.json and none on the line: it played without one")
	assert_eq(Array(lab.resume_mulligan(old_line, {"argv": BASE, "mulligan": true})), BASE,
		"a run.json that names its mulligan is read back as its line")
	var explicit := PackedStringArray(BASE + ["--mulligan", "on"])
	assert_eq(Array(lab.resume_mulligan(explicit, {"argv": Array(explicit)})), Array(explicit),
		"a line that chose its mulligan keeps it")


func test_a_real_run_writes_its_mulligan_into_run_json() -> void:
	for case in [[[], true], [["--mulligan", "off"], false]]:
		var out := "user://lab_mulligan_run_%d" % Time.get_ticks_usec()
		var lab := _lab()
		var argv := PackedStringArray(["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck"]
			+ QUIET + case[0] + ["--out", out])
		assert_eq(lab._main(argv), 0, str(lab.last_error))
		var path := out.path_join(lab.RUN_JSON)
		assert_true(FileAccess.file_exists(path), path)
		var run: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(run is Dictionary)
		if run is Dictionary:
			assert_eq(run.get("mulligan"), case[1], "a resume reads the run's mulligan back from here")
		_remove_tree(ProjectSettings.globalize_path(out))
