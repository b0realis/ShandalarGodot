extends GutTest
## THE CREATURES ON THE MAP (part B, 2026-10-23): [WorldCreatures] and the
## roaming slots' refill ([method WorldLairs.fill]) held to 1997's
## `UpdateWorldLairAndMonsterSlots` as the b2 spec reads it
## (world_lair_monster_slots.c 327–969) — the pick and the white tier 13,
## the ring and its colour, the eight ways, the 4-tick turn, the lead by
## difficulty, the flight and the quest's creature, the colour stop, the
## crowding, the contact radii, the push-back, the jump's dice, the
## besieger's hover, the meeting's end, the crowd a duel clears, what the
## hero sees, the cries' dice, the saves and the tick's split.

## The hero's tile in the plain worlds.
const HERO := Vector2i(20, 20)
## Terrain codes: white plains, red mountains, blue islands.
const WHITE := 6
const RED := 5
const BLUE := 1
## Rows: the Cleric (white, tier 4, a male wizard), the Arch Angel (white,
## fast), the War Mage (red, BLINK), the Conjurer (blue, a lurker), the
## Shapeshifter (blue, its disguise shows the Conjurer), the Necromancer (a
## henchman, silent), the Warlock (black, a male wizard like the Cleric).
const CLERIC := 8
const ARCH_ANGEL := 12
const WAR_MAGE := 34
const CONJURER := 17
const SHAPESHIFTER := 19
const NECROMANCER := 6
const WARLOCK := 3


## A world of one land, the hero standing in its middle at tile [constant
## HERO], every slot's respawn long past, the clock at [param timer].
func _player(terrain := WHITE, difficulty := 1, timer := 1000) -> AdventurePlayer:
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
	player.position = HERO * 32 + Vector2i(16, 16)
	player.monster_timer = timer
	player.dice = 4242
	return player


## Tile [param tile] of [param player]'s world made [param terrain].
func _land(player: AdventurePlayer, tile: Vector2i, terrain: int) -> void:
	var page := player.world.page
	page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] = (page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] & 0xF0) | terrain


## A creature of row [param row] in slot [param slot], [param offset] world
## units from the hero.
func _creature(player: AdventurePlayer, slot: int, row: int, offset: Vector2i, heading := 0,
		color := 5) -> Dictionary:
	var at := player.position + offset
	var creature := {"slot": slot, "kind": "creature", "creature": row, "x": at.x, "y": at.y,
		"color": color, "heading": heading, "frame": 0}
	player.monsters.append(creature)
	return creature


## Every roaming slot not in [param busy] held by a lair four tiles west of
## the hero, each on its own place — nothing refills, nothing draws dice,
## nothing comes near.
func _park(player: AdventurePlayer, busy: Array) -> void:
	for slot in WorldLairs.SLOTS:
		if slot in busy:
			continue
		var tile := HERO + Vector2i(-4, -3 + slot)
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 5})


func _at(held: Dictionary) -> Vector2i:
	return Vector2i(int(held["x"]), int(held["y"]))


# ------------------------------------------------------------ the fill --

## The draws of a fill on all-white land up to its tier (the ring's place,
## the colour, the tier and its roll), on dice from [param seed_value]:
## `[tier, dice after them]`.
func _tier_drawn(seed_value: int, vc: int) -> Array:
	var dice := MsvcRandom.new(seed_value)
	if dice.below(2) != 0:
		dice.below(2)
		dice.below(9)
	else:
		dice.below(9)
		dice.below(2)
	while dice.below(6) != 5:
		pass
	var draw := dice.below(clampi(128 / (vc + 4), 6, 20)) + 5 / (vc + 1)
	var tier := WorldLairs.TIERS[draw] if draw < WorldLairs.TIERS.size() else 0
	if tier == 10:
		var roll := dice.below(200)
		tier = 10 if roll < 50 else 11 if roll < 85 else 12 if roll < 115 else 13 if roll < 142 \
			else 14 if roll < 165 else 16 if roll < 185 else 18
	return [tier, dice]


func test_a_white_tier_13_draw_is_a_lair_after_999_draws() -> void:
	var player := _player()
	player.lairs_explored = 40   # vc 5: the stronger tiers come
	var found := -1
	for seed_value in range(1, 5000):
		if int(_tier_drawn(seed_value, 5)[0]) == 13:
			found = seed_value
			break
	assert_gt(found, 0, "a seed draws white tier 13")
	var drawn: Array = _tier_drawn(found, 5)
	var dice := MsvcRandom.new(found)
	assert_true(WorldLairs.fill(player, 1, dice), "not a gate")
	var held := WorldLairs.held_in(player, 1)
	assert_eq(String(held.get("kind", "")), "lair", "no white creature of tier 13: the lair")
	var expected := drawn[1] as MsvcRandom
	for i in CreatureBook.PICK_TRIES:
		expected.below(CreatureBook.size() - 1)
	assert_eq(dice.state, expected.state, "after 999 draws of the pick")


func test_the_ring_and_its_colour() -> void:
	var player := _player(10)   # green and white
	for x in ShandalarWorld.TILES:
		for y in range(0, HERO.y):
			_land(player, Vector2i(x, y), 0)   # the north is sea
	var dice := MsvcRandom.new(7)
	var creatures := 0
	for i in 300:
		player.monsters = []
		WorldLairs.fill(player, 2, dice)
		var held := WorldLairs.held_in(player, 2)
		if held.is_empty():
			continue
		var tile := _at(held) / 32
		assert_eq(maxi(absi(tile.x - HERO.x), absi(tile.y - HERO.y)), WorldLairs.RING, "on the ring")
		assert_gte(tile.y, HERO.y, "never on the sea")
		assert_has([3, 5], int(held["color"]), "a colour of its land")
		assert_eq(_at(held) % 32, Vector2i(16, 16), "the tile's middle")
		if WorldCreatures.is_creature(held):
			creatures += 1
			assert_true(CreatureBook.is_of(int(held["creature"]), int(held["color"])), "of its slot's colour")
			assert_eq([int(held["heading"]), int(held["frame"])], [0, 0], "come standing")
	assert_gt(creatures, 30, "creatures come, as many as 1997's draws give")


func test_the_respawn_wait_and_apprentice_slot_5_keep_the_slot() -> void:
	var player := _player(WHITE, 0, 0)
	player.world.lair_respawn[1] = 0
	var dice := MsvcRandom.new(99)
	var waited := 0
	for i in 200:
		player.monsters = []
		if not WorldLairs.fill(player, 5, dice):
			waited += 1
		assert_true(WorldLairs.held_in(player, 5).is_empty() or WorldLairs.held_in(player, 5)["kind"] == "lair",
			"an Apprentice's slot 5 holds no creature")
	assert_gt(waited, 0, "a creature's draw keeps slot 5 as it was")
	# Slot 1 met at T = 0: W = 280 ticks at Apprentice.
	var kept := {"slot": 1, "kind": "lair", "x": 0, "y": 0, "color": 5}
	var gated := 0
	for i in 100:
		player.monsters = [kept]
		if not WorldLairs.fill(player, 1, dice):
			gated += 1
			assert_eq(WorldLairs.held_in(player, 1), kept, "the wait keeps what it held")
		else:
			assert_ne(String(WorldLairs.held_in(player, 1).get("kind", "")), "creature", "no creature yet")
	assert_gt(gated, 0)
	player.monster_timer = 281
	var creatures := 0
	for i in 100:
		player.monsters = []
		WorldLairs.fill(player, 1, dice)
		if WorldCreatures.is_creature(WorldLairs.held_in(player, 1)):
			creatures += 1
	assert_gt(creatures, 0, "after 280 ticks they come")


func test_too_many_wins_stop_a_creature_but_not_the_quests() -> void:
	var player := _player()
	for kind in range(1, 12):
		for i in WorldLairs.TOO_MANY_WINS + 1:
			player.duel_victories.append({"color": 5, "kind": kind, "creature": ""})
	var dice := MsvcRandom.new(3)
	for i in 200:
		player.monsters = []
		WorldLairs.fill(player, 3, dice)
		assert_false(WorldCreatures.is_creature(WorldLairs.held_in(player, 3)), "beaten nine times over: none")
	# The quest's creature comes all the same [ours], into slot 0 only.
	player.quest = {"type": -CLERIC, "destination": 0, "giver": 0, "color": 5}
	var came := 0
	for i in 200:
		player.monsters = []
		WorldLairs.fill(player, 0, dice)
		var held := WorldLairs.held_in(player, 0)
		assert_false(WorldCreatures.is_lair(held), "slot 0 holds no lair while the quest runs")
		if WorldCreatures.is_creature(held):
			assert_eq(int(held["creature"]), CLERIC, "only the quest's creature")
			came += 1
	assert_gt(came, 0, "it comes")


func test_slot_0_is_held_for_the_quest_only_while_it_runs() -> void:
	var player := _player()
	var dice := MsvcRandom.new(11)
	player.quest = {"type": -CLERIC - 100, "destination": 0, "giver": 0, "color": 5}
	var lairs := 0
	for i in 200:
		player.monsters = []
		WorldLairs.fill(player, 0, dice)
		var held := WorldLairs.held_in(player, 0)
		if WorldCreatures.is_lair(held):
			lairs += 1
	assert_gt(lairs, 0, "beaten and on the way back: slot 0 is free again [ours]")
	assert_eq(WorldCreatures.quest_row(player), 0)
	player.quest["type"] = -CLERIC
	assert_eq(WorldCreatures.quest_row(player), CLERIC)
	player.quest = {}
	assert_eq(WorldCreatures.quest_row(player), 0, "no quest, no hold")


func test_a_beaten_wizard_s_creatures() -> void:
	var player := _player(10)   # green and white land
	player.defeated_wizards.append("white")
	var dice := MsvcRandom.new(5)
	for i in 300:
		player.monsters = []
		WorldLairs.fill(player, 1, dice)
		var held := WorldLairs.held_in(player, 1)
		if WorldCreatures.is_creature(held):
			assert_ne(int(held["color"]), 5, "no creature of a beaten wizard's colour")
			if CreatureBook.is_of(int(held["creature"]), 5):
				assert_eq(int(held["color"]), _other_color(int(held["creature"])), "a two-colour one takes its other")


func _other_color(row: int) -> int:
	for hue in range(1, 5):
		if CreatureBook.is_of(row, hue):
			return hue
	return 0


# ------------------------------------------------------------ the walk --

func test_the_eight_ways() -> void:
	var table := {Vector2i(10, 0): 3, Vector2i(-10, 0): 7, Vector2i(0, 10): 5, Vector2i(0, -10): 1,
		Vector2i(10, 10): 4, Vector2i(10, -10): 2, Vector2i(-10, 10): 6, Vector2i(-10, -10): 8,
		Vector2i(0, 0): 8, Vector2i(10, 5): 4, Vector2i(10, 4): 3, Vector2i(4, 10): 5, Vector2i(5, 10): 4,
		Vector2i(-1, 0): 7, Vector2i(0, -1): 1, Vector2i(-9, 4): 7, Vector2i(-9, 5): 6}
	for aim in table:
		assert_eq(WorldCreatures.way_of(aim), table[aim], "aim %s" % aim)


func test_a_creature_turns_only_every_fourth_tick() -> void:
	var player := _player()
	_park(player, [2])
	var creature := _creature(player, 2, CLERIC, Vector2i(60, 0), 1)
	var headings: Array[int] = []
	for t in range(100, 108):
		player.monster_timer = t
		WorldCreatures.tick(player)
		headings.append(int(creature["heading"]))
	assert_eq(headings, [1, 1, 7, 7, 7, 7, 7, 7] as Array[int], "(T + slot) & 3 == 0 at T 102 and 106")
	assert_eq(_at(creature), player.position + Vector2i(60 - 6, -2), "north twice, then west six times")


func test_a_wizard_is_led_ahead_of_a_walking_hero() -> void:
	var player := _player()
	var creature := _creature(player, 1, CLERIC, Vector2i(0, 60))
	var d0 := WorldGenerator.distance(0, 60)
	assert_eq(WorldCreatures.aim_of(player, 1, creature, d0), Vector2i(0, -60), "a standing hero: straight at them")
	player.step = 2
	player.facing = 3
	var leads: Array[Vector2i] = []
	for difficulty in 4:
		player.difficulty = difficulty
		leads.append(WorldCreatures.aim_of(player, 1, creature, d0))
	assert_eq(leads, [Vector2i(0, -60), Vector2i(16, -60), Vector2i(32, -60), Vector2i(40, -60)] as Array[Vector2i],
		"an Apprentice never led; d0 / 3 = 40, at most 16 a level")
	assert_eq(WorldCreatures.aim_of(player, 1, creature, 150).x, 48, "a Wizard's lead is at most 48")


func test_a_creature_flees_after_difficulty_plus_3_wins_but_never_the_quests() -> void:
	var player := _player()
	var creature := _creature(player, 1, CLERIC, Vector2i(30, 0))
	for i in 3:
		player.log_victory(WARLOCK, 5)
	assert_false(WorldCreatures.flees(player, creature), "3 wins: a Magician's creature still comes")
	player.log_victory(WARLOCK, 5)
	assert_true(WorldCreatures.flees(player, creature), "4: it runs — the Warlock's kind on white is the Cleric's")
	assert_eq(WorldCreatures.aim_of(player, 1, creature, 60), Vector2i(30, 0), "within 64: away from the hero")
	assert_eq(WorldCreatures.aim_of(player, 1, creature, 64), Vector2i(-30, 0), "at 64: towards")
	creature["color"] = 3
	assert_false(WorldCreatures.flees(player, creature), "not on another colour")
	creature["color"] = 5
	player.quest = {"type": -CLERIC, "destination": 0, "giver": 0, "color": 5}
	assert_false(WorldCreatures.flees(player, creature), "the quest's creature never runs [ours]")


func test_the_colour_stop_and_the_end_on_land_not_its_own() -> void:
	var player := _player()
	_park(player, [1])
	for y in ShandalarWorld.TILES:
		for x in range(HERO.x + 2, ShandalarWorld.TILES):
			_land(player, Vector2i(x, y), 0)
	player.monster_timer = 101   # slot 1 keeps its heading
	# On its own land at the shore, heading east into the sea.
	var stopped := _creature(player, 1, CLERIC, Vector2i(45, 0), 3)
	stopped["frame"] = 2
	var before := _at(stopped)
	var result := WorldCreatures.tick(player)
	assert_eq(_at(stopped), before, "the sea ahead: it stands")
	assert_eq(int(stopped["frame"]), 0, "standing")
	assert_eq(result["cries"], [], "a creature that stands never cries")
	# Standing on the sea itself, the hero within reach: gone, not met [ours].
	WorldCreatures.empty(player, 2)
	player.position = Vector2i((HERO.x + 3) * 32 + 16, HERO.y * 32 + 16)
	_creature(player, 2, CLERIC, Vector2i(6, 0), 3)
	result = WorldCreatures.tick(player)
	assert_true(WorldLairs.held_in(player, 2).is_empty(), "off its colours: gone")
	assert_eq(int(result["met"]), -1, "and not met though within 16")
	assert_eq(player.world.lair_respawn[2], -1000000, "unstamped")
	# The besieger walks the sea.
	var besieger := _creature(player, WorldCreatures.SIEGE_SLOT, CLERIC, Vector2i(40, 0), 7)
	var from := _at(besieger)
	WorldCreatures.tick(player)
	assert_eq(_at(besieger), from + Vector2i(-1, 0), "slot 7 minds no colour")


func test_only_live_creatures_crowd() -> void:
	var player := _player()
	_park(player, [1, 2])
	player.monster_timer = 101
	var walker := _creature(player, 1, CLERIC, Vector2i(-80, 0), 3)
	var other := _creature(player, 2, CLERIC, Vector2i(-62, 0), 3)
	var from := _at(walker)
	WorldCreatures.tick(player)
	assert_eq(_at(walker), from, "its probe within 32 of another, and nearer: it stands")
	assert_eq(int(walker["frame"]), 0)
	assert_eq(_at(other), from + Vector2i(18 + 1, 0), "the other walks on")
	# A lair in the way is no creature.
	player.monsters.erase(other)
	player.monsters.append({"slot": 2, "kind": "lair", "x": from.x + 18, "y": from.y, "color": 5})
	WorldCreatures.tick(player)
	assert_eq(_at(walker), from + Vector2i(1, 0), "a lair never crowds")
	# Nor an empty slot at the place its creature left [ours: 1997 slip].
	WorldCreatures.empty(player, 2)
	WorldCreatures.tick(player)
	assert_eq(_at(walker), from + Vector2i(2, 0), "an empty slot never crowds")
	# Within 32 of the hero nothing crowds.
	player.monsters = []
	_park(player, [1, 2])
	var close := _creature(player, 1, CLERIC, Vector2i(-15, 0), 3)
	_creature(player, 2, CLERIC, Vector2i(-11, 12), 3)
	var near := _at(close)
	assert_true(WorldCreatures.crowded(player, 1, near, near + Vector2i(4, 0)), "another in its way")
	WorldCreatures.tick(player)
	assert_eq(_at(close), near + Vector2i(1, 0), "the hero within 32: it comes on all the same")


func test_contact_within_16_and_a_lair_within_26() -> void:
	var player := _player()
	_park(player, [1, 2])
	player.monster_timer = 101
	var creature := _creature(player, 1, CLERIC, Vector2i(9, 0), 7)
	assert_eq(int(WorldCreatures.tick(player)["met"]), -1, "16 after its step: not yet")
	assert_eq(_at(creature), player.position + Vector2i(8, 0))
	var result := WorldCreatures.tick(player)
	assert_eq([int(result["met"]), String(result["kind"])], [1, "creature"], "14: met")
	player.monsters = []
	_park(player, [2])
	player.monsters.append({"slot": 2, "kind": "lair", "x": player.position.x + 13, "y": player.position.y, "color": 5})
	assert_eq(int(WorldCreatures.tick(player)["met"]), -1, "a lair at 26: not yet")
	WorldLairs.held_in(player, 2)["y"] = player.position.y + 1
	WorldLairs.held_in(player, 2)["x"] = player.position.x + 12
	result = WorldCreatures.tick(player)
	assert_eq([int(result["met"]), String(result["kind"])], [2, "lair"], "25: entered")


func test_the_jump_draws_two_dice_every_64th_tick() -> void:
	var player := _player(RED)
	_park(player, [1])
	var mage := _creature(player, 1, WAR_MAGE, Vector2i(80, 0), 7, 4)
	player.monster_timer = 129
	var dice := player.dice
	WorldCreatures.tick(player)
	assert_eq(player.dice, dice, "not the 64th tick: no dice")
	player.monster_timer = 128
	WorldCreatures.tick(player)
	var expected := MsvcRandom.new(dice)
	expected.below(2)
	expected.below(2)
	assert_eq(player.dice, expected.state, "two dice on T & 63 == 0")
	assert_eq(_at(mage), player.position + Vector2i(78, 0), "the jump moves only the probe the colour test reads")


func test_the_besieger_hovers_by_its_town_and_chases_inside_24() -> void:
	var player := _player()
	player.world.sites.append({"x": 30, "y": 30, "type": ShandalarWorld.TOWN, "trade": 0, "status": 0})
	player.world.sites.append({"x": 31, "y": 30, "type": ShandalarWorld.TOWN, "trade": 0, "status": 0})
	_park(player, [])
	var middle := Vector2i(30 * 32 + 16, 30 * 32 + 16)
	var besieger := {"slot": 7, "kind": "creature", "creature": CLERIC, "x": middle.x, "y": middle.y,
		"color": 5, "heading": 0, "frame": 0, "town": 0}
	player.monsters.append(besieger)
	var furthest := 0
	for t in range(1000, 3000):
		player.monster_timer = t
		assert_eq(int(WorldCreatures.tick(player)["met"]), -1)
		furthest = maxi(furthest, maxi(absi(int(besieger["x"]) - middle.x), absi(int(besieger["y"]) - middle.y)))
	assert_lte(furthest, 24, "it hovers by its town's middle")
	# Lured to the next town, it goes back to its own [ours: 1997 slip].
	besieger["x"] = middle.x + 32
	besieger["y"] = middle.y
	var aim := WorldCreatures.aim_of(player, 7, besieger, 500)
	var t := player.monster_timer
	assert_eq(aim, Vector2i(-32 + (t & 31) - 16, ((t & 62) >> 1) - 16), "to its own town, jittered by the clock")
	# The hero within 24: it comes for them.
	player.position = _at(besieger) + Vector2i(10, 0)
	var met := -1
	for i in 20:
		player.monster_timer += 1
		met = int(WorldCreatures.tick(player)["met"])
		if met >= 0:
			break
	assert_eq(met, 7, "met")


func test_a_fast_creature_strides_two() -> void:
	var player := _player()
	_park(player, [1])
	player.monster_timer = 101
	var angel := _creature(player, 1, ARCH_ANGEL, Vector2i(70, 0), 7)
	WorldCreatures.tick(player)
	assert_eq(_at(angel), player.position + Vector2i(68, 0))


# --------------------------------------------------------- the meeting --

func test_a_meeting_spends_the_slot() -> void:
	var player := _player()
	player.monster_timer = 1000
	_creature(player, 3, CLERIC, Vector2i(10, 0))
	var outcome := WorldCreatures.met(player, 3, WorldCreatures.WON)
	assert_eq(outcome, {"slot": 3, "creature": CLERIC, "color": 5, "town": -1, "siege": ""})
	assert_true(WorldLairs.held_in(player, 3).is_empty(), "gone")
	assert_eq(player.world.lair_respawn[3], 1000, "its slot's meeting now")
	assert_eq(player.monster_timer, 1023, "the clock on to the next 32")
	for result in [WorldCreatures.WON, WorldCreatures.LOST, WorldCreatures.DRAWN, WorldCreatures.NO_DUEL]:
		var besieger := _creature(player, 7, CLERIC, Vector2i(10, 0))
		besieger["town"] = 4
		outcome = WorldCreatures.met(player, 7, result)
		assert_eq(String(outcome["siege"]), "lifted" if result == WorldCreatures.WON else "falls",
			"the besieger beaten lifts the siege; anything else lets the town fall")
		assert_eq(int(outcome["town"]), 4)
		assert_true(WorldLairs.held_in(player, 7).is_empty())
	assert_eq(player.world.lair_respawn.size(), 7, "no stamp past the world's seven")


func test_a_duel_clears_the_crowd_round_the_hero() -> void:
	var player := _player()
	_creature(player, 0, CLERIC, Vector2i(10, 0))
	_creature(player, 1, CLERIC, Vector2i(20, 10))
	_creature(player, 2, CLERIC, Vector2i(33, 0))
	player.monsters.append({"slot": 3, "kind": "lair", "x": player.position.x, "y": player.position.y + 10, "color": 5})
	_creature(player, 7, CLERIC, Vector2i(0, 5))
	var cleared := WorldCreatures.clear_crowd(player, 0)
	assert_eq(cleared, [1] as Array[int], "within 64: gone; 66 away stays")
	assert_false(WorldLairs.held_in(player, 0).is_empty(), "the one met stays for its meeting")
	assert_false(WorldLairs.held_in(player, 3).is_empty(), "a lair stays")
	assert_false(WorldLairs.held_in(player, 7).is_empty(), "the besieger stays")
	assert_eq(player.world.lair_respawn[1], -1000000, "unstamped")


func test_entering_a_place_pushes_the_creatures_back() -> void:
	var player := _player()
	var hero := player.position
	var east := _creature(player, 0, CLERIC, Vector2i(30, 5))
	var corner := _creature(player, 1, CLERIC, Vector2i(-20, -20))
	var north := _creature(player, 2, CLERIC, Vector2i(5, -40))
	var far := _creature(player, 3, CLERIC, Vector2i(50, 0))
	player.monsters.append({"slot": 4, "kind": "lair", "x": hero.x + 10, "y": hero.y, "color": 5})
	var besieger := _creature(player, 7, CLERIC, Vector2i(10, 0))
	WorldCreatures.push_back(player)
	assert_eq(_at(east), hero + Vector2i(48, 0), "east: 48 out, level on the other axis")
	assert_eq(_at(corner), hero + Vector2i(-48, -48), "a diagonal: 48 × 48")
	assert_eq(_at(north), hero + Vector2i(0, -48), "north")
	assert_eq(_at(far), hero + Vector2i(50, 0), "at 100: stays")
	assert_eq(_at(WorldLairs.held_in(player, 4)), hero + Vector2i(10, 0), "a lair stays")
	assert_eq(_at(besieger), hero + Vector2i(10, 0), "the besieger stays")


# ------------------------------------------------------------ the eyes --

func test_the_hero_sees_every_creature_within_four_tiles() -> void:
	var player := _player()
	_creature(player, 0, CLERIC, Vector2i(4 * 32, 0))
	_creature(player, 1, CLERIC, Vector2i(5 * 32, 0))
	_creature(player, 2, CLERIC, Vector2i(-3 * 32, 4 * 32))
	player.monsters.append({"slot": 3, "kind": "lair", "x": player.position.x + 32, "y": player.position.y, "color": 5})
	var slots: Array[int] = []
	for creature in WorldCreatures.seen(player):
		slots.append(int(creature["slot"]))
	assert_eq(slots, [0, 2] as Array[int], "within four tiles on both axes [QoL]; a lair is not a creature")
	var one: Dictionary = WorldCreatures.seen(player)[0]
	assert_eq(one.keys(), ["slot", "creature", "x", "y", "heading", "frame", "color"])


func test_a_lurker_hides_beyond_256_page_pixels_of_the_hero_s_feet() -> void:
	var player := _player(BLUE)
	var lurker := _creature(player, 0, CONJURER, Vector2i(40, 0), 0, 2)
	assert_eq(WorldCreatures.seen(player).size(), 1, "near: seen (lay 80 × 40, 200)")
	lurker["x"] = player.position.x - 40
	assert_eq(WorldCreatures.seen(player).size(), 1, "as near west: seen too [ours: centred on the feet]")
	lurker["x"] = player.position.x + 64
	assert_eq(WorldCreatures.seen(player).size(), 0, "two tiles east: 320 pixels, hidden")
	lurker["creature"] = SHAPESHIFTER
	player.monster_timer = 2 << 5
	assert_eq(WorldCreatures.seen(player).size(), 0, "a Shapeshifter shown as the Conjurer lurks")
	player.monster_timer = 0
	assert_eq(WorldCreatures.seen(player).size(), 1, "shown as itself it does not")


# ----------------------------------------------------------- the cries --

func test_cries_draw_on_the_soundscape_s_dice_never_the_world_s() -> void:
	var player := _player()
	_park(player, [1])
	player.monster_timer = 101
	_creature(player, 1, CLERIC, Vector2i(30, 0), 7)
	var dice := player.dice
	var cries := 0
	for i in 6:
		var result := WorldCreatures.tick(player)
		cries += (result["cries"] as Array).size()
		for one in result["cries"]:
			assert_eq(int(one["creature"]), CLERIC)
			assert_lt(int(one["distance"]), WorldCreatures.CRY_REACH)
	assert_eq(cries, 6, "a stepping creature within 80 may cry every tick")
	assert_eq(player.dice, dice, "the world's dice untouched")
	var sounds := WorldSoundscape.new()
	add_child_autofree(sounds)
	sounds.rng.seed = 7
	var heard := 0
	for i in 4000:
		if sounds.cry(CLERIC, 40, Vector2(100, 100)):
			heard += 1
	assert_between(heard, 330, 470, "one time in ten at 40 (4 / d0)")
	assert_true(sounds.cry(CLERIC, 3, Vector2.ZERO), "within 4: always")
	sounds.rng.seed = 1
	var silent := 0
	for i in 200:
		if sounds.cry(NECROMANCER, 2, Vector2.ZERO):
			silent += 1
	assert_eq(silent, 0, "a henchman has no voice")
	assert_eq(player.dice, dice)


# ------------------------------------------------------------ the tick --

## [ours: 1997 slip] On the tick a slot is filled its creature's distance is
## read where it now stands: met at the hero's feet, the slot's next creature
## comes four tiles out and never cries, runs or is led on that first tick as
## if it still stood where the last one was met (1997 read the old place).
func test_a_new_creature_s_first_distance_is_read_where_it_stands() -> void:
	var player := _player()
	var came := 0
	for i in 60:
		player.monsters = []
		_park(player, [1])
		_creature(player, 1, CLERIC, Vector2i(2, 0))
		WorldCreatures.met(player, 1, WorldCreatures.WON)
		player.world.lair_respawn[1] = -1000000
		player.monster_timer = 2000 + i
		var result := WorldCreatures.tick(player)
		var held := WorldLairs.held_in(player, 1)
		if not WorldCreatures.is_creature(held):
			continue
		came += 1
		for one in result["cries"]:
			assert_ne(int(one["slot"]), 1, "a creature come 4 tiles out (d0 ≥ 256) does not cry")
	assert_gt(came, 5, "creatures came")


func test_the_hero_s_step_and_the_tick_s_end() -> void:
	var player := _player()
	player.quickening = 5
	var walk := HeroWalk.new(player)
	walk.walk_to(HERO + Vector2i(3, 0))
	walk.step()
	assert_eq([player.monster_timer, player.quickening], [1000, 5], "the step moves no clock")
	walk.end_tick()
	assert_eq([player.monster_timer, player.quickening], [1001, 4], "the tick's end: Quickening, then the clock")
	walk.tick()
	assert_eq([player.monster_timer, player.quickening], [1002, 3], "a whole tick does both")


func test_the_staff_of_thunder_names_the_creature_from_the_book() -> void:
	var player := _player()
	player.world_magics.append("Staff of Thunder")
	player.amulets["red"] = 1
	player.monsters.append({"slot": 0, "kind": "lair", "x": player.position.x + 4, "y": player.position.y, "color": 5})
	_creature(player, 1, CLERIC, Vector2i(200, 0))
	_creature(player, 7, CLERIC, Vector2i(2, 0))
	assert_eq(WorldMagic.nearest_roaming(player), 1, "not the lair, not the besieger: however far")
	var result := WorldMagic.cast(player, 4)
	assert_string_starts_with(String(result["said"]), "Staff of Thunder: the Cleric is struck from the land.")
	assert_eq(String(player.journal[-1]["text"]), "THUNDERED on: Cleric!")


# ------------------------------------------------------------ the saves --

func test_the_creatures_come_back_from_a_save() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Ilse"
	setup.color = "white"
	setup.difficulty = 1
	setup.seed_text = "777"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	var at := player.position
	player.monsters = [
		{"slot": 0, "kind": "lair", "x": at.x + 64, "y": at.y, "color": 3},
		{"slot": 1, "kind": "creature", "creature": CLERIC, "x": at.x + 10, "y": at.y - 7, "color": 5,
			"heading": 3, "frame": 2},
		{"slot": 2, "kind": "creature", "tier": 6, "waiting": true, "x": at.x, "y": at.y, "color": 2},
		{"slot": 3, "kind": "creature", "creature": 55, "x": at.x, "y": at.y, "color": 1},
		{"slot": 4, "kind": "creature", "creature": 0, "x": at.x, "y": at.y, "color": 1},
		{"slot": 5, "kind": "creature", "creature": WARLOCK, "x": at.x, "y": at.y, "color": 1,
			"heading": 12, "frame": -3},
		{"slot": 7, "kind": "creature", "creature": WAR_MAGE, "x": 300, "y": 400, "color": 4, "heading": 0,
			"frame": 0, "town": 2}]
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(back)
	var slots: Array[int] = []
	for held in back.monsters:
		slots.append(int(held["slot"]))
	assert_eq(slots, [0, 1, 5, 7] as Array[int], "the waiting draw and the rows not of the map dropped")
	assert_eq(WorldLairs.held_in(back, 1), {"slot": 1, "kind": "creature", "creature": CLERIC, "x": at.x + 10,
		"y": at.y - 7, "color": 5, "heading": 3, "frame": 2}, "a creature as it was, its numbers numbers")
	assert_eq([WorldLairs.held_in(back, 5)["heading"], WorldLairs.held_in(back, 5)["frame"]], [8, 0], "held to 0–8 and 0–4")
	assert_eq(int(WorldLairs.held_in(back, 7)["town"]), 2, "the besieger keeps its town")
	assert_typeof(WorldLairs.held_in(back, 1)["creature"], TYPE_INT)
	assert_eq(WorldLairs.held_in(back, 0)["kind"], "lair")
