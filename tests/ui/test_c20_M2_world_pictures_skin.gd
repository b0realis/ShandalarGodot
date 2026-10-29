extends GutTest
## Needs the imported 1997 skin — THE 1997 WORLD'S PICTURES DRAWN WITHOUT A
## HITCH (the smoothness pass, 0.50.66; the profiler's #4 and #5). Drawing
## the ground again at the furthest zoom took 22–29 ms in one frame; a
## town's flags changing (visited, priced — nothing drawn) threw away every
## tile's worked-out picture and drew them all again, 15–28 ms at the
## default zoom and 60–73 ms at the furthest; the first zoom out worked out
## two thousand tiles in its one frame (55–66 ms). Now the next pictures are
## drawn a share of a frame at a time, only a tile whose site changed is
## worked out again, the tiles a zoom out would want are worked out in
## spare time, and a creature just come into view waits for its sheets
## rather than the frame for them.

var view: WorldView
var world: ShandalarWorld
var player: AdventurePlayer
var start := Vector2.ZERO


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	world = AdventureSetup.make_world(record)
	player = AdventurePlayer.begin(record, world)
	start = Vector2(player.position)
	for y in range(0, 64, 3):
		for x in range(0, 64, 3):
			world.explore_around(Vector2i(x, y))
	view = WorldView.new()
	add_child_autofree(view)
	view.size = Vector2(1280, 800)
	view.world = world
	view.hero = start
	view.camera = start
	await wait_process_frames(3)
	assert_true(view.art.ready(), "the 1997 sheets")


func after_each() -> void:
	SkinWarmer.forced = -1


## At the furthest zoom the next pictures take several frames' shares; the
## pictures shown stay shown, whole, until the next are done.
func test_the_next_pictures_are_drawn_a_share_of_a_frame_at_a_time() -> void:
	view.zoom = WorldView.ZOOM_MIN
	await wait_process_frames(2)
	view.finish_drawing()
	var front: WorldView.Picture = view._front
	var drawings := view._drawing
	var at_once := view._at_once
	# Half the margin walked: the next pictures begun.
	view.camera = view.camera + Vector2(30, 30)
	var frames := 0
	var began := false
	while view._drawing == drawings and frames < 120:
		await get_tree().process_frame
		frames += 1
		if view._next != null:
			began = true
			assert_eq(view._front, front, "the pictures shown stay shown")
	assert_true(began, "the next pictures were drawn ahead")
	assert_eq(view._drawing, drawings + 1, "and shown when done")
	assert_eq(view._at_once, at_once, "never in one go")
	assert_gte(frames, 2, "over several frames' shares (%d)" % frames)
	assert_ne(view._front, front)


## A town's flags change nothing drawn: nothing is worked out or drawn
## again. The town taken: its tile alone is worked out again (its dome),
## and the pictures drawn again within a few frames.
func test_only_a_changed_site_s_tile_is_worked_out_again() -> void:
	var slot := -1
	for i in world.sites.size():
		var kind := int(world.sites[i].get("type", 0))
		var tile := Vector2i(int(world.sites[i]["x"]), int(world.sites[i]["y"]))
		if kind >= ShandalarWorld.VILLAGE and kind <= ShandalarWorld.CITY and TownStatus.ruler(world, i) == 0 \
				and view._recipes.has(tile):
			slot = i
			break
	assert_gt(slot, -1, "a free town on the screen")
	var tile := Vector2i(int(world.sites[slot]["x"]), int(world.sites[slot]["y"]))
	var kept := view._recipes.duplicate()
	var drawings := view._drawing
	TownStatus.put(world, slot, TownStatus.PRICED)
	view.queue_redraw()
	await wait_process_frames(4)
	assert_eq(view._drawing, drawings, "a flag not drawn: nothing drawn again")
	var same := true
	for key in kept:
		same = same and is_same(view._recipes.get(key), kept[key])
	assert_true(same, "and nothing worked out again")
	TownStatus.take(world, slot, 2)
	view.queue_redraw()
	var frames := 0
	while view._drawing == drawings and frames < 12:
		await get_tree().process_frame
		frames += 1
	assert_eq(view._drawing, drawings + 1, "the town taken: drawn again")
	assert_lte(frames, 4, "within a few frames (%d)" % frames)
	assert_false(is_same(view._recipes.get(tile), kept[tile]), "its tile worked out again")
	var others := 0
	var kept_too := 0
	for key in kept:
		if key == tile:
			continue
		others += 1
		if is_same(view._recipes.get(key), kept[key]):
			kept_too += 1
	assert_eq(kept_too, others, "every other tile's kept")
	var dome := false
	for upright in view._recipes[tile][2]:
		dome = dome or upright[1] == view.art.texture(String(WorldView.DOMES[1][0]))
	assert_true(dome, "the dome drawn on it")


## The frames' spare time works out what a zoom out would want: the first
## zoom out works out none in its own frame.
func test_a_zoom_out_finds_its_tiles_worked_out() -> void:
	var wanted := WorldView._tiles_over(view._screen_round(view._anchor, Vector2(view._anchor), WorldView.ZOOM_MIN)
		.grow(WorldView.SPARE / WorldView.ZOOM_MIN), WorldView._lay(Vector2(view._anchor)))
	var missing := 0
	for tile in wanted:
		if not view._recipes.has(tile):
			missing += 1
	assert_gt(missing, 500, "control: a zoom out wants hundreds of tiles not yet drawn (%d)" % missing)
	for i in 600:
		view.frame(0.0, 0.0)
		await get_tree().process_frame
		if view._warm_done >= view._warm.size() and not view._warm.is_empty():
			break
	missing = 0
	for tile in wanted:
		if not view._recipes.has(tile):
			missing += 1
	assert_eq(missing, 0, "worked out in spare time")
	var count := view._recipes.size()
	view.zoom = WorldView.ZOOM_MIN
	await wait_process_frames(2)
	assert_eq(view._recipes.size(), count, "the zoom out worked out none of its own")


## A creature come into view whose sheets a worker still reads is drawn
## once they are in hand ([method WorldArt.sheet_ready]), not stalled on.
func test_a_creature_waits_for_its_sheets() -> void:
	SkinWarmer.forced = 1
	var row := -1
	var keys := {}
	for r in range(1, 200):
		keys = CreatureBook.sprite_keys(r)
		if String(keys.get("body", "")) != "" and GameSkin.picture_job(String(keys["body"])).size() > 0 \
				and GameSkin.picture_job(String(keys["shadow"])).size() > 0:
			row = r
			break
	assert_gt(row, -1, "a creature whose sheets are not read yet")
	var near: Array[Dictionary] = [{"slot": 2, "creature": row, "x": int(start.x) + 40, "y": int(start.y),
		"heading": 7, "frame": 1, "color": 2}]
	view.creatures = near
	assert_eq(view._creatures_drawn().size(), 0, "not drawn while its sheets are read")
	var frames := 0
	while view._creatures_drawn().is_empty() and frames < 200:
		await get_tree().process_frame
		frames += 1
	assert_eq(view._creatures_drawn().size(), 1, "drawn once they are in hand (%d frames)" % frames)
	assert_not_null(view.art.texture(String(keys["body"])))
