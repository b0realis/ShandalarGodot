class_name C1123SkinIso
extends RefCounted
## A TINY CD IMAGE WRITER, for the skin builder's tests (builders
## 2026-11-23): made-up files laid out as an ISO 9660 volume — the primary
## tree (capitals, `;1`) and, when asked, a Joliet one (UCS-2 names) —
## written apart from the reader it tests ([SkinIsoImage]). No path
## tables, dates or padding a real disc would carry: only what a reader
## of the directories needs. Also the raw wrapping of sectors (2352 bytes,
## Mode 1 or Mode 2 Form 1) and a `.cue` sheet's text.

const BLOCK := 2048


static func le32(value: int) -> PackedByteArray:
	return PackedByteArray([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF])


static func both32(value: int) -> PackedByteArray:
	var out := le32(value)
	out.append_array(PackedByteArray([(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]))
	return out


static func both16(value: int) -> PackedByteArray:
	return PackedByteArray([value & 0xFF, (value >> 8) & 0xFF, (value >> 8) & 0xFF, value & 0xFF])


static func zeros(count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(maxi(count, 0))
	out.fill(0)
	return out


## [param name] as the primary tree spells it: capitals, and `;1` on a file.
static func primary_name(name: String, is_dir: bool, versions := true) -> PackedByteArray:
	var text := name.to_upper()
	if not is_dir:
		if not text.contains("."):
			text += "."
		if versions:
			text += ";1"
	# One byte a letter: what is not ASCII becomes an underline.
	var out := PackedByteArray()
	for i in text.length():
		var code := text.unicode_at(i)
		out.append(code if code < 128 else 0x5F)
	return out


## [param name] as the Joliet tree spells it: two bytes a letter, high first.
static func joliet_name(name: String, is_dir: bool, versions := true) -> PackedByteArray:
	var text := name + (";1" if versions and not is_dir else "")
	var out := PackedByteArray()
	for i in text.length():
		var code := text.unicode_at(i)
		out.append((code >> 8) & 0xFF)
		out.append(code & 0xFF)
	return out


## One directory record.
static func record(name: PackedByteArray, at: int, bytes: int, is_dir: bool, flags := -1) -> PackedByteArray:
	var length := 33 + name.size()
	if length % 2 == 1:
		length += 1
	var out := PackedByteArray([length, 0])
	out.append_array(both32(at))
	out.append_array(both32(bytes))
	out.append_array(zeros(7))
	out.append((0x02 if is_dir else 0x00) if flags < 0 else flags)
	out.append_array(PackedByteArray([0, 0]))
	out.append_array(both16(1))
	out.append(name.size())
	out.append_array(name)
	out.append_array(zeros(length - out.size()))
	return out


## [param records] laid in sectors: none crosses a sector's end.
static func directory(records: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for item: PackedByteArray in records:
		if (out.size() % BLOCK) + item.size() > BLOCK:
			out.append_array(zeros(BLOCK - out.size() % BLOCK))
		out.append_array(item)
	if out.size() % BLOCK != 0 or out.is_empty():
		out.append_array(zeros(BLOCK - out.size() % BLOCK))
	return out


## An image of [param files] (path -> bytes, `/` between a path's parts):
## `{bytes, primary_root, joliet_root, files}` — the image, the block each
## tree's root directory begins at, and each file's first block by path.
static func make(files: Dictionary, joliet := true, versions := true) -> Dictionary:
	# The directories, parents before their children.
	var dirs: Array[String] = [""]
	for path: String in files:
		var parts := path.split("/")
		var here := ""
		for i in parts.size() - 1:
			here = parts[i] if here == "" else here + "/" + parts[i]
			if not dirs.has(here):
				dirs.append(here)
	var trees := [false, true] if joliet else [false]
	# How many blocks each directory takes, tree by tree (the names differ).
	var sizes := {}
	for long: bool in trees:
		for dir in dirs:
			sizes[_key(long, dir)] = directory(_records(dir, dirs, files, long, versions, {}, {}, {})).size()
	var next := 16 + trees.size() + 1
	var dir_at := {}
	for long: bool in trees:
		for dir in dirs:
			dir_at[_key(long, dir)] = next
			@warning_ignore("integer_division")
			next += int(sizes[_key(long, dir)]) / BLOCK
	var file_at := {}
	for path: String in files:
		file_at[path] = next
		@warning_ignore("integer_division")
		next += maxi(((files[path] as PackedByteArray).size() + BLOCK - 1) / BLOCK, 1)
	var total := next

	var out := zeros(16 * BLOCK)
	for long: bool in trees:
		out.append_array(_descriptor(long, total, int(dir_at[_key(long, "")]), int(sizes[_key(long, "")])))
	var last := zeros(BLOCK)
	last[0] = 255
	for i in 5:
		last[1 + i] = "CD001".unicode_at(i)
	last[6] = 1
	out.append_array(last)
	for long: bool in trees:
		for dir in dirs:
			out.append_array(directory(_records(dir, dirs, files, long, versions, dir_at, sizes, file_at)))
	for path: String in files:
		var data: PackedByteArray = files[path]
		out.append_array(data)
		@warning_ignore("integer_division")
		var blocks := maxi((data.size() + BLOCK - 1) / BLOCK, 1)
		out.append_array(zeros(blocks * BLOCK - data.size()))
	return {"bytes": out, "primary_root": int(dir_at[_key(false, "")]),
		"joliet_root": int(dir_at.get(_key(true, ""), 0)), "files": file_at, "dirs": dir_at}


## A directory's key in the tables: its tree, then its path.
static func _key(long: bool, dir: String) -> String:
	return ("J:" if long else "P:") + dir


static func _records(dir: String, dirs: Array[String], files: Dictionary, long: bool,
		versions: bool, dir_at: Dictionary, sizes: Dictionary, file_at: Dictionary) -> Array:
	var parent := dir.get_base_dir() if dir.contains("/") else ""
	var out: Array = [
		record(PackedByteArray([0]), int(dir_at.get(_key(long, dir), 0)), int(sizes.get(_key(long, dir), 0)), true),
		record(PackedByteArray([1]), int(dir_at.get(_key(long, parent), 0)), int(sizes.get(_key(long, parent), 0)), true)]
	for other in dirs:
		if other != "" and (other.get_base_dir() if other.contains("/") else "") == dir:
			var name := other.get_file()
			out.append(record(joliet_name(name, true) if long else primary_name(name, true),
				int(dir_at.get(_key(long, other), 0)), int(sizes.get(_key(long, other), 0)), true))
	for path: String in files:
		if (path.get_base_dir() if path.contains("/") else "") == dir:
			var name := path.get_file()
			out.append(record(joliet_name(name, false, versions) if long else primary_name(name, false, versions),
				int(file_at.get(path, 0)), (files[path] as PackedByteArray).size(), false))
	return out


static func _descriptor(long: bool, total: int, root_at: int, root_size: int) -> PackedByteArray:
	var out := zeros(BLOCK)
	out[0] = 2 if long else 1
	for i in 5:
		out[1 + i] = "CD001".unicode_at(i)
	out[6] = 1
	_put(out, 80, both32(total))
	if long:
		_put(out, 88, PackedByteArray([0x25, 0x2F, 0x45]))
	_put(out, 120, both16(1))
	_put(out, 124, both16(1))
	_put(out, 128, both16(BLOCK))
	_put(out, 156, record(PackedByteArray([0]), root_at, root_size, true))
	out[881] = 1
	return out


static func _put(into: PackedByteArray, at: int, what: PackedByteArray) -> void:
	for i in what.size():
		into[at + i] = what[i]


## Where the record named [param name] (as its tree spells it) begins in
## [param image], in the directory at block [param dir_at]; -1 when it is
## not in that directory's first sector.
static func find_record(image: PackedByteArray, dir_at: int, name: PackedByteArray) -> int:
	var pos := dir_at * BLOCK
	var end := pos + BLOCK
	while pos < end and image[pos] >= 34:
		var length := image[pos]
		if image.slice(pos + 33, pos + 33 + image[pos + 32]) == name:
			return pos
		pos += length
	return -1


## [param image] (2048-byte sectors) wrapped in raw 2352-byte sectors:
## [param mode] 1, or 2 for Mode 2 Form 1. The error-correcting bytes are
## zeros.
static func raw(image: PackedByteArray, mode := 1) -> PackedByteArray:
	var out := PackedByteArray()
	@warning_ignore("integer_division")
	var sectors := image.size() / BLOCK
	var sync := PackedByteArray([0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0])
	for i in sectors:
		out.append_array(sync)
		out.append_array(PackedByteArray([0, 2, i % 75, mode]))
		if mode == 2:
			out.append_array(zeros(8))
		out.append_array(image.slice(i * BLOCK, (i + 1) * BLOCK))
		out.append_array(zeros(288 if mode == 1 else 280))
	return out


## A `.cue` sheet naming [param image_name].
static func cue(image_name: String, mode := 1, quoted := true) -> PackedByteArray:
	var name := "\"%s\"" % image_name if quoted else image_name
	return ("REM a made-up disc\r\nFILE %s BINARY\r\n  TRACK 01 MODE%d/2352\r\n    INDEX 01 00:00:00\r\n"
		% [name, mode]).to_ascii_buffer()
