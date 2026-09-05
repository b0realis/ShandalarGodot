class_name PortraitLibrary
extends RefCounted
## THE PLAYER'S OWN FACE — every portrait a player may wear, wherever it
## came from.
##
## The duelist beside a deck is DERIVED (`DuelistFace.portrait`, keyed by
## the deck's dominant colour, the way the original chose it). This is the
## other half: a face the player CHOOSES for themselves. Nothing in a duel
## reads it yet — it is the avatar the adventure (`docs/ROADMAP.md`, M5)
## will need, and the battle-setup screen offers it now so the choice
## exists and is remembered.
##
## THREE PLACES, IN THIS ORDER, first one wins on a name clash:
##
##   1. `user://portraits/`              the player's own art
##   2. `user://original_skin/portraits/` what tools/import_original.py cut
##                                        from their copy of the 1997 game
##   3. `res://assets/original/portraits/` the same, in a dev checkout
##
## The player's folder comes first ON PURPOSE: someone who drops in a face
## named like an imported one means to replace it.
##
## LOADING BYPASSES THE IMPORT PIPELINE (`Image.load_from_file`), exactly
## as [GameSkin] does and for the same reason — a file dropped into
## `user://portraits` after the game shipped has no `.import` companion
## and never will, so it has to be read as bytes rather than as a Godot
## resource. That is what makes "drop a PNG in and restart" work in an
## exported build.
##
## NO ART IS SHIPPED. `Provenance.md`: the original's files are the
## player's own copy, never this repository's, so an unskinned install
## finds nothing here and the chooser says where to put some.

## Searched in order; see the class doc.
const DEFAULT_DIRS: Array[String] = [
	"user://portraits",
	"user://original_skin/portraits",
	"res://assets/original/portraits",
]

## The portable copy, beside the executable — the same idea, and the same
## reason, as [method GameSkin.portable_dir]: art that travels with the
## build rather than living in one machine's home directory.
static func portable_dirs() -> Array[String]:
	var beside := GameSkin.portable_dir()
	if beside == "":
		return []
	# Both shapes work: `portraits/` beside the executable, and the
	# `skin/portraits/` an imported skin already puts them in.
	return [beside.get_base_dir().path_join("portraits"),
		beside.path_join("portraits")]


## The folders actually searched. A VAR, and the reason is the same one
## [member SetBadges.icons] carries: a machine that HAS the 1997 art
## imported cannot otherwise exercise the code paths for a machine that
## does not, and "what happens with no portraits at all" is exactly the
## state a player meets first. Tests point this at a scratch folder and
## put it back; nothing else touches it.
static var dirs: Array[String] = DEFAULT_DIRS.duplicate()

## What counts as a portrait. `Image.load_from_file` reads all four.
const EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]

## The instructions the game writes into the player's folder, so the
## folder explains itself without anybody reading the manual.
const README_NAME := "README.txt"
const README := """PORTRAITS — your own face in the game
=====================================

Drop image files in this folder and they appear in the portrait chooser
on the Magic Battle screen, next to your deck.

WHAT WORKS
  * PNG, JPG or WEBP. PNG with transparency is best — the frame behind
    the portrait is stone, and a transparent background lets it show.
  * Any size. The game fits the image to the frame and keeps its aspect
    ratio, so nothing is stretched. Around 120x150 is the shape the
    original's own faces use; anything close to that reads well.
  * One file per portrait. Sub-folders are ignored.

THE NAME UNDER THE PORTRAIT is the file name, tidied up:
      grey_wizard.png     ->  Grey Wizard
      Sisay-the-Bold.jpg  ->  Sisay The Bold
  Underscores and dashes become spaces and each word is capitalised, so
  name the file what you want to read.

THE ORDER is alphabetical by that name, and it is stable — a portrait
  keeps its place in the list when you add another.

REPLACING AN IMPORTED FACE: a file here wins over one that came from
  your copy of the 1997 game. Same file name, your version.

The game reads this folder when it starts. Add files, then restart.
"""


static var _cache: Array[Dictionary] = []
static var _textures: Dictionary = {}


## Every portrait found, as `{id, name, path}`, sorted by name. `id` is
## the file's base name and is what gets remembered in the settings file —
## never an index, so adding a portrait cannot silently change which one a
## player chose.
static func all() -> Array[Dictionary]:
	if not _cache.is_empty():
		return _cache
	var seen := {}
	var found: Array[Dictionary] = []
	var looked: Array[String] = [dirs[0]]
	looked.append_array(portable_dirs())
	for i in range(1, dirs.size()):
		looked.append(dirs[i])
	for dir_path in looked:
		for file in _files_in(dir_path):
			var id := file.get_basename()
			if seen.has(id):
				continue          # an earlier directory already has it
			seen[id] = true
			found.append({"id": id, "name": title_of(id),
				"path": dir_path.path_join(file)})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	_cache = found
	return _cache


## Forget what was found, so the next [method all] looks again. The
## chooser calls this after creating the folder, and tests after writing
## into it.
static func refresh() -> void:
	_cache = []
	_textures = {}


## One portrait's texture, or null. Cached by id.
static func texture(id: String) -> Texture2D:
	if id == "":
		return null
	if _textures.has(id):
		return _textures[id]
	var result: Texture2D = null
	for entry in all():
		if entry["id"] != id:
			continue
		var image := Image.load_from_file(
			ProjectSettings.globalize_path(String(entry["path"])))
		if image != null:
			result = ImageTexture.create_from_image(image)
		break
	_textures[id] = result
	return result


## `grey_wizard` -> `Grey Wizard`. Underscores and dashes are spaces; see
## the README this writes into the player's folder.
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


## The image files in one directory, ignoring the README, sub-folders and
## anything that is not an image. Sorted, so the search order below is the
## only thing that decides precedence.
static func _files_in(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and _is_image(file):
			out.append(file)
		file = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func _is_image(file: String) -> bool:
	# An exported build lists `x.png.import`/`.remap` beside nothing at
	# all; only a real extension counts (see CardRegistry.card_files_in
	# for the same trap, found the same day).
	return EXTENSIONS.has(file.get_extension().to_lower())
