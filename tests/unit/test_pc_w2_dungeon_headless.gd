extends GutTest
## THE DUELS INSIDE, PLAYED (part C, W2, 2026-10-27): [DungeonDuels]' duel
## dealt and played by [HeadlessDuel] — the castle's minion and card in
## effect on the creature's side at turn 1, the stake in the hero's ante and
## none in the creature's, the lives as built, the banned cards in neither
## the library nor the hand (the deck made up to the least with allowed
## basics), and a room duel played to each result and settled: won —
## cleared, lost — thrown out with the stake, drawn — no result.

var base: Dictionary
var player: AdventurePlayer


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Spelunker"
	setup.color = "white"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "5151"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.monsters = []
	player.dice = 777
	player.clear_duel_gifts()


func _deck(names: Array) -> void:
	player.cards = []
	for card_name in names:
		player.cards.append({"card": String(card_name), "decks": [0]})
	player.current_deck = 0


func _copies(card_name: String, count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append(card_name)
	return out


func _run(index: int, rules: int, color: int, monsters: Array, effect := -1) -> Dictionary:
	return {"index": index, "castle": index < 5, "color": color, "rules": rules,
		"monsters": monsters, "life_pool": 0, "dice_card": "", "card_in_effect": effect}


## The cards of [param zone] by their printed names.
func _names(zone: Array) -> Array[String]:
	var out: Array[String] = []
	for inst in zone:
		out.append(inst.printed_data.card_name)
	return out


func test_the_castle_s_cards_in_play_and_the_stake() -> void:
	_deck(_copies("Plains", 16) + _copies("Serra Angel", 4) + _copies("White Knight", 4))
	var run := _run(0, 3, 1, [36, 37, 38, 39, CreatureBook.castle_row(1)], 100)
	var duel := DungeonDuels.setup(player, run, DungeonDuels.WIZARD_SLOT)
	assert_true(DungeonDuels.draw_stake(player, duel))
	var config := DungeonDuels.duel_config(player, run, duel)
	config.rng_seed = 77
	var held: HeadlessDuel = await HeadlessDuel.begin(config)
	var theirs := _names(held.game.players[1].battlefield)
	assert_true(theirs.has("Hypnotic Specter"), "the minion in play: %s" % [theirs])
	assert_true(theirs.has("Gloom"), "the card in effect in play: %s" % [theirs])
	assert_eq(_names(held.game.players[0].ante), duel["hero_ante"] as Array[String], "the stake")
	assert_eq(_names(held.game.players[1].ante), [] as Array[String], "the creature stakes nothing")
	var report := held.report()
	assert_eq(report.lives_start, config.lives, "the lives as built")
	assert_eq(report.lives_start[0], DungeonDuels.hero_life(player, run))
	held.game.concede(0)


func test_the_banned_cards_are_in_neither_library_nor_hand() -> void:
	_deck(_copies("Swamp", 10) + _copies("Dark Ritual", 4) + _copies("Hypnotic Specter", 4)
		+ ["Nebuchadnezzar"] + _copies("Grizzly Bears", 6) + _copies("Forest", 6)
		+ _copies("Lightning Bolt", 3))
	var rules := DungeonDuels.NO_COLOR | DungeonDuels.CARRY
	var run := _run(9, rules, 1, [1, 2, 3, 4, 5])
	var duel := DungeonDuels.setup(player, run, 0)
	assert_true(DungeonDuels.draw_stake(player, duel))
	var config := DungeonDuels.duel_config(player, run, duel)
	config.rng_seed = 99
	var held: HeadlessDuel = await HeadlessDuel.begin(config)
	var hero: MtgPlayer = held.game.players[0]
	var dealt := _names(hero.library) + _names(hero.hand) + _names(hero.ante) + _names(hero.battlefield) \
		+ _names(hero.graveyard)
	assert_eq(dealt.size(), CreatureMeeting.DECK_LEAST[1], "the least, counted after the ban")
	for card_name in dealt:
		assert_false(DungeonDuels.bars(card_name, rules, 1), "not banned: %s" % card_name)
	assert_false(dealt.has("Swamp"), "no Swamp padded in")
	held.game.concede(0)


func test_a_room_duel_played_to_each_result() -> void:
	_deck(_copies("Plains", 16) + _copies("Serra Angel", 4) + _copies("White Knight", 4))
	var run := _run(12, DungeonDuels.CARRY, 5, [CreatureBook.row_named("Cleric"), 9, 10, 11, 12])
	# Won: the creature at no life.
	var duel := DungeonDuels.setup(player, run, 0)
	DungeonDuels.draw_stake(player, duel)
	var config := DungeonDuels.duel_config(player, run, duel)
	config.lives = [6, 0] as Array[int]
	config.rng_seed = 4242
	var report: DuelReport = await HeadlessDuel.play(config)
	assert_true(report.hero_won(), report.describe())
	var out := DungeonDuels.settle(player, run, duel, report)
	assert_eq(out["outcome"], DungeonDuels.CLEARED)
	assert_eq(out["journal"], "Defeated a Cleric")
	assert_eq(int(run["life_pool"]), 0, "the life it ended with is the life it began with")
	# Lost: the hero at no life.
	duel = DungeonDuels.setup(player, run, 0)
	DungeonDuels.draw_stake(player, duel)
	var staked := String((duel["hero_ante"] as Array)[0])
	var copies := player.deck_cards().count(staked)
	config = DungeonDuels.duel_config(player, run, duel)
	config.lives = [0, 4] as Array[int]
	config.rng_seed = 4243
	report = await HeadlessDuel.play(config)
	assert_true(report.hero_lost(), report.describe())
	out = DungeonDuels.settle(player, run, duel, report)
	assert_eq(out["outcome"], DungeonDuels.THROWN_OUT)
	assert_eq(player.deck_cards().count(staked), copies - 1, "the stake lost")
	assert_eq(int(run["life_pool"]), 0, "0 + (0 − 0)")
	# Drawn: both at no life.
	run["life_pool"] = 5
	duel = DungeonDuels.setup(player, run, 0)
	DungeonDuels.draw_stake(player, duel)
	var cards := player.cards.duplicate(true)
	config = DungeonDuels.duel_config(player, run, duel)
	config.lives = [0, 0] as Array[int]
	config.rng_seed = 4244
	report = await HeadlessDuel.play(config)
	assert_true(report.is_draw(), report.describe())
	out = DungeonDuels.settle(player, run, duel, report)
	assert_eq(out["outcome"], DungeonDuels.AGAIN)
	assert_eq(player.cards, cards, "nothing lost")
	assert_eq(int(run["life_pool"]), 5, "the pool untouched")
