extends GutTest
## A PLAY-TESTER'S SAVES (2026-11-05): *"there is not like a One button save
## and One Button load … I did a lot of saving and loading before stepping
## on certain tiles"* — Ctrl+L takes the Quickslot up at once ([method
## WorldScreen.quick_load]; the owner: *"ctrl-l should load from quicksave
## slot!"*) — and *"Is there a way in game to delete save files you don't
## want?"* — Delete on the saved adventures ([method
## LoadAdventureScreen.ask_delete]).

const SAVES := "user://adventure_tests_tester_saves"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	_clear()


func after_each() -> void:
	for node in get_tree().root.get_children():
		if node is WorldScreen:
			node.queue_free()
	await get_tree().process_frame
	_clear()
	DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _clear() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
	AdventurePlayer.forget_saves()


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _setup(hero := "Goya") -> AdventureSetup:
	var setup := AdventureSetup.new()
	setup.player_name = hero
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	return setup


func _world() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = WorldScreen.new()
	screen.record = _setup().resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array


func _key(code: Key, ctrl := false) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.ctrl_pressed = ctrl
	press.pressed = true
	viewport.push_input(press, true)
	var up := press.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames(2)


## The world screen put up in [member screen]'s place, or null.
func _taken_over() -> WorldScreen:
	for node in get_tree().root.get_children():
		if node is WorldScreen and node != screen and not node.is_queued_for_deletion():
			return node
	return null


# ------------------------------------------------------------ Ctrl+L --

func test_ctrl_l_takes_the_quickslot_up_at_once() -> void:
	await _world()
	screen.player.gold = 111
	await _key(KEY_S, true)
	assert_true(FileAccess.file_exists(screen.player.save_path(SaveSlots.QUICK_KIND)), "Ctrl+S saved")
	screen.player.gold = 999
	var old := screen
	var id := screen.player.adventure_id
	await _key(KEY_L, true)
	var fresh := _taken_over()
	assert_not_null(fresh, "the Quickslot's world is up")
	if fresh == null:
		return
	assert_eq(fresh.player.gold, 111, "as the last Ctrl+S left it")
	assert_eq(fresh.player.adventure_id, id, "the same adventure")
	assert_true(not is_instance_valid(old) or old.is_queued_for_deletion(), "the old world gone")
	assert_null(fresh.find_child("LoadAdventure", true, false), "no list in between")
	assert_eq(fresh._quick_notice.text if fresh._quick_notice != null else "", WorldScreen.QUICKLOADED,
		"and it says so")


func test_ctrl_l_without_a_quickslot_says_so_and_stays() -> void:
	await _world()
	screen.player.gold = 999
	await _key(KEY_L, true)
	assert_null(_taken_over(), "nothing to take up")
	assert_false(screen.is_queued_for_deletion())
	assert_eq(screen._quick_notice.text, WorldScreen.NO_QUICKSLOT)
	assert_eq(screen.player.gold, 999, "the hero as they were")
	assert_false(screen.loading(), "no list either")


func test_l_alone_still_opens_the_saved_adventures() -> void:
	await _world()
	await _key(KEY_S, true)
	await _key(KEY_L)
	assert_true(screen.loading(), "the list over the world")
	assert_null(_taken_over())


func test_ctrl_l_waits_while_a_duel_holds_the_world() -> void:
	await _world()
	await _key(KEY_S, true)
	screen._duel_held = true
	assert_false(screen.quick_load())
	screen._duel_held = false
	screen._lost = true
	assert_false(screen.quick_load(), "nor after the adventure ended")
	screen._lost = false
	assert_null(_taken_over())


func test_the_keys_page_names_ctrl_l() -> void:
	var keys := {}
	for entry in WorldHud.KEYS:
		keys[entry[0]] = entry[1]
	assert_true(keys.has("Ctrl+L"))
	assert_string_contains(HelpPages.all_text(), "Ctrl+L takes the Quickslot up again at once")


# ------------------------------------------------------------- Delete --

func _saved(hero: String) -> AdventurePlayer:
	var record := _setup(hero).resolve({})
	var adventure := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	adventure.autosave()
	adventure.autosave()   # a second write keeps the first as its .bak
	SaveSlots.save_quick(adventure)
	SaveSlots.save_into(adventure, 2, "By the river")
	return adventure


func _list() -> LoadAdventureScreen:
	var list: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child_autofree(list)
	await _frames(1)
	return list


func _select(list: LoadAdventureScreen, path: String) -> void:
	for i in list.rows.size():
		if not list.rows[i].is_empty() and String(list.rows[i]["path"]) == path:
			(list.find_child("Saves", true, false) as ItemList).select(i)
			return
	fail_test("no row for " + path)


func _answer(list: LoadAdventureScreen, button: String) -> void:
	var ask := list.ask_delete()
	assert_not_null(ask, "asked first")
	if ask == null:
		return
	await _frames(1)
	var choice := ask.find_child(button, true, false) as Button
	assert_not_null(choice, button)
	if choice != null:
		choice.pressed.emit()
	await _frames(2)


func test_delete_removes_the_save_chosen_and_its_backup_only() -> void:
	var goya := _saved("Goya")
	var other := _saved("Inniscor")
	var autosave := goya.save_path(AdventurePlayer.AUTOSAVE)
	assert_true(FileAccess.file_exists(AdventurePlayer.backup_path(autosave)), "the .bak the save keeps")
	var list := await _list()
	assert_false(list.delete_button.disabled, "a save is highlighted")
	_select(list, autosave)
	await _answer(list, "DeleteThis")
	assert_false(FileAccess.file_exists(autosave), "the autosave gone")
	assert_false(FileAccess.file_exists(AdventurePlayer.backup_path(autosave)), "and its .bak")
	assert_true(FileAccess.file_exists(goya.save_path(SaveSlots.QUICK_KIND)), "its Quickslot kept")
	assert_true(FileAccess.file_exists(other.save_path(AdventurePlayer.AUTOSAVE)), "the other adventure kept")
	assert_eq(list.saves_of(goya.adventure_id).size(), 2, "the list read again")
	assert_string_contains((list.find_child("Note", true, false) as Label).text, "Deleted the autosave of Goya")


func test_all_its_saves_forgets_the_whole_adventure() -> void:
	var goya := _saved("Goya")
	var other := _saved("Inniscor")
	var list := await _list()
	_select(list, goya.save_path(SaveSlots.QUICK_KIND))
	await _answer(list, "DeleteAll")
	var left: Array[String] = []
	for file_name in DirAccess.get_files_at(SAVES):
		if file_name.begins_with(goya.adventure_id):
			left.append(file_name)
	assert_eq(left, [] as Array[String], "nothing of Goya's adventure is left")
	assert_eq(list.saves_of(goya.adventure_id).size(), 0)
	assert_eq(list.saves_of(other.adventure_id).size(), 3, "the other adventure whole")


func test_keep_or_escape_deletes_nothing() -> void:
	var goya := _saved("Goya")
	var list := await _list()
	_select(list, goya.save_path(AdventurePlayer.AUTOSAVE))
	await _answer(list, "Keep")
	assert_eq(list.saves_of(goya.adventure_id).size(), 3)
	var ask := list.ask_delete()
	await _frames(1)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	ask._unhandled_input(escape)
	await _frames(2)
	assert_false(list.delete_shown(), "Escape keeps it")
	assert_eq(list.saves_of(goya.adventure_id).size(), 3)
	assert_true(is_instance_valid(list) and not list.is_queued_for_deletion(), "the list stays up")


func test_the_delete_key_asks_and_one_save_offers_no_all() -> void:
	var record := _setup("Solo").resolve({})
	var solo := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	solo.autosave()
	var list := await _list()
	var press := InputEventKey.new()
	press.keycode = KEY_DELETE
	press.pressed = true
	list._unhandled_input(press)
	await _frames(1)
	assert_true(list.delete_shown(), "the Delete key asks")
	assert_null(list._delete_ask.find_child("DeleteAll", true, false), "one save: no All its saves")
