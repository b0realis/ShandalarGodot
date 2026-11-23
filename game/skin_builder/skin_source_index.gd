class_name SkinSourceIndex
extends RefCounted
## EVERY FILE UNDER THE FOLDERS A PLAYER NAMED, BY NAME — the port of
## `build_index` of `tools/import_original.py`.
##
## A 1997 file is asked for by its name whatever its case and wherever it
## lies, so each file answers to its own name in lower case and to every
## trailing piece of its path (`duelsounds/button.wav`,
## `magictg/duelsounds/button.wav`): a recipe that names the folder gets
## the file in that folder and not its namesake elsewhere. Two rules
## decide which of two files of one name answers, both the Python tool's:
## the FIRST FOLDER NAMED WINS, and inside a folder the SHALLOWEST file,
## then the first by its lower-case path.
##
## THE WALK IS CUT INTO STEPS ([method step]) so a window can pace it: a
## folder a frame's worth at a time. It is bounded — a player may name
## their whole disk by mistake: [constant MAX_FILES] files and [constant
## MAX_DEPTH] folders deep, [member cut_short] saying so. A folder that is
## a link is named but not entered, as Python's `rglob` does not enter
## one (a link that loops would never end). Nothing is read but names.
##
## Entering a folder's files in the index is paced like the walk (a few
## hundred a step), and they are put in order by the engine's own sort, a
## depth at a time: a folder of two hundred thousand files must not hold a
## frame for seconds.
##
## A SOURCE IS A FOLDER OR A CD IMAGE (the owner, 2026-11-23: *"Yes choose
## iso add it."*). A file named among the folders is opened as an image
## ([SkinIsoImage]: `.iso`, a raw `.bin`/`.img`/`.mdf`, or the `.cue` that
## points at one) and its files answer by the same names, in the same
## order of precedence, as if the image were a folder of that name; one
## that will not open is told in [member problems]. A file is then read
## THROUGH the index ([method read], [method head]), which knows whether
## its path is on the disk or inside an image.
##
## Once [member done], the index is only ever read: a thread may use it —
## [method read] keeps no handle open between two calls.

const MAX_FILES := 200_000
const MAX_DEPTH := 32

## The bounds of a walk; a test sets them lower.
var max_files := MAX_FILES
var max_depth := MAX_DEPTH
## Lower-case name, or trailing path -> the file's whole path.
var files: Dictionary = {}
## The folders walked, in the order they were named.
var sources: Array[String] = []
## The ones that were no folder at all — nor an image that opened.
var not_folders: Array[String] = []
## Why each of those that was a file would not open as a CD image.
var problems: Dictionary = {}
## The sources that are CD images, each by its path.
var images: Dictionary = {}
## A file inside an image: its path here -> `[the image's source, its
## path in the image]`.
var inside: Dictionary = {}
## Per folder walked: every file's and folder's own name under it, lower
## case — what the landmarks are looked up in ([SkinInstallCheck]).
var names: Dictionary = {}
var file_count := 0
var cut_short := false
var done := false

var _queue: Array[String] = []
var _source := ""
var _pending: Array[String] = []   # folders still to list, relative to the source
## Depth -> the lower-case relative paths found at it; and each one's path
## as the disk spells it (the first met, where two differ only by case).
var _found: Dictionary = {}
var _spelt: Dictionary = {}
## The folder's files in their order, being entered; and how far that is.
var _filing := PackedStringArray()
var _filed := -1
var _stop := false
## Files entered in the index per step of the walk.
const FILED_A_STEP := 400


## Start a walk of [param folders], in their order of precedence.
func begin(folders: Array) -> void:
	files = {}
	sources = []
	not_folders = []
	problems = {}
	images = {}
	inside = {}
	names = {}
	file_count = 0
	cut_short = false
	done = false
	_queue = []
	for folder in folders:
		var clean := String(folder).simplify_path()
		if clean != "" and not _queue.has(clean):
			_queue.append(clean)
	_source = ""
	_pending = []
	_found = {}
	_spelt = {}
	_filing = PackedStringArray()
	_filed = -1


## Stop the walk at its next step (any thread).
func cancel() -> void:
	_stop = true


## Walk for about [param usec] microseconds (negative: to the end). True
## while there is more to walk.
func step(usec := -1) -> bool:
	var started := Time.get_ticks_usec()
	while not done:
		if _stop:
			done = true
			break
		if _source == "":
			if _queue.is_empty():
				done = true
				break
			_source = _queue.pop_front()
			_found = {}
			_spelt = {}
			_filed = -1
			if DirAccess.dir_exists_absolute(_source):
				sources.append(_source)
				names[_source] = {}
				_pending = [""]
			elif not _take_image():
				not_folders.append(_source)
				_source = ""
				continue
		elif not _pending.is_empty():
			_list(_pending.pop_back())
		elif _filed < 0:
			_order_source()
		elif not _file_some():
			_source = ""
		if usec >= 0 and Time.get_ticks_usec() - started >= usec:
			break
	return not done


## The whole walk at once.
static func of(folders: Array) -> SkinSourceIndex:
	var index := SkinSourceIndex.new()
	index.begin(folders)
	index.step()
	return index


## Whether [param source] is a CD image.
func is_image(source: String) -> bool:
	return images.has(source)


## The file at [param path] — one this index found — whole: `{error,
## bytes}`, the error in the player's words. Not opened when it is larger
## than [param most].
func read(path: String, most: int) -> Dictionary:
	if inside.has(path):
		var at: Array = inside[path]
		return (images[at[0]] as SkinIsoImage).read_checked(String(at[1]), most)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "it could not be opened", "bytes": PackedByteArray()}
	var length := file.get_length()
	if length > most:
		file.close()
		return {"error": "it is far larger than any 1997 file of its kind", "bytes": PackedByteArray()}
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		return {"error": "it could not be read to its end", "bytes": PackedByteArray()}
	return {"error": "", "bytes": bytes}


## The first [param count] bytes of the file at [param path]; fewer when
## it is shorter or will not read.
func head(path: String, count: int) -> PackedByteArray:
	if inside.has(path):
		var at: Array = inside[path]
		return (images[at[0]] as SkinIsoImage).read_checked(String(at[1]), count, count)["bytes"]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(count)
	file.close()
	return bytes


## The source just taken from the queue, opened as a CD image: its files
## laid out for the same ordering a folder's get. False when it is no
## image the game can read ([member problems] says why).
func _take_image() -> bool:
	if not FileAccess.file_exists(_source):
		return false
	var image := SkinIsoImage.new()
	image.max_entries = clampi(max_files - file_count, 0, SkinIsoImage.MAX_ENTRIES)
	var why := image.open(_source)
	if why != "":
		problems[_source] = why
		return false
	images[_source] = image
	sources.append(_source)
	var seen := {}
	names[_source] = seen
	for folder in image.folders():
		seen[folder.get_file().to_lower()] = true
	for entry: Dictionary in image.entries():
		var inner := String(entry["path"])
		var lower := inner.to_lower()
		seen[lower.get_file()] = true
		file_count += 1
		if _spelt.has(lower):
			continue
		_spelt[lower] = inner
		var depth := inner.count("/")
		if not _found.has(depth):
			_found[depth] = []
		(_found[depth] as Array).append(lower)
		inside[_source.path_join(inner)] = [_source, inner]
	if image.cut_short:
		cut_short = true
	_pending = []
	return true


## The path of the file that answers to [param name], or "".
##
## A CD image with no long names (plain ISO 9660, no Joliet) spells a name
## in capitals, digits and `_` alone: `Blu-Sprt.bmp` is `BLU_SPRT.BMP` on
## it. So a name not found as it is written is asked for once more as such
## a disc would spell it ([method strict_name]) — and only a file inside
## such an image may answer to that.
func find(name: String) -> String:
	var lower := name.to_lower()
	var path := String(files.get(lower, ""))
	if path != "" or images.is_empty():
		return path
	var strict := strict_name(lower)
	if strict == lower:
		return ""
	var other := String(files.get(strict, ""))
	if other != "" and inside.has(other) \
			and not (images[inside[other][0]] as SkinIsoImage).joliet:
		return other
	return ""


## [param lower], a lower-case name or path, as a plain ISO 9660 disc
## spells it: every character but a letter, a digit, `_`, `.` and `/`
## turned to `_`.
static func strict_name(lower: String) -> String:
	var points := PackedInt32Array()
	for i in lower.length():
		var c := lower.unicode_at(i)
		var kept := (c >= 0x61 and c <= 0x7A) or (c >= 0x30 and c <= 0x39) or c == 0x5F \
			or c == 0x2E or c == 0x2F
		points.append(c if kept else 0x5F)
	return points.to_byte_array().get_string_from_utf32()


## The first of [param candidates] that is there, or "".
func first_of(candidates: Array) -> String:
	for name in candidates:
		var path := find(String(name))
		if path != "":
			return path
	return ""


## Whether a file or a folder called [param name] lies under [param
## source] (every folder walked, when it is "").
func has_name(name: String, source := "") -> bool:
	var lower := name.to_lower()
	if source != "":
		return (names.get(source, {}) as Dictionary).has(lower)
	for each in names:
		if (names[each] as Dictionary).has(lower):
			return true
	return false


func _list(relative: String) -> void:
	var depth := 0 if relative == "" else relative.count("/") + 1
	var here := _source if relative == "" else _source.path_join(relative)
	var dir := DirAccess.open(here)
	if dir == null:
		return
	dir.include_hidden = true
	dir.include_navigational = false
	if dir.list_dir_begin() != OK:
		return
	var seen: Dictionary = names[_source]
	var entry := dir.get_next()
	while entry != "":
		var inner := entry if relative == "" else relative + "/" + entry
		seen[entry.to_lower()] = true
		if dir.current_is_dir():
			if depth + 1 >= max_depth:
				cut_short = true
			elif not dir.is_link(here.path_join(entry)):
				_pending.append(inner)
		elif file_count >= max_files:
			cut_short = true
			_pending.clear()
			break
		else:
			file_count += 1
			var lower := inner.to_lower()
			if not _spelt.has(lower):
				_spelt[lower] = inner
				if not _found.has(depth):
					_found[depth] = []
				(_found[depth] as Array).append(lower)
		entry = dir.get_next()
	dir.list_dir_end()


## The folder just walked, put in the order it is entered in: shallowest
## first, then by lower-case path.
func _order_source() -> void:
	var depths: Array = _found.keys()
	depths.sort()
	_filing = PackedStringArray()
	for depth: int in depths:
		var paths := PackedStringArray(_found[depth] as Array)
		paths.sort()
		_filing.append_array(paths)
	_found = {}
	_filed = 0


## Some more of its files entered in the index — a name already taken
## stays taken. False once the last one is in.
func _file_some() -> bool:
	var stop := mini(_filed + FILED_A_STEP, _filing.size())
	while _filed < stop:
		var lower := _filing[_filed]
		_filed += 1
		var path := _source.path_join(String(_spelt[lower]))
		var cut := lower.rfind("/")
		var bare := lower if cut < 0 else lower.substr(cut + 1)
		if not files.has(bare):
			files[bare] = path
		# Every trailing piece of two parts or more, the whole path last.
		while cut >= 0:
			cut = lower.rfind("/", cut - 1) if cut > 0 else -1
			var piece := lower if cut < 0 else lower.substr(cut + 1)
			if not files.has(piece):
				files[piece] = path
	if _filed < _filing.size():
		return true
	_filing = PackedStringArray()
	_spelt = {}
	return false
