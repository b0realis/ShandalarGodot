class_name PortalPack
extends RefCounted
## Trusted Pack 6 contract. The ZIP supplies data/art, never script paths.

const ID := "pack-6"
const FILE_NAME := "Pack-6-Portal.zip"
const PREFIX := "card_packs/pack_6_portal/"
const SOURCE := "res://packaging/card_packs/pack_6_portal/"
const COUNTS := {"published_printings": 215, "named_set_entries": 200,
	"distinct_cards": 200, "pack_card_entries": 215,
	"reprint_entries": 27, "new_rules_identities": 173}

## Reuse trusted earlier implementations even when their own pack is off.
const SHARED := {"Dry Spell": "hml", "Elvish Ranger": "all",
	"Mountain Goat": "ice", "Nature's Lore": "ice", "Pyroclasm": "ice", "Storm Crow": "all"}

## Only JSON and strings are cached; never card objects or Callables.
static var _records: Array = []
static var _names: Array[String] = []

static func printings() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "cards.json"))

static func records() -> Array:
	if not _records.is_empty():
		return _records.duplicate(true)
	var raw := printings()
	var seen := {}
	var out: Array = []
	for row in raw:
		if not seen.has(row.name):
			seen[row.name] = true
			out.append(row)
	_records = out
	return out.duplicate(true)

static func names() -> Array[String]:
	if not _names.is_empty():
		return _names.duplicate()
	var out: Array[String] = []
	for row in records():
		out.append(String(row.name))
	out.sort()
	_names = out
	return out.duplicate()

static func new_names() -> Array[String]:
	var reprints: Array = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "reprint_names.json"))
	var out := names()
	for name in reprints:
		out.erase(String(name))
	return out

static func scripts() -> Array:
	var out: Array = []
	for name in new_names():
		out.append({"name": name, "set": "por",
			"path": "res://cards/sets/por/%s.gd" % snake(name)})
	for name in SHARED:
		out.append({"name": name, "set": "por",
			"path": "res://cards/sets/%s/%s.gd" % [SHARED[name], snake(name)]})
	return out

static func snake(value: String) -> String:
	var out := ""
	for character in value.to_lower():
		var code := character.unicode_at(0)
		out += character if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")

static func inspect(path: String) -> Dictionary:
	if path.get_file() != FILE_NAME:
		return {"ok": false, "why": "must be named exactly " + FILE_NAME}
	if not _bounded_zip(path):
		return {"ok": false, "why": "invalid ZIP directory or Pack 6 size limit exceeded"}
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return {"ok": false, "why": "not a ZIP file"}
	var report := _inspect(reader)
	reader.close()
	report["path"] = path
	return report

## Inspect declared uncompressed lengths before ZIPReader allocates them.
## Our builder produces ordinary, single-disk ZIPs, never ZIP64 archives.
static func _bounded_zip(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 22 or file.get_length() > 256 * 1024 * 1024: return false
	var tail_size := mini(65557, file.get_length())
	file.seek(file.get_length() - tail_size)
	var tail := file.get_buffer(tail_size)
	var end := tail.size() - 22
	while end >= 0:
		if tail.decode_u32(end) == 0x06054b50 and end + 22 + tail.decode_u16(end + 20) == tail.size(): break
		end -= 1
	if end < 0 or tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0: return false
	var count := tail.decode_u16(end + 10)
	if count > 792 or count != tail.decode_u16(end + 8): return false
	var directory_end := file.get_length() - tail_size + end
	var offset := tail.decode_u32(end + 16)
	if offset + tail.decode_u32(end + 12) != directory_end: return false
	file.seek(offset)
	var total := 0
	for n in count:
		if file.get_position() + 46 > directory_end: return false
		var header := file.get_buffer(46)
		if header.decode_u32(0) != 0x02014b50 or header.decode_u16(34) != 0: return false
		var unpacked := header.decode_u32(24)
		if unpacked > 8 * 1024 * 1024: return false
		total += unpacked
		if total > 256 * 1024 * 1024: return false
		var next := file.get_position() + header.decode_u16(28) + header.decode_u16(30) + header.decode_u16(32)
		if next > directory_end: return false
		file.seek(next)
	return file.get_position() == directory_end

static func _inspect(reader: ZIPReader) -> Dictionary:
	var core := [PREFIX + "manifest.json", PREFIX + "catalog.json",
		PREFIX + "cards.json", PREFIX + "README.txt"]
	var artwork: Array = []
	var additions := new_names()
	additions.append_array(SHARED.keys())
	for name in names():
		for suffix in [".jpg", "_card.jpg"]:
			artwork.append(PREFIX + "art/por/" + snake(name) + suffix)
			if additions.has(name):
				artwork.append("skin/cardart/" + snake(name) + suffix)
	var seen := {}
	for row in printings():
		if seen.has(row.name):
			for suffix in [".jpg", "_card.jpg"]:
				artwork.append(PREFIX + "art/por/" + snake(row.name) + "__" + row.collector_number + suffix)
		seen[row.name] = true
	var all_files := core + artwork
	all_files.sort()
	core.sort()
	var got := Array(reader.get_files())
	got.sort()
	var has_art := got == all_files
	if not has_art and (got != core or not OS.has_feature("shandalar_test")):
		return {"ok": false, "why": "expected the exact metadata and all 788 Pack 6 artwork files; no scripts are allowed"}
	var manifest: Variant = JSON.parse_string(reader.read_file(PREFIX + "manifest.json").get_string_from_utf8())
	var catalog: Variant = JSON.parse_string(reader.read_file(PREFIX + "catalog.json").get_string_from_utf8())
	var cards: Variant = JSON.parse_string(reader.read_file(PREFIX + "cards.json").get_string_from_utf8())
	if not (manifest is Dictionary and catalog is Dictionary and cards is Array):
		return {"ok": false, "why": "invalid Pack 6 JSON"}
	var trusted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "manifest.json"))
	for key in trusted:
		if manifest.get(key) != trusted[key]:
			return {"ok": false, "why": "Pack 6 manifest mismatch: " + String(key)}
	var current := String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if _version_less(current, String(manifest.minimum_game_version)):
		return {"ok": false, "why": "requires game version " + String(manifest.minimum_game_version)}
	if not _same(manifest.get("counts"), COUNTS) or not _same(manifest.get("new_rules_identities"), new_names()):
		return {"ok": false, "why": "Pack 6 counts or names do not match Portal"}
	var wanted_catalog := {"pack_format": 1, "pack_id": ID, "counts": COUNTS,
		"sets": {"por": {"names": names(), "named_cards": 200, "published_printings": 215}}}
	if not _same(catalog, wanted_catalog) or cards != printings():
		return {"ok": false, "why": "Pack 6 checklist differs from the trusted Portal data"}
	var sums := {}
	for name in ["catalog.json", "cards.json", "README.txt"]:
		sums[name] = _sha(reader.read_file(PREFIX + name))
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	artwork.sort()
	if has_art:
		for name in artwork:
			hashing.update(String(name).to_utf8_buffer())
			hashing.update(PackedByteArray([0]))
			hashing.update(_sha(reader.read_file(name)).to_utf8_buffer())
			hashing.update("\n".to_utf8_buffer())
	var expected := {"algorithm": "sha256", "metadata": sums,
		"artwork": {"files": artwork.size() if has_art else 0,
			"sha256": hashing.finish().hex_encode()}}
	if not _same(manifest.get("checksums"), expected):
		return {"ok": false, "why": "Pack 6 metadata or artwork checksum does not match"}
	return {"ok": true, "why": "", "manifest": manifest, "catalog": catalog,
		"cards": cards, "has_art": has_art}

static func _sha(payload: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(payload)
	return hashing.finish().hex_encode()

## JSON numbers deserialize as floats; container equality is type-strict.
static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return float(a) == float(b)
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b

static func _version_less(left: String, right: String) -> bool:
	var a := left.split(".")
	var b := right.split(".")
	for i in 3:
		var av := int(a[i]) if i < a.size() else 0
		var bv := int(b[i]) if i < b.size() else 0
		if av != bv:
			return av < bv
	return false
