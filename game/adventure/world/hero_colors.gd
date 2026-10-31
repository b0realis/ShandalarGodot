class_name HeroColors
extends RefCounted
## THE WALKING FIGURE'S COLOURS (the owner, 2026-10-22: *"can we make the
## walking figure be colored — boots, pants, body, arms, hair, skin? And
## this be one of the choices in the adventure menu starting screen? And
## randomized also?"*) [QoL]. The 1997 figure (`EGO_M`, `EGO_F`) is one
## painted sprite, so its parts are found by their colours and their height
## in the figure, on the player's own sheets as the game reads them — never
## stored apart:
##  - black high in the figure is hair, black low is boots, and the dark
##    browns high are the hair's light;
##  - the warm tones are skin, the whites and greys are the sleeves;
##  - the man's red vest and the woman's blue bodice (its purple, its blue
##    cuffs) are the body; his blue trousers and her green skirt the pants;
##  - his green cuffs and belt and her red sash are trim, left as they are.
## A part is dressed in a colour by laying its shades, darkest to lightest,
## along that colour's own ramp, so the 1997 shading stays — the part's
## usual shade on the colour itself, so a part looks the colour chosen.

## The parts, in the order the Embark screen shows them.
const PARTS: Array[String] = ["hair", "skin", "body", "arms", "pants", "boots"]
const PART_NAMES: Array[String] = ["Hair", "Skin", "Body", "Arms", "Pants", "Boots"]
## The 1997 colours, the choice that leaves a part as it was painted.
const ORIGINAL := "1997"

## Each part's choices: `[key, name, colour]`, the 1997 colour first (its
## colour the one painted, for the swatch: the man's, then the woman's).
const HAIR: Array = [["black", "Black", Color8(28, 24, 24)], ["brown", "Brown", Color8(92, 58, 34)],
	["chestnut", "Chestnut", Color8(128, 64, 30)], ["auburn", "Auburn", Color8(150, 52, 32)],
	["red", "Red", Color8(196, 74, 36)], ["blond", "Blond", Color8(222, 186, 92)],
	["platinum", "Platinum", Color8(232, 224, 196)], ["white", "White", Color8(236, 236, 236)],
	["grey", "Grey", Color8(140, 140, 146)], ["blue", "Blue", Color8(60, 100, 210)],
	["green", "Green", Color8(52, 150, 70)], ["violet", "Violet", Color8(132, 68, 180)]]
const SKIN: Array = [["pale", "Pale", Color8(250, 218, 200)], ["fair", "Fair", Color8(240, 190, 156)],
	["olive", "Olive", Color8(200, 156, 108)], ["tan", "Tan", Color8(186, 128, 84)],
	["brown", "Brown", Color8(140, 90, 56)], ["dark", "Dark", Color8(96, 60, 38)],
	["green", "Orcish green", Color8(112, 160, 84)], ["blue", "Elemental blue", Color8(110, 150, 220)],
	["grey", "Stone grey", Color8(150, 150, 156)]]
const CLOTH: Array = [["white", "White", Color8(236, 236, 230)], ["grey", "Grey", Color8(140, 140, 146)],
	["black", "Black", Color8(40, 38, 40)], ["red", "Red", Color8(200, 40, 30)],
	["crimson", "Crimson", Color8(140, 20, 40)], ["orange", "Orange", Color8(226, 116, 30)],
	["gold", "Gold", Color8(214, 168, 60)], ["yellow", "Yellow", Color8(236, 214, 70)],
	["green", "Green", Color8(40, 170, 60)], ["forest", "Forest", Color8(30, 96, 44)],
	["teal", "Teal", Color8(30, 140, 140)], ["sky", "Sky", Color8(100, 170, 236)],
	["blue", "Blue", Color8(30, 70, 200)], ["navy", "Navy", Color8(20, 32, 96)],
	["purple", "Purple", Color8(110, 50, 160)], ["brown", "Brown", Color8(110, 70, 36)],
	["tan", "Tan", Color8(196, 160, 110)]]
## The colours the 1997 figures wear, by part: the man's, then the woman's.
const PAINTED := {"hair": [Color8(31, 31, 31), Color8(15, 11, 11)],
	"skin": [Color8(211, 143, 115), Color8(243, 179, 143)],
	"body": [Color8(191, 35, 15), Color8(19, 83, 203)],
	"arms": [Color8(223, 223, 223), Color8(235, 235, 235)],
	"pants": [Color8(0, 51, 151), Color8(7, 187, 55)],
	"boots": [Color8(31, 31, 31), Color8(15, 11, 11)]}


## A part's choices, the 1997 colour not among them.
static func choices(part: String) -> Array:
	match part:
		"hair":
			return HAIR
		"skin":
			return SKIN
	return CLOTH


## The choice [param key] of [param part], `[key, name, colour]`, or [] for
## the 1997 colour (or a key no longer offered).
static func choice(part: String, key: String) -> Array:
	for row in choices(part):
		if row[0] == key:
			return row
	return []


## The name shown for [param part]'s [param key].
static func choice_name(part: String, key: String) -> String:
	var row := choice(part, key)
	return String(row[1]) if not row.is_empty() else "As in 1997"


## The colour a swatch shows: the choice's, or the 1997 figure's.
static func swatch(part: String, key: String, female: bool) -> Color:
	var row := choice(part, key)
	if not row.is_empty():
		return row[2]
	return PAINTED[part][1 if female else 0]


## Only the keys a figure can wear, the 1997 colour left out.
static func cleaned(colors: Dictionary) -> Dictionary:
	var kept := {}
	for part in PARTS:
		var key := String(colors.get(part, ""))
		if not choice(part, key).is_empty():
			kept[part] = key
	return kept


## Every part drawn at random: one in four keeps its 1997 colour.
static func random(rng: RandomNumberGenerator) -> Dictionary:
	var drawn := {}
	for part in PARTS:
		var options := choices(part)
		if rng.randi_range(0, 3) == 0:
			continue
		drawn[part] = String(options[rng.randi_range(0, options.size() - 1)][0])
	return drawn


## `part=key,…`, as the choice is remembered.
static func to_text(colors: Dictionary) -> String:
	var parts: Array[String] = []
	for part in PARTS:
		if colors.has(part):
			parts.append("%s=%s" % [part, colors[part]])
	return ",".join(parts)


static func from_text(text: String) -> Dictionary:
	var colors := {}
	for pair in text.split(",", false):
		var bits := pair.split("=")
		if bits.size() == 2:
			colors[bits[0]] = bits[1]
	return cleaned(colors)


# ------------------------------------------------- finding the parts --

## Each sheet's parts found once: `{part: PackedInt32Array pixel offsets,
## part + "_shade": PackedFloat32Array 0–1 darkest to lightest, part +
## "_usual": the part's average shade}`.
static var _found := {}


## The part ([constant PARTS] index, or -1 for trim) of a pixel of colour
## [param color] at [param rel] of the figure's height (0 top, 1 feet).
static func part_of(color: Color, rel: float, female: bool) -> int:
	var h := color.h * 360.0
	var s := color.s
	var v := color.v
	if v < 0.12 or (v < 0.30 and s < 0.55):
		return 0 if rel < 0.42 else 5
	if rel < 0.32 and v < 0.48 and s < 0.78 and (h <= 60.0 or h >= 340.0):
		return 0
	if (s < 0.12 and v >= 0.3) or (female and h >= 200.0 and h <= 250.0 and s < 0.3 and v >= 0.6):
		return 3
	if (h >= 8.0 and h <= 38.0 and s >= 0.2 and s <= 0.76 and v >= 0.42) \
			or ((h <= 8.0 or h >= 350.0) and s >= 0.12 and s <= 0.42 and v >= 0.7):
		return 1
	if s < 0.2 and v >= 0.3:
		return 3
	if female:
		if h >= 200.0 and h <= 280.0 and s >= 0.3 and rel < 0.62:
			return 2
		if h >= 85.0 and h <= 160.0 and s >= 0.3 and rel >= 0.45:
			return 4
	else:
		if (h >= 335.0 or h <= 10.0) and s >= 0.42 and rel < 0.6:
			return 2
		if h >= 190.0 and h <= 245.0 and s >= 0.3 and rel >= 0.35:
			return 4
	return -1


## The parts of [param sheet] (frames [param frame] large), found once.
static func find_parts(sheet: Image, frame: Vector2i, female: bool, key := "") -> Dictionary:
	if key != "" and _found.has(key):
		return _found[key]
	# Plain arrays while they grow: a packed array taken out of a dictionary
	# is a copy, and would grow alone.
	var offsets := {}
	var shades := {}
	for part in PARTS:
		offsets[part] = []
		shades[part] = []
	var width := sheet.get_width()
	for fy in range(0, sheet.get_height() - frame.y + 1, frame.y):
		for fx in range(0, width - frame.x + 1, frame.x):
			var cell := Rect2i(fx, fy, frame.x, frame.y)
			var used := sheet.get_region(cell).get_used_rect()
			if used.size.y <= 0:
				continue
			var tall := maxf(used.size.y - 1, 1.0)
			for y in range(used.position.y, used.end.y):
				for x in range(used.position.x, used.end.x):
					var color := sheet.get_pixel(fx + x, fy + y)
					if color.a <= 0.0:
						continue
					var part := part_of(color, (y - used.position.y) / tall, female)
					if part < 0:
						continue
					(offsets[PARTS[part]] as Array).append((fy + y) * width + fx + x)
					(shades[PARTS[part]] as Array).append(color.v)
	var found := {}
	for part in PARTS:
		var values := PackedFloat32Array(shades[part])
		var low := 1.0
		var high := 0.0
		for value in values:
			low = minf(low, value)
			high = maxf(high, value)
		var span := maxf(high - low, 0.001)
		var total := 0.0
		for i in values.size():
			values[i] = (values[i] - low) / span
			total += values[i]
		found[part] = PackedInt32Array(offsets[part])
		found[part + "_shade"] = values
		found[part + "_usual"] = clampf(total / maxf(values.size(), 1.0), 0.2, 0.8)
		found[part + "_span"] = span
	if key != "":
		_found[key] = found
	return found


## THE HERO'S SHEET DRESSED in [param colors], for [param walker] (`male`
## or `female`), from [param art]'s 1997 sheet; null without the sheet, or
## when every part keeps its 1997 colour.
static func dressed(art: WorldArt, walker: String, colors: Dictionary) -> Texture2D:
	var key := "world_ego_f" if walker == "female" else "world_ego_m"
	var sheet := art.texture(key)
	if sheet == null or cleaned(colors).is_empty():
		return null
	var image := sheet.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	var frame := Vector2i(art.frame_size(key))
	# Find parts in the original frame grid; a 2x picture has twice as many
	# image pixels, not twice as many frames. Keep that logical size on the
	# recolored texture too, for the world, dungeon and Embark preview.
	var original := GameSkin.original(sheet)
	var cache := "%s@%d" % [key, sheet.get_instance_id()]
	var painted := dress(image, frame, walker == "female", colors, cache, original)
	return GameSkin.texture_of(painted, Vector2i(sheet.get_size()))


## [param target]'s ramp at [param t], 0 darkest to 1 lightest: the colour
## itself at [param usual], deepened below and lit above.
static func ramp(target: Color, t: float, usual := 0.5) -> Color:
	if t < usual:
		return target.darkened(0.68).lerp(target, t / usual)
	return target.lerp(target.lightened(0.42), (t - usual) / (1.0 - usual))


## [param sheet] dressed in [param colors] (`{part: key}`): a new image,
## or [param sheet] itself when every part keeps its 1997 colour. For a
## high-resolution sheet, [param original] supplies the logical frame
## grid and part boundaries; the large picture keeps its shading and alpha.
static func dress(sheet: Image, frame: Vector2i, female: bool, colors: Dictionary, key := "", original: Image = null) -> Image:
	var wanted := cleaned(colors)
	if wanted.is_empty():
		return sheet
	var source := original if original != null else sheet
	var found := find_parts(source, frame, female, key)
	var out := sheet.duplicate() as Image
	var width := source.get_width()
	var scale := sheet.get_width() / width
	for part in wanted:
		var target: Color = choice(part, String(wanted[part]))[2]
		var offsets: PackedInt32Array = found[part]
		var shades: PackedFloat32Array = found[part + "_shade"]
		var usual: float = found[part + "_usual"]
		var span: float = found[part + "_span"]
		for i in offsets.size():
			var at := offsets[i]
			var point := Vector2i(at % width, at / width)
			var value := source.get_pixelv(point).v
			for dy in scale:
				for dx in scale:
					var pixel := point * scale + Vector2i(dx, dy)
					var before := sheet.get_pixelv(pixel)
					var shade := clampf(shades[i] + (before.v - value) / span, 0.0, 1.0)
					var color := ramp(target, shade, usual)
					color.a = before.a
					out.set_pixelv(pixel, color)
	return out
