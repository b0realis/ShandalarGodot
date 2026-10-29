extends GutTest
## THE 0.50.65 BUG CAMPAIGN, F1 — the adventure:
##  - k1-3: a stake or the dungeon's dice drawn from a bag past 32,768
##    cards ends ([method MsvcRandom.place_among]; `rand()` reaches 32767
##    at most, and a bag whose usable cards all stood past it was drawn
##    forever); up to the reach the draw is 1997's, die for die;
##  - k6-1: a ruled town stakes from places past the bag's 500th under
##    "Unlimited card hold" ([method RuledTowns.walked]), 1997's walk under
##    its limit;
##  - k6-2: without the 1997 card table a shop stocks what 1997's did — the
##    table's marks read off the printings and carried by name, no
##    DeckFormat list ([method CardValue.expansion], [method
##    CardValue.named_marks]); a land that makes no mana is of no colour;
##  - k6-3: the save is version 3 (the card hold and the ban list), 1 to 3
##    read;
##  - the owner's ruling of 2026-10-28 ("Skip it"): under the Classic MTG
##    rules a dungeon never holds a treasure the adventure's ban list bans —
##    another of the 28 instead ([method
##    AdventurePlayer.treasures_by_the_ban_list]).

const MIND_TWIST := 14

var player: AdventurePlayer


func before_each() -> void:
	CardRegistry.ensure_loaded()
	player = _hero(AdventurePlayer.HOLD_UNLIMITED)


func after_each() -> void:
	AdventureSetup.forget()
	RuledTowns.forget()
	CardValue.forget()
	CardShop.forget()


func _record(hold: String, rule := AdventurePlayer.RULE_MEANT, bans := ClassicBans.DEFAULT,
		seed_text := "12345") -> Dictionary:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = seed_text
	setup.card_hold = hold
	setup.card_rule = rule
	setup.ban_list = bans
	return setup.resolve({})


func _hero(hold: String, rule := AdventurePlayer.RULE_MEANT, bans := ClassicBans.DEFAULT,
		seed_text := "12345") -> AdventurePlayer:
	var record := _record(hold, rule, bans, seed_text)
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## The bag: [param before] cards in no deck, then [param in_use] of
## [param card_name] in the deck in use.
func _bag(before: int, in_use: int, card_name := "Grizzly Bears") -> void:
	player.cards = []
	for i in before:
		player.cards.append({"card": "Mountain", "decks": []})
	for i in in_use:
		player.cards.append({"card": card_name, "decks": [player.current_deck]})


func _town(kind := ShandalarWorld.TOWN) -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == kind:
			return slot
	return -1


# ---------------------------------------------------------------- k1-3 --

## 1997's own loop, for the comparison: `rand(bag)` until one of [param places].
func _loop_1997(dice: MsvcRandom, bag: int, places: Array[int]) -> int:
	var at := dice.below(bag)
	while not at in places:
		at = dice.below(bag)
	return at


func test_within_reach_the_draw_is_1997_s_die_for_die() -> void:
	for seed_value in [1, 7, 4242, 0x7FFF1234]:
		for bag in [500, 640, 0x8000]:
			var places: Array[int] = [3, 41, bag - 1, bag / 2]
			var ours := MsvcRandom.new(seed_value)
			var theirs := MsvcRandom.new(seed_value)
			assert_eq(ours.place_among(bag, places), _loop_1997(theirs, bag, places), "seed %d, bag %d" % [seed_value, bag])
			assert_eq(ours.state, theirs.state, "the same dice spent: seed %d, bag %d" % [seed_value, bag])
	assert_eq(MsvcRandom.new(5).place_among(500, [] as Array[int]), -1, "nothing to draw")
	var one := MsvcRandom.new(5)
	assert_eq(one.below_wide(500), MsvcRandom.new(5).below(500), "below the reach: one draw, 1997's")


func test_past_the_reach_every_place_can_come() -> void:
	var dice := MsvcRandom.new(99)
	var seen := {}
	for n in 400:
		var at := dice.place_among(40000, [32768, 39999] as Array[int])
		assert_true(at in [32768, 39999], "one of the places: %d" % at)
		seen[at] = true
	assert_eq(seen.size(), 2, "both")
	var high := 0
	for n in 2000:
		high = maxi(high, dice.below_wide(40000))
	assert_gt(high, 32767, "a wide draw passes 32767")


func test_a_meeting_s_stake_from_a_bag_past_32768_cards_ends() -> void:
	_bag(33000, 3)
	var meeting := {}
	CreatureMeeting._draw_hero_ante(player, meeting, 3)
	assert_eq((meeting["hero_ante"] as Array).size(), 3, "three cards staked")
	for at in meeting["hero_ante_at"]:
		assert_gte(int(at), 33000, "from the deck in use, past the reach")
	var places: Array = meeting["hero_ante_at"]
	var apart := {}
	for at in places:
		apart[at] = true
	assert_eq(apart.size(), 3, "three copies, none twice")


func test_a_room_duel_s_stake_from_a_bag_past_32768_cards_ends() -> void:
	_bag(33000, 2)
	var duel := {"rules": 0, "color": 1}
	assert_true(DungeonDuels.draw_stake(player, duel))
	assert_eq(duel["hero_ante"], ["Grizzly Bears"] as Array[String])
	assert_gte(int((duel["hero_ante_at"] as Array)[0]), 33000)


func test_the_dungeon_s_dice_from_a_bag_past_32768_cards_end() -> void:
	_bag(33000, 2)
	var board := DungeonBoard.new()
	board.cells.resize(DungeonBoard.CELLS)
	board.cells.fill(0)
	board.depth.resize(DungeonBoard.CELLS)
	board.depth.fill(0)
	for at in [DungeonBoard.ENTRANCE, DungeonBoard.START]:
		board.cells[at.x * DungeonBoard.HEIGHT + at.y] = DungeonBoard.OPEN
	board.index = 7
	board.color = int(player.world.encounters[7]["color"])
	board.rules = 0
	board.difficulty = player.difficulty
	board.monsters = [1, 2, 3, 4, 5] as Array[int]
	var cell := Vector2i(8, 11)
	var cards := 0
	for start in 60:
		board.cells[cell.x * DungeonBoard.HEIGHT + cell.y] = DungeonBoard.OPEN | (DungeonBoard.DICE << DungeonBoard.EVENT_SHIFT)
		board.hero = DungeonBoard.START
		board.pending = DungeonBoard.NOWHERE
		board.reveal(board.hero)
		board.step(DungeonBoard.UP_RIGHT)
		board.dice = MsvcRandom.new(start)
		var got := board.roll_dice(player)
		if String(got.get("card", "")) != "":
			assert_eq(got["card"], "Grizzly Bears", "the deck's creature")
			cards += 1
	assert_gt(cards, 0, "the coin gave a card some times, and the draw ended")


# ---------------------------------------------------------------- k6-1 --

## The stake as the walk went before the bag could pass 500 (the class doc
## of [RuledTowns]): over 1997's 500 slots.
func _walk_1997(slot: int) -> Array[int]:
	var usable := CreatureMeeting.usable_cards(player)
	var places: Array[int] = []
	var count := mini(RuledTowns.stake_count(player.world, slot), usable.size())
	var seed := int(player.world.sites[slot]["y"])
	var steps := 0
	while places.size() < count and steps < 500 * (count + 1):
		var at := posmod(seed, 500)
		seed += 7
		steps += 1
		if at in usable and not at in places:
			places.append(at)
	return places


func test_a_ruled_town_stakes_from_places_past_the_500th() -> void:
	_bag(520, 40)
	var town := _town()
	var count := RuledTowns.stake_count(player.world, town)
	var staked := RuledTowns.stake(player, town)
	assert_eq((staked["names"] as Array).size(), count, "the town's count, from the deck in use")
	for at in staked["places"]:
		assert_gte(int(at), 520)
	TownStatus.take(player.world, town, 2)
	var entry := RuledTowns.enter(player, town)
	assert_false(bool(entry["no_ante"]))
	assert_eq((entry["hero_ante"] as Array).size(), count, "staked at the entry")
	var met := RuledTowns.meeting(player, entry)
	var report := DuelReport.new()
	report.finished = true
	report.winner = 1
	report.result = RuledTowns.LOST
	var out := RuledTowns.settle(player, met, report)
	assert_eq((out["lost"] as Array).size(), count, "a loss costs them")
	assert_eq(player.cards.size(), 560 - count)


func test_the_walk_is_1997_s_within_its_limit() -> void:
	player = _hero(AdventurePlayer.HOLD_1997)
	assert_eq(RuledTowns.walked(player), 500)
	for kind in [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]:
		var slot := _town(kind)
		assert_eq(RuledTowns.stake(player, slot)["places"], _walk_1997(slot), "the first deck, site %d" % slot)
	_bag(300, 200)
	for kind in [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]:
		var slot := _town(kind)
		assert_eq(RuledTowns.stake(player, slot)["places"], _walk_1997(slot), "a full bag, site %d" % slot)
	_bag(600, 100)
	assert_eq(RuledTowns.walked(player), 701, "700 cards: one slot more, 7 does not divide it")


# ---------------------------------------------------------------- k6-2 --

## The 1997 table set aside: every card read off itself.
func _without_table() -> void:
	CardValue.forget()
	CardShop.forget()
	CardValue._imported = {}
	CardValue._imported_read = true
	CardValue._read_at = CardRegistry.revision


func _stocked() -> Array[String]:
	var out: Array[String] = []
	for row in CardShop.stock():
		out.append(String(row["name"]))
	return out


func test_the_base_sets_are_read_off_the_printings() -> void:
	assert_eq(CardValue.expansion("Lightning Bolt"), CardValue.FOURTH_EDITION)
	assert_eq(CardValue.expansion("Faerie Dragon"), CardValue.ASTRAL)
	assert_eq(CardValue.expansion("Giant Badger"), CardValue.CAME_WITH_THE_GAME)
	assert_eq(CardValue.expansion("Clone"), CardValue.OTHER_SET, "Unlimited's, not Fourth Edition's")
	assert_true(CardValue.is_base("Faerie Dragon"))
	assert_false(CardValue.is_base("Clone"))
	assert_eq(CardValue.named_marks("Ironclaw Orcs"), CardValue.POWER)
	assert_eq(CardValue.named_marks("Junún Efreet"), CardValue.KEPT_BACK)
	assert_eq(CardValue.named_marks("Black Lotus"), CardValue.TREASURE | CardValue.POWER)
	assert_eq(CardValue.named_marks("Lightning Bolt"), 0)


func test_without_the_table_a_shop_stocks_what_1997_s_did() -> void:
	_without_table()
	var names := _stocked()
	for card_name in ["Black Vise", "Channel", "Mana Vault", "Strip Mine", "Mishra's Factory",
			"Bronze Tablet", "Rebirth", "Tempest Efreet", "Faerie Dragon", "Whimsy", "Giant Badger",
			"Aswan Jaguar", "Goblin Polka Band", "Sewers of Estark", "Oasis"]:
		assert_true(card_name in names, card_name + ": sold in 1997")
	for card_name in ["Clone", "Icy Manipulator", "Juggernaut", "Lich", "Kudzu", "Psionic Blast",
			"Sinkhole", "Junún Efreet", "Ironclaw Orcs", "Sol Ring", "Mind Twist", "Bazaar of Baghdad",
			"Mountain"]:
		assert_false(card_name in names, card_name + ": never sold in 1997")


func test_without_the_table_a_land_that_makes_no_mana_is_never_drawn() -> void:
	_without_table()
	for card_name in ["Oasis", "Bazaar of Baghdad", "Island of Wak-Wak"]:
		assert_eq(int(CardValue.facts(CardRegistry.get_card(card_name))["color"]), 0, card_name + ": no colour")
	assert_eq(int(CardValue.facts(CardRegistry.get_card("Strip Mine"))["color"]), CardValue.COLORLESS)
	assert_eq(int(CardValue.facts(CardRegistry.get_card("Mountain"))["color"]), 16)
	var city := _town(ShandalarWorld.CITY)
	var rules := CardShop._draw_rules(player, city)
	var dice := MsvcRandom.new(7)
	var seen := {}
	for i in 3000:
		seen[CardShop._draw(2, false, dice, rules)] = true
	assert_true(seen.has("Mishra's Factory") or seen.has("Strip Mine"), "a land of the program's in a rare place")
	assert_false(seen.has("Oasis"), "no colour at all: never sold")


func test_ironclaw_orcs_is_special_without_the_table_as_with_it() -> void:
	_without_table()
	assert_eq(CardShop.shop_rarity(CardValue.facts(CardRegistry.get_card("Ironclaw Orcs"))), 4)


# ---------------------------------------------------------------- k6-3 --

func test_a_save_is_version_3_and_versions_1_and_2_still_read() -> void:
	player.ban_list = ClassicBans.OLD
	var data: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	assert_eq(int(data["version"]), 3, "the card hold and the ban list: 0.50.64 reads up to 2 and refuses it")
	var back := AdventurePlayer.from_dict(data)
	assert_eq([back.card_hold, back.ban_list], [AdventurePlayer.HOLD_UNLIMITED, ClassicBans.OLD], "carried")
	for version in [1, 2]:
		data["version"] = version
		assert_not_null(AdventurePlayer.from_dict(data), "version %d reads" % version)
	data["version"] = 4
	assert_null(AdventurePlayer.from_dict(data), "a newer one does not")


# ------------------------------------- the owner's ruling: banned treasures --

func _held(world: ShandalarWorld) -> Array:
	var out := []
	for slot in world.encounters:
		out.append(((slot as Dictionary).get("cards", []) as Array).duplicate())
	return out


func _holds(world: ShandalarWorld, index: int) -> bool:
	for cards in _held(world):
		if index in cards:
			return true
	return false


func test_a_banned_treasure_is_never_placed_under_the_classic_rules() -> void:
	for bans in [ClassicBans.OLD, ClassicBans.BOTH]:
		for seed_text in ["12345", "4242", "777"]:
			var record := _record(AdventurePlayer.HOLD_1997, AdventurePlayer.RULE_CLASSIC, bans, seed_text)
			var made_1997 := AdventureSetup.make_world(record)
			assert_true(_holds(made_1997, MIND_TWIST), "control: 1997 places all 28")
			var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
			assert_false(_holds(hero.world, MIND_TWIST), "%s, %s: no Mind Twist in a dungeon" % [bans, seed_text])
			var was := _held(made_1997)
			var now := _held(hero.world)
			for e in was.size():
				assert_eq(now[e].size(), was[e].size(), "as many treasures")
				for i in was[e].size():
					if was[e][i] == MIND_TWIST:
						var instead := int(now[e][i])
						assert_false(ClassicBans.is_banned(String(ShandalarWorld.DUNGEON_CARDS[instead][1]), bans),
							"another of the 28 the list allows")
						assert_eq(now[e].count(instead), 1, "not one the dungeon holds already")
					else:
						assert_eq(now[e][i], was[e][i], "every other treasure where 1997 put it")
			var again := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
			assert_eq(_held(again.world), now, "the same world and list: the same dungeons")


func test_modern_and_the_other_card_rules_keep_1997_s_dungeons() -> void:
	var cases := [[AdventurePlayer.RULE_CLASSIC, ClassicBans.MODERN], [AdventurePlayer.RULE_MEANT, ClassicBans.OLD],
		[AdventurePlayer.RULE_SHIPPED, ClassicBans.BOTH]]
	for case in cases:
		var record := _record(AdventurePlayer.HOLD_1997, String(case[0]), String(case[1]))
		var made_1997 := AdventureSetup.make_world(record)
		var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
		assert_eq(_held(hero.world), _held(made_1997), "%s, %s: 1997's placement" % case)
		assert_true(_holds(hero.world, MIND_TWIST))


func test_a_classic_save_from_before_loses_its_banned_treasure_on_loading() -> void:
	var record := _record(AdventurePlayer.HOLD_1997, AdventurePlayer.RULE_CLASSIC, ClassicBans.OLD)
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	var now := _held(hero.world)
	var data: Dictionary = JSON.parse_string(JSON.stringify(hero.to_dict()))
	var made_1997 := AdventureSetup.make_world(record)
	var slots: Array = (data["world"] as Dictionary)["encounters"]
	for e in slots.size():
		(slots[e] as Dictionary)["cards"] = (made_1997.encounters[e] as Dictionary)["cards"].duplicate()
	var back := AdventurePlayer.from_dict(data)
	assert_false(_holds(back.world, MIND_TWIST), "replaced on loading")
	assert_eq(_held(back.world), now, "as the Embark replaces it")
	hero.ban_list = ClassicBans.MODERN
	data = JSON.parse_string(JSON.stringify(hero.to_dict()))
	slots = (data["world"] as Dictionary)["encounters"]
	for e in slots.size():
		(slots[e] as Dictionary)["cards"] = (made_1997.encounters[e] as Dictionary)["cards"].duplicate()
	assert_true(_holds(AdventurePlayer.from_dict(data).world, MIND_TWIST), "Modern: kept")
