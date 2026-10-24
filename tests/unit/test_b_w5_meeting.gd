extends GutTest
## A CREATURE MET (part B, W5, 2026-10-23): [CreatureMeeting], headless —
## the antes drawn, what the creature says and offers by its relation and
## the hero's wins, each choice (the bribe, the riddle, Sleight of Hand, the
## tribute's offers and payments), the duel prepared (the hand modifier, the
## colour filter, the special meeting's events and their odds) and the
## duel it hands to the engine ([method CreatureMeeting.duel_config]: the
## padding, the stakes, the lives, the first move, the cards in play, Mind
## Control, 1997's opening rules). The slips fixed are pinned here, each
## failing without its fix.

var base: Dictionary
var player: AdventurePlayer


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Meeting Goer"
	setup.color = "red"
	setup.difficulty = 0
	setup.walker = "female"
	setup.seed_text = "777"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.monsters = []
	player.monster_timer = 4   # not a special meeting: (4 >> 2) % 3 == 1


## A creature [param row] of colour [param color] in roaming slot
## [param slot], a few units from the hero (or [param at]).
func _creature(row: int, color: int, slot := 0, at := Vector2i(-1, -1)) -> Dictionary:
	var where := at if at.x >= 0 else player.position + Vector2i(8, 0)
	var held := {"slot": slot, "kind": "creature", "creature": row, "x": where.x, "y": where.y,
		"color": color, "heading": 0, "frame": 0}
	player.monsters.append(held)
	return held


## The deck in use made of [param names] (and nothing else owned).
func _deck(names: Array) -> void:
	player.cards = []
	for card_name in names:
		player.cards.append({"card": String(card_name), "decks": [0]})
	player.current_deck = 0


func _plain_deck() -> Array:
	var out: Array = []
	for i in 10:
		out.append("Mountain")
	for i in 4:
		out.append("Lightning Bolt")
	for i in 4:
		out.append("Hill Giant")
	for i in 2:
		out.append("Grizzly Bears")
	return out


func _ids(options: Array) -> Array:
	return options.map(func(o: Array) -> String: return String(o[0]))


## The castle of [param color]'s tile.
func _castle(color: int) -> Vector2i:
	var castle: Dictionary = player.world.encounters[color - 1]
	return Vector2i(int(castle["x"]), int(castle["y"]))


# ---------------------------------------------------------- the meeting --

func test_begin_reads_the_slot_and_draws_both_stakes() -> void:
	_deck(_plain_deck())
	_creature(3, 1)   # a Warlock, black
	var dice := player.dice
	var meeting := CreatureMeeting.begin(player, 0)
	assert_eq(int(meeting["row"]), 3)
	assert_eq(int(meeting["color"]), 1)
	assert_eq(int(meeting["kind"]), CreatureBook.MALE_WIZARD)
	assert_eq(int(meeting["strength"]), 3 + 8 / 2, "S = base + tier / 2")
	assert_eq(int(meeting["bribe"]), 70)
	assert_eq(int(meeting["slot"]), 0)
	assert_ne(player.dice, dice, "the antes are drawn on the adventure's dice")
	var stake: Array = meeting["creature_ante"]
	assert_eq(stake.size(), 1)
	assert_false(String(stake[0]) in CreatureDeck.BASICS)
	assert_ne(String(stake[0]), "Dark Ritual", "the Warlock never antes its signature card")
	var hero: Array = meeting["hero_ante"]
	assert_eq(hero.size(), 1)
	assert_true(String(hero[0]) in ["Lightning Bolt", "Hill Giant", "Grizzly Bears"], "never a basic land")
	var at: int = (meeting["hero_ante_at"] as Array)[0]
	assert_eq(String(player.cards[at]["card"]), String(hero[0]), "the stake's own copy is remembered")


func test_begin_needs_a_creature_in_the_slot() -> void:
	assert_eq(CreatureMeeting.begin(player, 0), {}, "an empty slot")
	player.monsters.append({"slot": 1, "kind": "lair", "x": 100, "y": 100, "color": 2})
	assert_eq(CreatureMeeting.begin(player, 1), {}, "a lair is entered, not met")


func test_every_copy_of_the_deck_in_use_is_staked_alike() -> void:
	_deck(["Forest", "Forest", "Llanowar Elves", "Forest", "Giant Growth"])
	player.cards.append({"card": "Serra Angel", "decks": [1]})   # another deck's: never staked
	var seen := {}
	for n in 300:
		var meeting := CreatureMeeting.meet(player, 1, 1)
		seen[String((meeting["hero_ante"] as Array)[0])] = int(seen.get(String((meeting["hero_ante"] as Array)[0]), 0)) + 1
	assert_eq(seen.keys().size(), 2, "only the deck in use's non-basic cards: %s" % [seen])
	assert_true(seen.has("Llanowar Elves") and seen.has("Giant Growth"))
	assert_between(int(seen["Llanowar Elves"]), 100, 200, "each card alike: %s" % [seen])


func test_no_card_to_stake_is_the_game_over() -> void:
	_deck(["Forest", "Island", "Swamp"])
	player.cards.append({"card": "Serra Angel", "decks": []})   # not in the deck in use
	_creature(1, 1)
	var meeting := CreatureMeeting.begin(player, 0)
	assert_true(bool(meeting["no_ante"]), "ExitIfNoUsableDeckCards: only the deck in use counts")
	assert_eq((meeting["hero_ante"] as Array).size(), 0)
	assert_eq(CreatureMeeting.NO_ANTE[0], "You have no power for even an Ante!")


func test_a_henchman_stakes_nothing_and_only_duels() -> void:
	_deck(_plain_deck())
	_creature(6, 1)   # the Necromancer
	var meeting := CreatureMeeting.begin(player, 0)
	assert_eq((meeting["creature_ante"] as Array).size(), 0, "henchmen ante nothing")
	assert_eq(_ids(CreatureMeeting.options(player, meeting)), ["duel"])
	assert_eq(int(meeting["bribe"]), 0)
	var words := "\n".join(CreatureMeeting.words(player, meeting))
	assert_string_contains(words, "The Evil Black Wizard\nhas sent his")
	var blue := CreatureMeeting.meet(player, 20, 2)   # the Thought Invoker, the Blue Wizardess's
	assert_string_contains("\n".join(CreatureMeeting.words(player, blue)), "has sent her")


# --------------------------------------------------- relation and choices --

func test_the_domain_offers_duel_pay_and_by_the_wins_the_riddle() -> void:
	_deck(_plain_deck())
	player.gold = 1000
	player.world_magics = [] as Array[String]
	_creature(1, 1)
	var meeting := CreatureMeeting.begin(player, 0)
	assert_eq(int(meeting["relation"]), CreatureMeeting.NONE)
	assert_eq(_ids(CreatureMeeting.options(player, meeting)), ["duel", "pay"], "no wins: no riddle")
	assert_eq(CreatureMeeting.words(player, meeting)[0], "Those who enter the domain")
	for i in 2:
		player.log_victory(1, 1)
	meeting = CreatureMeeting.begin(player, 0)
	assert_eq(_ids(CreatureMeeting.options(player, meeting)), ["duel", "pay", "riddle"],
		"2 wins at Apprentice: 2·(0 + 1)")
	player.difficulty = 2
	assert_eq(_ids(CreatureMeeting.options(player, meeting)), ["duel", "pay"], "never above Magician")
	player.difficulty = 0
	player.gold = 39
	assert_eq(_ids(CreatureMeeting.options(player, meeting)), ["duel", "riddle"], "no gold, no bribe")
	player.world_magics = ["Sleight of Hand"] as Array[String]
	assert_eq(_ids(CreatureMeeting.options(player, meeting)), ["duel", "riddle", "change"])


func test_five_wins_bring_tribute_and_the_quest_creature_says_duel() -> void:
	_deck(_plain_deck())
	player.gold = 1000
	for i in 5:
		player.log_victory(1, 1)
	_creature(1, 1)
	var meeting := CreatureMeeting.begin(player, 0)
	assert_eq(_ids(CreatureMeeting.options(player, meeting)), ["tribute"], "no bribe, no riddle from 5 wins")
	assert_eq(CreatureMeeting.words(player, meeting)[0], "The Witches who inhabit the")
	player.quest = {"type": -1, "destination": 3, "giver": 4, "color": 1, "deadline": 99}
	meeting = CreatureMeeting.begin(player, 0)
	var options := CreatureMeeting.options(player, meeting)
	# [ours: 1997 slip — "Accept tribute" from the quest's creature duelled.]
	assert_eq(_ids(options), ["duel"])
	assert_eq(String(options[0][1]), "Duel this Witch.")


func test_near_the_stronghold_only_duels() -> void:
	_deck(_plain_deck())
	player.gold = 1000
	var castle := _castle(1)
	_creature(1, 1, 0, Vector2i(castle.x * 32 + 16 + 64, castle.y * 32 + 16 - 32))
	var meeting := CreatureMeeting.begin(player, 0)
	assert_eq(int(meeting["relation"]), CreatureMeeting.STRONGHOLD, "two tiles off at Apprentice: 0/2 + 2")
	assert_eq(_ids(CreatureMeeting.options(player, meeting)), ["duel"])
	assert_string_contains("\n".join(CreatureMeeting.words(player, meeting)), "Mighty Black Wizard")
	player.monsters = []
	_creature(1, 1, 0, Vector2i(castle.x * 32 + 16 + 96, castle.y * 32 + 16))
	assert_eq(int(CreatureMeeting.begin(player, 0)["relation"]), CreatureMeeting.NONE, "three tiles off")


func test_the_besieger_names_the_town_it_besieges() -> void:
	_deck(_plain_deck())
	var town := 5
	var far := Vector2i(int(player.world.sites[40]["x"]), int(player.world.sites[40]["y"]))
	var held := _creature(8, 5, CreatureMeeting.SIEGE_SLOT, far * 32 + Vector2i(16, 16))
	held["town"] = town
	var meeting := CreatureMeeting.begin(player, CreatureMeeting.SIEGE_SLOT)
	assert_eq(int(meeting["relation"]), CreatureMeeting.SIEGE)
	assert_eq(_ids(CreatureMeeting.options(player, meeting)), ["duel"])
	# [ours: 1997 slip — the town nearest the creature.]
	assert_string_contains("\n".join(CreatureMeeting.words(player, meeting)),
		"Supremacy of %s must..." % WorldNames.site_name(player.world, town))


func test_the_bribe_does_not_hide_for_the_bags_first_card() -> void:
	_deck(["Lightning Bolt", "Mountain", "Mountain"])
	player.gold = 500
	_creature(1, 1)
	var meeting := CreatureMeeting.begin(player, 0)
	assert_eq(meeting["hero_ante_at"], [0], "the stake is the bag's first card")
	# [ours: 1997 slip — `deck_or_card_index != 0` hid the bribe.]
	assert_true("pay" in _ids(CreatureMeeting.options(player, meeting)))
	assert_true(CreatureMeeting.pay(player, meeting))
	assert_eq(player.gold, 460, "10·S, S = 2 + 4 / 2")
	player.gold = 30
	assert_false(CreatureMeeting.pay(player, meeting), "a purse spent since")
	assert_eq(player.gold, 30)


func test_a_riddle_missed_loses_the_staked_copy() -> void:
	player.cards = [{"card": "Hill Giant", "decks": []}, {"card": "Hill Giant", "decks": [0]},
		{"card": "Mountain", "decks": [0]}]
	player.current_deck = 0
	_creature(1, 1)
	var meeting := CreatureMeeting.begin(player, 0)
	assert_eq(meeting["hero_ante_at"], [1], "the deck in use's copy is staked")
	var asked := CreatureMeeting.riddle(player, meeting)
	assert_false(asked.is_empty(), "a riddle from the card pool")
	assert_eq(CreatureMeeting.riddle_answered(player, meeting, true), [] as Array[String])
	assert_eq(player.cards.size(), 3, "right: nothing lost")
	assert_eq(CreatureMeeting.riddle_answered(player, meeting, false), ["Hill Giant"] as Array[String])
	assert_eq(player.cards.size(), 2)
	# [ours: 1997 slip — `RemoveCardFromDeckById` took the bag's first copy,
	# the one in no deck, and left the staked one in the deck.]
	assert_eq(player.cards[0], {"card": "Hill Giant", "decks": []}, "the copy in no deck stays")
	assert_false("Hill Giant" in player.deck_cards(), "the staked copy is the one lost")


func test_a_castle_wizards_three_stakes_are_three_cards() -> void:
	_deck(["Lightning Bolt", "Hill Giant", "Grizzly Bears", "Mountain"])
	for seed in range(1, 40):
		player.dice = seed
		var meeting := CreatureMeeting.meet(player, 7, 1)   # the Greater Lich, kind 12
		var places: Array = meeting["hero_ante_at"]
		assert_eq(places.size(), 3)
		# [ours: 1997 slip — each of the three was drawn from the whole bag.]
		assert_eq({places[0]: 1, places[1]: 1, places[2]: 1}.size(), 3, "never one card twice: %s" % [places])
	_deck(["Lightning Bolt", "Mountain"])
	assert_eq((CreatureMeeting.meet(player, 7, 1)["hero_ante"] as Array).size(), 1, "as many as there are")


func test_sleight_of_hand_changes_the_stake_once() -> void:
	_deck(_plain_deck())
	_creature(1, 1)
	var meeting := CreatureMeeting.begin(player, 0)
	assert_eq(CreatureMeeting.change_ante(player, meeting), "", "not without Sleight of Hand")
	player.world_magics = ["Sleight of Hand"] as Array[String]
	var dice := player.dice
	var card := CreatureMeeting.change_ante(player, meeting)
	assert_true(card in ["Lightning Bolt", "Hill Giant", "Grizzly Bears"])
	assert_ne(player.dice, dice, "drawn again on the dice")
	assert_true(bool(meeting["sleight_used"]))
	assert_false("change" in _ids(CreatureMeeting.options(player, meeting)), "once a meeting")
	assert_eq(CreatureMeeting.change_ante(player, meeting), "")


# ------------------------------------------------------------ the tribute --

## The dice that give a tribute of [param offer] and [param payment].
func _tribute_dice(meeting: Dictionary, offer: int, payment: int) -> int:
	for seed in range(1, 400):
		player.dice = seed
		var paid := CreatureMeeting.tribute(player, meeting)
		if int(paid["offer"]) == offer and int(paid["payment"]) == payment:
			return seed
	return -1


func test_each_tribute_offer_and_payment() -> void:
	_deck(_plain_deck())
	_creature(18, 2)   # a Sea Dragon, blue, tier 12
	var meeting := CreatureMeeting.begin(player, 0)
	for offer in 3:
		for payment in 3:
			var seed := _tribute_dice(meeting, offer, payment)
			assert_gt(seed, 0, "offer %d with payment %d is drawn" % [offer, payment])
			player.dice = seed
			var paid := CreatureMeeting.tribute(player, meeting)
			assert_eq(paid["lines"][0], "I thank you for your mercy granted.")
			assert_eq(_ids(paid["choices"]), ["offer", "payment", "duel"])
			assert_eq(String(paid["choices"][2][1]), "Duel Anyway")
			if offer == 2:
				assert_eq(String(paid["choices"][0][1]), "Secrets from the Blue Castle?")
			var gold := player.gold
			var food := player.food
			var blue := int(player.amulets["blue"])
			var said := CreatureMeeting.take_payment(player, meeting)
			match payment:
				0:
					assert_between(player.gold - gold, 120, 210, "(tier + rand(10 − d)) · 10")
					assert_eq(String(paid["choices"][1][1]), "%d Gold" % (player.gold - gold))
				1:
					assert_eq(player.food - food, 40)
				2:
					var count := int(paid["count"])
					assert_between(count, 1, 3)
					# [ours: 1997 slip — 1.3 paid a colour drawn at random.]
					assert_eq(int(player.amulets["blue"]) - blue, count, "jewels of the colour the words name")
					assert_string_contains(String(paid["choices"][1][1]), "blue jewel")
			assert_ne(said, "")


func test_a_spell_from_the_creatures_deck() -> void:
	var meeting := CreatureMeeting.meet(player, 3, 1)
	var choices := CreatureMeeting.spell_choices(meeting)
	var maindeck := CardListPane.counted(CreatureDeck.for_meeting(3, 0))
	for card_name in choices:
		assert_eq(int(choices[card_name]), int(maindeck[card_name]))
	for treasure in ShandalarWorld.DUNGEON_CARDS:
		assert_false(choices.has(String(treasure[1])), "no dungeon treasure")
	var owned := player.cards.size()
	assert_true(CreatureMeeting.take_spell(player, "Dark Ritual"))
	assert_eq(player.cards.size(), owned + 1)
	assert_eq(player.cards[-1], {"card": "Dark Ritual", "decks": []}, "in no deck")


func test_a_world_magic_found() -> void:
	player.world_magics = ["Sleight of Hand", "Quickening"] as Array[String]
	var choices := CreatureMeeting.magic_choices(player)
	assert_eq(choices.size(), 10)
	assert_false(0 in choices or 6 in choices, "the owned are not sought")
	var index := -1
	for magic in choices:
		if WorldMagicShop.seller(player.world, magic) > 0:
			index = magic
			break
	assert_gt(index, 0, "a World Magic sold somewhere")
	var town := WorldMagicShop.seller(player.world, index)
	TownStatus.put(player.world, town, TownStatus.VISITED, false)
	var lines := CreatureMeeting.reveal_magic(player, index)
	assert_eq(lines[0], "%s may be" % AdventurePlayer.WORLD_MAGICS[index])
	assert_eq(lines[1], "found in %s." % WorldNames.site_name(player.world, town))
	assert_true(TownStatus.visited(player.world, town), "on the city list")
	var site: Dictionary = player.world.sites[town]
	assert_true(player.world.is_explored(int(site["x"]), int(site["y"])), "seen on the map")
	player.world_magics.assign(AdventurePlayer.WORLD_MAGICS)
	assert_eq(CreatureMeeting.magic_choices(player), [] as Array[int], "all gathered")


func test_the_castles_secrets() -> void:
	var meeting := CreatureMeeting.meet(player, 1, 1)
	var castle: Dictionary = player.world.encounters[0]
	castle["clues"] = 0
	var lines := CreatureMeeting.secrets(player, meeting)
	assert_eq(lines[0], WorldClues.title(0))
	assert_eq(int(castle["clues"]) & 7 != 0, true, "one clue learned")
	castle["clues"] = 7
	var dice := player.dice
	lines = CreatureMeeting.secrets(player, meeting)
	assert_eq(player.dice, dice, "all known: its clues shown, nothing drawn")
	player.defeated_wizards = ["black"] as Array[String]
	assert_eq(CreatureMeeting.secrets(player, meeting), ["You have already destroyed the Black Castle"] as Array[String])


# ------------------------------------------------------- the duel prepared --

func test_the_hand_modifier_and_the_colour_filter() -> void:
	_deck(_plain_deck())
	var meeting := CreatureMeeting.meet(player, 1, 1)
	player.creature_deck_colors[0] = 0x08
	CreatureMeeting.prepare_duel(player, meeting)
	assert_eq(int(meeting["modifier"]), -3, "no wins: −clamp(3 − 0/3, 0, 3)")
	assert_eq(int(meeting["filter"]), 0x08, "what black has learned")
	for i in 9:
		player.log_victory(31, 4)
	meeting = CreatureMeeting.meet(player, 1, 1)
	player.difficulty = 1
	CreatureMeeting.prepare_duel(player, meeting)
	assert_eq(int(meeting["modifier"]), 0, "9 wins")
	assert_eq(int(meeting["filter"]), DuelSpoils.deck_color_bits(player), "−1 < 0: the hero's colours")
	assert_eq(int(meeting["filter"]), 0x10, "a red deck")


func test_the_henchmans_modifier_is_zero() -> void:
	_deck(_plain_deck())
	var meeting := CreatureMeeting.meet(player, 6, 1)
	CreatureMeeting.prepare_duel(player, meeting)
	# [ours: 1997 slip — a World Magic's price read at a stale index.]
	assert_eq(int(meeting["modifier"]), 0)
	assert_eq(int(meeting["filter"]), 0x10, "a henchman plays the hero's colours")


## A special meeting's prepared [param row] on dice [param seed].
func _prepared(row: int, seed: int, timer := 0) -> Dictionary:
	player.monster_timer = timer
	player.dice = seed
	var meeting := CreatureMeeting.meet(player, row, 1)
	player.dice = seed
	CreatureMeeting.prepare_duel(player, meeting)
	return meeting


## The first dice from 1 whose special meeting for [param row] passes
## [param want].
func _seed_for(row: int, want: Callable, timer := 0) -> int:
	for seed in range(1, 600):
		if want.call(_prepared(row, seed, timer)):
			return seed
	return -1


func test_no_events_off_the_special_meeting() -> void:
	_deck(_plain_deck())
	for seed in range(1, 40):
		var meeting := _prepared(2, seed, 4)
		assert_false(bool(meeting["special"]))
		assert_eq((meeting["events"] as Array).size(), 0)
		assert_false(bool(meeting["first_strike"]))


func test_try_this_deck_leaves_the_filter_alone() -> void:
	_deck(_plain_deck())
	player.creature_deck_colors[0] = 0x04
	var seed := _seed_for(17, func(m: Dictionary) -> bool: return int(m["swap_row"]) > 0)
	assert_gt(seed, 0, "the Conjurer's swap comes one time in three")
	var meeting := _prepared(17, seed)
	assert_between(int(meeting["swap_row"]), 1, 35)
	assert_eq((meeting["events"] as Array)[0], "Why don't you try this deck!")
	# [ours: 1997 slip — the filter became the row number.]
	assert_eq(int(meeting["filter"]), 0x04)
	var config := CreatureMeeting.duel_config(player, meeting)
	assert_eq(Array(config.decks[0]), Array(CreatureDeck.for_meeting(int(meeting["swap_row"]), 0)),
		"the hero plays that deck")
	assert_eq(config.ante_extras[0], meeting["hero_ante"], "the hero's own card staked from outside it")
	assert_eq(config.ante_cards[0], [])


func test_a_summons_and_its_strength() -> void:
	_deck(_plain_deck())
	var counts := {}
	for seed in range(1, 300):
		var meeting := _prepared(1, seed)
		var called := int(meeting["summoned"])
		if called == 0:
			continue
		counts[called] = int(counts.get(called, 0)) + 1
		assert_eq(int(meeting["row"]), called)
		assert_eq(int(meeting["strength"]), CreatureBook.base_strength(1) + CreatureBook.tier(called) / 2,
			"the Witch's base + the new tier / 2")
		assert_eq((meeting["events"] as Array)[0], "Witch summons %s!" % CreatureBook.called(called))
		if called == 2:
			assert_true(bool(meeting["first_strike"]), "the Undead Knight's own First Strike")
	assert_eq(counts.keys().size(), 3, "an Undead Knight, a Warlock, a VampireLord: %s" % [counts])
	for called in counts:
		assert_true(int(called) in [2, 3, 4])


func test_the_enchantress_summons_past_the_great_druid() -> void:
	_deck(_plain_deck())
	for seed in range(1, 200):
		var called := int(_prepared(24, seed)["summoned"])
		assert_true(called == 0 or called in [25, 26, 27], "never row 28, a castle wizard")


func test_the_quest_creature_is_never_summoned_away() -> void:
	_deck(_plain_deck())
	player.quest = {"type": -1, "destination": 3, "giver": 4, "color": 1, "deadline": 99}
	for seed in range(1, 100):
		assert_eq(int(_prepared(1, seed)["summoned"]), 0)


func test_a_card_in_play_only_with_a_modifier_not_below_zero() -> void:
	_deck(_plain_deck())
	var meeting := _prepared(26, 1)
	assert_eq(String(meeting["card"]), "", "no wins: modifier −3")
	assert_eq((meeting["events"] as Array).size(), 0, "and nothing said")
	for i in 9:
		player.log_victory(31, 4)
	meeting = _prepared(26, 1)
	assert_eq(String(meeting["card"]), "Timber Wolves")
	assert_eq((meeting["events"] as Array)[0], "Beastmaster has card: Timber Wolves!")
	var config := CreatureMeeting.duel_config(player, meeting)
	assert_eq(config.start_in_play[1], ["Timber Wolves"])
	assert_eq(config.first_player, -1, "the hero moving first against it is DESIGNED, NEVER USED")


func test_first_strike_every_special_meeting() -> void:
	_deck(_plain_deck())
	var meeting := _prepared(10, 7)
	assert_true(bool(meeting["first_strike"]))
	assert_eq((meeting["events"] as Array)[0], "Crusader has First Strike!")
	player.next_duel_first_move = true
	assert_eq(CreatureMeeting.duel_config(player, meeting).first_player, 1, "First Strike before the hero's gift")


func test_mind_control_only_when_announced() -> void:
	_deck(_plain_deck())
	var meeting := _prepared(9, 3, 0)
	assert_true(bool(meeting["mind_control"]))
	assert_eq((meeting["events"] as Array)[0], "Priestess has Mind Control!")
	assert_true(CreatureMeeting.duel_config(player, meeting).mirror_seat0)
	meeting = _prepared(9, 3, 1)
	assert_true(bool(meeting["special"]), "(1 >> 2) % 3 == 0")
	assert_false(bool(meeting["mind_control"]), "1 % 3 != 0: not announced")


func test_mind_control_never_off_a_special_meeting() -> void:
	_deck(_plain_deck())
	# T = 6: 6 % 3 == 0 (1997's duel copied the deck), (6 >> 2) % 3 == 1: not special.
	var meeting := _prepared(9, 3, 6)
	assert_false(bool(meeting["special"]))
	assert_false(bool(meeting["mind_control"]), "1997 applied it silently here")
	assert_false(CreatureMeeting.duel_config(player, meeting).mirror_seat0)


# ---------------------------------------------------------- the duel set up --

func test_the_duel_config_pads_stakes_and_lives() -> void:
	_deck(_plain_deck())
	TownStatus.put(player.world, 3, TownStatus.LINKED)
	TownStatus.put(player.world, 4, TownStatus.LINKED)
	player.next_duel_life = 2
	player.next_duel_life_carried = -1
	player.next_duel_card = "Lord of Atlantis"
	_creature(16, 2)   # a Merfolk Shaman
	var meeting := CreatureMeeting.begin(player, 0)
	var config := CreatureMeeting.duel_config(player, meeting)
	var deck: Array = config.decks[0]
	assert_eq(deck.size(), 30, "a 20-card deck padded to Apprentice's 30")
	for i in range(20, 30):
		assert_true(String(deck[i]) in CreatureDeck.BASICS, "padded with basic lands")
	assert_eq(config.ante_cards[0], meeting["hero_ante"], "the stake lifted from the hero's library")
	assert_eq(config.ante_cards[1], meeting["creature_ante"], "and the creature's from its own")
	assert_eq(Array(config.decks[1]), Array(CreatureDeck.for_meeting(16, 0)))
	assert_eq(config.lives[0], player.mana_links() + 1, "the links, + 2 − 1")
	assert_eq(config.lives[1], CreatureBook.duel_life(16, 0), "6 + 0")
	assert_eq(config.start_in_play[0], ["Lord of Atlantis"], "the hero's next-duel card")
	assert_eq(config.first_player, -1, "the coin")
	assert_eq(config.mulligan_rule, MtgGame.MULLIGAN_1997)
	assert_true(config.ai_random_play_or_draw)
	assert_false(config.is_ai(0))
	assert_true(config.is_ai(1))
	assert_eq(config.portraits[1], "rogue_merfolk_shaman")
	assert_eq(config.player_names[1], "Merfolk Shaman")
	assert_ne(config.rng_seed, 0, "a fresh seed")
	player.difficulty = 3
	assert_eq(CreatureMeeting.duel_config(player, meeting).decks[0].size(), 40, "Wizard's 40")


func test_the_hero_life_has_no_base_and_no_floor() -> void:
	for slot in player.world.sites.size():
		TownStatus.put(player.world, slot, TownStatus.LINKED, false)
	assert_eq(CreatureMeeting.hero_life(player), 0, "no links: life 0 (DESIGNED, NEVER USED: the base 10)")
	player.world_magics = ["Fruit of Sustenance", "Haggler's Coin", "Ring of the Guardian"] as Array[String]
	assert_eq(CreatureMeeting.hero_life(player), 0, "the World Magics' bonuses are dead")
	player.next_duel_life = 3
	assert_eq(CreatureMeeting.hero_life(player), 3)


func test_a_summoned_creatures_stake_is_made_into_its_ante() -> void:
	_deck(_plain_deck())
	var meeting := CreatureMeeting.meet(player, 1, 1)
	meeting["creature_ante"] = ["Mahamoti Djinn"] as Array[String]
	var config := CreatureMeeting.duel_config(player, meeting)
	assert_false("Mahamoti Djinn" in config.decks[1])
	assert_eq(config.ante_extras[1], ["Mahamoti Djinn"], "made straight into its ante")
	assert_eq(config.ante_cards[1], [])


func test_the_ai_follows_the_difficulty() -> void:
	assert_eq(CreatureMeeting.ai_for(0).profile_name, AiProfile.apprentice().profile_name)
	assert_eq(CreatureMeeting.ai_for(3).profile_name, AiProfile.wizard().profile_name)
