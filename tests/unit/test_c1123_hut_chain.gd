extends GutTest
## THE OLD ADVENTURER'S FIVE DUNGEONS (the bundled hut 1.1.0, 2026-11-23;
## the owner: *"the old adventurer offers a new dungeon after you beat the
## current offered by him. They can be all around the map"*).
##
## The shipped plugin is copied into the test profile with stand-in
## pictures and played in the game's own model, on heroes of fixed seeds:
## pay, the dungeon is raised; empty it, the next is offered; five in all,
## 1000 gold each; then the old man has nothing left to sell. A save of the
## hut's 1.0.0 (one secret bought, the vault cleared) lands on the second
## offer.

const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const ROOT := "user://c1123_hut_chain_tests"
## The bundled places plugins: folder, id.
const PLACES := {"Old_Adventurers_Hut": "old_hut", "Conjuration_Wizard_Guild": "conjuration_guild",
	"Gamblers_Den": "gamblers_den", "Riddle_Stone": "riddle_stone",
	"Wandering_Collector": "wandering_collector", "Duelists_Ring": "duelists_ring"}
const HUT := "Old_Adventurers_Hut"
## The dungeons in the order they are sold: key, the action that sells it.
const CHAIN: Array[Array] = [
	["forgotten_vault", "secret"],
	["drowned_library", "secret2"],
	["sunken_forge", "secret3"],
	["hall_of_echoes", "secret4"],
	["planeswalkers_rest", "secret5"],
]


func before_each() -> void:
	_copy_plugin(HUT)
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


## Every file of bundled plugin [param folder] copied under [constant
## ROOT] (a study place keeps more files than the hut), each picture a
## small stand-in.
func _copy_whole(folder: String, from := "", to := "") -> void:
	if from == "":
		from = "res://expanded_adventure".path_join(folder)
		to = ROOT.path_join(folder)
	DirAccess.make_dir_recursive_absolute(to)
	var dir := DirAccess.open(from)
	for name in dir.get_directories():
		_copy_whole(folder, from.path_join(name), to.path_join(name))
	for name in dir.get_files():
		if name.get_extension() in ["import", "uid"]:
			continue
		if name.get_extension() in ["png", "jpg", "jpeg", "webp"]:
			var image := Image.create(48, 40, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			image.fill_rect(Rect2i(8, 6, 32, 30), Color(0.5, 0.4, 0.3))
			image.save_png(to.path_join(name)) if name.get_extension() == "png" else image.save_jpg(to.path_join(name))
			continue
		var file := FileAccess.open(to.path_join(name), FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(from.path_join(name)))
		file.close()


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	for name in dir.get_directories():
		_remove(path.path_join(name))
	DirAccess.remove_absolute(path)


func hero(seed_text := "48271", lands: Array[String] = ["old_hut"]) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = seed_text
	setup.adventures = lands
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player


func _point(player: AdventurePlayer, key: String) -> Vector2i:
	var point: Array = player.world.expansion.get(AdventureSites.KEY, {}).get(key, [])
	return Vector2i(int(point[0]), int(point[1])) if point.size() == 2 else Vector2i(-1, -1)


## The button of [param pane] whose id ends with [param tail], [] for none.
func _button(pane: Dictionary, tail: String) -> Array:
	for action: Array in pane.get("actions", []):
		if String(action[0]).ends_with(tail):
			return action
	return []


## The buttons of [param pane] that sell a secret: the ends of their ids.
func _offers(pane: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for action: Array in pane.get("actions", []):
		var id := String(action[0])
		if ":hut:secret" in id:
			out.append(id.get_slice(":hut:", 1))
	return out


## The shipped recipe of dungeon [param key].
func _recipe(key: String) -> Dictionary:
	return AdventureSites.provider("old_hut").dungeon(key)


## The hero has taken every card of the dungeon in [param slot]: cleared.
func _clear(player: AdventurePlayer, slot: int) -> void:
	var dungeon: Dictionary = player.world.encounters[slot]
	dungeon["cards"] = []
	dungeon[WorldClues.LEFT_CARDS] = []
	player.world.touch()


# ------------------------------------------------------------ the chain --

func test_the_old_man_sells_five_dungeons_one_after_another() -> void:
	var player := hero()
	var sites := AdventureSites.provider("old_hut")
	var hut := _point(player, "old_hut:hut")
	assert_true(hut.x >= 0, "the hut stands on the mainland")
	var dice := player.dice
	var slots := player.world.encounters.size()
	assert_eq(slots, WorldClues.SLOTS, "1997's fifteen")
	player.gold = 5400
	var first := AdventureExpansions.describe(player, hut)
	assert_string_contains(String(first["lines"][1]), "I was a planeswalker once", "his story, as ever")
	assert_eq(_offers(first), ["secret"] as Array[String], "one secret at a time")
	var doors: Array[Vector2i] = []
	var names: Array[String] = []
	for step in CHAIN.size():
		var key := String(CHAIN[step][0])
		var action := String(CHAIN[step][1])
		var recipe := _recipe(key)
		var name := String(recipe["name"])
		# The offer: this dungeon's button and no other, ready at 1000 gold.
		var offer := AdventureExpansions.describe(player, hut)
		assert_eq(String(offer["name"]), "Old Adventurer's Hut")
		assert_eq(_offers(offer), [action] as Array[String], "%s: the one offer" % key)
		var pay := _button(offer, ":hut:" + action)
		assert_eq(String(pay[1]), "Pay 1000 gold for the secret")
		assert_true(bool(pay[2]), "%s: ready" % key)
		if step > 0:
			var before := String(_recipe(String(CHAIN[step - 1][0]))["name"])
			assert_string_contains(String(offer["lines"][0]), "You came back from %s alive" % before, "he names the one just cleared")
			assert_string_contains(String(offer["lines"][2]), "For 1000 gold I will tell you where it lies.")
		assert_eq(sites.dungeon_state(player, key), "none")
		# Paid: 1000 gold, a new slot, the dungeon as the plugin wrote it.
		var gold := player.gold
		var told := sites.do_effects(player, "hut", action)
		assert_eq(gold - player.gold, 1000, "%s: its price" % key)
		assert_eq(player.world.encounters.size(), slots + step + 1, "%s: one new slot" % key)
		var index := sites.dungeon_index(player, key)
		assert_eq(index, slots + step, "%s: the slot after the last" % key)
		var dungeon: Dictionary = player.world.encounters[index]
		assert_eq(String(dungeon[WorldClues.RAISED]), "old_hut:" + key)
		assert_eq(WorldNames.dungeon_name(index, player.world), name)
		var cards: Array[String] = []
		for card in recipe["cards"]:
			cards.append(String(card))
		assert_eq(WorldClues.left_cards(dungeon), cards, "%s: its own treasure" % key)
		assert_eq(int(dungeon["clues"]), 7, "where, its creatures and its rules: all told")
		assert_eq(int(dungeon["monster_flags"]) & DungeonBoard.LARGE, DungeonBoard.LARGE)
		var door := Vector2i(int(dungeon["x"]), int(dungeon["y"]))
		assert_does_not_have(doors, door, "%s: a tile of its own" % key)
		assert_does_not_have(names, name, "%s: a name of its own" % key)
		assert_ne(door, hut)
		assert_ne(player.world.tile_flags(door.x, door.y) & ShandalarWorld.DUNGEON, 0)
		assert_eq(DungeonDoors.at(player.world, door), index, "%s: the hero can enter it" % key)
		assert_true(WorldClues.on_world(player.world).any(func(row: Dictionary) -> bool: return int(row["index"]) == index), "drawn on the map")
		var visit := VisitPane.describe(player, door)
		assert_eq([String(visit["kind"]), String(visit["name"])], ["dungeon", name])
		var far := door.distance_to(hut)
		assert_true(far >= float(recipe["distance"]["min"]) and far <= float(recipe["distance"]["max"]),
			"%s: within its distance %d to %d (%.1f)" % [key, int(recipe["distance"]["min"]), int(recipe["distance"]["max"]), far])
		assert_string_contains(" ".join(told["lines"]), name)
		assert_string_contains(String(told["lines"][1]), "The way to %s is marked on your map." % name)
		assert_true(player.journal.any(func(row: Variant) -> bool:
			return row is Dictionary and String(row.get("text", "")) == "Paid the old man in the woods 1000 gold for the way to %s." % name), "%s: in the journal" % key)
		# The dungeons before it stay where and what they were.
		for earlier in step:
			var slot: Dictionary = player.world.encounters[slots + earlier]
			assert_eq(Vector2i(int(slot["x"]), int(slot["y"])), doors[earlier])
			assert_eq(WorldNames.dungeon_name(slots + earlier, player.world), names[earlier])
			assert_eq(sites.dungeon_state(player, String(CHAIN[earlier][0])), "cleared")
		doors.append(door)
		names.append(name)
		# Open: he sends the hero on his way and sells nothing.
		assert_eq(sites.dungeon_state(player, key), "open")
		var waiting := AdventureExpansions.describe(player, hut)
		assert_eq(_offers(waiting), [] as Array[String], "%s open: nothing is sold" % key)
		assert_string_contains(String(waiting["lines"][0]), "You know the way to %s." % name)
		assert_false(_button(waiting, "_leave").is_empty(), "the hero can always walk away")
		gold = player.gold
		for other: Array in CHAIN:
			if sites.uses(player, "hut", String(other[1])) > 0:
				sites.do_effects(player, "hut", String(other[1]))
		assert_eq(player.gold, gold, "a secret already bought is never sold again")
		assert_eq(player.world.encounters.size(), slots + step + 1)
		# Cleared: the next offer (or, after the fifth, the end).
		_clear(player, index)
		assert_eq(sites.dungeon_state(player, key), "cleared")
	assert_eq(player.gold, 400, "5000 gold in all")
	assert_eq(player.dice, dice, "the adventure's dice untouched")
	assert_eq(doors.size(), 5)
	var last := AdventureExpansions.describe(player, hut)
	assert_eq(_offers(last), [] as Array[String], "nothing left to sell")
	assert_string_contains(String(last["lines"][0]), "So you have found them all")
	assert_eq(last["actions"].size(), 1, "only Leave")
	player.gold = 50000
	for link: Array in CHAIN:
		sites.do_effects(player, "hut", String(link[1]))
	assert_eq(player.gold, 50000, "no sixth secret, and none twice")
	assert_eq(player.world.encounters.size(), slots + 5)
	# The whole of it lives through a save.
	var read := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	for step in CHAIN.size():
		assert_eq(sites.dungeon_index(read, String(CHAIN[step][0])), slots + step)
		assert_eq(sites.dungeon_state(read, String(CHAIN[step][0])), "cleared")
		assert_eq(WorldNames.dungeon_name(slots + step, read.world), names[step])
	assert_string_contains(String(AdventureExpansions.describe(read, _point(read, "old_hut:hut"))["lines"][0]), "So you have found them all")


func test_the_shipped_distances_reach_farther_with_each_dungeon() -> void:
	var least := 0
	var most := 0
	for link: Array in CHAIN:
		var distance: Dictionary = _recipe(String(link[0]))["distance"]
		assert_gt(int(distance["min"]), least, "%s lies farther out than the one before" % link[0])
		assert_gt(int(distance["max"]), most)
		least = int(distance["min"])
		most = int(distance["max"])
	# A land's tiles lie in a square of some sixty: nothing is much farther
	# than 40 from a place, so no min may pass the schema's 40.
	assert_eq([least, most], [32, 64], "the last may lie anywhere on the land")
	assert_true(AdventurePlugins.valid("old_hut"), str(AdventurePlugins.row("old_hut").get("problems", [])))
	assert_eq(String(AdventurePlugins.row("old_hut").get("version", "")), "1.1.0")


func test_every_dungeon_finds_room_on_other_worlds_too() -> void:
	# Other seeds, other lands: wherever the hut stands, each of the five
	# can be raised, no nearer than its min, each on its own tile.
	for seed_text: String in ["7", "1997", "31337", "424242", "3", "99"]:
		var player := hero(seed_text)
		var sites := AdventureSites.provider("old_hut")
		var hut := _point(player, "old_hut:hut")
		assert_true(hut.x >= 0, "seed %s: the hut is placed" % seed_text)
		player.gold = 5000
		var doors: Array[Vector2i] = []
		for link: Array in CHAIN:
			var key := String(link[0])
			var pane := AdventureExpansions.describe(player, hut)
			var pay := _button(pane, ":hut:" + String(link[1]))
			assert_false(pay.is_empty(), "seed %s: %s is offered" % [seed_text, key])
			if pay.is_empty():
				break
			assert_true(bool(pay[2]), "seed %s: %s can be raised" % [seed_text, key])
			sites.do_effects(player, "hut", String(link[1]))
			var index := sites.dungeon_index(player, key)
			assert_true(index >= WorldClues.SLOTS, "seed %s: %s raised" % [seed_text, key])
			if index < 0:
				break
			var dungeon: Dictionary = player.world.encounters[index]
			var door := Vector2i(int(dungeon["x"]), int(dungeon["y"]))
			assert_does_not_have(doors, door)
			doors.append(door)
			var far := door.distance_to(hut)
			assert_true(far >= float(_recipe(key)["distance"]["min"]) and far <= float(_recipe(key)["distance"]["max"]),
				"seed %s: %s at %.1f, its distance %d to %d" % [seed_text, key, far, int(_recipe(key)["distance"]["min"]), int(_recipe(key)["distance"]["max"])])
			_clear(player, index)
		assert_eq(player.gold, 0, "seed %s: 5000 gold for the five" % seed_text)
		assert_string_contains(String(AdventureExpansions.describe(player, hut)["lines"][0]), "So you have found them all")


func test_a_secret_no_land_can_hold_is_not_offered_as_ready() -> void:
	# The button says what the press would do: with every dungeon slot of
	# the land taken the old man's secret cannot be raised, so its button is
	# not ready (it read ready, and the press then refused, before 0.70.9).
	var player := hero()
	var sites := AdventureSites.provider("old_hut")
	var hut := _point(player, "old_hut:hut")
	player.gold = 3000
	assert_true(bool(_button(AdventureExpansions.describe(player, hut), ":hut:secret")[2]), "room: ready")
	var slots := player.world.encounters.size()
	while player.world.encounters.size() < WorldClues.MOST_SLOTS:
		player.world.encounters.append({"x": 0, "y": 0, "cards": [], "clues": 0})
	var pay := _button(AdventureExpansions.describe(player, hut), ":hut:secret")
	assert_false(pay.is_empty(), "still shown")
	assert_false(bool(pay[2]), "no slot left: not ready")
	var refused := sites.do_effects(player, "hut", "secret")
	assert_eq(player.gold, 3000, "and the press pays nothing")
	assert_eq(String(refused["lines"][0]), "No place on this land can hold a new dungeon.")
	player.world.encounters.resize(slots)
	assert_true(bool(_button(AdventureExpansions.describe(player, hut), ":hut:secret")[2]), "room again: ready again")
	# A gold shortage still reads as ever.
	player.gold = 999
	assert_false(bool(_button(AdventureExpansions.describe(player, hut), ":hut:secret")[2]))
	assert_string_contains(String(sites.do_effects(player, "hut", "secret")["lines"][0]), "You need 1000 gold")


# ------------------------------------------------------------ old saves --

func test_a_save_with_only_the_first_vault_cleared_lands_on_the_second_offer() -> void:
	# What a campaign played with the hut's 1.0.0 saved: the one secret
	# bought, the vault raised and emptied, nothing known of the other four.
	var player := hero()
	var sites := AdventureSites.provider("old_hut")
	player.gold = 1000
	sites.do_effects(player, "hut", "secret")
	var vault := sites.dungeon_index(player, "forgotten_vault")
	assert_eq(vault, WorldClues.SLOTS)
	_clear(player, vault)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var kept: Dictionary = saved["sites"]["old_hut"]
	assert_eq((kept["dungeons"] as Dictionary).keys(), ["mainland:forgotten_vault"], "the 1.0.0 record: the vault alone")
	for key: String in (kept["uses"] as Dictionary).keys():
		assert_false("secret2" in key or "drowned" in key, "nothing of the later dungeons (%s)" % key)
	var read := AdventurePlayer.from_dict(saved)
	var hut := _point(read, "old_hut:hut")
	assert_eq(hut, _point(player, "old_hut:hut"), "the hut where it stood")
	assert_eq(sites.dungeon_state(read, "forgotten_vault"), "cleared")
	read.gold = 999
	var pane := AdventureExpansions.describe(read, hut)
	assert_eq(_offers(pane), ["secret2"] as Array[String], "the second offer")
	assert_string_contains(String(pane["lines"][0]), "You came back from The Forgotten Vault alive")
	assert_string_contains(String(pane["lines"][1]), "There was a library once")
	assert_false(bool(_button(pane, ":hut:secret2")[2]), "999 gold is not enough")
	read.gold = 1000
	sites.do_effects(read, "hut", "secret2")
	assert_eq(read.gold, 0)
	var library := sites.dungeon_index(read, "drowned_library")
	assert_eq(library, WorldClues.SLOTS + 1, "raised beside the cleared vault")
	assert_eq(WorldNames.dungeon_name(library, read.world), "The Drowned Library")
	assert_eq(WorldNames.dungeon_name(vault, read.world), "The Forgotten Vault", "the vault keeps its name")
	assert_string_contains(String(AdventureExpansions.describe(read, hut)["lines"][0]), "You know the way to The Drowned Library.")


func test_a_save_with_the_first_vault_still_open_waits_for_it() -> void:
	var player := hero()
	var sites := AdventureSites.provider("old_hut")
	player.gold = 3000
	sites.do_effects(player, "hut", "secret")
	var read := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	var hut := _point(read, "old_hut:hut")
	var pane := AdventureExpansions.describe(read, hut)
	assert_eq(_offers(pane), [] as Array[String], "the vault first")
	assert_string_contains(String(pane["lines"][0]), "You know the way to The Forgotten Vault.")
	assert_eq(read.gold, 2000)
	# A raised dungeon moves when the hero leaves it: the hut still knows it.
	var vault := sites.dungeon_index(read, "forgotten_vault")
	DungeonDoors.move(read, vault)
	assert_eq(sites.dungeon_state(read, "forgotten_vault"), "open")
	assert_eq(_offers(AdventureExpansions.describe(read, hut)), [] as Array[String])
	_clear(read, vault)
	assert_eq(_offers(AdventureExpansions.describe(read, hut)), ["secret2"] as Array[String])


# --------------------------------------------- never on another landmark --

## The land tiles the hero can walk to from [param from]: a flood over
## land, written here anew (not [method RegionGeography.component]).
func _reachable(world: ShandalarWorld, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := at + step
			if next.x < 0 or next.y < 0 or next.x >= ShandalarWorld.TILES or next.y >= ShandalarWorld.TILES:
				continue
			if not seen.has(next) and world.terrain(next.x, next.y) != ShandalarWorld.OCEAN:
				seen[next] = true
				todo.append(next)
	return seen


## EVERY LANDMARK OF [param player]'s LAND, read from the world's own
## records (never from the helpers the placing uses): `{tile: what}`, the
## dungeon in slot [param but] left out.
func _landmarks(player: AdventurePlayer, but: int) -> Dictionary:
	var world := player.world
	var out := {}
	for slot in world.sites.size():
		var site: Dictionary = world.sites[slot]
		var kind := int(site["type"])
		if kind > 0:
			out[Vector2i(int(site["x"]), int(site["y"]))] = ["", "village", "town", "city", "castle"][mini(kind, 4)]
	for index in world.encounters.size():
		if index != but:
			var slot: Dictionary = world.encounters[index]
			out[Vector2i(int(slot["x"]), int(slot["y"]))] = "castle" if index < 5 else "dungeon"
	for key: String in world.expansion.get(AdventureSites.KEY, {}):
		var point: Array = world.expansion[AdventureSites.KEY][key]
		out[Vector2i(int(point[0]), int(point[1]))] = "place"
	for point: Variant in (world.expansion.get("entries", {}) as Dictionary).values():
		out[Vector2i(int(point[0]), int(point[1]))] = "anchorage"
	for creature: Dictionary in player.monsters:
		if String(creature.get("kind", "")) == "lair":
			out[Vector2i(int(creature["x"]) / 32, int(creature["y"]) / 32)] = "lair"
	if not player.portal.is_empty():
		out[Vector2i(int(player.portal["x"]), int(player.portal["y"]))] = "portal"
	out[player.tile()] = "hero"
	return out


func test_a_raised_dungeon_never_stands_on_or_beside_another_landmark() -> void:
	# Every bundled places plugin on at once, and a land with an anchorage;
	# a lair or Arzakon's portal put on the very tile each dungeon would
	# have taken. Each of the five then stands on free, reachable land, 4 or
	# more (1997's distance) from every town, city, castle and dungeon, and
	# beside nothing else.
	for folder: String in PLACES:
		if folder != HUT:
			_copy_whole(folder)
	AdventurePlugins.scan()
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()))
	var lands: Array[String] = [BEACON.ID]
	for id: String in PLACES.values():
		assert_true(AdventurePlugins.valid(id), "%s: %s" % [id, str(AdventurePlugins.row(id).get("problems", []))])
		lands.append(id)
	var seeds: Array[String] = ["48271", "7", "1997", "31337", "424242", "3", "99", "8675309", "20261123", "1"]
	var dodged := 0
	for seed_text in seeds:
		var player := hero(seed_text, lands)
		var world := player.world
		var sites := AdventureSites.provider("old_hut")
		var hut := _point(player, "old_hut:hut")
		var placed: Dictionary = world.expansion.get(AdventureSites.KEY, {})
		assert_eq(placed.size(), 6, "seed %s: all six places stand (%s)" % [seed_text, str(placed.keys())])
		assert_false((world.expansion.get("entries", {}) as Dictionary).is_empty(), "seed %s: the land has an anchorage" % seed_text)
		var reach := _reachable(world, hut)
		var doors: Array[Vector2i] = []
		player.gold = 5000
		for step in CHAIN.size():
			var key := String(CHAIN[step][0])
			# What would be drawn is taken first by a landmark with no flag
			# on the page: the portal for the first dungeon, a lair after.
			var would := sites._dungeon_tile(player, key, "hut")
			assert_true(would.x >= 0, "seed %s: %s has a tile" % [seed_text, key])
			if step == 0:
				player.portal = {"x": would.x, "y": would.y, "state": FinalBattle.PORTAL_OPEN}
			else:
				player.monsters.append({"slot": 20 + step, "kind": "lair", "x": would.x * 32 + 16, "y": would.y * 32 + 16, "color": 1})
			sites.do_effects(player, "hut", String(CHAIN[step][1]))
			var index := sites.dungeon_index(player, key)
			assert_eq(index, WorldClues.SLOTS + step, "seed %s: %s raised" % [seed_text, key])
			if index < 0:
				break
			var dungeon: Dictionary = world.encounters[index]
			var door := Vector2i(int(dungeon["x"]), int(dungeon["y"]))
			var said := "seed %s: %s at %s" % [seed_text, key, door]
			assert_ne(door, would, said + " dodged the %s" % ("portal" if step == 0 else "lair"))
			dodged += 1
			# On nothing: every landmark the world records.
			var marks := _landmarks(player, index)
			assert_false(marks.has(door), said + " stands on a %s" % str(marks.get(door, "")))
			assert_does_not_have(doors, door, said + " is its own tile")
			# Land the hero can walk to from the hut.
			assert_ne(world.terrain(door.x, door.y), ShandalarWorld.OCEAN, said + " is land")
			assert_true(reach.has(door), said + " can be walked to from the hut")
			# The page: a dungeon's bit and no site's or road's.
			var flags := world.tile_flags(door.x, door.y)
			assert_eq(flags & (ShandalarWorld.SITE | ShandalarWorld.ROAD | ShandalarWorld.DUNGEON), ShandalarWorld.DUNGEON, said + ": the dungeon's bit alone")
			var flagged := 0
			for other in world.encounters.size():
				if int(world.encounters[other]["x"]) == door.x and int(world.encounters[other]["y"]) == door.y:
					flagged += 1
			assert_eq(flagged, 1, said + ": one slot on the tile")
			# Its pane is the dungeon's, nothing standing before it.
			assert_eq(String(VisitPane.describe(player, door).get("kind", "")), "dungeon", said)
			# Its air.
			for at: Vector2i in marks:
				var what := String(marks[at])
				if what == "hero":
					continue
				if what in ["town", "city", "castle", "dungeon"]:
					assert_true(WorldGenerator.distance(at.x - door.x, at.y - door.y) >= 4, said + ": 4 or more from the %s at %s" % [what, at])
				else:
					assert_true(absi(at.x - door.x) > 1 or absi(at.y - door.y) > 1, said + ": not beside the %s at %s" % [what, at])
			var far := door.distance_to(hut)
			assert_true(far >= float(_recipe(key)["distance"]["min"]) and far <= float(_recipe(key)["distance"]["max"]), said + ": within its distance (%.1f)" % far)
			doors.append(door)
			_clear(player, index)
		assert_eq(doors.size(), 5, "seed %s: all five" % seed_text)
		assert_eq(player.gold, 0, "seed %s" % seed_text)
	assert_eq(dodged, seeds.size() * 5)


func test_a_dungeon_takes_a_crowded_tile_only_when_no_other_is_left() -> void:
	# The air is kept where it can be: with every airy tile of the vault's
	# ring taken away (a lair on each), it still rises — on a tile of its
	# distance, on no landmark, though beside one.
	var player := hero()
	var sites := AdventureSites.provider("old_hut")
	var hut := _point(player, "old_hut:hut")
	var first := sites._dungeon_tile(player, "forgotten_vault", "hut")
	var air := sites._dungeon_air(player, DungeonDoors.kept_points(player.world))
	assert_true(DataSites._airy(first, air), "airy while it can be")
	var slot := 100
	for tile in RegionGeography.component(player.world, hut):
		var far := tile.distance_to(hut)
		if far >= 8.0 and far <= 22.0 and DataSites._airy(tile, air):
			player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16, "color": 1})
			slot += 1
	var crowded := sites._dungeon_tile(player, "forgotten_vault", "hut")
	assert_true(crowded.x >= 0, "still a tile")
	assert_false(_landmarks(player, -1).has(crowded), "on no landmark")
	var far := crowded.distance_to(hut)
	assert_true(far >= 8.0 and far <= 22.0, "within its distance still (%.1f)" % far)
	assert_eq(player.world.tile_flags(crowded.x, crowded.y) & (ShandalarWorld.SITE | ShandalarWorld.ROAD | ShandalarWorld.DUNGEON), 0)
