class_name CardListPane
extends PanelContainer
## A LIST OF CARDS IN A PANE — to look through (a creature's deck, shown by
## a wise man or the Guardian's Ghost: 1997's "Opponent library" list) or
## to pick one from (the wise man's copy: "Pick a spell"). The names in two
## columns with their counts, the card under the pointer large beside them,
## a right click reads it full screen ([method WorldScreen.read_card]).
## In the panes' rounded glass ([PaneStyle]).

## A card picked (pick mode).
signal picked(card_name: String)
## Done, or Never mind.
signal done
## A card right-clicked, to be read full screen.
signal card_read(card_name: String)

const LARGE := 0.78

## The cards, by name, with how many of each: `{name: count}`.
var cards := {}
## The title, and a line under it.
var title := ""
var subtitle := ""
## Whether a card is to be picked (Choose / Never mind) or only looked at
## (Done).
var picking := false
var k := 1.0
var chosen := ""
var _names: Array[String] = []
var _list: ItemList
var _large: CardPreview
var _choose: Button


## The counts of [param names], a card each: `{name: count}`.
static func counted(names: Array) -> Dictionary:
	var out := {}
	for card_name in names:
		out[String(card_name)] = int(out.get(String(card_name), 0)) + 1
	return out


func _ready() -> void:
	name = "CardList"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass())
	var across := HBoxContainer.new()
	across.add_theme_constant_override("separation", 14)
	across.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(across)
	var holder := Control.new()
	holder.custom_minimum_size = CardPreview.SIZE * LARGE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_large = CardPreview.new()
	_large.name = "Large"
	_large.docked = true
	_large.scale = Vector2(LARGE, LARGE)
	_large.mouse_filter = Control.MOUSE_FILTER_STOP
	_large.visible = false
	_large.gui_input.connect(func(input: InputEvent) -> void:
		if PaneStyle.right_click(input) and _large._shown != null:
			card_read.emit(_large._shown.data.card_name))
	holder.add_child(_large)
	across.add_child(holder)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(560, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.add_child(column)
	var heading := PaneStyle.title(title, 24)
	heading.name = "ListTitle"
	column.add_child(heading)
	if subtitle != "":
		column.add_child(PaneStyle.wrapped(subtitle, 15, 560, PaneStyle.DIM))
	_list = ItemList.new()
	_list.name = "ListCards"
	_list.max_columns = 2
	_list.same_column_width = true
	_list.fixed_column_width = 270
	_list.custom_minimum_size = Vector2(560, 300)
	_list.focus_mode = Control.FOCUS_NONE
	var face := GameSkin.font("font_title")
	if face != null:
		_list.add_theme_font_override("font", face)
	_list.add_theme_font_size_override("font_size", 15)
	_list.add_theme_color_override("font_color", PaneStyle.INK)
	_list.add_theme_color_override("font_hovered_color", PaneStyle.LIT)
	_list.add_theme_color_override("font_selected_color", PaneStyle.LIT)
	_list.add_theme_stylebox_override("panel", PaneStyle.well())
	_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_list.item_selected.connect(func(index: int) -> void: choose(_names[index]))
	_list.item_activated.connect(func(index: int) -> void:
		choose(_names[index])
		if picking:
			pick())
	_list.gui_input.connect(_list_input)
	column.add_child(_list)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(10 * k))
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picking:
		_choose = PaneStyle.button("Choose", "ListChoose", k)
		_choose.disabled = true
		_choose.pressed.connect(pick)
		buttons.add_child(_choose)
		var never := PaneStyle.button("Never mind", "ListNever", k)
		never.pressed.connect(func() -> void: done.emit())
		buttons.add_child(never)
	else:
		var close := PaneStyle.button("Done", "ListDone", k)
		close.pressed.connect(func() -> void: done.emit())
		buttons.add_child(close)
	column.add_child(buttons)
	_fill()


func _fill() -> void:
	_names.clear()
	for card_name in cards:
		_names.append(String(card_name))
	_names.sort()
	_list.clear()
	for card_name in _names:
		var count := int(cards[card_name])
		_list.add_item("%d %s" % [count, card_name] if count > 1 or not picking else card_name)
	if not _names.is_empty():
		show_large(_names[0])


## The card [param card_name] chosen: shown large; Choose is open.
func choose(card_name: String) -> void:
	chosen = card_name
	show_large(card_name)
	if _choose != null:
		_choose.disabled = chosen == ""


## The card chosen is picked.
func pick() -> void:
	if picking and chosen != "":
		picked.emit(chosen)


## Card [param card_name] large beside the list ([method PaneStyle.show_card]:
## not drawn again as the pointer moves over its row).
func show_large(card_name: String) -> void:
	if PaneStyle.show_card(_large, card_name):
		_large.visible = true


## The names listed, in order.
func names() -> Array[String]:
	return _names


func _list_input(input: InputEvent) -> void:
	var motion := input as InputEventMouseMotion
	var click := input as InputEventMouseButton
	var at := Vector2(-1, -1)
	if motion != null:
		at = motion.position
	elif click != null:
		at = click.position
	var index := _list.get_item_at_position(at, true) if at.x >= 0 else -1
	if index < 0 or index >= _names.size():
		return
	if motion != null:
		show_large(_names[index])
	elif PaneStyle.right_click(input):
		card_read.emit(_names[index])
		_list.accept_event()


func _unhandled_input(input: InputEvent) -> void:
	if input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		done.emit()
