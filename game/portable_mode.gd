class_name PortableMode
extends RefCounted
## THE PORTABLE GAME — issue #5 ("Portable version", 2026-11-04: a
## `Shandalar-portable.bat` was the answer then, and its reporter: *"In the
## future it might be more consistent to have the portable mode to be
## enabled from within the options menu itself"*), then the owner,
## 2026-11-17: *"Lets implement a portable
## option in menu! That means that all data for game working are in the
## game folder itself. The portable option would then store all things in
## portable folder under main game folder! So easy to copy and take
## around. It would become a full self-sustained package."*
##
## THE RULE: the game is portable while a folder named `portable` sits in
## the game folder — beside `Shandalar.exe`, `run.sh` or `Shandalar.app`
## ([method game_folder]). Everything the game and the engine keep then
## lives inside it: settings, decks, adventures, the Hall of Fame, the
## skins and card packs added in Options, the adventure plugins, the game
## records and the logs. Copy the whole game folder and the games go with
## it. Options › Portable game makes a game portable (the data copied in,
## [method start_copy]) and stops it (the data copied back, the folder
## renamed `portable-off`); a folder made by hand, or the Windows
## `Shandalar-portable.bat`, works the same way, starting with no data.
##
## HOW: the engine builds `user://` from the system's own data folder
## before any script runs, and from nothing else (Godot 4.7.2,
## `OS::get_user_data_dir`): `APPDATA` on Windows
## (`OS_Windows::get_config_path`, its cache from `LOCALAPPDATA`),
## `XDG_DATA_HOME` on Linux (`OS_LinuxBSD::get_data_path`), `HOME` +
## `Library/Application Support` on macOS (`OS_MacOS::get_config_path`).
## So a portable game runs with that variable pointed into `portable/`
## ([method env_for]). The launchers do it before the engine starts —
## `run.sh` and the tools' scripts on Linux and macOS, the Steam Deck's
## launcher, every `.bat` on Windows (tools/package_release.py,
## PORTABLE_SH_LINUX, PORTABLE_SH_MACOS and PORTABLE_BAT, checked
## against [constant OVERRIDDEN]) — and a start without one, `Shandalar.exe`
## or `Shandalar.app` opened as they are, starts the game once more with
## the variable set ([method enter_at_start], the first thing
## [code]Lifecycle[/code] does), before the skin, the card packs or a
## setting is read. Only the engine's own start-up log and shader cache
## (about 1 MB) of that first start are left in the system's folder.
##
## NEVER on the web, Android, the Meta Quest or ArkOS (whose launcher
## keeps the game's data in its port folder already), nor in a source
## checkout, a headless tool run or a test ([method available]).

## The folder, in the game folder.
const FOLDER := "portable"
## What the folder is renamed to when the game stops being portable —
## kept, never deleted; `portable-off-2` and on when that name is taken.
const OFF_FOLDER := "portable-off"
## The portable folder, set for a game started inside it.
const ENV_PORTABLE := "SHANDALAR_PORTABLE"
## The portable folder to rename once the game that stopped being
## portable has gone ([method retire]).
const ENV_RETIRE := "SHANDALAR_PORTABLE_RETIRE"
## The variables a portable start overrides, by system, and where the
## system's own value is kept meanwhile (an empty value: it was not set).
const OVERRIDDEN := {
	"windows": ["APPDATA", "LOCALAPPDATA"],
	"linux": ["XDG_DATA_HOME", "XDG_CACHE_HOME"],
	"macos": ["HOME"],
}
const SYSTEM_PREFIX := "SHANDALAR_SYSTEM_"
## Left out of every copy: the engine's logs, written while it runs.
const SKIPPED := ["logs"]
## Room kept free beyond what is copied.
const SPARE_BYTES := 64 * 1024 * 1024

## Tests: 1 or 0 forces [method available]; -1 asks the platform.
static var available_override := -1
## Tests: the portable folder ("" — the game folder's).
static var folder_override := ""
## Why the last start could not run inside the portable folder ("" when
## it did, or did not try).
static var start_problem := ""
## A note for Options from the start: the old portable folder renamed, or
## why it could not be.
static var start_note := ""

# ------------------------------------------------------------ the places --

## "windows", "linux" or "macos" for a desktop the engine can be pointed
## at a folder on, "" elsewhere.
static func platform() -> String:
	if OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios"):
		return ""
	match OS.get_name():
		"Windows":
			return "windows"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "linux"
		"macOS":
			return "macos"
	return ""


## Whether the game may be made portable here: an exported desktop game
## with a window, no handheld launcher of its own data (ArkOS).
static func available() -> bool:
	if available_override >= 0:
		return available_override == 1
	if platform() == "" or not OS.has_feature("template"):
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return Settings.handheld() != "arkos"


## The game folder: the executable's, or the folder that holds
## `Shandalar.app` ([method GamePaths.executable_dir]).
static func game_folder() -> String:
	return GamePaths.executable_dir(OS.get_executable_path(), OS.has_feature("macos"))


## The portable folder of the game in [param game_dir].
static func folder_in(game_dir: String) -> String:
	return game_dir.path_join(FOLDER)


static func folder() -> String:
	return folder_override if folder_override != "" else folder_in(game_folder())


## Whether this game was started inside its portable folder — this
## game's, or the one its launcher named (a game folder reached through a
## link is named one way by the launcher, the other by the engine).
static func active() -> bool:
	var named := OS.get_environment(ENV_PORTABLE)
	return inside(OS.get_user_data_dir(), folder(), platform()) \
		or (named != "" and inside(OS.get_user_data_dir(), named, platform()))


## Whether [param path] is [param dir] or inside it — by whole folder
## names, and without regard to letter case where the system does not
## regard it (Windows, macOS).
static func inside(path: String, dir: String, system: String) -> bool:
	var a := _clean(path)
	var b := _clean(dir)
	if a == "" or b == "":
		return false
	if system == "windows" or system == "macos":
		a = a.to_lower()
		b = b.to_lower()
	return a == b or a.begins_with(b + "/")


static func _clean(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/")


## What the engine's data folder is with [param dir] as the portable
## folder ([method env_for]).
static func data_path_for(system: String, dir: String) -> String:
	if system == "macos":
		return _clean(dir).path_join("Library/Application Support")
	return _clean(dir)


## `user://` inside the portable folder [param dir], for a game whose
## `user://` is [param user_dir] now: the engine keeps the last three
## names (`Godot/app_userdata/Shandalar`, `godot/…` on Linux) under its
## data folder.
static func user_dir_in(system: String, dir: String, user_dir: String) -> String:
	var parts := _clean(user_dir).split("/", false)
	var tail := "/".join(parts.slice(maxi(0, parts.size() - 3)))
	return data_path_for(system, dir).path_join(tail)


## The variables that point the engine into the portable folder [param
## dir], [param env] being the variables as they are now (by name): the
## overridden ones, the system's own values kept beside them, and
## [constant ENV_PORTABLE]. A value already kept is kept (a start from a
## portable start).
static func env_for(system: String, dir: String, env: Dictionary) -> Dictionary:
	var out := {}
	var path := _clean(dir)
	var native := path.replace("/", "\\") if system == "windows" else path
	for name in OVERRIDDEN.get(system, []):
		var kept_name: String = SYSTEM_PREFIX + String(name)
		out[kept_name] = String(env.get(kept_name, env.get(name, "")))
	match system:
		"windows":
			out["APPDATA"] = native
			out["LOCALAPPDATA"] = native
		"linux":
			out["XDG_DATA_HOME"] = native
			out["XDG_CACHE_HOME"] = native.path_join("cache")
		"macos":
			out["HOME"] = native
	out[ENV_PORTABLE] = native
	return out


## The variables as the system had them, for a game leaving the portable
## folder: name → value, "" for one to unset.
static func env_restored(system: String, env: Dictionary) -> Dictionary:
	var out := {}
	for name in OVERRIDDEN.get(system, []):
		out[name] = String(env.get(SYSTEM_PREFIX + String(name), ""))
		out[SYSTEM_PREFIX + String(name)] = ""
	out[ENV_PORTABLE] = ""
	return out


## The system's own `user://` while the game runs portable, [param
## user_dir] being the portable one and [param env] the variables (the
## system's kept ones first; else the system's defaults).
static func system_user_dir(system: String, user_dir: String, env: Dictionary) -> String:
	var parts := _clean(user_dir).split("/", false)
	var tail := "/".join(parts.slice(maxi(0, parts.size() - 3)))
	var base := ""
	match system:
		"windows":
			base = String(env.get(SYSTEM_PREFIX + "APPDATA", ""))
			if base == "" and String(env.get("USERPROFILE", "")) != "":
				base = String(env["USERPROFILE"]).path_join("AppData/Roaming")
		"linux":
			base = String(env.get(SYSTEM_PREFIX + "XDG_DATA_HOME", ""))
			if base == "" or not base.is_absolute_path():
				base = String(env.get("HOME", "")).path_join(".local/share") \
					if String(env.get("HOME", "")) != "" else ""
		"macos":
			var home := String(env.get(SYSTEM_PREFIX + "HOME", ""))
			if home == "" and String(env.get("USER", "")) != "":
				home = "/Users".path_join(String(env["USER"]))
			base = home.path_join("Library/Application Support") if home != "" else ""
	return "" if base == "" else _clean(base).path_join(tail)


static func _env(names: Array) -> Dictionary:
	var out := {}
	for name in names:
		out[name] = OS.get_environment(String(name))
	return out


## Every variable [method env_for], [method env_restored] and [method
## system_user_dir] read, as they are now.
static func env_now() -> Dictionary:
	var names: Array = [ENV_PORTABLE, ENV_RETIRE, "USERPROFILE", "USER"]
	for system in OVERRIDDEN:
		for name in OVERRIDDEN[system]:
			names.append(name)
			names.append(SYSTEM_PREFIX + String(name))
	if not "HOME" in names:
		names.append("HOME")
	return _env(names)


static func apply_env(vars: Dictionary) -> void:
	for name in vars:
		if String(vars[name]) == "":
			OS.unset_environment(String(name))
		else:
			OS.set_environment(String(name), String(vars[name]))


# ------------------------------------------------------------- the start --

## What the start does: "stay" as it is, "enter" the portable folder
## (start once more inside it), or "failed" — the folder is there but the
## game cannot run inside it ([param why] the reason, [member
## start_problem]). [param started_inside] is [constant ENV_PORTABLE] as
## the start found it: a start that was already sent inside and is not
## there never tries again.
static func plan(system: String, has_folder: bool, user_dir: String, dir: String,
		started_inside: String, writable: bool) -> String:
	if system == "" or not has_folder:
		return "stay"
	if inside(user_dir, dir, system) or (started_inside != "" and inside(user_dir, started_inside, system)):
		return "stay"
	if started_inside != "" or not writable:
		return "failed"
	return "enter"


## Whether files can be written in [param dir] (made if missing).
static func can_write(dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var probe := dir.path_join(".shandalar-write-test")
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("ok")
	file.close()
	DirAccess.remove_absolute(probe)
	return true


## Whether [param dir] could be written, MAKING NOTHING: a folder that is
## there is probed itself, one that is not by the nearest folder above it
## that is. Asking whether the game can be portable must not make the
## portable folder — an empty one left by a Cancel was entered at the next
## start, the game's settings, decks and adventures seeming gone.
static func can_hold(dir: String) -> bool:
	var at := _clean(dir)
	while at != "" and not DirAccess.dir_exists_absolute(at):
		var up := at.get_base_dir()
		if up == at:
			return false
		at = up
	return at != "" and can_write(at)


## The folder a first copy is made in, beside the portable folder [param
## dir] that is not there yet: the first free `portable-making` name. It
## becomes the portable folder only once the whole copy is in it, so a copy
## that stops halfway leaves nothing a start would enter.
static func making_name(dir: String) -> String:
	var base := _clean(dir) + "-making"
	var name := base
	var n := 1
	while DirAccess.dir_exists_absolute(name) or FileAccess.file_exists(name):
		n += 1
		name = "%s-%d" % [base, n]
	return name


## Remove the folder [param dir] and all in it — only ever a folder this
## game has just made ([method making_name]); links are removed, never
## followed.
static func remove_made(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	if here != null:
		here.include_hidden = true
		for sub in here.get_directories():
			if here.is_link(sub):
				DirAccess.remove_absolute(dir.path_join(sub))
			else:
				remove_made(dir.path_join(sub))
		for name in here.get_files():
			DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


## Why a folder that cannot be written cannot be: macOS runs a downloaded
## app from a hidden read-only copy until it is moved ("App
## Translocation"); otherwise the folder itself refuses.
static func write_problem(dir: String) -> String:
	if dir.contains("/AppTranslocation/"):
		return "macOS runs this download from a hidden read-only copy. Move the " \
			+ "game folder with Finder (out of Downloads, for example) and start it again."
	return "The game folder cannot be written to (%s). Put the game in a folder you " \
		% GamePaths.shown(dir.get_base_dir()) + "own, such as Documents or a USB stick."


## THE FIRST THING A START DOES ([code]Lifecycle[/code]): rename an old
## portable folder the last run left behind ([method retire]), then, in a
## portable game started without its launcher, start once more inside the
## folder and end this start before anything is read or written.
static func enter_at_start() -> void:
	var env := env_now()
	var system := platform()
	if String(env.get(ENV_RETIRE, "")) != "":
		retire(String(env[ENV_RETIRE]), 20)
		OS.unset_environment(ENV_RETIRE)
		return
	if not available():
		return
	var dir := folder()
	var has_folder := DirAccess.dir_exists_absolute(dir)
	var writable := has_folder and can_write(dir)
	match plan(system, has_folder, OS.get_user_data_dir(), dir, String(env.get(ENV_PORTABLE, "")), writable):
		"failed":
			start_problem = write_problem(dir) if not writable else \
				"This system did not let the game keep its data in the portable folder."
		"enter":
			if Settings.handheld() != "":
				# A handheld's launcher sets the variables (and a game
				# started twice is a game its launcher lost track of).
				start_problem = "Start the game from its launcher to use the portable folder."
				return
			apply_env(env_for(system, dir, env))
			var pid := OS.create_process(OS.get_executable_path(), launch_args())
			if pid <= 0:
				apply_env(env_restored(system, env_now()))
				start_problem = "The game could not start itself inside the portable folder."
				return
			# Nothing has been read or written yet: this start ends here,
			# and the one inside the folder goes on.
			OS.kill(OS.get_process_id())


## The start's own arguments, all of them ([code]SkinPack.relaunch_args[/code]).
static func launch_args() -> PackedStringArray:
	return load("res://game/skin_pack.gd").relaunch_args()


## Rename the portable folder [param dir] out of the way ([constant
## OFF_FOLDER]); [param tries] a quarter of a second apart, for a Windows
## game whose log was still open. The note for Options either way.
static func retire(dir: String, tries := 1) -> bool:
	if not DirAccess.dir_exists_absolute(dir):
		return true
	var target := off_name(dir.get_base_dir())
	for i in maxi(1, tries):
		if DirAccess.rename_absolute(dir, target) == OK:
			start_note = "The portable folder was renamed %s; delete it when you no longer need it." \
				% target.get_file()
			return true
		OS.delay_msec(250)
	start_note = "The portable folder could not be renamed. Rename or delete it yourself, " \
		+ "or the game will be portable again at the next start."
	return false


## The first free `portable-off` name in [param game_dir].
static func off_name(game_dir: String) -> String:
	var name := OFF_FOLDER
	var n := 1
	while DirAccess.dir_exists_absolute(game_dir.path_join(name)) \
			or FileAccess.file_exists(game_dir.path_join(name)):
		n += 1
		name = "%s-%d" % [OFF_FOLDER, n]
	return game_dir.path_join(name)


# -------------------------------------------------------------- the copy --

## Every file under [param root] to copy, by its path under it, but those
## in [constant SKIPPED] at the top: `{files: [rel...], bytes}`.
static func measure(root: String) -> Dictionary:
	var files: Array[String] = []
	var bytes := 0
	var stack: Array[String] = [""]
	while not stack.is_empty():
		var rel: String = stack.pop_back()
		var dir := DirAccess.open(root.path_join(rel) if rel != "" else root)
		if dir == null:
			continue
		dir.include_hidden = true
		for sub in dir.get_directories():
			if rel == "" and sub in SKIPPED:
				continue
			stack.append(rel.path_join(sub) if rel != "" else sub)
		for name in dir.get_files():
			var path := rel.path_join(name) if rel != "" else name
			files.append(path)
			var file := FileAccess.open(root.path_join(path), FileAccess.READ)
			if file != null:
				bytes += file.get_length()
				file.close()
	files.sort()
	return {"files": files, "bytes": bytes}


## A copy of `user://` from one folder to another, file by file on a
## worker so the screen keeps drawing ([method start_copy]); a file of the
## same name there is replaced, nothing else there is touched.
class Copy extends RefCounted:
	var from := ""
	var to := ""
	var files: Array[String] = []
	var bytes := 0
	var done_files := 0
	var done_bytes := 0
	var error := ""
	var finished := false
	var _mutex := Mutex.new()
	var _task := -1

	func progress() -> Dictionary:
		_mutex.lock()
		var out := {"files": done_files, "of_files": files.size(), "bytes": done_bytes,
			"of_bytes": bytes, "error": error, "finished": finished}
		_mutex.unlock()
		return out

	func run() -> void:
		for rel in files:
			var target := to.path_join(rel)
			var made := DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			var result := made if made != OK else DirAccess.copy_absolute(from.path_join(rel), target)
			_mutex.lock()
			if result != OK:
				error = "%s could not be copied (%s)." % [rel, error_string(result)]
				finished = true
				_mutex.unlock()
				return
			done_files += 1
			var file := FileAccess.open(target, FileAccess.READ)
			if file != null:
				done_bytes += file.get_length()
				file.close()
			_mutex.unlock()
		_mutex.lock()
		finished = true
		_mutex.unlock()

	## Wait for the worker (a screen leaving, a test).
	func wait() -> void:
		if _task >= 0:
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1


## Copy `user://` [param from] into [param to] on a worker: the [Copy] to
## watch, or the refusal ("" fields but `error`) when there is not room.
static func start_copy(from: String, to: String, threaded := true) -> Copy:
	var job := Copy.new()
	job.from = _clean(from)
	job.to = _clean(to)
	var found := measure(job.from)
	job.files.assign(found["files"])
	job.bytes = int(found["bytes"])
	# Asked first ([method can_hold]): a place that cannot be written is a
	# plain refusal, not an engine error on the log.
	if not can_hold(job.to) or DirAccess.make_dir_recursive_absolute(job.to) != OK:
		job.error = "%s could not be made." % GamePaths.shown(job.to)
		job.finished = true
		return job
	var dest := DirAccess.open(job.to)
	if dest != null and dest.get_space_left() > 0 \
			and dest.get_space_left() < job.bytes + SPARE_BYTES:
		job.error = "There is not enough room: %s to copy, %s free." % [
			size_words(job.bytes), size_words(dest.get_space_left())]
		job.finished = true
		return job
	if threaded:
		job._task = WorkerThreadPool.add_task(job.run, false, "portable copy")
	else:
		job.run()
	return job


## [param bytes] as a person reads a size.
static func size_words(bytes: int) -> String:
	if bytes >= 1024 * 1024 * 1024:
		return "%.1f GB" % (bytes / 1073741824.0)
	if bytes >= 1024 * 1024:
		return "%d MB" % roundi(bytes / 1048576.0)
	return "%d KB" % maxi(1, roundi(bytes / 1024.0))


## The copy as a line: "1,234 of 5,678 files, 1.2 GB of 2.3 GB".
static func progress_line(p: Dictionary) -> String:
	return "Copying: %d of %d files, %s of %s." % [int(p["files"]), int(p["of_files"]),
		size_words(int(p["bytes"])), size_words(int(p["of_bytes"]))]
