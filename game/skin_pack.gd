extends Node
## THE SKIN PACK — the whole skin as ONE ZIP, `original_skin.zip`,
## mounted into the resource tree so [GameSkin] reads it as
## `res://skin/...` without a single file being unpacked. `[QoL]`. The
## owner, 2026-09-08: *"a `/skin/` folder besides decks, music, portraits
## etc. where original art lives. In here should be the zip with our
## assets named original_skin along with a text file that catalogues all
## art, music, movies needed"* — and, for the browser, *"do 1 + 2"*: a
## zip DROPPED on the page, and a zip FETCHED from beside it.
##
## WHY A ZIP, AND WHY MOUNTED. The loose `skin/` folder beside the
## executable ([method GameSkin.portable_dir]) already made a build
## portable on a desktop, but a browser has no folder beside anything:
## `user://` is an IndexedDB and `Image.load_from_file` cannot open an
## URL. What a browser CAN hold is one file — dropped on the canvas, or
## downloaded — and what the engine can do with one zip is mount it
## (`ProjectSettings.load_resource_pack`), after which `FileAccess`,
## `DirAccess`, `Image.load_from_file`, `FontFile` and
## `AudioStreamWAV.load_from_file` all read `res://skin/x` straight out
## of it. Nothing is copied, nothing is decoded ahead of need, and the
## SAME mechanism serves the desktop: the package ships
## `skin/original_skin.zip` where it used to ship the loose files, and a
## player who drops any skin zip on the game window keeps it. One
## contract, every platform.
##
## THE CONTRACT. The zip has a top-level `skin/` folder and everything
## the catalogue (`skin/SKIN.txt`, `docs/skin-catalogue.txt`) lists
## inside it — exactly what `tools/mtg_assets.py` writes from a player's
## own 1997 disc. A zip with an entry outside `skin/` is refused whole
## ([method inspect]): the mount would put its files at `res://`, where
## the game's own scripts live.
##
## WHERE THE ZIPS ARE, in the order they are mounted; on a collision the
## FIRST mount wins (`replace_files = false`), so the order is the
## precedence:
##   1. `user://skin/original_skin.zip` — the one the player dropped on
##      the window, or the browser fetched. Theirs, so it wins.
##   2. `<executable>/skin/original_skin.zip` — the one that shipped.
## A zip that arrives while the game runs is mounted with replacement,
## so a second drop supersedes the first.
##
## THE MOMENT IT ARRIVES. Mounting is instant, but two dozen classes
## keep textures they derived from the skin they saw at start
## ([MiniCard]'s masks and stripes, [FilterBar]'s cells, [SetBadges]…),
## and a null they cached for "no skin" would stay null. On the title
## screen nothing of that has been built, so the title is simply rebuilt
## on the new art ([method GameSkin.clear_caches] and a scene reload);
## anywhere else the game says the art is in and offers a restart
## (`OS.set_restart_on_exit`; `location.reload()` in a browser). Honest,
## and one code path instead of twenty-five cache invalidations.
##
## THE BROWSER'S FETCH. With nothing stored, a web build asks for
## `skin/original_skin.zip` beside its own `index.html` — the folder the
## Linux package uses, served as-is. A host that has no such file answers
## 404 and the game wears its clean skin, exactly as before; a host that
## has it downloads once into `user://` (IndexedDB keeps it across
## visits) and mounts it. Whether to host the 1997 art at all is the
## owner's call — `build_release.sh --web --skin` places it, `--web`
## alone does not.

## A pack was mounted after boot.
signal changed
## The browser's download moved: the fraction done, or -1 when the size
## is unknown or nothing is being fetched. The title screen shows it.
signal fetch_progressed(fraction: float)

## The zip's name, wherever it lives.
const FILE_NAME := "original_skin.zip"
## The player's own copy: dropped, or fetched.
const USER_DIR := "user://skin"
const USER_ZIP := USER_DIR + "/" + FILE_NAME
## Every entry inside a valid zip starts with this.
const PREFIX := "skin/"
## The scene that is rebuilt in place when a pack arrives on it.
const TITLE_SCENE := "res://game/main.tscn"
## Seconds before the browser's "reload" button arms — the engine
## syncs `user://` to IndexedDB on its own schedule after a file closes,
## and a reload that outruns the sync loses the zip it just saved.
const RELOAD_GUARD := 3.0
## A megabyte per chunk: the zip is tens of megabytes and a 4 KB default
## chunk is a thousand callbacks a second.
const CHUNK := 1 << 20

## The zips mounted this run, in mount order.
var mounted: Array[String] = []
## Whether a browser download is in flight.
var fetching := false
var _request: HTTPRequest = null
var _notice: CanvasLayer = null
var _arrived_at := 0.0


func _ready() -> void:
	_mount_if_present(USER_ZIP, false)
	var beside := portable_zip()
	if beside != "":
		_mount_if_present(beside, false)
	get_tree().root.files_dropped.connect(_on_files_dropped)
	if OS.has_feature("web") and mounted.is_empty():
		_start_fetch()
	set_process(false)


func _process(_delta: float) -> void:
	if fetching:
		fetch_progressed.emit(fetch_progress())


# ----------------------------------------------------------- the zips --

## The shipped zip's path beside the executable, or "" where there is no
## executable to be beside (the editor, a browser).
static func portable_zip() -> String:
	var beside := GameSkin.portable_dir()
	if beside == "":
		return ""
	return beside.path_join(FILE_NAME)


## Whether [param path] is a skin zip: `{ok, files, why}`. Every entry
## must sit under `skin/` with no `..` in it — the whole zip is refused
## otherwise, because a mount puts its entries at `res://`.
static func inspect(path: String) -> Dictionary:
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return {"ok": false, "files": 0, "why": "not a zip file"}
	var files := 0
	for name in reader.get_files():
		if name.ends_with("/"):
			continue
		if not name.begins_with(PREFIX) or name.contains("..") \
				or name.contains("\\"):
			reader.close()
			return {"ok": false, "files": 0,
				"why": "an entry outside skin/: " + name}
		files += 1
	reader.close()
	if files == 0:
		return {"ok": false, "files": 0, "why": "no skin/ folder inside"}
	return {"ok": true, "files": files, "why": ""}


## Mount [param path] at `res://skin`. [param replace] lets its entries
## supersede an earlier mount's; at boot it is false, so the first
## mounted (the player's own) keeps precedence. False when the zip is
## not a skin or the engine refuses it.
func mount(path: String, replace: bool) -> bool:
	var report := inspect(path)
	if not report["ok"]:
		push_warning("skin pack: %s refused — %s" % [path, report["why"]])
		return false
	if not ProjectSettings.load_resource_pack(path, replace):
		push_warning("skin pack: %s could not be mounted" % path)
		return false
	mounted.append(path)
	GameSkin.pack_mounted = true
	print("skin pack: mounted %s (%d files)" % [path, report["files"]])
	return true


func _mount_if_present(path: String, replace: bool) -> void:
	if not FileAccess.file_exists(path):
		return
	if not mount(path, replace) and path == USER_ZIP:
		# A stored zip that is not a skin (a download that was a 404
		# page, say) is never going to be one; clear it so the browser
		# fetches again next time.
		DirAccess.remove_absolute(path)


## Keep [param source] as the player's own zip and mount it. The copy is
## what makes a drop survive: a browser deletes the dropped file the
## moment the signal returns, and `user://` is the one place it keeps.
func adopt(source: String) -> bool:
	var report := inspect(source)
	if not report["ok"]:
		_complain(source.get_file(), String(report["why"]))
		return false
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	if source != USER_ZIP and DirAccess.copy_absolute(source, USER_ZIP) != OK:
		_complain(source.get_file(), "could not be copied into the game's folder")
		return false
	if not mount(USER_ZIP, true):
		return false
	_arrived()
	return true


# --------------------------------------------------------- the arrival --

## What happens the moment a pack is mounted after boot: the title is
## rebuilt on it; any other screen is offered a restart. See the class
## doc for why the two differ.
func _arrived() -> void:
	GameSkin.clear_caches()
	PortraitLibrary.refresh()
	MusicLibrary.refresh()
	_arrived_at = Time.get_ticks_msec() / 1000.0
	changed.emit()
	if plan_after_arrival(_current_scene_path()) == "reload":
		get_tree().reload_current_scene.call_deferred()
	else:
		_show_notice("The 1997 art is in.",
			"It dresses the game from the next start.", true)


## "reload" when the pack arrived on the title screen, "restart"
## anywhere else — kept pure so the choice can be tested without a tree.
static func plan_after_arrival(scene_path: String) -> String:
	return "reload" if scene_path == TITLE_SCENE else "restart"


func _current_scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


## Leave and come back: the desktop relaunches the same binary with the
## same arguments; a browser reloads its page.
func restart() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()")
		return
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


# ------------------------------------------------------------- the drop --

func _on_files_dropped(files: PackedStringArray) -> void:
	for path in files:
		if path.get_extension().to_lower() == "zip":
			adopt(path)
			return


# ------------------------------------------------------------ the fetch --

## The zip's URL beside the page: [param href] without its query or
## fragment, cut after the last `/`, plus `skin/original_skin.zip`.
static func pack_url(href: String) -> String:
	var base := href
	for stop in ["#", "?"]:
		var at := base.find(stop)
		if at >= 0:
			base = base.left(at)
	return base.left(base.rfind("/") + 1) + PREFIX + FILE_NAME


## The fraction downloaded, or -1 when nothing is in flight or the host
## did not say how big the file is.
func fetch_progress() -> float:
	if _request == null:
		return -1.0
	var total := _request.get_body_size()
	if total <= 0:
		return -1.0
	return clampf(float(_request.get_downloaded_bytes()) / float(total), 0.0, 1.0)


func _start_fetch() -> void:
	var href := String(JavaScriptBridge.eval("location.href", true))
	if href.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	_request = HTTPRequest.new()
	_request.download_file = USER_ZIP
	_request.download_chunk_size = CHUNK
	_request.request_completed.connect(_on_fetched)
	add_child(_request)
	if _request.request(pack_url(href)) != OK:
		_request.queue_free()
		_request = null
		return
	fetching = true
	set_process(true)


func _on_fetched(result: int, code: int, _headers: PackedStringArray,
		_body: PackedByteArray) -> void:
	fetching = false
	set_process(false)
	_request.queue_free()
	_request = null
	fetch_progressed.emit(-1.0)
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 \
			and inspect(USER_ZIP)["ok"]:
		if mount(USER_ZIP, true):
			_arrived()
		return
	# A 404 page, a cut connection, a file that is not a skin: whatever
	# was written is not a skin and must not be mounted next visit.
	if FileAccess.file_exists(USER_ZIP):
		DirAccess.remove_absolute(USER_ZIP)


# ----------------------------------------------------------- the notice --

## A bad zip, in the player's own words: what they dropped, and why it
## was refused.
func _complain(file_name: String, why: String) -> void:
	push_warning("skin pack: %s refused — %s" % [file_name, why])
	_show_notice("%s is not a skin." % file_name,
		why.capitalize() + ". A skin zip has a skin/ folder inside it.", false)


## The overlay over whatever screen is up: a stone panel with a line or
## two and, with [param offer_restart], a button that restarts (armed
## after [constant RELOAD_GUARD] in a browser) beside one that does not.
func _show_notice(headline: String, detail: String, offer_restart: bool) -> void:
	_hide_notice()
	var layer := CanvasLayer.new()
	layer.layer = 128
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var head := UiChrome.body_label(headline, 18)
	column.add_child(head)
	column.add_child(UiChrome.body_label(detail, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	if offer_restart:
		var go := UiChrome.menu_button(
			"Reload the page" if OS.has_feature("web") else "Restart now",
			Vector2(170, 34), 16)
		go.name = "Restart"
		go.pressed.connect(restart)
		if OS.has_feature("web"):
			go.disabled = true
			get_tree().create_timer(RELOAD_GUARD).timeout.connect(
				func() -> void:
					if is_instance_valid(go):
						go.disabled = false)
		row.add_child(go)
	var later := UiChrome.menu_button("Later" if offer_restart else "OK",
		Vector2(110, 34), 16)
	later.name = "Later"
	later.pressed.connect(_hide_notice)
	row.add_child(later)
	column.add_child(row)
	var panel := UiChrome.panel_around(column, 14.0)
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position.y -= 24
	layer.add_child(panel)
	add_child(layer)
	_notice = layer


func _hide_notice() -> void:
	if _notice != null:
		_notice.queue_free()
		_notice = null


## The notice on screen, or null — for the tests.
func notice() -> CanvasLayer:
	return _notice
