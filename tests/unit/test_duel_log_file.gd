extends GutTest
## THE RUNNING LOG FILE — [DuelLogFile], `duel_log.txt` beside the game
## (2026-09-07, `[QoL]`): a banner per game, games appended one after
## another, the window's shape, and the 1 MB cap trimmed from the front
## on a game banner. Written into a scratch directory under `user://`
## through the [member DuelLogFile.location] seam; the real location is
## `user://` under the editor, which is where the suite runs.

var _dir := ""


func before_each() -> void:
	_dir = ProjectSettings.globalize_path("user://").path_join("duel_log_file_test")
	DirAccess.make_dir_recursive_absolute(_dir)
	DuelLogFile.location = _dir
	_wipe()


func after_each() -> void:
	_wipe()
	DuelLogFile.location = ""
	DirAccess.remove_absolute(_dir)


func _wipe() -> void:
	if FileAccess.file_exists(DuelLogFile.path()):
		DirAccess.remove_absolute(DuelLogFile.path())


func _read() -> String:
	var file := FileAccess.open(DuelLogFile.path(), FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _names() -> PackedStringArray:
	return PackedStringArray(["Player 1", "HAL 9000"])


func _meta(kind := "", pid := -1, turn := 1, step := -1) -> Dictionary:
	return {"turn": turn, "step": step, "pid": pid, "kind": kind, "card": "", "colors": 0}


func test_the_file_lives_under_user_when_the_editor_runs_the_project() -> void:
	DuelLogFile.location = ""
	assert_true(OS.has_feature("editor"), "the suite runs under the editor binary")
	assert_eq(DuelLogFile.game_dir(), ProjectSettings.globalize_path("user://"))
	assert_eq(DuelLogFile.path().get_file(), DuelLogFile.FILE_NAME)


func test_the_location_seam_moves_the_file() -> void:
	assert_eq(DuelLogFile.path(), _dir.path_join("duel_log.txt"))


func test_the_banner_names_the_moment_the_players_and_the_seed() -> void:
	var lines := DuelLogFile.banner(_names(), 4242)
	assert_eq(lines.size(), 4, "a blank, the rule, the banner, the rule")
	assert_eq(lines[0], "")
	assert_eq(lines[1], DuelLogFile.RULE)
	assert_eq(lines[3], DuelLogFile.RULE)
	assert_true(lines[2].begins_with("**********  GAME at "), lines[2])
	assert_true(lines[2].ends_with("  **********"), lines[2])
	assert_true(lines[2].contains("Player 1 vs HAL 9000"), lines[2])
	assert_true(lines[2].contains("(seed 4242)"), lines[2])
	var today := Time.get_datetime_string_from_system(false, true).left(10)
	assert_true(lines[2].contains(today), "dated today: " + lines[2])


func test_a_game_is_its_banner_and_its_lines_in_the_windows_shape() -> void:
	var log := DuelLogFile.new()
	log.begin(_names(), 7)
	log.write("== Turn 1 — Player 1 ==", _meta("turn", 0, 1, -1))
	log.write("Player 1 plays Forest", _meta("play", 0, 1, Mtg.Step.MAIN1))
	log.write("HAL 9000 discards Island", _meta("", 1, 1, Mtg.Step.MAIN1))
	var lines := _read().split("\n")
	assert_eq(lines[0], "")
	assert_eq(lines[1], DuelLogFile.RULE)
	assert_true(lines[2].contains("GAME at"))
	assert_eq(lines[3], DuelLogFile.RULE)
	assert_eq(lines[4], "== Turn 1 — Player 1 ==")
	assert_eq(lines[5], "[%s]" % Mtg.step_name(Mtg.Step.MAIN1))
	assert_eq(lines[6], "  Player 1 plays Forest")
	assert_eq(lines[7], "  Player 2 (HAL 9000) discards Island")
	assert_eq(lines[8], "", "store_line ends the file with a newline")


func test_games_are_appended_one_after_another() -> void:
	var first := DuelLogFile.new()
	first.begin(_names(), 1)
	first.write("Player 1 plays Forest", _meta("play", 0, 1, Mtg.Step.MAIN1))
	var second := DuelLogFile.new()
	second.begin(_names(), 2)
	second.write("Player 1 plays Forest", _meta("play", 0, 1, Mtg.Step.MAIN1))
	var text := _read()
	assert_eq(text.count("GAME at"), 2, "two banners")
	assert_true(text.find("(seed 1)") < text.find("(seed 2)"), "in order")
	assert_eq(text.count("[%s]" % Mtg.step_name(Mtg.Step.MAIN1)), 2,
		"each game starts its own reading — the step is marked again")


func test_the_cap_trims_the_front_on_a_game_banner() -> void:
	var filler := "x".repeat(99)   # 100 bytes a line with its newline
	var log := DuelLogFile.new()
	var games := 0
	while games < 12:   # 12 × ~100 KB = 1.2 MB, past the cap
		games += 1
		log.begin(_names(), games)
		for i in 1000:
			log.write(filler, _meta())
	var text := _read()
	var size := text.to_utf8_buffer().size()
	assert_true(size <= DuelLogFile.CAP, "under the cap: %d" % size)
	assert_true(size > DuelLogFile.CAP - DuelLogFile.SLACK - 110_000,
		"only a slab went, not the file: %d" % size)
	assert_eq(text.split("\n")[0], DuelLogFile.RULE, "the file opens on a banner's rule")
	assert_true(text.split("\n")[1].begins_with("**********  GAME at"), "…and its banner")
	assert_false(text.contains("(seed 1)"), "the oldest game is gone")
	assert_true(text.contains("(seed %d)" % games), "the newest is kept")


func test_writing_before_begin_still_lands() -> void:
	var log := DuelLogFile.new()
	log.write("Player 1 plays Forest", _meta("play", 0, 1, Mtg.Step.MAIN1))
	assert_true(_read().contains("Player 1 plays Forest"))
