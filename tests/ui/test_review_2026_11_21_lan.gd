extends GameTest
## WHOLE-PROJECT REVIEW 2026-11-21, LAN PLAY (game/sgmanalink/). Four
## findings, each pinned here:
##   1. a guest's "abandon" reaches the host before its socket dies when the
##      SGManalink screen closes ([method SgLocalClient.drain]);
##   2. a seat concedes while the other seat is away
##      ([method SgDuelView._send]);
##   3. the host's card-transfer allowance covers a whole plan: the bytes
##      sent and the requests counted beside them
##      ([constant SgCardTransfer.MAX_REQUESTS]);
##   4. Join in the Game Browser seats the player at the row clicked when
##      two tables carry one name ([member SgLobby._pending_row]).

var server: SgLocalServer
var clients: Array = []
var commands: Array = []


## A host that answers card requests from one made-up card, no socket.
class ShelfServer extends SgLocalServer:
	var sent: Array = []
	var zip := PackedByteArray()
	func _card_shelf() -> Array:
		return [{"name": "Big Moss", "spec": {}, "digest": "0".repeat(64), "size": zip.size(), "file": ""}]
	func _sending_bytes(_row: Dictionary) -> PackedByteArray:
		return zip
	func _send(_id: int, message: Dictionary) -> void:
		sent.append(message)


func before_each() -> void:
	super.before_each()
	server = SgLocalServer.new()
	add_child_autofree(server)
	commands.clear()


func after_each() -> void:
	for client: SgLocalClient in clients:
		if is_instance_valid(client): client.forget()
	clients.clear()
	server.stop()
	for i in 3: await get_tree().process_frame


func _until(predicate: Callable, frames := 600) -> bool:
	for i in frames:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "the LAN exchange exceeded its frame budget")
	return false


func _local_client(nickname: String) -> SgLocalClient:
	var client := SgLocalClient.new()
	add_child_autofree(client)
	clients.append(client)
	assert_eq(client.connect_local(server.port, server.access_code, nickname), OK)
	await _until(func() -> bool: return client.online)
	return client


func _act(client: SgLocalClient, action: Dictionary) -> void:
	assert_true(client.command(action), client.command_error)
	await _until(func() -> bool: return not client.busy())
	for i in 3: await get_tree().process_frame


# ------------------------------------------------------------ finding 1 --

func test_a_parting_clients_abandon_is_read_before_its_socket_goes() -> void:
	assert_eq(server.start_local(0), OK)
	assert_true(SgLocalServer.hosts_port(server.port), "a host in this process is known as one")
	var owl := await _local_client("Owl")
	await _act(owl, {"op": "host", "name": "Kitchen table", "decks": "own", "deck": {}})
	assert_eq(server._rooms.size(), 1)
	assert_eq(server._sessions.size(), 1)
	# The screen closes: the abandon is sent, and the parting socket is
	# polled until the host has closed it — the host polls between two.
	owl.forget()
	assert_eq(owl._closing.size(), 1, "the parting socket waits")
	owl.drain(2000, server.poll)
	assert_eq(owl._closing.size(), 0, "the host closed it")
	assert_eq(server._sessions.size(), 0, "the seat is given up at once, not after the reconnect grace")
	assert_eq(server._rooms.size(), 0)
	var gone := server.port
	server.stop()
	assert_false(SgLocalServer.hosts_port(gone))
	assert_false(SgLocalServer.hosts_port(0))


func test_a_client_leaving_the_tree_waits_for_a_host_elsewhere_only() -> void:
	assert_eq(server.start_local(0), OK)
	var owl := await _local_client("Owl")
	# A host in another process: this one cannot answer while the client
	# waits, so the wait runs its whole time and the socket is still there.
	SgLocalServer._listening.erase(server.port)
	var started := Time.get_ticks_msec()
	owl.get_parent().remove_child(owl)
	assert_gte(Time.get_ticks_msec() - started, SgLocalClient.EXIT_DRAIN_MS - 20, "the parting socket was waited for")
	assert_eq(owl._closing.size(), 1)
	for i in 10:
		server.poll()
		owl.drain(0)
	assert_eq(server._sessions.size(), 0, "and the abandon was there to read")
	owl.free()
	clients.clear()


# ------------------------------------------------------------ finding 2 --

func _room(connected: Array, hold := "none") -> Dictionary:
	var referee := SgPracticeMatch.new(42)
	referee.game = g
	var room := {"id": "r1", "name": "Friendly duel", "seat": 0,
		"names": ["Azure Fox", "Amber Owl"], "revision": 1,
		"ready": [true, true], "connected": connected, "game": referee.view(0),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}
	if hold != "none":
		room["tournament"] = {"id": "a".repeat(64), "name": "Cup", "round": 1, "pair": 1, "game": 1,
			"wins": [0, 0], "target": 1, "hold": hold}
	return room


func _screen(room: Dictionary) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	viewport.add_child(screen)
	screen.action_requested.connect(func(action: Dictionary) -> void: commands.append(action.duplicate(true)))
	screen.present(room, true, false)
	return screen


func test_a_seat_concedes_while_the_other_seat_is_away() -> void:
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	advance_to_step(Mtg.Step.MAIN1)
	var screen := _screen(_room([true, false], ""))
	for i in 4: await get_tree().process_frame
	assert_true(screen._built)
	assert_true(screen.projection.locked, "the table is suspended")
	screen._send({"op": "pass"})
	assert_eq(commands, [], "nothing else passes the lock")
	screen._send({"op": "concede"})
	assert_eq(commands, [{"op": "concede"}], "the concession is sent")
	assert_true(screen.projection.locked)
	# One in flight: no second one beside it.
	screen._send({"op": "concede"})
	assert_eq(commands.size(), 1)
	# A refusal does not open a suspended table.
	screen.show_notice("Wait for your decision.")
	assert_true(screen.projection.locked, "the other seat is still away")


func test_a_tournament_hold_still_holds_a_concession() -> void:
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	advance_to_step(Mtg.Step.MAIN1)
	var screen := _screen(_room([true, false], "organiser"))
	for i in 4: await get_tree().process_frame
	assert_true(screen._built)
	screen._send({"op": "concede"})
	assert_eq(commands, [], "the referee refuses everything under a hold")
	# And an open table sends it the ordinary way.
	var open := _screen(_room([true, true]))
	for i in 4: await get_tree().process_frame
	commands.clear()
	open._send({"op": "concede"})
	assert_eq(commands, [{"op": "concede"}])


# ------------------------------------------------------------ finding 3 --

func _shelf_server(bytes: int) -> ShelfServer:
	var host := ShelfServer.new()
	add_child_autofree(host)
	host.access_code = "c".repeat(64)
	host.zip.resize(bytes)
	host._peers[1] = {"socket": WebSocketPeer.new(), "session": 0, "waited": 0}
	return host


func _card(host: ShelfServer, offset: int) -> void:
	host._transfer(1, {"v": SgProtocol.VERSION, "type": "card", "access": host.access_code,
		"name": "Big Moss", "offset": offset})


func test_a_plan_of_many_two_chunk_cards_completes() -> void:
	# 110 cards of 600 KiB: 64 MiB, two requests a card — within the
	# guest's own limits (200 cards, 96 MiB). The 205th request was refused.
	var size := 600 * 1024
	var host := _shelf_server(size)
	assert_lt(110 * size, SgCardTransfer.MAX_TOTAL)
	for card in 110:
		_card(host, 0)
		_card(host, SgCardTransfer.CHUNK)
	assert_eq(host.sent.size(), 220)
	for reply: Dictionary in host.sent:
		if reply.get("type") != "card" or String(reply.get("error", "")) != "":
			assert_true(false, "refused: %s" % str(reply.get("error", reply)).left(120))
			break
	assert_false((host._peers[1] as Dictionary).has("reject_until"), "the connection is kept")
	assert_eq(int(host._peers[1].requests), 220)
	assert_almost_eq(int(host._peers[1].served), 110 * size, 220 * 3, "the bytes really sent")
	host._peers.clear()


func test_requests_past_the_largest_plan_are_refused() -> void:
	var host := _shelf_server(4096)
	assert_eq(SgCardTransfer.MAX_REQUESTS, SgCardTransfer.MAX_CARDS
		+ (SgCardTransfer.MAX_TOTAL + CommunityCards.MAX_ZIP) / SgCardTransfer.CHUNK)
	for i in SgCardTransfer.MAX_REQUESTS:
		_card(host, 4095)
	assert_eq(host.sent.size(), SgCardTransfer.MAX_REQUESTS)
	assert_false((host._peers[1] as Dictionary).has("reject_until"), "every request of the largest plan is answered")
	_card(host, 4095)
	assert_eq(String(host.sent.back().get("error", "")), SgCardTransfer.TOO_MANY, "one more is not")
	assert_true((host._peers[1] as Dictionary).has("reject_until"))
	host._peers.clear()


# ------------------------------------------------------------ finding 4 --

func _lan_client(nickname: String) -> SgLocalClient:
	var client := SgLocalClient.new()
	add_child_autofree(client)
	clients.append(client)
	assert_eq(client.connect_invitation(server.invitation(), nickname), OK)
	await _until(func() -> bool: return client.online)
	return client


func test_join_seats_the_player_at_the_row_clicked_when_names_repeat() -> void:
	assert_eq(server.start_lan("127.0.0.1", 0, true, "Forest Fox", 0, true), OK)
	assert_eq(server.discovery_error, OK)
	var fox := await _lan_client("Fox")
	var hen := await _lan_client("Hen")
	var deck := {"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}
	await _act(fox, {"op": "host", "name": "Friendly duel", "decks": "own", "deck": {}})
	await _act(hen, {"op": "host", "name": "Friendly duel", "decks": "fixed", "deck": deck})
	server.poll()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	clients.append(lobby.client)
	lobby._nickname.text = "Owl"
	lobby._show_page("browser")
	lobby._scan_lan()
	lobby._discovery.query("127.0.0.1", server.discovery._socket.get_local_port())
	await _until(func() -> bool: return lobby._discovery.hosts.size() == 1)
	lobby._refresh()
	var joins: Array = []
	for button: Button in lobby._body.find_children("*", "Button", true, false):
		if button.text == "Join": joins.append(button)
	assert_eq(joins.size(), 2, "two tables of one name, a row each")
	if joins.size() != 2: return
	# The second row: Hen's table, which deals its assigned deck.
	(joins[1] as Button).pressed.emit()
	assert_eq(lobby._pending_join, "Friendly duel")
	assert_eq(String(lobby._pending_row.get("decks", "")), "fixed")
	await _until(func() -> bool: return not lobby.client.state.room.is_empty() and not lobby.client.busy())
	for i in 4: await get_tree().process_frame
	assert_eq(String(lobby.client.state.room.decks), "fixed", "the table of the row clicked")
	assert_eq(String(lobby.client.state.room.fixed_deck), "White Knights")
	assert_true(String(lobby.client.state.room.names[0]).begins_with("Hen"))
	assert_eq(lobby._pending_row, {})
	assert_true(fox.state.room.names[1] == "Empty seat", "Fox's table of the same name stays open")


func test_a_join_that_knows_only_the_name_takes_the_first_open_table() -> void:
	var rooms := [{"id": "r1", "name": "Friendly duel", "open": true, "decks": "own", "deck": "", "rules": "x"},
		{"id": "r2", "name": "Friendly duel", "open": true, "decks": "fixed", "deck": "White Knights", "rules": "x"}]
	assert_false(SgLobby._same_table(rooms[1], {}), "no row, no match: the name alone decides, as before")
	assert_true(SgLobby._same_table(rooms[1], {"name": "Friendly duel", "decks": "fixed", "deck": "White Knights", "open": true, "rules": "x"}))
	assert_false(SgLobby._same_table(rooms[0], {"name": "Friendly duel", "decks": "fixed", "deck": "White Knights", "open": true, "rules": "x"}))
	assert_false(SgLobby._same_table(rooms[1], {"decks": "fixed", "deck": "White Knights", "rules": "y"}))
