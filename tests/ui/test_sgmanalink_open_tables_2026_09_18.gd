extends GutTest
## THE OPEN TABLE (2026-09-18). After a LAN playtest the owner ruled that
## pasting an invitation is too much for a kitchen-table game: a host is
## open by default, its advert carries the invitation itself, and the Game
## Browser joins the duel BY NAME with one click. Invitation only keeps the
## secret and the certificate out of the advert. A table plays either the
## decks the players bring or the one deck the host assigns to both seats,
## and the advert says which before anyone connects. Protocol 21.

var server: SgLocalServer
var scanner: SgLanDiscovery
var clients: Array = []
var refusals: Array = []


func before_each() -> void:
	server = SgLocalServer.new()
	add_child_autofree(server)
	scanner = SgLanDiscovery.new()
	add_child_autofree(scanner)
	refusals.clear()


func after_each() -> void:
	for client: SgLocalClient in clients:
		if is_instance_valid(client): client.forget()
	clients.clear()
	scanner.stop()
	server.stop()
	for i in 3: await get_tree().process_frame


func _until(predicate: Callable, frames := 600) -> bool:
	for i in frames:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "the LAN exchange exceeded its frame budget")
	return false


## A LAN host on loopback with an ephemeral discovery port (UDP 17898 is
## one computer's to lend); [param open] is the Invitation only switch, off.
func _host(open := true) -> void:
	assert_eq(server.start_lan("127.0.0.1", 0, true, "Forest Fox", 0, open), OK)
	assert_eq(server.discovery_error, OK)
	assert_eq(scanner.scan(), OK)


func _advert() -> Dictionary:
	server.poll()
	scanner.hosts.clear()
	scanner.query("127.0.0.1", server.discovery._socket.get_local_port())
	await _until(func() -> bool: return scanner.hosts.size() == 1)
	return scanner.hosts.values()[0].host if scanner.hosts.size() == 1 else {}


func _client(nickname: String) -> SgLocalClient:
	var client := SgLocalClient.new()
	add_child_autofree(client)
	clients.append(client)
	client.refused.connect(func(reason: String) -> void: refusals.append(reason))
	assert_eq(client.connect_invitation(server.invitation(), nickname), OK)
	await _until(func() -> bool: return client.online)
	return client


func _act(client: SgLocalClient, action: Dictionary) -> void:
	assert_true(client.command(action), client.command_error)
	await _until(func() -> bool: return not client.busy())
	for i in 3: await get_tree().process_frame


func _deck() -> Dictionary:
	return {"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}


func test_short_casual_decks_cross_the_socket_for_own_fixed_and_bot_seats() -> void:
	_host()
	var fox := await _client("Fox")
	var small := _deck()
	small.cards = small.cards.slice(0, 35)
	small.name = "Casual 35"
	await _act(fox, {"op": "host", "name": "Short decks", "decks": "own", "deck": {}})
	var hare := await _client("Hare")
	await _act(hare, {"op": "join", "room": String(fox.state.room.id)})
	await _act(fox, small.merged({"op": "deck"}))
	await _act(hare, small.merged({"op": "deck"}))
	await _act(fox, {"op": "ready", "value": true})
	await _act(hare, {"op": "ready", "value": true})
	var room: Dictionary = server._rooms[fox.state.room.id]
	assert_not_null(room.match)
	if room.match != null:
		for player in room.match.game.players:
			assert_eq(player.hand.size() + player.library.size(), 35, "no fallback or padding")
	var owl := await _client("Owl")
	await _act(owl, {"op": "host", "name": "Fixed short", "decks": "fixed", "deck": small})
	await _act(owl, {"op": "add_bot", "bot": SgBotPlayer.defaults(), "deck": small})
	assert_eq(owl.state.room.deck.cards.size(), 35)
	assert_eq(refusals, [])
	assert_false(SgTournament.valid_deck(small), "a friendly table does not relax tournaments")


func test_printing_preferences_cross_the_socket_only_for_their_visible_seat() -> void:
	_host()
	var fox := await _client("Fox")
	await _act(fox, {"op": "host", "name": "Artwork", "decks": "own", "deck": {}})
	var hare := await _client("Hare")
	await _act(hare, {"op": "join", "room": String(fox.state.room.id)})
	var chosen := _deck().merged({"printings": {"Plains": "por:199"}})
	await _act(fox, chosen.merged({"op": "deck"}))
	assert_eq(fox.state.room.deck.printings, chosen.printings)
	assert_false(JSON.stringify(hare.state.room).contains("por:199"))
	await _act(hare, _deck().merged({"op": "deck"}))
	await _act(fox, {"op": "ready", "value": true})
	await _act(hare, {"op": "ready", "value": true})
	assert_eq(refusals, [])
	var room: Dictionary = server._rooms[fox.state.room.id]
	assert_not_null(room.match)
	if room.match == null: return
	for card: CardInstance in room.match.game.players[0].library + room.match.game.players[0].hand:
		if card.data.card_name == "Plains": assert_eq(CardPrintings.of(card), "por:199")
	assert_false(JSON.stringify(hare.state.room).contains("por:199"), "no hidden deck metadata crosses to the other player")


func test_an_open_host_advertises_its_invitation_and_each_table_with_its_deck_rule() -> void:
	_host()
	var advert := await _advert()
	if advert.is_empty(): return
	assert_eq(String(advert.access), "open")
	assert_true(SgLanDiscovery.open_host(advert))
	assert_eq(String(advert.invitation), server.invitation(),
		"the advert carries the very invitation the host would hand out: the browser joins with a click")
	assert_eq(advert.tables, [], "no table yet")
	var fox := await _client("Fox")
	await _act(fox, {"op": "host", "name": "Kitchen table", "decks": "own", "deck": {}})
	var owl := await _client("Owl")
	await _act(owl, {"op": "host", "name": "Knights only", "decks": "fixed", "deck": _deck()})
	advert = await _advert()
	assert_eq(int(advert.rooms), 2)
	assert_eq(advert.tables, [
		{"name": "Kitchen table", "decks": "own", "deck": "", "open": true},
		{"name": "Knights only", "decks": "fixed", "deck": "White Knights", "open": true}],
		"the advert names each duel and its deck rule; that is what the browser shows")
	assert_true(JSON.stringify(advert).length() <= SgLanDiscovery.MAX_PACKET)
	assert_false(JSON.stringify(advert).contains(fox._resume), "never a seat's resume capability")
	# A taken table stays listed, marked so the browser says "In play".
	var guest := await _client("Guest")
	await _act(guest, {"op": "join", "room": String(fox.state.rooms[0].id)})
	advert = await _advert()
	assert_eq(int(advert.rooms), 1)
	assert_false(bool(advert.tables[0].open))
	assert_true(bool(advert.tables[1].open))


func test_an_invitation_only_host_lists_its_tables_but_never_its_secret_or_certificate() -> void:
	_host(false)
	var fox := await _client("Fox")
	await _act(fox, {"op": "host", "name": "Kitchen table", "decks": "own", "deck": {}})
	var advert := await _advert()
	if advert.is_empty(): return
	assert_eq(String(advert.access), "invitation")
	assert_false(SgLanDiscovery.open_host(advert))
	assert_false(advert.has("invitation"))
	assert_eq(advert.tables, [{"name": "Kitchen table", "decks": "own", "deck": "", "open": true}],
		"the duel's name is still what a player looks for")
	var listing := JSON.stringify(scanner.hosts)
	assert_false(listing.contains(server.access_code), "the secret is never broadcast")
	assert_false(listing.contains(server._lan_pem), "nor the certificate")
	assert_eq(String(advert.fingerprint), server._lan_pem.sha256_text(),
		"the fingerprint still checks a pasted invitation against the listening host")
	assert_false(SgLanDiscovery.valid_advert(advert.merged({"invitation": server.invitation()})),
		"an invitation on an invitation-only advert is a forgery")


func _lobby() -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	clients.append(lobby.client)
	return lobby


func test_the_browser_joins_an_open_table_by_name_without_a_paste() -> void:
	_host()
	var fox := await _client("Fox")
	await _act(fox, {"op": "host", "name": "Kitchen table", "decks": "own", "deck": {}})
	server.poll()
	var lobby := _lobby()
	lobby._nickname.text = "Owl"
	lobby._show_page("browser")
	assert_null(lobby._discovery, "opening the browser starts no search")
	lobby._scan_lan()
	lobby._discovery.query("127.0.0.1", server.discovery._socket.get_local_port())
	await _until(func() -> bool: return lobby._discovery.hosts.size() == 1)
	lobby._refresh()
	var rows := ""
	for label: Label in lobby._body.find_children("*", "Label", true, false): rows += label.text + "\n"
	for cell in ["DUEL", "Kitchen table", "Forest Fox", "Bring your own", "INVITE ONLY", "Same as yours"]:
		assert_string_contains(rows, cell)
	var marks: Array = []
	for mark: CheckBox in lobby._body.find_children("*", "CheckBox", true, false): marks.append(mark.button_pressed)
	assert_eq(marks, [false], "an open table's INVITE ONLY box is empty")
	var join: Button
	for button: Button in lobby._body.find_children("*", "Button", true, false):
		if button.text == "Join": join = button
	assert_not_null(join)
	if join == null: return
	var stale: Dictionary = lobby._discovery.hosts.values()[0].host.duplicate(true)
	join.pressed.emit()
	assert_eq(lobby._pending_join, "Kitchen table")
	assert_true(lobby.client._wanted, "an open host connects at once")
	assert_eq(lobby._code.text, "", "nothing was pasted")
	assert_false(lobby._window_open(), "and no invitation window opened")
	await _until(func() -> bool: return not lobby.client.state.room.is_empty() and not lobby.client.busy())
	for i in 4: await get_tree().process_frame
	assert_eq(String(lobby.client.state.room.name), "Kitchen table")
	assert_eq(int(lobby.client.state.room.seat), 1)
	assert_eq(lobby._pending_join, "")
	assert_eq(lobby._page, "room")
	assert_true(lobby.client.guest.begins_with("Owl"))
	# The table is taken now; a second browser holding the stale listing
	# connects, finds it closed and says so instead of sitting anywhere.
	var late := _lobby()
	late._nickname.text = "Late"
	late._join_advert(stale, "Kitchen table")
	await _until(func() -> bool: return late.client.online and not late.client.busy())
	for i in 4: await get_tree().process_frame
	assert_true(late.client.state.room.is_empty())
	assert_string_contains(late._notice.text, "“Kitchen table” is no longer open")


func test_an_assigned_deck_is_dealt_to_both_seats_and_refused_as_a_choice() -> void:
	_host()
	var fox := await _client("Fox")
	var owl := await _client("Owl")
	await _act(fox, {"op": "host", "name": "Knights only", "decks": "fixed", "deck": _deck()})
	assert_eq(String(fox.state.room.decks), "fixed")
	assert_eq(String(fox.state.room.fixed_deck), "White Knights")
	assert_eq(fox.state.room.deck_names, ["White Knights", "White Knights"])
	assert_eq(String(fox.state.rooms[0].decks), "fixed")
	assert_eq(String(fox.state.rooms[0].deck), "White Knights")
	await _act(owl, {"op": "join", "room": String(owl.state.rooms[0].id)})
	assert_eq(String(owl.state.room.deck.name), "White Knights", "the guest holds the table's deck on arrival")
	var other := {"op": "deck", "name": "Forest practice", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}
	await _act(owl, other)
	assert_eq(refusals.size(), 1)
	if refusals.size() == 1: assert_string_contains(String(refusals[0]), "assigned deck: White Knights")
	assert_eq(String(owl.state.room.deck.name), "White Knights", "the choice changed nothing")
	await _act(owl, {"op": "leave"})
	assert_eq(fox.state.room.deck_names[1], "White Knights", "the table keeps its deck when a seat empties")
	await _act(owl, {"op": "join", "room": String(owl.state.rooms[0].id)})
	await _act(fox, {"op": "ready", "value": true})
	await _act(owl, {"op": "ready", "value": true})
	await _until(func() -> bool: return not fox.state.room.get("game", {}).is_empty())
	assert_eq(fox.state.room.deck_names, ["White Knights", "White Knights"], "both seats play it")
	# A bring-your-own table is what it was: the seat's own deck, changeable.
	var hare := await _client("Hare")
	await _act(hare, {"op": "host", "name": "Anything goes", "decks": "own", "deck": {}})
	assert_eq(String(hare.state.room.decks), "own")
	assert_eq(String(hare.state.room.fixed_deck), "")
	await _act(hare, _deck().merged({"op": "deck"}))
	assert_eq(refusals.size(), 1)
	assert_eq(String(hare.state.room.deck.name), "White Knights")


func test_protocol_21_carries_the_deck_rule_and_refuses_the_old_host_shape() -> void:
	assert_eq(SgProtocol.VERSION, 23)
	assert_eq(SgProtocol.SUBPROTOCOL, "sgmanalink-local-v23")
	assert_eq(SgLanDiscovery.MAX_PACKET, 16384, "room for the certificate inside an open advert")
	var message := func(action: Dictionary) -> Dictionary:
		return {"v": SgProtocol.VERSION, "type": "command", "seq": 1, "room": "", "revision": 0, "action": action}
	assert_true(SgProtocol.valid(message.call({"op": "host", "name": "Kitchen table", "decks": "own", "deck": {}})))
	var smoke: Script = load("res://tools/lan_smoke.gd")
	assert_true(SgProtocol.valid(message.call(smoke.HOST_ACTION)),
		"the two-process release probe must speak the current host protocol")
	assert_true(SgProtocol.valid(message.call({"op": "host", "name": "Knights only", "decks": "fixed", "deck": _deck()})))
	for action in [
			{"op": "host", "name": "Old shape"},
			{"op": "host", "name": "Own with a deck", "decks": "own", "deck": _deck()},
			{"op": "host", "name": "Fixed without one", "decks": "fixed", "deck": {}},
			{"op": "host", "name": "Unknown rule", "decks": "borrowed", "deck": {}},
			{"op": "host", "name": "Wrong type", "decks": "fixed", "deck": "White Knights"},
			{"op": "host", "name": "Bad deck", "decks": "fixed", "deck": {"name": "x", "cards": ["Not a card"], "sideboard": []}}]:
		assert_false(SgProtocol.valid(message.call(action)), str(action))
	for row in [
			{"id": "r1", "name": "Kitchen table", "host": "Fox", "open": true, "decks": "own", "deck": ""},
			{"id": "r1", "name": "Knights only", "host": "Fox", "open": false, "decks": "fixed", "deck": "White Knights"}]:
		assert_true(SgViewProtocol.valid({"type": "state", "rooms": [row], "room": {}}), str(row))
	for row in [
			{"id": "r1", "name": "Old shape", "host": "Fox", "open": true},
			{"id": "r1", "name": "Bad rule", "host": "Fox", "open": true, "decks": "any", "deck": ""},
			{"id": "r1", "name": "Bad deck", "host": "Fox", "open": true, "decks": "fixed", "deck": 7}]:
		assert_false(SgViewProtocol.valid({"type": "state", "rooms": [row], "room": {}}), str(row))
