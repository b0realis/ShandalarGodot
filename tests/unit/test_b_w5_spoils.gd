extends GutTest
## WHAT A CREATURE'S DUEL LEAVES (part B, W5, 2026-10-23): [DuelSpoils] —
## a win's log, journal, quest, cards (the creature's stake first, the
## budget by rarity, more than ten allowed), the dungeon's clue instead,
## the amulet, the reward of a special meeting, the colour learning; a
## loss's stake; a draw's nothing; every next-duel gift spent first; the
## bag. The duels themselves are played headless where the engine matters
## ([HeadlessDuel]): the meeting's [DuelConfig] dealt and played to a win,
## a loss and a draw.

var base: Dictionary
var player: AdventurePlayer


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Spoils Taker"
	setup.color = "green"
	setup.difficulty = 0
	setup.walker = "male"
	setup.seed_text = "4242"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.monsters = []
	player.monster_timer = 4


func _deck(names: Array) -> void:
	player.cards = []
	for card_name in names:
		player.cards.append({"card": String(card_name), "decks": [0]})
	player.current_deck = 0


func _green_deck() -> Array:
	var out: Array = []
	for i in 12:
		out.append("Forest")
	for i in 4:
		out.append("Llanowar Elves")
	for i in 4:
		out.append("Grizzly Bears")
	for i in 2:
		out.append("Giant Growth")
	return out


## A finished duel's report: [param result] from the hero's side, the
## hero's life [param start] → [param end].
func _report(result: int, start := 5, end := 5) -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = result
	report.winner = {1: 0, 0: 1}.get(result, -1)
	report.lives_start = [start, 6] as Array[int]
	report.lives_end = [end, 0] as Array[int]
	report.hero_life = end
	return report


## No castle or dungeon left to hint at (the cards come at once).
func _no_hints() -> void:
	for slot in player.world.encounters:
		(slot as Dictionary)["clues"] = 7


func _meeting(row: int, color := 3) -> Dictionary:
	return CreatureMeeting.meet(player, row, color)


# ------------------------------------------------------------- every duel --

func test_every_gift_is_spent_before_the_spoils() -> void:
	_deck(_green_deck())
	player.next_duel_life = 3
	player.next_duel_life_carried = -2
	player.next_duel_card = "Lord of Atlantis"
	player.next_duel_first_move = true
	for result in [DuelSpoils.LOST, DuelSpoils.DRAWN]:
		var meeting := _meeting(1)
		DuelSpoils.settle(player, meeting, _report(result))
		assert_eq([player.next_duel_life, player.next_duel_life_carried, player.next_duel_card,
			player.next_duel_first_move], [0, 0, "", false], "after a %d" % result)
		player.next_duel_life = 3


# --------------------------------------------------------------- a win --

func test_a_win_logs_the_creature_fought_and_beats_the_quest() -> void:
	_deck(_green_deck())
	_no_hints()
	player.quest = {"type": -3, "destination": 7, "giver": 9, "color": 1, "deadline": 99}
	var meeting := _meeting(1, 1)
	meeting["row"] = 3   # summoned: a Warlock fought
	meeting["kind"] = CreatureBook.kind(3)
	var journal := player.journal.size()
	var spoils := DuelSpoils.settle(player, meeting, _report(DuelSpoils.WON))
	assert_eq(player.duel_victories[-1], {"color": 1, "kind": CreatureBook.MALE_WIZARD, "creature": "Warlock"})
	assert_eq(player.journal.size(), journal + 1 + _acquired(spoils))
	var line: Dictionary = player.journal[journal]
	assert_eq(String(line["text"]), "Defeated a Warlock")
	assert_eq([String(line["event"]), bool(line["won"]), String(line["creature"])], ["duel", true, "Warlock"])
	assert_true(bool(spoils["quest"]))
	assert_eq(int(player.quest["type"]), -103, "Return to the giver")
	assert_eq(HeroStats.record(player)["won"], 1)


## The "Acquired spell" lines the cards kept wrote.
func _acquired(spoils: Dictionary) -> int:
	var count := 0
	for card_name in spoils.get("kept", []):
		if AdventurePlayer._rarity(String(card_name)) >= 3:
			count += 1
	return count


func test_the_cards_won_start_with_the_creatures_stake() -> void:
	_deck(_green_deck())
	_no_hints()
	var meeting := _meeting(25, 3)   # a Forest Dragon, S 8
	var stake := String((meeting["creature_ante"] as Array)[0])
	var owned := player.cards.size()
	var spoils := DuelSpoils.settle(player, meeting, _report(DuelSpoils.WON))
	var cards: Array = spoils["cards"]
	assert_eq(String(cards[0]), stake, "the creature's stake is the first pick")
	var spent := 0
	for i in cards.size():
		var f := CardValue.facts(CardRegistry.get_card(String(cards[i])))
		spent += int(spoils["rarities"][i]) + (1 if int(f.get("extra", 0)) & CardValue.FAVOURED != 0 else 0)
		if i < cards.size() - 1:
			assert_lt(spent, 8, "picks go on while the budget lasts")
	assert_gte(spent, 8, "the budget of S spent")
	assert_eq((spoils["heights"] as Array).size(), cards.size())
	assert_eq(spoils["took"], "cards")
	assert_eq(spoils["words"], ["Won these cards."] as Array[String])
	assert_eq(player.cards.size(), owned + cards.size())
	for i in cards.size():
		assert_eq(player.cards[owned + i], {"card": String(cards[i]), "decks": []}, "in no deck")


func test_no_reward_card_breaks_the_decks_copy_limit() -> void:
	_deck(_green_deck())
	_no_hints()
	var counts := CardShop.deck_counts(player)
	var limit := CardShop.copies_allowed(player)
	for seed in range(1, 30):
		player.dice = seed
		var meeting := _meeting(22, 3)   # a Druid
		meeting["creature_ante"] = [] as Array[String]
		var dice := MsvcRandom.new(seed)
		for card_name in DuelSpoils.reward_cards(player, meeting, dice):
			var f := CardValue.facts(CardRegistry.get_card(card_name))
			assert_gt(DuelSpoils.copies_left(player, card_name, f, counts, limit), 0, card_name)
			assert_eq(int(f.get("type", 0)) & CardValue.ARTIFACT != 0 and int(f.get("type", 0)) & 0x3F == 0,
				false, "a plain artifact is never drawn: %s" % card_name)
			assert_true(CardValue.goes_with(int(f.get("color", 1)), 1 << 3, 3), "%s goes with green" % card_name)


func test_the_pick_may_exceed_ten_cards() -> void:
	_deck(_green_deck())
	var meeting := _meeting(50, 1)   # a Mandurang, S 11
	meeting["strength"] = 60
	var cards := DuelSpoils.reward_cards(player, meeting, MsvcRandom.new(99))
	# [ours: 1997 slip — its ten-place array overflowed.]
	assert_gt(cards.size(), 10)


func test_a_henchman_gives_only_the_log() -> void:
	_deck(_green_deck())
	var meeting := _meeting(27, 3)   # the Summoner
	var owned := player.cards.size()
	var spoils := DuelSpoils.settle(player, meeting, _report(DuelSpoils.WON))
	assert_eq(player.total_wins(), 1)
	assert_eq((spoils["cards"] as Array).size(), 0)
	assert_eq(player.cards.size(), owned)
	assert_eq(spoils["amulet"], "")
	assert_eq(spoils["words"], ["Defeated a Summoner."] as Array[String])


# --------------------------------------------------- the clue instead --

func test_the_clue_or_the_cards() -> void:
	_deck(_green_deck())
	for slot in player.world.encounters:
		(slot as Dictionary)["clues"] = 0
	var meeting := _meeting(22, 3)
	var owned := player.cards.size()
	var spoils := DuelSpoils.settle(player, meeting, _report(DuelSpoils.WON))
	var hint := int(spoils["hint"])
	assert_gte(hint, 0)
	assert_true(bool(spoils["asks"]))
	assert_eq(String(spoils["plaque"]["name"]), WorldNames.dungeon_name(hint))
	assert_eq(String(spoils["plaque"]["clue"]), "(first clue)")
	assert_eq(spoils["words"][0], "You have defeated the")
	assert_eq(player.cards.size(), owned, "the cards wait for the answer")
	assert_eq(spoils["amulet"], "", "and the rest of the spoils")
	DuelSpoils.choose(player, meeting, spoils, false)
	assert_eq(spoils["took"], "clue")
	assert_eq(player.cards.size(), owned, "the clue forfeits the cards")
	assert_ne(int(player.world.encounters[hint]["clues"]), 0, "a clue learned")
	assert_eq(int(player.world.encounters[hint].get("rules", 0)) & WorldClues.CARDS_TAKEN, 0)
	assert_eq((spoils["clue"] as Array)[0], WorldClues.title(hint))


func test_taking_the_cards_marks_the_place() -> void:
	_deck(_green_deck())
	for slot in player.world.encounters:
		(slot as Dictionary)["clues"] = 0
	var meeting := _meeting(22, 3)
	var owned := player.cards.size()
	var spoils := DuelSpoils.settle(player, meeting, _report(DuelSpoils.WON))
	var hint := int(spoils["hint"])
	DuelSpoils.choose(player, meeting, spoils, true)
	assert_eq(player.cards.size(), owned + (spoils["cards"] as Array).size())
	assert_ne(int(player.world.encounters[hint]["rules"]) & WorldClues.CARDS_TAKEN, 0, "0x200 set")
	assert_eq(int(player.world.encounters[hint]["clues"]), 0, "no clue")
	DuelSpoils.choose(player, meeting, spoils, false)
	assert_eq(int(player.world.encounters[hint]["clues"]), 0, "asked once")


func test_the_marks_fade_one_time_in_three() -> void:
	for slot in player.world.encounters:
		(slot as Dictionary)["rules"] = WorldClues.CARDS_TAKEN | 0x10
	player.dice = 1234
	var expected: Array[bool] = []
	var dice := MsvcRandom.new(1234)
	for i in 15:
		expected.append(dice.below(3) == 0)
	WorldClues.forget_marks(player)
	assert_eq(player.dice, dice.state, "fifteen dice")
	for i in 15:
		var rules := int(player.world.encounters[i]["rules"])
		assert_eq(rules & WorldClues.CARDS_TAKEN == 0, expected[i], "slot %d" % i)
		assert_ne(rules & 0x10, 0, "its other rules kept")


func test_a_marked_place_is_told_of_less_and_lists_no_plain_rules() -> void:
	var slot: Dictionary = player.world.encounters[7]
	slot["clues"] = WorldClues.RULES
	slot["rules"] = 0
	slot["card_in_effect"] = -1
	assert_true("-No special rules." in WorldClues.lines(player.world, 7))
	WorldClues.mark_cards_taken(player.world, 7)
	assert_false("-No special rules." in WorldClues.lines(player.world, 7), "as 1997 read the whole word")


# ----------------------------------------------- the amulet and the reward --

## The dice from 1 whose win over [param row] (special or not by
## [param timer]) passes [param want] — a fresh adventure each time.
func _win_until(row: int, want: Callable, timer := 0) -> Dictionary:
	for seed in range(1, 400):
		before_each()
		_deck(_green_deck())
		_no_hints()
		player.monster_timer = timer
		player.dice = seed
		var meeting := _meeting(row, 3)
		CreatureMeeting.prepare_duel(player, meeting)
		var spoils := DuelSpoils.settle(player, meeting, _report(DuelSpoils.WON, 5, 9))
		if want.call(spoils):
			return spoils
	return {}


func test_an_amulet_of_the_creatures_colour() -> void:
	var spoils := _win_until(25, func(s: Dictionary) -> bool: return s["amulet"] != "", 4)
	assert_eq(spoils["amulet"], "green")
	assert_eq(int(player.amulets["green"]), int(base["carried"]["amulets"].get("green", 0)) + 1)


func test_no_reward_off_a_special_meeting() -> void:
	for seed in range(1, 20):
		before_each()
		_deck(_green_deck())
		_no_hints()
		player.dice = seed
		var meeting := _meeting(18, 3)
		CreatureMeeting.prepare_duel(player, meeting)
		assert_eq(int(DuelSpoils.settle(player, meeting, _report(DuelSpoils.WON))["bits"]), 0)


func test_each_reward() -> void:
	var cases := [
		[18, "You get Extra FOOD!"],                                  # Sea Dragon 0x200
		[12, "You get +"],                                            # Arch Angel 0x800
		[40, "TELEPORTED!"],                                          # Winged Stallion 0x400
		[3, "You won card: Dark Ritual"],                             # Warlock 0x4
		[10, "You get White Knight in the next duel."],               # Crusader 0x20
		[39, "in the next duel."],                                    # Centaur Shaman 0x100
		[33, "You get first move"],                                   # Hydra 0x10
		[37, "You get Extra GOLD!"],                                  # Sedge Beast 0x8
		[4, "You get your lives (9)"],                                # VampireLord 0x1
		[44, "You get any card of your choice!"],                     # Lord of Fate 0x40
		[43, "You get a duplicate card"],                             # Mind Stealer 0x1000
	]
	for entry in cases:
		var row := int(entry[0])
		var spoils := _win_until(row, func(s: Dictionary) -> bool: return int(s["bits"]) != 0, 0)
		assert_eq(int(spoils["bits"]), CreatureBook.reward_flags(row), CreatureBook.name_of(row))
		var said := "\n".join(PackedStringArray(spoils["rewards"]))
		assert_string_contains(said, String(entry[1]))
		match row:
			18:
				assert_between(player.food - int(base["carried"]["food"]), 20, 49)
			12:
				assert_between(player.next_duel_life, 1, 4)
			40:
				assert_true(bool(spoils["teleported"]))
				assert_true(player.world.is_land(player.tile().x, player.tile().y))
				assert_eq(player.position, player.tile() * 32 + Vector2i(16, 16), "set down at a tile's middle")
			3:
				assert_eq(player.cards[-1], {"card": "Dark Ritual", "decks": []})
				assert_eq(spoils["reward_card"], "Dark Ritual")
			10:
				assert_eq(player.next_duel_card, "White Knight")
			39:
				var f := CardValue.facts(CardRegistry.get_card(player.next_duel_card))
				assert_eq(int(f["type"]) & (CardValue.ARTIFACT | CardValue.CREATURE), CardValue.ARTIFACT)
			33:
				assert_true(player.next_duel_first_move)
			37:
				assert_eq(player.gold - int(base["carried"]["gold"]), 100)
			4:
				assert_eq(player.next_duel_life_carried, 4, "9 − 5 carried")
			44:
				assert_true(bool(spoils["pick_any"]))
				assert_true(DuelSpoils.pick_any(player, spoils, "Shivan Dragon"))
				assert_eq(player.cards[-1], {"card": "Shivan Dragon", "decks": []})
				assert_false(DuelSpoils.pick_any(player, spoils, "Black Lotus"), "once")
			43:
				assert_true(bool(spoils["pick_duplicate"]))
				assert_false(DuelSpoils.pick_duplicate(player, spoils, "Shivan Dragon"), "not owned: cancelled")
		assert_ne(String(spoils["title"]), "")


func test_the_titles_by_difficulty_and_gender() -> void:
	player.difficulty = 2
	player.walker = "female"
	assert_eq(DuelSpoils.title_for(player, 1), "You are a Mighty Sorceress\nsays the Witch:")
	player.walker = "male"
	assert_eq(DuelSpoils.title_for(player, 1), "You are a Mighty Sorceror\nsays the Witch:")
	# [ours: a walker neither male nor female reads the masculine word.]
	player.walker = "other"
	assert_eq(DuelSpoils.title_for(player, 1), "You are a Mighty Sorceror\nsays the Witch:")
	player.difficulty = 3
	player.walker = "female"
	assert_eq(DuelSpoils.title_for(player, 1), "You are a Fearsome Wizardess\nsays the Witch:")


func test_a_random_reward_without_one_of_its_own() -> void:
	var seen := {}
	for seed in range(1, 160):
		before_each()
		_deck(_green_deck())
		_no_hints()
		player.monster_timer = 0
		player.dice = seed
		var meeting := _meeting(8, 5)   # a Cleric: no reward of its own
		CreatureMeeting.prepare_duel(player, meeting)
		var spoils := DuelSpoils.settle(player, meeting, _report(DuelSpoils.WON, 5, 7))
		if spoils["amulet"] == "":
			seen[int(spoils["bits"])] = true
		else:
			assert_eq(int(spoils["bits"]), 0, "an amulet won: no random reward")
	for bits in seen:
		assert_true(int(bits) in [0, 0x1, 0x8, 0x10, 0x200, 0x800], "drawn from 0x1A19: %x" % int(bits))
	assert_false(seen.has(0x1000), "DESIGNED, NEVER USED: rand(12) never reaches the duplicate")
	assert_gte(seen.size(), 4, "%s" % [seen])


func test_the_colour_learns_the_heros_deck() -> void:
	var spoils := _win_until(25, func(s: Dictionary) -> bool: return bool(s["learned"]), 4)
	assert_true(bool(spoils["learned"]))
	assert_eq(player.learned_deck_colors(3), 0x08, "the green deck's colour")
	assert_eq(player.deck_colors, ["green"] as Array[String], "kept as 1997 kept its bitmap")


func test_the_heros_deck_colours() -> void:
	var names: Array = []
	for i in 10:
		names.append("Lightning Bolt")
	for i in 7:
		names.append("Grizzly Bears")
	for i in 3:
		names.append("Serra Angel")
	_deck(names)
	assert_eq(DuelSpoils.deck_color_bits(player), 0x10 | 0x08, "7 is at least two thirds of 10; 3 is not")
	_deck(["Sol Ring", "Ornithopter"])
	assert_eq(DuelSpoils.deck_color_bits(player), 0, "colourless only")


# --------------------------------------------------------------- loss, draw --

func test_a_loss_loses_the_stake() -> void:
	_deck(_green_deck())
	var meeting := _meeting(1, 1)
	var staked := String((meeting["hero_ante"] as Array)[0])
	var owned := player.cards.size()
	var spoils := DuelSpoils.settle(player, meeting, _report(DuelSpoils.LOST))
	assert_eq(spoils["lost"], [staked] as Array[String])
	assert_eq(player.cards.size(), owned - 1)
	assert_eq(String(player.journal[-1]["text"]), "Lost to a Witch")
	assert_eq(player.total_wins(), 0)
	assert_eq(HeroStats.record(player)["lost"], 1)


func test_a_conceded_duel_is_a_loss() -> void:
	_deck(_green_deck())
	var meeting := _meeting(1, 1)
	meeting["conceded"] = true
	var unfinished := DuelReport.new()
	assert_eq(int(DuelSpoils.settle(player, meeting, unfinished)["result"]), DuelSpoils.LOST)


func test_a_draw_changes_nothing() -> void:
	_deck(_green_deck())
	var meeting := _meeting(1, 1)
	var cards := player.cards.duplicate(true)
	var journal := player.journal.size()
	var spoils := DuelSpoils.settle(player, meeting, _report(DuelSpoils.DRAWN))
	assert_eq(player.cards, cards)
	assert_eq(player.journal.size(), journal)
	assert_eq(player.total_wins(), 0)
	assert_eq(spoils["words"], ["The people are disappointed", "you could manage no better than a draw",
		"against the slimy Witch.", "Better Luck Next Time!"] as Array[String])


# ---------------------------------------------------------------- the bag --

func test_the_bag_warns_and_then_loses_cards() -> void:
	_deck(_green_deck())
	_no_hints()
	while player.cards.size() < 455:
		player.cards.append({"card": "Forest", "decks": []})
	var spoils := DuelSpoils.settle(player, _meeting(25, 3), _report(DuelSpoils.WON))
	assert_eq(int(spoils["bag"]), player.cards.size(), "from 450, the note")
	assert_string_contains(DuelSpoils.BAG_NOTE % 455, "and you currently have 455")
	before_each()
	_deck(_green_deck())
	_no_hints()
	while player.cards.size() < AdventurePlayer.BAG_MOST:
		player.cards.append({"card": "Forest", "decks": []})
	spoils = DuelSpoils.settle(player, _meeting(25, 3), _report(DuelSpoils.WON))
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST, "the full bag holds no more")
	assert_eq((spoils["bag_lost"] as Array).size(), (spoils["cards"] as Array).size())


# ----------------------------------------------- duels played headless --

## The meeting's own duel, played headless with lives [param lives].
func _play(meeting: Dictionary, lives: Array[int]) -> DuelReport:
	var config := CreatureMeeting.duel_config(player, meeting)
	config.lives = lives
	config.rng_seed = 31337
	return await HeadlessDuel.play(config)


func test_a_meeting_duel_played_to_each_result() -> void:
	_deck(_green_deck())
	_no_hints()
	var meeting := _meeting(1, 1)
	var staked := String((meeting["hero_ante"] as Array)[0])
	var report := await _play(meeting, [3, 0] as Array[int])
	assert_true(report.hero_won(), report.describe())
	assert_eq(report.ante[0], [staked] as Array[String], "the hero's stake was in the ante")
	assert_eq(report.ante[1], meeting["creature_ante"])
	var spoils := DuelSpoils.settle(player, meeting, report)
	assert_eq(int(spoils["result"]), DuelSpoils.WON)
	meeting = _meeting(1, 1)
	staked = String((meeting["hero_ante"] as Array)[0])
	report = await _play(meeting, [0, 4] as Array[int])
	assert_true(report.hero_lost(), report.describe())
	var owned := player.cards.size()
	DuelSpoils.settle(player, meeting, report)
	assert_eq(player.cards.size(), owned - 1)
	meeting = _meeting(1, 1)
	report = await _play(meeting, [0, 0] as Array[int])
	assert_true(report.is_draw(), report.describe())
	owned = player.cards.size()
	DuelSpoils.settle(player, meeting, report)
	assert_eq(player.cards.size(), owned)


func test_mind_control_and_first_strike_reach_the_engine() -> void:
	_deck(_green_deck())
	player.monster_timer = 0
	var meeting := _meeting(9, 5)   # a Priestess
	CreatureMeeting.prepare_duel(player, meeting)
	assert_true(bool(meeting["mind_control"]))
	var config := CreatureMeeting.duel_config(player, meeting)
	config.lives = [5, 5] as Array[int]
	config.rng_seed = 99
	var duel: HeadlessDuel = await HeadlessDuel.begin(config)
	var mine: Array[String] = []
	for inst in duel.game.players[0].hand:
		mine.append(inst.data.card_name)
	var theirs: Array[String] = []
	for inst in duel.game.players[1].hand:
		theirs.append(inst.data.card_name)
	mine.sort()
	theirs.sort()
	assert_eq(theirs, mine, "the Priestess holds a copy of the hero's hand")
	meeting = _meeting(10, 5)   # a Crusader
	CreatureMeeting.prepare_duel(player, meeting)
	config = CreatureMeeting.duel_config(player, meeting)
	config.lives = [5, 5] as Array[int]
	duel = await HeadlessDuel.begin(config)
	assert_eq(duel.game.active_player, 1, "First Strike: the Crusader starts")
