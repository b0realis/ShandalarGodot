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
## On Android those three defaults sit in the app's shared-storage
## corner instead ([method android_files_dir]): `user://` is private
## there and a player could never put a zip in it.
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
const KEY_TOURNAMENTS := "tournaments_folder"
const KEY_DRAFTS := "drafts_folder"

const DEFAULT_SKIN_FOLDER := "user://original_skin"
const DEFAULT_CARDPACKS := "user://cardpacks"
const DEFAULT_PORTRAITS := "user://portraits"
const DEFAULT_MUSIC := "user://music"
const DEFAULT_TOURNAMENTS := "user://tournaments"
const DEFAULT_DRAFTS := "user://decks"

## The keys a player may set by hand, in the order the Options note
## names them.
const PLACE_KEYS: Array[String] = [KEY_SKIN_ZIP, KEY_SKIN_FOLDER,
	KEY_CARDPACKS, KEY_PORTRAITS, KEY_MUSIC]


## THE PLAYER'S PLACES ON ANDROID (2026-09-29, the Meta Quest build).
## There `user://` is the app's PRIVATE folder — nothing outside the
## app can write into it, so a zip could never be put in the card
## folder — while the app's own corner of the shared storage,
## `/sdcard/Android/data/com.b0realis.shandalar/files`, is written by
## `adb push` and read by the app without any permission. The three
## folders the player fills live there, under the same names, with
## `skin/` beside them ([method GameSkin.portable_dir]): the desktop
## play copy's layout, one level down. The settings file, the decks
## and the tournament checkpoints stay in `user://` — the game writes
## those, not the player, and a private folder is the right place for
## them. Everywhere else this is "" and nothing moves.
static func android_files_dir() -> String:
	if not OS.has_feature("android"):
		return ""
	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP, false)


## [param user_path] as the player fills it: under [param files_dir]
## where there is one (Android), the `user://` place itself otherwise.
static func player_place(user_path: String, files_dir: String) -> String:
	if files_dir == "" or not user_path.begins_with("user://"):
		return user_path
	return files_dir.trim_suffix("/").path_join(user_path.trim_prefix("user://"))


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
	return _place(KEY_CARDPACKS, player_place(DEFAULT_CARDPACKS, android_files_dir()))


## The player's own portraits ([PortraitLibrary]).
static func portraits_folder() -> String:
	return _place(KEY_PORTRAITS, player_place(DEFAULT_PORTRAITS, android_files_dir()))


## The player's own music ([MusicLibrary]).
static func music_folder() -> String:
	return _place(KEY_MUSIC, player_place(DEFAULT_MUSIC, android_files_dir()))


## Private LAN organiser checkpoints; no transport keys or live hidden zones.
static func tournaments_folder() -> String:
	return _place(KEY_TOURNAMENTS, DEFAULT_TOURNAMENTS)


## Draft decks default to the ordinary deck collection. Explicit choices only.
static func drafts_folder() -> String:
	return _place(KEY_DRAFTS, DEFAULT_DRAFTS)


static func draft_folder_refusal(value: String) -> String:
	var path := expand(value.strip_edges()).replace("\\", "/")
	if path.is_empty() or path.length() > 4096 or not path.is_absolute_path() \
			or (path.contains("://") and not path.begins_with("user://")):
		return "Choose an absolute save folder, or use the default deck folder."
	for character in path:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127:
			return "The save folder cannot contain control characters."
	if FileAccess.file_exists(path):
		return "Choose a folder, not a file."
	return ""


static func set_drafts_folder(value: String) -> String:
	var refusal := draft_folder_refusal(value)
	if refusal != "": return refusal
	var path := expand(value.strip_edges()).replace("\\", "/").simplify_path()
	if path == DEFAULT_DRAFTS:
		Settings.clear_value(KEY_DRAFTS)
	elif path != drafts_folder():
		Settings.set_value(KEY_DRAFTS, path)
	return ""


## Explicit organiser choice only. Reading a default never writes settings,
## choosing a folder never moves existing checkpoints or sends a path to peers.
static func set_tournaments_folder(value: String) -> String:
	var path := expand(value.strip_edges()).replace("\\", "/")
	if path.is_empty(): path = DEFAULT_TOURNAMENTS
	if path.length() > 4096 or not path.is_absolute_path() \
		or (path.contains("://") and not path.begins_with("user://")):
		return "Choose an absolute folder path, or use the default tournament folder."
	for character in path:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127:
			return "A tournament folder path cannot contain control characters."
	path = path.simplify_path()
	if FileAccess.file_exists(path): return "That path is a file. Choose a folder for tournament saves."
	if path == DEFAULT_TOURNAMENTS:
		if Settings.has_value(KEY_TOURNAMENTS): Settings.clear_value(KEY_TOURNAMENTS)
	elif path != tournaments_folder(): Settings.set_value(KEY_TOURNAMENTS, path)
	return ""


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
		var home := _home_dir()
		if home != "":
			return home if path == "~" else home.path_join(path.substr(2))
	return path


## [QoL] A native Windows launch need not have the Unix HOME variable.
## With only USERPROFILE set, ~/Music used to become /Music (reproduced
## with an isolated environment, 2026-09-13). Never invent a root path
## when neither home is known; browsers can keep using user:// instead.
static func _home_dir() -> String:
	var home := OS.get_environment("HOME")
	if home == "":
		home = OS.get_environment("USERPROFILE")
	home = home.replace("\\", "/")
	return home if home == "/" or home.ends_with(":/") else home.trim_suffix("/")


## A place as a human can find it: the absolute path on a desktop, with
## the home folder as `~` (the owner: the rows read too long in full),
## the `user://` name in a browser, where there is no path to open and
## the engine's own name is the honest one.
static func shown(path: String) -> String:
	if path == "" or OS.has_feature("web"):
		return path
	var full := ProjectSettings.globalize_path(path)
	var home := _home_dir()
	if home.length() > 1 and (full == home or full.begins_with(home + "/")):
		return "~" + full.substr(home.length())
	return full


## Where the keys live, for the Options note.
static func settings_file() -> String:
	return shown(Settings.PATH)


## [QoL] A macOS app is one bundle to the player. Portable files belong
## beside it. An exported duel probe on 2026-09-12 created a 464-byte
## Contents/MacOS/duel_log.txt inside the signed app before this fix.
## Explicit arguments let the same path contract be checked on any host.
static func executable_dir(executable: String, macos: bool) -> String:
	var folder := executable.get_base_dir()
	if macos and folder.to_lower().ends_with(".app/contents/macos"):
		return folder.get_base_dir().get_base_dir().get_base_dir()
	return folder


## Whether [param path] is inside the game's own home. "Forget my zips"
## deletes only there: a folder the player pointed elsewhere is theirs
## to empty.
static func is_own(path: String) -> bool:
	if not path.begins_with("user://"):
		return false
	# [QoL] A written user:// prefix is not a containment check. Before
	# this fix the regression reported "Asserts 47/50": all three parent
	# escapes were accepted, so own_zips() could offer another folder's
	# packs to forget(). Compare resolved, normalised directory boundaries.
	var root := ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	var full := ProjectSettings.globalize_path(path.replace("\\", "/")).simplify_path()
	if full != root and not full.begins_with(root + "/"):
		return false
	# A symlink inside the profile can still lead outside it. Treat linked
	# places as the player's to manage, just like an absolute folder key.
	# Walk the written components BEFORE collapsing '..': link/../file
	# follows the link on disk, so normalisation must not hide that link.
	var current := root
	for part in path.trim_prefix("user://").replace("\\", "/").split("/", false):
		if part == ".":
			continue
		if part == "..":
			if current == root:
				return false
			current = current.get_base_dir()
			continue
		var parent := DirAccess.open(current)
		if parent != null and parent.is_link(part):
			return false
		current = current.path_join(part)
	return true
