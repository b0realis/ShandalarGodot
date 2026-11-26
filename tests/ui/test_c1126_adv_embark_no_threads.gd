extends GutTest
## 0.70.11 campaign, robust2 R2-1: where the engine has no threads (the
## plain Web package) the Embark makes the world in place — its `Thread`
## there is a stub that starts and never runs, and the hourglass stayed
## for ever. The no-thread path is forced here.

var screen: EmbarkScreen


func before_each() -> void:
	AdventureSetup.forget()
	screen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	EmbarkScreen.world_threads_forced = -1
	AdventureSetup.forget()


func _record() -> Dictionary:
	screen.setup.player_name = "Web Walker"
	screen.setup.seed_text = "4242"
	return screen.setup.resolve({})


func test_the_rule_is_the_engine_s_threads() -> void:
	assert_eq(EmbarkScreen.world_threads_here(), OS.has_feature("threads"))
	EmbarkScreen.world_threads_forced = 0
	assert_false(EmbarkScreen.world_threads_here())


func test_without_threads_the_world_is_made_in_place_and_no_thread_is_started() -> void:
	EmbarkScreen.world_threads_forced = 0
	var record := _record()
	var made: ShandalarWorld = await screen._make_world_aside(record)
	assert_not_null(made, "a world, with no worker")
	assert_null(screen._worker, "no thread was made to wait on")
	var beside := AdventureSetup.make_world(record)
	assert_eq(made.seed, beside.seed)
	assert_eq(made.sites.size(), beside.sites.size(), "the same world as the worker's")


func test_with_threads_the_world_still_comes_from_the_worker() -> void:
	EmbarkScreen.world_threads_forced = 1
	var made: ShandalarWorld = await screen._make_world_aside(_record())
	assert_not_null(made)
	assert_null(screen._worker, "the worker joined")
