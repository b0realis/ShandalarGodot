class_name CardPreview
extends Control
## The enlarged card: full frame, name, cost, type line, art, complete
## oracle text, and P/T — the original's card-inspection view. Shown by
## the stacked-hand's hover today; built as a shared component so hover
## zoom over the battlefield (QoL wishlist) can reuse it verbatim.
##
## Layout is FRACTION-ANCHORED to the 1997 frame's OWN regions, measured
## off Cardbk_White.pic (228x325): top border 0-5.5%, art window
## 5.8-55.5%, type strip 55.2-60.4%, white rules box 60-91.7%, bottom
## border 91.7-100%. Text sits ON those borders — name + cost on the top
## border, type on the strip between art and rules box, rules in the box,
## and the bottom border carries BOTH of its printed marks: the
## illustrator credit at its left (`Illus. <name>`) and P/T at its right.
## NOTHING is drawn behind the text (the card
## back IS the background); the flat no-skin fallback paints an
## equivalent frame instead of the texture.
##
## **AND A SECOND, INDEPENDENT LAYOUT AGREES WITH EVERY ONE OF THOSE
## FRACTIONS.** Manalink 3's replacement for the original `drawcardlib.dll`
## — **Tier 3**, but a drop-in for a 1997 DLL and so bound to its geometry
## — maps an 800x1200 logical space onto whatever rectangle it is handed
## (`SetWindowExtEx(hdc, 800, 1200)`,
## `shandalar-src/src/drawcardlib/drawfullcard.c:1406`) and lays the card
## out at `Frame` 24,24,752x1152 inside it (`.../config.c:758-767`).
## Dividing each rect by that frame gives fractions, and they are ours:
##
## | part | 1997 rect (l,t,w,h) | as a fraction of the card | ours |
## |---|---|---|---|
## | art | 80,96,640,560 | 0.075-0.926 x 0.063-0.549 | 0.075-0.925 x 0.078-0.541 |
## | type | 48,660,590,60 | y 0.552-0.604 | y 0.552-0.604 |
## | rules box | 64,720,672,364 | y 0.604-0.920 | y 0.603-0.915 |
## | P/T | 44,1084,704,72 | y 0.920-0.983 | y 0.920-0.995 |
##
## Two trees measured apart landing on the same numbers is as close to
## proof as this question gets: the geometry here was right the first
## time. What was WRONG was the INK — see [constant BODY_INK].

## The frame art is 228x325, so the card renders at THAT aspect (0.702)
## — undistorted, and within 2% of a real 63x88mm card (0.716).
const SIZE := Vector2(300, 428)

## THE ILLUSTRATOR CREDIT'S PREFIX, as every card of this era prints it in
## its bottom-left corner. `Duel.hlp`'s "Parts of the Card" topic numbers
## the twelve labelled parts of this view and calls part 6 **`Artist`**;
## the card face itself writes it `Illus. <name>`, which is the form the
## owner asked for and the form the real 1993-97 cards use.
##
## **AND THE STRING TABLE SETTLES BOTH THAT IT WAS DRAWN AND HOW IT WAS
## WRITTEN** (Tier 1, found 2026-09-04): `Program/UIStrings.txt:251-253` is
## a tag of its own —
##
##     @ARTISTLINE
##     1
##     Illus. %s
##
## which is this constant, plus the artist, exactly. The 1997 DLL's
## exported entry point takes the credit as an argument to match —
## `DrawFullCard(HDC, const RECT*, const card_ptr_t*, int pic_version, int
## big_art_style, int expand_text_box, const char* illus)`
## (`shandalar-src/src/deck/deckdll.h:46`) — and Manalink's replacement
## throws it away with a bare `(void)illus;`
## (`.../drawcardlib/drawfullcard.c:1390`), which is why no Manalink
## screenshot shows one.
const ILLUS_PREFIX := "Illus. "

# --------------------------------------------------------------------------
#  THE INK, AND THE BUG IT REPLACES
# --------------------------------------------------------------------------
## **THE LETTERS ON THE CARD BODY ARE WHITE.** Until 2026-09-04 every one
## of them — name, type line, edition label, illustrator credit, P/T — was
## painted in a near-black `_ink`, on the reasoning that the imported 1997
## frame is a "light marble frame". That reasoning was measured on
## **`Cardbk_White.pic` alone**, and it is the only frame it holds for. The
## other five card bodies are DARK, and the numbers are not close:
##
## | frame | type strip | bottom border |
## |---|---|---|
## | white | luma 188 | 184 |
## | blue | 113 | 104 |
## | red | 82 | 73 |
## | artifact | 68 | 64 |
## | green | 49 | 43 |
## | black | **22** | **19** |
##
## — mean luma of `assets/original/card_frame_*.png` over the exact
## rectangles these labels occupy, and those files are **Tier 1**: they are
## `Cardart/Cardbk_*.pic`, dated **1997-01-22** in the owner's own install.
## `Duel.hlp`'s **Background** topic names that region as what it is:
## *"The background of a spell card (experienced players will remember this
## was called the border in previous editions) serves as an easy visual
## reminder of the color of the spell."* Near-black ink at luma 25 on a
## body at luma 19 is not "hard to read" — it is INVISIBLE, and that is the
## defect the owner reported. **The 1997 art itself rules dark ink out on
## five of the six bodies**, so this is not a fidelity-versus-legibility
## trade: there is no reading of these frames on which the original
## lettered them dark.
##
## What the original DID use is not recoverable from a Tier-1 artefact
## locally (no pre-Manalink `Magic.exe` is in any tree here), but the
## nearest thing agrees: Manalink 3's replacement renderer letters exactly
## these three strings white, and only the rules text dark —
##
##     TXT_AND_SHADOW(fullcard_title_txt, "Title", 255,255,255, 47,47,47, 4,4);
##     TXT_AND_SHADOW_ALL_DEFAULT(fullcard_powertoughness_txt, "Powertoughness", fullcard_title_txt);
##     TXT_AND_SHADOW_ALL_DEFAULT(fullcard_type_txt, "Type", fullcard_title_txt);
##     get_cfg_colordef(config, &config->fullcard_rulestext_color, section, "RulestextColor", 47,47,47);
##
## (`shandalar-src/src/drawcardlib/config.c:817-822`, **Tier 3**) — white
## glyphs with a 47,47,47 shadow for the title, the type line and the P/T;
## 47,47,47 for the rules text, which is the only one of the four that sits
## on a light plate. Tier-1 art and Tier-3 code point the same way, so the
## dark ink was simply ours, and wrong.
const BODY_INK := Color(1, 1, 1)
## The rules text, which sits on the frame's own light rules plate (luma
## 126-223 across the six frames) and stays dark exactly as the original
## has it — `RulestextColor` 47,47,47.
const RULES_INK := Color8(47, 47, 47)

## `[QoL]` The original backs its body text with a SHADOW offset (4,4) in
## its 800x1200 logical space; the isotropic map onto our 428-tall card
## scales that to 4 * 428/1200 = **1.4 px**. We spend it as a symmetric
## OUTLINE instead, which is this project's standing finding for letters
## that stand on whatever art or marble a card happens to carry — a one-
## sided shadow dies on a pale ground (`MiniCard.PT_OUTLINE_SIZE` and
## `DuelScreen.PILE_COUNT_OUTLINE_SIZE`, both 2026-09-03, both 4). Godot's
## `outline_size` is a diameter, so 3 is that 1.4 px shadow made
## symmetric.
const OUTLINE_INK := Color(0, 0, 0, 1)
const OUTLINE_SIZE := 3
## The P/T pair keeps `MiniCard`'s heavier 4: it is the same pair of
## glyphs at very nearly the same size (26 here, 25 there), and the two
## renderings of one card should not letter it two different ways.
const PT_OUTLINE_SIZE := 4

# --------------------------------------------------------------------------
#  THE TYPE SIZES, AS RATIOS OF THE CARD'S HEIGHT
# --------------------------------------------------------------------------
## The font table is `Duelart/Duel.dat` `[fonts]`, whose own comment says
## it is *"used both by drawcardlib and magic.exe proper"* — and the 1997
## exe does carry the `Fonts` / `size` / `bold` / `font` key literals, so
## the MECHANISM is the original's. **The VALUES are not Tier 1**: both
## surviving copies are dated 2004, and they disagree —
## `../shandalar-xp/MagicTG/Duelart/Duel.dat:23-37` says 17/15/18/14 for
## title/subtitle/PT/text where Manalink 3's own
## `../shandalar-src/Program/DuelArt/Duel.dat:34-62` says 14/13/16/14. This
## ports the MagicTG copy, for a reason internal to the layout: `cfg_font`
## turns each `size` into a GDI cell height of `4 * size` in the same
## 800x1200 space the rects live in (`.../config.c:398`), and on those
## numbers the `Type` rect (height 60) is **exactly one** BigCardSubtitle
## cell and the `Powertoughness` rect (height 72) **exactly one** BigCardPT
## cell. A strip that is precisely as tall as the line it carries is a
## layout drawn around those fonts; the other copy fits neither. Both
## copies agree on BigCardText, which is the one that matters most.
##
## Against the 1152-unit card each cell is a share of the CARD'S HEIGHT,
## which is the portable number — the same way the small card's P/T was
## ported (`MiniCard.PT_FONT_SIZE`, "0.241 of the card's height"):
##
## | element | 1997 font | size | cell | / 1152 | on our 428 |
## |---|---|---|---|---|---|
## | name | BigCardTitle (Benguiat BkCn Bt) | 17 | 68 | 0.0590 | 25.3 px |
## | type line | BigCardSubtitle (Benguiat BkCn Bt) | 15 | 60 | 0.0521 | 22.3 px |
## | P/T | BigCardPT (CentSchbook BT) | 18 | 72 | 0.0625 | 26.8 px |
## | rules text | BigCardText (MPZurich Cn BT) | 14 | 56 | 0.0486 | 20.8 px |
##
## The numbers are LINE-BOX heights, so [method _size_for_ratio] resolves
## each one against the font actually in use rather than hard-coding a
## point size that would be wrong the moment a skin changes the face.
const NAME_RATIO := 68.0 / 1152.0
const TYPE_RATIO := 60.0 / 1152.0
const PT_RATIO := 72.0 / 1152.0
## `[QoL]` The credit is the one element no source sizes: neither
## `Duel.dat` has a `sizeBigCardIllus`, and the DLL that drew it is the one
## Manalink replaced. The printed card sets it in a fine italic below the
## rules text, so it is pinned to three quarters of the rules line — the
## smallest thing on the card, and still five points up from the 9 it used
## to be lettered at.
const ILLUS_RATIO_OF_RULES := 0.75

## THE RULES TEXT IS SIZED BY THE LINE COUNT, NOT BY THE RATIO, because
## that is the invariant the layout states and the one both copies of
## `Duel.dat` agree on: `Rulestext` is 336 logical units tall over a
## 56-unit cell — **exactly six lines** (`config.c:763`). Our text box is a
## hair shorter in proportion (0.280 of the card against 0.292), so six
## lines is a slightly tighter line box than the raw 0.0486 ratio would
## give, and six lines is the thing worth keeping.
const RULES_LINES := 6

## Leading between those lines. The 1997 renderer sets its rules text at
## the FONT'S OWN CELL — `draw_mana_text` advances one `tmHeight` a line,
## with no leading added — and Godot's default theme adds 3 px, which is
## most of a seventh line's worth over six lines and is why a card as
## ordinary as Nova Pentacle lost its last line before this pass. One
## pixel, not none: MPlantin's descenders reach far enough that a bare
## cell touches the line under it.
const RULES_LINE_SPACING := 1

## `[QoL]` The original NEVER shrinks the rules text — `BigCardText` is a
## single font with no ladder behind it, and what does not fit is clipped
## (`ExtTextOut(..., ETO_CLIPPED, ...)`). We drop a step at a time instead,
## because losing the back half of Tawnos's Coffin is a worse trade than
## two points of type. Coarse steps, so the pool wears five sizes and not
## fifteen; the floor is 11, which is still a point above the 10 the old
## char-count ladder bottomed out at.
const RULES_STEPS := [0, -2, -4, -6, -7, -8]

## Docked mode (the sidebar slot, like the original): position is fixed by
## the parent dock, place_beside() is a no-op, and the card persists after
## the pointer leaves — the "last examined card" behavior.
var docked := false

var _frame_bg: Panel
var _name_label: Label
var _cost_holder: Control
var _type_label: Label
var _set_icon: TextureRect
var _set_text: Label
var _set_suffix: Label
var _art: TextureRect
var _art_placeholder: ColorRect
var _text_bg: ColorRect
## The frame's OWN rules plate, cut out of the frame texture and stretched
## over the text box when the box grows past where the frame paints one —
## the original does exactly this, and for exactly this reason
## (`fullcard_expand_text_box`, `drawfullcard.c:1128-1151`).
var _text_plate: TextureRect
var _oracle: ManaText
var _pt_label: Label
var _artist_label: Label
var _back: Panel

## The two faces this card letters with (the imported skin's, or the
## engine fallback when no skin is imported), and the sizes resolved
## against them once — see [method _size_for_ratio].
var _title_font: Font
var _body_font: Font
var _name_size: int
var _type_size: int
var _pt_size: int
var _rules_size: int
var _illus_size: int
## The instance on show, so a live `Expand` toggle can re-lay-out the card
## the player is looking at instead of waiting for the next hover.
var _shown: CardInstance = null


## The largest font size whose LINE BOX still stands inside [param ratio]
## of the card's height — the ports in [constant NAME_RATIO] and its
## neighbours, resolved against the face actually in use. Hard-coding a
## point size instead would silently mis-size the card the moment a skin
## shipped a different face: the engine fallback runs a third taller per
## point than the skin's MPlantin (28 px at size 20 against 21), so the
## same number would overflow every strip on this card.
static func _size_for_ratio(f: Font, ratio: float) -> int:
	return _size_for_height(f, ratio * SIZE.y)


## The largest size whose LINE BOX still fits [param target] pixels (half a
## pixel of slack, so a target that lands a hair under a whole line box
## still gets that line box), never below 8.
static func _size_for_height(f: Font, target: float) -> int:
	var best := 8
	for candidate in range(8, 41):
		if f.get_height(candidate) <= target + 0.5:
			best = candidate
	return best


## The largest size at which [param lines] wrapped lines — leading
## included — still stand inside [param height] pixels.
static func _size_for_lines(f: Font, lines: int, height: float) -> int:
	var best := 8
	for candidate in range(8, 41):
		if lines * f.get_height(candidate) \
				+ (lines - 1) * RULES_LINE_SPACING <= height:
			best = candidate
	return best


## How tall [param text] really stands once it has wrapped to [param width]
## at [param size] — MANA SYMBOLS INCLUDED, because the box has to hold what
## is actually drawn in it.
##
## This used to reconstruct the line count from `get_multiline_string_size`
## (which reports only the sum of the line boxes, while a `Label` also puts
## `line_spacing` BETWEEN them — reading the first number as if it were the
## second is what used to clip the last line off a card whose text fitted
## perfectly well). It now asks [ManaText], which shapes the very paragraph
## the widget will draw and reports its height: measurement and render can
## no longer disagree, and a `{T}` costs the box exactly what it will cost
## it on screen.
static func _wrapped_height(f: Font, text: String, width: float, size: int) -> float:
	return ManaText.measure(text, f, size, width, RULES_LINE_SPACING)


## The largest size from [param sizes] whose ONE line of [param text] fits
## [param width] px — the shape of the original's own title and type-line
## ladders, which hold nine progressively CONDENSED faces and take the
## first that fits (`config.c:554-575`, `drawfullcard.c:984-994` and
## `:1033-1043`). Godot cannot condense a face, so ours steps the size.
static func _fit_one_line(f: Font, text: String, width: float, sizes: Array) -> int:
	for candidate in sizes:
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				int(candidate)).x <= width:
			return int(candidate)
	return int(sizes[sizes.size() - 1])


## Anchor a child to fractional coordinates of the card face.
static func _anchor(c: Control, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = left
	c.anchor_top = top
	c.anchor_right = right
	c.anchor_bottom = bottom
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # a tooltip never eats clicks
	z_index = 200
	visible = false

	# THE FACES, and every size on the card resolved against them. The
	# original letters name and type line in one face (Benguiat BkCn Bt)
	# and rules text and P/T in others; ours has two, so name and type take
	# the title face and the rest the body face.
	_title_font = GameSkin.font("font_title")
	if _title_font == null:
		_title_font = ThemeDB.fallback_font
	_body_font = GameSkin.font("font_body")
	if _body_font == null:
		_body_font = ThemeDB.fallback_font
	_name_size = _size_for_ratio(_title_font, NAME_RATIO)
	_type_size = _size_for_ratio(_title_font, TYPE_RATIO)
	_pt_size = _size_for_ratio(_body_font, PT_RATIO)
	# Six lines in the box, as the original's own text rect is six lines.
	_rules_size = _size_for_lines(_body_font, RULES_LINES,
		(0.902 - (TEXT_TOP + 0.019)) * SIZE.y)
	_illus_size = _size_for_height(_body_font,
		_body_font.get_height(_rules_size) * ILLUS_RATIO_OF_RULES)

	_frame_bg = Panel.new()
	_anchor(_frame_bg, 0, 0, 1, 1)
	add_child(_frame_bg)

	# ART sits INSIDE the frame's beveled window — inset a touch from the
	# measured opening so it never rides over the bevel.
	_art_placeholder = ColorRect.new()
	_anchor(_art_placeholder, 0.075, 0.078, 0.925, 0.541)
	add_child(_art_placeholder)
	_art = TextureRect.new()
	_anchor(_art, 0.075, 0.078, 0.925, 0.541)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_art)

	# NAME + COST on the frame's TOP BORDER (no band behind them).
	_name_label = Label.new()
	_anchor(_name_label, 0.055, 0.002, 0.68, 0.060)
	_name_label.add_theme_font_size_override("font_size", _name_size)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.clip_text = true
	_name_label.add_theme_font_override("font", _title_font)
	_outline(_name_label)
	add_child(_name_label)
	_cost_holder = Control.new()
	_anchor(_cost_holder, 0.68, 0.004, 0.945, 0.058)
	add_child(_cost_holder)

	# SET SYMBOL at the right-hand end of that middle border, just below
	# the art — where a printed card carries it.
	_set_icon = TextureRect.new()
	_anchor(_set_icon, 0.878, 0.559, 0.925, 0.598)
	_set_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_set_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_set_icon)
	# Sets the original gave no symbol still name themselves, short.
	# Two labels so the ordinal suffix rides RAISED, as an edition is
	# written: the stem sits on the baseline, "nd"/"th" above it.
	_set_text = Label.new()
	_anchor(_set_text, 0.78, 0.552, 0.905, 0.604)
	_set_text.add_theme_font_override("font", _body_font)
	_set_text.add_theme_font_size_override("font_size", _illus_size + 1)
	_set_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_set_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(_set_text)
	add_child(_set_text)
	_set_suffix = Label.new()
	_anchor(_set_suffix, 0.905, 0.546, 0.955, 0.586)
	_set_suffix.add_theme_font_override("font", _body_font)
	_set_suffix.add_theme_font_size_override("font_size", _illus_size - 2)
	_set_suffix.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_set_suffix.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_outline(_set_suffix)
	add_child(_set_suffix)

	# TYPE LINE on the border strip between art and rules box. The band is
	# the original's own `Type` rect, y 0.552-0.604 of the card, which is
	# exactly one BigCardSubtitle line tall — so the strip and the type on
	# it are the same measurement, as they were in 1997.
	_type_label = Label.new()
	_anchor(_type_label, 0.075, 0.552, 0.845, 0.604)
	_type_label.add_theme_font_override("font", _title_font)
	_type_label.add_theme_font_size_override("font_size", _type_size)
	_type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type_label.clip_text = true
	_outline(_type_label)
	add_child(_type_label)

	# RULES TEXT inside the frame's white box (60%-91.7%). The flat
	# no-skin fallback paints that box itself.
	# Measured box: x 8.3%-91.7%. The text is INSET inside it so it isn't
	# flush against the left edge.
	_text_bg = ColorRect.new()
	_anchor(_text_bg, 0.083, TEXT_TOP, 0.917, PLATE_BOTTOM)
	add_child(_text_bg)
	_text_plate = TextureRect.new()
	_anchor(_text_plate, 0.083, TEXT_TOP, 0.917, PLATE_BOTTOM)
	_text_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_text_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_text_plate.visible = false
	add_child(_text_plate)
	# THE RULES TEXT IS A [ManaText], NOT A `Label`: the oracle text writes
	# its mana and tap costs as `{R}`/`{T}` codes, and this is the widget
	# that sets the 1997 sheet's own symbols in their place — wrapping,
	# measuring and drawing them as one paragraph, and falling back to the
	# braces as plain text when no skin is imported. Everything else about
	# it is a Label's API, including the theme overrides below.
	_oracle = ManaText.new()
	_anchor(_oracle, 0.118, TEXT_TOP + 0.019, 0.882, 0.902)
	_oracle.add_theme_font_size_override("font_size", _rules_size)
	_oracle.add_theme_constant_override("line_spacing", RULES_LINE_SPACING)
	# CLIPPED, as the original clips (`ETO_CLIPPED`): text that beats even
	# the smallest step of the ladder stops at the box instead of running
	# out over the bottom border and off the card.
	_oracle.add_theme_font_override("font", _body_font)
	add_child(_oracle)

	# P/T on the frame's BOTTOM BORDER, right-aligned (the printed card's
	# power/toughness box).
	_pt_label = Label.new()
	_anchor(_pt_label, 0.58, 0.920, 0.935, 0.995)
	_pt_label.add_theme_font_override("font", _body_font)
	_pt_label.add_theme_font_size_override("font_size", _pt_size)
	_pt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(_pt_label, PT_OUTLINE_SIZE)
	add_child(_pt_label)

	# THE ILLUSTRATOR, bottom-LEFT of that same bottom border — part 6 of
	# `Duel.hlp`'s "Parts of the Card", and where every card of this era
	# prints it. It shares the band with the P/T and CANNOT collide with
	# it: the credit stops at 0.56 and the P/T box starts at 0.58, so even
	# a `10/10` on a card credited to Anson Maddocks keeps its own room.
	# A name too long for 0.075-0.56 is ellipsized rather than shrunk or
	# wrapped — the same rule the small card's names follow.
	_artist_label = Label.new()
	_anchor(_artist_label, 0.075, 0.920, 0.56, 0.995)
	_artist_label.add_theme_font_override("font", _body_font)
	_artist_label.add_theme_font_size_override("font_size", _illus_size)
	_artist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_artist_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_artist_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_outline(_artist_label)
	add_child(_artist_label)

	# The card BACK covers the whole face, so it is added LAST (on top of
	# every other child) and simply toggled — see show_back().
	_back = Panel.new()
	_anchor(_back, 0, 0, 1, 1)
	_back.visible = false
	add_child(_back)


## THE `Expand` TOGGLE — `@MENU_FULLCARD` entry 1 (`UIStrings.txt:868`),
## `docs/duel-todo.md` §6.12. `Duel.hlp`, **Showcase**: *"If the whole
## text of a card does not fit into the text area of the Showcase, you can
## fix that. Right-click on the text area, then click on the **Expand**
## toggle. This causes the text area to grow, when necessary, to display
## the entire card text. If the expanded box becomes annoying, you can
## always toggle **Expand** off again."*
##
## The box grows UPWARD, over the art — the printed card's text box
## already runs down to the bottom border, so there is nowhere else for it
## to go. It is the setting the 1997 executable calls
## `ExpandTextBoxOnBigCard`, persisted like every other duel switch.
##
## **"WHEN NECESSARY" IS PART OF THE RULE, and it used not to be ours.**
## The toggle used to move the box to [constant TEXT_TOP_EXPANDED] for
## every card, so a Forest sat in a box half again too big. The help file
## (Tier 1) says *when necessary*, and Manalink's renderer (Tier 3) is that
## same sentence in C: it measures the text first and only then moves the
## top up, by exactly the overflow — `if (rect_rulestext->bottom -
## rect_rulestext->top < txt_hgt) { rect_rulestext->top =
## rect_rulestext->bottom - txt_hgt; ... }`
## (`fullcard_exclude_expanded_text_box`, `drawfullcard.c:1118-1127`).
## [constant TEXT_TOP_EXPANDED] is now a CEILING on that growth, not the
## one expanded position.
const TEXT_TOP := 0.603
const TEXT_TOP_EXPANDED := 0.455
## The bottom of the frame's rules plate, and so of the text box — the
## band [member _text_plate] cuts out of the frame texture. The original
## takes the same slice, `ExpandTop` 6050 / `ExpandHeight` 3220 of the
## frame image, i.e. 0.605-0.927 (`config.c:755-756`); ours is the band
## measured off `Cardbk_*.pic` directly.
const PLATE_BOTTOM := 0.915

## Kept as a flag rather than read back off the anchor: Godot stores an
## anchor as a 32-bit float, so `anchor_top == TEXT_TOP` is false against
## the double the constant is, and a comparison would answer "expanded"
## for a box that is not.
var _text_expanded := false


## The setting's key and its default, in ONE place. The three call sites
## in `duel_screen.gd` each carried their own `false`, and the Deck
## Builder's Showcase carried no reader at all — which is why a long card
## clipped there and nothing the player could reach would fix it
## (2026-09-05 playtest).
##
## THE DEFAULT IS NOW ON, and that costs the cards that already fit
## nothing: the box grows *when necessary* and by exactly the overflow
## (see [constant TEXT_TOP_EXPANDED]), so a Forest is framed identically
## either way. What changes is the 209 cards that had to drop a font step
## to fit and the seven that clipped anyway — the pool sweep reads 688
## cards at full ported size unexpanded and 812 expanded, with ZERO
## losing a line (`tests/ui/test_card_preview.gd`). `[QoL]`: the original
## shipped the toggle (`@MENU_FULLCARD` entry 1) but we do not know what
## it defaulted to, so this is our choice and is labelled as one.
const EXPAND_SETTING := "ExpandTextBoxOnBigCard"

## Whether the Showcase's text box should grow when the text needs it.
##
## FALSE, because the framing is the 1997 one. The box the original draws
## is part of how a card looks, and a build that quietly grew it for two
## hundred cards would be showing the player something MicroProse never
## did. The toggle is the answer instead — and the real defect the
## 2026-09-05 playtest found was not the default, it was that the Deck
## Builder never read this setting at all and that the only door to it was
## an undiscoverable right-click.
##
## What "off" costs is measured, not guessed: 209 of 897 cards drop a font
## step to fit and seven clip even then. One click on the Showcase's
## toggle takes all of them whole (`tests/ui/test_card_preview.gd`).
static func expand_wanted() -> bool:
	return bool(Settings.get_value(EXPAND_SETTING, false))


## Write the player's choice. ONE WRITER for both doors — the duel's
## `@MENU_FULLCARD` entry and the Deck Builder's toggle — so the two can
## never disagree about which key they mean.
static func set_expand(on: bool) -> void:
	Settings.set_value(EXPAND_SETTING, on)


func set_text_expanded(on: bool) -> void:
	_text_expanded = on
	# Re-lay-out the card ON SHOW: the player toggles this from the
	# Showcase's own right-click menu while looking at a card, so the card
	# in front of them has to answer.
	if _shown != null:
		show_card(_shown)
	else:
		_lay_out_text_box(TEXT_TOP)


## Is the Showcase's text box expanded right now?
func text_is_expanded() -> bool:
	return _text_expanded


## Put the text box's top at [param top] — plate, fallback ground and
## label together, so nothing can drift apart.
func _lay_out_text_box(top: float) -> void:
	_text_bg.anchor_top = top
	_text_plate.anchor_top = top
	_oracle.anchor_top = top + 0.019


## Where the text box's top has to be for [param text] at [param size] to
## fit, clamped to the box's own range. [constant TEXT_TOP] when the text
## already fits, which is the "when necessary" half of the help file's
## sentence.
func _needed_text_top(text: String, size: int) -> float:
	var width := (0.882 - 0.118) * SIZE.x
	var needed := _wrapped_height(_body_font, text, width, size)
	# 0.019 of the card is the label's own inset below the box's top, and
	# the extra pixel is slack: grown to exactly the measured height, the
	# box and the text agree only to within a float, and [method
	# _fit_rules_size] would then drop a step for nothing.
	var top: float = 0.902 - (needed + 1.0) / SIZE.y - 0.019
	return clampf(top, TEXT_TOP_EXPANDED, TEXT_TOP)


## The frame's own rules plate as a stretchable texture — the band the
## frame paints its text box on, cut out once per frame key.
static var _plate_cache: Dictionary = {}

static func _plate_texture(frame_key: String) -> Texture2D:
	if _plate_cache.has(frame_key):
		return _plate_cache[frame_key]
	var result: Texture2D = null
	var frame := GameSkin.texture(frame_key)
	if frame != null:
		var plate := AtlasTexture.new()
		plate.atlas = frame
		var w := float(frame.get_width())
		var h := float(frame.get_height())
		plate.region = Rect2(0.083 * w, TEXT_TOP * h,
			(0.917 - 0.083) * w, (PLATE_BOTTOM - TEXT_TOP) * h)
		result = plate
	_plate_cache[frame_key] = result
	return result


## Show the CARD BACK in the slot — what the sidebar holds before
## anything has been examined. The original never leaves that slot empty:
## a Magic card back sits there, face down, waiting. Uses the imported
## Cardback.pic (228x323, the same aspect the frame gives this Control),
## falling back to a plain dark card shape when no skin is imported.
func show_back() -> void:
	var art := GameSkin.texture("card_back")
	if art != null:
		var box := StyleBoxTexture.new()
		box.texture = art
		_back.add_theme_stylebox_override("panel", box)
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.18, 0.11, 0.06)         # card-back brown
		box.border_color = Color(0.07, 0.05, 0.03)
		box.set_border_width_all(9)
		box.set_corner_radius_all(10)
		_back.add_theme_stylebox_override("panel", box)
	_back.visible = true
	_shown = null
	_text_plate.visible = false
	visible = true


## Fill and show the preview for one card instance.
func show_card(inst: CardInstance) -> void:
	_back.visible = false
	_shown = inst
	var d := inst.data
	var frame_key := MiniCard.frame_skin_key(d)
	var skinned := GameSkin.texture(frame_key) != null
	_name_label.text = d.card_name
	_type_label.text = _type_line(d)
	# THE ONE-LINE LADDERS. The original condenses its title and type-line
	# faces to fit; we step the size down instead, and only for the names
	# and type lines long enough to need it.
	var text_w := (0.68 - 0.055) * SIZE.x
	_name_label.add_theme_font_size_override("font_size",
		_fit_one_line(_title_font, _name_label.text, text_w,
			[_name_size, _name_size - 2, _name_size - 4, _name_size - 6,
				_name_size - 8]))
	var type_w := (0.845 - 0.075) * SIZE.x
	_type_label.add_theme_font_size_override("font_size",
		_fit_one_line(_title_font, _type_label.text, type_w,
			[_type_size, _type_size - 2, _type_size - 4, _type_size - 6,
				_type_size - 8]))
	# The set symbol (none for Unlimited/promos, as printed).
	_set_icon.texture = GameSkin.set_icon(d.set_code)
	_set_icon.visible = _set_icon.texture != null
	_set_text.text = "" if _set_icon.visible else GameSkin.set_label(d.set_code)
	_set_text.visible = not _set_icon.visible
	_set_suffix.text = "" if _set_icon.visible \
		else GameSkin.set_label_suffix(d.set_code)
	_set_suffix.visible = _set_suffix.text != ""
	_oracle.text = d.oracle_text if d.oracle_text != "" else "(no rules text)"
	# THE TEXT BOX, then the type in it — in that order, because how big
	# the box is decides what fits. `Expand` grows it only as far as the
	# card needs (see [constant TEXT_TOP]); the ladder then takes the
	# largest step that still fits what the box ended up being.
	var top := _needed_text_top(_oracle.text, _rules_size) if _text_expanded \
		else TEXT_TOP
	_lay_out_text_box(top)
	_oracle.add_theme_font_size_override("font_size",
		_fit_rules_size(_oracle.text, top))
	_pt_label.text = _power_toughness(inst)
	# NO CREDIT AT ALL when we do not know the artist — never `Illus. ` with
	# nothing after it. `CardData.artist` comes from the `cards/data/`
	# snapshot, and an older snapshot (or a printing Scryfall does not
	# credit) simply leaves it empty.
	_artist_label.text = (ILLUS_PREFIX + d.artist) if d.artist != "" else ""
	_artist_label.visible = d.artist != ""
	# The credit steps down rather than losing the artist's surname to an
	# ellipsis: a fifth of the pool is credited to a name too long for the
	# corner at the full size (Margaret Organ-Kean, Kev Brockschmidt, the
	# Foglios together), and a name half-printed is worse than a name a
	# point smaller.
	_artist_label.add_theme_font_size_override("font_size",
		_fit_one_line(_body_font, _artist_label.text,
			(0.56 - 0.075) * SIZE.x,
			[_illus_size, _illus_size - 1, _illus_size - 2, _illus_size - 3]))
	# Cost icons (original mana symbols when available, text otherwise).
	# remove_child BEFORE queue_free: a freed child is still in
	# `get_children()` for the rest of the frame, and `show_card` runs on
	# every hover — sweeping the pointer across two cards in one frame drew
	# the second card's cost row ON TOP of the first's.
	for child in _cost_holder.get_children():
		_cost_holder.remove_child(child)
		child.queue_free()
	if d.cost.text != "":
		var row := ManaIcons.cost_row(d.cost.text, 13)
		if row == null:
			var cost_label := Label.new()
			cost_label.text = d.cost.text
			cost_label.add_theme_font_size_override("font_size", 13)
			cost_label.add_theme_color_override("font_color", BODY_INK)
			_outline(cost_label)
			row = HBoxContainer.new()
			row.add_child(cost_label)
		# Fill the top-border band and CENTRE the symbols in it: anchoring
		# to the band's midpoint let them hang below the border onto the
		# art (the owner caught the cost sitting too low).
		row.alignment = BoxContainer.ALIGNMENT_END
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for icon in row.get_children():
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_cost_holder.add_child(row)
	# Art, or the quiet identity-colored placeholder.
	var art := GameSkin.card_art(d.card_name)
	_art.texture = art
	_art.visible = art != null
	_art_placeholder.color = MiniCard.frame_color(d).darkened(0.55)
	# Undocked = the original's centered examine popup: park the card in
	# the middle of the screen every time it shows.
	if not docked and is_inside_tree():
		var view := get_viewport_rect().size
		global_position = (view - SIZE * scale.x) / 2.0
	# Frame paint: the imported 1997 frame, or the clean flat frame.
	# EITHER WAY the letters are the same colours — white on the card body,
	# dark on the rules plate — because both grounds are the same shape:
	# a dark body (five of the six imported frames, and the flat frame) or
	# a pale one (Cardbk_White) with a light plate in it. That is why the
	# ink no longer branches on `skinned`; branching on it is what put
	# near-black type on a black card body in the first place.
	if skinned:
		var box := StyleBoxTexture.new()
		box.texture = GameSkin.texture(frame_key)
		_frame_bg.add_theme_stylebox_override("panel", box)
		_text_bg.visible = false
		# The frame paints its plate only where the frame puts it; when the
		# box has grown past that, the frame's OWN plate is stretched over
		# the difference, so the rules text never lands on bare art.
		_text_plate.texture = _plate_texture(frame_key)
		_text_plate.visible = top < TEXT_TOP and _text_plate.texture != null
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.15, 0.13, 0.11)
		box.border_color = MiniCard.frame_color(d)
		box.set_border_width_all(7)
		box.set_corner_radius_all(10)
		_frame_bg.add_theme_stylebox_override("panel", box)
		_text_bg.visible = true
		_text_bg.color = Color(0.90, 0.87, 0.78)   # parchment rules box
		_text_plate.visible = false
	for label in [_name_label, _type_label, _pt_label, _set_text, _set_suffix,
			_artist_label]:
		label.add_theme_color_override("font_color", BODY_INK)
	_oracle.add_theme_color_override("font_color", RULES_INK)
	visible = true


## The largest step of [constant RULES_STEPS] whose wrapped text still fits
## the box whose top is at [param top].
func _fit_rules_size(text: String, top: float) -> int:
	var width := (0.882 - 0.118) * SIZE.x
	var height := (0.902 - top - 0.019) * SIZE.y
	var chosen: int = _rules_size + int(RULES_STEPS[RULES_STEPS.size() - 1])
	for step in RULES_STEPS:
		var size: int = _rules_size + int(step)
		if _wrapped_height(_body_font, text, width, size) <= height:
			chosen = size
			break
	return chosen


## The house treatment for a letter standing on the card's own body: a
## hard black outline under [constant BODY_INK]. See [constant
## OUTLINE_SIZE] for where the weight comes from.
static func _outline(label: Label, size := OUTLINE_SIZE) -> void:
	label.add_theme_color_override("font_outline_color", OUTLINE_INK)
	label.add_theme_constant_override("outline_size", size)


## Place the preview beside [param anchor_rect] (global), preferring the
## side with room, clamped fully on-screen.
func place_beside(anchor_rect: Rect2) -> void:
	if docked:
		return
	var view := get_viewport_rect().size
	var x := anchor_rect.position.x + anchor_rect.size.x + 10.0
	if x + SIZE.x > view.x:
		x = anchor_rect.position.x - SIZE.x - 10.0
	var y: float = clampf(anchor_rect.position.y - SIZE.y / 3.0,
		8.0, view.y - SIZE.y - 8.0)
	global_position = Vector2(clampf(x, 8.0, view.x - SIZE.x - 8.0), y)


static func _type_line(d: CardData) -> String:
	var parts := PackedStringArray()
	if d.supertypes & Mtg.Supertype.LEGENDARY:
		parts.append("Legendary")
	if d.supertypes & Mtg.Supertype.BASIC:
		parts.append("Basic")
	var type_names := {Mtg.CardType.ARTIFACT: "Artifact",
		Mtg.CardType.CREATURE: "Creature", Mtg.CardType.ENCHANTMENT: "Enchantment",
		Mtg.CardType.INSTANT: "Instant", Mtg.CardType.LAND: "Land",
		Mtg.CardType.SORCERY: "Sorcery"}
	for flag in type_names:
		if d.types & flag:
			parts.append(type_names[flag])
	var line := " ".join(parts)
	if not d.subtypes.is_empty():
		var subs := PackedStringArray()
		for s in d.subtypes:
			subs.append(String(s).capitalize())
		line += " — " + " ".join(subs)
	return line


## A card's PRINTED P/T as the original writes it, quirks included:
## - "*/*" for a creature whose printed P/T is 0/0 but whose statics set
##   it (Nightmare, Keldon Warlord — the original prints * too),
## - nothing at all for a non-creature.
##
## **THE SHOWCASE SHOWS THE PRINTED VALUES, ALWAYS** — manual p.114, on the
## Duel Options check boxes: *"The Show Power/Toughness check box determines
## whether or not the CURRENT power and toughness of each creature is
## displayed on the card in play. (The SHOWCASE always shows the ORIGINAL
## power and toughness.)"* — and p.118 generalises it: *"Note that the
## Showcase always displays the original card text. Any changes made to a
## card after it was put into play — modifications to the power, toughness,
## color, or what have you — are noted on the representation of the card
## IN PLAY, not here."*
##
## This used to return the LIVE stats for a battlefield card, which is the
## one place the 1997 division of labour was inverted: the SMALL card
## carries what changed, the big card carries what was printed. A
## Crusade'd Savannah Lions now reads 3/2 on the table and 2/1 here.
##
## `data` is repointed by `become_copy` (CR 707), so a copy or a token
## prints ITS card's values, which is correct.
static func _power_toughness(inst: CardInstance) -> String:
	var d := inst.data
	if not d.is_creature():
		return ""
	if d.power == 0 and d.toughness == 0 and not d.static_abilities.is_empty():
		return "*/*"
	return "%d/%d" % [d.power, d.toughness]
