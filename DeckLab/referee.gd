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
## this computer or over the LAN.
##
##   DeckLab/referee.sh --deck-a DECK --deck-b DECK [--seat-a agent]
##       [--seat-b wizard] [--seed N] [--turns N] [--packs LIST]
##       [--log FILE] [--dry-run]
##   DeckLab/referee.sh --join INVITATION|CODE --deck DECK [--port N]
##       [--name NICK] [--wait SECONDS] [--turns N] [--packs LIST]
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
	"attack", "attack_bands", "block", "damage", "discard"]
const DEFAULT_TURNS := 200
const DEFAULT_PORT := 17897
const DEFAULT_WAIT := 300
## A program-held seat's decisions, over the whole duel, before the
## referee ends it (`reason: decisions`): a duel that long is a loop.
const MAX_DECISIONS := 20000
## Refused answers IN A ROW before the seat is conceded (`reason:
## refusals`): a program that cannot read its options is not playing.
const MAX_REFUSALS := 20
## A computer seat's steps without the table changing before the duel
## is called (`reason: stalled`).
const IDLE_BOT_STEPS := 100
## Empty reads in a row that mean the input has closed: Godot's stdin
## line reader returns "" for a blank line and for end-of-file alike.
const EMPTY_READS := 3
const BOT_PACE_MS := 50

const HELP := """Referee — one duel played through a pipe, a program in a seat
====================================================================
Every decision goes out on stdout as one JSON line (`decision`: the
seat, its legal `options`, its whole `view`); the answer comes back on
stdin as one JSON action (`{"op": "pass"}`); `refused` says why an
answer could not be applied, and the decision stands; `result` ends
the duel. Nothing but JSON is ever written to stdout.

USAGE
  DeckLab/referee.sh --deck-a DECK --deck-b DECK [--seat-a SEAT]
      [--seat-b SEAT] [--seed N] [--turns N] [--packs LIST] [--log FILE]
      [--dry-run]
  DeckLab/referee.sh --join INVITATION|CODE --deck DECK [--port N]
      [--name NICK] [--wait SECONDS] [--turns N] [--packs LIST]
  DeckLab/referee.sh -h | --help

SEATS  (--seat-a, --seat-b; default: agent vs wizard; at least one agent)
  agent       the program on the pipe (both seats: it plays itself)
  apprentice  magician  sorcerer  wizard   the shipped computer players
  unfair      the wizard that reads hidden cards, as the game offers it

SWITCHES
  --deck-a / --deck-b PATH  each seat's deck file, tried as typed and
                            then under decks/ (the Lab's own rule)
  --seed N                  the shuffle; unset, a random seed is drawn
                            and reported in `hello`
  --turns N                 the duel is called a draw past turn N (200)
  --packs LIST              all|none|a,b: the card packs in play
  --log FILE                the engine's own log of the duel, at the end
  --dry-run                 print the plan as JSON, play nothing
  --join TEXT               sit at a table the game hosts: a LAN
                            invitation (sglan1:...) or the same-computer
                            access code the host screen shows
  --deck PATH               the deck to bring to that table
  --port N                  the host's port for an access code (17897)
  --name NICK               the seat's name at that table (Agent)
  --wait SECONDS            how long to wait for an open table (300)

THE LINES (stdout)
  hello     {tool, protocol, version, seed, seats[{seat, player, name,
             deck, file}], toss, turns, ops}  — once, before play
  decision  {n, seat, mode, turn, step, options, view}
             mode: opening|priority|attack|block|discard|damage|choice
  refused   {n, seat, reason, action, left}  — the decision follows again
  result    {winner, draw, turns, reason, decisions, refusals, seed,
             life, names}  — reason: concluded|conceded|eof|refusals|
             limit|decisions|stalled|left|offline
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
             "excluded":[],"count":1}  prepare and pay in one line
            {"op":"mana","card":ID,"index":I}  {"op":"tap","card":ID}
            {"op":"special","index":I}
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
	"--seed": "--seed N: the shuffle, a non-negative integer; unset, one is drawn and reported",
	"--turns": "--turns N: the turn past which the duel is called a draw (200)",
	"--packs": "--packs LIST: all, none, or the pack ids in play, comma-separated",
	"--log": "--log FILE: where to write the engine's own log of the duel",
	"--join": "--join TEXT: a LAN invitation (sglan1:...) or the host screen's same-computer access code",
	"--deck": "--deck PATH: the deck to bring to a joined table",
	"--port": "--port N: the host's port when joining by access code (17897)",
	"--name": "--name NICK: the seat's name at a joined table (Agent)",
	"--wait": "--wait SECONDS: how long to wait for the host's open table (300)",
}

## THE TWO ENDS OF THE PIPE, as Callables so a test can hold both:
## `reader` returns the next line of input, or null once it has closed;
## `writer` takes one line for stdout.
var reader: Callable
var writer: Callable
var last_error: Dictionary = {}
var last_hello: Dictionary = {}
var last_decision: Dictionary = {}
var last_result: Dictionary = {}
var last_plan: Dictionary = {}
var decisions := 0
var refusals := 0
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


func _emit(record: Dictionary) -> void:
	writer.call(JSON.stringify(record))


func _refuse(exit: int, message: String, detail: Dictionary = {}) -> int:
	printerr("referee: %s" % message)
	last_error = LabConsole.error_record("referee", exit, message, detail)
	_emit({"error": last_error})
	return exit


## The next line of input, or null when it has closed. [param tick] is
## called while a table's pump is being waited on (the socket's poll).
func _next_line(tick: Callable) -> Variant:
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


# ------------------------------------------------------ the arguments --

func _parse_args(argv: PackedStringArray) -> Dictionary:
	var opts := {"deck_a": "", "deck_b": "", "seat_a": "agent", "seat_b": "wizard",
		"seed": -1, "turns": DEFAULT_TURNS, "packs": "", "log": "", "dry_run": false,
		"join": "", "deck": "", "port": DEFAULT_PORT, "name": "Agent", "wait": DEFAULT_WAIT}
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
			"--seed", "--turns", "--port", "--wait":
				if not value.is_valid_int() or int(value) < 0:
					return {"error": {"message": "%s wants a non-negative integer, not '%s'" % [arg, value],
						"detail": {"kind": "option", "flag": arg}}}
				opts[arg.trim_prefix("--")] = int(value)
			"--packs": opts.packs = value
			"--log": opts.log = value
			"--join": opts.join = value.strip_edges()
			"--deck": opts.deck = value
			"--name": opts.name = value.strip_edges()
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
		var problems: Array = Array(report.errors)
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
	if opts.join != "":
		return _join(opts, packs)
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
			"packs_on": Lab.packs_on(), "log": opts.log, "ops": DUEL_OPS}
		_emit(last_plan)
		return 0
	var m := SgPracticeMatch.new(seed_value, [loaded[0].deck, loaded[1].deck], names)
	for pid in 2:
		if players[pid] != "agent" and not m.set_bot(pid, _bot_options(players[pid])):
			return _refuse(1, "seat %d could not be given to the %s" % [pid, players[pid]], {"kind": "option"})
	_hello({"seats": seats, "seed": seed_value, "toss": m.toss_winner, "turns": int(opts.turns),
		"packs": packs, "log": opts.log})
	var result := _referee_local(m, int(opts.turns))
	result["seed"] = seed_value
	if opts.log != "":
		var file := FileAccess.open(opts.log, FileAccess.WRITE)
		if file == null:
			return _refuse(1, "cannot write the log at '%s'" % opts.log, {"kind": "out", "flag": "--log", "path": opts.log})
		file.store_string("\n".join(m.game.log_lines) + "\n")
		file.close()
		result["log"] = opts.log
	return _result(result)


func _hello(extra: Dictionary) -> void:
	last_hello = {"type": "hello", "tool": "referee", "protocol": PROTOCOL,
		"version": LabConsole.version(), "git": LabConsole.git_sha(), "ops": DUEL_OPS,
		"limits": {"decisions": MAX_DECISIONS, "refusals": MAX_REFUSALS}}.merged(extra)
	_emit(last_hello)


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
	if reason in ["eof", "refusals"] and not m.game.game_over:
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
## a table alive while the program thinks.
func _ask(seat: int, mode: String, fresh: Callable, apply: Callable, tick: Callable) -> String:
	decisions += 1
	var n := decisions
	var view: Dictionary = fresh.call()
	_decision(n, seat, mode, view)
	var consecutive := 0
	while true:
		var line: Variant = _next_line(tick)
		if line == null:
			return "eof"
		var text := String(line).strip_edges()
		if text == "":
			continue
		var parsed := _parse_action(text, seat)
		var refusal := ""
		var action: Dictionary = parsed.get("action", {})
		if parsed.has("refusal"):
			refusal = String(parsed.refusal)
		else:
			refusal = String(apply.call(action))
			if refusal == "":
				return "conceded" if action.op == "concede" else ""
		consecutive += 1
		refusals += 1
		_emit({"type": "refused", "n": n, "seat": seat, "reason": refusal, "action": action,
			"left": MAX_REFUSALS - consecutive})
		if consecutive >= MAX_REFUSALS:
			return "refusals"
		# THE DECISION IS ASKED AGAIN, as a `decision` line with the same
		# `n` — so a program acts on decision lines alone and a `refused`
		# is only the reason. From the live view: a refusal can still
		# have moved the table (a payment step that tapped before it
		# failed), and the options must say what is legal NOW.
		view = fresh.call()
		_decision(n, seat, mode, view)
	return ""


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
	_emit(last_decision)


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
	var keys: Array = ["op"] + SgProtocol.FIELDS[op]
	if not SgProtocol.exact(action, keys):
		return {"refusal": "op '%s' takes exactly the keys %s" % [op, ", ".join(keys)], "action": action}
	var envelope := {"v": SgProtocol.VERSION, "type": "command", "seq": 1, "room": "", "revision": 0, "action": action}
	if not SgProtocol.valid(envelope):
		return {"refusal": "op '%s' has a value the wire would not carry (card handles are c1..; indices, x and counts are small integers)" % op, "action": action}
	return {"action": action}


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
				"information": Array(view.choice.get("information", []))}
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
					"then": "autopay, then submit (or autoprepare for both in one line)"}
				out["mana"] = {"op": "mana", "sources": mana}
				var specials: Array = []
				var labels: Array = view.get("specials", [])
				for i in labels.size():
					specials.append({"index": i, "label": labels[i]})
				out["special"] = {"op": "special", "specials": specials}
				out["respond"] = bool(p.get("respond", false))
	return out


static func _every_card(view: Dictionary) -> Array:
	var cards: Array = Array(view.get("hand", []))
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
	if opts.deck == "":
		return _refuse(2, "--deck is required with --join — the deck this seat brings to the table  (%s)" % FLAG_HINTS["--deck"],
			{"kind": "option", "flag": "--deck"})
	if not SgProtocol.nickname(opts.name) or opts.name == "":
		return _refuse(2, "--name wants 1-%d plain characters, not '%s'" % [SgProtocol.NICKNAME_LIMIT, opts.name],
			{"kind": "option", "flag": "--name"})
	var one := _load_deck(opts.deck, "--deck")
	if one.has("error"):
		return _refuse(2, one.error.message, one.error.detail)
	var client: Node = load("res://game/sgmanalink/local_client.gd").new()
	var invitation := String(opts.join)
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
	if outcome.has("error"):
		return _refuse(2, outcome.error, {"kind": "join", "flag": "--join", "status": outcome.get("status", "")})
	return _result(outcome)


## Plays the joined table to its end. [param client] is anything with
## the lobby client's face — `poll()`, `online`, `busy()`, `command()`,
## `command_error`, `state`, the `refused` signal — so a test can seat
## the referee at a table it holds in the same process.
func _referee_table(client: Object, deck: Dictionary, opts: Dictionary, packs: Variant) -> Dictionary:
	var refused: Array = []
	client.refused.connect(func(reason: String) -> void: refused.append(reason))
	var tick := func() -> void:
		client.poll()
		OS.delay_msec(10)
	var deadline := Time.get_ticks_msec() + int(opts.wait) * 1000
	var until := func(condition: Callable, what: String) -> String:
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
	var failed: String = until.call(func() -> bool: return bool(client.online), "the table could not be reached")
	if failed != "":
		return {"error": failed, "status": String(client.status)}
	var open_room := func() -> Dictionary:
		if not client.state.room.is_empty():
			return client.state.room
		for room in client.state.rooms:
			if bool(room.get("open", false)):
				return room
		return {}
	failed = until.call(func() -> bool: return not open_room.call().is_empty(), "no open table appeared")
	if failed != "":
		return {"error": failed, "status": String(client.status)}
	if client.state.room.is_empty():
		var room: Dictionary = open_room.call()
		var joined: String = send.call({"op": "join", "room": room.id})
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
		var accepted: String = send.call(brought)
		if accepted != "":
			return {"error": "the table refused the deck: %s" % accepted, "status": String(client.status)}
	var ready: String = send.call({"op": "ready", "value": true})
	if ready != "":
		return {"error": "the table refused ready: %s" % ready, "status": String(client.status)}
	failed = until.call(func() -> bool: return not client.state.room.get("game", {}).is_empty(), "the duel never started")
	if failed != "":
		return {"error": failed, "status": String(client.status)}
	var room: Dictionary = client.state.room
	var seats: Array = []
	for pid in 2:
		seats.append({"seat": pid, "player": "agent" if pid == seat else "table", "name": String(room.names[pid]),
			"deck": String(room.deck_names[pid]), "file": ""})
	_hello({"seats": seats, "seed": -1, "toss": int(room.game.presentation.toss), "turns": int(opts.turns),
		"table": {"id": room.id, "name": room.name, "seat": seat}, "packs": packs})
	_pump_start()
	var reason := ""
	var acted_revision := -1
	while reason == "":
		tick.call()
		if not client.online:
			reason = "offline"
			break
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
			send, tick)
	if reason in ["eof", "refusals", "limit", "decisions"] and String(client.state.room.get("game", {}).get("mode", "")) != "finished":
		send.call({"op": "concede"})
		until.call(func() -> bool: return String(client.state.room.get("game", {}).get("mode", "")) == "finished", "the concession never landed")
	var final: Dictionary = client.state.room.get("game", {})
	var life: Array = []
	for player in final.get("players", []):
		life.append(int(player.life))
	_pump_finish()
	send.call({"op": "leave"})
	return {"winner": int(final.get("winner", -1)), "draw": bool(final.get("draw", false)),
		"turns": int(final.get("turn", 0)), "reason": reason, "life": life,
		"names": Array(room.names), "seat": seat, "table": {"id": room.id, "name": room.name}}
