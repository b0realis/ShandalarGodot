class_name SkinWarmer
extends Node
## THE SKIN DECODED BEFORE IT IS ASKED FOR (the smoothness pass, 0.50.66;
## the owner, 2026-10-29: *"I really want our adventure to play silky
## butter smooth"*). The world read the skin's files on the thread that
## draws, the first time each was wanted: a place's tune 15-25 ms (the 2x
## skin's zip 33-43), a creature's or a place's sheet 7-18 ms (31-63), the
## meeting's pictures and tune 49 ms (97) — the walk's hitches. That work
## needs no scene tree, so it is done here, ON A WORKER THREAD, before it is
## wanted — [CardArtWarmer]'s way, for the skin's own pictures, sounds and
## tunes:
##
##  1. [method warm] (main thread) asks each file's place —
##     [method GameSkin.picture_job], [method GameSkin.sound_job],
##     [method MusicLibrary.tune_job] — skipping what is kept already, is
##     missing, or is being warmed by another warmer;
##  2. one worker task decodes them in turn ([method decode]: the image,
##     the sound, the tune — nothing static, no node);
##  3. each frame the main thread keeps what is decoded, for at most
##     [constant KEEP_BUDGET_US] (at least one) — making the texture is the
##     one step that is the main thread's ([method keep]) — and the node
##     frees itself when done.
##
## Nothing is lost if a warmer is cut short: a file it did not reach is
## read on demand, as before. A file whose place changed meanwhile (a skin
## that arrived) is not kept. Leaving the tree asks the worker to stop and
## waits for it.
##
## NOT HEADLESS (the tests, the tools: nothing is drawn or heard, and a
## test must not race a thread), NOT ON THE WEB, nor where the engine has no
## threads ([method runs_here]): there every file is read on demand, as
## before.

## How long a frame may spend keeping decoded files (making textures), and
## how many bytes of pictures it may hand to the graphics card (the upload
## lands in the frame's drawing, which the clock here does not see): a 2x
## creature sheet is 10.6 MB, so one a frame — and always at least one.
const KEEP_BUDGET_US := 2000
const KEEP_BUDGET_BYTES := 4 * 1024 * 1024
## [method WorldArt.sheet_ready] waits no longer than this for a sheet in
## flight: past it the sheet is read on demand, the way it was before.
const MOST_WAIT_MS := 250

## Tests: 1 warms headless too, 0 never, -1 by the rule ([method runs_here]).
static var forced := -1

## The pictures, sounds and tunes being warmed, by key (a tune by its
## file's path): when each was asked for, in ms. Main thread only.
static var _pictures: Dictionary = {}
static var _sounds: Dictionary = {}
static var _tunes: Dictionary = {}
static var _faces: Dictionary = {}
## The warmers at work, for [method finish_all]. Main thread only; a
## warmer leaves it as it finishes.
static var _live: Array[SkinWarmer] = []


## The work shared with the worker thread. The worker writes only into the
## entries it decodes and [member done], under [member lock]; the main
## thread reads an entry only once [member done] has passed it, and sets
## [member stop] under the same lock.
class Job extends RefCounted:
	## The files, in the order they are decoded: [method GameSkin.picture_job]
	## and the like, each with its `kind`.
	var entries: Array[Dictionary] = []
	## How many of [member entries] the worker has been through.
	var done := 0
	var stop := false
	var lock := Mutex.new()

	func run() -> void:
		for i in entries.size():
			lock.lock()
			var stopped := stop
			lock.unlock()
			if stopped:
				return
			SkinWarmer.decode(entries[i])
			lock.lock()
			done = i + 1
			lock.unlock()


var _job: Job
var _task := -1
var _kept := 0


## True where a worker thread may decode: an engine with threads, a
## screen, not the web ([member forced] for tests).
static func runs_here() -> bool:
	if forced >= 0:
		return forced == 1
	return OS.has_feature("threads") and not OS.has_feature("web") and DisplayServer.get_name() != "headless"


## Starts warming [param pictures] and [param sounds] (skin keys) and
## [param tunes] (track ids, [MusicLibrary]), in that order; [param urgent]
## puts the task ahead of the background work (a sheet a creature waits
## on). The warmer lives UNDER THE TREE'S ROOT, joined at the end of the
## frame, whoever asked ([param parent] only says the asker is in a tree):
## what it keeps is the skin's, not a screen's, and a pane closed or a
## screen left must not wait in its leaving for a decode in hand (a 2x
## sheet's tens of milliseconds). Null when nothing needs it or no worker
## may run here.
static func warm(parent: Node, pictures: Array[String], sounds: Array[String] = [],
		tunes: Array[String] = [], urgent := false) -> SkinWarmer:
	if not runs_here():
		return null
	var now := Time.get_ticks_msec()
	var entries: Array[Dictionary] = []
	for key in pictures:
		if _pictures.has(key):
			continue
		var job := GameSkin.picture_job(key)
		if not job.is_empty():
			job["kind"] = "picture"
			entries.append(job)
			_pictures[key] = now
	for key in sounds:
		if _sounds.has(key):
			continue
		var job := GameSkin.sound_job(key)
		if not job.is_empty():
			job["kind"] = "sound"
			entries.append(job)
			_sounds[key] = now
	for id in tunes:
		var job := MusicLibrary.tune_job(id)
		if job.is_empty() or _tunes.has(String(job["path"])):
			continue
		job["kind"] = "tune"
		entries.append(job)
		_tunes[String(job["path"])] = now
	return _start(parent, entries, urgent)


## The faces [param ids] ([PortraitLibrary]: a creature's,
## [method CreatureBook.face_id]) warmed the same way.
static func warm_faces(parent: Node, ids: Array[String]) -> SkinWarmer:
	if not runs_here():
		return null
	var entries: Array[Dictionary] = []
	for id in ids:
		if _faces.has(id):
			continue
		var job := PortraitLibrary.face_job(id)
		if not job.is_empty():
			job["kind"] = "face"
			entries.append(job)
			_faces[id] = Time.get_ticks_msec()
	return _start(parent, entries, false)


static func _start(parent: Node, entries: Array[Dictionary], urgent: bool) -> SkinWarmer:
	if entries.is_empty():
		return null
	var warmer := SkinWarmer.new()
	warmer.name = "SkinWarmer"
	warmer._job = Job.new()
	warmer._job.entries = entries
	_live.append(warmer)
	warmer._task = WorkerThreadPool.add_task(warmer._job.run, urgent, "Skin warm-up")
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.root if tree != null else null
	if host == null or (parent != null and not parent.is_inside_tree()):
		warmer._finish()
		warmer.free()
		return null
	# Deferred: a sheet is asked for while the world is being drawn.
	host.add_child.call_deferred(warmer)
	return warmer


## Whether picture [param key] is being warmed, and asked for less than
## [constant MOST_WAIT_MS] ago.
static func picture_pending(key: String) -> bool:
	return _pictures.has(key) and Time.get_ticks_msec() - int(_pictures[key]) < MOST_WAIT_MS


## Whether sound [param key] is being warmed.
static func sound_pending(key: String) -> bool:
	return _sounds.has(key)


## One file decoded into [param entry], by its kind. Any thread: it reads
## only the entry and constants.
static func decode(entry: Dictionary) -> void:
	match String(entry.get("kind", "")):
		"picture", "face":
			GameSkin.decode_picture(entry)
		"sound":
			GameSkin.decode_sound(entry)
		"tune":
			MusicLibrary.decode_tune(entry)


## [param entry], decoded, kept where an ask on demand finds it. Main
## thread.
static func keep(entry: Dictionary) -> void:
	match String(entry.get("kind", "")):
		"picture":
			GameSkin.keep_picture(entry)
		"sound":
			GameSkin.keep_sound(entry)
		"tune":
			MusicLibrary.keep_tune(entry)
		"face":
			PortraitLibrary.keep_face(entry)


## [param entry] no longer being warmed — and what it decoded let go, so a
## long warm does not hold every picture twice until its end.
static func _let_go(entry: Dictionary) -> void:
	entry.erase("img")
	entry.erase("own_img")
	entry.erase("stream")
	match String(entry.get("kind", "")):
		"picture":
			_pictures.erase(String(entry["key"]))
		"sound":
			_sounds.erase(String(entry["key"]))
		"tune":
			_tunes.erase(String(entry["path"]))
		"face":
			_faces.erase(String(entry["id"]))


## Every warmer at work waited for and its files kept, now — a test, or a
## screen that needs them this frame (the warmers live under the root,
## joined at the end of the frame they were made in: [method warm]).
static func finish_all() -> void:
	for warmer in _live.duplicate():
		if is_instance_valid(warmer):
			warmer.finish_now()
	_live.clear()


## True once every file is decoded and kept (or dropped).
func finished() -> bool:
	return _job == null


## Waits for the worker and keeps everything it decoded, now — a test, or a
## screen that needs the files this frame.
func finish_now() -> void:
	if _job == null:
		return
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	while _kept < _job.done:
		keep(_job.entries[_kept])
		_let_go(_job.entries[_kept])
		_kept += 1
	_finish()


func _process(_delta: float) -> void:
	if _job == null:
		# Finished before it joined the root ([method finish_now]).
		if not is_queued_for_deletion():
			queue_free()
		return
	var started := Time.get_ticks_usec()
	var bytes := 0
	while true:
		_job.lock.lock()
		var done := _job.done
		_job.lock.unlock()
		if _kept >= done:
			break
		var entry := _job.entries[_kept]
		var img: Variant = entry.get("img")
		if img is Image:
			bytes += (img as Image).get_data_size()
		keep(entry)
		_let_go(entry)
		_kept += 1
		if Time.get_ticks_usec() - started >= KEEP_BUDGET_US or bytes >= KEEP_BUDGET_BYTES:
			break
	if _kept >= _job.entries.size():
		_finish()


## Stops the worker (it ends after the file in hand), waits for it, lets go
## of what it did not keep, and frees the node ([param free_self]).
func _finish(free_self := true) -> void:
	_live.erase(self)
	_stop_worker()
	if _job != null:
		for i in range(_kept, _job.entries.size()):
			_let_go(_job.entries[i])
	_job = null
	if free_self and is_inside_tree() and not is_queued_for_deletion():
		queue_free()


func _stop_worker() -> void:
	if _task == -1:
		return
	if _job != null:
		_job.lock.lock()
		_job.stop = true
		_job.lock.unlock()
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1


func _exit_tree() -> void:
	_finish(false)
