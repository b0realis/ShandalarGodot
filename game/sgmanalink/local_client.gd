class_name SgLocalClient
extends Node
## [QoL] Data-only client. One outstanding command; memory-only seat resumption.
## Plain WS only on loopback; native LAN connections require a pinned TLS invite.

signal changed
signal refused(reason: String)
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
	CardPacks.unlock_catalogue(self)
	_wanted = false
	_welcomed = false
	if _socket != null:
		if online and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_socket.send_text(SgProtocol.encode({"v": SgProtocol.VERSION, "type": "abandon"}))
			_socket.poll()
			_closing.append({"socket": _socket, "until": Time.get_ticks_msec() + 1000})
		else: _socket.close(-1)
	_socket = null
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
	state = {"rooms": [], "room": {}}
	status = "Not connected"


func _exit_tree() -> void:
	forget()


func busy() -> bool:
	return not _pending.is_empty()


func has_session() -> bool:
	return not _resume.is_empty()


func connecting() -> bool:
	return _wanted and not online


func reconnect() -> void:
	if _port == 0 or not has_session():
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
