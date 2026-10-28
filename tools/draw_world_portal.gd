extends SceneTree
## DRAWS ARZAKON'S PORTAL ON THE WORLD — the dark horned arch with its
## glowing void, and the same arch turned to grey stone — and writes it to
## `game/art/` (part C, 2026-10-28; the owner's pick of 2026-10-27, pair 2
## of the mock-ups).
##
##     ../tools/godot --headless --path . -s res://tools/draw_world_portal.gd
##
## WHY THIS FILE EXISTS. The owner's ruling of 2026-10-27: after the fifth
## wizard falls Arzakon's portal opens near the map's middle, and after the
## win, if the hero roams, "the portal is a monument made of stone (make it
## as a new asset)". The 1997 game had no portal on its world map, so both
## pictures are OURS, drawn here from nothing but this file: no 1997 pixel,
## no Manalink file, nothing of another game is read or embedded. Run it on
## a machine with no 1997 install and it draws the same pictures.
##
## WHAT IT DRAWS — eight pictures, each a castle's 192 x 192 frame
## (`world_castles1`; `WorldView` stands it on its tile as a castle stands,
## frame corner at (0, -160) from the tile's left corner, so the tile's
## middle is the frame's (64, 160)), an UPRIGHT and its GROUND HALF:
##   world_portal_open[_ground]           the open arch, 1x
##   world_portal_petrified[_ground]      the stone monument, 1x
##   … each again as `@2x` (384 x 384), worn with a 2x skin.
## The arch: a frontal pointed arch on a two-step plinth, its depth thrown
## up and to the right, two horns and a spike on top. Open: dark violet
## slate, violet runes, a violet rim round the opening, a swirling void
## inside, sparks, violet light spilled on the ground in front. Petrified:
## grey limestone, the right horn broken, the void sealed by a stone plug
## carved with two arches and a spiral, cracks, moss, rubble at its foot.
##
## IN THE 1997 WORLD'S MANNER, so it stands among the 1997 sprites without
## looking pasted on: lit from the left; outlined by darkening the
## silhouette's own edge pixels (no black line); binary alpha; the shadow
## a 50 % checker of (71, 75, 79) thrown up and to the right along the
## tile's x axis (0.6 across, 0.3 up per pixel of height); a glow dithered
## with a 4 x 4 Bayer matrix; stone grain. At 1x the colours are reduced,
## with Floyd–Steinberg error diffusion, to [constant PALETTE_HEX] — the
## 252 colours the 1997 world sheets are painted with, written here as
## numbers (a palette is a list of colours, no picture). At 2x the colours
## stay full (the hi-res skin's way), the checker and the Bayer come in
## 2 x 2 blocks and the outline is two pixels.
##
## HOW IT DRAWS. Every shape is a polygon in the frame's 1x units (an
## ellipse or a stroke is turned into one). A polygon is rasterised into a
## coverage mask at the final size — scanlines, four to a pixel, each
## span's coverage exact across — and colours are laid over the frame
## through masks. The depth is the frame's polygons drawn again, stepped;
## the shadow is the same polygons sheared. The dice are seeded, so the
## grain is the same every run.
##
## Not drawn here: the portal without a skin — `WorldView.draw_portal_plain`
## draws it in code, as `draw_dungeon_plain` draws a dungeon.
##
## Ours, 2026-10-28. NOT `[1997]`: no source claims these shapes.

const HELP := """
Draw World Portal — Arzakon's portal on the world, open and petrified
=====================================================================

USAGE
  ../tools/godot --headless --path . -s res://tools/draw_world_portal.gd
  ../tools/godot --headless --path . -s res://tools/draw_world_portal.gd -- --out DIR
  ../tools/godot --headless --path . -s res://tools/draw_world_portal.gd -- -h | --version

  Writes eight pictures into game/art/ (or DIR): world_portal_open,
  world_portal_open_ground, world_portal_petrified,
  world_portal_petrified_ground, and each again as @2x.

AFTER A CHANGE
  Move their SHA-256 in game/art/README.md (tests/ui/test_our_art.gd
  holds every row to its file).
"""

const TOOL := "draw_world_portal"
const OUT_DIR := "res://game/art"

## The family wordmark (`tools/tool_banner.py`'s face): PORTAL.
const WORDMARK := [
	"┌─┐┌─┐┬─┐┌┬┐┌─┐┬  ",
	"├─┘│ │├┬┘ │ ├─┤│  ",
	"┴  └─┘┴└─ ┴ ┴ ┴┴─┘",
]
const CAPTION := ["Shandalar 1997 · Arzakon's portal", "the world's arch, open and in stone"]

## The frame, 1x: a castle's.
const FRAME := 192
## The tile's middle in the frame.
const CX := 64.0
const CY := 160.0
## Scanlines per pixel.
const SS := 4
## The 1997 shadow's ink, and how far a pixel of height throws it.
const SHADOW := Color8(71, 75, 79)
const SHEAR := Vector2(0.6, 0.3)
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

## The 252 colours of the 1997 world sheets, RGB, as numbers.
const PALETTE_HEX := (
	"000000000053000b0000173b001b77003317003397004bbb004f1f0063df006b23007bff00872b07a32f07bb3707d7ab"
	+ "0b23070b876f0b9f830bbb970f0b0b0f2f4f0f4f470f6b5b134b931353cb136f8f136faf173b0f174b63174faf176fcf"
	+ "1f1b1b1f1f1f1f1f271f4b0f2367772397a327572b2b1b172b6b1b2b93272b9bd32bdb232f23532f2f2f2f53af2f838b"
	+ "33334b336f8f336faf3373cf3700003737433783233b33073b332f3b33633b9f9f3f271f3f633b43270b434343474373"
	+ "474b4f4b0f834b53634f130f4f2b174f332f4f4f4f4f536f4f53874f73af4f93cf4fabb34fabcf533327536b53536b6f"
	+ "536f8f537347538f93538fb35393eb53a78f53afef5727005757575b23975b63975f130b5f17235f532f5f9b27631313"
	+ "633f0f63570b636f7f673b2f675f57676fa76797636b430f6b53af6b6b6b6b83576f37ab6f534f6f6f736f73af6f93cb"
	+ "736b53738faf73abb373af8f73afcf77231f772f177b23377b3f077b47377b8f9b7f170b7f53237f7f7f834fbf835713"
	+ "83936787231f8b7b0f8f332f8f533f8f93ab8faf539363379363d3938b53938b7b938f7393939393ab9393abb393af6f"
	+ "93cfef93ebd393eff397334797abaf9b271f9b530b9b675b9f1f0b9f5b2ba33f37a39b2ba3d72ba7473fa77713a777eb"
	+ "a7a7a7a7d75fab734baf8f53af8f6faf938faf97afaf9f13afb3afafb3efafb7cfb33f5bb3ab73b3ab93b3af53b3cbd3"
	+ "b3d3efb3ebd3b3eff7bb6b0bbbbbbbbf230fbf574fbf7f5fc3af17c3b3a3cb970fcbb7efcbcbcbcf4b6fcf7777cf8f53"
	+ "cf936fcf938fcfaf73cfb38fcfb3afcfb7cfcfd3d3cfd7efcff34fd38f73d3af53d3cb93d3cbb3d3cf53d3ebd3d3ebf3"
	+ "d3efb3d3f38fd7675fd78787d7c317db432fdf270fdf7f0fdfdfdfe36b97e39797eb634beb776feba7a7ebebebef9b27"
	+ "efdfcbf3934ff3936ff3938ff3b38ff3b3aff3b3cff3bb0ff3d3aff3d3cff793aff7af4ff7b36ff7cf93f7db13f7f3d3"
	+ "fafafafbcf4ffbcf73fbef6ffbef93fbefb3fdfdfdff2b0fff9713ffd327ffe71bffe747")

## The violets, every one in the palette.
const V_BLACK := Color8(31, 15, 47)
const V_1 := Color8(111, 55, 171)
const V_3 := Color8(147, 99, 211)
const V_4 := Color8(167, 119, 235)
const V_MID := Color8(91, 35, 151)
const V_PALE := Color8(203, 183, 239)
const V_WHITE := Color8(243, 223, 255)
const MOSS: Array[Color] = [Color8(31, 75, 15), Color8(47, 91, 23), Color8(71, 115, 31), Color8(99, 131, 39)]

var _palette: Array[Vector3i] = []
var _nearest := {}


func _initialize() -> void:
	quit(_main(OS.get_cmdline_user_args()))


func _main(argv: PackedStringArray) -> int:
	var out := OUT_DIR
	var i := 0
	while i < argv.size():
		match argv[i]:
			"-h", "--help":
				print(HELP)
				return 0
			"--version":
				print("%s — Shandalar %s" % [TOOL, LabConsole.version()])
				return 0
			"--out":
				if i + 1 >= argv.size():
					printerr("%s: --out needs a folder (try --help)" % TOOL)
					return 2
				out = argv[i + 1]
				i += 1
			_:
				printerr("%s: unknown argument '%s' (try --help)" % [TOOL, argv[i]])
				return 2
		i += 1
	_banner()
	var dir := ProjectSettings.globalize_path(out) if out.begins_with("res://") else out
	DirAccess.make_dir_recursive_absolute(dir)
	_load_palette()
	var failed := 0
	for state in ["open", "petrified"]:
		for scale in [1, 2]:
			var pictures := _draw_arch(state == "petrified", scale)
			var suffix := "" if scale == 1 else "@2x"
			failed += _write(pictures[0], dir, "world_portal_%s%s.png" % [state, suffix])
			failed += _write(pictures[1], dir, "world_portal_%s_ground%s.png" % [state, suffix])
	return 1 if failed > 0 else 0


## The family's banner, on stderr and only on a terminal
## (`DeckLab/lab_console.gd`): with `SHANDALAR_NO_BANNER` set, never.
func _banner() -> void:
	if not LabConsole.is_terminal() or OS.get_environment("SHANDALAR_NO_BANNER") != "" \
			or OS.get_environment(LabConsole.NO_BANNER_ENV) != "":
		return
	var colour := LabConsole.use_colour()
	for row in WORDMARK.size():
		var beside := ""
		if row < CAPTION.size():
			beside = LabConsole.paint(String(CAPTION[row]), LabConsole.DIM, colour)
		else:
			beside = LabConsole.paint(LabConsole.version(), LabConsole.DIM, colour)
		printerr("  " + LabConsole.paint(String(WORDMARK[row]), LabConsole.AMBER + LabConsole.BOLD, colour)
			+ "   " + beside)


func _write(img: Image, dir: String, filename: String) -> int:
	var path := dir.path_join(filename)
	var err := img.save_png(path)
	print("%s %s (%dx%d)" % ["wrote" if err == OK else "FAILED", path, img.get_width(), img.get_height()])
	return 0 if err == OK else 1


# ------------------------------------------------------------ the arch --

## The upright and the ground half of the arch, open or [param petrified],
## at [param scale] (1 or 2).
func _draw_arch(petrified: bool, scale: int) -> Array[Image]:
	var c := Canvas.new(scale)
	var glow := Canvas.new(scale)
	var ground := Canvas.new(scale)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23 if petrified else 19
	var face_l: Color
	var face_r: Color
	var side: Color
	var top_c: Color
	var slab: Array[Color]
	if petrified:
		face_l = Color8(183, 179, 171)
		face_r = Color8(151, 147, 139)
		side = Color8(95, 91, 87)
		top_c = Color8(211, 207, 199)
		slab = [Color8(159, 155, 147), Color8(127, 123, 115), Color8(91, 87, 83)]
	else:
		face_l = Color8(87, 83, 107)
		face_r = Color8(63, 59, 79)
		side = Color8(31, 27, 39)
		top_c = Color8(123, 119, 147)
		slab = [Color8(83, 79, 95), Color8(63, 59, 71), Color8(39, 35, 47)]
	# THE PLINTH: two steps, their shadow short.
	var plinth: Array[PackedVector2Array] = []
	plinth.append_array(_iso_slab(c, CX, CY - 6, 40, 20, 6, slab[0], slab[1], slab[2]))
	plinth.append_array(_iso_slab(c, CX, CY - 12, 31, 15.5, 6, _shade(slab[0], 1.06), slab[1], slab[2]))
	var shadow := c.union(_sheared(plinth, CY + 14))
	# THE ARCH, frontal.
	var base := CY - 12
	var spring := CY - 66
	var outer := PackedVector2Array([Vector2(CX - 24, base)])
	outer.append_array(_gothic(CX, spring, 24, 32))
	outer.append(Vector2(CX + 24, base))
	var inner := PackedVector2Array([Vector2(CX - 12, base)])
	inner.append_array(_gothic(CX, spring + 2, 12, 22))
	inner.append(Vector2(CX + 12, base))
	var solid: Array[PackedVector2Array] = [outer,
		_horn(Vector2(CX - 18, spring - 14), Vector2(CX - 33, spring - 42), Vector2(-7, 4), 7),
		PackedVector2Array([Vector2(CX - 4, spring - 30), Vector2(CX, spring - 46), Vector2(CX + 4, spring - 30)])]
	if petrified:  # the right horn broken off
		solid.append(_horn(Vector2(CX + 18, spring - 14), Vector2(CX + 26, spring - 24), Vector2(4, 2), 7))
	else:
		solid.append(_horn(Vector2(CX + 18, spring - 14), Vector2(CX + 33, spring - 42), Vector2(7, 4), 7))
	var frame := c.minus(c.union(solid), c.cover(inner))
	# THE VOID — or its stone plug — behind the frame.
	var hollow := c.union([inner, _moved(inner, Vector2(3, -1.5))])
	if petrified:
		c.paint_ramp(hollow, spring - 20, base, Color8(119, 115, 109), Color8(99, 95, 91))
		for k in 2:
			var r := 9.0 if k == 0 else 5.0
			c.paint(c.times(c.stroke(_gothic(CX + 3, spring + 6 + k * 4, r, r * 1.6), 1.1), hollow), Color8(71, 67, 63))
		var spiral := PackedVector2Array()
		for k in 40:
			var a := k * 0.32
			var rr := 1.0 + k * 0.22
			spiral.append(Vector2(CX + 3 + cos(a) * rr, base - 26 + sin(a) * rr * 1.5))
		c.paint(c.times(c.stroke(spiral, 1.0), hollow), Color8(75, 71, 67))
		c.paint(c.times(c.cover(_ellipse(CX + 3, base - 22, 3, 3)), hollow), Color8(99, 95, 91))
		c.paint(c.times(c.stroke(PackedVector2Array([Vector2(CX - 2, base - 6), Vector2(CX + 6, base - 14),
			Vector2(CX + 3, base - 24)]), 0.8), hollow), Color8(83, 79, 75))
	else:
		_swirl(c, CX + 3, base - 36, 15, 44, 2, 4.0, 1.0, hollow)
	# THE DEPTH: the frame stepped back up and to the right.
	for t in range(6, 0, -1):
		var stepped: Array[PackedVector2Array] = []
		for poly in solid:
			stepped.append(_moved(poly, Vector2(t, -t * 0.5)))
		var back := c.minus(c.union(stepped), c.cover(_moved(inner, Vector2(t, -t * 0.5))))
		c.paint(back, side if t > 1 else _shade(side, 1.25))
	# THE FACE, the right half a step darker, the left edge lit.
	c.paint_ramp(frame, spring - 46, base, _shade(face_l, 1.05), _shade(face_l, 0.9))
	var right := c.cover(PackedVector2Array([Vector2(CX, 0), Vector2(FRAME, 0), Vector2(FRAME, FRAME), Vector2(CX, FRAME)]))
	c.paint_ramp(c.times(frame, right), spring - 46, base, face_r, _shade(face_r, 0.85))
	var shifted: Array[PackedVector2Array] = []
	for poly in solid:
		shifted.append(_moved(poly, Vector2(1.2, 0)))
	var edge := c.minus(frame, c.minus(c.union(shifted), c.cover(_moved(inner, Vector2(1.2, 0)))))
	c.paint(c.minus(edge, right), top_c)
	for x in [CX - 18, CX + 18]:
		for y in [base - 14, base - 30, base - 46]:
			c.paint(c.stroke(PackedVector2Array([Vector2(x - 5, y), Vector2(x + 5, y)]), 0.6), _shade(face_l, 0.7))
	if petrified:
		for line in [[Vector2(CX - 20, spring - 8), Vector2(CX - 16, spring + 4), Vector2(CX - 19, spring + 14)],
				[Vector2(CX + 15, base - 20), Vector2(CX + 19, base - 30), Vector2(CX + 17, base - 38)],
				[Vector2(CX - 3, spring - 26), Vector2(CX + 2, spring - 18)]]:
			c.paint(c.times(c.stroke(PackedVector2Array(line), 0.8), frame), Color8(79, 75, 71))
		for moss in [[CX - 22, spring - 18, 3.0], [CX + 2, spring - 31, 2.5], [CX - 30, CY - 8, 4.0],
				[CX + 26, CY - 4, 3.5], [CX - 10, CY - 15, 2.5], [CX + 17, base - 2, 2.5]]:
			var r: float = moss[2]
			c.paint(c.cover(_ellipse(moss[0], moss[1], r, r * 0.55)), MOSS[rng.randi_range(0, 3)])
		for k in 5:
			_rock(ground, CX + 30 + k * 4 + rng.randf_range(-2, 2), CY + 2 - k * 2 + rng.randf_range(-1, 2),
				rng.randf_range(1.6, 3.0), 23 + k, Color8(151, 147, 139), Color8(99, 95, 91))
	else:
		for x in [CX - 18, CX + 18]:
			for y in [base - 22, base - 38]:
				c.paint(c.stroke(PackedVector2Array([Vector2(x - 2, y - 3), Vector2(x + 1, y), Vector2(x - 2, y + 3)]),
					0.8), V_4)
		var ring: Array[PackedVector2Array] = []
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			ring.append(_moved(inner, d))
		c.paint(c.times(c.minus(c.union(ring), c.cover(inner)), frame), V_3, 0.8)
		glow.paint(c.times(c.cover(_moved(inner, Vector2(1.5, -0.7))), c.ramp(spring - 20, base, 0.15, 0.45)), V_4)
		var sparks := RandomNumberGenerator.new()
		sparks.seed = 22
		for k in 7:
			var at := Vector2(CX + sparks.randf_range(-10, 14), base - sparks.randf_range(4, 50))
			glow.paint(c.cover(_ellipse(at.x, at.y, 0.6, 0.6)), V_PALE if sparks.randi_range(0, 1) == 0 else V_WHITE)
	var cast: Array[PackedVector2Array] = solid.duplicate()
	shadow = c.union([shadow, c.union(_sheared(cast, base))])
	var pool := PackedFloat32Array()
	if not petrified:
		pool = c.radial(CX - 10, CY + 14, 36, 16, 0.1, 0.8)
	var upright := _finish(c, glow if not petrified else null, scale, 101 + scale + (10 if petrified else 0))
	var half := _finish_ground(ground, shadow, pool, V_MID, scale, 201 + scale + (10 if petrified else 0))
	return [upright, half]


## A stone slab seen from above at an angle: its top diamond and its two
## faces, painted; the polygons returned for its shadow.
func _iso_slab(c: Canvas, x: float, y: float, hw: float, hh: float, thick: float,
		top: Color, left: Color, right: Color) -> Array[PackedVector2Array]:
	var t := PackedVector2Array([Vector2(x - hw, y), Vector2(x, y - hh), Vector2(x + hw, y), Vector2(x, y + hh)])
	var lf := PackedVector2Array([Vector2(x - hw, y), Vector2(x, y + hh), Vector2(x, y + hh + thick), Vector2(x - hw, y + thick)])
	var rf := PackedVector2Array([Vector2(x, y + hh), Vector2(x + hw, y), Vector2(x + hw, y + thick), Vector2(x, y + hh + thick)])
	c.paint(c.cover(lf), left)
	c.paint(c.cover(rf), right)
	c.paint(c.cover(t), top)
	return [t, lf, rf]


## A pointed arch's outline from its left spring over the apex to its right
## spring: two arcs whose centres sit inside the span, [param rise] high.
static func _gothic(x: float, spring: float, half: float, rise: float, steps := 10) -> PackedVector2Array:
	var off := half * 0.35
	var r := half + off
	var apex := sqrt(maxf(0.0, r * r - off * off))
	var pts := PackedVector2Array()
	var a_left := atan2(apex, -off)
	for i in steps + 1:
		var a := PI - (PI - a_left) * i / steps
		pts.append(Vector2(x + off + r * cos(a), spring - r * sin(a) * rise / apex))
	var a_right := atan2(apex, off)
	for i in range(1, steps + 1):
		var a := a_right - a_right * i / steps
		pts.append(Vector2(x - off + r * cos(a), spring - r * sin(a) * rise / apex))
	return pts


## A curved horn tapering from [param from] to [param to].
static func _horn(from: Vector2, to: Vector2, bend: Vector2, width: float, steps := 8) -> PackedVector2Array:
	var mid := (from + to) / 2 + bend
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var p := from * (1 - t) * (1 - t) + mid * 2 * (1 - t) * t + to * t * t
		var d := (mid - from) * 2 * (1 - t) + (to - mid) * 2 * t
		var n := d.normalized()
		var w := width * (1 - t) / 2
		left.append(p + Vector2(-n.y, n.x) * w)
		right.append(p + Vector2(n.y, -n.x) * w)
	right.reverse()
	left.append_array(right)
	return left


static func _ellipse(x: float, y: float, rx: float, ry: float, steps := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		pts.append(Vector2(x + cos(a) * rx, y + sin(a) * ry))
	return pts


static func _moved(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p + by)
	return out


## Polygons' shadow thrown up and to the right from the foot row [param foot].
static func _sheared(polys: Array[PackedVector2Array], foot: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly in polys:
		var cast := PackedVector2Array()
		for p in poly:
			var height := foot - p.y
			cast.append(Vector2(p.x + SHEAR.x * height, foot - SHEAR.y * height))
		out.append(cast)
	return out


static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1))


## A small rock, lit from the top left.
func _rock(c: Canvas, x: float, y: float, r: float, seed: int, lit: Color, dark: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := rng.randi_range(5, 7)
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.3, 0.3)
		var rr := r * rng.randf_range(0.65, 1.1)
		pts.append(Vector2(x + cos(a) * rr, y + sin(a) * rr * 0.8))
	var m := c.cover(pts)
	c.paint(m, dark)
	c.paint(c.times(m, c.cover(PackedVector2Array([Vector2(x - r * 2, y - r * 2), Vector2(x + r * 0.4, y - r * 2),
		Vector2(x - r * 0.3, y + r * 0.3), Vector2(x - r * 2, y + r)]))), lit)


## The void: a swirl of [param arms] arms in an ellipse, the light at its
## heart, through [param clip].
func _swirl(c: Canvas, x: float, y: float, rx: float, ry: float, arms: int, twist: float, phase: float,
		clip: PackedFloat32Array) -> void:
	var m := c.times(c.cover(_ellipse(x, y, rx, ry, 64)), clip)
	for py in c.h:
		for px in c.w:
			var k := py * c.w + px
			if m[k] <= 0.0:
				continue
			var u := ((px + 0.5) / c.s - x) / rx
			var v := ((py + 0.5) / c.s - y) / ry
			var r := minf(1.0, sqrt(u * u + v * v))
			var sv := sin(arms * (atan2(v, u) + twist * r) + phase)
			var arm := pow((sv + 1.0) / 2.0, 2.2)
			var col := V_BLACK.lerp(V_1, arm * pow(1.0 - r, 0.5))
			col = col.lerp(V_4, clampf(maxf(0.0, arm - 0.55) * 2.0 * pow(1.0 - r, 0.7), 0, 1))
			if r < 0.22:
				col = V_WHITE.lerp(V_PALE, r / 0.22)
			elif r > 0.84:
				col = col.lerp(V_3, (r - 0.84) / 0.16)
			c.over(k, col, m[k])


# --------------------------------------------------------- finishing --

func _load_palette() -> void:
	_palette.clear()
	var raw := PALETTE_HEX.hex_decode()
	for i in range(0, raw.size(), 3):
		_palette.append(Vector3i(raw[i], raw[i + 1], raw[i + 2]))


func _nearest_colour(r: int, g: int, b: int) -> Vector3i:
	var key := ((r >> 2) << 12) | ((g >> 2) << 6) | (b >> 2)
	if _nearest.has(key):
		return _nearest[key]
	var best := _palette[0]
	var best_d := 1 << 30
	for p in _palette:
		var d := (p.x - r) * (p.x - r) * 3 + (p.y - g) * (p.y - g) * 4 + (p.z - b) * (p.z - b) * 2
		if d < best_d:
			best_d = d
			best = p
	_nearest[key] = best
	return best


static func _bayer(x: int, y: int, scale: int) -> float:
	return (BAYER[(y / scale) % 4][(x / scale) % 4] + 0.5) / 16.0


## THE UPRIGHT, finished: grain, solid at half coverage, the silhouette's
## edge darkened, the glow over it (blended on the solid, Bayer-dithered
## off it), the palette at 1x.
func _finish(c: Canvas, glow: Canvas, scale: int, seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var w := c.w
	var h := c.h
	# stone grain: coarse blotches, then a fine one
	var cell := 2 * scale
	var gw := w / cell + 2
	var gh := h / cell + 2
	var blot := PackedFloat32Array()
	blot.resize(gw * gh)
	for i in blot.size():
		blot[i] = rng.randfn(0.0, 16.0 / 255.0)
	var rgb := PackedFloat32Array()
	rgb.resize(w * h * 3)
	var on := PackedByteArray()
	on.resize(w * h)
	for y in h:
		for x in w:
			var k := y * w + x
			if c.a[k] < 0.5:
				continue
			on[k] = 1
			var fx := float(x) / cell
			var fy := float(y) / cell
			var ix := int(fx)
			var iy := int(fy)
			var tx := fx - ix
			var ty := fy - iy
			var n := lerpf(lerpf(blot[iy * gw + ix], blot[iy * gw + ix + 1], tx),
				lerpf(blot[(iy + 1) * gw + ix], blot[(iy + 1) * gw + ix + 1], tx), ty)
			for ch in 3:
				rgb[k * 3 + ch] = (c.rgb[k * 3 + ch] + n) * 255.0
	# the outline: the silhouette's own edge pixels, darker
	var rings: Array = [[1, 0.55]] if scale == 1 else [[1, 0.5], [2, 0.78]]
	for y in h:
		for x in w:
			var k := y * w + x
			if on[k] == 0:
				continue
			for ring in rings:
				var dist: int = ring[0]
				var edge := false
				for d in [Vector2i(dist, 0), Vector2i(-dist, 0), Vector2i(0, dist), Vector2i(0, -dist)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h or on[ny * w + nx] == 0:
						edge = true
						break
				if edge:
					for ch in 3:
						rgb[k * 3 + ch] *= float(ring[1])
					break
	var amp := 9.0 if scale == 1 else 6.0
	for k in w * h:
		if on[k] != 0:
			var n := rng.randfn(0.0, amp)
			for ch in 3:
				rgb[k * 3 + ch] += n
	if glow != null:
		for k in w * h:
			var ga := glow.a[k]
			if ga <= 0.0:
				continue
			if on[k] != 0:
				for ch in 3:
					rgb[k * 3 + ch] = lerpf(rgb[k * 3 + ch], glow.rgb[k * 3 + ch] * 255.0, ga)
			elif ga > _bayer(k % w, k / w, scale):
				on[k] = 1
				for ch in 3:
					rgb[k * 3 + ch] = glow.rgb[k * 3 + ch] * 255.0
	return _image(rgb, on, w, h, scale)


## THE GROUND HALF: the shadow as the 1997 checker, the light pool as a
## Bayer-dithered violet, the rubble solid over both.
func _finish_ground(ground: Canvas, shadow: PackedFloat32Array, pool: PackedFloat32Array, pool_ink: Color,
		scale: int, seed: int) -> Image:
	var w := ground.w
	var h := ground.h
	var decal := _finish(ground, null, scale, seed)
	var rgb := PackedFloat32Array()
	rgb.resize(w * h * 3)
	var on := PackedByteArray()
	on.resize(w * h)
	for y in h:
		for x in w:
			var k := y * w + x
			var ink := Color(0, 0, 0, 0)
			var px := decal.get_pixel(x, y)
			if px.a > 0.5:
				ink = px
			elif shadow[k] >= 0.5 and ((x / scale) + (y / scale)) % 2 == 1:
				ink = SHADOW
			elif not pool.is_empty() and pool[k] > 0.0 and pool[k] * 0.5 > _bayer(x, y, scale):
				ink = pool_ink
			if ink.a > 0.5:
				on[k] = 1
				rgb[k * 3] = ink.r * 255.0
				rgb[k * 3 + 1] = ink.g * 255.0
				rgb[k * 3 + 2] = ink.b * 255.0
	return _image(rgb, on, w, h, scale)


## The picture: at 1x reduced to the palette with Floyd–Steinberg error
## diffusion among its own opaque pixels; at 2x as it is.
func _image(rgb: PackedFloat32Array, on: PackedByteArray, w: int, h: int, scale: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var k := y * w + x
			if on[k] == 0:
				continue
			var r := clampi(roundi(rgb[k * 3]), 0, 255)
			var g := clampi(roundi(rgb[k * 3 + 1]), 0, 255)
			var b := clampi(roundi(rgb[k * 3 + 2]), 0, 255)
			if scale == 1:
				var p := _nearest_colour(r, g, b)
				var err := [rgb[k * 3] - p.x, rgb[k * 3 + 1] - p.y, rgb[k * 3 + 2] - p.z]
				for spread in [[1, 0, 7.0], [-1, 1, 3.0], [0, 1, 5.0], [1, 1, 1.0]]:
					var nx: int = x + spread[0]
					var ny: int = y + spread[1]
					if nx < 0 or nx >= w or ny >= h or on[ny * w + nx] == 0:
						continue
					var nk := ny * w + nx
					for ch in 3:
						rgb[nk * 3 + ch] += float(err[ch]) * float(spread[2]) / 16.0
				r = p.x
				g = p.y
				b = p.z
			img.set_pixel(x, y, Color8(r, g, b, 255))
	return img


# ------------------------------------------------------------ the canvas --

## A frame at its final size: straight-alpha colour, and the coverage
## masks every shape is rasterised into.
class Canvas:
	var w: int
	var h: int
	## Pixels per 1x unit.
	var s: float
	var rgb := PackedFloat32Array()
	var a := PackedFloat32Array()

	func _init(scale: int) -> void:
		s = scale
		w = FRAME * scale
		h = FRAME * scale
		rgb.resize(w * h * 3)
		a.resize(w * h)

	## Polygon [param poly] (1x units) as coverage: four scanlines a pixel,
	## each span's coverage exact across.
	func cover(poly: PackedVector2Array) -> PackedFloat32Array:
		var m := PackedFloat32Array()
		m.resize(w * h)
		_cover_into(m, poly)
		return m

	## [method cover] laid into [param m] where it covers more (a union),
	## worked over the polygon's own rows and columns only.
	func _cover_into(m: PackedFloat32Array, poly: PackedVector2Array) -> void:
		var n := poly.size()
		if n < 3:
			return
		var pts := PackedVector2Array()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in poly:
			var q := p * s
			pts.append(q)
			lo = lo.min(q)
			hi = hi.max(q)
		var row0 := maxi(0, floori(lo.y))
		var row1 := mini(h - 1, ceili(hi.y))
		var col0 := maxi(0, floori(lo.x))
		var col1 := mini(w - 1, ceili(hi.x))
		if row1 < row0 or col1 < col0:
			return
		var weight := 1.0 / SS
		var line := PackedFloat32Array()
		line.resize(w)
		for py in range(row0, row1 + 1):
			for x in range(col0, col1 + 1):
				line[x] = 0.0
			for sub in SS:
				var y := py + (sub + 0.5) / SS
				var xs := PackedFloat32Array()
				for i in n:
					var p0 := pts[i]
					var p1 := pts[(i + 1) % n]
					if (p0.y <= y and p1.y > y) or (p1.y <= y and p0.y > y):
						xs.append(p0.x + (y - p0.y) * (p1.x - p0.x) / (p1.y - p0.y))
				xs.sort()
				for i in range(0, xs.size() - 1, 2):
					_span(line, xs[i], xs[i + 1], weight)
			var at := py * w
			for x in range(col0, col1 + 1):
				var v := minf(1.0, line[x])
				if v > m[at + x]:
					m[at + x] = v

	func _span(line: PackedFloat32Array, xa: float, xb: float, weight: float) -> void:
		xa = clampf(xa, 0.0, w)
		xb = clampf(xb, 0.0, w)
		if xb <= xa:
			return
		var ia := floori(xa)
		var ib := floori(xb)
		if ia == ib:
			line[ia] += (xb - xa) * weight
			return
		line[ia] += (ia + 1 - xa) * weight
		for i in range(ia + 1, ib):
			line[i] += weight
		if ib < w:
			line[ib] += (xb - ib) * weight

	## A stroke [param width] wide along [param line]: its segments as
	## quads, its joints and ends as small discs.
	func stroke(line: PackedVector2Array, width: float) -> PackedFloat32Array:
		var parts: Array[PackedVector2Array] = []
		var r := width / 2.0
		for i in line.size() - 1:
			var d := (line[i + 1] - line[i]).normalized()
			var n := Vector2(-d.y, d.x) * r
			parts.append(PackedVector2Array([line[i] + n, line[i + 1] + n, line[i + 1] - n, line[i] - n]))
		for p in line:
			parts.append(_disc(p, r))
		return union(parts)

	static func _disc(at: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 12:
			pts.append(at + Vector2(cos(TAU * i / 12), sin(TAU * i / 12)) * r)
		return pts

	## The union of polygons, or of masks.
	func union(parts: Array) -> PackedFloat32Array:
		var m := PackedFloat32Array()
		m.resize(w * h)
		for part in parts:
			if part is PackedVector2Array:
				_cover_into(m, part)
				continue
			var other: PackedFloat32Array = part
			for k in m.size():
				if other[k] > m[k]:
					m[k] = other[k]
		return m

	func minus(m: PackedFloat32Array, cut: PackedFloat32Array) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		out.resize(w * h)
		for k in out.size():
			out[k] = m[k] * (1.0 - cut[k])
		return out

	func times(m: PackedFloat32Array, by: PackedFloat32Array) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		out.resize(w * h)
		for k in out.size():
			out[k] = m[k] * by[k]
		return out

	## A mask of the rows from [param y0] (value [param a0]) to [param y1]
	## (value [param a1]), 1x units.
	func ramp(y0: float, y1: float, a0: float, a1: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		out.resize(w * h)
		for py in h:
			var y := (py + 0.5) / s
			var t := clampf((y - y0) / maxf(0.001, y1 - y0), 0.0, 1.0)
			var v := lerpf(a0, a1, t)
			for px in w:
				out[py * w + px] = v
		return out

	## An ellipse's mask falling from [param v_in] at its middle to
	## [param v_out] at its rim.
	func radial(x: float, y: float, rx: float, ry: float, v_out: float, v_in: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		out.resize(w * h)
		for py in h:
			for px in w:
				var u := ((px + 0.5) / s - x) / rx
				var v := ((py + 0.5) / s - y) / ry
				var r := sqrt(u * u + v * v)
				if r <= 1.0:
					out[py * w + px] = lerpf(v_out, v_in, clampf((1.0 - r) / 0.92, 0.0, 1.0))
		return out

	## Colour [param ink] laid over the canvas through mask [param m].
	func paint(m: PackedFloat32Array, ink: Color, alpha := 1.0) -> void:
		for k in m.size():
			if m[k] > 0.0:
				over(k, ink, m[k] * alpha)

	## A vertical ramp from [param c0] at [param y0] to [param c1] at
	## [param y1] laid through [param m].
	func paint_ramp(m: PackedFloat32Array, y0: float, y1: float, c0: Color, c1: Color) -> void:
		for k in m.size():
			if m[k] > 0.0:
				var y := (k / w + 0.5) / s
				over(k, c0.lerp(c1, clampf((y - y0) / maxf(0.001, y1 - y0), 0.0, 1.0)), m[k])

	## Pixel [param k] with [param ink] over it at [param alpha].
	func over(k: int, ink: Color, alpha: float) -> void:
		var da := a[k]
		var oa := alpha + da * (1.0 - alpha)
		if oa <= 0.0:
			return
		rgb[k * 3] = (ink.r * alpha + rgb[k * 3] * da * (1.0 - alpha)) / oa
		rgb[k * 3 + 1] = (ink.g * alpha + rgb[k * 3 + 1] * da * (1.0 - alpha)) / oa
		rgb[k * 3 + 2] = (ink.b * alpha + rgb[k * 3 + 2] * da * (1.0 - alpha)) / oa
		a[k] = oa
