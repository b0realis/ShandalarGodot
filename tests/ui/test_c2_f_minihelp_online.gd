extends GameTest
## THE MINI HELP AT AN SGMANALINK TABLE (2026-10-13). The network duel view
## IS the duel screen ([SgDuelView] extends [DuelScreen]) and reuses its
## menus, so every `Help...` opens the same panel there. It is the local
## screen's alone: opening, reading and closing it sends the referee
## nothing, the automatic pass this seat would make waits while it is up,
## and a new table arriving from the host under it changes nothing about
## it — the other seat waits for nothing.

var referee: SgPracticeMatch
var revision := 1
var commands: Array = []


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	commands.clear()
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	# Every phase stopped while the table is set up, so nothing is passed
	# before the test means it to be.
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.action_requested.connect(_act.bind(screen, seat))
	screen.present(_room(seat), true, false)
	return screen


func _act(action: Dictionary, screen: SgDuelView, seat: int) -> void:
	commands.append(action.duplicate(true))
	var error := referee.act(seat, action)
	if not error.is_empty():
		screen.show_notice(error)
	else:
		revision += 1
	screen.present.call_deferred(_room(seat), true, false)


func _pump() -> void:
	for i in 8:
		await get_tree().process_frame


func _help_from(menu: PopupMenu) -> void:
	for i in menu.item_count:
		if menu.get_item_text(i) == "Help...":
			assert_false(menu.is_item_disabled(i), "Help... is live at the table")
			var id := menu.get_item_id(i)
			menu.hide()
			menu.id_pressed.emit(id)
			return
	fail_test("no Help... on the menu")


func test_the_tables_menus_open_the_same_mini_help() -> void:
	var screen := _screen()
	await _pump()
	screen._open_territory_menu(0, Vector2(300, 200))
	_help_from(screen._territory_menu)
	assert_true(screen.mini_help_open(), "the territory's help at an SGManalink table")
	assert_eq(screen._mini_help.subject, HelpPages.MINI_TERRITORY)
	screen._mini_help.dismiss()
	screen._open_library_menu(0, Vector2(300, 200))
	_help_from(screen._library_menu)
	assert_eq(screen._mini_help.subject, HelpPages.MINI_LIBRARY)
	screen._mini_help.dismiss()
	screen._open_phase_menu(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 3, Vector2(300, 200))
	_help_from(screen._phase_menu)
	assert_eq(screen._mini_help.subject, HelpPages.MINI_PHASE_BAR)
	screen._mini_help.dismiss()
	await _pump()
	assert_eq(commands, [], "reading the help sent the referee nothing")


func test_nothing_is_sent_and_this_seats_pass_waits() -> void:
	var screen := _screen()
	await _pump()
	assert_eq(commands, [], "control: the stopped table sent nothing")
	screen._open_mini_help(HelpPages.MINI_HAND, Vector2(300, 200))
	assert_true(screen.mini_help_open())
	assert_true(screen._modal_open(), "modal at the table too")
	# Take the stops off: an unstopped, quiet phase is one this seat would
	# pass by itself — but not while the help is up.
	screen.stops.clear_all()
	screen._refresh()
	assert_false(screen._auto_pass_applies(), "the automatic pass waits under the help")
	await _pump()
	assert_eq(commands, [], "nothing was sent while it was up")
	# The host's next table arrives under it: shown, and still nothing sent.
	revision += 1
	screen.present(_room(), true, false)
	await _pump()
	assert_true(screen.mini_help_open(), "a new table from the host leaves it up")
	assert_eq(commands, [], "and sends nothing")
	# Escape closes it, opens no Pause window and sends nothing itself.
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	screen._unhandled_key_input(esc)
	assert_false(screen.mini_help_open(), "Escape closed it")
	assert_false(screen.is_paused())
	assert_eq(commands, [], "closing it sent nothing")
	# Afterwards the table goes on exactly as before: the pass it held.
	await _pump()
	var passed := false
	for action in commands:
		if String(action.get("op", "")) == "pass":
			passed = true
	assert_true(passed, "closed: this seat's held pass goes to the referee (%s)" % [commands])


func test_the_duels_end_closes_it() -> void:
	# The other seat concedes while this one reads: the End of Duel window
	# is what comes next, not a help panel over it.
	var screen := _screen()
	await _pump()
	screen._open_mini_help(HelpPages.MINI_LIFE, Vector2(300, 200))
	assert_true(screen.mini_help_open(), "control: the help is up")
	assert_eq(referee.act(1, {"op": "concede"}), "", "control: the other seat concedes")
	revision += 1
	screen.present(_room(), true, false)
	await _pump()
	assert_true(screen.game.game_over, "control: the table says the duel is over")
	assert_false(screen.mini_help_open(), "the duel's end closed the help")
	assert_eq(commands, [], "and this seat sent nothing")
	for _i in 8:
		await get_tree().create_timer(0.5).timeout   # let the result countdown run out
