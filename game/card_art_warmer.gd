class_name CardArtWarmer
extends Node
## THE CARD ART DECODED BEFORE IT IS ASKED FOR (the owner, 2026-10-23:
## *"the first F1 session (can we do something in the background before
## user even comes to f1 - in parallel?)"*).
##
## The first deck builder of a session opened in ~290 ms, a later one in
## ~90. Measured in the running game at 1280 × 800: of the first opening's
## 203 ms of building, 127 went to decoding the deck's card pictures (a
## JPG each, then its mipmaps) on the main thread, the first time each was
## drawn. That work needs no scene tree, so it is done here, ON A WORKER
## THREAD, while the hero walks:
##
##  1. [method warm] (main thread) finds each picture's file the way a
##     builder cell will ask for it — the card's own set from [CardPacks]
##     (what [method CardPrintings.texture] gives for a bare set code, read
##     without building the packs' whole printing table, which cost a
##     frame 11-18 ms with every pack on: the bug pass after the campaign,
##     r1-1), then [method GameSkin.card_art] (the order of
##     [method MiniCard.table_art]) — skipping those already kept, at most
##     [constant MOST].
##  2. One low-priority worker task decodes them in turn
##     ([method CardPacks.decode_art], [method GameSkin.decode_card_art]);
##     the main thread goes on.
##  3. Each frame the main thread hands up to [constant KEPT_PER_FRAME]
##     decoded pictures to the caches ([method CardPacks.keep_art],
##     [method GameSkin.keep_card_art]) — making a texture is the one step
##     that is the main thread's — and the node frees itself when done.
##
## NOT ON THE WEB, nor where the engine has no threads: the single-threaded
## Web template has no worker, and the threaded one failed now and then to
## read packed files off its main thread ([method CardRegistry.load_in_background]
## keeps them there for the same reason). There the builder decodes on
## demand, as before ([method runs_here]).
##
## Nothing is lost if the warmer is cut short: a picture it did not reach
## is decoded on demand, as before. A registry rebuilt meanwhile (a card
## pack switched, [member CardRegistry.revision]) drops what was decoded,
## since its paths may no longer be the ones asked for. Leaving the tree
## asks the worker to stop and waits for it.

## The most pictures one warm decodes: the deck on show and the first page
## of the cards beside it, well under the caches' bound
## ([constant GameSkin.ART_CACHE_CAP]), so warming never pushes out a
## picture already on show.
const MOST := 96
## Pictures handed to the caches a frame: a texture made is 0.35-0.46 ms
## (measured on 563 × 451 crops; the decode it saves is 3.3-4.4 ms).
const KEPT_PER_FRAME := 4


## The work shared with the worker thread. The worker writes only
## [member images] and [member done], under [member lock]; the main thread
## takes the pictures out and sets [member stop] under the same lock.
class Job extends RefCounted:
	## The files, in the order they are decoded.
	var paths: Array[String] = []
	## For each file: the card's name (the skin's art) or "" (a pack's).
	var skin_names: Array[String] = []
	## The decoded pictures, null until decoded (or when one did not).
	var images: Array = []
	## How many of [member paths] the worker has been through.
	var done := 0
	var stop := false
	var lock := Mutex.new()

	func run() -> void:
		for i in paths.size():
			lock.lock()
			var stopped := stop
			lock.unlock()
			if stopped:
				return
			var image: Image = GameSkin.decode_card_art(paths[i]) \
				if skin_names[i] != "" else CardPacks.decode_art(paths[i])
			lock.lock()
			images[i] = image
			done = i + 1
			lock.unlock()


var _job: Job
var _task := -1
var _kept := 0
var _revision := -1


## Starts warming [param card_names]' pictures under [param parent] (the
## first name first: give the deck in use before the rest); null when
## every picture is kept already, or there is nothing to decode them from.
static func warm(parent: Node, card_names: Array[String]) -> CardArtWarmer:
	if not runs_here():
		return null
	return _start(parent, _job_for(card_names))


## True where a worker thread may decode: an engine with threads, not the
## web.
static func runs_here() -> bool:
	return OS.has_feature("threads") and not OS.has_feature("web")


## [param job] decoded on a worker thread under [param parent]; null when
## it holds nothing to decode.
static func _start(parent: Node, job: Job) -> CardArtWarmer:
	if job.paths.is_empty():
		return null
	var warmer := CardArtWarmer.new()
	warmer.name = "CardArtWarmer"
	warmer._job = job
	warmer._revision = CardRegistry.revision
	parent.add_child(warmer)
	warmer._task = WorkerThreadPool.add_task(job.run, false, "Card art warm-up")
	return warmer


## The files still to decode for [param card_names], each once.
static func _job_for(card_names: Array[String]) -> Job:
	var job := Job.new()
	var packs := CardPrintings.service()
	var seen := {}
	for card_name in card_names:
		if job.paths.size() >= MOST:
			break
		if seen.has(card_name) or not CardRegistry.has_card(card_name):
			continue
		seen[card_name] = true
		var set_code := CardRegistry.get_card(card_name).set_code
		var path: String = packs.art_path(card_name, set_code) if packs != null else ""
		if path != "":
			if packs != null and not packs.art_kept(path):
				job.paths.append(path)
				job.skin_names.append("")
		elif not GameSkin.card_art_known(card_name):
			path = GameSkin.card_art_path(card_name)
			if path != "":
				job.paths.append(path)
				job.skin_names.append(card_name)
	job.images.resize(job.paths.size())
	return job


## True once every picture is decoded and kept (or dropped).
func finished() -> bool:
	return _job == null


func _process(_delta: float) -> void:
	if _job == null:
		return
	if CardRegistry.revision != _revision:
		_finish()
		return
	# This frame's pictures taken out under the lock; the textures made
	# after it, so the worker is never kept waiting on them.
	var taken: Array[int] = []
	var images: Array[Image] = []
	_job.lock.lock()
	while _kept < _job.done and images.size() < KEPT_PER_FRAME:
		if _job.images[_kept] != null:
			taken.append(_kept)
			images.append(_job.images[_kept])
			_job.images[_kept] = null
		_kept += 1
	_job.lock.unlock()
	var packs := CardPrintings.service()
	for k in taken.size():
		var at := taken[k]
		if _job.skin_names[at] != "":
			GameSkin.keep_card_art(_job.skin_names[at], images[k])
		elif packs != null:
			packs.keep_art(_job.paths[at], images[k])
	if _kept >= _job.paths.size():
		_finish()


## Stops the worker (it ends after the picture in hand), waits for it, and
## frees the node.
func _finish() -> void:
	_stop_worker()
	_job = null
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
	_stop_worker()
