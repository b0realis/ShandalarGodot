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
