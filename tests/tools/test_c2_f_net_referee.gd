extends GutTest
## THE REFEREE UNDER HOSTILE CONDITIONS (robustness campaign 2026-10-12,
## f-net; DeckLab/referee.gd).
##
## r4-4  THE HOSTED TABLE'S END. `referee --host` stopped its host the moment
##       the duel ended, without a word: the person at the table reconnected
##       to nothing, forever, over the finished duel. Now the person still
##       seated gets a moment (at most HOST_LINGER_MS) to leave, and is then
##       told "The host closed its tables." (_close_table).
## r4-8  THE PIPE, BYTE BY BYTE. Godot's stdin line reader returned "" for a
##       blank line and for the end of the input alike — three blank lines
##       conceded the seat with the program still there — and cut a line
##       longer than its buffer in two: two refusals and two decisions for
##       one answer. A blank line is skipped now, only the real end
##       concedes, and an over-long line is refused once, whole.
## r4-10 THE INVITATION OFF THE COMMAND LINE: `--join env:NAME` reads it
##       from that environment variable (the MCP server's way; `ps` shows
##       every argv to anyone on the computer).

const REFEREE := "res://DeckLab/referee.gd"
const RefScript := preload("res://DeckLab/referee.gd")
const DECKS := ["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck", "--seed", "7"]
const VARIABLE := "SHANDALAR_C2_F_NET_INVITATION"

var _lines: Array = []


func before_each() -> void:
	_lines.clear()


func after_each() -> void:
	OS.unset_environment(VARIABLE)


func _referee():
	var ref = autofree(load(REFEREE).new())
	ref.writer = func(line: String) -> void: _lines.append(JSON.parse_string(line))
	return ref


func _of(type: String) -> Array:
	var found: Array = []
	for line in _lines:
		if line is Dictionary and line.get("type", "") == type:
			found.append(line)
	return found


func _errors() -> Array:
	var found: Array = []
	for line in _lines:
		if line is Dictionary and line.has("error"):
			found.append(line.error)
	return found


## A byte source for _read_line_from: the text in chunks of [param size].
func _source(text: String, size := 7) -> Callable:
	var state := {"bytes": text.to_utf8_buffer(), "at": 0}
	return func() -> PackedByteArray:
		var at: int = state.at
		var bytes: PackedByteArray = state.bytes
		if at >= bytes.size():
			return PackedByteArray()
		state.at = at + size
		return bytes.slice(at, at + size)


func _read_all(source: Callable) -> Array:
	var ref = _referee()
	var out: Array = []
	for i in 50:
		var line: Variant = ref._read_line_from(source)
		out.append(line)
		if line == null:
			break
	return out


func test_blank_lines_are_lines_and_the_end_is_the_end() -> void:
	for size in [1, 3, 64]:
		assert_eq(_read_all(_source("{\"op\":\"keep\"}\n\n\n\n{\"op\":\"pass\"}\r\n", size)),
			["{\"op\":\"keep\"}", "", "", "", "{\"op\":\"pass\"}\r", null], "chunks of %d" % size)
	assert_eq(_read_all(_source("")), [null], "nothing at all is the end")
	assert_eq(_read_all(_source("{\"op\":\"pass\"}")), ["{\"op\":\"pass\"}", null], "a last line without its newline")
	assert_eq(_read_all(_source("Junún\n", 1)), ["Junún", null], "a character split across reads")


func test_an_over_long_line_is_one_refusal() -> void:
	var ref = _referee()
	var long := "{\"op\": \"keep\", \"pad\": \"" + "x".repeat(RefScript.LINE_LIMIT + 5000) + "\"}"
	assert_eq(_read_all(_source(long + "\n{\"op\":\"pass\"}\n", 4096)), [RefScript.OVERLONG_LINE, "{\"op\":\"pass\"}", null])
	assert_eq(_read_all(_source(long, 4096)), [null], "an over-long last line at the end is nothing")
	var exact := "y".repeat(RefScript.LINE_LIMIT)
	assert_eq(_read_all(_source(exact + "\n", 4096)), [exact, null], "a line of exactly the limit is read")
	var refused: Dictionary = ref._parse_action(RefScript.OVERLONG_LINE, 0)
	assert_eq(String(refused.get("refusal", "")), "the line is longer than %d bytes; none of it was read" % RefScript.LINE_LIMIT)


## The pipe end to end: three blank lines are skipped and the duel goes on;
## an over-long answer is refused once, the decision asked once again.
func test_the_pipe_skips_blank_lines_and_refuses_a_long_line_once() -> void:
	var ref = _referee()
	var source := _source("\n\n\n{\"op\":\"keep\",\"pad\":\"" + "x".repeat(RefScript.LINE_LIMIT + 10) + "\"}\n\n\n{\"op\":\"concede\"}\n", 4096)
	ref.reader = func() -> Variant: return ref._read_line_from(source)
	assert_eq(ref._main(PackedStringArray(DECKS)), 0)
	assert_eq(ref.last_result.reason, "conceded", "blank lines are not the end of the input")
	assert_eq(_of("refused").size(), 1, "one refusal for the long line")
	assert_eq(String(_of("refused")[0].reason), "the line is longer than %d bytes; none of it was read" % RefScript.LINE_LIMIT)
	assert_eq(_of("decision").size(), 2, "the decision, and once again after the refusal")
	assert_eq(int(ref.last_result.refusals), 1)


func test_the_end_of_the_pipe_still_concedes() -> void:
	var ref = _referee()
	var source := _source("\n\n\n\n\n")
	ref.reader = func() -> Variant: return ref._read_line_from(source)
	assert_eq(ref._main(PackedStringArray(DECKS)), 0)
	assert_eq(ref.last_result.reason, "eof")


func test_join_reads_the_invitation_from_the_environment() -> void:
	var ref = _referee()
	var code: int = ref._main(PackedStringArray(["--join", "env:" + VARIABLE, "--deck", "big_green.deck", "--wait", "1"]))
	assert_eq(code, 2)
	var error: Dictionary = _errors()[0]
	assert_eq(error.flag, "--join")
	assert_eq(String(error.message), "--join env:%s: the environment variable %s holds no invitation" % [VARIABLE, VARIABLE])
	# A value that is no invitation is read — and refused as the value it is.
	_lines.clear()
	OS.set_environment(VARIABLE, "not-an-invitation")
	ref = _referee()
	assert_eq(ref._main(PackedStringArray(["--join", "env:" + VARIABLE, "--deck", "big_green.deck", "--wait", "1"])), 2)
	assert_true(String(_errors()[0].message).begins_with("cannot join with 'not-an-invitation'"), _errors()[0].message)
	# A same-computer access code from the environment is used to connect.
	_lines.clear()
	OS.set_environment(VARIABLE, "0123456789abcdef".repeat(4))
	ref = _referee()
	assert_eq(ref._main(PackedStringArray(["--join", "env:" + VARIABLE, "--deck", "big_green.deck", "--wait", "1", "--port", "1"])), 2)
	var message := String(_errors()[0].message)
	assert_true(message.begins_with("the table could not be reached"), message)
	assert_false(message.contains("0123456789abcdef"), "the secret is not repeated")
	# A name that is no variable name is refused before anything is read.
	_lines.clear()
	ref = _referee()
	assert_eq(ref._main(PackedStringArray(["--join", "env:1 bad", "--deck", "big_green.deck", "--wait", "1"])), 2)
	assert_true(String(_errors()[0].message).contains("holds no invitation"))


# ------------------------------------------------------------- r4-4 ----

var _server: SgLocalServer
var _guest: SgLocalClient


func _table() -> void:
	_server = SgLocalServer.new()
	add_child_autofree(_server)
	_server.set_process(false)
	assert_eq(_server.start_lan("127.0.0.1", 0, false), OK)
	_guest = SgLocalClient.new()
	add_child_autofree(_guest)
	_guest.set_process(false)
	assert_eq(_guest.connect_invitation(_server.invitation(), "Person"), OK)
	assert_true(_pump(func() -> bool: return _guest.online), "the person is in")
	assert_true(_guest.command({"op": "host", "name": "Kitchen", "decks": "own", "deck": {}}))
	assert_true(_pump(func() -> bool: return not _guest.busy() and not _guest.state.room.is_empty()), "seated")
	assert_eq(_server.seated_guests(), 1)


func _pump(until: Callable, ms := 5000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		_server.poll()
		_guest.poll()
		if until.call():
			return true
		OS.delay_msec(5)
	return false


func test_a_hosted_table_waits_for_the_person_then_tells_them() -> void:
	_table()
	var ref = _referee()
	var started := Time.get_ticks_msec()
	ref._close_table(_server, func() -> void:
		_server.poll()
		_guest.poll(), 600)
	var took := Time.get_ticks_msec() - started
	assert_between(took, 550, 2500, "waited for the seated person (%d ms)" % took)
	assert_eq(_server.closing(), 0, "the told connection was closed")
	_pump(func() -> bool: return not _guest._wanted, 2000)
	assert_eq(_guest.status, SgLocalServer.HOST_CLOSED)
	assert_false(_guest._wanted, "the person's game stops reconnecting")
	_guest.forget()


func test_a_person_who_leaves_ends_the_wait() -> void:
	_table()
	var ref = _referee()
	var asked := {"left": false, "at": Time.get_ticks_msec() + 150}
	var started := Time.get_ticks_msec()
	ref._close_table(_server, func() -> void:
		_server.poll()
		_guest.poll()
		if not asked.left and Time.get_ticks_msec() >= int(asked.at) and not _guest.busy():
			asked.left = _guest.command({"op": "leave"}), 3000)
	var took := Time.get_ticks_msec() - started
	assert_true(asked.left, "the person left")
	assert_lt(took, 2500, "the host closed once the table was empty (%d ms)" % took)
	_pump(func() -> bool: return not _guest._wanted, 2000)
	assert_eq(_guest.status, SgLocalServer.HOST_CLOSED)
	_guest.forget()


func test_an_empty_host_closes_at_once() -> void:
	_server = SgLocalServer.new()
	add_child_autofree(_server)
	_server.set_process(false)
	assert_eq(_server.start_lan("127.0.0.1", 0, false), OK)
	var ref = _referee()
	var started := Time.get_ticks_msec()
	ref._close_table(_server, func() -> void: _server.poll())
	assert_lt(Time.get_ticks_msec() - started, 200)
	assert_eq(_server.port, 0, "stopped")
