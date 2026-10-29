extends GutTest
## THE CAMPAIGN SETTINGS OF 2026-10-29 (builder A1 of 0.50.65; the owner's
## rulings on the choke points, scratchpad c10 DECISIONS "Other choke
## points"), headless:
##  - LOST MANA LINKS COME BACK under the sieges' paces Steady, Rare and
##    None — a town a siege took while linked gets its link back when the
##    hero frees it ([method RuledTowns.settle]) or its wizard falls
##    ([method Sieges.free_all], [method CastleWin.beat]); under As 1997 it
##    stays lost; an unlinked town gains nothing; the towns are remembered
##    in the save, an old save remembers none;
##  - THE DUELS' STARTING LIFE "Base 10 + links" (unused-features §1,
##    duel.c 2205–2226): 10, +2 Haggler's Coin, +3 Ring of the Guardian, +5
##    Fruit of Sustenance, then the links — through one reader ([method
##    AdventurePlayer.duel_start_life]) for every adventure duel: a meeting,
##    a ruled town, a dungeon room (and its pool), a castle, the final
##    battle; the carried lives counted from it;
##  - THE ASCETIC HERO: 50 food last 100 walking clock steps, not 50; a
##    save and a load mid-meal neither skip nor double one; off is 1997's.

const VAMPIRE_LORD := 4

var base: Dictionary
var player: AdventurePlayer


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Campaign Keeper"
	setup.color = "white"
	setup.difficulty = 0
	setup.walker = "male"
	setup.seed_text = "13579"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	RuledTowns.forget()
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.monsters = []
	player.siege_timer = 0
	player.cards = []
	for card_name in ["Plains", "Plains", "Plains", "Plains", "Plains", "Plains", "Plains", "Plains",
			"Savannah Lions", "White Knight", "Serra Angel", "Healing Salve", "Benalish Hero"]:
		player.cards.append({"card": card_name, "decks": [0]})
	player.current_deck = 0


func after_each() -> void:
	AdventureSetup.forget()


func _round_trip(hero: AdventurePlayer) -> AdventurePlayer:
	return AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))


## The first town (not a city) no wizard holds, linked.
func _linked_town() -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == ShandalarWorld.TOWN and not TownStatus.ruled(player.world, slot):
			TownStatus.put(player.world, slot, TownStatus.LINKED)
			return slot
	return -1


## Town [param town] besieged by wizard [param wizard] and fallen
## ([method Sieges.resolve], as the clock or a lost meeting resolves it).
func _fall(town: int, wizard := 4) -> Array[Dictionary]:
	var site: Dictionary = player.world.sites[town]
	player.monsters.append({"slot": Sieges.SLOT, "kind": "creature", "creature": 29, "color": wizard,
		"x": int(site["x"]) * 32 + 16, "y": int(site["y"]) * 32 + 16, "heading": 0, "frame": 0,
		"town": town})
	player.siege_active = true
	return Sieges.resolve(player)


func _report(result: int) -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = result
	report.winner = {1: 0, 0: 1}.get(result, -1)
	return report


## Ruled town [param town] freed by beating its guard.
func _free(town: int) -> Dictionary:
	var entry := RuledTowns.enter(player, town)
	var met := RuledTowns.meeting(player, entry)
	return RuledTowns.settle(player, met, _report(RuledTowns.WON))


# ------------------------------------------------- the links come back --

func test_a_freed_town_gets_its_link_back_under_steady_rare_and_none() -> void:
	for pace in [AdventurePlayer.SIEGES_STEADY, AdventurePlayer.SIEGES_RARE, AdventurePlayer.SIEGES_NONE]:
		before_each()
		player.sieges = AdventurePlayer.SIEGES_STEADY   # a siege can fall (None never begins one)
		var town := _linked_town()
		var links := player.mana_links()
		_fall(town)
		assert_true(TownStatus.ruled(player.world, town), "%s: taken" % pace)
		assert_eq(player.mana_links(), links - 1, "%s: its link lost" % pace)
		assert_eq(player.links_taken, [town] as Array[int], "%s: remembered" % pace)
		player.sieges = pace
		var out := _free(town)
		var name := WorldNames.site_name(player.world, town)
		assert_true(TownStatus.linked(player.world, town), "%s: the link is back" % pace)
		assert_eq(player.mana_links(), links, "%s: a life again" % pace)
		assert_true(bool(out["restored"]), pace)
		assert_eq(out["words"], ["%s is freed! The people rejoice." % name, AdventurePlayer.LINK_RESTORED] as Array[String],
			"%s: said in the town" % pace)
		assert_eq(String(player.journal[-1]["text"]), "Mana link restored at %s" % name, "%s: and in the journal" % pace)
		assert_eq(player.links_taken, [] as Array[int], "%s: forgotten" % pace)


func test_as_1997_the_link_stays_lost() -> void:
	player.sieges = AdventurePlayer.SIEGES_1997
	var town := _linked_town()
	var links := player.mana_links()
	_fall(town)
	var out := _free(town)
	assert_false(TownStatus.ruled(player.world, town), "freed")
	assert_false(TownStatus.linked(player.world, town), "its link stays lost, as played")
	assert_eq(player.mana_links(), links - 1)
	assert_false(bool(out["restored"]))
	assert_eq((out["words"] as Array).size(), 1, "only the freed words")
	assert_eq(player.links_taken, [] as Array[int], "forgotten all the same: a later Steady never brings it")


func test_an_unlinked_town_gains_no_link() -> void:
	player.sieges = AdventurePlayer.SIEGES_STEADY
	var town := _linked_town()
	TownStatus.put(player.world, town, TownStatus.LINKED, false)
	_fall(town)
	assert_eq(player.links_taken, [] as Array[int], "nothing lost, nothing remembered")
	_free(town)
	assert_false(TownStatus.linked(player.world, town), "never had one")


func test_a_beaten_wizard_frees_his_towns_with_their_links() -> void:
	player.sieges = AdventurePlayer.SIEGES_RARE
	var a := _linked_town()
	_fall(a, 4)
	var b := _linked_town()
	TownStatus.put(player.world, b, TownStatus.LINKED, false)
	_fall(b, 4)
	var won := CastleWin.beat(player, 3)
	assert_true(a in won["towns"] and b in won["towns"], "both freed")
	assert_true(TownStatus.linked(player.world, a), "the linked one's link is back")
	assert_false(TownStatus.linked(player.world, b), "the other had none")
	var a_name := WorldNames.site_name(player.world, a)
	var b_name := WorldNames.site_name(player.world, b)
	assert_eq(won["restored"], [a_name] as Array[String])
	var text := "\n".join(PackedStringArray(won["lines"]))
	assert_string_contains(text, "%s freed!\nIts mana link is restored." % a_name)
	assert_string_contains(text, "%s freed!" % b_name)
	assert_false(text.contains("%s freed!\nIts" % b_name))
	var said := false
	for entry in player.journal:
		said = said or String(entry["text"]) == "Mana link restored at %s" % a_name
	assert_true(said, "the journal says it")


func test_a_beaten_wizard_under_as_1997_frees_them_linkless() -> void:
	player.sieges = AdventurePlayer.SIEGES_1997
	var a := _linked_town()
	_fall(a, 4)
	var won := CastleWin.beat(player, 3)
	assert_true(a in won["towns"])
	assert_false(TownStatus.linked(player.world, a), "as played")
	assert_eq(won["restored"], [] as Array[String])
	assert_eq(won["lines"], CastleWin.defeated_lines(4, [WorldNames.site_name(player.world, a)] as Array[String]),
		"1997's words exactly")


func test_the_towns_remembered_ride_in_the_save_and_an_old_save_has_none() -> void:
	player.sieges = AdventurePlayer.SIEGES_STEADY
	var town := _linked_town()
	_fall(town)
	var again := _round_trip(player)
	assert_eq(again.links_taken, [town] as Array[int], "saved")
	var old: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	(old["record"] as Dictionary).erase("links_taken")
	var before := AdventurePlayer.from_dict(old)
	assert_eq(before.links_taken, [] as Array[int], "a save from before remembers none")
	(old["record"] as Dictionary)["links_taken"] = [town, town, 9999, "x"]
	assert_eq(AdventurePlayer.from_dict(old).links_taken, [town] as Array[int], "only this world's towns, once")
	player = before
	_free(town)
	assert_false(TownStatus.linked(player.world, town), "so nothing returns there")


# ------------------------------------------------- the starting life --

func test_links_only_is_1997s_life() -> void:
	assert_eq(player.life_start, AdventurePlayer.START_LINKS, "the default")
	player.world_magics.append_array(["Haggler's Coin", "Ring of the Guardian", "Fruit of Sustenance"])
	assert_eq(player.life_base(), 0)
	assert_eq(player.duel_start_life(), player.mana_links())
	player.next_duel_life = 2
	assert_eq(CreatureMeeting.hero_life(player), player.mana_links() + 2, "as played")


func test_base_10_and_the_world_magics_before_the_links() -> void:
	player.life_start = AdventurePlayer.START_BASE
	player.world_magics = [] as Array[String]
	var links := player.mana_links()
	assert_eq(player.life_base(), 10)
	player.world_magics.append("Haggler's Coin")
	assert_eq(player.life_base(), 12, "+2 Haggler's Coin")
	player.world_magics.append("Ring of the Guardian")
	assert_eq(player.life_base(), 15, "+3 Ring of the Guardian")
	player.world_magics.append("Fruit of Sustenance")
	assert_eq(player.life_base(), 20, "+5 Fruit of Sustenance")
	player.world_magics.append("Sword of Resistance")
	assert_eq(player.life_base(), 20, "no other World Magic")
	assert_eq(player.duel_start_life(), 20 + links, "then the links")


func test_every_adventure_duel_starts_from_it() -> void:
	player.life_start = AdventurePlayer.START_BASE
	player.world_magics = ["Ring of the Guardian"] as Array[String]
	var town := _linked_town()
	var start := 13 + player.mana_links()
	player.next_duel_life = 2
	# A meeting.
	var meeting := CreatureMeeting.meet(player, 8, 5)
	var config := CreatureMeeting.duel_config(player, meeting)
	assert_eq(config.lives[0], start + 2, "a meeting")
	# A ruled town.
	TownStatus.take(player.world, town, 4)
	start -= 1
	var entry := RuledTowns.enter(player, town)
	assert_eq(RuledTowns.duel_config(player, RuledTowns.meeting(player, entry)).lives[0], start + 2, "a ruled town")
	# A dungeon room and a castle: the run's pool on top.
	var run := {"life_pool": 3}
	assert_eq(DungeonDuels.life_parts(player, run)["base"], 13)
	assert_eq(DungeonDuels.hero_life(player, run), start + 2 + 3, "a dungeon room, its pool counted from it")
	# The final battle.
	assert_eq(FinalBattle.hero_life(player), start + 2, "the final battle")


func test_a_dungeon_pool_counts_from_the_base() -> void:
	player.life_start = AdventurePlayer.START_BASE
	player.world_magics = [] as Array[String]
	var start := 10 + player.mana_links()
	var run := {"life_pool": 0}
	assert_eq(DungeonDuels.hero_life(player, run), start)
	# A duel ended 4 lower: the next room starts 4 lower, from the base.
	run["life_pool"] = DungeonDuels.pool_after(DungeonDuels.CARRY, 0, start, start - 4)
	assert_eq(DungeonDuels.hero_life(player, run), start - 4)


func test_the_carried_lives_count_from_the_base() -> void:
	player.life_start = AdventurePlayer.START_BASE
	for slot in player.world.encounters:
		(slot as Dictionary)["clues"] = 7   # no dungeon to hint at: the cards at once
	var start := player.duel_start_life()
	var meeting := CreatureMeeting.meet(player, VAMPIRE_LORD, 1)
	meeting["timer"] = 0
	CreatureMeeting.prepare_duel(player, meeting)
	meeting["row"] = VAMPIRE_LORD
	meeting["special"] = true
	var report := DuelReport.new()
	report.finished = true
	report.result = DuelSpoils.WON
	report.winner = 0
	report.lives_start = [start, 6] as Array[int]
	report.lives_end = [start + 5, 0] as Array[int]
	report.hero_life = start + 5
	DuelSpoils.settle(player, meeting, report)
	assert_eq(player.next_duel_life_carried, 5, "the end less the start the base is in")
	assert_eq(CreatureMeeting.hero_life(player), start + 5, "the next duel starts at the life it ended with")


func test_the_choice_rides_in_the_save() -> void:
	player.life_start = AdventurePlayer.START_BASE
	player.creatures = AdventurePlayer.CREATURES_NOTICE
	player.ascetic = true
	var again := _round_trip(player)
	assert_eq([again.life_start, again.creatures, again.ascetic],
		[AdventurePlayer.START_BASE, AdventurePlayer.CREATURES_NOTICE, true])
	var old: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	for key in ["life_start", "creatures", "ascetic"]:
		(old["hero"] as Dictionary).erase(key)
	var before := AdventurePlayer.from_dict(old)
	assert_eq([before.life_start, before.creatures, before.ascetic],
		[AdventurePlayer.START_LINKS, AdventurePlayer.CREATURES_HUNT, false], "an old save plays as 1997")
	(old["hero"] as Dictionary)["life_start"] = "twenty"
	(old["hero"] as Dictionary)["creatures"] = 3
	assert_eq(AdventurePlayer.from_dict(old).life_start, AdventurePlayer.START_LINKS, "an odd value: 1997's")
	assert_eq(AdventurePlayer.from_dict(old).creatures, AdventurePlayer.CREATURES_HUNT)


func test_the_embark_record_begins_the_adventure_with_them() -> void:
	var setup := AdventureSetup.new()
	assert_eq([setup.creatures, setup.life_start, setup.ascetic],
		[AdventurePlayer.CREATURES_NOTICE, AdventurePlayer.START_LINKS, false], "the defaults")
	setup.player_name = "Ascetic Wanderer"
	setup.seed_text = "777"
	setup.life_start = AdventurePlayer.START_BASE
	setup.creatures = AdventurePlayer.CREATURES_HUNT
	setup.ascetic = true
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq([hero.life_start, hero.creatures, hero.ascetic],
		[AdventurePlayer.START_BASE, AdventurePlayer.CREATURES_HUNT, true])
	setup.remember()
	var kept := AdventureSetup.restore([] as Array[String])
	assert_eq([kept.life_start, kept.creatures, kept.ascetic],
		[AdventurePlayer.START_BASE, AdventurePlayer.CREATURES_HUNT, true], "remembered for the next visit")
	AdventureSetup.forget()
	kept = AdventureSetup.restore([] as Array[String])
	assert_eq([kept.life_start, kept.creatures, kept.ascetic],
		[AdventurePlayer.START_LINKS, AdventurePlayer.CREATURES_NOTICE, false], "forgotten: the defaults")


# ------------------------------------------------------ the ascetic hero --

## A walker on white plains, [param food] in the pack.
func _walker(food: int) -> HeroWalk:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 6
	var hero := AdventurePlayer.new()
	hero.world = world
	hero.food = food
	hero.position = Vector2i(2, 30) * 32 + Vector2i(16, 16)
	return HeroWalk.new(hero)


## The walking clock steps (the quest clock's, one for each 32 ticks
## walked) until the food runs out, east and back (at most [param most]).
func _steps_to_hunger(walk: HeroWalk, most := 400) -> int:
	walk.walk_to(Vector2i(60, 30))
	while walk.player.food > 0 and walk.player.quest_timer < most:
		if not walk.is_walking():
			walk.walk_to(Vector2i(2 if walk.player.tile().x > 30 else 60, 30))
		walk.tick()
	return walk.player.quest_timer


func test_off_a_food_every_clock_step_as_1997() -> void:
	var walk := _walker(50)
	assert_eq(_steps_to_hunger(walk), 50, "50 food, 50 steps")


func test_ascetic_food_lasts_twice_as_long() -> void:
	var walk := _walker(50)
	walk.player.ascetic = true
	assert_eq(_steps_to_hunger(walk), 100, "50 food, 100 steps")


func test_fruit_of_sustenance_still_gives_its_two() -> void:
	var walk := _walker(10)
	walk.player.ascetic = true
	walk.player.world_magics.append("Fruit of Sustenance")
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			walk.player.world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 2
	walk.walk_to(Vector2i(60, 30))
	while walk.player.quest_timer < 4:
		walk.tick()
	assert_eq(walk.player.food, 10 - 2 + 4 * 2, "two meals in four steps, four gifts of two")


func test_a_save_and_a_load_mid_meal_skip_and_double_nothing() -> void:
	var walk := _walker(50)
	walk.player.ascetic = true
	walk.walk_to(Vector2i(60, 30))
	while walk.player.quest_timer < 3:
		walk.tick()
	assert_eq(walk.player.food, 49, "three steps: one meal, a half kept")
	assert_eq(walk.player.meal_half, 1)
	# Saved and taken up again mid-meal: the next step eats.
	player.food = walk.player.food
	player.meal_half = walk.player.meal_half
	player.ascetic = true
	var again := _round_trip(player)
	assert_eq(again.meal_half, 1, "the half saved")
	assert_true(again.ascetic)
	assert_true(again.eats_this_step(), "the next step eats")
	assert_false(again.eats_this_step(), "the one after does not")
	var old: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	(old["carried"] as Dictionary).erase("meal_half")
	assert_eq(AdventurePlayer.from_dict(old).meal_half, 0, "a save from before: no half")
