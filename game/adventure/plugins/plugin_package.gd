class_name PluginPackage
extends RefCounted
## ADVENTURE PLUGINS — READING ONE PACKAGE (adventure plugins, 2026-11-10;
## the spec's §0.1, §0.10 and §1). A plugin is a `.zip` whose entries all
## sit under one top folder (any name: the id is the manifest's), or an
## unpacked folder with `plugin.json` at its top. Either is read here into
## `{rel_path: bytes}` and NOTHING ELSE: no file of a plugin is ever loaded
## as a resource, run as a script or mounted as a resource pack (a test
## holds this file and the registry's to it). Pictures and music are decoded
## from these bytes later
## ([method AdventurePlugins.texture], [method AdventurePlugins.stream]).
##
## THE CHECKS, in this order; every problem found is listed, and any one
## refuses the plugin ([AdventurePlugins] then reads nothing further):
##  - THE PACKAGE: a zip ≤ [constant MAX_TOTAL] bytes on disk, read from its
##    own central directory before anything is inflated — classic zip only
##    (no zip64, no encryption, stored or deflated entries), no two entries
##    with one name (letter case ignored), no symbolic link, every entry
##    under ONE top folder that holds `plugin.json`. A folder: no symbolic
##    link anywhere in it.
##  - EACH PATH (relative to the top): ≤ [constant MAX_PATH] characters, no
##    `..` or `.` part, not absolute, no `\`, `:`, NUL or other control
##    character, no empty part.
##  - EACH FILE'S KIND, by its extension, case ignored: only
##    [constant ALLOWED] — anything else (`.gd`, `.tscn`, `.tres`, `.pck`,
##    `.so`, `.dll`, `.exe`, `.import`, a file with no extension…) refuses the
##    plugin, naming the file.
##  - THE LIMITS: ≤ [constant MAX_FILES] files and ≤ [constant MAX_TOTAL]
##    bytes in all; a JSON, `.txt` or `.md` file ≤ [constant MAX_JSON]; an
##    OGG ≤ [constant MAX_OGG]; a picture's header names its kind as its
##    extension does and ≤ [constant MAX_SIDE] pixels a side; an OGG is Ogg
##    Vorbis by its first page.
##  - IGNORED, never read nor counted: the litter other systems leave — any
##    file or folder whose name begins with `.`, a `__MACOSX` folder,
##    `Thumbs.db` and `desktop.ini` (case ignored). [QoL: a plugin zipped on
##    a Mac or browsed on Windows is not refused for what the system added.]
## The plugin tool (`tools/adventure_plugin.py validate`) applies the same
## rules in the same order.

## The kinds of file a plugin may hold, by extension (lower case).
const ALLOWED: Array[String] = ["json", "txt", "md", "png", "jpg", "jpeg", "webp", "ogg"]
const PICTURES: Array[String] = ["png", "jpg", "jpeg", "webp"]
const TEXTS: Array[String] = ["json", "txt", "md"]
## The limits of §0.10.
const MAX_TOTAL := 32 * 1024 * 1024
const MAX_FILES := 512
const MAX_JSON := 1024 * 1024
const MAX_OGG := 16 * 1024 * 1024
const MAX_SIDE := 4096
const MAX_PATH := 200
const MAX_DEPTH := 32
## Folders walked in an unpacked plugin before the walk gives up.
const MAX_FOLDERS := 256
## The manifest, at the top of every plugin.
const MANIFEST := "plugin.json"
## Litter left by other systems, ignored (lower case).
const LITTER: Array[String] = ["thumbs.db", "desktop.ini"]
const LITTER_FOLDER := "__macosx"


## Read the plugin at [param path] (a `.zip` file or a folder). Returns
## `{files: {rel: PackedByteArray}, problems: Array[String], kind: "zip" or
## "folder", top: the zip's top folder ("" for a folder)}`; any problem
## refuses the plugin. `files` holds what could be read within the limits
## even then (the manifest shown in a refused plugin's row), never more.
static func read(path: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(path):
		return _read_folder(path)
	if path.get_extension().to_lower() == "zip" and FileAccess.file_exists(path):
		return _read_zip(path)
	var out := _empty("folder")
	out["problems"] = ["%s: not a .zip file or a folder." % path.get_file()]
	return out


static func _empty(kind: String) -> Dictionary:
	var problems: Array[String] = []
	return {"files": {}, "problems": problems, "kind": kind, "top": ""}


# ------------------------------------------------------------------ paths --

## Whether a path's part [param name] is litter ([constant LITTER]).
static func ignored(name: String) -> bool:
	var lower := name.to_lower()
	return (name.begins_with(".") and name != "." and name != "..") or lower == LITTER_FOLDER or lower in LITTER


## Why [param rel] (a path inside the plugin, `/`-separated) is not a path a
## plugin may hold, "" when it is.
static func path_problem(rel: String) -> String:
	if rel.length() > MAX_PATH:
		return "%s: the path is longer than %d characters." % [rel.left(60) + "...", MAX_PATH]
	if rel.begins_with("/") or rel.contains("\\") or rel.contains(":"):
		return "%s: the path must be relative and use / only (no \\ or :)." % rel
	for character in rel:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127:
			return "%s: the path holds a control character." % rel.c_escape()
	for part in rel.split("/"):
		if part == "" or part == "." or part == "..":
			return "%s: the path has an empty, . or .. part." % rel
	return ""


## Why the file [param rel] is not a kind a plugin may hold, "" when it is.
static func kind_problem(rel: String) -> String:
	var extension := rel.get_extension().to_lower()
	if extension in ALLOWED:
		return ""
	return "%s: this kind of file is not allowed in a plugin (only %s)." % [rel,
		" ".join(ALLOWED.map(func(e: String) -> String: return "." + e))]


## Why a file [param rel] of [param size] bytes is too big, "" when it is not.
static func size_problem(rel: String, size: int) -> String:
	var extension := rel.get_extension().to_lower()
	if extension in TEXTS and size > MAX_JSON:
		return "%s: %s is bigger than the 1 MiB a text or JSON file may be." % [rel, _bytes(size)]
	if extension == "ogg" and size > MAX_OGG:
		return "%s: %s is bigger than the 16 MiB a music file may be." % [rel, _bytes(size)]
	return ""


static func _bytes(size: int) -> String:
	if size >= 1024 * 1024:
		return "%.1f MiB" % (size / 1048576.0)
	return "%d bytes" % size


# ------------------------------------------------------------ the content --

## Why the bytes of [param rel] are not what its extension says, "" when
## they are: a picture's header (its kind and ≤ [constant MAX_SIDE] pixels a
## side), an OGG's first page (Vorbis), a text file's UTF-8.
static func content_problem(rel: String, bytes: PackedByteArray) -> String:
	var extension := rel.get_extension().to_lower()
	if extension in PICTURES:
		var size := picture_size(bytes)
		var wanted := "jpg" if extension == "jpeg" else extension
		if size.x <= 0 or picture_kind(bytes) != wanted:
			return "%s: not a %s picture (its first bytes say otherwise)." % [rel, extension.to_upper()]
		if size.x > MAX_SIDE or size.y > MAX_SIDE:
			return "%s: the picture is %d x %d pixels; %d is the most a side may be." % [rel, size.x, size.y, MAX_SIDE]
		return ""
	if extension == "ogg":
		return "" if is_vorbis(bytes) else "%s: not Ogg Vorbis music." % rel
	if extension in TEXTS and not is_utf8(bytes):
		return "%s: the text is not UTF-8." % rel
	return ""


## "png", "jpg" or "webp" by the first bytes of [param bytes], "" for none.
static func picture_kind(bytes: PackedByteArray) -> String:
	if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]):
		return "png"
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		return "jpg"
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" \
			and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return "webp"
	return ""


## A picture's size in pixels from its header alone (nothing decoded);
## (0, 0) when the header is not one this reads.
static func picture_size(bytes: PackedByteArray) -> Vector2i:
	match picture_kind(bytes):
		"png":
			if bytes.size() < 24 or bytes.slice(12, 16).get_string_from_ascii() != "IHDR":
				return Vector2i.ZERO
			return Vector2i(_be32(bytes, 16), _be32(bytes, 20))
		"jpg":
			return _jpeg_size(bytes)
		"webp":
			return _webp_size(bytes)
	return Vector2i.ZERO


static func _be16(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 8) | bytes[at + 1]


static func _be32(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]


## A JPEG's frame size: its markers walked to the first start-of-frame.
static func _jpeg_size(bytes: PackedByteArray) -> Vector2i:
	var at := 2
	while at + 3 < bytes.size():
		if bytes[at] != 0xFF:
			return Vector2i.ZERO
		var marker := bytes[at + 1]
		if marker == 0xFF:
			at += 1
			continue
		if marker == 0xD8 or marker == 0x01 or (marker >= 0xD0 and marker <= 0xD7):
			at += 2
			continue
		if marker == 0xD9 or marker == 0xDA:
			return Vector2i.ZERO
		var length := _be16(bytes, at + 2)
		if length < 2:
			return Vector2i.ZERO
		if marker >= 0xC0 and marker <= 0xCF and marker not in [0xC4, 0xC8, 0xCC]:
			if at + 9 > bytes.size():
				return Vector2i.ZERO
			return Vector2i(_be16(bytes, at + 7), _be16(bytes, at + 5))
		at += 2 + length
	return Vector2i.ZERO


## A WebP's canvas: its first chunk, lossy (`VP8 `), lossless (`VP8L`) or
## extended (`VP8X`).
static func _webp_size(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() < 30:
		return Vector2i.ZERO
	match bytes.slice(12, 16).get_string_from_ascii():
		"VP8 ":
			if bytes[23] != 0x9D or bytes[24] != 0x01 or bytes[25] != 0x2A:
				return Vector2i.ZERO
			return Vector2i(bytes.decode_u16(26) & 0x3FFF, bytes.decode_u16(28) & 0x3FFF)
		"VP8L":
			if bytes[20] != 0x2F:
				return Vector2i.ZERO
			var bits := bytes.decode_u32(21)
			return Vector2i((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)
		"VP8X":
			return Vector2i((bytes[24] | (bytes[25] << 8) | (bytes[26] << 16)) + 1,
				(bytes[27] | (bytes[28] << 8) | (bytes[29] << 16)) + 1)
	return Vector2i.ZERO


## Whether [param bytes] begin as Ogg Vorbis: an Ogg page whose first
## packet is Vorbis's identification header.
static func is_vorbis(bytes: PackedByteArray) -> bool:
	if bytes.size() < 28 or bytes.slice(0, 4).get_string_from_ascii() != "OggS":
		return false
	var at := 27 + bytes[26]
	return at + 7 <= bytes.size() and bytes[at] == 0x01 and bytes.slice(at + 1, at + 7).get_string_from_ascii() == "vorbis"


## Whether [param bytes] are UTF-8 — checked here, not by decoding, because
## the engine's decoder prints its complaints. ASCII is told at once (the
## bytes sorted, in the engine); anything else is walked.
static func is_utf8(bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		return true
	var sorted := bytes.duplicate()
	sorted.sort()
	if sorted[sorted.size() - 1] < 0x80:
		return true
	var at := 0
	var size := bytes.size()
	while at < size:
		var lead := bytes[at]
		if lead < 0x80:
			at += 1
			continue
		var more := 0
		var least := 0
		if lead >= 0xC2 and lead <= 0xDF:
			more = 1
			least = 0x80
		elif lead >= 0xE0 and lead <= 0xEF:
			more = 2
			least = 0x800
		elif lead >= 0xF0 and lead <= 0xF4:
			more = 3
			least = 0x10000
		else:
			return false
		if at + more >= size:
			return false
		var code := lead & (0x3F >> more)
		for n in more:
			var next := bytes[at + 1 + n]
			if next & 0xC0 != 0x80:
				return false
			code = (code << 6) | (next & 0x3F)
		if code < least or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF):
			return false
		at += 1 + more
	return true


## A JSON file of the plugin, parsed: `{value, problem}` — the problem ""
## when it parsed. Within the limits (≤ [constant MAX_JSON] bytes, UTF-8, a
## UTF-8 byte-order mark allowed, ≤ [constant MAX_DEPTH] levels deep) and
## without the engine printing a word ([JSON] parsed by an instance). For
## [PluginSchema] too: every content file goes through here.
static func json(rel: String, bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_JSON:
		return {"value": null, "problem": size_problem(rel, bytes.size())}
	if not is_utf8(bytes):
		return {"value": null, "problem": "%s: the text is not UTF-8." % rel}
	var text := bytes.get_string_from_utf8()
	if text.begins_with("﻿"):
		text = text.substr(1)
	var parser := JSON.new()
	if parser.parse(text) != OK:
		# "FILE: line N: MESSAGE", lines counted from 1 as an editor counts
		# them (the engine counts from 0) — the content schema's shape, and
		# the plugin tool's (the lead's ruling).
		return {"value": null, "problem": "%s: line %d: %s" % [rel,
			parser.get_error_line() + 1, parser.get_error_message()]}
	var value: Variant = parser.data
	if depth(value) > MAX_DEPTH:
		return {"value": null, "problem": "%s: nested deeper than %d levels." % [rel, MAX_DEPTH]}
	return {"value": value, "problem": ""}


## How deep [param value] nests: a plain value 0, `[]` or `{}` 1.
static func depth(value: Variant, limit := MAX_DEPTH + 1) -> int:
	if limit <= 0:
		return 0
	if value is Array:
		var most := 0
		for item: Variant in value:
			most = maxi(most, depth(item, limit - 1))
		return most + 1
	if value is Dictionary:
		var most := 0
		for key: Variant in value:
			most = maxi(most, depth(value[key], limit - 1))
		return most + 1
	return 0


## The SHA-256 of [param bytes] in lower-case hex.
static func sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish().hex_encode()


# ------------------------------------------------------------- a folder --

static func _read_folder(path: String) -> Dictionary:
	var out := _empty("folder")
	var problems: Array[String] = out["problems"]
	var found: Array[String] = []
	var folders := 0
	var pending: Array[String] = [""]
	while not pending.is_empty():
		var under: String = pending.pop_front()
		folders += 1
		if folders > MAX_FOLDERS:
			problems.append("The plugin holds more than %d folders." % MAX_FOLDERS)
			break
		var dir := DirAccess.open(path.path_join(under) if under != "" else path)
		if dir == null:
			problems.append("%s: the folder could not be read." % (under if under != "" else path.get_file()))
			continue
		dir.include_hidden = true
		dir.include_navigational = false
		var names: Array[String] = []
		names.assign(dir.get_directories())
		names.sort()
		for name in names:
			if ignored(name):
				continue
			var rel := under.path_join(name) if under != "" else name
			if dir.is_link(name):
				problems.append("%s: a symbolic link; a plugin holds only plain files and folders." % rel)
				continue
			pending.append(rel)
		var files: Array[String] = []
		files.assign(dir.get_files())
		files.sort()
		for name in files:
			if ignored(name):
				continue
			var rel := under.path_join(name) if under != "" else name
			if dir.is_link(name):
				problems.append("%s: a symbolic link; a plugin holds only plain files and folders." % rel)
				continue
			found.append(rel)
		if found.size() > MAX_FILES:
			break
	if found.size() > MAX_FILES:
		problems.append("The plugin holds more than %d files." % MAX_FILES)
		return out
	if not MANIFEST in found:
		problems.append("%s is missing from the plugin's top folder." % MANIFEST)
	var total := 0
	for rel in found:
		var problem := path_problem(rel)
		if problem == "":
			problem = kind_problem(rel)
		if problem != "":
			problems.append(problem)
			continue
		var file := FileAccess.open(path.path_join(rel), FileAccess.READ)
		if file == null:
			problems.append("%s: the file could not be read." % rel)
			continue
		var size := file.get_length()
		total += size
		if total > MAX_TOTAL:
			problems.append("The plugin is bigger than 32 MiB.")
			return out
		problem = size_problem(rel, size)
		if problem != "":
			problems.append(problem)
			continue
		_take(out, rel, file.get_buffer(size))
	return out


## [param bytes] of [param rel] checked ([method content_problem]) and kept.
static func _take(out: Dictionary, rel: String, bytes: PackedByteArray) -> void:
	var problem := content_problem(rel, bytes)
	if problem != "":
		(out["problems"] as Array[String]).append(problem)
		return
	(out["files"] as Dictionary)[rel] = bytes


# ---------------------------------------------------------------- a zip --

## The entries of the zip at [param path] by its central directory, read
## before anything is inflated: `{entries: [{name, size, method, flags,
## link}], problem}`. Classic zip only: an end record within the file's
## last 64 KiB, its directory whole and reaching it.
static func zip_entries(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"entries": [], "problem": "%s: the zip could not be opened." % path.get_file()}
	var length := file.get_length()
	if length > MAX_TOTAL:
		return {"entries": [], "problem": "%s is bigger than 32 MiB." % path.get_file()}
	if length < 22:
		return {"entries": [], "problem": "%s is not a whole zip." % path.get_file()}
	var tail_size := mini(65557, length)
	file.seek(length - tail_size)
	var tail := file.get_buffer(tail_size)
	var end := tail.size() - 22
	while end >= 0:
		if tail.decode_u32(end) == 0x06054b50 and end + 22 + tail.decode_u16(end + 20) == tail.size():
			break
		end -= 1
	if end < 0:
		return {"entries": [], "problem": "%s is not a whole zip (its list of files is missing)." % path.get_file()}
	var count := tail.decode_u16(end + 10)
	var directory_size := tail.decode_u32(end + 12)
	var offset := tail.decode_u32(end + 16)
	var directory_end := length - tail_size + end
	if count == 0xFFFF or offset == 0xFFFFFFFF or offset + directory_size != directory_end:
		return {"entries": [], "problem": "%s: a zip64 or damaged zip; save it as a plain zip." % path.get_file()}
	file.seek(offset)
	var directory := file.get_buffer(directory_size)
	var entries: Array[Dictionary] = []
	var at := 0
	for n in count:
		if at + 46 > directory.size() or directory.decode_u32(at) != 0x02014b50:
			return {"entries": [], "problem": "%s is damaged (its list of files)." % path.get_file()}
		var made_by := directory.decode_u16(at + 4)
		var flags := directory.decode_u16(at + 8)
		var method := directory.decode_u16(at + 10)
		var packed := directory.decode_u32(at + 20)
		var size := directory.decode_u32(at + 24)
		var name_length := directory.decode_u16(at + 28)
		var skip := name_length + directory.decode_u16(at + 30) + directory.decode_u16(at + 32)
		var external := directory.decode_u32(at + 38)
		if at + 46 + skip > directory.size():
			return {"entries": [], "problem": "%s is damaged (its list of files)." % path.get_file()}
		var raw := directory.slice(at + 46, at + 46 + name_length)
		var name := raw.get_string_from_utf8() if is_utf8(raw) else ""
		# Unix's file kind rides in the attributes' high half: 0xA000 (octal
		# 120000) of the 0xF000 mask a symbolic link.
		var link := (made_by >> 8) == 3 and ((external >> 16) & 0xF000) == 0xA000
		entries.append({"name": name, "raw": raw, "size": size, "packed": packed, "method": method,
			"flags": flags, "link": link})
		at += 46 + skip
		if entries.size() > MAX_FILES + MAX_FOLDERS:
			return {"entries": [], "problem": "%s holds more than %d files." % [path.get_file(), MAX_FILES]}
	return {"entries": entries, "problem": ""}


static func _read_zip(path: String) -> Dictionary:
	var out := _empty("zip")
	var problems: Array[String] = out["problems"]
	var listed := zip_entries(path)
	if String(listed["problem"]) != "":
		problems.append(String(listed["problem"]))
		return out
	# The entries kept, by their place under the top folder.
	var keep: Array[Dictionary] = []
	var tops := {}
	var seen := {}
	var total := 0
	for entry: Dictionary in listed["entries"]:
		var name := String(entry["name"])
		if name == "":
			problems.append("An entry's name is not UTF-8 (%s)." % (entry["raw"] as PackedByteArray).hex_encode().left(40))
			continue
		var problem := path_problem(name.trim_suffix("/"))
		if problem != "":
			problems.append(problem)
			continue
		var parts := name.split("/")
		var litter := false
		for part in parts:
			if part != "" and ignored(part):
				litter = true
		if litter:
			continue
		if name.ends_with("/") and not bool(entry["link"]):
			continue   # a folder's own entry
		if bool(entry["link"]):
			problems.append("%s: a symbolic link; a plugin holds only plain files and folders." % name)
			continue
		if int(entry["flags"]) & 1 != 0:
			problems.append("%s: encrypted; a plugin's zip is never locked." % name)
			continue
		if int(entry["method"]) not in [0, 8]:
			problems.append("%s: packed in a way this game does not read (only stored or deflated)." % name)
			continue
		var lower := name.to_lower()
		if seen.has(lower):
			problems.append("%s: two entries have this name." % name)
			continue
		seen[lower] = true
		if parts.size() < 2:
			problems.append("%s: every file of a plugin's zip goes inside one top folder." % name)
			continue
		tops[parts[0]] = true
		var rel := name.substr(parts[0].length() + 1)
		problem = kind_problem(rel)
		if problem != "":
			problems.append(problem)
			continue
		total += int(entry["size"])
		problem = size_problem(rel, int(entry["size"]))
		if problem != "":
			problems.append(problem)
			continue
		keep.append({"name": name, "rel": rel, "size": int(entry["size"])})
	if tops.size() > 1:
		problems.append("Every file of a plugin's zip goes inside ONE top folder; found %d (%s)." % [tops.size(),
			", ".join(tops.keys().slice(0, 4))])
	if keep.size() > MAX_FILES:
		problems.append("The plugin holds more than %d files." % MAX_FILES)
	if total > MAX_TOTAL:
		problems.append("The plugin is bigger than 32 MiB unpacked.")
	if not keep.any(func(row: Dictionary) -> bool: return row["rel"] == MANIFEST):
		problems.append("%s is missing from the plugin's top folder." % MANIFEST)
	if tops.size() == 1:
		out["top"] = String(tops.keys()[0])
	if tops.size() > 1 or keep.size() > MAX_FILES or total > MAX_TOTAL:
		return out
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		problems.append("%s: the zip could not be opened." % path.get_file())
		return out
	for row in keep:
		var bytes := reader.read_file(String(row["name"]))
		if bytes.size() != int(row["size"]):
			problems.append("%s: could not be read whole." % row["rel"])
			continue
		_take(out, String(row["rel"]), bytes)
	reader.close()
	return out


## The bytes of [param rel] in the plugin at [param path] (as [method read]
## found it: [param kind] and the zip's [param top] folder), read again —
## for a picture or a tune wanted after the scan. Empty when it is not there.
static func read_one(path: String, kind: String, top: String, rel: String) -> PackedByteArray:
	if path_problem(rel) != "" or kind_problem(rel) != "":
		return PackedByteArray()
	if kind == "folder":
		if not FileAccess.file_exists(path.path_join(rel)):
			return PackedByteArray()
		return FileAccess.get_file_as_bytes(path.path_join(rel))
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return PackedByteArray()
	var name := top + "/" + rel
	var bytes := reader.read_file(name) if reader.file_exists(name) else PackedByteArray()
	reader.close()
	return bytes
