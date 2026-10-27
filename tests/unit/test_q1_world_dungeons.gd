extends GutTest
## THE DUNGEONS DRAWN ON THE WORLD (the quick world package, 2026-10-27,
## step 2 — item A): [method WorldClues.on_world] is 1997's test of
## `DrawWorldTileRange` (adventureWorldUi.c 1230–1257) — the DUNGEON flag,
## a slot there, ANY clue, a card left — dungeons only, slots 5–14; and
## [method WorldView.dungeon_frames] its marker pairs
## (`g_dungeon_marker_sprite_lookup`, adventureWorldUi.c 57–83) in the six
## location sheets read as one.

var player: AdventurePlayer
var world: ShandalarWorld


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	world = AdventureSetup.make_world(record)
	player = AdventurePlayer.begin(record, world)


func _slot(index: int) -> Dictionary:
	return world.encounters[index]


func test_nothing_is_drawn_at_the_start() -> void:
	assert_eq(world.encounters.size(), 15, "control: the fifteen slots")
	assert_true(WorldClues.on_world(world).is_empty(), "no clue, no dungeon on the world")
	assert_true(WorldClues.on_world(null).is_empty(), "no world, none")


func test_any_clue_draws_the_dungeon_at_its_tile() -> void:
	for clue in [WorldClues.LOCATION, WorldClues.CREATURES, WorldClues.RULES, 6]:
		_slot(7)["clues"] = clue
		var drawn := WorldClues.on_world(world)
		assert_eq(drawn.size(), 1, "clue %d: one dungeon" % clue)
		assert_eq([int(drawn[0]["index"]), int(drawn[0]["x"]), int(drawn[0]["y"])],
			[7, int(_slot(7)["x"]), int(_slot(7)["y"])], "clue %d: slot 7 at its tile" % clue)
	_slot(12)["clues"] = WorldClues.RULES
	var both := WorldClues.on_world(world)
	assert_eq(both.size(), 2, "two known, two drawn")
	assert_eq([int(both[0]["index"]), int(both[1]["index"])], [7, 12], "in slot order")


func test_no_card_left_no_dungeon_but_any_card_keeps_it() -> void:
	_slot(7)["clues"] = WorldClues.CREATURES
	var cards: Array = _slot(7)["cards"]
	assert_gt(cards.size(), 0, "control: every dungeon starts with a card (28 in 30 places)")
	# 1997's slip A-s1: the first place empty, a card left in another.
	var last: int = cards[cards.size() - 1]
	_slot(7)["cards"] = [last] as Array[int]
	assert_eq(WorldClues.on_world(world).size(), 1, "one card left anywhere keeps it drawn")
	_slot(7)["cards"] = [] as Array[int]
	assert_true(WorldClues.on_world(world).is_empty(), "no card left: not drawn")


func test_castles_are_never_drawn() -> void:
	for castle in 5:
		_slot(castle)["clues"] = 7
	assert_true(WorldClues.on_world(world).is_empty(), "a castle's clues draw no dungeon")
	# The generator's stray flag: the tile first drawn for each castle keeps
	# DUNGEON, with no slot on it.
	var slots := {}
	for index in world.encounters.size():
		slots[Vector2i(int(_slot(index)["x"]), int(_slot(index)["y"]))] = index
	var strays := 0
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			if world.tile_flags(x, y) & ShandalarWorld.DUNGEON != 0 and not slots.has(Vector2i(x, y)):
				strays += 1
	assert_gt(strays, 0, "control: the castles' stray flags are on the map")
	for index in range(5, 15):
		_slot(index)["clues"] = 7
	var drawn := WorldClues.on_world(world)
	assert_eq(drawn.size(), 10, "every dungeon known, ten drawn — no stray tile among them")
	for one in drawn:
		assert_true(int(one["index"]) >= 5, "only dungeons")


func test_a_dungeon_off_its_flag_is_not_drawn() -> void:
	_slot(9)["clues"] = WorldClues.LOCATION
	var x := int(_slot(9)["x"])
	var y := int(_slot(9)["y"])
	var at := y * ShandalarWorld.PAGE_WIDTH + x
	world.page[at] = world.page[at] & ~ShandalarWorld.DUNGEON
	assert_true(WorldClues.on_world(world).is_empty(), "1997's first test: the tile's flag")


func test_the_marker_pairs_are_1997_s() -> void:
	assert_eq(WorldView.dungeon_frames(5), [["world_locatn03", 4], ["world_locatn03", 10]])
	assert_eq(WorldView.dungeon_frames(6), [["world_locatn04", 0], ["world_locatn04", 4]])
	assert_eq(WorldView.dungeon_frames(7), [["world_locatn03", 16], ["world_locatn03", 22]])
	assert_eq(WorldView.dungeon_frames(11), [["world_locatn05", 2], ["world_locatn05", 8]])
	assert_eq(WorldView.dungeon_frames(14), [["world_locatn03", 17], ["world_locatn03", 23]])
	assert_eq(WorldView.dungeon_frames(4), [], "a castle has none")
	assert_eq(WorldView.dungeon_frames(15), [], "nor a slot past the dungeons")
	assert_eq(WorldView.DUNGEON_LOOKS.size(), 20, "1997's first twenty, two for each dungeon")
