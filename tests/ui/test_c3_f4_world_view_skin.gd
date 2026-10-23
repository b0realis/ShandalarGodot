extends GutTest
## Needs the imported 1997 skin — THE UPRIGHTS AND THE HERO AMONG THEM
## (the adventure campaign of 2026-10-23, h5-1). The uprights are kept as
## one picture in the original's order — up by the height of the foot, the
## later of two at one height behind — sorted now on whole numbers rather
## than by a comparison called for every pair; the hero is drawn over that
## picture with the parts of whatever stands in front of them drawn again
## over the hero.

var view: WorldView
var world: ShandalarWorld


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	world = AdventureSetup.make_world(record)
	var player := AdventurePlayer.begin(record, world)
	for y in range(0, 64, 2):
		for x in range(0, 64, 2):
			world.explore_around(Vector2i(x, y))
	view = WorldView.new()
	add_child_autofree(view)
	view.size = Vector2(1280, 800)
	view.world = world
	view.hero = Vector2(player.position)
	view.camera = view.hero
	view.zoom = 1.0
	await wait_process_frames(3)


func test_the_uprights_stand_in_the_original_s_order() -> void:
	assert_true(view.art.ready(), "the 1997 sheets")
	# The original's queue, sorted as it was: by the foot, the later first.
	var queue: Array = []
	for i in view._tiles.size():
		if view._seen[i] == 0:
			continue
		var left: Vector2 = view._lefts[i]
		for upright in view._tile_recipes[i][2]:
			queue.append([left.y + upright[0], queue.size(), upright[1], Rect2(left + upright[2].position, upright[2].size)])
	queue.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] > b[1])
	assert_gt(queue.size(), 200, "a screen of trees, rocks and towns")
	assert_eq(view._upright_ops.size(), queue.size(), "every one of them")
	var same := true
	for i in queue.size():
		same = same and view._upright_ops[i][0] == queue[i][2] and view._upright_ops[i][1] == queue[i][3]
	assert_true(same, "in the same order")


## The hero standing just behind a tree has its trunk over them; standing
## at its foot's height too (the hero came last in the queue); a step in
## front, it is behind them.
func test_what_stands_in_front_of_the_hero_is_drawn_over_them() -> void:
	var tree := -1
	for i in view._upright_ops.size():
		var where: Rect2 = view._upright_ops[i][1]
		if where.size.y == 83 and absf(where.position.x) < 300 and absf(view._upright_feet[i]) < 200:
			tree = i
			break
	assert_gt(tree, -1, "a tree near the middle")
	var where: Rect2 = view._upright_ops[tree][1]
	var foot := float(view._upright_feet[tree])
	var feet_x := where.position.x + where.size.x * 0.5
	for case in [[foot - 4.0, true, "just behind"], [foot, true, "at its foot's height"],
			[foot + 1.0, false, "a step in front"]]:
		var figure := Rect2(Vector2(feet_x, case[0]) - Vector2(77, 61), Vector2(154, 108))
		var found := false
		for part in view._in_front_of(case[0], figure):
			var piece: Rect2 = part[1]
			if part[0] == view._upright_ops[tree][0] and where.encloses(piece):
				found = found or piece.intersects(figure)
		assert_eq(found, case[1], "the tree over the hero %s" % case[2])
