extends GutTest
## A RULED TOWN AND FREEING IT (part B, W6, 2026-10-23): [RuledTowns] — the
## hero's stake by 1997's seed walk (the same every entry, capped at what the
## deck holds [ours]), the creature's tier by the siege clock, the creature
## drawn anew on every entry, its stake, the wizard's minion in play, the
## words naming the creature, the game over with nothing to stake, and what
## the duel leaves: the town freed and the creature's stake INTO THE DECK IN
## USE, the stake lost, a draw nothing [ours: 1997 slip — a draw lost the
## stake]. The duels are played headless where the engine matters.

var base: Dictionary
var player: AdventurePlayer
var town := -1


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Town Freer"
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
	town = _first_town()
	_rule(town, 4)
	_deck()


func _first_town() -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


func _rule(slot: int, wizard: int) -> void:
	TownStatus.take(player.world, slot, wizard)


## A deck in use: lands at the front, the spells after — and a card out of
## the deck at [param spare].
func _deck() -> void:
	player.cards = []
	for card_name in ["Plains", "Plains", "Plains", "Plains", "Plains", "Plains", "Plains", "Plains",
			"Plains", "Plains", "Savannah Lions", "White Knight", "Swords to Plowshares", "Serra Angel",
			"Healing Salve", "Benalish Hero"]:
		player.cards.append({"card": card_name, "decks": [0]})
	player.cards.append({"card": "Wrath of God", "decks": []})
	player.current_deck = 0


func _report(result: int) -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = result
	report.winner = {1: 0, 0: 1}.get(result, -1)
	return report


## 1997's walk, written out apart: from the seed [param y], slot = seed mod
## 500, seed += 7, the first [param count] usable places.
func _walk(y: int, count: int, usable: Array) -> Array[int]:
	var out: Array[int] = []
	var seed := y
	while out.size() < count:
		var at := seed % 500
		seed += 7
		if at in usable and not at in out:
			out.append(at)
	return out


# -------------------------------------------------------------- the stake --

func test_the_hero_s_stake_is_1997_s_seed_walk() -> void:
	var site: Dictionary = player.world.sites[town]
	for x in [6, 7, 8]:
		site["x"] = x
		site["y"] = 3
		var staked := RuledTowns.stake(player, town)
		var count: int = x % 3 + 1
		assert_eq(RuledTowns.stake_count(player.world, town), count, "(town x mod 3) + 1")
		var places := _walk(3, count, range(10, 16))
		assert_eq(staked["places"], places, "the walk from the town's y")
		var names: Array[String] = []
		for at in places:
			names.append(String(player.cards[at]["card"]))
		assert_eq(staked["names"], names)
		assert_eq(RuledTowns.stake(player, town), staked, "the same every entry")
	# The walk from y = 3 meets slots 3, 10, 17, …: 10 first (Savannah Lions).
	site["x"] = 6
	assert_eq(RuledTowns.stake(player, town)["names"], ["Savannah Lions"] as Array[String])


func test_lands_and_cards_out_of_the_deck_are_never_staked() -> void:
	var site: Dictionary = player.world.sites[town]
	site["x"] = 8
	for y in 40:
		site["y"] = y
		for at in RuledTowns.stake(player, town)["places"]:
			assert_between(int(at), 10, 15, "a spell of the deck in use, y %d" % y)


## [Ours: 1997 slip — fewer such cards than the count staked one copy again.]
func test_the_stake_is_capped_at_the_cards_there_are() -> void:
	player.cards = [{"card": "Plains", "decks": [0]}, {"card": "Serra Angel", "decks": [0]}]
	player.world.sites[town]["x"] = 5
	var staked := RuledTowns.stake(player, town)
	assert_eq(staked["names"], ["Serra Angel"] as Array[String], "three asked, one there")


# ----------------------------------------------------------- the creature --

func test_the_tier_by_the_siege_clock() -> void:
	var site: Dictionary = player.world.sites[town]
	var want := {0: 4, 127: 4, 128: 6, 256: 8, 384: 12, 512: 16}
	for timer in want:
		player.siege_timer = timer
		assert_eq(RuledTowns.tier(player, town), want[timer], "T %d" % timer)
	player.siege_timer = 640
	site["y"] = 11
	assert_eq(RuledTowns.tier(player, town), 18, "later: an odd row")
	site["y"] = 12
	assert_eq(RuledTowns.tier(player, town), 14, "later: an even row")


func test_the_creature_is_drawn_on_every_entry() -> void:
	var rows := {}
	for i in 12:
		var dice := MsvcRandom.new(player.dice)
		var want := CreatureBook.pick(dice, 4, 4)
		var entry := RuledTowns.enter(player, town)
		assert_eq(int(entry["row"]), want, "the wizard's colour at the tier, on the dice")
		assert_true(CreatureBook.is_of(want, 4) and CreatureBook.tier(want) == 4)
		rows[want] = true
	assert_eq(rows.size(), 1, "the red tier-4 creature is the Sorceress alone")
	player.siege_timer = 512
	var seen := {}
	for i in 24:
		var row := int(RuledTowns.enter(player, town)["row"])
		assert_eq(CreatureBook.tier(row), 16)
		assert_true(CreatureBook.is_of(row, 4))
		seen[row] = true
	assert_true(seen.has(33), "a red tier-16: the Hydra")


func test_the_creature_s_stake_and_minion() -> void:
	for i in 20:
		var entry := RuledTowns.enter(player, town)
		var row := int(entry["row"])
		var stake: Array = entry["creature_ante"]
		assert_eq(stake.size(), 1)
		var card := String(stake[0])
		assert_true(CreatureDeck.maindeck(row).has(card), "of its maindeck: %s" % card)
		assert_false(card in CreatureDeck.BASICS, "never a basic land")
		for treasure in ShandalarWorld.DUNGEON_CARDS:
			assert_ne(card, String(treasure[1]), "never a dungeon's treasure")
		var met := RuledTowns.meeting(player, entry)
		assert_true(CreatureBook.MINIONS[4].has(String(met["card"])), "a Red Wizardess's minion")
	var dice := MsvcRandom.new(1)
	var seen := {}
	for i in 60:
		seen[RuledTowns.minion(1, dice)] = true
	assert_eq(seen.size(), 3, "rand(3) of the three")


func test_the_words_name_the_creature() -> void:
	var entry := RuledTowns.enter(player, town)
	var row := int(entry["row"])
	assert_eq(RuledTowns.words(player, entry), ["This place is ruled by the Red Wizardess.",
		"To free the city you must duel this %s" % CreatureBook.name_of(row)] as Array[String],
		"@VISIT 2 and 4: the creature, not the wizard's")
	assert_eq(RuledTowns.choices(entry), [["leave", "Never mind.", true], ["duel", "Duel the creature.", true]])
	assert_eq(RuledTowns.enter(player, _site_of(ShandalarWorld.CITY, false)), {}, "a free town: nothing")


func _site_of(kind: int, ruled: bool) -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == kind and TownStatus.ruled(player.world, slot) == ruled:
			return slot
	return -1


func test_nothing_to_stake_is_the_game_over() -> void:
	player.cards = [{"card": "Plains", "decks": [0]}, {"card": "Serra Angel", "decks": []}]
	var dice := player.dice
	var entry := RuledTowns.enter(player, town)
	assert_true(bool(entry["no_ante"]), "ExitIfNoUsableDeckCards, as the town is entered")
	assert_eq(int(entry["row"]), 0, "nothing drawn")
	assert_eq(player.dice, dice)


func test_the_last_entry_is_the_duel_s_once() -> void:
	var entry := RuledTowns.enter(player, town)
	assert_eq(RuledTowns.entered(player, town + 1), {}, "another town's: none")
	assert_eq(RuledTowns.entered(player, town), entry)
	assert_eq(RuledTowns.entered(player, town), {}, "taken once")


# --------------------------------------------------------------- the duel --

func test_the_duel_the_engine_is_given() -> void:
	player.world.sites[town]["x"] = 8
	var entry := RuledTowns.enter(player, town)
	var met := RuledTowns.meeting(player, entry)
	var config := RuledTowns.duel_config(player, met)
	var row := int(entry["row"])
	assert_eq(config.ante_cards[0], entry["hero_ante"], "the hero's stake lifted out of the deck")
	assert_eq((config.ante_cards[0] as Array).size(), 3)
	assert_eq(config.ante_cards[1], entry["creature_ante"], "the creature's out of its library")
	assert_eq(config.decks[1], CreatureDeck.for_meeting(row, 0), "its maindeck")
	assert_eq(config.start_in_play[1], [met["card"]], "its wizard's minion in play")
	assert_eq(config.lives[1], CreatureBook.duel_life(row, player.difficulty))
	assert_eq(config.player_names[1], CreatureBook.duel_name(row))


# --------------------------------------------------------------- the end --

func test_a_win_frees_the_town_and_the_stake_joins_the_deck() -> void:
	player.next_duel_card = "Black Lotus"
	var entry := RuledTowns.enter(player, town)
	var met := RuledTowns.meeting(player, entry)
	var won := String((entry["creature_ante"] as Array)[0])
	var owned := player.cards.size()
	var out := RuledTowns.settle(player, met, _report(RuledTowns.WON))
	var name := WorldNames.site_name(player.world, town)
	assert_false(TownStatus.ruled(player.world, town), "freed")
	assert_false(TownStatus.linked(player.world, town), "its link stays lost")
	assert_eq(player.cards.size(), owned + 1)
	assert_eq(player.cards[-1], {"card": won, "decks": [0]}, "into the deck in use (as played)")
	assert_eq(out["words"], ["%s is freed! The people rejoice." % name] as Array[String])
	assert_eq(String(player.journal[-1]["event"]), "freed")
	assert_eq(String(player.journal[-1]["text"]), "Freed %s" % name)
	assert_eq(player.total_wins(), 0, "no victory logged")
	assert_eq(player.duel_record(), {"won": 0, "lost": 0}, "no Defeated line")
	assert_eq(HeroStats.record(player)["recovered"], 1, "1997's Cities Recovered")
	assert_eq(player.next_duel_card, "", "the gifts spent")


func test_a_loss_loses_each_staked_card() -> void:
	player.world.sites[town]["x"] = 8
	var entry := RuledTowns.enter(player, town)
	var met := RuledTowns.meeting(player, entry)
	var places: Array = entry["hero_ante_at"]
	var kept: Array[String] = []
	for i in player.cards.size():
		if not i in places:
			kept.append(String(player.cards[i]["card"]))
	var journal := player.journal.size()
	var out := RuledTowns.settle(player, met, _report(RuledTowns.LOST))
	assert_eq(out["lost"], entry["hero_ante"])
	var left: Array[String] = []
	for card in player.cards:
		left.append(String(card["card"]))
	assert_eq(left, kept, "the copies staked, gone")
	assert_true(TownStatus.ruled(player.world, town), "still ruled")
	assert_eq(player.journal.size(), journal, "no journal line")


## [Ours: 1997 slip — a draw lost the stake.]
func test_a_draw_changes_nothing() -> void:
	var entry := RuledTowns.enter(player, town)
	var met := RuledTowns.meeting(player, entry)
	var cards := player.cards.duplicate(true)
	var out := RuledTowns.settle(player, met, _report(RuledTowns.DRAWN))
	assert_eq(int(out["result"]), RuledTowns.DRAWN)
	assert_eq(player.cards, cards)
	assert_true(TownStatus.ruled(player.world, town))
	assert_eq(int(RuledTowns.settle(player, met, _report(RuledTowns.WON), true)["result"]), RuledTowns.LOST,
		"conceded: a loss")


func test_a_ruled_town_duel_played_to_each_result() -> void:
	player.world.sites[town]["x"] = 7
	var entry := RuledTowns.enter(player, town)
	var met := RuledTowns.meeting(player, entry)
	var config := RuledTowns.duel_config(player, met)
	config.lives = [3, 0] as Array[int]
	config.rng_seed = 2024
	var report: DuelReport = await HeadlessDuel.play(config)
	assert_true(report.hero_won(), report.describe())
	assert_eq(report.ante[0], entry["hero_ante"], "the hero's stake in the ante")
	assert_eq(report.ante[1], entry["creature_ante"])
	RuledTowns.settle(player, met, report)
	assert_false(TownStatus.ruled(player.world, town))
	_rule(town, 4)
	entry = RuledTowns.enter(player, town)
	met = RuledTowns.meeting(player, entry)
	config = RuledTowns.duel_config(player, met)
	config.lives = [0, 4] as Array[int]
	report = await HeadlessDuel.play(config)
	assert_true(report.hero_lost(), report.describe())
	var owned := player.cards.size()
	RuledTowns.settle(player, met, report)
	assert_eq(player.cards.size(), owned - (entry["hero_ante"] as Array).size())
	entry = RuledTowns.enter(player, town)
	met = RuledTowns.meeting(player, entry)
	config = RuledTowns.duel_config(player, met)
	config.lives = [0, 0] as Array[int]
	report = await HeadlessDuel.play(config)
	assert_true(report.is_draw(), report.describe())
	owned = player.cards.size()
	RuledTowns.settle(player, met, report)
	assert_eq(player.cards.size(), owned)
	assert_true(TownStatus.ruled(player.world, town))


func test_the_minion_starts_in_play() -> void:
	var entry := RuledTowns.enter(player, town)
	var met := RuledTowns.meeting(player, entry)
	var config := RuledTowns.duel_config(player, met)
	config.lives = [5, 5] as Array[int]
	config.rng_seed = 11
	var duel: HeadlessDuel = await HeadlessDuel.begin(config)
	var theirs: Array[String] = []
	for inst in duel.game.players[1].battlefield:
		theirs.append(inst.data.card_name)
	assert_true(theirs.has(String(met["card"])), "%s in play: %s" % [met["card"], theirs])
	duel.game.concede(0)
