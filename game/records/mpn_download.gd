class_name MpnDownload
extends RefCounted
## [QoL] Pull one bounded chunk at a time. No paths or hidden seat views
## cross the wire. A different game/offset/size aborts rather than splicing.
signal completed(bytes: PackedByteArray)
signal failed(message: String)
const CHUNK := 16384
var active := false
var room := ""
var record := ""
var bytes := PackedByteArray()
var total := -1
var _waiting := false
var _due := 0
var _deadline := 0

static func valid_message(message: Dictionary) -> bool:
	return SgProtocol.exact(message, ["type", "record", "offset", "total", "data", "error"]) \
		and SgProtocol.literal(message.type, "mpn") and message.record is String \
		and (message.record == "" or SgProtocol.short_text(message.record, 24)) \
		and SgProtocol.integer(message.offset, 0, MpnCodec.MAX_BYTES) \
		and SgProtocol.integer(message.total, 0, MpnCodec.MAX_BYTES) \
		and SgViewProtocol.text(message.data, 21848) and SgViewProtocol.text(message.error, 512)

func start(room_id: String, record_id := "") -> void:
	reset()
	active = true
	room = room_id
	record = record_id

func reset() -> void:
	active = false
	bytes = PackedByteArray()
	record = ""
	room = ""
	total = -1
	_waiting = false
	_due = 0

func abort(message: String) -> void:
	reset()
	failed.emit(message)

func next(now: int) -> Dictionary:
	if not active: return {}
	if _waiting and now >= _deadline:
		abort("MPN download timed out. Reconnect and try Export MPN again before leaving the table.")
		return {}
	if _waiting or now < _due: return {}
	_waiting = true
	_deadline = now + 15000
	return {"v": SgProtocol.VERSION, "type": "mpn", "room": room, "record": record, "offset": bytes.size()}

func receive(message: Dictionary) -> void:
	if not active: return
	if not valid_message(message):
		abort("Invalid MPN response.")
		return
	if message.error != "":
		abort(message.error)
		return
	if not _waiting or int(message.offset) != bytes.size() or String(message.record).is_empty() \
		or (record != "" and record != message.record) or (total != -1 and total != int(message.total)):
		abort("The game record changed during download. Please try again.")
		return
	# Validate the alphabet before decoding; malformed base64 otherwise
	# produces a runtime error, not a clean refusal.
	var pattern := RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}\\z")
	if message.data.length() % 4 != 0 or pattern.search(message.data) == null:
		abort("Invalid MPN data.")
		return
	var chunk := Marshalls.base64_to_raw(message.data)
	var wanted := mini(CHUNK, int(message.total) - bytes.size())
	if chunk.is_empty() or chunk.size() != wanted or Marshalls.raw_to_base64(chunk) != message.data:
		abort("Incomplete MPN data.")
		return
	record = message.record
	total = int(message.total)
	bytes.append_array(chunk)
	_waiting = false
	_due = Time.get_ticks_msec() + 40 # below the host's flood limit
	if bytes.size() == total:
		var parsed := MpnCodec.parse_bytes(bytes)
		if parsed.error != "":
			abort("The downloaded MPN is invalid: " + parsed.error)
			return
		var complete := bytes
		reset()
		completed.emit(complete)
