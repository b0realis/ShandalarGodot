class_name SetBadges
extends HBoxContainer
## THE SET BADGES — the row in the title screen's top-left corner that says
## which expansions the game's card pool is made of. One badge per entry in
## [constant CardRegistry.SET_ORDER], in printing order, so the row grows by
## itself when the pool does.
##
## A badge is a SYMBOL where the original drew one and LETTERS where it did
## not, which is exactly how the printed cards read: Arabian Nights through
## The Dark wear an expansion symbol, and the core sets (Unlimited, Fourth
## Edition) wear nothing at all, because Wizards did not put a symbol on a
## core set until Fifth.
##
## THE LETTERS ARE WHAT SHIPS. Original art never enters this repository
## (`Provenance.md`), so the symbols arrive only when a player has run
## `tools/import_original.py` against their own copy. The lettered row is
## therefore the real product and the symbols are the dressing: with no
## skin at all this reads
##
##     2ⁿᵈ  ARN  ATQ  LEG  DRK  4ᵗʰ  Astral  PR
##
## — eight badges, no gaps and no placeholders — and each one carries the
## set's full 1997 name as its tooltip.
##
## THE SHORT FORMS ARE NOT A NEW NAMING SCHEME. They come from
## [method GameSkin.set_label], which the enlarged card
## (`game/duel/card_preview.gd`) and the Deck Builder's Set filters
## (`game/deck_builder/filter_bar.gd`) already letter themselves with: an
## edition is its numeral plus a raised ordinal, the promos are `PR`, and
## anything else is its Scryfall set code in capitals. The full names stay
## `DeckFilter.SET_LABELS`, the 1997 cue cards' own wording, and are what
## the tooltips say.
##
## ASTRAL IS THE EXCEPTION TO THE WORDING, NOT TO THE RULE. Its Scryfall
## code is `past`, so the general rule would letter it `PAST` — a code,
## not a word, for the one set in the pool no player has ever seen in
## print (Astral is the 1997 game's own invention). So when Astral has to
## letter itself it is NAMED. But the row shows a symbol OR letters, never
## both: Astral is one of the five the original drew a card symbol for
## (`SYMBOL_SLOT` slot 4, the star trailing sparks), and a skinned player
## sees the comet ALONE — the word beside it said the same thing twice
## (the owner, 2026-09-04). The name is the fallback, and it exists so
## that a player with no imported art reads `Astral` rather than `PAST`.

## Height every symbol is fitted to, in pixels. The two skins supply very
## differently shaped art — a `Cardsets` strip glyph is 12-15px tall, a
## DBArt medallion 36 — so the badge fixes the height and lets the width
## follow the aspect, which is what keeps the row's cap line straight.
const ICON_HEIGHT := 22

## Letter size for a lettered badge, and the gaps around the row.
const FONT_SIZE := 16
const SEPARATION := 10
const BADGE_SEPARATION := 4

## What a set is called when it has to letter itself and its short form
## would be a bare Scryfall code. Astral only — see the class doc. This
## decides WHAT the letters say, never WHETHER they appear: a badge that
## has its symbol shows the symbol alone.
const NAMED := {"past": "Astral"}

# ------------------------------------------------- the 1997 symbol strip --
# `s30/assets/art/card/Cardsets.pic.png` is the ORIGINAL's own sheet of the
# symbols it stamps on a card, and this is what it actually contains,
# MEASURED (PIL, 2026-09-02) rather than eyeballed:
#
#   330x15, palettised, and it is FIVE 66-WIDE SLOTS — not five 66px
#   symbols. Each slot is an IMAGE half and a MASK half, 33x15 each, the
#   same image+mask pairing as `Summon.pic` and `Dying.pic`
#   (tools/import_original.py's overlay block). The mask half is the exact
#   complement of the image half: palette index 0 (opaque black) wherever
#   the image has ink, index 255 (the file's declared transparent index)
#   everywhere else. Verified pixel for pixel across all five slots.
#
#   THERE IS NO SIXTH SLOT. 330 = 5 x 66 exactly, and the columns that
#   look empty in a naive column profile are the mask halves. The question
#   was asked because 330 also divides by 6; it does not survive the
#   measurement — a 55-wide grid puts slot 3's ink (x 210..230) across a
#   cell boundary, and the 66-wide grid puts every slot's ink flush
#   against the right edge of its image half, which is where a printed
#   card carries its expansion symbol.
#
#   Ink bounding boxes inside each 33x15 image half, x then y:
#     slot 0  x 18..32 (15 wide)  y 0..13 (14 tall)
#     slot 1  x 18..32 (15)       y 0..13 (14)
#     slot 2  x  0..32 (33)       y 0..14 (15)
#     slot 3  x 12..32 (21)       y 0..11 (12)
#     slot 4  x  3..32 (30)       y 0..12 (13)
#   All five are RIGHT-ALIGNED in their cell; the left padding varies
#   (18/18/0/12/3), which is why [method symbol_from_sheet] crops to the
#   ink before handing the glyph over. A row of badges laid out on the raw
#   cells would be visibly ragged.
#
# WHICH SYMBOL IS WHICH SET was settled by rendering the five slots at 10x
# beside the six NAMED DBArt glyphs (`Program/DBArt/Dark.pic`,
# `Legends.pic`, `ArabNite.pic`, `Antiquit.pic`, `Astral.pic`,
# `Fourth.pic`) at 8x, and matching them by eye. Each of the five is an
# unmistakable match for one named file — same hooked hilt, same anvil
# horn, same comet — so the map below rests on the original's own file
# names, not on anybody's reading of a 15px picture.

## Skin key for that strip. `tools/import_original.py` does not carry this
## row yet (its ART manifest was being edited by another pass when this was
## written); the badges fall back to `set_icon_<code>` until it lands, and
## nothing here changes when it does.
const SHEET_KEY := "card_set_symbols"

## The strip's exact size. A sheet that is not this is refused outright
## rather than sliced at a guess.
const SHEET_SIZE := Vector2i(330, 15)

## One slot's stride, and the image half inside it.
const SLOT_PITCH := 66
const CELL := Vector2i(33, 15)

## Set code -> slot on the strip, left to right. THESE FIVE, AND ONLY
## THESE FIVE, ARE THE SETS THE ORIGINAL DREW A CARD SYMBOL FOR.
const SYMBOL_SLOT := {
	"drk": 0,    # a crescent moon        — The Dark
	"leg": 1,    # a pillar with a capital — Legends
	"arn": 2,    # a curved scimitar      — Arabian nights
	"atq": 3,    # an anvil               — Antiquities
	"past": 4,   # a star trailing sparks — Astral
}

# FOURTH EDITION IS DELIBERATELY NOT ON THAT LIST, and the reason is worth
# recording because the evidence cuts both ways. `Program/DBArt/Fourth.pic`
# exists — a gold Roman `IV` — and `tools/import_original.py` already
# imports it as `set_icon_4ed`, so a skinned player DOES have a 4ed glyph
# in the skin directory. But it is a DECK BUILDER FILTER BUTTON, one of the
# 37 DBArt medallions that dress that screen's toggles (`deckdll.cpp`'s
# `draw_filter_button_pic(hdc, r, 5, 20, ... FS_4TH_EDITION)`), and the
# `Cardsets` strip — the sheet of symbols the game stamps on CARDS — has no
# slot for it, exactly as a printed Fourth Edition card has no expansion
# symbol. So on this row 4ed letters itself `4ᵗʰ`, which is also the form
# the owner asked for by name. Unlimited and the promos are absent from
# both sheets and have never been in question.

## Set icons on, i.e. the skin is allowed to dress the row. Tests turn it
## off to exercise the shipped lettered path on a machine that HAS the
## 1997 art imported.
var icons := true

## A badge was clicked; the argument is the set code. The row does not
## open the popup itself — it has no business deciding where a window goes
## on somebody else's screen — so the shell (`game/main.gd`) listens and
## calls [method UiChrome.explain_popup] with [method facts_for].
signal set_clicked(code: String)

static var _symbol_cache: Dictionary = {}

## Where the set facts live: name, release date, printed size and a short
## history for each set in the pool. Written from the Scryfall set objects
## in the local card packs (see the file's own `_source` line); the count
## for THIS game is not in it, because that is a question only the loaded
## [CardRegistry] can answer.
const FACTS_PATH := "res://cards/data/sets.json"

static var _facts: Dictionary = {}


## Everything known about one set, or an empty dictionary. Keys: `name`,
## `released`, `kind`, `printed`, `lore`.
static func facts_for(code: String) -> Dictionary:
	if _facts.is_empty():
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(FACTS_PATH))
		if parsed is Dictionary and (parsed as Dictionary).has("sets"):
			_facts = (parsed as Dictionary)["sets"]
	var one: Variant = _facts.get(code, {})
	return one if one is Dictionary else {}


## How many cards of a set THIS game implements — counted, never stored,
## because the pool is the filesystem (see [CardRegistry]).
static func cards_here(code: String) -> int:
	CardRegistry.ensure_loaded()
	var total := 0
	for name in CardRegistry.all_names():
		var card := CardRegistry.get_card(String(name))
		if card != null and card.set_code == code:
			total += 1
	return total


## The popup's body for one set: the two counts, the date, then the
## history. Kept here rather than in the shell so the Deck Builder can
## show the same words when it grows a set filter tooltip.
static func describe(code: String) -> String:
	var facts := facts_for(code)
	if facts.is_empty():
		return ""
	var printed := int(facts.get("printed", 0))
	var here := cards_here(code)
	# An em dash, not a middle dot: the imported MPlantin has no U+00B7
	# and drops it silently, which read as a hole in the sentence.
	var line := "%s — %s" % [_date_words(String(facts.get("released", ""))),
		"%d of its %d cards are in this game" % [here, printed]]
	if here == printed:
		line = "%s — all %d of its cards are in this game" % [
			_date_words(String(facts.get("released", ""))), printed]
	return "%s\n\n%s" % [line, String(facts.get("lore", ""))]


## "1993-12-17" -> "December 1993". The day is in the data and is not
## worth the room: what a player wants from a set badge is the year.
static func _date_words(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() < 2:
		return iso
	const MONTHS := ["January", "February", "March", "April", "May",
		"June", "July", "August", "September", "October", "November",
		"December"]
	var month := int(parts[1])
	if month < 1 or month > 12:
		return iso
	return "%s %s" % [MONTHS[month - 1], parts[0]]


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)
	for code in CardRegistry.SET_ORDER:
		add_child(_badge(String(code)))


## One badge: the set's symbol if we have one, its letters otherwise —
## one or the other, never both.
func _badge(code: String) -> Control:
	var badge := HBoxContainer.new()
	badge.name = "badge_%s" % code
	badge.add_theme_constant_override("separation", BADGE_SEPARATION)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	# The tooltip stays the set's 1997 NAME and nothing else — that name
	# is a provenance claim (`tests/ui/test_set_badges.gd` pins it), not a
	# label to hang instructions on. What says the badge can be clicked is
	# the pointing hand, and what it says when clicked is the popup.
	badge.tooltip_text = String(
		DeckFilter.SET_LABELS.get(code, code.to_upper()))
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.set_meta("set_code", code)
	badge.gui_input.connect(_on_badge_input.bind(code))

	var art: Texture2D = symbol(code) if icons else null
	if art != null:
		var glyph := Glyph.new()
		glyph.art = art
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(glyph)

	# The letters: whenever, and only whenever, there is no symbol. A
	# badge wearing its 1997 glyph does not also spell the set out.
	if art == null:
		var letters := Lettered.new()
		letters.stem = badge_text(code)
		letters.suffix = badge_suffix(code)
		letters.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(letters)
	return badge


## A left click anywhere on a badge — symbol or letters — asks for that
## set. Nothing else on this row is interactive, so the whole badge is the
## target rather than the glyph.
func _on_badge_input(event: InputEvent, code: String) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index \
				== MOUSE_BUTTON_LEFT:
		accept_event()
		set_clicked.emit(code)


# ------------------------------------------------------------- the words --

## The stem of a set's badge — its numeral, its initials or its name.
## [constant NAMED] first (Astral), then [method GameSkin.set_label], which
## is the short form the rest of the game already letters sets with.
static func badge_text(code: String) -> String:
	if NAMED.has(code):
		return String(NAMED[code])
	return GameSkin.set_label(code)


## The RAISED part, if the set has one: `2` takes `nd`, `4` takes `th`.
## Named sets take none — "Astral" is a word, not an ordinal.
static func badge_suffix(code: String) -> String:
	if NAMED.has(code):
		return ""
	return GameSkin.set_label_suffix(code)


# ----------------------------------------------------------- the symbols --

## The original's symbol for a set, or null — for the three sets it drew
## none for, and for every set when no skin is imported.
##
## TWO SOURCES, IN PROVENANCE ORDER. The 1997 `Cardsets` strip first: it is
## the genuine article, reaching us through s30's conversion of the
## original file. `set_icon_<code>` second: those are `Program/DBArt/*.pic`,
## which `tools/import_original.py` records as Manalink 3's own flat
## RESTYLE of the 1997 glyphs (a PNG wearing a `.pic` extension), and no
## 1997 conversion of them exists — s30 converted the card art, not DBArt.
## Same drawings, later hand; good enough to dress a menu, second in line.
static func symbol(code: String) -> Texture2D:
	if not SYMBOL_SLOT.has(code):
		return null
	if _symbol_cache.has(code):
		return _symbol_cache[code]
	var result: Texture2D = null
	var sheet := GameSkin.texture(SHEET_KEY)
	if sheet != null:
		result = symbol_from_sheet(sheet.get_image(), code)
	if result == null:
		result = ink_tight(GameSkin.set_icon(code))
	_symbol_cache[code] = result
	return result


## A glyph cropped to its own ink — the same trim [method symbol_from_sheet]
## does for the strip, applied to whatever the other source hands over.
##
## IT IS WHAT MAKES A ROW OF BADGES A ROW. A DBArt medallion is a 35x36
## TILE with the symbol floating in the middle of it, and the margin
## differs per file (the scimitar is the thinnest drawing in the set and
## the pillar nearly fills its tile). Fitting the tiles to a common height
## therefore fits the PADDING, and the first render of this row came out
## with a scimitar a third the size of the pillar beside it. Fitting the
## INK instead gives every set the same optical weight.
static func ink_tight(art: Texture2D) -> Texture2D:
	if art == null:
		return null
	var image := art.get_image()
	if image == null:
		return null
	var ink := image.get_used_rect()
	if ink.size.x <= 0 or ink.size.y <= 0:
		return art
	if ink.position == Vector2i.ZERO and ink.size == image.get_size():
		return art
	return ImageTexture.create_from_image(image.get_region(ink))


## Cut one symbol out of the strip: the IMAGE half of the set's slot, with
## the background keyed out and the glyph cropped to its own ink.
##
## The key is a flat `is it pure black` test, and it is safe because the
## strip says so: the darkest ink anywhere on the sheet is (28,28,28) and
## the background is (0,0,0) at palette index 0, so nothing in a symbol can
## be mistaken for backdrop. The mask half is not needed for this — it is
## the exact complement of the image half's ink, which is the same
## information — but it is what proved the key is total.
##
## Returns null for a set with no slot, or for a sheet that is not the
## strip. Never guesses at a sheet of the wrong size.
static func symbol_from_sheet(sheet: Image, code: String) -> Texture2D:
	if not SYMBOL_SLOT.has(code):
		return null
	if sheet == null or sheet.get_width() != SHEET_SIZE.x \
			or sheet.get_height() != SHEET_SIZE.y:
		return null
	var slot: int = SYMBOL_SLOT[code]
	var cell := sheet.get_region(
		Rect2i(slot * SLOT_PITCH, 0, CELL.x, CELL.y))
	cell.convert(Image.FORMAT_RGBA8)
	for y in cell.get_height():
		for x in cell.get_width():
			var px := cell.get_pixel(x, y)
			if px.r == 0.0 and px.g == 0.0 and px.b == 0.0:
				cell.set_pixel(x, y, Color(0, 0, 0, 0))
	# Every glyph is right-aligned in its cell with up to 18px of empty
	# room on the left (the measurements above); crop it away so the row
	# spaces its badges evenly instead of by the sheet's own padding.
	var ink := cell.get_used_rect()
	if ink.size.x <= 0 or ink.size.y <= 0:
		return null
	return ImageTexture.create_from_image(cell.get_region(ink))


# ---------------------------------------------------------- the drawing --

## ONE SYMBOL BADGE: the set's glyph at [constant ICON_HEIGHT], over its own
## one-pixel shadow.
##
## THE SHADOW IS NOT DECORATION. The two skins hand over glyphs of opposite
## value — the 1997 strip's are near-black with cream highlights (they were
## drawn to sit on a card's pale type line) and DBArt's are gold — and both
## land on the SAME sandstone plaque, which is pale. Screenshotted without
## it, the gold set nearly vanished into the stone. A dark offset copy
## underneath gives every glyph an edge on a light ground and costs nothing
## on a dark one, and it is the same one-pixel shadow the letters beside it
## already wear, so the row keeps one voice.
class Glyph extends Control:

	var art: Texture2D

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = _art_size() + Lettered.SHADOW
		queue_redraw()

	## Fitted to a common HEIGHT, with the width following the aspect — the
	## glyphs are ink-tight (see [method SetBadges.ink_tight]) and no two of
	## them are the same shape.
	func _art_size() -> Vector2:
		if art == null or art.get_height() <= 0:
			return Vector2.ZERO
		return Vector2(roundf(SetBadges.ICON_HEIGHT
			* float(art.get_width()) / float(art.get_height())),
			SetBadges.ICON_HEIGHT)

	func _draw() -> void:
		if art == null:
			return
		var box := Rect2(Vector2.ZERO, _art_size())
		draw_texture_rect(art, Rect2(Lettered.SHADOW, box.size), false,
			Lettered.SHADOW_INK)
		draw_texture_rect(art, box, false)


# ------------------------------------------------------ the raised suffix --

## ONE LETTERED BADGE: a stem on the baseline and, for an edition, its
## ordinal suffix RAISED — `4` with a small `th` sitting up on the cap
## line, the way an edition is written and the way the owner asked for it.
##
## DRAWN, not laid out, and the two layout answers were considered and
## rejected for the same reason — neither survives a change of font:
##   * A [RichTextLabel] can change SIZE mid-line but not baseline; BBCode
##     has no superscript tag, so `[font_size=10]th` still sits on the
##     baseline and the badge reads `4th`, flat.
##   * Two [Label]s in a box can align the small one to the row's TOP or
##     its BOTTOM, and the cap line is neither. The offset that looks right
##     for one face is wrong for the next, and a top-aligned suffix rides
##     above the numeral's cap and clips against the panel's margin.
## Asking the FONT where its own baseline is puts the suffix on the cap
## line at any size in any face, and the control's minimum size is measured
## from the same two strings, so it cannot clip. The enlarged card solves
## the same problem with two anchored Labels (`card_preview.gd`), which
## works there because that card's geometry is fixed and measured; a badge
## in a flow row has no such luxury.
class Lettered extends Control:

	## A superior figure is about 62% of the face it rides on...
	const SUB_SCALE := 0.62
	const MIN_SUB_SIZE := 8

	## ...and sits a bit over a quarter of the way up. RAISE is a fraction
	## of the FONT'S OWN ascent, so it tracks the face rather than a size
	## in pixels: 0.28 puts the suffix's top level with the numeral's cap
	## and its foot clear of the baseline. Checked at 3x on the rendered
	## menu with both the imported MPlantin and Godot's default face.
	const SUB_RAISE := 0.28

	## The corner-label voice from `game/main.gd`: warm parchment ink over
	## a one-pixel black shadow. The badges sit on the same stone panel the
	## rest of the shell uses, so they letter themselves like it.
	const INK := Color(1, 1, 0.98)
	const SHADOW_INK := Color(0, 0, 0, 0.9)
	const SHADOW := Vector2(1, 1)

	var stem := ""
	var suffix := ""
	var font_size := SetBadges.FONT_SIZE

	var _face: Font
	var _sub_size := 0
	var _raise := 0.0
	var _baseline := 0.0
	var _stem_width := 0.0

	func _ready() -> void:
		# TRANSPARENT TO THE MOUSE, exactly like [Glyph], and for the
		# reason the badges exist at all: the click belongs to the BADGE.
		# A bare [Control] defaults to MOUSE_FILTER_STOP, so until
		# 2026-09-04 the letters sat on top of their own badge and ate
		# the press — `2ⁿᵈ`, `4ᵗʰ` and `PR` never opened their window, and
		# on an unskinned machine no badge did.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face = GameSkin.font("font_body")
		if _face == null:
			_face = get_theme_default_font()
		_sub_size = maxi(MIN_SUB_SIZE, roundi(font_size * SUB_SCALE))
		var ascent := _face.get_ascent(font_size)
		_baseline = ascent
		_raise = roundf(ascent * SUB_RAISE)
		_stem_width = _face.get_string_size(
			stem, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var suffix_width := 0.0
		if suffix != "":
			suffix_width = _face.get_string_size(
				suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, _sub_size).x
		custom_minimum_size = Vector2(
			ceilf(_stem_width + suffix_width + SHADOW.x),
			ceilf(ascent + _face.get_descent(font_size) + SHADOW.y))
		queue_redraw()

	func _draw() -> void:
		if _face == null:
			return
		_ink_at(Vector2(0, _baseline), stem, font_size)
		if suffix != "":
			_ink_at(Vector2(_stem_width, _baseline - _raise),
				suffix, _sub_size)

	func _ink_at(at: Vector2, text: String, size: int) -> void:
		draw_string(_face, at + SHADOW, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, SHADOW_INK)
		draw_string(_face, at, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
