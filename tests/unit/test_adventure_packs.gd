extends GutTest
## Card modules and optional stories are independent, scoped to a saved campaign.
var previous: Array[String] = []

var _launch_before: bool

func before_each() -> void:
	_launch_before = AdventureExpansions.launch_enabled
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	previous = Settings.enabled_card_packs().duplicate()
	CardPacks.set_enabled("pack-2", true)
	CardPacks.set_enabled("pack-3", true)
	AdventureSetup.forget()
	AdventureExpansions.refresh()

func after_each() -> void:
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]) if _launch_before else PackedStringArray())
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in previous): CardPacks.set_enabled(id, id in previous)
	AdventureSetup.forget()
	AdventureExpansions.clear_development()

func hero(expanded := false, selected: Array[String] = ["pack-2"]) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.expanded_adventure = expanded
	setup.packs = selected
	var versions := {}
	for id in selected: versions[id] = "1"
	var record := setup.resolve(versions)
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player

func names(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return row["name"])

func test_only_the_exact_launch_flag_enables_new_adventures() -> void:
	Settings.set_value(AdventureSetup.KEY_PREFIX + "expanded_adventure", true)
	for args in [[], ["--debug-win"], ["--expanded-adventure=false"], ["--expanded-adventures"]]:
		AdventureExpansions.read_launch(PackedStringArray(args))
		assert_false(AdventureSetup.new().expanded_adventure)
		assert_false(AdventureSetup.restore(["pack-2"]).expanded_adventure, "old checkbox preference is ignored")
	AdventureExpansions.read_launch(PackedStringArray(["--debug-win", "--expanded-adventure"]))
	var setup := AdventureSetup.restore(["pack-2"])
	assert_true(setup.expanded_adventure)
	setup.packs = ["pack-2"]
	setup.remember()
	AdventureExpansions.read_launch(PackedStringArray())
	var restored := AdventureSetup.restore(["pack-2"])
	assert_false(restored.expanded_adventure, "next launch never inherits the opt-in")
	assert_eq(restored.packs, ["pack-2"] as Array[String])
	assert_false(restored.resolve({"pack-2": "1"})["expanded_adventure"])

func test_saved_mainland_story_needs_the_flag_without_losing_progress() -> void:
	var player := hero(true)
	player.refuge["quests"] = [0]
	var saved := player.to_dict()
	AdventureExpansions.read_launch(PackedStringArray())
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_not_null(player)
	assert_true(player.expanded_adventure, "saved mode is preserved, not converted to cards-only")
	assert_eq(player.refuge["quests"], [0])
	assert_true(AdventureExpansions.places(player.world).is_empty())
	assert_false(RefugeCampaign.travel(player))
	assert_true(AdventureExpansions.targets(player).is_empty())
	AdventureTasks.rows(player)
	assert_true(AdventureExpansions._providers.is_empty(), "ordinary launch does not load story providers")
	assert_false(AdventurePacks.offers_cards(player, "pack-2"), "omitting the flag cannot bypass the saved card unlock")
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	AdventureExpansions.initialize(player)
	assert_eq(player.world.expansion["entries"], saved["world"]["expansion"]["entries"])
	assert_true(RefugeCampaign.travel(player))
	assert_eq(player.refuge["quests"], [0])

func test_saved_island_can_return_without_flag_and_resume_later() -> void:
	var player := hero(true)
	assert_true(RefugeCampaign.travel(player))
	player.refuge["quests"] = [0]
	player.refuge["pending"] = ["Thallid"]
	var saved := player.to_dict()
	AdventureExpansions.read_launch(PackedStringArray())
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_not_null(player)
	assert_false(RefugeCampaign.available())
	assert_string_contains(RefugeCampaign.deck_problem(player), "--expanded-adventure")
	var port: Array = player.world.expansion["port"]
	var place := RefugeJourney.describe(player, Vector2i(port[0], port[1]))
	assert_eq(place["actions"][0], ["refuge_sail", "Sail to Shandalar", true])
	var tasks := AdventureTasks.rows(player)
	assert_true(tasks.any(func(task: Dictionary) -> bool: return task["id"] == "refuge/return"))
	assert_false(tasks.any(func(task: Dictionary) -> bool: return task["id"].begins_with("refuge/pledge:") and task["status"] == "active"))
	assert_true(RefugeCampaign.travel(player))
	assert_true(AdventureExpansions.places(player.world).is_empty())
	assert_false(RefugeCampaign.travel(player))
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	assert_true(RefugeCampaign.travel(player))
	assert_eq(player.world.seed, int(saved["world"]["seed"]))
	assert_eq(player.refuge["quests"], [0])
	assert_eq(player.refuge["pending"], ["Thallid"])

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
	assert_false(RefugeCampaign.travel(player), "no hidden voyage in cards-only mode")
	for pool in [CardShop._draw_rules(player, 1)["stock"], CardTrade.for_trader(player, CardTrade.TOWN), LairEvent.reward_pool(player)]:
		var cards := names(pool)
		for card in FallenEmpiresPack.names(): assert_has(cards, card)
	assert_true(AdventureTasks.rows(player).all(func(row: Dictionary) -> bool: return not row["id"].contains("refuge")))
	assert_true(AdventureExpansions._providers.is_empty(), "card availability never loads quest code")
	assert_true(AdventureExpansions._trims.is_empty(), "no expedition artwork")

func test_campaign_selection_overrides_global_enabled_packs() -> void:
	var player := hero(false, [])
	assert_false(AdventurePacks.offers_cards(player, "pack-2"))
	assert_false(AdventurePacks.offers_cards(player, "pack-3"))
	assert_false(names(CardShop._draw_rules(player, 1)["stock"]).has("Thallid"))
	assert_false(RefugeCampaign.travel(player))
	var expanded_without_pack := hero(true, [])
	assert_true(AdventureExpansions.places(expanded_without_pack.world).is_empty())
	assert_false(RefugeCampaign.travel(expanded_without_pack))

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

func test_expanded_mode_keeps_local_cards_and_mainland_liberation_gate() -> void:
	var player := hero(true)
	assert_false(AdventurePacks.offers_cards(player, "pack-2"))
	assert_false(AdventureExpansions.places(player.world).is_empty())
	assert_true(RefugeCampaign.travel(player))
	assert_true(AdventurePacks.offers_cards(player, "pack-2"))
	assert_true(RefugeCampaign.travel(player))
	assert_false(AdventurePacks.offers_cards(player, "pack-2"))
	player.refuge["liberated"] = true
	assert_true(AdventurePacks.offers_cards(player, "pack-2"))
	assert_false(AdventurePacks.offers_cards(hero(true), "pack-2"), "unlock is per hero")

func test_saved_modes_and_pack_choices_survive_round_trip() -> void:
	for mode in [false, true]:
		var player := hero(mode)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
		var loaded := AdventurePlayer.from_dict(saved)
		assert_not_null(loaded)
		if loaded == null: continue
		assert_eq(loaded.expanded_adventure, mode)
		assert_eq(loaded.packs, player.packs)
		assert_eq(AdventurePacks.offers_cards(loaded, "pack-2"), not mode)
		assert_eq(AdventureExpansions.places(loaded.world).is_empty(), not mode)

func test_legacy_expedition_save_keeps_story_and_return_even_with_pack_disabled() -> void:
	var player := hero(true)
	assert_true(RefugeCampaign.travel(player))
	var saved := player.to_dict()
	saved["version"] = 6
	saved["hero"].erase("expanded_adventure")
	saved["hero"]["packs"] = []
	CardPacks.set_enabled("pack-2", false)
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded)
	if loaded == null: return
	assert_true(loaded.expanded_adventure)
	assert_true(AdventurePacks.selected(loaded, "pack-2"))
	assert_true(RefugeCampaign.travel(loaded))
	assert_true(AdventureExpansions.places(loaded.world).is_empty())
	assert_false(RefugeCampaign.travel(loaded))
	CardPacks.set_enabled("pack-2", true)
	assert_true(RefugeCampaign.travel(loaded))

func test_old_ordinary_save_stays_ordinary_even_when_packs_are_enabled_globally() -> void:
	var saved := hero(false, []).to_dict()
	saved["version"] = 6
	saved["hero"].erase("expanded_adventure")
	var loaded := AdventurePlayer.from_dict(saved)
	assert_false(loaded.expanded_adventure)
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

func test_old_unvisited_harbor_keeps_its_pack_and_coordinates() -> void:
	var saved := hero(true).to_dict()
	var port: Array = saved["world"]["expansion"]["port"].duplicate()
	saved["version"] = 6
	saved["hero"].erase("expanded_adventure")
	saved["hero"]["packs"] = []
	var loaded := AdventurePlayer.from_dict(saved)
	assert_true(loaded.expanded_adventure)
	assert_true(AdventurePacks.selected(loaded, "pack-2"))
	assert_eq(loaded.world.expansion["port"], port)
	assert_false(AdventureExpansions.places(loaded.world).is_empty())

func test_switching_to_cards_only_drops_prior_adventure_provider() -> void:
	var expanded := hero(true)
	assert_true(RefugeCampaign.travel(expanded))
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

func test_another_pack_can_attach_an_adventure_with_its_own_unlock_field() -> void:
	var module := preload("res://tools/expansion_testing/beacon_region.gd")
	var descriptor: Dictionary = module.descriptor()
	descriptor["pack"] = "pack-3"
	descriptor["cards_unlock"] = "complete"
	assert_true(AdventureExpansions.register_development(module.ID, descriptor))
	var player := hero(true, ["pack-3"])
	assert_eq(AdventurePacks.adventures("pack-3"), [module.ID] as Array[String])
	assert_false(AdventurePacks.offers_cards(player, "pack-3"))
	assert_true(AdventureExpansions._providers.is_empty())
	player.expansions[module.ID]["complete"] = true
	assert_true(AdventurePacks.offers_cards(player, "pack-3"))
	assert_true(AdventurePacks.offers_cards(hero(false, ["pack-3"]), "pack-3"))
	assert_true(AdventureExpansions.places(hero(true, []).world).is_empty(), "unselected module adds no port")
	CardPacks.set_enabled("pack-3", false)
	assert_false(AdventureExpansions.enabled_for(player, module.ID))
	assert_false(AdventurePacks.offers_cards(player, "pack-3"))
