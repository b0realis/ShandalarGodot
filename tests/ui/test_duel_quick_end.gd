extends GameTest
## A DUEL ENDED BY ONE KEY, for testers: with the game started as
## `-- --debug-win` ([method MainScreen.read_debug_win]), Ctrl+Shift+W in a
## duel on this computer makes the other seat lose through the engine's own
## loss path ([member DuelScreen.debug_win]), so what follows a won duel —
## the verdict, the report, an adventure meeting's spoils — runs as after a
## real win. Refused at an SGManalink table, in the MPN replay, in a demo and
## at a two-human table; without the flag the key, the line and the log are
## exactly as before.


## A world screen that never leaves for the title (the meeting's fixture,
## tests/ui/test_b_w5_encounter_pane.gd).
class Walk extends WorldScreen:
	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_duel_quick_end"

var viewport: SubViewport
var finished: Array = []
var closed: Array = []
var referee: SgPracticeMatch


func before_each() -> void:
	super()
	DuelScreen.debug_win = false
	finished = []
	closed = []
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)


func after_each() -> void:
	DuelScreen.debug_win = false
	referee = null
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	await get_tree().process_frame


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## The flag as the title reads it off the command line.
func _flag_on() -> void:
	MainScreen.read_debug_win(PackedStringArray([MainScreen.DEBUG_WIN_FLAG]))


## Ctrl+Shift+W (or [param keycode] with the same modifiers) through the
## viewport, down and up.
func _key(ctrl := true, shift := true, alt := false, keycode := KEY_W) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.ctrl_pressed = ctrl
	down.shift_pressed = shift
	down.alt_pressed = alt
	down.pressed = true
	viewport.push_input(down, true)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames()


## A duel on [param config] in the viewport, dealt (headless: no toss).
func _duel(config: DuelConfig) -> DuelScreen:
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	screen.duel_finished.connect(func(winner: int) -> void: finished.append(winner))
	screen.duel_closed.connect(func(report: DuelReport) -> void: closed.append(report))
	viewport.add_child(screen)
	await _frames()
	return screen


func _vs_ai(human := 0) -> DuelConfig:
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	if human == 1:
		config.pilots = [AiProfile.wizard(), null]
	config.pace = 30.0   # the computer stays still while the test presses
	return config


func _line(screen: Node) -> Label:
	return screen.find_child("DebugWinLine", true, false) as Label


func _logged(screen: DuelScreen, text: String) -> bool:
	for line in screen.game.log_lines:
		if text in str(line):
			return true
	return false


# ---------------------------------------------------------- the switch --

func test_the_flag_is_read_from_the_command_line_and_nothing_else() -> void:
	MainScreen.read_debug_win(PackedStringArray())
	assert_false(DuelScreen.debug_win, "no flag, no key")
	MainScreen.read_debug_win(PackedStringArray(["--deck-lab", "--debug", "--win"]))
	assert_false(DuelScreen.debug_win, "only the flag itself")
	_flag_on()
	assert_true(DuelScreen.debug_win)
	assert_eq(MainScreen.DEBUG_WIN_FLAG, "--debug-win")


func test_without_the_flag_the_key_line_and_log_are_as_before() -> void:
	var screen := await _duel(_vs_ai())
	assert_null(_line(screen), "no line on the table")
	var lines := screen.game.log_lines.size()
	await _key()
	assert_false(screen.game.game_over, "the key does nothing")
	assert_eq(finished, [])
	assert_eq(screen.game.log_lines.size(), lines, "nothing in the log")
	assert_false(_logged(screen, DuelScreen.DEBUG_WIN_REASON))
	assert_eq(screen._debug_win_seat(), -1)


# ---------------------------------------------------- a duel on this desk --

func test_with_the_flag_the_key_wins_a_local_duel() -> void:
	_flag_on()
	var screen := await _duel(_vs_ai())
	var line := _line(screen)
	assert_not_null(line, "the table says the key is live")
	if line != null:
		assert_eq(line.text, DuelScreen.DEBUG_WIN_LINE)
		assert_true(line.is_visible_in_tree())
	await _key()
	assert_true(screen.game.game_over, "won at once")
	assert_eq(screen.game.winner, 0, "for the human seat")
	assert_true(screen.game.players[1].has_lost, "the computer lost, by the engine's loss")
	assert_true(_logged(screen, "loses: %s." % DuelScreen.DEBUG_WIN_REASON), "the log notes it")
	assert_eq(finished, [0], "the verdict, once")
	assert_eq(closed.size(), 1, "the duel's last word (headless: at once)")
	if closed.size() == 1:
		var report: DuelReport = closed[0]
		assert_true(report.finished)
		assert_eq(report.result, DuelReport.WIN)
	assert_eq(screen._prompt_label.text, "You won!")


func test_the_key_wins_for_a_human_in_the_top_seat() -> void:
	_flag_on()
	var screen := await _duel(_vs_ai(1))
	assert_not_null(_line(screen))
	await _key()
	assert_eq(screen.game.winner, 1)
	assert_true(screen.game.players[0].has_lost)


func test_only_ctrl_shift_w_is_the_key() -> void:
	_flag_on()
	var screen := await _duel(_vs_ai())
	await _key(true, false)            # Ctrl+W
	await _key(false, true)            # Shift+W
	await _key(true, true, true)       # Ctrl+Shift+Alt+W
	await _key(true, true, false, KEY_Q)
	assert_false(screen.game.game_over, "none of them wins")
	await _key()
	assert_true(screen.game.game_over)


func test_the_key_closes_the_pause_window_and_wins() -> void:
	_flag_on()
	var screen := await _duel(_vs_ai())
	screen._toggle_pause()
	assert_true(screen.is_paused())
	await _key()
	assert_false(screen.is_paused(), "the window closed")
	assert_eq(screen.game.winner, 0)


func test_before_the_duel_has_begun_there_is_nothing_to_win() -> void:
	_flag_on()
	var screen := await _duel(_vs_ai())
	screen._toss_active = true          # the toss / opening hand (not headless)
	await _key()
	assert_false(screen.game.game_over)
	assert_eq(screen._prompt_label.text, DuelScreen.DEBUG_WIN_EARLY)
	screen._toss_active = false
	await _key()
	assert_true(screen.game.game_over)


func test_a_finished_duel_stays_as_it_ended() -> void:
	_flag_on()
	var screen := await _duel(_vs_ai())
	assert_eq(screen.game.concede(0), "")
	await _frames()
	await _key()
	assert_eq(screen.game.winner, 1, "a lost duel is not turned into a win")
	assert_eq(finished, [1])


# ------------------------------------------------------------ refused --

func test_refused_at_a_hotseat() -> void:
	_flag_on()
	var screen := await _duel(DuelConfig.hotseat_default())   # two humans, open
	assert_null(_line(screen), "no single human to win for")
	await _key()
	assert_false(screen.game.game_over)
	var private := DuelConfig.hotseat_default()
	private.hotseat_privacy = true
	var other := await _duel(private)
	assert_null(_line(other))
	assert_eq(other._debug_win_seat(), -1)


func test_refused_in_a_demo() -> void:
	_flag_on()
	var config := DuelConfig.demo_default()
	config.pace = 30.0
	var screen := await _duel(config)
	assert_null(_line(screen), "no human seat")
	await _key()
	assert_false(screen.game.game_over)
	assert_false(_logged(screen, DuelScreen.DEBUG_WIN_REASON))


func test_refused_at_an_sgmanalink_table() -> void:
	_flag_on()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.present({"id": "r1", "name": "Quick end", "seat": 0, "names": ["One", "Two"],
		"revision": 1, "ready": [true, true], "connected": [true, true],
		"game": referee.view(0), "deck_names": referee.deck_names.duplicate(), "deck": {}},
		true, false)
	await _frames()
	assert_null(_line(screen), "no line at a LAN table")
	assert_eq(screen._debug_win_seat(), -1, "the host's game, not this computer's")
	await _key()
	assert_false(g.game_over, "the host's duel goes on")
	assert_false(screen.game.game_over, "and so does the table's view of it")


func test_refused_in_the_mpn_replay() -> void:
	_flag_on()
	var table := MpnDuelTable.new()
	viewport.add_child(table)
	await _frames()
	assert_null(_line(table))
	assert_eq(table._debug_win_seat(), -1, "a replay has no human seat")
	await _key()
	assert_false(table.game.game_over)


# ------------------------------------------------- an adventure meeting --

func test_the_key_wins_an_adventure_meeting_and_its_spoils_follow() -> void:
	_flag_on()
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Quick Walker"
	setup.color = "red"
	setup.difficulty = 0
	setup.walker = "male"
	setup.seed_text = "2468"
	var world := Walk.new()
	world.record = setup.resolve({})
	viewport.add_child(world)
	await _frames(3)
	world.player.monsters = [] as Array
	world.player.monster_timer = 4   # not a special meeting
	world.player.gold = 1000
	world.player.cards = []
	for card_name in ["Mountain", "Mountain", "Mountain", "Mountain", "Mountain",
			"Mountain", "Mountain", "Mountain", "Mountain", "Mountain",
			"Lightning Bolt", "Lightning Bolt", "Lightning Bolt", "Lightning Bolt",
			"Lightning Bolt", "Lightning Bolt", "Hill Giant", "Hill Giant", "Hill Giant",
			"Hill Giant"]:
		world.player.cards.append({"card": card_name, "decks": [0]})
	world.player.current_deck = 0
	for slot in world.world.encounters:
		(slot as Dictionary)["clues"] = 7   # no hints after the duel
	var at := world.player.position + Vector2i(6, 0)
	world.player.monsters.append({"slot": 0, "kind": "creature", "creature": 1,
		"x": at.x, "y": at.y, "color": 1, "heading": 0, "frame": 0})
	var pane := world.meet_creature(0) as EncounterPane
	assert_not_null(pane, "the meeting")
	if pane == null:
		return
	var results: Array = []
	pane.finished.connect(func(result: int) -> void: results.append(result))
	await _frames()
	var owned := world.player.cards.size()
	(pane.find_child("Choice_duel", true, false) as Button).pressed.emit()
	await _frames()
	var host := pane.duel_host()
	assert_not_null(host, "the duel over the world")
	if host == null:
		return
	assert_not_null(_line(host.duel), "the line in an adventure duel too")
	# The host and its duel go once the duel is over: what they said is kept.
	var game: MtgGame = host.duel.game
	var reports: Array = []
	host.ended.connect(func(report: DuelReport) -> void:
		reports.append([report.result, host.conceded]))
	await _key()
	assert_true(game.game_over and game.winner == 0, "won by the key")
	assert_eq(reports, [[DuelReport.WIN, false]], "a win, not a concession")
	await _frames(3)
	assert_eq(pane.step, "cards", "the spoils of a win")
	assert_eq(pane.words(), "Won these cards.")
	for i in 12:
		if not is_instance_valid(pane) or pane.done():
			break
		var go := pane.find_child("Choice_go", true, false) as Button
		if go == null:
			break
		go.pressed.emit()
		await _frames()
	await _frames(3)
	assert_eq(results, [EncounterPane.WON])
	assert_gt(world.player.cards.size(), owned, "cards won, none lost")
	assert_eq(world.player.total_wins(), 1)
