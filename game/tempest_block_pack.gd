class_name TempestBlockPack
extends RefCounted
## Trusted Pack 9 contract. The ZIP supplies data/art, never script paths.
## The Tempest block is three Scryfall sets — Tempest (tmp), Stronghold
## (sth) and Exodus (exo) — in one pack: 621 names, 636 printings, 574 new
## rules identities whose scripts live in `cards/sets/<set>/`. The 47
## reprints keep their existing scripts; the 27 of them that live only in
## another optional pack are provided by this one too ([method shared]).

const ID := "pack-9"
const FILE_NAME := "Pack-9-Tempest-Block.zip"
const PREFIX := "card_packs/pack_9_tempest_block/"
const SOURCE := "res://packaging/card_packs/pack_9_tempest_block/"
## [published printings, distinct names] per set, in pack order.
const SET_COUNTS := {"tmp": [350, 335], "sth": [143, 143], "exo": [143, 143]}
const COUNTS := {"published_printings": 636, "named_set_entries": 621,
	"distinct_cards": 621, "pack_card_entries": 636,
	"reprint_entries": 47, "new_rules_identities": 574}
## Every entry of the exact layout: 4 metadata files, 1,272 namespaced
## pictures and 1,202 skin/cardart fallbacks — the directory guard's bound
## ([method PortalPack.bounded_zip]).
const MAX_ENTRIES := 2478
## The archive's byte budget, the same as Pack 8's: the three sets'
## pictures and their fallbacks measured 237.3 MiB of members (2026-10-06),
## 92.7% of the 256 MiB the first seven packs allow — 18.7 MiB that one
## re-scanned picture set could take; the Python builder holds the same
## number (`tools/pack_9_tempest_block.py`, MAX_BYTES).
const MAX_BYTES := 384 * 1024 * 1024
const SHARED_COUNT := 27
## The per-set card files, in [constant SET_COUNTS] order.
const CARD_FILES := {"tmp": "cards.json", "sth": "cards_sth.json", "exo": "cards_exo.json"}

## Only JSON and strings are cached; never card objects or Callables.
static var _printings: Array = []
static var _records: Array = []
static var _names: Array[String] = []
static var _shared: Dictionary = {}

## The 27 reprints whose trusted script lives only in Ice Age, Portal,
## Portal Second Age or Mirage, keyed to the set folder of that script.
## Read from shared_names.json in the source folder.
static func shared() -> Dictionary:
	if _shared.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "shared_names.json"))
		assert(raw is Dictionary and raw.size() == SHARED_COUNT)
		_shared = raw
	return _shared.duplicate()

## Every printing of the three sets, Tempest first, in collector order.
static func printings() -> Array:
	if _printings.is_empty():
		var rows: Array = []
		for code in SET_COUNTS:
			rows.append_array(JSON.parse_string(FileAccess.get_file_as_string(SOURCE + CARD_FILES[code])))
		_printings = rows
	return _printings.duplicate(true)

static func catalog_sets() -> Dictionary:
	var rows := printings()
	var sets := {}
	for code in SET_COUNTS:
		var members: Array[String] = []
		for row in rows:
			if row.set == code and not members.has(row.name): members.append(row.name)
		members.sort()
		sets[code] = {"names": members, "named_cards": SET_COUNTS[code][1],
			"published_printings": SET_COUNTS[code][0]}
	return sets

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

## The block's own names load from their set folder; a shared reprint
## loads the original pack's script and wears the block set it was
## printed in, so it shows that symbol when Pack 9 is its only provider.
static func scripts() -> Array:
	var out: Array = []
	var additions := new_names()
	var origins := shared()
	for row in records():
		if additions.has(row.name):
			out.append({"name": row.name, "set": row.set,
				"path": "res://cards/sets/%s/%s.gd" % [row.set, snake(row.name)]})
		elif origins.has(row.name):
			out.append({"name": row.name, "set": row.set,
				"path": "res://cards/sets/%s/%s.gd" % [origins[row.name], snake(row.name)]})
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
	if not PortalPack.bounded_zip(path, MAX_ENTRIES, MAX_BYTES):
		return {"ok": false, "why": "invalid ZIP directory or Pack 9 size limit exceeded"}
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
	additions.append_array(shared().keys())
	var rows := printings()
	var seen := {}
	var fallback := {}
	for row in rows:
		var key: String = row.set + ":" + row.name
		var stem := snake(row.name) + ("__" + String(row.collector_number) if seen.has(key) else "")
		for suffix in [".jpg", "_card.jpg"]:
			artwork.append(PREFIX + "art/" + row.set + "/" + stem + suffix)
			if additions.has(row.name) and not fallback.has(row.name):
				artwork.append("skin/cardart/" + stem + suffix)
		seen[key] = true
		fallback[row.name] = true
	var all_files := core + artwork
	all_files.sort()
	core.sort()
	var got := Array(reader.get_files())
	got.sort()
	var has_art := got == all_files
	if not has_art and (got != core or not OS.has_feature("shandalar_test")):
		return {"ok": false, "why": "Rebuild Pack-9-Tempest-Block.zip with the matching tools/pack_9_tempest_block.py. Expected %d artwork files and exact metadata, without scripts." % artwork.size()}
	var manifest: Variant = JSON.parse_string(reader.read_file(PREFIX + "manifest.json").get_string_from_utf8())
	var catalog: Variant = JSON.parse_string(reader.read_file(PREFIX + "catalog.json").get_string_from_utf8())
	var cards: Variant = JSON.parse_string(reader.read_file(PREFIX + "cards.json").get_string_from_utf8())
	if not (manifest is Dictionary and catalog is Dictionary and cards is Array):
		return {"ok": false, "why": "invalid Pack 9 JSON"}
	var trusted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "manifest.json"))
	for key in trusted:
		if manifest.get(key) != trusted[key]:
			return {"ok": false, "why": "Pack 9 manifest mismatch: " + String(key)}
	var current := String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if PortalPack._version_less(current, String(manifest.minimum_game_version)):
		return {"ok": false, "why": "requires game version " + String(manifest.minimum_game_version)}
	if not PortalPack._same(manifest.get("counts"), COUNTS) or not PortalPack._same(manifest.get("new_rules_identities"), new_names()):
		return {"ok": false, "why": "Pack 9 counts or names do not match the Tempest block"}
	var wanted_catalog := {"pack_format": 1, "pack_id": ID, "counts": COUNTS,
		"sets": catalog_sets()}
	if not PortalPack._same(catalog, wanted_catalog) or cards != rows:
		return {"ok": false, "why": "Pack 9 checklist differs from the trusted Tempest block data"}
	var sums := {}
	for name in ["catalog.json", "cards.json", "README.txt"]:
		sums[name] = PortalPack._sha(reader.read_file(PREFIX + name))
	artwork.sort()
	# The pictures' digest, or the manifest's word for it on a sealed
	# pack whose pictures passed at an earlier start ([PackSeal]).
	var art_sum := PackSeal.artwork_sha256(reader, artwork if has_art else [],
		PackSeal.claimed_artwork(manifest) if art_trusted and has_art else "")
	var expected := {"algorithm": "sha256", "metadata": sums,
		"artwork": {"files": artwork.size() if has_art else 0, "sha256": art_sum}}
	if not PortalPack._same(manifest.get("checksums"), expected):
		return {"ok": false, "why": "Pack 9 metadata or artwork checksum does not match"}
	return {"ok": true, "why": "", "manifest": manifest, "catalog": catalog,
		"cards": cards, "has_art": has_art}
