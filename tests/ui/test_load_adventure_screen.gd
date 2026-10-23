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
	assert_true(screen.continue_button.disabled)


func test_the_saved_adventure_is_listed_and_taken_up_again() -> void:
	var saved := _saved_adventure()
	var screen: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var list := screen.find_child("Saves", true, false) as ItemList
	assert_eq(list.item_count, 1)
	assert_string_contains(list.get_item_text(0), "Xenia Quibble — Blue, Sorcerer · World seed 7 · autosaved")
	assert_false(screen.continue_button.disabled, "chosen and ready")
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
