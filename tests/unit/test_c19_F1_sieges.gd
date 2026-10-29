extends GutTest
## THE SIEGES' PACE (the owner's ruling of 2026-10-28 on 1997's complaint,
## "creatures siege towns too much and they cannot explore"; [Sieges],
## [member AdventurePlayer.sieges]): "As 1997" the 1.3 clock exactly — each
## siege sooner than the last; "Steady" (a new adventure's default) the
## first siege's pace all game, the clock's jumps by the difficulty only;
## "Rare" those jumps and the clock stepping on every 64 walking ticks, not
## 32; "None" no siege ever begins. The cycle and the window to lift a
## siege at Apprentice and Wizard, early (the first siege) and late (the
## 61st); the walk's clock; the save; an older save as 1997.

## The world's sites for a world with sieges: [x, y, type].
const CASTLE_BLACK := [10, 10, ShandalarWorld.CASTLE]
const CASTLE_RED := [40, 40, ShandalarWorld.CASTLE]
const NEAR_BLACK := [12, 12, ShandalarWorld.TOWN]
const NEAR_RED := [38, 38, ShandalarWorld.CITY]
const MIDDLE := [30, 30, ShandalarWorld.TOWN]
## The siege clock at the first siege and at the 61st (`T & 63 == 0`).
const EARLY := 64
const LATE := 64 * 61


func after_each() -> void:
	AdventureSetup.forget()


## A world of white plains with [param sites] (`[x, y, type]`), the castles
## on their colour's land — none given, no siege can begin and the clock
## alone runs.
func _player(pace: String, difficulty: int, sites: Array = []) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 6
	world.page[10 * ShandalarWorld.PAGE_WIDTH + 10] = 3
	world.page[40 * ShandalarWorld.PAGE_WIDTH + 40] = 5
	for site in sites:
		world.sites.append({"x": site[0], "y": site[1], "type": site[2], "trade": 0, "status": 0})
	world.lair_respawn = [0, 0, 0, 0, 0, 0, 0, 0]
	var player := AdventurePlayer.new()
	player.world = world
	player.difficulty = difficulty
	player.sieges = pace
	player.position = Vector2i(25 * 32 + 16, 25 * 32 + 16)
	player.dice = 4242
	return player


## The clock run from siege [param at] (`T` of a siege's start): `[cycle,
## lift]` — the clock's steps to the next start, and from the start to its
## resolving (the window to lift it), as [HeroWalk] steps it.
func _cycle(pace: String, difficulty: int, at: int) -> Array[int]:
	var player := _player(pace, difficulty)
	player.siege_timer = at - 1
	var starts: Array[int] = []
	var resolves: Array[int] = []
	for step in 200:
		player.siege_timer += 1
		var t := player.siege_timer
		Sieges.on_step(player)
		if t & 63 == Sieges.START_AT:
			starts.append(step)
		if t & 63 == Sieges.RESOLVE_AT:
			resolves.append(step)
		if starts.size() == 2:
			break
	return [starts[1] - starts[0], resolves[0] - starts[0]] as Array[int]


func test_as_1997_each_siege_comes_sooner_than_the_last() -> void:
	assert_eq(_cycle(AdventurePlayer.SIEGES_1997, 0, EARLY), [63, 24] as Array[int], "Apprentice, the first")
	assert_eq(_cycle(AdventurePlayer.SIEGES_1997, 3, EARLY), [54, 21] as Array[int], "Wizard, the first")
	assert_eq(_cycle(AdventurePlayer.SIEGES_1997, 0, LATE), [17, 9] as Array[int], "Apprentice, the 61st")
	assert_eq(_cycle(AdventurePlayer.SIEGES_1997, 3, LATE), [16, 8] as Array[int], "Wizard, the 61st")


func test_steady_keeps_the_first_siege_s_pace() -> void:
	for pace in [AdventurePlayer.SIEGES_STEADY, AdventurePlayer.SIEGES_RARE]:
		for at in [EARLY, LATE]:
			assert_eq(_cycle(pace, 0, at), [64, 24] as Array[int], "%s, Apprentice, T %d" % [pace, at])
			assert_eq(_cycle(pace, 3, at), [55, 21] as Array[int], "%s, Wizard, T %d" % [pace, at])


func test_the_besieger_s_tier_still_climbs_with_the_clock() -> void:
	assert_eq(Sieges.tier_for(EARLY, 0), 4)
	assert_eq(Sieges.tier_for(LATE, 0), Sieges.LATE_EVEN)


## A walker on plain land: the 32-tick steps it took, the siege clock's.
func _walk(pace: String, tiles: int) -> AdventurePlayer:
	var player := _player(pace, 0)
	player.food = 50
	player.position = Vector2i(10, 20) * 32 + Vector2i(16, 16)
	var walk := HeroWalk.new(player)
	walk.walk_to(Vector2i(10 + tiles, 20))
	var count := 0
	while walk.is_walking() and count < 2000:
		walk.tick()
		count += 1
	return player


func test_rare_steps_the_clock_on_every_64_walking_ticks() -> void:
	var steady := _walk(AdventurePlayer.SIEGES_STEADY, 8)
	assert_eq([steady.quest_timer, steady.siege_timer], [8, 8], "control: every 32 ticks")
	var rare := _walk(AdventurePlayer.SIEGES_RARE, 8)
	assert_eq([rare.quest_timer, rare.siege_timer], [8, 4], "the siege clock half as often, the quest clock not")
	assert_eq(rare.food, steady.food, "the hero eats as ever")


func test_none_never_begins_a_siege() -> void:
	var player := _player(AdventurePlayer.SIEGES_NONE, 3, [CASTLE_BLACK, CASTLE_RED, NEAR_BLACK, NEAR_RED, MIDDLE])
	var control := _player(AdventurePlayer.SIEGES_STEADY, 3, [CASTLE_BLACK, CASTLE_RED, NEAR_BLACK, NEAR_RED, MIDDLE])
	var dice := player.dice
	var news := 0
	for step in 1000:
		player.siege_timer += 1
		news += Sieges.on_step(player).size()
		control.siege_timer += 1
		Sieges.on_step(control)
	assert_eq(news, 0, "no news")
	assert_eq([player.siege_count, player.siege_active, player.dice], [0, false, dice], "no siege, no die drawn")
	assert_eq(player.siege_timer, 1000, "the clock steps on, no jump")
	assert_gt(control.siege_count, 0, "control: Steady besieges")
	for town in [2, 3, 4]:
		assert_false(TownStatus.ruled(player.world, town), "no town lost")
	assert_eq(Sieges.start(player, 1), [] as Array[Dictionary], "the Wizard level's retaliation neither")
	assert_false(player.siege_active)


func test_the_pace_is_saved_and_an_older_save_plays_as_1997() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.seed_text = "12345"
	assert_eq(setup.sieges, AdventurePlayer.SIEGES_STEADY, "a new adventure's default")
	setup.sieges = AdventurePlayer.SIEGES_RARE
	var record := setup.resolve({})
	assert_eq(String(record["sieges"]), AdventurePlayer.SIEGES_RARE, "the record carries it")
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(player.sieges, AdventurePlayer.SIEGES_RARE, "the adventure plays by it")
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	assert_eq(String((data["hero"] as Dictionary)["sieges"]), AdventurePlayer.SIEGES_RARE, "saved")
	assert_eq(AdventurePlayer.from_dict(data).sieges, AdventurePlayer.SIEGES_RARE, "and read back")
	(data["hero"] as Dictionary).erase("sieges")
	data["version"] = 2
	assert_eq(AdventurePlayer.from_dict(data).sieges, AdventurePlayer.SIEGES_1997, "a save from before: as 1997")
	(data["hero"] as Dictionary)["sieges"] = "every five minutes"
	assert_eq(AdventurePlayer.from_dict(data).sieges, AdventurePlayer.SIEGES_1997, "a bad value: as 1997")
	record.erase("sieges")
	assert_eq(AdventurePlayer.begin(record, AdventureSetup.make_world(record)).sieges, AdventurePlayer.SIEGES_1997)
	assert_eq(AdventurePlayer.new().sieges, AdventurePlayer.SIEGES_1997)
	setup.remember()
	assert_eq(AdventureSetup.restore([] as Array[String]).sieges, AdventurePlayer.SIEGES_RARE, "the next visit")
	AdventureSetup.forget()
	assert_eq(AdventureSetup.restore([] as Array[String]).sieges, AdventurePlayer.SIEGES_STEADY, "none remembered")
