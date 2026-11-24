class_name SkinBuildJob
extends RefCounted
## THE SKIN ZIP BUILT FROM A PLAYER'S OWN 1997 GAME, IN THE GAME — the port
## of `tools/import_original.py` (run as `--no-videos`) and of the packing
## `tools/mtg_assets.py --install` does after it. The owner, 2026-11-23:
## *"a skin tool … that would scrape a 1997 install for a skin we use
## directly within a game using godot engine"*, *"without any external
## dependencies"*. The same files under the same names, picture for
## picture the same pixels: a test builds both on a real install and
## compares every file.
##
## WHAT IS BUILT, in the Python tool's order ([method plan]): every row of
## its MANIFEST ([SkinRecipes]) — a picture decoded ([SkinPicCodec],
## [SkinSprCodec]), a sound or the title font copied byte for byte —, the
## two sheets laid together from cells and the two of ours drawn from one
## of them, the seventy portraits, the adventure's pictures, the card
## values read out of the game's program, the card seller's hints, the
## wise man's words, and the two coin-toss movies carried along as they
## are in `movies/`.
##
## WHAT IS LEFT OUT: the coin toss's sprite sheets and the ending's film.
## Python makes them with ffmpeg or gstreamer; the game carries neither
## and may run no other program, so this builds what `--no-videos` builds
## and [method result] names the three under `left_out`.
##
## A SOURCE MAY BE A CD IMAGE as well as a folder ([SkinSourceIndex],
## [SkinIsoImage]): a file's path then lies inside the image, and it is
## read out of it in place, nothing unpacked.
##
## NOTHING IN THE FOLDER IS TRUSTED. A file that will not decode is left
## out, noted with its reason under `skipped`, and the build goes on — as
## the Python tool does. Sizes are bounded before anything is read
## ([constant MAX_ART_FILE], [constant MAX_DATA_FILE], [constant
## MAX_COPY_FILE]). No path comes out of a file: every name written is a
## recipe's own.
##
## ONE FILE, WHOLE OR NOT AT ALL. The zip is written to `<dest>.part`
## ([ZIPPacker], every entry under `skin/`) and renamed over [member dest]
## only when the last entry is in; a build stopped ([method cancel]) or
## failed leaves no `.part` and never touches a zip already at [member
## dest].
##
## PACED. The work is a list of tasks, a file each, done one at a time by
## [method step]: from a window's `_process`, or on a thread ([method
## start_thread]) — everything here is the job's own data, and what a
## window may ask meanwhile ([method progress]) is handed over under a
## mutex. [method result] is for when it is over.

const PART_TAIL := ".part"
const PREFIX := "skin/"
## A `.pic`, `.spr`, `.bmp` or `.tr` larger than this is not opened (the
## largest in a 1997 install is under 1 MB).
const MAX_ART_FILE := 64 << 20
## The same for the game's program and its lists.
const MAX_DATA_FILE := 64 << 20
## And for a sound or a movie carried along (the longest 1997 tune is
## under 20 MB).
const MAX_COPY_FILE := 256 << 20
## A list in letters (`Info.csv`, `Hints.txt`, a `.tr` palette) larger
## than this is not opened: the largest in a 1997 install is 105 KB, and
## letters are held four bytes each while they are read.
const MAX_TEXT_FILE := 8 << 20
## The most rows read out of a program's card table.
const MAX_CARD_ROWS := 20_000

var index: SkinSourceIndex = null
var dest := ""
## The bounds on a file read; a test sets them lower.
var max_art_file := MAX_ART_FILE
var max_data_file := MAX_DATA_FILE
var max_copy_file := MAX_COPY_FILE
var max_text_file := MAX_TEXT_FILE
## The plan [method SkinInstallCheck.survey] already made of this very
## index, when the window has one: [method open] then reads no file a
## second time (a CD in a drive answers each in a tenth of a second).
var planned: Dictionary = {}

var _tasks: Array = []
var _at := 0
var _zip: ZIPPacker = null
var _part := ""
var _over := false
var _ok := false
var _why := ""
var _written: Array[String] = []
var _skipped: Array = []
var _missing: Array[String] = []
var _refused_png: Array = []
var _refused_program: Array = []
var _left_out: Array[String] = []
var _bytes_in := 0

var _palettes: Dictionary = {}
## A laid sheet's pixels, for the sheets drawn from it: key -> `{width,
## height, rgb}`.
var _sheets: Dictionary = {}
var _names_by_id: Variant = null
var _occurrences: Dictionary = {}
var _rogue_palette: Variant = null
var _rogue_seen: Array = []

var _mutex := Mutex.new()
var _thread: Thread = null
var _stop := false
var _shared := {"done": 0, "total": 0, "current": "", "finished": false}


# ------------------------------------------------------------- the plan --

## What a build of [param index] would do, nothing read but the first
## eight bytes of each picture (a PNG under a 1997 name is a later
## remake's, and is not taken): `{tasks, missing, refused_png,
## refused_program, left_out}`. A task is `{kind, key, name, path, ...}`.
static func plan(from: SkinSourceIndex) -> Dictionary:
	var tasks: Array = []
	var missing: Array[String] = []
	var refused_png: Array = []
	var refused_program: Array = []
	for key: String in SkinRecipes.MANIFEST:
		var texture := not (key.ends_with(".ttf") or key.ends_with(".wav"))
		var source := ""
		for name: String in SkinRecipes.MANIFEST[key]:
			var path := from.find(name)
			if path == "":
				continue
			# (A file two of a row's names reach is refused once.)
			if texture and SkinPicCodec.is_png(from.head(path, 8)):
				if not refused_png.has([key, path]):
					refused_png.append([key, path])
				continue
			if key.ends_with(".wav") and is_later_sound_copy(path):
				if not refused_program.has([key, path]):
					refused_program.append([key, path])
				continue
			source = path
			break
		if source == "":
			missing.append(key)
			continue
		tasks.append({"kind": "texture" if texture else "copy", "key": key,
			"name": key + ".png" if texture else key, "path": source, "manifest": true})
	for key: String in SkinRecipes.PIC_SHEETS:
		tasks.append({"kind": "pic_sheet", "key": key, "name": key + ".png", "path": ""})
	for key: String in SkinRecipes.DERIVED_SHEETS:
		tasks.append({"kind": "derived", "key": key, "name": key + ".png", "path": ""})
	var faces := from.first_of(SkinRecipes.PORTRAIT_SHEET_RAW)
	if faces != "":
		tasks.append({"kind": "portraits", "key": "portraits", "name": "portraits/", "path": faces})
	var own_face := from.first_of(SkinRecipes.PLAYER_FACE_PIC)
	if own_face != "":
		tasks.append({"kind": "face", "key": SkinRecipes.PLAYER_FACE_NAME,
			"name": "portraits/%s.png" % SkinRecipes.PLAYER_FACE_NAME, "path": own_face})
	# Named slots first, so a nameless one can know itself for a copy.
	var named: Array = []
	var nameless: Array = []
	for slot in SkinRecipes.ROGUE_SLOTS:
		var path := from.find("%03d.pic" % slot)
		if path == "":
			continue
		var task := {"kind": "rogue", "key": rogue_name(slot), "slot": slot,
			"name": "portraits/%s.png" % rogue_name(slot), "path": path}
		if slot >= 1 and slot <= SkinRecipes.ROGUE_NAMES.size():
			named.append(task)
		else:
			nameless.append(task)
	tasks.append_array(named)
	tasks.append_array(nameless)
	for key: String in SkinRecipes.PIC_SCREENS:
		var path := from.first_of(SkinRecipes.PIC_SCREENS[key])
		if path != "":
			tasks.append({"kind": "texture", "key": key, "name": key + ".png",
				"path": path, "manifest": false})
	var program := from.first_of(SkinRecipes.CARD_TABLE_PROGRAMS)
	if program != "":
		tasks.append({"kind": "card_values", "key": SkinRecipes.CARD_VALUES_KEY,
			"name": SkinRecipes.CARD_VALUES_KEY + ".json", "path": program})
	if from.find("hints.txt") != "" and from.find("info.csv") != "":
		tasks.append({"kind": "hints", "key": SkinRecipes.HINTS_KEY,
			"name": SkinRecipes.HINTS_KEY + ".json", "path": from.find("hints.txt")})
	if from.find("advblocks.txt") != "":
		tasks.append({"kind": "wise_words", "key": SkinRecipes.WISE_WORDS_KEY,
			"name": SkinRecipes.WISE_WORDS_KEY + ".json", "path": from.find("advblocks.txt")})
	for name: String in SkinRecipes.MOVIE_NAMES:
		var path := from.find(name)
		if path != "":
			tasks.append({"kind": "copy", "key": name, "manifest": false,
				"name": SkinRecipes.MOVIE_DIR + "/" + name, "path": path})
	# What Python's movie steps would have made of files that are here.
	var left_out: Array[String] = []
	for key: String in SkinRecipes.VIDEOS:
		if from.first_of(SkinRecipes.VIDEOS[key]) != "":
			left_out.append(key)
	for key: String in SkinRecipes.THEORA_MOVIES:
		if from.first_of(SkinRecipes.THEORA_MOVIES[key]) != "":
			left_out.append(key)
	return {"tasks": tasks, "missing": missing, "refused_png": refused_png,
		"refused_program": refused_program, "left_out": left_out}


## A sound under `Program/DuelSounds/` or `Program/Sound/`: a later
## product's copy at another mastering, which the 1997 game does not have.
static func is_later_sound_copy(path: String) -> bool:
	var folder := path.get_base_dir()
	var name := folder.get_file().to_lower()
	return (name == "duelsounds" or name == "sound") \
		and folder.get_base_dir().get_file().to_lower() == "program"


## A player face's file name by its frame in `16faces.spr`.
static func portrait_name(frame: int) -> String:
	if frame < SkinRecipes.PORTRAIT_NAMES.size():
		return SkinRecipes.PORTRAIT_NAMES[frame]
	return "%s%d" % [SkinRecipes.PORTRAIT_PREFIX, frame + 1]


## An enemy face's file name by its slot, `Faces/<slot>.pic`, counted from 1.
static func rogue_name(slot: int) -> String:
	if slot >= 1 and slot <= SkinRecipes.ROGUE_NAMES.size():
		return SkinRecipes.ROGUE_PREFIX + String(SkinRecipes.ROGUE_NAMES[slot - 1])
	return "%s%02d" % [SkinRecipes.ROGUE_UNNAMED_PREFIX, slot]


# -------------------------------------------------------------- the run --

## Plan the build of [param from] into the zip [param to] and open its
## `.part`. False, with [method result] saying why, when that cannot be.
func open(from: SkinSourceIndex, to: String) -> bool:
	index = from
	dest = to
	_part = to + PART_TAIL
	# (A copy: the job strikes names off these lists as it goes.)
	var made: Dictionary = plan(from) if planned.is_empty() else planned.duplicate(true)
	_tasks = made["tasks"]
	_missing.assign(made["missing"])
	_refused_png = made["refused_png"]
	_refused_program = made["refused_program"]
	_left_out.assign(made["left_out"])
	_at = 0
	_set_shared(0, "")
	# (The sheets laid from cells are planned whatever is there.)
	if not _tasks.any(func(task: Dictionary) -> bool: return String(task["path"]) != ""):
		return _finish(false, "Nothing of the 1997 game was found there.")
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	_zip = ZIPPacker.new()
	if _zip.open(_part) != OK:
		_zip = null
		return _finish(false, "The skin could not be written to %s." % to.get_base_dir())
	return true


## Do tasks for about [param usec] microseconds (at least one; negative:
## to the end). True while there is more to do.
func step(usec := -1) -> bool:
	if _over:
		return false
	var started := Time.get_ticks_usec()
	while not _over:
		if _stopped():
			_finish(false, "Stopped.")
			break
		if _at >= _tasks.size():
			_close()
			break
		var task: Dictionary = _tasks[_at]
		_set_shared(_at, String(task["name"]))
		_do(task)
		_at += 1
		_set_shared(_at, String(task["name"]))
		if usec >= 0 and Time.get_ticks_usec() - started >= usec:
			break
	return not _over


## The whole build on a thread of its own. False when the engine gives
## none — then call [method step] a frame at a time instead.
func start_thread() -> bool:
	if _thread != null or _over:
		return false
	_thread = Thread.new()
	if _thread.start(_run) != OK:
		_thread = null
		return false
	return true


func _run() -> void:
	while step(50_000):
		pass


## Stop at the next task: the `.part` is deleted and nothing else changes.
func cancel() -> void:
	_mutex.lock()
	_stop = true
	_mutex.unlock()


## Wait for the thread, when there is one.
func wait() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


## How far it is: `{done, total, current, finished}` — tasks done of all,
## and the file being made.
func progress() -> Dictionary:
	_mutex.lock()
	var out := _shared.duplicate()
	_mutex.unlock()
	return out


## How it ended (ask once [method progress] says finished): `{ok, why,
## stopped, dest, files, written, skipped, missing, left_out, later_art,
## later_sounds}` — `skipped` a `{name, file, why}` for each file that was
## there and would not decode, `missing` the recipes no file answered.
func result() -> Dictionary:
	return {"ok": _ok, "why": _why, "stopped": _stopped() and not _ok, "dest": dest,
		"files": _written.size(), "written": _written, "skipped": _skipped,
		"missing": _missing, "left_out": _left_out,
		"later_art": _refused_png.size(), "later_sounds": _refused_program.size(),
		"bytes": _bytes_in}


## The whole build at once: [method result].
static func build(folders: Array, to: String) -> Dictionary:
	var job := SkinBuildJob.new()
	if job.open(SkinSourceIndex.of(folders), to):
		job.step()
	return job.result()


func _stopped() -> bool:
	_mutex.lock()
	var stop := _stop
	_mutex.unlock()
	return stop


func _set_shared(done_now: int, current: String) -> void:
	_mutex.lock()
	_shared["done"] = done_now
	_shared["total"] = _tasks.size()
	_shared["current"] = current
	_mutex.unlock()


func _finish(succeeded: bool, why: String) -> bool:
	if _zip != null:
		_zip.close()
		_zip = null
	if not succeeded and _part != "" and FileAccess.file_exists(_part):
		DirAccess.remove_absolute(_part)
	_ok = succeeded
	_why = why
	_over = true
	_mutex.lock()
	_shared["finished"] = true
	_mutex.unlock()
	return succeeded


## The last entry is in: the `.part` takes the zip's name.
func _close() -> void:
	if _written.is_empty():
		_finish(false, "Nothing of the 1997 game could be read there.")
		return
	var err := _zip.close()
	_zip = null
	if err != OK:
		_finish(false, "The skin could not be written (is the disk full?).")
		return
	if DirAccess.rename_absolute(_part, dest) != OK:
		_finish(false, "The skin could not be put at %s." % dest)
		return
	_finish(true, "")


func _do(task: Dictionary) -> void:
	match String(task["kind"]):
		"texture":
			if not _texture(String(task["key"]), String(task["path"])) and bool(task["manifest"]):
				_missing.append(String(task["key"]))
		"copy":
			if not _copy(String(task["name"]), String(task["path"])) and bool(task["manifest"]):
				_missing.append(String(task["key"]))
		"pic_sheet":
			_pic_sheet(String(task["key"]))
		"derived":
			_derived(String(task["key"]))
		"portraits":
			_portraits(String(task["path"]))
		"face":
			_face(String(task["path"]))
		"rogue":
			_rogue(int(task["slot"]), String(task["path"]))
		"card_values":
			_card_values(String(task["path"]))
		"hints":
			_hints(String(task["path"]))
		"wise_words":
			_wise_words(String(task["path"]))


# ------------------------------------------------------------ the files --

func _skip(name: String, path: String, why: String) -> bool:
	_skipped.append({"name": name, "file": path.get_file(), "why": why})
	return false


## A whole file, when it is there, opens and is no larger than [param
## most]: `{error, bytes}` — off the disk or out of a CD image, as the
## index knows ([method SkinSourceIndex.read]: it keeps no handle, so the
## thread this runs on shares none).
func _read(path: String, most: int) -> Dictionary:
	var read := index.read(path, most)
	_bytes_in += (read["bytes"] as PackedByteArray).size()
	return read


## One entry of the zip, whole. False — and the build over — when the
## write fails.
func _put(name: String, bytes: PackedByteArray) -> bool:
	if _over or _written.has(name):
		return false
	if _zip.start_file(PREFIX + name) != OK or _zip.write_file(bytes) != OK \
			or _zip.close_file() != OK:
		return _finish(false, "The skin could not be written (is the disk full?).")
	_written.append(name)
	return true


## RGBA pixels as a PNG entry; without [param alpha] an RGB one, as the
## Python tool writes a picture that has no clear pixel by its kind.
func _put_png(name: String, width: int, height: int, rgba: PackedByteArray, alpha: bool) -> bool:
	if width <= 0 or height <= 0 or rgba.size() != width * height * 4:
		return false
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)
	if not alpha:
		image.convert(Image.FORMAT_RGB8)
	return _put(name, image.save_png_to_buffer())


## The first of [param names] that reads as a palette (a `.tr` list, or a
## `.pic`'s own block), 768 bytes; empty when none does.
func _palette(names: Array) -> PackedByteArray:
	for name: String in names:
		var path := index.find(name)
		if path == "":
			continue
		var cache_key := ("tr:" if name.to_lower().ends_with(".tr") else "pic:") + path
		if not _palettes.has(cache_key):
			var palette := PackedByteArray()
			var read := _read(path, max_text_file if cache_key.begins_with("tr:") else max_art_file)
			if String(read["error"]) == "":
				palette = SkinPicCodec.read_tr_palette(read["bytes"]) \
					if cache_key.begins_with("tr:") else SkinPicCodec.read_palette(read["bytes"])
			_palettes[cache_key] = palette
		var found: PackedByteArray = _palettes[cache_key]
		if not found.is_empty():
			return found
	return PackedByteArray()


## A sound, the font or a movie, byte for byte.
func _copy(name: String, path: String) -> bool:
	if _over or _written.has(name):
		return false
	# Read whole before the entry is opened: an entry begun cannot be
	# taken back out of the zip.
	var read := _read(path, max_copy_file)
	if String(read["error"]) != "":
		return _skip(name, path, String(read["error"]))
	return _put(name, read["bytes"])


## One raw 1997 picture into `<key>.png` — a sprite sheet (with its
## `.json` of the grid where the recipe has one), a Windows bitmap of the
## wizards' window, or a `.pic`.
func _texture(key: String, path: String) -> bool:
	var name := key + ".png"
	if SkinRecipes.SPR_SHEETS.has(key):
		return _spr_sheet(key, path)
	var read := _read(path, max_art_file)
	if String(read["error"]) != "":
		return _skip(name, path, String(read["error"]))
	if path.get_extension().to_lower() == "bmp":
		var bitmap := SkinPicCodec.read_bmp(read["bytes"])
		if String(bitmap["error"]) != "":
			return _skip(name, path, String(bitmap["error"]))
		var pixels: PackedByteArray = bitmap["pixels"]
		var clear: Variant = SkinRecipes.STATWIN_CLEAR.get(key)
		if clear != null:
			pixels = SkinPicCodec.clear_colour(pixels, clear)
		return _put_png(name, int(bitmap["width"]), int(bitmap["height"]), pixels, clear != null)
	var decoded := SkinPicCodec.decode(read["bytes"])
	if String(decoded["error"]) != "":
		return _skip(name, path, String(decoded["error"]))
	var palette := _palette(SkinRecipes.PIC_PALETTES.get(key, SkinRecipes.PIC_PALETTE))
	var own: PackedByteArray = decoded["palette"]
	var indices: PackedByteArray = decoded["indices"]
	var width := int(decoded["width"])
	var height := int(decoded["height"])
	# A sheet the 1997 game cut sprites out of: index 0 clear.
	if SkinRecipes.PIC_CUT.has(key) and not (own.is_empty() and palette.is_empty()):
		var table := SkinPicCodec.pixel_table(palette if own.is_empty() else own, 0)
		return _put_png(name, width, height, SkinPicCodec.paint(indices, table), true)
	# Its own palette: the whole picture, opaque.
	if not own.is_empty():
		return _put_png(name, width, height,
			SkinPicCodec.paint(indices, SkinPicCodec.pixel_table(own)), false)
	if palette.is_empty():
		return _skip(name, path, "it has no palette and none was found beside it")
	if SkinRecipes.PIC_OPAQUE.has(key):
		return _put_png(name, width, height,
			SkinPicCodec.paint(indices, SkinPicCodec.pixel_table(palette)), false)
	# Bare indices: 255 is the 1997 format's clear.
	return _put_png(name, width, height, SkinPicCodec.paint(indices,
		SkinPicCodec.pixel_table(palette, SkinRecipes.PIC_CLEAR)), true)


func _spr_sheet(key: String, path: String) -> bool:
	var name := key + ".png"
	var row: Array = SkinRecipes.SPR_SHEETS[key]
	var cells := int(row[0])
	var cell_w := int(row[1])
	var cell_h := int(row[2])
	var columns := int(SkinRecipes.SPR_COLUMNS.get(key, cells))
	var palette := _palette(SkinRecipes.SPR_PALETTES.get(key, SkinRecipes.SPR_PALETTE))
	if palette.is_empty():
		return _skip(name, path, "no palette for it was found")
	var read := _read(path, max_art_file)
	if String(read["error"]) != "":
		return _skip(name, path, String(read["error"]))
	var decoded := SkinSprCodec.decode(read["bytes"])
	if String(decoded["error"]) != "":
		return _skip(name, path, String(decoded["error"]))
	var sheet := SkinSprCodec.sheet(decoded["frames"], cells, cell_w, cell_h, columns)
	var rgba := SkinPicCodec.paint(sheet["indices"], SkinPicCodec.pixel_table(palette, 0))
	if not _put_png(name, int(sheet["width"]), int(sheet["height"]), rgba, true):
		return false
	if SkinRecipes.SIDECAR_SHEETS.has(key):
		var tops := SkinSprCodec.frame_tops(read["bytes"])
		@warning_ignore("integer_division")
		var layout := {"cols": columns, "rows": (cells + columns - 1) / columns,
			"frames": cells, "frame_width": cell_w, "frame_height": cell_h,
			"tops": tops.slice(0, cells), "source": path.get_file()}
		for size: Array in sheet["sizes"]:
			if size[0] != cell_w or size[1] != cell_h:
				layout["sizes"] = sheet["sizes"]
				break
		_put(key + ".json", (SkinText.json(layout) + "\n").to_utf8_buffer())
	return true


## A sheet laid together from 1997 cells: opaque, each cell at its place.
func _pic_sheet(key: String) -> void:
	if not _missing.has(key):
		return
	var name := key + ".png"
	var row: Array = SkinRecipes.PIC_SHEETS[key]
	var names: Array = row[0]
	var cols := int(row[1])
	var cell_w := int(row[2])
	var cell_h := int(row[3])
	var found: Array[String] = []
	for cell: String in names:
		var path := index.find(cell)
		if path == "":
			return   # a cell is not there: the sheet stays among the missing
		found.append(path)
	var palette := _palette(SkinRecipes.PIC_PALETTE)
	if palette.is_empty():
		_skip(name, String(names[0]), "no palette for it was found")
		return
	var rows := ceili(float(names.size()) / float(cols))
	var width := cols * cell_w
	var height := rows * cell_h
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 1))
	for slot in found.size():
		var read := _read(found[slot], max_art_file)
		if String(read["error"]) != "":
			_skip(name, found[slot], String(read["error"]))
			return
		var decoded := SkinPicCodec.decode(read["bytes"])
		if String(decoded["error"]) != "":
			_skip(name, found[slot], String(decoded["error"]))
			return
		if int(decoded["width"]) != cell_w or int(decoded["height"]) != cell_h:
			_skip(name, found[slot], "it is %d x %d, not %d x %d"
				% [decoded["width"], decoded["height"], cell_w, cell_h])
			return
		var own: PackedByteArray = decoded["palette"]
		var rgba := SkinPicCodec.paint(decoded["indices"],
			SkinPicCodec.pixel_table(palette if own.is_empty() else own))
		var cell_image := Image.create_from_data(cell_w, cell_h, false, Image.FORMAT_RGBA8, rgba)
		@warning_ignore("integer_division")
		sheet.blit_rect(cell_image, Rect2i(0, 0, cell_w, cell_h),
			Vector2i((slot % cols) * cell_w, (slot / cols) * cell_h))
	sheet.convert(Image.FORMAT_RGB8)
	if _put(name, sheet.save_png_to_buffer()):
		_missing.erase(key)
		_sheets[key] = {"width": width, "height": height, "rgb": sheet.get_data()}


## A sheet of OURS, not 1997's: another sheet with every channel scaled.
func _derived(key: String) -> void:
	if not _missing.has(key):
		return
	var row: Array = SkinRecipes.DERIVED_SHEETS[key]
	var parent := String(row[0])
	if not _sheets.has(parent):
		return
	var factor := float(row[1])
	# Python's `min(255, round(value * factor))`: a half rounds to even.
	var scaled := PackedByteArray()
	scaled.resize(256)
	for value in 256:
		var x := value * factor
		var low := floorf(x)
		var part := x - low
		var whole := int(low)
		if part > 0.5 or (part == 0.5 and whole % 2 == 1):
			whole += 1
		scaled[value] = mini(255, whole)
	var source: PackedByteArray = _sheets[parent]["rgb"]
	var out := PackedByteArray()
	out.resize(source.size())
	for i in source.size():
		out[i] = scaled[source[i]]
	var image := Image.create_from_data(int(_sheets[parent]["width"]),
		int(_sheets[parent]["height"]), false, Image.FORMAT_RGB8, out)
	if _put(key + ".png", image.save_png_to_buffer()):
		_missing.erase(key)


## The player faces of `16faces.spr`, one PNG each: every frame of a
## face's size, index 0 clear.
func _portraits(path: String) -> void:
	var palette := _palette(SkinRecipes.PORTRAIT_PALETTE)
	if palette.is_empty():
		_skip("portraits/", path, "no palette for the faces was found")
		return
	var read := _read(path, max_art_file)
	if String(read["error"]) != "":
		_skip("portraits/", path, String(read["error"]))
		return
	var decoded := SkinSprCodec.decode(read["bytes"])
	if String(decoded["error"]) != "":
		_skip("portraits/", path, String(decoded["error"]))
		return
	var table := SkinPicCodec.pixel_table(palette, 0)
	var frames: Array = decoded["frames"]
	var made := 0
	for i in frames.size():
		var frame: Array = frames[i]
		if frame[0] != SkinRecipes.PORTRAIT_CELL[0] or frame[1] != SkinRecipes.PORTRAIT_CELL[1]:
			continue
		if _put_png("portraits/%s.png" % portrait_name(i), int(frame[0]), int(frame[1]),
				SkinPicCodec.paint(frame[2], table), true):
			made += 1
	if made == 0 and not _over:
		_skip("portraits/", path, "it holds no frame of a face's size")


## One `<image><mask>` picture as RGBA, when it is of the size [param
## cell]; empty, noted, otherwise.
func _cut_masked(name: String, path: String, palette: PackedByteArray, cell: Array) -> PackedByteArray:
	var read := _read(path, max_art_file)
	if String(read["error"]) != "":
		_skip(name, path, String(read["error"]))
		return PackedByteArray()
	var decoded := SkinPicCodec.decode(read["bytes"])
	if String(decoded["error"]) != "":
		_skip(name, path, String(decoded["error"]))
		return PackedByteArray()
	var halves := SkinPicCodec.split_image_mask(int(decoded["width"]), int(decoded["height"]),
		decoded["indices"])
	if String(halves["error"]) != "":
		_skip(name, path, String(halves["error"]))
		return PackedByteArray()
	if int(halves["half"]) != int(cell[0]) or int(decoded["height"]) != int(cell[1]):
		_skip(name, path, "it is %d x %d, not %d x %d"
			% [halves["half"], decoded["height"], cell[0], cell[1]])
		return PackedByteArray()
	var own: PackedByteArray = decoded["palette"]
	return SkinPicCodec.paint_masked(halves["image"], palette if own.is_empty() else own,
		halves["clear"])


## `Face.pic`, the face the player made in the 1997 Facemaker.
func _face(path: String) -> void:
	var palette := _palette(SkinRecipes.PORTRAIT_PALETTE)
	if palette.is_empty():
		return
	var name := "portraits/%s.png" % SkinRecipes.PLAYER_FACE_NAME
	var pixels := _cut_masked(name, path, palette, SkinRecipes.PORTRAIT_CELL)
	if not pixels.is_empty():
		_put_png(name, int(SkinRecipes.PORTRAIT_CELL[0]), int(SkinRecipes.PORTRAIT_CELL[1]),
			pixels, true)


## One enemy face, `Faces/<slot>.pic`. A slot with no name is written by
## its number unless it is the picture of a face already written (the two
## end caps of a 1997 install are).
func _rogue(slot: int, path: String) -> void:
	var name := "portraits/%s.png" % rogue_name(slot)
	if _rogue_palette == null:
		_rogue_palette = _palette(SkinRecipes.ROGUE_PALETTE)
		if (_rogue_palette as PackedByteArray).is_empty():
			_skip("portraits/", path, "no palette for the enemy faces was found")
	var palette: PackedByteArray = _rogue_palette
	if palette.is_empty():
		return
	var pixels := _cut_masked(name, path, palette, SkinRecipes.ROGUE_CELL)
	if pixels.is_empty():
		return
	var named := slot >= 1 and slot <= SkinRecipes.ROGUE_NAMES.size()
	if not named:
		for seen: PackedByteArray in _rogue_seen:
			if seen == pixels:
				return
	_rogue_seen.append(pixels)
	_put_png(name, int(SkinRecipes.ROGUE_CELL[0]), int(SkinRecipes.ROGUE_CELL[1]), pixels, true)


# ------------------------------------------------- the adventure's lists --

## The 1997 card table's place in a program, or -1: the row named Swamp
## with Island, Forest, Mountain and Plains in the rows after it.
static func find_card_table(data: PackedByteArray) -> int:
	var names: Array[PackedByteArray] = []
	for word: String in ["Swamp", "Island", "Forest", "Mountain", "Plains"]:
		var bytes := word.to_ascii_buffer()
		bytes.append(0)
		names.append(bytes)
	var step_size: int = SkinRecipes.CARD_ROW
	var total := data.size()
	var at := _find_bytes(data, names[0], 0)
	while at >= 1:
		var row := at - 1
		var all := true
		for i in names.size():
			var from := row + step_size * i + 1
			if from + names[i].size() > total or data.slice(from, from + names[i].size()) != names[i]:
				all = false
				break
		if all:
			return row
		at = _find_bytes(data, names[0], at + 1)
	return -1


static func _find_bytes(data: PackedByteArray, what: PackedByteArray, from: int) -> int:
	var total := data.size()
	var length := what.size()
	var at := data.find(what[0], from)
	while at >= 0 and at + length <= total:
		if data.slice(at, at + length) == what:
			return at
		at = data.find(what[0], at + 1)
	return -1


## The table's rows from [param row] until one has no name: the fields
## the 1997 shop's price and offer read (72 bytes a row).
static func read_card_table(data: PackedByteArray, row: int) -> Array:
	var rows: Array = []
	var step_size: int = SkinRecipes.CARD_ROW
	var total := data.size()
	while row + step_size <= total and rows.size() < MAX_CARD_ROWS:
		var end := data.find(0, row + 1)
		if end < 0 or end > row + 20:
			end = row + 20
		if end == row + 1:
			break
		var printable := true
		for i in range(row + 1, end):
			if data[i] < 32 or data[i] >= 127:
				printable = false
				break
		if not printable:
			break
		rows.append({"short": data.slice(row + 1, end).get_string_from_ascii(),
			"id": data.decode_u16(row + 0x24), "type": data[row + 0x28],
			"color": data.decode_s8(row + 0x2a),
			"cc0": data.decode_s8(row + 0x2b), "cc1": data.decode_s8(row + 0x2c),
			"power": data.decode_s16(row + 0x2e), "tough": data.decode_s16(row + 0x30),
			"code": data.decode_u32(row + 0x34), "static": data.decode_u32(row + 0x38),
			"extra": data.decode_u32(row + 0x3c),
			"rarity": data[row + 0x40], "exp": data[row + 0x42],
			"ai": data.decode_s32(row + 0x44)})
		row += step_size
	return rows


## A CSV's column [param column] by the whole number in its first.
static func csv_by_id(text: String, column: int) -> Dictionary:
	var out := {}
	for fields: Array in SkinText.csv_rows(SkinText.lines(text)):
		if fields.size() <= column:
			continue
		var id := SkinText.strip(String(fields[0]))
		if SkinText.is_digits(id) and id.length() <= 18:
			out[int(id)] = SkinText.strip(String(fields[column]))
	return out


## The table by each card's full name ([param names]: id -> name):
## `vanilla` where its code is the one most rows share, `rarity` the
## shop's ([param rarities]), else the word of [param occurrences].
static func card_values(rows: Array, names: Dictionary, rarities: Dictionary,
		occurrences: Dictionary) -> Dictionary:
	var counts := {}
	for row: Dictionary in rows:
		counts[row["code"]] = int(counts.get(row["code"], 0)) + 1
	var dummy := 0
	var most := 0
	for code: int in counts:
		if int(counts[code]) > most:
			most = int(counts[code])
			dummy = code
	var out := {}
	for row: Dictionary in rows:
		var name := String(names.get(row["id"], ""))
		if name == "" or out.has(name):
			continue
		var entry := {}
		for field: String in ["id", "type", "color", "cc0", "cc1", "power", "tough",
				"static", "extra", "exp", "ai"]:
			entry[field] = row[field]
		entry["vanilla"] = row["code"] == dummy
		var word := SkinText.strip(String(occurrences.get(row["id"], ""))).to_lower()
		entry["rarity"] = rarities.get(row["id"], SkinRecipes.OCCURRENCE.get(word, 1))
		out[name] = entry
	return out


## `Info.csv`'s card names (and rarity words) by id, read once.
func _card_names() -> Dictionary:
	if _names_by_id == null:
		_names_by_id = {}
		var info := index.find("info.csv")
		if info != "":
			var read := _read(info, max_text_file)
			if String(read["error"]) == "":
				var text := SkinText.decode(read["bytes"])
				_names_by_id = csv_by_id(text, 1)
				_occurrences = csv_by_id(text, 8)
	return _names_by_id


func _card_values(program: String) -> void:
	var name: String = SkinRecipes.CARD_VALUES_KEY + ".json"
	var read := _read(program, max_data_file)
	if String(read["error"]) != "":
		_skip(name, program, String(read["error"]))
		return
	var data: PackedByteArray = read["bytes"]
	var row := find_card_table(data)
	if row < 0:
		_skip(name, program, "no card table was found in it")
		return
	var rows := read_card_table(data, row)
	var names := _card_names()
	var rarities := {}
	var concise := index.find("concise.csv")
	if concise != "":
		var listed := _read(concise, max_text_file)
		if String(listed["error"]) == "":
			for line in SkinText.lines(SkinText.decode(listed["bytes"])):
				var bits := SkinText.words(line)
				if bits.size() == 3 and SkinText.is_digits(bits[0]) and SkinText.is_digits(bits[1]) \
						and bits[0].length() <= 18 and bits[1].length() <= 18:
					rarities[int(bits[0])] = int(bits[1])
	var values := card_values(rows, names, rarities, _occurrences)
	if values.is_empty():
		_skip(name, program, "none of its cards is named in Info.csv")
		return
	_put(name, (SkinText.json({"source": program.get_file(), "cards": values}, true) + "\n")
		.to_utf8_buffer())


## The hints of a `Hints.txt`: `{first, second, levels, text}`, the cards
## by name (`second` "" for a single card), `levels` a bit for each
## difficulty letter. An entry whose card is not named is left out.
static func card_hints(text: String, names: Dictionary) -> Array:
	var out: Array = []
	var head: Variant = null
	for raw in SkinText.lines(text):
		var line := SkinText.strip(raw)
		if line.begins_with("."):
			head = SkinText.words(line.substr(1))
			continue
		if line == "" or head == null:
			continue
		var bits: PackedStringArray = head
		head = null
		if bits.size() < 3 or not _is_number(bits[0]) or not _is_number(bits[1]):
			continue
		var second_id := int(bits[1])
		var first := String(names.get(int(bits[0]), ""))
		var second := String(names.get(second_id, "")) if second_id >= 0 else ""
		if first == "" or (second_id >= 0 and second == ""):
			continue
		var levels := 0
		for letter in bits[2]:
			levels |= int(SkinRecipes.HINT_LEVELS.get(letter.to_upper(), 0))
		out.append({"first": first, "second": second, "levels": levels, "text": line.substr(0, 256)})
	return out


## A whole number, with or without one minus sign before it.
static func _is_number(word: String) -> bool:
	var digits := word.trim_prefix("-")
	return SkinText.is_digits(digits) and digits.length() <= 18


func _hints(source: String) -> void:
	var name: String = SkinRecipes.HINTS_KEY + ".json"
	var read := _read(source, max_text_file)
	if String(read["error"]) != "":
		_skip(name, source, String(read["error"]))
		return
	var hints := card_hints(SkinText.decode(read["bytes"], true), _card_names())
	if hints.is_empty():
		_skip(name, source, "no hint could be read in it")
		return
	_put(name, (SkinText.json({"source": source.get_file(), "hints": hints}, true) + "\n")
		.to_utf8_buffer())


## The blocks of an `Advblocks.txt`: `{city, tales}` — the first four
## blocks a text each, the rest a list of pages each.
static func wise_words(text: String) -> Dictionary:
	var blocks: Array = []
	var plain := text.replace("\r", "")
	var at := 0
	while true:
		var start := plain.find("STARTBLOCK\n", at)
		if start < 0:
			break
		var end := plain.find("ENDBLOCK", start)
		if end < 0:
			break
		var body := plain.substr(start + 11, end - start - 11)
		var pages: Array = [body]
		if body.contains("\n\n\n\n"):
			pages = Array(body.split("\n\n\n\n"))
			pages.pop_back()
		var block: Array = []
		for page: String in pages:
			if SkinText.strip(page) != "":
				block.append(page.rstrip("\n"))
		blocks.append(block)
		at = end + 8
	var city: Array = []
	for block: Array in blocks.slice(0, 4):
		city.append("\n\n".join(PackedStringArray(block)))
	return {"city": city, "tales": blocks.slice(4)}


func _wise_words(source: String) -> void:
	var name: String = SkinRecipes.WISE_WORDS_KEY + ".json"
	var read := _read(source, max_text_file)
	if String(read["error"]) != "":
		_skip(name, source, String(read["error"]))
		return
	var words := wise_words(SkinText.decode(read["bytes"], true))
	if (words["city"] as Array).size() < 4 or (words["tales"] as Array).is_empty():
		_skip(name, source, "no blocks could be read in it")
		return
	_put(name, (SkinText.json(words, true) + "\n").to_utf8_buffer())
