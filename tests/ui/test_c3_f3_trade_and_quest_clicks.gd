extends GutTest
## A TRADE AND A QUEST CLICKED (adventure campaign 2026-10-23, findings h1-1
## and h1-3). The card trader asked its price as a card was chosen and the
## trade, "Yes, I'll trade.", paid by that answer: amulets gone meanwhile
## (a World Magic cast while the trader waited) left the town's colour at
## −1, saved, and the Diamond Mine gave its card for what was left. And a
## village whose quest the hero had failed still stood "Begin a Quest" in
## its choices, and gave the quest again. Every click here is a real one,
## pushed through the viewport.

const SAVES := "user://adventure_tests_c3_f3_clicks"

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
	WiseMan.forget()
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


func _first(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func _tile(slot: int) -> Vector2i:
	return Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))


## The trader open on [param way], a card of [param amulets] amulets chosen.
func _trader_on(way: String, amulets: int, slot := -1, offer := {}) -> CardTradePane:
	var trader := screen.open_trade(way, slot, offer)
	await _frames(2)
	for card_name in trader.cards():
		if CardTrade.amulets_for(CardValue.facts(CardRegistry.get_card(card_name))) == amulets \
				and CardTrade.copies(card_name) == 1:
			trader.choose(card_name)
			break
	await _frames(1)
	return trader


func test_amulets_gone_before_yes_refuse_the_town_s_trade() -> void:
	var player := screen.player
	var slot := _first(ShandalarWorld.TOWN)
	CardTrade.arrive(player, slot)
	for hue in AdventurePlayer.COLORS:
		player.amulets[hue] = 2
	var offer := CardTrade.town_offer(player, slot)
	assert_false(offer.is_empty(), "the town trades")
	var want := String(offer["color"])
	var trader: CardTradePane = await _trader_on(CardTrade.TOWN, 2, slot, offer)
	assert_ne(trader.chosen, "", "a card of two amulets chosen")
	var yes := trader.find_child("TradeYes", true, false) as Button
	assert_false(yes.disabled, "affordable as it was chosen")
	var held := player.cards.size()
	player.amulets[want] = 0
	await _click(yes)
	assert_eq(int(player.amulets[want]), 0, "never -2, saved")
	assert_eq(player.cards.size(), held, "no card")
	assert_string_contains(trader.find_child("TradeNote", true, false).text, CardTrade.AFFORD)


func test_amulets_gone_before_yes_refuse_the_diamond_mine() -> void:
	var player := screen.player
	player.amulets = {"black": 1, "blue": 1, "green": 0, "red": 0, "white": 0}
	var trader: CardTradePane = await _trader_on(CardTrade.MINE, 2)
	assert_ne(trader.chosen, "")
	var held := player.cards.size()
	player.amulets["black"] = 0
	await _click(trader.find_child("TradeYes", true, false) as Button)
	assert_eq(player.amulet_count(), 1, "the one left kept")
	assert_eq(player.cards.size(), held, "no card for one amulet of two")


func test_a_village_whose_quest_failed_offers_no_quest() -> void:
	var player := screen.player
	var village := _first(ShandalarWorld.VILLAGE)
	var destination := -1
	for slot in screen.world.sites.size():
		if TownStatus.is_town(screen.world, slot) and not TownStatus.linked(screen.world, slot):
			destination = slot
			break
	TownStatus.put(screen.world, village, TownStatus.NO_QUESTS)
	player.quest_offer = {"type": Quests.LETTER_LINK, "destination": destination, "color": 4, "at": village}
	var pane := screen.visit(_tile(village), false)
	await _frames(2)
	assert_null(pane.find_child("Choice_quest", true, false), "no Begin a Quest")
	var wise := pane.find_child("Choice_wiseman", true, false) as Button
	assert_not_null(wise, "the wise man instead")
	if wise == null:
		return
	await _click(wise)
	await _frames(2)
	var room := screen.find_child("WiseManPane", true, false) as WiseManPane
	assert_not_null(room, "the wise man's room")
	if room == null:
		return
	assert_eq(room.words(), WiseMan.REFUSAL, "who turns the hero away")
	assert_false(Quests.has_quest(player), "and no quest")
