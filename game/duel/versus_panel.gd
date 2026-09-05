class_name VersusPanel
extends Control
## THE MARBLE VERSUS BOARD — the 1997 `Winbk_Versus.pic` panel, and the one
## copy of it.
##
## Two windows in the duel wear this board and they must not drift apart:
## [DuelIntro], the pre-duel splash the original shows between `Go` and the
## coin toss, and [DuelPause], the Q/Esc menu the owner asked for on
## 2026-09-03 (*"This Q or ESC button menu should reuse the brown portraits
## window with buttons on the bottom"*). Everything they share lives here —
## the dim, the centred 500x400 board, the marble ground, the two sunken
## wells with a portrait in each, the `vs.` between them, the seat lettering
## and the optional title band — and each subclass adds only its own button
## row and its own way of leaving.
##
## THE MEASUREMENTS ARE THE ART'S, not a layout. `versus_splash` is 500x400
## and its two wells are 162x192 at (50, 59) and (281, 59), read off the
## file; the board lays itself out in exactly those coordinates so the faces
## land where the marble expects them.
##
## PALE LETTERS, and that is not a contradiction of [UiChrome]'s dark ink:
## this ground is dark brown marble, and the rule the original follows (and
## this project with it) is dark ink on light faces, pale ink on dark ones.
##
## NO CLOCK LIVES HERE. [DuelIntro]'s five-second auto-advance is
## [DuelIntro]'s own `_process`, deliberately not shared — a window called
## **Pause** that dismisses itself while you are reading it would be worse
## than no window at all.

## The art's own size, and the two wells inside it — measured, not guessed.
const SPLASH := Vector2(500, 400)
const WELLS: Array[Rect2] = [
	Rect2(50, 59, 162, 192),
	Rect2(281, 59, 162, 192),
]

## Letters on the marble.
const INK := Color(0.96, 0.94, 0.88)
const SHADOW := Color(0, 0, 0, 0.85)

## The band of bare marble ABOVE the wells — 59px of it — which is where a
## title goes when a subclass asks for one.
const TITLE_RECT := Rect2(0, 12, 500, 34)


## Build the shared board into this control and hand it back, so the
## subclass can hang its own buttons on it in the art's coordinates.
##
## [param title] is drawn in the band above the wells when it is not empty.
## [param show_decks] draws each seat's *"playing with <deck>"* line; the
## Pause window turns it off, because five buttons need that band.
func build_panel(config: DuelConfig, title := "", show_decks := true) -> Control:
	# `set_anchors_and_offsets_preset`, not `set_anchors_preset`: the
	# second moves the anchors and leaves the offsets, so this control
	# keeps a ZERO-SIZED rect at the origin and the board centred inside
	# it lands in the screen's top-left corner. (Cost one screenshot,
	# 2026-09-03.)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# ANCHORS AND OFFSETS TOGETHER, not a preset and then a position: a
	# centre preset writes all four offsets from the control's CURRENT
	# size, and moving `position` afterwards drags only two of them, which
	# is how the first build of this screen ended up hanging off the
	# top-left corner.
	var board := Control.new()
	board.anchor_left = 0.5
	board.anchor_right = 0.5
	board.anchor_top = 0.5
	board.anchor_bottom = 0.5
	board.offset_left = -SPLASH.x * 0.5
	board.offset_right = SPLASH.x * 0.5
	board.offset_top = -SPLASH.y * 0.5
	board.offset_bottom = SPLASH.y * 0.5
	board.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(board)

	var art := GameSkin.texture("versus_splash")
	if art != null:
		var ground := TextureRect.new()
		ground.texture = art
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		board.add_child(ground)
	else:
		# No imported art: the same shape in the clean skin's stone, so
		# the window still says who is playing whom.
		var flat := PanelContainer.new()
		flat.add_theme_stylebox_override("panel", UiChrome.stone_panel(0.0))
		flat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		board.add_child(flat)

	if title != "":
		var heading := make_label(title, 22)
		heading.position = TITLE_RECT.position
		heading.size = TITLE_RECT.size
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		board.add_child(heading)

	for pid in 2:
		_build_seat(board, config, pid, art != null, show_decks)

	var versus := make_label("vs.", 15)
	versus.size = Vector2(69, 20)
	versus.position = Vector2(212, 140)
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(versus)
	return board


## One seat: its face in the well, then its name and its deck under it.
func _build_seat(board: Control, config: DuelConfig, pid: int,
		skinned: bool, show_decks: bool) -> void:
	var well: Rect2 = WELLS[pid]
	var face := TextureRect.new()
	face.texture = portrait_for(config, pid)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.position = well.position + Vector2(6, 6)
	face.size = well.size - Vector2(12, 12)
	board.add_child(face)
	if not skinned:
		# Without the marble there is no well drawn under the face; give
		# it the clean skin's frame so it still reads as a portrait.
		var frame := Panel.new()
		frame.add_theme_stylebox_override("panel", UiChrome.stone_panel(0.0))
		frame.position = well.position
		frame.size = well.size
		board.add_child(frame)
		board.move_child(frame, face.get_index())

	var name_label := make_label(String(config.player_names[pid]), 16)
	name_label.position = Vector2(well.position.x - 20, well.end.y + 12)
	name_label.size = Vector2(well.size.x + 40, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(name_label)

	if not show_decks:
		return
	var deck_name := String(config.deck_names[pid])
	if deck_name == "":
		return          # a scene run or a test: say nothing rather than lie
	# A HOLDER, because a free-standing Label ignores its own width: Godot
	# clamps a Control to its minimum size, and a Label's minimum is the
	# whole string on one line — so "playing with Kiska-Ra - White Dragon"
	# grew straight off the marble instead of wrapping. Given a parent
	# with a fixed rect and FULL_RECT anchors inside it, the width is the
	# parent's and the wrap happens.
	var holder := Control.new()
	holder.position = Vector2(well.position.x - 9, well.end.y + 38)
	holder.size = Vector2(well.size.x + 18, 46)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(holder)
	var deck_label := make_label("playing with %s" % deck_name, 13)
	deck_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	holder.add_child(deck_label)


## The face a seat shows: the portrait it chose, or its duelist face,
## which the deck's dominant colour already decided.
static func portrait_for(config: DuelConfig, pid: int) -> Texture2D:
	var chosen := ""
	if config.portraits.size() > pid:
		chosen = String(config.portraits[pid])
	if chosen != "":
		var art := PortraitLibrary.texture(chosen)
		if art != null:
			return art
	return DuelistFace.portrait(String(config.panel_colors[pid]))


## One line of the marble's pale lettering, with the hard shadow that keeps
## it legible over the stone's grain.
func make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	var font := GameSkin.font("font_title")
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
