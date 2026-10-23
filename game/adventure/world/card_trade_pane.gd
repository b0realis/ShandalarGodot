class_name CardTradePane
extends PanelContainer
## THE CARD TRADER (the owner, 2026-10-23: *"Build all trade features"*) —
## 1.3's card browser (`RunCardBrowser`, 00532aeb, on `tradscrn.pic`) and
## its trade (`BuyAnyCardFromTown`, 00530b90), in the world's rounded glass:
## "Which card do you seek?" over every card the trade may give
## ([CardTrade]), by name in two columns, each with the copies the hero
## owns ("Serra Angel-2"; dimmed when the deck in use may hold no more,
## still to be had), chips for the colours and the types (a town's own
## kind of card fixed, as 1997 fixed it) and a name to look for [ours]; the
## card under the pointer shown large; chosen, "I'll trade you 1 Serra
## Angel for 3 white amulets." — "Do you wish to trade?", "Yes, I'll
## trade." / "No Thanks", or "Hmmm... you can't afford this card yet."
## Trades go on until Done. The purse and the five amulets show below.

## Done: back to the town or the lair.
signal done
## A card right-clicked, to be read full screen ([method
## WorldScreen.read_card]).
signal card_read(card_name: String)

const GOLD := Color8(232, 190, 110)
const INK := Color8(236, 222, 196)
const DIM := Color8(160, 146, 128)
const FAINT := Color8(120, 108, 96)
const LIT := Color8(255, 236, 170)
const EDGE := Color8(20, 10, 8)
const LARGE := 0.78
## The colour chips (1997 colour bits) and the type chips (1997 type bits).
const COLOR_CHIPS: Array[Array] = [["Colorless", 1], ["Black", 2], ["Blue", 4], ["Green", 8],
	["Red", 16], ["White", 32]]
const TYPE_CHIPS: Array[Array] = [["Land", 1], ["Summon", 2], ["Enchantment", 4], ["Sorcery", 8],
	["Instant", 16], ["Interrupt", 32], ["Artifact", 64]]

var player: AdventurePlayer
## [constant CardTrade.TOWN], [constant CardTrade.BAZAAR] or
## [constant CardTrade.MINE].
var way := CardTrade.TOWN
## A town's trade: its site slot, what it takes ([member
## ShandalarWorld.sites]' `trade`) and the colour of amulet it wants.
var slot := -1
var trade := 0
var color := ""
## Who trades, under the title.
var who := ""
var k := 1.0
## The card chosen, and what is asked for it ([method CardTrade.offer]).
var chosen := ""
var asked := {}
## The chips on: a colour bit and a type bit, 0 for all.
var color_filter := 0
var type_filter := 0
var _list: ItemList
var _large: CardPreview
var _gold: Label
var _purse: Label
var _ask: Label
var _yes: Button
var _no: Button
var _note: Label
var _search: LineEdit
var _shown: Array[String] = []
var _chips := {}


func _ready() -> void:
	name = "CardTrade"
	mouse_filter = Control.MOUSE_FILTER_STOP
	if way == CardTrade.TOWN and trade & 0xFF != 0:
		color_filter = trade & 0xFF
	elif way == CardTrade.TOWN and trade >> 8 > 0 and trade >> 8 < CardTrade.CLASS_TYPES.size():
		type_filter = CardTrade.CLASS_TYPES[trade >> 8]
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.05, 0.03, 0.03, 0.95)
	face.border_color = Color(GOLD, 0.6)
	face.set_border_width_all(1)
	face.set_corner_radius_all(10)
	face.set_content_margin_all(14)
	add_theme_stylebox_override("panel", face)
	var across := HBoxContainer.new()
	across.add_theme_constant_override("separation", 14)
	across.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(across)
	var holder := Control.new()
	holder.name = "LargeHolder"
	holder.custom_minimum_size = CardPreview.SIZE * LARGE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_large = CardPreview.new()
	_large.name = "Large"
	_large.docked = true
	_large.scale = Vector2(LARGE, LARGE)
	_large.mouse_filter = Control.MOUSE_FILTER_STOP
	_large.gui_input.connect(func(input: InputEvent) -> void:
		if CardShopPane._right_click(input) and _large._shown != null:
			card_read.emit(_large._shown.data.card_name))
	_large.visible = false
	holder.add_child(_large)
	across.add_child(holder)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size = Vector2(600, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("Which card do you seek?", 24, GOLD)
	title.name = "TradeTitle"
	title.add_theme_color_override("font_outline_color", EDGE)
	title.add_theme_constant_override("outline_size", 4)
	head.add_child(title)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(room)
	_gold = _label("", 18, GOLD)
	_gold.name = "TradeGold"
	head.add_child(_gold)
	column.add_child(head)
	var under := _label(who, 15, DIM)
	under.name = "TradeWho"
	column.add_child(under)
	column.add_child(_chip_row("Colors", COLOR_CHIPS, true))
	column.add_child(_chip_row("Types", TYPE_CHIPS, false))
	_search = LineEdit.new()
	_search.name = "TradeSearch"
	_search.placeholder_text = "type a name"
	_search.custom_minimum_size = Vector2(220, 0)
	_search.text_changed.connect(func(_text: String) -> void: refresh())
	column.add_child(_search)
	_list = ItemList.new()
	_list.name = "TradeCards"
	_list.max_columns = 2
	_list.same_column_width = true
	_list.fixed_column_width = 290
	_list.custom_minimum_size = Vector2(600, 260)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.focus_mode = Control.FOCUS_NONE
	var face_font := GameSkin.font("font_title")
	if face_font != null:
		_list.add_theme_font_override("font", face_font)
	_list.add_theme_font_size_override("font_size", 15)
	_list.add_theme_color_override("font_color", INK)
	_list.add_theme_color_override("font_hovered_color", LIT)
	_list.add_theme_color_override("font_selected_color", LIT)
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0, 0, 0, 0.4)
	well.border_color = Color(GOLD, 0.35)
	well.set_border_width_all(1)
	well.set_corner_radius_all(6)
	well.set_content_margin_all(6)
	_list.add_theme_stylebox_override("panel", well)
	var pick := StyleBoxFlat.new()
	pick.bg_color = Color(GOLD, 0.22)
	pick.set_corner_radius_all(4)
	_list.add_theme_stylebox_override("selected", pick)
	_list.add_theme_stylebox_override("selected_focus", pick)
	_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_list.item_selected.connect(func(index: int) -> void: choose(_shown[index]))
	_list.gui_input.connect(_hover_list)
	column.add_child(_list)
	_ask = _label("", 17, INK)
	_ask.name = "TradeAsk"
	_ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask.custom_minimum_size = Vector2(600, 0)
	column.add_child(_ask)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(10 * k))
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_yes = _button("Yes, I'll trade.", "TradeYes")
	_yes.pressed.connect(trade_chosen)
	buttons.add_child(_yes)
	_no = _button("No Thanks", "TradeNo")
	_no.pressed.connect(func() -> void: choose(""))
	buttons.add_child(_no)
	var leave := _button("Done", "TradeDone")
	leave.pressed.connect(func() -> void: done.emit())
	buttons.add_child(leave)
	column.add_child(buttons)
	_purse = _label("", 14, DIM)
	_purse.name = "TradePurse"
	_purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_purse)
	_note = _label("", 14, DIM)
	_note.name = "TradeNote"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)
	refresh()


## A row of chips: the colours or the types; a town's fixed kind is fixed.
func _chip_row(row_name: String, chips: Array[Array], colors: bool) -> Control:
	var row := HFlowContainer.new()
	row.name = row_name
	row.add_theme_constant_override("h_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fixed := way == CardTrade.TOWN and ((colors and trade & 0xFF != 0) or (not colors and trade >> 8 > 0))
	for chip in chips:
		var button := _button(String(chip[0]), "Chip_" + String(chip[0]))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 0)
		var bit := int(chip[1])
		var on := (color_filter if colors else type_filter) & bit != 0
		button.button_pressed = on
		button.disabled = fixed and not on
		button.toggled.connect(func(pressed: bool) -> void:
			if fixed:
				return
			if colors:
				color_filter = bit if pressed else 0
			else:
				type_filter = bit if pressed else 0
			_sync_chips()
			refresh())
		_chips[button.name] = [button, colors, bit]
		row.add_child(button)
	return row


func _sync_chips() -> void:
	for key in _chips:
		var entry: Array = _chips[key]
		var on := (color_filter if bool(entry[1]) else type_filter) & int(entry[2]) != 0
		(entry[0] as Button).set_pressed_no_signal(on)


## THE CARDS SHOWN: the trade's, by the chips and the name looked for.
func cards() -> Array[String]:
	var out: Array[String] = []
	var look := _search.text.strip_edges().to_lower() if _search != null else ""
	for row in CardTrade.catalogue():
		var f: Dictionary = row["facts"]
		if way == CardTrade.TOWN and not CardTrade.wanted(trade, f):
			continue
		if color_filter != 0 and int(f.get("color", CardValue.COLORLESS)) & color_filter == 0:
			continue
		if type_filter != 0 and int(f.get("type", 0)) & type_filter == 0:
			continue
		if look != "" and not String(row["name"]).to_lower().contains(look):
			continue
		out.append(String(row["name"]))
	return out


## The list, the purse, the question, as they now stand.
func refresh() -> void:
	_shown = cards()
	_list.clear()
	var owned := {}
	var in_deck := {}
	for card in player.cards:
		var entry := card as Dictionary
		var card_name := String(entry.get("card", ""))
		owned[card_name] = int(owned.get(card_name, 0)) + 1
		if (entry.get("decks", []) as Array).has(player.current_deck):
			in_deck[card_name] = int(in_deck.get(card_name, 0)) + 1
	var limit := CardShop.copies_allowed(player)
	for card_name in _shown:
		var index := _list.add_item("%s-%d" % [card_name, int(owned.get(card_name, 0))])
		if int(in_deck.get(card_name, 0)) >= limit:
			_list.set_item_custom_fg_color(index, FAINT)
		if card_name == chosen:
			_list.select(index)
			_list.ensure_current_is_visible()
	_gold.text = AdventureBuilder.GOLD_TITLE % player.gold
	var held: Array[String] = []
	for hue in AdventurePlayer.COLORS:
		held.append("%s %d" % [hue, int(player.amulets.get(hue, 0))])
	_purse.text = "Amulets: " + " · ".join(held)
	_show_ask()


func _show_ask() -> void:
	if chosen == "":
		_ask.text = "%d cards. Choose one." % _shown.size()
		_yes.disabled = true
		_no.disabled = true
		return
	asked = CardTrade.offer(player, chosen, way, color, int(asked.get("gold", 0)) if String(asked.get("card", "")) == chosen else 0)
	if bool(asked["afford"]):
		_ask.text = "%s %s" % [asked["words"], CardTrade.ASK]
	else:
		_ask.text = "%s %s" % [asked["words"], CardTrade.AFFORD]
	_yes.disabled = not bool(asked["afford"])
	_no.disabled = false


## CHOOSE [param card_name] ("" none): the trader names the price.
func choose(card_name: String) -> void:
	_note.text = ""
	if card_name != chosen and card_name != "" and way == CardTrade.BAZAAR:
		# The Nomad's dice, once for the card chosen.
		var dice := MsvcRandom.new(player.dice)
		var draw := dice.below(CardTrade.bazaar_reach(player))
		player.dice = dice.state
		asked = {"card": card_name, "gold": CardTrade.bazaar_price(player, CardRegistry.get_card(card_name), draw)}
	elif card_name != chosen:
		asked = {}
	chosen = card_name
	if card_name != "":
		show_large(card_name)
		var at := _shown.find(card_name)
		if at >= 0 and not _list.is_selected(at):
			_list.select(at)
			_list.ensure_current_is_visible()
	else:
		_list.deselect_all()
	_show_ask()


## TRADE for the card chosen ([method CardTrade.pay]).
func trade_chosen() -> void:
	if chosen == "":
		return
	var result := CardTrade.pay(player, asked, way, color)
	_note.text = String(result["said"])
	if bool(result["traded"]):
		var keep := chosen
		chosen = ""
		asked = {}
		refresh()
		show_large(keep)
	else:
		_show_ask()


func show_large(card_name: String) -> void:
	if CardRegistry.has_card(card_name):
		_large.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
		_large.visible = true


func _hover_list(input: InputEvent) -> void:
	if CardShopPane._right_click(input):
		var at := _list.get_item_at_position((input as InputEventMouseButton).position, true)
		if at >= 0 and at < _shown.size():
			show_large(_shown[at])
			card_read.emit(_shown[at])
			_list.accept_event()
		return
	var motion := input as InputEventMouseMotion
	if motion == null:
		return
	var index := _list.get_item_at_position(motion.position, true)
	if index >= 0 and index < _shown.size():
		show_large(_shown[index])


func ask_text() -> String:
	return _ask.text


func note() -> String:
	return _note.text


func _unhandled_input(input: InputEvent) -> void:
	if input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		done.emit()


func _button(words: String, button_name: String) -> Button:
	var choice := Button.new()
	choice.name = button_name
	choice.text = words
	choice.focus_mode = Control.FOCUS_NONE
	choice.custom_minimum_size = Vector2(110, 0) * k
	var face := GameSkin.font("font_title")
	if face != null:
		choice.add_theme_font_override("font", face)
	choice.add_theme_font_size_override("font_size", int(15 * k))
	choice.add_theme_color_override("font_color", INK)
	choice.add_theme_color_override("font_hover_color", LIT)
	choice.add_theme_color_override("font_pressed_color", LIT)
	choice.add_theme_color_override("font_hover_pressed_color", LIT)
	choice.add_theme_color_override("font_disabled_color", Color(DIM, 0.5))
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0, 0, 0, 0.35)
	rest.border_color = Color(GOLD, 0.45)
	rest.set_border_width_all(1)
	rest.set_corner_radius_all(6)
	rest.content_margin_left = 10 * k
	rest.content_margin_right = 10 * k
	rest.content_margin_top = 3 * k
	rest.content_margin_bottom = 3 * k
	var lit := rest.duplicate() as StyleBoxFlat
	lit.bg_color = Color(GOLD, 0.22)
	var on := rest.duplicate() as StyleBoxFlat
	on.bg_color = Color(GOLD, 0.32)
	on.border_color = Color(GOLD, 0.9)
	var off := rest.duplicate() as StyleBoxFlat
	off.border_color = Color(GOLD, 0.15)
	choice.add_theme_stylebox_override("normal", rest)
	choice.add_theme_stylebox_override("hover", lit)
	choice.add_theme_stylebox_override("pressed", on)
	choice.add_theme_stylebox_override("hover_pressed", on)
	choice.add_theme_stylebox_override("disabled", off)
	choice.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return choice


func _label(text: String, size: int, color_ink := INK) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font("font_title")
	if face != null and size >= 15:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color_ink)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
