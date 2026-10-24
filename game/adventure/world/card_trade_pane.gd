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
## Escape closes the trader; in the name box with a name typed, it first
## clears the name and leaves the box, as Escape in a save's name puts the
## old name back first ([SaveSlotsPane]) [QoL].
## THE QUEST'S REWARD ([constant CardTrade.REWARD], part B): the same
## browser over the town's wares, free — "Will you take this card...",
## "Yes" / "No" — with no Done: a card must be taken (1997 looped its
## browser until one was), Escape only puts the card chosen back; taken,
## the pane is done.

## Done: back to the town or the lair.
signal done
## A card right-clicked, to be read full screen ([method
## WorldScreen.read_card]).
signal card_read(card_name: String)

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
## The reward taken ([constant CardTrade.REWARD]): the pane is done.
var taken := false
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
## The facts of each card shown, by name ([method cards]).
var _facts := {}
var _chips := {}
## The row last under the pointer, -1 for none: the pointer moving within
## it asks nothing more of the large card.
var _hovered := -1


func _ready() -> void:
	name = "CardTrade"
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _town_wares() and trade & 0xFF != 0:
		color_filter = trade & 0xFF
	elif _town_wares() and trade >> 8 > 0 and trade >> 8 < CardTrade.CLASS_TYPES.size():
		type_filter = CardTrade.CLASS_TYPES[trade >> 8]
	add_theme_stylebox_override("panel", PaneStyle.glass())
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
		if PaneStyle.right_click(input) and _large._shown != null:
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
	var title := PaneStyle.title("Which card do you seek?", 24)
	title.name = "TradeTitle"
	head.add_child(title)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(room)
	_gold = PaneStyle.label("", 18, PaneStyle.GOLD)
	_gold.name = "TradeGold"
	head.add_child(_gold)
	column.add_child(head)
	var under := PaneStyle.label(who, 15, PaneStyle.DIM)
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
	_list.add_theme_color_override("font_color", PaneStyle.INK)
	_list.add_theme_color_override("font_hovered_color", PaneStyle.LIT)
	_list.add_theme_color_override("font_selected_color", PaneStyle.LIT)
	_list.add_theme_stylebox_override("panel", PaneStyle.well())
	var pick := StyleBoxFlat.new()
	pick.bg_color = Color(PaneStyle.GOLD, 0.22)
	pick.set_corner_radius_all(4)
	_list.add_theme_stylebox_override("selected", pick)
	_list.add_theme_stylebox_override("selected_focus", pick)
	_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_list.item_selected.connect(func(index: int) -> void: choose(_shown[index]))
	_list.gui_input.connect(_hover_list)
	_list.mouse_exited.connect(func() -> void: _hovered = -1)
	column.add_child(_list)
	_ask = PaneStyle.label("", 17, PaneStyle.INK)
	_ask.name = "TradeAsk"
	_ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask.custom_minimum_size = Vector2(600, 0)
	column.add_child(_ask)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(10 * k))
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_yes = _trade_button("Yes" if must_take() else "Yes, I'll trade.", "TradeYes")
	_yes.pressed.connect(trade_chosen)
	buttons.add_child(_yes)
	_no = _trade_button("No" if must_take() else "No Thanks", "TradeNo")
	_no.pressed.connect(func() -> void: choose(""))
	buttons.add_child(_no)
	var leave := _trade_button("Done", "TradeDone")
	leave.pressed.connect(func() -> void: done.emit())
	# The reward has no Done: a card must be taken.
	leave.visible = not must_take()
	buttons.add_child(leave)
	column.add_child(buttons)
	_purse = PaneStyle.label("", 14, PaneStyle.DIM)
	_purse.name = "TradePurse"
	_purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_purse)
	_note = PaneStyle.label("", 14, PaneStyle.DIM)
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
	var fixed := _town_wares() and ((colors and trade & 0xFF != 0) or (not colors and trade >> 8 > 0))
	for chip in chips:
		var button := _trade_button(String(chip[0]), "Chip_" + String(chip[0]))
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
	# Under the Classic MTG rules no card the hero holds every copy of the
	# rules allow is offered ([method CardShop.classic_rule]).
	var rule := CardShop.classic_rule(player)
	for row in CardTrade.catalogue():
		var f: Dictionary = row["facts"]
		if not CardShop.classic_allows(rule, String(row["name"])):
			continue
		if _town_wares() and not CardTrade.wanted(trade, f):
			continue
		if color_filter != 0 and int(f.get("color", CardValue.COLORLESS)) & color_filter == 0:
			continue
		if type_filter != 0 and int(f.get("type", 0)) & type_filter == 0:
			continue
		if look != "" and not String(row["name"]).to_lower().contains(look):
			continue
		out.append(String(row["name"]))
		_facts[String(row["name"])] = f
	return out


## The list, the purse, the question, as they now stand.
func refresh() -> void:
	_shown = cards()
	_list.clear()
	_hovered = -1
	var owned := AdventureBuilder.owned_counts(player)
	# Dimmed: no copy left to the deck in use by 1997's own allowance
	# (`GetRemainingAllowedCardCopies(card) <= 0`, visitLocation.c 3822;
	# [method DuelSpoils.copies_left]: basic lands always lit, the cards
	# outside the base sets halved, the 0x100 ones by the difficulty), its
	# copies counted once for the whole list — none with the copy limit off
	# ([method CardShop.counted_copies]). The name carries "-N" only for a
	# card the hero owns (visitLocation.c 3804–3808).
	var in_deck := CardShop.counted_copies(player)
	var limit := CardShop.copies_allowed(player)
	# The classic rules list only what they allow: nothing to dim.
	var dims := player.card_rule != AdventurePlayer.RULE_CLASSIC
	for card_name in _shown:
		var count := int(owned.get(card_name, 0))
		var index := _list.add_item("%s-%d" % [card_name, count] if count > 0 else card_name)
		if dims and DuelSpoils.copies_left(player, card_name, _facts.get(card_name, {}), in_deck, limit) <= 0:
			_list.set_item_custom_fg_color(index, PaneStyle.FAINT)
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
	if must_take():
		_ask.text = String(asked["words"])
	elif bool(asked["afford"]):
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


## TRADE for the card chosen ([method CardTrade.pay]); the reward's card
## taken, the pane is done.
## What the reward's pick came to, for the pane under it to say
## ([method trade_chosen]); "" until taken.
var said := ""


func trade_chosen() -> void:
	if chosen == "" or taken:
		return
	var result := CardTrade.pay(player, asked, way, color)
	_note.text = String(result["said"])
	if must_take() and bool(result["traded"]):
		taken = true
		# The pane goes at once: what came of it ("… joins your cards", or
		# lost to a full bag) is said by the town's pane after it (the bug
		# pass of part B, q3-4: said here, it was never seen).
		said = String(result["said"])
		done.emit()
		return
	if bool(result["traded"]):
		var keep := chosen
		chosen = ""
		asked = {}
		refresh()
		show_large(keep)
	else:
		_show_ask()


## Card [param card_name] large beside the list ([method PaneStyle.show_card]:
## not drawn again when it is already the one shown).
func show_large(card_name: String) -> void:
	if PaneStyle.show_card(_large, card_name):
		_large.visible = true


## The pointer over the list: the row under it shown large — once, not at
## every move within the row; a right click reads it full screen.
func _hover_list(input: InputEvent) -> void:
	if PaneStyle.right_click(input):
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
	if index == _hovered:
		return
	_hovered = index
	if index >= 0 and index < _shown.size():
		show_large(_shown[index])


func ask_text() -> String:
	return _ask.text


func note() -> String:
	return _note.text


func _unhandled_input(input: InputEvent) -> void:
	if input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if must_take():
			choose("")
		else:
			done.emit()


## Whether a card must be taken before the pane is done (the quest's reward).
func must_take() -> bool:
	return way == CardTrade.REWARD and not taken


## Whether the cards are a town's own kind (its trade, or its reward).
func _town_wares() -> bool:
	return way == CardTrade.TOWN or way == CardTrade.REWARD


## ESCAPE IN THE NAME BOX, met before the box hears it (it would keep the
## Escape for itself, and the trader stay open): a name typed is cleared —
## the whole list again — and the box left, as Escape in a save's name puts
## the old name back ([SaveSlotsPane]); the next Escape, or one in an empty
## box, closes the trader.
func _input(input: InputEvent) -> void:
	if _search == null or not _search.has_focus() or not input.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _search.text == "":
		if must_take():
			_search.release_focus()
		else:
			done.emit()
		return
	_search.text = ""
	_search.release_focus()
	refresh()


## A button of the trader: the panes' own, a little smaller, at least 110
## wide.
func _trade_button(words: String, button_name: String) -> Button:
	var choice := PaneStyle.button(words, button_name, k, 15)
	choice.custom_minimum_size = Vector2(110, 0) * k
	return choice
