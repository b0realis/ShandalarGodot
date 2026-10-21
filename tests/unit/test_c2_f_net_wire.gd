extends GutTest
## THE WIRE CHECKS, NATIVELY (robustness campaign 2026-10-12, f-net, r4-7).
## Every SGManalink state a guest reads (40-80 KB late in a duel) went
## through a GDScript loop over every byte (SgProtocol.decode_payload: NUL,
## past 127, bracket depth) and a GDScript loop over every character of
## every text field (SgViewProtocol.text, rules texts to 4 KB) — 6-14 ms and
## 6-10 ms on a fast desk, per state, both ends. The checks are native now:
## a NUL found by PackedByteArray.find, the high bits tested eight bytes at
## a time, the nesting measured on the parsed tree, a text field matched by
## one RegEx. Pinned here: the same answers as before on every edge, and a
## late-game state checked well inside a frame.

const Pilot := preload("res://tests/support/sg_network_pilot.gd")
## The byte loop and parse below over the 79 KB state of this duel on the
## quiet desk, 2026-10-21 (5.4-5.9 ms).
const QUIET_OLD_DECODE_US := 5700.0


func _bytes(text: String) -> PackedByteArray:
	return text.to_ascii_buffer()


func test_decode_payload_answers_as_before() -> void:
	# (JSON numbers arrive as floats: the messages here hold floats.)
	var message := {"v": 29.0, "type": "state", "list": [1.0, 2.0, {"a": "b"}], "text": "x\ny \"q\" [{"}
	assert_eq(SgProtocol.decode_payload(_bytes(SgProtocol.encode(message))), message)
	# Not an object at the top, empty, too big, not JSON.
	assert_eq(SgProtocol.decode_payload(_bytes("[1, 2]")), {})
	assert_eq(SgProtocol.decode_payload(PackedByteArray()), {})
	assert_eq(SgProtocol.decode_payload(_bytes(" ".repeat(SgProtocol.MAX_BYTES + 1))), {})
	assert_eq(SgProtocol.decode_payload(_bytes("{\"a\": ")), {})
	assert_eq(SgProtocol.decode_payload(_bytes("[".repeat(30))), {})
	# A NUL or a byte past 127 anywhere — first, last, in every word slot.
	var plain := _bytes("{\"a\": \"" + "x".repeat(37) + "\"}")
	for at in [0, 1, 7, 8, 20, plain.size() - 2, plain.size() - 1]:
		for bad in [0, 128, 200, 255]:
			var bytes := plain.duplicate()
			bytes[at] = bad
			assert_eq(SgProtocol.decode_payload(bytes), {}, "byte %d at %d" % [bad, at])
	assert_eq(SgProtocol.decode_payload(PackedByteArray([0xff, 0xfe])), {})
	# An escaped character is ASCII on the wire and decodes.
	assert_eq(SgProtocol.decode_payload(_bytes("{\"n\": \"Jun\\u00fan\"}")), {"n": "Junún"})


func test_nesting_is_bounded_as_before() -> void:
	# The top object counts one; brackets inside strings count nothing.
	var four := "{\"a\": [{\"b\": [1]}]}"
	assert_eq(SgProtocol.decode_payload(_bytes(four), 4), {"a": [{"b": [1.0]}]})
	assert_eq(SgProtocol.decode_payload(_bytes(four), 3), {})
	var quoted := "{\"a\": \"[[[[[[[[[[[[[[[[\", \"b\": {}}"
	assert_eq(SgProtocol.decode_payload(_bytes(quoted), 2), {"a": "[[[[[[[[[[[[[[[[", "b": {}})
	assert_eq(SgProtocol.decode_payload(_bytes(quoted), 1), {})
	# Empty containers count as deep as full ones.
	assert_eq(SgProtocol.decode_payload(_bytes("{\"a\": [[]]}"), 3), {"a": [[]]})
	assert_eq(SgProtocol.decode_payload(_bytes("{\"a\": [[]]}"), 2), {})
	# Nested far past any limit (and past the parser's own): refused, quietly.
	var deep := "{\"a\": " + "[".repeat(5000) + "]".repeat(5000) + "}"
	assert_eq(SgProtocol.decode_payload(_bytes(deep)), {})
	var deeper := "{\"a\": " + "[".repeat(200000) + "]".repeat(200000) + "}"
	assert_eq(SgProtocol.decode_payload(_bytes(deeper)), {})
	assert_eq(get_errors().size(), 0, "nothing printed")


func test_text_answers_as_before() -> void:
	for good in ["", "Junún Efreet", "line one\nline two", "Æther Storm — {2}{R}", "😀 emoji", "a".repeat(128)]:
		assert_true(SgViewProtocol.text(good), "accepted: %s" % good.c_escape())
	for code in [1, 9, 13, 27, 31, 127, 0x80, 0x85, 0x9f, 0x202a, 0x202e, 0x2066, 0x2069]:
		var bad := "ok" + String.chr(code) + "ok"
		assert_false(SgViewProtocol.text(bad), "refused U+%04X" % code)
	assert_true(SgViewProtocol.text(String.chr(0xa0) + String.chr(0x2029) + String.chr(0x206a)), "the neighbours pass")
	assert_false(SgViewProtocol.text("a".repeat(129)), "over the limit")
	assert_false(SgViewProtocol.text(5), "not text")
	assert_false(SgViewProtocol.text(null))


func test_short_text_and_token_answer_as_before() -> void:
	for good in ["Kitchen", "r1", "a b-c_d", "Z".repeat(32)]:
		assert_true(SgProtocol.short_text(good), good)
	for bad in ["", "   ", "Z".repeat(33), "tab\there", "dot.", "Junún", "new\nline", 7, null]:
		assert_false(SgProtocol.short_text(bad), str(bad).c_escape())
	assert_true(SgProtocol.short_text("x".repeat(16), 16))
	assert_false(SgProtocol.short_text("x".repeat(17), 16))
	var hex := "0123456789abcdef".repeat(4)
	assert_true(SgProtocol.token(hex))
	for bad in [hex.to_upper(), hex.left(63), hex + "0", hex.left(63) + "g", hex.left(63) + "\n", 5]:
		assert_false(SgProtocol.token(bad), str(bad))


## A late-game state through the guest's two checks, and the host's own
## view check, each inside a frame — measured on this duel, the guest's
## worst went from 12.5 ms to 5.4 ms, the host's from 4.8 to 3.0. The frame
## budget is generous (a loaded desk runs four Godots at once); what pins
## the native checks is relative: each against the GDScript loop it
## replaced, run on the same bytes and text in the same process.
##
## A machine busy with other work (2026-10-21, a load of 57-71 on the desk)
## read 25-53 ms for checks that take 5: each state is timed best of three,
## against the scheduler's spikes, and the frame is stretched by how much
## slower the old decode of the biggest state runs right now than it ran on
## the quiet desk ([constant QUIET_OLD_DECODE_US]) — never shrunk.
func test_a_late_game_state_is_checked_inside_a_frame() -> void:
	var decks := SgDeckCatalog.available()
	var found := {}
	for deck in decks:
		if String(deck.name) in ["The Deck (Weissman, Winter 1994–95)", "Unholy Alliance"]:
			found[String(deck.name)] = deck
	var a: Dictionary = found.get("The Deck (Weissman, Winter 1994–95)", decks[0])
	var b: Dictionary = found.get("Unholy Alliance", decks[1])
	var m := SgPracticeMatch.new(102, [SgDeckCatalog.payload(a), SgDeckCatalog.payload(b)], ["A", "B"])
	var pilots := [Pilot.new(), Pilot.new()]
	var worst_guest := 0.0
	var worst_host := 0.0
	var biggest := 0
	var biggest_wire := PackedByteArray()
	var refused := 0
	for step in 1200:
		if m.game.game_over: break
		var actor := int(m.decision_state().actor)
		if step % 10 == 0:
			for seat in 2:
				var view := m.view(seat)
				var wire := SgProtocol.encode({"type": "state", "rooms": [], "room": {}, "game": view}).to_ascii_buffer()
				var host_ms := INF
				var guest_ms := INF
				for i in 3:
					var began := Time.get_ticks_usec()
					assert_true(SgViewProtocol.game(view), "the host's own check passes")
					host_ms = minf(host_ms, (Time.get_ticks_usec() - began) / 1000.0)
					began = Time.get_ticks_usec()
					var decoded := SgProtocol.decode_payload(wire)
					var valid := SgViewProtocol.game(decoded.get("game", {}))
					guest_ms = minf(guest_ms, (Time.get_ticks_usec() - began) / 1000.0)
					assert_true(valid, "the guest's check passes")
				worst_guest = maxf(worst_guest, guest_ms)
				worst_host = maxf(worst_host, host_ms)
				if wire.size() > biggest:
					biggest = wire.size()
					biggest_wire = wire
		var error := m.act(actor, pilots[actor].choose(m.view(actor), actor))
		if not error.is_empty():
			refused += 1
			if refused > 50: m.act(actor, {"op": "pass"})
	gut.p("wire: biggest state %d bytes; worst guest decode+check %.2f ms; worst host check %.2f ms" % [biggest, worst_guest, worst_host])
	assert_gt(biggest, 20000, "a state of some size was measured")
	# The decode against the one it replaced (the byte loop, then the
	# parse), best of three each.
	var native := INF
	var looped := INF
	for i in 3:
		var began := Time.get_ticks_usec()
		assert_false(SgProtocol.decode_payload(biggest_wire).is_empty())
		native = minf(native, Time.get_ticks_usec() - began)
		began = Time.get_ticks_usec()
		assert_true(_byte_loop(biggest_wire, 12))
		var parser := JSON.new()
		assert_eq(parser.parse(biggest_wire.get_string_from_ascii()), OK)
		looped = minf(looped, Time.get_ticks_usec() - began)
	gut.p("wire: decode of %d bytes %.0f us; the old decode %.0f us" % [biggest_wire.size(), native, looped])
	assert_lt(native, looped * 0.75, "the native checks beat the byte loop")
	var frame := 16.0 * maxf(1.0, looped / QUIET_OLD_DECODE_US)
	assert_lt(worst_guest, frame, "the guest's decode and check of one state")
	assert_lt(worst_host, frame, "the host's own check of one view")
	# A 4 KB rules text against the character loop it replaced.
	var rules := "Flying. When this enters, draw a card.\n".repeat(100).left(4096)
	native = INF
	looped = INF
	for i in 3:
		var began := Time.get_ticks_usec()
		for k in 20: assert_true(SgViewProtocol.text(rules, 4096))
		native = minf(native, Time.get_ticks_usec() - began)
		began = Time.get_ticks_usec()
		for k in 20: assert_true(_character_loop(rules))
		looped = minf(looped, Time.get_ticks_usec() - began)
	gut.p("wire: 20 checks of a 4 KB text %.0f us; the character loop %.0f us" % [native, looped])
	assert_lt(native, looped * 0.25, "one native match beats the character loop")


## SgProtocol.decode_payload's scan before 2026-10-12: NUL, past 127,
## bracket depth outside strings — a GDScript loop over every byte.
static func _byte_loop(bytes: PackedByteArray, max_depth: int) -> bool:
	var depth := 0
	var quoted := false
	var escaped := false
	for byte in bytes:
		if byte == 0 or byte > 127:
			return false
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
				return false
		elif byte == 93 or byte == 125:
			depth -= 1
	return true


## SgViewProtocol.text's loop before 2026-10-12.
static func _character_loop(value: String) -> bool:
	for character in value:
		var code: int = character.unicode_at(0)
		if (code < 32 and code != 10) or code == 127 or (code >= 0x80 and code <= 0x9f) \
			or code in [0x202a, 0x202b, 0x202c, 0x202d, 0x202e, 0x2066, 0x2067, 0x2068, 0x2069]:
			return false
	return true
