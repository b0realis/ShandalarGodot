extends GutTest
## One real campaign duel per acquisition rule, with purchases, deck editing,
## save/load and travel. Human-seat decisions use a fair Wizard stand-in.

const SAVE := "user://refuge_card_rule_gameplay.json"
var packs_before: Array[String] = []

func before_each() -> void:
	packs_before = Settings.enabled_card_packs().duplicate()
	CardPacks.set_enabled("pack-2", true)

func after_each() -> void:
	for path in [SAVE, AdventurePlayer.backup_path(SAVE)]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in packs_before):
			CardPacks.set_enabled(id, id in packs_before)

func test_intended_rule_pack_2_gameplay() -> void:
	await _campaign(AdventurePlayer.RULE_MEANT)

func test_shipped_rule_pack_2_gameplay() -> void:
	await _campaign(AdventurePlayer.RULE_SHIPPED)

func test_classic_rule_pack_2_gameplay() -> void:
	await _campaign(AdventurePlayer.RULE_CLASSIC)

func _campaign(rule: String) -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Campaign Tester"
	setup.color = "green"
	setup.seed_text = "48271"
	setup.packs = ["pack-2"]
	setup.expanded_adventure = true
	setup.card_rule = rule
	var record := setup.resolve({"pack-2": "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(player.card_rule, rule)
	assert_eq(player.deck_cards().size(), 36, "the real Apprentice starter, below forty")
	assert_false(AdventurePacks.offers_cards(player, "pack-2"), "mainland remains locked in expanded mode")
	# The same rule also works with cards-only play, without a story unlock.
	player.expanded_adventure = false
	assert_true(AdventurePacks.offers_cards(player, "pack-2"))
	player.expanded_adventure = true
	assert_true(RefugeCampaign.travel(player))
	assert_true(RefugeCampaign.on_island(player))
	assert_true(AdventurePacks.offers_cards(player, "pack-2"))
	var links := player.mana_links()
	# Funds avoid grinding; the deck, life totals, stock, prices and opponent
	# all use the campaign's normal rules. No result or reward is fabricated.
	player.gold = 10000
	player.amulets["green"] = 10
	var offer := _pack_offer(player)
	assert_false(offer.is_empty(), "actual generated town shelves contain a pack card")
	if offer.is_empty(): return
	var shop := CardShopPane.new()
	shop.player = player
	shop.slot = int(offer["slot"])
	add_child_autofree(shop)
	shop.choose(int(offer["index"]))
	var price := CardShop.price_at(player, shop.slot, String(offer["card"]))
	var count := player.cards.size()
	shop.buy_chosen()
	assert_eq(player.cards.size(), count + 1)
	assert_eq(player.gold, 10000 - price)
	assert_true(CardShop.offers(player, shop.slot)[int(offer["index"])] == "", "purchase spends its shelf slot")
	shop.queue_free()
	await get_tree().process_frame
	var trader := CardTradePane.new()
	trader.player = player
	trader.way = CardTrade.TOWN
	trader.color = "green"
	add_child_autofree(trader)
	trader.choose("Thallid")
	assert_false(trader._yes.disabled, "paid trades are available to the small starter")
	count = player.cards.size()
	trader.trade_chosen()
	assert_eq(player.cards.size(), count + 1)
	assert_eq(player.amulets["green"], 9)
	trader.queue_free()
	await get_tree().process_frame
	var builder := AdventureBuilder.new()
	builder.player = player
	add_child_autofree(builder)
	await get_tree().process_frame
	assert_true(builder._add_one("Thallid"), "the purchased card can enter the active deck")
	builder.write_back()
	assert_true(player.deck_cards().has("Thallid"))
	assert_eq(player.deck_cards().size(), 37)
	builder.queue_free()
	await get_tree().process_frame
	assert_eq(player.save(SAVE), SAVE)
	player = AdventurePlayer.load_from(SAVE)
	assert_not_null(player)
	if player == null: return
	assert_eq(player.card_rule, rule)
	assert_true(RefugeCampaign.on_island(player))
	assert_true(player.deck_cards().has("Thallid"))
	player.monster_timer = 4 # an ordinary meeting, without a special modifier
	var meeting := _regional_meeting(player)
	assert_false(meeting.is_empty())
	if meeting.is_empty(): return
	var config := CreatureMeeting.duel_config(player, meeting)
	config.rng_seed = 31337
	assert_true(config.decks[0].has("Thallid"))
	assert_true(config.decks[1].any(func(card: String) -> bool: return card in FallenEmpiresPack.names()))
	var before := player.cards.size()
	var report := await HeadlessDuel.play(config, AiProfile.wizard())
	assert_true(report.finished, report.describe())
	assert_gt(report.turns, 1, "a played game, not a fabricated terminal report")
	assert_eq(report.ante[0], meeting["hero_ante"])
	assert_eq(report.ante[1], meeting["creature_ante"])
	var spoils := DuelSpoils.settle(player, meeting, report)
	assert_eq(int(spoils["result"]), report.result)
	if bool(spoils.get("asks", false)):
		DuelSpoils.choose(player, meeting, spoils, true)
	if report.result == DuelReport.LOSS:
		assert_eq(player.cards.size(), before - report.ante[0].size(), "loss removes exactly the staked cards")
	elif report.result == DuelReport.WIN:
		assert_gte(player.cards.size(), before, "victory keeps the collection and applies spoils")
	WorldCreatures.met(player, int(meeting["slot"]), report.result)
	var owned := player.cards.duplicate(true)
	assert_eq(player.save(SAVE), SAVE)
	player = AdventurePlayer.load_from(SAVE)
	assert_not_null(player)
	if player == null: return
	assert_eq(player.cards, owned)
	assert_eq(player.card_rule, rule)
	assert_true(RefugeCampaign.travel(player))
	assert_false(RefugeCampaign.on_island(player))
	assert_eq(player.cards, owned, "bringing the collection home never confiscates pack cards")
	assert_eq(player.mana_links(), links)
	assert_false(AdventurePacks.offers_cards(player, "pack-2"), "one roaming duel does not liberate the island")
	gut.p("Pack 2 [%s]: bought %s + traded Thallid; 37-card deck; %s; %s; %d turns; save/load and return OK" % [rule, offer["card"], meeting["regional_name"], report.describe(), report.turns])

func _pack_offer(player: AdventurePlayer) -> Dictionary:
	for slot in range(1, 6):
		var stock := CardShop.offers(player, slot)
		for i in stock.size():
			if stock[i] in FallenEmpiresPack.names():
				return {"slot": slot, "index": i, "card": stock[i]}
	return {}

func _regional_meeting(player: AdventurePlayer) -> Dictionary:
	# The fixed white roaming identity has no deck-swap/summoning exception.
	for slot in range(1, 4):
		player.monsters = [{"slot": slot, "kind": "creature", "creature": 8,
			"x": player.position.x, "y": player.position.y, "color": 5, "heading": 0, "frame": 0}]
		var meeting := CreatureMeeting.begin(player, slot)
		if meeting.has("regional_deck"): return meeting
	return {}
