class_name ProxyFace
extends Button
## THE PROXY CARD, DRAWN — a card-shaped, card-sized piece of plain paper
## carrying a name and the word `proxy`, and nothing else. The visual half
## of [ProxyCard]; that class is the rule, this is the picture.
##
## DELIBERATELY NOT A [MiniCard], for exactly the reason [DamageMarker] is
## not one: there is no [CardInstance] behind it. A proxy has no cost, no
## type, no colour, no power, no mana it can produce and no state it can
## be in, so every question the small card exists to answer — castable?
## summoning sick? damaged? a legal target? — is a question you cannot ask
## of it. Wiring a MiniCard to answer them all with "nothing" would put
## fourteen silent children on screen and one more `if` in the hottest
## widget in the project.
##
## BUT IT IS THE ONE CARD SIZE, and never rescaled. [constant MiniCard.SIZE]
## in the small form, [constant CardPreview.SIZE] in the large one — the
## same two sizes every other card in this game is drawn at, because the
## one-size rule is about what a SURFACE looks like, not about which class
## drew it, and a stand-in that sat between two cards at some other size
## would break the rule in the only way the rule is about.
## `tests/unit/test_proxy_card.gd` measures both.
##
## ============================ WHY PLAIN PAPER ===========================
##
## A proxy has no colour to claim. Every 1997 card frame IS a colour —
## `Cardbk_White`, `Cardbk_Blue`, … `Cardbk_Gold`, `Cardbk_Artifact` — so
## putting a proxy in any of them would be a claim about a card we know
## nothing about beyond its name. Paper is the honest answer, and it is
## also what a paper proxy has always looked like on a real table: a blank
## card with the name written on it.
##
## THE ORIGINAL SHIPS NO BLANK CARD. Surveyed 2026-09-01, and recorded in
## `tools/import_original.py`'s manifest notes so nobody repeats it: the
## whole 1997 card-art set is 23 `Cardbk_*` frames plus ten overlays
## (`Summon`, `Damage`, `Dying`, `WillUntap`, `Target`, `CantTarget`,
## `Poison`, `Cardcounters`, `Cardsets`, `Manastripes`, `Manasymbols`) and
## the card back — no blank, no paper, no parchment. The two near misses
## were both checked and both rejected:
##   * `shandalar-src/Program/CardArt/Blank.png` is a **1x1 transparent
##     pixel** — Manalink's "no art here" placeholder, and a `.png` in a
##     Manalink install is never a 1997 file anyway (Provenance.md);
##   * `s30/assets/art/blank-card.png` IS a blank paper card, 300x418 with
##     a tan border and two empty boxes — but it is **s30's own drawing**
##     (Tier 3, and not in the 1997 `art/card/` set beside the converted
##     `.pic` files). That s30 had to draw one is corroboration that the
##     original has none, not permission to use theirs.
##
## So the paper below is OURS, built in the era's idiom: the geometry is
## the 1997 frame's own measured regions (the same fractions [MiniCard]
## and [CardPreview] anchor to), and the palette is that frame's pale
## rules box taken across the whole card.

## THE PAPER. Three tones and a rule, which is all a blank card needs:
## the aged surround, the fresher stock inside the two windows, the pencil
## rule that separates them, and the ink.
##
## Measured off the 1997 frames rather than invented — `Cardbk_White.pic`'s
## surround is a pale warm stone and its rules box is a near-white speckle,
## and these are those two tones with the colour taken out of them, which
## is precisely what "the frame with no colour to claim" means.
const PAPER := Color8(219, 210, 188)
const PAPER_LIT := Color8(238, 232, 215)
const RULE := Color8(150, 136, 110)
const INK := Color8(38, 32, 26)
## The flavour-line ink for the large card's explanation — the same ink,
## lifted, the way a printed card sets its flavour text against its rules.
const FAINT := Color8(103, 92, 74)

## Corner radius and content margin, matching [DamageMarker]'s and
## [MiniCard]'s unskinned frame so a proxy sitting beside a card is the
## same shape.
const CORNER := 6
const MARGIN := 4

## THE SMALL CARD'S THREE BANDS, in [constant MiniCard.SIZE] pixels and
## taken from [method MiniCard._build_face] so a proxy's name sits on
## exactly the line every other small card's name sits on: the title bar
## is inset 3 from each side and runs 2..18 down.
const BAND_INSET := 3
const BAND_TOP := 2
const BAND_BOTTOM := 18

## The small card's ART WINDOW and RULES BOX as fractions of the face.
## The window's left/right/top are [MiniCard]'s own
## (`ART_LEFT`/`ART_RIGHT`/`ART_TOP`); where MiniCard runs its art all the
## way down to 0.917 and overlays the P/T on it, a proxy stops early and
## gives the space back to the box that carries the word — because that
## word is the entire point of the card.
##
## The arithmetic: MiniCard's art spans 0.19..0.917, i.e. 0.727 of the
## face. Two thirds of that is the picture (0.19..0.675) and the rest, a
## 0.025 rule apart, is the text (0.70..0.917).
const ART_TOP := MiniCard.ART_TOP          # 0.19
const ART_BOTTOM := 0.675
const TEXT_TOP := 0.70
const TEXT_BOTTOM := MiniCard.ART_BOTTOM   # 0.917

## THE LARGE CARD'S REGIONS ARE [CardPreview]'S, unchanged and for the
## same reason the small card's are MiniCard's: an enlarged proxy must put
## its name, its picture and its text exactly where an enlarged card puts
## them, or the Showcase jumps as the pointer crosses from one to the
## other. Measured on `Cardbk_White.pic` (228x325) — see CardPreview's
## class doc for the full list.
const BIG_NAME := Rect2(0.055, 0.004, 0.625, 0.054)   # x, y, w, h
const BIG_ART := Rect2(0.075, 0.078, 0.850, 0.463)
const BIG_TEXT := Rect2(0.083, 0.603, 0.834, 0.312)

## The card this stands in for, verbatim from the deck file — a proxy
## carries its name where a card carries its name, and it is the only
## thing about it that is true.
var proxy_name := ""
## Which of the two card sizes this is. Set once, at construction: a proxy
## does not change size any more than a card does.
var large := false

## The pointer is on this card's row — the SAME property [MiniCard]
## exposes, because [CardArea] pushes it down onto whatever face a cell is
## holding and must not have to ask which kind it got.
var hovered := false:
	set(value):
		if hovered == value:
			return
		hovered = value
		_apply_modulate()

var _name_label: Label = null
var _band: ColorRect = null
var _art_window: Panel = null
var _text_box: Panel = null
var _word: Label = null
var _flavour: Label = null


func _init(p_name := "", p_large := false) -> void:
	proxy_name = p_name
	large = p_large
	var card_size: Vector2 = CardPreview.SIZE if large else MiniCard.SIZE
	custom_minimum_size = card_size
	size = card_size
	# SHRINK_CENTER on both axes for the same reason [MiniCard] and
	# [DamageMarker] carry it: a BoxContainer or FlowContainer stretches a
	# SIZE_FILL child to its line height, and this widget must be one card
	# and no more wherever it is parented.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	clip_text = false
	focus_mode = Control.FOCUS_ALL
	_apply_style()
	_build_face()
	refresh()


func _build_face() -> void:
	# THE NAME, where a card carries its name: on the title bar of the
	# small card, on the frame's top border of the large one. Never
	# shrunk — a long name is TRIMMED, exactly as a long card name is
	# everywhere else in this project.
	if not large:
		_band = ColorRect.new()
		_band.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_band.offset_left = BAND_INSET
		_band.offset_right = -BAND_INSET
		_band.offset_top = BAND_TOP
		_band.offset_bottom = BAND_BOTTOM
		_band.color = PAPER_LIT
		_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_band)
	_name_label = Label.new()
	if large:
		_place(_name_label, BIG_NAME)
		_name_label.add_theme_font_size_override("font_size", 13)
		var title_font := GameSkin.font("font_title")
		if title_font != null:
			_name_label.add_theme_font_override("font", title_font)
	else:
		_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_name_label.offset_left = BAND_INSET + 3
		_name_label.offset_right = -BAND_INSET - 1
		_name_label.offset_top = BAND_TOP
		_name_label.offset_bottom = BAND_BOTTOM
		_name_label.add_theme_font_size_override("font_size",
			MiniCard.NAME_FONT_SIZE)
	# Dark ink on a light face — the contrast rule every pale band in this
	# project follows ([DamageMarker], MiniCard's own `_tint_face`).
	_name_label.add_theme_color_override("font_color", INK)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	# THE EMPTY PICTURE. A window of fresher stock inside the era's own
	# gold/tan art bevel ([constant MiniCard.ART_BEVEL]) — the same rule
	# every card on this screen draws round its picture, so a proxy in the
	# deck area reads as a card with nothing in it rather than as a hole.
	_art_window = Panel.new()
	if large:
		_place(_art_window, BIG_ART)
	else:
		_fraction(_art_window, MiniCard.ART_LEFT, ART_TOP,
			MiniCard.ART_RIGHT, ART_BOTTOM)
	_art_window.add_theme_stylebox_override("panel",
		_window_style(PAPER_LIT, MiniCard.ART_BEVEL))
	_art_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_window)

	# THE RULES BOX, and the WORD. `proxy`, lower case, verbatim — the
	# owner's own instruction: *"To the card text we write proxy."*
	_text_box = Panel.new()
	if large:
		_place(_text_box, BIG_TEXT)
	else:
		_fraction(_text_box, MiniCard.ART_LEFT, TEXT_TOP,
			MiniCard.ART_RIGHT, TEXT_BOTTOM)
	_text_box.add_theme_stylebox_override("panel",
		_window_style(PAPER_LIT, RULE))
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_box)
	_word = Label.new()
	_word.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_word.offset_left = 6
	_word.offset_right = -6
	_word.offset_top = 5 if large else 1
	_word.offset_bottom = 26 if large else 16
	_word.text = ProxyCard.RULES_TEXT
	_word.add_theme_font_size_override("font_size", 14 if large else 10)
	_word.add_theme_color_override("font_color", INK)
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.add_child(_word)
	# ...and, on the LARGE card only, the sentence that says what that
	# word means, set where a printed card of this era sets its flavour
	# text: under the rules, in the same box, in a lighter ink. The small
	# card has no room for it and says it on its cue card instead.
	if large:
		_flavour = Label.new()
		_flavour.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flavour.offset_left = 6
		_flavour.offset_right = -6
		_flavour.offset_top = 30
		_flavour.offset_bottom = -4
		_flavour.text = ProxyCard.EXPLANATION
		_flavour.add_theme_font_size_override("font_size", 11)
		_flavour.add_theme_color_override("font_color", FAINT)
		_flavour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_flavour.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_flavour.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_text_box.add_child(_flavour)


## Re-derive the face from [member proxy_name]. Cheap, and named to match
## [method MiniCard.refresh] so [CardArea] can rebind either kind of face
## with the same two lines.
func refresh() -> void:
	_name_label.text = proxy_name
	# NAME first, then what it is — the shape of tooltip every card widget
	# in this project builds, and the only place the small proxy can say
	# the sentence its large form prints.
	tooltip_text = "%s\n%s — %s" % [proxy_name, ProxyCard.RULES_TEXT,
		ProxyCard.EXPLANATION]


## Point this face at a different proxy. [CardArea] rebinds a page widget
## rather than rebuilding it, so this is the counterpart of assigning
## [member MiniCard.instance].
func set_proxy_name(value: String) -> void:
	if proxy_name == value:
		return
	proxy_name = value
	refresh()


## Anchor a child to fractional coordinates of the card face — the same
## helper [CardPreview] uses, kept local because [CardPreview] is in
## `game/duel/` and this widget must not reach into it for a private.
static func _place(c: Control, r: Rect2) -> void:
	_fraction(c, r.position.x, r.position.y,
		r.position.x + r.size.x, r.position.y + r.size.y)


static func _fraction(c: Control, left: float, top: float,
		right: float, bottom: float) -> void:
	c.anchor_left = left
	c.anchor_top = top
	c.anchor_right = right
	c.anchor_bottom = bottom
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


## One of the card's two windows: fresher stock inside a one-pixel rule.
static func _window_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	return box


## EVERY Button STATE GETS THE PAPER, `disabled` included — and that one
## is not a nicety, it is the whole card.
##
## Both places this widget is used set `disabled = true` so that the
## holder underneath takes the click ([method CardArea._dress_face]) or so
## that the Showcase's card cannot be pressed at all. A `disabled` Button
## draws its `disabled` stylebox, and with only `normal` overridden that
## is Godot's default theme — which is why the first screenshot of this
## widget showed a title band, an art window and a rules box FLOATING ON
## THE DECK AREA'S NAVY TILE with no card behind them, and the name
## invisible in dark ink on that tile. Nothing in the tests could see it:
## the labels were there, `visible` was true, and the sizes were right.
func _apply_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = RULE
	box.set_border_width_all(1)
	box.set_corner_radius_all(CORNER)
	box.set_content_margin_all(MARGIN)
	for state in ["normal", "hover", "pressed", "focus", "disabled",
			"hover_pressed"]:
		add_theme_stylebox_override(state, box)


## The hover lift, which is [MiniCard]'s: the card under the pointer is
## LIGHTENED rather than outlined, so a row of cards reads as one surface.
func _apply_modulate() -> void:
	modulate = Color(1.08, 1.08, 1.08) if hovered else Color(1, 1, 1)
