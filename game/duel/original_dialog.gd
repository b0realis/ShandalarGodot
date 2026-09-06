class_name OriginalDialog
extends Control
## THE 1997 POPUP. One component for every centre dialog, message box and
## button in the duel, so they all wear the same chrome — which is what
## the owner means by "the original has a different style of button,
## border, text".
##
## Nothing here is invented. Every number below was measured with PIL on
## the original files (`tools/import_original.py` imports them; the survey
## is recorded in docs/duel-screen-design.md, twenty-eighth pass):
##
## THE FRAME. Each 1997 dialog ground bakes its own bevel into its edge
## pixels — a 2-4px HIGHLIGHT along top+left and the same width of SHADOW
## along bottom+right — so a NinePatchRect of exactly that width
## reproduces the window frame at any size. `PANELS` carries the measured
## width per ground plus whether its middle may TILE (a stone speckle) or
## must STRETCH (a picture).
##
## THE BUTTON. `Winbk_Startduelbutton{Normal,Depressed,Disabled}.pic`
## (131x36) is the only generic button art in DuelArt and it defines the
## era's button language: a DOUBLE rule — 2px highlight (207,209,209) on
## top+left, 2px slate shadow (82,111,140) on bottom+right, 3px of
## speckled face, then that pair AGAIN 5-6px in, then the face. Normal is
## raised twice; Depressed inverts both rules; Disabled inverts only the
## inner one. A 9-patch margin of 8 keeps both rules intact at any size.
##
## THE TEXT. Two voices, both taken from the art: PALE (207,209,209) with
## a hard one-pixel dark (28,24,26) shadow on the dark grounds — the
## Situation Bar's "Fast Effects?...Discard Phase" — and DARK INK
## (28,24,26) on the light button face, which is exactly how the original
## letters its own DONE button (Statbutt cells 11-13: dark letters on a
## light face).
##
## Wording comes from the 1997 string table, `shandalar-src/Program/
## UIStrings.txt` — see `docs/glossary-1997.md`. `@DIALOGBUTTONS` is
## "OK / Cancel / Done" and nothing else.

## The 1997 duel palette (`shandalar-src/Duel.plogpal`), by role.
const HIGHLIGHT := Color8(207, 209, 209)   ## top/left rule; pale text
const SHADOW := Color8(82, 111, 140)       ## bottom/right rule (slate)
const INK := Color8(28, 24, 26)            ## outline; letters on a light face
const CHOICE := Color8(205, 176, 143)      ## an unpicked list line
const CHOICE_LIT := Color8(247, 240, 208)  ## the line under the pointer

## Measured per ground: 9-patch margin (= the baked bevel's own width,
## plus a pixel of texture so a corner never samples the face) and
## whether the middle TILES.
##
## TILE only where the window is always SMALLER than its ground, so
## exactly one tile is laid and clipped — that keeps the stone's grain at
## its native scale with no seam. A window WIDER than its ground would
## lay a second tile and show the join, which no 1997 window does; those
## grounds stretch instead, and a stone speckle stretched by a third is
## invisible where a seam is not.
## The keys whose ART is LIGHT, and whose skinless fallback must be light
## too — see [method panel_style]. Everything not named here falls back
## dark, which is right for the dark stone, the knot and the end-duel ring.
const LIGHT_PANELS := {"panel_stone": true, "versus_background": true}

const PANELS := {
	# Winbk_Options 400x350 — sandstone, 2px bevel. The general dialog.
	"panel_stone": {"margin": 4, "tile": false},
	# Winbk_Questmana 289x274 — dark grey stone, 3px bevel. Questions.
	"panel_dark_stone": {"margin": 5, "tile": false},
	# Winbk_Changetext 481x323 — blue celtic knot, 3px bevel. Lists.
	"panel_knot": {"margin": 5, "tile": false},
	# Winbk_Endduel 272x422 — blue/gold rings, 3px INSET bevel. The last
	# word of a duel is carved in, not raised.
	"panel_end_duel": {"margin": 5, "tile": false},
	# Winbk_Bigcard 552x402 — a painting (a skeleton rider); never tile.
	"big_card_panel": {"margin": 5, "tile": false},
	# Winbk_Startduel 659x394 — the classical line-art mourners, the
	# START-OF-DUEL window's own ground (OpeningWindow, duel-todo §6.19).
	# Measured: 3px of dithered highlight (174,180,204)/(184,184,184) along
	# top+left, 3px of dithered shadow (114,138,144)/(147,147,147) along
	# bottom+right. A PICTURE, so its middle stretches — and the window
	# that wears it is sized to its aspect so that stretch stays uniform.
	"versus_background": {"margin": 4, "tile": false},
	# Winbk_Telluser 600x35 — the Situation Bar's stone. The ONE ground
	# with no bevel of its own: `bar_style()` rules it instead. The bar is
	# never as wide as 600, so its single tile keeps the stone 1:1.
	"message_panel": {"margin": 3, "tile": true},
}

## The button art's frame: 2px rule + 3px face + 2px rule = 7, plus one.
const BUTTON_MARGIN := 8

signal closed


var _body: VBoxContainer = null
var _buttons: HBoxContainer = null


# ------------------------------------------------------------- the frame --

## A NinePatchRect wearing [param key]'s ground, its patch margins set to
## that ground's own measured bevel width. Null when the skin is absent.
static func frame(key: String) -> NinePatchRect:
	var art := GameSkin.texture(key)
	if art == null:
		return null
	var spec: Dictionary = PANELS.get(key, {"margin": 4, "tile": true})
	var patch := NinePatchRect.new()
	patch.texture = art
	patch.patch_margin_left = spec["margin"]
	patch.patch_margin_top = spec["margin"]
	patch.patch_margin_right = spec["margin"]
	patch.patch_margin_bottom = spec["margin"]
	if spec["tile"]:
		# A stone speckle keeps its own grain at any window size; smearing
		# a 289px stone across 600px is what made our dialogs look painted
		# rather than built.
		patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
		patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	patch.set_anchors_preset(Control.PRESET_FULL_RECT)
	return patch


## The same ground as a StyleBox, for Panel/PanelContainer/Button slots
## that take a stylebox rather than a child node.
static func panel_style(key: String, content_margin := 10.0) -> StyleBox:
	var art := GameSkin.texture(key)
	if art != null:
		var spec: Dictionary = PANELS.get(key, {"margin": 4, "tile": true})
		var box := StyleBoxTexture.new()
		box.texture = art
		box.texture_margin_left = spec["margin"]
		box.texture_margin_top = spec["margin"]
		box.texture_margin_right = spec["margin"]
		box.texture_margin_bottom = spec["margin"]
		if spec["tile"]:
			box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
			box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		box.set_content_margin_all(content_margin)
		return box
	# No skin: the same GEOMETRY in flat colour, so layout never shifts.
	# AND THE SAME VALUE. A near-black box for EVERY key was wrong for the
	# light grounds: `panel_stone` is sandstone, its callers letter it in
	# dark ink, and a player with no imported art therefore got dark ink on
	# a dark face (found 2026-09-04 in the Deck Builder's pause menu, which
	# had to work around it locally). The fallback now keeps each key's
	# LIGHTNESS, not just its geometry. The colours are spelled out here
	# rather than taken from [code]UiChrome.flat_panel[/code] because
	# [code]UiChrome[/code] already calls [method focus_ring] — reaching
	# back would make the two classes cyclic.
	var flat := StyleBoxFlat.new()
	if LIGHT_PANELS.has(key):
		flat.bg_color = Color8(196, 179, 146)   # UiChrome.FACE
		flat.border_color = Color8(120, 100, 70)  # UiChrome.FACE_EDGE
	else:
		flat.bg_color = Color(0.16, 0.14, 0.12)
		flat.border_color = Color(0.45, 0.38, 0.26)
	flat.set_border_width_all(2)
	flat.set_content_margin_all(content_margin)
	return flat


# ------------------------------------------------- the Situation Bar rule --

## The Situation Bar's ground. `Winbk_Telluser.pic` is 600x35 of mottled
## red-brown stone with NO frame of its own (measured: every edge row and
## column is plain texture), yet the original's bar clearly carries "a
## thin lighter inset border line running around the inside" — so the bar
## is stone RULED by the same routine that draws the buttons. This paints
## that rule onto a copy of the tile: the era's dark outline at the very
## edge and the highlight one pixel in, raised (light top/left) or sunken.
static func bar_texture(raised := true) -> ImageTexture:
	return ruled_texture("message_panel", raised)


## The same treatment for any BEVEL-LESS 1997 ground. Two files in DuelArt
## carry no frame of their own and are meant to be framed in code:
## `Winbk_Telluser` (the Situation Bar) and `Winbk_Attack` (the Combat
## window's field of skulls). Both are ruled by the routine below, so the
## bar and the window read as the same piece of furniture.
static func ruled_texture(key: String, raised := true) -> ImageTexture:
	var art := GameSkin.texture(key)
	if art == null:
		return null
	var img := art.get_image().duplicate()
	img.convert(Image.FORMAT_RGBA8)
	return _rule(img, raised)


## A ruled ground as a StyleBox. Patch margin 4 keeps the outline and the
## inset rule crisp while the texture between them tiles at 1:1 — which is
## what these grounds want, since both are larger than the surfaces we lay
## them on and a single tile is therefore laid and clipped.
static func ruled_style(key: String, content_margin := 6.0,
		raised := true) -> StyleBox:
	var tex := ruled_texture(key, raised)
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.20, 0.18, 0.15)
		flat.border_color = HIGHLIGHT
		flat.set_border_width_all(1)
		flat.set_content_margin_all(content_margin)
		return flat
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = 4
	box.texture_margin_top = 4
	box.texture_margin_right = 4
	box.texture_margin_bottom = 4
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.set_content_margin_all(content_margin)
	return box


## THE SITUATION BAR'S OWN BUTTON — a LIGHTENED patch of the bar's stone,
## ruled by the same routine, lettered pale.
##
## The owner arbitrated this against the reading that shipped first
## (2026-08-31): in his 1997 photo the duel's Done button is a TAN/SALMON
## mottled face with a light blue-grey label, and his photo is the
## authority. It cannot come from a button sprite — `Statbutt.spr`'s DONE
## cells are plainly GREY, and `Winbk_Startduelbutton*.pic` is light
## BLUE-GREY. What it matches is the bar it sits on: the same mottle,
## lighter. So the original does not blit a button onto the Situation Bar
## at all — it rules a lightened patch of the bar's own Telluser stone,
## which is why the button shares the bar's texture and its warm cast.
##
## [param gain] multiplies the stone's own channels rather than blending
## it toward white: a palette ramp brightens a colour along its own hue,
## so a gain keeps the stone's warmth where `lightened()` washes it out to
## beige. At 1.55 the bar's mean RGB(125,89,93) becomes ~(194,138,144) —
## the photo's tan/salmon face.
static func bar_button_texture(pressed := false, gain := 1.55) -> ImageTexture:
	var art := GameSkin.texture("message_panel")
	if art == null:
		return null
	var img := art.get_image().duplicate()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r * gain, 1.0),
				minf(c.g * gain, 1.0), minf(c.b * gain, 1.0), c.a))
	return _rule(img, not pressed)


## Paint the era's frame onto [param img]: the dark outline at the very
## edge and the highlight/shadow pair one pixel in, raised or sunken.
## Shared by the bar and the bar's button so they are ruled identically.
## How wide the era's rule is, measured on `Winbk_Startduelbutton`
## (`assets/original/button_normal.png`, 131x36): rows 0 AND 1 are pure
## HIGHLIGHT right across the top and columns 0 and 1 right down the left,
## with the last two rows and columns pure SHADOW. TWO pixels, hard
## against the edge, and NO black outline anywhere.
const RULE_WIDTH := 2


static func _rule(img: Image, raised: bool) -> ImageTexture:
	# THE RULE IS THE ART'S OWN, remeasured 2026-09-03 after the owner's
	# playtest note on the Situation Bar — *"in the central message I am
	# missing the lighter border"*. It was: a 1px INK outline at the very
	# edge with ONE pale pixel two in from it, which reads as a hairline on
	# a dark board and is not what any 1997 ground does. The button art
	# above says 2px of HIGHLIGHT hard against the top and left edge, 2px
	# of SHADOW against the bottom and right, and no outline at all.
	#
	# The corners are MITRED, which the art also settles: at the top-right
	# the pale band steps down one pixel per column into the slate one
	# (x=w-1 is slate at y=0 while x=w-2 is still pale; at y=1 both are
	# slate), and the bottom-left mirrors it. Whichever edge is NEARER
	# wins, with the shadow taking a tie — which reproduces that step
	# exactly.
	var w: int = img.get_width()
	var h: int = img.get_height()
	var top := HIGHLIGHT if raised else SHADOW
	var bottom := SHADOW if raised else HIGHLIGHT
	for y in h:
		for x in w:
			var near_tl: int = mini(y, x)
			var near_br: int = mini(h - 1 - y, w - 1 - x)
			if near_br < RULE_WIDTH and near_br <= near_tl:
				img.set_pixel(x, y, bottom)
			elif near_tl < RULE_WIDTH:
				img.set_pixel(x, y, top)
	return ImageTexture.create_from_image(img)


## The Done button as it sits on the Situation Bar (see
## bar_button_texture). Pale letters, not the dark ink a dialog button on
## a light grey face wants.
static func bar_button(label: String, min_size := Vector2(64, 24)) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_ALL
	return dress_bar_button(btn)


## Put the bar's own stone on a button that already exists — the same
## chrome [method bar_button] applies, for callers that need a SUBCLASS of
## Button rather than a fresh one (ArrangeButton). Returns [param btn] so
## it composes; falls back to the flat button when the skin is absent,
## which is the same condition that leaves the whole table unskinned.
static func dress_bar_button(btn: Button) -> Button:
	var raised := bar_button_texture(false)
	if raised == null:
		return _flat_button(btn)
	btn.add_theme_stylebox_override("normal", _stone_box(raised))
	var depressed := _stone_box(bar_button_texture(true))
	btn.add_theme_stylebox_override("pressed", depressed)
	# HOVER_PRESSED IS NOT OPTIONAL. Godot draws `hover_pressed` while a
	# button is held down WITH THE CURSOR ON IT, and falls back to the
	# DEFAULT theme's box when nobody overrides it — so the depressed art
	# only appeared once the pointer left the button, which is what the
	# 2026-09-03 playtest reported: "nothing happens under the cursor -
	# button reads pressed only when the cursor is moved away".
	btn.add_theme_stylebox_override("hover_pressed", depressed)
	btn.add_theme_stylebox_override("disabled",
		_stone_box(bar_button_texture(false, 1.18)))
	var hover := _stone_box(bar_button_texture(false, 1.78))
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", focus_ring())
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(state, HIGHLIGHT)
	btn.add_theme_color_override("font_disabled_color", Color8(140, 128, 126))
	btn.add_theme_font_size_override("font_size", 14)
	return btn


## THE FOCUS BOX IS A RING, NOT A FACE.
##
## Godot paints `focus` ON TOP of the draw-mode box — probed on the pinned
## 4.7.2 with a toggle carrying five differently-coloured boxes: a focused
## button reads the focus colour whatever its state or latch. So binding
## `focus` to an opaque face hides `pressed` and `hover_pressed` outright,
## which silently undoes the 2026-09-03 fix that named those states in the
## first place — for every button that has focus. And
## [method UiChrome.explain_popup] focuses its OK button as it opens, so
## the button the player is about to press was exactly the one that could
## not show the press.
##
## Found by the Deck Builder pass, which measured it rather than reasoning
## about it, and fixed here because all three call sites share this file's
## chrome.
static var _focus_ring: StyleBoxFlat = null

static func focus_ring() -> StyleBoxFlat:
	if _focus_ring == null:
		_focus_ring = StyleBoxFlat.new()
		_focus_ring.draw_center = false
		_focus_ring.border_color = HIGHLIGHT
		_focus_ring.set_border_width_all(1)
	return _focus_ring


static func _stone_box(tex: ImageTexture) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = 4
	box.texture_margin_top = 4
	box.texture_margin_right = 4
	box.texture_margin_bottom = 4
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.set_content_margin_all(5)
	return box


## The ruled Situation Bar as a StyleBox. Patch margin 4 keeps the outline
## and the inset rule crisp while the stone between them tiles.
static func bar_style(content_margin := 6.0) -> StyleBox:
	return ruled_style("message_panel", content_margin)


# ------------------------------------------------------------ the button --

## THE button: the 1997 three-state art, 9-patched so the double rule
## survives at any size, lettered in dark ink the way the original letters
## its own DONE. Godot wants five states and the original ships three —
## hover reuses `normal` brightened (the era had no hover at all; a mouse
## cue is a modern affordance we owe the player), focus follows hover.
static func button(label: String, min_size := Vector2(96, 26)) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_ALL
	var normal := _button_style("button_normal")
	if normal == null:
		return _flat_button(btn)
	btn.add_theme_stylebox_override("normal", normal)
	var depressed := _button_style("button_pressed")
	btn.add_theme_stylebox_override("pressed", depressed)
	# See dress_bar_button: without this the press is invisible while the
	# cursor is still on the button.
	btn.add_theme_stylebox_override("hover_pressed", depressed)
	btn.add_theme_stylebox_override("disabled",
		_button_style("button_disabled"))
	var hover := _button_style("button_normal")
	hover.modulate_color = Color(1.14, 1.14, 1.12)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", focus_ring())
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_color_override("font_hover_color", INK)
	btn.add_theme_color_override("font_pressed_color", INK)
	btn.add_theme_color_override("font_disabled_color", Color8(110, 110, 112))
	btn.add_theme_font_size_override("font_size", 14)
	return btn


static func _button_style(key: String) -> StyleBoxTexture:
	var art := GameSkin.texture(key)
	if art == null:
		return null
	var box := StyleBoxTexture.new()
	box.texture = art
	box.texture_margin_left = BUTTON_MARGIN
	box.texture_margin_top = BUTTON_MARGIN
	box.texture_margin_right = BUTTON_MARGIN
	box.texture_margin_bottom = BUTTON_MARGIN
	# The face is a speckle: tile it so a wide button is not a smear.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.set_content_margin_all(6)
	return box


## No skin imported: the same bevel geometry drawn flat, so the button
## reads the same shape and every layout measurement still holds.
static func _flat_button(btn: Button) -> Button:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.68, 0.68, 0.66)
		if state == "hover":
			box.bg_color = Color(0.78, 0.78, 0.76)
		elif state == "pressed" or state == "hover_pressed":
			box.bg_color = Color(0.54, 0.54, 0.53)
		elif state == "disabled":
			box.bg_color = Color(0.52, 0.52, 0.52)
		box.border_color = INK
		box.set_border_width_all(1)
		box.set_content_margin_all(6)
		btn.add_theme_stylebox_override(state, box)
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_color_override("font_hover_color", INK)
	return btn


# -------------------------------------------------------------- the text --

## PALE text with the era's hard one-pixel dark shadow — the Situation
## Bar's voice, and every line that sits on a dark ground.
static func label(text: String, size := 14, bold := false) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", HIGHLIGHT)
	lab.add_theme_color_override("font_shadow_color", INK)
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	if bold:
		# The original's bar type is heavy; Godot's default face has no
		# bold cut, so weight it with a hairline outline in its own colour.
		lab.add_theme_constant_override("outline_size", 1)
		lab.add_theme_color_override("font_outline_color", HIGHLIGHT)
	var body := GameSkin.font("font_body")
	if body != null:
		lab.add_theme_font_override("font", body)
	return lab


## DARK INK, for the LIGHT grounds — the sandstone Winbk_Options and the
## button face. The era uses exactly two voices and both are readable off
## the art: pale-with-a-dark-shadow on dark stone (the Situation Bar), and
## dark letters on a light face (the original's own DONE button, Statbutt
## cells 11-13). The pale outline here does for ink what the dark shadow
## does for pale text — lifts it off a speckle without needing a text box.
static func ink_label(text: String, size := 14) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", Color8(46, 32, 12))
	lab.add_theme_color_override("font_outline_color", Color8(226, 219, 190))
	lab.add_theme_constant_override("outline_size", 4)
	var body := GameSkin.font("font_body")
	if body != null:
		lab.add_theme_font_override("font", body)
	return lab


## A NUMERIC FIELD, for the dialogs that ask for an amount (the original's
## own is @DIALOG_FIREBALL's "Generic mana to put into the spell:").
## A field is the bevel RUN BACKWARDS — shadow on top and left, highlight
## on bottom and right, so the box reads as cut INTO the stone, the same
## inversion the Depressed button art makes.
static func field(min_width := 96.0) -> SpinBox:
	var spin := SpinBox.new()
	spin.custom_minimum_size.x = min_width
	var sunken := StyleBoxFlat.new()
	sunken.bg_color = INK
	sunken.border_color = SHADOW
	sunken.set_border_width_all(1)
	sunken.border_width_right = 0
	sunken.border_width_bottom = 0
	sunken.set_content_margin_all(4)
	var line := spin.get_line_edit()
	line.add_theme_stylebox_override("normal", sunken)
	line.add_theme_stylebox_override("focus", sunken)
	line.add_theme_stylebox_override("read_only", sunken)
	line.add_theme_color_override("font_color", HIGHLIGHT)
	line.add_theme_color_override("caret_color", HIGHLIGHT)
	line.add_theme_font_size_override("font_size", 15)
	var body := GameSkin.font("font_body")
	if body != null:
		line.add_theme_font_override("font", body)
	return spin


## A TEXT FIELD on the dark stone — the box the Filter strip's type-ahead
## wears, the Deck Info title field, and the Load Deck list's finder, so a
## place to type looks the same wherever a dialog offers one. Pale letters
## on `panel_dark_stone`, the placeholder a shade dimmer than the letters
## so an empty field still says what it is for.
static func text_field(placeholder := "",
		min_size := Vector2(360, 28)) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = min_size
	for state in ["normal", "focus"]:
		edit.add_theme_stylebox_override(state,
			panel_style("panel_dark_stone", 5.0))
	edit.add_theme_color_override("font_color", CHOICE_LIT)
	edit.add_theme_color_override("caret_color", CHOICE_LIT)
	edit.add_theme_color_override("font_placeholder_color",
		Color(0.72, 0.68, 0.60, 0.7))
	var body := GameSkin.font("font_body")
	if body != null:
		edit.add_theme_font_override("font", body)
	return edit


## A CLICKABLE LIST LINE — the original's dialogs answer a question by
## offering lines, not radio buttons (Primal Clay's "Creature type?",
## `prompts.txt:670`). Tan when idle, pale under the pointer.
static func choice_line(text: String) -> Button:
	var line := Button.new()
	line.flat = true
	line.text = text
	line.alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 14)
	line.add_theme_color_override("font_color", CHOICE)
	line.add_theme_color_override("font_hover_color", CHOICE_LIT)
	line.add_theme_color_override("font_focus_color", CHOICE_LIT)
	line.add_theme_color_override("font_pressed_color", CHOICE_LIT)
	var body := GameSkin.font("font_body")
	if body != null:
		line.add_theme_font_override("font", body)
	return line


# ------------------------------------------------------------ the dialog --

## Build a centred modal on [param panel_key]'s ground. `title_text` is
## the window's own line (the 1997 dialogs title themselves in their body,
## e.g. `Start of Duel`, `@DIALOG_STARTCOINFLIP`); pass "" for none.
static func create(title_text: String, size: Vector2,
		panel_key := "panel_dark_stone") -> OriginalDialog:
	var dialog := OriginalDialog.new()
	dialog.name = "OriginalDialog"
	dialog.size = size
	# KEEP_SIZE writes real offsets around the centre anchor; the bare
	# preset leaves them at 0 and hangs the panel off screen-centre.
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER,
		Control.PRESET_MODE_KEEP_SIZE)
	dialog.z_index = 200

	var ground := frame(panel_key)
	if ground != null:
		dialog.add_child(ground)
	else:
		var fallback := Panel.new()
		fallback.add_theme_stylebox_override("panel",
			panel_style(panel_key, 0.0))
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		dialog.add_child(fallback)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, 16)
	column.add_theme_constant_override("separation", 10)
	dialog.add_child(column)

	if title_text != "":
		var head := label(title_text, 18, true)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(head)

	dialog._body = VBoxContainer.new()
	dialog._body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog._body.add_theme_constant_override("separation", 8)
	column.add_child(dialog._body)

	dialog._buttons = HBoxContainer.new()
	dialog._buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog._buttons.add_theme_constant_override("separation", 12)
	column.add_child(dialog._buttons)
	return dialog


## Where callers put the dialog's content.
func body() -> VBoxContainer:
	return _body


## Add a button to the dialog's foot. Use the 1997 labels — `@DIALOGBUTTONS`
## is "OK", "Cancel", "Done".
func add_button(text: String) -> Button:
	var btn := button(text)
	_buttons.add_child(btn)
	return btn


## Close and free, emitting [signal closed] once.
func dismiss() -> void:
	closed.emit()
	queue_free()
