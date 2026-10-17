class_name ManaIcons
extends RefCounted
## Renders mana costs with the ORIGINAL 1997 symbol sheet when the skin is
## imported (falls back to text otherwise).
##
## Sheet layout — decoded from the original Manasymbols.pic itself (19
## square cells, each sheet-height sized, in a single row):
##   cell 0: {X}   cells 1..11: {0}..{10}
##   cell 12: {W}  13: {R}  14: {U}  15: {B}  16: {G}  17: {T}
## (The Manalink-extended 63-cell sheet uses different indices — this is
## the 1997 original. See tools/import_original.py MANIFEST notes.)
##
## **The geometry is confirmed on the owner's own 1997 file**:
## `../shandalar-xp/MagicTG/Cardart/Manasymbols.pic` is dated 1996-10-29 and
## its header reads 342x18 — nineteen 18x18 cells, and an 18-pixel symbol is
## exactly one line of text tall at the original's 640x480. This is a sheet
## drawn to be set IN RUNNING TEXT, and 1997 set it there: see [ManaText]
## for the evidence. The pool's `{C}` (Scryfall's colorless pip) has no
## cell of its own — [method symbol] returns null for it — because the
## 1997 text never needed one: it wrote a run of colorless mana as a
## generic numeral (`Add |3 to your mana pool`, Master.csv), and
## [method ManaText.build] does the same, folding `{C}{C}{C}` into cell
## "3".

const CELL := {
	"X": 0, "0": 1, "1": 2, "2": 3, "3": 4, "4": 5, "5": 6,
	"6": 7, "7": 8, "8": 9, "9": 10, "10": 11,
	"W": 12, "R": 13, "U": 14, "B": 15, "G": 16, "T": 17,
}

## [QoL] The five colours as flat ink — the pip a deck's row wears when
## there is no 1997 sheet to cut a symbol from. The Deck Builder's bar
## graph (`DeckBuilderScreen.MANA_BAR`) is drawn in the same five.
const INK := {
	Mtg.ManaColor.W: Color8(232, 226, 196),
	Mtg.ManaColor.U: Color8(110, 158, 214),
	Mtg.ManaColor.B: Color8(126, 118, 128),
	Mtg.ManaColor.R: Color8(206, 102, 80),
	Mtg.ManaColor.G: Color8(120, 168, 116),
}
const LETTER := {Mtg.ManaColor.W: "W", Mtg.ManaColor.U: "U",
	Mtg.ManaColor.B: "B", Mtg.ManaColor.R: "R", Mtg.ManaColor.G: "G"}
## A [method color_strip] is always this many pips wide, filled or not.
const STRIP_PIPS := 5

static var _atlas_cache: Dictionary = {}


## Texture for one brace symbol ("W", "3", "X", "T"...) or null when the
## skin (or the symbol) is unavailable.
##
## The 1997 sheet stores every cell on an OPAQUE BLACK SQUARE (only ~100
## transparent pixels in the whole strip), which would box each symbol in
## on the card's borders. The symbols themselves are round, so each cell
## is cut out and masked to its inscribed circle — corners go
## transparent, with a one-pixel feather so the rim doesn't alias.
static func symbol(sym: String) -> Texture2D:
	if _atlas_cache.has(sym):
		return _atlas_cache[sym]
	var result: Texture2D = null
	var sheet := GameSkin.texture("mana_symbols")
	if sheet != null and CELL.has(sym):
		var size := sheet.get_height()   # cells are height-sized squares
		# Cut at the sheet's own resolution: a 2x sheet gives a 2x cell, its
		# circle and its one-pixel feather measured in ITS pixels
		# (GameSkin, THE 2x PICTURES).
		var cell := GameSkin.cut(sheet, Rect2i(CELL[sym] * size, 0, size, size))
		cell.convert(Image.FORMAT_RGBA8)
		var pixels := cell.get_width()
		var centre := (pixels - 1) / 2.0
		var radius := pixels / 2.0
		for y in pixels:
			for x in pixels:
				var dist := Vector2(x - centre, y - centre).length()
				if dist <= radius - 1.0:
					continue
				var px := cell.get_pixel(x, y)
				# Feather the last pixel of the rim, cut everything beyond.
				px.a = maxf(0.0, radius - dist) if dist < radius else 0.0
				cell.set_pixel(x, y, px)
		result = GameSkin.texture_of(cell, Vector2i(size, size))
	_atlas_cache[sym] = result
	return result


## Build a row of symbol icons for a cost string ("{2}{W}{W}"), or null
## when the skin is absent / a symbol is unknown (caller falls back to
## text). No cost in this pool writes `{C}` — it is a rules-text code, and
## [method ManaText.build] is where it becomes a numeral.
static func cost_row(cost_text: String, icon_size := 14) -> HBoxContainer:
	if GameSkin.texture("mana_symbols") == null or cost_text == "":
		return null
	var regex := RegEx.new()
	regex.compile("\\{([^}]+)\\}")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	for m in regex.search_all(cost_text):
		var tex := symbol(m.get_string(1))
		if tex == null:
			row.free()
			return null
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		row.add_child(icon)
	return row


## Width of a [method color_strip] at [param cell]: five pips and the four
## one-pixel gaps between them, whatever the mask.
static func strip_width(cell: int) -> int:
	return STRIP_PIPS * cell + STRIP_PIPS - 1


## [QoL] ONE TEXTURE OF COLOUR PIPS for a deck's row in a list — a pip per
## colour the deck plays, in WUBRG order, packed from the left on a strip
## always [method strip_width] wide, so the titles after it line up down
## the list whatever each deck casts (the Deck Builder's Load window has
## worn the same pips since 2026-09-06; the Battle-Setup pickers asked for
## them on 2026-09-17). The 1997 symbols where the skin is imported; a flat
## disc of the colour's [constant INK] otherwise, so the row still reads
## with no original files at all. Null for a mask with no colour in it — a
## deck of artifacts has nothing to say here, and its row wears nothing.
## A texture rather than a [method cost_row] because an [OptionButton]
## takes a texture per row and not a control.
static func color_strip(mask: int, cell := 14) -> Texture2D:
	var key := "strip/%d/%d" % [mask, cell]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var result: Texture2D = null
	var image: Image = null
	var slot := 0
	for color in Mtg.WUBRG:
		if not (mask & color):
			continue
		if image == null:
			image = Image.create_empty(strip_width(cell), cell, false, Image.FORMAT_RGBA8)
		image.blend_rect(_pip(int(color), cell), Rect2i(0, 0, cell, cell),
			Vector2i(slot * (cell + 1), 0))
		slot += 1
	if image != null:
		result = ImageTexture.create_from_image(image)
	_atlas_cache[key] = result
	return result


## One pip, [param cell] pixels square: the colour's 1997 symbol scaled to
## fit, or the disc. Cached per colour and size, so the sheet is read back
## from the texture five times at most.
static func _pip(color: int, cell: int) -> Image:
	var key := "pip/%d/%d" % [color, cell]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var pip: Image = null
	var sym := symbol(LETTER[color])
	if sym != null:
		pip = sym.get_image().duplicate()
		pip.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
	else:
		pip = Image.create_empty(cell, cell, false, Image.FORMAT_RGBA8)
		var ink: Color = INK[color]
		var rim := ink.darkened(0.45)
		var centre := (cell - 1) / 2.0
		var radius := cell / 2.0
		for y in cell:
			for x in cell:
				var dist := Vector2(x - centre, y - centre).length()
				if dist >= radius:
					continue
				var px := rim if dist > radius - 1.5 else ink
				px.a = minf(1.0, radius - dist)   # feather the last pixel
				pip.set_pixel(x, y, px)
	_atlas_cache[key] = pip
	return pip
