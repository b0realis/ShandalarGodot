class_name MpnCodec
extends RefCounted
## [QoL] MPN 0.1: public observations, never executable game commands.
## See docs/mpn-v0.1.md. JSON values keep quoting portable and unambiguous.

const VERSION := "MPN/0.1"
const COVERAGE := "public-observations"
const MAX_BYTES := 32 * 1024 * 1024
const MAX_LINE := 1024 * 1024
const MAX_RECORDS := 100000
const KINDS := ["state", "land", "cast", "activate", "draw", "discard", "enter",
	"leave", "die", "mana", "attack", "block", "damage", "tap", "untap",
	"regenerate", "reveal", "mana_burn", "result", "close", "comment"]
const ZONES := ["battlefield", "graveyard", "stack", "exile", "ante", "hand", "library", "phased_out"]

static func header_text(headers: Dictionary) -> String:
	var out := ""
	for key in headers:
		out += "[%s %s]\n" % [key, JSON.stringify(headers[key])]
	return out + "\n"

static func record_text(serial: int, kind: String, data: Dictionary) -> String:
	return "%d %s %s\n" % [serial, kind, JSON.stringify(data)]

## A file's or a download's BYTES, decoded strictly (hunt 2026-10-21): the
## specification makes invalid UTF-8 an error (§2, §9), and Godot's decoder
## replaces it with U+FFFD instead — a damaged record opened as if whole.
## A decode that does not encode back to the same bytes replaced something.
## A leading byte-order mark is passed over, as the decoder always did.
static func parse_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_BYTES: return _error("Record exceeds the 32 MiB prototype limit.")
	var body := bytes
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF: body = bytes.slice(3)
	var text := body.get_string_from_utf8()
	if text.to_utf8_buffer() != body: return _error("This file is not valid UTF-8 text.")
	return parse(text)

static func parse(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return _error("Record exceeds the 32 MiB prototype limit.")
	var headers := {}
	var records: Array = []
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"): continue
		if line.to_utf8_buffer().size() > MAX_LINE: return _error("Line %d is too long." % number)
		if line.begins_with("["):
			if not records.is_empty() or not line.ends_with("]"): return _error("Misplaced header at line %d." % number)
			var split := line.find(" ")
			if split < 2: return _error("Invalid header at line %d." % number)
			var key := line.substr(1, split - 1)
			if headers.has(key): return _error("Duplicate header: " + key)
			var json := JSON.new()
			if json.parse(line.substr(split + 1, line.length() - split - 2)) != OK:
				return _error("Invalid header value at line %d." % number)
			headers[key] = json.data
			continue
		var parts := line.split(" ", false, 2)
		# The digits are counted BEFORE int() (the bug campaign c12, h5-3):
		# a 20-digit serial made the engine print "Cannot represent … as a
		# 64-bit signed integer" before the file was refused. No serial
		# needs more digits than the last one a record may hold.
		if parts.size() != 3 or not parts[0].is_valid_int() \
				or _digits(parts[0]) > str(MAX_RECORDS + 1).length() \
				or int(parts[0]) != records.size() + 1:
			return _error("Broken event sequence at line %d." % number)
		if parts[1] not in KINDS: return _error("Unsupported event: " + parts[1])
		var json := JSON.new()
		if json.parse(parts[2]) != OK or not json.data is Dictionary:
			return _error("Invalid event payload at line %d." % number)
		var payload: Dictionary = json.data
		if not _bounded(payload): return _error("Invalid or excessive event data at line %d." % number)
		if parts[1] == "state" and not valid_patch(payload): return _error("Invalid public state at line %d." % number)
		if parts[1] == "result" and payload.get("result", "") not in ["1-0", "0-1", "1/2-1/2"]:
			return _error("Invalid result at line %d." % number)
		records.append({"kind": parts[1], "data": payload})
		if records.size() > MAX_RECORDS: return _error("Too many events.")
	if not _literal(headers.get("Notation"), VERSION): return _error("Unsupported or missing MPN version.")
	if not _literal(headers.get("Visibility"), "public") or not _literal(headers.get("Coverage"), COVERAGE):
		return _error("This viewer supports public-observation records only.")
	for key in ["Started", "Match", "Player.P1", "Player.P2"]:
		if not headers.get(key) is String or String(headers[key]).is_empty(): return _error("Missing header: " + key)
	if not _bounded(headers): return _error("Invalid metadata.")
	if records.is_empty() or records[0].kind != "state": return _error("Missing initial public state.")
	for key in ["turn", "step", "active", "players", "objects", "stack", "combat"]:
		if not records[0].data.has(key): return _error("Incomplete initial state: " + key)
	var finished := false
	var closed := false
	for record in records:
		if closed or (finished and record.kind not in ["close", "comment"]): return _error("Events follow the end of the game.")
		if record.kind == "result": finished = true
		if record.kind == "close": closed = true
	return {"headers": headers, "records": records, "finished": finished, "error": ""}

static func _error(message: String) -> Dictionary:
	return {"error": message, "headers": {}, "records": [], "finished": false}

static func _literal(value: Variant, expected: String) -> bool:
	return value is String and value == expected

static func _bounded(value: Variant, depth := 0) -> bool:
	if depth > 12: return false
	if value is String: return value.length() <= 8192
	if value is Array or value is Dictionary:
		if value.size() > 4096: return false
		for key in value:
			if value is Dictionary:
				if not key is String or key.length() > 128 or not _bounded(value[key], depth + 1): return false
			elif not _bounded(key, depth + 1): return false
		return true
	return value == null or value is bool or value is int or (value is float and is_finite(value))

static func valid_patch(data: Dictionary) -> bool:
	for key in data:
		if key not in ["turn", "step", "active", "players", "objects", "removed", "stack", "combat"]: return false
	for key in ["turn", "active"]:
		if data.has(key) and not _integer(data[key], 0, 1000000): return false
	if data.has("active") and int(data.active) > 1: return false
	if data.has("step") and not data.step is String: return false
	if data.has("players"):
		if not data.players is Array or data.players.size() != 2: return false
		for player in data.players:
			if not player is Dictionary: return false
			for key in player:
				if key not in ["life", "poison", "hand", "library", "mana"]: return false
			if player.has("poison") and not _integer(player.poison, 0, 1000000): return false
			for key in ["life", "hand", "library"]:
				if not player.has(key) or not _integer(player[key], -1000000 if key == "life" else 0, 1000000): return false
			if not player.get("mana") is Dictionary: return false
			for key in player.mana:
				if key not in ["W", "U", "B", "R", "G", "C"] or not _integer(player.mana[key], 0, 1000000): return false
	if data.has("objects"):
		if not data.objects is Array: return false
		var ids := {}
		for card in data.objects:
			if not card is Dictionary or not _id(card.get("id", ""), "o") or ids.has(card.id): return false
			for key in card:
				if key not in ["id", "name", "zone", "owner", "controller", "power", "toughness", "damage", "tapped", "face_down", "creature", "counters", "attached_to", "token", "definition_set", "printing", "rules_text", "types", "subtypes", "keywords"]: return false
			ids[card.id] = true
			if not card.get("name") is String or card.get("zone") not in ZONES: return false
			for key in ["owner", "controller"]:
				if not _integer(card.get(key), 0, 1): return false
			for key in ["power", "toughness", "damage"]:
				if not _integer(card.get(key), -1000000, 1000000): return false
			for key in ["tapped", "face_down", "creature"]:
				if not card.get(key) is bool: return false
			if not card.get("counters") is Dictionary: return false
			if card.face_down:
				if card.name != "Face-down card": return false
				for key in ["definition_set", "printing", "rules_text", "types", "subtypes", "keywords"]:
					if card.has(key): return false
	if data.has("removed"):
		if not data.removed is Array: return false
		for id in data.removed:
			if not _id(id, "o"): return false
	if data.has("stack"):
		if not data.stack is Array: return false
		for item in data.stack:
			if not item is Dictionary or not _id(item.get("id", ""), "s") or not item.get("name") is String: return false
			if not item.get("targets") is Array: return false
	if data.has("combat"):
		if not data.combat is Dictionary: return false
		if not data.combat.get("attackers") is Array or not data.combat.get("blocks") is Array: return false
		for id in data.combat.attackers:
			if not _id(id, "o"): return false
		for pair in data.combat.blocks:
			if not pair is Array or pair.size() != 2 or not _id(pair[0], "o") or not _id(pair[1], "o"): return false
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and float(value) == floor(float(value)) and value >= low and value <= high

## A handle's number has at most 18 digits — any more and int() prints an
## engine ERROR on the way to refusing it (the bug campaign c12, h5-3).
static func _id(value: Variant, prefix: String) -> bool:
	return value is String and value.begins_with(prefix) and value.substr(1).is_valid_int() and _digits(value.substr(1)) <= 18 and int(value.substr(1)) > 0 and value.substr(1) == str(int(value.substr(1)))

## The significant digits of an integer token is_valid_int() passed.
static func _digits(token: String) -> int:
	return token.trim_prefix("+").trim_prefix("-").lstrip("0").length()

static func apply_patch(state: Dictionary, patch: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	if not out.has("objects"): out.objects = {}
	for key in patch:
		if key not in ["objects", "removed"]: out[key] = patch[key].duplicate(true) if patch[key] is Array or patch[key] is Dictionary else patch[key]
	for id in patch.get("removed", []): out.objects.erase(id)
	for card in patch.get("objects", []): out.objects[card.id] = card.duplicate(true)
	return out

static func state_at(records: Array, index: int) -> Dictionary:
	var state := {}
	for i in mini(index + 1, records.size()):
		if records[i].kind == "state": state = apply_patch(state, records[i].data)
	return state

static func summary(record: Dictionary) -> String:
	return String(record.kind).capitalize() + "  " + JSON.stringify(record.data)
