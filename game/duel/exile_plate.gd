class_name ExilePlate
extends RefCounted
## The EMPTY-EXILE plate — the pile beside the graveyard, "out of play".
##
## DERIVED ART, NOT ORIGINAL. Every other plate on the duel table comes
## out of the 1997 game through tools/import_original.py; this one cannot,
## because the original never drew one. The 1997 UI reached the exile pile
## through the graveyard's own right-click menu — `@MENU_GRAVEYARD`
## (`Program/UIStrings.txt:901`): "View the graveyard / View exiled cards /
## View both antes / Help..." — and `Duel.hlp` (the shipped 1997 help file,
## dated 11 Nov 1997) says so outright: *"You can also right-click on
## either graveyard to see a reminder of what cards you and your opponent
## have put up as ante or to view cards removed from the game."* Neither
## the original art tree (`Program/DuelArt/`), the Manalink sources, nor
## the s30 re-release holds an exile plate of any kind: `Grave_<Colour>` is
## the only pile art that exists. A visible exile pile is therefore the
## owner's DELIBERATE DIVERGENCE ([QoL], docs/duel-screen-design.md), and
## its plate has to be made rather than found.
##
## WHAT IS DERIVED, AND FROM WHAT. The composition is ours; the material
## is not. The plate is painted at the graveyard plate's own size (61x91,
## a 1px white border around 59x89 of art, exactly as `Grave_*.pic.png` is
## built) and EVERY COLOUR IS SAMPLED FROM THAT SEAT'S OWN GRAVE PLATE —
## the five originals are tiny-palette woodcuts (Green has four art
## colours, Red nine), so borrowing their palette wholesale is what keeps
## the pair looking like two halves of one 1997 asset instead of a period
## painting next to a modern one. No grave plate in the skin, no exile
## plate either: the two piles appear and disappear together.
##
## THE SCENE is the 1997 manual's own words for the zone (p.118, quoted in
## docs/glossary-1997.md): cards removed from the game go to the "out of
## play" area. So: a card standing in the void, its right-hand side already
## eaten away, the motes it sheds drifting off across a speckled ground.
## One composition serves all five palettes because it is drawn entirely in
## light/dark relationships, and it is drawn the way the duel's own mini
## cards are read — an art box over three text lines — so the silhouette is
## unmistakably A CARD at the 40x60 the sidebar shows it at.

## Cache: seat colour name -> plate texture (or null when there is no skin).
static var _cache: Dictionary = {}

## Ordered 4x4 dither (Bayer), the era's own way of making a gradient out
## of a handful of colours — the grave plates dither for exactly this
## reason. Values 0..15 compared against a 0..16 threshold.
const BAYER := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]


## The empty-exile plate for a seat colour ("white", "blue", "black",
## "red", "green"), or null when the original skin is absent — the same
## condition that leaves the seat with no graveyard plate.
static func plate(seat_color: String) -> Texture2D:
	if _cache.has(seat_color):
		return _cache[seat_color]
	var result: Texture2D = null
	var grave := GameSkin.texture("grave_panel_" + seat_color)
	if grave != null:
		result = ImageTexture.create_from_image(_paint(grave.get_image()))
	_cache[seat_color] = result
	return result


## The seat's palette, darkest first: the art colours of its grave plate
## (the 1px white border is skipped), keeping only those that carry at
## least 3% of the art — the rare speckle colours in a dithered 1997 image
## are noise, and picking one for the card face gives a red plate a pink
## card. A plate with fewer than three body colours (none of the five, but
## the guard is free) keeps all of them.
static func _palette(src: Image) -> Array[Color]:
	var counts: Dictionary = {}
	var total := 0
	for y in range(1, src.get_height() - 1):
		for x in range(1, src.get_width() - 1):
			var key := src.get_pixel(x, y).to_rgba32()
			counts[key] = int(counts.get(key, 0)) + 1
			total += 1
	var out: Array[Color] = []
	for key in counts:
		if float(counts[key]) / float(maxi(total, 1)) >= 0.03:
			out.append(Color.hex(int(key)))
	if out.size() < 3:
		out.clear()
		for key in counts:
			out.append(Color.hex(int(key)))
	out.sort_custom(func(a: Color, b: Color) -> bool:
		return a.get_luminance() < b.get_luminance())
	return out


## Pick the [param fraction]-th colour along the palette's luminance ramp
## (0.0 = darkest, 1.0 = lightest). Small palettes simply repeat entries,
## which is what makes the four-colour Green plate work at all.
static func _step(palette: Array[Color], fraction: float) -> Color:
	if palette.is_empty():
		return Color.BLACK
	var i := int(round(fraction * (palette.size() - 1)))
	return palette[clampi(i, 0, palette.size() - 1)]


## A deterministic 0..15 value per pixel — the plate must be identical in
## every run and on every machine, so this stands in for a random number
## generator (which engine purity would not allow here anyway).
static func _speck(x: int, y: int) -> int:
	var v: int = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
	return (v >> 16) & 15


## Paint the plate at the grave plate's own size and border geometry.
##
## THE SCENE: a card standing in the void, its right-hand side already
## eaten away, the motes it sheds drifting off into a field of specks. The
## card is drawn the way the duel's own mini cards are read — an art box
## above three text lines — so the silhouette is unmistakably A CARD even
## at the 40x60 the sidebar shows it at.
static func _paint(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var palette := _palette(src)
	# Five roles taken as FRACTIONS of the ramp, so a four-colour palette
	# (Green) and a ten-colour one (Blue) both fill them.
	var void_tone := _step(palette, 0.0)
	var deep := _step(palette, 0.16)
	var mid := _step(palette, 0.42)
	var pale := _step(palette, 0.72)
	var rim := _step(palette, 1.0)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)   # the 1px border every Grave_* plate wears

	var cx := w * 0.5
	var card_x0 := int(w * 0.18)
	var card_x1 := int(w * 0.72)
	var card_y0 := int(h * 0.17)
	var card_y1 := int(h * 0.82)
	var cw := float(card_x1 - card_x0)
	var ch := float(card_y1 - card_y0)

	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var bayer: int = BAYER[y % 4][x % 4]
			# THE VOID, with a faint speckle that thickens behind the card
			# — a ground, not a flat rectangle.
			var dxh := (x - cx) / (w * 0.62)
			var dyh := (y - h * 0.5) / (h * 0.62)
			var halo := maxf(0.0, 1.0 - (dxh * dxh + dyh * dyh))
			var c := void_tone
			if _speck(x, y) < halo * halo * 5.0 + 0.6:
				c = deep
			# The card's shadow, down-left, lifting it off the ground.
			if x >= card_x0 - 2 and x < card_x1 - 2 \
					and y >= card_y0 + 2 and y < card_y1 + 2 \
					and not (x >= card_x0 and x < card_x1
						and y >= card_y0 and y < card_y1):
				c = void_tone
			# THE CARD, dissolving away to the right and upward.
			if x >= card_x0 and x < card_x1 and y >= card_y0 and y < card_y1:
				var fx := (x - card_x0) / cw
				var fy := (y - card_y0) / ch
				var gone := clampf((fx * 0.78 + (1.0 - fy) * 0.22 - 0.42) * 3.1,
					0.0, 1.0)
				# Ordered dither for the fade, hash-jittered so the edge
				# crumbles instead of running in a ruled diagonal.
				if bayer >= gone * 16.0 + (_speck(x, y) - 8) * 0.55:
					var edge := x == card_x0 or x == card_x1 - 1 \
						or y == card_y0 or y == card_y1 - 1
					var inside := x >= card_x0 + 3 and x < card_x1 - 3
					var art := inside and y >= card_y0 + 5 \
						and y < card_y0 + int(ch * 0.44)
					var line := inside and (
						(y >= card_y0 + int(ch * 0.58) and y < card_y0 + int(ch * 0.63))
						or (y >= card_y0 + int(ch * 0.71) and y < card_y0 + int(ch * 0.76))
						or (y >= card_y0 + int(ch * 0.84) and y < card_y0 + int(ch * 0.89)))
					c = mid if (edge or art or line) else pale
			img.set_pixel(x, y, c)
	# The motes themselves: what has already come off the card. Fixed
	# positions — nothing on this plate is random.
	for mote: Vector2 in [Vector2(0.78, 0.28), Vector2(0.86, 0.16),
			Vector2(0.70, 0.10), Vector2(0.92, 0.36), Vector2(0.82, 0.46),
			Vector2(0.66, 0.05), Vector2(0.94, 0.22), Vector2(0.74, 0.38)]:
		var mx: int = int(w * mote.x)
		var my: int = int(h * mote.y)
		if mx > 0 and mx < w - 1 and my > 0 and my < h - 1:
			img.set_pixel(mx, my, rim)
	return img
