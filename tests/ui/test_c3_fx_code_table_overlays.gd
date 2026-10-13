extends GameTest
## WHAT IS ON TOP AT AN SGMANALINK TABLE IS WHAT TAKES THE CLICK AND THE KEY
## (repository check 2026-10-13, found while checking c1-1).
##
## 1. THE PAUSE WINDOW STAYS ON TOP. The duel there goes on under it, and a
##    question for this seat, revealed cards or the End of Duel window can be
##    added to the screen while it is open. Godot finds a click by tree
##    order, whatever the z, so the newcomer — drawn under the Pause window —
##    took every click: its full-screen dim swallowed "Return to game", and a
##    Pause button over an answer line answered the question. Now a window
##    that arrives while the Pause window is open goes under it in the tree
##    too; the question waits behind it, dimmed, until the pause closes. A
##    window drawn over the Pause window stays over it.
## 2. THE MASTER PANEL COVERS THE TABLE. A tournament organiser can open the
##    lobby's Master Panel over their own table; one Escape closed the panel
##    and also opened the table's Pause window behind it, and every other
##    duel key (the pause key, the log key...) acted on the hidden table. Now
##    no key reaches the table while the panel covers it, and Escape does one
##    thing: it closes the panel.

var referee: SgPracticeMatch
var revision := 1


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	g.rules.set_preset("modern_mana_burn")
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	referee = null
	CardPacks.set_enabled("pack-9", false)


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	return viewport


func _screen() -> Array:
	var viewport := _viewport()
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.present(_room(), true, false)
	return [viewport, screen]


## A table inside a lobby, as the lobby seats it, with no socket.
func _table_in_lobby() -> Array:
	var viewport := _viewport()
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	lobby._duel = screen
	lobby.add_child(screen)
	screen.action_requested.connect(_act.bind(screen))
	screen.present(_room(), true, false)
	return [viewport, lobby, screen]


## The referee's side of a table action, as test_sgmanalink_shared_duel does.
func _act(action: Dictionary, screen: SgDuelView) -> void:
	if referee.act(0, action).is_empty():
		revision += 1
	screen.present.call_deferred(_room(), true, false)


func _pump(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame


func _click_at(viewport: SubViewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		viewport.push_input(ev, true)


func _press(viewport: SubViewport, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	viewport.push_input(key, true)
	var up: InputEventKey = key.duplicate()
	up.pressed = false
	viewport.push_input(up, true)


## This seat's Bolt at itself; this seat's Amulet and the other seat's
## Furnace both apply, so this seat is asked which applies first.
func _bolt_myself() -> void:
	put_battlefield(0, "Forethought Amulet")
	put_battlefield(1, "Furnace of Rath")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(0))   # the other seat now holds priority


func _pause_button(screen: SgDuelView, text: String) -> Button:
	for b in screen._pause_menu.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


func _answer_lines(screen: SgDuelView) -> Array:
	var out: Array = []
	for b in screen._choice_overlay.find_children("*", "BaseButton", true, false):
		if (b as BaseButton).text.begins_with("1. ") or (b as BaseButton).text.begins_with("2. "):
			out.append(b)
	return out


# ------------------------------------------------- 1. the Pause window --

func test_a_question_arriving_under_the_pause_window_waits_behind_it() -> void:
	_bolt_myself()
	var parts := _screen()
	var viewport: SubViewport = parts[0]
	var screen: SgDuelView = parts[1]
	var sent: Array = []
	screen.action_requested.connect(func(action: Dictionary) -> void:
		sent.append(action.duplicate(true))
		referee.act(0, action))
	await _pump()
	screen.toggle_menu()
	assert_true(screen.is_paused(), "control: the Pause window is up")
	# The other seat passes: the Bolt resolves and the referee holds it on
	# this seat's question, which reaches the paused table.
	assert_ok(g.pass_priority(1))
	assert_not_null(g.awaiting_choice, "control: a question is held for this seat")
	if g.awaiting_choice == null:
		return
	revision += 1
	screen.present(_room(), true, false)
	await _pump()
	assert_not_null(screen._choice_overlay, "control: the question is shown, behind the Pause window")
	assert_true(screen.is_paused(), "the question left the Pause window up")
	var kids := screen.get_children()
	assert_gt(kids.find(screen._pause_menu), kids.find(screen._choice_overlay),
		"the Pause window is after the question in the tree, so it takes the clicks it is drawn over")
	var resume := _pause_button(screen, "Return to game")
	assert_not_null(resume, "control: the Pause window's first button")
	if resume == null:
		return
	_click_at(viewport, resume.get_global_rect().get_center())
	await _pump()
	assert_false(screen.is_paused(), "Return to game was clicked and closed the Pause window")
	assert_eq(sent, [], "and nothing was answered: %s" % [sent])
	assert_not_null(g.awaiting_choice, "the question waits")
	# Now the question is in front and answers as usual.
	var lines := _answer_lines(screen)
	assert_eq(lines.size(), 2, "control: two answer lines")
	if lines.size() < 2:
		return
	_click_at(viewport, (lines[1] as Control).get_global_rect().get_center())
	await _pump()
	assert_eq(sent.size(), 1, "the question answers once the pause is closed")


## The worst case: a click on a Pause button that lies over an answer line.
## Before, the line under it took the click and the referee had an answer.
func test_a_click_on_the_pause_window_never_answers_the_question_behind_it() -> void:
	_bolt_myself()
	var parts := _screen()
	var viewport: SubViewport = parts[0]
	var screen: SgDuelView = parts[1]
	var sent: Array = []
	screen.action_requested.connect(func(action: Dictionary) -> void:
		sent.append(action.duplicate(true))
		referee.act(0, action))
	await _pump()
	screen.toggle_menu()
	assert_ok(g.pass_priority(1))
	assert_not_null(g.awaiting_choice, "control: a question is held for this seat")
	if g.awaiting_choice == null:
		return
	revision += 1
	screen.present(_room(), true, false)
	await _pump()
	assert_not_null(screen._choice_overlay, "control: the question is shown")
	# Click every point of the Pause board that lies over an answer line,
	# away from its buttons (the board itself does nothing when clicked).
	var board_hits := 0
	for line in _answer_lines(screen):
		var rect: Rect2 = (line as Control).get_global_rect()
		var at := rect.get_center()
		var on_button := false
		for b in screen._pause_menu.find_children("*", "Button", true, false):
			if (b as Control).get_global_rect().has_point(at):
				on_button = true
		if on_button:
			continue
		_click_at(viewport, at)
		board_hits += 1
		await _pump(2)
	assert_gt(board_hits, 0, "control: an answer line lies under the Pause window")
	assert_eq(sent, [], "a click on the Pause window answered the question behind it: %s" % [sent])
	assert_true(screen.is_paused(), "and the Pause window is still up")


func test_other_windows_arriving_go_under_the_pause_window() -> void:
	var parts := _screen()
	var screen: SgDuelView = parts[1]
	await _pump()
	screen.toggle_menu()
	assert_true(screen.is_paused(), "control: the Pause window is up")
	screen._show_reveal(-1, "Revealed information", ["Forest"])
	assert_true(screen.reveal_window_open(), "control: revealed cards arrive")
	screen._show_result_window("Amber Owl won")
	var last := screen.get_child(screen.get_child_count() - 1)
	assert_eq(last, screen._pause_menu, "revealed cards and the End of Duel window go under it")
	# A window drawn over the Pause window stays over it.
	var over := Control.new()
	over.z_index = screen._pause_menu.z_index + 10
	screen.add_child(over)
	assert_eq(screen.get_child(screen.get_child_count() - 1), over,
		"a window drawn over the Pause window stays after it")
	var under := Control.new()
	screen.add_child(under)
	var kids := screen.get_children()
	assert_lt(kids.find(under), kids.find(screen._pause_menu), "a later window drawn under it goes under it")
	assert_gt(kids.find(over), kids.find(screen._pause_menu), "and the one over it stays over it")
	screen._close_pause()
	var plain := Control.new()
	screen.add_child(plain)
	assert_eq(screen.get_child(screen.get_child_count() - 1), plain, "closed: the screen orders nothing")


# --------------------------------------------- 2. the Master Panel --

## The organiser's view of a small event (as test_sgmanalink_tournament_panel
## builds one, no socket), then the Master Panel over the table.
func _open_master(lobby: SgLobby) -> void:
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "LAN Cup", "limit": 8, "wins": 1, "policy": "fixed",
		"decks": [{"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]}, 4242), "")
	for i in 2:
		event.set_ready(event.register("Player %d" % (i + 1), str(i).sha256_text()), true)
	var server := SgLocalServer.new()
	add_child_autofree(server)
	var host := SgTournamentHost.new()
	host.event = event
	host.organiser = 99
	server.add_child(host)
	lobby.client.state["tournament"] = host.view(99)
	lobby._open_master()


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


## One Escape over the panel closes the panel and nothing else: a cast the
## player had begun on the table under it is still there afterwards. Before,
## the table took the Escape first and withdrew the cast (the lobby then
## closed the panel), so one press did two things.
func test_escape_over_the_master_panel_only_closes_the_panel() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	put_battlefield(0, "Mountain")
	put_battlefield(1, "Grizzly Bears")
	var parts := _table_in_lobby()
	var viewport: SubViewport = parts[0]
	var lobby: SgLobby = parts[1]
	var screen: SgDuelView = parts[2]
	await _pump()
	screen._on_card_clicked(_local(screen, bolt))
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "control: a cast is begun")
	_open_master(lobby)
	assert_true(is_instance_valid(lobby._master_overlay), "control: the Master Panel covers the table")
	assert_true(screen._tournament_panel_open)
	_press(viewport, KEY_ESCAPE)
	await _pump()
	assert_false(is_instance_valid(lobby._master_overlay), "Escape closed the panel")
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "and left the cast under it alone")
	assert_false(screen.is_paused(), "and opened no Pause window")
	_press(viewport, KEY_ESCAPE)
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "the next Escape is the table's own: the cast is withdrawn")


func test_no_duel_key_reaches_the_table_under_the_master_panel() -> void:
	var parts := _table_in_lobby()
	var viewport: SubViewport = parts[0]
	var lobby: SgLobby = parts[1]
	var screen: SgDuelView = parts[2]
	await _pump()
	_open_master(lobby)
	assert_true(is_instance_valid(lobby._master_overlay), "control: the Master Panel covers the table")
	_press(viewport, KEY_L)
	await _pump()
	assert_false(screen.duel_log_is_open(), "the log key opened no log window behind the panel")
	_press(viewport, KEY_Q)
	await _pump()
	assert_false(screen.is_paused(), "the pause key opened no Pause window behind it")
	assert_true(is_instance_valid(lobby._master_overlay), "and the panel is still up")
	lobby._close_master()
	_press(viewport, KEY_Q)
	await _pump()
	assert_true(screen.is_paused(), "control: with the panel closed the pause key is the table's again")
