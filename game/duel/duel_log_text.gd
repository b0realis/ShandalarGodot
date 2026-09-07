class_name DuelLogText
extends RefCounted
## THE SHAPE OF THE DUEL LOG — the one reading of the engine's lines that
## the log window (coloured, `L`) and the running log file (plain text,
## `duel_log.txt`) both print, so what the player reads on the table is
## what they find in the file. `[QoL]`.
##
## THE ENGINE WRITES PROSE, one sentence per mutation ("HAL 9000 plays
## Island", "Serra Angel is destroyed"), and beside each sentence a
## [member MtgGame.log_meta] entry — the turn and step it was written in,
## the seat it belongs to and the card it is about. The owner's playtest
## of 2026-09-07 asked for three things of that stream: *"individual
## phases should be indicated"*, *"each action from the player prefixed by
## Player 1 (name), Player 2 (name)"*, and casts *"colored and emphasized
## by card colour"* — a log that *"should be able to really help check the
## engine performance and dig out bugs and faults but also be readable
## quickly by a human"*. This class does the first two and hands the
## window what it needs for the third:
##
## - A STEP MARKER, `[Upkeep]`, `[First Main]`, `[Declare Attackers]` …,
##   the moment a line lands in a step no line has been printed in yet.
##   Lazily, not at every step: a turn walks thirteen steps and most of
##   them pass in silence, and thirteen headings over three sentences is
##   not readable. The marker says WHERE a sentence happened, which is
##   the half of a bug report the prose does not carry ("the trigger
##   resolved in the draw step, before the draw").
## - THE SEAT, on every sentence that opens with a player's name: "HAL
##   9000 plays Island" reads "Player 2 (HAL 9000) plays Island", and a
##   player who kept the default name reads "Player 1 plays Plains" — the
##   parenthesis never repeats itself. A sentence about a card ("Serra
##   Angel is destroyed") is a consequence, not an act, and keeps its
##   shape; the meta still says whose card it was.
## - INDENTATION under the step marker, a blank line before each turn
##   header, and the header itself naming the seat the same way — so a
##   1 MB file scans by eye and `grep '^\['` or `grep 'Player 1'` cuts
##   it the way a reader wants.
##
## Stateful: one instance per reader, fed every line in order, because
## "a step no line has been printed in yet" is a question about what
## came before. [method reset] for a new game.

## The indent under a step marker.
const INDENT := "  "

## The players' names by seat, as the engine has them.
var names: PackedStringArray = PackedStringArray(["Player 1", "Player 2"])

var _turn := -1
var _step := -1
var _headers := 0


## Start over — a new game, or a window refilled from the top.
func reset() -> void:
	_turn = -1
	_step = -1
	_headers = 0


## The seat's label: "Player 1", or "Player 1 (Fred)" when the player is
## called something else.
func seat(pid: int) -> String:
	var plain := "Player %d" % (pid + 1)
	if pid < 0 or pid >= names.size() or names[pid] == plain or names[pid].is_empty():
		return plain
	return "%s (%s)" % [plain, names[pid]]


## [param line] with the seat's label in place of the player's name when
## the sentence opens with it — an act — and unchanged otherwise.
func attributed(line: String, meta: Dictionary) -> String:
	var pid := int(meta.get("pid", -1))
	if pid < 0 or pid >= names.size():
		return line
	var who := names[pid]
	if who.is_empty() or not line.begins_with(who + " "):
		return line
	return seat(pid) + line.substr(who.length())


## The rows one engine line prints as, in order — each a Dictionary with
## `role` ("gap", "turn", "step" or "line"), `text` (what a plain reader
## prints, indent included) and `meta` (the engine's, for a reader that
## colours). A turn header comes with a gap before it (not the first);
## a line in a step not yet marked comes after its marker.
func rows(line: String, meta: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if String(meta.get("kind", "")) == "turn":
		if _headers > 0:
			out.append({"role": "gap", "text": "", "meta": {}})
		_headers += 1
		_turn = int(meta.get("turn", -1))
		_step = -1
		out.append({"role": "turn", "text": _header(line, meta), "meta": meta})
		return out
	var turn := int(meta.get("turn", -1))
	var step := int(meta.get("step", -1))
	if step >= 0 and (step != _step or turn != _turn):
		_turn = turn
		_step = step
		out.append({"role": "step", "text": "[%s]" % Mtg.step_name(step), "meta": {}})
	var text := attributed(line, meta)
	if step >= 0:
		text = INDENT + text
	out.append({"role": "line", "text": text, "meta": meta})
	return out


## "== Turn 8 — HAL 9000 ==" with the seat's label for the name.
func _header(line: String, meta: Dictionary) -> String:
	var pid := int(meta.get("pid", -1))
	if pid < 0 or pid >= names.size():
		return line
	var tail := " — %s ==" % names[pid]
	if names[pid].is_empty() or not line.ends_with(tail):
		return line
	return line.left(line.length() - tail.length()) + " — %s ==" % seat(pid)


## The whole log as plain text — what `Copy` and `Save` and the running
## file share: [param lines] and [param metas] index for index, one row
## per line of the result. A fresh reading, so the caller's own cursor
## is untouched.
static func plain(lines: PackedStringArray, metas: Array[Dictionary],
		who: PackedStringArray) -> String:
	var shape := DuelLogText.new()
	shape.names = who
	var out := PackedStringArray()
	for i in lines.size():
		var meta: Dictionary = metas[i] if i < metas.size() else {}
		for row in shape.rows(lines[i], meta):
			out.append(row["text"])
	return "\n".join(out)
