class_name QuestCardPane
extends PanelContainer
## THE CARD A QUEST ASKS FOR, CHOSEN BY THE HERO [ours; a player's report
## and the owner, 2026-11-26: a card quest took a Regrowth unasked, for one
## amulet]. 1997's card quest ([Quests], [constant Quests.CARD]) took the
## first card of the colour and class as the hero walked into the town.
## Here the town asks: "Which card will you give?" over the hero's cards
## that fit ([method Quests.cards_for_quest]), a row each — the name, the
## copies owned, the decks the copy that would go is in, its rarity and
## its 1997 price — the ones to spare first (a copy no deck holds, then
## the cheapest). The card under the pointer, or the row the keys are on,
## is shown large beside the list; a right click reads it full screen.
## A row chosen, the pane says what giving it means ("It is your only
## copy.", "It leaves Deck 1.") and "Give this card" gives it ([signal
## given]); "Not now" (Escape with no card chosen; with one chosen Escape
## first puts it back) gives nothing ([signal done]) — the quest stays under
## way. In the panes' rounded glass ([PaneStyle]), the size of the list of
## cards ([CardListPane]).
##
## WITH THE KEYS ALONE: the first row holds the keys as the pane opens;
## Up and Down walk the rows (the list scrolls with them), Enter or Space
## chooses the row and puts the keys on "Give this card", Left and Right
## go between the two buttons, Up goes back to the rows. A controller's
## pointer hops from row to row and button to button as on every pane, its
## right stick scrolls the list; with the pointer off its D-pad walks as
## the arrow keys do.

## The card of this name is given.
signal given(card_name: String)
## "Not now".
signal done
## A card right-clicked, to be read full screen ([method
## WorldScreen.read_card]).
signal card_read(card_name: String)

const LARGE := 0.78
const WIDTH := 560.0
const LIST_HEIGHT := 300.0
const RARITY_WORDS: Array[String] = ["", "Common", "Uncommon", "Rare", "Special"]
const TITLE := "Which card will you give?"
const ASKS := "The keeper of %s asks for a %s. The card you give is gone for good."
const CHOOSE := "%d cards fit. Choose one, or keep them all for now."
const CHOOSE_ONE := "One card fits. Choose it, or keep it for now."
const GIVE := "Give %s?"
const ONLY_COPY := "It is your only copy."
const COPIES_LEFT := "You keep %d."
const LEAVES_DECK := "It leaves Deck %s."
const LEAVES_DECKS := "It leaves Decks %s."

var player: AdventurePlayer
var k := 1.0
## The card chosen, "" for none.
var chosen := ""
## The rows ([method Quests.cards_for_quest]) and their buttons, in order.
var _rows: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _scroll: ScrollContainer
## The rows' column: where a controller's `First choice` looks for the
## pane's first choice ([method WorldScreen._first_choice]) — the first
## row, the card to spare.
var _choices: VBoxContainer
var _large: CardPreview
var _ask: Label
var _give: Button
var _not_now: Button
## Whether the card was given ([method give] gives it once).
var _given := false


func _ready() -> void:
	name = "QuestCard"
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
	column.custom_minimum_size = Vector2(WIDTH, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.add_child(column)
	var heading := _words(TITLE, 24, PaneStyle.GOLD)
	heading.name = "QuestCardTitle"
	column.add_child(heading)
	var asks := _words(asks_text(), 15, PaneStyle.DIM)
	asks.name = "QuestCardAsks"
	asks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asks.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_child(asks)
	_scroll = ScrollContainer.new()
	_scroll.name = "QuestCards"
	_scroll.custom_minimum_size = Vector2(WIDTH, LIST_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.add_theme_stylebox_override("panel", PaneStyle.well())
	column.add_child(_scroll)
	var list := VBoxContainer.new()
	_choices = list
	list.name = "Rows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(list)
	_rows = Quests.cards_for_quest(player) if player != null else ([] as Array[Dictionary])
	for row in _rows:
		var button := _row(row)
		_buttons.append(button)
		list.add_child(button)
	_ask = _words("", 16, PaneStyle.INK)
	_ask.name = "QuestCardAsk"
	_ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask.custom_minimum_size = Vector2(WIDTH, 44)
	column.add_child(_ask)
	var buttons := HBoxContainer.new()
	buttons.name = "QuestCardChoices"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(10 * k))
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_give = PaneStyle.button("Give this card", "QuestCardGive", k)
	_give.pressed.connect(give)
	buttons.add_child(_give)
	_not_now = PaneStyle.button("Not now", "QuestCardNotNow", k)
	_not_now.pressed.connect(func() -> void:
		if not _given:
			done.emit())
	buttons.add_child(_not_now)
	column.add_child(buttons)
	for button: Button in [_give, _not_now]:
		_take_keys(button)
	_wire_keys()
	choose("")
	if not _buttons.is_empty():
		show_large(String(_rows[0]["name"]))
		_buttons[0].grab_focus.call_deferred()
	else:
		_not_now.grab_focus.call_deferred()


## What the town asks, under the title.
func asks_text() -> String:
	if player == null or not Quests.has_quest(player):
		return ""
	var destination := int(player.quest.get("destination", -1))
	return ASKS % [WorldNames.site_name(player.world, destination),
		Quests.spell_name(int(player.quest.get("color", 1)), destination)]


## Lettering of the pane: the 1997 title face from 15 points up, plain.
static func _words(text: String, size: int, color: Color) -> Label:
	var line := Label.new()
	line.text = text
	var face := GameSkin.font("font_title")
	if face != null and size >= 15:
		line.add_theme_font_override("font", face)
	line.add_theme_font_size_override("font_size", size)
	line.add_theme_color_override("font_color", color)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## What a row says beside the card's name: "2 owned · Deck 1 · Rare · 150
## gold" (no deck named for a copy no deck holds).
static func facts_text(row: Dictionary) -> String:
	var parts: Array[String] = ["%d owned" % int(row.get("copies", 1))]
	var decks: Array = row.get("decks", [])
	if not decks.is_empty():
		parts.append(("Deck %s" if decks.size() == 1 else "Decks %s") % _deck_numbers(decks))
	var rarity := clampi(int(row.get("rarity", 0)), 0, RARITY_WORDS.size() - 1)
	if RARITY_WORDS[rarity] != "":
		parts.append(RARITY_WORDS[rarity])
	parts.append("%d gold" % int(row.get("price", 0)))
	return " · ".join(parts)


## "1" or "1, 3": the decks as the player counts them.
static func _deck_numbers(decks: Array) -> String:
	var numbers: Array[String] = []
	for deck: Variant in decks:
		numbers.append(str(int(deck) + 1))
	return ", ".join(numbers)


## What giving the card of [param row] means, for the pane to ask: "Give
## Regrowth? It is your only copy. It leaves Deck 1."
static func give_text(row: Dictionary) -> String:
	var parts: Array[String] = [GIVE % String(row.get("name", ""))]
	var copies := int(row.get("copies", 1))
	parts.append(ONLY_COPY if copies <= 1 else COPIES_LEFT % (copies - 1))
	var decks: Array = row.get("decks", [])
	if not decks.is_empty():
		parts.append((LEAVES_DECK if decks.size() == 1 else LEAVES_DECKS) % _deck_numbers(decks))
	return " ".join(parts)


## A row's button: the name left, its facts right; it takes the keys.
func _row(row: Dictionary) -> Button:
	var card_name := String(row["name"])
	var button := PaneStyle.button("", "", k)
	button.name = "Row_%d" % _buttons.size()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 30 * k)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inside := HBoxContainer.new()
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 10
	inside.offset_right = -10
	inside.add_theme_constant_override("separation", 10)
	var called := _words(card_name, int(15 * k), PaneStyle.INK)
	called.name = "RowName"
	called.clip_text = true
	called.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	called.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inside.add_child(called)
	var facts := _words(facts_text(row), int(13 * k), PaneStyle.DIM)
	facts.name = "RowFacts"
	facts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inside.add_child(facts)
	button.add_child(inside)
	_take_keys(button)
	# The row pressed is the row chosen, whatever its toggle came to.
	button.pressed.connect(func() -> void: choose(card_name))
	button.mouse_entered.connect(func() -> void: show_large(card_name))
	button.focus_entered.connect(func() -> void: show_large(card_name))
	button.gui_input.connect(func(input: InputEvent) -> void:
		if PaneStyle.right_click(input):
			show_large(card_name)
			card_read.emit(card_name)
			button.accept_event())
	return button


## [param button] takes the keys and wears a gold rim while it has them.
static func _take_keys(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = PaneStyle.GOLD
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(6)
	button.add_theme_stylebox_override("focus", rim)


## Where the arrow keys go: up and down the rows, from the last row down
## to the buttons, between the buttons, and from them up to the row chosen
## (the last row with none).
func _wire_keys() -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		var above := _buttons[maxi(i - 1, 0)]
		var below: Button = _buttons[i + 1] if i + 1 < _buttons.size() else _not_now
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)
		button.focus_previous = button.get_path_to(above)
		button.focus_next = button.get_path_to(below)
	_give.focus_neighbor_right = _give.get_path_to(_not_now)
	_give.focus_neighbor_left = _give.get_path_to(_give)
	_give.focus_neighbor_bottom = _give.get_path_to(_give)
	_give.focus_next = _give.get_path_to(_not_now)
	_not_now.focus_neighbor_left = _not_now.get_path_to(_give)
	_not_now.focus_neighbor_right = _not_now.get_path_to(_not_now)
	_not_now.focus_neighbor_bottom = _not_now.get_path_to(_not_now)
	_not_now.focus_previous = _not_now.get_path_to(_give)
	_up_from_buttons()


func _up_from_buttons() -> void:
	var at := index_of(chosen)
	if at < 0:
		at = _buttons.size() - 1
	for button: Button in [_give, _not_now]:
		var up: Button = _buttons[at] if at >= 0 else button
		button.focus_neighbor_top = button.get_path_to(up)


## The row of card [param card_name], −1 for none.
func index_of(card_name: String) -> int:
	for i in _rows.size():
		if String(_rows[i]["name"]) == card_name:
			return i
	return -1


## The names listed, in order.
func names() -> Array[String]:
	var out: Array[String] = []
	for row in _rows:
		out.append(String(row["name"]))
	return out


## The rows listed ([method Quests.cards_for_quest]).
func rows() -> Array[Dictionary]:
	return _rows


## CHOOSE card [param card_name] ("" none): its row lit, what giving it
## means asked, "Give this card" open — and the keys on it when they were
## on a row.
func choose(card_name: String) -> void:
	var at := index_of(card_name)
	chosen = card_name if at >= 0 else ""
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == at)
	_give.disabled = at < 0
	# A button that cannot be pressed takes no keys.
	_give.focus_mode = Control.FOCUS_ALL if at >= 0 else Control.FOCUS_NONE
	if at >= 0:
		_ask.text = give_text(_rows[at])
		show_large(chosen)
	elif _rows.size() == 1:
		_ask.text = CHOOSE_ONE
	else:
		_ask.text = CHOOSE % _rows.size()
	if not is_inside_tree():
		return
	_up_from_buttons()
	var held := get_viewport().gui_get_focus_owner()
	if at >= 0 and held == _buttons[at]:
		_give.grab_focus()
	elif at < 0 and (held == _give or held == null) and not _buttons.is_empty():
		_buttons[0].grab_focus()


## GIVE the card chosen — once.
func give() -> void:
	if chosen == "" or _given:
		return
	_given = true
	given.emit(chosen)


func ask_text() -> String:
	return _ask.text


## Card [param card_name] large beside the list ([method PaneStyle.show_card]:
## not drawn again as the pointer moves over its row).
func show_large(card_name: String) -> void:
	if PaneStyle.show_card(_large, card_name):
		_large.visible = true


## The card shown large, "" for none.
func shown_large() -> String:
	return _large._shown.data.card_name if _large.visible and _large._shown != null else ""


func _unhandled_input(input: InputEvent) -> void:
	if input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _given:
			return
		if chosen != "":
			var at := index_of(chosen)
			choose("")
			if at >= 0:
				_buttons[at].grab_focus()
		else:
			done.emit()
