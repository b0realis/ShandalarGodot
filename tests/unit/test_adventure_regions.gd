extends GutTest
## Shared regional state, migrations, dormant content and multi-island travel.

func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)

func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)

func hero(seed_text := "5") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = seed_text
	setup.card_rule = AdventurePlayer.RULE_CLASSIC
	setup.ban_list = ClassicBans.BOTH
	var record := setup.resolve({"pack-2": "1"})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))

func test_hero_effects_and_lifetime_counts_survive_travel() -> void:
	var player := hero()
	player.quickening = 75
	player.lairs_explored = 16
	player.siege_count = 9
	player.quest_timer = 320
	assert_true(_refuge().travel(player))
	assert_eq(player.quickening, 75)
	assert_eq(player.lairs_explored, 16)
	assert_eq(player.siege_count, 9)
	assert_eq(WorldStatus.days_on_road(player), 20)
	player.quickening = 200
	player.lairs_explored += 2
	player.journey_time += 64
	assert_true(_refuge().travel(player))
	assert_eq(player.quickening, 200)
	assert_eq(player.lairs_explored, 18)
	assert_eq(WorldStatus.days_on_road(player), 24)
	assert_eq(player.quest_timer, 320, "mainland deadline clock is independent")

func test_first_island_and_reload_offer_identical_legal_treasures() -> void:
	for seed_text in ["5", "37", "54", "74", "75", "82", "85", "95"]:
		var player := hero(seed_text)
		assert_true(_refuge().travel(player))
		var before: Array = player.world.encounters[5]["cards"].duplicate()
		for card in before:
			assert_false(ClassicBans.is_banned(ShandalarWorld.DUNGEON_CARDS[int(card)][1], player.ban_list))
		var loaded := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
		assert_not_null(loaded)
		if loaded != null: assert_eq(loaded.world.encounters[5]["cards"], before)

func test_nine_inactive_islands_keep_independent_snapshots() -> void:
	var player := hero()
	var template := _refuge().generate(48271, 5, 0)
	var fingerprints := {}
	for index in 9:
		var region_id := "test_island_%d" % index
		var make := func() -> ShandalarWorld:
			var world := AdventurePlayer._world_from(AdventureRegions.snapshot(_with_world(template))["world"], Vector2i.ZERO)
			world.expansion["region"] = region_id
			return world
		assert_true(AdventureRegions.travel(player, region_id, make))
		player.quest_timer = index + 10
		fingerprints[region_id] = player.world.fingerprint()
		assert_true(AdventureRegions.travel(player, AdventureRegions.MAINLAND))
	assert_eq(player.regions.size(), 9)
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(player)
	if player == null: return
	for index in 9:
		var region_id := "test_island_%d" % index
		assert_true(AdventureRegions.travel(player, region_id))
		assert_eq(player.quest_timer, index + 10)
		assert_eq(player.world.fingerprint(), fingerprints[region_id])
		assert_true(AdventureRegions.travel(player, AdventureRegions.MAINLAND))

func _with_world(world: ShandalarWorld) -> AdventurePlayer:
	var player := AdventurePlayer.new()
	player.world = world
	player.position = world.start
	return player

func test_disabled_mainland_needs_no_provider_or_art() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var player := hero()
	AdventureExpansions.refresh()
	AdventureExpansions.initialize(player)
	assert_true(AdventureExpansions._providers.is_empty())
	assert_true(AdventureExpansions.places(player.world).is_empty())
	assert_true(player.expansions.is_empty())
	assert_true(player.regions.is_empty())
	assert_true(AdventureExpansions._trims.is_empty())

func test_nine_coastal_entries_share_safe_anchorage_when_coast_is_full() -> void:
	var player := hero()
	var before := player.world.fingerprint()
	var used: Array = []
	for index in 9:
		var port := RegionGeography.entry_for(player.world, player.world.start_tile(), used)
		assert_gte(port.x, 0)
		for other in used:
			var distance := port.distance_to(Vector2i(other[0], other[1]))
			assert_true(is_zero_approx(distance) or distance >= 4.0, "share an anchorage rather than crowd its neighbor")
		used.append([port.x, port.y])
	assert_eq(player.world.fingerprint(), before)

func test_enabled_mainland_entry_does_not_load_quest_provider() -> void:
	var player := hero()
	AdventureExpansions.refresh()
	AdventureExpansions.initialize(player)
	assert_eq(AdventureExpansions.places(player.world).size(), 1)
	assert_true(AdventureExpansions._providers.is_empty())
	assert_true(player.regions.is_empty(), "unvisited islands are not generated")

func test_departure_menu_and_mainland_score_survive_region_change() -> void:
	var menu := AdventureExpansions.departure_place(["refuge", "second_destination"])
	assert_eq(menu["actions"].size(), 3)
	assert_eq(menu["actions"][0][0], "region_visit:refuge")
	assert_eq(menu["actions"].back()[0], "leave")
	var player := hero()
	TownStatus.take(player.world, 1, 4)
	player.siege_count = 4
	var before := FinalBattle.score_parts(player)
	assert_true(_refuge().travel(player))
	assert_eq(FinalBattle.score_parts(player), before, "sailing cannot erase score penalties")


## The Last Refuge's content, the plugin's own [DataRegion] (adventure
## plugins, 2026-11-10: the built-in scripts it replaced are gone).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
