extends GutTest
## THE HOST UNDER HOSTILE CONDITIONS (robustness campaign 2026-10-12, f-net).
## Real sockets on the loopback (127.0.0.1); a discovery socket on a private
## test port, never the shipped 17897/17898.
##
## r4-4  A HOST THAT CLOSES TELLS ITS GUESTS. `stop()` (the lobby's Close or
##       Disconnect, `referee --host` after its result) cut every socket
##       without a word, and a seated guest cycled "Connection lost;
##       reconnecting…" / "Host unavailable…" forever over the finished
##       duel. The host now says "The host closed its tables." — a fatal
##       message, then a close frame with its own code, which a guest reads
##       even when both land in one poll. A guest resuming at a host that
##       restarted reads "The host restarted; this seat is gone…" instead of
##       "Invalid invitation" — from this host, and from an older one that
##       still answers "Invalid invitation" (the client names it itself).
## r4-5  A HANDSHAKE IS CHECKED BEFORE IT IS POLLED. Godot's socket printed
##       an error on every poll of a connection whose upgrade headers had
##       filled its 4 KB buffer (no invitation needed, plain or TLS port):
##       thousands of lines in seconds. Such a peer is now let go before
##       that poll, quietly; a handshake has 1.5 s of the host's own polling
##       (a host that stalls drops nobody), and one address holds at most
##       PENDING_PER_ADDRESS unfinished connections. (Godot's own single
##       line for a failed TLS handshake or a request without upgrade
##       headers is the engine's, once per connection, and is not tested
##       here: a gate run fails on any ERROR line.)
## r4-6  A UDP FLOOD AT DISCOVERY COSTS LITTLE: drained to empty within a
##       byte budget, oversized and non-JSON packets skipped before any
##       decoding, and a receive buffer that never overflows with a
##       warning per packet.

var server: SgLocalServer
var a: SgLocalClient
var b: SgLocalClient
var extra: Array = []


func before_each() -> void:
	server = SgLocalServer.new()
	add_child_autofree(server)
	a = SgLocalClient.new()
	b = SgLocalClient.new()
	add_child_autofree(a)
	add_child_autofree(b)
	extra.clear()


func after_each() -> void:
	for peer in extra:
		if peer is StreamPeerTCP: peer.disconnect_from_host()
		elif peer is StreamPeerTLS: peer.disconnect_from_stream()
		elif peer is WebSocketPeer: peer.close(-1)
		elif peer is PacketPeerUDP: peer.close()
		elif peer is SgLocalServer: peer.stop()
	extra.clear()
	a.forget()
	b.forget()
	server.stop()
	await get_tree().process_frame


func _until(predicate: Callable, seconds := 10.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await get_tree().process_frame
	return false


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _act(client: SgLocalClient, action: Dictionary) -> void:
	assert_true(client.command(action), "command accepted: " + str(action))
	await _until(func() -> bool: return not client.busy())
	await _frames(3)


func _duel() -> void:
	await _until(func() -> bool: return a.online and b.online)
	assert_true(a.online and b.online, "both seats online")
	await _act(a, {"op": "host", "name": "Probe room", "decks": "own", "deck": {}})
	await _act(b, {"op": "join", "room": a.state.room.id})
	await _act(a, {"op": "ready", "value": true})
	await _act(b, {"op": "ready", "value": true})
	await _until(func() -> bool: return not a.state.room.game.is_empty() and not b.state.room.game.is_empty())
	assert_false(b.state.room.game.is_empty(), "the duel runs")


## The host stops in mid-duel: both seats are told, and stop retrying.
func test_a_closing_host_tells_its_seated_guests() -> void:
	assert_eq(server.start_local(0), OK)
	assert_eq(a.connect_local(server.port, server.access_code, "Ann"), OK)
	assert_eq(b.connect_local(server.port, server.access_code, "Bo"), OK)
	await _duel()
	var seen := {}
	server.stop()
	await _until(func() -> bool:
		seen[b.status] = true
		return not b._wanted and not a._wanted, 5.0)
	assert_eq(b.status, SgLocalServer.HOST_CLOSED, "the guest reads why (saw %s)" % str(seen.keys()))
	assert_eq(a.status, SgLocalServer.HOST_CLOSED)
	assert_false(b._wanted, "the guest stops retrying")
	assert_false(seen.has("Connection lost; reconnecting..."), "never 'reconnecting' (saw %s)" % str(seen.keys()))
	assert_false(b.state.room.is_empty(), "the finished table stays on the guest's screen")


## The same over the encrypted LAN port, a guest in the lobby.
func test_a_closing_lan_host_tells_its_guest() -> void:
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)
	assert_eq(b.connect_invitation(server.invitation(), "Bo"), OK)
	assert_true(await _until(func() -> bool: return b.online), "the guest is in")
	server.stop()
	assert_true(await _until(func() -> bool: return not b._wanted, 5.0), "the guest stops retrying (%s)" % b.status)
	assert_eq(b.status, SgLocalServer.HOST_CLOSED)


## A guest that reads its socket only after the host has gone still reads
## why: the fatal message and the close frame arrive in one poll.
func test_the_reason_survives_one_late_poll() -> void:
	assert_eq(server.start_local(0), OK)
	assert_eq(b.connect_local(server.port, server.access_code, "Bo"), OK)
	assert_true(await _until(func() -> bool: return b.online), "the guest is in")
	b.set_process(false)
	server.stop()
	await _frames(5)
	OS.delay_msec(50)
	b.poll()
	b.poll()
	assert_eq(b.status, SgLocalServer.HOST_CLOSED)
	assert_false(b._wanted)


## Crashed, not closed: no word; the guest retries, as it should. When the
## host comes back with a fresh invitation, the old seat's resume is told
## the seat is gone — not "Invalid invitation".
func test_a_restarted_host_names_the_lost_seat() -> void:
	assert_eq(server.start_local(0), OK)
	var port := server.port
	assert_eq(b.connect_local(port, server.access_code, "Bo"), OK)
	assert_true(await _until(func() -> bool: return b.online), "the guest is in")
	_crash(server)
	assert_true(await _until(func() -> bool: return not b.online, 5.0))
	assert_true(b._wanted, "a crashed host is retried")
	var again := SgLocalServer.new()
	add_child_autofree(again)
	extra.append(again)
	assert_eq(again.start_local(port), OK)
	assert_true(await _until(func() -> bool: return not b._wanted, 15.0), "the guest stops (%s)" % b.status)
	assert_eq(b.status, SgLocalServer.HOST_RESTARTED)


## An older host still answers a stale resume "Invalid invitation": the
## client names the lost seat itself.
func test_an_older_hosts_invalid_invitation_reads_as_the_lost_seat() -> void:
	assert_eq(server.start_local(0), OK)
	var port := server.port
	assert_eq(b.connect_local(port, server.access_code, "Bo"), OK)
	assert_true(await _until(func() -> bool: return b.online), "the guest is in")
	_crash(server)
	assert_true(await _until(func() -> bool: return not b.online, 5.0))
	var older := OlderHost.new()
	add_child_autofree(older)
	extra.append(older)
	assert_eq(older.start_local(port), OK)
	assert_true(await _until(func() -> bool: return not b._wanted, 15.0), "the guest stops (%s)" % b.status)
	assert_eq(b.status, SgLocalServer.HOST_RESTARTED)


## A fresh guest with a wrong code is still told its invitation is invalid.
func test_a_wrong_invitation_is_still_invalid() -> void:
	assert_eq(server.start_local(0), OK)
	assert_eq(b.connect_local(server.port, "0".repeat(64), "Bo"), OK)
	assert_true(await _until(func() -> bool: return not b._wanted, 10.0), "the guest stops (%s)" % b.status)
	assert_eq(b.status, SgLocalServer.INVALID_INVITATION)


## What a killed process leaves: sockets gone without a word, the port free.
func _crash(host: SgLocalServer) -> void:
	for peer: Dictionary in host._peers.values():
		peer.socket.close(-1)
	host._peers.clear()
	host._sessions.clear()
	host._tokens.clear()
	host._rooms.clear()
	host._listener.stop()
	host.set_process(false)


## A host from before this campaign: a hello with the wrong code is
## "Invalid invitation", whatever it resumes.
class OlderHost extends SgLocalServer:
	func _receive(id: int, message: Dictionary) -> void:
		if int(_peers[id].session) == 0 and SgProtocol.literal(message.get("type"), "hello") \
				and not SgProtocol.literal(message.get("access"), access_code):
			_reject(id, SgLocalServer.INVALID_INVITATION)
			return
		super._receive(id, message)


func _tcp(port: int) -> StreamPeerTCP:
	var socket := StreamPeerTCP.new()
	socket.connect_to_host("127.0.0.1", port)
	extra.append(socket)
	return socket


func _engine_errors(label: String) -> int:
	var count := 0
	for e in get_errors():
		gut.p("%s: engine said %s %s" % [label, e.code, String(e.rationale).left(160)])
		e.handled = true
		count += 1
	return count


func test_oversized_upgrade_headers_are_shed_quietly() -> void:
	assert_eq(server.start_local(0), OK)
	var junk := ("GET / HTTP/1.1\r\nX-Pad: " + "a".repeat(4200)).to_ascii_buffer()
	var rows: Array = []
	for i in 3: rows.append([_tcp(server.port), false])
	var started := Time.get_ticks_msec()
	var shed := {"at": -1}
	await _until(func() -> bool:
		for row in rows:
			var socket: StreamPeerTCP = row[0]
			socket.poll()
			if not row[1] and socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				socket.put_data(junk)
				row[1] = true
		if int(shed.at) < 0 and rows.all(func(row: Array) -> bool: return row[1]) and server._peers.is_empty():
			shed.at = Time.get_ticks_msec() - started
		return int(shed.at) >= 0, 5.0)
	assert_between(int(shed.at), 0, 1000, "shed at once (%d ms)" % int(shed.at))
	assert_eq(_engine_errors("plain oversized"), 0, "nothing printed on the host")
	assert_eq(a.connect_local(server.port, server.access_code, "Ann"), OK)
	assert_true(await _until(func() -> bool: return a.online), "a guest still joins")


func test_tls_then_oversized_upgrade_headers_are_shed_quietly() -> void:
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)
	var junk := ("GET / HTTP/1.1\r\nX-Pad: " + "a".repeat(4200)).to_ascii_buffer()
	var rows: Array = []
	for i in 2:
		var tls := StreamPeerTLS.new()
		extra.append(tls)
		rows.append([_tcp(server.port), tls, 0])
	await _until(func() -> bool:
		for row in rows:
			var tcp: StreamPeerTCP = row[0]
			var tls: StreamPeerTLS = row[1]
			tcp.poll()
			if row[2] == 0 and tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				tls.connect_to_stream(tcp, SgLanInvite.COMMON_NAME, TLSOptions.client(server.lan_certificate, SgLanInvite.COMMON_NAME))
				row[2] = 1
			elif row[2] == 1:
				# Polled only while it is still ours to talk on: a client
				# polling a stream the host has already shed makes Godot
				# print "status != STATUS_CONNECTED" — the CLIENT's line,
				# which this test would then count against the host (the
				# gate's four shards made that ordering happen, 2026-10-12).
				var status := tls.get_status()
				if status == StreamPeerTLS.STATUS_HANDSHAKING or status == StreamPeerTLS.STATUS_CONNECTED:
					tls.poll()
				if tls.get_status() == StreamPeerTLS.STATUS_CONNECTED:
					tls.put_data(junk)
					row[2] = 2
		return rows.all(func(row: Array) -> bool: return row[2] == 2) and server._peers.is_empty(), 5.0)
	assert_true(rows.all(func(row: Array) -> bool: return row[2] == 2), "both sent their headers")
	assert_eq(server._peers.size(), 0, "both shed")
	await _frames(10)
	assert_eq(_engine_errors("TLS oversized"), 0, "nothing printed on the host")
	assert_eq(b.connect_invitation(server.invitation(), "Bo"), OK)
	assert_true(await _until(func() -> bool: return b.online), "an invited guest still joins")


## A connection that never finishes its handshake goes after 1.5 s of the
## host's polling — and a host that stalls for seconds drops nobody.
func test_an_unfinished_handshake_has_the_hosts_polling_time() -> void:
	assert_eq(server.start_local(0), OK)
	server.set_process(false)
	var silent := _tcp(server.port)
	var partial := _tcp(server.port)
	assert_true(await _until(func() -> bool:
		silent.poll()
		partial.poll()
		server.poll()
		return server._peers.size() == 2), "both accepted")
	partial.put_data("GET / HTTP/1.1\r\nHost: 127.0.0.1\r\n".to_ascii_buffer())
	OS.delay_msec(SgLocalServer.HELLO_MS + 500)   # the host stalls past every cutoff
	server.poll()
	assert_eq(server._peers.size(), 2, "a stall is not the guest's time")
	var started := Time.get_ticks_msec()
	await _until(func() -> bool:
		server.poll()
		return server._peers.is_empty(), 5.0)
	var took := Time.get_ticks_msec() - started
	assert_true(server._peers.is_empty(), "dropped")
	assert_between(took, SgLocalServer.HANDSHAKE_MS - 300, SgLocalServer.HELLO_MS - 500, "after the handshake time (%d ms)" % took)
	assert_eq(_engine_errors("unfinished"), 0)


func test_one_address_holds_a_bounded_number_of_unfinished_connections() -> void:
	assert_eq(server.start_local(0), OK)
	var seen := {"most": 0, "opened": 0}
	# A few at a time (the listen backlog is short): all within a second.
	await _until(func() -> bool:
		if int(seen.opened) < SgLocalServer.PENDING_PER_ADDRESS + 12:
			for i in 4: _tcp(server.port)
			seen.opened = int(seen.opened) + 4
		for socket in extra: if socket is StreamPeerTCP: socket.poll()
		seen.most = maxi(int(seen.most), server._pending_from("127.0.0.1"))
		return false, 1.0)
	var most := int(seen.most)
	assert_eq(most, SgLocalServer.PENDING_PER_ADDRESS, "unfinished connections from one address, at most (%d)" % most)
	# Once they have had their time, a guest from the same address is in.
	await _until(func() -> bool: return server._peers.is_empty(), 4.0)
	assert_eq(a.connect_local(server.port, server.access_code, "Ann"), OK)
	assert_true(await _until(func() -> bool: return a.online), "a guest joins")
	assert_eq(_engine_errors("pending cap"), 0)


func test_a_udp_flood_at_discovery_costs_little() -> void:
	var discovery_port := 47891
	assert_eq(server.start_lan("127.0.0.1", 0, true, "Probe", discovery_port, false), OK)
	assert_not_null(server.discovery)
	server.discovery.set_process(false)
	var flood := PacketPeerUDP.new()
	extra.append(flood)
	flood.set_dest_address("127.0.0.1", discovery_port)
	var junk := ("{\"v\":1,\"type\":\"" + "a".repeat(16000) + "\"}").to_ascii_buffer()
	var binary := PackedByteArray()
	binary.resize(8000)
	var worst := 0.0
	var total := 0.0
	var pumps := 0
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until:
		for i in 40: flood.put_packet(junk)
		flood.put_packet(binary)
		var began := Time.get_ticks_usec()
		server.discovery.pump()
		var spent := (Time.get_ticks_usec() - began) / 1000.0
		worst = maxf(worst, spent)
		total += spent
		pumps += 1
		await get_tree().process_frame
	gut.p("discovery flood: %d pumps, worst %.2f ms, mean %.2f ms" % [pumps, worst, total / maxi(1, pumps)])
	assert_lt(worst, 8.0, "one pump under a flood stays well inside a frame")
	var dropped := 0
	for e in get_errors():
		if String(e.rationale + " " + e.code).contains("Buffer full"): dropped += 1
		e.handled = true
	assert_eq(dropped, 0, "no packet dropped with a warning each")
	# A real query is still answered.
	var asker := PacketPeerUDP.new()
	extra.append(asker)
	assert_eq(asker.bind(0, "127.0.0.1"), OK)
	asker.set_dest_address("127.0.0.1", discovery_port)
	asker.put_packet(SgProtocol.encode({"v": SgProtocol.VERSION, "type": "sg-lan-query", "nonce": "ab".repeat(32)}).to_ascii_buffer())
	assert_true(await _until(func() -> bool:
		server.discovery.pump()
		return asker.get_available_packet_count() > 0, 3.0), "the query is answered")
