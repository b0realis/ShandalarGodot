extends GutTest
## THE WORLD'S SMALL SHARED RULES, held to the adventure campaign's fixes
## (2026-10-23): what a site sells ([method WorldMagicShop.sold_at] — slot
## 0 never, though "sold nowhere" is 0), the world sheets' grids when a
## sidecar is missing ([WorldArt]), the amulets' colours without their
## sheet, a painted button's cell clipped to its region
## ([method WorldMap.cell]) and the dissolve's old picture read in the
## window's pixels ([method RevealDissolve.source_rect]).

const TOOL := "res://tools/import_original.py"


func _world(seed_value := 32676, color := 4) -> ShandalarWorld:
	return WorldGenerator.generate(seed_value, seed_value % 128, color, 1)


# ------------------------------------------------- what a site sells --

func test_slot_0_sells_nothing_though_sold_nowhere_reads_0() -> void:
	var world := _world()
	assert_true(TownStatus.is_town(world, 0), "seed 32676: a town in slot 0")
	assert_eq(WorldMagicShop.seller(world, 8), 0, "the red hero's own Staff of Thunder: sold nowhere")
	assert_eq(WorldMagicShop.sold_at(world, 0), -1, "slot 0 sells nothing")
	for i in world.world_magic_sites.size():
		var slot := world.world_magic_sites[i]
		if slot > 0:
			assert_eq(WorldMagicShop.sold_at(world, slot), i, "slot %d sells %s" % [slot, AdventurePlayer.WORLD_MAGICS[i]])
	# Bought, a World Magic's seller reads 0: still nothing at slot 0, and
	# nothing more at its old seller.
	var bought_at := world.world_magic_sites[0]
	world.world_magic_sites[0] = 0
	assert_eq(WorldMagicShop.sold_at(world, 0), -1)
	assert_eq(WorldMagicShop.sold_at(world, bought_at), -1)
	assert_eq(WorldMagicShop.sold_at(null, 3), -1)


func test_the_offer_never_takes_sold_nowhere_for_slot_0() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "32676"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	var offer := WorldMagicShop.offer(player, 0)
	assert_false(offer.is_empty(), "slot 0 is a town: it advertises the nearest")
	assert_ne(int(offer["seller"]), 0, "a real seller, never slot 0")
	assert_false(bool(offer["here"]), "nothing is sold in slot 0 itself")
	assert_false(player.owns(String(offer["name"])))


# ------------------------------------------------------ the sheets' grids --

## The importer's WORLD_SHEETS: `{key: [width, height, columns]}`.
func _importer_grids() -> Dictionary:
	var text := FileAccess.get_file_as_string(TOOL)
	var start := text.find("WORLD_SHEETS: dict")
	var stop := text.find("}", start)
	var rows := RegEx.create_from_string("\"(\\w+)\":\\s*\\((\\d+),\\s*(\\d+),\\s*(\\d+),\\s*(\\d+)\\)")
	var out := {}
	for found in rows.search_all(text.substr(start, stop - start)):
		out[found.get_string(1)] = [int(found.get_string(3)), int(found.get_string(4)), int(found.get_string(5))]
	return out


func test_the_built_in_grids_are_the_importer_s() -> void:
	var grids := _importer_grids()
	assert_gt(grids.size(), 20, "WORLD_SHEETS read from the importer")
	for key in grids:
		assert_true(WorldArt.LAYOUT.has(key), "%s has a built-in grid" % key)
		assert_eq(WorldArt.LAYOUT.get(key, []), grids[key], key)


func test_a_sheet_without_its_sidecar_is_cut_on_the_built_in_grid() -> void:
	var keys: Array[String] = ["world_amulets", "world_magics", "world_map_tiles", "quest_clock"]
	var kept := {}
	for key in keys:
		kept[key] = GameSkin._meta_cache.get(key)
		GameSkin._meta_cache[key] = {}
	var art := WorldArt.new()
	assert_eq(art.frame_rect("world_amulets", 2), Rect2(24, 0, 12, 17), "the black amulet's stone")
	assert_eq(art.frame_rect("world_magics", 13), Rect2(52, 54, 52, 54), "the second row's second icon")
	assert_eq(art.frame_rect("world_map_tiles", 49), Rect2(13, 60, 13, 20), "the town icon")
	assert_eq(art.frame_rect("quest_clock", 7), Rect2(469, 0, 67, 88))
	for key in keys:
		if kept[key] == null:
			GameSkin._meta_cache.erase(key)
		else:
			GameSkin._meta_cache[key] = kept[key]


func test_a_sheet_of_no_known_grid_is_absent() -> void:
	var key := "world_c3_f5_unknown"
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	GameSkin._texture_cache[key] = ImageTexture.create_from_image(image)
	GameSkin._meta_cache[key] = {}
	assert_null(WorldArt.new().texture(key), "no sidecar, no built-in row: not cut into garbage")
	GameSkin._meta_cache[key] = {"frame_width": 16, "frame_height": 16, "cols": 4}
	assert_not_null(WorldArt.new().texture(key), "with its sidecar it is there")
	GameSkin._texture_cache.erase(key)
	GameSkin._meta_cache.erase(key)


# ------------------------------------------------- the amulets' colours --

func test_an_amulet_without_its_sheet_is_a_square_of_its_colour() -> void:
	assert_eq(WorldArt.AMULET_INKS.size(), AdventurePlayer.COLORS.size(), "black to white")
	var red := WorldArt.amulet_disc(3, 9.0)
	assert_eq(red.color, WorldArt.AMULET_INKS[3])
	assert_eq(red.size, Vector2(9, 9))
	assert_eq(red.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	red.free()


# ------------------------------------------------ the painted buttons --

func test_a_painted_button_s_cell_is_clipped_to_its_region() -> void:
	var sheet := ImageTexture.create_from_image(Image.create(640, 480, false, Image.FORMAT_RGBA8))
	var cut := WorldMap.cell(sheet, Rect2(1, 1, 93, 27))
	assert_eq(cut.region, Rect2(1, 1, 93, 27))
	assert_true(cut.filter_clip, "the magenta lines between the cells never bleed in")


# ----------------------------------------------- the dissolve's picture --

func test_the_old_picture_is_read_in_the_window_s_pixels() -> void:
	var host := Control.new()
	add_child_autofree(host)
	var canvas := host.get_viewport_rect().size
	# A 1920 × 1080 window's picture over whatever canvas this run has.
	var picture := ImageTexture.create_from_image(Image.create(1920, 1080, false, Image.FORMAT_RGB8))
	var cover := RevealDissolve.over(host, picture)
	var square := Rect2(160, 96, 16, 16)
	var pixels := Vector2(1920, 1080) / canvas
	assert_eq(cover.source_rect(square), Rect2(square.position * pixels, square.size * pixels))
	cover.before = ImageTexture.create_from_image(Image.create(int(canvas.x), int(canvas.y), false, Image.FORMAT_RGB8))
	assert_eq(cover.source_rect(square), square, "a picture the canvas's size: the same square")
