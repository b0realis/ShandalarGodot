extends GutTest
## THE UNCLUTTERED LOBBY (2026-09-18). The owner's word after a LAN
## playtest: only the key settings front and centre, everything else in
## sub-windows; Invitation only right beside Host on LAN with Copy
## invitation at its side, so nobody searches for it; the Game Browser
## names the duel. No socket opens in any of these tests.

var _had_name := false
var _saved_name: Variant


func before_each() -> void:
	_had_name = Settings.has_value(SgIdentity.KEY)
	_saved_name = Settings.get_value(SgIdentity.KEY, "")
	Settings.clear_value(SgIdentity.KEY)


func after_each() -> void:
	if _had_name: Settings.set_value(SgIdentity.KEY, _saved_name)
	else: Settings.clear_value(SgIdentity.KEY)


func _lobby() -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	return lobby


func _button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree(): return node
	assert_true(false, "missing visible button: " + text)
	return null


func _click(root: Node, text: String) -> void:
	var button := _button(root, text)
	if button == null: return
	assert_false(button.disabled, text + " is enabled")
	button.pressed.emit()
	for i in 3: await get_tree().process_frame


func _key(lobby: SgLobby, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	lobby.get_viewport().push_input(press)
	for i in 2: await get_tree().process_frame


func _mouse(lobby: SgLobby, at: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	click.global_position = at
	lobby.get_viewport().push_input(click)
	for i in 2: await get_tree().process_frame


func test_host_game_keeps_the_key_settings_front_and_centre() -> void:
	var lobby := _lobby()
	lobby._show_page("host")
	for i in 4: await get_tree().process_frame
	assert_true(lobby._room_name.is_visible_in_tree(), "the duel's name")
	assert_true(lobby._host_decks.is_visible_in_tree(), "the deck rule")
	assert_eq(lobby._host_decks.get_item_text(0), "Bring your own deck")
	assert_eq(lobby._host_decks.get_item_text(1), "Assigned deck")
	assert_eq(lobby._host_decks.selected, 0, "everyone brings a deck unless the host says otherwise")
	assert_false(lobby._host_deck_button.visible, "the deck chooser only matters for an assigned deck")
	assert_true(lobby._invite_only.is_visible_in_tree())
	assert_false(lobby._invite_only.button_pressed, "open by default: no invitation needed")
	assert_true(lobby._copy.is_visible_in_tree())
	assert_same(lobby._copy.get_parent(), lobby._invite_only.get_parent(), "Copy invitation sits right beside the switch")
	assert_true(lobby._copy.disabled, "there is no invitation before a host runs")
	assert_string_contains(lobby._copy.tooltip_text, "once your host is running")
	assert_true(lobby._lan_start.is_visible_in_tree())
	assert_eq(lobby._lan_start.text, "Host on LAN")
	assert_string_contains(lobby._access_hint.text, "Anyone on your network sees this table")
	lobby._invite_only.button_pressed = true
	await get_tree().process_frame
	assert_string_contains(lobby._access_hint.text, "Only players you send the invitation to")
	# The rest waits in windows: nothing of it is on the page.
	for control in [lobby._interfaces, lobby._port, lobby._advertise, lobby._start]:
		assert_false(control.is_visible_in_tree(), str(control.name) + " lives in Network settings")
	assert_false(lobby._window_open())
	assert_true(lobby._advertise.button_pressed, "listed in the game browser unless switched off")
	lobby._host_decks.select(1)
	lobby._host_decks.item_selected.emit(1)
	await get_tree().process_frame
	assert_true(lobby._host_deck_button.visible)
	assert_eq(lobby._host_deck_label.text, "No deck chosen yet")
	assert_null(lobby.service)
	assert_null(lobby._discovery)
	assert_false(lobby.client._wanted)
	assert_lte(lobby._window.get_rect().end.x, 960.0)
	assert_lte(lobby._window.get_rect().end.y, 600.0)


func test_sub_windows_open_by_button_and_close_by_close_escape_and_a_click_on_the_sheet() -> void:
	var lobby := _lobby()
	lobby._show_page("host")
	for i in 4: await get_tree().process_frame
	await _click(lobby, "Network settings…")
	assert_true(lobby._window_open())
	assert_true(SgLobbyStyle.window_open(lobby._network_window))
	for control in [lobby._interfaces, lobby._port, lobby._advertise, lobby._start]:
		assert_true(control.is_visible_in_tree(), str(control.name) + " is in the open window")
	var frame: Control = lobby._network_window.get_meta("sg_frame")
	var sheet: Control = lobby._network_window.get_meta("sg_window")
	assert_true(sheet.top_level, "a window floats above the page, whatever container built it")
	assert_eq(sheet.z_index, SgLobbyStyle.WINDOW_Z)
	assert_gt(SgLobbyStyle.WINDOW_Z, 500, "above the master overlay")
	assert_lte(frame.get_rect().end.x, 960.0)
	assert_lte(frame.get_rect().end.y, 600.0)
	assert_gte(frame.position.x, 0.0)
	assert_gte(frame.position.y, 0.0)
	var close := sheet.find_child("CloseWindow", true, false) as Button
	assert_true(close.is_visible_in_tree())
	close.pressed.emit()
	await get_tree().process_frame
	assert_false(lobby._window_open(), "the window's Close closes it")
	assert_false(lobby._start.is_visible_in_tree())
	await _click(lobby, "Table rules…")
	assert_true(SgLobbyStyle.window_open(lobby._rules_window))
	await _key(lobby, KEY_ESCAPE)
	assert_false(lobby._window_open(), "Escape closes it")
	assert_eq(lobby._page, "host", "and only it: the page stays")
	lobby._host_decks.select(1)
	lobby._host_decks.item_selected.emit(1)
	await get_tree().process_frame
	await _click(lobby, "Choose deck…")
	assert_true(SgLobbyStyle.window_open(lobby._host_deck_window))
	frame = lobby._host_deck_window.get_meta("sg_frame")
	await _mouse(lobby, frame.get_global_rect().get_center())
	assert_true(SgLobbyStyle.window_open(lobby._host_deck_window), "a click inside the frame is the window's")
	await _mouse(lobby, Vector2(4, 4))
	assert_false(lobby._window_open(), "a click on the sheet outside the frame closes it")
	await _click(lobby, "Choose deck…")
	assert_true(lobby._window_open())
	lobby._show_page("home")
	assert_false(lobby._window_open(), "leaving the page closes its windows")
	assert_null(lobby.service)
	assert_null(lobby._discovery)
	assert_false(lobby.client._wanted)


func test_an_assigned_deck_is_chosen_in_its_window_and_required_before_hosting() -> void:
	var lobby := _lobby()
	lobby._show_page("host")
	for i in 4: await get_tree().process_frame
	lobby._room_name.text = "Knights only"
	lobby._room_name.text_changed.emit(lobby._room_name.text)
	lobby._host_decks.select(1)
	lobby._host_decks.item_selected.emit(1)
	await get_tree().process_frame
	var list := lobby.find_child("HostDeckList", true, false) as ItemList
	assert_eq(list.item_count, 0, "the catalogue is read when the window opens, not when the lobby does")
	lobby._host_game()
	assert_string_contains(lobby._notice.text, "Choose the deck both players will use")
	assert_true(SgLobbyStyle.window_open(lobby._host_deck_window), "the chooser opens where the deck is missing")
	assert_null(lobby.service, "nothing was hosted")
	for i in 2: await get_tree().process_frame
	assert_gt(list.item_count, 0)
	var use := lobby.find_child("HostDeckUse", true, false) as Button
	assert_true(use.disabled, "nothing selected yet")
	list.select(0)
	list.item_selected.emit(0)
	assert_false(use.disabled)
	var contents := lobby.find_child("HostDeckContents", true, false) as RichTextLabel
	assert_true(contents.text.length() > 20, "the complete list is shown")
	use.pressed.emit()
	await get_tree().process_frame
	assert_false(lobby._window_open(), "choosing closes the window")
	assert_false(lobby._host_deck.is_empty())
	assert_eq(lobby._host_deck_label.text, String(lobby._host_deck.name))
	var action := lobby._host_action()
	assert_eq(action.op, "host")
	assert_eq(action.name, "Knights only")
	assert_eq(action.decks, "fixed")
	assert_eq(action.deck, lobby._host_deck)
	assert_true(SgProtocol.valid({"v": SgProtocol.VERSION, "type": "command", "seq": 1, "room": "", "revision": 0, "action": action}))
	lobby._host_decks.select(0)
	lobby._host_decks.item_selected.emit(0)
	assert_eq(lobby._host_action(), {"op": "host", "name": "Knights only", "decks": "own", "deck": {},
		"rules": lobby._rules_setup.value()}, "bring your own sends no deck; the table rules always go")
	assert_null(lobby.service)
	assert_false(lobby.client._wanted)


func test_the_browser_keeps_find_and_join_by_invitation_and_names_each_duel() -> void:
	var lobby := _lobby()
	lobby._show_page("browser")
	for i in 4: await get_tree().process_frame
	assert_not_null(_button(lobby, "Find LAN games"))
	assert_not_null(_button(lobby, "Join by invitation…"))
	assert_false(lobby._code.is_visible_in_tree(), "the invitation field waits in its window")
	assert_null(lobby._discovery, "opening the browser starts no search")
	await _click(lobby, "Join by invitation…")
	assert_true(SgLobbyStyle.window_open(lobby._invite_window))
	assert_true(lobby._code.is_visible_in_tree())
	assert_true(lobby._code.has_focus(), "ready for the paste")
	assert_eq(lobby._invite_prompt.text, "Paste the invitation your host sent you.")
	assert_not_null(_button(lobby, "Connect"))
	(lobby._invite_window.get_meta("sg_window").find_child("CloseWindow", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_false(lobby._window_open())
	lobby._discovery = SgLanDiscovery.new()
	lobby.add_child(lobby._discovery)
	# An open advert's invitation must be real: it parses to the advert's own
	# address, port and certificate fingerprint or the advert is a forgery.
	var crypto := Crypto.new()
	var certificate := crypto.generate_self_signed_certificate(crypto.generate_rsa(2048),
		"CN=" + SgLanInvite.COMMON_NAME + ",O=SGManalink,C=XX", "20200101000000", "20400101000000")
	var pem := SgLanInvite.public_pem(certificate)
	var fox := {"address": "192.168.0.5", "port": 17897, "name": "Forest Fox", "fingerprint": pem.sha256_text(),
		"rooms": 2, "build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp(), "access": "open",
		"invitation": SgLanInvite.create("192.168.0.5", 17897, "a".repeat(64), pem), "tables": [
			{"name": "Kitchen table", "decks": "own", "deck": "", "open": true},
			{"name": "Knights only", "decks": "fixed", "deck": "White Knights", "open": false}]}
	var owl := {"address": "192.168.0.6", "port": 17897, "name": "Old Owl", "fingerprint": "b".repeat(64),
		"rooms": 0, "build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp(), "access": "invitation",
		"tables": [], "tournament": "Friday Cup"}
	var hare := owl.duplicate(true)
	hare.name = "Quiet Hare"
	hare.address = "192.168.0.7"
	hare.erase("tournament")
	for advert in [fox, owl, hare]:
		assert_true(SgLanDiscovery.valid_advert(advert), advert.name)
		lobby._discovery.hosts["%s:%d" % [advert.address, advert.port]] = {"host": advert, "seen": Time.get_ticks_msec()}
	lobby._refresh()
	var table: GridContainer = lobby._body.find_children("*", "GridContainer", true, false)[0]
	assert_eq(table.columns, 6)
	var cells: Array = []
	for label: Label in table.find_children("*", "Label", true, false): cells.append(label.text)
	assert_eq(cells.slice(0, 6), ["DUEL", "HOST", "DECKS", "INVITE ONLY", "BUILD", ""])
	assert_eq(cells.slice(6, 10), ["Kitchen table", "Forest Fox", "Bring your own", "Same as yours"])
	assert_eq(cells.slice(10, 14), ["Knights only", "Forest Fox", "Assigned: White Knights", "Same as yours"])
	assert_eq(cells.slice(14, 18), ["Tournament · Friday Cup", "Old Owl", "", "Same as yours"])
	assert_eq(cells.slice(18, 22), ["No table yet", "Quiet Hare", "", "Same as yours"])
	# The access rule is a ticked box, not a word (owner's word, 2026-09-18):
	# ticked where Join asks for the invitation, empty where Join connects.
	var marks: Array = []
	for mark: CheckBox in table.find_children("*", "CheckBox", true, false):
		marks.append(mark.button_pressed)
		assert_eq(mark.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the tick reports; it takes no clicks")
		assert_eq(mark.focus_mode, Control.FOCUS_NONE)
	assert_eq(marks, [false, false, true, true])
	var buttons: Array = []
	for button: Button in table.find_children("*", "Button", true, false):
		if not button is CheckBox: buttons.append([button.text, button.disabled])
	assert_eq(buttons, [["Join", false], ["In play", true], ["Join", false], ["Join", false]])
	assert_false(lobby.client._wanted)


func test_tournament_setup_keeps_its_key_settings_and_opens_the_rest_in_windows() -> void:
	var lobby := _lobby()
	lobby._show_page("tournament")
	for i in 6: await get_tree().process_frame
	var panel := lobby._tournament_panel
	var invite_only := panel.find_child("TournamentInviteOnly", true, false) as CheckButton
	var copy := panel.find_child("TournamentCopyInvitation", true, false) as Button
	assert_not_null(invite_only)
	assert_not_null(copy)
	if invite_only == null or copy == null: return
	assert_true(invite_only.is_visible_in_tree())
	assert_false(invite_only.button_pressed, "open by default")
	assert_false(panel.invite_only)
	assert_same(copy.get_parent(), invite_only.get_parent(), "Copy invitation beside the switch")
	assert_true(copy.disabled, "no host runs yet")
	var hint := panel.find_child("TournamentAccessHint", true, false) as Label
	assert_string_contains(hint.text, "find this tournament in their Game Browser")
	invite_only.button_pressed = true
	assert_true(panel.invite_only)
	assert_string_contains(hint.text, "Only players you send the invitation to")
	for name in ["TournamentName", "TournamentWins", "TournamentDeckSummary", "TournamentOpenRegistration"]:
		assert_true(panel.find_child(name, true, false).is_visible_in_tree(), name + " is front and centre")
	for name in ["TournamentPolicy", "TournamentWelcomeEdit", "TournamentSaveFolder"]:
		assert_false(panel.find_child(name, true, false).is_visible_in_tree(), name + " waits in a window")
	assert_false(panel.window_open())
	await _click(panel, "Change…")
	assert_true(panel.window_open())
	assert_true(panel._policy.is_visible_in_tree())
	assert_true(lobby._window_open(), "the lobby knows the panel's windows")
	await _key(lobby, KEY_ESCAPE)
	assert_false(panel.window_open(), "Escape closes it")
	assert_eq(lobby._page, "tournament")
	await _click(panel, "Welcome message…")
	assert_true(panel._welcome_edit.is_visible_in_tree())
	panel.close_windows()
	await _click(panel, "Save folder…")
	assert_true(panel._folder_edit.is_visible_in_tree())
	assert_lte(panel._folder_edit.get_global_rect().end.x, 960.0)
	lobby._show_page("home")
	assert_false(panel.window_open(), "leaving the page closes them")
	# With a host running, the copy button wakes and the hint names the mode.
	var copies := [0]
	panel.copy_requested.connect(func() -> void: copies[0] += 1)
	panel.host_access = "open"
	panel.present({}, true, false, true)
	copy = panel.find_child("TournamentCopyInvitation", true, false) as Button
	assert_false(copy.disabled)
	copy.pressed.emit()
	assert_eq(copies[0], 1, "the panel asks the lobby, which holds the invitation")
	assert_null(lobby.service)
	assert_null(lobby._discovery)
	assert_false(lobby.client._wanted)
