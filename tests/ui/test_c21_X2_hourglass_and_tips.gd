extends GutTest
## THE EMBARK'S HOURGLASS AND ITS NOTICE TIP (the 0.50.66 bug campaign):
## the sand above drawn at the moment its top sinks to the neck was no
## shape the renderer could fill — "Invalid polygon data, triangulation
## failed." (h1-4); and the Notice tip gives the ranges as the nearest
## creature's, the others noticing at half (h3-3).

## The moment of a run (its share, 0–1) at which the sand above, level with
## the neck, could not be cut into triangles — at every size alike (a sweep
## found 0.993908–0.993984).
const LEVEL_WITH_THE_NECK := 0.99395


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _glass(at_size: Vector2, run: float) -> Hourglass:
	var glass := Hourglass.new()
	add_child_autofree(glass)
	# Held at its moment: the clock stopped once it is in the tree (a
	# script's _process is switched on as it enters).
	glass.set_process(false)
	glass.size = at_size
	glass.time = run * Hourglass.RUN
	return glass


func test_the_sand_level_with_the_neck_is_drawn_without_an_error() -> void:
	for at_size in [Vector2(64, 96), Vector2(140, 210), Vector2(2, 3)]:
		var glass := _glass(at_size, LEVEL_WITH_THE_NECK)
		glass.queue_redraw()
		await _frames(2)
		assert_almost_eq(Hourglass.phase(glass.time).x, LEVEL_WITH_THE_NECK, 0.000001,
			"the moment drawn at %s" % at_size)
	# Each moment round it too, a frame each.
	var glass := _glass(Vector2(64, 96), 0.9939)
	for step in 12:
		glass.time = (0.99390 + step * 0.00001) * Hourglass.RUN
		glass.queue_redraw()
		await _frames(1)
	assert_engine_error_count(0, "no triangulation error")


func test_a_shape_with_no_area_is_not_filled() -> void:
	assert_false(Hourglass.fillable(PackedVector2Array([Vector2.ZERO, Vector2(4, 4), Vector2(4, 0),
		Vector2(0, 4)])), "a shape crossing itself")
	assert_false(Hourglass.fillable(PackedVector2Array([Vector2.ZERO, Vector2(4, 0)])), "two points")
	assert_true(Hourglass.fillable(PackedVector2Array([Vector2.ZERO, Vector2(4, 0), Vector2(0, 4)])),
		"control: a triangle")


# -------------------------------------------------------- h3-3: Notice --

func test_the_notice_tip_says_the_ranges_are_the_nearest_creature_s() -> void:
	var tip := String(EmbarkScreen.CREATURE_TIPS[AdventurePlayer.CREATURES_NOTICE])
	assert_string_contains(tip, "a tile and a half for a wizard")
	assert_string_contains(tip, "the creature nearest you")
	assert_string_contains(tip, "the others notice you at half that")
	# As the world reckons it (WorldCreatures.notice_range, slots.c 706–708).
	for row in range(1, CreatureBook.ROWS.size()):
		assert_eq(WorldCreatures.notice_range(row, false), CreatureBook.range_of(row) / 2 * WorldCreatures.NOTICE_SCALE,
			"the others at half: %s" % CreatureBook.name_of(row))
