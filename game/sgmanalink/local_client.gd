class_name SgLocalClient
extends Node
## [QoL] Data-only client. One outstanding command; memory-only seat resumption.
## Plain WS only on loopback; native LAN connections require a pinned TLS invite.

signal changed
signal refused(reason: String)
var mpn := MpnDownload.new()
const COMMAND_TIMEOUT_MS := 15000
## Connections a host may close on the hello, without a welcome or a reason,
## before this client stops retrying it (2026-10-03).
const UNANSWERED_LIMIT := 3
## [method command]'s refusal while the connection is down or a command
## is still in flight — never the seat's own mistake.
const NOT_CONNECTED := "Wait for the connection or the current action."
var state: Dictionary = {"rooms": [], "room": {}}
var status := "Not connected"
var command_error := ""
var online := false
var guest := ""
## THE HOST'S LAST WORD (gap review 2026-11-10, R4-1/R4-2): true once the
## host closed its tables or refused this seat for good (a fatal answer),
## when asking the same host again cannot bring the seat back. A view the
## host could not send (its own check, VIEW_REFUSED) is not final.
## Cleared by a new visit ([method forget]).
var host_final := false
var _socket: WebSocketPeer
var _port := 0
var _access := ""
var _resume := ""
var _nickname := ""
var _seq := 1
var _pending: Dictionary = {}
var _pending_wire := ""
var _pending_ack: Dictionary = {}
var _pending_started := 0
var _hello_sent := false
var _welcomed := false
var _wanted := false
var _retry_at := 0
var _backoff := 500
var _opened := 0
var _sent_at := 0
var _address := "127.0.0.1"
var _tls_options: TLSOptions
var build_fingerprint := SgCompatibility.fingerprint()
var build_stamp := SgCompatibility.stamp()
var _closing: Array = []
var _unavailable_since := 0
var _unanswered := 0


func connect_invitation(invitation: String, temporary_name := "") -> Error:
	if OS.has_feature("web"):
		return ERR_UNAVAILABLE
	var data := SgLanInvite.parse(invitation.strip_edges())
	var clean_name := temporary_name.strip_edges()
	if data.is_empty() or not SgProtocol.nickname(clean_name):
		return ERR_INVALID_PARAMETER
	var cert := SgLanInvite.certificate(data)
	if cert == null:
		return ERR_INVALID_PARAMETER
	forget()
	build_fingerprint = SgCompatibility.fingerprint()
	build_stamp = SgCompatibility.stamp()
	CardPacks.lock_catalogue(self)
	_address = data.address
	_port = int(data.port)
	_access = data.access
	_nickname = clean_name
	_tls_options = TLSOptions.client(cert, SgLanInvite.COMMON_NAME)
	_wanted = true
	return _connect()


func connect_local(local_port: int, code: String, temporary_name := "") -> Error:
	var clean_name := temporary_name.strip_edges()
	if local_port < 1 or local_port > 65535 or not SgProtocol.token(code) \
		or not SgProtocol.nickname(clean_name):
		return ERR_INVALID_PARAMETER
	forget()
	build_fingerprint = SgCompatibility.fingerprint()
	build_stamp = SgCompatibility.stamp()
	CardPacks.lock_catalogue(self)
	_port = local_port
	_access = code
	_nickname = clean_name
	_wanted = true
	return _connect()


## Where this client connects, or last tried to: `{address, port, access,
## tls}`, {} before any — kept after a refusal at the hello until
## [method forget]. The lobby's card transfer ([SgCardTransfer]) opens its
## own connection there.
func transfer_target() -> Dictionary:
	if _port == 0 or _access.is_empty():
		return {}
	return {"address": _address, "port": _port, "access": _access, "tls": _tls_options}


## Connect again to [param target] ([method transfer_target]) with a fresh
## build fingerprint: after the community cards came, the same host.
func connect_target(target: Dictionary, temporary_name := "") -> Error:
	var clean_name := temporary_name.strip_edges()
	if OS.has_feature("web") or not SgCardTransfer.valid_target(target) or not SgProtocol.nickname(clean_name):
		return ERR_INVALID_PARAMETER
	forget()
	build_fingerprint = SgCompatibility.fingerprint()
	build_stamp = SgCompatibility.stamp()
	CardPacks.lock_catalogue(self)
	_address = String(target.address)
	_port = int(target.port)
	_access = String(target.access)
	_tls_options = target.tls
	_nickname = clean_name
	_wanted = true
	return _connect()


func _connect() -> Error:
	_socket = WebSocketPeer.new()
	# Every earlier version too: an older host completes the handshake by
	# choosing its own, which names it (SgProtocol.subprotocols, 2026-10-03).
	_socket.supported_protocols = SgProtocol.subprotocols()
	_socket.inbound_buffer_size = SgProtocol.MAX_BYTES * 2
	_socket.outbound_buffer_size = 65536
	_socket.max_queued_packets = 64
	_socket.heartbeat_interval = 10.0
	_hello_sent = false
	_welcomed = false
	_opened = Time.get_ticks_msec()
	_pending_ack.clear()
	_pending_started = _opened
	if _unavailable_since == 0: _unavailable_since = Time.get_ticks_msec()
	status = "Connecting..." if Time.get_ticks_msec() - _unavailable_since < 5000 \
		else "Host unavailable. Check that it is running; reconnecting..."
	var scheme := "wss" if _tls_options != null else "ws"
	var result := _socket.connect_to_url("%s://%s:%d" % [scheme, _address, _port], _tls_options)
	# Publish a fully started attempt: a listener may immediately cancel it.
	changed.emit()
	return result


func forget() -> void:
	mpn.reset()
	CardPacks.unlock_catalogue(self)
	var was_wanted := _wanted
	_wanted = false
	_welcomed = false
	if _socket != null:
		# Welcomed is enough: the host knows the seat from the welcome on,
		# before the first table makes this client [member online].
		if (online or _welcomed_socket == _socket) and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_socket.send_text(SgProtocol.encode({"v": SgProtocol.VERSION, "type": "abandon"}))
			_socket.poll()
			_closing.append({"socket": _socket, "until": Time.get_ticks_msec() + 1000})
		else:
			_socket.close(-1)
			_part_offline(was_wanted)
	elif was_wanted:
		_part_offline(true)
	_socket = null
	_welcomed_socket = null
	_access = ""
	_resume = ""
	_nickname = ""
	_address = "127.0.0.1"
	_port = 0
	_tls_options = null
	guest = ""
	_pending = {}
	_pending_wire = ""
	_pending_ack.clear()
	command_error = ""
	_seq = 1
	online = false
	_backoff = 500
	_unavailable_since = 0
	_unanswered = 0
	host_final = false
	state = {"rooms": [], "room": {}}
	status = "Not connected"


## THE ABANDON REACHES THE HOST BEFORE THE SOCKET DIES (whole-project review
## 2026-11-21). [method forget] sends "abandon" and keeps the socket for
## [method poll] to close a second later — but a client leaving the tree
## (the SGManalink screen closed, the game quit) is never polled again: the
## socket died right behind the frame, the host read the two in one poll
## and dropped the connection before its packets, and the opponent waited
## out the whole reconnect grace over a duel already given up. The parting
## sockets are polled here until the host has closed them, at most
## [constant EXIT_DRAIN_MS] — as a host being freed waits for its guests
## ([constant SgLocalServer.CLOSING_WAIT_MS]). A host in this same process
## cannot answer while this waits, and is stopping with the screen anyway.
const EXIT_DRAIN_MS := 200


# --- campaign 2026-11-26: a seat given up while the connection is down ---
#
# A guest whose connection had dropped ("Connection lost; reconnecting...")
# and who then pressed Disconnect, or closed the screen, told the host
# nothing: [method forget] sent "abandon" only over an open, synchronized
# connection. The host kept the seat for its whole reconnect grace
# ([constant SgLocalServer.RECONNECT_GRACE_MS], 300 s) and the player left
# at the table was told to wait for someone who had gone.
#
# So the leaving is carried by a PARTING of its own: for a few seconds
# after such a Disconnect this client keeps trying the host — connect, the
# hello with the seat's resume code, "abandon" on the welcome, close —
# and then gives up quietly. The same messages an online guest's leaving
# sends, in the same order; nothing of the protocol changes. A guest whose
# network is really gone reaches nobody, and the host's grace is what it is
# for. Only a seat this client was still trying to get back is given up
# this way: one the host ended, refused, or handed to another connection
# is not this client's to abandon.

## How long a parting keeps trying the host, and how often.
const PARTING_MS := 4000
const PARTING_RETRY_MS := 400
## The partings under way: `{address, port, access, tls, resume, nickname,
## build, stamp, until, retry_at, socket, hello}`.
var _partings: Array = []
## The connection the host's welcome came over ([method forget]).
var _welcomed_socket: WebSocketPeer = null


func _part_offline(was_wanted: bool) -> void:
	if not was_wanted or _resume.is_empty() or _port == 0 or host_final:
		return
	_partings.append({"address": _address, "port": _port, "access": _access,
		"tls": _tls_options, "resume": _resume, "nickname": _nickname,
		"build": build_fingerprint, "stamp": build_stamp,
		"until": Time.get_ticks_msec() + PARTING_MS, "retry_at": 0,
		"socket": null, "hello": false})


## One step of every parting. Nothing here waits.
func _serve_partings() -> void:
	for parting: Dictionary in _partings.duplicate():
		if _serve_parting(parting):
			if parting.socket != null: (parting.socket as WebSocketPeer).close(-1)
			_partings.erase(parting)


## True when [param parting] is over: the abandon is on its way (its
## socket then waits among [member _closing]), the host answered something
## else, or its time is up.
func _serve_parting(parting: Dictionary) -> bool:
	var now := Time.get_ticks_msec()
	if now >= int(parting.until):
		return true
	var socket: WebSocketPeer = parting.socket
	if socket == null:
		if now < int(parting.retry_at):
			return false
		parting.retry_at = now + PARTING_RETRY_MS
		socket = WebSocketPeer.new()
		socket.supported_protocols = SgProtocol.subprotocols()
		socket.inbound_buffer_size = SgProtocol.MAX_BYTES * 2
		socket.outbound_buffer_size = 65536
		socket.max_queued_packets = 64
		parting.hello = false
		var scheme := "wss" if parting.tls != null else "ws"
		if socket.connect_to_url("%s://%s:%d" % [scheme, parting.address, int(parting.port)], parting.tls) != OK:
			return false
		parting.socket = socket
		return false
	socket.poll()
	var connection := socket.get_ready_state()
	if connection == WebSocketPeer.STATE_CLOSED:
		# Not reached, or hung up on: again in a moment, while there is time.
		parting.socket = null
		return bool(parting.hello)   # a host that closed on the hello has answered
	if connection != WebSocketPeer.STATE_OPEN:
		return false
	if socket.get_selected_protocol() != SgProtocol.SUBPROTOCOL:
		return true
	if not parting.hello:
		socket.send_text(SgProtocol.encode({"v": SgProtocol.VERSION,
			"type": "hello", "access": parting.access, "resume": parting.resume,
			"nickname": parting.nickname, "build": parting.build, "stamp": parting.stamp}))
		parting.hello = true
		return false
	if socket.get_available_packet_count() == 0:
		return false
	var packet := socket.get_packet()
	var message := SgProtocol.decode_payload(packet) if socket.was_string_packet() else {}
	# Anything but the welcome of this build's host is no seat to give up.
	if not SgViewProtocol.valid(message) or message.get("type") != "welcome" \
			or message.get("v") != SgProtocol.VERSION or message.get("build") != parting.build:
		return true
	socket.send_text(SgProtocol.encode({"v": SgProtocol.VERSION, "type": "abandon"}))
	socket.poll()
	_closing.append({"socket": socket, "until": now + 1000})
	parting.socket = null
	return true
# --- end campaign 2026-11-26 ---


func _exit_tree() -> void:
	var here := SgLocalServer.hosts_port(_port)
	forget()
	if not here:
		drain()


## Poll the connections [method forget] parted from until their host has
## closed each, or [param limit_ms] pass. [param between] runs between two
## polls in place of the short sleep (a test's host in this process).
func drain(limit_ms := EXIT_DRAIN_MS, between := Callable()) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not _closing.is_empty() or not _partings.is_empty():
		_serve_partings()
		for closing in _closing.duplicate():
			closing.socket.poll()
			if closing.socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
				closing.socket.close(-1)
				_closing.erase(closing)
		if (_closing.is_empty() and _partings.is_empty()) or Time.get_ticks_msec() >= deadline:
			break
		if between.is_valid(): between.call()
		else: OS.delay_msec(5)


func busy() -> bool:
	return not _pending.is_empty()


func has_session() -> bool:
	return not _resume.is_empty()


func connecting() -> bool:
	return _wanted and not online


## A seat and no connection, and no retry under way: the host ended it, or
## this client stopped on an answer it cannot use ([member status] says
## which). Only Reconnect or Disconnect move it on (gap review 2026-11-10,
## R4-1).
func stopped() -> bool:
	return has_session() and not _wanted and not online


func reconnect() -> void:
	# A host that closed its tables or refused this seat for good is not
	# asked again: its answer stays on screen (R4-1).
	if _port == 0 or not has_session() or host_final:
		return
	if _socket != null:
		_socket.close(-1)
	online = false
	_wanted = true
	_retry_at = 0
	_unanswered = 0
	_connect()


func command(action: Dictionary) -> bool:
	command_error = NOT_CONNECTED
	if not online or busy() or _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	var message := {"v": SgProtocol.VERSION, "type": "command", "seq": _seq,
		"room": String(state.room.get("id", "")),
		"revision": int(state.room.get("revision", 0)), "action": action.duplicate(true)}
	if String(action.get("op", "")).begins_with("t_"):
		message.revision = int(state.get("tournament", {}).get("revision", 0))
	if action.get("op", "") == "t_ready":
		var event: Dictionary = state.get("tournament", {})
		var rounds: Array = event.get("rounds", [])
		var game_number := 0
		if not rounds.is_empty():
			for pair: Dictionary in rounds.back():
				if int(pair.players[0]) == int(event.get("you", 0)) or int(pair.players[1]) == int(event.get("you", 0)):
					game_number = int(pair.game)
		message.action["round"] = action.get("round", rounds.size())
		message.action["game"] = action.get("game", game_number)
	if not SgProtocol.valid(message):
		command_error = "This action is not supported."
		return false
	var wire := SgProtocol.encode(message)
	if wire.length() > SgProtocol.MAX_COMMAND_BYTES:
		command_error = "This action is too large to send. Reduce the number of selected cards."
		return false
	command_error = ""
	_pending = message
	_pending_wire = wire
	_pending_ack.clear()
	_pending_started = Time.get_ticks_msec()
	_seq += 1
	_send_pending()
	changed.emit()
	return true


func _send_pending() -> void:
	if not _pending.is_empty() and _socket != null \
		and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if _socket.send_text(_pending_wire) != OK:
			_socket.close(-1)
		_sent_at = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	poll()


func poll() -> void:
	if mpn.active:
		if not online or _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
			mpn.abort("MPN download interrupted. Reconnect and try Export MPN again before leaving the table.")
		else:
			var request := mpn.next(Time.get_ticks_msec())
			if not request.is_empty(): _socket.send_text(SgProtocol.encode(request))
	_serve_partings()
	for closing in _closing.duplicate():
		closing.socket.poll()
		if closing.socket.get_ready_state() == WebSocketPeer.STATE_CLOSED or Time.get_ticks_msec() >= int(closing.until):
			closing.socket.close(-1)
			_closing.erase(closing)
	if not _wanted or _socket == null:
		return
	var now := Time.get_ticks_msec()
	var polled_socket := _socket
	_socket.poll()
	var connection := _socket.get_ready_state()
	if connection == WebSocketPeer.STATE_CLOSED:
		# THE HOST CLOSED (robustness campaign 2026-10-12): its own close
		# code, read even when its fatal message was dropped unread with the
		# connection in this one poll. Nothing to come back to: no retry.
		if _socket.get_close_code() == SgLocalServer.HOST_CLOSED_CODE:
			_wanted = false
			online = false
			host_final = true
			status = SgLocalServer.HOST_CLOSED
			changed.emit()
			return
		if _socket.get_close_code() == 4001:
			_wanted = false
			online = false
			status = "This seat was resumed in another connection."
			changed.emit()
			return
		# A HOST THAT HANGS UP ON THE HELLO (2026-10-03), with neither a
		# welcome nor a reason, is no host this build can talk to — an
		# earlier build drops a hello it cannot read. A few tries, then say so.
		if _hello_sent and not _welcomed:
			_hello_sent = false
			_unanswered += 1
			if _unanswered >= UNANSWERED_LIMIT:
				_wanted = false
				online = false
				status = "The host closed the connection without answering. It may run a different version of Shandalar; both players need the same version."
				changed.emit()
				return
		if online:
			online = false
			status = "Connection lost; reconnecting..."
			_retry_at = now + _backoff
			changed.emit()
			if not _wanted or _socket != polled_socket: return
		elif now - _opened > 5000:
			status = "Host unavailable. Check that it is running; reconnecting..."
		if now >= _retry_at:
			_retry_at = now + _backoff
			_backoff = mini(_backoff * 2, 8000)
			_connect()
		return
	# A CLOSING CONNECTION IS OFFLINE (gap review 2026-11-10, R4-3): it
	# takes no command ([method command]), and while [member online] stayed
	# set a table's automatic pass was refused on the spot and re-driven in
	# the same frame without end. Lost from here; the CLOSED poll that
	# follows reads its close code and retries as for any lost connection.
	if connection == WebSocketPeer.STATE_CLOSING:
		if online:
			online = false
			status = "Connection lost; reconnecting..."
			_retry_at = now + _backoff
			# The CLOSED poll reads the same loss, not a host that never answered.
			_opened = now
			changed.emit()
		elif now - _opened > 5000:
			# A close that never completes is cut; the CLOSED poll retries.
			_socket.close(-1)
		return
	if not online and now - _opened > 5000:
		_socket.close(-1)
		status = "Cannot join. Check the host, invitation, firewall and computer clocks."
		changed.emit()
		return
	if connection != WebSocketPeer.STATE_OPEN:
		return
	# The host chose an earlier version's handshake: it is that version.
	if _socket.get_selected_protocol() != SgProtocol.SUBPROTOCOL:
		var theirs := SgProtocol.subprotocol_version(_socket.get_selected_protocol())
		_wanted = false
		online = false
		status = SgCompatibility.protocol_difference(SgProtocol.VERSION, theirs) if theirs > 0 \
			else "Host sent an invalid response. Connection stopped."
		_socket.close(-1)
		changed.emit()
		return
	if not _hello_sent:
		_socket.send_text(SgProtocol.encode({"v": SgProtocol.VERSION,
			"type": "hello", "access": _access, "resume": _resume, "nickname": _nickname, "build": build_fingerprint,
			"stamp": build_stamp}))
		_hello_sent = true
	for i in 32:
		if _socket.get_available_packet_count() == 0:
			break
		var packet := _socket.get_packet()
		var message := SgProtocol.decode_payload(packet) if _socket.was_string_packet() else {}
		if not SgViewProtocol.valid(message) or (not _welcomed and message.get("type") not in ["welcome", "fatal"]) \
			or (_welcomed and message.get("type") == "welcome") \
			or (_welcomed and not online and message.get("type") not in ["state", "fatal"]):
			_wanted = false
			online = false
			status = "Host sent an invalid response. Connection stopped."
			_socket.close(-1)
			changed.emit()
			return
		match message.get("type", ""):
			"mpn":
				mpn.receive(message)
				continue
			"welcome":
				if message.build != build_fingerprint:
					_wanted = false
					online = false
					status = "Incompatible game builds or card packs. Use the same build and enabled packs as the host."
					_socket.close(-1)
					changed.emit()
					return
				if message.get("v") != SgProtocol.VERSION or not SgProtocol.token(message.get("resume")):
					_socket.close(-1)
					return
				_resume = message.resume
				guest = message.guest
				_seq = maxi(_seq, int(message.seq) + 1)
				_welcomed = true
				_welcomed_socket = _socket
				_unanswered = 0
				status = "Synchronizing with host..."
			"state":
				if not message.get("rooms") is Array or not message.get("room") is Dictionary:
					_socket.close(-1)
					return
				state = message
				if not _pending_ack.is_empty():
					var acknowledgement := _pending_ack.duplicate()
					_pending.clear()
					_pending_wire = ""
					_pending_ack.clear()
					if not acknowledgement.ok:
						refused.emit(acknowledgement.error)
						# A refusal listener may leave the visit or start another one.
						# Never revive that forgotten state or continue on its socket.
						if not _wanted or _socket != polled_socket: return
				if not online:
					# A welcome authenticates this connection, not the cached room
					# revision. Enable input only after its first fresh snapshot.
					online = true
					_unavailable_since = 0
					_backoff = 500
					status = "Connected - %s playtest (unrated)" % ("encrypted LAN" if _tls_options != null else "local")
					_send_pending()
			"ack":
				if not _pending.is_empty() and message.get("seq") == _pending.seq:
					# Keep input locked until a following state reflects this result.
					# The host sends acknowledgements before publishing snapshots.
					_pending_ack = message
			"fatal":
				_wanted = false
				online = false
				status = message.error
				if has_session() and message.error != SgLocalServer.VIEW_REFUSED: host_final = true
				# A seat resumed at a host that restarted: an older host
				# answers its stale access code "Invalid invitation" — the
				# seat is gone, and the guest is told so (2026-10-12).
				if has_session() and message.error == SgLocalServer.INVALID_INVITATION:
					status = SgLocalServer.HOST_RESTARTED
				_socket.close(-1)
			_: _socket.close(-1)
		changed.emit()
		if not _wanted or _socket != polled_socket: return
	if online and busy():
		if now - _pending_started >= COMMAND_TIMEOUT_MS:
			_socket.close(-1)
			online = false
			_retry_at = now + _backoff
			status = "Host response stalled; reconnecting to recover this action..."
			changed.emit()
		elif now - _sent_at > 2000: _send_pending()
