extends GutTest
## 0.70.11 campaign, robust2 R2-5: the app paused (a phone's Home, a
## headset taken off) saves a world at rest as the window's close does, and
## closes nothing; a deck builder open or an adventure lost saves nothing.

const SAVES := "user://c1126_adv_pause_saves"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Probe"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	for i in 3:
		await get_tree().process_frame
	screen.set_process(false)
	screen.player.monsters = [] as Array
	AdventurePlayer.finish_saves()


func after_each() -> void:
	AdventurePlayer.finish_saves()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


func _saved_gold() -> int:
	var saved := AdventurePlayer.load_from(screen.player.save_path())
	return saved.gold if saved != null else -1


func test_a_pause_saves_the_world_at_rest_and_the_game_goes_on() -> void:
	screen.player.gold = 4321
	assert_ne(_saved_gold(), 4321, "not saved yet")
	screen.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_saved_gold(), 4321, "saved as the app pauses")
	assert_true(screen.is_inside_tree() and not screen._leaving, "nothing left")
	screen.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_false(screen.modal())


func test_a_pause_with_the_deck_builder_open_or_the_adventure_lost_saves_nothing() -> void:
	screen.autosave()
	var before := _saved_gold()
	screen.player.gold = before + 77
	var builder := screen.show_deck()
	assert_not_null(builder)
	screen.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_saved_gold(), before, "the builder answers for itself")
	builder.closed.emit()
	await get_tree().process_frame
	screen.show_end(["The end."])
	screen.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_saved_gold(), before, "a lost adventure keeps its saves as they were")
