extends GutTest
## PART B (W2, 2026-10-23): THE HEADLESS DUEL ([HeadlessDuel]) and the
## shared opening ([DuelOpening]) — an adventure duel played to its
## [DuelReport] with no screen, through the very setup the duel screen
## runs. This is the helper the adventure's own tests use, so it is pinned
## here on the things they will lean on: the result, the ante by owner and
## unsettled, the forced start, 1997's opening rules, Mind Control, the
## cards in play, life 0, and the same seed giving the same duel.


## Twenty Mountains and twenty Lightning Bolts: a duel at a few lives is
## over in a handful of turns.
func _bolts() -> Array:
	var out: Array = []
	for i in 20:
		out.append("Mountain")
		out.append("Lightning Bolt")
	return out


func _bears() -> Array:
	var out: Array = []
	for i in 20:
		out.append("Forest")
		out.append("Grizzly Bears")
	return out


func _config(lives: Array[int] = [3, 3], seed_value := 4242) -> DuelConfig:
	var config := DuelConfig.new()
	config.decks = [_bolts(), _bears()]
	config.player_names = ["Hero", "Creature"]
	config.pilots = [null, AiProfile.apprentice()]
	config.lives = lives
	config.rng_seed = seed_value
	return config


func _names(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for inst in cards:
		out.append(inst.data.card_name)
	return out


# ------------------------------------------------------------ the result --

func test_a_short_duel_is_played_to_its_result() -> void:
	var report: DuelReport = await HeadlessDuel.play(_config())
	assert_true(report.finished, report.describe())
	assert_true(report.result in [DuelReport.WIN, DuelReport.LOSS, DuelReport.DRAW])
	assert_eq(report.result, DuelReport.result_for(report.winner))
	assert_eq(report.lives_start, [3, 3] as Array[int])
	assert_eq(report.hero_life, report.lives_end[0])
	assert_gt(report.turns, 0)


func test_the_same_seed_is_the_same_duel() -> void:
	var a: DuelReport = await HeadlessDuel.play(_config([4, 4], 99))
	var b: DuelReport = await HeadlessDuel.play(_config([4, 4], 99))
	assert_eq(a.describe(), b.describe())


func test_the_result_reads_from_seat_zeros_side() -> void:
	assert_eq(DuelReport.result_for(0), DuelReport.WIN)
	assert_eq(DuelReport.result_for(1), DuelReport.LOSS)
	assert_eq(DuelReport.result_for(-1), DuelReport.DRAW)
	assert_eq([DuelReport.WIN, DuelReport.LOSS, DuelReport.DRAW], [1, 0, -1], "1997's own numbers")


func test_an_unfinished_duel_says_so() -> void:
	var duel: HeadlessDuel = await HeadlessDuel.begin(_config([20, 20]))
	var report := duel.report()
	assert_false(report.finished)
	assert_false(report.hero_won() or report.hero_lost() or report.is_draw())


func test_a_concession_after_begin_is_a_result() -> void:
	var duel: HeadlessDuel = await HeadlessDuel.begin(_config([20, 20]))
	duel.game.concede(1)
	var report := duel.play_out()
	assert_true(report.hero_won(), report.describe())


# --------------------------------------------------------------- the ante --

func test_the_ante_is_reported_by_owner_and_left_unsettled() -> void:
	var config := _config()
	config.ante_cards = [["Lightning Bolt"], ["Grizzly Bears"]]
	config.ante_extras = [[], ["Black Lotus"]]
	var duel: HeadlessDuel = await HeadlessDuel.begin(config)
	assert_true(duel.game.ante_enabled)
	assert_eq(duel.game.players[0].library.size() + duel.game.players[0].hand.size(), 39,
		"the hero's stake came out of the deck")
	var report := duel.play_out()
	assert_true(report.finished, report.describe())
	assert_eq(report.ante[0], ["Lightning Bolt"] as Array[String])
	assert_eq(report.ante[1], ["Grizzly Bears", "Black Lotus"] as Array[String])
	assert_eq(report.owner_changes.size(), 0)


func test_a_plain_duel_is_not_for_ante() -> void:
	var duel: HeadlessDuel = await HeadlessDuel.begin(_config([20, 20]))
	assert_false(duel.game.ante_enabled)
	assert_eq(duel.report().ante, [[], []])


# --------------------------------------------------------------- the start --

func test_a_forced_start_tosses_nothing_and_asks_nothing() -> void:
	for seat in [0, 1]:
		var config := _config([20, 20])
		config.first_player = seat
		var duel: HeadlessDuel = await HeadlessDuel.begin(config)
		assert_eq(duel.game.active_player, seat)
		assert_eq(duel.opening_lines[0], "%s will start first" % ["Hero", "Creature"][seat],
			"@DIALOG_MULLIGAN's lead line, not a toss winner's choice")
		for line in duel.opening_lines:
			assert_false(line.contains("play first") or line.contains("draw first"), line)


func test_a_forced_start_spends_no_rng_draw() -> void:
	var config := _config([20, 20])
	config.first_player = 1
	var game := MtgGame.new()
	DuelOpening.prepare(game, config, 7)
	var state := game.rng.state
	assert_eq(DuelOpening.first_seat(game, config), 1)
	assert_eq(game.rng.state, state)
	config.first_player = -1
	DuelOpening.first_seat(game, config)
	assert_ne(game.rng.state, state, "the toss is one draw")


func test_1997s_computer_plays_or_draws_at_random() -> void:
	var seen := {}
	for seed_value in range(1, 13):
		var config := _config([20, 20], seed_value)
		config.pilots = [AiProfile.apprentice(), AiProfile.apprentice()]
		config.ai_random_play_or_draw = true
		var duel: HeadlessDuel = await HeadlessDuel.begin(config)
		var line: String = duel.opening_lines[0]
		var winner := 0 if line.begins_with("Hero") else 1
		var plays := line.ends_with("will play first.")
		assert_true(plays or line.ends_with("has chosen to draw first."), line)
		assert_eq(duel.game.active_player, winner if plays else 1 - winner, line)
		seen[plays] = true
	assert_eq(seen.size(), 2, "both choices are made over twelve seeds")


func test_without_the_option_the_computer_takes_the_play() -> void:
	for seed_value in range(1, 7):
		var config := _config([20, 20], seed_value)
		config.pilots = [AiProfile.apprentice(), AiProfile.apprentice()]
		var duel: HeadlessDuel = await HeadlessDuel.begin(config)
		assert_true(duel.opening_lines[0].ends_with("will play first."), duel.opening_lines[0])


# -------------------------------------------------- 1997's adventure mulligan --

func test_1997s_creature_throws_back_an_all_land_hand_once() -> void:
	var config := _config([20, 20])
	var lands: Array = []
	for i in 40:
		lands.append("Forest")
	config.decks[1] = lands
	config.mulligan_rule = MtgGame.MULLIGAN_1997
	config.first_player = 0
	var duel: HeadlessDuel = await HeadlessDuel.begin(config)
	assert_true(duel.opening_lines.has("Creature has all land and will take a mulligan"),
		str(duel.opening_lines))
	assert_eq(duel.game.mulligans_taken[1], 1, "once, whatever it drew")
	assert_eq(duel.game.players[1].hand.size(), 7, "seven for seven")


func test_1997s_rule_never_deals_a_smaller_hand() -> void:
	# Ours deals one card fewer each redraw; 1997's is seven for seven and
	# once — every hand at turn 1 is seven, whoever redrew.
	for seed_value in range(1, 9):
		var config := _config([20, 20], seed_value)
		config.mulligan_rule = MtgGame.MULLIGAN_1997
		var duel: HeadlessDuel = await HeadlessDuel.begin(config)
		for pid in 2:
			assert_eq(duel.game.players[pid].hand.size(), 7, "seed %d seat %d" % [seed_value, pid])
			assert_lte(duel.game.mulligans_taken[pid], 1)


# ---------------------------------------- Mind Control and cards in play --

func test_mind_control_hands_the_creature_the_heros_deck() -> void:
	var config := _config([20, 20])
	config.first_player = 0
	config.mirror_seat0 = true
	var duel: HeadlessDuel = await HeadlessDuel.begin(config)
	var game := duel.game
	assert_eq(_names(game.players[1].hand), _names(game.players[0].hand),
		"the hero kept its seven and plays first: no draw yet")
	var mine := _names(game.players[0].library)
	var theirs := _names(game.players[1].library)
	mine.sort()
	theirs.sort()
	assert_eq(theirs, mine)
	assert_false(theirs.has("Grizzly Bears"), "nothing of its own deck is left")


func test_cards_in_play_stand_at_turn_one() -> void:
	var config := _config([20, 20])
	config.start_in_play = [["Wall of Wood"], ["Timber Wolves"]]
	var duel: HeadlessDuel = await HeadlessDuel.begin(config)
	assert_eq(_names(duel.game.players[0].battlefield), ["Wall of Wood"] as Array[String])
	assert_eq(_names(duel.game.players[1].battlefield), ["Timber Wolves"] as Array[String])


# ------------------------------------------------------------------ life 0 --

func test_life_zero_loses_before_anyone_acts() -> void:
	var report: DuelReport = await HeadlessDuel.play(_config([0, 5]))
	assert_true(report.hero_lost(), report.describe())
	assert_eq(report.turns, 1)
	assert_eq(report.lives_end, [0, 5] as Array[int])


# ------------------------------------------------- the shared opening --

func test_a_plain_config_is_dealt_as_the_screen_always_dealt_it() -> void:
	# The setup moved out of the duel screen into DuelOpening.prepare: a
	# config that asks for nothing new is the game it was — the libraries,
	# the random stake (the player's sparing basic lands) and the stream.
	var config := _config([20, 20])
	config.ante = 1
	var shared := MtgGame.new()
	DuelOpening.prepare(shared, config, 77)
	var old := MtgGame.new()
	old.setup(config.decks[0], config.decks[1], config.seat_name(0), config.seat_name(1),
		config.lives[0], config.lives[1], 77)
	CardPrintings.apply_game(old, config.printings)
	for pid in 2:
		old.stake_ante(pid, config.ante, not config.is_ai(pid))
	for pid in 2:
		assert_eq(_names(shared.players[pid].ante), _names(old.players[pid].ante))
		assert_eq(_names(shared.players[pid].library), _names(old.players[pid].library))
	assert_eq(shared.rng.state, old.rng.state)
	assert_eq(shared.mulligan_rule, "")
	assert_false(config.adventure_opening())
	assert_ne(_names(shared.players[0].ante)[0], "Mountain", "the player's stake spares basics")


func test_named_stakes_replace_the_random_count() -> void:
	var config := _config([20, 20])
	config.ante = 1
	config.ante_extras = [[], ["Mox Pearl"]]
	assert_true(config.plays_named_ante())
	assert_true(config.adventure_opening())
	var game := MtgGame.new()
	DuelOpening.prepare(game, config, 77)
	assert_eq(game.players[0].ante.size(), 0, "the lair: the hero stakes nothing")
	assert_eq(_names(game.players[1].ante), ["Mox Pearl"] as Array[String])
	assert_true(game.ante_enabled)


func test_a_malformed_seat_list_breaks_nothing() -> void:
	var config := _config([20, 20])
	config.ante_cards = [["Lightning Bolt"]]          # one seat only
	config.start_in_play = ["not a list", ["Wall of Wood"]]
	assert_eq(DuelConfig.seat_names(config.ante_cards, 1), [])
	assert_eq(DuelConfig.seat_names(config.start_in_play, 0), [])
	var duel: HeadlessDuel = await HeadlessDuel.begin(config)
	assert_eq(_names(duel.game.players[0].ante), ["Lightning Bolt"] as Array[String])
	assert_eq(_names(duel.game.players[1].battlefield), ["Wall of Wood"] as Array[String])
