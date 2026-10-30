extends GutTest
## THE TRADES ON SCREEN (2026-10-23, the owner: *"Build all trade
## features"*): a town's "Trade … amulet for …" opens the card trader
## ([CardTradePane]); the seller's hint shows in the shop; a lair walked
## onto opens its pane ([LairPane]) — the treasure, the Gemcutter's Guild,
## the Nomad's Bazaar through the trader and back, a riddle.

var screen: WorldScreen
const SAVES := "user://adventure_tests_trade"


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
	CardHints.forget()
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


func _tile(slot: int) -> Vector2i:
	return Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))


## A lair of [param color] in roaming slot 1, beside the hero, entered with
## the clock at [param clock] (a treasure when `(clock >> 2) % 3` is not 0).
func _lair(event: int, color := 3) -> LairPane:
	var player := screen.player
	var hero := player.tile()
	player.monsters = [{"slot": 1, "kind": "lair", "color": color,
		"x": hero.x * 32 + 16, "y": (hero.y + 1) * 32 + 16}]
	player.monster_timer = 4 if event < 0 else 0
	var pane := screen.enter_lair(1)
	if event >= 0:
		pane.queue_free()
		await get_tree().process_frame
		var held := WorldLairs.held_in(player, 1)
		var made := LairEvent.begin(player, held)
		made["event"] = event
		made["name"] = LairEvent.NAMES[event]
		made["reward"] = ""
		pane = LairPane.new()
		pane.player = player
		pane.event = made
		pane.place = LairPane.place_of(made)
		screen._visit = pane
		screen.add_child(pane)
		pane.left.connect(screen._left_lair.bind(1), CONNECT_DEFERRED)
		pane.trading.connect(func(way: String) -> void: screen.open_trade(way))
	await get_tree().process_frame
	return pane


func test_a_town_s_trade_for_amulets() -> void:
	var player := screen.player
	var slot := _town()
	CardTrade.arrive(player, slot)
	for hue in AdventurePlayer.COLORS:
		player.amulets[hue] = 6
	var pane := screen.visit(_tile(slot))
	var want := String(player.shops[str(slot)]["want"])
	var trade_button := pane.find_child("Choice_trade", true, false) as Button
	assert_not_null(trade_button, "the trade stands where the wise man is")
	assert_eq(trade_button.text, "Trade %s amulet for %s" % [want, CardTrade.wares(int(screen.world.sites[slot]["trade"]))])
	trade_button.pressed.emit()
	await get_tree().process_frame
	var trader := screen.find_child("CardTrade", true, false) as CardTradePane
	assert_not_null(trader, "the card trader")
	assert_true(screen.visiting(), "the world waits")
	var cards := trader.cards()
	assert_true(cards.size() > 0)
	var trade := int(screen.world.sites[slot]["trade"])
	for card_name in cards:
		assert_true(CardTrade.wanted(trade, CardValue.facts(CardRegistry.get_card(card_name))),
			"%s: the town's kind" % card_name)
	trader.choose(cards[0])
	assert_string_contains(trader.ask_text(), "I'll trade you")
	var before := int(player.amulets[want])
	var held := player.cards.size()
	(trader.find_child("TradeYes", true, false) as Button).pressed.emit()
	assert_true(player.cards.size() > held, "traded")
	assert_true(player.amulets[want] < before, "the town's colour paid")
	(trader.find_child("TradeDone", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_false(screen.trading())
	pane = screen.find_child("VisitPane", true, false) as VisitPane
	assert_not_null(pane, "back in the town")
	assert_null(pane.find_child("Choice_trade", true, false), "traded: the wise man again for a while")


func test_the_seller_s_hint_in_the_shop() -> void:
	var player := screen.player
	var slot := _town()
	var offers := CardShop.offers(player, slot)
	var offered := ""
	for card_name in offers:
		if card_name != "" and not card_name in CardShop.LANDS:
			offered = card_name
			break
	CardHints._read = true
	CardHints._hints = [{"first": String(player.cards[0]["card"]), "second": offered, "levels": 0xF,
		"text": "win the day!"}]
	var pane := screen.visit(_tile(slot))
	var buy := pane.find_child("Choice_buy", true, false) as Button
	assert_eq(buy.text, "Buy Cards/Card Hints", "the seller has a hint")
	buy.pressed.emit()
	await get_tree().process_frame
	var shop := screen.find_child("CardShop", true, false) as CardShopPane
	assert_string_contains(shop.hint_text(), "The card seller suggests")
	assert_string_contains(shop.hint_text(), "win the day!")


func test_a_lair_s_treasure() -> void:
	var player := screen.player
	var cards := player.cards.size()
	var pane := await _lair(-1, 3)
	assert_not_null(pane)
	assert_eq(pane.picture_key(), "visit_lair_green")
	assert_eq(pane.words(), LairEvent.FOUND)
	var found := pane.reward()
	assert_eq(pane.shown_card(), found, "the card over the picture")
	# The lair is spent as it is entered, and the world waits under its
	# pane: checked here, not after leaving, where one world tick may
	# already refill the empty slot (1997: a lair never waits) — a slow
	# frame in a loaded run did, once (0.60.0).
	assert_eq(WorldLairs.held_in(player, 1), {}, "the lair gone")
	assert_eq(player.lairs_explored, 1)
	pane.choose("leave")
	await get_tree().process_frame
	assert_false(screen.visiting(), "left")
	assert_eq(player.cards.size(), cards + 1)
	assert_eq(String(player.cards[-1]["card"]), found)


func test_the_gemcutter_s_guild() -> void:
	var player := screen.player
	player.gold = 500
	var pane := await _lair(LairEvent.GEMCUTTER)
	assert_string_contains(pane.words(), "You happen upon a Gemcutter's Guild!")
	assert_string_contains(pane.words(), "You may buy amulets for 200 gold pieces.")
	var blue := int(player.amulets["blue"])
	(pane.find_child("Choice_amulet_blue", true, false) as Button).pressed.emit()
	assert_eq([player.gold, player.amulets["blue"]], [300, blue + 1])
	assert_eq((pane.find_child("Choice_amulet_blue", true, false) as Button).text,
		"Buy a blue amulet. (you have %d)" % (blue + 1))
	(pane.find_child("Choice_leave", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_false(screen.visiting())


func test_the_nomad_s_bazaar() -> void:
	var player := screen.player
	player.gold = 3000
	var pane := await _lair(LairEvent.BAZAAR)
	(pane.find_child("Choice_bazaar", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var trader := screen.find_child("CardTrade", true, false) as CardTradePane
	assert_not_null(trader, "the trader over the lair")
	assert_false(pane.visible, "the lair waits under it")
	trader.choose("Grizzly Bears")
	assert_string_contains(trader.ask_text(), "gold pieces")
	var price := int(trader.asked["gold"])
	(trader.find_child("TradeYes", true, false) as Button).pressed.emit()
	assert_eq(player.gold, 3000 - price)
	(trader.find_child("TradeDone", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_true(pane.visible, "back in the lair")
	pane.leave_lair()
	await get_tree().process_frame
	assert_false(screen.visiting())


func test_a_riddle() -> void:
	var pane := await _lair(LairEvent.LOREMASTER)
	var riddle := pane.riddle
	assert_false(riddle.is_empty())
	assert_string_contains(pane.words(), String(riddle["question"]))
	var right := int(riddle["right"])
	if right < 0:
		right = 0
		while int(riddle["bits"]) & (1 << right) == 0:
			right += 1
	(pane.find_child("Choice_answer_%d" % right, true, false) as Button).pressed.emit()
	assert_string_contains(pane.words(), CardRiddle.CORRECT)
	assert_eq(pane.shown_card(), String(riddle["card"]), "the card shown")
	assert_eq(pane.reward(), String(pane.event["lair_rare"]), "the lair's rare to be found")


func test_a_right_click_reads_a_card_full_screen() -> void:
	var slot := _town()
	screen.open_shop(slot)
	await get_tree().process_frame
	var shop := screen.find_child("CardShop", true, false) as CardShopPane
	var cards := CardShop.offers(screen.player, slot)
	var place := shop.find_child("Offer_0", true, false) as Control
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	place.gui_input.emit(right)
	assert_true(screen.reader.is_open(), "a right click on a card: the large card, as in a duel")
	assert_eq(screen.reader._card._shown.data.card_name, cards[0])
	screen.reader.dismiss()
	Settings.set_value(WorldHud.READER_SETTING, false)
	place.gui_input.emit(right)
	assert_false(screen.reader.is_open(), "switched off in the options")
	Settings.set_value(WorldHud.READER_SETTING, true)

