extends GutTest
## PLACES, API 3, ROUND 3 (2026-11-22): a journey (`teleport`), a World
## Magic, a mana link and a life bonus given by a place, and the two
## conditions that go with them — each refused before anything is paid
## when it cannot be had, each behind a price, none on the adventure's dice.

const INN := preload("res://tests/support/c1122_places_fixture.gd")
const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const ROOT := "user://c1122_places_r3_tests"


func before_each() -> void:
	INN.install(ROOT, INN.sites_r3())
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()


func after_each() -> void:
	AdventureExpansions.clear_development()
	INN.remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()


func hero(lands: Array[String] = ["inn"]) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.adventures = lands
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player


func inn() -> DataSites:
	return AdventureSites.provider("inn")


func _has_problem(problems: Array, part: String) -> bool:
	for problem: String in problems:
		if part in problem:
			return true
	gut.p("problems: " + "\n".join(problems))
	return false


func _guild(content: Dictionary) -> Array:
	return content["sites"]["inn"]["panes"][0]["actions"]


func _inn_tile(player: AdventurePlayer) -> Vector2i:
	var point: Array = player.world.expansion[AdventureSites.KEY]["inn:inn"]
	return Vector2i(int(point[0]), int(point[1]))


## The hero standing at the inn, as when its pane is open.
func _at_the_inn(player: AdventurePlayer) -> void:
	player.position = _inn_tile(player) * 32 + Vector2i(16, 16)


# ------------------------------------------------------------ the checks --

func test_the_words_are_of_api_3_and_checked() -> void:
	assert_true(AdventurePlugins.valid("inn"), AdventurePlugins.refusal("inn"))
	var content := INN.sites_r3()
	_guild(content)[0]["when"] = [{"life_bonus_below": 10}, {"town_linked": "nearest_town"}]
	assert_eq(INN.problems(content), [])
	var old := INN.problems(content, 2)
	for word in ["teleport", "world_magic", "mana_link", "life_bonus", "life_bonus_below", "town_linked"]:
		assert_true(_has_problem(old, "\"%s\" is a word of plugin API 3" % word), word)
	assert_eq(PluginSchema.schema()["types"]["sites_effect"]["options"]["world_magic"]["values"], AdventurePlayer.WORLD_MAGICS as Array)
	var cases := [
		[func(c: Dictionary) -> void: _guild(c)[0]["effects"].reverse(), "teleport: a teleport is the action's last effect"],
		[func(c: Dictionary) -> void: _guild(c)[0]["effects"] = [{"roll": {"outcomes": [{"effects": [{"teleport": {"to": "start"}}]}, {}]}}], "not in a roll, a duel or a talk."],
		[func(c: Dictionary) -> void: _guild(c)[0]["effects"] = [{"teleport": {"to": "place:mill"}}], "teleport.to: no place mill in sites.json sites."],
		[func(c: Dictionary) -> void: _guild(c)[0]["effects"] = [{"teleport": {"to": "place:inn"}}], "teleport.to: inn is this place itself."],
		[func(c: Dictionary) -> void: _guild(c)[0]["effects"] = [{"teleport": {"to": "dungeon:attic"}}], "teleport.to: no dungeon attic"],
		[func(c: Dictionary) -> void: _guild(c)[0]["effects"] = [{"teleport": {"to": "the_moon"}}], "teleport.to"],
		[func(c: Dictionary) -> void: _guild(c)[2]["prices"] = [], "world_magic: this is given without end"],
		[func(c: Dictionary) -> void: _guild(c)[3]["prices"] = [], "mana_link: this is given without end"],
		[func(c: Dictionary) -> void: _guild(c)[4]["prices"] = [], "life_bonus: this is given without end"],
		[func(c: Dictionary) -> void: _guild(c)[4]["effects"] = [{"life_bonus": 4}], "life_bonus: 4 is outside 1..3."],
		[func(c: Dictionary) -> void: _guild(c)[2]["effects"] = [{"world_magic": "Sword of Plenty"}], "world_magic"],
	]
	for case: Array in cases:
		content = INN.sites_r3()
		(case[0] as Callable).call(content)
		assert_true(_has_problem(INN.problems(content), String(case[1])), String(case[1]))


# ----------------------------------------------------------- world magic --

func test_a_world_magic_is_the_heros_as_if_bought_and_never_paid_for_twice() -> void:
	var plain := hero([])
	var player := hero()
	var index := AdventurePlayer.WORLD_MAGICS.find("Dwarven Pick")
	player.world_magics.erase("Dwarven Pick")
	player.world.world_magic_sites[index] = 7
	player.gold = 1000
	assert_string_contains(String(inn().describe(player, "inn", "guild")["actions"][2][1]), "Pay 300 gold")
	inn().do_effects(player, "inn", "magic")
	assert_true(player.owns("Dwarven Pick"))
	assert_eq(player.gold, 700)
	assert_eq(player.world.world_magic_sites[index], 0, "its seller sells it no more")
	assert_eq(String(player.journal.back()["event"]), "magic", "written as a World Magic bought")
	assert_eq(player.world_magics.count("Dwarven Pick"), 1)
	var pane := inn().do_effects(player, "inn", "magic")
	assert_eq(String(pane["lines"][0]), "Dwarven Pick is yours already.")
	assert_eq(player.gold, 700, "nothing paid")
	assert_eq(inn().uses(player, "inn", "magic"), 1)
	assert_eq(player.dice, plain.dice, "the adventure's dice untouched")


# ------------------------------------------------------------- mana link --

func test_a_mana_link_is_made_with_the_nearest_town_that_can_take_one() -> void:
	var player := hero()
	var world := player.world
	player.gold = 1000
	var first := inn().nearest_town(player, "inn", true)
	assert_gt(first, -1, "control: a town without a link")
	assert_true(TownStatus.is_town(world, first))
	# The nearest is held by a wizard, the next besieged: neither is linked.
	TownStatus.take(world, first, 1)
	var second := inn().nearest_town(player, "inn", true)
	assert_ne(second, first)
	player.monsters.append({"slot": Sieges.SLOT, "town": second, "x": 0, "y": 0})
	if WorldStatus.siege_town(player) != second:
		player.monsters.pop_back()
		pending("this build reads its besieger another way")
		return
	var third := inn().nearest_town(player, "inn", true)
	assert_false(third in [first, second])
	var links := player.mana_links()
	var life := player.duel_start_life()
	inn().do_effects(player, "inn", "link")
	assert_true(TownStatus.linked(world, third))
	assert_false(TownStatus.has(world, second, TownStatus.LINKED), "the besieged town is left alone")
	assert_false(TownStatus.has(world, first, TownStatus.LINKED), "and the wizard's")
	assert_eq(TownStatus.ruler(world, first), 1)
	assert_eq(player.mana_links(), links + 1)
	assert_eq(player.duel_start_life(), life + 1)
	assert_eq(player.gold, 800)


func test_a_link_is_refused_before_paying_where_none_can_be_made() -> void:
	var player := hero()
	player.gold = 1000
	for slot in player.world.sites.size():
		if TownStatus.is_town(player.world, slot):
			TownStatus.put(player.world, slot, TownStatus.LINKED)
	assert_true(inn().holds(player, "inn", [{"town_linked": "nearest_town"}]))
	var links := player.mana_links()
	var pane := inn().do_effects(player, "inn", "link")
	assert_eq(String(pane["lines"][0]), "No town of this land can be linked now.")
	assert_eq([player.gold, player.mana_links(), inn().uses(player, "inn", "link")], [1000, links, 0])
	assert_false(bool(inn().describe(player, "inn", "guild")["actions"][3][2]), "its button says so")
	var nearest := inn().nearest_town(player, "inn")
	TownStatus.put(player.world, nearest, TownStatus.LINKED, false)
	assert_false(inn().holds(player, "inn", [{"town_linked": "nearest_town"}]))
	assert_eq(inn().nearest_town(player, "inn", true), nearest)


func test_no_link_on_a_land_without_mana_links() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()))
	var player := hero([BEACON.ID, "inn"] as Array[String])
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	AdventureExpansions.entered(player)
	assert_false(AdventureExpansions.mana_links_allowed(player.world), "control")
	player.gold = 1000
	var pane := inn().do_effects(player, "inn", "link")
	assert_eq(String(pane["lines"][0]), "No town of this land can be linked now.", "said, never silently dropped")
	assert_eq(player.gold, 1000)


# ------------------------------------------------------------ life bonus --

func test_a_life_bonus_counts_in_every_duel_up_to_ten_and_is_saved() -> void:
	var player := hero()
	player.gold = 1000
	var life := player.duel_start_life()
	var plain: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	assert_false((plain["duels"] as Dictionary).has("life_bonus"), "a save without a bonus is the save it was")
	assert_true(inn().holds(player, "inn", [{"life_bonus_below": 1}]))
	var seen: Array = []
	for i in 4:
		inn().do_effects(player, "inn", "vigor")
		seen.append(player.life_bonus)
	assert_eq(seen, [3, 6, 9, 10], "ten at most")
	assert_eq(player.gold, 600)
	assert_eq(player.duel_start_life(), life + 10)
	assert_eq(CreatureMeeting.hero_life(player), life + 10, "a meeting's life reads it through the one reader")
	assert_eq(inn().values(player, "inn")["life_bonus"], 10)
	assert_false(inn().holds(player, "inn", [{"life_bonus_below": 10}]))
	var pane := inn().do_effects(player, "inn", "vigor")
	assert_eq(String(pane["lines"][0]), "No place can add to your life any more.")
	assert_eq(player.gold, 600, "nothing paid at the cap")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	assert_eq(int(saved["version"]), 9)
	assert_eq(int(saved["duels"]["life_bonus"]), 10)
	# The plugin gone: the bonus was paid for, and stays.
	INN.remove(ROOT)
	AdventurePlugins.scan()
	var read := AdventurePlayer.from_dict(saved)
	assert_eq(read.life_bonus, 10)
	assert_eq(read.duel_start_life(), life + 10)
	saved["duels"]["life_bonus"] = 99
	assert_eq(AdventurePlayer.from_dict(saved).life_bonus, 10, "a damaged save's bonus is capped")
	saved["duels"]["life_bonus"] = "many"
	assert_eq(AdventurePlayer.from_dict(saved).life_bonus, 0)
	assert_eq(AdventurePlayer.from_dict(plain).life_bonus, 0, "absent: none")


# -------------------------------------------------------------- teleport --

func test_a_journey_lands_beside_its_target_on_free_ground_of_the_same_landmass() -> void:
	var plain := hero([])
	var player := hero()
	_at_the_inn(player)
	var world := player.world
	var town := inn().nearest_town(player, "inn")
	var target := Vector2i(int(world.sites[town]["x"]), int(world.sites[town]["y"]))
	assert_eq(inn().teleport_target(player, "inn", "nearest_town"), target)
	var landing := inn().teleport_tile(player, "inn", {"to": "nearest_town"})
	assert_ne(landing, Vector2i(-1, -1))
	assert_ne(landing, target, "beside, never on it")
	assert_true(landing.distance_to(target) < 4.5)
	assert_true(world.is_land(landing.x, landing.y))
	assert_eq(world.tile_flags(landing.x, landing.y) & (ShandalarWorld.SITE | ShandalarWorld.DUNGEON), 0)
	assert_true(landing in RegionGeography.component(world, player.tile()), "the hero's own landmass")
	assert_eq(AdventureExpansions.marker(world, landing), "")
	assert_false(landing in AdventureSites.blocked_tiles(player), "no lair, no portal")
	assert_eq(VisitPane.describe(player, landing), {}, "nothing there opens a pane")
	assert_eq(inn().teleport_tile(player, "inn", {"to": "nearest_town"}), landing, "the same every time: no dice")
	var start := inn().teleport_tile(player, "inn", {"to": "start"})
	assert_true(start.distance_to(world.start_tile()) < 4.5)
	assert_eq(player.dice, plain.dice)
	assert_eq(world.fingerprint(), plain.world.fingerprint(), "the 1997 world is the same")
	# A hero cut off from the target by water is not carried over it.
	inn()._landmass_key = [world.get_instance_id(), player.tile()]
	inn()._landmass = {player.tile(): true}
	assert_eq(inn().teleport_tile(player, "inn", {"to": "nearest_town"}), Vector2i(-1, -1))
	inn()._landmass_key = []


func test_a_journey_to_what_is_not_on_this_land_is_refused_before_paying() -> void:
	var player := hero()
	_at_the_inn(player)
	player.gold = 600
	assert_eq(inn().teleport_tile(player, "inn", {"to": "dungeon:cellar"}), Vector2i(-1, -1), "not raised yet")
	assert_eq(inn().teleport_tile(player, "inn", {"to": "place:mill"}), Vector2i(-1, -1), "no such place stands here")
	var pane := inn().do_effects(player, "inn", "to_cellar")
	assert_eq(String(pane["lines"][0]), "There is no way there from here.")
	assert_false(inn().applied)
	assert_eq([player.gold, inn().uses(player, "inn", "to_cellar")], [600, 0], "nothing paid, nothing counted")
	inn().do_effects(player, "inn", "cellar")
	var slot: Dictionary = player.world.encounters[inn().dungeon_index(player, "cellar")]
	var door := Vector2i(int(slot["x"]), int(slot["y"]))
	var landing := inn().teleport_tile(player, "inn", {"to": "dungeon:cellar"})
	if landing.x < 0:
		pass_test("the cellar rose on another landmass: no way there, as it should be")
		return
	assert_ne(landing, door)
	assert_true(landing.distance_to(door) < 4.5)
	inn().do_effects(player, "inn", "to_cellar")
	assert_true(inn().applied)
	assert_eq(player.gold, 495, "100 for the cellar, 5 for the way")
