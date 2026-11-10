extends GameTest
## A SEAT THE HOST HAS ENDED, AND A TABLE WHOSE CONNECTION IS CLOSING (gap
## review 2026-11-10, R4-1, R4-2, R4-3).
##
## R4-1  A guest whose seat ended (it expired, or the host closed its
##       tables) stayed on the dead waiting room: the tabs hidden, Leave
##       greyed, and the Disconnect the host's message names nowhere on
##       screen; Reconnect after "The host closed its tables." retried the
##       closed host for ever. The room now offers Disconnect, the tabs
##       come back, and a host's last word is not asked again.
## R4-2  At a running table the banner kept promising "The game reconnects
##       by itself" after the host had closed, and the reason was shown
##       nowhere (the lobby's status line is hidden during a duel). The
##       banner now says why, and offers Leave table instead of Reconnect.
## R4-3  An automatic pass the lobby refused on the spot (online, but the
##       socket no longer open) unlocked the table, which passed again in
##       the same frame, without end: the message queue overflowed and the
##       game crashed. A command that never left keeps the table locked,
##       and a closing socket is offline.

var server: SgLocalServer
var host_client: SgLocalClient
var lobbies: Array = []
var referee: SgPracticeMatch


func before_each() -> void:
	super.before_each()
	server = SgLocalServer.new()
	add_child_autofree(server)
	host_client = SgLocalClient.new()
	add_child_autofree(host_client)
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	host_client.forget()
	for lobby in lobbies:
		if is_instance_valid(lobby): lobby.client.forget()
	lobbies.clear()
	server.stop()
	referee = null
	g = null
	for i in 3: await get_tree().process_frame


func _until(predicate: Callable, frames := 900) -> bool:
	for i in frames:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "frame budget exceeded")
	return false


func _lobby() -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	lobbies.append(lobby)
	return lobby


func _visible_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree() and not button.disabled: return button
	return null


func _stopped(client: SgLocalClient) -> bool:
	return client.has_session() and not client._wanted and not client.online


func _visible_text(root: Node) -> String:
	var out := ""
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree(): out += label.text + "\n"
	return out


## A guest seated at the host's "Kitchen table", in its waiting room.
func _seated_guest() -> SgLobby:
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
	assert_eq(lobby._page, "room", "control: the guest sits in the waiting room")
	return lobby


func test_an_expired_seat_offers_the_disconnect_its_message_names() -> void:
	var lobby := await _seated_guest()
	var guest_sid := int(server._tokens[lobby.client._resume.sha256_text()])
	# The guest's network goes away (a laptop lid): no polling, socket gone.
	lobby.client.set_process(false)
	lobby.client._socket.close(-1)
	await _until(func() -> bool: return not server._connected(guest_sid))
	# The host removes the disconnected guest with the room's own button.
	assert_true(host_client.command({"op": "remove_guest"}), host_client.command_error)
	await _until(func() -> bool: return not host_client.busy())
	# The network comes back: the resume is refused for good.
	lobby.client.set_process(true)
	await _until(func() -> bool: return not lobby.client._wanted, 1200)
	for i in 4: await get_tree().process_frame
	lobby._refresh()
	assert_string_contains(lobby.client.status, "Disconnect", "control: the refusal tells the guest to Disconnect")
	assert_true(_stopped(lobby.client), "the client has stopped: a seat, no connection, no retry")
	var disconnect := _visible_button(lobby, "Disconnect")
	assert_not_null(disconnect, "the Disconnect the message names is on screen")
	assert_true(lobby._navigation_bar.visible, "and the tabs lead out of the dead room")
	assert_false(lobby._navigation["browser"].disabled, "the Game Browser tab can be pressed")
	lobby._navigation["browser"].pressed.emit()
	assert_eq(lobby._page, "browser", "a tab takes the guest out of the dead room")
	if disconnect == null: return
	lobby._show_page("room")
	disconnect = _visible_button(lobby, "Disconnect")
	assert_not_null(disconnect)
	if disconnect == null: return
	disconnect.pressed.emit()
	for i in 2: await get_tree().process_frame
	assert_false(lobby.client.has_session(), "Disconnect forgets the ended seat")
	assert_eq(lobby._page, "home", "and returns to the Overview")
	assert_false(lobby._scan.disabled, "where the Game Browser can search again")


func test_a_closed_host_is_not_retried() -> void:
	var lobby := await _seated_guest()
	server.stop()
	await _until(func() -> bool: return not lobby.client._wanted, 600)
	for i in 4: await get_tree().process_frame
	lobby._refresh()
	assert_eq(lobby.client.status, SgLocalServer.HOST_CLOSED, "control: the guest was told")
	assert_true(lobby._navigation_bar.visible, "the tabs lead back to the Game Browser")
	assert_not_null(_visible_button(lobby, "Disconnect"), "Disconnect is on the room")
	assert_null(_visible_button(lobby._body, "Reconnect"), "Reconnect is not offered to a host that closed its tables")
	lobby.client.reconnect()
	for i in 10: await get_tree().process_frame
	assert_false(lobby.client._wanted, "nor does a Reconnect from elsewhere retry it")
	assert_eq(lobby.client.status, SgLocalServer.HOST_CLOSED, "the host's last word stays on screen")


## A guest whose connection merely dropped still reconnects by itself and
## keeps its Reconnect: only a stopped client loses it.
func test_a_dropped_connection_keeps_its_reconnect() -> void:
	var lobby := await _seated_guest()
	lobby.client.set_process(false)
	lobby.client._socket.close(-1)
	lobby.client.poll()
	for i in 2: await get_tree().process_frame
	lobby._refresh()
	assert_false(lobby.client.online, "control: offline")
	assert_true(lobby.client._wanted, "control: still trying")
	assert_false(_stopped(lobby.client), "a client that is still trying has not stopped")
	assert_eq(lobby._page, "room", "the room stays while the seat is held")
	assert_false(lobby._navigation_bar.visible, "with its tabs hidden as before")
	assert_not_null(_visible_button(lobby._body, "Reconnect"), "Reconnect stays offered")
	lobby.client.set_process(true)
	await _until(func() -> bool: return lobby.client.online and not lobby.client.busy(), 1200)
	assert_true(lobby.client.online, "and the seat comes back")


func test_the_table_says_why_the_host_is_gone() -> void:
	var lobby := await _seated_guest()
	await _until(func() -> bool: return not host_client.busy() and bool(host_client.state.room.connected[1]))
	assert_true(host_client.command({"op": "ready", "value": true}), host_client.command_error)
	await _until(func() -> bool: return not host_client.busy())
	await _until(func() -> bool: return bool(lobby.client.state.room.ready[0]) and not lobby.client.busy())
	for i in 4: await get_tree().process_frame
	assert_true(lobby._send({"op": "ready", "value": true}), lobby.client.command_error)
	await _until(func() -> bool: return is_instance_valid(lobby._duel) and lobby._duel._built)
	for i in 6: await get_tree().process_frame
	# The host closes SGManalink (its Confirm close stops the service).
	server.stop()
	await _until(func() -> bool: return not lobby.client._wanted, 600)
	for i in 6: await get_tree().process_frame
	lobby._refresh()
	for i in 3: await get_tree().process_frame
	assert_eq(lobby.client.status, SgLocalServer.HOST_CLOSED, "control: the client was told and stopped")
	assert_true(is_instance_valid(lobby._duel), "control: the last table stays up")
	if not is_instance_valid(lobby._duel): return
	var banner := String(lobby._duel._banner_text.text)
	assert_false(banner.contains("reconnects by itself"), "the banner promises no reconnection that will never come")
	assert_true(_visible_text(lobby).contains(SgLocalServer.HOST_CLOSED), "the reason the host gave is on screen")
	var button := lobby._duel._connection_banner.find_children("*", "Button", true, false)[0] as Button
	assert_eq(button.text, "Leave table", "the banner's button leaves the table instead of reconnecting")
	assert_ne(lobby._duel._network_badge.text, "Reconnect", "nor does the badge offer a reconnection")
	button.pressed.emit()
	for i in 4: await get_tree().process_frame
	assert_false(lobby.client.has_session(), "Leave table forgets the ended seat")
	assert_false(is_instance_valid(lobby._duel) and not lobby._duel.is_queued_for_deletion(), "the dead table goes")
	assert_true(lobby._shell.visible, "and the lobby is back")


func _room() -> Dictionary:
	return {"id": "r1", "name": "Kitchen table", "seat": 0, "names": ["One", "Two"],
		"revision": 2, "ready": [true, true], "connected": [true, true],
		"game": referee.view(0), "deck_names": referee.deck_names.duplicate(), "deck": {}}


## The lobby refuses on the spot (online, no open socket): with the defect
## the table re-drove its automatic pass in one deferred flush without end
## and the process crashed. Past a bound, this probe locks the table itself,
## so a regression fails here instead of taking the run down.
func test_a_refused_automatic_pass_does_not_spin_the_table() -> void:
	var lobby := _lobby()
	lobby.client.online = true
	lobby.client.state = {"rooms": [], "room": _room()}
	lobby._refresh()
	assert_true(is_instance_valid(lobby._duel), "control: the table is up")
	if not is_instance_valid(lobby._duel): return
	var screen: SgDuelView = lobby._duel
	var sent := [0]
	screen.action_requested.connect(func(_action: Dictionary) -> void:
		sent[0] += 1
		if sent[0] > 50: screen.projection.locked = true)
	for i in 30: await get_tree().process_frame
	assert_lt(sent[0], 5, "a refused pass is not sent again and again in one frame (%d sent)" % sent[0])
	assert_true(screen.projection.locked, "a command that never left keeps the table locked")
	lobby.client.online = false
	lobby.client.forget()


## A host's own refusal still unlocks the table: the seat may act again.
func test_a_refereed_refusal_still_unlocks_the_table() -> void:
	var lobby := _lobby()
	lobby.client.online = true
	lobby.client._pending = {"seq": 1}
	lobby.client.state = {"rooms": [], "room": _room()}
	lobby._refresh()
	assert_true(is_instance_valid(lobby._duel), "control: the table is up")
	if not is_instance_valid(lobby._duel): return
	lobby._duel.projection.locked = true
	lobby._duel.show_notice("That card can't be played now.")
	assert_false(lobby._duel.projection.locked, "the referee's refusal hands the table back")
	lobby._duel.projection.locked = true
	lobby._duel.show_notice(SgLocalClient.NOT_CONNECTED)
	assert_true(lobby._duel.projection.locked, "a command that never left does not")
	lobby.client._pending = {}
	lobby.client.online = false
	lobby.client.forget()


func test_a_closing_socket_is_offline() -> void:
	assert_eq(server.start_local(0), OK)
	assert_eq(host_client.connect_local(server.port, server.access_code, "Fox"), OK)
	await _until(func() -> bool: return host_client.online and not host_client.busy())
	host_client.set_process(false)
	host_client._socket.close(1000)
	assert_eq(host_client._socket.get_ready_state(), WebSocketPeer.STATE_CLOSING, "control: the socket is closing")
	host_client.poll()
	assert_false(host_client.online, "a closing connection is not online")
	assert_false(host_client.command({"op": "ready", "value": true}), "and takes no command")
	assert_eq(host_client.status, "Connection lost; reconnecting...", "the status says the connection was lost")
	assert_true(host_client._wanted, "the client keeps trying")
	host_client.set_process(true)
	await _until(func() -> bool: return host_client.online and not host_client.busy(), 1200)
	assert_true(host_client.online, "and the connection comes back")
