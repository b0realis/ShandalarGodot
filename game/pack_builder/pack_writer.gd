class_name PackWriter
extends RefCounted
## ONE PACK'S ZIP, WRITTEN AND CHECKED A FEW ENTRIES A FRAME — the `build`
## and `verify` of `tools/pack_N_*.py` (and `mtg_assets.py --from-cardart`
## for the 1997 pictures), with the engine alone.
##
## THE ZIP IS WRITTEN HERE, NOT BY [ZIPPacker]: the engine's packer adds an
## entry for every folder a file is the first in, and a pack's contract
## lists its entries exactly — a folder entry is one too many and the pack
## is refused. A zip is a short format: each entry a header and its
## deflated bytes, then the table of them all. The deflating is the
## engine's ([method PackedByteArray.compress] as gzip, whose stream is a
## zip entry's own between a ten-byte head and a tail that holds the
## CRC-32 the zip header wants), so no byte of it is computed in script.
##
## It is given a recipe ([PackRecipes]), the cache its pictures are in
## ([PackFetch]) and a folder to work in, and is stepped once a frame
## ([method step]) until [member state] is "done" or "failed":
##
##   writing    every picture into `<folder>/<file name>.part`, stored as
##              downloaded (no re-encoding), its SHA-256 taken on the way;
##              then, for a numbered pack, the manifest with the checksums
##              the Python tools write — `metadata` over catalog.json,
##              cards.json and README.txt, `artwork` over the sorted lines
##              `name + NUL + sha256 + newline` — and those three files,
##              byte for byte what the Python tools write ([PackJson]).
##   checking   the finished zip takes its exact name, still in the work
##              folder, and is read back: every picture inflated out of the
##              file and its SHA-256 compared with the one taken while
##              writing, a few a frame; then the game's own check of that
##              kind of zip is asked ([member judge] — the pack's contract,
##              or the art-zip rule), and only its yes makes "done".
##
## Nothing is ever written where the game looks for packs: [member path]
## is the checked zip in the work folder, and putting it in place is the
## caller's one rename ([PackBuild]). [method abandon] at any moment leaves
## no file behind.
##
## A picture in the cache that is not a whole JPEG is deleted and the pack
## fails with "missing": the next run fetches it again.

const PART := ".part"
## Local file header and central directory record: sizes and signatures.
const LOCAL_SIGNATURE := 0x04034B50
const CENTRAL_SIGNATURE := 0x02014B50
const END_SIGNATURE := 0x06054B50
## Bit 11: the names are UTF-8.
const UTF8_NAMES := 0x0800
## 1 January 1980, as a zip writes a date.
const DATE_1980 := 0x0021
## An ordinary file, rw-r--r-- (octal 100644).
const FILE_MODE := 0x81A4

enum {WRITE, CLOSE, INDEX, READ_BACK, JUDGE}

## "idle", "writing", "checking", "done" or "failed".
var state := "idle"
## Why it failed — "disk", "missing" or "refused" — and in words.
var problem := ""
var problem_text := ""
## Entries written (while writing) or read back (while checking), of how many.
var done := 0
var total := 0
## The checked zip, under its exact name in the work folder, once "done".
var path := ""
## The game's own check of the finished zip: `func(path) -> {ok, why}`.
var judge := Callable()

var _recipe := {}
var _cache := ""
var _folder := ""
var _stage := WRITE
var _out: FileAccess = null
var _central := PackedByteArray()
var _count := 0
var _at := 0
var _art: Array = []          # [name in the zip, sha256 hex]
var _sums := {}               # cache file -> sha256 hex
var _last_file := ""
var _last_payload := PackedByteArray()
var _bytes := 0
var _file: FileAccess = null
var _index := {}              # name -> [local header at, method, crc, packed, unpacked]


## Begin writing [param recipe] from [param cache] in [param folder].
func start(recipe: Dictionary, cache: String, folder: String) -> void:
	_recipe = recipe
	_cache = cache
	_folder = folder
	_at = 0
	_art.clear()
	_sums.clear()
	_index.clear()
	_last_file = ""
	_last_payload = PackedByteArray()
	_bytes = 0
	done = 0
	total = (recipe["entries"] as Array).size()
	problem = ""
	problem_text = ""
	path = ""
	DirAccess.make_dir_recursive_absolute(folder)
	_clear()
	_central = PackedByteArray()
	_count = 0
	_out = FileAccess.open(_part(), FileAccess.WRITE)
	if _out == null:
		_fail("disk", "The pack could not be written in %s." % GamePaths.shown(folder))
		return
	_stage = WRITE
	state = "writing"


## One frame's worth, for about [param budget_usec]. True while there is
## more to do.
func step(budget_usec := 6000) -> bool:
	if state != "writing" and state != "checking":
		return false
	var started := Time.get_ticks_usec()
	while state == "writing" or state == "checking":
		match _stage:
			WRITE:
				_write_one()
			CLOSE:
				_close()
			INDEX:
				_read_index()
			READ_BACK:
				_read_one_back()
			JUDGE:
				_judge()
		if Time.get_ticks_usec() - started >= budget_usec:
			break
	return state == "writing" or state == "checking"


## Stop and leave nothing behind: the part and the finished zip both go.
func abandon() -> void:
	if _out != null:
		_out.close()
		_out = null
	if _file != null:
		_file.close()
		_file = null
	_clear()
	if state == "writing" or state == "checking":
		state = "idle"


## The artwork digest of the pack tools: SHA-256 over, for each picture in
## name order, `name`, a zero byte, the picture's own SHA-256 in hex and a
## newline. [param entries] are `[name, sha256 hex]`.
static func artwork_sha256(entries: Array) -> String:
	var ordered := entries.duplicate()
	ordered.sort_custom(func(a: Array, b: Array) -> bool:
		return PackJson.less(String(a[0]), String(b[0])))
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for entry: Array in ordered:
		hashing.update(String(entry[0]).to_utf8_buffer())
		hashing.update(PackedByteArray([0]))
		hashing.update(String(entry[1]).to_utf8_buffer())
		hashing.update("\n".to_utf8_buffer())
	return hashing.finish().hex_encode()


static func sha256(payload: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	if not payload.is_empty():
		hashing.update(payload)
	return hashing.finish().hex_encode()


# ------------------------------------------------------------- writing --

func _part() -> String:
	return _final() + PART


func _final() -> String:
	return _folder.path_join(String(_recipe["file_name"]))


func _clear() -> void:
	for file: String in [_part(), _final()]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


func _write_one() -> void:
	var entries: Array = _recipe["entries"]
	if _at >= entries.size():
		_stage = CLOSE
		return
	var entry: Array = entries[_at]
	var name := String(entry[0])
	var cached := String(entry[1])
	if cached != _last_file:
		var from := _cache.path_join(cached)
		_last_payload = FileAccess.get_file_as_bytes(from) if FileAccess.file_exists(from) \
			else PackedByteArray()
		_last_file = cached
		if not PackFetch.whole_jpeg(_last_payload):
			# Not what was downloaded: gone, so the next run fetches it.
			if FileAccess.file_exists(from):
				DirAccess.remove_absolute(from)
			_fail("missing", "A downloaded picture is missing or damaged (%s). Choose the pack again to fetch it." % cached.get_file())
			return
		if not _sums.has(cached):
			_sums[cached] = sha256(_last_payload)
	_bytes += _last_payload.size()
	var limit := int(_recipe.get("max_bytes", 0))
	if limit > 0 and _bytes > limit:
		_fail("refused", "The pictures are bigger than this pack may be (%d MB)." % (limit >> 20))
		return
	if not _put(name, _last_payload):
		_fail("disk", "The pack could not be written. Is the disk full?")
		return
	_art.append([name, String(_sums[cached])])
	_at += 1
	done = _at


## The metadata last (a zip's order is not part of any pack's contract),
## then the part takes the pack's exact name — still in the work folder.
func _close() -> void:
	var prefix := String(_recipe.get("prefix", ""))
	var ok := true
	if prefix != "":
		var metadata: Dictionary = _recipe["metadata"]
		var sums := {}
		for name: String in metadata:
			sums[name] = sha256(metadata[name])
		var manifest: Dictionary = (_recipe["manifest"] as Dictionary).duplicate(true)
		manifest["checksums"] = {"algorithm": "sha256", "metadata": sums,
			"artwork": {"files": _art.size(), "sha256": artwork_sha256(_art)}}
		var written := PackJson.bytes(manifest)
		ok = not written.is_empty() and _put(prefix + "manifest.json", written)
		for name: String in metadata:
			ok = ok and _put(prefix + name, metadata[name])
	ok = ok and _finish_zip()
	_out.close()
	_out = null
	_last_payload = PackedByteArray()
	if not ok or DirAccess.rename_absolute(_part(), _final()) != OK:
		_fail("disk", "The pack could not be written. Is the disk full?")
		return
	done = 0
	_stage = INDEX
	state = "checking"


## One entry: its header, its name, its bytes deflated — and its line for
## the table, kept until the end. Dated 1 January 1980 and marked an
## ordinary file (rw-r--r--), as the Python tools write theirs.
func _put(name: String, payload: PackedByteArray) -> bool:
	var packed := deflated(payload)
	if packed.is_empty() or _count >= 0xFFFF:
		return false
	var crc: int = packed[0]
	var data: PackedByteArray = packed[1]
	var name_bytes := name.to_utf8_buffer()
	var at := _out.get_position()
	if at + data.size() + name_bytes.size() + 30 > 0xFFFFFFFF:
		return false
	var local := PackedByteArray()
	local.resize(30)
	local.encode_u32(0, LOCAL_SIGNATURE)
	local.encode_u16(4, 20)                 # version needed: deflate
	local.encode_u16(6, UTF8_NAMES)
	local.encode_u16(8, 8)                  # method: deflate
	local.encode_u16(10, 0)                 # 00:00:00
	local.encode_u16(12, DATE_1980)
	local.encode_u32(14, crc)
	local.encode_u32(18, data.size())
	local.encode_u32(22, payload.size())
	local.encode_u16(26, name_bytes.size())
	local.encode_u16(28, 0)
	local.append_array(name_bytes)
	if not _out.store_buffer(local) or not _out.store_buffer(data) or _out.get_error() != OK:
		return false
	var line := PackedByteArray()
	line.resize(46)
	line.encode_u32(0, CENTRAL_SIGNATURE)
	line.encode_u16(4, (3 << 8) | 20)       # made on Unix, version 2.0
	line.encode_u16(6, 20)
	line.encode_u16(8, UTF8_NAMES)
	line.encode_u16(10, 8)
	line.encode_u16(12, 0)
	line.encode_u16(14, DATE_1980)
	line.encode_u32(16, crc)
	line.encode_u32(20, data.size())
	line.encode_u32(24, payload.size())
	line.encode_u16(28, name_bytes.size())
	line.encode_u32(38, FILE_MODE << 16)
	line.encode_u32(42, at)
	line.append_array(name_bytes)
	_central.append_array(line)
	_count += 1
	return true


## The table of entries and the record that ends a zip.
func _finish_zip() -> bool:
	var at := _out.get_position()
	if at + _central.size() + 22 > 0xFFFFFFFF:
		return false
	var end := PackedByteArray()
	end.resize(22)
	end.encode_u32(0, END_SIGNATURE)
	end.encode_u16(8, _count)
	end.encode_u16(10, _count)
	end.encode_u32(12, _central.size())
	end.encode_u32(16, at)
	var ok := (_central.is_empty() or _out.store_buffer(_central)) and _out.store_buffer(end)
	_out.flush()
	return ok and _out.get_error() == OK


## [param payload] as a zip entry holds it: `[its CRC-32, its bytes as a raw
## deflate stream]`, or nothing when the engine would not compress it. The
## engine writes gzip — a head, that same stream, then the CRC-32 and the
## length — so the head and the tail are cut off and the CRC read.
static func deflated(payload: PackedByteArray) -> Array:
	if payload.is_empty():
		# An empty stream: one final, empty stored block.
		return [0, PackedByteArray([0x03, 0x00])]
	var gzip := payload.compress(FileAccess.COMPRESSION_GZIP)
	if gzip.size() < 18 or gzip[0] != 0x1F or gzip[1] != 0x8B or gzip[2] != 8:
		return []
	var flags := gzip[3]
	var from := 10
	if flags & 4 != 0:                         # an extra field
		from += 2 + gzip.decode_u16(from)
	for bit: int in [8, 16]:                 # a file name, a comment
		if flags & bit != 0:
			while from < gzip.size() and gzip[from] != 0:
				from += 1
			from += 1
	if flags & 2 != 0:                         # a header checksum
		from += 2
	var to := gzip.size() - 8
	if from >= to or gzip.decode_u32(to + 4) != payload.size():
		return []
	return [gzip.decode_u32(to), gzip.slice(from, to)]


# ------------------------------------------------------------ checking --

## The finished zip's own table: where each entry lies and what it says of
## itself. A table that does not list exactly what was written is refused.
func _read_index() -> void:
	_file = FileAccess.open(_final(), FileAccess.READ)
	if _file == null:
		_fail("disk", "The finished pack could not be read back.")
		return
	var size := _file.get_length()
	var tail_size := mini(size, 22 + 65535)
	_file.seek(size - tail_size)
	var tail := _file.get_buffer(tail_size)
	var at := tail.size() - 22
	while at >= 0 and tail.decode_u32(at) != END_SIGNATURE:
		at -= 1
	if at < 0:
		_fail("refused", "The finished pack is not a whole zip.")
		return
	var count := tail.decode_u16(at + 10)
	var directory_size := tail.decode_u32(at + 12)
	var directory_at := tail.decode_u32(at + 16)
	var wanted := _art.size() + (4 if String(_recipe.get("prefix", "")) != "" else 0)
	if count != wanted or directory_at + directory_size > size:
		_fail("refused", "The finished pack does not hold what was written.")
		return
	_file.seek(directory_at)
	var directory := _file.get_buffer(directory_size)
	var p := 0
	for i in count:
		if p + 46 > directory.size() or directory.decode_u32(p) != CENTRAL_SIGNATURE:
			_fail("refused", "The finished pack is not a whole zip.")
			return
		var name_size := directory.decode_u16(p + 28)
		var name := directory.slice(p + 46, p + 46 + name_size).get_string_from_utf8()
		_index[name] = [directory.decode_u32(p + 42), directory.decode_u16(p + 10),
			directory.decode_u32(p + 16), directory.decode_u32(p + 20), directory.decode_u32(p + 24)]
		p += 46 + name_size + directory.decode_u16(p + 30) + directory.decode_u16(p + 32)
	if _index.size() != count:
		_fail("refused", "The finished pack lists an entry twice.")
		return
	_at = 0
	_stage = READ_BACK


## One picture out of the finished file, and its SHA-256 against the one
## taken while writing.
func _read_one_back() -> void:
	if _at >= _art.size():
		_file.close()
		_file = null
		_stage = JUDGE
		return
	var entry: Array = _art[_at]
	var where: Variant = _index.get(String(entry[0]), null)
	var payload := PackedByteArray()
	var size := _file.get_length()
	if where is Array and int(where[0]) + 30 <= size:
		_file.seek(int(where[0]))
		var header := _file.get_buffer(30)
		var data_at := int(where[0]) + 30 + header.decode_u16(26) + header.decode_u16(28)
		var packed := int(where[3])
		var unpacked := int(where[4])
		if header.decode_u32(0) == LOCAL_SIGNATURE and data_at + packed <= size \
				and unpacked <= PackFetch.MAX_PICTURE:
			_file.seek(data_at)
			payload = _file.get_buffer(packed)
			if int(where[1]) == 8 and unpacked > 0:
				# Raw deflate, dressed as gzip for the engine's inflater —
				# the way [PackSeal] reads a pack's pictures.
				var gzip := PackedByteArray([0x1F, 0x8B, 8, 0, 0, 0, 0, 0, 0, 0xFF])
				gzip.append_array(payload)
				var trailer := PackedByteArray()
				trailer.resize(8)
				trailer.encode_u32(0, int(where[2]))
				trailer.encode_u32(4, unpacked)
				gzip.append_array(trailer)
				payload = gzip.decompress(unpacked, FileAccess.COMPRESSION_GZIP)
			elif int(where[1]) != 0:
				payload = PackedByteArray()
	if payload.is_empty() or sha256(payload) != String(entry[1]):
		_fail("refused", "The finished pack did not read back as it was written (%s)." % String(entry[0]).get_file())
		return
	_at += 1
	done = _at


func _judge() -> void:
	var report: Variant = judge.call(_final()) if judge.is_valid() else {"ok": true}
	if not (report is Dictionary) or not bool(report.get("ok", false)):
		var why := String(report.get("why", "refused")) if report is Dictionary else "refused"
		_fail("refused", "The game's own check refused the finished pack: %s" % why)
		return
	path = _final()
	state = "done"


func _fail(kind: String, text: String) -> void:
	if _out != null:
		_out.close()
		_out = null
	if _file != null:
		_file.close()
		_file = null
	_clear()
	problem = kind
	problem_text = text
	state = "failed"
