extends GutTest
## WHAT THE LOBBY'S PAGES SAY AND OFFER (gap review 2026-11-10, R4-5, R4-6,
## R4-7, R4-9, R4-10, R4-12, and the lead's default for R4 Q2).
##
## R4-5  A Join on an invitation-only listing left its table name pending
##       after Stop LAN search; the next host the player connected to seated
##       them at a table of that name they never picked.
## R4-6  The waiting room and the Table rules window said a friendly table
##       takes 40–250 cards; the referee takes 8–250 and advises 40.
## R4-7  The Game Browser's DECKS cell never wrapped or trimmed: a long
##       deck name widened the window past the screen, and Join with it.
## R4-9  The deck picker kept "Connection lost" after the connection was back.
## R4-10 The host's waiting room was rebuilt when ANOTHER table changed:
##       typing in its computer-opponent search lost the focus.
## R4-12 Add computer seat(s) added a deck the search had hidden.
## Q2    An armed "Declare X winner" became "Confirm: Correct: X wins" when
##       that pairing's game ended; a ruling armed over one state of a
##       pairing now disarms when the pairing's status changes.

var server: SgLocalServer
var host_client: SgLocalClient
var lobbies: Array = []


func before_each() -> void:
	server = SgLocalServer.new()
	add_child_autofree(server)
	host_client = SgLocalClient.new()
	add_child_autofree(host_client)


func after_each() -> void:
	host_client.forget()
	for lobby in lobbies:
		if is_instance_valid(lobby): lobby.client.forget()
	lobbies.clear()
	server.stop()
	for i in 3: await get_tree().process_frame


func _until(predicate: Callable, frames := 900) -> bool:
	for i in frames:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "frame budget exceeded")
	return false


func _lobby(dimensions := Vector2i(1280, 800)) -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	lobbies.append(lobby)
	return lobby


func _texts(root: Node) -> String:
	var out := ""
	for node in root.find_children("*", "Label", true, false): out += (node as Label).text + "\n"
	return out


# --- R4-5 ---------------------------------------------------------------

func test_stop_lan_search_drops_the_invitation_only_tables_pending_name() -> void:
	assert_eq(server.start_local(0), OK)
	# Host B (a same-computer service here) has the default table name.
	assert_eq(host_client.connect_local(server.port, server.access_code, "Fox"), OK)
	await _until(func() -> bool: return host_client.online)
	assert_true(host_client.command({"op": "host", "name": "Friendly duel", "decks": "own", "deck": {}}))
	await _until(func() -> bool: return not host_client.busy() and not host_client.state.room.is_empty())
	var lobby := _lobby()
	lobby._nickname.text = "Owl"
	lobby._show_page("browser")
	# A searching browser (no socket, as tests/ui/test_c3_fx_code_lobby_selection.gd).
	lobby._discovery = SgLanDiscovery.new()
	autofree(lobby._discovery)
	lobby._discovery.scanning = true
	lobby._refresh()
	# Host A is invitation only; its listing has the same default table name.
	var advert := {"address": "192.168.0.5", "port": 17897, "name": "Amber Owl",
		"fingerprint": "a".repeat(64), "rooms": 1, "build": lobby.client.build_fingerprint,
		"stamp": SgCompatibility.stamp(), "access": "invitation",
		"tables": [{"name": "Friendly duel", "decks": "own", "deck": "", "open": true}]}
	lobby._join_advert(advert, "Friendly duel")
	assert_true(lobby._window_open(), "control: the invitation window opened for host A")
	assert_eq(lobby._pending_join, "Friendly duel", "control: host A's table is pending")
	# No invitation from A: the player stops the search, as the notice
	# advises, and joins B with its local access code.
	lobby._close_windows()
	lobby._scan.pressed.emit()
	assert_true(lobby._selected_host.is_empty(), "control: Stop LAN search dropped the selection")
	assert_eq(lobby._pending_join, "", "and the table name that belonged to it")
	lobby._code.text = server.access_code
	lobby._port.value = server.port
	lobby._connect_local()
	await _until(func() -> bool: return lobby.client.online and not lobby.client.busy())
	for i in 10: await get_tree().process_frame
	await _until(func() -> bool: return not lobby.client.busy())
	assert_true(lobby.client.state.room.is_empty(), "connecting to host B seats the player nowhere until they pick a table")


func test_leaving_the_browser_drops_a_pending_name_no_connection_carries() -> void:
	var lobby := _lobby()
	lobby._nickname.text = "Owl"
	lobby._show_page("browser")
	lobby._discovery = SgLanDiscovery.new()
	autofree(lobby._discovery)
	lobby._discovery.scanning = true
	lobby._refresh()
	var advert := {"address": "192.168.0.5", "port": 17897, "name": "Amber Owl",
		"fingerprint": "a".repeat(64), "rooms": 1, "build": lobby.client.build_fingerprint,
		"stamp": SgCompatibility.stamp(), "access": "invitation",
		"tables": [{"name": "Friendly duel", "decks": "own", "deck": "", "open": true}]}
	lobby._join_advert(advert, "Friendly duel")
	assert_eq(lobby._pending_join, "Friendly duel", "control: pending")
	lobby._show_page("home")
	assert_true(lobby._selected_host.is_empty(), "control: leaving the page stops the search and its selection")
	assert_eq(lobby._pending_join, "", "and its pending table")


# --- R4-6 ---------------------------------------------------------------

func test_the_friendly_table_states_the_deck_size_the_referee_accepts() -> void:
	var lobby := _lobby()
	lobby.client.state.room = {"id": "r1", "name": "Kitchen table", "seat": 0,
		"names": ["Fox (Guest 1)", "Owl (Guest 2)"], "revision": 1, "ready": [false, false],
		"connected": [true, true], "game": {}, "deck_names": ["Small", "Forest practice"], "deck": {},
		"decks": "own", "fixed_deck": "", "rules": SgTableRules.standard()}
	lobby._show_page("room")
	var floor_cards: Array = Array(StarterDecks.WHITE_KNIGHTS).slice(0, DeckModel.CASUAL_MIN_CARDS)
	assert_eq(SgDeckCatalog.validate(floor_cards), "", "control: the casual floor is accepted at a friendly table")
	assert_ne(SgDeckCatalog.validate(floor_cards.slice(1)), "", "control: one card fewer is refused")
	var room_text := _texts(lobby._body)
	var rules_text := _texts(lobby._rules_window)
	var sizes := "%d–250 cards" % DeckModel.CASUAL_MIN_CARDS
	assert_false(room_text.contains("40–250 cards"), "the waiting room does not claim a 40-card floor")
	assert_false(rules_text.contains("40–250 cards"), "the Table rules window does not claim a 40-card floor")
	assert_string_contains(room_text, sizes, "the waiting room names the referee's bounds")
	assert_string_contains(rules_text, sizes, "and so does the Table rules window")
	assert_string_contains(room_text, "%d+ advised" % DeckModel.MIN_CARDS, "with the size it advises")
	lobby.client.forget()


# --- R4-7 ---------------------------------------------------------------

func _join_buttons(lobby: SgLobby) -> Array:
	var out: Array = []
	for node in lobby._body.find_children("*", "Button", true, false):
		if (node as Button).text in ["Join", "In use", "In play"]: out.append(node)
	return out


func _check(lobby: SgLobby, dimensions: Vector2i, what: String) -> void:
	for i in 6: await get_tree().process_frame
	var window: Rect2 = lobby._window.get_global_rect()
	assert_true(window.position.x >= 0.0 and window.end.x <= float(dimensions.x),
		"%s at %s: the window fits the screen (%s)" % [what, dimensions, window])
	assert_true(window.size.x <= 980.5, "%s at %s: the window keeps its own width (%s)" % [what, dimensions, window])
	var buttons := _join_buttons(lobby)
	assert_false(buttons.is_empty(), "control: %s has its Join buttons" % what)
	for button: Button in buttons:
		var rect := button.get_global_rect()
		assert_true(rect.end.x <= float(dimensions.x) and rect.position.x >= 0.0,
			"%s at %s: the row's %s button is on screen (%s)" % [what, dimensions, button.text, rect])


func _deck_cell(lobby: SgLobby, deck_name: String) -> Label:
	for node in lobby._body.find_children("*", "Label", true, false):
		if (node as Label).text.begins_with("Assigned: " + deck_name): return node
	return null


## A saved deck may carry a long name (the Deck Builder takes 200
## characters, the wire 128); the game's stretch keeps the logical width at
## 1280 or more.
const NAME_100 := "Evening league deck number seven with the long sideboard plan and the Old School Winds of Change list"


func test_a_long_assigned_deck_keeps_the_lan_listing_on_screen() -> void:
	var deck_name := NAME_100.left(100)
	for dimensions in [Vector2i(1280, 800), Vector2i(1422, 800)]:
		var lobby := _lobby(dimensions)
		lobby._show_page("browser")
		lobby._discovery = SgLanDiscovery.new()
		autofree(lobby._discovery)
		var advert := {"address": "192.168.0.5", "port": 17897, "name": "Emerald Falcon 123",
			"fingerprint": "a".repeat(64), "rooms": 2, "build": lobby.client.build_fingerprint,
			"stamp": SgCompatibility.stamp(), "access": "invitation",
			"tables": [{"name": "Old School night", "decks": "fixed", "deck": deck_name,
				"open": true, "rules": SgTableRules.brief(SgTableRules.standard())},
				{"name": "Friendly duel", "decks": "own", "deck": "", "open": true,
				"rules": SgTableRules.brief(SgTableRules.standard())}]}
		lobby._discovery.hosts["192.168.0.5:17897"] = {"host": advert, "seen": Time.get_ticks_msec()}
		lobby._refresh()
		await _check(lobby, dimensions, "LAN listing")
		var cell := _deck_cell(lobby, deck_name)
		assert_not_null(cell, "control: the DECKS cell is listed")
		if cell != null: assert_string_contains(cell.tooltip_text, deck_name, "the whole deck name is in its tooltip")
		lobby.client.forget()


func test_a_players_long_deck_name_keeps_the_hosts_own_list_on_screen() -> void:
	var name_100 := NAME_100.left(100)
	for dimensions in [Vector2i(1280, 800), Vector2i(1422, 800)]:
		var lobby := _lobby(dimensions)
		lobby.client.online = true
		lobby.client.state = {"rooms": [{"id": "r1", "name": "Old School night", "host": "Emerald Falcon 123 (Guest 12)",
			"open": true, "decks": "fixed", "deck": name_100, "rules": SgTableRules.brief(SgTableRules.standard())}], "room": {}}
		lobby._show_page("browser")
		await _check(lobby, dimensions, "host's room list")
		var cell := _deck_cell(lobby, name_100)
		assert_not_null(cell, "control: the DECKS cell is listed")
		if cell != null: assert_string_contains(cell.tooltip_text, name_100, "the whole deck name is in its tooltip")
		lobby.client.online = false
		lobby.client.forget()


# --- R4-9 ---------------------------------------------------------------

func test_the_deck_picker_drops_connection_lost_once_reconnected() -> void:
	assert_eq(server.start_local(0), OK)
	assert_eq(host_client.connect_local(server.port, server.access_code, "Fox"), OK)
	await _until(func() -> bool: return host_client.online)
	assert_true(host_client.command({"op": "host", "name": "Kitchen table", "decks": "own", "deck": {}}))
	await _until(func() -> bool: return not host_client.busy() and not host_client.state.room.is_empty())
	var lobby := _lobby()
	lobby._nickname.text = "Owl"
	lobby._code.text = server.access_code
	lobby._port.value = server.port
	lobby._connect_local()
	await _until(func() -> bool: return lobby.client.online and not lobby.client.busy())
	assert_true(lobby._send({"op": "join", "room": String(host_client.state.room.id)}))
	await _until(func() -> bool: return not lobby.client.busy() and not lobby.client.state.room.is_empty())
	for i in 4: await get_tree().process_frame
	lobby._open_decks()
	assert_true(is_instance_valid(lobby._deck_picker), "control: the deck picker is open")
	var before := lobby._deck_status.text
	# The connection blinks; the client reconnects with its held seat.
	lobby.client._socket.close(-1)
	await _until(func() -> bool: return not lobby.client.online)
	for i in 3: await get_tree().process_frame
	assert_string_contains(lobby._deck_status.text, "Connection lost", "control: the picker says so while offline")
	await _until(func() -> bool: return lobby.client.online and not lobby.client.busy(), 1500)
	for i in 6: await get_tree().process_frame
	lobby._refresh()
	assert_true(is_instance_valid(lobby._deck_picker), "control: the picker stayed open")
	assert_false(lobby._deck_status.text.contains("Connection lost"),
		"the picker does not still say the connection is lost once it is back")
	assert_eq(lobby._deck_status.text, before, "it says again what it said before")


# --- R4-10 --------------------------------------------------------------

func _room() -> Dictionary:
	return {"id": "r1", "name": "Kitchen table", "seat": 0,
		"names": ["Fox (Guest 1)", "Empty seat"], "revision": 1, "ready": [false, false],
		"connected": [true, false], "game": {}, "deck_names": ["Forest practice", "Forest practice"], "deck": {},
		"decks": "own", "fixed_deck": "", "rules": SgTableRules.standard()}


func test_another_tables_change_keeps_the_waiting_rooms_controls() -> void:
	var lobby := _lobby()
	lobby.client.online = true
	var listing := [{"id": "r1", "name": "Kitchen table", "host": "Fox (Guest 1)", "open": true,
		"decks": "own", "deck": "", "rules": "Modern rules, mana burn on  ·  20 life"}]
	lobby.client.state = {"rooms": listing.duplicate(true), "room": _room()}
	lobby._refresh()
	assert_eq(lobby._page, "room", "control: the host's waiting room")
	var search := lobby._body.find_child("BotDeckSearch", true, false) as LineEdit
	assert_not_null(search, "control: the computer-opponent search is there")
	if search == null: return
	search.grab_focus()
	search.text = "Gob"
	search.caret_column = 3
	# Another guest opens a table of their own at the same host.
	listing.append({"id": "r2", "name": "Late table", "host": "Owl (Guest 2)", "open": true,
		"decks": "own", "deck": "", "rules": "Modern rules, mana burn on  ·  20 life"})
	lobby.client.state = {"rooms": listing.duplicate(true), "room": _room()}
	lobby._refresh()
	await get_tree().process_frame
	var after := lobby._body.find_child("BotDeckSearch", true, false) as LineEdit
	assert_true(after == search and is_instance_valid(search) and search.has_focus(),
		"the host's search keeps its focus while another table at the host changes")
	# The browser still lists every table, and follows their changes.
	lobby.client.state = {"rooms": listing.duplicate(true), "room": {}}
	lobby._refresh()
	assert_eq(lobby._page, "browser", "control: out of the room, on the browser")
	assert_string_contains(_texts(lobby._body), "Late table", "the host's other tables are listed on its browser page")
	listing.append({"id": "r3", "name": "Third table", "host": "Owl (Guest 2)", "open": true,
		"decks": "own", "deck": "", "rules": "Modern rules, mana burn on  ·  20 life"})
	lobby.client.state = {"rooms": listing.duplicate(true), "room": {}}
	lobby._refresh()
	assert_string_contains(_texts(lobby._body), "Third table", "a new table appears on the browser page")
	lobby.client.online = false


# --- R4-12 --------------------------------------------------------------

func _bot_setup() -> SgBotSetup:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var holder := VBoxContainer.new()
	viewport.add_child(holder)
	var setup := SgBotSetup.new()
	holder.add_child(setup)
	setup.build(1, [
		{"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []},
		{"name": "Second Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}])
	return setup


func test_a_hidden_search_result_is_not_still_added_as_the_bots_deck() -> void:
	var setup := _bot_setup()
	var add := setup.find_child("AddBots", true, false) as Button
	var list := setup.find_child("BotDeckList", true, false) as ItemList
	var search := setup.find_child("BotDeckSearch", true, false) as LineEdit
	assert_false(add.disabled, "control: the first deck is chosen by default")
	search.text = "No deck matches this phrase"
	search.text_changed.emit(search.text)
	assert_eq(list.item_count, 0, "control: the search hides every deck")
	var sent: Array = []
	setup.submitted.connect(func(_count: int, _options: Dictionary, deck: Dictionary) -> void: sent.append(deck))
	assert_true(add.disabled, "an invisible old result is not offered for submission")
	assert_false(bool(add.get_meta("available")), "nor marked available to the lobby's network gate")
	if not add.disabled: add.pressed.emit()
	assert_eq(sent.size(), 0, "nothing hidden is added")
	assert_true(setup.draft.get("deck", {}).is_empty(), "the remembered draft holds no hidden deck either")


func test_a_search_that_still_shows_the_chosen_deck_keeps_it() -> void:
	var setup := _bot_setup()
	var add := setup.find_child("AddBots", true, false) as Button
	var list := setup.find_child("BotDeckList", true, false) as ItemList
	var search := setup.find_child("BotDeckSearch", true, false) as LineEdit
	list.select(1)
	list.item_selected.emit(1)
	search.text = "second"
	search.text_changed.emit(search.text)
	assert_eq(list.item_count, 1, "control: one deck left")
	assert_eq(list.get_selected_items(), PackedInt32Array([0]), "the chosen deck stays selected where it is still listed")
	assert_false(add.disabled, "and can still be added")
	var sent: Array = []
	setup.submitted.connect(func(_count: int, _options: Dictionary, deck: Dictionary) -> void: sent.append(deck))
	add.pressed.emit()
	assert_eq(sent.size(), 1)
	if not sent.is_empty(): assert_eq(sent[0].name, "Second Knights", "the deck added is the one on screen")


# --- Q2 -----------------------------------------------------------------

func _event() -> SgTournament:
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Hall Cup", "limit": 8, "wins": 1, "policy": "fixed",
		"decks": [{"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]}, 4242), "")
	for i in 2:
		var pid := event.register("Player %d" % (i + 1), str(i).sha256_text())
		event.set_ready(pid, true)
	assert_eq(event.draw_round(), "")
	return event


func _organiser_view(event: SgTournament) -> Dictionary:
	var fake := SgLocalServer.new()
	add_child_autofree(fake)
	var host := SgTournamentHost.new()
	host.event = event
	host.organiser = 99
	fake.add_child(host)
	return SgProtocol.decode_payload(SgProtocol.encode(host.view(99)).to_ascii_buffer())


func _panel() -> SgTournamentPanel:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(1200, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	viewport.add_child(scroll)
	var panel := SgTournamentPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	return panel


func _button(panel: SgTournamentPanel, caption: String) -> Button:
	for node in panel.find_children("*", "Button", true, false):
		if (node as Button).text == caption: return node
	return null


func _armed(panel: SgTournamentPanel) -> PackedStringArray:
	var out := PackedStringArray()
	for node in panel.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("Confirm: "): out.append((node as Button).text)
	return out


func test_an_armed_ruling_disarms_when_its_pairing_changes() -> void:
	var event := _event()
	var pair: Dictionary = event.rounds[0][0]
	var first := String(event.entrant(int(pair.players[0])).name)
	for pid: int in pair.players: event.set_ready(pid, true)
	assert_eq(event.begin_game(int(pair.id)), "")
	var panel := _panel()
	panel.present(_organiser_view(event), true, false, true)
	panel._choose_section("overview")
	for i in 3: await get_tree().process_frame
	var declare := _button(panel, "Declare %s winner" % first)
	assert_not_null(declare, "control: the organiser can declare a winner over the live table")
	if declare == null: return
	declare.pressed.emit()
	assert_eq(_armed(panel), PackedStringArray(["Confirm: Declare %s winner" % first]), "control: one click arms it")
	# The game ends before the second click: the other seat wins it.
	assert_true(event.record_game(int(pair.id), int(pair.game), 1))
	panel.present(_organiser_view(event), true, false, true)
	panel._choose_section("overview")
	for i in 3: await get_tree().process_frame
	assert_not_null(_button(panel, "Correct: %s wins" % first), "control: the pairing is finished, a correction is offered")
	assert_eq(_armed(panel), PackedStringArray(), "the click armed over the live game does not stand over the result")
	# An unchanged pairing keeps an armed control (two clicks, as before).
	var correct := _button(panel, "Correct: %s wins" % first)
	if correct == null: return
	correct.pressed.emit()
	panel.present(_organiser_view(event), true, false, true)
	for i in 2: await get_tree().process_frame
	assert_eq(_armed(panel), PackedStringArray(["Confirm: Correct: %s wins" % first]), "a refresh of the same state keeps it armed")
