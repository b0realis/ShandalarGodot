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
## CRC-32 — read from the end of the file ([method fingerprint]). A
## pack rebuilt, repaired, re-zipped or replaced has another table and
## is hashed in full again; a truncated one has another size. The check
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

static var pictures_hashed := 0


## The fingerprint of the pack file at [param path]: "" where there is
## no file, no zip tail or a zip64 table (never sealed — hashed every
## start, as before).
static func fingerprint(path: String) -> String:
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
## [constant KEPT]).
static func seal(seal: String) -> void:
	if seal == "":
		return
	var seals := _seals()
	seals.erase(seal)
	seals.append(seal)
	while seals.size() > KEPT:
		seals.pop_front()
	# Whole or not at all (bug pass of 2026-10-03): a list cut short by a
	# failed write in place read back as no seals, and every pack was
	# hashed in full again. A list that cannot be written is left as it
	# was; this pack is simply hashed again at the next start.
	Settings.write_atomically(FILE, JSON.stringify({"seals": seals}).to_utf8_buffer())


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
static func artwork_sha256(reader: ZIPReader, names: Array, trusted := "") -> String:
	if trusted != "" and not names.is_empty():
		return trusted
	var ordered := names.duplicate()
	ordered.sort()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for value in ordered:
		var name := String(value)
		hashing.update(name.to_utf8_buffer())
		hashing.update(PackedByteArray([0]))
		hashing.update(_sha256(reader.read_file(name)).to_utf8_buffer())
		hashing.update("\n".to_utf8_buffer())
		pictures_hashed += 1
	return hashing.finish().hex_encode()


static func _sha256(payload: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(payload)
	return hashing.finish().hex_encode()
