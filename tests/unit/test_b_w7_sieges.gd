extends GutTest
## THE WIZARDS' SIEGES (part B, W7, 2026-10-23): the siege clock — a siege
## begun at `T & 63 == 0`, resolved at 24, the jumps — ([Sieges]); the
## towns a siege may fall on and their scores on the dice; the creature's
## tier by the clock; the besieger put in slot 7; the news in the 1997
## words; the town falling — the besieged one, its link lost, the wizard's
## taps against the 3 (5 with Ring of the Guardian) that cast the Spell of
## Dominion; a siege lifted; part C's helpers.

const BLACK := 1
const RED := 4
## The world's sites: [x, y, type].
const CASTLE_BLACK := [10, 10, ShandalarWorld.CASTLE]
const CASTLE_RED := [40, 40, ShandalarWorld.CASTLE]
const NEAR_BLACK := [12, 12, ShandalarWorld.TOWN]
const NEAR_RED := [38, 38, ShandalarWorld.CITY]
const A_VILLAGE := [20, 20, ShandalarWorld.VILLAGE]
const MIDDLE := [30, 30, ShandalarWorld.TOWN]


## A world of white plains, the castles on their own colour's land, its
## sites given as `[x, y, type]` — slot by slot in the order given.
func _player(sites: Array, difficulty := 1) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 6
	world.page[10 * ShandalarWorld.PAGE_WIDTH + 10] = 3   # black land
	world.page[40 * ShandalarWorld.PAGE_WIDTH + 40] = 5   # red land
	for site in sites:
		world.sites.append({"x": site[0], "y": site[1], "type": site[2], "trade": 0, "status": 0})
	world.lair_respawn = [0, 0, 0, 0, 0, 0, 0, 0]
	var player := AdventurePlayer.new()
	player.world = world
	player.difficulty = difficulty
	player.position = Vector2i(25 * 32 + 16, 25 * 32 + 16)
	player.dice = 4242
	return player


func _all() -> Array:
	return [CASTLE_BLACK, CASTLE_RED, NEAR_BLACK, NEAR_RED, A_VILLAGE, MIDDLE]


# ------------------------------------------------------------ the clock --

func test_the_clock_begins_at_64_and_resolves_at_24_with_its_jumps() -> void:
	var player := _player(_all(), 2)
	var began: Array[int] = []
	var resolved: Array[int] = []
	var timers: Array[int] = []
	for step in 400:
		player.siege_timer += 1
		var before := player.siege_timer
		var news := Sieges.on_step(player)
		for one in news:
			if String(one["kind"]) == "siege":
				began.append(before)
			elif String(one["kind"]) == "fall":
				resolved.append(before)
		timers.append(player.siege_timer)
	assert_eq(began[0], 64, "the first siege at T = 64")
	assert_true(66 in timers, "then the jump: d + T / 256 = 2")
	assert_eq(resolved[0], 88, "resolved at T & 63 == 24")
	assert_true(88 + 4 + 1 in timers, "then 2d + T / 64 = 5")
	for t in began:
		assert_eq(t & 63, 0)
	for t in resolved:
		assert_eq(t & 63, 24)
	assert_eq(began.size(), resolved.size(), "each siege, unlifted, falls")


func test_the_jump_is_taken_even_with_a_siege_under_way() -> void:
	var player := _player(_all(), 3)
	player.siege_active = true
	player.siege_timer = 256
	var dice := player.dice
	assert_eq(Sieges.on_step(player), [] as Array[Dictionary], "a siege already under way: none begun")
	assert_eq(player.dice, dice, "and no die drawn")
	assert_eq(player.siege_timer, 256 + 3 + 1, "the jump all the same: d + T / 256")
	player.siege_timer = 64 * 40
	Sieges.on_step(player)
	assert_eq(player.siege_timer, 64 * 40 + 13, "3 + 2560 / 256")
	player.siege_timer = 64 * 80 + 24
	player.siege_active = false
	Sieges.on_step(player)
	assert_eq(player.siege_timer, 64 * 80 + 24 + 32, "2d + T / 64, at most 32")


func test_the_tier_grows_with_the_clock() -> void:
	assert_eq([Sieges.tier_for(64, 0), Sieges.tier_for(128, 0), Sieges.tier_for(256, 0),
		Sieges.tier_for(448, 0)], [4, 6, 8, 12])
	assert_eq(Sieges.tier_for(512, 7), 12, "later: an odd row 12")
	assert_eq(Sieges.tier_for(4096, 8), 16, "an even row 16")


# -------------------------------------------------------- a siege begins --

func test_the_towns_and_their_scores_on_the_dice() -> void:
	var player := _player(_all())
	assert_eq(Sieges.candidates(player.world), [2, 3, 5] as Array[int], "towns and cities: no village, no castle")
	assert_eq(Sieges.castle_tiles(player), {BLACK: Vector2i(10, 10), RED: Vector2i(40, 40)})
	assert_eq(Sieges.nearest_castle(player.world, 2, Sieges.castle_tiles(player)), BLACK)
	assert_eq(Sieges.nearest_castle(player.world, 5, Sieges.castle_tiles(player)), RED, "60 against 30")
	# Red already holds a town: 32 more on each of hers.
	player.world.sites.append({"x": 50, "y": 50, "type": ShandalarWorld.TOWN, "trade": 0, "status": RED << 8})
	player.siege_timer = 64
	var dice := MsvcRandom.new(player.dice)
	var scores := [dice.below(128), 32 + dice.below(128), 32 + dice.below(128)]
	var best := 0
	for i in 3:
		if scores[i] < scores[best]:
			best = i
	var town: int = [2, 3, 5][best]
	var wizard := BLACK if town == 2 else RED
	var row := CreatureBook.pick(dice, wizard, 4)
	var news := Sieges.start(player)
	assert_eq(player.dice, dice.state, "one die a town, in slot order, then the pick")
	assert_eq(news.size(), 1)
	assert_eq(int(news[0]["town"]), town, "the lowest score besieged: %s" % [scores])
	assert_eq(int(news[0]["wizard"]), wizard)
	assert_eq(int(news[0]["creature"]), row)
	var held := WorldLairs.held_in(player, 7)
	assert_eq(held, {"slot": 7, "kind": "creature", "creature": row, "x": int(player.world.sites[town]["x"]) * 32 + 16,
		"y": int(player.world.sites[town]["y"]) * 32 + 16, "color": wizard, "heading": 0, "frame": 0, "town": town},
		"slot 7 at the town's middle")
	assert_true(player.siege_active)
	assert_eq(player.siege_count, 1)
	assert_true(player.world.is_explored(int(player.world.sites[town]["x"]), int(player.world.sites[town]["y"])),
		"the town's tile explored")
	assert_false(player.world.is_explored(int(player.world.sites[town]["x"]) + 1, int(player.world.sites[town]["y"])),
		"that tile alone")
	assert_eq(news[0]["lines"], ["%s sends %s to attack %s!" % [WorldNames.WIZARDS[wizard - 1],
		CreatureBook.called(row), WorldNames.site_name(player.world, town)]] as Array[String])
	assert_eq(WorldStatus.siege_line(player), "%s attacking %s!" % [CreatureBook.name_of(row),
		WorldNames.site_name(player.world, town)], "@QUESTSTATUS 0: the name without its article")


func test_the_witch_comes_first_and_no_castle_no_siege() -> void:
	var player := _player([CASTLE_BLACK, NEAR_BLACK])
	player.siege_timer = 64
	var news := Sieges.start(player)
	assert_eq(int(news[0]["creature"]), 1, "black, tier 4: the Witch")
	assert_eq(news[0]["lines"][0], "Black Wizard sends a Witch to attack %s!" % WorldNames.site_name(player.world, 1))
	# Every wizard beaten: the dice drawn, no siege.
	var beaten := _player([[10, 10, Sieges.BEATEN_CASTLE], NEAR_BLACK, MIDDLE])
	var dice := MsvcRandom.new(beaten.dice)
	dice.below(128)
	dice.below(128)
	assert_eq(Sieges.start(beaten), [] as Array[Dictionary])
	assert_eq(beaten.dice, dice.state, "a die for each town all the same, as 1997 drew them")
	assert_false(beaten.siege_active)
	assert_true(WorldLairs.held_in(beaten, 7).is_empty())
	var defeated := _player([CASTLE_BLACK, NEAR_BLACK])
	defeated.defeated_wizards.append("black")
	assert_eq(Sieges.start(defeated), [] as Array[Dictionary], "a wizard beaten sends no more")


func test_a_retaliation_scores_only_the_angry_wizard() -> void:
	var player := _player(_all())
	var news := Sieges.start(player, RED)
	assert_eq(int(news[0]["wizard"]), RED, "only his castle: every town his")
	assert_string_starts_with(String(news[0]["lines"][0]), "In retaliation for your effrontery the Great Red Wizardess sends ")
	var none := _player([CASTLE_BLACK, NEAR_BLACK])
	assert_eq(Sieges.start(none, RED), [] as Array[Dictionary], "his castle gone: no siege [ours]")


# -------------------------------------------------------- the town falls --

## A siege of town [param town] by wizard [param wizard]'s creature.
func _besieged(player: AdventurePlayer, town: int, wizard: int) -> void:
	player.monsters.append({"slot": 7, "kind": "creature", "creature": 29, "color": wizard, "heading": 0,
		"frame": 0, "town": town, "x": int(player.world.sites[town]["x"]) * 32 + 16,
		"y": int(player.world.sites[town]["y"]) * 32 + 16})
	player.siege_active = true


func test_the_besieged_town_falls_and_its_link_is_lost() -> void:
	var player := _player(_all())
	_besieged(player, 5, RED)
	TownStatus.put(player.world, 5, TownStatus.LINKED)
	# Lured away, the creature stands by the village now.
	var held := WorldLairs.held_in(player, 7)
	held["x"] = 20 * 32 + 16
	held["y"] = 20 * 32 + 16
	var news := Sieges.resolve(player)
	assert_eq(TownStatus.ruler(player.world, 5), RED, "the besieged town falls [ours: 1997 took the site nearest]")
	assert_eq(TownStatus.ruler(player.world, 4), 0, "not the village by the creature")
	assert_false(TownStatus.linked(player.world, 5), "its link lost")
	var named := WorldNames.site_name(player.world, 5)
	assert_eq(news.size(), 1)
	assert_eq(news[0]["lines"], ["The Evil Red Wizardess taps %s!" % named,
		"She needs 2 more mana taps to cast the Spell of Dominion!", "Your mana tap here is lost.",
		"Red Wizardess: 1 of 3 mana taps"] as Array[String])
	assert_false(player.siege_active)
	assert_true(WorldLairs.held_in(player, 7).is_empty(), "slot 7 emptied")
	assert_eq(player.siege_count, 1)
	assert_eq(Sieges.resolve(player), [] as Array[Dictionary], "nothing left to resolve: no news")


func test_three_taps_cast_dominion_five_with_the_ring() -> void:
	var player := _player(_all())
	TownStatus.take(player.world, 2, BLACK)
	TownStatus.take(player.world, 3, BLACK)
	player.world_magics.append("Ring of the Guardian")
	_besieged(player, 5, BLACK)
	var news := Sieges.resolve(player)
	assert_eq(news.size(), 1, "the Ring: five needed")
	assert_eq(news[0]["lines"][1], "He needs 2 more mana taps to cast the Spell of Dominion!")
	assert_eq(news[0]["lines"].size(), 3, "no link there to lose")
	var lost := _player(_all())
	TownStatus.take(lost.world, 2, BLACK)
	TownStatus.take(lost.world, 3, BLACK)
	_besieged(lost, 5, BLACK)
	news = Sieges.resolve(lost)
	assert_eq(news.size(), 2)
	assert_eq(news[0]["lines"][1], "He casts the spell of Dominion")
	assert_eq(String(news[1]["kind"]), "dominion")
	assert_eq(news[1]["lines"], ["Your Righteous Quest has Failed",
		"The Evil Planeswalker Arzakon\nand his Minion the\nEvil Black Wizard\nhave attained Dominion over the plane of Shandalar",
		Sieges.SUFFER] as Array[String])
	assert_true(Sieges.ends(news))
	assert_false(Sieges.ends(news.slice(0, 1)))


func test_the_besieger_met_and_not_beaten_takes_its_town_at_once() -> void:
	var player := _player(_all())
	_besieged(player, 3, RED)
	var outcome := WorldCreatures.met(player, 7, WorldCreatures.DRAWN)
	assert_eq(String(outcome["siege"]), "falls", "a draw takes the town too (the lead's ruling)")
	var news := Sieges.resolve(player, outcome)
	assert_eq(TownStatus.ruler(player.world, 3), RED, "the slot spent, the town falls from what was met")
	assert_eq(String(news[0]["kind"]), "fall")


func test_a_siege_lifted_writes_saved() -> void:
	var player := _player(_all())
	_besieged(player, 3, RED)
	var outcome := WorldCreatures.met(player, 7, WorldCreatures.WON)
	assert_eq(String(outcome["siege"]), "lifted")
	Sieges.lifted(player, outcome)
	assert_false(player.siege_active)
	assert_eq(String(player.journal[-1]["event"]), "saved")
	assert_eq(String(player.journal[-1]["text"]), "Saved %s" % WorldNames.site_name(player.world, 3))
	assert_eq(HeroStats.record(player)["saved"], 1, "the stats count it")
	player.siege_timer = 24
	assert_eq(Sieges.on_step(player), [] as Array[Dictionary], "the clock's turn: no besieger, no news")
	assert_eq(TownStatus.ruler(player.world, 3), 0)


func test_part_c_frees_a_beaten_wizard_s_towns() -> void:
	var player := _player(_all())
	TownStatus.take(player.world, 2, RED)
	TownStatus.take(player.world, 3, BLACK)
	_besieged(player, 5, RED)
	player.monsters.append({"slot": 2, "kind": "lair", "x": 0, "y": 0, "color": RED})
	assert_eq(Sieges.free_all(player, RED), [2] as Array[int])
	assert_eq(TownStatus.ruler(player.world, 3), BLACK, "another wizard's kept")
	assert_true(player.monsters.is_empty(), "his creatures gone, the besieger too")
	assert_false(player.siege_active)
