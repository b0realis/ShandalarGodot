class_name HallOfFame
extends RefCounted
## THE HALL OF FAME — every adventure won, best first (the owner,
## 2026-10-27, round P2 Q-RANK: "Hall of Fame — each won adventure kept
## (name, face, colour, difficulty, score, days, wins, date), best first,
## shown after the win"; and later: *"Only hall of fame button should be
## inside save/load as not to clutter the main menu!"*). 1997 had no
## ranking, only the years of its last words (@CASTLEWIN 9); its shell
## named a "Hall of Fame: View Game Records." (Uistrings.txt
## @SHELLSCREEN_RECORDS) it never filled. Ours [ours]: a small file of its
## own, apart from the saves, so deleting an adventure never takes its
## place in the Hall; the screens (after the win, and a button inside Save
## / Load) read [method entries].
##
## A LINE ([method entry_of]): `{id, name, portrait, color, difficulty,
## score, days, wins, date, seed_text, life_rule, attempts}` — the
## adventure, the hero's name and face, their colour, the difficulty
## (0 Apprentice … 3 Wizard), the years Arzakon is banished, the days on
## the road, the duels won, when the final battle was won (ISO, UTC), the
## world's seed, the final battle's rule and the battles lost before the
## win. ONE LINE AN ADVENTURE: an adventure won again (a save from before
## the win, taken up and won once more) keeps its better line.
##
## BEST FIRST ([method best_first]): the higher score; on a tie the harder
## difficulty, then the fewer days, then the earlier win, then the name.
## At most [constant MOST] lines are kept, the lowest let go.
##
## THE ONE-LIFE BATTLES, kept in the same file beside the lines (the
## owner's ruling of 2026-10-27 for "One life": *"True ironman: closing
## mid-battle ends the adventure as a lost final battle; no way to retry."*):
## `{adventure id: "begun" | "failed"}` — a One-life adventure whose final
## battle began ([method FinalBattle.door]) or was lost ([method
## FinalBattle.settle]); a win takes it out (the Hall's line takes over).
## It lives OUTSIDE the saves so that no save of the adventure — the
## autosave, a slot saved before the door — can take the battle up again:
## [method FinalBattle.on_load] reads it ([method one_life_state]). No
## screen shows it. [ours]
##
## WRITTEN WHOLE OR NOT AT ALL ([method add], [method mark_one_life]):
## through [method Settings.write_atomically] — aside, checked, then
## renamed over the old — and read back; each write keeps what the other
## keeps. READ SAFELY ([method entries]): field by field, a line kept only
## with a name and a score, a One-life mark only as one of the two words; a
## file that cannot be read at all is never written over — it is first set
## aside as `<file>.bad` (`.bad2` …), as the settings file is
## (docs/player-files.md).

## The file, and where the tests point it.
const FILE := "user://hall_of_fame.json"
static var file := FILE
## The file's own name and version, first in it.
const FORMAT := "shandalar-hall-of-fame"
const FORMAT_VERSION := 1
## The lines kept.
const MOST := 100
## A One-life adventure's final battle: begun, or lost ([method
## one_life_state]).
const BEGUN := "begun"
const FAILED := "failed"
const ONE_LIFE_STATES: Array[String] = [BEGUN, FAILED]
## What the file says of itself.
const ABOUT := "The adventures won in Shandalar, best first: the hero, their color, the difficulty (0 Apprentice to 3 Wizard), the years Arzakon is banished (the score), the days on the road, the duels won, and when. one_life: the adventures of one life whose final battle began or was lost, so that no older save of them can fight it again."


## THE LINE OF [param player]'s won adventure ([member AdventurePlayer.final]
## holds the end's record; an adventure not won has none: `{}`).
static func entry_of(player: AdventurePlayer) -> Dictionary:
	if player == null or player.ended != AdventurePlayer.ENDED_WON:
		return {}
	var end := player.final
	return {"id": player.adventure_id, "name": player.name, "portrait": player.portrait,
		"color": player.color, "difficulty": player.difficulty,
		"score": int(end.get("score", 0)), "days": int(end.get("days", player.quest_timer / WorldStatus.DAY)),
		"wins": int(end.get("wins", player.duel_record()["won"])),
		"date": String(end.get("date", "")), "seed_text": player.world_seed_text,
		"life_rule": player.life_rule, "attempts": int(end.get("attempts", player.final_attempts))}


## THE HALL'S LINES, best first — from [param path] ([member file] when
## ""); none when there is no file or it cannot be read.
static func entries(path := "") -> Array[Dictionary]:
	return _read(path if path != "" else file)["entries"]


## WHETHER A FILE IS AT [param path] ([member file] when "") THAT CANNOT BE
## READ as the Hall (not JSON, another format, a newer version): its lines
## are not shown, and it is kept as it is until the next write sets it
## aside (part C stage C3, h3-4: the Hall said "No adventure has been won
## yet" over it).
static func damaged(path := "") -> bool:
	return bool(_read(path if path != "" else file)["damaged"])


## [param player]'s won adventure written into the Hall at [param path]
## ([member file] when ""): its place there, 1 the best — or 0 when it is
## not written (no win; the file could not be written, the Hall then as it
## was; or, among [constant MOST] better ones, no place left).
static func add(player: AdventurePlayer, path := "") -> int:
	var line := entry_of(player)
	if line.is_empty():
		return 0
	var at := path if path != "" else file
	var read := _read(at)
	if bool(read["damaged"]):
		_set_aside(at)
	var kept: Array[Dictionary] = []
	var better_kept := false
	for entry: Dictionary in read["entries"]:
		if String(entry["id"]) != "" and String(entry["id"]) == String(line["id"]):
			if best_first(entry, line):
				better_kept = true
				kept.append(entry)
			continue
		kept.append(entry)
	if not better_kept:
		kept.append(line)
	kept = sorted(kept)
	if kept.size() > MOST:
		kept.resize(MOST)
	var place := place_of(kept, String(line["id"]))
	if place == 0:
		return 0
	# The win: the adventure's One-life mark is the Hall's line now.
	var marks: Dictionary = read["one_life"]
	marks.erase(String(line["id"]))
	return place if _write(at, kept, marks) else 0


## WHAT IS KNOWN OF ONE-LIFE ADVENTURE [param id]'s final battle in the file
## at [param path] ([member file] when ""): [constant BEGUN], [constant
## FAILED], or "" (never begun, won, or no file).
static func one_life_state(id: String, path := "") -> String:
	if id == "":
		return ""
	return String(one_life_marks(path).get(id, ""))


## EVERY ONE-LIFE MARK in the file at [param path] ([member file] when ""),
## read once: `{adventure id: BEGUN | FAILED}` (a list of saves asks of
## each, [LoadAdventureScreen]).
static func one_life_marks(path := "") -> Dictionary:
	return _read(path if path != "" else file)["one_life"]


## ONE-LIFE ADVENTURE [param id]'s final battle marked [param state]
## ([constant BEGUN], [constant FAILED]; "" takes the mark away) in the
## file at [param path] ([member file] when ""), the Hall's lines kept.
## False when it could not be written (or [param id] is "", or the state
## is none of these).
static func mark_one_life(id: String, state: String, path := "") -> bool:
	if id == "" or not (state == "" or state in ONE_LIFE_STATES):
		return false
	var at := path if path != "" else file
	var read := _read(at)
	if bool(read["damaged"]):
		_set_aside(at)
	var marks: Dictionary = read["one_life"]
	if state == "":
		if not marks.has(id) and not bool(read["damaged"]):
			return true
		marks.erase(id)
	elif String(marks.get(id, "")) == state and not bool(read["damaged"]):
		return true
	else:
		marks[id] = state
	return _write(at, read["entries"], marks)


## [param list] best first ([method best_first]), a new list.
static func sorted(list: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in list:
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return best_first(a, b))
	return out


## Whether line [param a] stands before line [param b]: the higher score,
## then the harder difficulty, the fewer days, the earlier date, the name.
static func best_first(a: Dictionary, b: Dictionary) -> bool:
	if int(a["score"]) != int(b["score"]):
		return int(a["score"]) > int(b["score"])
	if int(a["difficulty"]) != int(b["difficulty"]):
		return int(a["difficulty"]) > int(b["difficulty"])
	if int(a["days"]) != int(b["days"]):
		return int(a["days"]) < int(b["days"])
	if String(a["date"]) != String(b["date"]):
		return String(a["date"]) < String(b["date"])
	return String(a["name"]) < String(b["name"])


## The place (1 the best) of adventure [param id] in [param list] (best
## first), 0 when it is not there.
static func place_of(list: Array, id: String) -> int:
	for i in list.size():
		if String((list[i] as Dictionary).get("id", "")) == id:
			return i + 1
	return 0


# -------------------------------------------------------------- reading --

## What the file at [param path] holds: `{entries, one_life, damaged}` —
## its lines best first ([method _line]), its One-life marks (each one of
## [constant ONE_LIFE_STATES] by a word of an id), and whether a file is
## there that cannot be read as the Hall (not JSON, another format, a
## newer version).
static func _read(path: String) -> Dictionary:
	var out := {"entries": [] as Array[Dictionary], "one_life": {}, "damaged": false}
	var bytes := _bytes_at(path)
	if bytes.is_empty():
		return out
	var json := JSON.new()
	var data: Variant = json.data if json.parse(bytes.get_string_from_utf8()) == OK else null
	if not data is Dictionary or String((data as Dictionary).get("format", "")) != FORMAT \
			or not ((data as Dictionary).get("version") is float or (data as Dictionary).get("version") is int) \
			or int((data as Dictionary)["version"]) < 1 or int((data as Dictionary)["version"]) > FORMAT_VERSION \
			or not (data as Dictionary).get("entries") is Array:
		out["damaged"] = true
		return out
	var lines: Array[Dictionary] = []
	for value in (data as Dictionary)["entries"]:
		var line := _line(value)
		if not line.is_empty():
			lines.append(line)
	out["entries"] = sorted(lines)
	var marks: Variant = (data as Dictionary).get("one_life", {})
	if marks is Dictionary:
		for id in marks:
			if id is String and String(id) != "" and marks[id] is String \
					and String(marks[id]) in ONE_LIFE_STATES:
				(out["one_life"] as Dictionary)[String(id)] = String(marks[id])
	return out


## A line of the file, each field of its kind (its default otherwise);
## `{}` when it has no name or no score.
static func _line(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var saved := value as Dictionary
	if not saved.get("name") is String or String(saved["name"]) == "" or not _is_number(saved.get("score")):
		return {}
	var out := {"name": String(saved["name"]), "score": _number(saved["score"])}
	for key in ["id", "portrait", "color", "date", "seed_text"]:
		out[key] = String(saved[key]) if saved.get(key) is String else ""
	for key in ["days", "wins", "attempts"]:
		out[key] = maxi(_number(saved.get(key)), 0)
	out["difficulty"] = clampi(_number(saved.get("difficulty")), 0, 3)
	out["life_rule"] = AdventurePlayer.life_rule_of(saved.get("life_rule"))
	if not out["color"] in AdventurePlayer.COLORS:
		out["color"] = ""
	return out


static func _is_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value))


static func _number(value: Variant) -> int:
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(clampf(roundf(value), -9.0e15, 9.0e15))
	return 0


static func _bytes_at(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var opened := FileAccess.open(path, FileAccess.READ)
	if opened == null:
		return PackedByteArray()
	var bytes := opened.get_buffer(opened.get_length())
	opened.close()
	return bytes


# -------------------------------------------------------------- writing --

## THE FILE WRITTEN at [param path]: [param entries] (best first) and the
## One-life [param marks], whole or not at all, read back. False when it
## could not be (the file then as it was).
static func _write(path: String, entries: Array, marks: Dictionary) -> bool:
	var bytes := JSON.stringify({"format": FORMAT, "version": FORMAT_VERSION, "about": ABOUT,
		"entries": entries, "one_life": marks}, "\t").to_utf8_buffer()
	if not _folder_ready(path.get_base_dir()) or Settings.write_atomically(path, bytes) != OK \
			or _bytes_at(path) != bytes:
		push_warning("HallOfFame: cannot write %s" % path)
		return false
	return true


## The file at [param path], which cannot be read, kept aside as
## `<path>.bad` (or `.bad2`, `.bad3` … when that is taken) before a new
## Hall is written.
static func _set_aside(path: String) -> void:
	var aside := path + ".bad"
	var n := 2
	while FileAccess.file_exists(aside):
		aside = "%s.bad%d" % [path, n]
		n += 1
	DirAccess.rename_absolute(path, aside)


## Whether [param folder] is there, or is made now — quietly false when a
## file stands where a folder of the way should be (the engine prints an
## error for a folder it cannot make; [method AdventurePlayer.save]'s
## rule).
static func _folder_ready(folder: String) -> bool:
	var at := folder
	while not DirAccess.dir_exists_absolute(at):
		if FileAccess.file_exists(at):
			return false
		var up := at.get_base_dir()
		if up == at or up == "":
			break
		at = up
	return DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) == OK
