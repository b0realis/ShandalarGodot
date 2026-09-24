extends SceneTree
## DRAWS THE ART THIS PROJECT SHIPS AS ITS OWN — set glyphs, expansion
## medallions and the damage dagger — and writes them to `game/art/`.
##
##     ../tools/godot --headless --path . -s res://tools/draw_our_art.gd
##
## WHY THIS FILE EXISTS. The game's default look must belong to the game.
## The 1997 art is the player's own copy and is never redistributed
## (`Provenance.md`), and the flat gold set glyphs and the fat dagger a
## Manalink install carries are a THIRD PARTY'S RESTYLE of MicroProse's
## drawings — not ours to copy either. So the shapes below are DRAWN HERE,
## from scratch, by this file: an anvil, a scimitar, a comet, a crescent,
## a Roman II and a Roman IV, a broken column and a dagger, described as polygons and
## arcs in unit coordinates and rasterised by the little signed-distance
## renderer in this script. Fallen Empires follows the owner's supplied
## crown silhouette, redrawn here as geometry. No reference image is read
## or embedded: run without any 1997 game or Manalink install and this
## produces exactly the same pictures.
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

## THE BLADE IS RED, AND THAT IS A LEGIBILITY DECISION, not a
## decoration. The dagger is the ONE mark on this table drawn over an
## arbitrary picture — a card's own art — instead of over a panel, and a
## steel-grey blade was tried first and lost: on `Grizzly Bears`, whose
## art is a snowfield, an 18 px grey blade simply vanished. The pass that
## followed only WARMED it — a near-white spine falling to scarlet — and
## the owner's ruling of 2026-09-09 took it the rest of the way: red and
## salmon, the register of a wound, which is also what the game already
## says about damage everywhere else. The number beside this very mark is
## salmon ([MiniCard]'s `_damage_count`, `1.0, 0.45, 0.35`) and the damage
## still to come is its cold twin ([constant MiniCard.PENDING_COLOR]).
##
## So the ramp is SHORT and lives entirely inside the red: a pale salmon
## highlight down to a strong red, whose midpoint is `_damage_count`'s own
## colour to within a hair. Nowhere on the blade is it either pale enough
## to read as steel on a snowfield or dark enough to sink into a black
## card — the two grounds that decide this mark — and the furniture stays
## gold, which is what tells blade and hilt apart at a glance.
##
## The DARK end is the one that had to be pulled back up (2026-09-09).
## The picture's base ramp runs top to bottom, and the blade now points
## down-left, so the deepest colour of the ramp lands on the TIP — the
## thinnest part of the mark, where the 2 px rim is already most of what
## is drawn. A scarlet that looked right in the middle of the blade took
## the last four pixels of the point to black on a black card and the
## dagger simply got shorter.
const BLADE_LIT := Color(1.00, 0.74, 0.63)
const BLADE_DARK := Color(0.86, 0.20, 0.15)
## The furniture, deepened on 2026-09-09 when the blade went red. Gold
## and sandstone (`UiChrome.FACE`, 196/179/146) are within a percent of
## each other in luminance, so the old bright gold was separated from the
## Help page's own panel by hue alone — which a 14 px minification does
## not keep. This gold is a full step darker at both ends of its ramp.
const HILT_LIT := Color(0.96, 0.76, 0.26)
const HILT_DARK := Color(0.34, 0.18, 0.02)

const OUT_DIR := "res://game/art"


func _init() -> void:
	var dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for code in ["atq", "arn", "past", "drk", "2ed", "4ed", "leg", "fem", "ice", "hml", "all", "por"]:
		var img := _render(Vector2i(GLYPH_SIZE, GLYPH_SIZE),
			[[_glyph(code), GOLD_LIT, GOLD_DARK]], RIM)
		_write(img, dir, "set_icon_%s.png" % code)
	_write(_crown_medallion(true), dir, "filter_fem_on.png")
	_write(_crown_medallion(false), dir, "filter_fem_off.png")
	_write(_stone_medallion(true, _snowflake()), dir, "filter_ice_on.png")
	_write(_stone_medallion(false, _snowflake()), dir, "filter_ice_off.png")
	_write(_stone_medallion(true, _homelands()), dir, "filter_hml_on.png")
	_write(_stone_medallion(false, _homelands()), dir, "filter_hml_off.png")
	_write(_stone_medallion(true, _alliances()), dir, "filter_all_on.png")
	_write(_stone_medallion(false, _alliances()), dir, "filter_all_off.png")
	_write(_stone_medallion(true, _portal()), dir, "filter_por_on.png")
	_write(_stone_medallion(false, _portal()), dir, "filter_por_off.png")
	_write(_stone_medallion(true, []), dir, "filter_source_on.png")
	_write(_stone_medallion(false, []), dir, "filter_source_off.png")
	_write(_stone_medallion(true, _completed_cards()), dir, "filter_pack1_on.png")
	_write(_stone_medallion(false, _completed_cards()), dir, "filter_pack1_off.png")
	_write(_variant_medallion(true), dir, "card_variant_on.png")
	_write(_variant_medallion(false), dir, "card_variant_off.png")
	# The blade and the furniture are two GROUPS, each with its own metal
	# and its own rim — which is what puts a dark seam between the guard
	# and the blade instead of one gold-into-red smear.
	#
	# THE FURNITURE GOES ON LAST, i.e. IN FRONT (2026-09-09), which is
	# both where a real crossguard sits and the only way the guard
	# survives being drawn at eighteen pixels. Behind the blade it is two
	# gold lobes with the blade's shoulder between them, and once the
	# blade turned red and the hilt came up into the light half of the
	# picture those lobes had neither value nor hue to separate them from
	# it — at 14 px the mark read as a spike with a bead on the end. In
	# front it is ONE unbroken bar crossing the blade, with its own dark
	# rim down both sides of it, and a bar across a diagonal is the whole
	# reason a dagger is not an arrow.
	_write(_render(DAGGER_SIZE, [
			[_dagger_blade(), BLADE_LIT, BLADE_DARK],
			[_dagger_hilt(), HILT_LIT, HILT_DARK]], RIM_DAGGER),
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
		"2ed":
			return _roman_two()
		"4ed":
			return _roman_four()
		"leg":
			return _column()
		"fem":
			return _crown()
		"ice":
			return _snowflake()
		"hml":
			return _homelands()
		"all":
			return _alliances()
		"por":
			return _portal()
	return []


## PORTAL — the original set's round gate: solid center, two concentric
## rings and ten radial divisions. Authored geometry, not an embedded SVG.
## The printed card symbol is the visual reference (Scryfall's por.svg);
## wide openings keep the same shape readable as gold and incised stone.
func _portal() -> Array:
	var ops: Array = []
	var center := Vector2(0.5, 0.5)
	for band in [["add", 0.456], ["sub", 0.402],
			["add", 0.266], ["sub", 0.227], ["add", 0.160]]:
		var circle := PackedVector2Array()
		for n in 96:
			circle.append(center + Vector2.from_angle(TAU * float(n) / 96.0) * float(band[1]))
		ops.append({"op": band[0], "poly": circle})
	for n in 10:
		var angle := TAU * float(n) / 10.0
		var inner := center + Vector2.from_angle(angle + 0.04) * 0.145
		var outer := center + Vector2.from_angle(angle) * 0.430
		var edge := (outer - inner).normalized().orthogonal() * 0.015
		ops.append({"op": "add", "poly": PackedVector2Array([
			inner - edge, outer - edge, outer + edge, inner + edge])})
	return ops


## ALLIANCES — an authored forked banner. Broad gold folds and the same
## silhouette in carved stone keep the set coherent with the earlier packs.
func _alliances() -> Array:
	return [{"op": "add", "poly": PackedVector2Array([
		Vector2(0.17, 0.07), Vector2(0.25, 0.07), Vector2(0.25, 0.92),
		Vector2(0.17, 0.92)])}, {"op": "add", "poly": PackedVector2Array([
		Vector2(0.24, 0.11), Vector2(0.52, 0.06), Vector2(0.68, 0.13),
		Vector2(0.88, 0.09), Vector2(0.78, 0.33), Vector2(0.91, 0.57),
		Vector2(0.68, 0.61), Vector2(0.51, 0.52), Vector2(0.24, 0.56)])},
		{"op": "sub", "poly": PackedVector2Array([
			Vector2(0.50, 0.15), Vector2(0.56, 0.18), Vector2(0.56, 0.47), Vector2(0.50, 0.43)])}]


## HOMELANDS — a ringed world and three authored land silhouettes.
## Broad coastlines keep the gold mark legible in the tiny card slot;
## the same geometry is carved into the stone filter, with no SVG dependency.
func _homelands() -> Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 64:
		var direction := Vector2.from_angle(TAU * float(i) / 64.0)
		outer.append(Vector2(0.5, 0.5) + direction * 0.46)
		inner.append(Vector2(0.5, 0.5) + direction * 0.385)
	return [
		{"op": "add", "poly": outer}, {"op": "sub", "poly": inner},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.24, 0.23), Vector2(0.37, 0.16), Vector2(0.49, 0.24),
			Vector2(0.48, 0.37), Vector2(0.40, 0.43), Vector2(0.33, 0.36),
			Vector2(0.19, 0.40), Vector2(0.17, 0.32)])},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.15, 0.51), Vector2(0.28, 0.48), Vector2(0.37, 0.57),
			Vector2(0.48, 0.59), Vector2(0.45, 0.70), Vector2(0.38, 0.77),
			Vector2(0.39, 0.86), Vector2(0.28, 0.78), Vector2(0.23, 0.65)])},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.57, 0.17), Vector2(0.72, 0.23), Vector2(0.82, 0.36),
			Vector2(0.75, 0.44), Vector2(0.85, 0.55), Vector2(0.78, 0.72),
			Vector2(0.62, 0.82), Vector2(0.58, 0.71), Vector2(0.64, 0.59),
			Vector2(0.58, 0.47), Vector2(0.65, 0.34), Vector2(0.56, 0.28)])},
	]


## ICE AGE — six crystal arms, each with two broad branches. The same
## authored geometry drives the carved stone medallion and gold card mark.
func _snowflake() -> Array:
	var out: Array = []
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var arm := PackedVector2Array([
			Vector2(-0.040, 0.015), Vector2(-0.040, -0.20),
			Vector2(-0.15, -0.265), Vector2(-0.15, -0.345),
			Vector2(-0.040, -0.275), Vector2(-0.040, -0.46),
			Vector2(0.040, -0.46), Vector2(0.040, -0.275),
			Vector2(0.15, -0.345), Vector2(0.15, -0.265),
			Vector2(0.040, -0.20), Vector2(0.040, 0.015)])
		for j in arm.size():
			arm[j] = Vector2(0.5, 0.5) + arm[j].rotated(angle)
		out.append({"op": "add", "poly": arm})
	return out


## FALLEN EMPIRES — three points, an oval opening and a detached lower
## band. One shape drives both the gold card symbol and the stone filter.
func _crown() -> Array:
	var opening := PackedVector2Array()
	for i in 48:
		var angle := TAU * float(i) / 48.0
		opening.append(Vector2(0.5 + cos(angle) * 0.064,
			0.516 + sin(angle) * 0.122))
	return [
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.04, 0.29), Vector2(0.345, 0.38),
			Vector2(0.50, 0.11), Vector2(0.655, 0.38),
			Vector2(0.96, 0.29), Vector2(0.82, 0.71),
			Vector2(0.18, 0.71)])},
		{"op": "sub", "poly": opening},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.20, 0.78), Vector2(0.80, 0.78),
			Vector2(0.75, 0.92), Vector2(0.25, 0.92)])},
	]


## Pack 1 completes a collection: three fanned card frames, with a small
## four-point glint in the front card. Broad silhouettes survive at 34px.
func _completed_cards() -> Array:
	return [
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.08, 0.29), Vector2(0.37, 0.18), Vector2(0.60, 0.76), Vector2(0.31, 0.88)])},
		{"op": "sub", "poly": PackedVector2Array([
			Vector2(0.16, 0.33), Vector2(0.33, 0.27), Vector2(0.51, 0.72), Vector2(0.34, 0.79)])},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.63, 0.18), Vector2(0.92, 0.29), Vector2(0.69, 0.88), Vector2(0.40, 0.76)])},
		{"op": "sub", "poly": PackedVector2Array([
			Vector2(0.67, 0.27), Vector2(0.84, 0.33), Vector2(0.66, 0.79), Vector2(0.49, 0.72)])},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.31, 0.12), Vector2(0.69, 0.12), Vector2(0.69, 0.85), Vector2(0.31, 0.85)])},
		{"op": "sub", "poly": PackedVector2Array([
			Vector2(0.38, 0.20), Vector2(0.62, 0.20), Vector2(0.62, 0.77), Vector2(0.38, 0.77)])},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.50, 0.30), Vector2(0.54, 0.43), Vector2(0.61, 0.49), Vector2(0.54, 0.54),
			Vector2(0.50, 0.68), Vector2(0.46, 0.54), Vector2(0.39, 0.49), Vector2(0.46, 0.43)])},
	]


## Two overlapping picture frames: choose an illustration, not a card pool.
## A round stone edge leaves the compact Showcase control light on the page.
func _variant_medallion(on: bool) -> Image:
	var glyph := [
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.17, 0.16), Vector2(0.62, 0.16), Vector2(0.62, 0.72), Vector2(0.17, 0.72)])},
		{"op": "sub", "poly": PackedVector2Array([
			Vector2(0.25, 0.24), Vector2(0.54, 0.24), Vector2(0.54, 0.64), Vector2(0.25, 0.64)])},
		{"op": "sub", "poly": PackedVector2Array([
			Vector2(0.33, 0.28), Vector2(0.86, 0.28), Vector2(0.86, 0.88), Vector2(0.33, 0.88)])},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.38, 0.33), Vector2(0.81, 0.33), Vector2(0.81, 0.84), Vector2(0.38, 0.84)])},
		{"op": "sub", "poly": PackedVector2Array([
			Vector2(0.46, 0.41), Vector2(0.73, 0.41), Vector2(0.73, 0.76), Vector2(0.46, 0.76)])},
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.43, 0.74), Vector2(0.56, 0.54), Vector2(0.63, 0.65),
			Vector2(0.69, 0.58), Vector2(0.76, 0.74)])},
	]
	var img := _stone_medallion(true, glyph)
	for y in GLYPH_SIZE:
		for x in GLYPH_SIZE:
			var delta := Vector2(x, y) - Vector2.ONE * (GLYPH_SIZE - 1) * 0.5
			var radius := delta.length()
			var pixel := img.get_pixel(x, y)
			pixel.a = clampf(23.5 - radius, 0.0, 1.0)
			if radius > 21.0:
				var light := 0.37 + delta.normalized().dot(LIGHT) * 0.25
				pixel = Color(light * 0.87, light * 0.96, light * 1.08, pixel.a)
			if not on: pixel = Color(pixel.r * 0.5, pixel.g * 0.5, pixel.b * 0.5, pixel.a)
			img.set_pixel(x, y, pixel)
	return img


## Blue-grey square stone with a bevel, gold ring and dark carved emblem:
## the same construction as the owner's set-strip reference. The grain is
## deterministic and wholly procedural; no original skin is redistributed.
func _crown_medallion(on: bool) -> Image:
	return _stone_medallion(on, _crown())


## A blank version takes live 97 lettering; pack versions carry an emblem.
func _stone_medallion(on: bool, glyph: Array) -> Image:
	var size := Vector2i(GLYPH_SIZE, GLYPH_SIZE)
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var grain := float((x * 73 + y * 151 + x * y * 19) % 31) / 30.0 - 0.5
			var vein := sin(float(x) * 0.43 + sin(float(y) * 0.31) * 2.0) * 0.018
			var edge := mini(mini(x, y), mini(size.x - 1 - x, size.y - 1 - y))
			var light := 0.62 + grain * 0.10 + vein - float(y) * 0.0007
			if edge == 0:
				light = 0.26 + grain * 0.04
			elif edge < 4:
				var top_left := mini(x, y) < mini(size.x - 1 - x, size.y - 1 - y)
				light += (0.22 if top_left else -0.25) * (1.0 - float(edge - 1) / 4.0)
			img.set_pixel(x, y, Color(light * 0.87, light * 0.96, light * 1.08, 1.0))
	_draw_group(img, size, [
		{"op": "add", "ellipse": [0.5, 0.5, 0.426]},
		{"op": "sub", "ellipse": [0.5, 0.5, 0.387]},
	], Color("e2c873"), Color("9c782c"), 0.45)
	var inset: Array = []
	for op in glyph:
		var poly := PackedVector2Array()
		for point in op.poly:
			poly.append((point - Vector2(0.5, 0.5)) * 0.72 + Vector2(0.5, 0.5))
		inset.append({"op": op.op, "poly": poly})
	var field := _signed_field(size, inset)
	for y in size.y:
		for x in size.x:
			var sd: float = field[y * size.x + x]
			if sd < -1.0:
				continue
			var coverage := clampf(sd + 0.5, 0.0, 1.0)
			var under := img.get_pixel(x, y)
			var slope := Vector2(_at(field, size, x + 1, y) - _at(field, size, x - 1, y),
				_at(field, size, x, y + 1) - _at(field, size, x, y - 1))
			# Recessed edges catch light on the lower-right lip.
			if sd < 0.5:
				under = under.lightened(maxf(0.0, slope.normalized().dot(LIGHT)) * 0.28)
			img.set_pixel(x, y, under.lerp(Color("101419"), coverage))
	if not on:
		for y in size.y:
			for x in size.x:
				var pixel := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(pixel.r * 0.50, pixel.g * 0.50, pixel.b * 0.50, pixel.a))
	return img


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


## UNLIMITED — a Roman `II`, the Fourth Edition numeral's sibling
## (2026-09-18, the owner: *"Make also a gold roman II (similar as for
## fourth) and use that for 2nd edition cards"*). No printed Unlimited
## card wears a symbol and the 1997 game drew none, so until today an
## Unlimited card was the one card in the Deck Builder lettered `2ⁿᵈ`
## while every neighbour wore gold. The same slab-serif `I` as the IV's,
## twice, centred in the square with a gap of one stem between them, so
## the pair still reads as two strokes at fourteen pixels.
func _roman_two() -> Array:
	var bars: Array = []
	for left in [0.155, 0.55]:
		var right: float = left + 0.295
		var stem_l: float = left + 0.09
		var stem_r: float = right - 0.09
		bars.append({"op": "add", "poly": PackedVector2Array([
			Vector2(left, 0.135), Vector2(right, 0.135), Vector2(right, 0.265),
			Vector2(stem_r, 0.265), Vector2(stem_r, 0.735), Vector2(right, 0.735),
			Vector2(right, 0.865), Vector2(left, 0.865), Vector2(left, 0.735),
			Vector2(stem_l, 0.735), Vector2(stem_l, 0.265), Vector2(left, 0.265),
		])})
	return bars


## LEGENDS — a BROKEN COLUMN. Hard flat facets and not one curve: a wide
## CAPITAL whose ends are taken off at 45°, a groove cut through it, a
## narrower BAND under that, then the SHAFT with three arched flutes —
## and the whole monument sheared away by a single DIAGONAL running from
## the lower left up to the right, so the shaft ends in a slant and there
## is no base at all.
##
## THE BREAK IS THE GLYPH, and it is there for legibility before it is
## there for mood. Every other symbol on the row is left-right
## symmetrical, and so was the column that shipped on 2026-09-09 — a
## standing fluted column on a plinth, which at fourteen pixels is the
## anvil beside it with the horn filed off. A silhouette that is
## deliberately lopsided is the one thing the eye can still pick out of
## that row once the flutes and both grooves have closed up, so the
## shear is cut SHALLOW (about 30° off the horizontal) and long, taking
## most of the shaft's right-hand side with it: at fourteen pixels the
## missing corner is five pixels of the fourteen.
##
## Redrawn to the owner's brief of 2026-09-09 ("a broken monument, not a
## standing column"). The levels, the chamfer angles and the shear are
## chosen here by what survives minification; nothing is traced.

## The break, corner to corner: down the shaft's left edge to [constant
## COLUMN_CUT_L], then one straight line back up to [constant
## COLUMN_CUT_R] on its right edge. Everything below and to the right of
## that line is gone.
const COLUMN_CUT_L := Vector2(0.195, 0.945)
const COLUMN_CUT_R := Vector2(0.805, 0.585)


func _column() -> Array:
	var ops: Array = [
		# THE CAPITAL — widest along its top edge, the ends taken in
		# gently to a kink and then at a flat 45° (dx == dy) to the
		# underside, which is the cut that gives it its splayed look.
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.025, 0.045), Vector2(0.975, 0.045),
			Vector2(0.915, 0.150), Vector2(0.822, 0.243),
			Vector2(0.178, 0.243), Vector2(0.085, 0.150)])},
		# THE BAND — flaring the other way: narrow where it goes behind
		# the capital, wide where it hands over to the shaft.
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.335, 0.205), Vector2(0.665, 0.205),
			Vector2(0.775, 0.395), Vector2(0.225, 0.395)])},
		# THE SHAFT — square shoulders, straight sides, and then the
		# break instead of a foot.
		{"op": "add", "poly": PackedVector2Array([
			Vector2(0.238, 0.340), Vector2(0.762, 0.340),
			Vector2(0.805, 0.440), COLUMN_CUT_R, COLUMN_CUT_L,
			Vector2(0.195, 0.440)])},
		# the groove through the capital, its ends splayed STEEPER than
		# the 45° chamfer outside them so each end reads as a chevron
		_groove(0.132, 0.196, 0.300, 0.700, 1.4),
		# the groove between the band and the shaft
		_groove(0.330, 0.386, 0.340, 0.660, 1.1),
	]
	# Three flutes and the two ribs between them, in the proportions a
	# fluted shaft actually wears: the ribs a little wider than the
	# channels, and a margin either side so the outer rib is not thinner
	# than the rest.
	for left in [0.270, 0.458, 0.646]:
		ops.append(_flute(left, left + 0.085))
	return ops


## The height of the break at [param x] — used by the flutes, which stop
## short of it rather than running off the end.
func _column_cut(x: float) -> float:
	var t: float = (x - COLUMN_CUT_L.x) / (COLUMN_CUT_R.x - COLUMN_CUT_L.x)
	return lerpf(COLUMN_CUT_L.y, COLUMN_CUT_R.y, t)


## A groove cut clean through: a horizontal slot from [param top] to
## [param bottom], spanning [param left]..[param right] at the top and
## splaying outward on the way down by [param splay] times its own
## height. In a lit gold relief a slot is a DARK line, not a hole — the
## rim ink meets in the middle of anything narrower than about three
## pixels — which is the right reading anyway: these are incisions in a
## stone, not gaps between separate pieces.
func _groove(top: float, bottom: float, left: float, right: float,
		splay: float) -> Dictionary:
	var out: float = (bottom - top) * splay
	return {"op": "sub", "poly": PackedVector2Array([
		Vector2(left, top), Vector2(right, top),
		Vector2(right + out, bottom), Vector2(left - out, bottom)])}


## One flute: a channel with a 45° arch at its head, running down until
## the break takes it.
##
## THE FOOT STOPS SHORT of the break by [constant COLUMN_LIP], and that
## small number is doing real work. Run the channels all the way onto the
## diagonal and the break becomes a dashed edge — three notches of
## nothing where the flutes reach it — which at fourteen pixels is a
## ragged bottom rather than a cut one. Stopping them early leaves an
## unbroken dark LIP along the whole diagonal, and that lip is most of
## what still says "sheared off" after the flutes themselves have gone.
const COLUMN_LIP := 0.055

func _flute(left: float, right: float) -> Dictionary:
	var head := 0.485
	var arch := 0.022
	return {"op": "sub", "poly": PackedVector2Array([
		Vector2(left + arch, head), Vector2(right - arch, head),
		Vector2(right, head + arch),
		Vector2(right, _column_cut(right) - COLUMN_LIP),
		Vector2(left, _column_cut(left) - COLUMN_LIP),
		Vector2(left, head + arch)])}


## THE DAMAGE DAGGER — the mark a wounded creature wears. The register is
## the one the owner chose: SHORT, FAT, BRIGHT and on a clear diagonal,
## with furniture you can see.
##
## IT POINTS DOWN AND TO THE LEFT (owner, 2026-09-09), hilt high on the
## right — turned end for end from the version that shipped that morning.
## The mark sits in the small card's bottom-right corner directly above
## the P/T box (`MiniCard._build_face`), so a blade pointing down-left
## drives INTO the card's own art and into the creature it is about; the
## old up-right blade pointed out of the card at the table, which is a
## cursor's job and not a wound's.
##
## The turn is a straight half-turn about the middle of the picture, and
## that is what keeps the light honest. The bevel is lit from the top
## left by the slope of the shape's own distance field ([method _metal]),
## so every facet is relit for the direction it now faces: the edges that
## caught the light before are the shadowed ones now, which is what a
## real blade turned end for end does. Nothing about the lighting is
## pinned to the blade's old direction, and nothing needed to be.
##
## Its points are given in the SAME square-unit space the rasteriser
## works in — x in 0..[constant DAGGER_ASPECT], y in 0..1, one unit is one
## picture height on both axes — so that "perpendicular" means
## perpendicular and the crossguard crosses the blade at a right angle on
## screen. [method _unq] puts them back into the 0..1 form the ops take.
const DAGGER_ASPECT := 1.6
const DAGGER_GUARD := Vector2(1.06, 0.315)
const DAGGER_TIP := Vector2(0.055, 0.945)
const DAGGER_POMMEL := Vector2(1.41, 0.125)


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
