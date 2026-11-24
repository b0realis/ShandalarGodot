class_name PackBuild
extends RefCounted
## ONE PACK FROM THE FIRST QUESTION TO ITS PLACE IN THE CARD FOLDER:
## the recipe read ([PackRecipes]), its pictures fetched ([PackFetch]), the
## zip written and checked ([PackWriter]), the checked zip renamed into the
## card folder and the cache let go. Stepped once a frame ([method step])
## by [PackBuilderWindow]; every step is a few milliseconds.
##
## [member state] is "working" until it is "done", "failed" or "stopped";
## [member outcome] then says what came of it, in words the summary shows:
## `{id, title, ok, kind, text, halts}` with kind "" (installed), "locked"
## (a LAN table holds the catalogue), "disk", "network", "refused" or
## "stopped". `halts` is true when what stopped this pack would stop the
## next one the same way — no connection, a refused certificate, a server
## that stays busy, a folder or a disk that takes no more — so the window
## does not begin the packs after it: without it, eleven packs chosen with
## the network down were eleven rounds of waiting and asking again. A card
## Scryfall lacks or a zip the game's check refuses is this pack's alone.
##
## WHAT A STOP OR A FAILURE LEAVES: every picture downloaded so far, in the
## cache — the same pack chosen again fetches only what is missing — and
## never a half-written zip. The cache goes only once the pack is in place.

## Megabytes kept free beyond what the pack itself needs.
const SPARE_MB := 64
## Cache files removed per step once the pack is in place.
const TIDY_PER_STEP := 200

## How long one [method step] may go on fetching, in microseconds. Zero
## (the tests) is one small step a call.
var frame_usec := 4000
## Whether the fetch pauses between pictures ([member PackFetch.gentle]);
## set before [method start].
var gentle := true
var host: PackBuildHost
var id := ""
var title := ""
## "idle", "working", "done", "failed" or "stopped".
var state := "idle"
## "downloading", "writing", "checking" or "tidying".
var phase := ""
var outcome := {}
var fetch: PackFetch = null
var writer: PackWriter = null

var _recipe := {}
var _cache := ""
var _tidy: Array = []
var _tidy_dirs: Array = []


func start(pack_id: String, on: PackBuildHost) -> void:
	host = on
	id = pack_id
	var about := PackRecipes.about(id)
	title = String(about.get("title", id))
	outcome = {}
	state = "working"
	var locked := host.refusal()
	if locked != "":
		_end("failed", "locked", locked, true)
		return
	_recipe = PackRecipes.recipe(id)
	if not bool(_recipe.get("ok", false)):
		_end("failed", "refused", "This build cannot make it: %s." % String(_recipe.get("why", "")))
		return
	_cache = host.cache_root().path_join(id)
	var jobs: Array = _recipe["jobs"]
	var have := PackFetch.cached_count(jobs, _cache)
	var lacking := int(about["pictures"]) - have
	var need_mb := int(ceil(float(about["fetch_mb"]) * float(lacking) / float(maxi(int(about["pictures"]), 1)))) \
		+ int(about["zip_mb"]) + SPARE_MB
	var free := host.free_bytes()
	if free >= 0 and free < need_mb * 1024 * 1024:
		_end("failed", "disk", "Not enough free disk space: it needs about %d MB and %d MB are free." % [
			need_mb, free >> 20])
		return
	# Said now, not after half an hour of downloading.
	var closed := host.unwritable()
	if closed != "":
		_end("failed", "disk", closed, true)
		return
	fetch = PackFetch.new()
	fetch.transport = host.transport()
	fetch.clock = host.now_msec
	fetch.gentle = gentle
	fetch.start(jobs, _cache)
	phase = "downloading"


## One frame's worth. True while there is more to do.
func step() -> bool:
	if state != "working":
		return false
	match phase:
		"downloading":
			# As many of the fetch's small steps as fit, until it can only
			# wait: an answer that is in is acted on in the frame it came.
			var started := Time.get_ticks_usec()
			var more := fetch.step()
			while more and not fetch.waiting and Time.get_ticks_usec() - started < frame_usec:
				more = fetch.step()
			if not more:
				_fetched()
		"writing", "checking":
			if not writer.step():
				_written()
			elif writer.state == "checking":
				phase = "checking"
		"tidying":
			_tidy_some()
	return state == "working"


## Stop cleanly: what was downloaded is kept, a zip being written is not.
func stop() -> void:
	if state != "working":
		return
	if fetch != null:
		fetch.stop()
	if writer != null:
		writer.abandon()
	_close_transport()
	if phase == "tidying":
		# The pack is already in place; only the cache's end was cut short.
		_end("done", "", "")
	else:
		_end("stopped", "stopped", "Stopped. What was downloaded is kept; choose it again to go on.")


## Where it is, for the window's line: "downloading 512 of 760".
func line() -> String:
	match phase:
		"downloading":
			var words := "downloading %d of %d" % [fetch.pictures_done, fetch.pictures_total]
			var pause := fetch.pause_seconds()
			if pause > 0:
				# Said, so a wait does not look like a window that hangs.
				words += " — Scryfall asked for a pause, %d s" % pause if fetch.pause_why == "busy" \
					else " — no answer, asking again in %d s" % pause
			return words
		"writing":
			return "writing %d of %d" % [writer.done, writer.total]
		"checking":
			return "checking %d of %d" % [writer.done, writer.total]
		"tidying":
			return "tidying up"
	return ""


## How far this pack is, 0..1: the download is most of it.
func fraction() -> float:
	match phase:
		"downloading":
			return 0.80 * float(fetch.pictures_done) / float(maxi(fetch.pictures_total, 1))
		"writing":
			return 0.80 + 0.12 * float(writer.done) / float(maxi(writer.total, 1))
		"checking":
			return 0.92 + 0.07 * float(writer.done) / float(maxi(writer.total, 1))
		"tidying":
			return 0.99
	return 1.0 if state == "done" else 0.0


func _fetched() -> void:
	_close_transport()
	if fetch.state == "failed":
		_end("failed", "disk" if fetch.problem == "disk" else "network", fetch.problem_text, true)
		return
	if fetch.state != "done":
		return
	if not fetch.missed.is_empty():
		var first: Dictionary = fetch.missed[0]
		var count := fetch.missed.size()
		_end("failed", "network", "%d %s could not be fetched (%s: %s). The rest is kept; choose it again to fetch what is missing." % [
			count, "card" if count == 1 else "cards", String(first["name"]), String(first["why"])])
		return
	writer = PackWriter.new()
	# A method, not a lambda: a lambda would hold this build, which holds
	# the writer, which would hold the lambda.
	writer.judge = _judge
	writer.start(_recipe, _cache, host.folder().path_join(PackBuildHost.BUILDING))
	phase = "writing"
	if writer.state == "failed":
		_written()


func _judge(path: String) -> Dictionary:
	return host.judge(id, path)


func _written() -> void:
	if writer.state != "done":
		var kind := writer.problem
		_end("failed", "network" if kind == "missing" else kind, writer.problem_text, kind == "disk")
		_drop_work_folder()
		return
	var refused := host.place(id, writer.path)
	if refused != "":
		writer.abandon()
		_drop_work_folder()
		_end("failed", "disk", refused, true)
		return
	_drop_work_folder()
	_list_cache(_cache)
	phase = "tidying"


## The work folder goes when it is empty (another pack's leftovers stay).
func _drop_work_folder() -> void:
	DirAccess.remove_absolute(host.folder().path_join(PackBuildHost.BUILDING))


func _list_cache(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	_tidy_dirs.push_front(folder)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				_list_cache(folder.path_join(entry))
		else:
			_tidy.append(folder.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()


func _tidy_some() -> void:
	for n in TIDY_PER_STEP:
		if _tidy.is_empty():
			break
		DirAccess.remove_absolute(String(_tidy.pop_back()))
	if _tidy.is_empty():
		for folder: String in _tidy_dirs:
			DirAccess.remove_absolute(folder)
		_tidy_dirs.clear()
		_end("done", "", "")


func _close_transport() -> void:
	if fetch != null and fetch.transport != null:
		fetch.transport.close()


func _end(how: String, kind: String, text: String, halts := false) -> void:
	state = how
	outcome = {"id": id, "title": title, "ok": how == "done", "kind": kind, "text": text,
		"halts": halts}
