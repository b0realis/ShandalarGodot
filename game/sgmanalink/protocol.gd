class_name SgProtocol
extends RefCounted
## [QoL] Unrated loopback/LAN protocol. Data only; no Variant object decoding or RPC.
## Version this independently from the application release and future rated protocol.

const VERSION := 23
const SUBPROTOCOL := "sgmanalink-local-v23"
## THE OPEN TABLE (2026-09-18): a table is hosted with a deck rule — "own"
## (everyone brings a deck) or "fixed" (the host's deck is dealt to both).
const DECK_RULES := ["own", "fixed"]
const NICKNAME_LIMIT := 20
const MAX_BYTES := 2097152
const MAX_COMMAND_BYTES := 32768
const MAX_CARDS := 512
const FIELDS := {
	"host": ["name", "decks", "deck"], "join": ["room"], "ready": ["value"], "leave": [],
	"keep": [], "mulligan": [], "pass": [], "play": ["card"],
	"tap": ["card"], "attack": ["cards"], "block": ["pairs"],
	"damage": ["points"], "discard": ["cards"], "concede": [],
	"deck": ["name", "cards", "sideboard"],
	"prepare": ["card", "kind", "index", "x", "mode"],
	"submit": ["targets"], "cancel": [], "choice": ["picks"],
	"attack_bands": ["cards", "bands"],
	"special": ["index"],
	"order": ["play"], "mana": ["card", "index"],
	"autopay": ["excluded", "count"],
	"autoprepare": ["card", "kind", "index", "mode", "excluded", "count"],
	"remove_guest": [],
	"add_bot": ["bot", "deck"], "remove_bot": [],
	"t_bots": ["event", "count", "bot", "deck"],
	"t_join": ["event"], "t_ready": ["event", "value", "round", "game"],
	"t_deck": ["event", "name", "cards", "sideboard"], "t_choose": ["event", "index"],
	"t_start": ["event"], "t_next": ["event"], "t_return": ["event"],
	"t_withdraw": ["event"], "t_remove": ["event", "player"],
	"t_recover": ["event", "code"], "t_cancel": ["event"], "t_retry": ["event"],
	"t_clear": ["event"],
	"t_close": ["event"],
	"t_pause": ["event"], "t_resume": ["event"],
	"t_rule": ["event", "pair", "winner"],
}
static var _unicode_pattern: RegEx


static func integer(value: Variant, low := 0, high := 1000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= low and value <= high


static func exact(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true


static func short_text(value: Variant, limit := 32) -> bool:
	if not value is String or value.is_empty() or value.length() > limit:
		return false
	for c in value:
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_".contains(c):
			return false
	return not value.strip_edges().is_empty()


static func token(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for c in value:
		if not "0123456789abcdef".contains(c):
			return false
	return true


static func nickname(value: Variant) -> bool:
	return value is String and (value.is_empty() or short_text(value, NICKNAME_LIMIT)) \
		and value == value.strip_edges()


## Is an UNTRUSTED field exactly this word? GDScript raises "Invalid
## operands" on `5 == "hello"` instead of answering false, so a decoded
## message's own text is compared through this, never with == directly.
static func literal(value: Variant, expected: String) -> bool:
	return value is String and value == expected


static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_COMMAND_BYTES:
		return {}
	var message := decode_payload(bytes, 6)
	return message if valid(message) else {}


static func decode_payload(bytes: PackedByteArray, max_depth := 12) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_BYTES:
		return {}
	# This protocol deliberately uses ASCII JSON. Bound nesting BEFORE parsing.
	var depth := 0
	var quoted := false
	var escaped := false
	for byte in bytes:
		if byte == 0 or byte > 127:
			return {}
		if quoted:
			if escaped:
				escaped = false
			elif byte == 92:
				escaped = true
			elif byte == 34:
				quoted = false
		elif byte == 34:
			quoted = true
		elif byte == 91 or byte == 123:
			depth += 1
			if depth > max_depth:
				return {}
		elif byte == 93 or byte == 125:
			depth -= 1
			if depth < 0:
				return {}
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_ascii()) != OK or not parser.data is Dictionary:
		return {}
	return parser.data


static func valid(message: Dictionary) -> bool:
	if not integer(message.get("v"), VERSION, VERSION):
		return false
	if literal(message.get("type"), "hello"):
		return exact(message, ["v", "type", "access", "resume", "nickname", "build", "stamp"]) \
			and token(message.access) and (literal(message.resume, "") or token(message.resume)) \
			and nickname(message.nickname) and token(message.build) and SgCompatibility.valid_stamp(message.stamp)
	if literal(message.get("type"), "abandon"): return exact(message, ["v", "type"])
	if not exact(message, ["v", "type", "seq", "room", "revision", "action"]):
		return false
	if not message.room is String or (message.room != "" and not short_text(message.room, 16)):
		return false
	if not literal(message.type, "command") or not integer(message.seq, 1) \
		or not integer(message.revision) or not message.action is Dictionary:
		return false
	var action: Dictionary = message.action
	var op: Variant = action.get("op")
	if not op is String or not FIELDS.has(op):
		return false
	var keys: Array = ["op"] + FIELDS[op]
	if op in ["deck", "t_deck"] and action.has("printings"): keys.append("printings")
	if not exact(action, keys):
		return false
	if op.begins_with("t_") and not token(action.event): return false
	match op:
		"add_bot": return SgBotPlayer.valid(action.bot) and SgDeckCatalog.valid_payload(action.deck)
		"t_bots":
			return SgBotPlayer.valid(action.bot) and SgTournament.valid_deck(action.deck) \
				and integer(action.count, 1, SgTournament.MAX_PLAYERS)
		"t_recover": return token(action.code)
		"t_remove": return integer(action.player, 1)
		"t_rule": return integer(action.pair, 1, SgTournament.MAX_PAIR_ID) and integer(action.winner, 1)
		"t_choose": return integer(action.index, 0, 15)
		"order": return action.play is bool
		"mana": return short_text(action.card, 16) and integer(action.index, 0, 63)
		"autopay": return handles(action.excluded) and integer(action.count, 1, MAX_CARDS)
		"autoprepare":
			return short_text(action.card, 16) and action.kind in ["spell", "ability"] \
				and integer(action.index, 0, 63) and integer(action.mode, 0, 63) \
				and handles(action.excluded) and integer(action.count, 1, MAX_CARDS)
		"special": return integer(action.index, 0, MAX_CARDS)
		"deck", "t_deck":
			return SgViewProtocol.text(action.name, 128) and not action.name.strip_edges().is_empty() \
				and names(action.cards, 250) and names(action.sideboard, 250) \
				and DeckPrintings.valid_map(action.get("printings", {}), action.cards + action.sideboard)
		"prepare":
			return short_text(action.card, 16) and action.kind in ["spell", "ability", "mana"] \
				and integer(action.index, 0, 63) and integer(action.x, 0, 1000) and integer(action.mode, 0, 63)
		"submit":
			if not action.targets is Array or action.targets.size() > MAX_CARDS:
				return false
			for target in action.targets:
				if not target is Array or target.size() != 2 or not short_text(target[0], 16) \
					or not integer(target[1], 0, 1000):
					return false
		"choice": return indices(action.picks, MAX_CARDS)
		"attack_bands":
			if not handles(action.cards) or not action.bands is Array or action.bands.size() > MAX_CARDS:
				return false
			for band in action.bands:
				if not handles(band): return false
		"host":
			if not short_text(action.name) or not action.decks in DECK_RULES or not action.deck is Dictionary:
				return false
			return action.deck.is_empty() if action.decks == "own" else SgDeckCatalog.valid_payload(action.deck)
		"join": return short_text(action.room, 16)
		"ready": return action.value is bool
		"t_ready": return action.value is bool and integer(action.round, 0, SgTournament.MAX_ROUNDS) and integer(action.game, 0, SgTournament.MAX_GAMES)
		"play", "tap": return short_text(action.card, 16)
		"attack", "discard":
			if not action.cards is Array or action.cards.size() > MAX_CARDS:
				return false
			for handle in action.cards:
				if not short_text(handle, 16):
					return false
		"block", "damage":
			var pairs: Variant = action.get("pairs", action.get("points"))
			if not pairs is Array or pairs.size() > MAX_CARDS:
				return false
			for pair in pairs:
				if not pair is Array or pair.size() != 2 or not short_text(pair[0], 16):
					return false
				if op == "block" and not short_text(pair[1], 16):
					return false
				if op == "damage" and not integer(pair[1], 0, 1000000):
					return false
	return true


static func names(value: Variant, maximum: int) -> bool:
	if not value is Array or value.size() > maximum: return false
	for item in value:
		if not SgViewProtocol.text(item, 128) or item.is_empty(): return false
	return true


static func handles(value: Variant) -> bool:
	if not value is Array or value.size() > MAX_CARDS: return false
	for item in value:
		if not short_text(item, 16): return false
	return true


static func indices(value: Variant, maximum: int) -> bool:
	if not value is Array or value.size() > maximum: return false
	for item in value:
		if not integer(item, 0, 4095): return false
	return true


## ASCII wire framing still permits printed names such as Junún Efreet.
static func encode(value: Dictionary) -> String:
	# Scan in native code and join chunks once, not one allocation per character.
	if _unicode_pattern == null:
		_unicode_pattern = RegEx.new()
		_unicode_pattern.compile("[^\\x{0}-\\x{7f}]")
	var json := JSON.stringify(value)
	var chunks := PackedStringArray()
	var start := 0
	for found in _unicode_pattern.search_all(json):
		chunks.append(json.substr(start, found.get_start() - start))
		var code: int = found.get_string().unicode_at(0)
		if code <= 65535:
			chunks.append("\\u%04x" % code)
		else:
			code -= 65536
			chunks.append("\\u%04x\\u%04x" % [55296 + (code >> 10), 56320 + (code & 1023)])
		start = found.get_end()
	chunks.append(json.substr(start))
	return "".join(chunks)
