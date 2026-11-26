class_name PackBuildHost
extends RefCounted
## THE GAME AS THE PACK BUILDER SEES IT — the card folder, the catalogue's
## lock, the pack contracts' own checks, the network — in one place, so
## [PackBuild] and [PackBuilderWindow] can be run against a stand-in. The
## tests replace it: no test opens a socket, mounts a zip or rescans the
## real catalogue.

const CACHE := "user://cardpack_build"
## The work folder inside the card folder: a finished zip is renamed from
## it into place, so the move is one rename on one disk. Not a zip, so
## nothing that mounts the card folder's zips looks at it.
const BUILDING := "building"


## The settings key of the window's "Go easy on Scryfall's servers" tick.
const GENTLE_KEY := "card_packs_gentle"


## Whether the player keeps the pause between pictures — ticked unless
## they unticked it, and remembered across starts.
func gentle() -> bool:
	return bool(Settings.get_value(GENTLE_KEY, true))


func set_gentle(on: bool) -> void:
	Settings.set_value(GENTLE_KEY, on)


## Why no pack may change now — a LAN table holds the catalogue — or "".
func refusal() -> String:
	return CardPacks.change_refusal()


## Where finished packs go.
func folder() -> String:
	return GamePaths.cardpacks_folder()


## Where a pack's pictures are kept while it is built: `<this>/<id>/`.
func cache_root() -> String:
	return CACHE


func transport() -> PackTransport:
	return PackTransport.new()


func now_msec() -> int:
	return Time.get_ticks_msec()


## Bytes free where the packs are built, or -1 when the platform cannot say.
func free_bytes() -> int:
	var least := -1
	for place: String in [folder(), cache_root()]:
		DirAccess.make_dir_recursive_absolute(place)
		var dir := DirAccess.open(place)
		var free := int(dir.get_space_left()) if dir != null else 0
		if free > 0 and (least < 0 or free < least):
			least = free
	return least


## Why a pack cannot be built where the packs are built — the work folder
## in the card folder or the cache will not take a file — or "". Tried with
## a file of a few bytes that goes again at once (named as a build's own
## part, so [method clear_work] takes it should the game end under it); the
## work folder goes again too when that leaves it empty.
func unwritable() -> String:
	var work := folder().path_join(BUILDING)
	for place: String in [work, cache_root()]:
		var ok := _can_be_made(place)
		if ok:
			DirAccess.make_dir_recursive_absolute(place)
			var probe := place.path_join("probe.zip.part")
			var file := FileAccess.open(probe, FileAccess.WRITE)
			ok = file != null and file.store_string("probe")
			if file != null:
				file.close()
			DirAccess.remove_absolute(probe)
		if not ok:
			DirAccess.remove_absolute(work)
			return "The game cannot write in %s. Check that the folder is there and may be written to." % GamePaths.shown(
				folder() if place == work else place)
	DirAccess.remove_absolute(work)
	return ""


## False when a file lies where [param place] or a folder above it should
## be: asked first, so the engine is not made to try and complain.
static func _can_be_made(place: String) -> bool:
	var at := place
	while not DirAccess.dir_exists_absolute(at):
		if FileAccess.file_exists(at):
			return false
		var above := at.get_base_dir()
		if above == at or above == "":
			break
		at = above
	return true


## How [param id] stands: `{state, note}` with state
##   "installed"  in the card folder and in use — not built again
##   "elsewhere"  in use from another place (beside the game, a checkout)
##   "refused"    a file of its name is in the card folder and was refused
##                (`note` says why); a build replaces it
##   "absent"
func status(id: String) -> Dictionary:
	var info := PackRecipes.about(id)
	var file := folder().path_join(String(info.get("file_name", "")))
	var here := FileAccess.file_exists(file)
	if id == PackRecipes.BASE:
		if here and not SkinPack.refused.has(file):
			return {"state": "installed", "note": ""}
		if here:
			return {"state": "refused", "note": String(SkinPack.refused[file])}
		if SkinPack.has("cardart") or String(SkinPack.describe("cardart").get("source", "none")) != "none":
			return {"state": "elsewhere", "note": ""}
		return {"state": "absent", "note": ""}
	if CardPacks.has_pack(id):
		var used := String(CardPacks.info(id).get("path", ""))
		var same := ProjectSettings.globalize_path(used) == ProjectSettings.globalize_path(file)
		return {"state": "installed" if same else "elsewhere", "note": ""}
	if here:
		return {"state": "refused", "note": String(CardPacks.status(id).get("rejection", ""))}
	return {"state": "absent", "note": ""}


## The game's own check of a finished zip of [param id] at [param path]:
## `{ok, why}`. A numbered pack is judged by its contract with the
## pictures' digest taken from the manifest — [PackWriter] has just read
## every picture back against the digests that manifest was made from —
## and the 1997 pictures by the rule for an art zip.
func judge(id: String, path: String) -> Dictionary:
	if path.get_file() != String(PackRecipes.about(id).get("file_name", "")):
		return {"ok": false, "why": "it is not named as %s must be" % id}
	if id == PackRecipes.BASE:
		var report: Dictionary = SkinPack.inspect(path)
		if bool(report.get("ok", false)) and String(report.get("kind", "")) != "cardart":
			return {"ok": false, "why": "it is not a card art zip"}
		return report
	return CardPacks.inspect(path, true)


## Put the checked zip [param staged] in the card folder under its exact
## name: "" or why not. A numbered pack is sealed ([PackSeal]) — its
## pictures have just been read and compared — so the rescan does not read
## them all again.
func place(id: String, staged: String) -> String:
	var final := folder().path_join(staged.get_file())
	if DirAccess.rename_absolute(staged, final) != OK:
		return "The finished pack could not be put in %s." % GamePaths.shown(folder())
	if id != PackRecipes.BASE:
		PackSeal.seal(PackSeal.fingerprint(final))
	return ""


## The work folder emptied and removed: a zip or a part an earlier run
## left there when the game was closed under it. Only what a build writes
## there is touched — `*.zip` and `*.zip.part` — and the folder goes only
## when that leaves it empty.
func clear_work() -> void:
	var work := folder().path_join(BUILDING)
	var dir := DirAccess.open(work)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and (entry.ends_with(".zip") or entry.ends_with(".zip.part")):
			DirAccess.remove_absolute(work.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(work)


## After the last build: the catalogue reads the card folder again when a
## numbered pack among [param ids] was put there. The card pool is rebuilt
## on a thread ([method CardPacks.rescan], campaign 2026-11-26 — in the
## foreground it froze the window most of a second); the window waits for
## [method settling] to say it is in.
func settle(ids: Array) -> void:
	for id: String in ids:
		if id != PackRecipes.BASE:
			CardPacks.rescan(true)
			return


## True while the card pool [method settle] asked for is still being
## built. Asked once a frame; it never waits.
func settling() -> bool:
	return CardRegistry.is_loading() and not CardRegistry.poll()


## A CACHE NOBODY WILL USE AGAIN (campaign 2026-11-26). A pack's pictures
## are kept under [method cache_root] until that same build has put the
## pack in place. A pack that came in another way — a zip the player
## copied in after stopping a download — or whose tidying was cut short
## kept its 20 to 189 MB there for good: an installed pack cannot be
## ticked, so nothing looked at its cache again. [method stale_caches]
## names the packs that are "installed" ([method status]) and still have a
## cache folder; [method sweep] lists what is in them and [method
## sweep_step] removes it, [constant PackBuild.TIDY_PER_STEP] files a call.
##
## Only `<cache_root>/<id>` for an id of [method PackRecipes.ids] is ever
## touched — no path comes from a file's contents — and a link found
## there is removed as a link, never followed.
func stale_caches() -> Array[String]:
	var out: Array[String] = []
	for id: String in PackRecipes.ids():
		if DirAccess.dir_exists_absolute(cache_root().path_join(id)) \
				and String(status(id).get("state", "")) == "installed":
			out.append(id)
	return out


var _sweep_files: Array[String] = []
var _sweep_dirs: Array[String] = []


## Begin removing the caches of [param ids] (of [method stale_caches]).
func sweep(ids: Array[String]) -> void:
	var known := PackRecipes.ids()
	for id: String in ids:
		if known.has(id):
			_sweep_list(cache_root().path_join(id))


## One frame's worth of the sweep. True while there is more to remove.
func sweep_step() -> bool:
	for n in PackBuild.TIDY_PER_STEP:
		if _sweep_files.is_empty():
			break
		DirAccess.remove_absolute(_sweep_files.pop_back())
	if not _sweep_files.is_empty():
		return true
	# Deepest first; a folder that would not empty simply stays.
	for folder: String in _sweep_dirs:
		DirAccess.remove_absolute(folder)
	_sweep_dirs.clear()
	return false


func _sweep_list(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.include_hidden = true
	_sweep_dirs.push_front(folder)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := folder.path_join(entry)
		if dir.current_is_dir() and not dir.is_link(path):
			if entry != "." and entry != "..":
				_sweep_list(path)
		else:
			_sweep_files.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


## Whether the 1997 pictures just built are worn the moment the window
## closes (the title is simply drawn again) or from the next start.
func art_needs_restart() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := tree.current_scene if tree != null else null
	return SkinPack.plan_after_arrival(scene.scene_file_path if scene != null else "") != "reload"


## The window has closed with the 1997 pictures built: the game takes the
## zip as it takes one chosen in Options ([method SkinPack.adopt]) — the
## title is redrawn in it, any other screen is told it is in from the next
## start. Deferred: the window that asked is on its way out.
func wear_art() -> void:
	var file := folder().path_join(PackRecipes.BASE_FILE)
	if FileAccess.file_exists(file):
		SkinPack.adopt.call_deferred(file)
