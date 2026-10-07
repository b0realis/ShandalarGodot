extends SceneTree
## THE REFEREE — ONE DUEL PLAYED THROUGH A PIPE (2026-09-27): a program
## holds a seat, the referee holds the rules. At every decision the
## seat's legal options and its whole view of the table go out on
## stdout as one JSON line; the program answers with one JSON action on
## stdin; the referee applies it or refuses it and asks again. The
## other seat is a shipped computer player (apprentice, magician,
## sorcerer, wizard, unfair), a second program-held seat (both seats
## then arrive on the same pipe, each line naming its `seat`), or —
## with `--join` — a person at a table the game's own lobby hosts, on
## this computer or over the LAN — or, with `--host`, a person who sits
## down at the table this referee hosts.
##
##   DeckLab/referee.sh --deck-a DECK --deck-b DECK [--seat-a agent]
##       [--seat-b wizard] [--seed N] [--turns N] [--packs LIST]
##       [--rules PRESET] [--log FILE] [--dry-run]
##   DeckLab/referee.sh --join INVITATION|CODE | --table NAME --deck DECK
##       [--port N] [--name NICK] [--wait SECONDS] [--turns N]
##       [--packs LIST] [--log FILE]
##   DeckLab/referee.sh --host NAME --deck DECK [--access open|invitation]
##       [--address IP] [--port N] [--name NICK] [--wait SECONDS]
##       [--turns N] [--packs LIST] [--rules PRESET] [--log FILE]
##   DeckLab/referee.sh ... --listen FILE [--idle SECONDS]
##   DeckLab/referee.sh -h | --help
##
## THE LINES. stdout carries nothing but JSON, one document a line:
## `hello` once (the seats, the seed, the toss, the ops), `decision`
## whenever a program-held seat must act, `refused` when its answer
## could not be applied (the decision stands; answer again), `result`
## once at the end, and `{"error": ...}` — the Lab's own envelope —
## when the line could not be run at all. stdin carries one action a
## line, the lobby's own wire actions ([constant SgProtocol.FIELDS]):
## `{"op": "pass"}`, `{"op": "play", "card": "c3"}`, `{"op":
## "prepare", "card": "c5", "kind": "spell", "index": 0, "x": 0,
## "mode": 0}` and so on. Blank lines are skipped; three empty reads in
## a row are the end of the input, and the seat concedes.
##
## THE KEPT GAME (2026-10-03). With `--listen FILE` the same lines are
## served on a loopback TCP socket instead of the pipe, so the program
## may go away and come back — a client restarted, a server that
## crashed — while the duel waits. The referee writes FILE once it
## listens ({port, token, pid, version, started}; the token is drawn
## here and never on a command line); a client connects to
## 127.0.0.1:port and sends `{"token": ..., "client": ...}` as its
## first line; the referee answers with `hello` again, one `resume`
## line ({decisions, refusals, awaiting, n, finished}) and, when a
## decision is awaited, that decision again with the WHOLE journal.
## One client at a time: a newcomer with the token replaces the last.
## A client that goes away leaves its whole lines to be read (a
## concession sent just before its socket closed is the next answer).
## stdout still carries every line (the transcript), stdin is not read.
## `--idle SECONDS` (1800; 0 never) concedes the seat when a decision
## has waited that long with nobody connected (`reason: idle`).
##
## THE TABLE BY NAME. `--table NAME` asks the LAN (SgLanDiscovery) for
## an OPEN host advertising a table of that name and joins with the
## invitation its advert carries — and sits at THAT table of the host's
## (campaign 2026-10-07; it took the host's first open one); an
## invitation-only host's table is named back as such — paste its
## invitation with `--join` instead.
##
## THE TABLE RECONNECTING (campaign 2026-10-07). A table is waited for
## while this seat's own client reconnects or the other seat is away (the
## host keeps an absent seat five minutes): an answer sent meanwhile is
## held and sent again once the table is whole, never counted among the
## refusals. `offline` ends the duel only when the client stops retrying
## or the wait outlasts the host's own grace.
##
## THE TABLE THE REFEREE HOSTS (2026-10-03). `--host NAME --deck DECK`
## runs the game's own LAN host (SgLocalServer) in this process, opens
## one table of that name at it with the program in seat 0, and prints
## one `table` line — the name, the access rule, the host's address and
## port, the invitation, whether the advert is out — before anything
## else. An OPEN table is listed in every Game Browser on the LAN and a
## person joins it by name; an INVITATION-ONLY table is listed without
## its secret, and the person pastes the invitation from the `table`
## line. The seat is kept ready while the lobby resets it (a guest
## sitting down, a guest's deck), `hello` comes when the duel starts,
## and `--wait` is how long the empty chair is held. The server stops
## with the result: the table lives as long as the duel.
##
## THE VIEW is [method SgPracticeMatch.view] as the lobby sends it to a
## guest — the same truth a person's screen is painted from, hidden
## information withheld the same way. `options` is derived FROM THAT
## VIEW ALONE ([method options_for]), so a program that reads the view
## itself and one that reads only the options see the same table.
##
## THE EXIT CODE says whether a duel was played, not who won: 0 for a
## `result` line (a concession on end-of-input is a result), 2 for a
## line that could not be run (a deck that will not load, an unknown
## seat, a table that could not be joined), 1 when a file could not be
## written.
##
## HOW IT IS RUN. Through the game's own door, in the checkout and in a
## release alike: `Shandalar --headless -- --referee ...` (game/main.gd
## loads this script and calls `_main`). Not as a `--script` main loop
## the way the Lab's other tools run: the lobby classes this one names
## — the referee, the wire protocol, the bot adapter — read the
## `CardPacks` autoload at compile time, and a `--script` is compiled
## before the autoloads exist (tools/lan_smoke.gd's own note). It still
## extends SceneTree because the door frees its tool with `free()`.

const Lab := preload("res://DeckLab/simulate.gd")

## The pipe's own version, bumped when a line's shape changes.
const PROTOCOL := 1
## What a seat may be: a program on the pipe, or a shipped player.
const SEATS := {"agent": {}, "apprentice": {"level": 0, "unfair": false},
	"magician": {"level": 1, "unfair": false}, "sorcerer": {"level": 2, "unfair": false},
	"wizard": {"level": 3, "unfair": false}, "unfair": {"level": 3, "unfair": true}}
## The wire actions a seat may send during a duel — every key of
## [constant SgProtocol.FIELDS] that is not a lobby or tournament op.
const DUEL_OPS := ["concede", "order", "keep", "mulligan", "pass", "play", "tap", "mana",
	"prepare", "autoprepare", "autopay", "submit", "cancel", "choice", "special",
	"attack", "attack_bands", "block", "damage", "discard", "discard_special"]
## What a line may leave out of these ops (2026-10-04); the referee fills
## it in before the wire's exact keys are checked ([method _parse_action]).
const DEFAULTS := {
	"prepare": {"kind": "spell", "index": 0, "x": 0, "mode": 0},
	"autoprepare": {"kind": "spell", "index": 0, "mode": 0, "excluded": [], "count": 1},
	"autopay": {"excluded": [], "count": 1},
	"submit": {"targets": []},
}
## The ops whose refusal may leave paid-for mana in the pool: their
## `refused` line says what is floating ([method _floating]).
const PAYING_OPS := ["prepare", "autoprepare", "autopay", "submit", "mana", "tap"]
const DEFAULT_TURNS := 200
const DEFAULT_PORT := 17897
const DEFAULT_WAIT := 300
## A kept game's patience: a decision nobody has come back for in this
## many seconds is conceded (`reason: idle`); 0 waits forever.
const DEFAULT_IDLE := 1800
## A kept game's socket: a knock (a connection that has not sent its
## token yet) is dropped after this long; the token line's own limit.
const KNOCK_MS := 5000
const LINE_LIMIT := 65536
## A program-held seat's decisions, over the whole duel, before the
## referee ends it (`reason: decisions`): a duel that long is a loop.
const MAX_DECISIONS := 20000
## Refused answers IN A ROW before the seat is conceded (`reason:
## refusals`): a program that cannot read its options is not playing.
const MAX_REFUSALS := 20
## THE TABLE RECONNECTING (campaign 2026-10-07): how long a table that is
## not whole — this seat's own client reconnecting, or the other seat away
## — is waited for before the duel is given up (`reason: offline`): the
## host's own grace for a disconnected seat (SgLocalServer
## .RECONNECT_GRACE_MS, five minutes, after which it concedes that seat
## itself) and half a minute more. A client that stops retrying (its
## `connecting()` false) is given up at once.
const RECONNECT_PATIENCE_MS := 330000
## The host's refusal of a game action while the other seat is away
## (SgLocalServer.SEAT_AWAY) and the client's own while its connection is
## down (SgLocalClient.NOT_CONNECTED): never the program's refusals.
const SEAT_AWAY := "Waiting for the other player to reconnect."
const NOT_CONNECTED := "Wait for the connection or the current action."
## A computer seat's steps without the table changing before the duel
## is called (`reason: stalled`).
const IDLE_BOT_STEPS := 100
## Empty reads in a row that mean the input has closed: Godot's stdin
## line reader returns "" for a blank line and for end-of-file alike.
const EMPTY_READS := 3
const BOT_PACE_MS := 50
## The lobby's refusal of a command that carried an old revision; it
## asks for the same command again, and a lobby command is sent again
## this many times (a game action is not — the seat decides afresh).
const ROOM_CHANGED := "The room changed. Please try again."
const LOBBY_TRIES := 5

const HELP := """Referee — one duel played through a pipe, a program in a seat
====================================================================
Every decision goes out on stdout as one JSON line (`decision`: the
seat, its legal `options`, its whole `view`); the answer comes back on
stdin as one JSON action (`{"op": "pass"}`); `refused` says why an
answer could not be applied, and the decision stands; `result` ends
the duel. Nothing but JSON is ever written to stdout.

USAGE
  DeckLab/referee.sh --deck-a DECK --deck-b DECK [--seat-a SEAT]
      [--seat-b SEAT] [--seed N] [--turns N] [--packs LIST] [--rules PRESET]
      [--log FILE] [--dry-run]
  DeckLab/referee.sh --join INVITATION|CODE | --table NAME --deck DECK
      [--port N] [--name NICK] [--wait SECONDS] [--turns N]
      [--packs LIST] [--log FILE]
  DeckLab/referee.sh --host NAME --deck DECK [--access open|invitation]
      [--address IP] [--port N] [--name NICK] [--wait SECONDS]
      [--turns N] [--packs LIST] [--rules PRESET] [--log FILE]
  DeckLab/referee.sh ... --listen FILE [--idle SECONDS]
  DeckLab/referee.sh -h | --help

SEATS  (--seat-a, --seat-b; default: agent vs wizard; at least one agent)
  agent       the program on the pipe (both seats: it plays itself)
  apprentice  magician  sorcerer  wizard   the shipped computer players
  unfair      the wizard that reads hidden cards, as the game offers it

SWITCHES
  --deck-a / --deck-b PATH  each seat's deck file, tried as typed and
                            then under decks/ (the Lab's own rule)
  --seed N                  the shuffle; unset, a random seed is drawn
                            and reported in `result` only (hello says
                            -1: the seed deals both hands)
  --turns N                 the duel is called a draw past turn N (200)
  --packs LIST              all|none|a,b: the card packs in play
  --log FILE                the duel's log at the end: the engine's own
                            lines (a local duel) or the journal the
                            seat saw (a joined table)
  --dry-run                 print the plan as JSON, play nothing
  --join TEXT               sit at a table the game hosts: a LAN
                            invitation (sglan1:...) or the same-computer
                            access code the host screen shows
  --table NAME              sit at the open LAN table of that name, as
                            the Game Browser lists it (no paste: the
                            open host's advert carries its invitation)
  --deck PATH               the deck to bring to that table
  --host NAME               host a table of that name yourself, with the
                            game's own LAN host, and hold seat 0 until a
                            person sits down (the `table` line says how
                            they find it)
  --access RULE             with --host: open (the Game Browser lists
                            the table and anyone on the LAN joins it by
                            name) or invitation (they paste the
                            invitation from the `table` line)
  --address IP              with --host: the LAN address to host on
                            (unset: this computer's first private IPv4)
  --port N                  the host's port: for an access code when
                            joining, to listen on with --host (17897;
                            0 is any free port)
  --name NICK               the seat's name at that table (Agent)
  --wait SECONDS            how long to wait for an open table, or with
                            --host for a guest (300)
  --listen FILE             serve the lines on a loopback socket instead
                            of the pipe and write {port, token, pid} to
                            FILE: the game is kept while the program is
                            away (see THE KEPT GAME above)
  --idle SECONDS            with --listen: concede a decision nobody
                            has come back for in that long (1800; 0 off)
  --rules PRESET            the rules forks: modern, modern_mana_burn
                            (the standard table, the default) or fifth
                            (the 1997 Fifth Edition rules: mana burn,
                            the damage-prevention window...); a local
                            duel or --host; reported in hello.rules

THE LINES (stdout)
  table     {id, name, access, host, address, port, invitation,
             discovery}  — with --host, once the table is open; a
             person joins it from the Game Browser by name (open) or by
             pasting the invitation (invitation); hello follows when
             they sit down and the duel starts
  hello     {tool, protocol, version, seed, seats[{seat, player, name,
             deck, file}], toss, turns, rules, ops}  — once, before play
  decision  {n, seat, mode, turn, step, options, view}
             mode: opening|priority|attack|block|discard|damage|choice
  refused   {n, seat, reason, action, left[, floating]}  — the decision
             follows again; floating {total, W..C} is mana a refused
             cast left in the pool (cancel withdraws the announcement)
  resume    {decisions, refusals, awaiting, n, finished}  — to a client
             that connects to a kept game (--listen), after hello
  result    {winner, draw, turns, reason, decisions, refusals, seed,
             life, names}  — reason: concluded|conceded|eof|refusals|
             limit|decisions|stalled|left|offline|idle
  error     {"error": {...}} — the Lab's envelope; nothing was played

THE ANSWERS (stdin), one JSON object a line, the game's wire actions
  opening   {"op":"order","play":true|false} (the toss winner, once)
            {"op":"keep"}  {"op":"mulligan"}
  priority  {"op":"pass"}
            {"op":"play","card":ID}                          a land
            {"op":"prepare","card":ID,"kind":"spell"|"ability",
             "index":I,"x":X,"mode":M}   then {"op":"autopay",
             "excluded":[],"count":1}    then {"op":"submit",
             "targets":[[TOKEN,AMOUNT]...]} — or "cancel"
            {"op":"autoprepare","card":ID,"kind":K,"index":I,"mode":M,
             "excluded":[],"count":1}  prepare and pay in one line;
             add "targets":[TARGET...] to submit it too, a TARGET being
             a card handle, player:0|player:1 or [TARGET,AMOUNT]
            left out: kind "spell", index 0, x 0, mode 0, excluded [],
             count 1 (the targets' count), targets [] — and a submit's
             TOKEN may be a card handle or player:N
            {"op":"mana","card":ID,"index":I}  {"op":"tap","card":ID}
            {"op":"special","index":I}
            {"op":"discard_special","card":ID}  a hand card that may be
             discarded any time an instant could be cast (Circling
             Vultures): options.discard_special.cards
  attack    {"op":"attack","cards":[ID...]}
            {"op":"attack_bands","cards":[ID...],"bands":[[ID...]...]}
  block     {"op":"block","pairs":[[BLOCKER,ATTACKER]...]}
  discard   {"op":"discard","cards":[ID...]}
  damage    {"op":"damage","points":[[ID|"player",N]...]}
  choice    {"op":"choice","picks":[I...]}  {"op":"cancel"}
  any time  {"op":"concede"}
  A line may carry "seat": it must be the seat the decision named.

EXIT CODES
  0  a result line was written (whatever the reason)
  2  the line could not be run: a deck, a seat, a switch, a table —
     {"error": {...}} on stdout
  1  a file could not be written
"""

const FLAG_HINTS := {
	"--deck-a": "--deck-a PATH: seat A's deck file, tried as typed and then under decks/",
	"--deck-b": "--deck-b PATH: seat B's deck file, tried as typed and then under decks/",
	"--seat-a": "--seat-a SEAT: who holds seat A — agent, apprentice, magician, sorcerer, wizard or unfair",
	"--seat-b": "--seat-b SEAT: who holds seat B — agent, apprentice, magician, sorcerer, wizard or unfair",
	"--seed": "--seed N: the shuffle, a non-negative integer; unset, one is drawn and reported in the result",
	"--turns": "--turns N: the turn past which the duel is called a draw (200)",
	"--packs": "--packs LIST: all, none, or the pack ids in play, comma-separated",
	"--log": "--log FILE: where to write the duel's log — the engine's lines, or a joined table's journal",
	"--join": "--join TEXT: a LAN invitation (sglan1:...) or the host screen's same-computer access code",
	"--table": "--table NAME: the open LAN table of that name, as the Game Browser lists it",
	"--deck": "--deck PATH: the deck to bring to a joined or hosted table",
	"--host": "--host NAME: host a table of that name with the game's own LAN host and hold seat 0 for a guest",
	"--access": "--access RULE: with --host, open (joined by name from the Game Browser) or invitation (pasted)",
	"--address": "--address IP: with --host, the LAN address to host on (unset: this computer's first private IPv4)",
	"--port": "--port N: the host's port — for an access code when joining, to listen on with --host (17897; 0 any)",
	"--name": "--name NICK: the seat's name at a joined or hosted table (Agent)",
	"--wait": "--wait SECONDS: how long to wait for the host's open table, or with --host for a guest (300)",
	"--listen": "--listen FILE: serve the lines on a loopback socket, the port and token written to FILE",
	"--idle": "--idle SECONDS: with --listen, concede a decision nobody has come back for in that long (1800; 0 never)",
	"--rules": "--rules PRESET: the rules forks the duel plays under — modern, modern_mana_burn (the standard table) or fifth (the 1997 Fifth Edition rules)",
}

## THE TWO ENDS OF THE PIPE, as Callables so a test can hold both:
## `reader` returns the next line of input, or null once it has closed;
## `writer` takes one line for stdout.
var reader: Callable
var writer: Callable
var last_error: Dictionary = {}
var last_hello: Dictionary = {}
## The `table` line of a hosted table, replayed to a kept game's client
## before hello.
var last_table: Dictionary = {}
var last_decision: Dictionary = {}
var last_result: Dictionary = {}
var last_plan: Dictionary = {}
var decisions := 0
var refusals := 0
## [constant RECONNECT_PATIENCE_MS], shortened by a test.
var reconnect_patience_ms := RECONNECT_PATIENCE_MS
var _empty_reads := 0
var _journal_sent: Array[int] = [0, 0]
# The pump: a joined table's socket must keep being polled while the
# program thinks, so at a table the input is read on a thread and taken
# here; a local duel has nothing to keep alive and reads inline.
var _pump: Thread
var _pump_lock := Mutex.new()
var _pump_want := Semaphore.new()
var _pump_lines: Array = []
var _pump_stop := false
var _pump_pending := 0
# The kept game (--listen): the loopback server, the one client it
# serves (`_peer`, once its token line was read), the knock still to
# send its token, the handshake file's path, and what a client that
# comes back is told — whether a decision is awaited and the whole
# journal of the view it was asked from.
var _server: TCPServer
var _peer: StreamPeerTCP
var _peer_buffer := PackedByteArray()
var _knock: StreamPeerTCP
var _knock_buffer := PackedByteArray()
var _knock_since := 0
var _token := ""
var _listen_path := ""
var _idle_ms := 0
var _idle_since := 0
var _awaiting := false
var _last_journal: Array = []
var _eof_reason := ""
## The UDP port a hosted table is advertised on; a test's own host
## takes an ephemeral one so the system-wide port stays free.
var discovery_port: int = SgLanDiscovery.PORT


func _init() -> void:
	reader = _read_stdin
	writer = _write_stdout


# ---------------------------------------------------------- the pipe --

func _read_stdin() -> Variant:
	while true:
		var line := OS.read_string_from_stdin(65536)
		if line != "":
			_empty_reads = 0
			return line
		_empty_reads += 1
		if _empty_reads >= EMPTY_READS:
			return null
	return null


func _write_stdout(line: String) -> void:
	print(line)


## One line out: in a kept game to the client on the socket (a knock
## waiting there is seated first, and told where the duel stands), then
## to the writer — stdout, or a test's collector.
func _emit(record: Dictionary) -> void:
	var text := JSON.stringify(record)
	if _server != null:
		_serve()
		_send_peer(text)
	writer.call(text)


func _refuse(exit: int, message: String, detail: Dictionary = {}) -> int:
	printerr("referee: %s" % message)
	last_error = LabConsole.error_record("referee", exit, message, detail)
	_emit({"error": last_error})
	return exit


## The next line of input, or null when it has closed. [param tick] is
## called while a table's pump is being waited on (the socket's poll).
func _next_line(tick: Callable) -> Variant:
	if _server != null:
		return _read_socket(tick)
	if _pump == null:
		return reader.call()
	_pump_pending += 1
	_pump_want.post()
	while true:
		_pump_lock.lock()
		var ready := not _pump_lines.is_empty()
		var line: Variant = _pump_lines.pop_front() if ready else null
		_pump_lock.unlock()
		if ready:
			_pump_pending -= 1
			return line
		tick.call()
	return null


func _pump_start() -> void:
	_pump_stop = false
	_pump_lines.clear()
	_pump_pending = 0
	_pump = Thread.new()
	_pump.start(_pump_run)


func _pump_run() -> void:
	while true:
		_pump_want.wait()
		if _pump_stop:
			return
		var line: Variant = reader.call()
		_pump_lock.lock()
		_pump_lines.append(line)
		_pump_lock.unlock()
		if line == null:
			return


## Stops the pump. A read the program never answered is waited out —
## the result line is already on stdout, and the program's next line or
## its closing the pipe ends the wait.
func _pump_finish() -> void:
	if _pump == null:
		return
	_pump_stop = true
	_pump_want.post()
	_pump.wait_to_finish()
	_pump = null


# ------------------------------------------------------ the kept game --

## Opens the loopback socket and writes the handshake file (as .part,
## then renamed: a client never reads half a record). Returns "" or the
## refusal. From here on every line is sent to the seated client as
## well, and `_next_line` reads the socket; the pump is never started.
func _listen_start(path: String, idle_seconds: int) -> String:
	_server = TCPServer.new()
	var error := _server.listen(0, "127.0.0.1")
	if error != OK:
		_server = null
		return "cannot listen on the loopback: %s" % error_string(error)
	_token = Crypto.new().generate_random_bytes(16).hex_encode()
	_listen_path = path
	_idle_ms = idle_seconds * 1000
	_idle_since = Time.get_ticks_msec()
	var record := {"port": _server.get_local_port(), "token": _token, "pid": OS.get_process_id(),
		"version": LabConsole.version(), "started": Time.get_datetime_string_from_system()}
	var part := path + ".part"
	var file := FileAccess.open(part, FileAccess.WRITE)
	if file == null:
		_listen_stop()
		return "cannot write the handshake at '%s'" % path
	file.store_string(JSON.stringify(record) + "\n")
	file.close()
	var moved := DirAccess.rename_absolute(ProjectSettings.globalize_path(part), ProjectSettings.globalize_path(path))
	if moved != OK:
		_listen_stop()
		return "cannot write the handshake at '%s': %s" % [path, error_string(moved)]
	return ""


## Closes the socket; the handshake file stays for whoever reads the
## transcript (the server that keeps the registry removes both).
func _listen_stop() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
	if _knock != null:
		_knock.disconnect_from_host()
		_knock = null
	if _server != null:
		_server.stop()
		_server = null


func _send_peer(line: String) -> void:
	if _peer != null and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_peer.put_data((line + "\n").to_utf8_buffer())


## One line from the kept game's client, or null once a decision has
## waited `--idle` long with nobody connected (`_eof_reason` = idle).
## The server is polled here — no frame runs while the program thinks.
## A whole line a client sent before it went away is still read
## ([method _serve] keeps it): `referee_stop`'s concession, sent between
## two decisions just before its socket closed, is the next answer.
func _read_socket(tick: Callable) -> Variant:
	while true:
		tick.call()
		_serve()
		var cut := _cut_line(_peer_buffer)
		if not cut.is_empty():
			_peer_buffer = cut.rest
			return String(cut.line)
		if _peer != null:
			if _peer_buffer.size() > LINE_LIMIT:
				_peer_buffer = PackedByteArray()
		elif _awaiting and _idle_ms > 0 and Time.get_ticks_msec() - _idle_since >= _idle_ms:
			_eof_reason = "idle"
			return null
		OS.delay_msec(10)
	return null


## Takes a knock, reads its token line, seats the client (dropping the
## last one) and replays what it needs; reads the seated client's bytes.
func _serve() -> void:
	var now := Time.get_ticks_msec()
	if _knock == null and _server.is_connection_available():
		_knock = _server.take_connection()
		_knock.set_no_delay(true)
		_knock_buffer = PackedByteArray()
		_knock_since = now
	if _knock != null:
		var got := _drain(_knock, _knock_buffer)
		_knock_buffer = got.bytes
		var cut := _cut_line(_knock_buffer)
		if not cut.is_empty():
			var parsed = JSON.parse_string(String(cut.line))
			_knock_buffer = cut.rest
			if parsed is Dictionary and parsed.get("token") is String and String(parsed.token) == _token:
				# A live client replaced takes its unread bytes with it; the
				# whole lines one that had already gone left are read first.
				if _peer != null:
					_peer.disconnect_from_host()
					_peer_buffer = PackedByteArray()
				_peer = _knock
				_peer_buffer.append_array(_knock_buffer)
				_knock = null
				_replay()
			else:
				printerr("referee: a connection without the token was dropped")
				_knock.disconnect_from_host()
				_knock = null
		elif not bool(got.alive) or now - _knock_since > KNOCK_MS or _knock_buffer.size() > LINE_LIMIT:
			_knock.disconnect_from_host()
			_knock = null
	if _peer != null:
		var got := _drain(_peer, _peer_buffer)
		_peer_buffer = got.bytes
		if not bool(got.alive):
			# A CLIENT GONE KEEPS ITS WHOLE LINES (campaign 2026-10-07):
			# `referee_stop` on a kept game with no decision pending sends
			# its concession and closes the socket; the buffer was dropped
			# with the client and the duel played on for nobody until
			# `--idle`. Only a line cut off mid-way goes.
			_peer = null
			_peer_buffer = _whole_lines(_peer_buffer)
			_idle_since = now


## [param buffer] up to and including its last newline: the whole lines.
static func _whole_lines(buffer: PackedByteArray) -> PackedByteArray:
	var last := buffer.rfind(10)
	return buffer.slice(0, last + 1) if last >= 0 else PackedByteArray()


## Polls one connection and appends the bytes that arrived: {bytes,
## alive}. BYTES, NOT TEXT (2026-10-03): each read used to be decoded on
## its own, so a character whose UTF-8 bytes straddled two reads became
## two replacement marks — a nickname or a name in an action garbled, or
## a line that no longer parsed as JSON.
static func _drain(peer: StreamPeerTCP, buffer: PackedByteArray) -> Dictionary:
	peer.poll()
	var status := peer.get_status()
	if status != StreamPeerTCP.STATUS_CONNECTED:
		return {"bytes": buffer, "alive": status == StreamPeerTCP.STATUS_CONNECTING}
	var pending := peer.get_available_bytes()
	if pending > 0:
		var chunk: Array = peer.get_data(pending)
		if int(chunk[0]) == OK:
			buffer.append_array(PackedByteArray(chunk[1]))
	return {"bytes": buffer, "alive": true}


## The first whole line of [param buffer], decoded, and the bytes after
## it: {line, rest} — or {} while its newline has not arrived.
static func _cut_line(buffer: PackedByteArray) -> Dictionary:
	var cut := buffer.find(10)
	if cut < 0:
		return {}
	return {"line": buffer.slice(0, cut).get_string_from_utf8(), "rest": buffer.slice(cut + 1)}


## What a client that (re)connects is told: hello again, where the duel
## stands, and the awaited decision with the whole journal — a client
## that was away has no idea what it missed.
func _replay() -> void:
	if not last_table.is_empty():
		_send_peer(JSON.stringify(last_table))
	if not last_hello.is_empty():
		_send_peer(JSON.stringify(last_hello))
	_send_peer(JSON.stringify({"type": "resume", "decisions": decisions, "refusals": refusals,
		"awaiting": _awaiting, "n": int(last_decision.get("n", 0)) if _awaiting else 0,
		"finished": not last_result.is_empty()}))
	if _awaiting:
		var again := last_decision.duplicate()
		var view: Dictionary = again.view.duplicate()
		view["journal"] = _last_journal
		again["view"] = view
		_send_peer(JSON.stringify(again))


# ------------------------------------------------------ the arguments --

func _parse_args(argv: PackedStringArray) -> Dictionary:
	var opts := {"deck_a": "", "deck_b": "", "seat_a": "agent", "seat_b": "wizard",
		"seed": -1, "turns": DEFAULT_TURNS, "packs": "", "log": "", "dry_run": false,
		"join": "", "table": "", "deck": "", "port": DEFAULT_PORT, "name": "Agent", "wait": DEFAULT_WAIT,
		"host": "", "access": "open", "address": "", "listen": "", "idle": DEFAULT_IDLE, "rules": ""}
	var i := 0
	while i < argv.size():
		var arg := String(argv[i])
		if arg == "--dry-run":
			opts.dry_run = true
			i += 1
			continue
		if not FLAG_HINTS.has(arg):
			var detail := {"kind": "option", "flag": arg}
			var near := LabConsole.closest(arg, PackedStringArray(FLAG_HINTS.keys() + ["--dry-run"]), 2)
			var message := "unknown option '%s'" % arg
			if not near.is_empty():
				detail["suggestions"] = Array(near)
				message += " — did you mean %s?" % " or ".join(near)
			return {"error": {"message": message, "detail": detail}}
		if i + 1 >= argv.size():
			return {"error": {"message": "%s needs a value  (%s)" % [arg, FLAG_HINTS[arg]],
				"detail": {"kind": "option", "flag": arg}}}
		var value := String(argv[i + 1])
		i += 2
		match arg:
			"--deck-a": opts.deck_a = value
			"--deck-b": opts.deck_b = value
			"--seat-a", "--seat-b":
				var seat := value.to_lower()
				if not SEATS.has(seat):
					var detail := {"kind": "option", "flag": arg, "seats": SEATS.keys()}
					var near := LabConsole.closest(seat, PackedStringArray(SEATS.keys()), 1)
					if not near.is_empty():
						detail["suggestions"] = Array(near)
					return {"error": {"message": "unknown seat '%s' for %s — the seats are %s" % [value, arg, ", ".join(SEATS.keys())],
						"detail": detail}}
				opts["seat_a" if arg == "--seat-a" else "seat_b"] = seat
			"--seed", "--turns", "--port", "--wait", "--idle":
				if not value.is_valid_int() or int(value) < 0:
					return {"error": {"message": "%s wants a non-negative integer, not '%s'" % [arg, value],
						"detail": {"kind": "option", "flag": arg}}}
				opts[arg.trim_prefix("--")] = int(value)
			"--packs": opts.packs = value
			"--log": opts.log = value
			"--join": opts.join = value.strip_edges()
			"--table": opts.table = value.strip_edges()
			"--deck": opts.deck = value
			"--name": opts.name = value.strip_edges()
			"--host": opts.host = value.strip_edges()
			"--access":
				var rule := value.to_lower().strip_edges()
				if not rule in SgLanDiscovery.ACCESS:
					return {"error": {"message": "--access is open or invitation, not '%s'" % value,
						"detail": {"kind": "option", "flag": "--access", "rules": SgLanDiscovery.ACCESS}}}
				opts.access = rule
			"--address": opts.address = value.strip_edges()
			"--listen": opts.listen = value
			"--rules":
				var preset := value.to_lower().strip_edges()
				if RulesOptions.find_preset(preset).is_empty():
					var ids := rule_presets()
					var detail := {"kind": "option", "flag": "--rules", "presets": ids}
					var near := LabConsole.closest(preset, PackedStringArray(ids), 2)
					if not near.is_empty():
						detail["suggestions"] = Array(near)
					return {"error": {"message": "unknown rules '%s' for --rules — the presets are %s" % [value, ", ".join(ids)],
						"detail": detail}}
				opts.rules = preset
	return opts


## A deck file the way the Lab finds one — as typed, then under decks/
## — loaded strictly: a line the parser refuses or a name the pool does
## not know is a refusal with the `check` query's own report attached,
## so the program reads what to fix. Returns {deck, file} or {error}.
func _load_deck(typed: String, flag: String) -> Dictionary:
	var tries := [typed, "decks/" + typed, "res://decks/" + typed]
	var found := ""
	for candidate in tries:
		if FileAccess.file_exists(candidate):
			found = candidate
			break
	if found == "":
		var lab = Lab.new()
		var near: PackedStringArray = Lab.suggest_decks(typed, lab._every_shipped_deck())
		lab.free()
		var detail := {"kind": "deck", "flag": flag, "path": typed, "tried": tries}
		if not near.is_empty():
			detail["suggestions"] = Array(near)
		return {"error": {"message": "deck file not found: '%s'" % typed, "detail": detail}}
	var Query = load("res://DeckLab/lab_query.gd")
	var report: Dictionary = Query.deck_report(found, "")
	if not bool(report.playable):
		# The report's own errors stay its own: a copy takes the unknowns.
		var problems: Array = report.errors.duplicate()
		for entry in report.unknown:
			problems.append("%s: not in the card pool%s" % [entry.name,
				"" if entry.pack == "" else " (pack %s)" % entry.pack])
		return {"error": {"message": "%s cannot be played: %s" % [typed, "; ".join(problems)],
			"detail": {"kind": "deck", "flag": flag, "path": found, "problems": problems,
				"report": report}}}
	var deck := DeckList.load_file(found)
	var refusal := SgDeckCatalog.validate(deck.cards, deck.sideboard)
	if refusal != "":
		return {"error": {"message": "%s cannot be played: %s" % [typed, refusal],
			"detail": {"kind": "deck", "flag": flag, "path": found, "problems": [refusal]}}}
	return {"deck": {"name": deck.deck_name, "cards": Array(deck.cards),
		"sideboard": Array(deck.sideboard), "printings": deck.printings}, "file": found}


static func _seat_name(player: String, other: String, letter: String) -> String:
	if player == "agent":
		return "Agent %s" % letter if other == "agent" else "Agent"
	return SgBotPlayer.label(SEATS[player])


## THE RULES A DUEL PLAYS UNDER (2026-10-04): `--rules` names one of the
## Options screen's presets ([constant RulesOptions.PRESETS]); unset, the
## standard table every SGManalink host opens (modern rules, mana burn
## on — [constant RulesOptions.DEFAULT_PRESET]).
static func rule_presets() -> Array:
	var ids: Array = []
	for preset in RulesOptions.PRESETS:
		ids.append(String(preset.id))
	return ids


## The preset id a duel plays under: [param chosen], or the default.
static func rules_name(chosen: String) -> String:
	return chosen if chosen != "" else RulesOptions.DEFAULT_PRESET


## The table rules ([SgTableRules]) of preset [param chosen] at the
## standard 20 life.
static func table_rules(chosen: String) -> Dictionary:
	var options := RulesOptions.new()
	options.set_preset(rules_name(chosen))
	return SgTableRules.from_options(SgTableRules.DEFAULT_LIFE, options)


static func _bot_options(player: String) -> Dictionary:
	return {"level": int(SEATS[player].level), "unfair": bool(SEATS[player].unfair), "pace_ms": BOT_PACE_MS}


func _main(argv: PackedStringArray) -> int:
	if argv.is_empty() or argv[0] == "-h" or argv[0] == "--help":
		print(HELP)
		return 0
	if argv[0] == "-V" or argv[0] == "--version":
		print("referee %s" % LabConsole.version())
		return 0
	var opts := _parse_args(argv)
	if opts.has("error"):
		return _refuse(2, opts.error.message, opts.error.detail)
	if opts.join != "" and opts.table != "":
		return _refuse(2, "--join and --table name two tables — give one  (%s)" % FLAG_HINTS["--table"],
			{"kind": "option", "flag": "--table"})
	if opts.rules != "" and (opts.join != "" or opts.table != ""):
		return _refuse(2, "--rules is the host's to choose — a joined table plays its host's rules (they are in hello.rules)  (%s)" % FLAG_HINTS["--rules"],
			{"kind": "option", "flag": "--rules"})
	if opts.host != "" and (opts.join != "" or opts.table != ""):
		return _refuse(2, "--host opens a table of its own; it does not go with --join or --table  (%s)" % FLAG_HINTS["--host"],
			{"kind": "option", "flag": "--host"})
	if opts.listen != "":
		var refusal := _listen_start(String(opts.listen), int(opts.idle))
		if refusal != "":
			return _refuse(1, refusal, {"kind": "out", "flag": "--listen", "path": opts.listen})
	var code := _play(opts)
	_listen_stop()
	return code


func _play(opts: Dictionary) -> int:
	CardRegistry.ensure_loaded()
	var packs: Variant = null
	if opts.packs != "":
		var chosen: Dictionary = Lab.parse_packs(opts.packs, Lab.available_packs())
		if chosen.has("error"):
			return _refuse(2, chosen.error, {"kind": "packs", "flag": "--packs"})
		var refusal: String = Lab.enable_packs(chosen.ids)
		if refusal != "":
			return _refuse(2, refusal, {"kind": "packs", "flag": "--packs"})
		packs = chosen.ids
	if opts.join != "" or opts.table != "":
		return _join(opts, packs)
	if opts.host != "":
		return _host(opts, packs)
	for flag in ["--deck-a", "--deck-b"]:
		if opts[flag.trim_prefix("--").replace("-", "_")] == "":
			return _refuse(2, "%s is required — the referee plays two named decks  (%s)" % [flag, FLAG_HINTS[flag]],
				{"kind": "option", "flag": flag})
	if opts.seat_a != "agent" and opts.seat_b != "agent":
		return _refuse(2, "at least one seat must be the agent — %s vs %s has nobody on the pipe (the Lab plays computer duels)" % [opts.seat_a, opts.seat_b],
			{"kind": "option", "flag": "--seat-a", "seats": SEATS.keys()})
	var loaded: Array = []
	for flag in ["--deck-a", "--deck-b"]:
		var one := _load_deck(opts[flag.trim_prefix("--").replace("-", "_")], flag)
		if one.has("error"):
			return _refuse(2, one.error.message, one.error.detail)
		loaded.append(one)
	var seed_value := int(opts.seed)
	if seed_value < 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		seed_value = rng.randi_range(0, 2147483647)
	var players := [String(opts.seat_a), String(opts.seat_b)]
	var names := [_seat_name(players[0], players[1], "A"), _seat_name(players[1], players[0], "B")]
	var seats: Array = []
	for pid in 2:
		seats.append({"seat": pid, "player": players[pid], "name": names[pid],
			"deck": loaded[pid].deck.name, "file": loaded[pid].file})
	if opts.dry_run:
		last_plan = {"dry_run": true, "tool": "referee", "protocol": PROTOCOL, "version": LabConsole.version(),
			"seats": seats, "seed": seed_value, "turns": int(opts.turns), "packs": packs,
			"packs_on": Lab.packs_on(), "log": opts.log, "ops": DUEL_OPS, "rules": rules_name(String(opts.rules))}
		_emit(last_plan)
		return 0
	var m := SgPracticeMatch.new(seed_value, [loaded[0].deck, loaded[1].deck], names, table_rules(String(opts.rules)))
	for pid in 2:
		if players[pid] != "agent" and not m.set_bot(pid, _bot_options(players[pid])):
			return _refuse(1, "seat %d could not be given to the %s" % [pid, players[pid]], {"kind": "option"})
	# A DRAWN SEED IS THE RESULT'S, NOT HELLO'S (campaign 2026-10-07): the
	# seed and the two deck files deal both opening hands and order both
	# libraries, so a seat told it before play could replay the duel
	# beside it and read the opponent's hidden hand (CONTRIBUTING.md hard
	# rule 8). Hello says -1, as at a table; the result names it for the
	# replay. A seed the caller chose is theirs already and is echoed.
	_hello({"seats": seats, "seed": int(opts.seed), "toss": m.toss_winner, "turns": int(opts.turns), "rules": rules_name(String(opts.rules)),
		"packs": packs, "log": opts.log})
	var result := _referee_local(m, int(opts.turns))
	result["seed"] = seed_value
	if opts.log != "":
		var written := _write_log(opts.log, Array(m.game.log_lines))
		if written != "":
			return _refuse(1, written, {"kind": "out", "flag": "--log", "path": opts.log})
		result["log"] = opts.log
	return _result(result)


## The duel's log, one line each; "" or the refusal.
func _write_log(path: String, lines: Array) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "cannot write the log at '%s'" % path
	file.store_string("\n".join(PackedStringArray(lines)) + "\n")
	file.close()
	return ""


func _hello(extra: Dictionary) -> void:
	var record := {"type": "hello", "tool": "referee", "protocol": PROTOCOL,
		"version": LabConsole.version(), "git": LabConsole.git_sha(), "ops": DUEL_OPS,
		"limits": {"decisions": MAX_DECISIONS, "refusals": MAX_REFUSALS}}.merged(extra)
	# Emitted before it is remembered: a kept game's client seated by
	# this very emit is replayed what came before, and hello comes next.
	_emit(record)
	last_hello = record


func _result(record: Dictionary) -> int:
	last_result = {"type": "result"}.merged(record)
	last_result["decisions"] = decisions
	last_result["refusals"] = refusals
	_emit(last_result)
	return 0


# --------------------------------------------------- the local duel --

## A duel in this process: the computer seats step between the
## program's decisions; the table's stillness is the stall detector.
func _referee_local(m: SgPracticeMatch, turns: int) -> Dictionary:
	var idle := 0
	var reason := ""
	while reason == "":
		var state := m.decision_state()
		if state.mode == "finished":
			reason = "concluded"
			break
		if m.game.turn_number > turns:
			reason = "limit"
			break
		var actor := int(state.actor)
		if m.bots.has(actor):
			var before := _mark(m, state)
			SgBotPlayer.step(m, m.bots[actor])
			idle = 0 if _mark(m, m.decision_state()) != before else idle + 1
			if idle >= IDLE_BOT_STEPS:
				reason = "stalled"
			continue
		if decisions >= MAX_DECISIONS:
			reason = "decisions"
			break
		idle = 0
		reason = _ask(actor, String(state.mode),
			func() -> Dictionary: return m.view(actor),
			func(action: Dictionary) -> String: return m.act(actor, action),
			func() -> void: pass)
	if reason in ["eof", "idle", "refusals"] and not m.game.game_over:
		m.act(_conceding(m), {"op": "concede"})
	var life: Array = []
	for pid in 2:
		life.append(m.game.players[pid].life)
	return {"winner": -1 if reason in ["limit", "stalled", "decisions"] else int(m.game.winner),
		"draw": bool(m.game.is_draw) if m.game.game_over else true, "turns": int(m.game.turn_number),
		"reason": reason, "life": life, "names": [m.game.players[0].player_name, m.game.players[1].player_name]}


func _conceding(m: SgPracticeMatch) -> int:
	var state := m.decision_state()
	return int(state.actor) if int(state.actor) in [0, 1] else 0


static func _mark(m: SgPracticeMatch, state: Dictionary) -> Array:
	return [m.state_generation, state.mode, state.actor, m.game.turn_number,
		m.game.current_step(), m.game.stack.size(), m.game.priority_player]


# ------------------------------------------------------ one decision --

## Asks the program for one decision and applies its answer. Returns ""
## once an answer was applied, "conceded" for a concession, "eof" when
## the input closed, "refusals" when too many answers in a row could
## not be applied. [param fresh] builds the seat's current view, [param
## apply] applies an action and returns the refusal, [param tick] keeps
## a table alive while the program thinks. [param stop], when given, is
## asked after a refusal: a reason ("offline": the table is gone for good)
## ends the duel there, uncounted and unasked again.
func _ask(seat: int, mode: String, fresh: Callable, apply: Callable, tick: Callable,
		stop: Callable = Callable()) -> String:
	decisions += 1
	var n := decisions
	var view: Dictionary = fresh.call()
	_decision(n, seat, mode, view)
	var consecutive := 0
	while true:
		var line: Variant = _next_line(tick)
		if line == null:
			_awaiting = false
			return "idle" if _eof_reason == "idle" else "eof"
		var text := String(line).strip_edges()
		if text == "":
			continue
		var parsed := _parse_action(text, seat)
		var refusal := ""
		var action: Dictionary = parsed.get("action", {})
		if parsed.has("refusal"):
			refusal = String(parsed.refusal)
		else:
			refusal = _apply_line(parsed, apply, fresh)
			if refusal == "":
				_awaiting = false
				return "conceded" if action.op == "concede" else ""
		var ended := String(stop.call()) if stop.is_valid() else ""
		if ended != "":
			_awaiting = false
			return ended
		consecutive += 1
		refusals += 1
		# THE DECISION IS ASKED AGAIN, as a `decision` line with the same
		# `n` — so a program acts on decision lines alone and a `refused`
		# is only the reason. From the live view: a refusal can still
		# have moved the table (a payment step that tapped before it
		# failed), and the options must say what is legal NOW.
		view = fresh.call()
		var shown := action.duplicate()
		if parsed.has("targets"):
			shown["targets"] = parsed.targets
		var record := {"type": "refused", "n": n, "seat": seat, "reason": refusal, "action": shown,
			"left": MAX_REFUSALS - consecutive}
		# PAID FOR AND REFUSED (2026-10-04): mana a refused cast leaves in
		# the pool is said, not left to burn silently at the end of the
		# step; the announcement stays open and `cancel` withdraws it.
		if PAYING_OPS.has(String(action.get("op", ""))):
			var floating := _floating(view, seat)
			if not floating.is_empty():
				record["floating"] = floating
		_emit(record)
		if consecutive >= MAX_REFUSALS:
			return "refusals"
		_decision(n, seat, mode, view)
	return ""


## One parsed line applied through [param apply] (one wire action →
## its refusal), [param fresh] building the seat's live view between the
## steps. A `submit` naming card handles or players has them read as the
## open announcement's tokens first ([method _tokens_for]).
##
## THE THREE IN ONE (2026-10-04): an `autoprepare` that carries `targets`
## is the wire's `prepare` at X 0 — nothing paid — to read the
## announcement and find every target among its candidates; a target that
## is not there cancels it and refuses the line with NOTHING TAPPED. Then
## the wire's own `autoprepare` (prepare, X, auto-pay) and `submit`. A
## question the payment holds the duel on (a Fellwar Stone's colour, which
## Forest to return) ends the line there: answered, the announcement is
## still open for its `submit`.
func _apply_line(parsed: Dictionary, apply: Callable, fresh: Callable) -> String:
	var action: Dictionary = parsed.action
	if action.op == "submit":
		var named: Variant = _tokens_for(fresh.call(), action.targets)
		if named is String:
			return named
		return String(apply.call({"op": "submit", "targets": named}))
	if not parsed.has("targets"):
		return String(apply.call(action))
	var pairs: Array = parsed.targets
	var looked := String(apply.call({"op": "prepare", "card": action.card, "kind": action.kind,
		"index": action.index, "x": 0, "mode": action.mode}))
	if looked != "":
		return looked
	var named: Variant = _tokens_for(fresh.call(), pairs)
	var withdrawn := String(apply.call({"op": "cancel"}))
	if named is String:
		return named
	if withdrawn != "":
		return withdrawn
	var paid := String(apply.call(action))
	if paid != "":
		return paid
	var now: Dictionary = fresh.call()
	if String(now.get("mode", "")) != "priority" or Dictionary(now.get("announcement", {})).is_empty():
		return ""
	named = _tokens_for(now, pairs)
	if named is String:
		return named
	return String(apply.call({"op": "submit", "targets": named}))


## [param pairs] (`[target, amount]`) with every target read as a token of
## [param view]'s open announcement: a token as it is; a card handle
## (`c7`), `player:0`/`player:1`, `ability:oN` or `damage:oN` — what
## `presentation.targets` says each token stands for — as the candidate
## of the first slot, at or after the last one filled, that lists it and
## has room. List them in slot order. Returns the pairs or the refusal.
static func _tokens_for(view: Dictionary, pairs: Array) -> Variant:
	var announcement: Dictionary = view.get("announcement", {})
	if announcement.is_empty():
		return "No announcement is waiting."
	var refs := {}
	for row in Dictionary(view.get("presentation", {})).get("targets", []):
		var ref: Dictionary = row.get("ref", {})
		if ref.is_empty():
			continue
		refs[String(row.token)] = String(ref.id) if ref.kind == "card" else "%s:%s" % [ref.kind, ref.id]
	var slots: Array = announcement.get("slots", [])
	var out: Array = []
	var taken := {}
	var filled := {}
	var at := 0
	for pair in pairs:
		var wanted := String(pair[0])
		if refs.has(wanted) or (not wanted.contains(":") and wanted.begins_with("t")):
			out.append([wanted, int(pair[1])])
			continue
		var found := ""
		while at < slots.size():
			if int(filled.get(at, 0)) < int(slots[at].max):
				for target in slots[at].targets:
					if refs.get(String(target.id), "") == wanted and not taken.has(String(target.id)):
						found = String(target.id)
						break
			if found != "":
				break
			at += 1
		if found == "":
			var named: Array = []
			for slot in slots:
				for target in slot.targets:
					named.append("%s (%s)" % [refs.get(String(target.id), String(target.id)), target.label])
			return "target %s is not among the announcement's candidates%s" % [wanted,
				"" if named.is_empty() else ": " + ", ".join(PackedStringArray(named))]
		taken[found] = true
		filled[at] = int(filled.get(at, 0)) + 1
		out.append([found, int(pair[1])])
	return out


## The seat's floating mana as its view tells it — `{total, W, U, B, R,
## G, C}` with the colours it holds — or {} when the pool is empty.
static func _floating(view: Dictionary, seat: int) -> Dictionary:
	var players: Array = view.get("players", [])
	if seat < 0 or seat >= players.size():
		return {}
	var player: Dictionary = players[seat]
	var total := int(player.get("mana", 0))
	if total <= 0:
		return {}
	var out := {"total": total}
	var colors: Array = player.get("mana_colors", [])
	var letters := ["W", "U", "B", "R", "G", "C"]
	for i in mini(colors.size(), letters.size()):
		if int(colors[i]) > 0:
			out[letters[i]] = int(colors[i])
	return out


func _decision(n: int, seat: int, mode: String, view: Dictionary) -> void:
	var shown := view.duplicate()
	var fresh: Array = []
	for entry in view.get("journal", []):
		if int(entry.serial) > _journal_sent[seat]:
			fresh.append(entry)
			_journal_sent[seat] = int(entry.serial)
	shown["journal"] = fresh
	last_decision = {"type": "decision", "n": n, "seat": seat, "mode": mode,
		"turn": int(view.get("turn", 0)), "step": String(view.get("step", "")),
		"options": options_for(view, seat), "view": shown}
	# A kept game's client that comes back is told this decision again,
	# with every journal entry — not only the ones since the last line.
	# Awaited only once emitted: a client seated by this emit gets the
	# decision from the emit, not from the replay as well.
	_last_journal = Array(view.get("journal", []))
	_emit(last_decision)
	_awaiting = true
	if _peer == null:
		_idle_since = Time.get_ticks_msec()


## One line of input as an action for [param seat], or the refusal that
## keeps it off the table: not JSON, not an object, an op that is not a
## duel op, keys that are not that op's ([constant SgProtocol.FIELDS]),
## a value the wire would not carry, or a `seat` that is not this one.
static func _parse_action(text: String, seat: int) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {"refusal": "not a JSON object: %s" % text.left(80), "action": {}}
	var action: Dictionary = json.data
	if action.has("seat"):
		if not SgProtocol.integer(action.seat, 0, 1) or int(action.seat) != seat:
			var typed: String = str(int(action.seat)) if SgProtocol.integer(action.seat, -1000, 1000) else str(action.seat)
			return {"refusal": "this decision is seat %d's, not seat %s's" % [seat, typed], "action": action}
		action = action.duplicate()
		action.erase("seat")
	var op: Variant = action.get("op")
	if not op is String or not DUEL_OPS.has(op):
		var near := LabConsole.closest(str(op), PackedStringArray(DUEL_OPS), 1)
		return {"refusal": "unknown op '%s' — the duel ops are %s%s" % [str(op), ", ".join(DUEL_OPS),
			"" if near.is_empty() else " (did you mean %s?)" % near[0]], "action": action}
	# THE KEYS A LINE MAY LEAVE OUT (2026-10-04): the referee fills them
	# before the wire's own exact-key check — the wire keeps its strict
	# keys ([constant SgProtocol.FIELDS]); a program need not spell out
	# `"mode": 0, "excluded": [], "count": 1` on every cast.
	var targets: Variant = null
	var counted := action.has("count")
	if DEFAULTS.has(op):
		action = action.duplicate(true)
		for key in DEFAULTS[op]:
			if not action.has(key):
				action[key] = DEFAULTS[op][key].duplicate() if DEFAULTS[op][key] is Array else DEFAULTS[op][key]
		# `targets` on an autoprepare is the referee's own "three in one"
		# ([method _apply_line]), never a wire key.
		if op == "autoprepare" and action.has("targets"):
			targets = action.targets
			action.erase("targets")
		# A submit's targets may name card handles and players
		# ([method _tokens_for] reads them as tokens): checked here, the
		# wire sees the tokens they become.
		if op == "submit" and action.has("targets"):
			targets = action.targets
			action.targets = []
	var keys: Array = ["op"] + SgProtocol.FIELDS[op]
	var envelope := {"v": SgProtocol.VERSION, "type": "command", "seq": 1, "room": "", "revision": 0, "action": action}
	var exact := SgProtocol.exact(action, keys)
	var carried := exact and SgProtocol.valid(envelope)
	if targets != null and not carried:
		action = action.duplicate()
		action["targets"] = targets
	if not exact:
		return {"refusal": "op '%s' takes exactly the keys %s" % [op, ", ".join(keys + (["targets"] if op == "autoprepare" else []))], "action": action}
	if not carried:
		return {"refusal": "op '%s' has a value the wire would not carry (card handles are c1..; indices, x and counts are small integers)" % op, "action": action}
	if targets != null:
		var pairs: Variant = _target_pairs(targets)
		if pairs == null:
			action["targets"] = targets
			return {"refusal": "%s's targets are a list of [target, amount] pairs or bare targets — a slot token (t0), a card handle (c7), player:0 or player:1" % op, "action": action}
		if op == "submit":
			action.targets = pairs
			return {"action": action}
		# The payment counts the targets it is cast with (Fireball's {1} a
		# target after the first) unless the line said otherwise.
		if not counted:
			action.count = clampi(pairs.size(), 1, SgProtocol.MAX_CARDS)
		return {"action": action, "targets": pairs}
	return {"action": action}


## [param entries] as submit pairs — a bare target is `[target, 0]`, a
## pair stays a pair — or null when one is not a target: a token, a card
## handle, `player:N`, `ability:oN` or `damage:oN` (letters, digits, `:`,
## `_`, `-`, at most 24) with an amount of 0..1000, at most
## [constant SgProtocol.MAX_CARDS] of them.
static func _target_pairs(entries: Variant) -> Variant:
	if not entries is Array or entries.size() > SgProtocol.MAX_CARDS:
		return null
	var out: Array = []
	for entry in entries:
		var pair: Variant = [entry, 0] if entry is String else entry
		if not pair is Array or pair.size() != 2 or not _target_name(pair[0]) \
				or not SgProtocol.integer(pair[1], 0, 1000):
			return null
		out.append([String(pair[0]), int(pair[1])])
	return out


static func _target_name(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 24:
		return false
	for c in value:
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:_-".contains(c):
			return false
	return true


# ------------------------------------------------------- the options --

## The seat's legal answers, read from its view alone. Each mode lists
## what its op takes; `concede` is always there. A card is named by the
## view's handle (`c7`) and its name, so a program need not look it up.
static func options_for(view: Dictionary, seat: int) -> Dictionary:
	var out := {"mode": String(view.get("mode", "")), "concede": true}
	if int(view.get("actor", -1)) != seat or out.mode == "finished":
		out["waiting"] = true
		return out
	var p: Dictionary = view.get("presentation", {})
	match out.mode:
		"opening":
			if int(p.get("toss", -1)) == seat and not bool(p.get("order", true)):
				out["order"] = {"op": "order", "play": [true, false]}
			out["keep"] = {"op": "keep"}
			if not view.get("hand", []).is_empty():
				out["mulligan"] = {"op": "mulligan", "hand": view.hand.size()}
		"attack":
			out["attack"] = {"op": "attack", "attackable": _named(view, p.get("attackable", []))}
			out["attack_bands"] = {"op": "attack_bands", "attackable": Array(p.get("attackable", []))}
		"block":
			var rows: Array = []
			for row in p.get("blockable", []):
				rows.append({"blocker": row[0], "name": _card_name(view, row[0]), "attackers": _named(view, row[1])})
			out["block"] = {"op": "block", "blockable": rows, "pairs": "[[blocker, attacker], ...]; [] blocks nothing"}
		"discard":
			out["discard"] = {"op": "discard", "count": int(view.get("discard_count", 0)), "hand": _named(view, _ids(view.get("hand", [])))}
		"damage":
			out["damage"] = {"op": "damage", "request": view.get("damage_request", {}), "points": "[[target id or \"player\", amount], ...]"}
		"choice":
			out["choice"] = {"op": "choice", "prompt": view.choice.get("prompt", ""), "source": view.choice.get("source", ""),
				"options": Array(view.choice.get("options", [])), "count": int(view.choice.get("count", 1)),
				"information": Array(view.choice.get("information", [])),
				# Per line, the board card it stands for (protocol 29) or "".
				"cards": Array(view.choice.get("cards", []))}
			if bool(view.choice.get("cancel", false)):
				out["cancel"] = {"op": "cancel"}
		"priority":
			if not view.get("announcement", {}).is_empty():
				out["announcement"] = view.announcement
				out["draft"] = p.get("draft", {})
				out["autopay"] = {"op": "autopay", "excluded": [], "count": 1}
				out["submit"] = {"op": "submit", "targets": "[[slot target id, amount], ...] — one entry per slot within its min..max, [] for no slots"}
				out["cancel"] = {"op": "cancel"}
			else:
				out["pass"] = {"op": "pass"}
				var lands: Array = []
				var casts: Array = []
				var abilities: Array = []
				var mana: Array = []
				var rows := {}
				for row in p.get("cards", []):
					rows[row.id] = row
				for card in _every_card(view):
					if bool(card.get("playable", false)) and bool(card.get("land", false)):
						lands.append({"card": card.id, "name": card.name})
					var row: Dictionary = rows.get(card.id, {})
					for option in card.get("actions", []):
						var entry := {"card": card.id, "name": card.name, "index": int(option.index), "label": option.label}
						if option.kind == "spell":
							if not bool(row.get("castable", false)):
								continue
							entry["x"] = bool(option.x)
							entry["modes"] = Array(option.modes)
							# THE MODES IT MAY BE CAST IN NOW (2026-10-04):
							# `modes` stays every label at its index (the
							# `mode` a line names); `usable_modes` are the
							# indices whose payment the seat can make —
							# the spell's rows after its first.
							if not option.modes.is_empty():
								entry["usable_modes"] = _usable_modes(row)
							entry["budget"] = _budget(row, "spell", 0)
							casts.append(entry)
						elif option.kind == "ability":
							entry["budget"] = _budget(row, "ability", int(option.index))
							entry["cost"] = _cost(row, "ability", int(option.index))
							abilities.append(entry)
						else:
							mana.append(entry)
				out["play"] = {"op": "play", "lands": lands}
				out["prepare"] = {"op": "prepare", "casts": casts, "abilities": abilities,
					"then": "autopay, then submit (or autoprepare to prepare and pay in one line; autoprepare with targets casts it too)"}
				out["mana"] = {"op": "mana", "sources": mana}
				var specials: Array = []
				var labels: Array = view.get("specials", [])
				for i in labels.size():
					specials.append({"index": i, "label": labels[i]})
				out["special"] = {"op": "special", "specials": specials}
				# THE HAND'S SPECIAL-ACTION DISCARD (campaign 2026-10-07):
				# Circling Vultures' "You may discard this card any time you
				# could cast an instant" (CR 116.2, MtgGame
				# .discard_as_special_action) — the wire has carried
				# `discard_special` since protocol 26 and the person's screen
				# offers it; the pipe refused it as an unknown op. The card's
				# own printed rule says which; the 1997 prevention and
				# regeneration windows admit no such action.
				var discardable: Array = []
				if not bool(p.get("prevention", false)) and not bool(p.get("regeneration", false)):
					for card in view.get("hand", []):
						var printed := String(card.get("name", ""))
						if CardRegistry.has_card(printed) and CardRegistry.get_card(printed).discard_special_action:
							discardable.append({"card": card.id, "name": card.name})
				out["discard_special"] = {"op": "discard_special", "cards": discardable}
				out["respond"] = bool(p.get("respond", false))
	return out


static func _every_card(view: Dictionary) -> Array:
	# A COPY of the hand (2026-10-02). `Array(array)` is the same array,
	# and appending the two boards to it appended them to the VIEW's hand:
	# every decision line after the first land listed the whole table —
	# both players' permanents, graveyards, the opponent's lands — as the
	# seat's hand, growing by a card a turn (the MCP play-through read 90
	# "hand" cards against a hand count of 7).
	var cards: Array = view.get("hand", []).duplicate()
	for player in view.get("players", []):
		for zone in ["battlefield", "graveyard", "exile", "revealed"]:
			cards.append_array(player.get(zone, []))
	return cards


static func _card_name(view: Dictionary, handle: String) -> String:
	for card in _every_card(view):
		if card.id == handle:
			return String(card.name)
	return ""


static func _named(view: Dictionary, handles: Array) -> Array:
	var out: Array = []
	for handle in handles:
		out.append({"card": handle, "name": _card_name(view, handle)})
	return out


static func _ids(cards: Array) -> Array:
	var out: Array = []
	for card in cards:
		out.append(card.id)
	return out


static func _budget(row: Dictionary, kind: String, index: int) -> int:
	for option in row.get("abilities", []):
		if option.kind == kind and int(option.index) == index:
			return int(option.budget)
	return 0


## The modes a spell's presentation row says are open: its spell rows
## after the first (the first is its printed cost, always there).
static func _usable_modes(row: Dictionary) -> Array:
	var out: Array = []
	var first := true
	for option in row.get("abilities", []):
		if option.kind != "spell":
			continue
		if first:
			first = false
			continue
		out.append(int(option.index))
	return out


static func _cost(row: Dictionary, kind: String, index: int) -> String:
	for option in row.get("abilities", []):
		if option.kind == kind and int(option.index) == index:
			return String(option.cost)
	return ""


# ------------------------------------------------------- the table --

## A table the game hosts: the lobby's own client, driven by hand — no
## frame runs while the program thinks, so the socket is polled here.
## The class cannot be named at compile time from a `--script` tool
## (the autoloads it reads are registered after the script is), hence
## the load.
func _join(opts: Dictionary, packs: Variant) -> int:
	var one := _seat_deck(opts, "--join")
	if one.has("error"):
		return _refuse(2, one.error.message, one.error.detail)
	var invitation := String(opts.join)
	if invitation == "":
		var discovery := SgLanDiscovery.new()
		var found := _find_table(String(opts.table), int(opts.wait), discovery)
		discovery.free()
		if found.has("error"):
			return _refuse(2, found.error, {"kind": "table", "flag": "--table", "table": opts.table,
				"seen": found.get("seen", [])})
		invitation = String(found.invitation)
	var client: Node = load("res://game/sgmanalink/local_client.gd").new()
	var opened: Error
	if invitation.begins_with(SgLanInvite.PREFIX):
		opened = client.connect_invitation(invitation, opts.name)
	else:
		opened = client.connect_local(int(opts.port), invitation, opts.name)
	if opened != OK:
		client.free()
		return _refuse(2, "cannot join with '%s': not a LAN invitation (sglan1:...) nor a 64-character access code for port %d" % [invitation.left(24), int(opts.port)],
			{"kind": "join", "flag": "--join", "port": int(opts.port)})
	var outcome := _referee_table(client, one.deck, opts, packs)
	client.free()
	return _finish_table(outcome, opts, "--join" if opts.table == "" else "--table")


## The deck and the nickname a seat brings to a table, joined or
## hosted: {deck, file} or {error}.
func _seat_deck(opts: Dictionary, flag: String) -> Dictionary:
	if opts.deck == "":
		return {"error": {"message": "--deck is required with %s — the deck this seat brings to the table  (%s)" % [flag, FLAG_HINTS["--deck"]],
			"detail": {"kind": "option", "flag": "--deck"}}}
	if not SgProtocol.nickname(opts.name) or opts.name == "":
		return {"error": {"message": "--name wants 1-%d plain characters, not '%s'" % [SgProtocol.NICKNAME_LIMIT, opts.name],
			"detail": {"kind": "option", "flag": "--name"}}}
	return _load_deck(opts.deck, "--deck")


## The end of a table, joined or hosted: the error line, or the log and
## the result. The log of a table is the journal the seat saw: the
## engine's own lines are not on the wire (a hosted table's engine runs
## here, and still the seat is told what every guest is told).
func _finish_table(outcome: Dictionary, opts: Dictionary, flag: String) -> int:
	if outcome.has("error"):
		return _refuse(2, outcome.error, {"kind": "join" if flag != "--host" else "host", "flag": flag,
			"status": outcome.get("status", "")})
	var journal: Array = outcome.get("journal", [])
	outcome.erase("journal")
	if String(opts.get("log", "")) != "":
		var written := _write_log(opts.log, journal)
		if written != "":
			return _refuse(1, written, {"kind": "out", "flag": "--log", "path": opts.log})
		outcome["log"] = opts.log
	return _result(outcome)


## A table this referee hosts: the game's own LAN host in this process,
## polled by hand like the client, one table at it with the program in
## seat 0. The `table` line goes out once the room exists (the advert
## lists the rooms), then the chair is held for a guest.
func _host(opts: Dictionary, packs: Variant) -> int:
	var one := _seat_deck(opts, "--host")
	if one.has("error"):
		return _refuse(2, one.error.message, one.error.detail)
	if not SgProtocol.short_text(opts.host):
		return _refuse(2, "--host wants a table name of 1-32 plain characters, not '%s'" % opts.host,
			{"kind": "option", "flag": "--host"})
	var address := String(opts.address)
	var known := SgLanInvite.local_addresses()
	if address == "":
		if known.is_empty():
			return _refuse(2, "no private IPv4 address to host on — this computer is not on a LAN; give --address",
				{"kind": "host", "flag": "--address", "addresses": Array(known)})
		address = known[0]
	elif not SgLanInvite.address(address) or not IP.get_local_addresses().has(address):
		return _refuse(2, "--address wants one of this computer's private IPv4 addresses, not '%s'%s" % [address,
			"" if known.is_empty() else " — it has " + ", ".join(known)],
			{"kind": "host", "flag": "--address", "addresses": Array(known)})
	var server: Node = load("res://game/sgmanalink/local_server.gd").new()
	var started: Error = server.start_lan(address, int(opts.port), true, opts.name, discovery_port, opts.access == "open")
	if started != OK:
		server.free()
		return _refuse(2, "cannot host on %s:%d: %s" % [address, int(opts.port), error_string(started)],
			{"kind": "host", "flag": "--port", "address": address, "port": int(opts.port)})
	var hosting := {"name": String(opts.host), "access": String(opts.access), "host": String(opts.name),
		"address": address, "port": int(server.port), "invitation": String(server.invitation()),
		"discovery": server.discovery != null and server.discovery_error == OK}
	var company := func() -> void:
		server.poll()
		if server.discovery != null:
			server.discovery.pump()
	var client: Node = load("res://game/sgmanalink/local_client.gd").new()
	var opened: Error = client.connect_invitation(hosting.invitation, opts.name)
	var outcome: Dictionary
	if opened != OK:
		outcome = {"error": "the host's own invitation could not be used: %s" % error_string(opened), "status": ""}
	else:
		outcome = _referee_table(client, one.deck, opts, packs, hosting, company)
	client.free()
	server.stop()
	server.free()
	return _finish_table(outcome, opts, "--host")


## The invitation of the open LAN table called [param name], asked of
## [param discovery] — anything with SgLanDiscovery's face (`scan()`,
## `pump()`, `hosts`, `stop()`), driven by hand since no frame runs
## here. Returns {invitation} or {error, seen}: the table names seen
## tell the program what to ask for instead.
func _find_table(name: String, wait: int, discovery: Object) -> Dictionary:
	var started: Error = discovery.scan()
	if started != OK:
		return {"error": "the LAN cannot be searched for '%s': %s" % [name, error_string(started)], "seen": []}
	var deadline := Time.get_ticks_msec() + wait * 1000
	var seen := {}
	var invitation_only := false
	var full := false
	while true:
		discovery.pump()
		for key in discovery.hosts:
			var advert: Dictionary = discovery.hosts[key].get("host", {})
			for table in advert.get("tables", []):
				var table_name := String(table.get("name", ""))
				seen[table_name] = true
				if table_name != name:
					continue
				if not bool(table.get("open", false)):
					full = true
				elif SgLanDiscovery.open_host(advert):
					discovery.stop()
					return {"invitation": String(advert.invitation), "host": String(advert.get("name", ""))}
				else:
					invitation_only = true
		if Time.get_ticks_msec() > deadline:
			break
		OS.delay_msec(50)
	discovery.stop()
	var names := seen.keys()
	names.sort()
	if invitation_only:
		return {"error": "the table '%s' is hosted with an invitation — paste it with --join" % name, "seen": names}
	if full:
		return {"error": "the table '%s' has no free seat — waited %d s" % [name, wait], "seen": names}
	return {"error": "no open table called '%s' on the LAN — waited %d s%s" % [name, wait,
		"" if names.is_empty() else ", saw: " + ", ".join(PackedStringArray(names))], "seen": names}


## Plays the joined — or, with [param hosting], the hosted — table to
## its end. [param client] is anything with the lobby client's face —
## `poll()`, `online`, `busy()`, `command()`, `command_error`, `state`,
## the `refused` signal — so a test can seat the referee at a table it
## holds in the same process. [param hosting] is the `table` line
## without its id (the host's own client opens the room and holds seat
## 0); [param company] is called every tick — the host's own server and
## advert, polled by hand like the client.
func _referee_table(client: Object, deck: Dictionary, opts: Dictionary, packs: Variant,
		hosting: Dictionary = {}, company: Callable = Callable()) -> Dictionary:
	var refused: Array = []
	client.refused.connect(func(reason: String) -> void: refused.append(reason))
	# A kept game's client is seated while the lobby is waited on too —
	# the one that hosts gets its table line long before any decision,
	# and a knock left until hello would have gone stale.
	var tick := func() -> void:
		if company.is_valid():
			company.call()
		client.poll()
		if _server != null:
			_serve()
		OS.delay_msec(10)
	# Each wait has the whole `--wait` to itself (2026-10-03): one
	# deadline for the session made every answer after that many
	# seconds "never answered", and a duel longer than --wait was lost
	# to refusals.
	var until := func(condition: Callable, what: String) -> String:
		var deadline := Time.get_ticks_msec() + int(opts.wait) * 1000
		while not condition.call():
			if Time.get_ticks_msec() > deadline:
				return "%s — waited %d s (%s)" % [what, int(opts.wait), String(client.status)]
			tick.call()
		return ""
	var send := func(action: Dictionary) -> String:
		refused.clear()
		if not client.command(action):
			return String(client.command_error)
		var waited: String = until.call(func() -> bool: return not client.busy(), "the host never answered '%s'" % action.op)
		if waited != "":
			return waited
		return String(refused[0]) if not refused.is_empty() else ""
	# A lobby command (host, join, deck, ready, leave) the room moved on
	# under — the other seat's mark or deck landed while it was on the
	# wire — is sent again with the fresh revision, as the lobby asks.
	var arrange := func(action: Dictionary) -> String:
		var answer := ""
		for _try in LOBBY_TRIES:
			answer = send.call(action)
			if answer != ROOM_CHANGED:
				return answer
			tick.call()
		return answer
	var failed: String = until.call(func() -> bool: return bool(client.online), "the table could not be reached")
	if failed != "":
		return {"error": failed, "status": String(client.status)}
	if not hosting.is_empty():
		var host_command := {"op": "host", "name": String(hosting.name), "decks": "own", "deck": {}}
		if String(opts.get("rules", "")) != "":
			host_command["rules"] = table_rules(String(opts.rules))
		var hosted: String = arrange.call(host_command)
		if hosted != "":
			return {"error": "the table could not be opened: %s" % hosted, "status": String(client.status)}
	else:
		# THE TABLE BY NAME IS THE TABLE JOINED (campaign 2026-10-07): one
		# host lists every table its players open, and `--table Kitchen`
		# found the host by Kitchen's advert, then sat down at whichever
		# open table it listed first. A `--join` names no table: the first.
		var wanted := String(opts.get("table", ""))
		var open_room := func() -> Dictionary:
			if not client.state.room.is_empty():
				return client.state.room
			for room in client.state.rooms:
				if bool(room.get("open", false)) and (wanted == "" or String(room.get("name", "")) == wanted):
					return room
			return {}
		failed = until.call(func() -> bool: return not open_room.call().is_empty(),
			"no open table appeared" + ("" if wanted == "" else " called '%s'" % wanted))
		if failed != "":
			return {"error": failed, "status": String(client.status)}
		if client.state.room.is_empty():
			var room: Dictionary = open_room.call()
			var joined: String = arrange.call({"op": "join", "room": room.id})
			if joined != "":
				return {"error": "the table refused the seat: %s" % joined, "status": String(client.status)}
	failed = until.call(func() -> bool: return not client.state.room.is_empty(), "the seat never appeared")
	if failed != "":
		return {"error": failed, "status": String(client.status)}
	var seat := int(client.state.room.seat)
	if String(client.state.room.get("decks", "own")) == "own":
		var brought: Dictionary = {"op": "deck", "name": deck.name, "cards": deck.cards, "sideboard": deck.sideboard}
		if not deck.get("printings", {}).is_empty():
			brought["printings"] = deck.printings
		var accepted: String = arrange.call(brought)
		if accepted != "":
			return {"error": "the table refused the deck: %s" % accepted, "status": String(client.status)}
	var ready: String = arrange.call({"op": "ready", "value": true})
	if ready != "":
		return {"error": "the table refused ready: %s" % ready, "status": String(client.status)}
	var started := func() -> bool: return not client.state.room.get("game", {}).is_empty()
	if not hosting.is_empty():
		last_table = {"type": "table", "id": String(client.state.room.id)}.merged(hosting)
		_emit(last_table)
		# The lobby clears every ready mark when a guest sits down and
		# again when their deck arrives; the host's seat is marked ready
		# again each time, so the duel starts on the guest's own mark.
		var chair := {"readied": 0}
		var hold := func() -> bool:
			if started.call():
				return true
			var room: Dictionary = client.state.room
			if room.is_empty():
				return false
			var now := Time.get_ticks_msec()
			if not bool(room.ready[0]) and not client.busy() and now - int(chair.readied) >= 250:
				chair.readied = now
				send.call({"op": "ready", "value": true})
			return false
		failed = until.call(hold, "no guest sat down at '%s'" % hosting.name)
	else:
		failed = until.call(started, "the duel never started")
	if failed != "":
		return {"error": failed, "status": String(client.status)}
	var room: Dictionary = client.state.room
	var seats: Array = []
	for pid in 2:
		seats.append({"seat": pid, "player": "agent" if pid == seat else "table", "name": String(room.names[pid]),
			"deck": String(room.deck_names[pid]), "file": ""})
	_hello({"seats": seats, "seed": -1, "toss": int(room.game.presentation.toss), "turns": int(opts.turns),
		"table": {"id": room.id, "name": room.name, "seat": seat, "hosted": not hosting.is_empty()},
		"packs": packs, "log": String(opts.get("log", "")),
		"rules": RulesOptions.find_preset(SgTableRules.options(SgTableRules.normalize(room.get("rules", {}))).preset()).get("id", "custom")})
	# A kept game polls its own socket in _next_line; the pipe needs the
	# pump so the table's socket is served while the program thinks.
	if _server == null:
		_pump_start()
	# THE TABLE RECONNECTING (campaign 2026-10-07): a LAN table is not
	# whole while this seat's own client reconnects (SgLocalClient goes
	# offline for every transient drop and resumes the seat with its
	# resume code) or while the other seat is away (the host keeps it for
	# SgLocalServer.RECONNECT_GRACE_MS and refuses every game action
	# meanwhile, SEAT_AWAY). The duel used to end at the first offline
	# tick (`offline`), and every answer sent meanwhile counted as the
	# program's refusal — twenty, and the seat conceded (`refusals`): a
	# person's brief drop lost the agent its game. Now the table is waited
	# for, and an answer that met it reconnecting is held and sent again
	# once it is whole — still this seat's decision — uncounted.
	# `offline` is final only when the client stops retrying or the wait
	# outlasts the host's own grace ([member reconnect_patience_ms]).
	var away := func() -> bool:
		if not client.online:
			return true
		var seated: Dictionary = client.state.room
		var duel: Dictionary = seated.get("game", {})
		if seated.is_empty() or duel.is_empty() or String(duel.get("mode", "")) == "finished":
			return false
		var connected: Array = seated.get("connected", [true, true])
		return connected.size() == 2 and not (bool(connected[0]) and bool(connected[1]))
	var lost := {"offline": false}
	var hold := func() -> bool:
		var since := Time.get_ticks_msec()
		while away.call() or client.busy():
			var given_up: bool = not client.online and client.has_method("connecting") and not client.connecting()
			if given_up or Time.get_ticks_msec() - since > reconnect_patience_ms:
				lost.offline = true
				return false
			tick.call()
		return true
	var act := func(action: Dictionary) -> String:
		var asked := String(client.state.room.get("game", {}).get("mode", ""))
		while true:
			var answer: String = send.call(action)
			if answer == "":
				return ""
			# Sent, and still unanswered when the wait ran out: the link
			# dropped under it, and the client sends it again once it is back.
			var in_flight: bool = client.busy()
			if not (in_flight or away.call() or answer == SEAT_AWAY or answer == NOT_CONNECTED):
				return answer
			if not hold.call():
				return answer
			if in_flight:
				# Its own answer came with the link: applied, or refused.
				if refused.is_empty():
					return ""
				if String(refused[0]) != SEAT_AWAY:
					return String(refused[0])
			# Overtaken while it waited (the host conceded a seat that never
			# came back, the decision moved on): the loop below reads on.
			var now: Dictionary = client.state.room.get("game", {})
			if now.is_empty() or String(now.mode) == "finished" or int(now.actor) != seat or String(now.mode) != asked:
				return ""
		return ""
	var reason := ""
	var acted_revision := -1
	while reason == "":
		tick.call()
		if away.call():
			if not hold.call():
				reason = "offline"
			continue
		var view: Dictionary = client.state.room.get("game", {})
		if view.is_empty():
			if client.state.room.is_empty():
				reason = "left"
			continue
		if String(view.mode) == "finished":
			reason = "concluded"
			break
		if int(view.turn) > int(opts.turns):
			reason = "limit"
			break
		if client.busy() or int(client.state.room.revision) <= acted_revision or int(view.actor) != seat:
			continue
		if decisions >= MAX_DECISIONS:
			reason = "decisions"
			break
		acted_revision = int(client.state.room.revision)
		reason = _ask(seat, String(view.mode),
			func() -> Dictionary: return client.state.room.get("game", {}),
			act, tick, func() -> String: return "offline" if bool(lost.offline) else "")
	if reason in ["eof", "idle", "refusals", "limit", "decisions"] and String(client.state.room.get("game", {}).get("mode", "")) != "finished":
		send.call({"op": "concede"})
		until.call(func() -> bool: return String(client.state.room.get("game", {}).get("mode", "")) == "finished", "the concession never landed")
	var final: Dictionary = client.state.room.get("game", {})
	var life: Array = []
	for player in final.get("players", []):
		life.append(int(player.life))
	var journal: Array = []
	for entry in final.get("journal", []):
		journal.append(String(entry.get("text", "")))
	_pump_finish()
	arrange.call({"op": "leave"})
	return {"winner": int(final.get("winner", -1)), "draw": bool(final.get("draw", false)),
		"turns": int(final.get("turn", 0)), "reason": reason, "life": life,
		"names": Array(room.names), "seat": seat, "table": {"id": room.id, "name": room.name},
		"journal": journal}
