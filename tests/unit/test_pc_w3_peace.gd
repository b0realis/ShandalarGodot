extends GutTest
## PART C, W3 — THE WORLD AT PEACE after Arzakon's fall ([method
## AdventurePlayer.at_peace]; the owner's words, 2026-10-27: creatures *"do
## not hunt you always, some do not or are passive and do not cocer towns"*):
## no siege begins or falls ([Sieges]); the creatures and lairs of every
## colour come back ([WorldCreatures], where 1997's refill sends a beaten
## wizard's colours away — all five, every one); each creature a temper
## drawn as it is made — it hunts, wanders or stands — and saved with it;
## the quest's creature always hunts; and before the win all is as 1997.

const HERO := Vector2i(20, 20)
const WHITE := 6
## The Cleric: white, tier 4.
const CLERIC := 8


## A world of white plains, the hero in its middle, every slot's respawn
## long past; all five wizards beaten, and — [param won] — Arzakon too.
func _player(won := true) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = WHITE
	for i in 8:
		world.lair_respawn.append(-1000000)
	world.sites.append({"x": 30, "y": 30, "type": ShandalarWorld.TOWN, "trade": 0, "status": TownStatus.LINKED})
	var player := AdventurePlayer.new()
	player.world = world
	player.difficulty = 1
	player.position = HERO * 32 + Vector2i(16, 16)
	player.monster_timer = 1000
	player.dice = 4242
	for hue in AdventurePlayer.COLORS:
		player.defeated_wizards.append(hue)
	if won:
		player.ended = AdventurePlayer.ENDED_WON
	return player


func _creature(player: AdventurePlayer, slot: int, offset: Vector2i, temper: String) -> Dictionary:
	var at := player.position + offset
	var creature := {"slot": slot, "kind": "creature", "creature": CLERIC, "x": at.x, "y": at.y,
		"color": 5, "heading": 0, "frame": 0, "temper": temper}
	player.monsters.append(creature)
	return creature


## Every roaming slot not in [param busy] held by a lair four tiles west.
func _park(player: AdventurePlayer, busy: Array) -> void:
	for slot in WorldLairs.SLOTS:
		if slot in busy:
			continue
		var tile := HERO + Vector2i(-4, -3 + slot)
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 5})


func _at(held: Dictionary) -> Vector2i:
	return Vector2i(int(held["x"]), int(held["y"]))


func _ticks(player: AdventurePlayer, count: int) -> Array:
	var met := []
	for i in count:
		var out := WorldCreatures.tick(player)
		if int(out["met"]) >= 0:
			met.append(out["met"])
		player.monster_timer += 1
	return met


# ------------------------------------------------------------ the sieges --

func test_no_siege_in_a_world_at_peace() -> void:
	var player := _player()
	assert_true(player.at_peace())
	player.world.sites.append({"x": 10, "y": 10, "type": ShandalarWorld.CASTLE, "trade": 0, "status": 0})
	player.defeated_wizards.erase("black")
	player.world.page[10 * ShandalarWorld.PAGE_WIDTH + 10] = 3
	player.siege_timer = 64
	var dice := player.dice
	assert_eq(Sieges.on_step(player), [] as Array[Dictionary], "the clock's turn: nothing")
	assert_eq(Sieges.start(player), [] as Array[Dictionary], "no siege begins")
	assert_eq(Sieges.start(player, 1), [] as Array[Dictionary], "no retaliation either")
	assert_eq([player.siege_count, player.dice, player.siege_timer], [0, dice, 64], "no die, no jump")
	player.siege_active = true
	player.monsters.append({"slot": Sieges.SLOT, "kind": "creature", "creature": CLERIC,
		"x": 30 * 32 + 16, "y": 30 * 32 + 16, "color": 1, "heading": 0, "frame": 0, "town": 0})
	assert_eq(Sieges.resolve(player), [] as Array[Dictionary], "a besieger an odd save holds: no town falls")
	assert_false(TownStatus.ruled(player.world, 0))
	assert_false(player.siege_active)
	assert_true(WorldLairs.held_in(player, Sieges.SLOT).is_empty(), "it goes")
	player.ended = ""
	assert_eq(Sieges.start(player).size(), 1, "before the win, black's castle sends one (as played)")


# --------------------------------------------------------- the creatures --

func test_before_the_win_the_beaten_colours_leave_the_world_empty() -> void:
	var player := _player(false)
	_ticks(player, 40)
	assert_eq(player.monsters, [], "1997's refill: every colour beaten, nothing comes")


func test_at_peace_every_colour_comes_back_each_with_a_temper() -> void:
	var player := _player()
	_ticks(player, 40)
	var creatures := player.monsters.filter(func(m: Dictionary) -> bool: return m["kind"] == "creature")
	assert_gt(creatures.size(), 0, "the world walks again")
	assert_eq(player.defeated_wizards.size(), 5, "the beaten wizards stay beaten")
	for creature in creatures:
		assert_true(String(creature["temper"]) in WorldCreatures.TEMPERS, str(creature))
	for lair in player.monsters.filter(func(m: Dictionary) -> bool: return m["kind"] == "lair"):
		assert_false(lair.has("temper"), "a lair has none")


func test_the_tempers_are_drawn_by_their_odds() -> void:
	var dice := MsvcRandom.new(99)
	var counts := {WorldCreatures.HUNTS: 0, WorldCreatures.WANDERS: 0, WorldCreatures.STANDS: 0}
	for i in 4000:
		var held := {}
		var temper := WorldCreatures.give_temper(held, dice)
		assert_eq(String(held["temper"]), temper)
		counts[temper] += 1
	assert_almost_eq(float(counts[WorldCreatures.HUNTS]) / 4000.0, 0.25, 0.03, "a hunter in four")
	assert_almost_eq(float(counts[WorldCreatures.WANDERS]) / 4000.0, 0.5, 0.03, "a wanderer in two")
	assert_almost_eq(float(counts[WorldCreatures.STANDS]) / 4000.0, 0.25, 0.03, "one standing in four")


func test_a_standing_creature_stays_and_is_met_when_walked_into() -> void:
	var player := _player()
	_park(player, [0])
	var still := _creature(player, 0, Vector2i(48, 0), WorldCreatures.STANDS)
	var at := _at(still)
	assert_eq(_ticks(player, 20), [], "never comes")
	assert_eq(_at(still), at, "never moves")
	assert_eq(int(still["frame"]), 0)
	player.position = at + Vector2i(6, 0)
	assert_eq(_ticks(player, 1), [0], "the hero walks into it (within 16): met")


func test_a_wanderer_goes_its_own_way() -> void:
	var player := _player()
	_park(player, [0])
	var roamer := _creature(player, 0, Vector2i(64, 0), WorldCreatures.WANDERS)
	roamer["wander"] = 3
	var aim := WorldCreatures.aim_of(player, 0, roamer, 64)
	assert_eq(aim, Vector2i(ShandalarWorld.DX[3], ShandalarWorld.DY[3]) * WorldCreatures.WANDER_AIM,
		"its own way, not the hero")
	var hunter := _creature(player, 1, Vector2i(64, 0), WorldCreatures.HUNTS)
	assert_eq(WorldCreatures.aim_of(player, 1, hunter, 64), player.position - _at(hunter), "a hunter: the hero")
	player.monster_timer = 2   # (T + slot) & 3 == 0: its turning tick
	var dice := MsvcRandom.new(5)
	var ways := {}
	for i in 200:
		var held := {"slot": 2, "kind": "creature", "creature": CLERIC, "x": player.position.x + 80,
			"y": player.position.y, "heading": 0, "frame": 0, "temper": WorldCreatures.WANDERS}
		WorldCreatures._walk(player, 2, held, dice)
		ways[int(held["wander"])] = true
	assert_eq(ways.size(), 8, "a new way drawn among the eight")


func test_the_quest_creature_and_a_world_not_at_peace_hunt() -> void:
	var player := _player()
	var held := {"slot": 0, "kind": "creature", "creature": CLERIC, "x": 0, "y": 0, "temper": WorldCreatures.STANDS}
	assert_eq(WorldCreatures.temper_of(player, held), WorldCreatures.STANDS)
	player.quest = {"type": -CLERIC, "destination": 3}
	assert_eq(WorldCreatures.temper_of(player, held), WorldCreatures.HUNTS, "the quest's creature comes")
	player.quest = {}
	held["temper"] = "sleepy"
	assert_eq(WorldCreatures.temper_of(player, held), WorldCreatures.HUNTS, "an odd temper: it hunts")
	held["temper"] = WorldCreatures.STANDS
	player.ended = ""
	assert_false(player.at_peace())
	assert_eq(WorldCreatures.temper_of(player, held), WorldCreatures.HUNTS, "before the win: 1997's")
	player.ended = AdventurePlayer.ENDED_FAILED
	assert_false(player.at_peace(), "a failed adventure is no peace")


func test_the_temper_is_saved_with_the_creature() -> void:
	var player := _player()
	player.adventure_id = "peace-0000"
	player.world.start = HERO
	_creature(player, 0, Vector2i(48, 0), WorldCreatures.WANDERS)["wander"] = 5
	_creature(player, 1, Vector2i(0, 48), "grumpy")["wander"] = 40
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_eq(String(WorldLairs.held_in(back, 0)["temper"]), WorldCreatures.WANDERS)
	assert_eq(int(WorldLairs.held_in(back, 0)["wander"]), 5)
	assert_false(WorldLairs.held_in(back, 1).has("temper"), "an odd temper dropped: drawn again")
	assert_eq(int(WorldLairs.held_in(back, 1)["wander"]), 8, "a way held to the eight")
	assert_true(back.at_peace(), "and the peace with them")
