extends GutTest
## The 0.60.13 bug campaign, fixer X2 — regions and names: the island keeps
## the campaign's world seed (h1-3), a save made at landing is not a new
## adventure (h1-5), old journal lines carry no "Region day" (the owner's
## ruling of 2026-11-03), and the island's villages and extra towns have
## their own names (the owner's polish of 2026-11-03).

func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)

func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)

func hero(seed_text := "48271", island := true) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures.assign(["refuge"] if island else [])
	var chosen: Array[String] = []
	if island: chosen.append("pack-2")
	setup.packs = chosen
	setup.seed_text = seed_text
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": "1"} if island else {})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))

func reloaded(saved: Dictionary) -> AdventurePlayer:
	return AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(saved)))


# --------------------------------------------------- h1-3, the world seed --

func test_the_island_keeps_the_campaigns_seed_text() -> void:
	var player := hero("Dragonsong")
	assert_eq(player.world_seed_text, "Dragonsong")
	assert_true(_refuge().travel(player))
	assert_eq(player.world_seed_text, "Dragonsong", "on the island")
	var saved := player.to_dict()
	assert_eq(saved["world"]["seed_text"], "Dragonsong", "an island save writes it")
	var loaded := reloaded(saved)
	assert_not_null(loaded)
	if loaded == null: return
	assert_eq(loaded.world_seed_text, "Dragonsong", "an island save reads it")
	assert_true(_refuge().travel(loaded))
	assert_eq(loaded.world_seed_text, "Dragonsong", "home again")
	assert_true(_refuge().travel(loaded))
	assert_eq(loaded.world_seed_text, "Dragonsong", "the island again")

func test_a_region_entered_is_not_a_new_adventure() -> void:
	var player := hero()
	assert_eq(player.monster_timer, 0, "a new adventure's clock")
	assert_true(_refuge().travel(player))
	assert_ne(player.monster_timer, 0, "the island just landed on")
	var loaded := reloaded(player.to_dict())
	assert_not_null(loaded)
	if loaded == null: return
	assert_ne(loaded.monster_timer, 0, "its autosave, loaded")

func test_the_island_keeps_its_own_quiet_clock() -> void:
	# The island's creatures still wait as on a fresh world: one tick on,
	# not the mainland's clock.
	var player := hero()
	player.monster_timer = 9000
	assert_true(_refuge().travel(player))
	assert_lt(player.monster_timer, 32)
	assert_true(_refuge().travel(player))
	assert_eq(player.monster_timer, 9000, "the mainland's clock waited")


# ------------------------------------------ the journal ruling, old lines --

func test_old_journal_lines_read_as_plain_days() -> void:
	var player := hero("5", false)
	player.log_event("visit", "Visited the town of Oldtown.")
	var saved := player.to_dict()
	saved["version"] = 3
	saved.erase("journey")
	for entry in saved["record"]["journal"]: entry.erase("region")
	var loaded := reloaded(saved)
	assert_not_null(loaded)
	if loaded == null: return
	assert_eq(loaded.journal.size(), 1)
	for entry: Dictionary in loaded.journal:
		assert_false(entry.has("regional_day"), "no \"Region day\" (ruling 2026-11-03)")
		assert_false(entry.has("region"), "an old line carries no region")

func test_a_journal_marked_by_0_60_6_loses_the_region_day() -> void:
	var player := hero("5", false)
	player.log_event("visit", "Visited the town of Oldtown.")
	var saved := player.to_dict()
	saved["record"]["journal"][0]["regional_day"] = true
	var loaded := reloaded(saved)
	assert_not_null(loaded)
	if loaded == null: return
	assert_false(loaded.journal[0].has("regional_day"))
	assert_eq(loaded.journal[0].get("region"), AdventureRegions.MAINLAND, "a new line keeps its region")


# ---------------------------------------------------- the island's names --

func mainland_names() -> Dictionary:
	var names := {}
	for first in WorldNames.FIRST_HALVES:
		names[first + " Village"] = true
		for second in WorldNames.SECOND_HALVES:
			names[first + " " + second] = true
	for list in [WorldNames.CASTLES, WorldNames.WIZARDS, WorldNames.DUNGEONS]:
		for name: String in list:
			names[name] = true
	return names

func test_the_islands_villages_and_towns_have_their_own_names() -> void:
	var mainland := mainland_names()
	var kinds := [ShandalarWorld.TOWN, ShandalarWorld.CITY, ShandalarWorld.VILLAGE]
	var villages_seen := {}
	for seed_value in [48271, 5, 37, 54, 74, 1997, 31337, 777]:
		var world := _refuge().generate(seed_value, 5, 1)
		var used := {}
		var villages := 0
		for slot in world.sites.size():
			var kind := int(world.sites[slot]["type"])
			if kind not in kinds: continue
			var name := WorldNames.site_name(world, slot)
			assert_eq(name, String(world.expansion["town_names"].get(str(slot), "")), "slot %d is named by the island" % slot)
			assert_false(mainland.has(name), "%s is not a mainland name" % name)
			for first in WorldNames.FIRST_HALVES:
				assert_false(name.contains(first), "%s borrows no mainland word" % name)
			assert_false(used.has(name), "%s is the island's only one" % name)
			used[name] = true
			if kind == ShandalarWorld.VILLAGE:
				villages += 1
				villages_seen[name] = true
		assert_between(villages, 6, 9)
		# The extra towns keep the word their picture shows (a temple, …).
		for slot in [22, 43, 58, 76, 80, 103]:
			assert_true(WorldNames.site_name(world, slot).ends_with(" " + WorldNames.SECOND_HALVES[slot % 16]))
		for i in _refuge().quest_count():
			assert_eq(WorldNames.site_name(world, i + 1), _refuge().giver_name(i), "the five communities keep theirs")
	assert_gt(villages_seen.size(), 6, "the later villages are named too")


## The Last Refuge's content, the plugin's own [DataRegion] (adventure
## plugins, 2026-11-10: the built-in scripts it replaced are gone).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
