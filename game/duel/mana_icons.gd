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
## for the evidence, and note that the pool's `{C}` is the one code these
## nineteen cells cannot draw ([method symbol] returns null for it, and
## every caller falls back to the braces as text).

const CELL := {
	"X": 0, "0": 1, "1": 2, "2": 3, "3": 4, "4": 5, "5": 6,
	"6": 7, "7": 8, "8": 9, "9": 10, "10": 11,
	"W": 12, "R": 13, "U": 14, "B": 15, "G": 16, "T": 17,
}

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
		var cell := sheet.get_image().get_region(
			Rect2i(CELL[sym] * size, 0, size, size))
		cell.convert(Image.FORMAT_RGBA8)
		var centre := (size - 1) / 2.0
		var radius := size / 2.0
		for y in size:
			for x in size:
				var dist := Vector2(x - centre, y - centre).length()
				if dist <= radius - 1.0:
					continue
				var px := cell.get_pixel(x, y)
				# Feather the last pixel of the rim, cut everything beyond.
				px.a = maxf(0.0, radius - dist) if dist < radius else 0.0
				cell.set_pixel(x, y, px)
		result = ImageTexture.create_from_image(cell)
	_atlas_cache[sym] = result
	return result


## Build a row of symbol icons for a cost string ("{2}{W}{W}"), or null
## when the skin is absent / a symbol is unknown (caller falls back to
## text). Colorless {C} costs render as generic numbers on the 1997 sheet
## era, so {C} maps to the "1" digit look via plain text fallback.
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
