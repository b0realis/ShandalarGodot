extends GutTest
## THE CREATURES' WAY (builder A1 of 0.50.65; the owner's ruling of
## 2026-10-29: "Creatures": Hunt, as 1997 shipped it / Notice, the
## default): [WorldCreatures] under Notice switches on 1997's designed,
## never used range and speed (unused-features §6–§7; world_lair_monster_
## slots.c 361–375, 636–714, 770–780) — a creature out of its range wanders
## its own lands at an amble, one in it hurries at the hero, slowed on the
## lands its flags name; the nearest keeps its whole range, the others
## half; the besieger and the quest's creature hunt as under Hunt; Hunt is
## the walk it always was. And the measure: meetings a minute of walking
## in a seeded world, Hunt against Notice.

const HERO := Vector2i(20, 20)
const WHITE := 6
const MIXED_BLACK_BLUE := 8   # magic mask 0x06
const BLUE := 1
## Rows.
const CLERIC := 8            # a male wizard: 32 → 48
const UNDEAD_KNIGHT := 2     # a knight with 0x200: 48 → 72 → 144
const TROLL_SHAMAN := 31     # a troll: 96 → 144
const SEA_DRAGON := 18       # a wyrm with 0x200: 96 → 144 → 288
const MANDURANG := 50        # a dragon with 0x200: 64 → 96 → 192
const NECROMANCER := 6       # a henchman: [ours] the archmages' 48 → 72
const MERFOLK_SHAMAN := 16   # slowed on black land
const ARCH_ANGEL := 12       # fast: a stride of 2


## A world of one land, the hero standing in its middle, every respawn
## long past ([test_b_w4_world_creatures]' world).
func _player(way: String, terrain := WHITE, difficulty := 1, timer := 1000) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = terrain
	for i in 7:
		world.lair_respawn.append(-1000000)
	var player := AdventurePlayer.new()
	player.world = world
	player.difficulty = difficulty
	player.creatures = way
	player.position = HERO * 32 + Vector2i(16, 16)
	player.monster_timer = timer
	player.dice = 4242
	return player


func _creature(player: AdventurePlayer, slot: int, row: int, offset: Vector2i, color := 5) -> Dictionary:
	var at := player.position + offset
	var creature := {"slot": slot, "kind": "creature", "creature": row, "x": at.x, "y": at.y,
		"color": color, "heading": 0, "frame": 0}
	player.monsters.append(creature)
	return creature


## Every roaming slot not in [param busy] a lair four tiles west.
func _park(player: AdventurePlayer, busy: Array) -> void:
	for slot in WorldLairs.SLOTS:
		if slot in busy:
			continue
		var tile := HERO + Vector2i(-4, -3 + slot)
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 5})


func _at(held: Dictionary) -> Vector2i:
	return Vector2i(int(held["x"]), int(held["y"]))


# ------------------------------------------------------------ the range --

func test_the_ranges_are_1997s() -> void:
	assert_eq(CreatureBook.range_of(CLERIC), 48, "a wizard: 32 × 3 / 2, a tile and a half")
	assert_eq(CreatureBook.range_of(UNDEAD_KNIGHT), 144, "a knight 48 × 3 / 2, doubled by 0x200")
	assert_eq(CreatureBook.range_of(TROLL_SHAMAN), 144, "a troll: 96 × 3 / 2, four and a half tiles")
	assert_eq(CreatureBook.range_of(SEA_DRAGON), 288, "a wide wyrm")
	assert_eq(CreatureBook.range_of(MANDURANG), 192, "a wide dragon")
	assert_eq(CreatureBook.range_of(NECROMANCER), 72, "[ours] a henchman as an archmage")
	assert_eq(CreatureBook.range_of(ARCH_ANGEL), 72, "an archmage")
	assert_eq(CreatureBook.range_of(0), -1, "the lair")
	# [ours] Read in world units: on 1997's distance (about twice a
	# straight one) twice the number.
	assert_eq(WorldCreatures.notice_range(CLERIC, true), 96, "the nearest: whole, 48 world units")
	assert_eq(WorldCreatures.notice_range(CLERIC, false), 48, "the others: half")
	assert_eq(WorldGenerator.distance(48, 0), WorldCreatures.notice_range(CLERIC, true),
		"a tile and a half straight across")
	assert_eq(WorldGenerator.distance(144, 0), WorldCreatures.notice_range(TROLL_SHAMAN, true),
		"four and a half tiles for a troll")


func test_the_nearest_is_the_nearest_live_creature() -> void:
	var player := _player(AdventurePlayer.CREATURES_NOTICE)
	player.monsters.append({"slot": 0, "kind": "lair", "x": player.position.x + 20, "y": player.position.y,
		"color": 5})
	_creature(player, 1, CLERIC, Vector2i(90, 0))
	_creature(player, 2, CLERIC, Vector2i(60, 0))
	_creature(player, 3, CLERIC, Vector2i(0, 60))
	assert_eq(WorldCreatures.nearest_slot(player), 2, "no lair; the first of equals")
	assert_eq(WorldCreatures.nearest_slot(_player(AdventurePlayer.CREATURES_NOTICE)), -1, "none")


func test_out_of_range_it_wanders_in_range_it_hunts() -> void:
	var player := _player(AdventurePlayer.CREATURES_NOTICE)
	var cleric := _creature(player, 1, CLERIC, Vector2i(49, 0))
	assert_eq(WorldCreatures.goes(player, 1, cleric, 97, 1), WorldCreatures.WANDERS, "just out of range")
	assert_eq(WorldCreatures.goes(player, 1, cleric, 96, 1), WorldCreatures.HUNTS, "at its range")
	assert_eq(WorldCreatures.goes(player, 1, cleric, 60, 2), WorldCreatures.WANDERS, "not the nearest: half")
	assert_eq(WorldCreatures.goes(player, 1, cleric, 48, 2), WorldCreatures.HUNTS)
	player.creatures = AdventurePlayer.CREATURES_HUNT
	assert_eq(WorldCreatures.goes(player, 1, cleric, 900, 1), WorldCreatures.HUNTS, "Hunt: from anywhere")


func test_the_besieger_the_quests_creature_and_one_that_flees() -> void:
	var player := _player(AdventurePlayer.CREATURES_NOTICE)
	var besieger := _creature(player, WorldCreatures.SIEGE_SLOT, CLERIC, Vector2i(200, 0))
	assert_eq(WorldCreatures.goes(player, WorldCreatures.SIEGE_SLOT, besieger, 200), WorldCreatures.HUNTS,
		"the besieger keeps its way")
	assert_eq(WorldCreatures.speed_of(player, WorldCreatures.SIEGE_SLOT, besieger, WorldCreatures.HUNTS),
		WorldCreatures.HURRY)
	var wanted := _creature(player, 0, TROLL_SHAMAN, Vector2i(400, 0))
	player.quest = {"type": -TROLL_SHAMAN, "destination": 3}
	assert_eq(WorldCreatures.goes(player, 0, wanted, 400), WorldCreatures.HUNTS, "the quest's creature hunts")
	var beaten := _creature(player, 2, CLERIC, Vector2i(30, 0))
	assert_eq(WorldCreatures.goes(player, 2, beaten, 60), WorldCreatures.WANDERS, "control: out of its 48")
	for i in player.difficulty + 3:
		player.log_victory(CLERIC, 5)
	assert_eq(WorldCreatures.goes(player, 2, beaten, 60), WorldCreatures.HUNTS,
		"one that flees runs within 64, whatever its range")
	assert_eq(WorldCreatures.aim_of(player, 2, beaten, 60, WorldCreatures.HUNTS),
		-(player.position - _at(beaten)), "away from the hero")


func test_a_wanderer_aims_its_own_way() -> void:
	var player := _player(AdventurePlayer.CREATURES_NOTICE)
	var cleric := _creature(player, 1, CLERIC, Vector2i(100, 0))
	cleric["wander"] = 1
	assert_eq(WorldCreatures.aim_of(player, 1, cleric, 100, WorldCreatures.WANDERS),
		Vector2i(0, -WorldCreatures.WANDER_AIM), "north, its way, not west at the hero")


# ------------------------------------------------------------- the pace --

func test_the_pace_hurry_and_amble() -> void:
	assert_eq(WorldCreatures.pace(CLERIC, WorldCreatures.HURRY, 10, 1), 1, "hurrying: its stride")
	assert_eq(WorldCreatures.pace(ARCH_ANGEL, WorldCreatures.HURRY, 10, 1), 2, "a fast one's 2")
	assert_eq(WorldCreatures.pace(ARCH_ANGEL, WorldCreatures.AMBLE, 11, 1), 1, "a fast one ambles a unit a tick")
	var steps: Array[int] = []
	for now in range(8, 16):
		steps.append(WorldCreatures.pace(CLERIC, WorldCreatures.AMBLE, now, 1))
	assert_eq(steps, [0, 1, 0, 1, 0, 1, 0, 1] as Array[int], "a stride-1 amble: every other tick")
	for now in range(0, 64):
		if (now + 1) & 3 == 0:
			assert_eq(WorldCreatures.pace(CLERIC, WorldCreatures.AMBLE, now, 1), 1, "its turning ticks are steps")


func test_slowed_on_the_lands_its_flags_name() -> void:
	assert_true(CreatureBook.slowed_on(MERFOLK_SHAMAN, 0x02), "the Merfolk Shaman on black land")
	assert_true(CreatureBook.slowed_on(MERFOLK_SHAMAN, 0x06), "a black and blue land too")
	assert_false(CreatureBook.slowed_on(MERFOLK_SHAMAN, 0x04), "not on blue")
	assert_true(CreatureBook.slowed_on(37, 0x08), "the Sedge Beast on green")
	assert_true(CreatureBook.slowed_on(42, 0x10), "the Centaur Warchief on red")
	assert_false(CreatureBook.slowed_on(31, 0x20), "the Troll Shaman's 0x100 is no land's")
	assert_false(CreatureBook.slowed_on(CLERIC, 0x3E), "no flags, never")


## The units creature [param held] went in [param ticks] ticks, the hero
## standing.
func _units_walked(player: AdventurePlayer, held: Dictionary, ticks: int) -> int:
	var walked := 0
	for i in ticks:
		var was := _at(held)
		WorldCreatures.tick(player)
		walked += maxi(absi(_at(held).x - was.x), absi(_at(held).y - was.y))
		player.monster_timer += 1
	return walked


func test_a_hurrying_merfolk_shaman_wades_black_swamps() -> void:
	# Under Hunt a unit a tick on any land.
	var hunt := _player(AdventurePlayer.CREATURES_HUNT, MIXED_BLACK_BLUE)
	_park(hunt, [1])
	var a := _creature(hunt, 1, MERFOLK_SHAMAN, Vector2i(100, 0), 2)
	a["heading"] = 7   # already going west, at the hero
	assert_eq(_units_walked(hunt, a, 8), 8, "Hunt: 8 units in 8 ticks")
	# Under Notice, in range (144) on black and blue land: an amble.
	var slow := _player(AdventurePlayer.CREATURES_NOTICE, MIXED_BLACK_BLUE)
	_park(slow, [1])
	var b := _creature(slow, 1, MERFOLK_SHAMAN, Vector2i(100, 0), 2)
	b["heading"] = 7
	assert_eq(_units_walked(slow, b, 8), 4, "Notice, black land: 4 units in 8 ticks")
	assert_lt(_at(b).x, slow.position.x + 100, "and towards the hero")
	# On blue land it hurries.
	var quick := _player(AdventurePlayer.CREATURES_NOTICE, BLUE)
	_park(quick, [1])
	var c := _creature(quick, 1, MERFOLK_SHAMAN, Vector2i(100, 0), 2)
	c["heading"] = 7
	assert_eq(_units_walked(quick, c, 8), 8, "Notice, blue land: 8 units in 8 ticks")


func test_a_far_creature_comes_under_hunt_and_ambles_under_notice() -> void:
	# Three tiles east of a standing hero, out of a Cleric's 48 units: Hunt closes
	# in at a unit a tick; Notice wanders at an amble — 30 units at most in
	# 60 ticks, whichever way, so never into its range.
	var after := {}
	for way in AdventurePlayer.CREATURE_WAYS:
		var player := _player(way)
		_park(player, [1])
		var cleric := _creature(player, 1, CLERIC, Vector2i(96, 0))
		for tick in 60:
			WorldCreatures.tick(player)
			player.monster_timer += 1
		after[way] = WorldGenerator.distance(_at(cleric).x - player.position.x, _at(cleric).y - player.position.y)
	assert_lt(int(after[AdventurePlayer.CREATURES_HUNT]), 96, "Hunt: closing in")
	assert_gte(int(after[AdventurePlayer.CREATURES_NOTICE]), WorldGenerator.distance(66, 0),
		"Notice: still far, wandering")


func test_hunt_draws_no_dice_notice_does_not_change_hunt() -> void:
	# The same world walked twice under Hunt: identical, and the Notice code
	# left it alone (no dice, no field written).
	var runs: Array = []
	for i in 2:
		var player := _player(AdventurePlayer.CREATURES_HUNT)
		_creature(player, 1, CLERIC, Vector2i(96, 40))
		_creature(player, 2, TROLL_SHAMAN, Vector2i(-80, 60), 4)
		for tick in 200:
			WorldCreatures.tick(player)
			player.monster_timer += 1
		runs.append([player.dice, JSON.stringify(player.monsters)])
	assert_eq(runs[0], runs[1])
	assert_false(String(runs[0][1]).contains("wander"), "no wanderer's way under Hunt")


# ------------------------------------------------------------ the measure --

## A SEEDED WORLD WALKED HEADLESS for [param ticks] ticks under [param way]
## at [param difficulty]: the hero walks from place to place on land (never
## a town's tile, so no place opens), fed, no sieges; a creature met is
## dueled (the crowd cleared, the slot spent), a lair explored. `{meetings,
## lairs, minutes}`.
static func walk_world(seed_text: String, difficulty: int, way: String, ticks: int) -> Dictionary:
	var setup := AdventureSetup.new()
	setup.player_name = "Measured Walker"
	setup.seed_text = seed_text
	setup.difficulty = difficulty
	setup.walker = "male"
	setup.creatures = way
	setup.sieges = AdventurePlayer.SIEGES_NONE
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.food = 1000000
	var walk := HeroWalk.new(player)
	walk.settle()
	var aims := RandomNumberGenerator.new()
	aims.seed = 97
	var meetings := 0
	var lairs := 0
	for tick in ticks:
		if not walk.is_walking():
			for attempt in 50:
				var here := player.tile()
				var to := here + Vector2i(aims.randi_range(-10, 10), aims.randi_range(-10, 10))
				if to.x < 1 or to.y < 1 or to.x > 62 or to.y > 62 or not player.world.is_land(to.x, to.y) \
						or not player.world.site_at(to.x, to.y).is_empty() or to == here:
					continue
				if walk.walk_to(to):
					break
		walk.step()
		walk.take_news()
		var slots := WorldCreatures.tick(player)
		var met := int(slots.get("met", -1))
		if met >= 0:
			if String(slots["kind"]) == "lair":
				lairs += 1
				WorldLairs.explored(player, met)
			else:
				meetings += 1
				WorldCreatures.clear_crowd(player, met)
				WorldCreatures.met(player, met, WorldCreatures.WON)
		walk.end_tick()
	return {"meetings": meetings, "lairs": lairs, "minutes": ticks * HeroWalk.TICK / 60.0}


func test_notice_meets_fewer_creatures_than_hunt() -> void:
	# Five minutes of walking at Apprentice in a seeded world.
	var hunt := walk_world("31337", 0, AdventurePlayer.CREATURES_HUNT, 5000)
	var notice := walk_world("31337", 0, AdventurePlayer.CREATURES_NOTICE, 5000)
	gut.p("Apprentice, 5 min: Hunt %d meetings (%d lairs), Notice %d (%d lairs)" % [hunt["meetings"],
		hunt["lairs"], notice["meetings"], notice["lairs"]])
	assert_gt(int(hunt["meetings"]), 0, "control: creatures are met under Hunt")
	assert_lt(int(notice["meetings"]), int(hunt["meetings"]), "fewer under Notice")
