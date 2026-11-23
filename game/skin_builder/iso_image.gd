class_name SkinIsoImage
extends RefCounted
## A CD IMAGE READ AS IT IS — the 1997 game's disc as one file, for the
## skin builder (the owner, 2026-11-23: *"Can skin be built also from 1997
## Shandalar CD or its iso image?"*, *"Yes choose iso add it."*). [QoL]:
## the Python tools read folders only.
##
## WHAT IS READ:
##  - a plain ISO 9660 image (`.iso`: 2048 bytes a sector);
##  - a raw image (`.bin`, `.img`, `.mdf`: 2352 bytes a sector, the 2048
##    of data after a 16-byte head in Mode 1 and a 24-byte one in Mode 2
##    Form 1; 2448 with subchannels, and 2336 without the sync, are told
##    the same way). Which it is, is found, not asked: the volume's mark
##    `CD001` stands at sector 16, wherever a sector's data begins;
##  - a `.cue` sheet, which is only a pointer: its first `FILE` line names
##    the image beside it, and a name that leads out of the sheet's own
##    folder is refused.
## The names are the Joliet ones when the disc has them (Windows' long
## names, UCS-2), else the primary volume's, with the `;1` and a trailing
## dot taken off. A file is looked up whatever its case.
##
## NOT READ: a file in several extents or interleaved (over 4 GB — none
## on a 1997 disc; left out and counted, [member unsupported]), Rock
## Ridge names, blocks that are not 2048 bytes, UDF-only discs, a second
## session or track, a compressed image, and anything packed inside an
## installer's own archive on the disc.
##
## NOTHING IN THE IMAGE IS TRUSTED. Every length is checked against the
## sector it lies in and the file it lies in before it is used; a
## directory is walked once whatever points at it (a loop ends there);
## the walk stops at [member max_entries] files, [constant MAX_DIRS]
## directories, [constant MAX_DEPTH] deep and [constant MAX_TREE_BYTES]
## of directories read, [member cut_short] saying so; a file whose data
## lies past the image's end is left out and counted ([member damaged]).
## A name is never used as a path on the disk: it is a key in a table.
##
## NOTHING IS UNPACKED and no handle is kept: [method open] reads the
## directories and closes the file; each [method read] opens the image,
## seeks, reads and closes again. So once open, an image is only tables,
## and any thread may read through it at the same time as another.

const BLOCK := 2048
## `[bytes a sector, where its data begins]`, in the order tried.
const LAYOUTS: Array = [[2048, 0], [2352, 16], [2352, 24], [2448, 16], [2448, 24], [2336, 8]]
const MAX_ENTRIES := 50_000
const MAX_DIRS := 8192
const MAX_DEPTH := 24
## The most bytes one directory, and all of them together, may be.
const MAX_DIR_BYTES := 4 << 20
const MAX_TREE_BYTES := 64 << 20
const MAX_DESCRIPTORS := 32
const MAX_CUE_BYTES := 64 << 10
## The most a [method read] hands back when the caller sets no bound.
const MAX_READ := 256 << 20
## Sectors read at a go from a raw image.
const RAW_CHUNK := 2048

## The image file read (a `.cue`'s image, not the sheet).
var path := ""
var sector_size := 0
var data_offset := 0
## Whether the names are the Joliet ones.
var joliet := false
var cut_short := false
var damaged := 0
var unsupported := 0
## The bound on files; a test sets it lower.
var max_entries := MAX_ENTRIES

## Lower-case path -> `[first block, bytes, the path as the disc spells it]`.
var _files: Dictionary = {}
var _order: Array[String] = []
var _folders: Array[String] = []


## Open the image at [param image_path] (or the one its `.cue` names) and
## read its directories. "" when it is open, else why not, as the end of
## a sentence that begins with the file's name.
func open(image_path: String) -> String:
	close()
	if not FileAccess.file_exists(image_path):
		return "it is not there"
	var file := FileAccess.open(image_path, FileAccess.READ)
	if file == null:
		return "it could not be opened"
	var why := _open_volume(file, image_path)
	if why != "" and file.get_length() <= MAX_CUE_BYTES:
		# Not an image itself: a sheet that names one?
		file.seek(0)
		var sheet := file.get_buffer(file.get_length())
		file.close()
		var named := image_of_cue(sheet, image_path.get_base_dir())
		if String(named["error"]) != "":
			return String(named["error"]) if bool(named["is_cue"]) else why
		file = FileAccess.open(String(named["path"]), FileAccess.READ)
		if file == null:
			return "the image its .cue names could not be opened"
		why = _open_volume(file, String(named["path"]))
	file.close()
	if why != "":
		close()
	return why


## Forget the image.
func close() -> void:
	path = ""
	sector_size = 0
	data_offset = 0
	joliet = false
	cut_short = false
	damaged = 0
	unsupported = 0
	_files = {}
	_order = []
	_folders = []


## Whether an image is open.
func is_open() -> bool:
	return path != ""


## Every file in it: `{path, size}`, the path with `/` between its parts.
func entries() -> Array:
	var out: Array = []
	for name in _order:
		out.append({"path": name, "size": int(_files[name.to_lower()][1])})
	return out


## Every directory in it, by its path.
func folders() -> Array[String]:
	return _folders


## How many bytes the file at [param inner] is, or -1 when there is none.
func size_of(inner: String) -> int:
	var row: Variant = _files.get(inner.to_lower())
	return int(row[1]) if row != null else -1


## The file at [param inner], whole — empty when it is not there, is
## larger than [param most] or cannot be read ([method read_checked] says
## which).
func read(inner: String, most := MAX_READ) -> PackedByteArray:
	return read_checked(inner, most)["bytes"]


## The same with the reason: `{error, bytes}`. With [param only_first] it
## hands back that many bytes from the file's start at most.
func read_checked(inner: String, most := MAX_READ, only_first := -1) -> Dictionary:
	var row: Variant = _files.get(inner.to_lower())
	if row == null:
		return _refused("it is not in the image")
	var size := int(row[1])
	if only_first >= 0:
		size = mini(size, only_first)
	elif size > most:
		return _refused("it is far larger than any 1997 file of its kind")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _refused("the image could not be opened")
	var bytes: Variant = _read_blocks(file, int(row[0]), size)
	file.close()
	if bytes == null:
		return _refused("the image is cut short there")
	return {"error": "", "bytes": bytes}


static func _refused(why: String) -> Dictionary:
	return {"error": why, "bytes": PackedByteArray()}


# ----------------------------------------------------------- the .cue --

## The image a `.cue` sheet names: `{error, path, is_cue}`. Its first
## `FILE` line, the name taken as a file in [param folder] and nothing
## else — a name with a folder in it, or one that climbs out, is refused.
static func image_of_cue(sheet: PackedByteArray, folder: String) -> Dictionary:
	var name := ""
	var found := false
	for raw in SkinText.lines(SkinText.decode(sheet.slice(0, MAX_CUE_BYTES))):
		var line := SkinText.strip(raw)
		if not line.to_upper().begins_with("FILE"):
			continue
		if line.length() > 4 and not SkinText.is_space(line.unicode_at(4)):
			continue
		found = true
		var first := line.find("\"")
		var last := line.rfind("\"")
		if first >= 0 and last > first:
			name = line.substr(first + 1, last - first - 1)
		else:
			var words := SkinText.words(line)
			name = words[1] if words.size() > 1 else ""
		break
	if not found:
		return {"error": "it is not a .cue sheet", "path": "", "is_cue": false}
	if name == "" or name == "." or name == ".." or not name.is_valid_filename() \
			or name.contains("/") or name.contains("\\") or name.contains(":"):
		return {"error": "its .cue names a file outside its own folder, which the game will not follow",
			"path": "", "is_cue": true}
	var beside := folder.path_join(name)
	if FileAccess.file_exists(beside):
		return {"error": "", "path": beside, "is_cue": true}
	# Sheets written on Windows often spell the name in another case.
	var dir := DirAccess.open(folder)
	if dir != null:
		var lower := name.to_lower()
		var looked := 0
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "" and looked < 20_000:
			if entry.to_lower() == lower and not dir.current_is_dir():
				dir.list_dir_end()
				return {"error": "", "path": folder.path_join(entry), "is_cue": true}
			looked += 1
			entry = dir.get_next()
		dir.list_dir_end()
	return {"error": "its .cue names %s, which is not beside it" % name, "path": "", "is_cue": true}


# --------------------------------------------------------- the volume --

func _open_volume(file: FileAccess, image_path: String) -> String:
	var length := file.get_length()
	sector_size = 0
	for layout: Array in LAYOUTS:
		var at := 16 * int(layout[0]) + int(layout[1])
		if at + BLOCK > length:
			continue
		file.seek(at)
		var head := file.get_buffer(6)
		if head.size() == 6 and head.slice(1, 6) == "CD001".to_ascii_buffer():
			sector_size = int(layout[0])
			data_offset = int(layout[1])
			break
	if sector_size == 0:
		return "it is not a CD image the game can read"
	path = image_path
	# The volume descriptors, from sector 16 to the one that ends them.
	var primary := PackedByteArray()
	var long_names := PackedByteArray()
	for i in MAX_DESCRIPTORS:
		var block: Variant = _read_blocks(file, 16 + i, BLOCK)
		if block == null:
			break
		var descriptor: PackedByteArray = block
		if descriptor.slice(1, 6) != "CD001".to_ascii_buffer() or descriptor[0] == 255:
			break
		if descriptor[0] == 1 and primary.is_empty():
			primary = descriptor
		elif descriptor[0] == 2 and long_names.is_empty() and _is_joliet(descriptor):
			long_names = descriptor
	var volume := primary if long_names.is_empty() else long_names
	if volume.is_empty():
		return "it holds no volume the game can read"
	joliet = not long_names.is_empty()
	if volume.decode_u16(128) != BLOCK:
		return "its blocks are not 2048 bytes"
	var root_at := volume.decode_u32(158) + volume[157]
	var root_size := volume.decode_u32(166)
	return _walk(file, root_at, root_size)


## A supplementary volume whose names are UCS-2: one of Joliet's three
## escape sequences among its escapes.
static func _is_joliet(descriptor: PackedByteArray) -> bool:
	for i in range(88, 118):
		if descriptor[i] == 0x25 and descriptor[i + 1] == 0x2F \
				and (descriptor[i + 2] == 0x40 or descriptor[i + 2] == 0x43 or descriptor[i + 2] == 0x45):
			return true
	return false


## The directories from the root down, each once.
func _walk(file: FileAccess, root_at: int, root_size: int) -> String:
	var visited := {}
	var stack: Array = [[root_at, root_size, "", 0]]
	var dirs := 0
	var tree_bytes := 0
	var partial := {}
	while not stack.is_empty():
		var here: Array = stack.pop_back()
		var at := int(here[0])
		var parent := String(here[2])
		var depth := int(here[3])
		if visited.has(at):
			continue   # a directory that leads back to one already read
		visited[at] = true
		dirs += 1
		var size := int(here[1])
		if dirs > MAX_DIRS or tree_bytes >= MAX_TREE_BYTES:
			cut_short = true
			break
		if size > MAX_DIR_BYTES:
			cut_short = true
			size = MAX_DIR_BYTES
		var read_now: Variant = _read_blocks(file, at, size)
		if read_now == null:
			if depth == 0:
				return "it is cut short: its list of files is not all there"
			damaged += 1
			continue
		var data: PackedByteArray = read_now
		tree_bytes += data.size()
		var total := data.size()
		var pos := 0
		while pos < total:
			var sector_end := mini((pos / BLOCK + 1) * BLOCK, total)
			var length := data[pos]
			# Nothing more in this sector, or a record that does not fit
			# it: on to the next one.
			if length < 34 or pos + length > sector_end or 33 + data[pos + 32] > length:
				pos = sector_end
				continue
			var flags := data[pos + 25]
			var extent := data.decode_u32(pos + 2) + data[pos + 1]
			var bytes := data.decode_u32(pos + 10)
			var interleaved := data[pos + 26] != 0 or data[pos + 27] != 0
			var name_bytes := data.slice(pos + 33, pos + 33 + data[pos + 32])
			pos += length
			if name_bytes.size() == 1 and name_bytes[0] <= 1:
				continue   # the directory itself, and its parent
			var name := _name(name_bytes)
			if name == "" or name == "." or name == ".." or name.contains("/") or name.contains("\\"):
				continue
			var inner := name if parent == "" else parent + "/" + name
			if flags & 0x02:
				_folders.append(inner)
				if depth + 1 >= MAX_DEPTH:
					cut_short = true
				else:
					stack.append([extent, bytes, inner, depth + 1])
				continue
			var lower := inner.to_lower()
			if (flags & 0x80) or interleaved or partial.has(lower):
				# A file in several pieces: its first piece is not the file.
				if not partial.has(lower):
					unsupported += 1
					partial[lower] = true
				continue
			if _order.size() >= max_entries:
				cut_short = true
				stack.clear()
				break
			if not _fits(file.get_length(), extent, bytes):
				damaged += 1
				continue
			if not _files.has(lower):
				_files[lower] = [extent, bytes, inner]
				_order.append(inner)
	return ""


## A record's name as text: UCS-2 on a Joliet volume, else one byte a
## letter; the version (`;1`) and a trailing dot taken off.
func _name(raw: PackedByteArray) -> String:
	var points := PackedInt32Array()
	if joliet:
		for i in range(0, raw.size() - 1, 2):
			var code := (raw[i] << 8) | raw[i + 1]
			if code != 0:
				points.append(code)
	else:
		for byte in raw:
			if byte != 0:
				points.append(byte)
	if points.is_empty():
		return ""
	var name := points.to_byte_array().get_string_from_utf32()
	var cut := name.rfind(";")
	if cut >= 0 and SkinText.is_digits(name.substr(cut + 1)):
		name = name.substr(0, cut)
	if not joliet and name.ends_with(".") and name.length() > 1:
		name = name.substr(0, name.length() - 1)
	return name


## Whether [param bytes] from block [param at] lie inside an image of
## [param length] bytes.
func _fits(length: int, at: int, bytes: int) -> bool:
	if bytes == 0:
		return true
	if at < 0 or bytes < 0:
		return false
	@warning_ignore("integer_division")
	var blocks := (bytes + BLOCK - 1) / BLOCK
	if data_offset == 0 and sector_size == BLOCK:
		return at * BLOCK + bytes <= length
	return (at + blocks - 1) * sector_size + data_offset + BLOCK <= length


## [param bytes] of data from block [param at]: null when they are not
## all in the image.
func _read_blocks(file: FileAccess, at: int, bytes: int) -> Variant:
	if bytes <= 0:
		return PackedByteArray()
	if not _fits(file.get_length(), at, bytes):
		return null
	if data_offset == 0 and sector_size == BLOCK:
		file.seek(at * BLOCK)
		var plain := file.get_buffer(bytes)
		return plain if plain.size() == bytes else null
	# A raw image: the 2048 of each sector, a run of sectors at a go.
	@warning_ignore("integer_division")
	var blocks := (bytes + BLOCK - 1) / BLOCK
	var out := PackedByteArray()
	var done := 0
	while done < blocks:
		var run := mini(RAW_CHUNK, blocks - done)
		file.seek((at + done) * sector_size)
		var raw := file.get_buffer(run * sector_size)
		if raw.size() < (run - 1) * sector_size + data_offset + BLOCK:
			return null
		for i in run:
			var from := i * sector_size + data_offset
			out.append_array(raw.slice(from, from + BLOCK))
		done += run
	out.resize(bytes)
	return out
