class_name CardShopPane
extends PanelContainer
## THE TOWN'S CARD SHOP (the owner, 2026-10-23: *"lets build the card
## shop"*) — 1.3's `RunTownBuyCardsScreen` (004f0d09) in the world's
## rounded glass: "Cards for Sale" over the shop's own ground
## (`Buycards.pic`), the town's cards in a row with their price tags
## ("%d gold"), the card under the pointer large beside them, and "Buy for
## %d gold?" for the one chosen. The cards and prices are [CardShop]'s and
## [CardValue]'s. 1997 refused a card the purse could not pay without a
## word; this says so. The seller's hint for this visit ([CardHints]) shows
## in its own box under the cards — 1997 showed it in a box over the shop
## each time it opened — and its card's tag is marked.

## Done: back to the town.
signal done
## A card right-clicked, to be read full screen ([method
## WorldScreen.read_card]).
signal card_read(card_name: String)

const GOLD := Color8(232, 190, 110)
const INK := Color8(236, 222, 196)
const DIM := Color8(160, 146, 128)
const LIT := Color8(255, 236, 170)
const EDGE := Color8(20, 10, 8)
## The cards in the row, and the one shown large.
const SMALL := 0.4
const LARGE := 0.78

var player: AdventurePlayer
## The town's site slot.
var slot := -1
var k := 1.0
var chosen := -1
var _row: HBoxContainer
var _large: CardPreview
var _gold: Label
var _ask: Label
var _buy: Button
var _note: Label
var _hint: Label


func _ready() -> void:
	name = "CardShop"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.05, 0.03, 0.03, 0.94)
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
		if _right_click(input) and _large._shown != null:
			card_read.emit(_large._shown.data.card_name))
	holder.add_child(_large)
	across.add_child(holder)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("Cards for Sale", 26, GOLD)
	title.name = "ShopTitle"
	title.add_theme_color_override("font_outline_color", EDGE)
	title.add_theme_constant_override("outline_size", 4)
	head.add_child(title)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(room)
	_gold = _label("", 18, GOLD)
	_gold.name = "ShopGold"
	head.add_child(_gold)
	column.add_child(head)
	column.add_child(_label(WorldNames.site_name(player.world, slot), 15, DIM))
	# The shop's own ground under the row of cards.
	var stage := PanelContainer.new()
	stage.name = "Stage"
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.02, 0.015, 0.015, 1.0)
	rim.border_color = Color(GOLD, 0.6)
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(4)
	# Room round the cards, so the shop's own ground shows as in 1997.
	rim.content_margin_left = 26
	rim.content_margin_right = 26
	rim.content_margin_top = 22
	rim.content_margin_bottom = 22
	stage.add_theme_stylebox_override("panel", rim)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ground := TextureRect.new()
	ground.name = "Ground"
	ground.texture = GameSkin.texture("visit_buycards")
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ground.modulate = Color(0.85, 0.82, 0.8)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(ground)
	_row = HBoxContainer.new()
	_row.name = "Offers"
	_row.add_theme_constant_override("separation", 12)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_row)
	column.add_child(stage)
	_hint = _label("", 15, INK)
	_hint.name = "Hint"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(560, 0)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.16, 0.11, 0.06, 0.9)
	paper.border_color = Color(GOLD, 0.55)
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(8)
	paper.set_content_margin_all(8)
	_hint.add_theme_stylebox_override("normal", paper)
	column.add_child(_hint)
	_ask = _label("Choose a card.", 17, INK)
	_ask.name = "Ask"
	_ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_ask)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(10 * k))
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy = _button("Buy", "Buy")
	_buy.pressed.connect(buy_chosen)
	buttons.add_child(_buy)
	var leave := _button("Done", "Done")
	leave.pressed.connect(func() -> void: done.emit())
	buttons.add_child(leave)
	column.add_child(buttons)
	_note = _label("", 14, DIM)
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)
	refresh()


## The row of cards, the gold, the question, as they now stand.
func refresh() -> void:
	var cards := CardShop.offers(player, slot)
	for child in _row.get_children():
		child.free()
	for i in cards.size():
		_row.add_child(_offer(i, cards[i]))
	_gold.text = AdventureBuilder.GOLD_TITLE % player.gold
	var hint := CardHints.current(player, slot)
	_hint.text = String(hint.get("text", ""))
	_hint.visible = _hint.text != ""
	if chosen >= cards.size() or (chosen >= 0 and cards[chosen] == ""):
		chosen = -1
	if chosen < 0:
		_ask.text = "Choose a card."
		_buy.disabled = true
		for i in cards.size():
			if cards[i] != "":
				show_large(cards[i])
				break
	else:
		var price := CardShop.price_at(player, slot, cards[chosen])
		_ask.text = "Buy %s for %d gold?" % [cards[chosen], price]
		_buy.disabled = player.gold < price
		show_large(cards[chosen])


## One place of the row: the card and its price tag, or the place sold.
func _offer(index: int, card_name: String) -> Control:
	var place := VBoxContainer.new()
	place.name = "Offer_%d" % index
	place.add_theme_constant_override("separation", 4)
	place.mouse_filter = Control.MOUSE_FILTER_STOP
	var holder := Control.new()
	holder.custom_minimum_size = CardPreview.SIZE * SMALL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place.add_child(holder)
	var tag := _label("", 15, GOLD)
	tag.name = "Price"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.05, 0.03, 0.03, 0.85)
	chip.border_color = Color(GOLD, 0.8 if index == chosen else 0.35)
	chip.set_border_width_all(2 if index == chosen else 1)
	chip.set_corner_radius_all(6)
	chip.content_margin_left = 6
	chip.content_margin_right = 6
	tag.add_theme_stylebox_override("normal", chip)
	place.add_child(tag)
	if card_name == "" or not CardRegistry.has_card(card_name):
		var sold := _label("Sold", 16, DIM)
		sold.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		holder.add_child(sold)
		tag.text = "—"
		return place
	var card := CardPreview.new()
	card.docked = true
	card.scale = Vector2(SMALL, SMALL)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	card.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
	tag.text = "%d gold" % CardShop.price_at(player, slot, card_name)
	if String(CardHints.current(player, slot).get("card", "")) == card_name:
		tag.text = "✦ " + tag.text
	if index == chosen:
		place.modulate = Color(1.15, 1.1, 0.95)
	place.mouse_entered.connect(func() -> void: show_large(card_name))
	place.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
			choose(index)
		elif _right_click(event):
			card_read.emit(card_name))
	return place


## Card [param card_name] large beside the row.
func show_large(card_name: String) -> void:
	if CardRegistry.has_card(card_name):
		_large.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))


## Choose offer [param index]: "Buy … for … gold?".
func choose(index: int) -> void:
	chosen = index
	_note.text = ""
	refresh()


## BUY the chosen card ([method CardShop.buy]).
func buy_chosen() -> void:
	if chosen < 0:
		return
	var result := CardShop.buy(player, slot, chosen)
	chosen = -1
	refresh()
	_note.text = String(result["said"])


## A right press, the read's gesture (a finger's hold on a touch screen).
static func _right_click(input: InputEvent) -> bool:
	var click := input as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT


func ask_text() -> String:
	return _ask.text


func note() -> String:
	return _note.text


func hint_text() -> String:
	return _hint.text if _hint.visible else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
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
	choice.add_theme_font_size_override("font_size", int(17 * k))
	choice.add_theme_color_override("font_color", INK)
	choice.add_theme_color_override("font_hover_color", LIT)
	choice.add_theme_color_override("font_pressed_color", LIT)
	choice.add_theme_color_override("font_disabled_color", Color(DIM, 0.6))
	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0, 0, 0, 0.35)
	rest.border_color = Color(GOLD, 0.45)
	rest.set_border_width_all(1)
	rest.set_corner_radius_all(6)
	rest.content_margin_left = 12 * k
	rest.content_margin_right = 12 * k
	rest.content_margin_top = 4 * k
	rest.content_margin_bottom = 4 * k
	var lit := rest.duplicate() as StyleBoxFlat
	lit.bg_color = Color(GOLD, 0.22)
	var off := rest.duplicate() as StyleBoxFlat
	off.border_color = Color(GOLD, 0.15)
	choice.add_theme_stylebox_override("normal", rest)
	choice.add_theme_stylebox_override("hover", lit)
	choice.add_theme_stylebox_override("pressed", lit)
	choice.add_theme_stylebox_override("disabled", off)
	choice.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return choice


func _label(text: String, size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font("font_title")
	if face != null and size >= 15:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
