class_name DuelLogFile
extends RefCounted
## THE RUNNING LOG — every duel, appended to one text file beside the
## game, `duel_log.txt`. `[QoL]`, 2026-09-07: *"All logs should be saved
## also to a running log text file at the game location (each game
## separated by some large comment block ********* GAME at {date time}
## ********** or something similar. That running log should be 1 MB and
## just oldest output overwritten by newest (new logs just appended)."*
##
## WHAT IT IS FOR. The log window (`L`) shows the duel that is on the
## table, and `Save` keeps one on request; this keeps them ALL, whether
## anybody asked — the duel that crashed, the one the owner meant to
## report and closed, the AI's twenty games overnight. A bug report is a
## seed plus a log ([member MtgGame.log_lines]), and this is where the
## log is when nobody thought to save it.
##
## WHERE. Beside the executable in an exported game — "at the game
## location", the one place a player looks — and under `user://` when
## the editor binary runs the project (`OS.has_feature("editor")`): the
## project directory is the repository, and the test suite and the soak
## each play hundreds of duels through the live screen. An executable
## directory that cannot be written (a system install) falls back to
## `user://` too, so the log is never silently lost.
##
## THE CAP. One megabyte, trimmed from the FRONT: when an append takes
## the file past [constant CAP], the oldest 64 KB and a little more go,
## and the cut lands on the next game banner where there is one — so
## the file's first line is a `GAME at` banner, not the middle of a
## turn. Trimming rewrites the file, which is why it trims a slab and
## not a line: once a duel per hour, not once a sentence.
##
## THE SHAPE is [DuelLogText]'s — the same step markers, seat labels and
## indents the window prints — so a line found in the file is the line
## that was on the screen.

## The file's name, beside the game.
const FILE_NAME := "duel_log.txt"
## One megabyte.
const CAP := 1_000_000
## How much more than the cap a trim takes, so trimming is rare.
const SLACK := 65_536
## The banner's rule and its word. `********** GAME at ... **********`.
const RULE := "****************************************************************************"
const BANNER_WORD := "GAME at"

## Where the file goes when it is not the game's own directory — the
## tests' seam. Empty means [method game_dir].
static var location := ""


## The directory the file lives in: the executable's own in an exported
## game, `user://` under the editor or when the executable's directory
## is not writable.
static func game_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("user://")
	var beside := OS.get_executable_path().get_base_dir()
	var probe := FileAccess.open(beside.path_join(FILE_NAME), FileAccess.READ_WRITE)
	if probe == null:
		probe = FileAccess.open(beside.path_join(FILE_NAME), FileAccess.WRITE)
	if probe == null:
		return ProjectSettings.globalize_path("user://")
	probe.close()
	return beside


## The file's absolute path.
static func path() -> String:
	var dir := location if not location.is_empty() else game_dir()
	return dir.path_join(FILE_NAME)


## The banner that opens a game in the file: three lines, the middle one
## naming the moment, the players and the seed.
static func banner(names: PackedStringArray, seed_value: int) -> PackedStringArray:
	var when := Time.get_datetime_string_from_system(false, true)
	var who := " vs ".join(names)
	var out := PackedStringArray()
	out.append("")
	out.append(RULE)
	out.append("**********  %s %s  —  %s  (seed %d)  **********" % [
		BANNER_WORD, when, who, seed_value])
	out.append(RULE)
	return out


var _shape := DuelLogText.new()


## Open a game: the banner, and the shape's cursor back to the top.
func begin(names: PackedStringArray, seed_value: int) -> void:
	_shape.names = names
	_shape.reset()
	_append(banner(names, seed_value))


## One engine line, as the window would print it.
func write(line: String, meta: Dictionary) -> void:
	var out := PackedStringArray()
	for row in _shape.rows(line, meta):
		out.append(row["text"])
	_append(out)


func _append(lines: PackedStringArray) -> void:
	var file_path := path()
	var file := FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	for line in lines:
		file.store_line(line)
	var length := file.get_length()
	file.close()
	if length > CAP:
		_trim(file_path)


## Drop the front of the file so it fits under the cap with room to
## spare, cutting on a game banner where one falls inside the slab.
## Measured in bytes, the way the cap is — a line of prose with an em
## dash is longer on disk than in a String.
func _trim(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return
	var body := file.get_as_text()
	file.close()
	var lines := body.split("\n")
	var total := body.to_utf8_buffer().size()
	var cut := 0
	while total > CAP - SLACK and cut < lines.size():
		total -= lines[cut].to_utf8_buffer().size() + 1
		cut += 1
	for i in range(cut, lines.size() - 1):
		if lines[i] == RULE and lines[i + 1].begins_with("**********  " + BANNER_WORD):
			cut = i
			break
	file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines.slice(cut)))
	file.close()
