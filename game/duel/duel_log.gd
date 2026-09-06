class_name DuelLog
extends Control
## THE DUEL LOG — `L` during a duel. `[QoL]`.
##
## The engine writes one line per mutation into [member MtgGame.log_lines]
## (*"the engine's audit trail: every mutation helper writes one, which is
## what makes a bug report reproducible from a seed plus a log"*), and
## until now the table threw every one of them away:
## [method DuelScreen._on_log_line] was `pass`, with the note that *"the
## original had none — a QoL log viewer returns later"*. This is that
## viewer, returned.
##
## WHY IT IS WORTH A WINDOW. The 1997 duel tells you what happened in the
## Situation Bar, one sentence at a time, and the sentence is gone the
## moment the next one lands. A blocker that killed something bigger than
## itself, a Circle of Protection that did or did not fire, a Strip Mine
## that took the wrong land — every playtest question of 2026-09-06 was of
## the form *"what just happened?"*, and the log has the answer in the
## engine's own words. It is also the half of a bug report the owner
## cannot write from memory: `Copy` puts the whole duel on the clipboard
## and `Save` writes it beside the F12 screenshots, so *"check my photo"*
## can come with the lines behind the photo.
##
## WHAT IT IS NOT. Not a modal and not a rung of the cancel ladder: the
## duel runs on under it, every key and click on the table still lands,
## and [method DuelScreen._modal_open] and `_dialogs_open` do not count it
## — the same standing as the [CombatWindow], which it borrows its bar,
## drag and clamp from. `Duel.hlp`, topic **Hands**: *"To move a hand
## window, click and drag on the bar at the top of the window"* — one
## gesture for every window on this table.
##
## Not 1997. The original has no log on any key, and `@MENU_TERRITORY` is
## the 1997 table verbatim — the menu greys what it cannot offer, it does
## not grow — so this lives on a bare key, the way `H` (s30's hand fold)
## and `M` (mute) do, and on nothing in the menus. Recorded in
## `docs/ROADMAP.md`.

## The ruled frame's own width (`OriginalDialog._rule`), as the combat
## window has it.
const EDGE := 4.0
## The title bar — the Situation Bar's stone, the combat window's height.
const TITLE_H := 28.0
## The window's size at rest. Wide enough for the engine's longest common
## sentence (*"SeatZero's damage to Serra Angel is prevented (circle of
## protection)"*) at 13px without wrapping most lines, and tall enough for
## a turn's worth of them.
const SIZE := Vector2(460.0, 320.0)
## Where the player last put it, remembered like the hand's and the
## combat window's are. Absence means "where the screen puts it".
const POS_SETTING := "duel_log_pos"
## A press moves a pixel or two under the finger; without a threshold
## every click on the bar would read as a drag. [StackHand]'s number.
const DRAG_SLOP := 4.0
## Text size. One step below the bar's 14: a log is read in bulk.
const FONT_SIZE := 13
## Where `Save` writes, beside `user://screenshot_<ms>.png` (F12).
const SAVE_PREFIX := "user://duel_log_"

## The window was closed by its own gadget — the screen forgets its
## handle on this, nothing more.
signal closed
## A line for the Situation Bar: where a save went, or that the log is on
## the clipboard. The screen owns the bar; this window only has the words.
signal notice(text: String)

## The reserve-strip control ([member DuelScreen._qol_reserve]'s third
## tenant, after Arrange and Expand): the same stone face, a glyph of a
## page of lines, and TOGGLE state that mirrors whether the window is up
## — so the button reads as the window's own switch, and closing the
## window by its gadget or its key un-presses it.
const FACE := Vector2(38, 30)
const GLYPH := Vector2i(24, 18)
const PAGE := Rect2i(4, 1, 16, 16)
const GLYPH_INK := Color8(28, 24, 26)
const GLYPH_LIT := Color8(250, 244, 214)

static var _glyph: ImageTexture = null


## The strip button. [param on_toggled] takes one bool: true opens the
## window, false closes it.
static func button(on_toggled: Callable) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = FACE
	btn.focus_mode = Control.FOCUS_NONE
	OriginalDialog.dress_bar_button(btn)
	btn.icon = glyph()
	btn.tooltip_text = "Duel log (L)"
	btn.toggled.connect(on_toggled)
	return btn


## A page of ruled lines, drawn here for the same reason Arrange's cards
## are: `Program/DuelArt/` has no icon for a command 1997 did not have.
static func glyph() -> ImageTexture:
	if _glyph != null:
		return _glyph
	var image := Image.create_empty(GLYPH.x, GLYPH.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(PAGE.position.y, PAGE.end.y):
		for x in range(PAGE.position.x, PAGE.end.x):
			var edge := y == PAGE.position.y or y == PAGE.end.y - 1 \
				or x == PAGE.position.x or x == PAGE.end.x - 1
			image.set_pixel(x, y, GLYPH_INK if edge else GLYPH_LIT)
	# Four lines of "text", the last one short — a paragraph, not a grid.
	var lines: Array[int] = [4, 7, 10, 13]
	for i in lines.size():
		var y: int = lines[i]
		var right := PAGE.end.x - 3 if i < lines.size() - 1 else PAGE.end.x - 7
		for x in range(PAGE.position.x + 3, right):
			image.set_pixel(x, y, GLYPH_INK)
	_glyph = ImageTexture.create_from_image(image)
	return _glyph


var _text: RichTextLabel = null
var _title: Label = null
var _count := 0

var _dragging := false
var _drag_moved := false
var _drag_from := Vector2.ZERO
var _drag_offset := Vector2.ZERO


func _init() -> void:
	# ABOVE the combat window (10) and the arrows (20) — a log the player
	# opened is the thing they are reading — but UNDER the hand (60), the
	# chain box (80) and every dialog (200): it must never sit on top of
	# a question.
	z_index = 40
	size = SIZE
	custom_minimum_size = Vector2(240.0, 120.0)

	# THE GROUND: the celtic-knot list ground (`Winbk_Changetext`), the
	# one the library picker's list wears, ruled by its own bevel.
	var ground := OriginalDialog.frame("panel_knot")
	if ground != null:
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ground)
	else:
		var fallback := Panel.new()
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.add_theme_stylebox_override("panel",
			OriginalDialog.panel_style("panel_knot", 0.0))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fallback)

	# THE TITLE BAR — the Situation Bar's own stone, the drag handle, with
	# the close gadget at the upper right corner where the combat window
	# keeps its Minimize. The pointer says it drags (CURSOR_MOVE) for the
	# same reason the combat window's does (2026-09-05).
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = EDGE
	bar.offset_right = -EDGE
	bar.offset_top = EDGE
	bar.offset_bottom = EDGE + TITLE_H
	bar.add_theme_stylebox_override("panel", OriginalDialog.bar_style(2.0))
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(_on_bar_input)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	_title = OriginalDialog.label("Duel log", 14, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title)
	var copy := OriginalDialog.bar_button("Copy", Vector2(48.0, 18.0))
	copy.tooltip_text = "Copy the whole log to the clipboard"
	copy.focus_mode = Control.FOCUS_NONE
	copy.pressed.connect(copy_to_clipboard)
	row.add_child(copy)
	var save := OriginalDialog.bar_button("Save", Vector2(48.0, 18.0))
	save.tooltip_text = "Save the log as a text file (beside the F12 screenshots)"
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(save_to_file)
	row.add_child(save)
	var close := OriginalDialog.bar_button("×", Vector2(22.0, 18.0))
	close.tooltip_text = "Close (L)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(dismiss)
	row.add_child(close)

	# THE LINES. A RichTextLabel for two things a Label cannot do: follow
	# its own tail — `scroll_following` sticks to the newest line ONLY
	# while the reader is already at the bottom, so scrolling up to read
	# an earlier turn is never yanked back — and colour the turn headers.
	# NO FOCUS: the table's keys (`Space`, `Return`, `L` itself) must keep
	# reaching [method DuelScreen._unhandled_key_input] with this open,
	# and a focused text control would swallow them.
	_text = RichTextLabel.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = EDGE + 6.0
	_text.offset_right = -(EDGE + 6.0)
	_text.offset_top = EDGE + TITLE_H + 6.0
	_text.offset_bottom = -(EDGE + 6.0)
	# ON THE DARK STONE, not on the knot: the knot is the window's frame
	# and the list ground the library picker uses INSIDE it is the grey
	# `Winbk_Questmana` stone — pale text on the knot's own blue-grey is
	# legible in a screenshot and tiring over a turn (checked by
	# looking, 2026-09-06). The same inset the picker's list wears.
	_text.add_theme_stylebox_override("normal",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	_text.bbcode_enabled = false
	_text.scroll_active = true
	_text.scroll_following = true
	_text.selection_enabled = true
	_text.focus_mode = Control.FOCUS_NONE
	_text.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text.add_theme_color_override("default_color", OriginalDialog.CHOICE)
	_text.add_theme_color_override("font_shadow_color", OriginalDialog.INK)
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	var body := GameSkin.font("font_body")
	if body != null:
		_text.add_theme_font_override("normal_font", body)
	add_child(_text)


## Fill from the whole log so far, then follow it line by line through
## [method append_line]. Called once, when the window opens mid-duel.
func fill(lines: PackedStringArray) -> void:
	_text.clear()
	_count = 0
	for line in lines:
		append_line(line)


## One more line — the screen forwards [signal MtgGame.log_appended] here.
func append_line(line: String) -> void:
	_count += 1
	var header := line.begins_with("== ")
	_text.push_color(OriginalDialog.CHOICE_LIT if header
		else OriginalDialog.CHOICE)
	# `add_text`, never `append_text`: a card name or an effect's own
	# words may carry a `[`, and this is a log, not markup.
	_text.add_text(line)
	_text.pop()
	_text.newline()
	_title.text = "Duel log  (%d lines)" % _count


## How many lines the window holds. Tests read this; so does the title.
func line_count() -> int:
	return _count


## The title bar's text, count and all.
func title_text() -> String:
	return _title.text


## The log as one string, a line each — what `Copy` and `Save` write.
func text() -> String:
	return _text.get_parsed_text()


## `Copy`: the whole log onto the clipboard, and a word on the bar.
func copy_to_clipboard() -> void:
	DisplayServer.clipboard_set(text())
	notice.emit("Duel log copied (%d lines)" % _count)


## `Save`: `user://duel_log_<ms>.txt`, the F12 screenshot's own naming,
## and the absolute path on the bar so the player can find it. Returns
## the path, or "" when the write failed (the bar says so too).
func save_to_file() -> String:
	var path := "%s%d.txt" % [SAVE_PREFIX, Time.get_ticks_msec()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		notice.emit("Could not write %s" % ProjectSettings.globalize_path(path))
		return ""
	file.store_string(text())
	file.close()
	notice.emit("Duel log saved: %s" % ProjectSettings.globalize_path(path))
	return path


## Close and free, once.
func dismiss() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


# --------------------------------------------------------------- the bar --

func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_moved = false
			_drag_from = get_global_mouse_position()
			_drag_offset = _drag_from - global_position
		else:
			if _dragging and _drag_moved:
				Settings.set_value(POS_SETTING, position)
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		if get_global_mouse_position().distance_to(_drag_from) > DRAG_SLOP:
			_drag_moved = true
		if _drag_moved:
			position = get_global_mouse_position() - _drag_offset
			_clamp_on_screen()


## NEVER OFF THE EDGE. A window dragged past the viewport cannot be
## dragged back, so the bar always stays reachable — the combat window's
## guard, for the same reason.
func _clamp_on_screen() -> void:
	var room := get_viewport_rect().size
	if room.x <= 0.0 or room.y <= 0.0:
		return
	position.x = clampf(position.x, -size.x + EDGE + 60.0, room.x - EDGE - 60.0)
	position.y = clampf(position.y, 0.0, room.y - EDGE - TITLE_H)


## Where the window opens: where the player last left it, or else the
## screen's own place for it — the upper right of the table, clear of
## the hand along the bottom and of the Phase Bar's column, over the
## opponent's territory where the cards that matter least to the reader
## are (their lands). Called once the window is in the tree, because the
## clamp needs a viewport.
func place(default_at: Vector2) -> void:
	position = default_at
	if Settings.has_value(POS_SETTING):
		var saved: Variant = Settings.get_value(POS_SETTING, Vector2.ZERO)
		if saved is Vector2:
			position = saved
	_clamp_on_screen()
