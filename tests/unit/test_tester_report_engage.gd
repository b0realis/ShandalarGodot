extends GutTest
## GOING FOR A CREATURE (0.60.18; the owner, 2026-11-05: *"Can we actively
## engage the creature if clicking with the mouse in it or walking
## straight into it?"*): within [constant WorldCreatures.BUMP] of the hero a
## creature is met when the hero walks toward it or goes for it ([method
## WorldCreatures.bumps]) — 1997's contact needed the two all but on top of
## each other. The world's own creature test's world: one land, the hero in
## its middle ([test_c19_A1_creatures]).

const HERO := Vector2i(20, 20)
const WHITE := 6
const CLERIC := 8
## World ways (ShandalarWorld.DX/DY): 3 is +x, 7 is −x.
const EAST := 3
const WEST := 7


func _player(way := AdventurePlayer.CREATURES_NOTICE) -> AdventurePlayer:
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
	player.creatures = way
	player.position = HERO * 32 + Vector2i(16, 16)
	player.monster_timer = 1000
	player.dice = 4242
	return player


## A cleric [param offset] from the hero in slot 0, every other slot a lair
## far to the west.
func _cleric(player: AdventurePlayer, offset: Vector2i) -> Dictionary:
	var at := player.position + offset
	var creature := {"slot": 0, "kind": "creature", "creature": CLERIC, "x": at.x, "y": at.y,
		"color": 5, "heading": 0, "frame": 0}
	player.monsters.append(creature)
	for slot in range(1, WorldLairs.SLOTS):
		var tile := HERO + Vector2i(-4, -3 + slot)
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 5})
	return creature


func _walking(player: AdventurePlayer, facing: int) -> void:
	player.facing = facing
	player.step = 1


func test_walking_into_it_meets_it() -> void:
	var player := _player()
	var cleric := _cleric(player, Vector2i(20, 0))
	_walking(player, EAST)
	assert_true(WorldCreatures.bumps(player, 0, Vector2i(int(cleric["x"]), int(cleric["y"]))))
	assert_eq(int(WorldCreatures.tick(player)["met"]), 0, "met, though 1997's contact is not reached")


func test_standing_by_or_walking_away_does_not() -> void:
	var player := _player()
	var at := player.position + Vector2i(20, 0)
	assert_false(WorldCreatures.bumps(player, 0, at), "the hero stands")
	_walking(player, WEST)
	assert_false(WorldCreatures.bumps(player, 0, at), "walking away")
	_walking(player, 1)
	assert_false(WorldCreatures.bumps(player, 0, at), "walking past it, at right angles")
	_walking(player, EAST)
	assert_false(WorldCreatures.bumps(player, 0, player.position + Vector2i(WorldCreatures.BUMP, 0)),
		"further than three quarters of a tile")


func test_the_creature_gone_for_is_met_however_the_hero_stands() -> void:
	var player := _player()
	_cleric(player, Vector2i(0, 20))
	assert_eq(int(WorldCreatures.tick(player, -1)["met"]), -1,
		"by a hero standing still, not yet")
	assert_eq(int(WorldCreatures.tick(player, 0)["met"]), 0, "gone for: met")


func test_the_sword_is_its_own_pointer() -> void:
	var sword := WorldCursors.image(WorldCursors.Kind.CREATURE)
	assert_eq(sword.get_size(), Vector2i(WorldCursors.SIZE, WorldCursors.SIZE))
	assert_gt(sword.get_pixelv(Vector2i(WorldCursors.hotspot(WorldCursors.Kind.CREATURE)) + Vector2i(1, 1)).a, 0.0,
		"its point is where it points")
	assert_ne(sword.get_data(), WorldCursors.image(WorldCursors.Kind.WALK).get_data())
