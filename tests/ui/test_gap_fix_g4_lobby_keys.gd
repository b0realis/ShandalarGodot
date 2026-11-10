extends GameTest
## THE LOBBY'S BACK KEY AND ITS FOCUS (gap review 2026-11-10, R4-4, R4-8,
## R4-11).
##
## R4-4  Escape over one of the lobby's own popups (Export MPN's answer)
##       acted on the page under it and left the popup up; at a LAN table
##       the key went to the table, which opened its Pause window under
##       the popup. The popup on top is now the first rung, and the table
##       takes no key while one is up.
## R4-8  Expand Master Panel left the keyboard focus on the hall's button
##       under the opaque panel. The panel's first button takes it.
## R4-11 A pad's B (`ui_cancel`) did nothing in the lobby: only the Escape
##       KEY closed a sub-window or left a page. Both are `ui_cancel` now.

var referee: SgPracticeMatch


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	referee = null
	g = null
	await get_tree().process_frame


func _lobby() -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	return lobby


func _escape(lobby: SgLobby) -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ESCAPE
	press.physical_keycode = KEY_ESCAPE
	press.pressed = true
	lobby.get_viewport().push_input(press)
	var up: InputEventKey = press.duplicate()
	up.pressed = false
	lobby.get_viewport().push_input(up)
	for i in 3: await get_tree().process_frame


func _pad_b(lobby: SgLobby) -> void:
	for pressed in [true, false]:
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_B
		b.pressed = pressed
		lobby.get_viewport().push_input(b)
	for i in 3: await get_tree().process_frame


## Untyped: a freed popup is no Control to type-check.
func _up(popup: Variant) -> bool:
	return is_instance_valid(popup) and not (popup as Node).is_queued_for_deletion()


func test_escape_closes_the_lobbys_popup_not_the_page_under_it() -> void:
	var lobby := _lobby()
	lobby._show_page("browser")
	var popup := UiChrome.explain_popup(lobby, "Export MPN", "Public game record saved.")
	await get_tree().process_frame
	await _escape(lobby)
	assert_false(_up(popup), "Escape closes the popup")
	assert_eq(lobby._page, "browser", "and leaves the page under it alone")
	await _escape(lobby)
	assert_eq(lobby._page, "home", "the next Escape leaves the page, as before")
	lobby.client.forget()


func test_pad_b_closes_the_lobbys_popup_too() -> void:
	var lobby := _lobby()
	lobby._show_page("host")
	var popup := UiChrome.explain_popup(lobby, "Export MPN", "Public game record saved.")
	await get_tree().process_frame
	await _pad_b(lobby)
	assert_false(_up(popup), "B closes the popup")
	assert_eq(lobby._page, "host", "and leaves the page under it alone")
	lobby.client.forget()


func test_pad_b_closes_a_lobby_sub_window_and_leaves_a_page() -> void:
	var lobby := _lobby()
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	assert_true(InputMap.action_has_event(&"ui_cancel", b), "control: B is ui_cancel")
	lobby._show_page("host")
	SgLobbyStyle.open_window(lobby._rules_window)
	assert_true(lobby._window_open(), "control: the Table rules window is open")
	await _pad_b(lobby)
	assert_false(lobby._window_open(), "B closes the sub-window, as Escape does")
	assert_eq(lobby._page, "host", "and only the sub-window")
	await _pad_b(lobby)
	assert_eq(lobby._page, "home", "a second B leaves the Host Game page, as Escape does")
	lobby.client.forget()


func test_escape_still_closes_a_sub_window_and_leaves_a_page() -> void:
	var lobby := _lobby()
	lobby._show_page("host")
	SgLobbyStyle.open_window(lobby._rules_window)
	await _escape(lobby)
	assert_false(lobby._window_open(), "Escape closes the sub-window")
	assert_eq(lobby._page, "host")
	await _escape(lobby)
	assert_eq(lobby._page, "home", "and the next one leaves the page")
	lobby.client.forget()


func _room() -> Dictionary:
	return {"id": "r1", "name": "Kitchen table", "seat": 0, "names": ["One", "Two"],
		"revision": 2, "ready": [true, true], "connected": [true, true],
		"game": referee.view(0), "deck_names": referee.deck_names.duplicate(), "deck": {}}


func _table() -> SgLobby:
	var lobby := _lobby()
	lobby.client.online = true
	# A command in flight keeps the table locked (no automatic pass).
	lobby.client._pending = {"seq": 1}
	lobby.client.state = {"rooms": [], "room": _room()}
	lobby._refresh()
	for i in 6: await get_tree().process_frame
	return lobby


func _untable(lobby: SgLobby) -> void:
	lobby.client._pending = {}
	lobby.client.online = false
	lobby.client.forget()


func test_escape_over_a_popup_at_the_table_closes_the_popup_only() -> void:
	var lobby := await _table()
	assert_true(is_instance_valid(lobby._duel), "control: the table is up")
	if not is_instance_valid(lobby._duel): return
	var popup := UiChrome.explain_popup(lobby, "Export MPN", "Public game record saved.")
	for i in 2: await get_tree().process_frame
	await _escape(lobby)
	assert_false(_up(popup), "Escape closes the popup on top")
	assert_false(lobby._duel.is_paused(), "and the table under it does not open its Pause window")
	await _escape(lobby)
	assert_true(lobby._duel.is_paused(), "with the popup gone, Escape is the table's again")
	_untable(lobby)


func test_pad_b_over_a_popup_at_the_table_closes_the_popup_only() -> void:
	var lobby := await _table()
	assert_true(is_instance_valid(lobby._duel), "control: the table is up")
	if not is_instance_valid(lobby._duel): return
	var popup := UiChrome.explain_popup(lobby, "Export MPN", "Public game record saved.")
	for i in 2: await get_tree().process_frame
	await _pad_b(lobby)
	assert_false(_up(popup), "B closes the popup on top")
	assert_false(lobby._duel.is_paused(), "and the table under it does not open its Pause window")
	_untable(lobby)


func _organiser_view() -> Dictionary:
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Hall Cup", "limit": 8, "wins": 1, "policy": "own", "decks": []}, 4242), "")
	for i in 3: event.register("Player %d" % (i + 1), str(i).sha256_text())
	var host := SgTournamentHost.new()
	host.event = event
	host.organiser = 99
	var fake := SgLocalServer.new()
	add_child_autofree(fake)
	fake.add_child(host)
	return SgProtocol.decode_payload(SgProtocol.encode(host.view(99)).to_ascii_buffer())


func test_the_master_panel_takes_the_keyboard_focus_it_covers() -> void:
	var lobby := _lobby()
	lobby.client.online = true
	lobby.client.state = {"rooms": [], "room": {}, "tournament": _organiser_view()}
	lobby._refresh()
	assert_eq(lobby._page, "tournament", "control: the hall opened")
	lobby._expand_tournament.grab_focus()
	lobby._expand_tournament.pressed.emit()
	await get_tree().process_frame
	assert_true(is_instance_valid(lobby._master_overlay), "control: the Master Panel is open")
	var focus: Control = lobby.get_viewport().gui_get_focus_owner()
	assert_true(focus != null and lobby._master_overlay.is_ancestor_of(focus),
		"the keyboard focus is on the panel that covers the screen, not under it")
	assert_true(focus is Button and (focus as Button).text == "Back to hall", "on its Back to hall")
	await _escape(lobby)
	assert_false(is_instance_valid(lobby._master_overlay), "control: Escape closes the panel")
	assert_eq(lobby.get_viewport().gui_get_focus_owner(), lobby._expand_tournament,
		"and the focus goes back to the button that opened it")
	lobby.client.online = false
	lobby.client.forget()
