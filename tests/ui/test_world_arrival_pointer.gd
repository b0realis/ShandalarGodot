extends GutTest
## A WALK'S ARRIVAL NAMES NO PLACE BESIDE THE PANE (the bug pass after the
## campaign, r3-1). The walk's last step opens the place's pane inside the
## world's frame; the frame then read the pointer again — the camera had
## moved — and with the pointer resting on the world, the place's name and
## its pointer came back beside the pane for the whole visit. The world
## waits from the tick that opened it ([method WorldScreen._process]).
##
## The pointer is a real one, pushed through the screen's own viewport.

const SAVES := "user://adventure_tests_arrival_pointer"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	for i in 3:
		await get_tree().process_frame
	screen.player.monsters = [] as Array


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func test_a_walk_s_arrival_names_no_place_beside_the_pane() -> void:
	var town := -1
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
			break
	var tile := Vector2i(int(screen.world.sites[town]["x"]), int(screen.world.sites[town]["y"]))
	assert_true(screen.walk_to_tile(tile), "control: a way to the town")
	# The pointer rests on the world, in the middle of the screen.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(viewport.size) * 0.5
	motion.global_position = motion.position
	viewport.push_input(motion, true)
	await get_tree().process_frame
	assert_eq(viewport.gui_get_hovered_control(), screen.view, "control: the pointer is over the world")
	for i in 4000:
		if screen.visiting():
			break
		screen._process(HeroWalk.TICK)
	assert_true(screen.visiting(), "control: the walk arrived and the pane opened")
	assert_false(screen.hud._place_tip.visible, "no place name beside the pane")
	screen._process(HeroWalk.TICK)
	assert_false(screen.hud._place_tip.visible, "nor a frame later")
