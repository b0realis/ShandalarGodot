class_name SaveSlotsPane
extends PanelContainer
## SAVE THE ADVENTURE (the options' Save, Ctrl+S; the owner, 2026-10-23:
## *"Add 10 named slots"*) — 1997's save list (`RunLoadSaveMenu` in save
## mode): ten rows, each a slot's name or "(Empty)"; a click on one lets its
## name be typed (the old name in it, nothing for an empty one), Enter
## saves into it, Escape puts the name back — and Escape again, or Done,
## closes the list. In the panes' glass ([PaneStyle]).
## [Ours: any letters and marks (1997 took letters, digits and spaces), at
## most [constant LONGEST] of them; a blank name becomes the day and the
## place ("Day 12 near Kraag Temple"); the list says where it was saved and
## shows when each slot was.]

signal done
## Saved into a slot: the file written.
signal saved(path: String)

const LONGEST := 40

var player: AdventurePlayer
var k := 1.0
## The slot whose name is being typed, 0 for none.
var editing := 0
## The ten slots as last read ([method SaveSlots.slots_of]): picking a
## slot to name it remakes the rows from these, reading no file
## (campaign of 2026-10-23: every pick read every save in the folder).
var _slots: Array[Dictionary] = []
var _rows: VBoxContainer
var _note: Label
var _edit: LineEdit


func _ready() -> void:
	name = "SaveSlots"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(560, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(PaneStyle.title("Save the adventure", 24))
	column.add_child(PaneStyle.label("Click a slot, name it, and press Enter.", 15, PaneStyle.DIM))
	_rows = VBoxContainer.new()
	_rows.name = "Slots"
	_rows.add_theme_constant_override("separation", 4)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rows)
	_note = PaneStyle.label("", 15, PaneStyle.GOLD)
	_note.name = "Note"
	column.add_child(_note)
	var close := PaneStyle.button("Done", "SaveDone", k)
	close.pressed.connect(func() -> void: done.emit())
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(close)
	refresh()


## The ten rows as the files now stand.
func refresh() -> void:
	_slots = SaveSlots.slots_of(player.adventure_id)
	_show_rows()


## The ten rows remade from the slots as last read.
func _show_rows() -> void:
	PaneStyle.drop_children(_rows)
	_edit = null
	for entry in _slots:
		_rows.add_child(_row(entry))


func _row(entry: Dictionary) -> Control:
	var slot := int(entry["slot"])
	var row := HBoxContainer.new()
	row.name = "Slot_%d" % slot
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := PaneStyle.label(str(slot), 16, PaneStyle.GOLD)
	number.custom_minimum_size = Vector2(26, 0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)
	if slot == editing:
		_edit = LineEdit.new()
		_edit.name = "SlotName"
		_edit.max_length = LONGEST
		_edit.text = "" if bool(entry["empty"]) or bool(entry.get("damaged", false)) else String(entry["name"])
		_edit.placeholder_text = SaveSlots.default_name(player)
		_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_edit.text_submitted.connect(func(text: String) -> void: save_into(slot, text))
		row.add_child(_edit)
		_focus_later(_edit)
	else:
		var pick := PaneStyle.button(String(entry["name"]), "Pick_%d" % slot, k, 15)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if bool(entry["empty"]) or bool(entry.get("damaged", false)):
			pick.add_theme_color_override("font_color", PaneStyle.DIM)
		pick.pressed.connect(edit.bind(slot))
		row.add_child(pick)
	# On the player's clock (the file keeps UTC).
	var stamp := PaneStyle.label(AdventurePlayer.local_time(String(entry.get("saved", ""))), 13, PaneStyle.DIM)
	stamp.custom_minimum_size = Vector2(130, 0)
	row.add_child(stamp)
	return row


## The name box [param box] takes the keys once the frame is done, the
## caret at its end — unless a second pick in the same frame has made the
## rows again and dropped it (the bug pass after the campaign, r3-3: an
## `ERROR` for a box no longer in the tree).
func _focus_later(box: LineEdit) -> void:
	(func() -> void:
		if is_instance_valid(box) and box.is_inside_tree():
			box.grab_focus()
			box.set_caret_column(box.text.length())).call_deferred()


## Type a name for slot [param slot].
func edit(slot: int) -> void:
	editing = slot
	_note.text = ""
	_show_rows()


## SAVE into slot [param slot] by [param slot_name] ([method
## SaveSlots.save_into]).
func save_into(slot: int, slot_name: String) -> String:
	var path := SaveSlots.save_into(player, slot, slot_name)
	editing = 0
	refresh()
	_note.text = ("Saved to slot %d: %s." % [slot, player.slot_name]) if path != "" \
		else "The adventure could not be saved."
	if path != "":
		saved.emit(path)
	return path


func note() -> String:
	return _note.text


func _unhandled_input(input: InputEvent) -> void:
	if input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if editing != 0:
			editing = 0
			_show_rows()
		else:
			done.emit()


func _input(input: InputEvent) -> void:
	# Escape inside the name being typed puts the old name back (the line
	# edit would otherwise keep it).
	if editing != 0 and _edit != null and _edit.has_focus() and input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		editing = 0
		_show_rows()
