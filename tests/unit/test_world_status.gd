extends GutTest
## WHAT CALLS THE HERO AND WHAT THEY CAST (2026-10-23): the 1997 names of
## the places ([WorldNames]), the quest panel's lines and clock
## ([WorldStatus]), the clues ([WorldClues]) and the five World Magics
## that risk an amulet ([WorldMagic]), read in the 1.3 decompilation.


## A world of plain land, its sites given as `[x, y, type]`.
func _player(sites: Array = []) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 6
	for site in sites:
		world.sites.append({"x": site[0], "y": site[1], "type": site[2], "trade": 0, "status": 0})
	var player := AdventurePlayer.new()
	player.world = world
	player.position = Vector2i(10 * 32 + 16, 10 * 32 + 16)
	return player


func test_the_places_are_named_as_1997_named_them() -> void:
	var sites := []
	for slot in 12:
		sites.append([slot, 0, ShandalarWorld.TOWN])
	sites[0][2] = ShandalarWorld.VILLAGE
	var player := _player(sites)
	assert_eq(WorldNames.site_name(player.world, 0), "Amanaxis Village", "a village: its first half")
	assert_eq(WorldNames.site_name(player.world, 9), "Andor's Hall", "slot 9: halves 1 and 9")
	assert_eq(WorldNames.site_name(player.world, 3), "Amanaxis Forge")
	assert_eq(WorldNames.dungeon_name(0), "Castle Necris")
	assert_eq(WorldNames.dungeon_name(14), "Altar of the Cyclops")


func test_the_quest_s_days_and_words() -> void:
	var player := _player([[20, 20, ShandalarWorld.CITY], [5, 5, ShandalarWorld.VILLAGE]])
	assert_eq(WorldStatus.lines(player), [] as Array[String], "nothing calls")
	player.quest_timer = 40
	player.quest = {"type": 1, "destination": 0, "color": 4, "data": 2, "deadline": 40 + 40 * 2 - 1,
		"giver": 1}
	assert_eq(WorldStatus.days_left(player), 5, "a card quest's 79 steps: 5 days, 16 steps a day")
	var called := WorldNames.site_name(player.world, 0)
	player.cards.clear()
	assert_eq(WorldStatus.quest_lines(player), ["Find a red Land spell",
		"Reward: Mana Link and an amulet", "5 days left"] as Array[String],
		"slot 0 asks a land (slot & 3); not held yet: what to find, as 1997 said it")
	player.cards.append({"card": "Mountain", "decks": []})
	assert_eq(WorldStatus.quest_lines(player)[0], "Go South to " + called, "held: the way")
	player.quest["data"] = -1
	assert_eq(WorldStatus.quest_lines(player)[0], "Take card to " + called, "turned off it: what to do")
	player.quest_timer = 40 + 64
	assert_eq(WorldStatus.days_left(player), 1, "the last day")
	assert_eq(WorldStatus.check_quest(player), "", "still running")
	player.quest_timer = 40 + 79
	assert_eq(WorldStatus.check_quest(player),
		"The people of Amanaxis Village are sorry their quest was not completed.")
	assert_true(player.quest.is_empty())
	assert_eq(String(player.journal[-1]["event"]), "quest")
	# A creature to defeat; beaten, back to the giver.
	player.quest = {"type": -1, "destination": 0, "giver": 1, "deadline": 999}
	assert_eq(WorldStatus.quest_lines(player)[0], "Defeat a Witch", "the creature with its article")
	player.quest["type"] = -112
	assert_eq(WorldStatus.quest_target(player), 1)
	assert_eq(WorldStatus.quest_lines(player)[0], "Return to Amanaxis Village")
	assert_eq(WorldStatus.check_quest(player), "", "a beaten creature's quest waits for its reward")
	assert_eq(WorldStatus.days_on_road(player), (40 + 79) / 16, "days on the road: the quest clock's days")


func test_the_wizards_taps_and_the_next_duel() -> void:
	var player := _player([[20, 20, ShandalarWorld.CITY], [30, 30, ShandalarWorld.CITY]])
	assert_eq(WorldStatus.taps(player), [0, 0, 0, 0, 0] as Array[int])
	player.world.sites[0]["status"] = 2 << 8
	player.world.sites[1]["status"] = (2 << 8) | 2
	assert_eq(WorldStatus.taps(player), [0, 2, 0, 0, 0] as Array[int], "a city's high byte: its wizard")
	assert_eq(WorldStatus.tap_lines(player), ["Blue Wizardess: 2 of 3 mana taps"] as Array[String])
	player.world_magics.append("Ring of the Guardian")
	assert_eq(WorldStatus.dominion(player), 5, "Ring of the Guardian: five")
	assert_eq(WorldStatus.next_duel_line(player), "")
	player.next_duel_life = -3
	player.next_duel_card = "Lord of Atlantis"
	assert_eq(WorldStatus.next_duel_line(player), "Next Duel: -3 lives, Lord of Atlantis")


func test_the_clues_say_what_is_known() -> void:
	var player := _player([[20, 20, ShandalarWorld.CITY]])
	var world := player.world
	for i in 15:
		world.encounters.append({"x": 23, "y": 25, "town": 0, "color": 4, "rules": 0,
			"card_in_effect": -1, "cards": [] if i < 5 else [11]})
	assert_eq(WorldClues.known(world), [] as Array[int])
	world.encounters[6]["clues"] = WorldClues.RULES | WorldClues.LOCATION
	world.encounters[6]["rules"] = 0x10 | 0x20 | 0x01
	world.encounters[6]["card_in_effect"] = 287
	world.encounters[7]["clues"] = WorldClues.RULES
	world.encounters[7]["cards"] = []
	assert_eq(WorldClues.known(world), [6] as Array[int], "a dungeon emptied of its cards is not listed")
	assert_eq(WorldClues.lines(world, 6), ["Treasure: Black Lotus", "Dungeon Rules:", "-No Red cards allowed.",
		"-One deck for all duels.", "-Life losses carried over.", "-Winter Orb permanently in effect.",
		"Location:", "-East of %s." % WorldNames.site_name(world, 0)] as Array[String])
	world.encounters[8]["clues"] = WorldClues.RULES
	assert_eq(WorldClues.lines(world, 8)[-1], "-No special rules.")


func test_the_amulet_is_risked_as_the_difficulty_says() -> void:
	var player := _player()
	player.world_magics.append("Quickening")
	player.amulets["green"] = 5
	player.difficulty = 3
	for i in 3:
		assert_true(WorldMagic.cast(player, 3)["spent"], "a Wizard always loses it")
	assert_eq(int(player.amulets["green"]), 2)
	player.difficulty = 0
	var dice := MsvcRandom.new(player.dice)
	var expected := dice.below(4) == 0
	var result := WorldMagic.cast(player, 3)
	assert_true(result["cast"])
	assert_eq(result["spent"], expected, "an Apprentice: internal_rand(4) == 0")
	assert_eq(player.quickening, WorldMagic.QUICKENING_TICKS)
	assert_eq(WorldMagic.key_of("Sword of Resistance"), 5)
	assert_eq(WorldMagic.key_of("Ring of the Guardian"), 0, "the passive ones have no key")


func test_staff_of_thunder_strikes_the_nearest_roaming_creature() -> void:
	var player := _player()
	player.world_magics.append("Staff of Thunder")
	player.amulets["red"] = 1
	player.difficulty = 3
	player.monsters = [{"slot": 2, "name": "Far", "x": player.position.x + 300, "y": player.position.y},
		{"slot": 4, "name": "Near", "x": player.position.x + 100, "y": player.position.y + 100},
		{"slot": 7, "name": "Besieger", "x": player.position.x, "y": player.position.y, "town": 0}]
	assert_eq(WorldMagic.nearest_roaming(player), 1, "600 against 300: twice the longer side and the shorter (1.3's measure)")
	var result := WorldMagic.cast(player, 4)
	assert_eq(String(result["said"]), "Staff of Thunder: the Near is struck from the land. The red amulet is spent.")
	assert_eq(player.monsters.size(), 2)
	assert_false(WorldMagic.ready_to_cast(player, 4), "no red amulet left")


## The hero's stats count the journal as 1997's `RebuildStatsJournalCounts`
## did, and colour a creature's record as it did.
func test_the_stats_are_read_from_the_journal() -> void:
	var player := _player()
	player.log_event("duel", "Defeated Ogre", {"won": true, "creature": "Ogre"})
	player.log_event("duel", "Defeated Ogre", {"won": true, "creature": "Ogre"})
	player.log_event("duel", "Lost to Shade", {"won": false, "creature": "Shade"})
	player.log_event("saved", "Saved Kraag Forge")
	player.log_event("freed", "Freed Zephyr Hold")
	player.log_event("quest", "Completed quest at Kraag Forge", {"done": true})
	player.log_event("quest", "Quest failed for Zephyr Hold", {"done": false})
	player.log_event("treasure", "Acquired spell: Mox Jet")
	var kept := HeroStats.record(player)
	assert_eq([kept["won"], kept["lost"], kept["saved"], kept["recovered"], kept["quests_done"],
		kept["quests_failed"], kept["treasures"]], [2, 1, 1, 1, 1, 1, 1])
	assert_eq(kept["creatures"], {"Ogre": [2, 0], "Shade": [0, 1]})
	assert_eq(HeroStats.record_ink(9, 1), HeroStats.RECORD_INKS[4], "winning big")
	assert_eq(HeroStats.record_ink(1, 8), HeroStats.RECORD_INKS[0], "losing badly")
	assert_eq(HeroStats.record_ink(2, 1), HeroStats.RECORD_INKS[2], "too few to tell")
	assert_eq(HeroStats.record_ink(6, 3), HeroStats.RECORD_INKS[3], "winning")
	assert_eq(int(player.journal[0]["day"]), 0, "the day on the road kept with each line")
