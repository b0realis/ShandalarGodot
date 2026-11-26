extends GutTest
## 0.70.11 campaign, smooth2 #1: a place that raises a dungeon asks only
## WHETHER there is room for it when its pane is described ([method
## DataSites._dungeon_room]) — the same answer as the whole search ([method
## DataSites._dungeon_tile]) in every state, and never an old one.

const CHAIN := ["secret", "secret2", "secret3", "secret4", "secret5"]


func before_all() -> void:
	CardRegistry.ensure_loaded()
	AdventurePlugins.folders_override = ["res://expanded_adventure"] as Array[String]
	AdventurePlugins.scan()


func after_all() -> void:
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()


func _hero(seed_text := "12345") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = seed_text
	setup.adventures = ["old_hut"] as Array[String]
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player


func _hut(player: AdventurePlayer) -> Vector2i:
	var point: Array = player.world.expansion.get(AdventureSites.KEY, {}).get("old_hut:hut", [])
	return Vector2i(int(point[0]), int(point[1])) if point.size() == 2 else Vector2i(-1, -1)


func _keys(sites: DataSites) -> Array:
	return (sites.file().get("dungeons", {}) as Dictionary).keys()


func _same(player: AdventurePlayer, sites: DataSites, why: String) -> void:
	for key: String in _keys(sites):
		assert_eq(sites._dungeon_room(player, key, "hut"), sites._dungeon_tile(player, key, "hut").x >= 0,
			"%s: %s" % [why, key])


func test_room_is_the_search_s_answer_in_every_state() -> void:
	for seed_text in ["12345", "48271", "7"]:
		var player := _hero(seed_text)
		var sites := AdventureSites.provider("old_hut")
		assert_gt(_keys(sites).size(), 0, "the hut's dungeons")
		_same(player, sites, "new land " + seed_text)
		player.gold = 9000
		for action: String in CHAIN:
			var pane := AdventureExpansions.describe(player, _hut(player))
			if not (pane.get("actions", []) as Array).any(func(row: Array) -> bool: return String(row[0]).ends_with(":hut:" + action)):
				break
			sites.do_effects(player, "hut", action)
			_same(player, sites, "after %s on %s" % [action, seed_text])
			# The dungeon cleared, so the next is offered.
			var last: Dictionary = player.world.encounters[-1]
			last["cards"] = []
			last[WorldClues.LEFT_CARDS] = []
			player.world.touch()
			_same(player, sites, "cleared %s on %s" % [action, seed_text])
		player.position = Vector2i(_hut(player) * 32) + Vector2i(16 + 32 * 7, 16)
		_same(player, sites, "the hero moved")


func test_no_room_on_a_land_too_small_is_said_at_once() -> void:
	var player := _hero()
	var sites := AdventureSites.provider("old_hut")
	var key := String(_keys(sites)[0])
	# The hero far out at sea, no place given: no land to raise it on.
	player.position = Vector2i(16, 16)
	if not player.world.is_land(0, 0):
		assert_false(sites._dungeon_room(player, key))
		assert_eq(sites._dungeon_tile(player, key).x, -1)
	else:
		pass_test("the corner is land on this seed")


func test_describing_the_hut_with_the_gold_is_quick() -> void:
	var player := _hero()
	var sites := AdventureSites.provider("old_hut")
	var hut := _hut(player)
	player.gold = 20000
	var key := String(_keys(sites)[0])
	var pane := AdventureExpansions.describe(player, hut)
	var ready := (pane["actions"] as Array).filter(func(row: Array) -> bool: return ":hut:secret" in String(row[0]))
	assert_eq(ready.size(), 1)
	assert_true(bool(ready[0][2]), "the offer is ready")
	var t := Time.get_ticks_usec()
	for n in 20:
		sites._dungeon_tile(player, key, "hut")
	var search := (Time.get_ticks_usec() - t) / 20000.0
	t = Time.get_ticks_usec()
	for n in 20:
		sites._dungeon_room(player, key, "hut")
	var room := (Time.get_ticks_usec() - t) / 20000.0
	t = Time.get_ticks_usec()
	for n in 20:
		AdventureExpansions.describe(player, hut)
	var described := (Time.get_ticks_usec() - t) / 20000.0
	print("C1126 adv hut: whole search %.2f ms, room %.3f ms, describe %.2f ms" % [search, room, described])
	assert_lt(room * 4.0, search, "the room question is a fraction of the search")
