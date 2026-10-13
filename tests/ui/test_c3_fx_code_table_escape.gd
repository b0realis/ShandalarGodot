extends GameTest
## ONE ESCAPE AT AN SGMANALINK TABLE IS ONE ESCAPE (repository check
## 2026-10-13, found while checking c1-1).
##
## The table ([SgDuelView]) is a child of the lobby, so a key reaches the
## table's own `_unhandled_key_input` first, and the duel answers Escape
## itself. The lobby then handed the same Escape to the table a second time
## ([method SgDuelView.toggle_menu]): with nothing open the Pause window
## opened and closed again in one press, and over the mini help the press
## closed the help and then opened the Pause window. The lobby leaves the
## table's keys to the table now.

var referee: SgPracticeMatch
var revision := 1


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


## A table inside a lobby, as the lobby seats it, with no socket.
func _table() -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	lobby._duel = screen
	lobby.add_child(screen)
	screen.present(_room(), true, false)
	return [viewport, lobby, screen]


func _pump(frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame


## One press and release of Escape through the viewport.
func _escape(viewport: SubViewport) -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	viewport.push_input(esc, true)
	var up: InputEventKey = esc.duplicate()
	up.pressed = false
	viewport.push_input(up, true)


func test_escape_with_nothing_open_opens_the_pause_window() -> void:
	var parts := _table()
	var viewport: SubViewport = parts[0]
	var screen: SgDuelView = parts[2]
	await _pump()
	assert_false(screen.is_paused(), "control: not paused")
	_escape(viewport)
	await _pump()
	assert_true(screen.is_paused(), "one Escape opens the Pause window and leaves it open")
	_escape(viewport)
	await _pump()
	assert_false(screen.is_paused(), "and the next one closes it")


func test_escape_over_the_mini_help_closes_only_the_help() -> void:
	var parts := _table()
	var viewport: SubViewport = parts[0]
	var screen: SgDuelView = parts[2]
	await _pump()
	screen._open_mini_help(HelpPages.MINI_HAND, Vector2(300, 200))
	assert_true(screen.mini_help_open(), "control: the help is up")
	_escape(viewport)
	await _pump()
	assert_false(screen.mini_help_open(), "Escape closed the help")
	assert_false(screen.is_paused(), "and opened no Pause window")
