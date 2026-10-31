extends GutTest
## CONTINUE AN ADVENTURE (2026-10-22): [LoadAdventureScreen] lists the
## adventures saved, newest first, and takes the chosen one back into its
## world — the hero where they stood, all they carry, the world as it was.

const FOLDER := "user://adventure_tests_load"


func before_each() -> void:
	AdventurePlayer.saves_folder = FOLDER
	_clear()


func after_each() -> void:
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _clear() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)


func _saved_adventure() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Xenia Quibble"
	setup.color = "blue"
	setup.difficulty = 2
	setup.seed_text = "7"
	var record := setup.resolve({})
	var adventure := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	adventure.gold = 321
	var walk := HeroWalk.new(adventure)
	var way := walk.plan(adventure.tile() + Vector2i(2, 0))
	if not way.is_empty():
		walk.walk_to(way.back())
		for i in 300:
			if not walk.is_walking():
				break
			if walk.tick():
				adventure.world.explore_around(adventure.tile())
	adventure.autosave()
	return adventure


func test_with_nothing_saved_it_says_how_a_save_comes_to_be() -> void:
	var screen: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq((screen.find_child("Saves", true, false) as ItemList).item_count, 0)
	assert_string_contains((screen.find_child("Note", true, false) as Label).text, "No adventure has been saved yet")
	assert_true(screen.resume_button.disabled)


func test_the_saved_adventure_is_listed_and_taken_up_again() -> void:
	var saved := _saved_adventure()
	var screen: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var list := screen.find_child("Saves", true, false) as ItemList
	assert_eq(list.item_count, 2, "the adventure's line, and its autosave")
	assert_eq(list.get_item_text(0), "Xenia Quibble — Blue, Sorcerer · World seed 7")
	assert_string_contains(list.get_item_text(1), "Autosave · autosaved")
	assert_false(screen.resume_button.disabled, "Resume: the newest autosave")
	assert_eq(list.get_selected_items(), PackedInt32Array([1]), "chosen and ready")
	assert_null(screen.find_child("Continue", true, false), "one load action")
	var world_screen := LoadAdventureScreen.open_save(String(screen.saves[0]["path"]))
	assert_not_null(world_screen)
	var back := world_screen.player
	assert_eq([back.name, back.gold, back.position, back.facing], [saved.name, 321, saved.position, saved.facing],
		"the hero where they stood, with what they carry")
	assert_eq(back.world.fingerprint(), saved.world.fingerprint(), "the world as they left it")
	assert_eq(back.monster_timer, saved.monster_timer, "and its clock")
	add_child_autofree(world_screen)
	await get_tree().process_frame
	assert_eq(world_screen.view.hero, Vector2(saved.position), "drawn where they stood")
	assert_true(world_screen.walk != null, "and ready to walk on")


# Exercise the real button wiring without transitioning to another scene.
class SelectionProbe extends LoadAdventureScreen:
	var loaded_row := -1
	func continue_adventure(index: int) -> bool:
		loaded_row = index
		return true


func test_resume_loads_the_selected_quickslot_or_manual_save() -> void:
	var player := _saved_adventure()
	SaveSlots.save_quick(player)
	SaveSlots.save_into(player, 1, "Before the castle")
	var screen := SelectionProbe.new()
	add_child_autofree(screen)
	await get_tree().process_frame
	var list := screen.find_child("Saves", true, false) as ItemList
	assert_eq(list.get_selected_items(), PackedInt32Array([2]), "autosave selected past Quickslot")
	for index in [1, 3]:
		list.select(index)
		list.item_selected.emit(index)
		screen.resume_button.pressed.emit()
		assert_false(screen.resume_button.disabled)
		assert_eq(screen.loaded_row, index, "Resume follows the selection, not the autosave")
	assert_eq(screen.hall_button.get_index(), 0, "Hall at the far left")
	assert_eq(screen.back_button.get_index() + 1, screen.resume_button.get_index(), "Back beside Resume")


func test_without_an_autosave_resume_selects_the_newest_manual_or_quick_save() -> void:
	var player := _saved_adventure()
	var manual := SaveSlots.save_into(player, 1, "Before the castle")
	var quick := SaveSlots.save_quick(player)
	for entry in [[manual, "2026-10-30T10:00:00Z"], [quick, "2026-10-31T10:00:00Z"]]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry[0]))
		data["adventure"]["saved"] = entry[1]
		var file := FileAccess.open(entry[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
	DirAccess.remove_absolute(player.save_path(AdventurePlayer.AUTOSAVE))
	AdventurePlayer.forget_saves()
	var screen := SelectionProbe.new()
	add_child_autofree(screen)
	await get_tree().process_frame
	var list := screen.find_child("Saves", true, false) as ItemList
	assert_false(screen.resume_button.disabled, "manual saves remain loadable without an autosave")
	var selected := list.get_selected_items()
	assert_eq(selected.size(), 1)
	if selected.size() == 1:
		assert_eq(screen.rows[selected[0]]["path"], quick, "newest eligible save selected")
