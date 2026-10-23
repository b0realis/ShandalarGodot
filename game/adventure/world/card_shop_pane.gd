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
##
## The row is made once: a choice restyles the price tags where they stand,
## and a buy remakes only the place sold ([method refresh]). Nothing in the
## row is freed under its own click (a click once freed the place being
## clicked: the shop never asked, and the row lost a card a click).

## Done: back to the town.
signal done
## A card right-clicked, to be read full screen ([method
## WorldScreen.read_card]).
signal card_read(card_name: String)

## The cards in the row, and the one shown large.
const SMALL := 0.4
const LARGE := 0.78
## The chosen place, a little brighter than the rest.
const CHOSEN_TINT := Color(1.15, 1.1, 0.95)

var player: AdventurePlayer
## The town's site slot.
var slot := -1
var k := 1.0
## The place chosen, -1 for none.
var chosen := -1
## The place under the pointer, -1 for none: its tag is lit too.
var _hovered := -1
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
	holder.add_child(_large)
	across.add_child(holder)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := PaneStyle.title("Cards for Sale")
	title.name = "ShopTitle"
	head.add_child(title)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(room)
	_gold = PaneStyle.label("", 18, PaneStyle.GOLD)
	_gold.name = "ShopGold"
	head.add_child(_gold)
	column.add_child(head)
	column.add_child(PaneStyle.label(WorldNames.site_name(player.world, slot), 15, PaneStyle.DIM))
	# The shop's own ground under the row of cards.
	var stage := PanelContainer.new()
	stage.name = "Stage"
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.02, 0.015, 0.015, 1.0)
	rim.border_color = Color(PaneStyle.GOLD, 0.6)
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
	_hint = PaneStyle.label("", 15, PaneStyle.INK)
	_hint.name = "Hint"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(560, 0)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.16, 0.11, 0.06, 0.9)
	paper.border_color = Color(PaneStyle.GOLD, 0.55)
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(8)
	paper.set_content_margin_all(8)
	_hint.add_theme_stylebox_override("normal", paper)
	column.add_child(_hint)
	_ask = PaneStyle.label("Choose a card.", 17, PaneStyle.INK)
	_ask.name = "Ask"
	_ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_ask)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(10 * k))
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy = PaneStyle.button("Buy", "Buy", k, 17)
	_buy.pressed.connect(buy_chosen)
	buttons.add_child(_buy)
	var leave := PaneStyle.button("Done", "Done", k, 17)
	leave.pressed.connect(func() -> void: done.emit())
	buttons.add_child(leave)
	column.add_child(buttons)
	_note = PaneStyle.label("", 14, PaneStyle.DIM)
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)
	refresh()


## The row of cards, the gold, the hint and the question, as they now
## stand. Only a place whose card has changed — sold, or restocked — is
## made anew; every tag is dressed where it stands.
func refresh() -> void:
	var cards := CardShop.offers(player, slot)
	_sync_row(cards)
	_gold.text = AdventureBuilder.GOLD_TITLE % player.gold
	var hint := CardHints.current(player, slot)
	_hint.text = String(hint.get("text", ""))
	_hint.visible = _hint.text != ""
	if chosen >= cards.size() or (chosen >= 0 and cards[chosen] == ""):
		chosen = -1
	for i in _row.get_child_count():
		_dress_place(i)
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


## The row's places to [param cards]: a place whose card is no longer the
## one on offer is swapped for a new one, in the same spot ([method
## PaneStyle.swap] — the old place may be the one being clicked).
func _sync_row(cards: Array[String]) -> void:
	for i in cards.size():
		if i >= _row.get_child_count():
			_row.add_child(_offer(i, cards[i]))
		elif String(_row.get_child(i).get_meta("card", "")) != cards[i]:
			PaneStyle.swap(_row.get_child(i), _offer(i, cards[i]))
			if _hovered == i:
				_hovered = -1
	while _row.get_child_count() > cards.size():
		PaneStyle.drop(_row.get_child(_row.get_child_count() - 1))


## One place of the row: the card and its price tag, or the place sold. Its
## tag is dressed by [method _dress_place].
func _offer(index: int, card_name: String) -> Control:
	var place := VBoxContainer.new()
	place.name = "Offer_%d" % index
	place.set_meta("card", card_name)
	place.add_theme_constant_override("separation", 4)
	place.mouse_filter = Control.MOUSE_FILTER_STOP
	var holder := Control.new()
	holder.custom_minimum_size = CardPreview.SIZE * SMALL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place.add_child(holder)
	var tag := PaneStyle.label("", 15, PaneStyle.GOLD)
	tag.name = "Price"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place.add_child(tag)
	if not CardRegistry.has_card(card_name):
		var sold := PaneStyle.label("Sold", 16, PaneStyle.DIM)
		sold.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		holder.add_child(sold)
		return place
	var card := CardPreview.new()
	card.docked = true
	card.scale = Vector2(SMALL, SMALL)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	card.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0))
	# The tag wears the card's rarity under the pointer and once chosen.
	tag.set_meta("rarity", CardShop.shop_rarity(CardValue.facts(CardRegistry.get_card(card_name))))
	place.mouse_entered.connect(_hover.bind(index, true))
	place.mouse_exited.connect(_hover.bind(index, false))
	place.gui_input.connect(_place_input.bind(index))
	return place


## Place [param index] as it now stands: its price tag ("✦" on the
## seller's hint), lit in the card's rarity under the pointer or chosen, its
## rim thicker and the place brighter when chosen; "—" when sold.
func _dress_place(index: int) -> void:
	var place := _row.get_child(index) as Control
	var tag := place.get_node("Price") as Label
	var card_name := String(place.get_meta("card", ""))
	if not CardRegistry.has_card(card_name):
		tag.text = "—"
		PaneStyle.dress_chip(tag, 1, false)
		place.modulate = Color.WHITE
		return
	tag.text = "%d gold" % CardShop.price_at(player, slot, card_name)
	if String(CardHints.current(player, slot).get("card", "")) == card_name:
		tag.text = "✦ " + tag.text
	var mine := index == chosen
	PaneStyle.dress_chip(tag, int(tag.get_meta("rarity", 1)), mine or index == _hovered, mine)
	place.modulate = CHOSEN_TINT if mine else Color.WHITE


## The pointer comes onto ([param over]) or leaves place [param index]: its
## card shown large, its tag lit while the pointer is on it. (A place just
## swapped out may still say the pointer left it.)
func _hover(index: int, over: bool) -> void:
	if index >= _row.get_child_count():
		return
	if over:
		_hovered = index
		show_large(String(_row.get_child(index).get_meta("card", "")))
	elif _hovered == index:
		_hovered = -1
	_dress_place(index)


## A click on place [param index]: the left button let go chooses it, a
## right press reads it full screen.
func _place_input(event: InputEvent, index: int) -> void:
	if index >= _row.get_child_count():
		return
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		choose(index)
	elif PaneStyle.right_click(event):
		card_read.emit(String(_row.get_child(index).get_meta("card", "")))


## Card [param card_name] large beside the row ([method PaneStyle.show_card]:
## not drawn again when it is already the one shown).
func show_large(card_name: String) -> void:
	PaneStyle.show_card(_large, card_name)


## Choose offer [param index]: "Buy … for … gold?". Nothing in the row is
## made anew ([method refresh]): the place clicked lives on.
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

