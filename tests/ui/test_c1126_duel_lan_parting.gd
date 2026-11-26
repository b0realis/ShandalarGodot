extends GameTest
## A LAN SEAT GIVEN UP WHILE THE CONNECTION IS DOWN IS GIVEN UP AT THE HOST
## (campaign 2026-11-26, robustness 2): a guest who presses Disconnect
## while "reconnecting..." tells the host so on its next contact, and the
## other player is not held for the whole reconnect grace.
## Loopback only: the host is this process's own.

var server: SgLocalServer
var clients: Array = []


func before_each() -> void:
	super.before_each()
	server = SgLocalServer.new()
	add_child_autofree(server)


func after_each() -> void:
	for client: SgLocalClient in clients:
		if is_instance_valid(client):
			client.forget()
			client._partings.clear()
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


func _seated(nickname: String) -> SgLocalClient:
	var client := await _local_client(nickname)
	assert_true(client.command({"op": "host", "name": "Kitchen table", "decks": "own", "deck": {}}), client.command_error)
	await _until(func() -> bool: return not client.busy())
	for i in 3: await get_tree().process_frame
	return client


## The connection drops under [param client]: it is reconnecting, not online.
func _blip(client: SgLocalClient) -> void:
	client._socket.close(-1)
	client.poll()
	assert_false(client.online, "control: the connection is lost")
	assert_true(client.connecting(), "control: and the client is trying to get it back")
	assert_true(client.has_session(), "control: with its seat")


func test_a_disconnect_while_reconnecting_gives_the_seat_up_at_the_host() -> void:
	assert_eq(server.start_local(0), OK)
	var owl := await _seated("Owl")
	assert_eq(server._sessions.size(), 1)
	assert_eq(server._rooms.size(), 1)
	_blip(owl)
	owl.forget()
	assert_eq(owl._partings.size(), 1, "the leaving is still to be said")
	assert_false(owl.has_session(), "control: the visit itself is over at once")
	assert_eq(owl.status, "Not connected")
	var started := Time.get_ticks_msec()
	await _until(func() -> bool: return server._sessions.is_empty())
	assert_eq(server._rooms.size(), 0, "the seat and its table are given up")
	assert_lt(Time.get_ticks_msec() - started, SgLocalClient.PARTING_MS, "at the next contact, not after the reconnect grace")
	await _until(func() -> bool: return owl._partings.is_empty() and owl._closing.is_empty())


func test_the_other_seat_is_not_told_to_wait() -> void:
	assert_eq(server.start_local(0), OK)
	var owl := await _seated("Owl")
	var fox := await _local_client("Fox")
	var room_id := String(owl.state.room.id)
	assert_true(fox.command({"op": "join", "room": room_id}), fox.command_error)
	await _until(func() -> bool: return not fox.busy())
	await _until(func() -> bool: return not fox.state.room.is_empty())
	assert_eq(server._sessions.size(), 2, "control: two seats at the table")
	_blip(fox)
	fox.forget()
	await _until(func() -> bool: return server._sessions.size() == 1)
	assert_true(owl.online, "the host's own player plays on")


func test_a_seat_the_client_was_not_trying_to_get_back_is_not_abandoned() -> void:
	assert_eq(server.start_local(0), OK)
	var owl := await _seated("Owl")
	_blip(owl)
	# The host's last word, or a seat moved to another connection: no retry.
	owl._wanted = false
	owl.forget()
	assert_eq(owl._partings.size(), 0, "nothing is sent for a seat that is not this client's to give up")
	for i in 30: await get_tree().process_frame
	assert_eq(server._sessions.size(), 1, "the host keeps it for its grace, as before")


func test_a_parting_that_reaches_nobody_ends_quietly() -> void:
	assert_eq(server.start_local(0), OK)
	var owl := await _seated("Owl")
	_blip(owl)
	server.stop()
	owl.forget()
	assert_eq(owl._partings.size(), 1)
	owl._partings[0].until = Time.get_ticks_msec() + 300
	await _until(func() -> bool: return owl._partings.is_empty())
	assert_eq(owl.status, "Not connected", "and nothing is said about it")
	assert_false(owl.online)


func test_a_new_visit_is_not_disturbed_by_the_old_ones_parting() -> void:
	assert_eq(server.start_local(0), OK)
	var owl := await _seated("Owl")
	_blip(owl)
	# Straight into a new visit of the same host: the old seat is given up
	# and the new one stands.
	assert_eq(owl.connect_local(server.port, server.access_code, "Owl"), OK)
	assert_eq(owl._partings.size(), 1)
	await _until(func() -> bool: return owl.online and owl._partings.is_empty())
	await _until(func() -> bool: return server._sessions.size() == 1)
	assert_eq(server._rooms.size(), 0, "the old table went with the old seat")
	assert_true(owl.has_session(), "the new seat is the client's")
