extends GutTest
## The island palette is recolored off the thread that draws (0.60.13 bug
## campaign, h1-6): the sheet as the skin has it meanwhile, the same
## recolored pixels after, and the drawn world told once when they arrive.

const DRY := WorldTerrainPalette.DRY_COAST

var _forced := -1


func before_each() -> void:
	_forced = SkinWarmer.forced
	SkinWarmer.forced = 1   # a worker may run here, as in the game


func after_each() -> void:
	SkinWarmer.forced = _forced


func _sheet(size: Vector2i, scale := 1) -> Texture2D:
	var pixels := Image.create(size.x * scale, size.y * scale, false, Image.FORMAT_RGBA8)
	pixels.fill(Color("54a032"))
	pixels.set_pixel(1, 1, Color("2c6634"))
	pixels.set_pixel(130 * scale, 2, Color("347fbd"))   # water in the second cell
	pixels.set_pixel(0, 0, Color(0.2, 0.7, 0.1, 0.0))
	return GameSkin.texture_of(pixels, size)


func _island() -> ShandalarWorld:
	var island := ShandalarWorld.new()
	island.expansion = {"region": "refuge"}
	island.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	return island


func _until_delivered() -> void:
	for i in 600:
		if WorldTerrainPalette.recoloring() == 0:
			return
		await get_tree().process_frame
	assert_eq(WorldTerrainPalette.recoloring(), 0, "the worker's sheets arrived")


func test_the_skins_sheet_is_drawn_while_a_worker_recolors_it_then_the_world_is_told(scale = use_parameters([1, 2])) -> void:
	var island := _island()
	assert_eq(WorldTerrainPalette.for_world(island), DRY)
	watch_signals(island)
	var revision := island.appearance_revision
	var palette := WorldTerrainPalette.new()
	var source := _sheet(Vector2i(768, 64), scale)
	assert_same(palette.texture("world_landtile", source, DRY), source,
		"the frame that asks draws the skin's sheet: nothing recolored on this thread")
	assert_same(palette.texture("world_landtile", source, DRY), source, "a redraw starts no second recolor")
	assert_eq(WorldTerrainPalette.recoloring(), 1)
	await _until_delivered()
	var changed := palette.texture("world_landtile", source, DRY)
	assert_ne(changed, source)
	var expected := WorldTerrainPalette.recolor(source.get_image(), "world_landtile", DRY, scale)
	assert_eq(changed.get_image().get_data(), expected.get_data(), "the same pixels the old way made")
	assert_eq(changed.get_size(), source.get_size(), "the logical size")
	assert_eq(GameSkin.scale_of(changed), scale)
	assert_signal_emit_count(island, "appearance_changed", 1, "the world's views look again, once")
	assert_eq(island.appearance_revision, revision + 1)


func test_sheets_asked_together_arrive_together_and_are_shared_by_the_map() -> void:
	var island := _island()
	WorldTerrainPalette.for_world(island)
	watch_signals(island)
	var view := WorldTerrainPalette.new()
	var sheets := {"world_landtile": _sheet(Vector2i(768, 64)), "world_cstline1": _sheet(Vector2i(448, 384)),
		"world_map_tiles": _sheet(Vector2i(208, 80))}
	for key in sheets:
		assert_same(view.texture(key, sheets[key], DRY), sheets[key])
	await _until_delivered()
	assert_signal_emit_count(island, "appearance_changed", 1, "one look again for every sheet")
	var map := WorldTerrainPalette.new()
	for key in sheets:
		var changed := view.texture(key, sheets[key], DRY)
		assert_ne(changed, sheets[key])
		assert_same(map.texture(key, sheets[key], DRY), changed, "the map's palette reuses the view's sheet")
	assert_eq(WorldTerrainPalette.recoloring(), 0, "nothing recolored twice")


func test_a_palette_gone_before_its_sheet_arrives_is_not_waited_for() -> void:
	var island := _island()
	WorldTerrainPalette.for_world(island)
	watch_signals(island)
	var palette := WorldTerrainPalette.new()
	var source := _sheet(Vector2i(768, 64))
	palette.texture("world_landtile", source, DRY)
	palette = null
	await _until_delivered()
	assert_signal_emit_count(island, "appearance_changed", 0, "no view left to look again")


func test_the_mainland_is_never_recolored_nor_watched() -> void:
	var mainland := ShandalarWorld.new()
	mainland.expansion = {"region": "mainland"}
	assert_eq(WorldTerrainPalette.for_world(mainland), WorldTerrainPalette.SHANDALAR)
	var palette := WorldTerrainPalette.new()
	var source := _sheet(Vector2i(768, 64))
	assert_same(palette.texture("world_landtile", source, WorldTerrainPalette.SHANDALAR), source)
	assert_same(palette.texture("world_roads", source, DRY), source)
	assert_eq(WorldTerrainPalette.recoloring(), 0)
	assert_false(WorldTerrainPalette._drawn.has(mainland.get_instance_id()))


func test_where_no_worker_may_run_the_recolor_stays_on_demand() -> void:
	SkinWarmer.forced = 0
	var palette := WorldTerrainPalette.new()
	var source := _sheet(Vector2i(768, 64))
	var changed := palette.texture("world_landtile", source, DRY)
	assert_ne(changed, source, "headless and the web recolor at once, as before")
	assert_eq(WorldTerrainPalette.recoloring(), 0)


## Every key at both resolutions, random colors and alphas: the recolor
## that runs on the worker makes exactly the pixels 0.60.12's made.
func test_the_word_at_a_time_recolor_matches_the_pixel_at_a_time_one(scale = use_parameters([1, 2])) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026_11_03 + scale
	var sheets := {"world_landtile": Vector2i(768, 8), "world_cstline1": Vector2i(448, 140),
		"world_land": Vector2i(640, 12), "world_land2": Vector2i(640, 12), "world_sland": Vector2i(640, 12),
		"world_sland2": Vector2i(640, 12), "world_map_tiles": Vector2i(208, 80), "world_roads": Vector2i(64, 8)}
	for key in sheets:
		var size: Vector2i = sheets[key] * scale
		var source := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		for y in size.y:
			for x in size.x:
				var alpha: int = [0, 128, 255, 255, 255, 255, 255, 255, 255, 255][rng.randi_range(0, 9)]
				source.set_pixel(x, y, Color8(rng.randi_range(0, 255), rng.randi_range(0, 255),
					rng.randi_range(0, 255), alpha))
		var made := WorldTerrainPalette.recolor(source, key, DRY, scale)
		assert_eq(made.get_data(), _reference(source, key, DRY, scale).get_data(), "%s at %dx" % [key, scale])


## 0.60.12's WorldTerrainPalette.recolor, verbatim but for its name.
static func _reference(source: Image, key: String, profile: String, scale := 1) -> Image:
	var result := source.duplicate() as Image
	if not WorldTerrainPalette._remaps(profile) or not WorldTerrainPalette.supports(key):
		return result
	result.convert(Image.FORMAT_RGBA8)
	var bytes := result.get_data()
	var width := result.get_width()
	var height := result.get_height()
	bytes.resize(width * height * 4)
	var colors := {}
	for y in height:
		for x in width:
			var at := (y * width + x) * 4
			if bytes[at + 3] == 0:
				continue
			var style := "grass"
			match key:
				"world_landtile":
					var column := x / (128 * scale)
					if column == 1: style = "water"
					elif column != 0: continue
				"world_cstline1":
					if y < 128 * scale: style = "coast"
				"world_map_tiles":
					if y >= 60 * scale: continue
					var terrain := (x / (13 * scale)) % 16
					if terrain in [0, 1, 8]: style = "water"
					elif not terrain in [2, 6, 10, 15]: continue
					elif terrain == 2: style = "foliage"
				"world_land", "world_land2", "world_sland", "world_sland2":
					var object_column := (x / (128 * scale)) % 5
					if object_column != 4: style = "foliage"
					if object_column == (0 if key.ends_with("2") else 1): style = "wet_foliage"
			var rgb := (int(bytes[at]) << 16) | (int(bytes[at + 1]) << 8) | int(bytes[at + 2])
			var kind := 0
			match style:
				"foliage": kind = 1
				"water": kind = 2
				"coast": kind = 3
				"wet_foliage": kind = 4
			var memo := rgb | (kind << 24)
			if not colors.has(memo):
				var original := Color8(bytes[at], bytes[at + 1], bytes[at + 2])
				var recipe := style
				if style == "coast": recipe = "water" if original.h >= 0.42 else "grass"
				elif style == "wet_foliage": recipe = "water" if original.h >= 0.42 else "foliage"
				var changed := WorldTerrainPalette.shift(original, profile, recipe)
				colors[memo] = (changed.r8 << 16) | (changed.g8 << 8) | changed.b8
			var changed: int = colors[memo]
			bytes[at] = (changed >> 16) & 255
			bytes[at + 1] = (changed >> 8) & 255
			bytes[at + 2] = changed & 255
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)
	if source.has_mipmaps(): image.generate_mipmaps()
	return image
