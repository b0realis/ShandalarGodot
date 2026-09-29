class_name HomelandsPack
extends RefCounted
## Trusted Pack 4 contract. The ZIP supplies data/art, never script paths.

const ID := "pack-4"
const FILE_NAME := "Pack-4-Homelands.zip"
const PREFIX := "card_packs/pack_4_homelands/"
const SOURCE := "res://packaging/card_packs/pack_4_homelands/"
const COUNTS := {"published_printings": 140, "named_set_entries": 115,
	"distinct_cards": 115, "pack_card_entries": 115,
	"reprint_entries": 0, "new_rules_identities": 115}

## Only JSON and strings are cached; never card objects or Callables.
static var _records: Array = []
static var _names: Array[String] = []

static func records() -> Array:
	if not _records.is_empty():
		return _records.duplicate(true)
	var raw: Array = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "cards.json"))
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
		out.append({"name": name, "set": "hml",
			"path": "res://cards/sets/hml/%s.gd" % snake(name)})
	return out

static func snake(value: String) -> String:
	var out := ""
	for character in value.to_lower():
		var code := character.unicode_at(0)
		out += character if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")

static func inspect(path: String, art_trusted := false) -> Dictionary:
	if path.get_file() != FILE_NAME:
		return {"ok": false, "why": "must be named exactly " + FILE_NAME}
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return {"ok": false, "why": "not a ZIP file"}
	var report := _inspect(reader, art_trusted)
	reader.close()
	report["path"] = path
	return report

static func _inspect(reader: ZIPReader, art_trusted := false) -> Dictionary:
	var core := [PREFIX + "manifest.json", PREFIX + "catalog.json",
		PREFIX + "cards.json", PREFIX + "README.txt"]
	var artwork: Array = []
	var additions := new_names()
	for name in names():
		for suffix in [".jpg", "_card.jpg"]:
			artwork.append(PREFIX + "art/hml/" + snake(name) + suffix)
			if additions.has(name):
				artwork.append("skin/cardart/" + snake(name) + suffix)
	var all_files := core + artwork
	all_files.sort()
	core.sort()
	var got := Array(reader.get_files())
	got.sort()
	var has_art := got == all_files
	if not has_art and (got != core or not OS.has_feature("shandalar_test")):
		return {"ok": false, "why": "expected the exact metadata and all 460 Pack 4 artwork files; no scripts are allowed"}
	var manifest: Variant = JSON.parse_string(reader.read_file(PREFIX + "manifest.json").get_string_from_utf8())
	var catalog: Variant = JSON.parse_string(reader.read_file(PREFIX + "catalog.json").get_string_from_utf8())
	var cards: Variant = JSON.parse_string(reader.read_file(PREFIX + "cards.json").get_string_from_utf8())
	if not (manifest is Dictionary and catalog is Dictionary and cards is Array):
		return {"ok": false, "why": "invalid Pack 4 JSON"}
	var trusted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "manifest.json"))
	for key in trusted:
		if manifest.get(key) != trusted[key]:
			return {"ok": false, "why": "Pack 4 manifest mismatch: " + String(key)}
	var current := String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if _version_less(current, String(manifest.minimum_game_version)):
		return {"ok": false, "why": "requires game version " + String(manifest.minimum_game_version)}
	if not _same(manifest.get("counts"), COUNTS) or not _same(manifest.get("new_rules_identities"), new_names()):
		return {"ok": false, "why": "Pack 4 counts or names do not match Homelands"}
	var wanted_catalog := {"pack_format": 1, "pack_id": ID, "counts": COUNTS,
		"sets": {"hml": {"names": names(), "named_cards": 115, "published_printings": 140}}}
	if not _same(catalog, wanted_catalog) or cards != records():
		return {"ok": false, "why": "Pack 4 checklist differs from the trusted Homelands data"}
	var sums := {}
	for name in ["catalog.json", "cards.json", "README.txt"]:
		sums[name] = _sha(reader.read_file(PREFIX + name))
	artwork.sort()
	# The pictures' digest, or the manifest's word for it on a sealed
	# pack whose pictures passed at an earlier start ([PackSeal]).
	var art_sum := PackSeal.artwork_sha256(reader, artwork if has_art else [],
		PackSeal.claimed_artwork(manifest) if art_trusted and has_art else "")
	var expected := {"algorithm": "sha256", "metadata": sums,
		"artwork": {"files": artwork.size() if has_art else 0, "sha256": art_sum}}
	if not _same(manifest.get("checksums"), expected):
		return {"ok": false, "why": "Pack 4 metadata or artwork checksum does not match"}
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
