extends GutTest
## THE TOURNAMENT RESULT'S OK REACHES THE HALL (whole-game campaign
## 2026-10-07, fix-net, w7-13). OK on a tournament game's result sent
## `t_return` once, on the spot; a seat whose connection blinked as the
## player dismissed the result stayed at the finished table with no result
## window left to press, and the table held up the next round. Now the
## return is kept until the connection can carry it, as a friendly
## duel's leave is (SgLobby._leave_room, bug pass 2026-10-03): with the
## real host, a lobby, its duel view and the real client reconnecting.

var server: SgLocalServer
var clients: Array[SgLocalClient] = []
var scratch := ""


func before_each() -> void:
	clients.clear()
	scratch = "user://campaign-fix-net-return/" + Crypto.new().generate_random_bytes(8).hex_encode()
	server = SgLocalServer.new()
	add_child_autofree(server)
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)


func after_each() -> void:
	for client in clients: client.forget()
	server.stop()
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := DirAccess.open(scratch)
	if dir != null:
		for filename in dir.get_files(): dir.remove(filename)
		DirAccess.remove_absolute(scratch)


func _until(predicate: Callable, frames := 800) -> bool:
	for i in frames:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "operation exceeded its frame budget")
	return false


func _client(name_value: String) -> SgLocalClient:
	var client := SgLocalClient.new()
	add_child_autofree(client)
	clients.append(client)
	assert_eq(client.connect_invitation(server.invitation(), name_value), OK)
	await _until(func() -> bool: return client.online)
	return client


func _lobby(name_value: String) -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	clients.append(lobby.client)
	assert_eq(lobby.client.connect_invitation(server.invitation(), name_value), OK)
	await _until(func() -> bool: return lobby.client.online)
	return lobby


func _act(client: SgLocalClient, op: String, fields := {}) -> void:
	var action := fields.duplicate(true)
	action.op = op
	if op.begins_with("t_"): action.event = server.tournament.event.id
	assert_true(client.command(action), op + ": " + client.command_error)
	await _until(func() -> bool: return not client.busy())
	for i in 3: await get_tree().process_frame


func test_ok_on_a_tournament_result_reaches_the_hall_once_the_connection_is_back() -> void:
	var owner := await _client("Organiser")
	assert_eq(server.open_tournament({"name": "LAN Cup", "limit": 8, "wins": 1, "policy": "fixed",
		"decks": [{"name": "Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]},
		owner._resume, scratch), "")
	await _until(func() -> bool: return owner.state.has("tournament"))
	var guest := await _lobby("Guest")
	var other := await _client("Other")
	for client in [guest.client, other]:
		await _act(client, "t_join")
		await _act(client, "t_ready", {"value": true})
	await _act(owner, "t_start")
	for client in [guest.client, other]: await _act(client, "t_ready", {"value": true})
	await _until(func() -> bool: return is_instance_valid(guest._duel))
	await _act(other, "concede")
	await _until(func() -> bool: return is_instance_valid(guest._duel) and guest._duel._result_seen)
	for i in 4: await get_tree().process_frame
	# The host's link blinks just as the player presses OK on the result.
	guest.client.reconnect()
	guest._duel._on_game_over_dismissed()
	await _until(func() -> bool: return guest.client.online)
	for i in 60: await get_tree().process_frame
	assert_true(guest.client.state.room.is_empty(),
		"OK on the result returns the seat to the hall once the connection is back (it stays at the finished table: room %s)" % str(guest.client.state.room.get("id", "")))
	assert_eq(guest._page, "tournament", "and the hall is shown")


func test_ok_on_a_live_connection_returns_at_once() -> void:
	var owner := await _client("Organiser")
	assert_eq(server.open_tournament({"name": "LAN Cup", "limit": 8, "wins": 1, "policy": "fixed",
		"decks": [{"name": "Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]},
		owner._resume, scratch), "")
	await _until(func() -> bool: return owner.state.has("tournament"))
	var guest := await _lobby("Guest")
	var other := await _client("Other")
	for client in [guest.client, other]:
		await _act(client, "t_join")
		await _act(client, "t_ready", {"value": true})
	await _act(owner, "t_start")
	for client in [guest.client, other]: await _act(client, "t_ready", {"value": true})
	await _until(func() -> bool: return is_instance_valid(guest._duel))
	await _act(other, "concede")
	await _until(func() -> bool: return is_instance_valid(guest._duel) and guest._duel._result_seen)
	guest._duel._on_game_over_dismissed()
	await _until(func() -> bool: return guest.client.state.room.is_empty())
	assert_eq(guest._page, "tournament", "the hall is shown")
	assert_true(guest._return_hall.is_empty(), "nothing is left pending")
