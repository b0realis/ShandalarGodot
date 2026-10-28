extends GutTest
## ARZAKON'S PORTAL ON THE WORLD (part C, W5, 2026-10-28; the owner's pick of
## the mock-ups, the horned arch): [member WorldView.portal] stands on its
## tile as a castle stands — the ground half with the ground, the upright
## among the uprights at the tile's middle row — from this project's own
## pictures (`game/art/world_portal_*`, `tools/draw_world_portal.gd`), the
## `@2x` ones with a 2x skin; the tile's trees make way for it; without the
## 1997 sheets it is drawn plain ([method WorldView.draw_portal_plain]); and
## the world screen hands the adventure's portal to its view. No test here
## needs the imported skin: the pictures are ours.

const SAVES := "user://adventure_tests_portal"


func _world() -> ShandalarWorld:
	return WorldGenerator.generate(777, 5, 2, 0)


func _portal_on(world: ShandalarWorld, state: String) -> Dictionary:
	var tile := FinalBattle.portal_tile(world)
	return {"x": tile.x, "y": tile.y, "state": state}


func test_every_portal_picture_is_ours_at_a_castle_s_size() -> void:
	for state in FinalBattle.PORTAL_STATES:
		for ground in [false, true]:
			var one := GameSkin.our_art(WorldView.portal_key(state, ground, false))
			var two := GameSkin.our_art(WorldView.portal_key(state, ground, true))
			assert_not_null(one, "%s %s" % [state, ground])
			assert_not_null(two, "%s %s @2x" % [state, ground])
			if one != null and two != null:
				assert_eq(one.get_size(), WorldView.PORTAL_FRAME, "a castle's frame")
				assert_eq(two.get_size(), WorldView.PORTAL_FRAME * 2, "twice it")


func test_the_keys() -> void:
	assert_eq(WorldView.portal_key(FinalBattle.PORTAL_OPEN, false, false), "world_portal_open")
	assert_eq(WorldView.portal_key(FinalBattle.PORTAL_PETRIFIED, true, true),
		"world_portal_petrified_ground@2x")
	assert_eq(WorldView.portal_key("", false, false), "", "no state, no picture")
	assert_eq(WorldView.portal_key("ajar", true, false), "", "nor an unknown one")


func test_it_stands_on_its_tile_as_a_castle_stands() -> void:
	var view := WorldView.new()
	add_child_autofree(view)
	var world := _world()
	view.world = world
	assert_eq(view.portal_tile(), Vector2i(-1, -1), "none before it opens")
	assert_eq(view._portal_op(Vector2.ZERO, false, false), [], "nothing drawn")
	for state in FinalBattle.PORTAL_STATES:
		view.portal = _portal_on(world, state)
		var tile := view.portal_tile()
		assert_eq(tile, FinalBattle.portal_tile(world))
		var origin := Vector2(13, -7)
		var left := Vector2(64 * (tile.x + tile.y), 32 * (tile.y - tile.x)) - origin
		for ground in [false, true]:
			var op := view._portal_op(origin, ground, false)
			assert_eq(op.size(), 3, "%s %s drawn" % [state, ground])
			if op.size() != 3:
				continue
			assert_eq(op[0], GameSkin.our_art(WorldView.portal_key(state, ground, false)))
			assert_eq(op[1], Rect2(left + Vector2(0, -160), Vector2(192, 192)), "a castle's place")
			assert_eq(op[2], Rect2(Vector2.ZERO, Vector2(192, 192)), "the whole picture")


func test_a_2x_skin_wears_the_2x_pictures_in_the_same_place() -> void:
	var view := WorldView.new()
	add_child_autofree(view)
	var world := _world()
	view.world = world
	view.portal = _portal_on(world, FinalBattle.PORTAL_OPEN)
	var one := view._portal_op(Vector2.ZERO, false, false)
	var two := view._portal_op(Vector2.ZERO, false, true)
	assert_eq(two[0], GameSkin.our_art("world_portal_open@2x"))
	assert_eq(two[1], one[1], "drawn into the same frame")
	assert_eq(two[2], Rect2(Vector2.ZERO, Vector2(384, 384)), "with all its pixels")


func test_the_portal_s_tile_keeps_no_trees() -> void:
	var view := WorldView.new()
	add_child_autofree(view)
	var world := _world()
	view.world = world
	view.portal = _portal_on(world, FinalBattle.PORTAL_OPEN)
	var halves: Array = []
	var uprights: Array = []
	view._standing_on(view.portal_tile(), halves, uprights)
	assert_eq([halves, uprights], [[], []], "it stands alone, as a site does")


func test_it_is_drawn_among_the_uprights_or_plain() -> void:
	var view := WorldView.new()
	view.size = Vector2(1280, 800)
	add_child_autofree(view)
	var world := _world()
	view.world = world
	var tile := FinalBattle.portal_tile(world)
	view.camera = Vector2(tile.x * 32 + 16, tile.y * 32 + 16)
	view.portal = _portal_on(world, FinalBattle.PORTAL_OPEN)
	await wait_process_frames(3)
	if view.art.ready():
		var found := false
		for op in view._upright_ops:
			if op[0] == GameSkin.our_art(WorldView.portal_key(FinalBattle.PORTAL_OPEN, false,
					view._skin_twice())):
				found = true
		assert_true(found, "the upright among the uprights")
	else:
		assert_true(view._plain, "no sheets: the plain world, the portal drawn in code")


func test_the_plain_portal_wears_one_rim() -> void:
	for petrified in [false, true]:
		var rim := WorldView.portal_plain_rim(Vector2(100, 100), petrified)
		assert_eq(rim.size(), 1, "the shapes' one silhouette (petrified: %s)" % petrified)
		if rim.size() == 1:
			var box := Rect2(rim[0][0], Vector2.ZERO)
			for point in rim[0]:
				box = box.expand(point)
			assert_almost_eq(box.end.y, 107.0, 0.5, "under the plinth, grown by 2")
			assert_lt(box.position.y, 50.0, "over the horns")


func test_the_world_screen_hands_its_view_the_portal() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var screen: WorldScreen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await wait_process_frames(1)
	FinalBattle.open_portal(screen.player)
	screen._show_hero()
	assert_eq(screen.view.portal, screen.player.portal, "open")
	screen.player.portal["state"] = FinalBattle.PORTAL_PETRIFIED
	screen._show_hero()
	assert_eq(String(screen.view.portal["state"]), FinalBattle.PORTAL_PETRIFIED, "petrified")


func after_all() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
