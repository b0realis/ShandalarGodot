class_name HallOfFamePane
extends PanelContainer
## THE HALL OF FAME, SHOWN (part C, stage C2) — every adventure won, best
## first ([HallOfFame], its file and its order), in the panes' rounded
## glass ([PaneStyle]). The owner (2026-10-27): *"Hall of Fame — each won
## adventure kept (name, face, colour, difficulty, score, days, wins,
## date), best first, shown after the win"*, and *"Only hall of fame button
## should be inside save/load as not to clutter the main menu!"* — so it
## opens from a button in the saved adventures ([LoadAdventureScreen]: the
## title's Save / Load, and Load over the world), from the save slots over
## the world ([SaveSlotsPane]), and after the win ([AdventureFinale], the
## new line lit and the last choice under it) — never from the main menu.
## 1997 had no ranking (its shell named a "Hall of Fame: View Game Records."
## it never filled, Uistrings.txt @SHELLSCREEN_RECORDS). [ours]
##
## A LINE: its place, the hero's face, name, color, the level (and "One
## life" for an adventure won under that rule), the years Arzakon is
## banished, the days on the road, the duels won and the day it was won,
## on the player's clock. One line is LIT ([member lit], the adventure just
## won) and scrolled into sight. No adventure won yet: a line says how one
## gets here; a Hall's file that cannot be read ([method HallOfFame.damaged])
## says that instead, and that it is kept (part C stage C3, h3-4).
##
## WHERE IT STANDS ([method open]): centred over whatever opened it, a dim
## veil under it taking every click meant for what lies beneath, both gone
## together. Its choices ([member choices], "Done" unless the opener gives
## its own) answer to their first letter as every pane's do ([method
## VisitPane.letter_choice]); Escape is "Done" when there is one, else
## nothing (the win's last choice must be made). The list scrolls only when
## it is longer than the screen allows — fitted again, and centred, when
## the window changes size (part C stage C3, h5-4) —; the big buttons
## ([constant WorldHud.BIG]) grow the choices, not the list.

## A choice made: its id ("done" for Done).
signal chosen(what: String)

const TITLE := "Hall of Fame"
const ABOUT := "Every adventure won, best first: the most years, then the harder level, then the fewer days."
const EMPTY := "No adventure has been won yet. Free Shandalar from the five wizards and banish Arzakon, and your name will stand here."
const DAMAGED := "The Hall of Fame could not be read: its file is damaged, or was written by a newer version of the game. It is kept untouched until the Hall is next written, and then set aside beside the new one."
const DONE := "Done"
const ONE_LIFE := "One life"
## The columns: header words and widths (the face has no header).
const COLUMNS := [["", 34.0], ["", 34.0], ["Hero", 210.0], ["Color", 64.0], ["Level", 150.0],
	["Banished for", 120.0], ["Days", 64.0], ["Wins", 56.0], ["Won on", 104.0]]
## A face's size on a line.
const FACE := Vector2(26, 32)
## The room kept free above and below the pane, in all.
const ROOM_MARGIN := 48.0
## The veil's shade under the pane.
const VEIL := Color(0, 0, 0, 0.55)

## The size factor of the choices: 1, or [constant WorldHud.BIG].
var k := 1.0
## The adventure whose line is lit ("" for none).
var lit := ""
## The choices under the list, each `[id, words]`.
var choices: Array = [["done", DONE]]
## The lines shown, best first; read from the Hall's file as the pane opens
## when none were given.
var entries: Array[Dictionary] = []
var _given := false
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _choices: HBoxContainer
var _lit_row: Control


## THE HALL OVER [param host], centred, a veil under it: [param size_k] the
## choices' size, [param lit_id] the line to light, [param with] the
## choices (`[[id, words], …]`; empty for Done). The pane, in the tree.
static func open(host: Node, size_k := 1.0, lit_id := "", with: Array = []) -> HallOfFamePane:
	var veil := ColorRect.new()
	veil.name = "HallVeil"
	veil.color = VEIL
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pane := HallOfFamePane.new()
	pane.k = size_k
	pane.lit = lit_id
	if not with.is_empty():
		pane.choices = with
	host.add_child(pane)
	PaneStyle.centre(pane)
	pane.tree_exiting.connect(func() -> void:
		if is_instance_valid(veil):
			veil.queue_free())
	return pane


func _ready() -> void:
	name = "HallOfFame"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass(16.0))
	if not _given:
		entries = HallOfFame.entries()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var title := PaneStyle.title(TITLE, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var about := PaneStyle.label(ABOUT, 14, PaneStyle.DIM)
	about.name = "About"
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(about)
	if entries.is_empty():
		var unread := not _given and HallOfFame.damaged()
		var none := PaneStyle.wrapped(DAMAGED if unread else EMPTY, 17, _width() * 0.7)
		none.name = "Empty"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(none)
	else:
		column.add_child(_line(_header(), false, "Header"))
		_scroll = ScrollContainer.new()
		_scroll.name = "Lines"
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.add_theme_stylebox_override("panel", PaneStyle.well(4.0))
		_rows = VBoxContainer.new()
		_rows.name = "Rows"
		_rows.add_theme_constant_override("separation", 2)
		_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scroll.add_child(_rows)
		column.add_child(_scroll)
		for i in entries.size():
			var row := _line(_cells(i + 1, entries[i]), String(entries[i].get("id", "")) == lit and lit != "",
				"Line_%d" % (i + 1))
			_rows.add_child(row)
			if String(entries[i].get("id", "")) == lit and lit != "":
				_lit_row = row
		_fit_scroll()
	_choices = HBoxContainer.new()
	_choices.name = "Choices"
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", int(12 * k))
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for choice in choices:
		var button := PaneStyle.button(String(choice[1]), "Choice_" + String(choice[0]), k)
		button.pressed.connect(func() -> void: chosen.emit(String(choice[0])))
		_choices.add_child(button)
	column.add_child(_choices)
	if _lit_row != null:
		_show_lit.call_deferred()
	# A window made larger or smaller, a device turned: fitted again.
	get_viewport().size_changed.connect(_refit)


## THE PANE FITTED AGAIN to the window's new size: the list's height, the
## pane shrunk to what it holds and centred, the lit line kept in sight.
func _refit() -> void:
	if not is_inside_tree():
		return
	_fit_scroll()
	reset_size()
	PaneStyle.centre(self)
	if _lit_row != null:
		_show_lit.call_deferred()


## The lines shown are [param lines] (best first), not the Hall's file —
## set before the pane is in the tree.
func show_entries(lines: Array[Dictionary]) -> void:
	entries = lines
	_given = true


## The whole width of a line: its columns and their gaps.
func _width() -> float:
	var out := 0.0
	for column in COLUMNS:
		out += float(column[1]) + 8.0
	return out + 16.0


## The list's height: every line while they fit the screen, else as many as
## do, the rest scrolled to.
func _fit_scroll() -> void:
	if _scroll == null:
		return
	var room := (get_viewport_rect().size.y if is_inside_tree() else 800.0) - ROOM_MARGIN
	# The title, the line about the order, the header, the choices and the
	# pane's own margins.
	var rest := 150.0 + 46.0 * k
	var wanted := _rows.get_combined_minimum_size().y + 10.0
	_scroll.custom_minimum_size = Vector2(_width(), clampf(wanted, 48.0, maxf(room - rest, 120.0)))


## The lit line scrolled into sight, once the list is laid out.
func _show_lit() -> void:
	if is_instance_valid(_lit_row) and is_instance_valid(_scroll) and _scroll.is_inside_tree():
		_scroll.ensure_control_visible(_lit_row)


## The header's cells.
func _header() -> Array[Control]:
	var out: Array[Control] = []
	for column in COLUMNS:
		out.append(PaneStyle.label(String(column[0]), 14, PaneStyle.DIM))
	return out


## Line [param place]'s cells for [param entry].
func _cells(place: int, entry: Dictionary) -> Array[Control]:
	var out: Array[Control] = []
	var number := PaneStyle.label(str(place), 16, PaneStyle.GOLD)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	out.append(number)
	var face := TextureRect.new()
	face.name = "Face"
	face.texture = PortraitLibrary.texture(String(entry.get("portrait", "")))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = FACE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.append(face)
	var hero := PaneStyle.label(String(entry.get("name", "")), 16, PaneStyle.INK)
	hero.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hero.clip_text = true
	out.append(hero)
	var color := AdventureSetup.color_row(String(entry.get("color", "")))
	out.append(PaneStyle.label(String(color.get("name", "")), 15, PaneStyle.INK))
	var level := String(AdventureSetup.DIFFICULTIES[clampi(int(entry.get("difficulty", 0)), 0, 3)])
	if String(entry.get("life_rule", "")) == AdventurePlayer.LIFE_ONE:
		level += " · " + ONE_LIFE
	out.append(PaneStyle.label(level, 15, PaneStyle.INK))
	out.append(PaneStyle.label("%d years" % int(entry.get("score", 0)), 16, PaneStyle.GOLD))
	out.append(PaneStyle.label(str(int(entry.get("days", 0))), 15, PaneStyle.INK))
	out.append(PaneStyle.label(str(int(entry.get("wins", 0))), 15, PaneStyle.INK))
	out.append(PaneStyle.label(AdventurePlayer.local_time(String(entry.get("date", ""))).left(10), 14,
		PaneStyle.DIM))
	return out


## A line of [param cells] in the columns' widths; [param shine] lights it.
func _line(cells: Array[Control], shine: bool, line_name: String) -> Control:
	var holder := PanelContainer.new()
	holder.name = line_name
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := StyleBoxFlat.new()
	face.set_corner_radius_all(6)
	face.content_margin_left = 6
	face.content_margin_right = 6
	face.content_margin_top = 2
	face.content_margin_bottom = 2
	face.bg_color = Color(PaneStyle.GOLD, 0.2) if shine else Color(0, 0, 0, 0)
	face.border_color = Color(PaneStyle.GOLD, 0.8)
	face.set_border_width_all(1 if shine else 0)
	holder.add_theme_stylebox_override("panel", face)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in cells.size():
		var cell := cells[i]
		cell.custom_minimum_size.x = float(COLUMNS[i][1])
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cell)
	holder.add_child(row)
	return holder


## The lines shown, for tests: each line's cells' words (the face's "").
func lines() -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	if _rows == null:
		return out
	for holder in _rows.get_children():
		var words := PackedStringArray()
		for cell in (holder as Control).get_child(0).get_children():
			words.append((cell as Label).text if cell is Label else "")
		out.append(words)
	return out


## The place (1 the first) of the lit line, 0 for none.
func lit_place() -> int:
	return _lit_row.get_index() + 1 if is_instance_valid(_lit_row) else 0


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		for choice in choices:
			if String(choice[0]) == "done":
				chosen.emit("done")
				return
	elif VisitPane.letter_choice(self, _choices, event):
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	VisitPane.drop_letter(_choices, event)
