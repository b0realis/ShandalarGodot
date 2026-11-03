extends GutTest
## The 0.60.13 bug campaign (c26), fixer X6: the quest pane follows a
## petition's stages (h2-2); the final battle's record and the Hall of Fame
## count the whole journey's days (h1-2); a moved dungeon — and Arzakon's
## portal — never stands on a region's hidden anchorage (h2-8); the wise
## man's news is a dated journal line, never a Known clue (h2-9).

const HALL := "user://adventure_tests_c26_x6_hall.json"

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
	if FileAccess.file_exists(HALL):
		DirAccess.remove_absolute(HALL)


func _hero(island: bool, seed_text := "48271") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.expanded_adventure = island
	if island:
		setup.packs = ["pack-2"]
	setup.seed_text = seed_text
	var record := setup.resolve({"pack-2": "1"} if island else {})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


# ------------------------------------------------------- h2-2: the quest pane --

func test_the_quest_pane_follows_a_petitions_stages() -> void:
	var player := _hero(true)
	assert_true(RefugeCampaign.travel(player))
	var before := WorldStatus.lines(player)
	assert_true(RefugeQuests.start(player, 0), "the Bread Road accepted")
	var accepted := WorldStatus.lines(player)
	assert_eq(accepted, WorldStatus.lines_fresh(player), "the pane read again as the petition was accepted")
	assert_ne(accepted, before)
	assert_true(accepted.has("Seek Refuge Harbor."), "where the grain warrant goes: %s" % [accepted])
	player.position = RefugeQuests.destination(player, 0)["tile"] * 32 + Vector2i(16, 16)
	assert_true(RefugeQuests.deliver(player, 0))
	var delivered := WorldStatus.lines(player)
	assert_eq(delivered, WorldStatus.lines_fresh(player), "and again as the warrant was delivered")
	assert_false(delivered.has("Seek Refuge Harbor."))


# ------------------------------------------------------------- h1-2: the days --

## A hero of 40 days on the mainland, 2 on the island, 1 more at home: 43
## days on the road; the mainland's own clock says 41.
func _travelled() -> AdventurePlayer:
	var player := _hero(true)
	player.quest_timer = 40 * WorldStatus.DAY
	player.journey_time = 40 * WorldStatus.DAY
	assert_true(RefugeCampaign.travel(player))
	player.quest_timer += 2 * WorldStatus.DAY
	player.journey_time += 2 * WorldStatus.DAY
	assert_true(RefugeCampaign.travel(player))
	player.quest_timer += WorldStatus.DAY
	player.journey_time += WorldStatus.DAY
	assert_eq(player.quest_timer / WorldStatus.DAY, 41, "the mainland's own clock")
	assert_eq(WorldStatus.days_on_road(player), 43, "the hero pane's days on the road")
	return player


func _won() -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = DuelReport.WIN
	report.winner = 0
	report.lives_start = [20, 40] as Array[int]
	report.lives_end = [7, 0] as Array[int]
	return report


func test_the_final_record_and_the_hall_count_the_whole_journey() -> void:
	var player := _travelled()
	player.defeated_wizards.assign(AdventurePlayer.COLORS)
	FinalBattle.settle(player, _won(), false, {}, "2026-11-03T10:00:00Z")
	assert_eq(player.ended, AdventurePlayer.ENDED_WON)
	assert_eq(int(player.final["days"]), 43, "the record's days are the hero's days on the road")
	assert_eq(int(HallOfFame.entry_of(player)["days"]), 43, "the Hall's line")
	player.final.erase("days")
	assert_eq(int(HallOfFame.entry_of(player)["days"]), 43, "a record without its days reads the journey")


func test_a_one_life_battle_settled_on_an_island_load_counts_the_whole_journey() -> void:
	var player := _travelled()
	player.life_rule = AdventurePlayer.LIFE_ONE
	assert_true(RefugeCampaign.travel(player), "back to the island")
	HallOfFame.mark_one_life(player.adventure_id, HallOfFame.FAILED, HALL)
	assert_true(FinalBattle.on_load(player, HALL, "2026-11-03T10:00:00Z"))
	assert_eq(int(player.final["days"]), 43, "not the island's own 2 days")


# ------------------------------------------------- h2-8: the hidden anchorage --

func test_a_moved_dungeon_never_takes_a_hidden_anchorage() -> void:
	var player := _hero(true)
	AdventureExpansions.initialize(player)
	var point: Array = player.world.expansion["entries"]["refuge"]
	var anchorage := Vector2i(int(point[0]), int(point[1]))
	assert_true(player.world.is_land(anchorage.x, anchorage.y))
	assert_false(DungeonDoors.takes_dungeon(player.world, anchorage, player.tile()), "shown: never")
	AdventureExpansions.read_launch(PackedStringArray())
	assert_eq(AdventureExpansions.marker(player.world, anchorage), "", "hidden without the flag")
	assert_false(DungeonDoors.takes_dungeon(player.world, anchorage, player.tile()), "hidden without the flag: never")
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_false(DungeonDoors.takes_dungeon(player.world, anchorage, player.tile()), "hidden with the pack off: never")
	# An older save's `port` alone.
	var entries: Dictionary = player.world.expansion["entries"]
	player.world.expansion.erase("entries")
	assert_false(DungeonDoors.takes_dungeon(player.world, anchorage, player.tile()), "an older save's port: never")
	player.world.expansion["entries"] = entries
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	# The island's harbor and castle.
	assert_true(RefugeCampaign.travel(player))
	for mark in ["port", "castle"]:
		var at: Array = player.world.expansion[mark]
		assert_false(DungeonDoors.takes_dungeon(player.world, Vector2i(int(at[0]), int(at[1])), Vector2i(-1, -1)), mark)


func test_arzakons_portal_never_stands_on_a_hidden_anchorage() -> void:
	AdventureExpansions.read_launch(PackedStringArray())
	var player := _hero(false)
	var world := player.world
	var chosen := FinalBattle.portal_tile(world)
	assert_true(chosen.x >= 0)
	# A region's anchorage on that very tile, hidden (no flag).
	world.expansion = {"region": AdventureRegions.MAINLAND, "entries": {"refuge": [chosen.x, chosen.y]}}
	assert_eq(AdventureExpansions.marker(world, chosen), "")
	var moved := FinalBattle.portal_tile(world)
	assert_ne(moved, chosen, "the portal stands beside the anchorage, not on it")
	assert_true(FinalBattle.portal_may_stand(world, moved))


# --------------------------------------------------------- h2-9: the news --

## The news's journal lines: their own event, the town named first
## ([constant WiseMan.NEWS_EVENT], [constant WiseMan.NEWS_LOG]; spelled
## out here so the test reads the same before the fix).
const NEWS_EVENT := "news"
const NEWS_LOG := "News from the wise man of %s: %s"

func _first_town(world: ShandalarWorld) -> int:
	for slot in world.sites.size():
		if int(world.sites[slot]["type"]) == ShandalarWorld.TOWN and not TownStatus.ruled(world, slot):
			return slot
	return -1


func _news_lines(player: AdventurePlayer) -> Array:
	return player.journal.filter(func(entry: Dictionary) -> bool: return String(entry.get("event", "")) == NEWS_EVENT)


func test_the_wise_mans_news_is_a_dated_journal_line_never_a_known_clue() -> void:
	AdventureExpansions.read_launch(PackedStringArray())
	var player := _hero(false, "4242")
	var town := _first_town(player.world)
	assert_true(town >= 0)
	var base := player.journal.size()
	var news := ""
	var pages := PackedStringArray()
	for attempt in 400:
		player.journal.resize(base)
		player.known_clues = []
		player.last_town = -1
		player.wise_man = {}
		player.dice = attempt * 7919 + 13
		pages = WiseMan.speak(player, town)["pages"]
		if int(player.wise_man.get("stage", -1)) == WiseMan.STAGE_NEWS \
				and String(player.wise_man.get("news", "")).contains("not yet defeated"):
			news = String(player.wise_man["news"])
			break
	assert_ne(news, "", "a wizard's news found on the dice")
	if news == "":
		return
	assert_eq(pages, PackedStringArray([news]), "the news said")
	for clue in player.known_clues:
		assert_false(String(clue["text"]).contains("not yet defeated"), "never a Known clue: %s" % clue)
	var lines := _news_lines(player)
	assert_eq(lines.size(), 1, "one dated journal line")
	assert_eq(String(lines[0]["text"]) if not lines.is_empty() else "", NEWS_LOG % [WorldNames.site_name(player.world, town),
		news.replace("\n", " ").strip_edges()])
	for entry in player.journal:
		if String(entry.get("text", "")).contains("not yet defeated"):
			assert_false(HeroStats.journal_line(entry).contains("Clue: "), "a plain line: %s" % entry)
			assert_false(bool(entry.get("highlight", false)))
	# The same talk again, in the same town: the same news, not written again.
	pages = WiseMan.speak(player, town)["pages"]
	assert_eq(pages, PackedStringArray([news]))
	assert_eq(_news_lines(player).size(), 1)
	# Saved and read back, the journal's news makes no clue either.
	player.defeated_wizards.assign(AdventurePlayer.COLORS)
	var loaded := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(loaded)
	if loaded == null:
		return
	for clue in loaded.known_clues:
		assert_false(String(clue["text"]).contains("not yet defeated"), "read back: %s" % clue)
	assert_eq(_news_lines(loaded).size(), 1)
