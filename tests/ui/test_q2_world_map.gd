extends GutTest
## THE MAP'S ORNAMENT (the quick world package, 2026-10-27, H2): 1997's
## `g_map_summary_panel_sprite` — not a plaque with words but the silver
## scrollwork crowning the F2 map, cut from `Mapbttns.pic` at (45, 141),
## 209 × 28 and drawn at (220, 54) in every mode (mapScreen.c 477, 791–792)
## — and the sprites of that sheet cut as 1997's `EncodeSpriteFromPage` cut
## them, index 0 (pure black) clear: the ornament and the amulet panel.

var _kept := {}


func before_each() -> void:
	_kept = GameSkin._texture_cache.duplicate()
	WorldMap._sprites.clear()


func after_each() -> void:
	GameSkin._texture_cache = _kept
	WorldMap._sprites.clear()


func test_the_ornament_is_1997_s_cut_and_place() -> void:
	assert_eq(WorldMap.ORNAMENT, [Rect2(220, 54, 209, 28), Rect2(45, 141, 209, 28)] as Array[Rect2])
	assert_eq(WorldMap.AMULET_PANEL, [Rect2(0, 133, 43, 233), Rect2(1, 141, 43, 233)] as Array[Rect2])


## A sheet of [param scale] times 640 × 480: grey, pure black in the
## ornament's top-left corner and a near black beside it.
func _sheet(scale: int) -> Texture2D:
	var image := Image.create(640 * scale, 480 * scale, false, Image.FORMAT_RGB8)
	image.fill(Color8(120, 120, 128))
	image.fill_rect(Rect2i(45 * scale, 141 * scale, 10 * scale, 5 * scale), Color8(0, 0, 0))
	image.fill_rect(Rect2i(55 * scale, 141 * scale, 2 * scale, 5 * scale), Color8(15, 11, 11))
	return GameSkin.texture_of(image, Vector2i(640, 480))


func test_a_sprite_is_cut_with_its_pure_black_clear() -> void:
	var cut := WorldMap.sprite(_sheet(1), WorldMap.ORNAMENT[1])
	assert_eq(Vector2i(cut.get_size()), Vector2i(209, 28))
	var image := cut.get_image()
	assert_eq(image.get_pixel(0, 0).a, 0.0, "index 0, pure black: clear")
	assert_eq(image.get_pixel(10, 0).a, 1.0, "a near black stays")
	assert_eq(image.get_pixel(100, 20).a, 1.0, "the silver stays")
	assert_true(WorldMap.sprite(_sheet(1), WorldMap.ORNAMENT[1]) != cut, "another sheet, another cut")


func test_a_2x_sheet_is_keyed_on_its_1997_pixels() -> void:
	var sheet := _sheet(2)
	var cut := WorldMap.sprite(sheet, WorldMap.ORNAMENT[1])
	assert_eq(Vector2i(cut.get_size()), Vector2i(209, 28), "drawn at the 1997 size")
	var image := cut.get_image()
	assert_eq(image.get_size(), Vector2i(418, 56), "with all its pixels")
	assert_eq(image.get_pixel(1, 1).a, 0.0, "black clear")
	assert_eq(image.get_pixel(21, 1).a, 1.0)
	assert_same(WorldMap.sprite(sheet, WorldMap.ORNAMENT[1]), cut, "cut once")


func test_the_map_draws_with_and_without_the_sheet() -> void:
	var player := AdventurePlayer.new()
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	player.world = world
	for sheet in [null, _sheet(1)]:
		GameSkin._texture_cache["map_buttons"] = sheet
		var map := WorldMap.new()
		map.world = world
		map.player = player
		map.size = Vector2(1280, 800)
		add_child_autofree(map)
		for mode in [WorldMap.Mode.MAIN, WorldMap.Mode.JOURNAL]:
			map.show_mode(mode)
			await get_tree().process_frame
		assert_eq(WorldMap._sprites.size(), 0 if sheet == null else 2, "the ornament and the panel cut")
