extends GutTest
## Needs the imported 1997 skin — THE DUNGEON MARKERS ON THE WORLD (the
## quick world package, 2026-10-27, step 2 — item A): a dungeon the hero
## holds a clue to stands on its tile as 1997 drew it (adventureWorldUi.c
## 1230–1257): its upright among the uprights and its ground half with the
## ground, both 32 less the upright's height above the tile's left corner,
## the pair of `g_dungeon_marker_sprite_lookup` for its slot — on land not
## yet seen too (the owner's ruling A-1); none without a clue; drawn again
## when one is learned.

var view: WorldView
var world: ShandalarWorld
var player: AdventurePlayer


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	world = AdventureSetup.make_world(record)
	player = AdventurePlayer.begin(record, world)
	view = WorldView.new()
	add_child_autofree(view)
	view.size = Vector2(1280, 800)
	view.world = world
	view.zoom = 1.0


## The first dungeon (5–14) on land the hero has not seen.
func _unseen_dungeon() -> int:
	for index in range(5, 15):
		var slot: Dictionary = world.encounters[index]
		if not world.is_explored(int(slot["x"]), int(slot["y"])):
			return index
	return -1


## The view looking at dungeon [param index]'s tile.
func _look_at(index: int) -> Vector2i:
	var slot: Dictionary = world.encounters[index]
	var tile := Vector2i(int(slot["x"]), int(slot["y"]))
	view.hero = Vector2(tile.x * 32 + 16, tile.y * 32 + 16)
	view.camera = view.hero
	await wait_process_frames(3)
	return tile


## The uprights drawn of [param sheet]'s frame [param frame]: their places.
func _uprights_of(sheet: String, frame: int) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var texture := view.art.texture(sheet)
	var region := view.art.frame_rect(sheet, frame)
	for op in view._upright_ops:
		if op[0] == texture and op[2] == region:
			found.append(op[1])
	return found


## The left corner of [param tile] on the view's pictures.
func _left_of(tile: Vector2i) -> Vector2:
	var i := view._tiles.find(tile)
	assert_gt(i, -1, "control: the tile is among those drawn")
	return view._lefts[i] if i >= 0 else Vector2.INF


func test_a_known_dungeon_stands_on_its_tile_seen_or_not() -> void:
	assert_true(view.art.ready(), "the 1997 sheets")
	var index := _unseen_dungeon()
	assert_gt(index, -1, "control: a dungeon on land not seen")
	var tile: Vector2i = await _look_at(index)
	assert_false(world.is_explored(tile.x, tile.y), "control: land not seen")
	var frames := WorldView.dungeon_frames(index)
	var upright: Array = frames[0]
	assert_true(_uprights_of(upright[0], upright[1]).is_empty(), "no clue: not drawn")
	world.encounters[index]["clues"] = WorldClues.CREATURES
	view.dungeons = WorldClues.on_world(world)
	await wait_process_frames(3)
	var found := _uprights_of(upright[0], upright[1])
	assert_eq(found.size(), 1, "a clue learned: drawn again, standing there, over the dark [QoL]")
	var height := view.art.frame_size(upright[0]).y
	assert_gt(height, 32.0, "control: the location sheet's frame height")
	var left := _left_of(tile)
	assert_eq(found[0].position, left + Vector2(0, 32 - height), "1997's place: 32 less its height above the corner")
	var ground := view._dungeon_op(tile, true)
	assert_false(ground.is_empty(), "its ground half")
	assert_eq(ground[2], view.art.frame_rect(frames[1][0], frames[1][1]), "the slot's own ground half")
	assert_eq(ground[1].position, Vector2(0, 32 - height), "at the upright's place")


func test_on_land_seen_the_tile_keeps_its_trees_under_the_dark_it_hides_them() -> void:
	var index := _unseen_dungeon()
	var tile: Vector2i = await _look_at(index)
	world.encounters[index]["clues"] = WorldClues.LOCATION
	view.dungeons = WorldClues.on_world(world)
	await wait_process_frames(3)
	var frames := WorldView.dungeon_frames(index)
	var i := view._tiles.find(tile)
	assert_gt(i, -1, "control: the tile drawn")
	var trees: Array = view._recipe(tile)[2]
	assert_gt(trees.size(), 0, "control: the dungeon's tile has its trees or rocks (1997 kept them)")
	assert_eq(_uprights_of(frames[0][0], frames[0][1]).size(), 1, "unseen: the marker stands")
	assert_false(_has_upright(trees[0], view._lefts[i]), "and the tile's trees stay hidden in the dark")
	world.explore_around(tile)
	view.queue_redraw()
	await wait_process_frames(3)
	i = view._tiles.find(tile)
	assert_eq(_uprights_of(frames[0][0], frames[0][1]).size(), 1, "seen: the marker stands")
	assert_true(_has_upright(trees[0], view._lefts[i]), "with the tile's trees")


## Whether recipe upright [param upright] (`[foot, sheet, where, frame]`)
## of the tile whose left corner is [param left] is among those drawn.
func _has_upright(upright: Array, left: Vector2) -> bool:
	for op in view._upright_ops:
		if op[0] == upright[1] and op[2] == upright[3] and (op[1] as Rect2).position == left + (upright[2] as Rect2).position:
			return true
	return false
