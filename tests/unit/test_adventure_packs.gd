extends GutTest
## Card modules and optional lands are independent, scoped to a saved campaign.
## ADVENTURE PLUGINS (2026-11-10, the spec's §0.2 and §0.3): a land is ticked
## at the Embark — no launch flag — and the card packs it needs behave as in
## the vanilla adventure, their cards on offer from the first day. Ported
## from the launch-flag era: the flag's tests became the plugins' (a ticked
## land, remembered like the packs; the retired flag's preference never
## read), and the "cards wait for liberation" tests now hold that they do not.
var previous: Array[String] = []

func before_each() -> void:
	previous = Settings.enabled_card_packs().duplicate()
	CardPacks.set_enabled("pack-2", true)
	CardPacks.set_enabled("pack-3", true)
	AdventureSetup.forget()
	AdventureExpansions.refresh()

func after_each() -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in previous): CardPacks.set_enabled(id, id in previous)
	AdventureSetup.forget()
	AdventureExpansions.clear_development()

func hero(expanded := false, selected: Array[String] = ["pack-2"]) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.adventures.assign(["refuge"] if expanded else [])
	setup.packs = selected
	var versions := {}
	for id in selected: versions[id] = "1"
	var record := setup.resolve(versions)
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player

func names(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return row["name"])

func test_plugins_are_ticked_and_remembered_never_the_retired_switch() -> void:
	assert_true(AdventurePlugins.valid("refuge"), "the prototype is found in a development run: %s" % AdventurePlugins.refusal("refuge"))
	Settings.set_value(AdventureSetup.KEY_PREFIX + "expanded_adventure", true)
	assert_eq(AdventureSetup.new().adventures, [] as Array[String])
	assert_eq(AdventureSetup.restore(["pack-2"]).adventures, [] as Array[String], "the old checkbox preference is never read")
	var setup := AdventureSetup.restore(["pack-2"])
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.remember()
	var restored := AdventureSetup.restore(["pack-2"])
	assert_eq(restored.adventures, ["refuge"] as Array[String], "remembered like the packs")
	assert_eq(restored.packs, ["pack-2"] as Array[String])
	var record := restored.resolve({"pack-2": "1"})
	assert_eq(record["adventures"].map(func(row: Dictionary) -> String: return row["id"]), ["refuge"])
	assert_eq(String(record["adventures"][0]["version"]), String(AdventurePlugins.row("refuge")["version"]))
	assert_false(record.has("expanded_adventure"))
	Settings.set_value(AdventureSetup.KEY_PREFIX + "plugins", "refuge,not_installed", false)
	assert_eq(AdventureSetup.restore(["pack-2"]).adventures, ["refuge"] as Array[String], "a plugin gone is dropped")

func test_a_ticked_land_whose_pack_is_off_keeps_its_progress_and_way_home() -> void:
	var player := hero(true)
	assert_true(_refuge().travel(player))
	AdventureExpansions.progress(player, "refuge")["quests"] = [0]
	AdventureExpansions.progress(player, "refuge")["pending"] = ["Thallid"]
	var saved := player.to_dict()
	CardPacks.set_enabled("pack-2", false)
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_not_null(player)
	assert_false(_refuge().available())
	assert_string_contains(_refuge().deck_problem(player), "Pack 2")
	var port: Array = player.world.expansion["port"]
	var place := _refuge().describe(player, Vector2i(port[0], port[1]))
	assert_eq(place["actions"][0], ["refuge_sail", "Sail to Shandalar", true], "the ship home always sails")
	var tasks := AdventureTasks.rows(player)
	assert_true(tasks.any(func(task: Dictionary) -> bool: return task["id"] == "refuge/return"))
	assert_true(_refuge().travel(player))
	assert_true(AdventureExpansions.places(player.world).is_empty(), "no anchorage while its pack is off")
	assert_false(_refuge().travel(player))
	CardPacks.set_enabled("pack-2", true)
	assert_true(_refuge().travel(player))
	assert_eq(player.world.seed, int(saved["world"]["seed"]))
	assert_eq(AdventureExpansions.progress(player, "refuge")["quests"], [0])
	assert_eq(AdventureExpansions.progress(player, "refuge")["pending"], ["Thallid"])

func test_cards_only_add_all_fallen_empires_cards_without_adventure_resources() -> void:
	var player := hero()
	var ordinary := hero(false, [])
	assert_eq(player.world.page, ordinary.world.page)
	assert_eq(player.world.sites, ordinary.world.sites)
	assert_eq(player.world.encounters, ordinary.world.encounters)
	assert_eq(player.cards, ordinary.cards, "the starter remains base cards")
	assert_eq(player.dice, ordinary.dice)
	assert_true(player.world.expansion.is_empty())
	assert_true(player.expansions.is_empty())
	assert_true(player.regions.is_empty())
	assert_true(AdventureExpansions.places(player.world).is_empty())
	assert_false(_refuge().travel(player), "no hidden voyage in cards-only mode")
	for pool in [CardShop._draw_rules(player, 1)["stock"], CardTrade.for_trader(player, CardTrade.TOWN), LairEvent.reward_pool(player)]:
		var cards := names(pool)
		for card in FallenEmpiresPack.names(): assert_has(cards, card)
	assert_true(AdventureTasks.rows(player).all(func(row: Dictionary) -> bool: return not row["id"].contains("refuge")))
	AdventureExpansions.release_inactive("mainland")
	assert_true(AdventureExpansions._trims.is_empty(), "no expedition artwork")

func test_campaign_selection_overrides_global_enabled_packs() -> void:
	var player := hero(false, [])
	assert_false(AdventurePacks.offers_cards(player, "pack-2"))
	assert_false(AdventurePacks.offers_cards(player, "pack-3"))
	assert_false(names(CardShop._draw_rules(player, 1)["stock"]).has("Thallid"))
	assert_false(_refuge().travel(player))
	var expanded_without_pack := hero(true, [])
	assert_true(AdventureExpansions.places(expanded_without_pack.world).is_empty())
	assert_false(_refuge().travel(expanded_without_pack))

func test_pack_without_adventure_is_usable_in_both_modes_and_stock_deduplicates() -> void:
	assert_true(AdventurePacks.adventures("pack-3").is_empty())
	for mode in [false, true]:
		var player := hero(mode, ["pack-2", "pack-3"])
		assert_true(AdventurePacks.offers_cards(player, "pack-3"))
		var stock := CardTrade.for_trader(player, CardTrade.TOWN)
		var cards := names(stock)
		assert_has(cards, "Balduvian Bears")
		var unique := {}
		for card in cards: unique[card] = true
		assert_eq(cards.size(), unique.size(), "reprints and variants appear once")
		# A base card withheld by the trader must not slip back as a reprint.
		for row in AdventurePacks.card_stock("pack-3"):
			assert_false(CardTrade.in_adventure(row["name"]))

func test_a_ticked_land_never_holds_its_packs_cards_back() -> void:
	var player := hero(true)
	assert_true(AdventurePacks.offers_cards(player, "pack-2"), "on the mainland from the first day (§0.2)")
	assert_has(names(CardTrade.for_trader(player, CardTrade.TOWN)), "Thallid")
	assert_false(AdventureExpansions.places(player.world).is_empty())
	assert_true(_refuge().travel(player))
	assert_true(AdventurePacks.offers_cards(player, "pack-2"))
	assert_true(_refuge().travel(player))
	assert_true(AdventurePacks.offers_cards(player, "pack-2"), "not freed, and still on offer")

func test_saved_modes_and_pack_choices_survive_round_trip() -> void:
	for mode in [false, true]:
		var player := hero(mode)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
		var loaded := AdventurePlayer.from_dict(saved)
		assert_not_null(loaded)
		if loaded == null: continue
		assert_eq(AdventureExpansions.ticked(loaded, "refuge"), mode)
		assert_eq(loaded.packs, player.packs)
		assert_true(AdventurePacks.offers_cards(loaded, "pack-2"))
		assert_eq(AdventureExpansions.places(loaded.world).is_empty(), not mode)

func test_old_ordinary_save_stays_ordinary_even_when_packs_are_enabled_globally() -> void:
	var saved := hero(false, []).to_dict()
	saved["version"] = 6
	saved["hero"].erase("adventures")
	var loaded := AdventurePlayer.from_dict(saved)
	assert_eq(loaded.adventures, [])
	assert_true(loaded.packs.is_empty())
	AdventureExpansions.initialize(loaded)
	assert_true(AdventureExpansions.places(loaded.world).is_empty())

func test_embarking_activates_selected_card_rules_only() -> void:
	CardPacks.set_enabled("pack-2", false)
	assert_eq(AdventurePacks.activate(["pack-2"]), "")
	assert_true(CardPacks.is_enabled("pack-2"))
	assert_true(CardPacks.is_enabled("pack-3"), "unrelated duel settings are retained")
	CardPacks.set_enabled("pack-2", false)
	assert_false(AdventurePacks.activate(["pack-2", "pack-missing"]).is_empty())
	assert_false(CardPacks.is_enabled("pack-2"), "a missing selection is refused before enabling any pack")

func test_switching_to_cards_only_drops_prior_adventure_provider() -> void:
	var expanded := hero(true)
	assert_true(_refuge().travel(expanded))
	assert_false(AdventureExpansions._providers.is_empty())
	var ordinary := hero()
	assert_true(AdventureExpansions._providers.is_empty())
	assert_true(AdventurePacks.offers_cards(ordinary, "pack-2"))
	assert_true(AdventureExpansions.places(ordinary.world).is_empty())

func test_every_installed_card_module_works_without_its_adventure() -> void:
	var ids := AdventureSetup.offered_packs(CardPacks.available_ids())
	assert_gt(ids.size(), 1)
	assert_eq(AdventurePacks.activate(ids), "")
	var player := hero(false, ids)
	var cards := names(CardTrade.for_trader(player, CardTrade.TOWN))
	for id in ids:
		assert_true(AdventurePacks.offers_cards(player, id), id)
		var missing: Array[String] = []
		for entry in CardPacks.entry_records(id):
			var card: String = entry["name"]
			if not CardTrade.in_adventure(card) and not card in cards: missing.append(card)
		assert_eq(missing, [] as Array[String], id + " supplies every added identity")
	assert_true(player.expansions.is_empty())
	assert_true(AdventureExpansions._providers.is_empty())

func test_another_pack_can_attach_a_land_that_needs_it() -> void:
	var module := preload("res://tools/expansion_testing/beacon_region.gd")
	var descriptor: Dictionary = module.descriptor()
	descriptor["packs"] = ["pack-3"]
	assert_true(AdventureExpansions.register_development(module.ID, descriptor))
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.adventures = [module.ID] as Array[String]
	setup.packs = ["pack-3"]
	var record := setup.resolve({"pack-3": "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	assert_eq(AdventurePacks.adventures("pack-3"), [module.ID] as Array[String])
	assert_true(AdventurePacks.offers_cards(player, "pack-3"), "its cards from the first day")
	assert_true(AdventureExpansions._providers.is_empty())
	assert_true(AdventureExpansions.enabled_for(player, module.ID))
	assert_true(AdventureExpansions.places(hero(true, []).world).is_empty(), "unselected module adds no port")
	CardPacks.set_enabled("pack-3", false)
	assert_false(AdventureExpansions.enabled_for(player, module.ID))
	assert_false(AdventurePacks.offers_cards(player, "pack-3"))


## The Last Refuge's content, the plugin's own [DataRegion] (adventure
## plugins, 2026-11-10: the built-in scripts it replaced are gone).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
