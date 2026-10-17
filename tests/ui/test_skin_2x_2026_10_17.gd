extends GutTest
## THE 2x PICTURES AND THE CATALOGUE (2026-10-17) — a skin's
## `catalogue.txt` says which of its files the game wears in each place,
## and a picture at 2x, 3x or 4x its slot's size is worn at the slot's
## size with all its pixels (GameSkin, THE CATALOGUE, THE 2x PICTURES).
##
## THE PROOF IS A DOUBLING. Each sheet below is written into a scratch
## skin folder as its 1x file, the cutter run; then a copy with every pixel
## doubled is written beside it as `<key>@2x.png` and listed, the way
## tools/upscale_skin.py lays out the 2x skin, and the cutter run again. A cutter that is right at 2x must hand back
## the SAME picture it cut at 1x — the same drawn size, twice the pixels,
## and at each doubled pixel the colour and the on/off it had at 1x —
## whatever it does to the pixels (a circle cut, a black or white key, an
## image+mask sprite, a mirrored border, a two-pixel rule). A cutter that
## cut the 2x picture at 1997 coordinates fails here. With the 1x file
## still in the skin (the way the 2x skin keeps it) the keys are decided
## on it: an upscaler's off-palette copy ([param blend]) must not move
## them. With the 2x picture ALONE ([method _alone], fixtures at the 1997
## size, so the slot's size is [constant GameSkin.SIZES]'s) they are
## decided on the picture shrunk back. The fixtures are blocks of a few
## colours (black, white and greys among them, for the keys), so no 1997
## file is needed on the machine running the suite.
##
## Then what the catalogue itself promises: a file it does not name is
## not worn, but 0.50.28's `<key>@2x.png` needs no line; a slot may wear
## any file; a line naming a missing file falls back to the slot's own;
## the rules of a line; any other size worn as it is; 3x and 4x; a
## stale `skin_2x` key from 0.50.29 changes nothing; one skin is worn, a
## zip of 2x pictures is a skin like any other, a skin that replaces
## another arrives after a restart, and Options has no 2x switch.

const SCRATCH := "user://skin_2x_test"
const SKIN := SCRATCH + "/skin"
const KEYS: Array[String] = [GamePaths.KEY_SKIN_FOLDER, GamePaths.KEY_USE_SKIN_FOLDER,
	"skin_2x"]

var _saved: Dictionary = {}
var _portrait_dirs: Array[String] = []
var _was_worn := false


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SKIN.path_join("portraits"))
	DirAccess.make_dir_recursive_absolute(SKIN.path_join("2x/portraits"))
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SKIN)
	_portrait_dirs = PortraitLibrary.dirs
	_was_worn = GameSkin.zip_worn
	GameSkin.zip_worn = false
	_clear()


func after_each() -> void:
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	PortraitLibrary.dirs = _portrait_dirs
	GameSkin.zip_worn = _was_worn
	_wipe(SCRATCH)
	_clear()


static func _wipe(folder: String) -> void:
	for sub in DirAccess.get_directories_at(folder):
		_wipe(folder.path_join(sub))
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)


## A fresh skin folder, for a test that runs a second fixture.
func _fresh() -> void:
	_wipe(SKIN)
	DirAccess.make_dir_recursive_absolute(SKIN.path_join("2x/portraits"))


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


static func _at(name: String) -> String:
	return ProjectSettings.globalize_path(SKIN.path_join(name))


func _write(key: String, img: Image) -> void:
	img.save_png(_at(key + ".png"))


## One catalogue line, added to the skin's catalogue.
func _list(slot: String, file: String) -> void:
	var text := FileAccess.get_file_as_string(_at(GameSkin.CATALOGUE)) \
		if FileAccess.file_exists(_at(GameSkin.CATALOGUE)) else ""
	var out := FileAccess.open(_at(GameSkin.CATALOGUE), FileAccess.WRITE)
	out.store_string(text + "%s = %s\n" % [slot, file])
	out.close()


## The 2x picture: [param key]'s file with every pixel doubled, written
## beside it as `<key>@2x.png` and listed — or, with [param mark], a copy whose odd
## pixels are tinted, so a test can tell the picture's own pixels from a
## 1x picture blown up. [param blend] "black" or "white" moves that colour
## off its exact 1997 value the way an upscaler does (black to 0.12,
## near-white to 0.90): a key decided on the copy then misses, one decided
## on the 1x file does not.
func _write_twice(key: String, mark := false, blend := "") -> void:
	var img := Image.load_from_file(_at(key + ".png"))
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
	img.save_png(_at(key + "@2x.png"))
	_list(key + ".png", key + "@2x.png")


## [param cutter] run on [param key] as the 1x file alone, then with its
## doubled 2x picture listed beside it: `[1x result, 2x result]`.
func _both(key: String, img: Image, cutter: Callable, blend := "") -> Array:
	_write(key, img)
	_clear()
	var one = cutter.call()
	_write_twice(key, false, blend)
	_clear()
	var two = cutter.call()
	return [one, two]


## The same with the 2x picture ALONE: its 1x file gone, so the slot's
## size is the 1997 one and every key is decided on the picture shrunk
## back. [param img] must be the 1997 size.
func _alone(key: String, img: Image, cutter: Callable) -> Array:
	assert_eq(img.get_size(), GameSkin.SIZES[key], key + ": the fixture is the 1997 size")
	_write(key, img)
	_clear()
	var one = cutter.call()
	_write_twice(key)
	DirAccess.remove_absolute(_at(key + ".png"))
	_clear()
	var two = cutter.call()
	return [one, two]


## The 2x result is the 1x one doubled: same drawn size, twice the pixels,
## and at each doubled pixel the 1x pixel's on/off and colour — all but a
## few pixels at the edges a key's carried-up line rounds off.
func _assert_doubled(pair: Array, what: String, limit := 0.06) -> void:
	var one: Texture2D = pair[0]
	var two: Texture2D = pair[1]
	assert_not_null(one, what + ": cut from the 1x file")
	assert_not_null(two, what + ": cut from the 2x picture")
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


# ------------------------------------------------------ the catalogue --

func test_a_line_is_slot_equals_file_and_nothing_else() -> void:
	var read := GameSkin.parse_catalogue("﻿# the 2x skin\n"
		+ "\n"
		+ "title_background.png = 2x/title_background.png\r\n"
		+ "   card_back.png=backs/moon.png   \n"
		+ "  # an indented comment = still a comment\n"
		+ "no equals sign here\n"
		+ " = 2x/nothing.png\n"
		+ "menu_background.png = \n"
		+ "panel_stone.png = ../outside.png\n"
		+ "panel_knot.png = 2x/../../outside.png\n"
		+ "panel_end_duel.png = /etc/passwd\n"
		+ "big_card_panel.png = 2x\\big_card_panel.png\n"
		+ "versus_splash.png = a=b.png\n"
		+ "card_back.png = backs/holly.png\n")
	assert_eq(read, {
		"title_background.png": "2x/title_background.png",
		"card_back.png": "backs/holly.png",
		"versus_splash.png": "a=b.png",
	}, "comments, blanks, half lines and files leaving the skin are not read; "
		+ "the first = splits; a slot named twice takes its last line")


func test_a_file_the_catalogue_does_not_name_is_not_worn() -> void:
	var small := _blocks(Vector2i(131, 36), PALETTE)
	_write("button_normal", small)
	var big := small.duplicate() as Image
	big.resize(262, 72, Image.INTERPOLATE_NEAREST)
	big.save_png(_at("2x/button_normal.png"))
	_clear()
	var tex := GameSkin.texture("button_normal")
	assert_eq(GameSkin.scale_of(tex), 1, "a 2x/ file no line names is not worn")
	assert_eq(tex.get_image().get_size(), Vector2i(131, 36))


func test_the_old_at_2x_name_needs_no_line() -> void:
	# 0.50.28's layout: `<key>@2x.png` beside `<key>.png`, no catalogue.
	_write("button_normal", _blocks(Vector2i(131, 36), PALETTE))
	_write_twice("button_normal")
	DirAccess.remove_absolute(_at(GameSkin.CATALOGUE))
	_clear()
	var tex := GameSkin.texture("button_normal")
	assert_eq(GameSkin.scale_of(tex), 2, "worn at the slot's size")
	assert_eq(tex.get_image().get_size(), Vector2i(262, 72))
	_list("button_normal.png", "button_normal.png")
	_clear()
	assert_eq(GameSkin.scale_of(GameSkin.texture("button_normal")), 1,
		"a line naming the 1x file picks it over the @2x one")


func test_the_0_50_28_zip_alone_is_worn_at_its_sizes() -> void:
	# The 2x pictures and nothing else: no 1x file, no catalogue.
	_write("button_normal", _blocks(Vector2i(131, 36), PALETTE))
	_write_twice("button_normal")
	DirAccess.remove_absolute(_at("button_normal.png"))
	DirAccess.remove_absolute(_at(GameSkin.CATALOGUE))
	_clear()
	var tex := GameSkin.texture("button_normal")
	assert_eq(GameSkin.scale_of(tex), 2, "the 1997 size from GameSkin.SIZES")
	assert_eq(tex.get_size(), Vector2(131, 36))


func test_mix_and_match_is_a_line() -> void:
	_write("button_normal", _blocks(Vector2i(131, 36), PALETTE))
	_write("button_pressed", _blocks(Vector2i(131, 36), PALETTE, 4, 1))
	_write_twice("button_normal")
	_write_twice("button_pressed")
	_clear()
	assert_eq(GameSkin.scale_of(GameSkin.texture("button_normal")), 2)
	assert_eq(GameSkin.scale_of(GameSkin.texture("button_pressed")), 2)
	# Back to the 1997 picture for one place: its line points at it.
	_list("button_pressed.png", "button_pressed.png")
	_clear()
	assert_eq(GameSkin.scale_of(GameSkin.texture("button_normal")), 2, "the other place keeps its 2x")
	assert_eq(GameSkin.scale_of(GameSkin.texture("button_pressed")), 1, "this one wears the 1997 file")


func test_any_file_may_stand_in_a_slot() -> void:
	DirAccess.make_dir_recursive_absolute(_at("backs"))
	var moon := _blocks(Vector2i(228, 323), PALETTE)
	moon.save_png(_at("backs/moon.png"))
	_list("card_back.png", "backs/moon.png")
	_clear()
	var tex := GameSkin.texture("card_back")
	assert_not_null(tex, "the slot wears the file its line names")
	if tex != null:
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		assert_eq(img.get_data(), moon.get_data())


func test_a_line_naming_a_missing_file_falls_back_to_the_slot() -> void:
	_write("button_normal", _blocks(Vector2i(131, 36), PALETTE))
	_list("button_normal.png", "2x/not_there.png")
	_clear()
	var tex := GameSkin.texture("button_normal")
	assert_not_null(tex, "the slot's own file")
	assert_eq(GameSkin.scale_of(tex), 1)


func test_the_catalogue_reaches_every_file_the_game_looks_for() -> void:
	DirAccess.make_dir_recursive_absolute(_at("sheets"))
	var out := FileAccess.open(_at("sheets/heads.json"), FileAccess.WRITE)
	out.store_string('{"cols": 7}')
	out.close()
	_list("coin_toss_heads.json", "sheets/heads.json")
	_clear()
	assert_eq(GameSkin.metadata("coin_toss_heads"), {"cols": 7.0}, "a sidecar, not only a picture")


# ------------------------------------------------------------ the sizes --

func test_a_2x_picture_is_worn_at_its_slots_size() -> void:
	_write("button_normal", _blocks(Vector2i(131, 36), PALETTE))
	_write_twice("button_normal")
	DirAccess.remove_absolute(_at("button_normal.png"))
	_clear()
	var tex := GameSkin.texture("button_normal")
	assert_eq(tex.get_size(), Vector2(131, 36), "drawn at the 1997 size")
	assert_eq(tex.get_image().get_size(), Vector2i(262, 72), "holding the picture's pixels")
	assert_eq(GameSkin.scale_of(tex), 2)
	assert_eq(GameSkin.original(tex).get_size(), Vector2i(131, 36),
		"and its pixels at the drawn size are to hand, shrunk back")


func test_a_2x_picture_under_its_own_name_is_worn_at_its_slots_size() -> void:
	# The hi-res skin's own shape (0.50.31): the 1997 names, twice the size,
	# no 1x file and no catalogue.
	var small := _blocks(Vector2i(131, 36), PALETTE)
	var big := small.duplicate() as Image
	big.resize(262, 72, Image.INTERPOLATE_NEAREST)
	big.save_png(_at("button_normal.png"))
	_clear()
	var tex := GameSkin.texture("button_normal")
	assert_eq(GameSkin.scale_of(tex), 2)
	assert_eq(tex.get_size(), Vector2(131, 36), "drawn at the 1997 size")
	var img := GameSkin.original(tex)
	img.convert(Image.FORMAT_RGBA8)
	assert_eq(img.get_data(), small.get_data(),
		"shrunk back, a block averaging to its 1997 pixel gives that pixel")


func test_the_slots_own_1x_file_is_the_original() -> void:
	var small := _blocks(Vector2i(131, 36), PALETTE)
	_write("button_normal", small)
	_write_twice("button_normal", true)
	_clear()
	var tex := GameSkin.texture("button_normal")
	assert_eq(GameSkin.scale_of(tex), 2)
	var img := GameSkin.original(tex)
	img.convert(Image.FORMAT_RGBA8)
	assert_eq(img.get_data(), small.get_data(),
		"the 1x file itself, not the tinted picture shrunk")


func test_3x_and_4x_are_worn_too() -> void:
	for scale in [3, 4]:
		var big := _blocks(Vector2i(131, 36) * scale, PALETTE, 4 * scale)
		big.save_png(_at("2x/button_normal.png"))
		_list("button_normal.png", "2x/button_normal.png")
		_clear()
		var tex := GameSkin.texture("button_normal")
		assert_eq(GameSkin.scale_of(tex), scale, "%dx" % scale)
		assert_eq(tex.get_size(), Vector2(131, 36))
		assert_eq(GameSkin.original(tex).get_size(), Vector2i(131, 36))


func test_any_other_size_is_worn_at_its_own_size() -> void:
	_blocks(Vector2i(200, 50), PALETTE).save_png(_at("2x/button_normal.png"))
	_list("button_normal.png", "2x/button_normal.png")
	_clear()
	var tex := GameSkin.texture("button_normal")
	assert_eq(GameSkin.scale_of(tex), 1)
	assert_eq(tex.get_size(), Vector2(200, 50), "as every picture was worn before")
	assert_eq(GameSkin.scale_for(Vector2i(262, 72), Vector2i(131, 36)), 2)
	assert_eq(GameSkin.scale_for(Vector2i(655, 180), Vector2i(131, 36)), 1, "5x is past the limit")
	assert_eq(GameSkin.scale_for(Vector2i(262, 73), Vector2i(131, 36)), 1)
	assert_eq(GameSkin.scale_for(Vector2i(262, 72), Vector2i.ZERO), 1)


func test_a_slot_whose_1x_file_is_another_size_takes_its_size_from_it() -> void:
	# The fixture is not the 1997 size: the 1x file beside it says what 1x is.
	_write("title_background", _blocks(Vector2i(20, 12), PALETTE))
	_write_twice("title_background")
	_clear()
	var tex := GameSkin.texture("title_background")
	assert_eq(GameSkin.scale_of(tex), 2)
	assert_eq(tex.get_size(), Vector2(20, 12))


func test_the_pictures_own_pixels_reach_the_screen() -> void:
	# A tinted picture: its odd pixels are greener than the 1x file's. A
	# cut that blew up a 1x picture would have none of that green.
	_write("phase_bar", _blocks(Vector2i(82, 40), PALETTE))
	_write_twice("phase_bar", true)
	var piece := GameSkin.region("phase_bar", Rect2i(10, 8, 20, 12))
	assert_eq(piece.get_size(), Vector2(20, 12))
	var img := piece.get_image()
	var plain := img.get_pixel(0, 0)
	var tinted := img.get_pixel(1, 1)
	assert_almost_eq(tinted.g, minf(1.0, plain.g + 0.25), 0.02, "the picture's own pixel")


func test_no_switch_a_stale_skin_2x_key_changes_nothing() -> void:
	# 0.50.29's `skin_2x = false` in a player's settings.cfg: read by nothing.
	Settings.set_value("skin_2x", false)
	_write("button_normal", _blocks(Vector2i(131, 36), PALETTE))
	_write_twice("button_normal")
	_clear()
	assert_eq(GameSkin.scale_of(GameSkin.texture("button_normal")), 2)
	var methods: Array = (load("res://game/paths.gd") as Script).get_script_method_list() \
		.map(func(m: Dictionary) -> String: return m["name"])
	assert_false(methods.has("use_skin_2x"), "no switch left to read")


func test_the_sizes_are_the_1997_ones() -> void:
	assert_eq(GameSkin.SIZES["title_background"], Vector2i(640, 480))
	assert_eq(GameSkin.SIZES["mana_symbols"], Vector2i(342, 18))
	assert_false(GameSkin.SIZES.has("coin_toss_heads"), "a movie sheet's .json describes it")


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


func test_mana_stripes_key_black_on_the_1x_palette() -> void:
	_assert_doubled(_both("mana_stripes", _blocks(Vector2i(54, 126), PALETTE, 3),
		func() -> Texture2D: return MiniCard.stripe_texture(Mtg.ManaColor.R), "black"),
		"MiniCard.stripe_texture")


func test_mana_stripes_alone() -> void:
	_assert_doubled(_alone("mana_stripes", _blocks(Vector2i(54, 126), PALETTE, 3),
		func() -> Texture2D: return MiniCard.stripe_texture(Mtg.ManaColor.R)),
		"MiniCard.stripe_texture, 2x alone")


func _summon_sheet() -> Image:
	var sheet := _blocks(Vector2i(194, 97), PALETTE)
	# The right half is the mask: two-tone, its corner the clear tone.
	var mask := _blocks(Vector2i(97, 97), [Color.WHITE, Color.BLACK], 6, 5)
	mask.set_pixel(0, 0, Color.WHITE)
	sheet.blit_rect(mask, Rect2i(0, 0, 97, 97), Vector2i(97, 0))
	return sheet


func test_an_image_and_mask_sprite_reads_its_mask_at_the_drawn_size() -> void:
	_assert_doubled(_both("summon_sick", _summon_sheet(),
		func() -> Texture2D: return MiniCard.masked_sprite("summon_sick")),
		"MiniCard.masked_sprite")
	_fresh()
	_assert_doubled(_alone("summon_sick", _summon_sheet(),
		func() -> Texture2D: return MiniCard.masked_sprite("summon_sick")),
		"MiniCard.masked_sprite, 2x alone")


func _counter_sheet() -> Image:
	var sheet := _blocks(Vector2i(24, 750), PALETTE)
	var mask := _blocks(Vector2i(24, 30), [Color.WHITE, Color.BLACK], 4, 9)
	mask.set_pixel(0, 0, Color.WHITE)
	sheet.blit_rect(mask, Rect2i(0, 0, 24, 30), Vector2i(0, CounterMarks.MASK_ROW * 30))
	return sheet


func test_counter_stones_read_their_mask_row_at_the_drawn_size() -> void:
	_assert_doubled(_both("card_counters", _counter_sheet(),
		func() -> Texture2D: return CounterMarks.tile(3)), "CounterMarks.tile")
	_fresh()
	_assert_doubled(_alone("card_counters", _counter_sheet(),
		func() -> Texture2D: return CounterMarks.tile(3)), "CounterMarks.tile, 2x alone")


func _set_strip() -> Image:
	var strip := Image.create_empty(330, 15, false, Image.FORMAT_RGBA8)
	strip.fill(Color.BLACK)
	var glyph := _blocks(Vector2i(20, 11), [Color(0.11, 0.11, 0.11), Color(0.9, 0.85, 0.7)], 2)
	strip.blit_rect(glyph, Rect2i(0, 0, 20, 11), Vector2i(3 * SetBadges.SLOT_PITCH + 10, 2))
	return strip


func test_set_symbols_key_pure_black_on_the_1x_strip() -> void:
	_assert_doubled(_both(SetBadges.SHEET_KEY, _set_strip(),
		func() -> Texture2D: return SetBadges.symbol("atq"), "black"), "SetBadges.symbol")
	_fresh()
	_assert_doubled(_alone(SetBadges.SHEET_KEY, _set_strip(),
		func() -> Texture2D: return SetBadges.symbol("atq")), "SetBadges.symbol, 2x alone")


func test_filter_cells_and_deck_plaques() -> void:
	_assert_doubled(_both("filter_icons", _blocks(Vector2i(360, 120), PALETTE),
		func() -> Texture2D: return FilterBar.sheet_cell("filter_icons", 1, 2)),
		"FilterBar.sheet_cell")
	_assert_doubled(_both("deck_slot_plaques", _blocks(Vector2i(585, 200), PALETTE),
		func() -> Texture2D: return CardArea._plaque(1)), "CardArea._plaque")


func test_the_combat_bar_keys_white_on_the_1x_palette() -> void:
	var sheet := _blocks(Vector2i(164, 760), PALETTE)
	var region := CombatBar.column_region(true)
	_assert_doubled(_both("combat_bar", sheet,
		func() -> Texture2D: return CombatBar.keyed_texture(region, CombatBar.Fill.BLACK), "white"),
		"CombatBar.keyed_texture black")
	_fresh()
	_assert_doubled(_both("combat_bar", sheet,
		func() -> Texture2D: return CombatBar.keyed_texture(region, CombatBar.Fill.STONE)),
		"CombatBar.keyed_texture stone")   # its band is cut from the picture: no blend here
	_fresh()
	_assert_doubled(_alone("combat_bar", sheet,
		func() -> Texture2D: return CombatBar.keyed_texture(region, CombatBar.Fill.BLACK)),
		"CombatBar.keyed_texture black, 2x alone")


func test_the_hand_window_mirrors_its_border() -> void:
	_assert_doubled(_both("hand_panel_red", _blocks(Vector2i(145, 51), PALETTE),
		func() -> Texture2D: return StackHand.window_texture("red")), "StackHand.window_texture")


func test_the_ruled_grounds_rule_two_drawn_pixels() -> void:
	_assert_doubled(_both("message_panel", _blocks(Vector2i(60, 35), PALETTE),
		func() -> Texture2D: return OriginalDialog.ruled_texture("message_panel")),
		"OriginalDialog.ruled_texture")
	_fresh()
	_assert_doubled(_both("message_panel", _blocks(Vector2i(60, 35), PALETTE),
		func() -> Texture2D: return OriginalDialog.bar_button_texture(true)),
		"OriginalDialog.bar_button_texture")


## A territory with its 1px black conversion edge, at [param size].
static func _ground(size: Vector2i) -> Image:
	var ground := _blocks(size, PALETTE.slice(4))
	for x in size.x:
		ground.set_pixel(x, 0, Color.BLACK)
		ground.set_pixel(x, size.y - 1, Color.BLACK)
	for y in size.y:
		ground.set_pixel(0, y, Color.BLACK)
		ground.set_pixel(size.x - 1, y, Color.BLACK)
	return ground


func test_measurements_read_the_1x_pixels() -> void:
	# A territory's 1px black conversion edge is measured, not assumed; an
	# upscaler's near-black is not 0 and must not hide it while the 1x file
	# is in the skin.
	var ground := _ground(Vector2i(64, 40))
	_write("duel_pattern_red", ground)
	var big := ground.duplicate() as Image
	big.resize(128, 80, Image.INTERPOLATE_BILINEAR)
	for x in 128:
		big.set_pixel(x, 0, Color(0.05, 0.05, 0.05))   # an upscaler's black
	big.save_png(_at("2x/duel_pattern_red.png"))
	_list("duel_pattern_red.png", "2x/duel_pattern_red.png")
	_clear()
	var tex := GameSkin.texture("duel_pattern_red")
	assert_eq(GameSkin.scale_of(tex), 2)
	assert_eq(TerritoryGround._inner("duel_pattern_red", tex), Rect2i(1, 1, 62, 38),
		"the edge found on the 1x file, in drawn pixels")


func test_measurements_on_a_2x_picture_alone() -> void:
	_write("duel_pattern_red", _ground(Vector2i(888, 381)))
	_write_twice("duel_pattern_red")
	DirAccess.remove_absolute(_at("duel_pattern_red.png"))
	_clear()
	var tex := GameSkin.texture("duel_pattern_red")
	assert_eq(GameSkin.scale_of(tex), 2)
	assert_eq(TerritoryGround._inner("duel_pattern_red", tex), Rect2i(1, 1, 886, 379),
		"a clean black edge is found on the picture shrunk back")


func test_the_exile_plate_is_painted_from_the_1x_palette() -> void:
	for alone in [false, true]:
		_fresh()
		var plate := _blocks(Vector2i(61, 91), PALETTE.slice(4), 3)
		var cutter := func() -> Texture2D: return ExilePlate.plate("red")
		var pair := _alone("grave_panel_red", plate, cutter) if alone \
			else _both("grave_panel_red", plate, cutter)
		assert_not_null(pair[0])
		assert_not_null(pair[1])
		if pair[0] != null and pair[1] != null:
			assert_eq((pair[1] as Texture2D).get_image().get_data(),
				(pair[0] as Texture2D).get_image().get_data(),
				"the same plate: its palette is counted at the drawn size (alone: %s)" % alone)


# ------------------------------------------------------- the portraits --

func test_an_at_2x_face_is_worn_at_its_1x_size_and_listed_once() -> void:
	PortraitLibrary.dirs = [SKIN.path_join("portraits")]
	var face := _blocks(Vector2i(14, 17), PALETTE)
	face.save_png(_at("portraits/agnosia.png"))
	var big := face.duplicate() as Image
	big.resize(28, 34, Image.INTERPOLATE_NEAREST)
	big.save_png(_at("portraits/agnosia@2x.png"))
	big.save_png(_at("portraits/goya@2x.png"))
	PortraitLibrary.refresh()
	_clear()
	var ids: Array = PortraitLibrary.all().map(func(e: Dictionary) -> String: return e["id"])
	assert_eq(ids, ["agnosia", "goya"], "one face each; a lone @2x face goes by its name")
	var tex := PortraitLibrary.texture("agnosia")
	assert_eq(tex.get_size(), Vector2(14, 17), "worn at its 1x size")
	assert_eq(GameSkin.scale_of(tex), 2, "with the @2x picture's pixels")
	assert_not_null(PortraitLibrary.texture("goya"))


func test_a_listed_face_is_worn_at_its_1x_size_and_listed_once() -> void:
	PortraitLibrary.dirs = [SKIN.path_join("portraits")]
	var face := _blocks(Vector2i(14, 17), PALETTE)
	face.save_png(_at("portraits/agnosia.png"))
	var big := face.duplicate() as Image
	big.resize(28, 34, Image.INTERPOLATE_NEAREST)
	big.save_png(_at("2x/portraits/agnosia.png"))
	_list("portraits/agnosia.png", "2x/portraits/agnosia.png")
	PortraitLibrary.refresh()
	_clear()
	var ids: Array = PortraitLibrary.all().map(func(e: Dictionary) -> String: return e["id"])
	assert_eq(ids, ["agnosia"], "one face, not two")
	var tex := PortraitLibrary.texture("agnosia")
	assert_eq(tex.get_size(), Vector2(14, 17), "worn at its size")
	assert_eq(GameSkin.scale_of(tex), 2, "with the 2x picture's pixels")


# ----------------------------------------------------------- one skin --

func test_a_worn_skin_zip_is_the_skin_alone() -> void:
	assert_has(GameSkin.search_dirs(), GamePaths.skin_folder(), "no zip worn: the folder dresses")
	_write("button_normal", _blocks(Vector2i(131, 36), PALETTE))
	assert_not_null(GameSkin.texture("button_normal"))
	GameSkin.zip_worn = true
	_clear()
	assert_does_not_have(GameSkin.search_dirs(), GamePaths.skin_folder(),
		"a skin zip worn: the folder is not read")
	assert_false(GameSkin._find("button_normal.png").begins_with(_at("")),
		"so a folder's 1997 picture never stands over the worn zip's own")


func _zip(path: String, names: Array) -> void:
	var packer := ZIPPacker.new()
	assert(packer.open(path) == OK)
	for name in names:
		packer.start_file(name)
		packer.write_file(PackedByteArray([1, 2, 3]))
		packer.close_file()
	packer.close()


func test_a_zip_of_2x_pictures_is_a_skin() -> void:
	var path := SCRATCH.path_join("twice.zip")
	_zip(path, ["skin/catalogue.txt", "skin/title_background.png",
		"skin/2x/title_background.png", "skin/UPSCALE.txt"])
	var report := SkinPack.inspect(path)
	assert_true(report["ok"])
	assert_eq(report["kind"], "skin", "the 2x skin is a skin")
	assert_eq(report["files"], 4)
	DirAccess.remove_absolute(path)
	_zip(path, ["skin/title_background@2x.png", "skin/UPSCALE.txt"])
	assert_eq(SkinPack.inspect(path)["kind"], "skin",
		"0.50.28's zip of copies is no kind of its own any more")
	DirAccess.remove_absolute(path)


func test_a_skin_that_replaces_the_worn_one_arrives_after_a_restart() -> void:
	assert_eq(SkinPack.plan_after_arrival(SkinPack.TITLE_SCENE), "reload",
		"the first skin, on the title screen: nothing to mix with")
	assert_eq(SkinPack.plan_after_arrival(SkinPack.TITLE_SCENE, true), "restart",
		"another skin worn already: the engine cannot unmount it")
	assert_eq(SkinPack.plan_after_arrival("res://game/duel/duel_screen.tscn", false), "restart")


func test_options_has_no_2x_switch() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_not_null(screen.find_child("SkinStatus_skin", true, false), "the skin row")
	assert_null(screen.find_child("UseSkin2x", true, false), "no switch")
	assert_null(screen.find_child("SkinStatus_skin2x", true, false), "no 2x row")
