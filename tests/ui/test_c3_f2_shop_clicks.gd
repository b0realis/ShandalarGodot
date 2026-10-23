extends GutTest
## THE CARD SHOP CLICKED (adventure campaign 2026-10-23, findings h3-1 /
## h6-1 and h5-8). A click on a card in the shop chose it by rebuilding the
## whole row — freeing every place, the one whose click was still being
## handled among them. Godot refuses that ("Object is locked and can't be
## freed"), the rebuild stopped halfway, and the shop never asked "Buy … for
## … gold?": Buy stayed dim and each click lost another card from the row (a
## release build would free the place under its own click). The tests before
## called [method CardShopPane.choose] directly and never clicked.
##
## Now a choice restyles the price tags where they stand, and a buy remakes
## only the place sold. Every click here is a real one, pushed through the
## viewport.

const SAVES := "user://adventure_tests_c3_f2_shop"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## A real left click on [param node]'s middle, through the viewport.
func _click(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames(2)


func _town() -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


## The town's shop, opened by clicking Buy Cards in its pane.
func _open_shop() -> CardShopPane:
	var slot := _town()
	var pane := screen.visit(Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"])))
	await _frames(2)
	await _click(pane.find_child("Choice_buy", true, false) as Control)
	await _frames(2)
	var shop := screen.find_child("CardShop", true, false) as CardShopPane
	assert_not_null(shop, "Buy Cards clicked: the shop")
	return shop


func _offers(shop: CardShopPane) -> Node:
	return shop.find_child("Offers", true, false)


## The first two places with a card for sale.
func _for_sale(shop: CardShopPane) -> Array[int]:
	var cards := CardShop.offers(screen.player, shop.slot)
	var out: Array[int] = []
	for i in cards.size():
		if cards[i] != "":
			out.append(i)
	return out


func test_a_card_clicked_is_asked_for_and_bought() -> void:
	var shop := await _open_shop()
	var player := screen.player
	var cards := CardShop.offers(player, shop.slot)
	var places := _offers(shop).get_child_count()
	var sale := _for_sale(shop)
	assert_true(sale.size() >= 2, "control: two cards for sale")
	var pick := sale[1]
	var price := CardShop.price_at(player, shop.slot, cards[pick])
	player.gold = price + 5
	shop.refresh()
	await _click(_offers(shop).get_child(pick) as Control)
	assert_eq(shop.chosen, pick, "the card clicked is chosen")
	assert_eq(shop.ask_text(), "Buy %s for %d gold?" % [cards[pick], price], "the shop asks for it")
	assert_false((shop.find_child("Buy", true, false) as Button).disabled, "Buy is open: the purse holds the price")
	assert_eq(_offers(shop).get_child_count(), places, "no card lost from the row")
	# Another card clicked: the question follows, the row stays whole.
	await _click(_offers(shop).get_child(sale[0]) as Control)
	assert_eq(shop.chosen, sale[0], "the second card clicked is chosen")
	assert_eq(shop.ask_text(), "Buy %s for %d gold?" % [cards[sale[0]],
		CardShop.price_at(player, shop.slot, cards[sale[0]])])
	assert_eq(_offers(shop).get_child_count(), places, "still a place for each card")
	# Back to the first, and Buy clicked.
	await _click(_offers(shop).get_child(pick) as Control)
	var owned := player.cards.size()
	await _click(shop.find_child("Buy", true, false) as Control)
	assert_eq(player.cards.size(), owned + 1, "bought with clicks alone")
	assert_eq(player.gold, 5, "paid")
	assert_eq(shop.note(), "You buy %s for %d gold." % [cards[pick], price])
	assert_eq(_offers(shop).get_child_count(), places, "the place stays, sold")
	var sold := _offers(shop).get_child(pick)
	assert_eq(sold.name, "Offer_%d" % pick, "in its own place in the row")
	assert_true(sold.find_children("*", "CardPreview", true, false).is_empty(), "no card shown in it")
	assert_eq((sold.find_child("Price", true, false) as Label).text, "—", "its tag sold")
	assert_eq(shop.ask_text(), "Choose a card.", "the shop asks again")


func test_a_choice_restyles_the_tags_in_place() -> void:
	var shop := await _open_shop()
	var sale := _for_sale(shop)
	var before: Array = []
	for place in _offers(shop).get_children():
		before.append(place.get_instance_id())
	await _click(_offers(shop).get_child(sale[0]) as Control)
	var after: Array = []
	for place in _offers(shop).get_children():
		after.append(place.get_instance_id())
	assert_eq(after, before, "the row is not remade for a choice")
	var chosen_tag := _offers(shop).get_child(sale[0]).find_child("Price", true, false) as Label
	var other_tag := _offers(shop).get_child(sale[1]).find_child("Price", true, false) as Label
	var chosen_face := chosen_tag.get_theme_stylebox("normal") as StyleBoxFlat
	var other_face := other_tag.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(chosen_face.border_width_top, 2, "the chosen tag's rim is thicker")
	assert_eq(other_face.border_width_top, 1, "another's is not")
	assert_eq(chosen_tag.get_theme_color("font_color"), PaneStyle.ON_RARITY, "the chosen tag lit")
	# The choice moves on: the first tag goes back to rest.
	await _click(_offers(shop).get_child(sale[1]) as Control)
	chosen_face = chosen_tag.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(chosen_face.border_width_top, 1, "the old choice's rim thin again")
	assert_eq(chosen_tag.get_theme_color("font_color"), PaneStyle.GOLD, "and at rest")
