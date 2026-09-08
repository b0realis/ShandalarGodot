class_name GamePaths
extends RefCounted
## THE PLAYER'S PLACES — every folder and file the player may fill or
## point the game at, each one a key in `user://settings.cfg`. `[QoL]`.
## The owner, 2026-09-08: *"a checkbox — 'use art folder instead of
## zip' (the default folder location should be shown in settings but
## can also be changed in cfg) … additional music folder: user sees
## there is a folder he can put music in … Additional Portraits folder
## … Card folder (therein cardpacks as zip are placed; support for
## future card packs). Write in settings also that these folder
## locations can be changed in the cfg file!"* — and on what the two
## folders do: *"Music by user is added to original scores and played,
## and portraits by the user are added to originals and displayed on
## portrait selection."*
##
## SIX KEYS, under `[options]` like every other setting, and NONE IS
## WRITTEN until the player changes it — a default materialised into
## the file is a default that can never change (see
## [method Settings.clear_value] for the "fan" hand that shipped once):
##
##   skin_zip          the skin zip worn: "" for the game's own pick —
##                     the player's `skins/original_skin.zip`, else the
##                     one that shipped beside the executable
##   use_skin_folder   true: the zip stays closed and the skin folder
##                     alone dresses the game
##   skin_folder       loose files the way `import_original.py` lays
##                     them out;                     user://original_skin
##   cardpacks_folder  every zip in it is mounted at boot; user://cardpacks
##   portraits_folder  the player's own faces, shown with the 1997 ones
##                     in the portrait chooser;      user://portraits
##   music_folder      the player's own tunes, played among the 1997
##                     ones;                         user://music
##
## A value is `user://…`, `res://…` or an absolute path; a leading `~`
## is the home folder. Each is read where it is used — [SkinPack] at
## boot, [method GameSkin.search_dirs], [member PortraitLibrary.dirs],
## [member MusicLibrary.dirs] — so an edit to the file takes effect at
## the next start. The Options screen's `Skin:` section shows every
## place and names the keys ([method OptionsScreen._add_skin_section]).

const KEY_SKIN_ZIP := "skin_zip"
const KEY_USE_SKIN_FOLDER := "use_skin_folder"
const KEY_SKIN_FOLDER := "skin_folder"
const KEY_CARDPACKS := "cardpacks_folder"
const KEY_PORTRAITS := "portraits_folder"
const KEY_MUSIC := "music_folder"

const DEFAULT_SKIN_FOLDER := "user://original_skin"
const DEFAULT_CARDPACKS := "user://cardpacks"
const DEFAULT_PORTRAITS := "user://portraits"
const DEFAULT_MUSIC := "user://music"

## The keys a player may set by hand, in the order the Options note
## names them.
const PLACE_KEYS: Array[String] = [KEY_SKIN_ZIP, KEY_SKIN_FOLDER,
	KEY_CARDPACKS, KEY_PORTRAITS, KEY_MUSIC]


## The skin zip the `skin_zip` key names, or "" for the game's own pick.
static func skin_zip() -> String:
	return _place(KEY_SKIN_ZIP, "")


## Options > Skin > "Use the skin folder instead of the zip". The screen
## writes a bool; a hand that typed `true`, `yes`, `on` or `1` into the
## file is read as meant.
static func use_skin_folder() -> bool:
	var value: Variant = Settings.get_value(KEY_USE_SKIN_FOLDER, false)
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String:
		return String(value).strip_edges().to_lower() in ["true", "yes", "on", "1"]
	return false


static func set_use_skin_folder(on: bool) -> void:
	Settings.set_value(KEY_USE_SKIN_FOLDER, on)


## Loose skin files, the way `tools/import_original.py` lays them out.
static func skin_folder() -> String:
	return _place(KEY_SKIN_FOLDER, DEFAULT_SKIN_FOLDER)


## The card packs: every zip here is mounted at boot ([SkinPack]).
static func cardpacks_folder() -> String:
	return _place(KEY_CARDPACKS, DEFAULT_CARDPACKS)


## The player's own portraits ([PortraitLibrary]).
static func portraits_folder() -> String:
	return _place(KEY_PORTRAITS, DEFAULT_PORTRAITS)


## The player's own music ([MusicLibrary]).
static func music_folder() -> String:
	return _place(KEY_MUSIC, DEFAULT_MUSIC)


## One key's path, tidied: a `~` expanded, a trailing slash dropped, and
## the built-in place for a value that is empty or not a string at all.
static func _place(key: String, fallback: String) -> String:
	var value: Variant = Settings.get_value(key, fallback)
	if not (value is String):
		return fallback
	var path := expand(String(value)).strip_edges()
	if path.length() > 1 and path.ends_with("/"):
		path = path.trim_suffix("/")
	return fallback if path == "" else path


## A leading `~` is the home folder, as a shell would read it.
static func expand(path: String) -> String:
	if path == "~" or path.begins_with("~/"):
		return OS.get_environment("HOME") + path.substr(1)
	return path


## A place as a human can find it: the absolute path on a desktop, with
## the home folder as `~` (the owner: the rows read too long in full),
## the `user://` name in a browser, where there is no path to open and
## the engine's own name is the honest one.
static func shown(path: String) -> String:
	if path == "" or OS.has_feature("web"):
		return path
	var full := ProjectSettings.globalize_path(path)
	var home := OS.get_environment("HOME")
	if home.length() > 1 and (full == home or full.begins_with(home + "/")):
		return "~" + full.substr(home.length())
	return full


## Where the keys live, for the Options note.
static func settings_file() -> String:
	return shown(Settings.PATH)


## Whether [param path] is inside the game's own home. "Forget my zips"
## deletes only there: a folder the player pointed elsewhere is theirs
## to empty.
static func is_own(path: String) -> bool:
	return path.begins_with("user://")
