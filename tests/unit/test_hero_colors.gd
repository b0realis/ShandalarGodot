extends GutTest
## THE WALKING FIGURE'S COLOURS (2026-10-22): [HeroColors] finds the 1997
## figure's parts by colour and height, dresses each in a chosen colour
## along its own shading, and leaves the trim (his green cuffs and belt,
## her red sash) as painted.


func test_the_parts_of_the_1997_figures() -> void:
	# [colour, height in the figure, female] → part index, -1 trim.
	var cases := [
		[Color8(15, 11, 11), 0.1, false, 0], [Color8(15, 11, 11), 0.9, false, 5],
		[Color8(103, 59, 47), 0.2, false, 0], [Color8(211, 143, 115), 0.2, false, 1],
		[Color8(223, 223, 223), 0.4, false, 3], [Color8(191, 35, 15), 0.3, false, 2],
		[Color8(0, 51, 151), 0.7, false, 4], [Color8(7, 163, 47), 0.5, false, -1],
		[Color8(19, 83, 203), 0.3, true, 2], [Color8(7, 187, 55), 0.7, true, 4],
		[Color8(191, 35, 15), 0.4, true, -1], [Color8(175, 179, 239), 0.25, true, 3],
	]
	for case in cases:
		assert_eq(HeroColors.part_of(case[0], case[1], case[2]), case[3], str(case))


## A sheet of two 4 × 8 frames: hair on top, a skin row, a body row, the
## sleeves, a green trim row, the trousers and boots at the feet.
func _sheet() -> Image:
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	var rows := [Color8(15, 11, 11), Color8(211, 143, 115), Color8(191, 35, 15), Color8(223, 223, 223),
		Color8(7, 163, 47), Color8(0, 51, 151), Color8(0, 23, 59), Color8(31, 31, 31)]
	for x in 8:
		for y in 8:
			image.set_pixel(x, y, rows[y] if x != 0 else Color(0, 0, 0, 0))
	return image


func test_a_part_is_dressed_along_its_own_shading() -> void:
	var sheet := _sheet()
	var dressed := HeroColors.dress(sheet, Vector2i(4, 8), false, {"body": "blue", "boots": "brown"})
	assert_ne(dressed, sheet, "a new picture")
	var blue: Color = HeroColors.choice("body", "blue")[2]
	assert_almost_eq(dressed.get_pixel(2, 2).h, blue.h, 0.02, "the vest is blue now")
	assert_eq(dressed.get_pixel(2, 1), sheet.get_pixel(2, 1), "the skin as it was")
	assert_eq(dressed.get_pixel(2, 4), sheet.get_pixel(2, 4), "the trim as it was")
	assert_almost_eq(dressed.get_pixel(2, 7).h, (HeroColors.choice("boots", "brown")[2] as Color).h, 0.05, "brown boots")
	assert_eq(dressed.get_pixel(0, 3).a, 0.0, "the clear stays clear")
	assert_eq(HeroColors.dress(sheet, Vector2i(4, 8), false, {}), sheet, "all in 1997: the sheet itself")


func test_the_ramp_keeps_the_shading() -> void:
	var red := Color8(200, 40, 30)
	assert_eq(HeroColors.ramp(red, 0.5), red, "the colour in the middle")
	assert_lt(HeroColors.ramp(red, 0.0).v, red.v, "darker below")
	assert_gt(HeroColors.ramp(red, 1.0).get_luminance(), red.get_luminance(), "lighter above")


func test_the_choices_are_kept_as_text_and_drawn_at_random() -> void:
	var colors := {"hair": "auburn", "skin": "olive", "boots": "black"}
	assert_eq(HeroColors.from_text(HeroColors.to_text(colors)), colors)
	assert_eq(HeroColors.from_text("hair=nonsense,cape=red,skin=tan"), {"skin": "tan"}, "only what a figure can wear")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var kept := 0
	var dressed := 0
	for draw in 60:
		var drawn := HeroColors.random(rng)
		assert_eq(HeroColors.cleaned(drawn), drawn, "every key one a part offers")
		for part in HeroColors.PARTS:
			if drawn.has(part):
				dressed += 1
			else:
				kept += 1
	assert_gt(kept, 0, "now and then a part keeps its 1997 colour")
	assert_gt(dressed, kept, "but mostly a new one")
	assert_eq(HeroColors.swatch("body", HeroColors.ORIGINAL, false), HeroColors.PAINTED["body"][0], "his red vest")
	assert_eq(HeroColors.swatch("body", HeroColors.ORIGINAL, true), HeroColors.PAINTED["body"][1], "her blue bodice")


func _art_with_sheet(image: Image, logical: Vector2i, walker := "male") -> WorldArt:
	var art := WorldArt.new()
	var key := "world_ego_f" if walker == "female" else "world_ego_m"
	art._textures[key] = GameSkin.texture_of(image, logical)
	art._meta[key] = {"cols": 2, "frame_width": 4, "frame_height": 8}
	return art


func test_upscaled_dressed_figures_keep_the_original_size_and_each_complete_frame() -> void:
	var colors := {"hair": "blond", "body": "blue", "boots": "brown"}
	for walker in ["male", "female"]:
		var original := _sheet()
		var female: bool = walker == "female"
		if female:
			for x in range(1, 8):
				original.set_pixel(x, 2, Color8(19, 83, 203))
				original.set_pixel(x, 5, Color8(7, 187, 55))
		var expected := HeroColors.dress(original, Vector2i(4, 8), female, colors)
		for scale in [1, 2, 4]:
			var image := original.duplicate() as Image
			image.resize(8 * scale, 8 * scale, Image.INTERPOLATE_NEAREST)
			var art := _art_with_sheet(image, original.get_size(), walker)
			var dressed := HeroColors.dressed(art, walker, colors)
			assert_eq(dressed.get_size(), Vector2(8, 8), "same drawn size at %dx" % scale)
			assert_eq(GameSkin.scale_of(dressed), scale, "resolution retained at %dx" % scale)
			assert_eq(dressed.get_image().get_size(), image.get_size(), "keep the detailed pixels")
			for frame in 2:
				var rect := Rect2i(art.frame_rect("world_ego_f" if female else "world_ego_m", frame))
				var cut := GameSkin.cut(dressed, rect)
				cut.resize(4, 8, Image.INTERPOLATE_NEAREST)
				assert_eq(cut.get_data(), expected.get_region(rect).get_data(),
					"complete, correctly dressed frame %d at %dx" % [frame, scale])


func test_upscaled_recoloring_keeps_fine_shading_and_transparency() -> void:
	var original := _sheet()
	original.set_pixel(3, 2, Color8(100, 20, 10))
	var image := original.duplicate() as Image
	image.resize(16, 16, Image.INTERPOLATE_NEAREST)
	image.set_pixel(4, 4, Color(0.5, 0.1, 0.05, 0.5))
	var painted := HeroColors.dress(image, Vector2i(4, 8), false, {"body": "blue"}, "", original)
	assert_lt(painted.get_pixel(4, 4).v, painted.get_pixel(5, 4).v, "keep the larger picture's finer shades")
	assert_almost_eq(painted.get_pixel(4, 4).h, (HeroColors.choice("body", "blue")[2] as Color).h, 0.02)
	assert_eq(painted.get_pixel(4, 4).a, image.get_pixel(4, 4).a, "keep partial alpha")
	assert_eq(painted.get_pixel(0, 4), image.get_pixel(0, 4), "leave clear pixels alone")


func test_a_different_skin_with_the_same_sheet_size_gets_its_own_parts() -> void:
	var first := _sheet()
	var second := first.duplicate() as Image
	second.set_pixel(2, 2, Color8(223, 223, 223)) # A sleeve where the first skin had its vest.
	HeroColors.dressed(_art_with_sheet(first, first.get_size()), "male", {"body": "blue"})
	var dressed := HeroColors.dressed(_art_with_sheet(second, second.get_size()), "male", {"body": "blue"})
	assert_eq(dressed.get_image().get_pixel(2, 2), second.get_pixel(2, 2), "the new skin's sleeve is left alone")


func test_original_colors_keep_the_skin_sheet_without_a_recolored_copy() -> void:
	var original := _sheet()
	var art := _art_with_sheet(original, original.get_size())
	assert_null(HeroColors.dressed(art, "male", {}))
	assert_null(HeroColors.dressed(art, "male", {"body": HeroColors.ORIGINAL}))
