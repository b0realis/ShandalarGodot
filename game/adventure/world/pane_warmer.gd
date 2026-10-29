class_name PaneWarmer
extends Node
## THE PANES' PICTURES MADE BEFORE THEY OPEN (the smoothness pass, 0.50.66;
## the owner, 2026-10-29: *"I really want our adventure to play silky
## butter smooth"*). The first hero's pane (F5), Wizards tab (F6) and map
## (M) of a session opened in 38, 48 and 11 ms with the 1997 skin, 61, 129
## and 31 with the 2x skin (measured on the desk's RTX 4060), later ones in
## 2-8: the panes made, on the thread that draws, pictures of their own out
## of the skin's — and each began by reading a sheet's pixels back off the
## graphics card (1-7 ms a picture, 14 for a 2x castles sheet): the
## hall's keyed pictures bled at their edges ([method WizardsPicture.bleed]),
## the castles cut to their painted part ([method HeroStats.trimmed]), the
## map's ornament and amulet panel keyed ([method WorldMap.sprite_image]).
## None of that needs the scene tree, so a while after the world opens it is
## done here, ON A WORKER THREAD, from the files themselves:
##
##  1. [method warm] (main thread) asks each picture's place ([method
##     GameSkin.picture_job]; for one the world keeps already, its place
##     all the same, `kept_too`) and the parts the panes will cut of it;
##  2. one worker task decodes each file ([method GameSkin.decode_picture])
##     and makes the parts from its pixels — the same pixels the card
##     would give back, so the same pictures;
##  3. each frame the main thread keeps what is made, for at most
##     [constant KEEP_BUDGET_US]: the skin's texture ([method
##     GameSkin.keep_picture]) and the parts where the panes look for them
##     first; then the node frees itself.
## The plain pictures the panes draw as they are (the hero's frame, the
## creatures' faces, the map's ground, the hall's floor, the wizards'
## sound) are [SkinWarmer]'s ([method WorldScreen._warm_the_panes]).
##
## Nothing is lost if it is cut short: what it did not reach is made on
## demand, as before. A picture whose place changed meanwhile (a skin that
## arrived) is not kept, nor its parts. Where no worker may decode
## ([method SkinWarmer.runs_here]: headless, the web) it does nothing.
##
## THE MEMORY: only what the first opening would make anyway — warmed
## sooner, not more; but made even if the pane is never opened in the
## session: the hall's keyed pictures and their bled twins, 3.1 MB of
## textures with the 1997 skin (and 1.2 MB a skulls' picture shown), the
## map's two cuts 0.06 MB, the castles' trims a few numbers; four times that
## with the 2x skin.

## How long a frame may spend keeping what is made (making textures).
const KEEP_BUDGET_US := 2000


## The work shared with the worker thread. The worker writes only into the
## entries it makes and [member done], under [member lock]; the main
## thread reads an entry only once [member done] has passed it.
class Job extends RefCounted:
	var entries: Array[Dictionary] = []
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
			PaneWarmer.make(entries[i])
			lock.lock()
			done = i + 1
			lock.unlock()


var _job: Job
var _task := -1
var _kept := 0

## The warmers at work ([method finish_all]).
static var _live: Array[PaneWarmer] = []


## Starts making the panes' parts — under the tree's root, joined at the
## end of the frame, as [SkinWarmer]'s are, so a screen left never waits
## for a picture in hand; [param parent] only says the tree is there —: the hall's bled
## pictures [param bled] (skin keys), the castles' trims [param trims]
## (`[key, frame, region]` each, the frame's region in drawn pixels), and
## [param sprites] (`[key, place]`, the map's cuts). Null when nothing is
## left to make or no worker may run here.
static func warm(parent: Node, bled: Array[String], trims: Array[Array], sprites: Array[Array]) -> PaneWarmer:
	if not SkinWarmer.runs_here() or parent == null or not parent.is_inside_tree():
		return null
	var entries: Array[Dictionary] = []
	for key in bled:
		var source := _kept_texture(key)
		if source != null and WizardsPicture.bled_kept(source):
			continue
		var entry := _entry("bleed", key)
		if not entry.is_empty():
			entries.append(entry)
	var by_sheet := {}
	for one in trims:
		if HeroStats.trim_kept(HeroStats.trim_key(String(one[0]), int(one[1]))):
			continue
		if not by_sheet.has(one[0]):
			var entry := _entry("trim", String(one[0]))
			if entry.is_empty():
				continue
			entry["frames"] = []
			by_sheet[one[0]] = entry
			entries.append(entry)
		(by_sheet[one[0]]["frames"] as Array).append([HeroStats.trim_key(String(one[0]), int(one[1])), one[2]])
	for one in sprites:
		var sheet := _kept_texture(String(one[0]))
		if sheet != null and WorldMap.sprite_kept(sheet, one[1]):
			continue
		var entry := _entry("sprite", String(one[0]))
		if not entry.is_empty():
			entry["place"] = one[1]
			entries.append(entry)
	if entries.is_empty():
		return null
	var warmer := PaneWarmer.new()
	warmer.name = "PaneWarmer"
	warmer._job = Job.new()
	warmer._job.entries = entries
	parent.get_tree().root.add_child.call_deferred(warmer)
	warmer._task = WorkerThreadPool.add_task(warmer._job.run, false, "Pane warm-up")
	_live.append(warmer)
	return warmer


## Every warmer at work waited for and its parts kept, now (a test).
static func finish_all() -> void:
	for warmer in _live.duplicate():
		if is_instance_valid(warmer):
			warmer.finish_now()
	_live.clear()


## How many warmers are at work.
static func working() -> int:
	return _live.size()


## The skin's texture for [param key] when it is kept already (or missing:
## null), else null — never read from its file here.
static func _kept_texture(key: String) -> Texture2D:
	return GameSkin.texture(key) if GameSkin.picture_job(key).is_empty() else null


## An entry of [param kind] for [param key]: its file's place, and whether
## the skin's texture is to be kept from it too (not kept yet); `{}` when no
## place has it.
static func _entry(kind: String, key: String) -> Dictionary:
	var job := GameSkin.picture_job(key)
	var keep := not job.is_empty()
	if not keep:
		job = GameSkin.picture_job(key, true)
		if job.is_empty():
			return {}
	return {"kind": kind, "key": key, "job": job, "keep": keep}


## WHAT [param entry] HOLDS, MADE: its file decoded, the scale and drawn
## size the skin will give its texture ([method GameSkin.keep_picture]'s
## rule), and its parts. Any thread: it reads only the entry and constants.
static func make(entry: Dictionary) -> void:
	var job: Dictionary = entry["job"]
	GameSkin.decode_picture(job)
	var img: Image = job.get("img")
	if img == null:
		return
	var key := String(entry["key"])
	var slot: Vector2i = GameSkin.SIZES.get(key, Vector2i.ZERO)
	var scale := GameSkin.scale_for(img.get_size(), slot)
	var own := String(job["own"])
	if scale == 1 and own != "" and own != String(job["path"]):
		var one: Image = job.get("own_img")
		if one == null:
			one = Image.load_from_file(own)
		if one != null:
			slot = one.get_size()
			scale = GameSkin.scale_for(img.get_size(), slot)
	entry["scale"] = scale
	entry["drawn"] = slot if scale > 1 else img.get_size()
	match String(entry["kind"]):
		"bleed":
			entry["made"] = WizardsPicture.bleed(img.duplicate() as Image)
		"trim":
			var rects := []
			for frame in entry["frames"]:
				rects.append([frame[0], HeroStats.trimmed(img, frame[1], scale)])
			entry["made"] = rects
		"sprite":
			# The sheet's 1997 pixels as [method GameSkin.original] reads them.
			var small: Image = img
			if scale > 1:
				small = null
				if own != "" and own != String(job["path"]):
					var one := Image.load_from_file(own)
					if one != null and one.get_size() == Vector2i(entry["drawn"]):
						small = one
				if small == null:
					small = GameSkin.shrunk(img, scale)
			entry["made"] = WorldMap.sprite_image(small.duplicate() as Image, img, scale, entry["place"])


## [param entry], made, kept where the panes look first. Main thread.
static func keep(entry: Dictionary) -> void:
	if not entry.has("made"):
		return
	var key := String(entry["key"])
	var source: Texture2D = GameSkin.keep_picture(entry["job"]) if bool(entry["keep"]) else GameSkin.texture(key)
	# The texture the skin wears must be the one the parts were made for.
	if source == null or GameSkin.scale_of(source) != int(entry["scale"]) \
			or Vector2i(source.get_size()) != Vector2i(entry["drawn"]):
		return
	match String(entry["kind"]):
		"bleed":
			WizardsPicture.keep_bled(source, entry["made"])
		"trim":
			for one in entry["made"]:
				HeroStats.keep_trim(String(one[0]), one[1])
		"sprite":
			WorldMap.keep_sprite(source, entry["place"], entry["made"])


## True once everything is made and kept (or dropped).
func finished() -> bool:
	return _job == null


## Waits for the worker and keeps everything it made, now (a test).
func finish_now() -> void:
	if _job == null:
		return
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	while _kept < _job.done:
		keep(_job.entries[_kept])
		_kept += 1
	_finish()


func _process(_delta: float) -> void:
	if _job == null:
		return
	var started := Time.get_ticks_usec()
	while true:
		_job.lock.lock()
		var done := _job.done
		_job.lock.unlock()
		if _kept >= done:
			break
		keep(_job.entries[_kept])
		_kept += 1
		if Time.get_ticks_usec() - started >= KEEP_BUDGET_US:
			break
	if _kept >= _job.entries.size():
		_finish()


## Stops the worker (it ends after the entry in hand), waits for it, and
## frees the node.
func _finish() -> void:
	if _task != -1:
		if _job != null:
			_job.lock.lock()
			_job.stop = true
			_job.lock.unlock()
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_job = null
	_live.erase(self)
	if is_inside_tree():
		queue_free()
	elif not is_queued_for_deletion():
		# Finished before it joined the tree (a test): freed with the frame.
		queue_free()


func _exit_tree() -> void:
	_finish()
