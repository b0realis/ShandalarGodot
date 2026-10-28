extends GutTest
## PART C STAGE C3, G2 — THE END ON SCREEN: a won Final Battle left for the
## main menu (its result standing) still lets "Return to Shandalar" at the
## Hall walk on (h3-1); a save that could not be written is said — after
## "Return to Shandalar first" and after the win's "Return to Shandalar",
## on the battle's menu question when the door's save failed, on the
## quest-failed end when the result's did (h3-3); the Hall over a file it
## cannot read says so (h3-4) and fits a window made smaller (h5-4); and the
## load list marks a One-life save whose battle began as a failed quest
## (h3-2), Resume passing over the failed ones (h3-6). Headless: no movie,
## the world a real generated one, its saves (and their failing) and its
## leaving counted.

const SAVES := "user://adventure_tests_c13_g2_end"
const HALL := "user://adventure_tests_c13_g2_end_hall"


## A world screen that counts its saves, its leaving and its quitting — and
## whose saves fail while [member fail] is set.
class Probe extends WorldScreen:
	var saves := 0
	var titles := 0
	var quits := 0
	var fail := false

	func _write_autosave() -> String:
		saves += 1
		return "" if fail else super()

	func _go_to_title() -> void:
		titles += 1
		_leaving = true

	func _end_process() -> void:
		quits += 1


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	HallOfFame.file = HALL + "/hall_of_fame.json"
	AdventureFinale.movie_forced = 0
	_clear()
	AdventurePlayer.forget_saves()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)


func after_each() -> void:
	AdventureFinale.movie_forced = -1
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	HallOfFame.file = HallOfFame.FILE
	AdventurePlayer.forget_saves()


func _clear() -> void:
	for folder in [SAVES, HALL]:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(folder)


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _setup(hero_name := "Ysolde Starfall") -> AdventureSetup:
	var setup := AdventureSetup.new()
	setup.player_name = hero_name
	setup.color = "blue"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "12345"
	return setup


func _open_world(life_rule := AdventurePlayer.LIFE_RELOAD) -> void:
	screen = Probe.new()
	screen.record = _setup().resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	var hero := screen.player
	hero.life_rule = life_rule
	hero.food = 50
	hero.monsters = [] as Array
	hero.defeated_wizards.assign(AdventurePlayer.COLORS)
	screen.saves = 0


## The finale over the world, its guard passed.
func _finale() -> AdventureFinale:
	var finale := AdventureFinale.showing(screen)
	if finale != null:
		finale._shown_at -= 100000
	return finale


func _to_battle() -> AdventureFinale:
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	_finale().choose("face")
	_finale().go_on()
	await _frames()
	var finale := _finale()
	finale.builder.closed.emit()
	await _frames(2)
	assert_eq(finale.step, AdventureFinale.BATTLE)
	return finale


func _report(result: int, his_start: int, his_end: int) -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = result
	report.winner = 0 if result == DuelReport.WIN else (1 if result == DuelReport.LOSS else -1)
	report.lives_start = [20, his_start] as Array[int]
	report.lives_end = [7, his_end] as Array[int]
	return report


## The win's pages read through to the Hall.
func _to_the_hall(finale: AdventureFinale) -> void:
	await _frames(2)
	assert_eq(finale.step, AdventureFinale.WIN)
	_finale().go_on()
	finale._after_stats()
	await _frames()
	assert_eq(finale.step, AdventureFinale.HALL)


# ---------------------------------------------------------------- h3-1 --

func test_a_won_battle_left_for_the_menu_still_walks_on_from_the_hall() -> void:
	await _open_world()
	var finale := await _to_battle()
	assert_eq(finale.duel.menu_over_words, AdventureFinale.MENU_OVER_FINAL, "the over question fits the battle")
	# The duel's Return to main menu with its End of Duel window up
	# (WorldDuels._to_menu's own two steps): the world to leave once its
	# panes are done, the result reported.
	screen.leave_after_panes()
	finale.duel._finish(_report(DuelReport.WIN, 200, 0))
	await _to_the_hall(finale)
	assert_false(screen.leaving_after_panes(), "the win's last choice decides, not the duel's door")
	finale.last_choice(AdventureFinale.ROAMING)
	await _frames()
	screen._process(0.016)
	assert_eq(screen.titles, 0, "Return to Shandalar: the hero walks on")
	assert_false(screen.modal(), "the world given back")


func test_a_won_battle_left_for_the_menu_ends_at_the_title_on_end() -> void:
	await _open_world()
	var finale := await _to_battle()
	screen.leave_after_panes()
	finale.duel._finish(_report(DuelReport.WIN, 200, 0))
	await _to_the_hall(finale)
	finale.last_choice(AdventureFinale.ENDED)
	await _frames()
	assert_eq(screen.titles, 1, "End: the title, once")


# ---------------------------------------------------------------- h3-3 --

func test_return_first_says_a_save_that_failed() -> void:
	await _open_world()
	screen.fail = true
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	_finale().choose("return")
	await _frames()
	var said := screen.hud.notice()
	assert_string_contains(said, "Arzakon's Portal opened", "where it stands")
	assert_string_contains(said, WorldScreen.UNSAVED, "and that the adventure could not be saved")


func test_return_first_saved_says_only_where() -> void:
	await _open_world()
	AdventureFinale.after_fifth_wizard(screen, screen.player)
	await _frames()
	_finale().choose("return")
	await _frames()
	assert_eq(screen.hud.notice(), FinalBattle.OPENED_LOG % FinalBattle.portal_where(screen.player))


func test_walking_on_after_the_win_says_a_save_that_failed() -> void:
	await _open_world()
	var finale := await _to_battle()
	finale.duel._finish(_report(DuelReport.WIN, 200, 0))
	await _to_the_hall(finale)
	screen.fail = true
	finale.last_choice(AdventureFinale.ROAMING)
	await _frames()
	var said := screen.hud.notice()
	assert_string_contains(said, "Arzakon's Portal turned to stone", "the roaming line")
	assert_string_contains(said, WorldScreen.UNSAVED, "and the save that failed")


func test_a_door_that_could_not_be_saved_is_said_on_the_question_and_the_end() -> void:
	await _open_world()
	screen.fail = true
	var finale := await _to_battle()
	assert_eq(finale.duel.menu_words, AdventureFinale.MENU_RELOAD_UNSAVED, "no door's save to go back to")
	finale.duel.concede()
	await _frames()
	assert_true(screen.ended(), "the quest-failed end")
	assert_eq(screen._end.lines, AdventureFinale.failed_parts(false) + [WorldScreen.UNSAVED],
		"no save holds the door: no 'waits at the door', and the failed save said")


func test_a_result_that_could_not_be_saved_is_said_on_the_end() -> void:
	await _open_world()
	var finale := await _to_battle()
	assert_eq(finale.duel.menu_words, AdventureFinale.MENU_RELOAD, "the door saved")
	screen.fail = true
	finale.duel.concede()
	await _frames()
	assert_eq(screen._end.lines, AdventureFinale.failed_parts(true) + [WorldScreen.UNSAVED],
		"the door's save holds: it waits there; the result's save failed, said")


func test_a_failed_quest_taken_up_says_its_save_failed() -> void:
	await _open_world(AdventurePlayer.LIFE_ONE)
	screen.fail = true
	screen.player.at_door = true
	assert_true(AdventureFinale.after_load(screen, screen.player))
	assert_eq(screen._end.lines, AdventureFinale.failed_parts(false) + [WorldScreen.UNSAVED])


# ---------------------------------------------------------------- h3-4 --

func test_the_hall_over_a_file_it_cannot_read_says_so() -> void:
	DirAccess.make_dir_recursive_absolute(HALL)
	var file := FileAccess.open(HallOfFame.file, FileAccess.WRITE)
	file.store_string("{\"format\": \"shandalar-hall-of-fame\", \"version\": 99, \"entries\": []}")
	file.close()
	var host := Control.new()
	viewport.add_child(host)
	var pane := HallOfFamePane.open(host)
	await _frames()
	assert_eq((pane.find_child("Empty", true, false) as Label).text, HallOfFamePane.DAMAGED,
		"not 'No adventure has been won yet'")
	assert_true(FileAccess.file_exists(HallOfFame.file), "the file kept as it is")
	host.queue_free()


# ---------------------------------------------------------------- h5-4 --

func test_the_hall_fits_a_window_made_smaller() -> void:
	var lines: Array[Dictionary] = []
	for i in HallOfFame.MOST:
		lines.append({"id": "x%d" % i, "name": "Hero %d" % i, "portrait": "", "color": "blue", "difficulty": 1,
			"score": 1000 - i, "days": 10, "wins": 3, "date": "2026-10-28T12:00:00Z", "life_rule": "",
			"attempts": 0})
	viewport.size = Vector2i(1280, 960)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(host)
	var pane := HallOfFamePane.new()
	pane.show_entries(lines)
	pane.lit = "x99"
	host.add_child(pane)
	PaneStyle.centre(pane)
	await _frames(3)
	assert_gt(pane.size.y, 800.0, "a tall Hall in a tall window")
	viewport.size = Vector2i(1422, 800)
	await _frames(3)
	var rect := pane.get_rect()
	assert_true(rect.position.y >= 0.0 and rect.end.y <= 800.0,
		"the window made lower: the pane within it, its title and its choices seen (%s)" % rect)
	assert_almost_eq(rect.get_center().x, 711.0, 1.0, "centred across")
	viewport.size = Vector2i(1280, 960)
	await _frames(3)
	assert_gt(pane.get_rect().size.y, 800.0, "and taller again")
	host.queue_free()


# ---------------------------------------------------------- h3-2, h3-6 --

## An adventure saved: its autosave stamped [param saved] (the list's order).
func _saved(id: String, hero_name: String, saved: String, rule := AdventurePlayer.LIFE_RELOAD,
		ended := "") -> AdventurePlayer:
	var record := _setup(hero_name).resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.adventure_id = id
	player.life_rule = rule
	player.ended = ended
	if ended != "":
		player.final = {"result": ended}
	assert_ne(player.autosave(), "")
	var path := player.save_path(AdventurePlayer.AUTOSAVE)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["adventure"]["saved"] = saved
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return player


func _load_screen() -> LoadAdventureScreen:
	var load_screen: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	viewport.add_child(load_screen)
	await _frames()
	return load_screen


func _rows(load_screen: LoadAdventureScreen) -> String:
	var list := load_screen.find_child("Saves", true, false) as ItemList
	var all := PackedStringArray()
	for i in list.item_count:
		all.append(list.get_item_text(i))
	return "\n".join(all)


func test_a_one_life_slot_whose_battle_began_reads_quest_failed() -> void:
	var player := _saved("one-life", "Brina", "2026-10-28T10:00:00Z", AdventurePlayer.LIFE_ONE)
	player.defeated_wizards.assign(AdventurePlayer.COLORS)
	assert_ne(SaveSlots.save_into(player, 1, "At the portal"), "")
	HallOfFame.mark_one_life("one-life", HallOfFame.BEGUN)
	var load_screen := await _load_screen()
	var text := _rows(load_screen)
	assert_string_contains(text, "1. At the portal", "the slot")
	assert_eq(text.count(LoadAdventureScreen.FAILED_ROW), 2, "the slot and the autosave both: Continue opens the end")
	load_screen.queue_free()


func test_resume_passes_over_a_failed_quest() -> void:
	_saved("going", "Aldus", "2026-10-28T09:00:00Z")
	_saved("failed", "Corvin", "2026-10-28T11:00:00Z", AdventurePlayer.LIFE_ONE, AdventurePlayer.ENDED_FAILED)
	_saved("begun", "Brina", "2026-10-28T12:00:00Z", AdventurePlayer.LIFE_ONE)
	HallOfFame.mark_one_life("begun", HallOfFame.FAILED)
	var load_screen := await _load_screen()
	assert_eq(String(load_screen.newest_autosave().get("id", "")), "going",
		"the newest autosave whose quest has not failed")
	assert_false(load_screen.resume_button.disabled)
	load_screen.queue_free()
	await _frames()
	for path in [SAVES.path_join("going.autosave.json"), SAVES.path_join("going.autosave.json.bak")]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	AdventurePlayer.forget_saves()
	load_screen = await _load_screen()
	assert_true(load_screen.newest_autosave().is_empty(), "only failed quests left")
	assert_true(load_screen.resume_button.disabled, "Resume greyed")
	assert_false(load_screen.resume(), "and takes nothing up")
	load_screen.queue_free()


func test_resume_still_takes_up_a_won_adventure() -> void:
	_saved("going", "Aldus", "2026-10-28T09:00:00Z")
	_saved("won", "Corvin", "2026-10-28T11:00:00Z", AdventurePlayer.LIFE_RELOAD, AdventurePlayer.ENDED_WON)
	var load_screen := await _load_screen()
	assert_eq(String(load_screen.newest_autosave().get("id", "")), "won", "its Hall's End or Return again")
	load_screen.queue_free()
