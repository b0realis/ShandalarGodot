extends GutTest

func world(region: String) -> ShandalarWorld:
	var out := ShandalarWorld.new()
	out.expansion = {"region": region}
	out.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	return out

func test_only_the_refuge_selects_a_palette_and_travel_resets_the_view() -> void:
	var mainland := world("mainland")
	var island := world("refuge")
	assert_eq(WorldTerrainPalette.for_world(mainland), WorldTerrainPalette.SHANDALAR)
	assert_eq(WorldTerrainPalette.for_world(world("unknown")), WorldTerrainPalette.SHANDALAR)
	assert_eq(WorldTerrainPalette.for_world(null), WorldTerrainPalette.SHANDALAR)
	var view := WorldView.new()
	var map := WorldMap.new()
	view.world = island
	map.world = island
	assert_eq(view.art.terrain_palette, WorldTerrainPalette.DRY_COAST)
	assert_eq(map._art.terrain_palette, WorldTerrainPalette.DRY_COAST)
	view.world = mainland
	map.world = mainland
	assert_eq(view.art.terrain_palette, WorldTerrainPalette.SHANDALAR)
	assert_eq(map._art.terrain_palette, WorldTerrainPalette.SHANDALAR)
	view.free()
	map.free()

func test_grass_becomes_straw_and_foliage_stays_greener_without_changing_stone_or_water() -> void:
	var original := Color("54a032")
	var grass := WorldTerrainPalette.shift(original, WorldTerrainPalette.DRY_COAST)
	var foliage := WorldTerrainPalette.shift(original, WorldTerrainPalette.DRY_COAST, "foliage")
	assert_lt(grass.h, 0.16)
	assert_gt(foliage.h, grass.h)
	assert_lt(grass.s, original.s)
	for color in [Color("347fbd"), Color("30aab0"), Color("858585"), Color("95734a"), Color("e1b968")]:
		assert_eq(WorldTerrainPalette.shift(color, WorldTerrainPalette.DRY_COAST), color)

func test_copy_preserves_alpha_other_frames_and_skin_source_at_both_resolutions() -> void:
	for scale in [1, 2]:
		var source := Image.create(768 * scale, 64 * scale, false, Image.FORMAT_RGBA8)
		source.fill(Color(0.25, 0.6, 0.15, 0.5))
		source.set_pixel(0, 0, Color(0.2, 0.7, 0.1, 0.0))
		var original := source.get_data()
		var changed := WorldTerrainPalette.recolor(source, "world_landtile", WorldTerrainPalette.DRY_COAST, scale)
		assert_eq(source.get_data(), original, "the mounted skin is never rewritten")
		assert_eq(changed.get_size(), source.get_size())
		assert_ne(changed.get_pixel(1, 0), source.get_pixel(1, 0))
		assert_eq(changed.get_pixel(1, 0).a8, source.get_pixel(1, 0).a8)
		assert_eq(changed.get_pixel(0, 0), source.get_pixel(0, 0))
		for frame in range(1, 6):
			assert_eq(changed.get_pixel(frame * 128 * scale, 0), source.get_pixel(frame * 128 * scale, 0))

func test_cached_texture_keeps_upscaled_detail_and_logical_frame_size() -> void:
	var pixels := Image.create(1536, 128, true, Image.FORMAT_RGBA8)
	pixels.fill(Color("54a032"))
	pixels.set_pixel(1, 1, Color("2c6634"))
	pixels.generate_mipmaps()
	var source := GameSkin.texture_of(pixels, Vector2i(768, 64))
	var palette := WorldTerrainPalette.new()
	var changed := palette.texture("world_landtile", source, WorldTerrainPalette.DRY_COAST)
	assert_eq(changed.get_size(), source.get_size())
	assert_eq(changed.get_image().get_size(), Vector2i(1536, 128))
	assert_eq(GameSkin.scale_of(changed), 2)
	assert_true(changed.get_image().has_mipmaps())
	assert_ne(changed.get_image().get_pixel(1, 1), changed.get_image().get_pixel(2, 1))
	assert_same(changed, palette.texture("world_landtile", source, WorldTerrainPalette.DRY_COAST))
	assert_same(source, palette.texture("world_landtile", source, ""))
	for key in ["world_locatn01", "world_ego_m", "world_roads", "world_creature_g_lrd", "font_body"]:
		assert_same(source, palette.texture(key, source, WorldTerrainPalette.DRY_COAST))

func test_map_icons_and_nonvegetated_terrain_are_unchanged() -> void:
	var pixels := Image.create(208, 80, false, Image.FORMAT_RGBA8)
	pixels.fill(Color("54a032"))
	var changed := WorldTerrainPalette.recolor(pixels, "world_map_tiles", WorldTerrainPalette.DRY_COAST)
	assert_eq(changed.get_region(Rect2i(0, 60, 208, 20)).get_data(), pixels.get_region(Rect2i(0, 60, 208, 20)).get_data())
	for terrain in [0, 1, 3, 5, 8, 13]:
		assert_eq(changed.get_pixel(terrain * 13, 0), pixels.get_pixel(terrain * 13, 0))
	assert_ne(changed.get_pixel(6 * 13, 0), pixels.get_pixel(6 * 13, 0))
	var island := world("refuge")
	assert_gt(WorldTerrainPalette.plain(island, 0, WorldView.PLAIN[0]).h, WorldView.PLAIN[0].h)
	assert_ne(WorldTerrainPalette.plain(island, 6, WorldView.PLAIN[6]), WorldView.PLAIN[6])
	assert_eq(WorldTerrainPalette.plain(world("mainland"), 6, WorldView.PLAIN[6]), WorldView.PLAIN[6])
	assert_eq(WorldTerrainPalette.plain(world("mainland"), 0, WorldView.PLAIN[0]), WorldView.PLAIN[0])

func test_water_is_bluer_only_in_water_and_coast_cells_at_both_resolutions() -> void:
	var sea := Color("30aab080")
	var blue := WorldTerrainPalette.shift(sea, WorldTerrainPalette.LAST_REFUGE, "water")
	assert_gt(blue.h, sea.h)
	assert_lt(blue.h, 0.62)
	assert_almost_eq(blue.v, sea.v, 0.03, "waves keep their brightness variation")
	assert_eq(blue.a, sea.a)
	assert_eq(WorldTerrainPalette.shift(sea, WorldTerrainPalette.SHANDALAR, "water"), sea)
	for untouched in [Color("54a032"), Color("e1b968"), Color("858585"), Color.WHITE]:
		assert_eq(WorldTerrainPalette.shift(untouched, WorldTerrainPalette.LAST_REFUGE, "water"), untouched)
	for scale in [1, 2]:
		var ground := Image.create(768 * scale, 64 * scale, false, Image.FORMAT_RGBA8)
		ground.fill(sea)
		var original := ground.get_data()
		var changed := WorldTerrainPalette.recolor(ground, "world_landtile", WorldTerrainPalette.LAST_REFUGE, scale)
		var water := changed.get_pixel(128 * scale, 0)
		assert_gt(water.h, sea.h)
		assert_eq(water.a8, sea.a8)
		assert_eq(ground.get_data(), original)
		for frame in [0, 2, 3, 4, 5]:
			assert_eq(changed.get_pixel(frame * 128 * scale, 0), ground.get_pixel(frame * 128 * scale, 0))
		var coast := Image.create(64 * scale, 256 * scale, false, Image.FORMAT_RGBA8)
		coast.fill(sea)
		coast.set_pixel(0, 1, Color("e1b968"))
		coast.set_pixel(0, 2, Color("54a032"))
		changed = WorldTerrainPalette.recolor(coast, "world_cstline1", WorldTerrainPalette.LAST_REFUGE, scale)
		assert_eq(changed.get_pixel(0, 0), water, "shore water and open water meet without a color seam")
		assert_eq(changed.get_pixel(0, 1), coast.get_pixel(0, 1), "sand stays warm")
		assert_ne(changed.get_pixel(0, 2), coast.get_pixel(0, 2), "grass on the shore still uses the straw recipe")
		assert_eq(changed.get_pixel(0, 128 * scale), coast.get_pixel(0, 128 * scale), "stone edge cells are excluded")
		for key in ["world_land", "world_land2", "world_sland", "world_sland2"]:
			var trees := Image.create(640 * scale, 83 * scale, false, Image.FORMAT_RGBA8)
			trees.fill(sea)
			changed = WorldTerrainPalette.recolor(trees, key, WorldTerrainPalette.LAST_REFUGE, scale)
			var wet_column := 0 if key.ends_with("2") else 1
			assert_eq(changed.get_pixel(wet_column * 128 * scale, 0), water, "water in coastal tree sprites matches the sea")
			assert_eq(changed.get_pixel(2 * 128 * scale, 0), trees.get_pixel(2 * 128 * scale, 0), "other tree columns keep blue details")
		var chart := Image.create(208 * scale, 80 * scale, false, Image.FORMAT_RGBA8)
		chart.fill(sea)
		changed = WorldTerrainPalette.recolor(chart, "world_map_tiles", WorldTerrainPalette.LAST_REFUGE, scale)
		for terrain in [0, 1, 8]:
			assert_eq(changed.get_pixel(terrain * 13 * scale, 0), water, "map water matches the world")
		assert_eq(changed.get_pixel(5 * 13 * scale, 0), chart.get_pixel(5 * 13 * scale, 0))
		assert_eq(changed.get_pixel(0, 60 * scale), chart.get_pixel(0, 60 * scale), "map icons are untouched")

func test_presets_terrain_and_single_tiles_inherit_and_can_be_reset() -> void:
	var map := world("refuge")
	var tile := Vector2i(30, 31)
	var neighbor := tile + Vector2i.RIGHT
	for at in [tile, neighbor]: map.page[at.y * 320 + at.x] = 6
	var fingerprint := map.fingerprint()
	var warm := {"tint": "#d9b484", "strength": 0.4}
	var cool := {"tint": "#88aacc", "strength": 0.7}
	assert_true(WorldTerrainPalette.set_terrain_style(map, 6, {"ground": warm, "objects": cool}))
	assert_true(WorldTerrainPalette.set_tile_style(map, tile, {"preset": WorldTerrainPalette.SHANDALAR, "ground": cool}))
	var local := WorldTerrainPalette.resolve(map, tile)
	var next := WorldTerrainPalette.resolve(map, neighbor)
	assert_eq(local["preset"], WorldTerrainPalette.SHANDALAR)
	assert_eq(local["ground"], cool)
	assert_eq(local["objects"], cool, "other layers inherit from the terrain style")
	assert_eq(next["preset"], WorldTerrainPalette.LAST_REFUGE)
	assert_eq(next["ground"], warm, "the neighboring tile is not affected")
	local["objects"]["strength"] = 0
	assert_eq(WorldTerrainPalette.resolve(map, tile)["objects"]["strength"], 0.7, "callers receive copies")
	assert_true(WorldTerrainPalette.set_tile_style(map, tile, {}))
	assert_eq(WorldTerrainPalette.resolve(map, tile), next)
	assert_true(WorldTerrainPalette.set_terrain_style(map, 6, {}))
	assert_eq(WorldTerrainPalette.resolve(map, tile), {"preset": WorldTerrainPalette.LAST_REFUGE})
	assert_eq(map.fingerprint(), fingerprint, "appearance never changes terrain or roads")

func test_live_changes_notify_views_and_minimap_without_leaking_on_world_switch() -> void:
	var map := world("mainland")
	var view := WorldView.new()
	var chart := WorldMap.new()
	var mini := WorldMinimap.new()
	add_child_autofree(view)
	add_child_autofree(chart)
	add_child_autofree(mini)
	view.world = map
	chart.world = map
	mini.world = map
	watch_signals(map)
	var before := mini.looks
	assert_true(WorldTerrainPalette.set_preset(map, WorldTerrainPalette.LAST_REFUGE))
	assert_eq(view.art.terrain_palette, WorldTerrainPalette.LAST_REFUGE)
	assert_eq(chart._art.terrain_palette, WorldTerrainPalette.LAST_REFUGE)
	assert_gt(mini.looks, before)
	assert_signal_emit_count(map, "appearance_changed", 1)
	assert_true(WorldTerrainPalette.set_preset(map, WorldTerrainPalette.LAST_REFUGE))
	assert_signal_emit_count(map, "appearance_changed", 1, "a repeated setting does not rebuild the view")
	var other := world("mainland")
	view.world = other
	chart.world = other
	mini.world = other
	before = mini.looks
	WorldTerrainPalette.tint_tile(map, Vector2i(30, 30), Color.RED)
	assert_eq(mini.looks, before)
	assert_eq(view.art.terrain_palette, WorldTerrainPalette.SHANDALAR)

func test_tile_tints_reuse_textures_and_survive_upright_occlusion() -> void:
	var map := world("refuge")
	var tile := Vector2i(30, 30)
	map.page[30 * 320 + 30] = 2
	var image := Image.create(768, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color("54a032"))
	var source := ImageTexture.create_from_image(image)
	var view := WorldView.new()
	view.world = map
	view.art._textures["world_landtile"] = source
	view.art._textures["world_locatn01"] = source
	var old := view._op("world_landtile", 0, Vector2.ZERO, tile)
	assert_true(WorldTerrainPalette.tint_tile(map, tile, Color("cc8899"), 0.6))
	var changed := view._op("world_landtile", 0, Vector2.ZERO, tile)
	assert_same(changed[0], old[0], "tints share the cached preset texture")
	assert_ne(WorldView.op_color(changed), Color.WHITE)
	assert_eq(WorldView.op_color(changed).a, 1.0)
	assert_eq(WorldView.op_color(view._op("world_locatn01", 0, Vector2.ZERO, tile)), Color.WHITE)
	assert_eq(WorldView.op_color(view._op("world_landtile", 0, Vector2.ZERO, tile + Vector2i.RIGHT)), Color.WHITE)
	var ink := Color("88aacc")
	var upright: Array = []
	WorldView._stand(upright, 20, [source, Rect2(0, 0, 30, 40), Rect2(0, 0, 30, 40), ink])
	var picture := WorldView.Picture.new()
	picture.lefts = PackedVector2Array([Vector2.ZERO])
	picture.tiles = [tile]
	picture.seen = PackedByteArray([1])
	picture.recipes = [[[], [], upright]]
	view._gather(picture, 0)
	assert_eq(WorldView.op_color(picture.standing[0]), ink)
	view._upright_ops = picture.standing
	view._upright_feet = PackedInt32Array([20])
	var parts := view._in_front_of(20, Rect2(0, 0, 20, 30), tile)
	assert_eq(parts.size(), 1)
	assert_eq(WorldView.op_color(parts[0]), ink, "a tree crossing the hero retains its tint")
	view.free()

func test_saved_appearance_round_trips_as_json_and_invalid_styles_are_refused() -> void:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	var tile := player.tile()
	WorldTerrainPalette.set_preset(player.world, WorldTerrainPalette.LAST_REFUGE)
	WorldTerrainPalette.set_terrain_style(player.world, 6, {"objects": {"tint": "#aabbcc", "strength": 0.3}})
	WorldTerrainPalette.tint_tile(player.world, tile, Color("ffe0cc"), 0.5, "roads")
	var json: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var loaded := AdventurePlayer.from_dict(json)
	assert_not_null(loaded)
	assert_eq(loaded.world.expansion["appearance"], player.world.expansion["appearance"])
	assert_eq(WorldTerrainPalette.resolve(loaded.world, tile), WorldTerrainPalette.resolve(player.world, tile))
	var original: Dictionary = player.world.expansion["appearance"].duplicate(true)
	for bad in [{"ground": {"tint": "#-fffff", "strength": 0.5}},
		{"ground": {"tint": "#abcdef", "strength": -1}},
		{"ground": {"tint": "#abcdef", "strength": NAN}}, {"preset": "unknown"}, {"buildings": {}}]:
		assert_false(WorldTerrainPalette.set_tile_style(player.world, tile, bad))
	assert_false(WorldTerrainPalette.set_tile_style(player.world, Vector2i(64, 0), {}))
	assert_false(WorldTerrainPalette.set_terrain_style(player.world, 16, {}))
	assert_eq(player.world.expansion["appearance"], original)
	json["world"]["expansion"]["appearance"]["tiles"]["64,0"] = {}
	assert_null(AdventurePlayer.from_dict(json), "malformed saved coordinates are rejected")

func test_mainland_and_island_keep_independent_saved_styles() -> void:
	var enabled := CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	WorldTerrainPalette.tint_tile(player.world, player.tile(), Color("cceeff"), 0.25)
	var mainland: Dictionary = player.world.expansion["appearance"].duplicate(true)
	assert_true(RefugeCampaign.travel(player))
	assert_false(player.world.expansion.has("appearance"))
	WorldTerrainPalette.set_preset(player.world, WorldTerrainPalette.SHANDALAR)
	WorldTerrainPalette.tint_tile(player.world, player.tile(), Color("ffeebb"), 0.4)
	var island: Dictionary = player.world.expansion["appearance"].duplicate(true)
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(player)
	assert_true(RefugeCampaign.travel(player))
	assert_eq(player.world.expansion["appearance"], mainland)
	assert_true(RefugeCampaign.travel(player))
	assert_eq(player.world.expansion["appearance"], island)
	CardPacks.set_enabled(FallenEmpiresPack.ID, enabled)
