extends GutTest
## Optional expanded trader selections: original defaults, campaign persistence,
## the actual card browser, and unchanged reward, category and Classic rules.

var base: Dictionary
var player: AdventurePlayer


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Trader Keeper"
	setup.walker = "male"
	setup.seed_text = "13579"
	var record := setup.resolve({})
	base = AdventurePlayer.begin(record, AdventureSetup.make_world(record)).to_dict()


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.cards = []
	CardTrade.forget()


func after_each() -> void:
	AdventureSetup.forget()
	CardTrade.forget()


func _pane(way: String) -> CardTradePane:
	var pane := CardTradePane.new()
	pane.player = player
	pane.way = way
	add_child_autofree(pane)
	return pane


func _names(rows: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for row in rows:
		names.append(String(row["name"]))
	return names


func test_new_and_old_campaigns_keep_original_traders() -> void:
	assert_false(AdventureSetup.new().all_trader_cards)
	assert_false(player.all_trader_cards)
	var old := base.duplicate(true)
	old["hero"].erase("all_trader_cards")
	assert_false(AdventurePlayer.from_dict(old).all_trader_cards, "an older save")
	old["hero"]["all_trader_cards"] = "true"
	assert_false(AdventurePlayer.from_dict(old).all_trader_cards, "malformed text is not enabled")
	for way in [CardTrade.TOWN, CardTrade.BAZAAR, CardTrade.MINE, CardTrade.REWARD]:
		var names := _pane(way).cards()
		assert_has(names, "Grizzly Bears")
		for card_name in ["Ifh-Bíff Efreet", "Serendib Efreet", "Black Lotus"]:
			assert_does_not_have(names, card_name, "%s: original selection" % way)


func test_campaign_choice_survives_json_save_and_next_embark() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Trader Keeper"
	setup.all_trader_cards = true
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, player.world)
	assert_true(hero.all_trader_cards)
	var loaded := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	assert_true(loaded.all_trader_cards, "saved with the campaign")
	setup.remember()
	assert_true(AdventureSetup.restore([] as Array[String]).all_trader_cards)
	loaded.all_trader_cards = false
	assert_false(AdventurePlayer.from_dict(loaded.to_dict()).all_trader_cards)
	AdventureSetup.forget()
	assert_false(AdventureSetup.restore([] as Array[String]).all_trader_cards)


func test_paid_traders_include_efreets_and_treasures_but_rewards_do_not() -> void:
	player.all_trader_cards = true
	for way in [CardTrade.TOWN, CardTrade.BAZAAR, CardTrade.MINE]:
		var names := _pane(way).cards()
		for card_name in ["Ifh-Bíff Efreet", "Serendib Efreet", "Black Lotus"]:
			assert_has(names, card_name, "%s: expanded selection" % way)
		for card_name in names:
			assert_true(CardTrade.in_adventure(card_name), "only the adventure's pool")
	var rewards := _pane(CardTrade.REWARD).cards()
	assert_has(rewards, "Grizzly Bears")
	assert_does_not_have(rewards, "Ifh-Bíff Efreet", "free quest picks keep their original pool")
	assert_does_not_have(rewards, "Black Lotus")
	assert_does_not_have(_names(CardTrade.catalogue()), "Serendib Efreet",
		"other reward callers keep the original catalogue after an expanded trade")
	player.all_trader_cards = false
	assert_does_not_have(_pane(CardTrade.TOWN).cards(), "Serendib Efreet",
		"another campaign cannot inherit the cached expanded selection")


func test_town_categories_and_browser_filters_still_apply() -> void:
	player.all_trader_cards = true
	var pane := _pane(CardTrade.TOWN)
	pane.trade = 2 << 8
	assert_has(pane.cards(), "Ifh-Bíff Efreet")
	assert_has(pane.cards(), "Serendib Efreet")
	assert_does_not_have(pane.cards(), "Black Lotus", "Any creatures still means creatures")
	pane.color_filter = 1 << 2
	assert_has(pane.cards(), "Serendib Efreet", "blue creatures")
	assert_does_not_have(pane.cards(), "Ifh-Bíff Efreet", "a green creature")
	pane.color_filter = 0
	pane.trade = 1 << 3
	assert_has(pane.cards(), "Ifh-Bíff Efreet", "green town")
	assert_does_not_have(pane.cards(), "Serendib Efreet")


func test_classic_bans_and_owned_copy_limits_still_apply() -> void:
	player.all_trader_cards = true
	player.card_rule = AdventurePlayer.RULE_CLASSIC
	player.ban_list = ClassicBans.OLD
	var pane := _pane(CardTrade.MINE)
	assert_has(pane.cards(), "Black Lotus", "one restricted copy may be obtained")
	assert_has(pane.cards(), "Serendib Efreet")
	assert_does_not_have(pane.cards(), "Channel", "the selected ban list still applies")
	player.add_card("Black Lotus")
	for i in 4:
		player.add_card("Serendib Efreet")
	assert_does_not_have(pane.cards(), "Black Lotus", "restricted copy already owned")
	assert_does_not_have(pane.cards(), "Serendib Efreet", "four copies already owned")
	assert_has(pane.cards(), "Plains", "basic lands remain available")


func test_newly_available_card_is_purchased_at_its_normal_price() -> void:
	player.all_trader_cards = true
	player.amulets = {"black": 0, "blue": 0, "green": 10, "red": 0, "white": 0}
	var pane := _pane(CardTrade.TOWN)
	pane.trade = 2 << 8
	assert_has(pane.cards(), "Ifh-Bíff Efreet")
	var offered := CardTrade.offer(player, "Ifh-Bíff Efreet", CardTrade.TOWN, "green")
	var price := CardTrade.amulets_for(CardValue.facts(CardRegistry.get_card("Ifh-Bíff Efreet")))
	assert_true(bool(offered["afford"]))
	var bought := CardTrade.pay(player, offered, CardTrade.TOWN, "green")
	assert_true(bool(bought["traded"]))
	assert_eq(int(player.amulets["green"]), 10 - price)
	assert_eq(player.cards[-1], {"card": "Ifh-Bíff Efreet", "decks": []})
