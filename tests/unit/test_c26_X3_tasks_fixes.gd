extends GutTest
## THE TASKS AND THE JOURNAL'S DAYS (0.60.13 bug campaign, c26, fixer X3):
## h2-3 a paused errand's id floated after a load and lost its tracking;
## h2-4 the Tasks tab called the ordinary campaign's dungeons "Dungeon 1";
## h2-7 one launch without the flag cleared a tracked island task; h1-4 a
## tracked island task hid every arrow on the mainland with Pack 2 off; and
## the owner's journal ruling of 2026-11-03 ("Region only with an island"):
## an ordinary campaign's lines read "Day N: …" and no line says "Region day".

var _launch_before: bool
var _pack_before: bool


func before_each() -> void:
	_launch_before = AdventureExpansions.launch_enabled
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	_pack_before = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)


func after_each() -> void:
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]) if _launch_before else PackedStringArray())
	CardPacks.set_enabled(FallenEmpiresPack.ID, _pack_before)


## A campaign that chose the island (Pack 2 and the prototype).
func _island_hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.expanded_adventure = true
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	var record := setup.resolve({"pack-2": "1"})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## An ordinary campaign.
func _plain_hero(seed_text := "4242") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = seed_text
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func _reloaded(player: AdventurePlayer) -> AdventurePlayer:
	return AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))


func _first_town(world: ShandalarWorld, kind: int) -> int:
	for slot in world.sites.size():
		if int(world.sites[slot]["type"]) == kind and not TownStatus.ruled(world, slot): return slot
	return -1


func _ids(player: AdventurePlayer) -> Array:
	return AdventureTasks.rows(player).map(func(task: Dictionary) -> String: return task["id"])


# ------------------------------------------------------------------ h2-3 --

func test_h2_3_a_paused_errand_keeps_its_id_and_tracking_through_an_island_save() -> void:
	var player := _island_hero()
	var giver := _first_town(player.world, ShandalarWorld.VILLAGE)
	var goal := _first_town(player.world, ShandalarWorld.TOWN)
	player.quest = {"type": Quests.LETTER_AMULET, "destination": goal, "giver": giver, "color": 2, "data": -1, "deadline": player.quest_timer + 63}
	var id := "mainland/errand:%d:%d" % [giver, player.quest_timer + 63]
	assert_true(AdventureTasks.select(player, id))
	assert_true(RefugeCampaign.travel(player))
	var loaded := _reloaded(player)
	assert_not_null(loaded)
	if loaded == null: return
	assert_true(_ids(loaded).has(id), "the paused errand's id after the load: %s" % [_ids(loaded)])
	assert_false(_ids(loaded).any(func(each: String) -> bool: return each.contains(".0")), "no float in an id")
	var guided := AdventureTasks.guide(loaded, [] as Array[Dictionary])
	assert_eq(loaded.tracked_task, id, "the tracking survives the load")
	assert_eq(guided.size(), 1, "one arrow: the ship home")
	if guided.size() == 1: assert_eq(guided[0]["name"], "Ship toward Shandalar")


func test_h2_3_a_float_id_saved_by_0_60_12_is_mended_on_reading() -> void:
	var player := _island_hero()
	player.quest = {"type": Quests.LETTER_AMULET, "destination": 22, "giver": 8, "color": 2, "deadline": 63}
	AdventureTasks.rows(player)
	var entry: Dictionary = player.task_history["mainland/errand:8:63"].duplicate()
	var old := {"selected": "mainland/errand:8.0:63.0", "sequence": 9,
		"history": {"mainland/errand:8:63": entry, "mainland/errand:8.0:63.0": entry.merged({"order": 9}, true)}}
	AdventureTasks.read(player, old)
	assert_false(player.task_history.has("mainland/errand:8.0:63.0"), "the floated twin is gone")
	assert_true(player.task_history.has("mainland/errand:8:63"))
	assert_eq(player.tracked_task, "mainland/errand:8:63", "its tracking moves to the mended id")


# ------------------------------------------------------------------ h2-4 --

func test_h2_4_the_ordinary_campaigns_dungeon_tasks_carry_the_dungeons_names() -> void:
	AdventureExpansions.read_launch(PackedStringArray())
	var player := _plain_hero()
	for slot in [5, 9]:
		player.world.encounters[slot]["clues"] = int(player.world.encounters[slot].get("clues", 0)) | WorldClues.LOCATION
	var titles := {}
	for task in AdventureTasks.rows(player):
		titles[task["id"]] = task["title"]
	assert_eq(titles.get("mainland/dungeon:5", ""), "The Paths of Chronus")
	assert_eq(titles.get("mainland/dungeon:9", ""), "Soulchant Monastery")
	assert_eq(titles.get("mainland/dungeon:5", ""), WorldNames.dungeon_name(5, player.world), "as the clues and the visit pane name it")


func test_h2_4_the_islands_own_dungeon_name_still_wins() -> void:
	var player := _island_hero()
	assert_true(RefugeCampaign.travel(player))
	player.world.encounters[5]["clues"] = int(player.world.encounters[5].get("clues", 0)) | WorldClues.LOCATION
	var titles := {}
	for task in AdventureTasks.rows(player):
		titles[task["id"]] = task["title"]
	assert_eq(titles.get("refuge/dungeon:5", ""), WorldNames.dungeon_name(5, player.world))
	assert_ne(titles.get("refuge/dungeon:5", ""), WorldNames.DUNGEONS[5], "the island's dungeon keeps its own name")


# ------------------------------------------------------------------ h2-7 --

func test_h2_7_a_launch_without_the_flag_keeps_a_tracked_island_task() -> void:
	var player := _island_hero()
	assert_true(RefugeCampaign.travel(player))
	assert_true(AdventureTasks.select(player, "refuge/pledge:2"))
	AdventureExpansions.read_launch(PackedStringArray())
	AdventureTasks.guide(player, [] as Array[Dictionary])
	assert_eq(player.tracked_task, "refuge/pledge:2", "the choice is kept while the island's tasks are hidden")
	var saved := _reloaded(player)
	assert_not_null(saved)
	if saved == null: return
	AdventureTasks.guide(saved, [] as Array[Dictionary])
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	assert_eq(saved.tracked_task, "refuge/pledge:2", "and saved: the next launch with the flag still has it")
	var guided := AdventureTasks.guide(saved, [] as Array[Dictionary])
	assert_eq(guided.size(), 1)
	if guided.size() == 1: assert_eq(guided[0]["id"], "refuge/pledge:2")


# ------------------------------------------------------------------ h1-4 --

func test_h1_4_an_island_task_out_of_reach_leaves_the_mainlands_arrow() -> void:
	var player := _island_hero()
	assert_true(RefugeCampaign.travel(player))
	assert_true(AdventureTasks.select(player, "refuge/pledge:0"))
	assert_true(RefugeCampaign.travel(player))
	var siege: Array[Dictionary] = [{"tile": Vector2i(12, 30), "kind": "siege", "name": "Kraag Temple"}]
	assert_eq(AdventureTasks.guide(player, siege)[0]["name"], "Ship toward The Last Refuge", "the pack on: the ship")
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var guided := AdventureTasks.guide(player, siege)
	assert_eq(guided.size(), 1, "the pack off: not no arrow at all")
	if guided.size() == 1: assert_eq(guided[0]["kind"], "siege", "the automatic guidance takes over")
	assert_eq(player.tracked_task, "refuge/pledge:0", "the choice is kept for when the pack is back")
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	assert_eq(AdventureTasks.guide(player, siege)[0]["name"], "Ship toward The Last Refuge")


# ------------------------------------------------------- the journal ruling --

func _lines(player: AdventurePlayer) -> Array[String]:
	var stats := HeroStats.new()
	stats.player = player
	var lines := stats.journal_lines()
	stats.free()
	return lines


func test_an_ordinary_campaigns_journal_reads_day_n_without_a_region() -> void:
	AdventureExpansions.read_launch(PackedStringArray())
	var player := _plain_hero()
	player.journal.clear()
	player.log_event("magic", "JUMP!")
	assert_eq(_lines(player), ["Day 0: JUMP!"] as Array[String])


func test_an_island_campaigns_journal_names_the_region() -> void:
	var player := _island_hero()
	player.journal.clear()
	player.log_event("magic", "On the mainland.")
	assert_true(RefugeCampaign.travel(player))
	player.log_event("magic", "On the island.")
	var lines := _lines(player)
	assert_eq(lines[0], "Day 0 · The Last Refuge: On the island.")
	assert_true(lines.has("Day 0 · Shandalar: On the mainland."), "a mainland line too: %s" % [lines])


func test_no_line_says_region_day() -> void:
	var player := _plain_hero()
	player.journal = [{"event": "magic", "text": "Old line.", "day": 7, "regional_day": true},
		{"event": "magic", "text": "Old line with its region.", "day": 8, "regional_day": true, "region": "mainland"}]
	assert_eq(_lines(player), ["Day 8: Old line with its region.", "Day 7: Old line."] as Array[String])
	var island := _island_hero()
	island.journal = [{"event": "magic", "text": "Old line.", "day": 7, "regional_day": true}]
	assert_eq(_lines(island), ["Day 7: Old line."] as Array[String], "an old line with no region names none")
