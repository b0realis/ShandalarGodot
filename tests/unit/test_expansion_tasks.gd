extends GutTest
## Shared objectives, mana-link policy, independent region schemas and opponents.
const BEACON = preload("res://tools/expansion_testing/beacon_region.gd")

func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)

func after_each() -> void:
	AdventureExpansions.clear_development()
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)

func hero(seed_text := "48271") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = seed_text
	var record := setup.resolve({"pack-2": "1"})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))

func test_only_mainland_links_count_across_travel_and_legacy_saves() -> void:
	var player := hero()
	var original := player.mana_links()
	var magics := player.world_magics.duplicate()
	var jewels := player.amulets.duplicate()
	assert_true(_refuge().travel(player))
	assert_eq(player.mana_links(), original)
	TownStatus.put(player.world, 1, TownStatus.LINKED)
	assert_false(TownStatus.linked(player.world, 1))
	player.world.sites[2]["status"] = TownStatus.LINKED # legacy prototype save
	assert_false(TownStatus.linked(player.world, 2))
	assert_true(_refuge().finish_quest(player, 0))
	assert_eq(player.mana_links(), original)
	assert_eq(player.world_magics, magics)
	assert_eq(player.amulets, jewels)
	assert_true(_refuge().travel(player))
	var restored := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(restored)
	if restored != null: assert_eq(restored.mana_links(), original)

func test_task_selection_moves_with_quest_and_routes_through_return_ship() -> void:
	var player := hero()
	assert_true(_refuge().travel(player))
	assert_true(AdventureTasks.select(player, "refuge/pledge:0"))
	assert_eq(AdventureTasks.guide(player, [])[0]["tile"], Quests.site_tile(player.world, 1))
	assert_true(_refuge().start(player, 0))
	var port: Array = player.world.expansion["port"]
	assert_eq(AdventureTasks.guide(player, [])[0]["tile"], Vector2i(port[0], port[1]))
	assert_true(_refuge().travel(player))
	var selected := AdventureTasks.guide(player, [])
	var departure: Array = player.world.expansion["entries"]["refuge"]
	assert_eq(selected[0]["tile"], Vector2i(departure[0], departure[1]))
	assert_true(AdventureExpansions._providers.is_empty(), "listing inactive tasks releases their provider")
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_true(AdventureTasks.guide(player, []).is_empty(), "do not direct to invisible harbor")
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	assert_true(_refuge().travel(player))
	assert_true(AdventureTasks.select(player, "mainland/wizard:0"))
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_eq(AdventureTasks.guide(player, [])[0]["tile"], Vector2i(port[0], port[1]))

func test_completed_task_clears_and_clues_outlive_journal_trimming() -> void:
	var player := hero()
	assert_true(_refuge().travel(player))
	AdventureTasks.select(player, "refuge/pledge:0")
	player.log_clue("The vault is north of Havenwood.")
	player.log_clue("The vault is north of Havenwood.")
	player.journal.clear()
	assert_true(_refuge().finish_quest(player, 0))
	assert_true(AdventureTasks.guide(player, []).is_empty())
	assert_eq(player.tracked_task, "")
	var restored := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(restored)
	if restored == null: return
	assert_eq(restored.known_clues.filter(func(clue: Dictionary) -> bool: return clue["text"] == "The vault is north of Havenwood.").size(), 1)
	AdventureTasks.read(restored, {"selected": [], "clues": [{"region": "refuge", "text": "bad", "kind": [], "day": {}}]})
	assert_eq(restored.tracked_task, "")
	assert_true(restored.known_clues.is_empty())

func test_geographic_targets_on_several_seeds_and_old_map_repair() -> void:
	for seed_text in ["5", "37", "82", "48271"]:
		var player := hero(seed_text)
		assert_true(_refuge().travel(player))
		var channel := _refuge().destination_slot(player, 1)
		if channel >= 0: assert_true(RegionGeography.coast(player.world, Quests.site_tile(player.world, channel)))
		var raider := _refuge().destination_slot(player, 3)
		if raider != 4: assert_true(RegionObjectives.matches(player.world, Quests.site_tile(player.world, raider), {"road": true, "near_terrain": 5, "radius": 2}))
		var before := player.world.fingerprint()
		player.world.expansion["objectives"] = {"channel": {}, "raider": 999}
		_refuge().ensure_objectives(player)
		assert_gte(_refuge().destination_slot(player, 1), -1)
		assert_eq(player.world.fingerprint(), before)

func test_another_region_needs_no_castle_pledges_art_or_refuge_schema() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()))
	var player := hero()
	# Ticked at the Embark beside the Refuge (adventure plugins: no switch
	# ticks every land at once any more).
	player.adventures = AdventurePlayer.ticked_rows(["refuge", BEACON.ID])
	AdventureExpansions.initialize(player)
	assert_true(AdventureRegions.travel(player, BEACON.ID, func() -> ShandalarWorld: return AdventureExpansions.generate(BEACON.ID, 42, 5, 0)))
	assert_false(player.world.expansion.has("castle"))
	assert_eq(RegionGeography.component(player.world, player.tile()).size(), 64)
	assert_true(AdventureTasks.select(player, BEACON.ID + "/light"))
	player.expansions[BEACON.ID]["lit"] = 2
	var restored := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(restored)
	if restored == null: return
	assert_eq(restored.expansions[BEACON.ID]["lit"], 2)
	assert_eq(restored.tracked_task, BEACON.ID + "/light")
	assert_false(AdventureExpansions.valid_progress(BEACON.ID, {"lit": 4, "complete": false}))
	assert_false(AdventureExpansions.valid_progress(BEACON.ID, {"lit": 2, "complete": "yes"}))
	assert_true(AdventureRegions.travel(restored, AdventureRegions.MAINLAND))
	assert_true(AdventureExpansions._providers.is_empty())

func test_roaming_spells_tribute_and_life_are_consistent_and_not_adaptive() -> void:
	var player := hero()
	assert_true(_refuge().travel(player))
	var meeting := CreatureMeeting.meet(player, 4, 3, 2)
	_refuge().roaming_encounter(player, meeting)
	# Select a stable eligible slot without changing the player or enemy strength.
	for slot in range(1, 7):
		meeting["slot"] = slot
		_refuge().roaming_encounter(player, meeting)
		if meeting.has("regional_deck"): break
	assert_true(meeting.has("regional_deck"))
	if not meeting.has("regional_deck"): return
	var first := CreatureMeeting.duel_config(player, meeting)
	assert_eq(first.decks[1], meeting["regional_deck"])
	assert_eq(first.lives[1], _refuge().foe_for(4)["life"])
	for card in CreatureMeeting.spell_choices(meeting): assert_true(card in first.decks[1])
	for card in meeting["creature_ante"]: assert_true(card in first.decks[1])
	player.next_duel_life = 90
	player.cards.clear()
	for i in 40: player.cards.append({"card": "Black Lotus", "decks": [0]})
	var later := CreatureMeeting.duel_config(player, meeting)
	assert_eq(later.decks[1], first.decks[1])
	assert_eq(later.lives[1], first.lives[1])
	var quest := CreatureMeeting.meet(player, 4, 3, 2)
	quest["quest"] = true
	_refuge().roaming_encounter(player, quest)
	assert_false(quest.has("regional_deck"))

func test_pledges_and_liberation_leave_small_saved_visual_marks() -> void:
	var player := hero()
	assert_true(_refuge().travel(player))
	assert_true(RegionPresentation.banner(player.world, Quests.site_tile(player.world, 1)).is_empty())
	_refuge().finish_quest(player, 0)
	assert_false(RegionPresentation.banner(player.world, Quests.site_tile(player.world, 1)).is_empty())
	assert_eq(player.world.expansion["banners"].size(), 1)
	AdventureExpansions.progress(player, "refuge")["quests"] = [0, 1, 2, 3, 4]
	AdventureExpansions.progress(player, "refuge")["liberated"] = true
	_refuge().refresh_appearance(player)
	assert_eq(player.world.expansion["banners"].size(), 6)
	var restored := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(restored)
	if restored != null: assert_eq(restored.world.expansion["banners"], player.world.expansion["banners"])

func test_old_link_errand_keeps_other_rewards_without_creating_a_link() -> void:
	var player := hero()
	assert_true(_refuge().travel(player))
	var links := player.mana_links()
	var jewels := int(player.amulets.get("blue", 0))
	player.quest = {"type": Quests.LETTER_LINK, "destination": 22, "giver": 8, "color": 2, "deadline": 200}
	var answer := Quests.complete_at(player, 22)
	assert_false(answer.is_empty())
	assert_eq(player.mana_links(), links)
	assert_eq(int(player.amulets["blue"]), jewels + 1)
	assert_eq(answer["sound"], "sfx_reward")
	assert_false(str(answer["lines"]).contains("mana link"))
	assert_true(player.quest.is_empty())

func test_unknown_hunt_has_no_arrow_and_selection_survives_saving() -> void:
	var player := hero()
	player.quest = {"type": -4, "destination": 1, "giver": 1, "color": 3, "deadline": 200}
	var id := "mainland/errand:1:200"
	assert_true(AdventureTasks.select(player, id))
	assert_true(AdventureTasks.guide(player, []).is_empty())
	var restored := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(restored)
	if restored == null: return
	assert_eq(restored.tracked_task, id)
	restored.quest["type"] = -104
	assert_eq(AdventureTasks.guide(restored, [])[0]["tile"], Quests.site_tile(restored.world, 1))

func test_task_deadline_refreshes_at_its_boundary_not_the_calendar_day() -> void:
	var player := hero()
	player.quest = {"type": Quests.LETTER_AMULET, "destination": 1, "giver": 8, "color": 2, "deadline": 23}
	player.quest_timer = 0
	var first := AdventureTasks.rows(player).filter(func(task: Dictionary) -> bool: return task["title"] == "Town errand")
	assert_string_contains(first[0]["text"], "2 days left")
	player.quest_timer = 8
	var later := AdventureTasks.rows(player).filter(func(task: Dictionary) -> bool: return task["title"] == "Town errand")
	assert_string_contains(later[0]["text"], "1 day left")
	player.quest_timer = 23
	later = AdventureTasks.rows(player).filter(func(task: Dictionary) -> bool: return task["title"] == "Town errand")
	assert_string_contains(later[0]["text"], "0 days left")

func test_completed_entries_remain_below_new_tasks_after_reload() -> void:
	var player := hero()
	_refuge().travel(player)
	AdventureTasks.rows(player)
	_refuge().finish_quest(player, 0)
	var tasks := AdventureTasks.rows(player)
	var completed := tasks.filter(func(task: Dictionary) -> bool: return task["id"] == "refuge/pledge:0")[0] as Dictionary
	assert_eq(completed["status"], "completed")
	assert_false(AdventureTasks.select(player, completed["id"]))
	player.quest = {"type": Quests.LETTER_AMULET, "destination": 22, "giver": 8, "color": 2, "deadline": 123}
	tasks = AdventureTasks.rows(player)
	assert_eq(tasks[0]["id"], "refuge/errand:8:123")
	var hit_done := false
	for task in tasks:
		if task["status"] != "active": hit_done = true
		elif hit_done: fail_test("An active task appeared below finished tasks")
	var restored := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(restored)
	if restored == null: return
	tasks = AdventureTasks.rows(restored)
	assert_eq(tasks[0]["id"], "refuge/errand:8:123")
	assert_true(tasks.any(func(task: Dictionary) -> bool: return task["id"] == completed["id"] and task["status"] == "completed"))

func test_errand_completion_and_expiration_have_distinct_saved_outcomes() -> void:
	var player := hero()
	_refuge().travel(player)
	player.quest = {"type": Quests.LETTER_AMULET, "destination": 22, "giver": 8, "color": 2, "deadline": 123}
	assert_false(Quests.complete_at(player, 22).is_empty())
	var done := AdventureTasks.rows(player).filter(func(task: Dictionary) -> bool: return task["id"] == "refuge/errand:8:123")[0] as Dictionary
	assert_eq(done["status"], "completed", "a quest never opened in Tasks is still recorded")
	player.quest = {"type": Quests.LETTER_AMULET, "destination": 22, "giver": 16, "color": 2, "deadline": 2}
	player.quest_timer = 2
	assert_ne(Quests.check_deadline(player), "")
	var expired := AdventureTasks.rows(player).filter(func(task: Dictionary) -> bool: return task["id"] == "refuge/errand:16:2")[0] as Dictionary
	assert_eq(expired["status"], "expired")
	assert_eq(AdventureTasks.timer_text(expired), "")
	assert_false(AdventureTasks.select(player, expired["id"]))

func test_timers_are_colored_and_pause_for_inactive_regions() -> void:
	var player := hero()
	player.quest = {"type": Quests.LETTER_AMULET, "destination": 1, "giver": 8, "color": 2, "deadline": 10}
	var active := AdventureTasks.rows(player).filter(func(task: Dictionary) -> bool: return task["id"] == "mainland/errand:8:10")[0] as Dictionary
	assert_string_contains(AdventureTasks.timer_text(active), "less than a campaign day")
	assert_eq(AdventureTasks.timer_color(active), Color("ff9494"))
	_refuge().travel(player)
	var paused := AdventureTasks.rows(player).filter(func(task: Dictionary) -> bool: return task["id"] == "mainland/errand:8:10")[0] as Dictionary
	assert_string_contains(AdventureTasks.timer_text(paused), "PAUSED")
	assert_eq(AdventureTasks.timer_color(paused), Color("9bd8ef"))
	assert_eq(paused["timer_steps"], 10)

func test_siege_countdown_survives_travel_and_archives_real_outcomes() -> void:
	var player := hero()
	player.siege_timer = 64
	assert_false(Sieges.start(player).is_empty())
	var task: Dictionary = AdventureTasks.rows(player).filter(func(item: Dictionary) -> bool: return item["kind"] == "siege")[0]
	var id: String = task["id"]
	assert_eq(task["timer_steps"], 24)
	_refuge().travel(player)
	var paused: Dictionary = AdventureTasks.rows(player).filter(func(item: Dictionary) -> bool: return item["id"] == id)[0]
	assert_true(paused["paused"])
	assert_eq(paused["timer_steps"], 24)
	_refuge().travel(player)
	player.siege_timer = 85
	var urgent: Dictionary = AdventureTasks.rows(player).filter(func(item: Dictionary) -> bool: return item["id"] == id)[0]
	assert_eq(urgent["timer_steps"], 3)
	assert_eq(AdventureTasks.timer_color(urgent), Color("ff9494"))
	var outcome := WorldCreatures.met(player, Sieges.SLOT, WorldCreatures.WON)
	Sieges.lifted(player, outcome)
	assert_eq(player.task_history[id]["status"], "completed")
	assert_false(Sieges.start(player).is_empty())
	var next: Dictionary = AdventureTasks.rows(player).filter(func(item: Dictionary) -> bool: return item["kind"] == "siege" and item["status"] == "active")[0]
	assert_ne(next["id"], id)
	Sieges.resolve(player)
	assert_eq(player.task_history[next["id"]]["status"], "failed")


## The Last Refuge's content, the plugin's own [DataRegion] (adventure
## plugins, 2026-11-10: the built-in scripts it replaced are gone).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
