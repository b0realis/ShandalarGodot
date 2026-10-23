extends GutTest
## THE WORLD'S POINTERS, PAINTED QUICKLY AND THE SAME (the adventure
## campaign of 2026-10-23, h5-4). Each pointer was painted pixel by pixel,
## every shape asked of every one of 16,384 pixels: 20 to 70 ms a pointer,
## half a second for the twelve, on the first pointer worn over a fresh
## world. [WorldCursors] now paints each shape a row at a time; these hold
## every picture to the pixel-by-pixel rule it replaced.


## The rule the pointers were first painted by, pixel by pixel: a pixel
## takes the colour of the last shape it lies in, else ink when it lies
## within the outline's width of any shape, else nothing.
func _painted_pixel_by_pixel(kind: WorldCursors.Kind) -> Image:
	var parts := WorldCursors.shapes(kind)
	var ink_width := WorldCursors.outline(kind)
	var image := Image.create_empty(WorldCursors.DRAWN, WorldCursors.DRAWN, false, Image.FORMAT_RGBA8)
	for y in WorldCursors.DRAWN:
		for x in WorldCursors.DRAWN:
			var at := Vector2(x + 0.5, y + 0.5)
			var color := Color(0, 0, 0, 0)
			var near := false
			for part in parts:
				var d := WorldCursors._distance(part, at)
				if d < 0.0:
					color = part[2]
				elif d < ink_width:
					near = true
			if color.a == 0.0 and near:
				color = WorldCursors.INK
			image.set_pixel(x, y, color)
	return image


## The first pixel where two pictures differ, or "" when none does.
func _first_difference(a: Image, b: Image) -> String:
	if a.get_size() != b.get_size():
		return "sizes %s and %s" % [str(a.get_size()), str(b.get_size())]
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				return "(%d, %d): %s against %s" % [x, y, str(a.get_pixel(x, y)), str(b.get_pixel(x, y))]
	return ""


func test_every_pointer_is_the_same_to_the_pixel() -> void:
	for kind in WorldCursors.Kind.values():
		var name: String = WorldCursors.Kind.keys()[kind]
		var reference := _painted_pixel_by_pixel(kind)
		var drawn := WorldCursors.drawing(kind)
		assert_eq(_first_difference(drawn, reference), "", "%s drawn as before" % name)
		reference.resize(WorldCursors.SIZE, WorldCursors.SIZE, Image.INTERPOLATE_LANCZOS)
		assert_eq(WorldCursors.image(kind).get_data(), reference.get_data(), "%s worn as before" % name)


## Each shape kind on its own, at odd places and sizes — the edges a row's
## run is worked out for (a box's far edge, a circle's top and bottom rows,
## a stroke's round ends, a hollow outline's two runs).
func test_each_kind_of_shape_is_the_same_to_the_pixel() -> void:
	var shapes: Array = [
		["rect", Rect2(10.3, 20.7, 33.4, 9.6), WorldCursors.GOLD],
		["circle", [Vector2(63.5, 64.25), 17.75], WorldCursors.BONE],
		["capsule", [Vector2(20, 100), Vector2(97.3, 31.1), 4.5], WorldCursors.ROOF],
		["capsule", [Vector2(40, 40), Vector2(40, 90), 3.0], WorldCursors.STONE],
		["poly", PackedVector2Array([Vector2(8, 8), Vector2(120, 12), Vector2(64, 60),
			Vector2(118, 118), Vector2(10, 110), Vector2(40, 64)]), WorldCursors.DOME],
	]
	for i in shapes.size():
		for ink_width in [0.0, 5.0, 6.0]:
			var parts: Array = [shapes[i]]
			var fast := WorldCursors._layers(parts, ink_width)
			var slow := Image.create_empty(WorldCursors.DRAWN, WorldCursors.DRAWN, false, Image.FORMAT_RGBA8)
			for y in WorldCursors.DRAWN:
				for x in WorldCursors.DRAWN:
					var d := WorldCursors._distance(shapes[i], Vector2(x + 0.5, y + 0.5))
					if d < 0.0:
						slow.set_pixel(x, y, shapes[i][2])
					elif d < ink_width:
						slow.set_pixel(x, y, WorldCursors.INK)
			assert_eq(_first_difference(fast, slow), "", "%s, ink %s" % [shapes[i][0], ink_width])
