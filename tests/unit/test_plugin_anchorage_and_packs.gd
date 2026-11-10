extends GutTest
## ADVENTURE PLUGINS — two plugins at one anchorage, and a required pack
## installed but older than a plugin asks (the review of 2026-11-10,
## RV2-3, RV2-4).

const REFUGE := "res://expanded_adventure/Fallen_Empires_Refuge_prototype"
const ROOT := "user://p2_plugin_anchorage"

var _pack_before: bool


func before_each() -> void:
	_pack_before = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)


func after_each() -> void:
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()
	_remove(ROOT)
	CardPacks.set_enabled(FallenEmpiresPack.ID, _pack_before)


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for name in dir.get_files(): dir.remove(name)
	for name in dir.get_directories(): _remove(path.path_join(name))
	DirAccess.remove_absolute(path)


## [param from] copied to [param to], each JSON file named in [param edits]
## changed by its callable first.
func _copy(from: String, to: String, edits := {}) -> void:
	var dir := DirAccess.open(from)
	DirAccess.make_dir_recursive_absolute(to)
	for name in dir.get_files():
		var bytes := FileAccess.get_file_as_bytes(from.path_join(name))
		if edits.has(name):
			var parsed: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
			(edits[name] as Callable).call(parsed)
			bytes = JSON.stringify(parsed, "\t").to_utf8_buffer()
		var file := FileAccess.open(to.path_join(name), FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	for name in dir.get_directories():
		_copy(from.path_join(name), to.path_join(name), edits)


func _hero(lands: Array[String]) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures = lands
	setup.packs = ["pack-2"] as Array[String]
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": String(CardPacks.info("pack-2").get("version", "1"))})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(hero)
	return hero


## A second land: the prototype under another id, its pictures renamed.
func _second() -> void:
	_copy(REFUGE, ROOT.path_join("Second"), {
		"plugin.json": func(manifest: Dictionary) -> void:
			manifest["id"] = "second_isle"
			manifest["name"] = "Second Isle"
			manifest["region"]["title"] = "Second Isle"
			manifest["region"]["salt"] = 99,
		"places.json": func(places: Dictionary) -> void:
			places["pictures"] = {"second_isle_harbor": "art/refuge_harbor.png", "second_isle_castle": "art/refuge_castle.png"}
			places["markers"]["port"]["picture"] = "second_isle_harbor"
			places["markers"]["castle"]["picture"] = "second_isle_castle"})


func test_each_plugin_at_a_shared_anchorage_answers_for_its_own_ship() -> void:
	_copy(REFUGE, ROOT.path_join("Refuge"))
	_second()
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()
	assert_true(AdventurePlugins.valid("refuge"), AdventurePlugins.refusal("refuge"))
	assert_true(AdventurePlugins.valid("second_isle"), AdventurePlugins.refusal("second_isle"))
	var hero := _hero(["refuge", "second_isle"] as Array[String])
	var entries: Dictionary = hero.world.expansion["entries"]
	assert_true(entries.has("refuge") and entries.has("second_isle"))
	# The coast ran out: both ships at one anchorage.
	entries["second_isle"] = (entries["refuge"] as Array).duplicate()
	AdventureExpansions.initialize(hero)
	var point: Array = entries["refuge"]
	var tile := Vector2i(point[0], point[1])
	assert_eq(AdventureExpansions.describe(hero, tile).get("name"), "Coastal Anchorage", "one anchorage, two voyages")
	for id in ["refuge", "second_isle"]:
		var land := AdventureExpansions.provider(id) as DataRegion
		assert_eq(land.marker(hero.world, tile), "port", "%s's ship is there" % id)
		var pane := land.describe(hero, tile)
		assert_eq(String(pane.get("expansion", "")), id, "%s's own harbor pane" % id)


func test_a_pack_older_than_the_plugin_asks_is_named_as_such() -> void:
	_copy(REFUGE, ROOT.path_join("Refuge"), {"plugin.json": func(manifest: Dictionary) -> void:
		manifest["requires"]["card_packs"][0]["min_version"] = "99.0"})
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()
	assert_true(AdventurePlugins.valid("refuge"), AdventurePlugins.refusal("refuge"))
	var old := AdventureExpansions.pack_too_old("refuge")
	assert_false(old.is_empty(), "Pack 2 is older than 99.0")
	var land := AdventureExpansions.provider("refuge") as DataRegion
	var hero := _hero(["refuge"] as Array[String])
	var problem := land.deck_problem(hero)
	assert_eq(problem, "The plugin The Last Refuge (Fallen Empires prototype) needs %s 99.0 or newer (installed %s)." % [String(old["title"]), String(old["version"])])
	assert_false(problem.contains("Enable"), "never to enable a pack that is enabled")
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_eq(land.deck_problem(hero), land.say("deck.no_pack"), "a pack switched off is asked for as before")
