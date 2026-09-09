extends SceneTree
## DRAWS THE ART THIS PROJECT SHIPS AS ITS OWN — the six set glyphs and the
## damage dagger — and writes them to `game/art/`.
##
##     ../tools/godot --headless --path . -s res://tools/draw_our_art.gd
##
## WHY THIS FILE EXISTS. The game's default look must belong to the game.
## The 1997 art is the player's own copy and is never redistributed
## (`Provenance.md`), and the flat gold set glyphs and the fat dagger a
## Manalink install carries are a THIRD PARTY'S RESTYLE of MicroProse's
## drawings — not ours to copy either. So the shapes below are DRAWN HERE,
## from scratch, by this file: an anvil, a scimitar, a comet, a crescent,
## a Roman IV, a fluted column and a dagger, described as polygons and
## arcs in unit coordinates and rasterised by the little signed-distance
## renderer in this script. Nothing is traced, sampled or copied from any
## file: run this on a machine with no 1997 game and no Manalink install
## and it produces exactly the same pictures.
##
## They are the FLOOR, not the ceiling. A player who imports their own
## 1997 art still gets the 1997 art — `GameSkin` checks the imported skin
## first and only falls through to these (see `GameSkin.our_art`).
##
## HOW IT DRAWS. Every glyph is a list of ops (`add`/`sub` polygons,
## ellipses and capsules) in a 0..1 unit square. The ops are sampled onto
## a supersampled grid, a chamfer distance transform turns that into a
## signed distance field, and the field is rendered at the final size with
## an anti-aliased edge, a dark outline and a lit bevel — which is what
## makes a 14 px glyph keep its shape instead of turning to porridge.
##
## Ours, 2026-09-09. NOT `[1997]`: no source claims these shapes.

## The final size of a set glyph, in pixels. 48 rather than something
## larger on purpose: every consumer MINIFIES it (the enlarged card's icon
## box is about 14 px, the title row's badges 22, the Help page's column
## 34) and Godot filters these textures without mipmaps, so a master far
## bigger than its uses would sparkle. 48 is within a hair of the 1997
## medallion's own 40 and of the restyle's 35, so ours scales exactly as
## either of those does.
const GLYPH_SIZE := 48

## The dagger is WIDE, because it lies along a diagonal: 64x40 is the
## aspect the small card's 28x18 slot and the damage marker's own 28x28
## box both want (`MiniCard._build_face`, `DamageMarker._build_face`).
const DAGGER_SIZE := Vector2i(64, 40)

## Subsamples per axis. 8 gives 64 samples a pixel, which is more than
## enough for a clean edge and still finishes in well under a second.
const SS := 8

## The dark rim under every glyph, in FINAL pixels. Both grounds a set
## symbol lands on are pale — the enlarged card's type strip and the title
## screen's sandstone plaque — so a gold shape with no rim loses its
## outline on both. 1.15 keeps a visible edge at 14 px without eating the
## shape.
const RIM := 1.15
## THE DAGGER GETS A HEAVIER ONE, and the reason is the minification, not
## taste: a set glyph is drawn at 14-34 px from a 48 px file (at worst
## 3.4:1), but the dagger is drawn at 18 px on the small card from a 64x40
## file — and at that reduction a 1.15 px rim is a third of a pixel and
## disappears into whatever card art is underneath. 2.0 survives it. The
## dagger is the one mark on this table that has to read over an arbitrary
## picture; everything else has a panel behind it.
const RIM_DAGGER := 2.0
const RIM_INK := Color(0.16, 0.10, 0.03, 0.96)

## The gold, top to bottom, and the light that models it. A set symbol is
## "the golden image of edition" (the owner, 2026-09-09), so the ramp runs
## from a pale highlight gold to a deep shadow gold and a top-left light
## picks out the edges.
const GOLD_LIT := Color(1.00, 0.92, 0.62)
const GOLD_DARK := Color(0.55, 0.33, 0.05)
const LIGHT := Vector2(-0.7071, -0.7071)
## How deep into the shape the bevel reaches, in final pixels.
const BEVEL_DEPTH := 2.6

## THE BLADE IS WARM, AND THAT IS A LEGIBILITY DECISION, not a
## decoration. The dagger is the ONE mark on this table drawn over an
## arbitrary picture — a card's own art — instead of over a panel, and a
## steel-grey blade was tried first and lost: on `Grizzly Bears`, whose
## art is a snowfield, an 18 px grey blade simply vanished. Warm carries
## it, because it is also what the game already says about damage
## everywhere else — the number beside this very mark is salmon
## ([MiniCard]'s `_damage_count`, `1.0, 0.45, 0.35`) and the damage still
## to come is its cold twin ([constant MiniCard.PENDING_COLOR]). So the
## blade runs from a hot pale spine to a deep scarlet edge and the
## furniture stays gold, which is what tells the two apart at a glance.
const BLADE_LIT := Color(1.00, 0.94, 0.88)
const BLADE_DARK := Color(0.72, 0.16, 0.12)
const HILT_LIT := Color(1.00, 0.86, 0.42)
const HILT_DARK := Color(0.42, 0.24, 0.04)

const OUT_DIR := "res://game/art"


func _init() -> void:
	var dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for code in ["atq", "arn", "past", "drk", "4ed", "leg"]:
		var img := _render(Vector2i(GLYPH_SIZE, GLYPH_SIZE),
			[[_glyph(code), GOLD_LIT, GOLD_DARK]], RIM)
		_write(img, dir, "set_icon_%s.png" % code)
	# The blade and the furniture are two GROUPS, each with its own metal
	# and its own rim — which is what puts a dark seam between the guard
	# and the blade instead of one gold-into-steel smear.
	_write(_render(DAGGER_SIZE, [
			[_dagger_hilt(), HILT_LIT, HILT_DARK],
			[_dagger_blade(), BLADE_LIT, BLADE_DARK]], RIM_DAGGER),
		dir, "damage_marker.png")
	quit()


func _write(img: Image, dir: String, filename: String) -> void:
	var path := dir.path_join(filename)
	var err := img.save_png(path)
	print("%s %s (%dx%d)" % ["wrote" if err == OK else "FAILED", path,
		img.get_width(), img.get_height()])


# ---------------------------------------------------------- the shapes --
# All coordinates are fractions of the picture: (0,0) top-left, (1,1)
# bottom-right. Everything below is a description of a shape in words a
# person can check against the picture, which is the point of drawing them
# in code rather than in a paint program.

func _glyph(code: String) -> Array:
	match code:
		"atq":
			return _anvil()
		"arn":
			return _scimitar()
		"past":
			return _comet()
		"drk":
			return _crescent()
		"4ed":
			return _roman_four()
		"leg":
			return _column()
	return []


## ANTIQUITIES — an anvil: a long pointed HORN on the left, a top slab
## with a heel on the right, a waisted body and a splayed foot. The horn
## is the half of the silhouette that says "anvil" and not "column", and
## the two glyphs sit next to each other on the same row, so it is drawn
## long and it is drawn pointed.
func _anvil() -> Array:
	var body := PackedVector2Array([
		Vector2(0.010, 0.30), Vector2(0.32, 0.245), Vector2(0.90, 0.245),
		Vector2(0.955, 0.285), Vector2(0.955, 0.395), Vector2(0.90, 0.445),
		Vector2(0.66, 0.445), Vector2(0.615, 0.53), Vector2(0.615, 0.665),
		Vector2(0.825, 0.815), Vector2(0.845, 0.945), Vector2(0.155, 0.945),
		Vector2(0.175, 0.815), Vector2(0.385, 0.665), Vector2(0.385, 0.53),
		Vector2(0.34, 0.445), Vector2(0.255, 0.445), Vector2(0.145, 0.395),
	])
	return [{"op": "add", "poly": body}]


## ARABIAN NIGHTS — a scimitar: one deep sweep of blade from a hilt at the
## bottom right up to a point at the top left, with a crossguard, a grip
## and a pommel. The spine is a quadratic curve and the blade is that
## curve offset both ways by a width that runs out at the tip, so the
## thing tapers to a point instead of ending in a stump.
func _scimitar() -> Array:
	var root := Vector2(0.72, 0.80)
	var bend := Vector2(0.30, 0.86)
	var tip := Vector2(0.20, 0.12)
	var blade := _tapered_curve(root, bend, tip, 0.175, 40)
	# The hilt runs the other way out of the root, along the blade's own
	# line, so guard, grip and blade share one axis.
	var away := ((root - bend) * 2.0).normalized()
	var across := Vector2(-away.y, away.x)
	var grip := root + away * 0.185
	return [
		{"op": "add", "poly": blade},
		{"op": "add", "capsule": [
			(root + across * 0.225).x, (root + across * 0.225).y,
			(root - across * 0.225).x, (root - across * 0.225).y, 0.042]},
		{"op": "add", "capsule": [root.x, root.y, grip.x, grip.y, 0.046]},
		{"op": "add", "ellipse": [grip.x, grip.y, 0.062]},
	]


## A blade: the quadratic curve through [param a], [param bend] and
## [param b], offset both ways by a width that starts at [param width] and
## runs out to nothing at the far end.
func _tapered_curve(a: Vector2, bend: Vector2, b: Vector2, width: float,
		steps: int) -> PackedVector2Array:
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	for i in steps + 1:
		var s: float = float(i) / float(steps)
		var u: float = 1.0 - s
		var p: Vector2 = a * (u * u) + bend * (2.0 * u * s) + b * (s * s)
		var d: Vector2 = ((bend - a) * (2.0 * u) + (b - bend) * (2.0 * s))
		if d.length() < 0.0001:
			d = b - a
		var n := Vector2(-d.normalized().y, d.normalized().x)
		var w: float = width * pow(1.0 - s, 0.55)
		front.append(p + n * w)
		back.append(p - n * w)
	var out := PackedVector2Array(front)
	for i in range(back.size() - 1, -1, -1):
		out.append(back[i])
	return out


## ASTRAL — the star trailing sparks the original drew for its own set.
## A four-pointed star with a long tail down to the left and two loose
## sparks behind it: a comet, and unmistakably not a plain star even when
## it is fourteen pixels across.
func _comet() -> Array:
	var c := Vector2(0.655, 0.335)
	var star := PackedVector2Array()
	var arms := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var long := 0.335
	var short := 0.105
	for i in 4:
		var a: Vector2 = arms[i]
		var b: Vector2 = arms[(i + 1) % 4]
		star.append(c + a * long)
		star.append(c + (a + b).normalized() * short)
	return [
		{"op": "add", "poly": star},
		# the tail: two strokes falling away behind the head, the outer
		# one shorter, both tapering by being thinner as they go
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.60, 0.40), Vector2(0.475, 0.45),
			Vector2(0.06, 0.96), Vector2(0.235, 0.60),
		])},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.545, 0.545), Vector2(0.60, 0.62),
			Vector2(0.315, 0.945), Vector2(0.40, 0.70),
		])},
		{"op": "add", "ellipse": [0.145, 0.545, 0.065]},
		{"op": "add", "ellipse": [0.35, 0.33, 0.05]},
	]


## THE DARK — a crescent moon, one disc with a second taken out of it. Cut
## fat on purpose: a thin crescent is the first thing to disappear at the
## card's own size.
func _crescent() -> Array:
	return [
		{"op": "add", "ellipse": [0.475, 0.50, 0.465]},
		{"op": "sub", "ellipse": [0.79, 0.375, 0.435]},
	]


## FOURTH EDITION — the Roman `IV` the 1997 Deck Builder wore on its own
## filter button, drawn as slab-serif letters so that two strokes two
## pixels wide still read as a numeral.
func _roman_four() -> Array:
	var i_bar := PackedVector2Array([
		Vector2(0.03, 0.135), Vector2(0.325, 0.135), Vector2(0.325, 0.265),
		Vector2(0.235, 0.265), Vector2(0.235, 0.735), Vector2(0.325, 0.735),
		Vector2(0.325, 0.865), Vector2(0.03, 0.865), Vector2(0.03, 0.735),
		Vector2(0.12, 0.735), Vector2(0.12, 0.265), Vector2(0.03, 0.265),
	])
	var v := PackedVector2Array([
		Vector2(0.395, 0.135), Vector2(0.615, 0.135), Vector2(0.615, 0.265),
		Vector2(0.545, 0.265), Vector2(0.675, 0.665), Vector2(0.805, 0.265),
		Vector2(0.735, 0.265), Vector2(0.735, 0.135), Vector2(0.965, 0.135),
		Vector2(0.965, 0.265), Vector2(0.905, 0.265), Vector2(0.735, 0.865),
		Vector2(0.605, 0.865), Vector2(0.44, 0.265), Vector2(0.395, 0.265),
	])
	return [{"op": "add", "poly": i_bar}, {"op": "add", "poly": v}]


## LEGENDS — a fluted column: a wide flat abacus, an echinus flaring down
## into a slender shaft with a little entasis, and a stepped base. Drawn
## deliberately NARROWER in the waist and WIDER at the ends than the anvil
## beside it, because at fourteen pixels the two are the same family of
## silhouette and only the proportions tell them apart. The two flutes are
## cut, not shaded, so they survive being scaled down; below about twelve
## pixels they close up and the silhouette carries the glyph, which is the
## right failure.
func _column() -> Array:
	var shaft := PackedVector2Array([
		Vector2(0.365, 0.225), Vector2(0.635, 0.225), Vector2(0.655, 0.50),
		Vector2(0.635, 0.775), Vector2(0.365, 0.775), Vector2(0.345, 0.50),
	])
	return [
		# the abacus — the flat slab on top
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.05, 0.045), Vector2(0.95, 0.045),
			Vector2(0.95, 0.135), Vector2(0.05, 0.135)])},
		# the echinus, flaring down into the shaft
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.105, 0.135), Vector2(0.895, 0.135),
			Vector2(0.635, 0.245), Vector2(0.365, 0.245)])},
		{"op": "add", "poly": shaft},
		# the base: a torus over a plinth
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.345, 0.755), Vector2(0.655, 0.755),
			Vector2(0.895, 0.865), Vector2(0.105, 0.865)])},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.045, 0.865), Vector2(0.955, 0.865),
			Vector2(0.955, 0.955), Vector2(0.045, 0.955)])},
		{"op": "sub", "capsule": [0.445, 0.285, 0.445, 0.72, 0.020]},
		{"op": "sub", "capsule": [0.555, 0.285, 0.555, 0.72, 0.020]},
	]


## THE DAMAGE DAGGER — the mark a wounded creature wears. The register is
## the one the owner chose: SHORT, FAT, BRIGHT and on a clear diagonal,
## with furniture you can see. It points up and to the right, hilt at the
## bottom left, because that is the corner of the small card it is drawn
## in (`MiniCard._build_face`) and a blade pointing up out of the card's
## own art reads as a wound rather than as a cursor.
##
## Its points are given in the SAME square-unit space the rasteriser
## works in — x in 0..[constant DAGGER_ASPECT], y in 0..1, one unit is one
## picture height on both axes — so that "perpendicular" means
## perpendicular and the crossguard crosses the blade at a right angle on
## screen. [method _unq] puts them back into the 0..1 form the ops take.
const DAGGER_ASPECT := 1.6
const DAGGER_GUARD := Vector2(0.54, 0.685)
const DAGGER_TIP := Vector2(1.545, 0.055)
const DAGGER_POMMEL := Vector2(0.19, 0.875)


## A square-unit point as the fraction of the picture's width and height
## the ops are written in.
func _unq(p: Vector2) -> Vector2:
	return Vector2(p.x / DAGGER_ASPECT, p.y)


func _dagger_blade() -> Array:
	var axis := (DAGGER_TIP - DAGGER_GUARD).normalized()
	var n := Vector2(-axis.y, axis.x)
	var belly := DAGGER_GUARD.lerp(DAGGER_TIP, 0.30)
	var w := 0.155
	return [{"op": "add", "poly": PackedVector2Array([
		_unq(DAGGER_GUARD + n * w * 0.80), _unq(belly + n * w),
		_unq(DAGGER_TIP),
		_unq(belly - n * w), _unq(DAGGER_GUARD - n * w * 0.80)])}]


func _dagger_hilt() -> Array:
	var axis := (DAGGER_TIP - DAGGER_GUARD).normalized()
	var n := Vector2(-axis.y, axis.x)
	var arm_a := _unq(DAGGER_GUARD + n * 0.245)
	var arm_b := _unq(DAGGER_GUARD - n * 0.245)
	var grip_a := _unq(DAGGER_GUARD)
	var grip_b := _unq(DAGGER_POMMEL)
	return [
		# the crossguard, square across the blade
		{"op": "add", "capsule": [arm_a.x, arm_a.y, arm_b.x, arm_b.y, 0.062]},
		# the grip
		{"op": "add", "capsule": [grip_a.x, grip_a.y, grip_b.x, grip_b.y,
			0.058]},
		# the pommel
		{"op": "add", "ellipse": [grip_b.x, grip_b.y, 0.095]},
	]


# ------------------------------------------------------- the rasteriser --

## Render [param groups] — each `[ops, lit colour, dark colour]` — onto a
## transparent picture of [param size], back to front.
func _render(size: Vector2i, groups: Array, rim: float) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for group in groups:
		var ops: Array = group[0]
		if ops.is_empty():
			continue
		_draw_group(img, size, ops, group[1], group[2], rim)
	return img


func _draw_group(img: Image, size: Vector2i, ops: Array,
		lit: Color, dark: Color, rim: float) -> void:
	var field := _signed_field(size, ops)
	for y in size.y:
		for x in size.x:
			var sd: float = field[y * size.x + x]
			# Outside the rim by more than half a pixel: nothing here.
			var rim_cover: float = clampf(sd + rim + 0.5, 0.0, 1.0)
			if rim_cover <= 0.0:
				continue
			var cover: float = clampf(sd + 0.5, 0.0, 1.0)
			var ink := RIM_INK
			if cover > 0.0:
				var metal := _metal(field, size, x, y, sd, lit, dark)
				ink = RIM_INK.lerp(metal, cover)
				ink.a = maxf(RIM_INK.a, cover)
			ink.a *= rim_cover
			img.set_pixel(x, y, _over(ink, img.get_pixel(x, y)))


## One pixel of metal: the vertical ramp, lit from the top left by the
## slope of the distance field, which is the shape's own surface.
func _metal(field: PackedFloat32Array, size: Vector2i, x: int, y: int,
		sd: float, lit: Color, dark: Color) -> Color:
	var down: float = float(y) / maxf(1.0, float(size.y - 1))
	var base := lit.lerp(dark, clampf(down * 0.92 + 0.04, 0.0, 1.0))
	# The gradient of the field points INTO the shape; the surface tilts
	# the other way, so the normal is its negative.
	var gx: float = _at(field, size, x + 1, y) - _at(field, size, x - 1, y)
	var gy: float = _at(field, size, x, y + 1) - _at(field, size, x, y - 1)
	var slope := Vector2(-gx, -gy)
	var edge: float = 1.0 - clampf(sd / BEVEL_DEPTH, 0.0, 1.0)
	var shade := 1.0
	if slope.length() > 0.001:
		shade = 1.0 + 0.62 * edge * slope.normalized().dot(LIGHT)
	return Color(clampf(base.r * shade, 0.0, 1.0),
		clampf(base.g * shade, 0.0, 1.0),
		clampf(base.b * shade, 0.0, 1.0), 1.0)


func _at(field: PackedFloat32Array, size: Vector2i, x: int, y: int) -> float:
	var cx: int = clampi(x, 0, size.x - 1)
	var cy: int = clampi(y, 0, size.y - 1)
	return field[cy * size.x + cx]


## Alpha-over, straight (not premultiplied) — the pictures are small and
## the groups few, so the readable form is the right one.
func _over(top: Color, under: Color) -> Color:
	var a: float = top.a + under.a * (1.0 - top.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var f: float = under.a * (1.0 - top.a)
	return Color((top.r * top.a + under.r * f) / a,
		(top.g * top.a + under.g * f) / a,
		(top.b * top.a + under.b * f) / a, a)


## THE SIGNED DISTANCE FIELD, in final pixels, positive inside. The ops
## are filled onto an SSxSS grid a ROW AT A TIME (scanline, not one
## point-in-polygon test per subsample — the scimitar's blade is ninety
## vertices and the naive form is minutes rather than seconds), a chamfer
## distance transform runs over that grid both ways, and each pixel's
## block is averaged back down. That gives an anti-aliased edge AND a
## surface for the bevel to be lit by.
func _signed_field(size: Vector2i, ops: Array) -> PackedFloat32Array:
	var w := size.x * SS
	var h := size.y * SS
	var inside := _fill(ops, size, w, h)
	var din := _chamfer(inside, w, h, 1)
	var dout := _chamfer(inside, w, h, 0)
	var field := PackedFloat32Array()
	field.resize(size.x * size.y)
	for y in size.y:
		for x in size.x:
			var total := 0.0
			for j in SS:
				var row: int = (y * SS + j) * w + x * SS
				for i in SS:
					var k: int = row + i
					total += (din[k] - 0.5) if inside[k] == 1 \
						else -(dout[k] - 0.5)
			field[y * size.x + x] = total / float(SS * SS * SS)
	return field


## THE UNIT SQUARE IS NOT SQUARE on a picture that is wider than it is
## tall, so every shape is worked in `q` — x times the aspect, y as it
## is — where one unit is one picture HEIGHT on both axes. A radius means
## the same thing in both directions there, which is what keeps the
## dagger's crossguard from coming out an oval.
func _fill(ops: Array, size: Vector2i, w: int, h: int) -> PackedByteArray:
	var aspect := float(size.x) / float(size.y)
	var mask := PackedByteArray()
	mask.resize(w * h)
	for op in ops:
		var on: int = 1 if String(op.get("op", "add")) == "add" else 0
		if op.has("poly"):
			_fill_poly(mask, w, h, aspect, op["poly"], on)
		elif op.has("ellipse"):
			var e: Array = op["ellipse"]
			_fill_ellipse(mask, w, h, aspect, Vector2(e[0], e[1]) \
				* Vector2(aspect, 1.0), float(e[2]), on)
		elif op.has("capsule"):
			var c: Array = op["capsule"]
			_fill_capsule(mask, w, h, aspect,
				Vector2(c[0], c[1]) * Vector2(aspect, 1.0),
				Vector2(c[2], c[3]) * Vector2(aspect, 1.0), float(c[4]), on)
	return mask


## Subpixel column of a q-space x, and back again.
func _col(qx: float, w: int, aspect: float) -> float:
	return qx / aspect * float(w) - 0.5


func _span(mask: PackedByteArray, w: int, row: int, x0: float, x1: float,
		on: int) -> void:
	var lo: int = maxi(0, int(ceil(x0)))
	var hi: int = mini(w - 1, int(floor(x1)))
	for x in range(lo, hi + 1):
		mask[row + x] = on


func _fill_poly(mask: PackedByteArray, w: int, h: int, aspect: float,
		poly: PackedVector2Array, on: int) -> void:
	var q := PackedVector2Array()
	for p in poly:
		q.append(Vector2(p.x * aspect, p.y))
	var n := q.size()
	for sy in h:
		var y: float = (float(sy) + 0.5) / float(h)
		var xs := PackedFloat32Array()
		var j := n - 1
		for i in n:
			var a := q[i]
			var b := q[j]
			if (a.y > y) != (b.y > y):
				xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
			j = i
		if xs.is_empty():
			continue
		var sorted := Array(xs)
		sorted.sort()
		var row: int = sy * w
		var k := 0
		while k + 1 < sorted.size():
			_span(mask, w, row, _col(sorted[k], w, aspect),
				_col(sorted[k + 1], w, aspect), on)
			k += 2


func _fill_ellipse(mask: PackedByteArray, w: int, h: int, aspect: float,
		centre: Vector2, radius: float, on: int) -> void:
	for sy in h:
		var y: float = (float(sy) + 0.5) / float(h)
		var dy: float = y - centre.y
		if absf(dy) > radius:
			continue
		var half: float = sqrt(radius * radius - dy * dy)
		_span(mask, w, sy * w, _col(centre.x - half, w, aspect),
			_col(centre.x + half, w, aspect), on)


func _fill_capsule(mask: PackedByteArray, w: int, h: int, aspect: float,
		a: Vector2, b: Vector2, radius: float, on: int) -> void:
	var top: float = minf(a.y, b.y) - radius
	var bottom: float = maxf(a.y, b.y) + radius
	var left: float = minf(a.x, b.x) - radius
	var right: float = maxf(a.x, b.x) + radius
	for sy in h:
		var y: float = (float(sy) + 0.5) / float(h)
		if y < top or y > bottom:
			continue
		var lo: int = maxi(0, int(ceil(_col(left, w, aspect))))
		var hi: int = mini(w - 1, int(floor(_col(right, w, aspect))))
		var row: int = sy * w
		for sx in range(lo, hi + 1):
			var x: float = (float(sx) + 0.5) / float(w) * aspect
			if _seg_distance(Vector2(x, y), a, b) <= radius:
				mask[row + sx] = on


## Distance, in SUBPIXELS, from every cell to the nearest cell whose value
## is not [param of] — the two-pass chamfer with 1 / 1.35 weights, within
## about 5% of the true Euclidean distance, which is all a one-pixel rim
## and a three-pixel bevel need.
func _chamfer(mask: PackedByteArray, w: int, h: int, of: int) -> PackedFloat32Array:
	const BIG := 1.0e9
	var d := PackedFloat32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0.0 if mask[i] != of else BIG
	for y in h:
		for x in w:
			var k: int = y * w + x
			if d[k] == 0.0:
				continue
			var best: float = d[k]
			if x > 0:
				best = minf(best, d[k - 1] + 1.0)
			if y > 0:
				best = minf(best, d[k - w] + 1.0)
				if x > 0:
					best = minf(best, d[k - w - 1] + 1.35)
				if x < w - 1:
					best = minf(best, d[k - w + 1] + 1.35)
			d[k] = best
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var k: int = y * w + x
			if d[k] == 0.0:
				continue
			var best: float = d[k]
			if x < w - 1:
				best = minf(best, d[k + 1] + 1.0)
			if y < h - 1:
				best = minf(best, d[k + w] + 1.0)
				if x > 0:
					best = minf(best, d[k + w - 1] + 1.35)
				if x < w - 1:
					best = minf(best, d[k + w + 1] + 1.35)
			d[k] = best
	return d


func _seg_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
