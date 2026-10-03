class_name SgLanDiscovery
extends Node
## [QoL] Explicit, bounded IPv4 LAN discovery. UDP announcements are UNTRUSTED.
## Broadcast queries + unicast replies; no accounts or directory. Desktop only.
## Joining always uses a certificate-pinned invitation. THE OPEN TABLE
## (2026-09-18): an OPEN host publishes that invitation in its own advert, by
## design — anyone on the LAN may sit down, so the Game Browser's Join button
## connects without a paste. An INVITATION-ONLY host advertises its name and
## tables but never the access secret or the certificate; its guests paste
## the invitation the host handed them. Either way the browser learns each
## table's duel name and deck rule, so a player picks a table, not a host.

signal changed
const PORT := 17898
## An open advert carries the invitation (up to SgLanInvite.MAX_LENGTH) and
## up to twenty table rows; well inside one UDP datagram, fragmented or not
## on a LAN. [method update_tables] drops the last rows of an advert that
## would not fit — a receiver discards a bigger packet unread.
const MAX_PACKET := 16384
const ACCESS := ["open", "invitation"]
const MAX_HOSTS := 64
## One address can list a few hosts (a development machine runs two), never
## the whole table: a reply names its own port, so one LAN peer answering
## with sixty-four ports would otherwise hide every real host (2026-10-02).
const MAX_HOSTS_PER_ADDRESS := 4
const EXPIRES_MS := 7000
var hosts: Dictionary = {}
## Hosts of another protocol version (2026-10-03), listed so the browser
## can say so instead of hiding them: {"host": {address, port, name,
## protocol, game}, "seen"}. Never joinable; never in [member hosts].
var others: Dictionary = {}
var scanning := false
var advertising := false
var status := ""
var _socket := PacketPeerUDP.new()
var _advert: Dictionary = {}
var _nonce := ""
var _next_query := 0
var _reply_window := 0
var _replies := 0


func scan() -> Error:
	if OS.has_feature("web") or advertising:
		return ERR_UNAVAILABLE
	stop()
	var error := _bind_broadcast(0)
	if error != OK:
		return error
	_nonce = Crypto.new().generate_random_bytes(32).hex_encode()
	scanning = true
	status = "Looking for LAN hosts..."
	query()
	return OK


func advertise(advert: Dictionary, discovery_port := PORT) -> Error:
	if OS.has_feature("web") or not valid_advert(advert):
		return ERR_INVALID_PARAMETER
	stop()
	var error := _bind_broadcast(discovery_port)
	if error != OK:
		status = "LAN discovery port is busy; share the invitation to join directly."
		return error
	_advert = advert.duplicate(true)
	advertising = true
	return OK


## Bind the discovery socket with broadcast ON — for BOTH ends (2026-10-03).
## On Android, Godot's runtime takes the Wi-Fi multicast lock (without it
## the Wi-Fi drops broadcast packets) only for a socket with broadcast
## enabled and only under CHANGE_WIFI_MULTICAST_STATE (the Android Quest
## preset asks for it); the host's socket RECEIVES the Game Browsers'
## broadcast queries, so it needs the lock as much as the scanner does.
func _bind_broadcast(port: int) -> Error:
	var error := _socket.bind(port, "0.0.0.0", 65536)
	if error == OK:
		_socket.set_broadcast_enabled(true)
	return error


func update_rooms(count: int) -> void:
	if advertising:
		_advert.rooms = clampi(count, 0, SgLocalServer.MAX_ROOMS)


## The tables of the host as the browser lists them: `name`, `decks` ("own"
## or "fixed"), `deck` (the assigned deck's name, "" for bring-your-own),
## `open` (a seat is free) and `rules` (the table's one-line rules readout,
## SgTableRules.brief). Rows that fail the advert check are dropped.
func update_tables(tables: Array) -> void:
	if not advertising: return
	var rows: Array = []
	for row in tables:
		if rows.size() >= SgLocalServer.MAX_ROOMS: break
		if valid_table(row): rows.append(row.duplicate(true))
	_advert.tables = rows
	# The reply must fit MAX_PACKET on the wire, where every character past
	# ASCII is six bytes: twenty tables with long non-Latin deck names were
	# a 20 KB advert no browser ever showed (2026-10-02). The last rows go.
	while not rows.is_empty() and reply_size() > MAX_PACKET:
		rows.pop_back()


## The byte count of this advert's reply to a query, as [method poll] sends it.
func reply_size() -> int:
	return SgProtocol.encode({"v": SgProtocol.VERSION, "type": "sg-lan-host",
		"nonce": "0".repeat(64), "host": _advert}).length()


static func valid_table(row: Variant) -> bool:
	if not row is Dictionary: return false
	# The rules readout is optional, like the room view's: a row without
	# one is a standard table.
	var fields := ["name", "decks", "deck", "open"]
	if row.has("rules"):
		fields.append("rules")
		if not SgViewProtocol.text(row.rules, 64): return false
	return SgProtocol.exact(row, fields) \
		and SgProtocol.short_text(row.name) and row.decks in SgProtocol.DECK_RULES \
		and SgViewProtocol.text(row.deck, 128) and row.open is bool


func update_tournament(tournament_name: String) -> void:
	if not advertising: return
	if tournament_name.is_empty(): _advert.erase("tournament")
	elif SgProtocol.short_text(tournament_name): _advert.tournament = tournament_name


func stop() -> void:
	_socket.close()
	hosts.clear()
	others.clear()
	scanning = false
	advertising = false
	_advert = {}
	_nonce = ""
	_next_query = 0
	_replies = 0
	_reply_window = 0


func _exit_tree() -> void:
	stop()


func query(destination := "255.255.255.255", discovery_port := PORT) -> void:
	if not scanning or (destination != "255.255.255.255" and not SgLanInvite.address(destination)):
		return
	var packet := SgProtocol.encode({"v": SgProtocol.VERSION, "type": "sg-lan-query", "nonce": _nonce})
	if _socket.set_dest_address(destination, discovery_port) == OK:
		_socket.put_packet(packet.to_ascii_buffer())
	_next_query = Time.get_ticks_msec() + 2000


static func valid_advert(data: Dictionary) -> bool:
	var fields := ["address", "port", "name", "fingerprint", "rooms", "build", "stamp", "access", "tables"]
	if data.has("tournament"):
		fields.append("tournament")
		if not SgProtocol.short_text(data.tournament): return false
	if data.has("invitation"): fields.append("invitation")
	if not SgProtocol.exact(data, fields) \
		or not SgLanInvite.address(data.get("address")) \
		or not SgProtocol.integer(data.get("port"), 1, 65535) \
		or not SgProtocol.short_text(data.get("name"), SgProtocol.NICKNAME_LIMIT) \
		or not SgProtocol.token(data.get("fingerprint")) or not SgProtocol.integer(data.get("rooms"), 0, SgLocalServer.MAX_ROOMS) \
		or not SgProtocol.token(data.get("build")) or not SgCompatibility.valid_stamp(data.get("stamp")) \
		or not data.access in ACCESS or not data.tables is Array or data.tables.size() > SgLocalServer.MAX_ROOMS:
		return false
	for row in data.tables:
		if not valid_table(row): return false
	# Only an open host publishes its invitation, and only its own: the
	# address, port and certificate inside it must be the advert's.
	if data.has("invitation"):
		if data.access != "open" or not data.invitation is String: return false
		var invite := SgLanInvite.parse(data.invitation)
		if invite.is_empty() or invite.address != data.address or int(invite.port) != int(data.port) \
			or invite.fingerprint != data.fingerprint:
			return false
	return true


## True for a listing whose Join needs no paste.
static func open_host(advert: Dictionary) -> bool:
	return advert.get("access") == "open" and advert.get("invitation") is String


## True for a joinable listing of this protocol version. A reply from a
## host of another version is kept in [member others] and answers false.
func accept_reply(data: Dictionary, source: String, now: int) -> bool:
	# A UDP packet is anyone's: read every field through a typed check, since
	# GDScript raises on `5 != "sg-lan-host"` instead of answering false.
	if not scanning or not SgProtocol.exact(data, ["v", "type", "nonce", "host"]) \
		or not SgProtocol.integer(data.v, 1) \
		or not SgProtocol.literal(data.type, "sg-lan-host") \
		or not SgProtocol.literal(data.nonce, _nonce) or not SgLanInvite.address(source) \
		or not data.get("host") is Dictionary:
		return false
	if int(data.v) != SgProtocol.VERSION:
		_accept_other(data.host, int(data.v), source, now)
		return false
	if not valid_advert(data.host):
		return false
	var advert: Dictionary = data.host
	# A discovery packet is never permission to contact a different IP.
	if advert.address != source:
		return false
	var key := "%s:%d" % [source, int(advert.port)]
	if not _has_room(hosts, key, source): return false
	others.erase(key)
	var previous: Dictionary = hosts.get(key, {})
	var changed_data: bool = previous.get("host", {}) != advert
	hosts[key] = {"host": advert.duplicate(true), "seen": now}
	if changed_data:
		changed.emit()
	return true


## A host of ANOTHER PROTOCOL VERSION (2026-10-03) used to vanish from the
## browser without a word. Its advert's shape is that version's, so only the
## fields every version has carried are read, each through a typed check.
func _accept_other(advert: Dictionary, version: int, source: String, now: int) -> void:
	if not SgLanInvite.address(advert.get("address")) or advert.address != source \
		or not SgProtocol.integer(advert.get("port"), 1, 65535) \
		or not SgProtocol.short_text(advert.get("name"), SgProtocol.NICKNAME_LIMIT):
		return
	var key := "%s:%d" % [source, int(advert.port)]
	if hosts.has(key) or not _has_room(others, key, source): return
	var stamp: Variant = advert.get("stamp")
	var listing := {"address": source, "port": int(advert.port), "name": String(advert.name), "protocol": version,
		"game": String(stamp.game) if stamp is Dictionary and SgCompatibility.plain(stamp.get("game"), 24) else ""}
	var changed_data: bool = others.get(key, {}).get("host", {}) != listing
	others[key] = {"host": listing, "seen": now}
	if changed_data:
		changed.emit()


## Whether [param table] may hold [param key]: bounded overall and per address.
func _has_room(table: Dictionary, key: String, source: String) -> bool:
	if table.has(key): return true
	if table.size() >= MAX_HOSTS: return false
	var from_source := 0
	for other: String in table:
		if other.begins_with(source + ":"): from_source += 1
	return from_source < MAX_HOSTS_PER_ADDRESS


func expire(now: int) -> void:
	var removed := false
	for table: Dictionary in [hosts, others]:
		for key in table.keys():
			if now - int(table[key].seen) >= EXPIRES_MS:
				table.erase(key)
				removed = true
	if removed:
		changed.emit()


func _process(_delta: float) -> void:
	pump()


## One poll of the socket: the periodic query and the expiry while
## scanning, up to 32 packets read. The frame calls it; a tool with no
## frame (the referee's `--table`, 2026-10-03) calls it by hand.
func pump() -> void:
	if not scanning and not advertising:
		return
	var now := Time.get_ticks_msec()
	if scanning:
		if now >= _next_query:
			query()
		expire(now)
	if now - _reply_window >= 1000:
		_reply_window = now
		_replies = 0
	for i in 32:
		if _socket.get_available_packet_count() == 0:
			break
		var bytes := _socket.get_packet()
		var source := _socket.get_packet_ip()
		var source_port := _socket.get_packet_port()
		if bytes.size() > MAX_PACKET or not SgLanInvite.address(source):
			continue
		# Query: root. Reply: root > host > stamp > packs list (depth 4).
		var data := SgProtocol.decode_payload(bytes, 4)
		if scanning:
			accept_reply(data, source, now)
		# A query of any version is answered, in this version's own words: a
		# browser of another version lists this host as such (2026-10-03).
		elif advertising and _replies < 16 \
			and SgProtocol.exact(data, ["v", "type", "nonce"]) \
			and SgProtocol.integer(data.v, 1) \
			and SgProtocol.literal(data.type, "sg-lan-query") \
			and SgProtocol.token(data.nonce):
			_replies += 1
			var reply := {"v": SgProtocol.VERSION, "type": "sg-lan-host",
				"nonce": data.nonce, "host": _advert}
			# Reply from the queried port so stateful firewalls can associate it
			# with the outbound query. Routing chooses the source LAN adapter.
			# SgProtocol.encode, not a bare stringify (2026-10-02): the wire is
			# ASCII JSON and a bare to_ascii_buffer turns every character past
			# 127 — a table rules brief's "·", a deck name's "Æ" — into a
			# space, with an engine error for each. encode escapes them.
			if _socket.set_dest_address(source, source_port) == OK:
				_socket.put_packet(SgProtocol.encode(reply).to_ascii_buffer())
