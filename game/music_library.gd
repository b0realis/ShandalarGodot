class_name MusicLibrary
extends RefCounted
## EVERY TUNE THE GAME CAN PLAY — the original's, and the player's own.
##
## **WHY THIS EXISTS.** Until 2026-09-03 a duel played one file,
## `Dueltune.wav`, patched to loop. That file is **ten seconds long** —
## 889 184 bytes of 22 050 Hz SIXTEEN-BIT STEREO, which is 10.08 s and not
## the twenty a mono reading of it suggests. A duel is not ten seconds, so
## the owner heard the same ten seconds a hundred times and said so: *"Music in the duel is wrong — now it is repeating a short
## sample — unacceptable. Check music songs available (expose this also in
## music and user can add their own)."* This is that check, and the answer
## is that the 1997 game has **twenty-seven** loopable beds, not one.
##
## WHAT THE ORIGINAL HAS, all of it in `Sound/` and all of it now
## importable (`tools/import_original.py`, the MUSIC block):
##
##   * `Dueltune.wav`      the duel's own bed, 10.1 s
##   * `LocMus0..19`       the twenty location tracks, 25-39 s each.
##                         `MAGIC.EXE` picks one by terrain index
##                         (`index % 20`, entry `004e7f51`); the deck
##                         builder draws from 1..19 (`deckdll.cpp:2047`).
##   * `Tmplmus1.wav`      the Temple, terrain slot 19, 24.9 s
##   * `[BGRUW]castle.wav` five castle beds, one per colour, 28-33 s
##
## Left out on purpose, because a stinger inside a shuffle is a
## jump-scare: `Dngnduel.wav` (the "you encounter" line), `Wingame.wav`
## (winning the whole adventure), and `Winduel`/`Loseduel`, which are
## already the duel's win and lose cues.
##
## **`user://music/` — THE PLAYER'S OWN, and it works the same way
## `user://portraits/` does** ([PortraitLibrary], which this is modelled
## on down to the README it writes). Same search order (the player's
## folder first, so a file of theirs REPLACES an imported one of the same
## name), same byte-level loading that bypasses Godot's import pipeline so
## a file dropped in after the game shipped still plays, same "the game
## reads the folder when it starts".
##
## **NOTHING IS CACHED HERE, and that is deliberate.** These are whole
## songs: one imported `LocMus` is ~2.8 MB of 22 kHz PCM, and the
## twenty-seven together are 76 MB. [GameSkin]'s sound cache is
## process-long and would hold every one of them for the rest of the
## session, so music does NOT go through it — [method stream] reads the
## file each time it is asked, and the only thing holding a tune in memory
## is the [AudioStreamPlaylist] currently playing. [MusicPlayer.MAX_TRACKS]
## is what bounds that.

## The player's own folder. A `var` for the same reason
## [PortraitLibrary.dirs] is one: a machine that HAS the original imported
## cannot otherwise exercise the code paths for a machine that does not.
## Tests point this at a scratch folder and put it back.
static var dirs: Array[String] = ["user://music"]

## Where an IMPORTED track is looked for. `null` means "ask [GameSkin]",
## which is what ships. A test sets it — to a scratch folder, or to `[]`
## for a machine with nothing imported — because otherwise this suite
## would test one thing on the developer's machine, which HAS the 1997
## music, and a different thing on a machine that does not. Same seam,
## same reason, as [member dirs] and [member PortraitLibrary.dirs].
static var skin_dirs: Variant = null

## What counts as a tune. All three load without an `.import` companion —
## see [method stream].
const EXTENSIONS: Array[String] = ["wav", "ogg", "mp3"]

## The instructions the game writes into the player's folder, so the
## folder explains itself without anybody reading the manual. Same shape,
## and the same promises, as [constant PortraitLibrary.README].
const README_NAME := "README.txt"
const README := """MUSIC — your own soundtrack
===========================

Drop music files in this folder and they join the game's own playlist.
Pick one, or shuffle them all, under Options -> Music.

WHAT WORKS
  * WAV, OGG (Vorbis) or MP3. Any length, any sample rate, mono or
    stereo. Whole songs are the point — the game plays a track through
    and moves to the next one, it does not loop a fragment.
  * One file per track. Sub-folders are ignored.

THE NAME IN THE MENU is the file name, tidied up:
      windswept_march.ogg   ->  Windswept March
      Grim-Tutor.mp3        ->  Grim Tutor
  Underscores and dashes become spaces and each word is capitalised, so
  name the file what you want to read.

REPLACING ONE OF THE ORIGINAL'S TRACKS: a file here wins over one that
  came from your copy of the 1997 game. Name it after the track you want
  to replace and yours plays instead:
      music_duel.ogg          the duel's own tune
      music_location_1.ogg    .. music_location_19, the location tracks
      music_location_0.ogg    the adventure's own
      music_temple.ogg        the Temple
      music_castle_white.ogg  .. _blue, _black, _red, _green

THE ORIGINAL'S TRACKS come first in the menu, then yours, alphabetically.

The game reads this folder when it starts. Add files, then restart.
"""

## THE ORIGINAL'S OWN TRACKS, in the original's own order: `[skin key,
## the name a human reads]`. The key is what `tools/import_original.py`
## writes and what [GameSkin] searches for; the name is ours, because the
## 1997 game never showed these titles anywhere — there is no `@`-tag for
## them in any string table, so inventing a poetic name would be
## inventing. "Location 7" is what the file is.
const ORIGINAL_TRACKS := [
	["music_duel", "Duel"],
	["music_location_0", "Location 0"],
	["music_location_1", "Location 1"],
	["music_location_2", "Location 2"],
	["music_location_3", "Location 3"],
	["music_location_4", "Location 4"],
	["music_location_5", "Location 5"],
	["music_location_6", "Location 6"],
	["music_location_7", "Location 7"],
	["music_location_8", "Location 8"],
	["music_location_9", "Location 9"],
	["music_location_10", "Location 10"],
	["music_location_11", "Location 11"],
	["music_location_12", "Location 12"],
	["music_location_13", "Location 13"],
	["music_location_14", "Location 14"],
	["music_location_15", "Location 15"],
	["music_location_16", "Location 16"],
	["music_location_17", "Location 17"],
	["music_location_18", "Location 18"],
	["music_location_19", "Location 19"],
	["music_temple", "Temple"],
	["music_castle_white", "Castle (White)"],
	["music_castle_blue", "Castle (Blue)"],
	["music_castle_black", "Castle (Black)"],
	["music_castle_red", "Castle (Red)"],
	["music_castle_green", "Castle (Green)"],
]

# ------------------------------------------------------- what to play --

## Shuffle every track. `[QoL]`, and the DEFAULT — see the class doc for
## why looping one twenty-second file is not an option any more.
const CHOICE_SHUFFLE := "shuffle"

## The 1997 behaviour, kept and labelled: ONE bed per screen, looped for
## as long as the screen is up. `Dueltune.wav` in a duel, a random
## `LocMus` in the deck builder — exactly what `MAGIC.EXE` (entry
## `004ebfef`) and `deckdll.cpp:2047` do.
const CHOICE_ORIGINAL := "original"

## The stored key. One value, many views: the Options screen writes it and
## every screen with music reads it, the contract the two sound switches
## already keep.
const SETTING := "music_choice"


## What the player chose: [constant CHOICE_SHUFFLE], [constant
## CHOICE_ORIGINAL], or a track id from [method all].
static func choice() -> String:
	return String(Settings.get_value(SETTING, CHOICE_SHUFFLE))


static func set_choice(value: String) -> void:
	Settings.set_value(SETTING, value)


## The tracks to play for a screen that asked for [param context_key]
## (`music_duel`, `music_location_7`...), in order.
##
## THE CONTEXT KEY IS STILL HONOURED IN EVERY MODE, which is what lets the
## duel screen and the deck builder go on calling
## `play_key("music_duel")` and mean it:
##
##  * `original` — just that key, looped. The 1997 answer.
##  * a track id — just that track, looped. The player asked for one tune.
##  * `shuffle`  — that key FIRST and then everything else, shuffled, so a
##    duel still opens on `Dueltune` and the deck builder still opens on
##    the track it drew. What changes is what happens ten seconds
##    later.
##
## Returns `[]` when nothing is available, which every caller treats as
## silence.
static func playlist_for(context_key: String) -> Array[String]:
	var picked := choice()
	if picked == CHOICE_ORIGINAL:
		return _just(context_key)
	if picked != CHOICE_SHUFFLE:
		return _just(picked)
	var ids := ids_of(all())
	if ids.is_empty():
		return []
	ids.shuffle()
	if ids.has(context_key):
		ids.erase(context_key)
		ids.push_front(context_key)
	return ids


## THE ONE BED A SCREEN LOOPS, for a screen that wants a single tune
## rather than a playlist — the Deck Builder, since the owner's playtest
## of 2026-09-04: *"Deck builder: only the first song you now use should
## loop over."*
##
## WHAT "THE FIRST SONG" MEANS, and it is deliberately not "whatever the
## shuffle drew". A shuffle's first track is a different tune every time
## the screen opens, so "the first song" would name nothing a player could
## come back to. It is THE LIBRARY'S OWN ORDER instead — [constant
## ORIGINAL_TRACKS], the order the 1997 files are numbered in — so the
## answer is stable across runs, across shuffles, and across the player
## dropping their own tracks into `user://music`.
##
## THE OPTIONS CHOICE STILL WINS. A player who picked ONE track under
## Options -> Music asked for that track everywhere, and this returns it;
## `shuffle` and `original` are the two modes that mean "you choose", and
## for them this walks [param candidates] in order and takes the first one
## the player actually has. A machine with nothing imported and one file
## of its own still gets that file, via the final fallback — silence is
## reserved for a library that is genuinely empty.
static func single_for(candidates: Array[String]) -> String:
	var picked := choice()
	if picked != CHOICE_SHUFFLE and picked != CHOICE_ORIGINAL and has(picked):
		return picked
	for id in candidates:
		if has(id):
			return id
	var every := all()
	return String(every[0]["id"]) if not every.is_empty() else ""


## The beds the DECK BUILDER draws from, in the library's own order —
## `LocMus1..19`. `init_sounds_and_music`
## (`shandalar-src/src/deck/deckdll.cpp:2047`) opens the deck surface on
## `sprintf(path, "Sound\\LocMus%d.wav", RANDRANGE(1, 19))` and
## `RANDRANGE` is inclusive at both ends (`:746`), so the range is 1..19.
## `LocMus0` exists and belongs to the adventure's own preload list, which
## is why it is not in here.
static func deck_builder_beds() -> Array[String]:
	var out: Array[String] = []
	for i in range(1, 20):
		out.append("music_location_%d" % i)
	return out


## One track, if it is there — a TYPED array, which matters: a bare `[id]`
## literal is an untyped `Array` at runtime whatever the return annotation
## says, and the caller's `:=` then refuses it.
static func _just(id: String) -> Array[String]:
	var out: Array[String] = []
	if has(id):
		out.append(id)
	return out


## Just the `id` column of what [method all] returned.
static func ids_of(entries: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for entry in entries:
		out.append(String(entry["id"]))
	return out


# ---------------------------------------------------------- the library --

static var _cache: Array[Dictionary] = []


## Every tune available, as `{id, name, path, mine}`. `id` is what gets
## stored in the settings file — never an index, so adding a track cannot
## silently change which one a player chose.
##
## ORDER: the original's own tracks first, in the original's order, then
## whatever the player added, alphabetically. A player file whose name
## matches one of the original's keys does not appear twice — it REPLACES
## that track, in place, keeping the readable name.
static func all() -> Array[Dictionary]:
	if not _cache.is_empty():
		return _cache
	var mine := {}
	for dir_path in _search_dirs():
		for file in _files_in(dir_path):
			var id := file.get_basename()
			if not mine.has(id):        # an earlier directory wins
				mine[id] = dir_path.path_join(file)
	var out: Array[Dictionary] = []
	for row in ORIGINAL_TRACKS:
		var id: String = row[0]
		var path: String = String(mine.get(id, ""))
		var is_mine := path != ""
		if not is_mine:
			path = skin_path(id)
		if path == "":
			continue                    # not imported, and not replaced
		out.append({"id": id, "name": String(row[1]), "path": path,
			"mine": is_mine})
		mine.erase(id)
	var extra: Array[Dictionary] = []
	for id in mine:
		extra.append({"id": String(id), "name": title_of(String(id)),
			"path": String(mine[id]), "mine": true})
	extra.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	out.append_array(extra)
	_cache = out
	return _cache


## Is there a tune under this id?
static func has(id: String) -> bool:
	for entry in all():
		if entry["id"] == id:
			return true
	return false


## The readable name for an id, or the id itself when it is not a track
## (so a stale settings value still says something).
static func name_of(id: String) -> String:
	for entry in all():
		if entry["id"] == id:
			return String(entry["name"])
	return title_of(id)


## Forget what was found, so the next [method all] looks again. The
## Options screen calls this after creating the folder, and tests after
## writing into it.
static func refresh() -> void:
	_cache = []


## One tune, loaded. Null for an id that is not there, a file that has
## gone, or a format the engine refuses — every caller treats null as
## silence.
##
## LOADING BYPASSES THE IMPORT PIPELINE, exactly as [GameSkin] and
## [PortraitLibrary] do and for the same reason: a file dropped into
## `user://music` after the game shipped has no `.import` companion and
## never will. `load_from_file` on each of the three stream types reads
## the bytes directly, which is what makes "drop a track in and restart"
## work in an exported build.
##
## NOT CACHED — see the class doc. The caller holds what it is playing.
static func stream(id: String) -> AudioStream:
	for entry in all():
		if entry["id"] != id:
			continue
		var path := String(entry["path"])
		match path.get_extension().to_lower():
			"wav":
				return AudioStreamWAV.load_from_file(path)
			"ogg":
				return AudioStreamOggVorbis.load_from_file(path)
			"mp3":
				return AudioStreamMP3.load_from_file(path)
		return null
	return null


## `windswept_march` -> `Windswept March`. Underscores and dashes are
## spaces; see the README this writes into the player's folder.
static func title_of(id: String) -> String:
	var words := id.replace("_", " ").replace("-", " ").strip_edges()
	var out: Array[String] = []
	for word in words.split(" ", false):
		out.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(out)


## The player's own folder, created if it is not there, with the README in
## it. Returns the path a human can be told to open — the GLOBAL one,
## because `user://` means nothing outside Godot.
static func ensure_folder() -> String:
	var global := ProjectSettings.globalize_path(dirs[0])
	DirAccess.make_dir_recursive_absolute(global)
	var readme := dirs[0].path_join(README_NAME)
	if not FileAccess.file_exists(readme):
		var file := FileAccess.open(readme, FileAccess.WRITE)
		if file != null:
			file.store_string(README)
			file.close()
	return global


# ------------------------------------------------------------ plumbing --

## The player's folders, in order: `user://music` first, then a `music/`
## folder beside the executable — the portable copy, the same idea and the
## same reason as [method PortraitLibrary.portable_dirs].
static func _search_dirs() -> Array[String]:
	var out: Array[String] = [dirs[0]]
	var beside := GameSkin.portable_dir()
	if beside != "":
		out.append(beside.get_base_dir().path_join("music"))
		out.append(beside.path_join("music"))
	for i in range(1, dirs.size()):
		out.append(dirs[i])
	return out


## Where an IMPORTED track sits, searched exactly as [GameSkin] searches —
## `user://original_skin`, the portable copy, then a dev checkout. Done
## here rather than through `GameSkin.sound` so that finding a track does
## not LOAD it (see the class doc on memory).
static func skin_path(key: String) -> String:
	for dir_path in (GameSkin.search_dirs() if skin_dirs == null else skin_dirs):
		var path: String = String(dir_path).path_join(key + ".wav")
		if FileAccess.file_exists(path):
			return path
	return ""


## The tunes in one directory, ignoring the README, sub-folders and
## anything that is not audio. Sorted, so the search order above is the
## only thing that decides precedence.
static func _files_in(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and _is_audio(file):
			out.append(file)
		file = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func _is_audio(file: String) -> bool:
	# An exported build lists `x.ogg.import`/`.remap` beside nothing at
	# all; only a real extension counts (the same trap
	# `PortraitLibrary._is_image` and `CardRegistry.card_files_in` guard).
	return EXTENSIONS.has(file.get_extension().to_lower())
