class_name AndroidCorner
extends Node
## THE SHARED-STORAGE CORNER ON ANDROID (2026-09-29, the first Meta Quest
## report: *"app starts, no cards, no skin, no music visible"*).
##
## The player's zips reach an Android build over `adb push` into the
## app's corner of the shared storage ([method GamePaths.android_files_dir])
## — and a folder made there FROM THE SHELL (`adb shell mkdir`) is the
## shell's: `rwxrws---`, owner `shell`, and the game, its own user and
## not of that group, may not enter it. The first push made `skin/` and
## `cardpacks/` that way; the game found nothing behind them and one
## engine error (a listing that would not open), while the `portraits/`
## it had made itself worked. The files inside were readable all along.
##
## So the folders are the game's own, made before anything is pushed:
##
##   - [method prepare] makes every place of the corner at every start
##     — the four folders, a README in each — so by the time `adb push`
##     fills one it belongs to the game (the package's `push_to_quest.sh`
##     installs the APK, starts the game once and pushes into the
##     folders it made; docs/handhelds.md);
##   - [method report] says in the log what the game sees there: the
##     corner, then each folder as `ok` with what it holds, `missing`,
##     or `NOT LISTABLE` with the cure — the lines the next report needs;
##   - [method device_line] is the display's side: the window, whether
##     the display server calls itself a touchscreen, the handheld word,
##     the pads it sees;
##   - on the tree, the first event of each input class is printed once
##     ([method _input]) — whether the headset's laser comes as a touch,
##     a mouse or a pad, with the device id (`-1` is the engine's own
##     mouse emulated from a touch), which is what the pointer work turns
##     on;
##   - and every line of it is also WRITTEN, as it comes, to
##     [constant REPORT_NAME] in the corner ([method write_report]): the
##     second headset report (2026-09-29) came from `adb logcat -d` after
##     the fact, and Android's main log buffer, filled by the headset
##     shell's own chatter, had lost every line of the start within three
##     minutes — only the first click survived. The file is the last
##     start's whole report, pulled at any time with `adb pull`.
##
## Every function takes the corner as a parameter, so a test runs them
## on a scratch folder on a desk; [Lifecycle] runs them on Android only.

const README_NAME := "README.txt"
const SKIN_README := """SKIN — the game's look, and the card pictures

The two zips go here, pushed from the package folder:

  adb push skin/original_skin.zip <this folder>/
  adb push skin/cardart.zip <this folder>/

original_skin.zip is the original look (the -with-skin package carries
it); cardart.zip is your own card pictures, which no package carries
(CARD-ART-AND-PACKS.md). The game reads this folder at its next start.

The game made this folder. Push into the folders it made: a folder made
with `adb shell mkdir` is the shell's, and the game may not enter it —
if you made one, delete it (`adb shell rm -rf <it>`), start the game
once, then push.
"""
## The corner's places, by their word.
const SKIN := "skin"
const CARDPACKS := "cardpacks"
const PORTRAITS := "portraits"
const MUSIC := "music"
## What a folder listing came to.
const OK_LISTED := "ok"
const MISSING := "missing"
const UNLISTABLE := "unlistable"
## How many input classes are reported before the tracer goes quiet.
const TRACED_CLASSES := 10
## The last start's report, written into the corner line by line.
const REPORT_NAME := "start_report.txt"

## The corner the report is written into; "" writes nothing (a desk).
var corner := ""
## The lines this node said, in order — the report.
var traced: Array[String] = []
var _seen := {}


## The four folders of the corner at [param files_dir], by their word —
## the defaults there ([method GamePaths.player_place]); a key the
## player wrote moves the game's own reading, not these.
static func folders(files_dir: String) -> Dictionary:
	return {
		SKIN: GameSkin.portable_dir_for(files_dir),
		CARDPACKS: GamePaths.player_place(GamePaths.DEFAULT_CARDPACKS, files_dir),
		PORTRAITS: GamePaths.player_place(GamePaths.DEFAULT_PORTRAITS, files_dir),
		MUSIC: GamePaths.player_place(GamePaths.DEFAULT_MUSIC, files_dir),
	}


## Make the four folders, each with its README, where they are not.
## Returns the folders made or found, by their word; nothing for "".
static func prepare(files_dir: String) -> Dictionary:
	if files_dir == "":
		return {}
	var made := folders(files_dir)
	var readmes := {
		SKIN: [README_NAME, SKIN_README],
		CARDPACKS: [SkinPack.CARD_README_NAME, SkinPack.CARD_README],
		PORTRAITS: [PortraitLibrary.README_NAME, PortraitLibrary.README],
		MUSIC: [MusicLibrary.README_NAME, MusicLibrary.README],
	}
	for word in made:
		var folder: String = made[word]
		DirAccess.make_dir_recursive_absolute(folder)
		var readme: String = folder.path_join(readmes[word][0])
		if not FileAccess.file_exists(readme):
			var file := FileAccess.open(readme, FileAccess.WRITE)
			if file != null:
				file.store_string(readmes[word][1])
				file.close()
	return made


## What listing [param folder] comes to: `state` one of [constant
## OK_LISTED], [constant MISSING] (does not open) or [constant
## UNLISTABLE] (opens, will not list — the shell's folder), and the
## sorted `names` in it.
static func listing(folder: String) -> Dictionary:
	var dir := DirAccess.open(folder)
	if dir == null:
		return {"state": MISSING, "names": []}
	if dir.list_dir_begin() != OK:
		return {"state": UNLISTABLE, "names": []}
	var names: Array[String] = []
	var name := dir.get_next()
	while name != "":
		names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return {"state": OK_LISTED, "names": names}


## One log line for the folder [param word] at [param folder] as
## [method listing] found it.
static func line_for(word: String, folder: String, found: Dictionary) -> String:
	var state: String = found["state"]
	if state == MISSING:
		return "android: %s %s: missing" % [word, folder]
	if state == UNLISTABLE:
		return ("android: %s %s: NOT LISTABLE - made from the shell? " +
			"delete it (adb shell rm -rf \"%s\"), start the game once, " +
			"then push into the folder the game made") % [word, folder, folder]
	var names: Array = found["names"]
	return "android: %s %s: ok, %d %s" % [word, folder, names.size(),
		"entries (%s)" % ", ".join(names) if not names.is_empty() else "entries"]


## The lines that say what the game sees in the corner at
## [param files_dir]: the corner, then one per folder.
static func report(files_dir: String) -> Array[String]:
	var out: Array[String] = []
	if files_dir == "":
		out.append("android: no shared-storage corner")
		return out
	out.append("android: corner %s" % files_dir)
	var places := folders(files_dir)
	for word in places:
		out.append(line_for(word, places[word], listing(places[word])))
	return out


## The first line of a start: the game and the moment.
static func version_line() -> String:
	return "android: Shandalar %s, started %s" % [
		String(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		Time.get_datetime_string_from_system(false, true)]


## How long the engine took to reach the tracer — the start's length.
static func ready_line() -> String:
	return "android: tree ready after %d ms" % Time.get_ticks_msec()


## The display's side, one line.
static func device_line() -> String:
	var pads: Array[String] = []
	for id in Input.get_connected_joypads():
		pads.append("%d:%s" % [id, Input.get_joy_name(id)])
	var handheld := Settings.handheld()
	return "android: window %dx%d, touchscreen %s, handheld %s, pads [%s]" % [
		DisplayServer.window_get_size().x, DisplayServer.window_get_size().y,
		"yes" if DisplayServer.is_touchscreen_available() else "no",
		handheld if handheld != "" else "none", ", ".join(pads)]


## What one event is, for the trace: its class, device and the part of
## it the pointer work reads.
static func describe(event: InputEvent) -> String:
	var parts: Array[String] = ["device %d%s" % [event.device,
		" (mouse emulated from a touch)" if event.device == InputEvent.DEVICE_ID_EMULATION else ""]]
	if event is InputEventMouseButton:
		parts.append("button %d %s at %s" % [event.button_index,
			"down" if event.pressed else "up", _at(event.position)])
	elif event is InputEventMouseMotion:
		parts.append("at %s, buttons %d" % [_at(event.position), event.button_mask])
	elif event is InputEventScreenTouch:
		parts.append("finger %d %s at %s" % [event.index,
			"down" if event.pressed else "up", _at(event.position)])
	elif event is InputEventScreenDrag:
		parts.append("finger %d at %s" % [event.index, _at(event.position)])
	elif event is InputEventJoypadButton:
		parts.append("button %d %s on %s" % [event.button_index,
			"down" if event.pressed else "up", Input.get_joy_name(event.device)])
	elif event is InputEventJoypadMotion:
		parts.append("axis %d at %.2f on %s" % [event.axis, event.axis_value,
			Input.get_joy_name(event.device)])
	elif event is InputEventKey:
		parts.append("key %s %s" % [OS.get_keycode_string(event.keycode),
			"down" if event.pressed else "up"])
	return "android: first %s: %s" % [event.get_class(), ", ".join(parts)]


static func _at(position: Vector2) -> String:
	return "%d,%d" % [int(position.x), int(position.y)]


## Write [param lines] as [constant REPORT_NAME] in the corner at
## [param files_dir]; false where there is no corner or no writing it.
static func write_report(files_dir: String, lines: Array[String]) -> bool:
	if files_dir == "":
		return false
	var file := FileAccess.open(files_dir.path_join(REPORT_NAME), FileAccess.WRITE)
	if file == null:
		return false
	for line in lines:
		file.store_line(line)
	file.close()
	return true


## The tracer joins the tree after the autoloads: the start's length,
## the display, then what the skin and the card packs said (their own
## lines, already in the log — noted for the report only).
func _ready() -> void:
	say(ready_line())
	say(device_line())
	if SkinPack.mounted.is_empty():
		note("skin pack: nothing mounted")
	for line in SkinPack.report_lines:
		note(line)
	for line in CardPacks.report_lines:
		note(line)


## The first event of each class, once, until [constant TRACED_CLASSES]
## classes were seen; nothing is consumed.
func _input(event: InputEvent) -> void:
	var cls := event.get_class()
	if _seen.has(cls) or _seen.size() >= TRACED_CLASSES:
		return
	_seen[cls] = true
	say(describe(event))


## Say [param line]: to the log, and to the report.
func say(line: String) -> void:
	printerr(line)
	note(line)


## Put [param line] in the report only — the log has it already.
func note(line: String) -> void:
	traced.append(line)
	write_report(corner, traced)
