extends GutTest
## THE DUELS INSIDE A CASTLE OR A DUNGEON (part C, W2, 2026-10-27):
## [DungeonDuels], headless, against hand-made run records shaped as the
## board's (c2 spec §12.5) — the ban per rule bit (j2: gold black cards
## barred, Black Lotus allowed), the fair deck under a ban (i2: the least
## counted after the ban, allowed basics only), the stake from allowed cards
## only (f2), the castle's minions (every slot, difficulty and colour), the
## words, the cards in play, the lives (a dungeon carries its losses, a
## castle's duels each start fresh — a1 —, the world's gifts spent only by
## the duel that uses them — d2), the creature's life and config, and what a
## duel leaves (a draw no result — g3b). The duels played to a result are in
## test_pc_w2_dungeon_headless.gd.

var base: Dictionary
var player: AdventurePlayer


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Delver"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "31337"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.monsters = []
	player.dice = 4242
	player.clear_duel_gifts()


## The deck in use made of [param names] (and nothing else owned).
func _deck(names: Array) -> void:
	player.cards = []
	for card_name in names:
		player.cards.append({"card": String(card_name), "decks": [0]})
	player.current_deck = 0


## [param count] copies of [param card_name].
func _copies(card_name: String, count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append(card_name)
	return out


## A hand-made run record (c2 spec §12.5) of slot [param index].
func _run(index: int, rules: int, color: int, monsters: Array, effect := -1) -> Dictionary:
	return {"index": index, "castle": index < 5, "color": color, "rules": rules,
		"monsters": monsters, "life_pool": 0, "dice_card": "", "card_in_effect": effect}


## Exactly [param count] mana links that count.
func _links(count: int) -> void:
	var world := player.world
	for slot in world.sites.size():
		TownStatus.put(world, slot, TownStatus.LINKED, false)
		TownStatus.release(world, slot)
	var made := 0
	for slot in world.sites.size():
		if made < count and TownStatus.is_town(world, slot):
			TownStatus.put(world, slot, TownStatus.LINKED)
			made += 1
	assert_eq(player.mana_links(), count, "control: the links")


func _report(result: int, start := 10, end := 10) -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = result
	report.winner = {1: 0, 0: 1}.get(result, -1)
	report.lives_start = [start, 20] as Array[int]
	report.lives_end = [end, 0] as Array[int]
	return report


func _row(creature_name: String) -> int:
	var row := CreatureBook.row_named(creature_name)
	assert_gt(row, 0, "control: %s is a row" % creature_name)
	return row


# --------------------------------------------------------------- the ban --

func test_no_instants_bars_instants_and_interrupts() -> void:
	var rules := DungeonDuels.NO_INSTANTS | DungeonDuels.CARRY
	for card_name in ["Lightning Bolt", "Dark Ritual", "Counterspell", "Giant Growth"]:
		assert_true(DungeonDuels.bars(card_name, rules, 3), card_name)
	for card_name in ["Grizzly Bears", "Fireball", "Sol Ring", "Forest", "Gloom"]:
		assert_false(DungeonDuels.bars(card_name, rules, 3), card_name)


func test_no_artifacts_bars_artifact_creatures_too() -> void:
	var rules := DungeonDuels.NO_ARTIFACTS | DungeonDuels.CARRY
	for card_name in ["Sol Ring", "Juggernaut", "Black Lotus", "Mox Jet"]:
		assert_true(DungeonDuels.bars(card_name, rules, 1), card_name)
	for card_name in ["Grizzly Bears", "Lightning Bolt", "Swamp", "Badlands"]:
		assert_false(DungeonDuels.bars(card_name, rules, 1), card_name)


func test_no_black_cards_bars_every_black_card_but_the_colourless() -> void:
	var rules := DungeonDuels.NO_COLOR | DungeonDuels.CARRY
	# [ours: 1997 slip j2] gold black cards barred too; the colours the
	# card's own — a land's by its land types.
	for card_name in ["Dark Ritual", "Hypnotic Specter", "Swamp", "Nebuchadnezzar",
			"Sol'kanar the Swamp King", "Badlands"]:
		assert_true(DungeonDuels.bars(card_name, rules, 1), card_name)
	# Black Lotus and Mox Jet are colourless cards (1997's table coloured
	# them); the other colours stay.
	for card_name in ["Black Lotus", "Mox Jet", "Mountain", "Lightning Bolt", "Sol Ring",
			"Grizzly Bears", "Sedge Troll"]:
		assert_false(DungeonDuels.bars(card_name, rules, 1), card_name)
	assert_true(DungeonDuels.bars("Lightning Bolt", rules, 4), "red: the red cards")
	assert_true(DungeonDuels.bars("Mountain", rules, 4), "red: its basic land")
	assert_false(DungeonDuels.bars("Swamp", rules, 4))


func test_the_other_rules_bar_nothing() -> void:
	for rules in [DungeonDuels.CARRY, DungeonDuels.FRESH, DungeonDuels.ONE_DECK, 0x03, 0x100, 0x200, 0]:
		for card_name in ["Dark Ritual", "Sol Ring", "Juggernaut", "Swamp", "Lightning Bolt", "Black Lotus"]:
			assert_false(DungeonDuels.bars(card_name, int(rules), 1), "%s under 0x%x" % [card_name, rules])
	assert_false(DungeonDuels.bars("No Such Card Anywhere", 0xF0, 1), "an unknown card is never barred")


func test_forbidden_lists_each_copy_of_the_deck_in_use() -> void:
	_deck(["Dark Ritual", "Dark Ritual", "Swamp", "Mountain", "Lightning Bolt", "Nebuchadnezzar"])
	player.cards.append({"card": "Hypnotic Specter", "decks": [1]})
	var run := _run(7, 0x11, 1, [1, 2, 3, 4, 5])
	assert_eq(DungeonDuels.forbidden(player, run),
		["Dark Ritual", "Dark Ritual", "Swamp", "Nebuchadnezzar"] as Array[String],
		"one per copy, the deck in use only")


# ---------------------------------------------------- the deck and the stake --

func test_the_least_is_counted_after_the_ban_with_allowed_basics() -> void:
	# [ours: 1997 slip i2] a mono-black deck in a "No black cards" dungeon.
	var names := _copies("Swamp", 16) + _copies("Dark Ritual", 4) + _copies("Hypnotic Specter", 4) \
		+ _copies("Grizzly Bears", 4) + _copies("Lightning Bolt", 2)
	_deck(names)
	player.difficulty = 1
	var run := _run(8, 0x11, 1, [1, 2, 3, 4, 5])
	var duel := DungeonDuels.setup(player, run, 0)
	var deck := DungeonDuels.hero_deck(player, duel)
	assert_eq(deck.size(), CreatureMeeting.DECK_LEAST[1], "35 after the ban")
	for card_name in deck:
		assert_false(DungeonDuels.bars(String(card_name), 0x11, 1), "allowed: %s" % card_name)
	assert_eq(deck.count("Grizzly Bears"), 4)
	assert_eq(deck.count("Lightning Bolt"), 2)
	assert_eq(deck.count("Swamp"), 0, "no Swamp padded in")
	var dice := player.dice
	assert_eq(DungeonDuels.hero_deck(player, duel), deck, "asked again: the same deck")
	assert_eq(player.dice, dice, "the dice drawn once")


func test_without_a_ban_the_padding_is_1997_s() -> void:
	_deck(_copies("Forest", 10) + _copies("Grizzly Bears", 8))
	player.difficulty = 2
	var run := _run(9, DungeonDuels.CARRY, 3, [1, 2, 3, 4, 5])
	var duel := DungeonDuels.setup(player, run, 1)
	var other := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	var deck := DungeonDuels.hero_deck(player, duel)
	assert_eq(deck, CreatureMeeting.padded_deck(other, other.deck_cards()), "the meeting's own padding")
	assert_eq(player.dice, other.dice, "the same dice")
	assert_eq(deck.size(), 40)


func test_a_deck_big_enough_after_the_ban_is_not_padded() -> void:
	_deck(_copies("Forest", 20) + _copies("Grizzly Bears", 20) + _copies("Sol Ring", 4))
	player.difficulty = 3
	var run := _run(9, DungeonDuels.NO_ARTIFACTS | DungeonDuels.CARRY, 3, [1, 2, 3, 4, 5])
	var dice := player.dice
	var deck := DungeonDuels.hero_deck(player, DungeonDuels.setup(player, run, 0))
	assert_eq(deck.size(), 40)
	assert_false(deck.has("Sol Ring"))
	assert_eq(player.dice, dice, "no padding, no dice")


func test_the_stake_is_one_allowed_non_basic_card() -> void:
	_deck(_copies("Swamp", 10) + _copies("Dark Ritual", 4) + _copies("Grizzly Bears", 2) + ["Sol Ring"])
	var run := _run(10, 0x11, 1, [1, 2, 3, 4, 5])
	for seed_value in [1, 77, 4242, 99991, 123456]:
		player.dice = int(seed_value)
		var duel := DungeonDuels.setup(player, run, 0)
		assert_true(DungeonDuels.draw_stake(player, duel))
		var staked: Array = duel["hero_ante"]
		assert_eq(staked.size(), 1, "one card")
		assert_true(String(staked[0]) in ["Grizzly Bears", "Sol Ring"],
			"[ours: 1997 slip f2] never a banned or basic card: %s" % staked[0])
		var at := int((duel["hero_ante_at"] as Array)[0])
		assert_eq(String(player.cards[at]["card"]), String(staked[0]), "its place in the bag")
	player.dice = 4242
	var one := DungeonDuels.setup(player, run, 0)
	DungeonDuels.draw_stake(player, one)
	player.dice = 4242
	var two := DungeonDuels.setup(player, run, 0)
	DungeonDuels.draw_stake(player, two)
	assert_eq(one["hero_ante"], two["hero_ante"], "the same dice, the same card")


func test_every_card_banned_stakes_nothing_but_plays() -> void:
	_deck(_copies("Swamp", 10) + _copies("Dark Ritual", 4))
	var run := _run(10, 0x11, 1, [1, 2, 3, 4, 5])
	var duel := DungeonDuels.setup(player, run, 0)
	var dice := player.dice
	assert_true(DungeonDuels.draw_stake(player, duel), "no game over: there are cards to stake")
	assert_eq(duel["hero_ante"], [] as Array[String], "the lead's reading: nothing staked")
	assert_false(bool(duel["no_ante"]))
	assert_eq(player.dice, dice)
	var config := DungeonDuels.duel_config(player, run, duel)
	assert_eq(config.ante_cards, [[], []])
	assert_eq(config.ante_extras, [[], []])


func test_no_card_to_stake_is_the_game_over() -> void:
	_deck(_copies("Forest", 20))
	player.cards.append({"card": "Grizzly Bears", "decks": [1]})
	var duel := DungeonDuels.setup(player, _run(6, DungeonDuels.CARRY, 3, [1, 2, 3, 4, 5]), 0)
	assert_false(DungeonDuels.draw_stake(player, duel), "ExitIfNoUsableDeckCards")
	assert_true(bool(duel["no_ante"]))


# ------------------------------------------------------------- the setup --

func test_the_castle_minions_by_slot_difficulty_and_colour() -> void:
	# c2 spec §2.4, slot × difficulty → the minion's index, −1 none.
	var table := [[-1, -1, -1, 0], [-1, -1, 0, 1], [-1, 0, 1, 2], [0, 1, 2, 2], [1, 2, 2, 2]]
	for color in range(1, 6):
		var three: Array = CreatureBook.MINIONS[color]
		for slot in 5:
			for d in 4:
				var want := int(table[slot][d])
				var got := DungeonDuels.minion(true, color, slot, d)
				assert_eq(got, "" if want < 0 else String(three[want]),
					"colour %d slot %d difficulty %d" % [color, slot, d])
				assert_eq(DungeonDuels.minion(false, color, slot, d), "", "a dungeon never has one")


func test_the_words_word_for_word() -> void:
	player.difficulty = 1
	var lich := _row("Greater Lich")
	var castle := DungeonDuels.setup(player, _run(0, 3, 1, [1, 2, 3, 4, lich], 100), 4)
	assert_eq(castle["words"], ["Exploring the Castle...", "you encounter a Greater Lich!", "",
		"Greater Lich has the spell Hypnotic Specter!", "(Gloom starts in play!)"] as Array[String])
	player.difficulty = 0
	castle = DungeonDuels.setup(player, _run(0, 3, 1, [1, 2, 3, 4, lich], 246), 4)
	assert_eq(castle["minion"], "Carrion Ants")
	assert_eq((castle["words"] as Array)[3], "Greater Lich has the spell Carrion Ants!")
	var druid := _row("Druid")
	var dungeon := DungeonDuels.setup(player, _run(9, 1, 3, [druid, 2, 3, 4, 5], 114), 0)
	assert_eq(dungeon["words"], ["Exploring the Dungeon...", "you encounter a Druid!",
		"(Howling Mine starts in play!)"] as Array[String])
	dungeon = DungeonDuels.setup(player, _run(9, 1, 3, [druid, 2, 3, 4, 5], -1), 0)
	assert_eq(dungeon["words"], ["Exploring the Dungeon...", "you encounter a Druid!"] as Array[String])
	assert_eq(DungeonDuels.ENCOUNTER_CASTLE, "Exploring the Castle...\nyou encounter %s!\n")
	assert_eq(DungeonDuels.BOOTED,
		"You are unceremoniously booted from\nthe stronghold of the Mighty %s!\n")


func test_the_setup_reads_the_record_and_draws_no_dice() -> void:
	var druid := _row("Druid")
	var run := _run(11, 0x41, 3, [druid, _row("Elvish Magi"), 3, 4, 5], 15)
	var dice := player.dice
	var duel := DungeonDuels.setup(player, run, 1)
	assert_eq(player.dice, dice, "no dice")
	assert_eq([duel["index"], duel["castle"], duel["color"], duel["rules"], duel["slot"], duel["final"],
		duel["row"], duel["minion"], duel["effect"]],
		[11, false, 3, 0x41, 1, false, _row("Elvish Magi"), "", "Birds of Paradise"])
	assert_true(DungeonDuels.setup(player, _run(11, 1, 3, [0, 0, 0, 0, 0]), 2).is_empty(),
		"an empty slot: no duel")
	assert_true(DungeonDuels.setup(player, run, 5).is_empty())
	var castle := DungeonDuels.setup(player, _run(2, 3, 3, [1, 2, 3, 4, 0]), 4)
	assert_eq(int(castle["row"]), CreatureBook.castle_row(3), "the castle's wizard, the Great Druid")
	assert_true(bool(castle["final"]))
	assert_eq([DungeonDuels.slot_of(3), DungeonDuels.slot_of(6), DungeonDuels.slot_of(15),
		DungeonDuels.slot_of(7), DungeonDuels.slot_of(1)], [0, 3, 4, -1, -1])
	run["code"] = 4
	assert_eq(DungeonDuels.setup_room(player, run), duel, "the room's code names the creature")
	run["code"] = 7
	assert_true(DungeonDuels.setup_room(player, run).is_empty(), "a treasure: no duel")


func test_the_card_in_effect_and_rules_fall_back_to_the_world_slot() -> void:
	var slot: Dictionary = player.world.encounters[0]
	var run := {"index": 0, "castle": true, "color": 1, "monsters": [1, 2, 3, 4, 7], "life_pool": 0,
		"dice_card": ""}
	var duel := DungeonDuels.setup(player, run, 4)
	assert_eq(int(duel["rules"]), int(slot["rules"]))
	assert_eq(int(duel["rules"]) & 3, 3, "every castle: 0x01 and 0x02")
	assert_eq(String(duel["effect"]),
		String(WorldClues.EFFECT_CARDS[WorldGenerator.MANA_CASTLE_EFFECTS[0][player.difficulty]]))


## A run record held as an object with the contract's fields (the board's
## own class may be one).
class RunRecord:
	extends RefCounted
	var index := 12
	var castle := false
	var color := 4
	var rules := 0x81
	var monsters: Array[int] = [32, 33, 34, 35, 36]
	var life_pool := 2
	var dice_card := "Grizzly Bears"


func test_a_run_record_object_is_read_and_written() -> void:
	_deck(_copies("Mountain", 10) + _copies("Hill Giant", 8) + _copies("Lightning Bolt", 4))
	var run := RunRecord.new()
	var duel := DungeonDuels.setup(player, run, 0)
	assert_eq(int(duel["row"]), 32)
	assert_eq(int(duel["color"]), 4)
	assert_eq(int(duel["rules"]), 0x81)
	assert_eq(DungeonDuels.life_parts(player, run)["pool"], 2)
	DungeonDuels.draw_stake(player, duel)
	DungeonDuels.settle(player, run, duel, _report(DungeonDuels.WON, 12, 9))
	assert_eq(run.life_pool, -1, "written back: 2 + 9 − 12")
	assert_eq(run.dice_card, "", "the dice's card spent")


# ----------------------------------------------------------- the config --

func test_the_config_whole() -> void:
	_deck(_copies("Forest", 12) + _copies("Grizzly Bears", 6) + _copies("Giant Growth", 4))
	player.difficulty = 2
	player.playmat = {"color": "green", "type": "Pattern"}
	player.next_duel_first_move = true
	var druid := _row("Druid")
	var run := _run(13, 0x81, 3, [druid, 2, 3, 4, 5], 15)
	var duel := DungeonDuels.setup(player, run, 0)
	assert_true(DungeonDuels.draw_stake(player, duel))
	var config := DungeonDuels.duel_config(player, run, duel)
	assert_eq(config.decks[1], CreatureDeck.for_meeting(druid, 0), "the creature's maindeck only")
	assert_eq((config.decks[0] as Array).size(), 40)
	assert_false((config.decks[0] as Array).has("Giant Growth"), "no instants here")
	assert_eq(config.ante_cards[0], duel["hero_ante"], "the stake lifted out of the hero's deck")
	assert_eq(config.ante_cards[1], [], "the creature stakes nothing")
	assert_eq(config.ante_extras, [[], []])
	assert_eq(config.first_player, 0, "the first-move gift")
	assert_eq(config.mulligan_rule, MtgGame.MULLIGAN_1997)
	assert_true(config.ai_random_play_or_draw)
	assert_null(config.pilots[0])
	assert_eq((config.pilots[1] as AiProfile).profile_name, AiProfile.sorcerer().profile_name)
	assert_eq(config.player_names[1], CreatureBook.duel_name(druid))
	assert_eq(config.portraits[1], CreatureBook.face_id(druid))
	assert_eq(config.territories[0], {"color": "green", "type": "Pattern"}, "the hero's playmat")
	assert_eq(config.start_in_play, [[], ["Birds of Paradise"]])
	assert_ne(config.rng_seed, 0)
	player.next_duel_first_move = false
	assert_eq(DungeonDuels.duel_config(player, run, duel).first_player, -1, "else 1997's coin")


func test_the_cards_in_play_in_order() -> void:
	_deck(_copies("Swamp", 12) + _copies("Hypnotic Specter", 6) + ["Sol Ring", "Juggernaut"])
	player.difficulty = 3
	player.next_duel_card = "King Suleiman"
	var lich := _row("Greater Lich")
	var run := _run(0, 3, 1, [1, 2, 3, 4, lich], 661)
	run["dice_card"] = "Juggernaut"
	var duel := DungeonDuels.setup(player, run, 4)
	DungeonDuels.draw_stake(player, duel)
	var config := DungeonDuels.duel_config(player, run, duel)
	assert_eq(config.start_in_play, [["King Suleiman", "Juggernaut"], ["Hypnotic Specter", "Greed"]],
		"the world's card and the dice's; the minion, then the card in effect")
	# A dice card the rules bar is left out (a guard: the board's dice never
	# give one).
	var banned := _run(9, DungeonDuels.NO_ARTIFACTS | 1, 1, [1, 2, 3, 4, 5])
	banned["dice_card"] = "Juggernaut"
	var other := DungeonDuels.setup(player, banned, 0)
	DungeonDuels.draw_stake(player, other)
	assert_eq((DungeonDuels.duel_config(player, banned, other).start_in_play as Array)[0], ["King Suleiman"])


# ------------------------------------------------------------- the lives --

func test_the_dungeon_carries_its_losses() -> void:
	# c2 spec §4's worked example under d2: links 8, the world's carried +2,
	# a wise man's +2 waiting, the dice +3.
	_deck(_copies("Forest", 20) + _copies("Grizzly Bears", 20))
	_links(8)
	player.next_duel_life_carried = 2
	player.next_duel_life = 2
	var run := _run(7, DungeonDuels.CARRY, 3, [22, 23, 24, 25, 26])
	run["life_pool"] = 3
	assert_eq(DungeonDuels.life_parts(player, run),
		{"links": 8, "carried": 2, "gift": 2, "pool": 3, "total": 15})
	var a := DungeonDuels.setup(player, run, 0)
	DungeonDuels.draw_stake(player, a)
	var config := DungeonDuels.duel_config(player, run, a)
	assert_eq(config.lives[0], 15, "room A: [ours: d2] the world's lives gift counts")
	DungeonDuels.settle(player, run, a, _report(DungeonDuels.WON, 15, 9))
	assert_eq(int(run["life_pool"]), -3, "3 + 9 − 15")
	assert_eq([player.next_duel_life, player.next_duel_life_carried], [0, 0], "spent")
	var b := DungeonDuels.setup(player, run, 1)
	DungeonDuels.draw_stake(player, b)
	assert_eq(DungeonDuels.duel_config(player, run, b).lives[0], 5, "room B: 8 − 3")
	DungeonDuels.settle(player, run, b, _report(DungeonDuels.WON, 5, 10))
	assert_eq(int(run["life_pool"]), 2, "the example ends at 2")


func test_a_castle_s_duels_each_start_fresh() -> void:
	# The owner's ruling a1: links 8 — room A 8, won at 3 → 0; room B 8;
	# the dice +2, room C 10; then 0 again.
	_deck(_copies("Swamp", 20) + _copies("Hypnotic Specter", 20))
	_links(8)
	var run := _run(0, DungeonDuels.CARRY | DungeonDuels.FRESH, 1, [36, 37, 38, 39, 7])
	var lives: Array[int] = []
	for step in [[0, 3, 0], [1, 8, 0], [2, 8, 2]]:
		run["life_pool"] = int(run["life_pool"]) + int(step[2])
		var duel := DungeonDuels.setup(player, run, int(step[0]))
		DungeonDuels.draw_stake(player, duel)
		var start := int(DungeonDuels.duel_config(player, run, duel).lives[0])
		lives.append(start)
		DungeonDuels.settle(player, run, duel, _report(DungeonDuels.WON, start, int(step[1])))
		assert_eq(int(run["life_pool"]), 0, "0x02 zeroes after 0x01")
	assert_eq(lives, [8, 8, 10] as Array[int])
	assert_eq(DungeonDuels.pool_after(DungeonDuels.CARRY, 4, 10, 6), 0, "0x01: 4 + 6 − 10")
	assert_eq(DungeonDuels.pool_after(3, 4, 10, 16), 0, "0x02 after 0x01")
	assert_eq(DungeonDuels.pool_after(0x10, 4, 10, 16), 4, "no rule: untouched")


func test_no_floor_on_the_hero_s_life() -> void:
	_links(3)
	var run := _run(7, DungeonDuels.CARRY, 3, [22, 23, 24, 25, 26])
	run["life_pool"] = -5
	assert_eq(DungeonDuels.hero_life(player, run), -2, "0 or less loses at once, as played")


func test_the_creature_s_life() -> void:
	player.difficulty = 2
	var druid := _row("Druid")
	var duel := {"row": druid, "color": 3}
	assert_eq(DungeonDuels.creature_life(player, duel), CreatureBook.tier(druid) + 4, "tier + 2d")
	var invoker := _row("Thought Invoker")
	player.world_magics = ["Sleight of Hand", "Haggler's Coin", "Sword of Resistance"] as Array[String]
	assert_eq(DungeonDuels.creature_life(player, {"row": invoker, "color": 2}),
		CreatureBook.tier(invoker) + 4 + 2, "a henchman: + its World Magics among the first ten")
	var visionary := CreatureBook.castle_row(2)
	player.duel_victories = []
	for i in 3:
		player.log_victory(_row("Seer"), 2)
	for slot in player.world.sites.size():
		TownStatus.release(player.world, slot)
	var ruled := 0
	for slot in player.world.sites.size():
		if ruled < 2 and TownStatus.is_town(player.world, slot):
			TownStatus.take(player.world, slot, 2)
			ruled += 1
	assert_eq(DungeonDuels.creature_life(player, {"row": visionary, "color": 2}),
		20 + 5 * 2 + 10 - 3 + 2 * 2, "the castle's wizard: wins and towns")
	for i in 40:
		player.log_victory(_row("Seer"), 2)
	assert_eq(DungeonDuels.creature_life(player, {"row": visionary, "color": 2}), 5 * 2 + 20, "the floor")


# -------------------------------------------------------------- the end --

func _room(rules := DungeonDuels.CARRY, index := 7, color := 3) -> Array:
	_deck(_copies("Forest", 16) + _copies("Grizzly Bears", 4) + ["Llanowar Elves"])
	var run := _run(index, rules, color, [22, 23, 24, 25, CreatureBook.castle_row(color)])
	var duel := DungeonDuels.setup(player, run, 0)
	assert_true(DungeonDuels.draw_stake(player, duel))
	return [run, duel]


func test_a_room_won_is_cleared_and_written_but_not_logged() -> void:
	var pair := _room()
	var run: Dictionary = pair[0]
	var duel: Dictionary = pair[1]
	run["dice_card"] = "Grizzly Bears"
	player.next_duel_card = "King Suleiman"
	var cards := player.cards.size()
	var wins := player.total_wins()
	var out := DungeonDuels.settle(player, run, duel, _report(DungeonDuels.WON, 10, 7))
	assert_eq(out["outcome"], DungeonDuels.CLEARED)
	assert_eq(out["journal"], "Defeated a Druid")
	var line: Dictionary = player.journal[-1]
	assert_eq([line["event"], line["text"], line["won"], line["row"], line["dungeon"]],
		["duel", "Defeated a Druid", true, 22, 7])
	assert_eq(player.total_wins(), wins, "no victory logged (room wins stay out)")
	assert_eq(player.cards.size(), cards, "no card won, none lost")
	assert_eq(player.next_duel_card, "", "the world's gift spent")
	assert_eq(run["dice_card"], "", "the dice's spent")
	assert_eq(int(run["life_pool"]), -3)
	assert_eq(HeroStats.record(player)["won"], 1, "a win in the record")


func test_a_room_lost_throws_out_and_loses_the_stake() -> void:
	var pair := _room()
	var run: Dictionary = pair[0]
	var duel: Dictionary = pair[1]
	var staked := String((duel["hero_ante"] as Array)[0])
	var copies := player.deck_cards().count(staked)
	var out := DungeonDuels.settle(player, run, duel, _report(DungeonDuels.LOST, 10, 0))
	assert_eq(out["outcome"], DungeonDuels.THROWN_OUT)
	assert_eq(out["lost"], [staked] as Array[String])
	assert_eq(player.deck_cards().count(staked), copies - 1, "the copy staked")
	assert_eq(out["journal"], "Lost to a Druid")
	assert_false(bool(player.journal[-1]["won"]))
	assert_eq(out["booted"], [] as Array[String], "a dungeon: no booted words")
	assert_true(DungeonDuels.ends_visit(String(out["outcome"])))


func test_a_castle_room_lost_boots_the_hero() -> void:
	var pair := _room(3, 2, 3)
	var out := DungeonDuels.settle(player, pair[0], pair[1], _report(DungeonDuels.LOST, 10, 0))
	assert_eq(out["outcome"], DungeonDuels.THROWN_OUT)
	assert_eq(out["booted"], ["You are unceremoniously booted from",
		"the stronghold of the Mighty Green Wizard!"] as Array[String])


func test_a_room_drawn_is_no_result() -> void:
	# [ours: 1997 slip g3, the pool untouched — g3b]
	var pair := _room()
	var run: Dictionary = pair[0]
	var duel: Dictionary = pair[1]
	run["life_pool"] = 4
	var cards := player.cards.duplicate(true)
	var journal := player.journal.size()
	var out := DungeonDuels.settle(player, run, duel, _report(DungeonDuels.DRAWN, 14, 0))
	assert_eq(out["outcome"], DungeonDuels.AGAIN)
	assert_eq(player.cards, cards, "the stake kept")
	assert_eq(player.journal.size(), journal, "nothing written")
	assert_eq(int(run["life_pool"]), 4, "the pool untouched")
	assert_false(DungeonDuels.ends_visit(String(out["outcome"])))
	var unfinished := DuelReport.new()
	unfinished.finished = false
	DungeonDuels.draw_stake(player, duel)
	assert_eq(DungeonDuels.settle(player, run, duel, unfinished)["outcome"], DungeonDuels.AGAIN,
		"an unfinished duel is a draw")


func test_the_castle_s_wizard_won_lost_and_drawn() -> void:
	_deck(_copies("Plains", 16) + _copies("Serra Angel", 4))
	var run := _run(4, 3, 5, [8, 9, 10, 11, 14], 128)
	var journal := player.journal.size()
	var duel := DungeonDuels.setup(player, run, 4)
	DungeonDuels.draw_stake(player, duel)
	var out := DungeonDuels.settle(player, run, duel, _report(DungeonDuels.WON, 10, 4))
	assert_eq(out["outcome"], DungeonDuels.BEATEN)
	assert_eq(player.journal.size(), journal, "the win's journal is CastleWin's")
	DungeonDuels.draw_stake(player, duel)
	var cards := player.cards.size()
	out = DungeonDuels.settle(player, run, duel, _report(DungeonDuels.LOST, 10, 0))
	assert_eq(out["outcome"], DungeonDuels.LEFT)
	assert_eq(player.cards.size(), cards - 1, "the stake lost")
	assert_eq(player.journal.size(), journal, "no journal line")
	assert_eq(out["booted"], [] as Array[String], "no booted words")
	DungeonDuels.draw_stake(player, duel)
	cards = player.cards.size()
	out = DungeonDuels.settle(player, run, duel, _report(DungeonDuels.DRAWN, 10, 0))
	assert_eq(out["outcome"], DungeonDuels.AGAIN, "1.3: pushed back, fought again")
	assert_eq(player.cards.size(), cards)


func test_a_concession_is_a_loss_and_settling_twice_changes_nothing() -> void:
	var pair := _room()
	var run: Dictionary = pair[0]
	var duel: Dictionary = pair[1]
	var cards := player.cards.size()
	var out := DungeonDuels.settle(player, run, duel, _report(DungeonDuels.WON, 10, 10), true)
	assert_eq(int(out["result"]), DungeonDuels.LOST)
	assert_eq(player.cards.size(), cards - 1)
	var again := DungeonDuels.settle(player, run, duel, _report(DungeonDuels.LOST, 10, 0))
	assert_eq(again, out, "the same record")
	assert_eq(player.cards.size(), cards - 1, "no second card lost")
	assert_eq(int(DungeonDuels.settle(player, run, duel, null)["result"]), DungeonDuels.LOST)


func test_the_world_s_gifts_wait_until_a_duel() -> void:
	_deck(_copies("Forest", 16) + _copies("Grizzly Bears", 4))
	player.next_duel_life = 3
	player.next_duel_life_carried = -1
	player.next_duel_card = "King Suleiman"
	player.next_duel_first_move = true
	var run := _run(7, DungeonDuels.CARRY, 3, [22, 23, 24, 25, 26])
	var duel := DungeonDuels.setup(player, run, 0)
	DungeonDuels.draw_stake(player, duel)
	DungeonDuels.duel_config(player, run, duel)
	assert_eq([player.next_duel_life, player.next_duel_life_carried, player.next_duel_card,
		player.next_duel_first_move], [3, -1, "King Suleiman", true], "nothing spent before the duel")
	DungeonDuels.settle(player, run, duel, _report(DungeonDuels.DRAWN))
	assert_eq([player.next_duel_life, player.next_duel_life_carried, player.next_duel_card,
		player.next_duel_first_move], [0, 0, "", false], "spent by the duel that used them")
