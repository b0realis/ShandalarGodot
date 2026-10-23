extends GutTest
## THE TOWN'S CARD SHOP (2026-10-23): Buy Cards in a town opens
## [CardShopPane] — the town's cards and their 1997 prices, Buy and Done —
## and its Edit deck/Sell cards opens the deck builder with Sell
## ([AdventureBuilder.sell]).

var screen: WorldScreen
const SAVES := "user://adventure_tests_shop"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _town() -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


func test_buy_cards_in_a_town() -> void:
	var player := screen.player
	var slot := _town()
	var tile := Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))
	var pane := screen.visit(tile)
	var buy := pane.find_child("Choice_buy", true, false) as Button
	assert_false(buy.disabled, "Buy Cards is open")
	buy.pressed.emit()
	await get_tree().process_frame
	assert_false(screen.find_child("VisitPane", true, false) != null and is_instance_valid(screen._visit), "the town's pane gives way")
	var shop := screen.find_child("CardShop", true, false) as CardShopPane
	assert_not_null(shop, "the shop")
	assert_true(screen.visiting(), "the world waits under it")
	var cards := CardShop.offers(player, slot)
	assert_eq((shop.find_child("Offers", true, false) as Node).get_child_count(), cards.size(), "a place for each card")
	assert_eq((shop.find_child("ShopGold", true, false) as Label).text, "GOLD: %d" % player.gold)
	var pick := -1
	for i in cards.size():
		if not cards[i] in CardShop.LANDS:
			pick = i
			break
	var price := CardShop.price_at(player, slot, cards[pick])
	var tag := ((shop.find_child("Offers", true, false) as Node).get_child(pick).find_child("Price", true, false) as Label)
	assert_eq(tag.text, "%d gold" % price, "its price tag")
	shop.choose(pick)
	assert_eq(shop.ask_text(), "Buy %s for %d gold?" % [cards[pick], price], "the 1997 question")
	player.gold = price + 7
	shop.refresh()
	var owned := player.cards.size()
	(shop.find_child("Buy", true, false) as Button).pressed.emit()
	assert_eq(player.gold, 7, "paid")
	assert_eq(player.cards.size(), owned + 1, "the card is the hero's")
	assert_eq(shop.note(), "You buy %s for %d gold." % [cards[pick], price])
	assert_eq(CardShop.offers(player, slot)[pick], "", "its place is sold")
	(shop.find_child("Done", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(screen.shopping(), "Done")
	assert_true(screen.visiting(), "back in the town")
	assert_not_null(screen.find_child("VisitPane", true, false))


func test_sell_cards_in_a_town() -> void:
	var player := screen.player
	var slot := _town()
	player.cards.append({"card": "Grizzly Bears", "decks": []})
	var tile := Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))
	var pane := screen.visit(tile)
	(pane.find_child("Choice_deck", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var builder := screen.find_child("DeckBuilder", true, false) as AdventureBuilder
	assert_eq(builder.sell_site, slot, "opened in the town: it buys")
	var sell := builder.find_child("SellButton", true, false) as Button
	assert_not_null(sell)
	builder._show_in_showcase(CardRegistry.get_card("Grizzly Bears"))
	var price := CardShop.sell_price_at(player, slot, "Grizzly Bears")
	assert_eq(sell.text, "Sell for %d" % price)
	var gold := player.gold
	var owned := player.cards.size()
	sell.pressed.emit()
	assert_eq(player.gold, gold + price, "paid by the town")
	assert_eq(player.cards.size(), owned - 1, "the card is sold")
	assert_eq(builder.gold_text(), "GOLD: %d" % player.gold, "the title follows")
	assert_true(sell.disabled, "no spare Bears left")
	# A card all of whose copies are in the deck on show is not sold.
	var in_deck := String(player.cards[0]["card"])
	builder._show_in_showcase(CardRegistry.get_card(in_deck))
	if builder.deck.count_of(in_deck) >= AdventureBuilder.owned_counts(player).get(in_deck, 0):
		assert_eq(builder.sell(in_deck), 0, "the deck keeps its copies")
	builder._exit()
	await get_tree().process_frame
	var opened := screen.show_deck()
	assert_eq(opened.sell_site, -1, "the spellbook out in the world does not sell")
	assert_null(opened.find_child("SellButton", true, false))
