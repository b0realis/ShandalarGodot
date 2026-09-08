extends Node
## THE SKIN PACKS — the skin as TWO ZIPS mounted into the resource tree,
## so [GameSkin] reads them as `res://skin/...` without a single file
## being unpacked. `[QoL]`. The owner, 2026-09-08: *"a `/skin/` folder
## besides decks, music, portraits etc. where original art lives. In
## here should be the zip with our assets named original_skin along
## with a text file that catalogues all art, music, movies needed"* —
## and, for the browser, *"do 1 + 2"*: a zip DROPPED on the page, and a
## zip FETCHED from beside it. Later the same day: *"the skin assets
## should be a separate zip, card art pack should be separate! … we
## should have a menu options to select asset art skin by file
## choosing."* — so the card pictures moved out into their own zip, and
## Options grew a chooser ([method pick]).
##
## THE TWO ZIPS, one per KIND:
##   * `original_skin.zip` — kind "skin": the 1997 material. Sheets,
##     panels, fonts, sounds, tunes, movies, portraits. 84 MB.
##   * `cardart.zip` — kind "cardart": one picture per card under
##     `skin/cardart/`. 193 MB, from another source (Scryfall, through
##     `tools/fetch_card_art.py`) and on another licence, which is why
##     it travels apart. A skin zip that carries a `cardart/` folder of
##     its own is still a skin, and its pictures are read too.
## The kind of a zip is what it HOLDS ([method inspect]), never its
## name: a player may call the file what they like.
##
## WHY A ZIP, AND WHY MOUNTED. The loose `skin/` folder beside the
## executable ([method GameSkin.portable_dir]) already made a build
## portable on a desktop, but a browser has no folder beside anything:
## `user://` is an IndexedDB and `Image.load_from_file` cannot open an
## URL. What a browser CAN hold is one file — dropped on the canvas,
## chosen in a file box, or downloaded — and what the engine can do with
## one zip is mount it (`ProjectSettings.load_resource_pack`), after
## which `FileAccess`, `DirAccess`, `Image.load_from_file`, `FontFile`
## and `AudioStreamWAV.load_from_file` all read `res://skin/x` straight
## out of it. Nothing is copied, nothing is decoded ahead of need, and
## the SAME mechanism serves the desktop: the package ships both zips
## beside the executable where it used to ship the loose files, and a
## player who drops or chooses any skin zip keeps it. One contract,
## every platform.
##
## THE CONTRACT. A zip has a top-level `skin/` folder and everything
## the catalogue (`skin/SKIN.txt`, `docs/skin-catalogue.txt`) lists
## inside it — exactly what `tools/mtg_assets.py` writes from a player's
## own 1997 disc. A zip with an entry outside `skin/` is refused whole
## ([method inspect]): the mount would put its files at `res://`, where
## the game's own scripts live.
##
## WHERE THE ZIPS ARE, in the order they are mounted; on a collision the
## FIRST mount wins (`replace_files = false`), so the order is the
## precedence:
##   1. The player's SKIN ZIP: the one the `skin_zip` key names
##      ([GamePaths]), else `user://skins/original_skin.zip` — chosen,
##      dropped or fetched by the browser. Theirs, so it wins. Left
##      closed when the player set `use_skin_folder`: then the loose
##      skin folder alone dresses the game.
##   2. EVERY ZIP IN THE CARD FOLDER, `user://cardpacks/` unless the
##      `cardpacks_folder` key moved it, by name — `cardart.zip` is what
##      a chosen or fetched one is called, and a player may place more
##      (the owner, 2026-09-08: *"Card folder. Therein cardpacks as zip
##      are placed; support for future card packs"*).
##   3. `<executable>/skin/original_skin.zip`, `<executable>/skin/
##      cardart.zip` — the ones that shipped.
## A zip that arrives while the game runs is mounted with replacement,
## so a second drop supersedes the first.
##
## THE MOMENT ONE ARRIVES. Mounting is instant, but two dozen classes
## keep textures they derived from the skin they saw at start
## ([MiniCard]'s masks and stripes, [FilterBar]'s cells, [SetBadges]…),
## and a null they cached for "no skin" would stay null. On the title
## screen nothing of that has been built, so the title is simply rebuilt
## on the new art ([method GameSkin.clear_caches] and a scene reload);
## anywhere else the game says the art is in and offers a restart
## (`OS.set_restart_on_exit`; `location.reload()` in a browser). Honest,
## and one code path instead of twenty-five cache invalidations.
##
## THE BROWSER'S FETCH. With nothing stored, a web build asks for each
## zip it lacks beside its own `index.html` — `skin/original_skin.zip`
## first, `skin/cardart.zip` after it — the folder the Linux package
## uses, served as-is. A host that has no such file answers 404 and the
## game wears its clean skin, exactly as before; a host that has it
## downloads once into `user://` (IndexedDB keeps it across visits) and
## mounts it. Whether to host the 1997 art at all is the owner's call —
## `build_release.sh --web --skin` places both zips, `--web` alone does
## not.

## A pack was mounted after boot; the argument is its kind.
signal changed(kind: String)
## A transfer moved — the browser's download, or a chosen file being
## read in: the fraction done, or -1 when the size is unknown or
## nothing is in flight. The title screen and Options show it.
signal fetch_progressed(fraction: float)

## The two kinds of zip, in the order they are mounted and fetched.
const KINDS: Array[String] = ["skin", "cardart"]
## The zips' names, wherever they live.
const FILE_NAME := "original_skin.zip"
const ART_FILE_NAME := "cardart.zip"
## The player's own SKIN zips: dropped, chosen or fetched; the one worn
## is [method own_skin_zip]. Card packs go in the card folder instead
## ([method GamePaths.cardpacks_folder]).
const USER_DIR := "user://skins"
const USER_ZIP := USER_DIR + "/" + FILE_NAME
## Where the first two-zip build (the morning of 2026-09-08) kept both
## zips; [method _migrate] moves them out once.
const OLD_USER_DIR := "user://skin"
## Names in the skins folder that are a transfer, never a skin.
const IN_FLIGHT: Array[String] = ["fetching.zip", "arriving.zip"]
## Every entry inside a valid zip starts with this; every entry of a
## card art zip with the second.
const PREFIX := "skin/"
const ART_PREFIX := PREFIX + "cardart/"
## The scene that is rebuilt in place when a pack arrives on it.
const TITLE_SCENE := "res://game/main.tscn"
## Seconds before the browser's "reload" button arms — the engine
## syncs `user://` to IndexedDB on its own schedule after a file closes,
## and a reload that outruns the sync loses the zip it just saved.
const RELOAD_GUARD := 3.0
## A megabyte per download chunk: the zip is tens of megabytes and a
## 4 KB default chunk is a thousand callbacks a second.
const CHUNK := 1 << 20
## Eight megabytes per frame when a chosen file is read in from the
## page's memory — two hundred megabytes in a second and a half, and no
## single allocation the size of the whole file.
const PICK_CHUNK := 8 << 20
## Where the browser's download is written, and where it is moved to
## while still being written — see [method _process]. A chosen file is
## read into the second name too.
const FETCHING := USER_DIR + "/fetching.zip"
const ARRIVING := USER_DIR + "/arriving.zip"
## The page-side half of the browser's chooser: an `<input type=file>`
## opened for the player, its file read whole into `window.shandalarPick`
## as a Uint8Array, which [method _read_pick] then pulls across a slice
## at a time. The engine can neither open the browser's file box nor
## read a `File` itself; only a script on the page can, and this is it.
const PICK_JS := """
(function () {
	window.shandalarPick = {state: "open"};
	var input = document.createElement("input");
	input.type = "file";
	input.accept = ".zip,application/zip";
	input.style.display = "none";
	document.body.appendChild(input);
	var done = function (result) {
		window.shandalarPick = result;
		if (input.parentNode) { input.parentNode.removeChild(input); }
	};
	input.addEventListener("change", function () {
		var file = input.files && input.files[0];
		if (!file) { done({state: "cancelled"}); return; }
		var reader = new FileReader();
		reader.onload = function () {
			done({state: "ready", name: file.name, data: new Uint8Array(reader.result)});
		};
		reader.onerror = function () { done({state: "failed"}); };
		reader.readAsArrayBuffer(file);
	});
	input.addEventListener("cancel", function () { done({state: "cancelled"}); });
	input.click();
})();
"""

## The zips mounted this run, in precedence order (see [method mount]).
var mounted: Array[String] = []
## What [method inspect] said of each mounted zip, by path.
var _reports: Dictionary = {}
## Whether a browser download is in flight, and of which kind.
var fetching := false
var fetching_kind := ""
## The kinds still to fetch, in order.
var _queue: Array[String] = []
var _request: HTTPRequest = null
## The zip's size from the host's own HEAD answer, or -1: the web client
## cannot say how big a body is (`http_client_web.cpp`, always -1).
var _expected := -1
## The browser's chooser: whether one is open or its file being read,
## the file's name and size as the page reported them, how far the read
## is, and the file it is written to.
var picking := false
var _pick_name := ""
var _pick_size := 0
var _pick_offset := 0
var _pick_file: FileAccess = null
var _notice: CanvasLayer = null
var _arrived_at := 0.0


func _ready() -> void:
	_migrate()
	# The skin folder instead of the zip: no skin zip is opened, the
	# player's or the shipped one — [GameSkin] reads the folder.
	var folder_instead := GamePaths.use_skin_folder()
	if not folder_instead:
		_mount_if_present(own_skin_zip(), false)
	for path in cardpacks():
		_mount_if_present(path, false)
	if not folder_instead:
		_mount_if_present(portable_zip("skin"), false)
	_mount_if_present(portable_zip("cardart"), false)
	get_tree().root.files_dropped.connect(_on_files_dropped)
	if OS.has_feature("web"):
		for kind in KINDS:
			if not has(kind) and not (kind == "skin" and folder_instead):
				_queue.append(kind)
		_fetch_next()
	set_process(fetching)


## The first two-zip build kept `original_skin.zip` and `cardart.zip`
## together in `user://skin/`; a player who ran it finds them where this
## build looks — moved, not copied, and only where nothing newer sits.
func _migrate() -> void:
	for kind in KINDS:
		var old := OLD_USER_DIR.path_join(file_name(kind))
		var now := user_zip(kind)
		if FileAccess.file_exists(old) and not FileAccess.file_exists(now):
			DirAccess.make_dir_recursive_absolute(now.get_base_dir())
			if DirAccess.rename_absolute(old, now) == OK:
				print("skin pack: moved %s to %s" % [old, now])


## While a transfer is in flight: report how far it is, and for a
## download MOVE THE FILE OUT FROM UNDER THE REQUEST as soon as the
## request has opened it.
##
## Godot 4.7's `HTTPRequest` deletes its `download_file` in
## `cancel_request()` unless `download_complete` was set, and the branch
## that finishes a body of unknown length (read to EOF) never sets it
## (`scene/main/http_request.cpp`, the `STATUS_DISCONNECTED` branch of
## `STATUS_BODY`). On the web the length is ALWAYS unknown —
## `platform/web/http_client_web.cpp` returns -1 on purpose (GH-47597,
## GH-79327) — so every finished download on the web is deleted the
## moment it completes, and reported a success.
##
## The file is a name; the request writes to an inode. Renaming
## [const FETCHING] to [const ARRIVING] while it is open leaves the
## request writing to the same inode under the new name, and the
## deletion at the end finds nothing at the old one. The chunks go
## through `fwrite` a megabyte at a time, larger than the C buffer, so
## nothing is held back that the rename could lose. Native platforms
## know the length and never hit the branch; the rename is harmless
## there, and [method _on_fetched] accepts either name.
func _process(_delta: float) -> void:
	if picking:
		_read_pick()
		return
	if not fetching:
		return
	fetch_progressed.emit(fetch_progress())
	if _request != null and _request.download_file == FETCHING \
			and FileAccess.file_exists(FETCHING):
		DirAccess.rename_absolute(FETCHING, ARRIVING)


# ----------------------------------------------------------- the zips --

## The name a zip of [param kind] goes by.
static func file_name(kind: String) -> String:
	return ART_FILE_NAME if kind == "cardart" else FILE_NAME


## Where a zip of [param kind] the player chose, dropped or fetched goes
## by default: the skins folder, or the card folder.
static func user_zip(kind: String) -> String:
	if kind == "cardart":
		return GamePaths.cardpacks_folder().path_join(ART_FILE_NAME)
	return USER_ZIP


## Where a zip of [param kind] arriving under [param name] is kept: in
## the skins folder or the card folder, under its own name — a card
## folder holds many, and a skins folder may too, the `skin_zip` key
## saying which is worn. A name that is not a file name (a browser
## may report anything) falls back to the kind's own.
static func home_for(kind: String, name: String) -> String:
	var file := name.get_file()
	if file.get_extension().to_lower() != "zip" or not file.is_valid_filename():
		file = file_name(kind)
	return user_zip(kind).get_base_dir().path_join(file)


## The skin zip the player wears: the one the `skin_zip` key names, when
## it is there, else their own `skins/original_skin.zip` (which may not
## be there either — then the shipped one is what [method _ready] finds).
static func own_skin_zip() -> String:
	var named := GamePaths.skin_zip()
	if named != "" and FileAccess.file_exists(named):
		return named
	return USER_ZIP


## Every zip in the card folder, by name — the order they are mounted.
static func cardpacks() -> Array[String]:
	return _zips_in(GamePaths.cardpacks_folder())


## The instructions the game writes into the card folder, the way
## [PortraitLibrary] and [MusicLibrary] explain theirs.
const CARD_README_NAME := "README.txt"
const CARD_README := """CARD PACKS — the pictures on the cards

Every zip in this folder is worn by the game from its next start, in
name order; where two hold the same picture the first wins. A card
pack is a zip with skin/cardart/<card_name>.jpg (or .png) inside it —
"mishra_s_factory.jpg" for Mishra's Factory — and nothing outside
skin/. The one the game fetches or you choose in Options is called
cardart.zip; add others beside it under any name.

To build one: fetch_card_art.py beside the game downloads the pictures,
then mtg_assets.py --from-cardart <folder> --out cardart.zip packs them.
SKIN.txt beside the game lists every name the game looks for.

This folder can be moved: the cardpacks_folder key in settings.cfg.
"""


## The card folder, created if it is not there, with the README in it.
## Returns the path a human can be told to open, as
## [method PortraitLibrary.ensure_folder] does.
static func ensure_card_folder() -> String:
	var folder := GamePaths.cardpacks_folder()
	var global := ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(global)
	var readme := folder.path_join(CARD_README_NAME)
	if not FileAccess.file_exists(readme):
		var file := FileAccess.open(readme, FileAccess.WRITE)
		if file != null:
			file.store_string(CARD_README)
			file.close()
	return global


## The zips in one folder, sorted, a transfer in flight left out.
static func _zips_in(folder: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.get_extension().to_lower() == "zip" \
				and not IN_FLIGHT.has(file):
			out.append(folder.path_join(file))
		file = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


## How many files sit at the top of [param folder] — the Options rows
## count a loose skin folder that way (its sheets and sounds lie flat;
## `cardart/` and `portraits/` are folders beside them).
static func files_at(folder: String) -> int:
	var dir := DirAccess.open(folder)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			count += 1
		file = dir.get_next()
	dir.list_dir_end()
	return count


## The shipped zip's path beside the executable, or "" where there is no
## executable to be beside (the editor, a browser).
static func portable_zip(kind: String = "skin") -> String:
	var beside := GameSkin.portable_dir()
	if beside == "":
		return ""
	return beside.path_join(file_name(kind))


## Whether [param path] is a skin zip: `{ok, kind, files, art, why}`.
## Every entry must sit under `skin/` with no `..` in it — the whole zip
## is refused otherwise, because a mount puts its entries at `res://`.
## `art` counts the entries under `skin/cardart/`; a zip that holds
## nothing else is of kind "cardart", anything else is a "skin".
static func inspect(path: String) -> Dictionary:
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return _refusal("not a zip file")
	var files := 0
	var art := 0
	for name in reader.get_files():
		if name.ends_with("/"):
			continue
		if not name.begins_with(PREFIX) or name.contains("..") \
				or name.contains("\\"):
			reader.close()
			return _refusal("an entry outside skin/: " + name)
		files += 1
		if name.begins_with(ART_PREFIX):
			art += 1
	reader.close()
	if files == 0:
		return _refusal("no skin/ folder inside")
	return {"ok": true, "kind": "cardart" if art == files else "skin",
		"files": files, "art": art, "why": ""}


static func _refusal(why: String) -> Dictionary:
	return {"ok": false, "kind": "", "files": 0, "art": 0, "why": why}


## Mount [param path] at `res://skin`. [param replace] lets its entries
## supersede an earlier mount's; at boot it is false, so the first
## mounted (the player's own) keeps precedence. False when the zip is
## not a skin or the engine refuses it. [member mounted] is kept in
## PRECEDENCE order: a mount that replaces goes to its front, a boot
## mount to its back.
func mount(path: String, replace: bool) -> bool:
	var report := inspect(path)
	if not report["ok"]:
		push_warning("skin pack: %s refused — %s" % [path, report["why"]])
		return false
	if not ProjectSettings.load_resource_pack(path, replace):
		push_warning("skin pack: %s could not be mounted" % path)
		return false
	mounted.erase(path)
	if replace:
		mounted.push_front(path)
	else:
		mounted.append(path)
	_reports[path] = report
	GameSkin.pack_mounted = true
	print("skin pack: mounted %s (%s, %d files)" % [path, report["kind"], report["files"]])
	return true


func _mount_if_present(path: String, replace: bool) -> void:
	if not FileAccess.file_exists(path):
		return
	if not mount(path, replace) and path.begins_with(USER_DIR + "/"):
		# A stored zip that is not a skin (a download that was a 404
		# page, say) is never going to be one; clear it so the browser
		# fetches again next time.
		DirAccess.remove_absolute(path)


## How many files a mounted [param path] holds of [param kind] — the
## card pictures, or everything else.
func _holds(path: String, kind: String) -> int:
	var report: Dictionary = _reports.get(path, {})
	var art := int(report.get("art", 0))
	return art if kind == "cardart" else int(report.get("files", 0)) - art


## Whether something mounted dresses the game for [param kind].
func has(kind: String) -> bool:
	for path in mounted:
		if _holds(path, kind) > 0:
			return true
	return false


## The zips of the player's own — the ones the browser's "Forget my
## zips" deletes (a desktop names the folder, and the player deletes
## the zip there): every zip in the skins folder, and every zip in the card folder
## while that folder is inside the game's own home. A card folder the
## player pointed elsewhere is theirs to empty ([method GamePaths.is_own]).
static func own_zips() -> Array[String]:
	var out := _zips_in(USER_DIR)
	if GamePaths.is_own(GamePaths.cardpacks_folder()):
		out.append_array(cardpacks())
	return out


## Whether the player keeps a zip of their own, of either kind.
static func has_own() -> bool:
	return not own_zips().is_empty()


## Whose a mounted zip is: "yours" for one in the skins folder, in the
## card folder or named by the `skin_zip` key — "forgotten" when that
## file is gone but the mount remains — "shipped" beside the executable,
## "mounted" for anything else.
static func source_of(path: String) -> String:
	if path.begins_with(USER_DIR + "/") \
			or path.begins_with(GamePaths.cardpacks_folder() + "/") \
			or path == GamePaths.skin_zip():
		# A forgotten zip stays mounted until the restart; the row says
		# so rather than calling it the player's own still.
		return "yours" if FileAccess.file_exists(path) else "forgotten"
	var beside := GameSkin.portable_dir()
	if beside != "" and path.begins_with(beside):
		return "shipped"
	return "mounted"


## What dresses the game for [param kind], for the Options screen:
## `{source, name, files}` — and for the card packs `folder` (the card
## folder, as shown) and `packs`, one `{name, files, source}` per
## mounted zip that holds card pictures, in precedence order. The
## source is "yours" (the player's own zip), "shipped" (the one beside
## the executable), "mounted" (a zip from elsewhere), "forgotten" (the
## player's, deleted, worn until the restart), "folder" (loose files in
## a search folder, the way a checkout or an unzipped skin reads),
## "missing" (the skin folder is to be worn instead of the zip and is
## not there) or "none". Names are as [method GamePaths.shown] has them:
## a path a player can open.
func describe(kind: String) -> Dictionary:
	if kind == "cardart":
		return _describe_packs()
	for path in mounted:
		var count := _holds(path, kind)
		if count > 0:
			return {"source": source_of(path), "name": GamePaths.shown(path),
				"files": count}
	for dir in GameSkin.search_dirs():
		if dir == GameSkin.PACK_DIR:
			continue
		if DirAccess.dir_exists_absolute(GameSkin.locate(dir)):
			return {"source": "folder", "name": GamePaths.shown(dir),
				"files": files_at(dir)}
	if GamePaths.use_skin_folder():
		return {"source": "missing", "name": GamePaths.shown(GamePaths.skin_folder()),
			"files": 0}
	return {"source": "none", "name": "", "files": 0}


func _describe_packs() -> Dictionary:
	var about := {"source": "none", "name": "", "files": 0,
		"folder": GamePaths.shown(GamePaths.cardpacks_folder()), "packs": []}
	for path in mounted:
		var count := _holds(path, "cardart")
		if count > 0:
			about["packs"].append({"name": path.get_file(), "files": count,
				"source": source_of(path)})
	if not about["packs"].is_empty():
		var first: Dictionary = about["packs"][0]
		about["source"] = first["source"]
		about["name"] = first["name"]
		about["files"] = first["files"]
		return about
	for dir in GameSkin.search_dirs():
		if dir == GameSkin.PACK_DIR:
			continue
		var folder: String = dir.path_join("cardart")
		if DirAccess.dir_exists_absolute(GameSkin.locate(folder)):
			about["source"] = "folder"
			about["name"] = GamePaths.shown(folder)
			return about
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://assets/cardart")):
		about["source"] = "folder"
		about["name"] = GamePaths.shown("res://assets/cardart")
	return about


## The words for whose a zip is, by [method source_of]'s answer.
const WHOSE := {"yours": "your own", "shipped": "shipped with the game",
	"mounted": "mounted", "forgotten": "forgotten, worn until the restart"}


## The Options screen's line for [param kind], from what [method describe]
## found — a static so the words can be tested against any report. The
## skin row names the zip worn, by its path; the card row names the card
## folder and every pack in it.
static func status_line(kind: String, about: Dictionary) -> String:
	var source := String(about["source"])
	if kind == "cardart":
		var head := "Card folder: %s — " % String(about.get("folder", ""))
		var packs: Array = about.get("packs", [])
		if packs.is_empty():
			if source == "folder":
				return head + "no card pack; a loose folder, %s" % String(about["name"])
			return head + "no card pack yet; cards show a plain art window"
		var named := PackedStringArray()
		for pack in packs:
			named.append("%s (%s, %s)" % [String(pack["name"]),
				_count(int(pack["files"]), "picture"), WHOSE[String(pack["source"])]])
		return head + "; ".join(named)
	if source == "none":
		return "Skin: none — the game draws its own"
	if source == "missing":
		return "Skin: none — %s is not there; the game draws its own" % String(about["name"])
	if source == "folder":
		return "Skin: a loose folder, %s — %s" % [String(about["name"]),
			_count(int(about["files"]), "file")]
	return "Skin: %s — %s, %s" % [String(about["name"]),
		_count(int(about["files"]), "file"), WHOSE[source]]


static func _count(n: int, unit: String) -> String:
	return "%d %s" % [n, unit if n == 1 else unit + "s"]


## Keep [param source] as the player's own zip of whatever kind it is,
## and mount it. The copy is what makes a drop survive: a browser
## deletes the dropped file the moment the signal returns, and `user://`
## is the one place it keeps.
func adopt(source: String) -> bool:
	var report := inspect(source)
	if not report["ok"]:
		_complain(source.get_file(), String(report["why"]))
		return false
	var kind := String(report["kind"])
	var dest := home_for(kind, source)
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	if ProjectSettings.globalize_path(source) != ProjectSettings.globalize_path(dest) \
			and DirAccess.copy_absolute(source, dest) != OK:
		_complain(source.get_file(), "could not be copied into the game's folder")
		return false
	if not mount(dest, true):
		return false
	_wear(kind, dest)
	_arrived(kind)
	return true


## A skin zip that arrived is the one worn from now on: the `skin_zip`
## key names it — unless it is the default pick itself, when the key is
## cleared instead, so no default is written into the file and an older
## choice stops winning over it. A card pack needs no key: every zip in
## the card folder is worn.
static func _wear(kind: String, dest: String) -> void:
	if kind != "skin":
		return
	if dest == USER_ZIP:
		Settings.clear_value(GamePaths.KEY_SKIN_ZIP)
	else:
		Settings.set_value(GamePaths.KEY_SKIN_ZIP, dest)


## The same for a file that is already in `user://` under a passing name
## (a download, a chosen file read in): moved, not copied. [param shown]
## is the name the player knows it by, for the notice.
func _take(landed: String, shown: String) -> bool:
	var report := inspect(landed)
	if not report["ok"]:
		_complain(shown, String(report["why"]))
		DirAccess.remove_absolute(landed)
		return false
	var kind := String(report["kind"])
	var dest := home_for(kind, shown)
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	if DirAccess.rename_absolute(landed, dest) != OK or not mount(dest, true):
		DirAccess.remove_absolute(landed)
		return false
	_wear(kind, dest)
	_arrived(kind)
	return true


## Options > Skin > "Forget my zips" — built in a browser only, where
## there is no folder to open (the owner: *"Do we need forget my zips
## button?"* — on a desktop the row names the folder, and deleting the
## zip there is the same): the player's own zips are deleted
## ([method own_zips]) and the `skin_zip` key cleared, so the next start
## dresses the game in what shipped. What is mounted stays mounted for
## this run (the engine has no unmount), hence the restart on offer.
func forget() -> void:
	var gone := 0
	for path in own_zips():
		if DirAccess.remove_absolute(path) == OK:
			gone += 1
	var named := Settings.has_value(GamePaths.KEY_SKIN_ZIP)
	Settings.clear_value(GamePaths.KEY_SKIN_ZIP)
	if gone == 0 and not named:
		return
	changed.emit("")
	_show_notice("Your own %s forgotten." % ("zip is" if gone == 1 else "zips are"),
		"The game wears what shipped from the next start.", true)


# --------------------------------------------------------- the arrival --

## What happens the moment a pack is mounted after boot: the title is
## rebuilt on it; any other screen is offered a restart. See the class
## doc for why the two differ.
func _arrived(kind: String) -> void:
	GameSkin.clear_caches()
	PortraitLibrary.refresh()
	MusicLibrary.refresh()
	_arrived_at = Time.get_ticks_msec() / 1000.0
	changed.emit(kind)
	if plan_after_arrival(_current_scene_path()) == "reload":
		get_tree().reload_current_scene.call_deferred()
	elif kind == "cardart":
		_show_notice("The card art is in.",
			"The cards wear it from the next start.", true)
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


# ----------------------------------------------------------- the picker --

## Options > Skin > "Choose...": a file box for a skin or card art zip,
## which is then kept and mounted exactly as a drop is ([method adopt]):
## in the skins folder or the card folder, by what it HOLDS — [param kind]
## only titles the box.
##
## On a desktop it is the platform's own file box where the engine has
## one (`FileDialog.use_native_dialog`; on Linux through the desktop
## portal) and the engine's own box where it has not — the fallback is
## the engine's, not ours. A browser has neither: its file box is
## `<input type=file>`, which only a script on the page may open, and
## inside the click that the player's press is still part of; so the
## web path runs [const PICK_JS] on the page and the chosen file crosses
## into the engine through `JavaScriptBridge.eval`, which hands a
## Uint8Array back as a PackedByteArray — a [const PICK_CHUNK] slice per
## frame ([method _read_pick]), written to [const ARRIVING] and taken
## from there like a download.
func pick(kind: String) -> void:
	if OS.has_feature("web"):
		if picking or fetching:
			return
		picking = true
		_pick_name = ""
		_pick_size = 0
		_pick_offset = 0
		JavaScriptBridge.eval(PICK_JS, true)
		set_process(true)
		return
	var box := FileDialog.new()
	box.name = "SkinChooser"
	box.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	# After the mode: setting the mode retitles the box ("Open a File").
	box.title = "Choose the card art zip" if kind == "cardart" else "Choose a skin zip"
	box.access = FileDialog.ACCESS_FILESYSTEM
	box.filters = PackedStringArray(["*.zip ; Zip files"])
	box.use_native_dialog = true
	box.size = Vector2i(760, 520)
	box.current_dir = pick_start_dir()
	box.file_selected.connect(func(path: String) -> void:
		adopt(path)
		box.queue_free())
	box.canceled.connect(box.queue_free)
	add_child(box)
	box.popup_centered()


## Where the desktop's file box opens: the player's downloads folder,
## where a zip they fetched is, else their home.
static func pick_start_dir() -> String:
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if downloads != "" and DirAccess.dir_exists_absolute(downloads):
		return downloads
	return OS.get_environment("HOME")


## One frame of the browser's chooser: while the box is open, wait; once
## the page has the file, pull a slice across into [const ARRIVING];
## when the last slice is in, take it like a download.
func _read_pick() -> void:
	if _pick_file == null:
		var state := String(JavaScriptBridge.eval(
			"window.shandalarPick ? window.shandalarPick.state : 'gone'", true))
		if state == "open":
			return
		if state != "ready":
			_pick_over()
			return
		_pick_name = String(JavaScriptBridge.eval("window.shandalarPick.name", true))
		_pick_size = int(JavaScriptBridge.eval("window.shandalarPick.data.length", true))
		DirAccess.make_dir_recursive_absolute(USER_DIR)
		_pick_file = FileAccess.open(ARRIVING, FileAccess.WRITE)
		if _pick_file == null:
			_complain(_pick_name, "could not be written into the game's folder")
			_pick_over()
			return
	var stop := mini(_pick_offset + PICK_CHUNK, _pick_size)
	if stop > _pick_offset:
		var slice: Variant = JavaScriptBridge.eval(
			"window.shandalarPick.data.subarray(%d, %d)" % [_pick_offset, stop], true)
		if not (slice is PackedByteArray) or (slice as PackedByteArray).size() != stop - _pick_offset:
			_pick_file.close()
			_pick_file = null
			DirAccess.remove_absolute(ARRIVING)
			_complain(_pick_name, "could not be read from the page")
			_pick_over()
			return
		_pick_file.store_buffer(slice)
		_pick_offset = stop
	fetch_progressed.emit(pick_progress())
	if _pick_offset >= _pick_size:
		_pick_file.close()
		_pick_file = null
		var shown := _pick_name
		_pick_over()
		_take(ARRIVING, shown)


func _pick_over() -> void:
	JavaScriptBridge.eval("window.shandalarPick = null", true)
	picking = false
	_pick_name = ""
	_pick_size = 0
	_pick_offset = 0
	set_process(fetching)
	fetch_progressed.emit(-1.0)


## The fraction of a chosen file read in, or -1 when none is.
func pick_progress() -> float:
	if not picking or _pick_size <= 0 or _pick_file == null:
		return -1.0
	return clampf(float(_pick_offset) / float(_pick_size), 0.0, 1.0)


# ------------------------------------------------------------ the fetch --

## A zip's URL beside the page: [param href] without its query or
## fragment, cut after the last `/`, plus `skin/<the zip's name>`.
static func pack_url(href: String, kind: String = "skin") -> String:
	var base := href
	for stop in ["#", "?"]:
		var at := base.find(stop)
		if at >= 0:
			base = base.left(at)
	return base.left(base.rfind("/") + 1) + PREFIX + file_name(kind)


## The fraction downloaded, or -1 when nothing is in flight or the host
## did not say how big the file is.
func fetch_progress() -> float:
	if _request == null:
		return -1.0
	var total := _expected if _expected > 0 else _request.get_body_size()
	if total <= 0:
		return -1.0
	return clampf(float(_request.get_downloaded_bytes()) / float(total), 0.0, 1.0)


## The words for a download of [param kind] that is [param fraction]
## along — a percentage when the host said how big it is, and just the
## fact otherwise.
static func fetch_line(fraction: float, kind: String = "skin") -> String:
	var what := "the card art" if kind == "cardart" else "the 1997 art"
	if fraction < 0.0:
		return "Fetching %s…" % what
	return "Fetching %s… %d%%" % [what, int(round(fraction * 100.0))]


## What is on its way right now, for a label: the download's line, a
## chosen file's, or "" when nothing is.
func transfer_line(fraction: float) -> String:
	if picking:
		if _pick_file == null:
			return ""
		if fraction < 0.0:
			return "Reading %s…" % _pick_name
		return "Reading %s… %d%%" % [_pick_name, int(round(fraction * 100.0))]
	if fetching:
		return fetch_line(fraction, fetching_kind)
	return ""


## Whether a download or a read is in flight — what shows a progress line.
func busy() -> bool:
	return fetching or (picking and _pick_file != null)


## Ask the host how big the next zip is (HEAD), then fetch it. Two
## requests because the web client will not say how big a body is while
## it arrives, and a title line that only says "fetching" for a minute
## is a line the player stops believing.
func _fetch_next() -> void:
	if _queue.is_empty():
		return
	var href := String(JavaScriptBridge.eval("location.href", true))
	if href.is_empty():
		_queue.clear()
		return
	fetching_kind = _queue.pop_front()
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	for stale in [FETCHING, ARRIVING]:
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)
	_expected = -1
	_request = HTTPRequest.new()
	_request.request_completed.connect(_on_measured)
	add_child(_request)
	if _request.request(pack_url(href, fetching_kind), PackedStringArray(),
			HTTPClient.METHOD_HEAD) != OK:
		_request.queue_free()
		_request = null
		_queue.clear()
		return
	fetching = true
	set_process(true)


## The `content-length` a host answered with, or -1 when it did not.
static func content_length(headers: PackedStringArray) -> int:
	for header in headers:
		if header.to_lower().begins_with("content-length:"):
			var size := header.get_slice(":", 1).strip_edges().to_int()
			return size if size > 0 else -1
	return -1


func _on_measured(result: int, code: int, headers: PackedStringArray,
		_body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_expected = content_length(headers)
	_request.request_completed.disconnect(_on_measured)
	_request.request_completed.connect(_on_fetched)
	_request.download_file = FETCHING
	_request.download_chunk_size = CHUNK
	if _request.request(pack_url(String(JavaScriptBridge.eval(
			"location.href", true)), fetching_kind)) != OK:
		_fetch_over()


func _fetch_over() -> void:
	fetching = false
	set_process(picking)
	_request.queue_free()
	_request = null
	fetch_progressed.emit(-1.0)


func _on_fetched(result: int, code: int, _headers: PackedStringArray,
		_body: PackedByteArray) -> void:
	var kind := fetching_kind
	_fetch_over()
	# Whichever name the download ended under (see _process).
	var landed := ARRIVING if FileAccess.file_exists(ARRIVING) else FETCHING
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 \
			and FileAccess.file_exists(landed):
		var report := inspect(landed)
		if report["ok"]:
			if landed != ARRIVING:
				DirAccess.rename_absolute(landed, ARRIVING)
			_take(ARRIVING, file_name(kind))
		else:
			push_warning("skin pack: the fetched zip was refused — %s" % report["why"])
	else:
		push_warning("skin pack: fetch of %s failed (result %d, HTTP %d)"
			% [file_name(kind), result, code])
	# A 404 page, a cut connection, a file that is not a skin: whatever
	# was written is not a skin and must not be mounted next visit.
	for leftover in [FETCHING, ARRIVING]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(leftover)
	fetching_kind = ""
	# The next zip the page lacks, if any.
	_fetch_next()


# ----------------------------------------------------------- the notice --

## A bad zip, in the player's own words: what they dropped or chose, and
## why it was refused.
func _complain(shown: String, why: String) -> void:
	push_warning("skin pack: %s refused — %s" % [shown, why])
	_show_notice("%s is not a skin." % shown,
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
