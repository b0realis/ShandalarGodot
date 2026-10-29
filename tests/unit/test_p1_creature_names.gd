extends GutTest
## THE CREATURES' NAMES ON THE MAP — the rule (the polish pass,
## 2026-10-28; the owner's ruling of 2026-10-28 on the unused 1997
## features: *"only §5, the creature names on the map — small, with their
## own on/off setting in the adventure's options menu"*). 1997's drawing
## copied a creature's name in eight ticks of every 32, slot by slot —
## `((T >> 3) & 3) == (slot & 3)` — and for the three DISGUISE creatures
## the name of the row their disguise shows, a row lower every 32 ticks
## (adventureWorldUi.c 2276–2284; docs/adventure-unused-1997-features.md
## §5); nothing drew it. [method WorldCreatures.map_name] is that copy.

const HERO := Vector2i(20, 20)
const WHITE := 6
const CLERIC := 8
const CONJURER := 17
const NECROMANCER := 6
const SHAPESHIFTER := 19
const SUMMONER := 27


func _player(timer := 0) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = WHITE
	for i in 7:
		world.lair_respawn.append(-1000000)
	var player := AdventurePlayer.new()
	player.world = world
	player.difficulty = 1
	player.position = HERO * 32 + Vector2i(16, 16)
	player.monster_timer = timer
	return player


func _creature(player: AdventurePlayer, slot: int, row: int, offset: Vector2i) -> Dictionary:
	var at := player.position + offset
	var creature := {"slot": slot, "kind": "creature", "creature": row, "x": at.x, "y": at.y,
		"color": 5, "heading": 0, "frame": 0}
	player.monsters.append(creature)
	return creature


func test_a_name_shows_in_its_slot_s_eight_ticks_of_32() -> void:
	for timer in 64:
		for slot in 8:
			var due := ((timer >> 3) & 3) == (slot & 3)
			assert_eq(WorldCreatures.map_name(CLERIC, slot, timer), "Cleric" if due else "",
				"slot %d at tick %d" % [slot, timer])
	assert_eq(WorldCreatures.map_name(CLERIC, 4, 3), "Cleric", "slot 4 shares slot 0's ticks (slot & 3)")
	assert_eq(WorldCreatures.map_name(CLERIC, 1, 3), "", "not slot 1's")


func test_the_disguised_creatures_cycle_false_names() -> void:
	var cycles := {NECROMANCER: ["Necromancer", "Nether Fiend", "VampireLord", "Warlock"],
		SHAPESHIFTER: ["Shapeshifter", "Sea Dragon", "Conjurer", "Merfolk Shaman"],
		SUMMONER: ["Summoner", "Beastmaster", "Forest Dragon", "Enchantress"]}
	for row in cycles:
		var said: Array[String] = []
		for turn in 5:
			said.append(WorldCreatures.map_name(row, 0, turn * 32))
		var expected: Array[String] = []
		expected.assign(cycles[row])
		expected.append(cycles[row][0])
		assert_eq(said, expected, "%s: a row lower every 32 ticks, round again" % cycles[row][0])
	assert_eq(WorldCreatures.map_name(CLERIC, 0, 96), "Cleric", "no disguise: always itself")


func test_the_names_are_those_of_the_creatures_seen() -> void:
	var player := _player(0)
	_creature(player, 0, CLERIC, Vector2i(64, 0))
	_creature(player, 4, NECROMANCER, Vector2i(0, 64))
	_creature(player, 1, CLERIC, Vector2i(96, 0))
	_creature(player, 2, CLERIC, Vector2i(6 * 32, 0))
	assert_eq(WorldCreatures.map_names(player), {0: "Cleric", 4: "Necromancer"},
		"tick 0: slots 0 and 4, both seen")
	player.monster_timer = 8
	assert_eq(WorldCreatures.map_names(player), {1: "Cleric"}, "tick 8: slot 1")
	player.monster_timer = 16
	assert_eq(WorldCreatures.map_names(player), {}, "tick 16: slot 2 stands six tiles off, unseen")
	player.monster_timer = 32
	assert_eq(WorldCreatures.map_names(player), {0: "Cleric", 4: "Nether Fiend"},
		"the next round: the Necromancer disguised")


func test_a_lurker_out_of_sight_is_not_named() -> void:
	var player := _player(0)
	var lurker := _creature(player, 0, CONJURER, Vector2i(64, 0))
	assert_eq(WorldCreatures.map_names(player), {}, "a Conjurer two tiles east lurks unseen")
	lurker["x"] = player.position.x + 40
	assert_eq(WorldCreatures.map_names(player), {0: "Conjurer"}, "near, seen and named")
	assert_eq(WorldCreatures.map_names(null), {})
