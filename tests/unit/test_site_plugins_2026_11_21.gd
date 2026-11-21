extends GutTest
## SITES PLUGINS (adventure plugin API 2, 2026-11-21; the owner: *"Is it
## possible to add a new type of town or interaction place as a plugin?"*,
## then: *"this separate plugin can be placed on other islands or on
## mainland if used"*, the dungeon *"separate from the main quest and hold
## from the list of plugin creator"*, and the two places — *"An old
## adventurers hut"*: 1000 gold for a dungeon nobody knows of; the
## *"conjuration wizard guild"*: a copy of a card for 2000, 4000, 8000 and
## 12000 gold, *"and after that they do not offer the service any more"*).
##
## The two shipped plugins are copied into the test profile with stand-in
## pictures (the loader reads bytes; a picture's look is not tested here),
## and played on a hero of a fixed seed.

const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const ROOT := "user://site_plugin_tests"
const HUT := "Old_Adventurers_Hut"
const GUILD := "Conjuration_Wizard_Guild"
const SCREEN := """extends Node
var player: AdventurePlayer
var _visit_tile := Vector2i.ZERO
var opened: Array = []
func autosave() -> String:
	return ""
func _after_leaving() -> void:
	pass
func _sync_rest() -> void:
	pass
func open_place(place: Dictionary) -> Control:
	opened.append(place)
	return null
"""


func before_each() -> void:
	_copy_plugin(HUT)
	_copy_plugin(GUILD)
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()


func after_each() -> void:
	AdventureExpansions.clear_development()
	_remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()


## [param folder] of res://expanded_adventure copied under [constant ROOT],
## each picture a small stand-in of the same name.
func _copy_plugin(folder: String) -> void:
	var from := "res://expanded_adventure".path_join(folder)
	var to := ROOT.path_join(folder)
	DirAccess.make_dir_recursive_absolute(to.path_join("art"))
	for rel in ["plugin.json", "sites.json", "text.json", "README.txt", "LICENSE.txt"]:
		var file := FileAccess.open(to.path_join(rel), FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(from.path_join(rel)))
		file.close()
	var sites: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(from.path_join("sites.json")))
	var pictures: Array = (sites.get("pictures", {}) as Dictionary).values()
	for site: Dictionary in (sites["sites"] as Dictionary).values():
		pictures.append(String(site["sprite"]["file"]))
	for rel: String in pictures:
		var image := Image.create(48, 40, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		image.fill_rect(Rect2i(8, 6, 32, 30), Color(0.5, 0.4, 0.3))
		image.save_png(to.path_join(rel))


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	for name in dir.get_directories():
		_remove(path.path_join(name))
	DirAccess.remove_absolute(path)


func hero(lands: Array[String]) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.adventures = lands
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player


func _screen(player: AdventurePlayer) -> Node:
	var script := GDScript.new()
	script.source_code = SCREEN
	script.reload()
	var screen: Node = script.new()
	screen.set(&"player", player)
	return autofree(screen)


func _point(player: AdventurePlayer, key: String) -> Vector2i:
	var point: Array = player.world.expansion.get(AdventureSites.KEY, {}).get(key, [])
	return Vector2i(int(point[0]), int(point[1])) if point.size() == 2 else Vector2i(-1, -1)


## The button of [param pane] whose id ends with [param tail], [] for none.
func _button(pane: Dictionary, tail: String) -> Array:
	for action: Array in pane.get("actions", []):
		if String(action[0]).ends_with(tail):
			return action
	return []


func _count(player: AdventurePlayer, card: String) -> int:
	return player.cards.filter(func(row: Dictionary) -> bool: return String(row["card"]) == card).size()


# ------------------------------------------------------------ loading --

func test_both_plugins_are_valid_sites_plugins() -> void:
	for id in ["old_hut", "conjuration_guild"]:
		assert_true(AdventurePlugins.valid(id), "%s: %s" % [id, AdventurePlugins.refusal(id)])
		assert_eq(AdventurePlugins.kind(id), AdventurePlugins.KIND_SITES)
		assert_true(AdventureSites.known(id))
		assert_false(AdventureExpansions.known(id), "a sites plugin is no land")
		assert_false(AdventureExpansions.definitions().has(id))
	assert_eq(AdventurePlugins.site_ids(), ["conjuration_guild", "old_hut"] as Array[String], "found in folder order")
	assert_eq(AdventurePlugins.land_ids(), [] as Array[String])


func test_the_manifest_rules_of_the_sites_kind() -> void:
	var base := {"plugin_format": 1, "api_version": 2, "kind": "sites", "id": "a_place", "name": "A Place",
		"version": "1.0.0", "authors": ["Someone"], "description": "A place."}
	assert_eq(AdventurePlugins.manifest_problems(base), [] as Array[String], "a sites plugin needs no region")
	var old := base.duplicate()
	old["api_version"] = 1
	assert_has(AdventurePlugins.manifest_problems(old), "plugin.json: a sites plugin needs api_version 2 or newer.")
	var with_region := base.duplicate()
	with_region["region"] = {"title": "Somewhere"}
	assert_has(AdventurePlugins.manifest_problems(with_region), "plugin.json: a sites plugin has no region; its places are described in sites.json.")
	var odd := base.duplicate()
	odd["kind"] = "castle"
	odd["region"] = {"title": "Somewhere"}
	assert_has(AdventurePlugins.manifest_problems(odd), "plugin.json: kind must be one of island, sites.")
	var island := base.duplicate()
	island.erase("kind")
	assert_has(AdventurePlugins.manifest_problems(island), "plugin.json: the field \"region\" is missing.", "an island still needs its region")
	var newer := base.duplicate()
	newer["api_version"] = 3
	assert_has(AdventurePlugins.manifest_problems(newer), "This plugin needs plugin API 3; this game reads API 2. A newer game is needed.")


func test_content_problems_are_named() -> void:
	var sites: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join(HUT).path_join("sites.json")))
	var hut: Dictionary = sites["sites"]["hut"]
	hut["panes"][2]["actions"][0]["effects"].append({"spawn_dungeon": "no_such_vault"})
	hut["panes"][0]["when"] = [{"used_up": "leave"}]
	sites["dungeons"]["forgotten_vault"]["cards"] = ["No Such Card Anywhere"]
	var file := FileAccess.open(ROOT.path_join(HUT).path_join("sites.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(sites))
	file.close()
	AdventurePlugins.scan()
	var problems: Array = AdventurePlugins.row("old_hut")["problems"]
	assert_false(AdventurePlugins.valid("old_hut"))
	assert_has(problems, "sites.json: sites.hut.panes[2].actions[0].effects[3].spawn_dungeon: no dungeon no_such_vault in sites.json dungeons.")
	assert_has(problems, "sites.json: sites.hut.panes[0].when[0].used_up: the action leave has no prices, so it is never used up.")
	assert_has(problems, "sites.json.dungeons.forgotten_vault.cards[0]: No Such Card Anywhere is not a card of the base game or of a required pack (none).")


# ------------------------------------------------------------ placing --

func test_vanilla_worlds_are_untouched_and_places_are_fixed() -> void:
	var plain := hero([])
	assert_false(plain.world.expansion.has(AdventureSites.KEY), "no sites plugin ticked: nothing written")
	var with_sites := hero(["old_hut", "conjuration_guild"] as Array[String])
	assert_eq(with_sites.world.fingerprint(), plain.world.fingerprint(), "the 1997 world is the same")
	assert_eq(with_sites.dice, plain.dice, "the adventure's dice are not touched")
	assert_eq(with_sites.world.rand_state, plain.world.rand_state)
	var hut := _point(with_sites, "old_hut:hut")
	var tower := _point(with_sites, "conjuration_guild:tower")
	assert_true(hut.x >= 0 and tower.x >= 0, "both placed on the mainland")
	var again := hero(["old_hut", "conjuration_guild"] as Array[String])
	assert_eq(_point(again, "old_hut:hut"), hut, "the same campaign seed, the same tile")
	for tile in [hut, tower]:
		assert_true(with_sites.world.is_land(tile.x, tile.y))
		assert_eq(with_sites.world.tile_flags(tile.x, tile.y) & (ShandalarWorld.SITE | ShandalarWorld.ROAD | ShandalarWorld.DUNGEON), 0)
		assert_ne(AdventureExpansions.marker(with_sites.world, tile), "")
		for site in with_sites.world.sites:
			if int(site["type"]) > 0:
				assert_true(tile.distance_to(Vector2i(int(site["x"]), int(site["y"]))) >= 3.0, "kept from the towns")
	assert_eq(AdventureExpansions.marker(with_sites.world, hut), "old_hut:hut")
	assert_eq(AdventureExpansions.map_op("old_hut:hut").size(), 3, "its sprite is drawn")
	assert_eq(AdventureExpansions.mainland_note(with_sites), "", "a sites plugin never has a ship to explain")


func test_the_guild_stands_on_an_island_too_and_the_hut_does_not() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()))
	var player := hero([BEACON.ID, "old_hut", "conjuration_guild"] as Array[String])
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	AdventureExpansions.entered(player)
	assert_eq(AdventureRegions.id(player.world), BEACON.ID)
	assert_true(_point(player, "conjuration_guild:tower").x >= 0, "the guild's tower on the island")
	assert_eq(_point(player, "old_hut:hut"), Vector2i(-1, -1), "the hut is the mainland's alone")
	var tower := _point(player, "conjuration_guild:tower")
	var pane := AdventureExpansions.describe(player, tower)
	assert_eq(String(pane["kind"]), "site")
	assert_eq(String(pane["name"]), "Conjuration Wizard Guild")


# --------------------------------------------------------------- the hut --

func test_the_hut_sells_its_secret_once_and_raises_the_vault() -> void:
	var player := hero(["old_hut"] as Array[String])
	var hut := _point(player, "old_hut:hut")
	var dice := player.dice
	var slots := player.world.encounters.size()
	player.gold = 900
	var pane := AdventureExpansions.describe(player, hut)
	assert_eq(String(pane["name"]), "Old Adventurer's Hut")
	assert_string_contains(String(pane["lines"][1]), "I was a planeswalker once")
	var pay := _button(pane, ":hut:secret")
	assert_eq(String(pay[1]), "Pay 1000 gold for the secret")
	assert_false(bool(pay[2]), "900 gold is not enough")
	var sites := AdventureSites.provider("old_hut")
	var refused := sites.do_effects(player, "hut", "secret")
	assert_eq(player.gold, 900, "nothing paid")
	assert_string_contains(String(refused["lines"][0]), "You need 1000 gold")
	player.gold = 1500
	assert_true(bool(_button(AdventureExpansions.describe(player, hut), ":hut:secret")[2]))
	var told := sites.do_effects(player, "hut", "secret")
	assert_eq(player.gold, 500)
	assert_eq(player.world.encounters.size(), slots + 1, "a new dungeon slot")
	var index := slots
	var vault: Dictionary = player.world.encounters[index]
	assert_eq(index, 15, "after the 1997 fifteen")
	assert_eq(WorldClues.left_cards(vault), ["Old Man of the Sea", "Planar Gate", "Mirror Universe"] as Array[String])
	assert_eq(int(vault["clues"]), 7, "where, its creatures and its rules: all told")
	assert_eq(int(vault["monster_flags"]) & DungeonBoard.LARGE, DungeonBoard.LARGE)
	assert_eq(WorldNames.dungeon_name(index, player.world), "The Forgotten Vault")
	var door := Vector2i(int(vault["x"]), int(vault["y"]))
	assert_ne(player.world.tile_flags(door.x, door.y) & ShandalarWorld.DUNGEON, 0)
	assert_eq(DungeonDoors.at(player.world, door), index, "the hero can enter it")
	assert_true(WorldClues.on_world(player.world).any(func(row: Dictionary) -> bool: return int(row["index"]) == index), "drawn on the map")
	var distance := door.distance_to(hut)
	assert_true(distance >= 8.0 and distance <= 22.0, "within the plugin's distance (%.1f)" % distance)
	assert_eq(player.dice, dice, "the adventure's dice untouched")
	assert_string_contains(" ".join(told["lines"]), "The Forgotten Vault")
	assert_true(player.journal.any(func(row: Variant) -> bool: return row is Dictionary and "The Forgotten Vault" in String(row.get("text", ""))))
	pane = AdventureExpansions.describe(player, hut)
	assert_eq(_button(pane, ":hut:secret"), [], "sold once")
	assert_string_contains(String(pane["lines"][0]), "You know the way to The Forgotten Vault")
	var visit := VisitPane.describe(player, door)
	assert_eq(String(visit["kind"]), "dungeon")
	assert_eq(String(visit["name"]), "The Forgotten Vault")
	vault[WorldClues.LEFT_CARDS] = []
	pane = AdventureExpansions.describe(player, hut)
	assert_string_contains(String(pane["lines"][0]), "So you found my old treasures")


# ------------------------------------------------------------- the guild --

func test_the_guild_copies_four_times_at_rising_prices_and_then_never() -> void:
	var player := hero(["conjuration_guild"] as Array[String])
	var tower := _point(player, "conjuration_guild:tower")
	var sites := AdventureSites.provider("conjuration_guild")
	var card := String(player.cards[0]["card"])
	player.gold = 1999
	var copy := _button(AdventureExpansions.describe(player, tower), ":tower:copy")
	assert_eq(String(copy[1]), "Copy a card (2000 gold, 4 left)")
	assert_false(bool(copy[2]))
	player.gold = 26500
	var before := _count(player, card)
	var paid: Array[int] = []
	for i in 4:
		var gold := player.gold
		var done := sites.copy_card(player, "tower", "copy", card)
		paid.append(gold - player.gold)
		assert_string_contains(String(done["lines"][0]), "A copy of %s is yours" % card)
	assert_eq(paid, [2000, 4000, 8000, 12000] as Array[int])
	assert_eq(player.gold, 500)
	assert_eq(_count(player, card), before + 4)
	var pane := AdventureExpansions.describe(player, tower)
	assert_eq(_button(pane, ":tower:copy"), [], "no more copies")
	assert_string_contains(" ".join(pane["lines"]), "the guild's law allows no more")
	player.gold = 50000
	sites.copy_card(player, "tower", "copy", card)
	assert_eq(player.gold, 50000, "a fifth is never sold")


func test_a_copy_needs_a_card_the_hero_holds() -> void:
	var player := hero(["conjuration_guild"] as Array[String])
	player.gold = 5000
	var sites := AdventureSites.provider("conjuration_guild")
	sites.copy_card(player, "tower", "copy", "Black Lotus")
	assert_eq(player.gold, 5000, "nothing paid for a card not carried")
	assert_eq(_count(player, "Black Lotus"), 0)


func test_the_buttons_go_through_the_screen() -> void:
	var player := hero(["old_hut"] as Array[String])
	player.gold = 1000
	var screen := _screen(player)
	var pane := AdventureExpansions.describe(player, _point(player, "old_hut:hut"))
	var pay := String(_button(pane, ":hut:secret")[0])
	assert_true(AdventureExpansions.is_action(pay))
	assert_true(AdventureExpansions.act(screen, pay, pane))
	assert_eq(player.gold, 0)
	var opened: Array = screen.get(&"opened")
	assert_eq(opened.size(), 1, "the pane after the secret")
	assert_true(AdventureExpansions.act(screen, String(_button(opened[0], "_back:hut")[0]), opened[0]))
	assert_eq(opened.size(), 2, "and the hut again")


# --------------------------------------------------------------- saves --

func test_the_progress_and_the_vault_are_saved() -> void:
	var player := hero(["old_hut", "conjuration_guild"] as Array[String])
	player.gold = 30000
	AdventureSites.provider("old_hut").do_effects(player, "hut", "secret")
	var card := String(player.cards[0]["card"])
	AdventureSites.provider("conjuration_guild").copy_card(player, "tower", "copy", card)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	assert_eq(int(saved["version"]), 9)
	var rows: Array = saved["hero"]["adventures"]
	assert_true(rows.all(func(row: Dictionary) -> bool: return String(row.get("kind", "")) == "sites"), "each row knows its kind")
	var read := AdventurePlayer.from_dict(saved)
	assert_eq(read.sites, player.sites)
	assert_eq(_point(read, "old_hut:hut"), _point(player, "old_hut:hut"))
	assert_eq(WorldClues.left_cards(read.world.encounters[15]), ["Old Man of the Sea", "Planar Gate", "Mirror Universe"] as Array[String])
	assert_eq(WorldNames.dungeon_name(15, read.world), "The Forgotten Vault")
	assert_eq(AdventureSites.provider("conjuration_guild").uses(read, "tower", "copy"), 1)
	assert_eq(JSON.stringify(read.to_dict(), "\t"), JSON.stringify(AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(read.to_dict()))).to_dict(), "\t"),
		"saved, read and saved again, the same")


func test_a_missing_sites_plugin_hides_its_places_but_keeps_its_dungeon() -> void:
	var player := hero(["old_hut"] as Array[String])
	player.gold = 1000
	AdventureSites.provider("old_hut").do_effects(player, "hut", "secret")
	var hut := _point(player, "old_hut:hut")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	_remove(ROOT.path_join(HUT))
	AdventurePlugins.scan()
	var read := AdventurePlayer.from_dict(saved)
	assert_not_null(read, "the save opens")
	AdventureExpansions.initialize(read)
	assert_eq(AdventureExpansions.marker(read.world, hut), "", "the hut hides")
	assert_eq(_point(read, "old_hut:hut"), hut, "its tile is kept")
	var vault: Dictionary = read.world.encounters[15]
	assert_eq(DungeonDoors.at(read.world, Vector2i(int(vault["x"]), int(vault["y"]))), 15, "the vault is an ordinary dungeon now")
	assert_eq(AdventureExpansions.mainland_note(read), "", "no ship to explain for a missing sites plugin")
	assert_true(read.sites.has("old_hut"), "its progress is kept")


func test_an_older_save_reads_no_sites() -> void:
	var player := hero([])
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	saved["version"] = 8
	saved.erase("sites")
	var read := AdventurePlayer.from_dict(saved)
	assert_not_null(read)
	assert_eq(read.sites, {})
