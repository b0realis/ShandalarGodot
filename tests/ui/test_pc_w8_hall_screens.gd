extends GutTest
## PART C, W8 — THE HALL OF FAME ON SCREEN AND THE END ON THE LOAD LIST:
## [HallOfFamePane] shows the Hall's lines best first (the face, the name,
## the color, the level — "One life" when won so —, the years, the days,
## the wins, the day), lights the adventure just won, says how a line is
## earned when there is none, and closes on Done or Escape; it opens from a
## button in the saved adventures ([LoadAdventureScreen]) and beside the
## save slots ([SaveSlotsPane]) — never the main menu (the owner) — and the
## screen under it hears no Escape while it is up. The load list tells a won
## adventure with its years and a failed quest ([method
## LoadAdventureScreen.end_words]), and a hero's line "One life".

const FOLDER := "user://adventure_tests_pc_w8_hall"
const HALL := "user://adventure_tests_pc_w8_hall_file"

var viewport: SubViewport


func before_each() -> void:
	AdventurePlayer.saves_folder = FOLDER
	HallOfFame.file = HALL + "/hall_of_fame.json"
	_clear()
	AdventurePlayer.forget_saves()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)


func after_each() -> void:
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	HallOfFame.file = HallOfFame.FILE
	AdventurePlayer.forget_saves()


func _clear() -> void:
	for folder in [FOLDER, HALL]:
		var dir := DirAccess.open(folder)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(folder)


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## A hero who has won their adventure: [param score] years, [param days] on
## the road, under [param rule].
func _winner(id: String, hero: String, score: int, days: int, rule := AdventurePlayer.LIFE_RELOAD) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = hero
	setup.color = "red"
	setup.difficulty = 2
	setup.walker = "male"
	setup.seed_text = "4242"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.adventure_id = id
	player.life_rule = rule
	player.ended = AdventurePlayer.ENDED_WON
	player.final = {"result": "won", "score": score, "days": days, "wins": 40, "date": "2026-10-28T12:00:00Z"}
	return player


func _escape() -> InputEventAction:
	var action := InputEventAction.new()
	action.action = "ui_cancel"
	action.pressed = true
	return action


# ---------------------------------------------------------------- the pane --

func test_the_hall_shows_its_lines_best_first_and_lights_one() -> void:
	HallOfFame.add(_winner("a", "Aldus", 300, 50))
	HallOfFame.add(_winner("b", "Brina", 1130, 90, AdventurePlayer.LIFE_ONE))
	HallOfFame.add(_winner("c", "Corvin", 700, 40))
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(host)
	var pane := HallOfFamePane.open(host, 1.0, "c")
	await _frames()
	var lines := pane.lines()
	assert_eq(lines.size(), 3)
	assert_eq([lines[0][2], lines[1][2], lines[2][2]], ["Brina", "Corvin", "Aldus"], "best first")
	assert_eq(lines[0][0], "1")
	assert_eq(lines[0][3], "Red")
	assert_eq(lines[0][4], "Sorcerer · One life", "won under One life, said")
	assert_eq(lines[1][4], "Sorcerer")
	assert_eq(lines[0][5], "1130 years")
	assert_eq([lines[0][6], lines[0][7]], ["90", "40"], "days, wins")
	assert_eq(pane.lit_place(), 2, "the adventure asked for, lit")
	assert_not_null(host.find_child("HallVeil", false, false), "a veil under it")
	var picked: Array[String] = []
	pane.chosen.connect(func(what: String) -> void: picked.append(what))
	pane._unhandled_input(_escape())
	assert_eq(picked, ["done"] as Array[String], "Escape is Done")
	assert_true(pane.get_combined_minimum_size().x <= 1280.0, "it fits the screen's width")
	assert_true(pane.get_combined_minimum_size().y <= 800.0, "and its height")
	pane.queue_free()
	await _frames()
	assert_null(host.find_child("HallVeil", false, false), "the veil goes with it")
	host.queue_free()


func test_an_empty_hall_says_how_a_line_is_earned() -> void:
	var host := Control.new()
	viewport.add_child(host)
	var pane := HallOfFamePane.open(host)
	await _frames()
	assert_eq((pane.find_child("Empty", true, false) as Label).text, HallOfFamePane.EMPTY)
	assert_eq(pane.lines().size(), 0)
	host.queue_free()


func test_the_last_choice_is_no_escape() -> void:
	var host := Control.new()
	viewport.add_child(host)
	var pane := HallOfFamePane.open(host, 1.6, "", [["end", "End"], ["roam", "Return to Shandalar"]])
	await _frames()
	var picked: Array[String] = []
	pane.chosen.connect(func(what: String) -> void: picked.append(what))
	pane._unhandled_input(_escape())
	assert_eq(picked.size(), 0, "Escape chooses nothing there")
	(pane.find_child("Choice_roam", true, false) as Button).pressed.emit()
	assert_eq(picked, ["roam"] as Array[String])
	host.queue_free()


func test_a_hundred_lines_scroll_inside_the_screen() -> void:
	var lines: Array[Dictionary] = []
	for i in HallOfFame.MOST:
		lines.append({"id": "x%d" % i, "name": "Hero %d" % i, "portrait": "", "color": "blue", "difficulty": 1,
			"score": 1000 - i, "days": 10, "wins": 3, "date": "2026-10-28T12:00:00Z", "life_rule": "", "attempts": 0})
	var pane := HallOfFamePane.new()
	pane.show_entries(lines)
	pane.lit = "x99"
	viewport.add_child(pane)
	PaneStyle.centre(pane)
	await _frames(3)
	assert_eq(pane.lines().size(), HallOfFame.MOST)
	assert_true(pane.get_combined_minimum_size().y <= 800.0, "the list scrolls, the pane fits")
	assert_eq(pane.lit_place(), 100)
	pane.queue_free()


# -------------------------------------------------------- the load screen --

func test_the_load_screen_opens_the_hall_and_tells_the_end() -> void:
	var won := _winner("won-one", "Brina", 1130, 90, AdventurePlayer.LIFE_ONE)
	won.autosave()
	var lost := _winner("lost-one", "Corvin", 0, 40)
	lost.ended = AdventurePlayer.ENDED_FAILED
	lost.final = {"result": "failed"}
	lost.autosave()
	var screen: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	viewport.add_child(screen)
	await _frames()
	var list := screen.find_child("Saves", true, false) as ItemList
	var all := PackedStringArray()
	for i in list.item_count:
		all.append(list.get_item_text(i))
	var text := "\n".join(all)
	assert_string_contains(text, "Won: Arzakon banished for 1130 years")
	assert_string_contains(text, "Quest failed")
	assert_string_contains(text, "Brina — Red, Sorcerer · World seed 4242 · One life")
	assert_eq(LoadAdventureScreen.end_words({"ended": ""}), "")
	assert_not_null(screen.hall_button, "the Hall's button inside Save / Load")
	screen.hall_button.pressed.emit()
	await _frames()
	assert_true(screen.hall_shown())
	var pane := screen.find_child("HallOfFame", true, false) as HallOfFamePane
	assert_eq(pane.lines().size(), 0, "none won in this Hall's file yet")
	screen._unhandled_input(_escape())
	assert_true(screen.hall_shown(), "the list hears no Escape while the Hall is up")
	pane._unhandled_input(_escape())
	await _frames()
	assert_false(screen.hall_shown(), "Done: the list again")
	screen.queue_free()


# ---------------------------------------------------------- the save slots --

func test_the_save_slots_open_the_hall_beside_them() -> void:
	var player := _winner("slots", "Aldus", 300, 50)
	player.ended = ""
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(host)
	var slots := SaveSlotsPane.new()
	slots.player = player
	host.add_child(slots)
	await _frames()
	var done_count := [0]
	slots.done.connect(func() -> void: done_count[0] += 1)
	(slots.find_child("SaveHall", true, false) as Button).pressed.emit()
	await _frames()
	assert_true(slots.hall_shown())
	assert_eq(host.find_child("HallOfFame", false, false).get_parent(), host, "over the world, not in the pane")
	assert_false(slots.visible, "the slots step aside")
	slots._unhandled_input(_escape())
	assert_eq(done_count[0], 0, "the slots hear no Escape under the Hall")
	(host.find_child("HallOfFame", false, false) as HallOfFamePane)._unhandled_input(_escape())
	await _frames()
	assert_false(slots.hall_shown())
	assert_true(slots.visible, "and come back")
	slots.queue_free()
	await _frames()
	host.queue_free()
