extends GutTest
## PART B (W2, 2026-10-23): AN ADVENTURE DUEL ON THE DUEL SCREEN — held
## over another screen ([method DuelScreen.held]), dealt from its
## [DuelConfig]'s adventure fields, reporting back ([signal
## DuelScreen.duel_closed], [method DuelScreen.report]) — and the opening
## window under a forced start and 1997's adventure mulligan
## ([OpeningHand.forced_first], [constant MtgGame.MULLIGAN_1997]).
##
## Headless, the duel screen deals and begins at once, with no toss and no
## window (as it always has); the window's half is pinned through
## [OpeningHand] with a human seat, as tests/ui/test_opening_hand.gd does.


var host: Control


func before_each() -> void:
	host = Control.new()
	add_child_autofree(host)


func _bolts() -> Array:
	var out: Array = []
	for i in 20:
		out.append("Mountain")
		out.append("Lightning Bolt")
	return out


func _bears(lands := 20) -> Array:
	var out: Array = []
	for i in lands:
		out.append("Forest")
	for i in 40 - lands:
		out.append("Grizzly Bears")
	return out


## The adventure's config: the hero at seat 0 (a human), the creature at 1.
func _config() -> DuelConfig:
	var config := DuelConfig.new()
	config.decks = [_bolts(), _bears()]
	config.player_names = ["Hero", "Witch"]
	config.pilots = [null, AiProfile.apprentice()]
	config.lives = [9, 6]
	config.rng_seed = 4242
	config.ante_cards = [["Lightning Bolt"], ["Grizzly Bears"]]
	return config


const LEAVE := "Flee from the Witch? You can meet her again."
const MENU := "Quit the adventure for the main menu?"


func _held(config: DuelConfig) -> DuelScreen:
	return DuelScreen.held(config, "Duel", LEAVE, MENU, "Flee")


func _names(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for inst in cards:
		out.append(inst.data.card_name)
	return out


# ------------------------------------------------------------- hosting --

func test_held_makes_a_held_duel_not_yet_in_the_tree() -> void:
	var config := _config()
	var duel := _held(config)
	assert_false(duel.is_inside_tree())
	assert_eq(duel.config, config)
	assert_eq(duel.leave_title, "Duel")
	assert_eq(duel.leave_question, LEAVE)
	assert_eq(duel.menu_question, MENU)
	assert_eq(duel.leave_label, "Flee")
	duel.free()


func test_the_adventure_duel_is_dealt_as_its_config_says() -> void:
	var config := _config()
	config.ante_extras = [[], ["Black Lotus"]]
	config.first_player = 1
	config.start_in_play = [[], ["Timber Wolves"]]
	var duel := _held(config)
	host.add_child(duel)
	await get_tree().process_frame
	var game := duel.game
	assert_eq(_names(game.players[0].ante), ["Lightning Bolt"] as Array[String])
	assert_eq(_names(game.players[1].ante), ["Grizzly Bears", "Black Lotus"] as Array[String])
	assert_eq(game.players[0].library.size() + game.players[0].hand.size(), 39)
	assert_eq(game.active_player, 1, "First Strike: the creature starts")
	assert_eq(game.turn_number, 1)
	assert_eq(_names(game.players[1].battlefield), ["Timber Wolves"] as Array[String])
	assert_eq(game.players[0].life, 9)
	assert_eq(game.players[1].life, 6)


func test_a_won_duel_reports_and_closes_once() -> void:
	var duel := _held(_config())
	var finished: Array = []
	var closed: Array = []
	duel.duel_finished.connect(func(winner: int) -> void: finished.append(winner))
	duel.duel_closed.connect(func(report: DuelReport) -> void: closed.append(report))
	host.add_child(duel)
	await get_tree().process_frame
	duel.game.concede(1)
	await get_tree().process_frame
	assert_eq(finished, [0])
	assert_eq(closed.size(), 1, "headless: at once, there is no window to wait on")
	var report: DuelReport = closed[0]
	assert_true(report.hero_won(), report.describe())
	assert_eq(report.ante[0], ["Lightning Bolt"] as Array[String])
	assert_eq(report.ante[1], ["Grizzly Bears"] as Array[String])
	assert_eq(report.lives_start, [9, 6] as Array[int])
	# The engine settled nothing: the stakes are where and whose they were.
	for pid in 2:
		for inst in duel.game.players[pid].ante:
			assert_eq(inst.owner_id, pid)
	assert_eq(duel.report().describe(), report.describe(), "and report() says the same")
	assert_true(duel.is_inside_tree(), "the holder takes it away, not the screen")


func test_a_lost_duel_reports_a_loss() -> void:
	var duel := _held(_config())
	var closed: Array = []
	duel.duel_closed.connect(func(report: DuelReport) -> void: closed.append(report))
	host.add_child(duel)
	await get_tree().process_frame
	duel.game.concede(0)
	assert_true((closed[0] as DuelReport).hero_lost())


func test_life_zero_ends_the_held_duel_at_once() -> void:
	var config := _config()
	config.lives = [0, 6]
	var duel := _held(config)
	var closed: Array = []
	duel.duel_closed.connect(func(report: DuelReport) -> void: closed.append(report))
	host.add_child(duel)
	await get_tree().process_frame
	assert_true(duel.game.game_over)
	assert_eq(closed.size(), 1)
	assert_true((closed[0] as DuelReport).hero_lost())
	assert_eq((closed[0] as DuelReport).turns, 1)


func test_fleeing_asks_and_the_yes_is_the_holders() -> void:
	var duel := _held(_config())
	var fled := [0]
	var closed := [0]
	duel.leave_confirmed.connect(func() -> void: fled[0] += 1)
	duel.duel_closed.connect(func(_r: DuelReport) -> void: closed[0] += 1)
	host.add_child(duel)
	await get_tree().process_frame
	var scene := get_tree().current_scene
	duel._open_pause()
	duel._on_pause_chosen(DuelPause.Action.EXIT_DUEL)
	assert_true(duel.leave_question_open(), "a held duel asks")
	duel._confirm_leave()
	assert_eq(fled[0], 1)
	assert_eq(get_tree().current_scene, scene, "no scene change under a holder")
	assert_true(duel.is_inside_tree())
	assert_false(duel.report().finished, "fled: nothing lost or won")
	assert_eq(closed[0], 0, "and no result to settle")


func test_the_main_menu_asks_and_the_yes_is_the_holders() -> void:
	var duel := _held(_config())
	var asked := [0]
	duel.menu_confirmed.connect(func() -> void: asked[0] += 1)
	host.add_child(duel)
	await get_tree().process_frame
	duel._open_pause()
	duel._on_pause_chosen(DuelPause.Action.MAIN_MENU)
	assert_true(duel.leave_question_open())
	duel._confirm_leave()
	assert_eq(asked[0], 1)
	assert_true(duel.is_inside_tree())


func test_every_duel_closes_with_a_report() -> void:
	# One signal for every holder, the plain duel's too.
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	var closed: Array = []
	duel.duel_closed.connect(func(report: DuelReport) -> void: closed.append(report))
	host.add_child(duel)
	await get_tree().process_frame
	assert_false(duel.game.ante_enabled, "a plain duel is not for ante")
	duel.game.concede(0)
	assert_eq(closed.size(), 1)
	assert_eq((closed[0] as DuelReport).winner, 1)


func test_mind_control_on_the_screen() -> void:
	var config := _config()
	config.mirror_seat0 = true
	config.first_player = 0
	var duel := _held(config)
	host.add_child(duel)
	await get_tree().process_frame
	var game := duel.game
	assert_eq(_names(game.players[1].hand), _names(game.players[0].hand))
	assert_false(_names(game.players[1].library).has("Grizzly Bears"))
	assert_eq(_names(game.players[1].ante), ["Grizzly Bears"] as Array[String],
		"its stake was its own")


func _first_on_screen(seed_value: int, random_choice: bool) -> int:
	var config := _config()
	config.rng_seed = seed_value
	config.ai_random_play_or_draw = random_choice
	var duel := _held(config)
	host.add_child(duel)
	await get_tree().process_frame
	var first := duel.game.active_player
	duel.queue_free()
	await get_tree().process_frame
	return first


func test_an_ai_toss_winner_may_draw_on_the_screen() -> void:
	# Headless the screen has no window: the computer's random choice is
	# still made, on the duel's rng (DuelOpening.first_without_windows).
	# The same seed with the option off is the plain toss: the winner plays.
	var drew := 0
	for seed_value in range(1, 13):
		var plain: int = await _first_on_screen(seed_value, false)
		var chosen: int = await _first_on_screen(seed_value, true)
		if plain != chosen:
			drew += 1
			assert_eq(plain, 1, "only the computer's toss is a coin of its own")
	assert_gt(drew, 0, "the computer drew first at least once in twelve seeds")


# -------------------------------------------- the opening window, forced --

func _deal(deck0: Array, deck1: Array, rule := "") -> MtgGame:
	var game := MtgGame.new()
	game.setup(deck0, deck1, "Hero", "Witch", 20, 20, 424242)
	game.stake_named_ante(0, ["Lightning Bolt"])
	game.stake_named_ante(1, ["Grizzly Bears"])
	game.mulligan_rule = rule
	game.deal_opening_hands(7)
	return game


## The opening with seat 0 at the screen, [param seat] given as the start.
func _opening(game: MtgGame, seat: int, forced := true) -> OpeningHand:
	var opening := OpeningHand.new()
	opening.forced_first = forced
	host.add_child(opening)
	opening.run(game, seat, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	return opening


func _press(window: OpeningWindow, label: String) -> void:
	assert_true(window.press(label), "no such button up: %s (have %s)" % [label, window.button_labels()])
	await get_tree().process_frame
	await get_tree().process_frame


func test_a_forced_start_asks_no_order() -> void:
	var game := _deal(_bolts(), _bears())
	var lines: Array[String] = []
	var opening := OpeningHand.new()
	opening.forced_first = true
	opening.announced.connect(func(line: String) -> void: lines.append(line))
	host.add_child(opening)
	opening.run(game, 1, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var window := opening.window()
	assert_eq(window.lead_text(), "Witch will start first", "@DIALOG_MULLIGAN entry 1")
	assert_eq(window.button_labels(), PackedStringArray(["Take mulligan", "Start the duel"]),
		"straight to the hand: no Play first / Draw first")
	assert_eq(lines[0], "Witch will start first")
	assert_eq(window.card_names().size(), 2, "both antes up")
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1)
	assert_eq(game.active_player, 1)


func test_the_players_forced_start_says_you() -> void:
	var game := _deal(_bolts(), _bears())
	var opening: OpeningHand = await _opening(game, 0)
	var window := opening.window()
	assert_eq(window.lead_text(), "You will take the first turn", "@DIALOG_MULLIGAN entry 2")
	await _press(window, "Start the duel")
	assert_eq(game.active_player, 0)


# ------------------------------------- the opening window, 1997's mulligan --

func test_1997_an_ordinary_hand_is_offered_nothing() -> void:
	var game := _deal(_bolts(), _bears(), MtgGame.MULLIGAN_1997)
	assert_false(game.hand_is_a_mulligan_hand(0), "a mixed deck's hand")
	var opening: OpeningHand = await _opening(game, 0)
	var window := opening.window()
	assert_eq(window.button_labels(), PackedStringArray(["Start the duel"]),
		"1997's dialog had only its OK for a hand with land and spells")
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1)
	assert_eq(game.mulligans_taken, [0, 0] as Array[int])


func test_1997_a_no_land_hand_is_redrawn_once_for_seven() -> void:
	var game := _deal(_bears(0), _bears(), MtgGame.MULLIGAN_1997)
	_set_hand(game, 1, 3)
	var lines: Array[String] = []
	var opening := OpeningHand.new()
	opening.forced_first = true
	opening.announced.connect(func(line: String) -> void: lines.append(line))
	host.add_child(opening)
	opening.run(game, 0, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var window := opening.window()
	assert_eq(window.button_labels(), PackedStringArray(["Take mulligan", "Start the duel"]))
	await _press(window, "Take mulligan")
	assert_eq(game.players[0].hand.size(), 7, "free: seven again")
	assert_eq(game.mulligans_taken[0], 1)
	assert_true(lines.has("Hero has no land and chose to take a mulligan"),
		"1997's line, with no count: %s" % str(lines))
	# Still no land — and no second offer: the creature's answer is the
	# news, and the window's last look is `Start the duel` alone.
	assert_eq(window.button_labels(), PackedStringArray(["Start the duel"]))
	assert_eq(window.status_text(), "Witch decided not to take a mulligan")
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1)
	assert_eq(game.players[0].hand.size(), 7)


func test_1997_the_creatures_redraw_is_up_before_the_player_is_asked() -> void:
	var game := _deal(_bolts(), _bears(40), MtgGame.MULLIGAN_1997)   # all land
	var opening: OpeningHand = await _opening(game, 0)
	var window := opening.window()
	assert_eq(window.status_text(), "Witch has all land and will take a mulligan",
		"the 1997 dialog opened on it")
	assert_eq(game.mulligans_taken[1], 1)
	assert_eq(game.players[1].hand.size(), 7)
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1)


## Test-only surgery: [param pid]'s hand made [param lands] Forests and the
## rest Grizzly Bears, out of its own library.
func _set_hand(game: MtgGame, pid: int, lands: int) -> void:
	var p := game.players[pid]
	for inst in p.hand:
		inst.zone = Mtg.Zone.LIBRARY
		p.library.append(inst)
	p.hand.clear()
	var want := {"Forest": lands, "Grizzly Bears": 7 - lands}
	for card_name in want:
		for i in int(want[card_name]):
			for j in range(p.library.size() - 1, -1, -1):
				if p.library[j].data.card_name == card_name:
					var inst: CardInstance = p.library[j]
					p.library.remove_at(j)
					inst.zone = Mtg.Zone.HAND
					p.hand.append(inst)
					break


func test_1997_the_creature_follows_a_redraw_with_a_poor_hand() -> void:
	# The creature's hand of one land: kept, unless the hero redrew — then
	# it goes again ("will also take a mulligan").
	var game := _deal(_bears(0), _bears(), MtgGame.MULLIGAN_1997)
	_set_hand(game, 1, 1)
	var opening: OpeningHand = await _opening(game, 0)
	var window := opening.window()
	assert_eq(window.status_text(), "", "a one-land hand is not thrown back on its own")
	await _press(window, "Take mulligan")
	assert_eq(game.mulligans_taken, [1, 1] as Array[int])
	assert_eq(window.status_text(), "Witch will also take a mulligan")
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1)


func test_1997_the_creature_keeps_a_fair_hand_after_a_redraw() -> void:
	var game := _deal(_bears(0), _bears(), MtgGame.MULLIGAN_1997)
	_set_hand(game, 1, 3)
	var opening: OpeningHand = await _opening(game, 0)
	var window := opening.window()
	await _press(window, "Take mulligan")
	assert_eq(game.mulligans_taken, [1, 0] as Array[int])
	assert_eq(window.status_text(), "Witch decided not to take a mulligan")
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1)
