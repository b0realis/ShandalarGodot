extends GutTest
## THE SANDSTONE TILES (2026-10-18) — the owner's playtest of 0.50.32:
## *"Also check the background of options and magic battle! - it looks
## like a blur too much"*. The 400x350 `panel_stone` was stretched over
## windows twice its size and squeezed into every shell button; it is
## now the seamless tile the game makes of it ([method
## OriginalDialog.ground]), laid at its own size.
##
## The fixture is a stone drawn here, so no 1997 file is needed: a grain
## that changes from pixel to pixel the way sandstone does (noise drawn
## small and smoothed up, so a column is like the next and unlike one far
## away), lit twenty levels darker at the left than at the right as the
## 1997 picture is, inside a three-pixel bevel. Raw, its edges do not
## meet and its tiles would band; the tile made of it must do neither,
## keep its grain, and keep its bevel.

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

## The 1997 stone's shape: 400x350, a 3px bevel (two light rows and a
## mid one along top+left, two dark and a mid one along bottom+right),
## and inside it a smooth grain lit [param fall] levels brighter at the
## right than at the left.
static func _stone(fall := 20.0) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1997
	var grain := Image.create_empty(100, 88, false, Image.FORMAT_RGBA8)
	for y in grain.get_height():
		for x in grain.get_width():
			var v := rng.randf_range(-0.12, 0.12)
			grain.set_pixel(x, y, Color(0.5 + v, 0.5 + v * 0.9, 0.5 + v * 0.7))
	grain.resize(400, 350, Image.INTERPOLATE_BILINEAR)
	var img := Image.create_empty(400, 350, false, Image.FORMAT_RGBA8)
	for y in 350:
		for x in 400:
			var g := grain.get_pixel(x, y)
			var lit := (x / 399.0 - 0.5) * fall / 255.0
			img.set_pixel(x, y, Color(g.r + 0.27 + lit, g.g + 0.21 + lit, g.b + 0.08 + lit))
	for i in 400:
		for d in 3:
			img.set_pixel(i, d, MID if d == 2 else LIGHT)
			img.set_pixel(i, 349 - d, MID if d == 2 else DARK)
	for i in 350:
		for d in 3:
			img.set_pixel(d, i, MID if d == 2 else LIGHT)
			img.set_pixel(399 - d, i, MID if d == 2 else DARK)
	return img


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

func test_the_skin_s_stone_is_worn_as_the_tile() -> void:
	_stone().save_png(ProjectSettings.globalize_path(SKIN.path_join("panel_stone.png")))
	GameSkin.clear_caches()
	var tile := OriginalDialog.ground("panel_stone")
	assert_not_null(tile)
	if tile == null:
		return
	assert_eq(Vector2i(tile.get_size()), Vector2i(362, 312))
	assert_same(OriginalDialog.ground("panel_stone"), tile, "made once")
	assert_eq(OriginalDialog.ground("panel_dark_stone"), GameSkin.texture("panel_dark_stone"),
		"a ground not marked seamless is worn as it is")
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
