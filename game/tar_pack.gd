class_name TarPack
extends RefCounted
## A TAR, plain or gzipped, read as a stream and written out as a ZIP.
##
## The engine mounts zips and pcks and nothing else
## (`ProjectSettings.load_resource_pack`), and a Linux hand reaches for
## tar.gz — the owner: *"Can we use also tar.gz not only zip? As an
## alternative for card packs and original skin file?"* So a tar that
## arrives at any of the skin's doors ([method SkinPack.adopt], the
## browser's chooser) is repacked ONCE into a zip of the same name in
## the folder the zip would have gone to, and from there it is a zip
## like any other: mounted in place, listed in its row, deleted from
## its folder. [QoL] — the 1997 game had no packs at all.
##
## The tar is never held whole. [const CHUNK] bytes of it go in per
## [method step] — through [StreamPeerGZIP] when the file is gzipped —
## and every entry that comes out the far side is written to the zip as
## it comes, a slice at a time, through [ZIPPacker]: a 200 MB card pack
## costs one chunk in memory, not the pack. The steps are the caller's
## to pace (one a frame keeps a screen alive; a loop finishes in one
## go — [method convert]).
##
## What is understood: ustar and GNU headers, `./` at the front of a
## name dropped, GNU long names (`L`) and pax `path` records (`x`),
## directories skipped, anything else (links, devices) left out with
## its data. Sizes are the octal field; a pack over 8 GB is nobody's.
## What the entries are allowed to be named is not judged here — the
## zip is inspected afterwards exactly as a chosen zip is
## ([method SkinPack.inspect]), so a tar with a file outside `skin/`
## is refused by the same words.

## Bytes read from the tar per step.
const CHUNK := 4 << 20
const BLOCK := 512
## Entry types: a regular file (two spellings), a directory, a GNU long
## name, a pax extended header.
const TYPE_FILE := "0"
const TYPE_FILE_OLD := ""
const TYPE_DIR := "5"
const TYPE_LONG_NAME := "L"
const TYPE_PAX := "x"
## The tails a tar goes by.
const TAILS := [".tar.gz", ".tgz", ".tar"]

var source := ""
var dest := ""
## Set once [method step] has nothing more to do; [member ok] says how
## it ended, [member why] in words when it did not.
var done := false
var ok := false
var why := ""
## Entries written to the zip so far.
var files := 0

var _in: FileAccess = null
var _size := 0
var _gz: StreamPeerGZIP = null
var _out: ZIPPacker = null
## Decompressed bytes not yet consumed, and the read point in them.
var _buf := PackedByteArray()
var _off := 0
## The entry being copied: bytes of its body still to come, then the
## block padding after it; whether the body goes to the zip, or is a
## name for the next entry (`L`/`x`) gathered in [member _meta].
var _remaining := 0
var _pad := 0
var _writing := false
var _meta_type := ""
var _meta := PackedByteArray()
## A name handed down by an `L` or `x` entry for the entry after it.
var _next_name := ""
var _input_over := false


## Whether the file at [param path] is a tar — gzipped (the two magic
## bytes) or plain (`ustar` at 257) — by content, never by name.
static func is_tar(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var head := f.get_buffer(2)
	if head.size() == 2 and head[0] == 0x1f and head[1] == 0x8b:
		f.close()
		return true
	f.seek(257)
	var magic := f.get_buffer(5)
	f.close()
	return magic.get_string_from_ascii() == "ustar"


## The name the zip takes: `x.tar.gz`, `x.tgz`, `x.tar` → `x.zip`. Any
## other name is left as it is.
static func zip_name(name: String) -> String:
	var lower := name.to_lower()
	for tail in TAILS:
		if lower.ends_with(tail):
			return name.substr(0, name.length() - tail.length()) + ".zip"
	return name


## Whether [param name] says tar — the doors take such a file in and,
## when its bytes are no tar ([method is_tar]), say so rather than
## ignore it.
static func is_tar_name(name: String) -> bool:
	var lower := name.to_lower()
	for tail in TAILS:
		if lower.ends_with(tail):
			return true
	return false


## Start reading [param from] and writing [param to]. False, with
## [member why] set, when either cannot be opened.
func open(from: String, to: String) -> bool:
	source = from
	dest = to
	_in = FileAccess.open(from, FileAccess.READ)
	if _in == null:
		return _fail("could not be read")
	_size = _in.get_length()
	var head := _in.get_buffer(2)
	_in.seek(0)
	if head.size() == 2 and head[0] == 0x1f and head[1] == 0x8b:
		_gz = StreamPeerGZIP.new()
		if _gz.start_decompression(false, CHUNK) != OK:
			return _fail("could not be decompressed")
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	_out = ZIPPacker.new()
	# Fast, not small: the zip is a mount the game reads in place, and
	# what a tar carries is pictures and sound that deflate barely
	# touches — the wait is what the player notices.
	_out.compression_level = ZIPPacker.COMPRESSION_FAST
	if _out.open(to) != OK:
		return _fail("could not be written into the game's folder")
	return true


## How far the tar has been read, 0..1.
func progress() -> float:
	if _in == null or _size <= 0:
		return 0.0
	return clampf(float(_in.get_position()) / float(_size), 0.0, 1.0)


## One chunk in, every whole entry it completes out. True while there
## is more to do; false once [member done].
func step() -> bool:
	if done:
		return false
	if not _input_over:
		var raw := _in.get_buffer(CHUNK)
		if _in.get_position() >= _size or raw.is_empty():
			_input_over = true
		if _gz == null:
			_buf.append_array(raw)
			if not _consume():
				return false
		elif not _inflate(raw):
			return false
	elif not _consume():
		return false
	if _input_over and not done:
		if _remaining > 0 or _pad > 0:
			_finish(false, "ends before its last file does")
		else:
			_finish(files > 0, "" if files > 0 else "holds no files")
	return not done


## A chunk of the gzipped tar through the inflater. Its ring buffer is
## [const CHUNK] wide, and a chunk of compressed bytes may come out
## many times wider (a tar of small files is mostly zero blocks), so
## the chunk goes in as much at a time as the buffer has room for
## (`put_partial_data`), and what comes out is consumed between the
## puts — the buffer never has to hold a whole chunk's worth of output.
## False once the job is over, done or failed.
func _inflate(raw: PackedByteArray) -> bool:
	var at := 0
	while at < raw.size():
		var put: Array = _gz.put_partial_data(raw.slice(at) if at > 0 else raw)
		if put[0] != OK:
			return _finish(false, "is not a gzip file the game can read")
		var sent := int(put[1])
		var available := _gz.get_available_bytes()
		if sent <= 0 and available <= 0:
			return _finish(false, "is not a gzip file the game can read")
		at += sent
		if available > 0:
			var got: Array = _gz.get_data(available)
			if got[0] != OK:
				return _finish(false, "is not a gzip file the game can read")
			_buf.append_array(got[1])
		if not _consume():
			return false
	return true


## Run to the end in one go; the report a caller wants when nothing
## is on screen to keep alive.
static func convert(from: String, to: String) -> Dictionary:
	var job := TarPack.new()
	if job.open(from, to):
		while job.step():
			pass
	return {"ok": job.ok, "files": job.files, "why": job.why}


## Work through [member _buf]: the open entry's body first, then as
## many whole headers (and the bodies they promise) as are in hand.
func _consume() -> bool:
	while true:
		if _remaining > 0 or _pad > 0:
			var have := _buf.size() - _off
			if have <= 0:
				break
			if _remaining > 0:
				var take := mini(_remaining, have)
				var slice := _buf.slice(_off, _off + take)
				if _writing:
					if _out.write_file(slice) != OK:
						return _finish(false, "could not be written into the game's folder")
				elif _meta_type != "":
					_meta.append_array(slice)
				_off += take
				_remaining -= take
				if _remaining > 0:
					break
				_entry_over()
				continue
			var skip := mini(_pad, have)
			_off += skip
			_pad -= skip
			if _pad > 0:
				break
			continue
		if _buf.size() - _off < BLOCK:
			break
		var header := _buf.slice(_off, _off + BLOCK)
		_off += BLOCK
		if _is_zero(header):
			_finish(files > 0, "" if files > 0 else "holds no files")
			return false
		if not _begin_entry(header):
			return false
	if _off > 0:
		_buf = _buf.slice(_off)
		_off = 0
	return true


## Read one header and decide what its body is for.
func _begin_entry(header: PackedByteArray) -> bool:
	var size := _octal(header.slice(124, 136))
	if size < 0:
		return _finish(false, "has a header the game cannot read")
	var type := header.slice(156, 157).get_string_from_ascii()
	var name := _field(header, 0, 100)
	var prefix := _field(header, 345, 155)
	if header.slice(257, 262).get_string_from_ascii() == "ustar" and prefix != "":
		name = prefix + "/" + name
	if _next_name != "":
		name = _next_name
		_next_name = ""
	_remaining = size
	_pad = (BLOCK - size % BLOCK) % BLOCK
	_writing = false
	_meta_type = ""
	_meta = PackedByteArray()
	match type:
		TYPE_FILE, TYPE_FILE_OLD:
			name = _tidy(name)
			if name != "" and not name.ends_with("/"):
				if _out.start_file(name) != OK:
					return _finish(false, "could not be written into the game's folder")
				_writing = true
				files += 1
			# else a directory in the old spelling: skipped with its body
		TYPE_LONG_NAME, TYPE_PAX:
			_meta_type = type
		_:
			pass   # a directory, a link, a device: skipped with its body
	if size == 0:
		_entry_over()
	return true


## The open entry's body is all in: close the zip's file, or keep the
## name an `L`/`x` entry carried for the one after it.
func _entry_over() -> void:
	if _writing:
		_out.close_file()
		_writing = false
	elif _meta_type == TYPE_LONG_NAME:
		_next_name = _meta.get_string_from_utf8()
	elif _meta_type == TYPE_PAX:
		for line in _meta.get_string_from_utf8().split("\n"):
			# "<len> path=<name>"
			var at := line.find(" path=")
			if at >= 0:
				_next_name = line.substr(at + 6)
	_meta_type = ""
	_meta = PackedByteArray()


## An entry's name as the zip should carry it: `./` and `/` at the
## front dropped, backslashes as the separators they were meant as.
static func _tidy(name: String) -> String:
	var out := name.replace("\\", "/")
	while out.begins_with("./"):
		out = out.substr(2)
	while out.begins_with("/"):
		out = out.substr(1)
	return out


## A NUL-terminated text field of the header.
static func _field(header: PackedByteArray, at: int, length: int) -> String:
	var raw := header.slice(at, at + length)
	var end := raw.find(0)
	if end >= 0:
		raw = raw.slice(0, end)
	return raw.get_string_from_utf8()


## The octal size field: digits up to the first NUL or space; -1 when
## it is not octal (a base-256 size, for a file over 8 GB).
static func _octal(raw: PackedByteArray) -> int:
	if raw.size() > 0 and raw[0] & 0x80:
		return -1
	var value := 0
	var seen := false
	for b in raw:
		if b == 0 or b == 0x20:
			if seen:
				break
			continue
		if b < 0x30 or b > 0x37:
			return -1
		value = value * 8 + (b - 0x30)
		seen = true
	return value


static func _is_zero(block: PackedByteArray) -> bool:
	for b in block:
		if b != 0:
			return false
	return true


func _fail(reason: String) -> bool:
	return _finish(false, reason)


## The end, either way: the zip closed (and deleted when the tar was
## bad — a half zip in the folder would be mounted at the next start).
func _finish(succeeded: bool, reason: String) -> bool:
	if done:
		return false
	done = true
	ok = succeeded
	why = reason
	if _out != null:
		if _writing:
			_out.close_file()
			_writing = false
		_out.close()
		_out = null
	if _in != null:
		_in.close()
		_in = null
	_gz = null
	_buf = PackedByteArray()
	_off = 0
	if not ok and dest != "" and FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	return false
