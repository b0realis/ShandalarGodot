class_name PackSeal
extends RefCounted
## THE SEAL ON A CARD PACK (2026-09-29, the first Meta Quest report:
## *"very long load time — time is spent on 'card pack found'"*).
##
## Every start hashed every picture of every pack: [method
## CardPacks.inspect] and its six siblings read the whole artwork out of
## the zip and compared its digest with the manifest's, 600 MB through
## the zip reader — 7.5 s on a desk with an SSD (measured, seven packs),
## the better part of a minute on a headset that reads its storage
## through Java. The pictures do not change between starts; the FILE
## does not change. So a pack whose pictures passed once is SEALED, and
## at the next start the manifest's word for the artwork digest is taken
## without a picture read — everything else the inspection does (the
## file list, no scripts, the metadata digests, the counts, the
## checklists) still runs, in milliseconds.
##
## WHAT THE SEAL IS. The SHA-256 of the file's size and of its central
## directory — the zip's own table of every entry's name, sizes and
## CRC-32 — read from the end of the file ([method table_fingerprint]),
## bound since 2026-10-12 to the file itself: its path and modification
## time ([method fingerprint]; a copy damaged in its data has the good
## pack's table, and inherited its seal). A
## pack rebuilt, repaired, re-zipped or replaced has another table and
## is hashed in full again; a truncated one has another size; a copy
## elsewhere or written anew is another file. A pack REFUSED after its
## pictures were read is remembered the same way ([method refuse]), so a
## damaged copy is not read again at every start. The check
## exists against a corrupt or mislabelled pack and against code in a
## pack; the second is the file list, read every start. It is not a
## defence against the player's own hand editing a picture under an
## unchanged CRC — the player's machine is the player's.
##
## The seals live in `user://pack_seals.json`, a list of fingerprints,
## newest last, at most [constant KEPT]. "Forget my zips" does not touch
## them; a seal with no file behind it is a string nobody asks for.
##
## [member pictures_hashed] counts the pictures read since the process
## started — the log line at discovery says `sealed` or `hashed`, and a
## test reads the count.

const FILE := "user://pack_seals.json"
const KEPT := 64
## The end-of-central-directory record: 22 bytes, then a comment of at
## most 65535, at the very end of the file.
const EOCD_SIZE := 22
const EOCD_SCAN := EOCD_SIZE + 65535
## The pictures are read this many bytes at a time ([method _window_bytes]).
const WINDOW := 8 * 1024 * 1024

static var pictures_hashed := 0


## The fingerprint of the pack FILE at [param path]: its table ([method
## table_fingerprint]) bound to where the file is and when it was last
## written; "" where the table is "" (never sealed — hashed every start,
## as before).
##
## ONE FILE'S SEAL (robustness campaign of 2026-10-12). The table alone
## was the seal until then, and a copy damaged in its DATA has the good
## pack's table: a damaged copy in the card folder was refused at one
## start while the good copy in another folder was hashed and sealed —
## and at the next start the damaged copy came first and was taken as
## sealed, broken pictures and all. A copy written over a sealed pack
## (same name, same table, other bytes) was never checked either. Bound
## to the file, a copy elsewhere is checked for itself, and a copy over
## the same name has another modification time. (A copy made keeping the
## old file's time, `cp -p`, over the same name, is still taken: the
## engine reads no change time to tell.)
static func fingerprint(path: String) -> String:
	return bind(table_fingerprint(path), path)


## [param table] (a [method table_fingerprint]) bound to the file at
## [param path] — its full path and modification time; "" for "".
static func bind(table: String, path: String) -> String:
	if table == "":
		return ""
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(("%s\n%s\n%d\n" % [table, ProjectSettings.globalize_path(path),
		FileAccess.get_modified_time(path)]).to_utf8_buffer())
	return hashing.finish().hex_encode()


## The fingerprint of the ZIP's TABLE at [param path]: the SHA-256 of the
## file's size and its central directory — what the seal was before
## 2026-10-12, and what an older build's seal still is ([method
## CardPacks._hash_plan] honours one for the single file that has that
## table). "" where there is no file, no zip tail or a zip64 table.
static func table_fingerprint(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var size := file.get_length()
	var tail_size := mini(size, EOCD_SCAN)
	file.seek(size - tail_size)
	var tail := file.get_buffer(tail_size)
	var at := tail.size() - EOCD_SIZE
	while at >= 0:
		if tail[at] == 0x50 and tail[at + 1] == 0x4B and tail[at + 2] == 0x05 \
				and tail[at + 3] == 0x06:
			break
		at -= 1
	if at < 0:
		return ""
	var directory_size := tail.decode_u32(at + 12)
	var directory_at := tail.decode_u32(at + 16)
	if directory_size == 0xFFFFFFFF or directory_at == 0xFFFFFFFF \
			or directory_at + directory_size > size:
		return ""
	file.seek(directory_at)
	var directory := file.get_buffer(directory_size)
	file.close()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(("%d\n" % size).to_utf8_buffer())
	hashing.update(directory)
	return hashing.finish().hex_encode()


## Whether [param seal] is on the list.
static func sealed(seal: String) -> bool:
	return seal != "" and _seals().has(seal)


## Put [param seal] on the list (last; the oldest drops past
## [constant KEPT]), taking [param replaces] off it in the same write (an
## older build's table seal, now bound to its file) and any refusal
## remembered for [param seal].
static func seal(seal: String, replaces := "") -> void:
	if seal == "":
		return
	var seals := _seals()
	seals.erase(seal)
	if replaces != "":
		seals.erase(replaces)
	seals.append(seal)
	while seals.size() > KEPT:
		seals.pop_front()
	var refused := _refused()
	refused.erase(seal)
	_write(seals, refused)


## Write the list (and the refusals, when there are any) whole.
static func _write(seals: Array, refused: Dictionary) -> void:
	var data := {"seals": seals}
	if not refused.is_empty():
		data["refused"] = refused
	# Whole or not at all (bug pass of 2026-10-03): a list cut short by a
	# failed write in place read back as no seals, and every pack was
	# hashed in full again. A list that cannot be written is left as it
	# was; this pack is simply hashed again at the next start.
	Settings.write_atomically(FILE, JSON.stringify(data).to_utf8_buffer())


# --- campaign 2026-10-12 f-packs: a refused pack is remembered ---

## REMEMBER A REFUSAL (robustness campaign of 2026-10-12). A pack refused
## after its pictures were read — a damaged copy — was never sealed, so
## every start read all its pictures again (the check screen at every
## start, tens of seconds on the headset) to refuse it again, three engine
## errors each time. [param seal] is the FILE's fingerprint ([method
## fingerprint]), so the memory is that file's alone — the good copy of
## the same pack elsewhere is another file — and it is kept with the game
## version that judged it: another version may judge the file otherwise
## and reads it again. A file written anew has another fingerprint.
static func refuse(seal: String, why: String) -> void:
	if seal == "":
		return
	var refused := _refused()
	refused.erase(seal)
	refused[seal] = {"why": why, "game": _game_version()}
	while refused.size() > KEPT:
		refused.erase(refused.keys()[0])
	var seals := _seals()
	seals.erase(seal)
	_write(seals, refused)


## Why the file whose fingerprint is [param seal] was refused at an
## earlier start by this game version, or "".
static func refusal(seal: String) -> String:
	if seal == "":
		return ""
	var one: Variant = _refused().get(seal, null)
	if not (one is Dictionary) or String(one.get("game", "")) != _game_version():
		return ""
	return String(one.get("why", ""))


static func _refused() -> Dictionary:
	if not FileAccess.file_exists(FILE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not (parsed is Dictionary) or not (parsed.get("refused", null) is Dictionary):
		return {}
	var out := {}
	for key in parsed["refused"]:
		var one: Variant = parsed["refused"][key]
		if key is String and one is Dictionary and one.get("why", null) is String:
			out[key] = one
	return out


static func _game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))

# --- end campaign 2026-10-12 f-packs ---


## Forget every seal — a test's clean slate, or a player who wants the
## next start to read every picture again.
static func clear() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)


static func _seals() -> Array:
	if not FileAccess.file_exists(FILE):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not (parsed is Dictionary) or not (parsed.get("seals", null) is Array):
		return []
	var out: Array = []
	for value in parsed["seals"]:
		if value is String:
			out.append(value)
	return out


## The manifest's word for the artwork digest, or "" where it has none.
static func claimed_artwork(manifest: Variant) -> String:
	if not (manifest is Dictionary):
		return ""
	var checksums: Variant = manifest.get("checksums", null)
	if not (checksums is Dictionary):
		return ""
	var artwork: Variant = checksums.get("artwork", null)
	if not (artwork is Dictionary):
		return ""
	return String(artwork.get("sha256", ""))


## The digest of the pictures [param names] in [param reader], the way
## the Python builder computes it: sorted, each name, a zero byte, the
## hex SHA-256 of the file and a newline into one SHA-256. Given a
## [param trusted] value — the manifest's claim, on a sealed pack — that
## value comes back and no picture is read.
##
## Given the pack's [param path] the pictures are read through
## [method _indexed_sha256s], several times faster on every machine and
## most on the headset (see there); the digest is the same stream either
## way, and a zip that reader does not take is read through [param reader]
## as it always was.
static func artwork_sha256(reader: ZIPReader, names: Array, trusted := "", path := "") -> String:
	if trusted != "" and not names.is_empty():
		return trusted
	var ordered := names.duplicate()
	ordered.sort()
	var sums: Dictionary = _indexed_sha256s(path, ordered) if path != "" else {}
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	var done := 0
	for value in ordered:
		var name := String(value)
		hashing.update(name.to_utf8_buffer())
		hashing.update(PackedByteArray([0]))
		if sums.is_empty():
			hashing.update(_sha256(reader.read_file(name)).to_utf8_buffer())
			pictures_hashed += 1
			done += 1
			_report(done, ordered.size())
		else:
			hashing.update(String(sums[name]).to_utf8_buffer())
		hashing.update("\n".to_utf8_buffer())
	return hashing.finish().hex_encode()


## Told of each picture read — `(read, of)` — while a pack is checked: the
## start's progress screen ([PackCheckScreen]). Not set, nothing is called.
static var progress := Callable()


static func _report(done: int, total: int) -> void:
	if progress.is_valid():
		progress.call(done, total)


## THE PICTURES IN ONE PASS (2026-10-11, the owner's Quest: the first
## start after nine packs were copied over took six minutes on the splash
## screen, Pack 3 alone 54 s). [method ZIPReader.read_file] finds an entry
## by walking the zip's directory from its first record, reading record
## after record through the file, so a pack of 2,474 pictures read ~3
## million records to read its pictures — 9.9 s for Pack 9 on a desk
## (measured), and on the headset, where every one of those small reads
## goes through Java, about 3 MB/s.
##
## Here the directory is read ONCE, the pictures are taken in the order
## they lie in the file, through reads of a few megabytes, and each is
## inflated by the engine's own gzip reader — a raw deflate stream given
## the gzip header and the trailer the directory already holds (its CRC-32
## and size), so the inflate also checks the CRC. Pack 9 on the same desk:
## 2.4 s, the same digest (measured on all nine packs).
##
## Returns {name: hex SHA-256} for every name in [param names], or {} for
## anything it does not take — no file, a zip64 or encrypted entry, a
## method other than stored or deflate, a name the directory does not
## hold, an entry that does not inflate to its size — and the caller reads
## through [ZIPReader] exactly as before, which decides what is wrong.
static func _indexed_sha256s(path: String, names: Array) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var size := file.get_length()
	var tail_size := mini(size, EOCD_SCAN)
	file.seek(size - tail_size)
	var tail := file.get_buffer(tail_size)
	var at := tail.size() - EOCD_SIZE
	while at >= 0 and not (tail[at] == 0x50 and tail[at + 1] == 0x4B \
			and tail[at + 2] == 0x05 and tail[at + 3] == 0x06):
		at -= 1
	if at < 0:
		return {}
	var count := tail.decode_u16(at + 10)
	var directory_size := tail.decode_u32(at + 12)
	var directory_at := tail.decode_u32(at + 16)
	if count == 0xFFFF or directory_size == 0xFFFFFFFF or directory_at == 0xFFFFFFFF \
			or directory_at + directory_size > size:
		return {}
	file.seek(directory_at)
	var directory := file.get_buffer(directory_size)
	var wanted := {}
	for value in names:
		wanted[String(value)] = true
	var entries: Array = []   # [local offset, name, method, crc, packed, unpacked, name bytes]
	var p := 0
	for i in count:
		if p + 46 > directory.size() or directory.decode_u32(p) != 0x02014B50:
			return {}
		var flags := directory.decode_u16(p + 8)
		var method := directory.decode_u16(p + 10)
		var packed := directory.decode_u32(p + 20)
		var unpacked := directory.decode_u32(p + 24)
		var name_size := directory.decode_u16(p + 28)
		var record := 46 + name_size + directory.decode_u16(p + 30) + directory.decode_u16(p + 32)
		var name := directory.slice(p + 46, p + 46 + name_size).get_string_from_utf8()
		if wanted.has(name):
			if flags & 1 or not method in [0, 8] or packed == 0xFFFFFFFF or unpacked == 0xFFFFFFFF:
				return {}
			entries.append([directory.decode_u32(p + 42), name, method,
				directory.decode_u32(p + 16), packed, unpacked,
				directory.slice(p + 46, p + 46 + name_size)])
		p += record
	if entries.size() != wanted.size():
		return {}
	entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var sums := {}
	var window := PackedByteArray()
	var window_at := 0
	for entry: Array in entries:
		var local: int = entry[0]
		var name_bytes: PackedByteArray = entry[6]
		var head := _window_bytes(file, size, local, 30 + name_bytes.size(), window, window_at)
		if head.is_empty():
			return {}
		window = head[1]
		window_at = head[2]
		var header: PackedByteArray = head[0]
		if header.decode_u32(0) != 0x04034B50 or not _local_agrees(header, entry):
			return {}
		var data_at: int = local + 30 + header.decode_u16(26) + header.decode_u16(28)
		var body := _window_bytes(file, size, data_at, int(entry[4]), window, window_at)
		if body.is_empty():
			return {}
		window = body[1]
		window_at = body[2]
		var payload: PackedByteArray = body[0]
		if int(entry[2]) == 8:
			var gzip := PackedByteArray([0x1F, 0x8B, 8, 0, 0, 0, 0, 0, 0, 0xFF])
			gzip.append_array(payload)
			var trailer := PackedByteArray()
			trailer.resize(8)
			trailer.encode_u32(0, int(entry[3]))
			trailer.encode_u32(4, int(entry[5]))
			gzip.append_array(trailer)
			payload = gzip.decompress(int(entry[5]), FileAccess.COMPRESSION_GZIP) \
				if int(entry[5]) > 0 else PackedByteArray()
		if payload.size() != int(entry[5]):
			return {}
		sums[entry[1]] = _sha256(payload)
		pictures_hashed += 1
		_report(sums.size(), entries.size())
	return sums


## [param length] bytes at [param at] out of [param window] (which starts
## at [param window_at] in the file), reading a fresh window of at least
## [constant WINDOW] bytes when they are not in it. Returns
## [bytes, window, window_at], or [] past the end of the file.
static func _window_bytes(file: FileAccess, size: int, at: int, length: int,
		window: PackedByteArray, window_at: int) -> Array:
	if at < 0 or at + length > size:
		return []
	if at < window_at or at + length > window_at + window.size():
		file.seek(at)
		window = file.get_buffer(mini(maxi(length, WINDOW), size - at))
		window_at = at
		if window.size() < length:
			return []
	return [window.slice(at - window_at, at - window_at + length), window, window_at]


static func _sha256(payload: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	# An empty buffer is an engine error in `update` (robustness campaign
	# of 2026-10-12: a picture the zip library could not read came back
	# empty, and every start that read it logged one); the empty digest
	# is the same without it.
	if not payload.is_empty():
		hashing.update(payload)
	return hashing.finish().hex_encode()


## THE LOCAL HEADER AGREES WITH THE DIRECTORY (robustness campaign of
## 2026-10-12). The zip library the engine reads through — [ZIPReader],
## and the mounted pack the pictures are drawn from — refuses an entry
## whose local header disagrees with its directory record: another
## method, and unless the entry's sizes and CRC follow its data (flag bit
## 3), another CRC or size; another name length. This reader took the
## header's two lengths and nothing else, so a bit flipped in a local
## CRC passed the check, the pack was sealed, and the picture failed to
## load from the mounted pack at every start. It now asks what the
## library asks, and the name itself besides; [param header] holds the
## 30 bytes and the name, [param entry] the directory's record.
static func _local_agrees(header: PackedByteArray, entry: Array) -> bool:
	var name_bytes: PackedByteArray = entry[6]
	if header.decode_u16(8) != int(entry[2]):
		return false
	if (header.decode_u16(6) & 8) == 0 and (header.decode_u32(14) != int(entry[3]) \
			or header.decode_u32(18) != int(entry[4]) or header.decode_u32(22) != int(entry[5])):
		return false
	return header.decode_u16(26) == name_bytes.size() \
		and header.slice(30, 30 + name_bytes.size()) == name_bytes
