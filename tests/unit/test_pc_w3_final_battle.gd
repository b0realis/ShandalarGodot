extends GutTest
## PART C, W3 — ARZAKON'S BATTLE AND THE SCORE ([FinalBattle]): the end
## score exactly as `CalculateDungeonEndgameScore` (dungeonEncounter.c
## 1856–1888) with the owner's fixes — the golden vectors of the c3 spec's
## §4 table —; the final battle's years under each rule (as played, lives
## lost; floored or not; overkill); the duel handed to the engine
## (Arzakon's row on the dice, his 138 cards, his life by difficulty, Black
## Lotus then Celestial Prism, no stake, 1997's coin and mulligan, the
## hero's deck padded, his name); the hero's life; and the 1997 words.

## A world of white plains: towns 0–2 linked, town 3 not; the five castles
## (encounter slots 0–4) on their tiles.
func _player(difficulty := 0) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 6
	for i in 4:
		world.sites.append({"x": 20 + i * 3, "y": 20, "type": ShandalarWorld.TOWN, "trade": 0,
			"status": TownStatus.LINKED if i < 3 else 0})
	for i in 5:
		world.encounters.append({"x": 10 + i * 8, "y": 40, "color": i + 1, "clues": 0, "cards": []})
	world.lair_respawn = [0, 0, 0, 0, 0, 0, 0, 0] as Array[int]
	var player := AdventurePlayer.new()
	player.world = world
	player.difficulty = difficulty
	player.name = "Ysolde Starfall"
	player.portrait = "melody_whisp"
	player.position = Vector2i(25 * 32 + 16, 25 * 32 + 16)
	player.dice = 4242
	for i in 12:
		player.cards.append({"card": "Grizzly Bears", "decks": [0]})
	return player


## Wins of [param kinds] in the victory log.
func _wins(player: AdventurePlayer, kinds: Array) -> void:
	for kind in kinds:
		player.duel_victories.append({"color": 1, "kind": kind, "creature": ""})


const CASE_A := [1, 1, 4, 4, 4, 7, 7, 9, 9, 11]


# ------------------------------------------------------------ the score --

func test_the_golden_vectors_of_the_end_score() -> void:
	var a := _player()
	a.siege_count = 4
	_wins(a, CASE_A)
	var parts := FinalBattle.score_parts(a)
	assert_eq(parts["kinds_sum"], 77, "Σ (k + 2)")
	assert_eq([parts["sieges"], parts["ruled"], parts["wins"], parts["castle_wizards"]], [4, 0, 10, 0])
	assert_eq(FinalBattle.score(a), 130, "A: 2 · (−12 + 77)")
	TownStatus.take(a.world, 3, 2)
	assert_eq(FinalBattle.score(a), 118, "A′, one town ruled: 2 · (−18 + 77)")
	TownStatus.release(a.world, 3)
	_wins(a, [CreatureBook.CASTLE_WIZARD])
	assert_eq(FinalBattle.score(a), 208, "A and a castle wizard: 14 + 25 more, doubled")
	assert_eq(FinalBattle.score_parts(a)["castle_wizards"], 1)
	var b := _player()
	b.siege_count = 30
	_wins(b, [8, 8, 8, 8, 8])
	assert_eq(FinalBattle.score_parts(b)["kinds_sum"], 50)
	assert_eq(FinalBattle.score(b), -80, "B: 2 · (−90 + 50)")
	assert_eq(FinalBattle.shown(FinalBattle.score(b)), 0, "shown as 0 years")
	assert_eq(FinalBattle.score(_player()), 0, "nothing done: 0")


func test_the_score_so_far_is_the_heros_record() -> void:
	var a := _player()
	a.siege_count = 4
	_wins(a, CASE_A)
	assert_eq(a.score_so_far(), 130, "the record page's number is the end's")


func test_a_win_logged_without_its_kind_counts_by_its_creature() -> void:
	var player := _player()
	player.duel_victories.append({"color": 1, "kind": -1, "creature": "Witch"})
	player.duel_victories.append({"color": 1, "kind": -1, "creature": "No Such Creature"})
	var witch := CreatureBook.kind(CreatureBook.row_named("Witch"))
	assert_eq(FinalBattle.score_parts(player)["kinds_sum"], witch + 2 + 2, "the Witch's kind; else kind 0")
	assert_eq(FinalBattle.victory_kind("not a win"), 0)


func test_the_sieges_count_a_start_and_a_fall_and_the_freed_towns_cost_nothing() -> void:
	var player := _player()
	player.world.sites.append({"x": 10, "y": 40, "type": ShandalarWorld.CASTLE, "trade": 0, "status": 0})
	player.world.page[40 * ShandalarWorld.PAGE_WIDTH + 10] = 3   # black land under the castle
	Sieges.start(player)
	assert_eq(player.siege_count, 1, "a siege begun")
	var news := Sieges.resolve(player)
	assert_eq(String(news[0]["kind"]), "fall")
	assert_eq(player.siege_count, 2, "and the town fallen: one more")
	var parts := FinalBattle.score_parts(player)
	assert_eq([parts["sieges"], parts["ruled"]], [2, 1])
	assert_eq(FinalBattle.score(player), 2 * (3 * (-2 - 2)), "−24: the sieges and the town held")
	Sieges.free_all(player, 1)
	assert_eq(FinalBattle.score(player), -12, "the wizard beaten: his towns freed, R = 0")


# ------------------------------------------------------- the final years --

func test_the_years_as_played() -> void:
	var played := {"years": FinalBattle.AS_PLAYED, "base": FinalBattle.AS_PLAYED}
	assert_eq(FinalBattle.final_score(130, 100, 0, played), 1130, "d 0 won at 0: base + 1000")
	assert_eq(FinalBattle.final_score(130, 100, -7, played), 1200, "overkill −7: + 1070")
	assert_eq(FinalBattle.final_score(130, 400, 400, played), -2870, "d 3 lost at 400: − 3000")
	assert_eq(FinalBattle.final_score(-80, 100, 0, played), 920, "B: told 0 years, given 920 (C3-3)")


func test_the_years_for_each_life_lost() -> void:
	assert_eq(FinalBattle.final_score(130, 400, 0), 4130, "d 3 won at 0: + 4000")
	assert_eq(FinalBattle.final_score(130, 400, 250), 1630, "lost at 250: + 1500")
	assert_eq(FinalBattle.final_score(-80, 100, 0), 1000, "B floored first: 0 + 1000")
	assert_eq(FinalBattle.years(400, 450), 0, "never fewer than 0")
	assert_eq(FinalBattle.final_score(-80, 100, 0, {"base": FinalBattle.AS_PLAYED}), 920,
		"unfloored, as played")
	assert_eq(FinalBattle.years(100, -7), 1070, "overkill counted: a life below 0 is a life lost")
	assert_eq(FinalBattle.years(100, -7, {"overkill": false}), 1000, "capped at his starting life")
	assert_eq(FinalBattle.RULES["years"], FinalBattle.LIVES_LOST, "the owner's b2")
	assert_eq(FinalBattle.RULES["base"], FinalBattle.FLOORED, "the owner's C3-3")


# --------------------------------------------------------------- the duel --

func test_arzakons_duel() -> void:
	for d in 4:
		var player := _player(d)
		var config := FinalBattle.duel_config(player)
		assert_eq(config.lives[1], 100 * d + 100, "his life at difficulty %d" % d)
		assert_eq((config.decks[0] as Array).size(), CreatureMeeting.DECK_LEAST[d],
			"the hero's twelve cards padded to %d" % CreatureMeeting.DECK_LEAST[d])
		assert_eq(config.pilots[1].profile_name, CreatureMeeting.ai_for(d).profile_name)
	var config := FinalBattle.duel_config(_player())
	assert_eq((config.decks[1] as Array).size(), 138, "his deck 999: the maindeck alone")
	assert_eq(config.decks[1], CreatureDeck.for_meeting(55, 0))
	assert_eq(config.start_in_play[1], ["Black Lotus", "Celestial Prism"], "in this order")
	assert_eq(config.start_in_play[0], [], "nothing of the hero's")
	assert_eq([config.ante_cards, config.ante_extras], [[[], []], [[], []]], "no stake either side (C3-4)")
	assert_eq(config.mulligan_rule, MtgGame.MULLIGAN_1997)
	assert_eq(config.first_player, -1, "1997's coin")
	assert_true(config.ai_random_play_or_draw)
	assert_eq(config.player_names, ["Ysolde Starfall", "Arzakon"] as Array[String], "named Arzakon")
	assert_eq(config.deck_names, ["Deck 1", "Arzakon"] as Array[String])
	assert_eq(config.portraits, ["melody_whisp", CreatureBook.face_id(55)] as Array[String])
	assert_eq(config.lives[0], 3, "three linked towns, no gift: three lives")


func test_his_name_as_played() -> void:
	var config := FinalBattle.duel_config(_player(), 0, {"name": FinalBattle.AS_PLAYED})
	assert_eq(config.player_names[1], "Uber Villain", "part B's @DECKFACES name")


func test_his_row_is_drawn_on_the_adventures_dice_before_the_deck_is_padded() -> void:
	var player := _player()
	var dice := MsvcRandom.new(player.dice)
	var row := CreatureBook.pick(dice, 0, FinalBattle.TIER)
	assert_true(row in [55, 56], "a tier-100 row")
	assert_eq(FinalBattle.draw_row(player), row)
	assert_eq(player.dice, dice.state, "the dice given back")
	var again := _player()
	var expected := MsvcRandom.new(again.dice)
	CreatureBook.pick(expected, 0, FinalBattle.TIER)
	var padded := _player()
	padded.dice = expected.state
	var deck := CreatureMeeting.padded_deck(padded, padded.deck_cards())
	var config := FinalBattle.duel_config(again)
	assert_eq(config.decks[0], deck, "then the padding, on the same dice")
	assert_eq(again.dice, padded.dice)


func test_the_heros_life_and_the_worlds_gifts() -> void:
	var player := _player()
	player.next_duel_life = 3
	player.next_duel_life_carried = -1
	player.next_duel_first_move = true
	player.next_duel_card = "Lord of Atlantis"
	assert_eq(FinalBattle.hero_life(player, 9), 3 + 3 - 1, "links and the next duel's lives; no pool")
	assert_eq(FinalBattle.hero_life(player, 9, {"pool": FinalBattle.AS_PLAYED}), 3 + 2 + 9,
		"as played the castle's pool reaches him")
	var config := FinalBattle.duel_config(player, 9)
	assert_eq(config.lives[0], 5)
	assert_eq(config.first_player, 0, "the first move the world gave")
	assert_eq(config.start_in_play[0], ["Lord of Atlantis"], "the hero's next-duel card")
	assert_eq(config.start_in_play[1], ["Black Lotus", "Celestial Prism"])


func test_the_duel_is_dealt_with_his_artifacts_in_play() -> void:
	var config := FinalBattle.duel_config(_player())
	config.rng_seed = 4242
	var duel: HeadlessDuel = await HeadlessDuel.begin(config)
	var names: Array[String] = []
	for inst in duel.game.players[1].battlefield:
		names.append(inst.data.card_name)
	assert_eq(names, ["Black Lotus", "Celestial Prism"] as Array[String], "both at turn 1")
	assert_eq(duel.game.players[1].life, 100)
	assert_eq(duel.game.players[0].ante.size() + duel.game.players[1].ante.size(), 0, "no ante")


# --------------------------------------------------------------- the words --

func test_the_words_are_1997s() -> void:
	assert_eq(FinalBattle.fifth_lines(), ["You have defeated all five wizards!", "Shandalar is free!",
		"Prepare to face the final challenge."] as Array[String])
	assert_eq(FinalBattle.banish_lines(-80), ["Your battles so far will banish the evil",
		"Planeswalker Arzakon for 0 years.", "Each life it loses in the Final Battle",
		"will banish it for 10 additional years.", "Good Luck!"] as Array[String], "shown no lower than 0")
	assert_eq(FinalBattle.banish_lines(130)[1], "Planeswalker Arzakon for 130 years.")
	assert_eq(FinalBattle.win_lines(4130), ["You have protected the", "plane of Shandalar for",
		"the next 4130 years.", "The people rejoice!", "", "Life is good!"] as Array[String])
	var failed := FinalBattle.failed_lines()
	assert_eq(failed[0], "Your Righteous Quest has Failed")
	assert_true("have worn you down" in failed, "@QUESTFAILED 4")
	assert_eq(failed[failed.size() - 1], "to challenge the great Arzakon and his Slimy Minions")


func test_all_five_beaten() -> void:
	var player := _player()
	assert_false(FinalBattle.all_beaten(player))
	for hue in AdventurePlayer.COLORS:
		player.defeated_wizards.append(hue)
	assert_true(FinalBattle.all_beaten(player))
	assert_false(FinalBattle.all_beaten(null))


## THE HAND-OFF FROM THE CASTLES (part C's W2, [CastleWin]): five wizards
## beaten by [method CastleWin.beat] are five castle wizards in the victory
## log, each paying its kind + 2 and the designed 25 more (the owner's SC2,
## §27 of the unused features: 78 years a castle); the fifth one's castle
## is where the portal stands.
func test_five_castle_wins_hand_over_to_the_end() -> void:
	var player := _player()
	for index in [0, 1, 3, 4, 2]:
		CastleWin.beat(player, index)
	assert_true(FinalBattle.all_beaten(player))
	var parts := FinalBattle.score_parts(player)
	assert_eq(parts["castle_wizards"], 5)
	assert_eq(FinalBattle.score(player), 5 * 78, "78 years a castle wizard")
	assert_eq(FinalBattle.fifth_castle(player), 2, "green's, beaten last")
