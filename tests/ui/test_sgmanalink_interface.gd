extends GameTest
## Classic menus and data-only duel controls. Player preferences are restored.

var _saved_name: Variant
var _had_name := false


func before_each() -> void:
	super.before_each()
	_had_name = Settings.has_value(SgIdentity.KEY)
	_saved_name = Settings.get_value(SgIdentity.KEY, "")
	Settings.clear_value(SgIdentity.KEY)


func after_each() -> void:
	if _had_name:
		Settings.set_value(SgIdentity.KEY, _saved_name)
	else:
		Settings.clear_value(SgIdentity.KEY)
	super.after_each()


func _lobby() -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	return lobby


func _room(duel: SgPracticeMatch, seat: int, revision := 1) -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": seat,
		"names": ["Azure Fox (Guest 1)", "Amber Owl (Guest 2)"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": duel.view(seat),
		"deck_names": duel.deck_names.duplicate(), "deck": {}}


func _screen() -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	viewport.add_child(screen)
	return screen


func test_deck_selector_lists_shipped_decks_and_full_contents() -> void:
	var lobby := _lobby()
	lobby.client.online = true
	lobby.client.state.room = {"id":"r1", "name":"Friendly duel", "seat":0,
		"names":["Azure Fox", "Amber Owl"], "revision":1, "ready":[false,false],
		"connected":[true,true], "game":{}, "deck_names":["Knights","Raiders"], "deck":{}}
	lobby._open_decks()
	for i in 5: await get_tree().process_frame
	var list := lobby._deck_picker.find_child("NetworkDeckList", true, false) as ItemList
	assert_gt(list.item_count, 100)
	list.select(0)
	list.item_selected.emit(0)
	var contents := lobby._deck_picker.find_child("NetworkDeckContents", true, false) as RichTextLabel
	assert_string_contains(contents.text, "Main deck")
	assert_false(_button(lobby, "Use this deck").disabled)
	lobby._close_decks()


func _button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree():
			return node
	return null


func test_identity_is_optional_local_and_only_saved_on_confirmation() -> void:
	var lobby := _lobby()
	var writes := Settings.write_count
	lobby._show_page("identity")
	assert_false(Settings.has_value(SgIdentity.KEY))
	assert_eq(Settings.write_count, writes)
	_button(lobby, "Generate name").pressed.emit()
	assert_true(SgProtocol.nickname(lobby._nickname.text))
	assert_false(lobby._nickname.text.is_empty())
	assert_false(Settings.has_value(SgIdentity.KEY), "generation is not a save or an account")
	lobby._nickname.text = "Azure Fox"
	lobby._remember.button_pressed = true
	_button(lobby, "Use this identity").pressed.emit()
	assert_eq(lobby._page, "home")
	assert_eq(SgIdentity.remembered_name(), "Azure Fox")
	assert_null(lobby.service)
	assert_null(lobby._discovery)
	assert_false(lobby.client._wanted)
	var reopened := _lobby()
	assert_eq(reopened._nickname.text, "Azure Fox")
	lobby._show_page("identity")
	lobby._nickname.text = "Unsaved edit"
	_button(lobby, "Cancel").pressed.emit()
	assert_eq(lobby._nickname.text, "Azure Fox")
	assert_eq(SgIdentity.remembered_name(), "Azure Fox")
	lobby._show_page("identity")
	lobby._nickname.text = "Guest Fox"
	lobby._remember.button_pressed = false
	_button(lobby, "Use this identity").pressed.emit()
	assert_false(Settings.has_value(SgIdentity.KEY))
	assert_eq(lobby._nickname.text, "Guest Fox")
	assert_eq(_lobby()._nickname.text, "")


func test_invalid_identity_and_saved_setting_are_not_trusted() -> void:
	Settings.set_value(SgIdentity.KEY, {"name": "bad"})
	assert_eq(SgIdentity.remembered_name(), "")
	var lobby := _lobby()
	lobby._show_page("identity")
	lobby._nickname.text = "[admin]"
	lobby._save_identity()
	assert_eq(lobby._page, "identity")
	assert_string_contains(lobby._notice.text, "letters")
	assert_eq(SgIdentity.remembered_name(), "")
	for i in 80:
		assert_true(SgProtocol.nickname(SgIdentity.generate_name()))


func test_windows_are_separate_fit_and_do_not_open_sockets() -> void:
	var lobby := _lobby()
	for page in ["home", "identity", "host", "browser"]:
		lobby._show_page(page)
		for i in 5:
			await get_tree().process_frame
		for key in lobby._pages:
			assert_eq(lobby._pages[key].visible, key == page)
		assert_lte(lobby._window.get_rect().end.x, 960.0)
		assert_lte(lobby._window.get_rect().end.y, 600.0)
		assert_gte(lobby._window.position.x, 0.0)
		assert_null(lobby.service)
		assert_null(lobby._discovery)
		assert_false(lobby.client._wanted)
	assert_true(lobby._advertise.button_pressed)
	lobby._advertise.button_pressed = false
	assert_false(lobby._advertise.button_pressed, "private hosting is explicit")


func test_overview_states_the_facts_and_repeats_no_navigation() -> void:
	var lobby := _lobby()
	var home: Control = lobby._pages.home
	assert_eq(home.find_children("*", "Button", true, false).size(), 0,
		"the tabs above are the map; the Overview repeats none of them (owner's word, 2026-09-17)")
	var explanation := ""
	for label in home.find_children("*", "Label", true, false):
		explanation += label.text + "\n"
	for fact in ["local network", SgCompatibility.summary(), "same version and packs", "IDENTITY", "HOST", "JOIN", "TOURNAMENT",
		"invitation", "referee", "40 players", "LAN address" if not SgLanInvite.local_addresses().is_empty() else "No LAN IPv4 address"]:
		assert_string_contains(explanation, fact)
	assert_eq(lobby._navigation.size(), 5, "top tabs stay the full map")
	for dimensions in [Vector2i(1280,800), Vector2i(960,600), Vector2i(640,480)]:
		(lobby.get_parent() as SubViewport).size = dimensions
		for i in 5: await get_tree().process_frame
		var window := lobby._window.get_global_rect()
		assert_gte(window.position.x, 0.0)
		assert_lte(window.end.x, float(dimensions.x))
		assert_lte(window.end.y, float(dimensions.y))
		for node in home.find_children("*", "Label", true, false):
			assert_gte(node.get_global_rect().position.x, window.position.x)
			assert_lte(node.get_global_rect().end.x, window.end.x)
	assert_null(lobby.service)
	assert_null(lobby._discovery)
	assert_false(lobby.client._wanted)


func test_buttons_wear_the_surface_they_sit_on() -> void:
	var lobby := _lobby()
	for i in 3: await get_tree().process_frame
	var seen := {"paper": 0, "stone": 0}
	for node in lobby.find_children("*", "Button", true, false):
		if not node.has_meta("sg_sand"): continue
		var sand: bool = node.get_meta("sg_sand")
		assert_eq(sand, SgLobbyStyle.on_paper(node), node.text)
		seen["paper" if sand else "stone"] += 1
		assert_eq(node.get_theme_color("font_focus_color"), UiChrome.INK, node.text + ": focused text stays legible")
		# The parchment face is the shell's shadowed lettering; the window face has none.
		assert_eq(node.has_theme_color_override("font_shadow_color"), sand, node.text + " wears its surface's face")
	assert_gt(seen.paper, 0, "the paper sections' buttons are parchment")
	assert_gt(seen.stone, 0, "the frame's buttons are the window's grey")
	assert_true(SgLobbyStyle.on_paper(lobby._lan_start))
	assert_false(SgLobbyStyle.on_paper(lobby._close_button))
	assert_false(SgLobbyStyle.on_paper(lobby._navigation["home"]))
	# A caller's own override outranks the dress, and survives a re-dress.
	var custom := SgLobbyStyle.button("Custom", func() -> void: pass)
	custom.add_theme_font_size_override("font_size", 11)
	lobby._pages.host.add_child(custom)
	assert_eq(custom.get_theme_font_size("font_size"), 11)
	assert_true(custom.has_theme_stylebox_override("normal"))
	custom.get_parent().remove_child(custom)
	lobby._window.add_child(custom)
	assert_false(custom.get_meta("sg_sand"))
	assert_eq(custom.get_theme_font_size("font_size"), 11)
	custom.queue_free()


func test_enter_submits_identity_room_name_and_invitation() -> void:
	var lobby := _lobby()
	lobby._show_page("identity")
	lobby._nickname.text = "Forest Fox"
	lobby._remember.button_pressed = false
	lobby._nickname.text_submitted.emit(lobby._nickname.text)
	assert_eq(lobby._page, "home", "Enter in the name field confirms the identity")
	assert_eq(lobby._identity_name, "Forest Fox")
	assert_false(Settings.has_value(SgIdentity.KEY), "not remembered unless asked")
	lobby._show_page("host")
	lobby._lan_start.disabled = true
	lobby._room_name.text_submitted.emit("Friendly duel")
	assert_null(lobby.service, "Enter never hosts while hosting is unavailable")
	lobby._show_page("browser")
	lobby._code.text = "not an invitation"
	lobby._code.text_submitted.emit(lobby._code.text)
	assert_false(lobby.client._wanted, "an invalid invitation opens no socket")
	assert_string_contains(lobby._notice.text, "complete invitation")
	assert_null(lobby._discovery)


func test_browser_names_what_a_nearby_host_does_not_match() -> void:
	var lobby := _lobby()
	lobby._show_page("browser")
	lobby._discovery = SgLanDiscovery.new()
	lobby.add_child(lobby._discovery)
	var same := {"address": "192.168.0.5", "port": 17897, "name": "Forest Fox", "fingerprint": "a".repeat(64),
		"rooms": 1, "build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp(), "access": "invitation",
		"tables": [{"name": "Fox's duel", "decks": "fixed", "deck": "Knights", "open": true}]}
	var older := same.duplicate(true)
	older.name = "Old Owl"
	older.port = 17898
	older.build = "0".repeat(64)
	older.stamp.game = "0.31.0"
	older.tables = [{"name": "Owl's duel", "decks": "own", "deck": "", "open": true}]
	lobby._discovery.hosts["192.168.0.5:17897"] = {"host": same, "seen": Time.get_ticks_msec()}
	lobby._discovery.hosts["192.168.0.5:17898"] = {"host": older, "seen": Time.get_ticks_msec()}
	lobby._refresh()
	var table: GridContainer = lobby._body.find_children("*", "GridContainer", true, false)[0]
	assert_eq(table.columns, 6, "duel, host, decks, access, build, join")
	var rows := ""
	for label in table.find_children("*", "Label", true, false): rows += label.text + "\n"
	for cell in ["DUEL", "HOST", "DECKS", "INVITE ONLY", "BUILD", "Fox's duel", "Forest Fox", "Assigned: Knights",
			"Same as yours", "Owl's duel", "Old Owl", "Bring your own", "Shandalar 0.31.0"]:
		assert_string_contains(rows, cell)
	var marks: Array = []
	for mark: CheckBox in table.find_children("*", "CheckBox", true, false): marks.append(mark.button_pressed)
	assert_eq(marks, [true, true], "both hosts ask for their invitation: the box is ticked")
	assert_false(rows.contains("192.168.0.5"), "the address is a tooltip, not a column")
	var joins: Array = []
	for node in table.find_children("*", "Button", true, false):
		if node.text == "Join": joins.append(node)
	assert_eq(joins.size(), 2)
	joins[1].pressed.emit()
	await get_tree().process_frame
	assert_true(lobby._selected_host.is_empty(), "a mismatched host is refused before it is selected")
	assert_string_contains(lobby._notice.text, "This host runs Shandalar 0.31.0; you run " + SgCompatibility.game_version())
	assert_false(lobby.client._wanted)
	joins[0].pressed.emit()
	await get_tree().process_frame
	assert_eq(lobby._selected_host.name, "Forest Fox")
	assert_eq(lobby._pending_join, "Fox's duel")
	assert_true(lobby._window_open(), "an invitation-only host asks for the invitation")
	assert_string_contains(lobby._invite_prompt.text, "Forest Fox hosts by invitation only")
	assert_false(lobby.client._wanted, "no socket until the invitation is pasted")
