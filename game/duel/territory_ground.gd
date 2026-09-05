class_name TerritoryGround
extends RefCounted
## THE TABLE UNDER THE CARDS — `Your territory background`, all nine
## choices of `@DIALOG_DUELOPTIONS` (`UIStrings.txt:598`), drawn.
##
## [DuelOptions] owns the SETTING (which colour, which style, and whose
## half it applies to); this file owns the PICTURE. One entry point,
## [method node], hands back the Control that dresses one territory, and
## it always hands back something: with the 1997 art it is the original's
## own file, without it a ground painted here.
##
## ---------------------------------------------------------------------
## WHAT THE THREE STYLES ARE — surveyed with PIL at 3-8x, 2026-09-02, and
## the survey is written out in `tools/import_original.py`'s MANIFEST.
## They are not three copies of one idea and they are not drawn alike:
##
##  * `Pattern` (`Terr_<c>patt.pic`) is a FRAMED PANEL. Its field is a
##    seamless damask, but the file is ringed by a decorative border — 8px
##    on white, blue, red and green; ~20px on black, which carries a
##    corner ornament and a double rule. So it is drawn as a NINE-PATCH:
##    the border at its native size, the field TILED inside it. Tiling the
##    file whole is what an earlier pass tried, and the "seam a third of
##    the way across" it recorded was this border repeating.
##  * `Mana symbols` (`Terr_<c>mana.pic`) is a true WALLPAPER, with no
##    border of its own: a staggered quilt of medallions carrying all five
##    mana glyphs. It tiles as it is.
##  * `Line drawing` (`Terr_<c>pict.pic`) is ONE PICTURE — a frieze of
##    carved angels, a winged orb, a hooded figure on a jetty, a sleeping
##    nymph, a dragon over a magenta sea. A PICTURE STRETCHES AND MUST
##    KEEP ITS OWN ASPECT: this is the rule `game/duel/opening_window.gd`
##    states for `Winbk_Startduel`, and the board half (914x400 at
##    1280x800) is a different shape from the art (721x381 or 888x381), so
##    it is drawn COVERED — scaled up until it fills, cropped, never
##    squashed. A 27% horizontal stretch is nothing on a damask and very
##    visible on a dragon.
##
## THE 1px BLACK EDGE. Fourteen of the fifteen s30 conversions carry one
## (`Terr_Redpict` is the exception). It is invisible under a stretch and
## a black grid under a tile, so every path here cuts it off first —
## [method _inner] measures it rather than assuming it, because the one
## file without it would lose a pixel of art for nothing.
##
## ---------------------------------------------------------------------
## WITHOUT THE 1997 ART, all fifteen grounds are PAINTED HERE. That is not
## a courtesy: `Provenance.md` requires the game to be complete and
## playable with no imported asset at all, and a chooser whose nine
## choices all looked the same would be a chooser in name only. The
## derived set keeps the three styles apart the way the originals do — a
## lattice, a medallion quilt, and one large emblem drawn in outline —
## and keeps the five colours apart by palette. It is OUR drawing in the
## era's idiom (an ordered dither over a tiny palette), not a copy of
## anything.

## The decorative border of each `Terr_<c>patt.pic`, in source pixels,
## measured 2026-09-02 by trimming t pixels off the file, tiling the rest
## to 914x400 and looking: at t below the border the frame repeats as a
## visible bar, at t equal to it the field is seamless. White, blue, red
## and green settle at 8; black needs 20 because its border is an
## ornamented one (a corner square with a star, plus a double rule).
##
## These count from the file's own edge, so the 1px conversion edge that
## [method _inner] removes is inside them — the nine-patch margin is
## therefore `BORDER - edge`, not `BORDER`.
const PATTERN_BORDER := {
	"white": 8, "blue": 8, "black": 20, "red": 8, "green": 8,
}

## THE DERIVED GROUND'S PALETTE. Each base is that colour's own card-frame
## tint — [constant MiniCard.FRAME_COLORS], repeated here as literals
## because that table is keyed by [enum Mtg.ManaColor] and a territory is
## named by the seat's colour STRING. Everything else is arithmetic on it,
## so the five grounds are one design in five keys:
##   ground   = base * 0.45   (a table sits UNDER cards, so it is dark)
##   dither   = ground * 0.80 and ground * 1.20 (the two ordered-dither
##              tones — the original's own territory files are 7 to 28
##              colours built exactly this way)
##   motif    = ground * 1.85, the lattice and the medallion rims
##   emblem   = ground * 2.40, the one bright tone the line drawing uses
const BASE := {
	"white": Color(0.85, 0.82, 0.68),
	"blue": Color(0.35, 0.50, 0.78),
	"black": Color(0.30, 0.26, 0.32),
	"red": Color(0.72, 0.32, 0.22),
	"green": Color(0.30, 0.52, 0.34),
}
const GROUND_SCALE := 0.45
const DITHER_DARK := 0.80
const DITHER_LIGHT := 1.20
const MOTIF_SCALE := 1.85
const EMBLEM_SCALE := 2.40

## The derived wallpaper's tile, and the derived picture's size. 64 is the
## smallest square that holds a readable mana glyph in a medallion at 1:1
## on the board; the picture is 16:9 because it is the shape the board
## half is closest to, so COVER crops least.
const TILE := 64
const PICTURE := Vector2i(320, 180)

## Ordered 4x4 dither (Bayer) — the era's way of making a gradient out of
## a handful of colours, and the same table [ExilePlate] derives its plate
## with. Values 0..15 against a 0..16 threshold.
const BAYER := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]

## Cache: colour -> the glyph's polygons, outline first and any HOLES
## after it (only the skull has any). Built once by [method _build_glyphs]
## on the first ask — as plain data rather than as constants, because
## GDScript will not fold a `PackedVector2Array(...)` call into a constant
## expression and a `static var` whose initialiser calls another static
## function does not compile.
static var _glyph_cache: Dictionary = {}

## Cache: "<colour>|<style key>" -> derived texture. Painting a 64x64 tile
## is cheap and painting a 320x180 picture is not free, and both are
## asked for on every redress.
static var _derived_cache: Dictionary = {}
## Cache: skin key -> the file's 1px-black-edge width (0 or 1).
static var _edge_cache: Dictionary = {}


## THE GROUND FOR ONE TERRITORY, anchored to fill its parent. Never null:
## the original's art when the skin has it, a painted one when it does
## not. The caller adds it as the FIRST child of the half's holder and may
## modulate it (the duel dims its table so cards pop; the setup screen's
## preview shows it at full strength).
static func node(color_key: String, type_label: String) -> Control:
	var row := DuelOptions.territory_type_row(type_label)
	var wallpaper := bool(row["wallpaper"])
	var key := DuelOptions.ground_key(color_key, String(row["label"]))
	var skin := GameSkin.texture(key)
	if skin == null:
		return _fill(_texture_rect(derived(color_key, type_label), wallpaper))
	var inner := _inner(key, skin)
	# `Pattern` is the only style whose file is FRAMED, so it is the only
	# one that needs the nine-patch. Its margin counts from the region,
	# which already has the conversion edge cut off it.
	var margin := 0
	if String(row["key"]) == "pattern":
		margin = maxi(0, int(PATTERN_BORDER.get(color_key, 8))
			- (skin.get_width() - int(inner.size.x)) / 2)
	if wallpaper and margin > 0:
		var patch := NinePatchRect.new()
		patch.texture = skin
		patch.region_rect = Rect2(inner)
		patch.patch_margin_left = margin
		patch.patch_margin_top = margin
		patch.patch_margin_right = margin
		patch.patch_margin_bottom = margin
		patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
		patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
		return _fill(patch)
	var trimmed := GameSkin.region(key, inner)
	return _fill(_texture_rect(trimmed if trimmed != null else skin, wallpaper))


## The imported 1997 art for one of the nine choices, or null when the
## skin has not been imported. [method node] does not expose which of the
## two grounds it chose, on purpose — a caller that wants to KNOW asks
## here, which is what the test does when it checks that all fifteen
## `Terr_*` files arrived.
static func art(color_key: String, type_label: String) -> Texture2D:
	return GameSkin.texture(DuelOptions.ground_key(color_key, type_label))


## The ground PAINTED HERE for one of the nine choices — a seamless tile
## for the two wallpapers, one picture for the line drawing. Never null,
## with or without the skin, so it is also what a test can compare
## fifteen of against each other.
static func derived(color_key: String, type_label: String) -> Texture2D:
	var row := DuelOptions.territory_type_row(type_label)
	var style := String(row["key"])
	var cache_key := "%s|%s" % [color_key, style]
	if _derived_cache.has(cache_key):
		return _derived_cache[cache_key]
	var base: Color = BASE.get(color_key, BASE["white"])
	var image: Image
	match style:
		"picture":
			image = _paint_picture(color_key, base)
		"mana":
			image = _paint_medallion_tile(color_key, base)
		_:
			image = _paint_lattice_tile(base)
	var result := ImageTexture.create_from_image(image)
	_derived_cache[cache_key] = result
	return result


# ------------------------------------------------------------- plumbing --

static func _fill(control: Control) -> Control:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


## A wallpaper REPEATS; a picture is scaled until it covers and is then
## cropped, which is the only way to fill a differently-shaped hole
## without changing the drawing's proportions.
static func _texture_rect(tex: Texture2D, wallpaper: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_TILE if wallpaper \
		else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return rect


## The file MINUS its 1px black conversion edge. Measured rather than
## assumed: fourteen of the fifteen territory files have one and
## `Terr_Redpict` does not, and cutting a pixel off the one that does not
## would throw away art. Sampled every 8px along the top row and left
## column — an edge that is black at those points is black.
static func _inner(key: String, tex: Texture2D) -> Rect2i:
	var edge: int = _edge_cache.get(key, -1)
	if edge < 0:
		edge = 0
		var img := tex.get_image()
		if img != null and img.get_width() > 4 and img.get_height() > 4:
			edge = 1
			for x in range(0, img.get_width(), 8):
				if img.get_pixel(x, 0).v > 0.02:
					edge = 0
					break
			if edge == 1:
				for y in range(0, img.get_height(), 8):
					if img.get_pixel(0, y).v > 0.02:
						edge = 0
						break
		_edge_cache[key] = edge
	return Rect2i(edge, edge, tex.get_width() - 2 * edge,
		tex.get_height() - 2 * edge)


# --------------------------------------------------------- derived paint --

## The dithered stone every derived ground is laid on: the base colour at
## [constant GROUND_SCALE], split into its two dither tones by the Bayer
## table. `wobble` moves the threshold about so the speckle is not a
## regular 4x4 grid at arm's length.
static func _ground_at(base: Color, x: int, y: int) -> Color:
	var ground := Color(base.r * GROUND_SCALE, base.g * GROUND_SCALE,
		base.b * GROUND_SCALE)
	var wobble := int(absf(sin(float(x) * 12.9898 + float(y) * 78.233)
		* 43758.5453)) % 5
	var threshold: int = int(BAYER[y % 4][x % 4]) + wobble
	return ground * (DITHER_LIGHT if threshold > 8 else DITHER_DARK)


## `Pattern`, painted: a diagonal lattice of lozenges over the dithered
## stone, with a rosette at every crossing. Seamless because 32 divides
## [constant TILE] — the lattice is `(x+y) mod 32` against `(x-y) mod 32`,
## and both wrap exactly at the tile edge.
static func _paint_lattice_tile(base: Color) -> Image:
	var img := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	var motif := Color(base.r * GROUND_SCALE * MOTIF_SCALE,
		base.g * GROUND_SCALE * MOTIF_SCALE,
		base.b * GROUND_SCALE * MOTIF_SCALE)
	for y in TILE:
		for x in TILE:
			var color := _ground_at(base, x, y)
			var a := absf(fposmod(float(x + y), 32.0) - 16.0)
			var b := absf(fposmod(float(x - y), 32.0) - 16.0)
			if a < 1.6 or b < 1.6:
				color = motif
			# The rosette: a small filled diamond where the two rules
			# cross, which is what turns a grid into a pattern.
			if a + b < 5.0:
				color = motif.lightened(0.25)
			img.set_pixel(x, y, color)
	return img


## `Mana symbols`, painted: one medallion per tile carrying the seat
## colour's own glyph, rim-lit from the top left the way the original's
## are embossed.
##
## SIMPLIFIED, and deliberately: the 1997 `Terr_<c>mana.pic` quilts ALL
## FIVE glyphs together and this paints only the seat's own. That is the
## `Life_<c>mana.pic` arrangement rather than the territory one — a
## smaller drawing that still says "mana symbols" at a glance. It is
## derived art, so it is not claiming to be the original's composition;
## the note is here so nobody reads it as one.
static func _paint_medallion_tile(color_key: String, base: Color) -> Image:
	var img := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	var motif := Color(base.r * GROUND_SCALE * MOTIF_SCALE,
		base.g * GROUND_SCALE * MOTIF_SCALE,
		base.b * GROUND_SCALE * MOTIF_SCALE)
	var half := float(TILE) * 0.5
	var outer := half - 3.0
	var inner := outer - 2.0
	for y in TILE:
		for x in TILE:
			var color := _ground_at(base, x, y)
			var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5)
			var r := d.length()
			if r < inner:
				# The disc's face, a shade above the stone, with the
				# glyph cut into it.
				color = motif.darkened(0.35)
				var p := d / inner
				if _glyph(color_key, p):
					color = motif.lightened(0.2)
			elif r < outer:
				# The rim, lit from the top left: the era's bevel.
				var lit := (d.x + d.y) < 0.0
				color = motif.lightened(0.35) if lit else motif.darkened(0.5)
			img.set_pixel(x, y, color)
	return img


## `Line drawing`, painted: ONE picture — the colour's emblem drawn in
## OUTLINE (the style's own name is the specification) over a ground that
## darkens towards the edges, inside a double rule. Not a tile: the caller
## covers with it, keeping its aspect.
##
## The outline is where the glyph's inside meets its outside: a pixel is
## on the line when it is in the polygon and one of its neighbours two
## pixels away is not, which gives a stroke of even weight all round
## without a distance field.
static func _paint_picture(color_key: String, base: Color) -> Image:
	var w := PICTURE.x
	var h := PICTURE.y
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var emblem := Color(base.r * GROUND_SCALE * EMBLEM_SCALE,
		base.g * GROUND_SCALE * EMBLEM_SCALE,
		base.b * GROUND_SCALE * EMBLEM_SCALE)
	var rule := Color(base.r * GROUND_SCALE * MOTIF_SCALE,
		base.g * GROUND_SCALE * MOTIF_SCALE,
		base.b * GROUND_SCALE * MOTIF_SCALE)
	# The emblem is drawn as tall as the picture allows, centred, at 78%
	# of the half-height so the double rule is never touched.
	var radius := float(h) * 0.5 * 0.78
	var centre := Vector2(float(w) * 0.5, float(h) * 0.5)
	var stroke := 2.0
	for y in h:
		for x in w:
			var color := _ground_at(base, x, y)
			# The vignette: everything outside the middle third of the
			# picture goes down towards the frame, so the emblem reads.
			var away := maxf(absf(float(x) / float(w) - 0.5),
				absf(float(y) / float(h) - 0.5)) * 2.0
			color = color.darkened(clampf(away - 0.45, 0.0, 1.0) * 0.55)
			var p := (Vector2(float(x), float(y)) - centre) / radius
			if _glyph(color_key, p):
				var edge := false
				for step in [Vector2(stroke, 0.0), Vector2(-stroke, 0.0),
						Vector2(0.0, stroke), Vector2(0.0, -stroke)]:
					if not _glyph(color_key, p + step / radius):
						edge = true
						break
				if edge:
					color = emblem
			# The double rule, 4px and 7px in — the era's frame, and the
			# same idiom the original's own `patt` files are bordered with.
			var inset: int = mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			if inset == 4 or inset == 7:
				color = rule
			img.set_pixel(x, y, color)
	return img


## THE FIVE GLYPHS, as polygons in a [-1, 1] square with +y DOWN. They
## are the mana symbols the original carves into its own `Terr_<c>mana`
## medallions — a sun, a drop, a skull, a flame and a tree — drawn here
## from scratch, because the 1997 sheet is not ours to ship.
##
## Each entry is [outline, hole...]: only the skull has holes, and a skull
## without its eye sockets is a stone. WHITE'S SUN IS GENERATED — an
## eight-point star, outer radius 0.95 and inner 0.42 so its rays are
## even — because sixteen alternating vertices written by hand invites one
## of them to be wrong.
static func _build_glyphs() -> Dictionary:
	var sun := PackedVector2Array()
	for i in 16:
		var angle := float(i) * PI / 8.0
		var r := 0.95 if i % 2 == 0 else 0.42
		sun.append(Vector2(cos(angle) * r, sin(angle) * r))
	return {
		"white": [sun],
		"blue": [PackedVector2Array([
			Vector2(0.0, -0.92), Vector2(0.30, -0.30), Vector2(0.52, 0.10),
			Vector2(0.55, 0.38), Vector2(0.38, 0.68), Vector2(0.0, 0.80),
			Vector2(-0.38, 0.68), Vector2(-0.55, 0.38), Vector2(-0.52, 0.10),
			Vector2(-0.30, -0.30)])],
		"black": [
			PackedVector2Array([
				Vector2(-0.62, -0.18), Vector2(-0.50, -0.62),
				Vector2(-0.18, -0.85), Vector2(0.18, -0.85),
				Vector2(0.50, -0.62), Vector2(0.62, -0.18),
				Vector2(0.50, 0.14), Vector2(0.34, 0.22),
				Vector2(0.34, 0.62), Vector2(0.12, 0.62),
				Vector2(0.12, 0.34), Vector2(-0.12, 0.34),
				Vector2(-0.12, 0.62), Vector2(-0.34, 0.62),
				Vector2(-0.34, 0.22), Vector2(-0.50, 0.14)]),
			PackedVector2Array([Vector2(-0.46, -0.46), Vector2(-0.12, -0.46),
				Vector2(-0.12, -0.08), Vector2(-0.46, -0.08)]),
			PackedVector2Array([Vector2(0.12, -0.46), Vector2(0.46, -0.46),
				Vector2(0.46, -0.08), Vector2(0.12, -0.08)]),
		],
		"red": [PackedVector2Array([
			Vector2(0.06, -0.95), Vector2(0.34, -0.40), Vector2(0.44, -0.55),
			Vector2(0.60, -0.05), Vector2(0.58, 0.42), Vector2(0.30, 0.76),
			Vector2(-0.06, 0.84), Vector2(-0.42, 0.68), Vector2(-0.58, 0.30),
			Vector2(-0.48, -0.08), Vector2(-0.26, -0.28),
			Vector2(-0.30, -0.62)])],
		"green": [PackedVector2Array([
			Vector2(-0.16, 0.88), Vector2(-0.16, 0.14), Vector2(-0.52, 0.02),
			Vector2(-0.74, -0.30), Vector2(-0.58, -0.62),
			Vector2(-0.28, -0.74), Vector2(0.0, -0.92), Vector2(0.28, -0.74),
			Vector2(0.58, -0.62), Vector2(0.74, -0.30), Vector2(0.52, 0.02),
			Vector2(0.16, 0.14), Vector2(0.16, 0.88)])],
	}


## Is a point in the colour's glyph? [param p] is in a [-1, 1] square with
## +y down. Asked about a quarter of a million points while one picture is
## painted, which is why the table is built once and cached.
static func _glyph(color_key: String, p: Vector2) -> bool:
	if _glyph_cache.is_empty():
		_glyph_cache = _build_glyphs()
	var polys: Array = _glyph_cache.get(color_key, [])
	if polys.is_empty():
		return false
	if not Geometry2D.is_point_in_polygon(p, polys[0]):
		return false
	for i in range(1, polys.size()):
		if Geometry2D.is_point_in_polygon(p, polys[i]):
			return false
	return true
