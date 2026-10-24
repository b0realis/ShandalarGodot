extends GutTest
## THE FOUR LAIR DUELS (part B, W6, 2026-10-23): [LairDuels] — each lair's
## tier and hoard, the creature (never Arzakon's rows), 1997's words, the
## Hall of the Sultan's King Suleiman set first, the Spectral Arena's own
## creature fought as a Spectre at tier-16 life [ours: 1997 slip], the dice
## in 1997's order, the duel handed to the engine (the hero stakes nothing,
## the hoard made into the creature's ante), and what it leaves — a win's
## cards in no deck in 1997's places, a loss nothing, a draw nothing [ours:
## 1997 slip — a draw won the hoard]. The duels are played headless where the
## engine matters ([HeadlessDuel]).

var base: Dictionary
var player: AdventurePlayer


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Hoard Seeker"
	setup.color = "blue"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "8642"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.monsters = []
	player.monster_timer = 0
	player.siege_timer = 0
	_deck()


func _deck() -> void:
	player.cards = []
	for card_name in ["Island", "Island", "Island", "Island", "Island", "Island", "Island", "Island",
			"Island", "Island", "Merfolk of the Pearl Trident", "Merfolk of the Pearl Trident",
			"Phantom Monster", "Phantom Monster", "Counterspell", "Counterspell", "Unsummon"]:
		player.cards.append({"card": card_name, "decks": [0]})
	player.current_deck = 0


## A lair's event of kind [param kind] ([method LairEvent.begin]'s shape).
func _event(kind: int) -> Dictionary:
	return {"slot": 1, "color": 2, "event": kind, "name": LairEvent.NAMES[kind], "reward": "",
		"lair_rare": "", "oasis": -1}


func _report(result: int) -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = result
	report.winner = {1: 0, 0: 1}.get(result, -1)
	return report


# ------------------------------------------------------------- the setup --

func test_each_lair_s_tier_hoard_and_creature() -> void:
	for kind in [LairEvent.SHRINE, LairEvent.DRAGON, LairEvent.SULTAN]:
		before_each()
		var setup := LairDuels.begin(player, _event(kind))
		var want: Array = LairDuels.SETUPS[kind]
		assert_eq([setup["tier"], setup["count"]], [want[0], want[1]], LairEvent.NAMES[kind])
		var rares: Array = setup["rares"]
		assert_eq(rares.size(), int(want[1]), "the hoard's size")
		for rare in rares:
			assert_gte(LairDuels.rarity_of(String(rare)), 3, "a rare or unique: %s" % rare)
		var row := int(setup["row"])
		assert_between(row, 1, 54, "never Arzakon's rows")
		assert_eq(CreatureBook.tier(row), int(want[0]), "a creature of the lair's tier")
		assert_eq(int(setup["color"]), LairDuels.first_color(row))
		assert_true(CreatureBook.is_of(row, int(setup["color"])))
	assert_true(LairDuels.begin(player, _event(LairEvent.BAZAAR)).is_empty(), "no duel at the Bazaar")


func test_the_shrine_by_the_siege_clock() -> void:
	player.siege_timer = LairDuels.LATE_SIEGE - 1
	assert_eq(LairDuels.setup_of(player, LairEvent.SHRINE), [8, 2] as Array[int])
	player.siege_timer = LairDuels.LATE_SIEGE
	assert_eq(LairDuels.setup_of(player, LairEvent.SHRINE), [13, 3] as Array[int])
	var setup := LairDuels.begin(player, _event(LairEvent.SHRINE))
	assert_eq((setup["rares"] as Array).size(), 3)
	assert_eq(CreatureBook.kind(int(setup["row"])), CreatureBook.DJINN, "a tier-13 djinn")
	assert_eq((setup["words"] as Array)[1], "Genie guarding a horde")


func test_the_words_by_the_tier() -> void:
	var setup := LairDuels.begin(player, _event(LairEvent.DRAGON))
	var row := int(setup["row"])
	assert_eq(setup["words"], ["You encounter %s" % CreatureBook.called(row), "Dragon guarding a horde",
		"of valuable spells.", "Will you..."] as Array[String], "@MONSTERLAIR 2 and 4")
	before_each()
	setup = LairDuels.begin(player, _event(LairEvent.SHRINE))
	assert_eq((setup["words"] as Array)[1], "warily guarding a horde", "@MONSTERLAIR 3, tier 8")
	assert_eq(LairDuels.choices(setup), [["leave", "Leave quietly.", true], ["lair_duel", "Duel the creature.", true]])


func test_the_hall_sets_king_suleiman_first() -> void:
	var event := _event(LairEvent.SULTAN)
	var setup := LairDuels.begin(player, event)
	assert_eq(player.next_duel_card, LairDuels.KING_SULEIMAN, "the next duel's card, set before anything")
	assert_eq(setup["gift"], "King Suleiman")
	assert_true((setup["words"] as Array).has("(King Suleiman starts in play!)"),
		"[QoL] 1997's own @DUNGEON 18 says so")
	assert_eq((setup["words"] as Array)[1], "Genie guarding a horde", "tier 13")
	assert_eq(LairDuels.begin(player, event), setup, "begun once: the same setup again")
	# Leaving quietly settles nothing: the card stays for the next duel.
	assert_eq(player.next_duel_card, "King Suleiman")


func test_the_dice_go_as_1997_drew_them() -> void:
	var dice := MsvcRandom.new(player.dice)
	var rares: Array[String] = []
	for n in 4:
		rares.append(LairEvent.rare_of_any_kind(dice))
	var row := 0
	while true:
		row = CreatureBook.pick(dice, 0, 18)
		if row < 55:
			break
	var setup := LairDuels.begin(player, _event(LairEvent.DRAGON))
	assert_eq(setup["rares"], rares, "the hoard first")
	assert_eq(int(setup["row"]), row, "then the creature")
	assert_eq(player.dice, dice.state, "and nothing else drawn")


## [Ours: 1997 slip — row 56's copy was never fought.]
func test_the_arena_fights_its_own_creature_as_a_spectre() -> void:
	var dice := MsvcRandom.new(player.dice)
	var drawn := dice.below(54) + 1
	for n in 3:
		LairEvent.rare_of_any_kind(dice)
	while CreatureBook.pick(dice, 0, 16) >= 55:
		pass
	var setup := LairDuels.begin(player, _event(LairEvent.ARENA))
	assert_eq(int(setup["row"]), drawn, "the creature the Arena drew, rows 1–54")
	assert_eq(player.dice, dice.state, "the tier-16 pick still drawn, as 1997 drew it")
	assert_true(bool(setup["arena"]))
	assert_eq((setup["words"] as Array)[0], "You encounter %s" % CreatureBook.called(drawn))
	assert_eq((setup["words"] as Array)[1], "Spectre guarding a horde")
	assert_eq(LairDuels.foe(setup), "%s Spectre" % CreatureBook.name_of(drawn))
	for d in 4:
		player.difficulty = d
		assert_eq(LairDuels.life(player, setup), 16 + 2 * d, "tier-16 life, whatever the row")
	var config := LairDuels.duel_config(player, setup)
	assert_eq(config.lives[1], 16 + 2 * player.difficulty)
	assert_eq(config.player_names[1], "%s Spectre" % CreatureBook.duel_name(drawn))
	assert_eq(config.portraits[1], CreatureBook.face_id(drawn), "its own face")
	assert_eq(config.decks[1], CreatureDeck.for_meeting(drawn, 0), "its own maindeck")
	assert_eq(CreatureBook.tier(56), 100, "the table is never changed")


# -------------------------------------------------------------- the duel --

func test_the_duel_the_engine_is_given() -> void:
	var setup := LairDuels.begin(player, _event(LairEvent.SULTAN))
	var config := LairDuels.duel_config(player, setup)
	var row := int(setup["row"])
	assert_eq(config.ante_cards, [[], []], "nothing lifted out of either deck")
	assert_eq(config.ante_extras[0], [], "the hero stakes nothing")
	assert_eq(config.ante_extras[1], setup["rares"], "the hoard made into the creature's ante")
	assert_true(config.plays_named_ante(), "a duel for ante")
	assert_eq(config.decks[1], CreatureDeck.for_meeting(row, 0), "its maindeck, no section learned")
	assert_eq(config.lives[1], CreatureBook.tier(row) + 2 * player.difficulty)
	assert_eq(config.lives[0], player.mana_links() + player.next_duel_lives())
	assert_eq(config.start_in_play[0], ["King Suleiman"], "the Hall's gift in play")
	assert_eq(config.start_in_play[1], [], "the creature starts with nothing")
	assert_eq(config.mulligan_rule, MtgGame.MULLIGAN_1997)


func test_the_places_1997_laid_the_cards() -> void:
	assert_eq(LairDuels.stake_places(4), [Vector2(100, 100), Vector2(137, 102), Vector2(174, 104),
		Vector2(211, 106)] as Array[Vector2], "(150/N·i + 100, 10/N·i + 100)")
	assert_eq(LairDuels.won_places(2, [0, 9]), [Vector2(61, 16), Vector2(161, 25)] as Array[Vector2],
		"s·i + 111 − (N−1)·s/2, rand(10) + 16")
	assert_eq(LairDuels.won_places(4, [1, 2, 3, 4]), [Vector2(21, 17), Vector2(81, 18), Vector2(141, 19),
		Vector2(201, 20)] as Array[Vector2])


# --------------------------------------------------------------- the end --

func test_a_win_gives_the_hoard_in_no_deck() -> void:
	player.next_duel_life = 3
	var setup := LairDuels.begin(player, _event(LairEvent.DRAGON))
	var owned := player.cards.size()
	var journal := player.journal.size()
	var dice := MsvcRandom.new(player.dice)
	var spoils := LairDuels.settle(player, setup, _report(LairDuels.WON))
	assert_eq(int(spoils["result"]), LairDuels.WON)
	assert_eq(spoils["cards"], setup["rares"])
	assert_eq(player.cards.size(), owned + 4)
	for i in range(owned, player.cards.size()):
		assert_eq(player.cards[i]["decks"], [], "in no deck")
	var heights: Array[int] = []
	for n in 4:
		heights.append(dice.below(10))
	assert_eq(spoils["heights"], heights, "a die for each card's height")
	assert_eq(spoils["places"], LairDuels.won_places(4, heights))
	assert_eq(spoils["words"], ["Won These Cards"] as Array[String])
	for rarity in spoils["rarities"]:
		assert_true(int(rarity) in [3, 4])
	assert_eq(player.total_wins(), 0, "no victory logged")
	for i in range(journal, player.journal.size()):
		assert_eq(String(player.journal[i]["event"]), "card", "only 1997's Acquired spell lines")
	assert_eq(player.duel_record(), {"won": 0, "lost": 0}, "no duel counted")
	assert_eq(player.next_duel_life, 0, "the gifts spent")


func test_a_loss_or_a_draw_changes_nothing() -> void:
	for result in [LairDuels.LOST, LairDuels.DRAWN]:
		before_each()
		var setup := LairDuels.begin(player, _event(LairEvent.SHRINE))
		var cards := player.cards.duplicate(true)
		var journal := player.journal.size()
		var spoils := LairDuels.settle(player, setup, _report(result))
		assert_eq(int(spoils["result"]), result)
		assert_eq(player.cards, cards, "[ours: 1997 slip — a draw won the hoard]" if result == -1 else "a loss loses nothing")
		assert_eq(player.journal.size(), journal)
		assert_eq(spoils["cards"], [])
	var setup := LairDuels.begin(player, _event(LairEvent.SHRINE))
	assert_eq(int(LairDuels.settle(player, setup, _report(LairDuels.WON), true)["result"]), LairDuels.LOST,
		"conceded: a loss")
	var unfinished := DuelReport.new()
	assert_eq(LairDuels.result_of(unfinished), LairDuels.DRAWN, "never finished: no cards change hands")


func test_a_full_bag_loses_the_cards_it_cannot_hold() -> void:
	while player.cards.size() < AdventurePlayer.BAG_MOST - 1:
		player.cards.append({"card": "Island", "decks": []})
	var setup := LairDuels.begin(player, _event(LairEvent.SHRINE))
	var spoils := LairDuels.settle(player, setup, _report(LairDuels.WON))
	assert_eq((spoils["kept"] as Array).size(), 1)
	assert_eq((spoils["bag_lost"] as Array).size(), 1)
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST)


# ----------------------------------------------- duels played headless --

func _play(setup: Dictionary, lives: Array[int]) -> DuelReport:
	var config := LairDuels.duel_config(player, setup)
	config.lives = lives
	config.rng_seed = 4242
	return await HeadlessDuel.play(config)


func test_a_lair_duel_played_to_each_result() -> void:
	var setup := LairDuels.begin(player, _event(LairEvent.DRAGON))
	var report := await _play(setup, [3, 0] as Array[int])
	assert_true(report.hero_won(), report.describe())
	assert_eq(report.ante[0], [], "the hero staked nothing")
	var hoard: Array = (setup["rares"] as Array).duplicate()
	var staked: Array = (report.ante[1] as Array).duplicate()
	hoard.sort()
	staked.sort()
	assert_eq(staked, hoard, "the hoard was the creature's ante")
	var owned := player.cards.size()
	LairDuels.settle(player, setup, report)
	assert_eq(player.cards.size(), owned + 4)
	report = await _play(setup, [0, 4] as Array[int])
	assert_true(report.hero_lost(), report.describe())
	owned = player.cards.size()
	LairDuels.settle(player, setup, report)
	assert_eq(player.cards.size(), owned)
	report = await _play(setup, [0, 0] as Array[int])
	assert_true(report.is_draw(), report.describe())
	LairDuels.settle(player, setup, report)
	assert_eq(player.cards.size(), owned, "a draw: nothing")


func test_king_suleiman_starts_in_play() -> void:
	var setup := LairDuels.begin(player, _event(LairEvent.SULTAN))
	var config := LairDuels.duel_config(player, setup)
	config.lives = [5, 5] as Array[int]
	config.rng_seed = 77
	var duel: HeadlessDuel = await HeadlessDuel.begin(config)
	var mine: Array[String] = []
	for inst in duel.game.players[0].battlefield:
		mine.append(inst.data.card_name)
	assert_true(mine.has("King Suleiman"), "in play for the hero: %s" % [mine])
	duel.game.concede(0)
