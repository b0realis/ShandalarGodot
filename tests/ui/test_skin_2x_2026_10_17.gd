extends GutTest
## THE 2x PICTURES (2026-10-17) — `<key>@2x.png` beside `<key>.png`, worn
## at the 1997 size with twice the pixels (GameSkin, THE 2x PICTURES).
##
## THE PROOF IS A DOUBLING. Each sheet below is written twice into a
## scratch skin folder: once as the 1997 file alone, once with a 2x copy
## that is that file with every pixel doubled. A cutter that is right at
## 2x must then hand back the SAME picture it cut at 1x — the same drawn
## size, twice the pixels, and at each doubled pixel the colour and the
## on/off it had at 1x — whatever it does to the pixels (a circle cut, a
## black or white key decided on the 1997 palette, an image+mask sprite, a
## mirrored border, a two-pixel rule). A cutter that cut the 2x picture at
## 1997 coordinates, or keyed an upscaler's blend, fails here. The
## fixtures are blocks of a few colours (black, white and greys among
## them, for the keys) in the sheets' own sizes, so no 1997 file is
## needed on the machine running the suite.
##
## Then what is NOT a doubling: a 2x copy that is not exactly twice the
## size is ignored, the `skin_2x` key switches the copies off, a copy's
## own pixels reach the screen (not a 1x picture blown up), the portrait
## chooser does not list a copy as a face, and a 2x zip is its own kind
## of pack that never takes the skin zip's place.

const SCRATCH := "user://skin_2x_test"
const SKIN := SCRATCH + "/skin"
const KEYS: Array[String] = [GamePaths.KEY_SKIN_FOLDER, GamePaths.KEY_SKIN_2X,
	GamePaths.KEY_USE_SKIN_FOLDER]

var _saved: Dictionary = {}
var _portrait_dirs: Array[String] = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SKIN.path_join("portraits"))
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SKIN)
	_portrait_dirs = PortraitLibrary.dirs
	_clear()


func after_each() -> void:
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	PortraitLibrary.dirs = _portrait_dirs
	for folder in [SKIN.path_join("portraits"), SKIN, SCRATCH]:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	_clear()


## Every cache a cutter keeps, so the next call reads the folder again.
func _clear() -> void:
	GameSkin.clear_caches()
	ManaIcons._atlas_cache.clear()
	MiniCard._badge_cache.clear()
	MiniCard._stripe_cache.clear()
	MiniCard._masked_cache.clear()
	MiniCard._pending_dagger = null
	CounterMarks._tile_cache.clear()
	SetBadges._symbol_cache.clear()
	FilterBar._cell_cache.clear()
	CardArea._plaque_cache.clear()
	CombatBar._keyed.clear()
	StackHand._window_cache.clear()
	TerritoryGround._edge_cache.clear()
	ExilePlate._cache.clear()
	PortraitLibrary.refresh()


# ------------------------------------------------------------- fixtures --

const PALETTE: Array[Color] = [Color.BLACK, Color.WHITE, Color(0.18, 0.18, 0.18),
	Color(0.96, 0.95, 0.94), Color(0.62, 0.20, 0.18), Color(0.20, 0.35, 0.70),
	Color(0.30, 0.62, 0.28), Color(0.80, 0.70, 0.30)]


## A sheet of [param size] in blocks of [param block] pixels, each one of
## [param colours], picked by a fixed hash so every run draws the same.
static func _blocks(size: Vector2i, colours: Array[Color], block := 4, salt := 0) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var h := ((x / block) * 73856093) ^ ((y / block) * 19349663) ^ (salt * 83492791)
			img.set_pixel(x, y, colours[absi(h) % colours.size()])
	return img


func _write(key: String, img: Image) -> void:
	img.save_png(ProjectSettings.globalize_path(SKIN.path_join(key + ".png")))


## The 2x copy: [param key]'s file with every pixel doubled — or, with
## [param mark], a copy whose odd pixels are tinted, so a test can tell
## the copy's own pixels from a 1x picture blown up. [param blend]
## "black" or "white" moves that colour off its exact 1997 value the way
## an upscaler does (black to 0.12, near-white to 0.90): a key decided
## on the copy then misses, one decided on the 1997 file does not.
func _write_twice(key: String, mark := false, blend := "") -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SKIN.path_join(key + ".png")))
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	if blend != "":
		for y in img.get_height():
			for x in img.get_width():
				var px := img.get_pixel(x, y)
				if blend == "black" and px.r < 0.01 and px.g < 0.01 and px.b < 0.01:
					img.set_pixel(x, y, Color(0.12, 0.12, 0.12, px.a))
				elif blend == "white" and px.r >= 0.93 and px.g >= 0.93 and px.b >= 0.93:
					img.set_pixel(x, y, Color(0.90, 0.90, 0.90, px.a))
	if mark:
		for y in range(1, img.get_height(), 2):
			for x in range(1, img.get_width(), 2):
				var px := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(px.r, minf(1.0, px.g + 0.25), px.b, px.a))
	img.save_png(ProjectSettings.globalize_path(SKIN.path_join(key + "@2x.png")))


## [param cutter] run on [param key] as the 1997 file alone, then with its
## doubled 2x copy beside it: `[1x result, 2x result]`.
func _both(key: String, img: Image, cutter: Callable, blend := "") -> Array:
	_write(key, img)
	_clear()
	var one = cutter.call()
	_write_twice(key, false, blend)
	_clear()
	var two = cutter.call()
	return [one, two]


## The 2x result is the 1x one doubled: same drawn size, twice the pixels,
## and at each doubled pixel the 1x pixel's on/off and colour — all but a
## few pixels at the edges a key's carried-up line rounds off.
func _assert_doubled(pair: Array, what: String, limit := 0.06) -> void:
	var one: Texture2D = pair[0]
	var two: Texture2D = pair[1]
	assert_not_null(one, what + ": cut from the 1997 file")
	assert_not_null(two, what + ": cut with the 2x copy beside it")
	if one == null or two == null:
		return
	assert_eq(two.get_size(), one.get_size(), what + ": drawn at the 1997 size")
	assert_eq(GameSkin.scale_of(two), 2, what + ": and known to be a 2x picture")
	var a := one.get_image()
	var b := two.get_image()
	assert_eq(b.get_size(), a.get_size() * 2, what + ": with twice the pixels")
	if b.get_size() != a.get_size() * 2:
		return
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var off := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(2 * x, 2 * y)
			if absf(p.a - q.a) > 0.5 or (p.a > 0.5 and q.a > 0.5
					and absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.1):
				off += 1
	var share := float(off) / float(a.get_width() * a.get_height())
	assert_lt(share, limit, "%s: %.1f%% of the pixels differ from the 1x cut"
		% [what, share * 100.0])


# ------------------------------------------------------- the loader --

func test_a_2x_copy_is_worn_at_the_1997_size() -> void:
	_write("title_background", _blocks(Vector2i(20, 12), PALETTE))
	_write_twice("title_background")
	var tex := GameSkin.texture("title_background")
	assert_eq(tex.get_size(), Vector2(20, 12), "drawn at the 1997 size")
	assert_eq(tex.get_image().get_size(), Vector2i(40, 24), "holding the copy's pixels")
	assert_eq(GameSkin.scale_of(tex), 2)
	assert_eq(GameSkin.original(tex).get_size(), Vector2i(20, 12),
		"and the 1997 pixels are still to hand")


func test_no_copy_no_change() -> void:
	_write("title_background", _blocks(Vector2i(20, 12), PALETTE))
	var tex := GameSkin.texture("title_background")
	assert_eq(tex.get_image().get_size(), Vector2i(20, 12))
	assert_eq(GameSkin.scale_of(tex), 1)


func test_a_copy_of_the_wrong_size_is_not_worn() -> void:
	_write("title_background", _blocks(Vector2i(20, 12), PALETTE))
	_blocks(Vector2i(41, 24), PALETTE).save_png(
		ProjectSettings.globalize_path(SKIN.path_join("title_background@2x.png")))
	var tex := GameSkin.texture("title_background")
	assert_eq(GameSkin.scale_of(tex), 1, "a copy of another picture is not this one's")
	assert_eq(tex.get_image().get_size(), Vector2i(20, 12))


func test_the_key_switches_the_copies_off_and_on() -> void:
	_write("title_background", _blocks(Vector2i(20, 12), PALETTE))
	_write_twice("title_background")
	assert_true(GamePaths.use_skin_2x(), "on by default")
	GamePaths.set_use_skin_2x(false)
	assert_eq(Settings.get_value(GamePaths.KEY_SKIN_2X, null), false)
	_clear()
	assert_eq(GameSkin.scale_of(GameSkin.texture("title_background")), 1, "off: 1997 alone")
	GamePaths.set_use_skin_2x(true)
	assert_false(Settings.has_value(GamePaths.KEY_SKIN_2X), "on is the default, never written")
	_clear()
	assert_eq(GameSkin.scale_of(GameSkin.texture("title_background")), 2)
	for typed in ["no", "0", "off", "false"]:
		Settings.set_value(GamePaths.KEY_SKIN_2X, typed)
		assert_false(GamePaths.use_skin_2x(), "a hand-typed %s is meant" % typed)


func test_the_copys_own_pixels_reach_the_screen() -> void:
	# A tinted copy: its odd pixels are greener than the 1997 file's. A cut
	# that blew up a 1x picture would have none of that green.
	_write("phase_bar", _blocks(Vector2i(82, 40), PALETTE))
	_write_twice("phase_bar", true)
	var piece := GameSkin.region("phase_bar", Rect2i(10, 8, 20, 12))
	assert_eq(piece.get_size(), Vector2(20, 12))
	var img := piece.get_image()
	var plain := img.get_pixel(0, 0)
	var tinted := img.get_pixel(1, 1)
	assert_almost_eq(tinted.g, minf(1.0, plain.g + 0.25), 0.02, "the copy's own pixel")


func test_the_names() -> void:
	assert_eq(GameSkin.scaled_path("res://skin/title_background.png"),
		"res://skin/title_background@2x.png")
	assert_true(GameSkin.is_scaled_name("agnosia@2x.png"))
	assert_false(GameSkin.is_scaled_name("agnosia.png"))


# ---------------------------------------------------------- the cutters --

func test_the_generic_cutter() -> void:
	_assert_doubled(_both("phase_bar", _blocks(Vector2i(82, 60), PALETTE),
		func() -> Texture2D: return GameSkin.region("phase_bar", Rect2i(41, 4, 30, 20))),
		"GameSkin.region")


func test_mana_symbols_are_cut_to_their_circle() -> void:
	_assert_doubled(_both("mana_symbols", _blocks(Vector2i(342, 18), PALETTE, 3),
		func() -> Texture2D: return ManaIcons.symbol("W")), "ManaIcons.symbol", 0.08)


func test_ability_badges_are_cut_to_their_circle() -> void:
	_assert_doubled(_both("ability_icons", _blocks(Vector2i(22, 396), PALETTE, 3),
		func() -> Texture2D: return MiniCard.badge_from_slot(2)), "MiniCard.badge_from_slot", 0.08)


func test_mana_stripes_key_black_on_the_1997_palette() -> void:
	_assert_doubled(_both("mana_stripes", _blocks(Vector2i(54, 126), PALETTE, 3),
		func() -> Texture2D: return MiniCard.stripe_texture(Mtg.ManaColor.R), "black"),
		"MiniCard.stripe_texture")


func test_an_image_and_mask_sprite_reads_its_mask_at_1997_size() -> void:
	var sheet := _blocks(Vector2i(194, 97), PALETTE)
	# The right half is the mask: two-tone, its corner the clear tone.
	var mask := _blocks(Vector2i(97, 97), [Color.WHITE, Color.BLACK], 6, 5)
	mask.set_pixel(0, 0, Color.WHITE)
	sheet.blit_rect(mask, Rect2i(0, 0, 97, 97), Vector2i(97, 0))
	_assert_doubled(_both("summon_sick", sheet,
		func() -> Texture2D: return MiniCard.masked_sprite("summon_sick")),
		"MiniCard.masked_sprite")


func test_counter_stones_read_their_mask_row_at_1997_size() -> void:
	var sheet := _blocks(Vector2i(24, 750), PALETTE)
	var mask := _blocks(Vector2i(24, 30), [Color.WHITE, Color.BLACK], 4, 9)
	mask.set_pixel(0, 0, Color.WHITE)
	sheet.blit_rect(mask, Rect2i(0, 0, 24, 30), Vector2i(0, CounterMarks.MASK_ROW * 30))
	_assert_doubled(_both("card_counters", sheet,
		func() -> Texture2D: return CounterMarks.tile(3)), "CounterMarks.tile")


func test_set_symbols_key_pure_black_on_the_1997_strip() -> void:
	var strip := Image.create_empty(330, 15, false, Image.FORMAT_RGBA8)
	strip.fill(Color.BLACK)
	var glyph := _blocks(Vector2i(20, 11), [Color(0.11, 0.11, 0.11), Color(0.9, 0.85, 0.7)], 2)
	strip.blit_rect(glyph, Rect2i(0, 0, 20, 11), Vector2i(3 * SetBadges.SLOT_PITCH + 10, 2))
	_assert_doubled(_both(SetBadges.SHEET_KEY, strip,
		func() -> Texture2D: return SetBadges.symbol("atq"), "black"), "SetBadges.symbol")


func test_filter_cells_and_deck_plaques() -> void:
	_assert_doubled(_both("filter_icons", _blocks(Vector2i(360, 120), PALETTE),
		func() -> Texture2D: return FilterBar.sheet_cell("filter_icons", 1, 2)),
		"FilterBar.sheet_cell")
	_assert_doubled(_both("deck_slot_plaques", _blocks(Vector2i(585, 200), PALETTE),
		func() -> Texture2D: return CardArea._plaque(1)), "CardArea._plaque")


func test_the_combat_bar_keys_white_on_the_1997_palette() -> void:
	var sheet := _blocks(Vector2i(164, 760), PALETTE)
	var region := CombatBar.column_region(true)
	_assert_doubled(_both("combat_bar", sheet,
		func() -> Texture2D: return CombatBar.keyed_texture(region, CombatBar.Fill.BLACK), "white"),
		"CombatBar.keyed_texture black")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SKIN.path_join("combat_bar@2x.png")))
	_assert_doubled(_both("combat_bar", sheet,
		func() -> Texture2D: return CombatBar.keyed_texture(region, CombatBar.Fill.STONE)),
		"CombatBar.keyed_texture stone")   # its band is cut from the copy: no blend here


func test_the_hand_window_mirrors_its_border() -> void:
	_assert_doubled(_both("hand_panel_red", _blocks(Vector2i(145, 51), PALETTE),
		func() -> Texture2D: return StackHand.window_texture("red")), "StackHand.window_texture")


func test_the_ruled_grounds_rule_two_drawn_pixels() -> void:
	_assert_doubled(_both("message_panel", _blocks(Vector2i(60, 35), PALETTE),
		func() -> Texture2D: return OriginalDialog.ruled_texture("message_panel")),
		"OriginalDialog.ruled_texture")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SKIN.path_join("message_panel@2x.png")))
	_assert_doubled(_both("message_panel", _blocks(Vector2i(60, 35), PALETTE),
		func() -> Texture2D: return OriginalDialog.bar_button_texture(true)),
		"OriginalDialog.bar_button_texture")


func test_measurements_read_the_1997_pixels() -> void:
	# A territory's 1px black conversion edge is measured, not assumed; a
	# copy's near-black is not 0 and must not hide it.
	var ground := _blocks(Vector2i(64, 40), PALETTE.slice(4))
	for x in 64:
		ground.set_pixel(x, 0, Color.BLACK)
		ground.set_pixel(x, 39, Color.BLACK)
	for y in 40:
		ground.set_pixel(0, y, Color.BLACK)
		ground.set_pixel(63, y, Color.BLACK)
	_write("duel_pattern_red", ground)
	var big := ground.duplicate() as Image
	big.resize(128, 80, Image.INTERPOLATE_BILINEAR)
	for x in 128:
		big.set_pixel(x, 0, Color(0.05, 0.05, 0.05))   # an upscaler's black
	big.save_png(ProjectSettings.globalize_path(SKIN.path_join("duel_pattern_red@2x.png")))
	_clear()
	var tex := GameSkin.texture("duel_pattern_red")
	assert_eq(GameSkin.scale_of(tex), 2)
	assert_eq(TerritoryGround._inner("duel_pattern_red", tex), Rect2i(1, 1, 62, 38),
		"the edge found on the 1997 file, in drawn pixels")


func test_the_exile_plate_is_painted_from_the_1997_palette() -> void:
	var pair := _both("grave_panel_red", _blocks(Vector2i(61, 91), PALETTE.slice(4), 3),
		func() -> Texture2D: return ExilePlate.plate("red"))
	assert_not_null(pair[0])
	assert_not_null(pair[1])
	if pair[0] != null and pair[1] != null:
		assert_eq((pair[1] as Texture2D).get_image().get_data(),
			(pair[0] as Texture2D).get_image().get_data(),
			"the same plate: its palette is counted on the 1997 colours")


# ------------------------------------------------------- the portraits --

func test_a_portraits_copy_is_not_a_face_of_its_own() -> void:
	PortraitLibrary.dirs = [SKIN.path_join("portraits")]
	var face := _blocks(Vector2i(14, 17), PALETTE)
	face.save_png(ProjectSettings.globalize_path(SKIN.path_join("portraits/agnosia.png")))
	var big := face.duplicate() as Image
	big.resize(28, 34, Image.INTERPOLATE_NEAREST)
	big.save_png(ProjectSettings.globalize_path(SKIN.path_join("portraits/agnosia@2x.png")))
	PortraitLibrary.refresh()
	var ids: Array = PortraitLibrary.all().map(func(e: Dictionary) -> String: return e["id"])
	assert_eq(ids, ["agnosia"], "one face, not two")
	var tex := PortraitLibrary.texture("agnosia")
	assert_eq(tex.get_size(), Vector2(14, 17), "worn at its size")
	assert_eq(GameSkin.scale_of(tex), 2, "with the copy's pixels")


# --------------------------------------------------------- the 2x zip --

func _zip(path: String, names: Array) -> void:
	var packer := ZIPPacker.new()
	assert(packer.open(path) == OK)
	for name in names:
		packer.start_file(name)
		packer.write_file(PackedByteArray([1, 2, 3]))
		packer.close_file()
	packer.close()


func test_a_2x_zip_is_its_own_kind() -> void:
	var path := SCRATCH.path_join("twice.zip")
	_zip(path, ["skin/title_background@2x.png", "skin/portraits/agnosia@2x.png",
		"skin/UPSCALE.txt"])
	var report := SkinPack.inspect(path)
	assert_true(report["ok"])
	assert_eq(report["kind"], "skin2x")
	assert_eq(report["files"], 2, "its pictures")
	DirAccess.remove_absolute(path)
	_zip(path, ["skin/title_background.png", "skin/title_background@2x.png"])
	assert_eq(SkinPack.inspect(path)["kind"], "skin",
		"a skin zip that carries copies of its own is still the skin")
	DirAccess.remove_absolute(path)


func test_a_2x_zip_dresses_nothing_alone_and_is_never_the_worn_skin() -> void:
	var pack := SkinPack
	pack._reports["probe_2x.zip"] = {"ok": true, "kind": "skin2x", "files": 168, "art": 0}
	assert_eq(pack._holds("probe_2x.zip", "skin"), 0)
	assert_eq(pack._holds("probe_2x.zip", "cardart"), 0)
	assert_eq(pack._holds("probe_2x.zip", "skin2x"), 168)
	pack._reports.erase("probe_2x.zip")
	assert_eq(SkinPack.home_for("skin2x", "original_skin.zip"),
		SkinPack.USER_DIR.path_join(SkinPack.SCALED_FILE_NAME),
		"never lands on the player's own skin zip")
	assert_eq(SkinPack.home_for("skin2x", "original_skin_realesrgan-anime_2x.zip"),
		SkinPack.USER_DIR.path_join("original_skin_realesrgan-anime_2x.zip"))
	var before = Settings.get_value(GamePaths.KEY_SKIN_ZIP, null)
	SkinPack._wear("skin2x", "user://skins/x_2x.zip")
	assert_eq(Settings.get_value(GamePaths.KEY_SKIN_ZIP, null), before, "the skin_zip key untouched")


func test_the_options_line_says_what_was_found() -> void:
	assert_string_contains(SkinPack.status_line("skin2x",
		{"source": "none", "name": "", "files": 0}), "upscale_skin.py")
	assert_eq(SkinPack.status_line("skin2x",
		{"source": "shipped", "name": "skin/original_skin_realesrgan-anime_2x.zip", "files": 168}),
		"2x pictures: skin/original_skin_realesrgan-anime_2x.zip — 168 pictures, beside the game")
	assert_eq(SkinPack.status_line("skin2x",
		{"source": "folder", "name": "~/skin", "files": 1}),
		"2x pictures: a loose folder, ~/skin — 1 picture")
	_write("title_background", _blocks(Vector2i(8, 8), PALETTE))
	_write_twice("title_background")
	assert_eq(SkinPack.scaled_at(SKIN), 1)


func test_options_shows_the_2x_pictures_and_the_switch() -> void:
	_write("title_background", _blocks(Vector2i(8, 8), PALETTE))
	_write_twice("title_background")
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var status := screen.find_child("SkinStatus_skin2x", true, false) as Label
	assert_not_null(status, "the 2x row")
	if status != null:
		assert_string_starts_with(status.text, "2x pictures:")
	var wear := screen.find_child("UseSkin2x", true, false) as CheckButton
	assert_not_null(wear, "the switch")
	if wear != null:
		assert_true(wear.button_pressed, "on by default")
		wear.button_pressed = false
		assert_false(GamePaths.use_skin_2x(), "off writes the key")
		wear.button_pressed = true
		assert_true(GamePaths.use_skin_2x())
		assert_false(Settings.has_value(GamePaths.KEY_SKIN_2X), "on clears it again")
