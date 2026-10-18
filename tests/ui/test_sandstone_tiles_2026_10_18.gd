extends GutTest
## THE SEAMLESS GROUNDS (2026-10-18) — the owner's playtest of 0.50.32:
## *"Also check the background of options and magic battle! - it looks
## like a blur too much"*, and then of the dark stone, the knot and the
## end-of-duel rings, *"fix all the rest!"*. The 1997 window grounds were
## stretched over windows up to twice their size and squeezed into
## buttons and fields; each stone and pattern ground is now the seamless
## tile the game makes of it ([method OriginalDialog.ground]), laid at
## its own size. Only the two pictures stretch.
##
## The fixtures are drawn here, so no 1997 file is needed. A STONE: a
## grain that changes from pixel to pixel the way sandstone does (noise
## drawn small and smoothed up, so a column is like the next and unlike
## one far away), lit twenty levels darker at the left than at the right
## as the 1997 picture is, inside a three-pixel bevel. Raw, its edges do
## not meet and its tiles would band; the tile made of it must do
## neither, keep its grain — every pixel of the join from one stone or
## the other, never both but at the cut — and keep its bevel. A PATTERN:
## figures repeating exactly every few pixels, as the knot does; its tile
## must be whole repeats and every pixel of it the pattern's own.

const SCRATCH := "user://sandstone_tiles_test"
const SKIN := SCRATCH + "/skin"
const KEYS: Array[String] = [GamePaths.KEY_SKIN_FOLDER, GamePaths.KEY_USE_SKIN_FOLDER]

const LIGHT := Color8(238, 238, 210)
const MID := Color8(198, 190, 150)
const DARK := Color8(106, 106, 100)

var _saved: Dictionary = {}
var _was_worn := false


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SKIN)
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SKIN)
	_was_worn = GameSkin.zip_worn
	GameSkin.zip_worn = false
	GameSkin.clear_caches()


func after_each() -> void:
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	GameSkin.zip_worn = _was_worn
	for name in DirAccess.get_files_at(SKIN):
		DirAccess.remove_absolute(SKIN.path_join(name))
	DirAccess.remove_absolute(SKIN)
	DirAccess.remove_absolute(SCRATCH)
	GameSkin.clear_caches()


# ------------------------------------------------------------- fixtures --

## The 1997 stone's shape: 400x350 (or [param size]), a 3px bevel (two
## light rows and a mid one along top+left, two dark and a mid one along
## bottom+right), and inside it a smooth grain lit [param fall] levels
## brighter at the right than at the left.
static func _stone(fall := 20.0, size := Vector2i(400, 350)) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1997
	var grain := Image.create_empty(size.x / 4, size.y / 4, false, Image.FORMAT_RGBA8)
	for y in grain.get_height():
		for x in grain.get_width():
			var v := rng.randf_range(-0.12, 0.12)
			grain.set_pixel(x, y, Color(0.5 + v, 0.5 + v * 0.9, 0.5 + v * 0.7))
	grain.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var g := grain.get_pixel(x, y)
			var lit := (float(x) / (size.x - 1) - 0.5) * fall / 255.0
			img.set_pixel(x, y, Color(g.r + 0.27 + lit, g.g + 0.21 + lit, g.b + 0.08 + lit))
	_bevel(img)
	return img


## A pattern of [param size] repeating exactly every [param period]: a
## smooth figure (a ring round each repeat's middle) on a dark ground.
static func _pattern(size: Vector2i, period: Vector2i) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var at := Vector2(x % period.x, y % period.y) - Vector2(period) / 2.0
			var ring := clampf(1.0 - absf(at.length() - period.y * 0.3) / 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.15 + 0.5 * ring, 0.2 + 0.4 * ring,
				0.35 + 0.1 * ring + 0.002 * (x % period.x)))
	_bevel(img)
	return img


static func _bevel(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for i in w:
		for d in 3:
			img.set_pixel(i, d, MID if d == 2 else LIGHT)
			img.set_pixel(i, h - 1 - d, MID if d == 2 else DARK)
	for i in h:
		for d in 3:
			img.set_pixel(d, i, MID if d == 2 else LIGHT)
			img.set_pixel(w - 1 - d, i, MID if d == 2 else DARK)


## Mean |difference| of two columns of [param img] (0..255), over
## [param rows].
static func _columns_apart(img: Image, a: int, b: int, rows: Vector2i) -> float:
	var sum := 0.0
	for y in range(rows.x, rows.y):
		var p := img.get_pixel(a, y)
		var q := img.get_pixel(b, y)
		sum += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
	return sum * 255.0 / (3.0 * (rows.y - rows.x))


static func _lum(img: Image, rect: Rect2i) -> Array:
	var values: Array = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			values.append((c.r + c.g + c.b) * 255.0 / 3.0)
	return values


static func _mean(values: Array) -> float:
	var sum := 0.0
	for v in values:
		sum += v
	return sum / values.size()


static func _spread(values: Array) -> float:
	var m := _mean(values)
	var sum := 0.0
	for v in values:
		sum += (v - m) * (v - m)
	return sqrt(sum / values.size())


## The tile's own pixels inside [param out]: the ring is the bevel and one
## pixel of the tile's wrap.
static func _tile_rect(out: Image, scale := 1) -> Rect2i:
	var ring := (OriginalDialog.SEAMLESS_BEVEL + 1) * scale
	return Rect2i(Vector2i(ring, ring), out.get_size() - Vector2i(ring, ring) * 2)


# ---------------------------------------------------------------- the tile --

func test_the_tile_is_the_stone_a_band_smaller_inside_its_own_bevel() -> void:
	var out := OriginalDialog.seamless(_stone())
	var band := OriginalDialog.SEAMLESS_BAND
	assert_eq(out.get_size(), Vector2i(400 - band + 2, 350 - band + 2),
		"the stone less the band, and a pixel of wrap each side inside the bevel")
	assert_eq(_tile_rect(out).size, Vector2i(394 - band, 344 - band))
	assert_eq(OriginalDialog.PANELS["panel_stone"]["margin"],
		OriginalDialog.SEAMLESS_BEVEL + 1, "the frame's margin is that ring")


func test_its_edges_meet() -> void:
	var stone := _stone()
	var out := OriginalDialog.seamless(stone)
	var t := _tile_rect(out)
	var rows := Vector2i(t.position.y, t.end.y)
	var neighbours := 0.0
	for x in range(t.position.x, t.end.x - 1, 7):
		neighbours += _columns_apart(out, x, x + 1, rows)
	neighbours /= ceili((t.size.x - 1) / 7.0)
	var wrap := _columns_apart(out, t.end.x - 1, t.position.x, rows)
	var raw := _columns_apart(stone, 396, 3, Vector2i(3, 347))
	assert_gt(raw, 3.0 * neighbours, "the fixture's own edges do not meet")
	assert_lt(wrap, 1.5 * neighbours,
		"across the join the tile changes no more than from one column to the next")
	# And down: the same, rotated.
	var turned := out.duplicate() as Image
	turned.rotate_90(CLOCKWISE)
	var tt := _tile_rect(turned)
	var down := _columns_apart(turned, tt.end.x - 1, tt.position.x,
		Vector2i(tt.position.y, tt.end.y))
	assert_lt(down, 1.5 * neighbours, "and from its foot to its head")


func test_its_light_is_flat() -> void:
	var out := OriginalDialog.seamless(_stone(20.0))
	var t := _tile_rect(out)
	var quarter := t.size.x / 4
	var left := _mean(_lum(out, Rect2i(t.position, Vector2i(quarter, t.size.y))))
	var right := _mean(_lum(out, Rect2i(t.end.x - quarter, t.position.y, quarter, t.size.y)))
	assert_lt(absf(left - right), 4.0,
		"tiles side by side do not band: the left-to-right fall of the light is gone")
	var stone := _mean(_lum(_stone(20.0), Rect2i(3, 3, 394, 344)))
	assert_lt(absf(_mean(_lum(out, t)) - stone), 4.0, "and the stone is as light as it was")


func test_the_join_keeps_the_grain() -> void:
	var out := OriginalDialog.seamless(_stone())
	var t := _tile_rect(out)
	var band := OriginalDialog.SEAMLESS_BAND
	# The middle of the fade, where the two stones are mixed most nearly
	# half and half: plain mixing would leave it about 0.72 as grainy.
	var faded := _spread(_lum(out, Rect2i(t.position.x + band / 4, t.position.y,
		band / 2, t.size.y)))
	var kept := _spread(_lum(out, Rect2i(t.position.x + band, t.position.y,
		t.size.x - band, t.size.y)))
	assert_between(faded / kept, 0.88, 1.15,
		"the fade across the join is as grainy as the stone, not a smooth stripe")


func test_the_join_takes_each_pixel_from_one_stone_or_the_other() -> void:
	# THE CUT, NOT A FADE. Laid over each other, two stones double every
	# figure — a ring beside its own ghost. So in the band each pixel is
	# the stone that follows the tile's end or the tile's own, and only
	# the few pixels either side of the cut are mixed. Light left as drawn
	# here, so the pixels can be read against the stone's own.
	var stone := _stone()
	var out := OriginalDialog.seamless(stone, 1, Vector2i.ZERO, false)
	var t := _tile_rect(out)
	var band := OriginalDialog.SEAMLESS_BAND
	var feather := OriginalDialog.SEAMLESS_FEATHER
	var mixed_most := 0
	# Rows below the band the second (downward) join made.
	for y in range(band, t.size.y, 5):
		var mixed := 0
		for x in band:
			var got := out.get_pixel(t.position.x + x, t.position.y + y)
			var own := stone.get_pixel(3 + x, 3 + y)
			var follows := stone.get_pixel(3 + x + t.size.x, 3 + y)
			if not (_alike(got, own) or _alike(got, follows)):
				mixed += 1
		mixed_most = maxi(mixed_most, mixed)
		assert_eq(out.get_pixel(t.position.x + band + 7, t.position.y + y),
			stone.get_pixel(3 + band + 7, 3 + y), "past the band, the stone itself")
	assert_lte(mixed_most, 2 * feather + 1,
		"no more pixels of a row mixed than the feather either side of the cut")


static func _alike(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) * 255.0 < 1.5 and absf(a.g - b.g) * 255.0 < 1.5 \
		and absf(a.b - b.b) * 255.0 < 1.5


func test_a_pattern_tiles_as_whole_repeats_untouched() -> void:
	# The knot repeats every 94x52: its tile is as many whole repeats as
	# leave a band to cut in, and since the two sides of every cut are the
	# same figure, every pixel of the tile is the pattern's own.
	var period := Vector2i(94, 52)
	var knot := _pattern(Vector2i(481, 323), period)
	var out := OriginalDialog.seamless(knot, 1, period, false)
	var t := _tile_rect(out)
	assert_eq(t.size, Vector2i(4 * 94, 5 * 52), "whole repeats")
	assert_eq(t.size.x % period.x, 0)
	for y in range(0, t.size.y, 7):
		for x in range(0, t.size.x, 5):
			assert_true(_alike(out.get_pixel(t.position.x + x, t.position.y + y),
				knot.get_pixel(3 + x, 3 + y)), "the pattern untouched at %d,%d" % [x, y])
	# The repeats of a band: none for a stone, whole ones for a pattern.
	assert_eq(OriginalDialog._band(394, 0, 40), 40)
	assert_eq(OriginalDialog._band(475, 94, 40), 475 - 4 * 94)
	assert_eq(OriginalDialog._band(100, 94, 40), 40, "a repeat longer than the stone allows")


func test_the_ring_round_the_tile_is_the_tiles_own_wrap() -> void:
	# A tile's edge drawn smooth reads the pixel beyond it. That pixel is
	# the ring's, so it must be the stone that follows — never the bevel.
	var out := OriginalDialog.seamless(_stone())
	var t := _tile_rect(out)
	for y in range(t.position.y, t.end.y, 11):
		assert_eq(out.get_pixel(t.position.x - 1, y), out.get_pixel(t.end.x - 1, y))
		assert_eq(out.get_pixel(t.end.x, y), out.get_pixel(t.position.x, y))
	for x in range(t.position.x, t.end.x, 11):
		assert_eq(out.get_pixel(x, t.position.y - 1), out.get_pixel(x, t.end.y - 1))
		assert_eq(out.get_pixel(x, t.end.y), out.get_pixel(x, t.position.y))


func test_the_bevel_goes_back_round_it() -> void:
	var stone := _stone()
	var out := OriginalDialog.seamless(stone)
	var o := out.get_size()
	# The four corners as the stone has them...
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		for d in 9:
			var at := Vector2i(d % 3, d / 3)
			assert_eq(out.get_pixel((o.x - 3) * corner.x + at.x, (o.y - 3) * corner.y + at.y),
				stone.get_pixel(397 * corner.x + at.x, 347 * corner.y + at.y), "corner %s" % corner)
	# ...and each edge one line all along.
	for d in 3:
		var want_tl := MID if d == 2 else LIGHT
		var want_br := MID if d == 2 else DARK
		for i in [3, o.x / 2, o.x - 4]:
			assert_eq(out.get_pixel(i, d).to_html(), want_tl.to_html(), "top, row %d" % d)
			assert_eq(out.get_pixel(i, o.y - 1 - d).to_html(), want_br.to_html(),
				"bottom, row %d" % d)
		for i in [3, o.y / 2, o.y - 4]:
			assert_eq(out.get_pixel(d, i).to_html(), want_tl.to_html(), "left, column %d" % d)
			assert_eq(out.get_pixel(o.x - 1 - d, i).to_html(), want_br.to_html(),
				"right, column %d" % d)


func test_too_small_a_picture_comes_back_as_it_is() -> void:
	var small := Image.create_empty(60, 50, false, Image.FORMAT_RGBA8)
	small.fill(Color(0.6, 0.5, 0.4))
	assert_eq(OriginalDialog.seamless(small).get_size(), Vector2i(60, 50))


# -------------------------------------------------------- worn by the game --

func test_every_stone_and_pattern_ground_tiles_and_the_pictures_stretch() -> void:
	for key in OriginalDialog.PANELS:
		var spec: Dictionary = OriginalDialog.PANELS[key]
		if key in ["big_card_panel", "versus_background"]:
			assert_false(spec["tile"], key + ": a picture stretches")
			assert_false(spec.get("seamless", false), key)
		elif key != "message_panel":
			assert_true(spec["tile"], key)
			assert_true(spec.get("seamless", false), key + ": made a seamless tile")
			assert_eq(spec["margin"], OriginalDialog.SEAMLESS_BEVEL + 1,
				key + ": its margin is the bevel and the pixel of wrap")


func test_each_ground_is_worn_as_its_tile() -> void:
	var made := {
		"panel_stone": [_stone(20.0, GameSkin.SIZES["panel_stone"]), Vector2i(362, 312)],
		"panel_dark_stone": [_stone(20.0, GameSkin.SIZES["panel_dark_stone"]),
			Vector2i(289 - 6 - 40 + 8, 274 - 6 - 40 + 8)],
		"panel_end_duel": [_stone(20.0, GameSkin.SIZES["panel_end_duel"]),
			Vector2i(272 - 6 - 40 + 8, 422 - 6 - 40 + 8)],
		"panel_knot": [_pattern(GameSkin.SIZES["panel_knot"], Vector2i(94, 52)),
			Vector2i(4 * 94 + 8, 5 * 52 + 8)],
	}
	for key in made:
		(made[key][0] as Image).save_png(
			ProjectSettings.globalize_path(SKIN.path_join(key + ".png")))
	GameSkin.clear_caches()
	for key in made:
		var tile := OriginalDialog.ground(key)
		assert_not_null(tile, key)
		if tile == null:
			continue
		assert_ne(tile, GameSkin.texture(key), key + ": not the picture itself")
		assert_eq(Vector2i(tile.get_size()), made[key][1], key)
		var patch := OriginalDialog.frame(key)
		assert_same(patch.texture, tile, key)
		assert_eq(patch.axis_stretch_vertical, NinePatchRect.AXIS_STRETCH_MODE_TILE, key)
		patch.free()
		var box := OriginalDialog.panel_style(key, 5.0) as StyleBoxTexture
		assert_same(box.texture, tile, key)


func test_a_window_that_fits_wears_the_picture_itself() -> void:
	# The duel's verdict, 272x300, fits inside the 272x422 rings: it wears
	# the 1997 picture, clipped, with no join. The match's 430x200 does not.
	_stone(20.0, Vector2i(272, 422)).save_png(
		ProjectSettings.globalize_path(SKIN.path_join("panel_end_duel.png")))
	GameSkin.clear_caches()
	var tile := OriginalDialog.ground("panel_end_duel")
	var picture := GameSkin.texture("panel_end_duel")
	assert_ne(tile, picture)
	var holder := Control.new()
	add_child_autofree(holder)
	holder.size = Vector2(272, 300)
	var patch := OriginalDialog.frame("panel_end_duel")
	holder.add_child(patch)
	await get_tree().process_frame
	assert_same(patch.texture, picture, "272x300 fits the rings")
	holder.size = Vector2(430, 200)
	await get_tree().process_frame
	assert_same(patch.texture, tile, "430 wide does not")
	holder.size = Vector2(200, 150)
	await get_tree().process_frame
	assert_same(patch.texture, picture, "and back")


func test_the_skin_s_stone_is_worn_as_the_tile() -> void:
	_stone().save_png(ProjectSettings.globalize_path(SKIN.path_join("panel_stone.png")))
	GameSkin.clear_caches()
	var tile := OriginalDialog.ground("panel_stone")
	assert_not_null(tile)
	if tile == null:
		return
	assert_eq(Vector2i(tile.get_size()), Vector2i(362, 312))
	assert_same(OriginalDialog.ground("panel_stone"), tile, "made once")
	assert_eq(OriginalDialog.ground("big_card_panel"), GameSkin.texture("big_card_panel"),
		"a picture is worn as it is")
	# Every sandstone surface wears it, tiled, inside its ring.
	var box := UiChrome.stone_panel(6.0)
	assert_true(box is StyleBoxTexture)
	var styled := box as StyleBoxTexture
	assert_same(styled.texture, tile)
	assert_eq(styled.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
	assert_eq(styled.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
	assert_eq(styled.texture_margin_left, float(OriginalDialog.SEAMLESS_BEVEL + 1))
	assert_eq(styled.content_margin_left, 6.0)
	var patch := OriginalDialog.frame("panel_stone")
	assert_same(patch.texture, tile)
	assert_eq(patch.axis_stretch_horizontal, NinePatchRect.AXIS_STRETCH_MODE_TILE)
	patch.free()


func test_a_2x_stone_gives_a_2x_tile_drawn_at_the_same_size() -> void:
	var big := _stone()
	big.resize(800, 700, Image.INTERPOLATE_NEAREST)
	big.save_png(ProjectSettings.globalize_path(SKIN.path_join("panel_stone.png")))
	GameSkin.clear_caches()
	var tile := OriginalDialog.ground("panel_stone")
	assert_not_null(tile)
	if tile == null:
		return
	assert_eq(Vector2i(tile.get_size()), Vector2i(362, 312), "drawn at the 1x tile's size")
	assert_eq(GameSkin.scale_of(tile), 2)
	assert_eq(tile.get_image().get_size(), Vector2i(724, 624), "with all its pixels")
	# A new picture makes a new tile.
	_stone(0.0).save_png(ProjectSettings.globalize_path(SKIN.path_join("panel_stone.png")))
	GameSkin.clear_caches()
	var again := OriginalDialog.ground("panel_stone")
	assert_ne(again, tile)
	assert_eq(GameSkin.scale_of(again), 1)
