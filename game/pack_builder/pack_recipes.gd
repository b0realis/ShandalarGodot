class_name PackRecipes
extends RefCounted
## WHAT EACH CARD PACK IS MADE OF, as the game builds it itself (the owner,
## 2026-11-23: *"using godot only the game would download the cards art and
## generate card packs and put it in its own folder automatically"*).
##
## Eleven recipes: "base" — the 1997 card pictures, the `cardart.zip` that
## `tools/fetch_card_art.py` and `tools/mtg_assets.py --from-cardart` make —
## and "pack-1" … "pack-10", the numbered packs `tools/pack_N_*.py` build.
## Each is a faithful port of its Python tool: the same card list, read
## from the same trusted files this build carries (`res://cards/data/` and
## `res://packaging/card_packs/pack_N_*/`), the same Scryfall questions,
## the same file names and the same zip layout. Nothing in a recipe comes
## from the network; the network supplies pictures and nothing else.
##
## A recipe ([method recipe]) is a Dictionary:
##   ok, why        whether the trusted files gave a whole recipe
##   id, number     "base" / "pack-N"; 0 for base
##   title          "1997 card pictures", "Pack 2: Fallen Empires"
##   file_name      the exact zip name (`Pack-2-Fallen-Empires.zip`)
##   prefix         `card_packs/pack_2_fallen_empires/`; "" for base
##   jobs           what to download, one per card or printing:
##                  {name, ask, key, lookups: [url…], set, number, files:
##                  [[cache file, Scryfall picture kind]…]} — `ask` is the
##                  card as one identifier of a batched question
##                  (`{"id"}` or `{"name", "set"}`) and `key` what its
##                  answer is known by; `lookups` are the single questions
##                  for a card the batch did not find, asked in order, the
##                  next only when the one before answers 404; `set` and
##                  `number` are what the answer must say ("" when the
##                  number is not pinned)
##   entries        the zip's pictures, [[name in the zip, cache file]…]
##   manifest       the trusted manifest with its counts and identities
##                  ([PackWriter] adds the checksums); {} for base
##   metadata       {"catalog.json", "cards.json", "README.txt"} as bytes,
##                  exactly what the Python tool writes; {} for base
##   max_entries, max_bytes   the pack contract's own bounds
##
## THE PACKS DIFFER IN THREE WAYS, and [constant PACKS] names them:
##   * `kind` "dotp" (Pack 1: the set entries the 897-card pool leaves
##     out), "names" (Packs 2–5: one printing per name, asked by name and
##     set) or "printings" (Packs 6–10: every numbered printing, asked by
##     its Scryfall id and checked against set and collector number);
##   * `fallback` — whose pictures also travel as `skin/cardart/<name>`:
##     "all", "new" (the new rules identities), "shared" (shared_names.json)
##     or "new+shared";
##   * `sets`, in the pack's own order; the first set's printings are in
##     `cards.json`, each later one's in `cards_<code>.json`.

const BASE := "base"
const BASE_TITLE := "1997 card pictures"
## `SkinPack.ART_FILE_NAME`, spelt out: this file is read by tools that
## compile before the autoloads have names.
const BASE_FILE := "cardart.zip"
const BASE_DATA := "res://cards/data/"
const BASE_SCRIPTS := "res://cards/sets/"
const PACKAGING := "res://packaging/card_packs/"
const NAMED := "https://api.scryfall.com/cards/named?"
const BY_ID := "https://api.scryfall.com/cards/"
## The two files every card gets: [tail of the file name, Scryfall's name
## for the picture] — the artwork alone, and the whole card.
const VARIANTS := [[".jpg", "art_crop"], ["_card.jpg", "border_crop"]]
## The 1997 pool's sets in the order Pack 1 lists them.
const DOTP_SETS := ["2ed", "arn", "atq", "leg", "drk", "4ed", "past", "phpr"]
const DOTP_MISSING := ["Chaos Orb", "Word of Command", "Shahrazad", "Falling Star"]
const DOTP_COUNTS := {"published_printings": 1305, "named_set_entries": 1270,
	"distinct_cards": 901, "pack_card_entries": 373,
	"reprint_entries": 369, "new_rules_identities": 4}
const DOTP_BASE_CARDS := 897
const PLAIN_MAX_BYTES := 256 * 1024 * 1024
const BLOCK_MAX_BYTES := 384 * 1024 * 1024

## Pack by pack: its source folder, how its list is read, what it is called
## (the trusted manifest's `name`), how many pictures a build downloads and
## — measured on the packs built with the Python tools, 2026-11 — roughly
## how many megabytes they are and the finished zip is.
const PACKS := {
	1: {"dir": "pack_1_dotp_complete", "kind": "dotp", "name": "DotP Complete",
		"file": "Pack-1-DotP-complete.zip", "pictures": 746, "entries": 758, "fetch_mb": 75, "zip_mb": 76},
	2: {"dir": "pack_2_fallen_empires", "kind": "names", "sets": ["fem"], "fallback": "all",
		"name": "Fallen Empires", "file": "Pack-2-Fallen-Empires.zip",
		"pictures": 204, "entries": 412, "fetch_mb": 20, "zip_mb": 41},
	3: {"dir": "pack_3_ice_age", "kind": "names", "sets": ["ice"], "fallback": "new",
		"name": "Ice Age", "file": "Pack-3-Ice_Age.zip",
		"pictures": 746, "entries": 1442, "fetch_mb": 79, "zip_mb": 153},
	4: {"dir": "pack_4_homelands", "kind": "names", "sets": ["hml"], "fallback": "new",
		"name": "Homelands", "file": "Pack-4-Homelands.zip",
		"pictures": 230, "entries": 464, "fetch_mb": 22, "zip_mb": 44},
	5: {"dir": "pack_5_alliances", "kind": "names", "sets": ["all"], "fallback": "new",
		"name": "Alliances", "file": "Pack-5-Alliances.zip",
		"pictures": 288, "entries": 580, "fetch_mb": 29, "zip_mb": 57},
	6: {"dir": "pack_6_portal", "kind": "printings", "sets": ["por", "p02"], "fallback": "new+shared",
		"shared": ["Dry Spell", "Elvish Ranger", "Mountain Goat", "Nature's Lore", "Pyroclasm", "Storm Crow"],
		"name": "Portal & Second Age", "file": "Pack-6-Portal.zip",
		"pictures": 760, "entries": 1356, "fetch_mb": 68, "zip_mb": 122},
	7: {"dir": "pack_7_fifth_edition", "kind": "printings", "sets": ["5ed"], "fallback": "shared",
		"name": "Fifth Edition", "file": "Pack-7-Fifth-Edition.zip",
		"pictures": 898, "entries": 1196, "fetch_mb": 87, "zip_mb": 116},
	8: {"dir": "pack_8_mirage_block", "kind": "printings", "sets": ["mir", "vis", "wth"], "fallback": "new+shared",
		"name": "The Mirage Block", "file": "Pack-8-Mirage-Block.zip",
		"pictures": 1368, "entries": 2676, "fetch_mb": 136, "zip_mb": 266},
	9: {"dir": "pack_9_tempest_block", "kind": "printings", "sets": ["tmp", "sth", "exo"], "fallback": "new+shared",
		"name": "The Tempest Block", "file": "Pack-9-Tempest-Block.zip",
		"pictures": 1272, "entries": 2478, "fetch_mb": 127, "zip_mb": 248},
	10: {"dir": "pack_10_urza_block", "kind": "printings", "sets": ["usg", "ulg", "uds"], "fallback": "new+shared",
		"name": "The Urza Block", "file": "Pack-10-Urza-Block.zip",
		"pictures": 1272, "entries": 2494, "fetch_mb": 128, "zip_mb": 252},
}
## The same for the 1997 pictures: 897 cards, two pictures each.
const BASE_ABOUT := {"name": BASE_TITLE, "file": BASE_FILE, "pictures": 1794,
	"entries": 1794, "fetch_mb": 189, "zip_mb": 189}


## Every recipe's id, in the order the window lists them.
static func ids() -> Array[String]:
	var out: Array[String] = [BASE]
	for number: int in PACKS:
		out.append("pack-%d" % number)
	return out


## 2 for "pack-2", 0 for "base" or anything else.
static func number_of(id: String) -> int:
	var digits := id.trim_prefix("pack-")
	var number := int(digits) if id.begins_with("pack-") and digits.is_valid_int() else 0
	return number if PACKS.has(number) else 0


## What the window shows before anything is built — no trusted file is
## read: {id, number, title, file_name, pictures, entries, fetch_mb, zip_mb}.
static func about(id: String) -> Dictionary:
	var number := number_of(id)
	if id != BASE and number == 0:
		return {}
	var row: Dictionary = BASE_ABOUT if id == BASE else PACKS[number]
	return {"id": id, "number": number,
		"title": BASE_TITLE if id == BASE else "Pack %d: %s" % [number, row["name"]],
		"file_name": String(row["file"]), "pictures": int(row["pictures"]),
		"entries": int(row["entries"]), "fetch_mb": int(row["fetch_mb"]),
		"zip_mb": int(row["zip_mb"])}


## Where the packs' trusted files are read from: this build's own copy.
## A test points it at a folder that lacks some, as an export can.
static var packaging := PACKAGING
## Files this build is to be read as not carrying, by their `res://` path —
## a test's way to stand where an export stands. The game leaves it empty.
static var without: Array[String] = []


## The trusted files [param id]'s recipe is read from, as paths in this
## build.
static func sources(id: String) -> Array[String]:
	var out: Array[String] = []
	var number := number_of(id)
	if id == BASE or number == 1:
		for code: String in DOTP_SETS:
			out.append(BASE_DATA + code + ".json")
	if number == 0:
		return out
	var row: Dictionary = PACKS[number]
	var source := packaging + String(row["dir"]) + "/"
	out.append(source + "manifest.json")
	out.append(source + "README.txt")
	match String(row["kind"]):
		"dotp":
			out.append(source + "missing_cards.json")
		"names":
			out.append(source + "cards.json")
			if number > 2:
				out.append(source + "reprint_names.json")
		_:
			var codes: Array = row["sets"]
			for i in codes.size():
				out.append(source + ("cards.json" if i == 0 else "cards_%s.json" % String(codes[i])))
			out.append(source + "reprint_names.json")
			if String(row["fallback"]).contains("shared") and not row.has("shared"):
				out.append(source + "shared_names.json")
	return out


## The first trusted file of [param id] this build does not carry, or "".
## An exported build holds only what its export filters let in: a pack
## whose list was left out cannot be built by that build, and the window
## says so before it is chosen.
static func lacking(id: String) -> String:
	if id != BASE and number_of(id) == 0:
		return id
	for path: String in sources(id):
		if not _there(path) and _own(path) == "":
			return path.trim_prefix("res://")
	return ""


## Whether this build carries the trusted file [param path].
static func _there(path: String) -> bool:
	return not without.has(path) and FileAccess.file_exists(path)


## The text of [param path] as the script itself carries it ([constant
## PACK_ONE_OWN]), or "" — Pack 1's three files, under the game's own
## packaging folder and nowhere else.
static func _own(path: String) -> String:
	var folder := PACKAGING + String(PACKS[1]["dir"]) + "/"
	if not path.begins_with(folder):
		return ""
	return String(PACK_ONE_OWN.get(path.trim_prefix(folder), ""))


## The whole recipe for [param id]; `ok` false with `why` when a trusted
## file is missing or no longer says what its pack's contract says.
static func recipe(id: String) -> Dictionary:
	if id == BASE:
		return _base()
	var number := number_of(id)
	if number == 0:
		return _refusal("there is no such card pack: " + id)
	var row: Dictionary = PACKS[number]
	var source := packaging + String(row["dir"]) + "/"
	var built: Dictionary
	match String(row["kind"]):
		"dotp":
			built = _dotp(source)
		"names":
			built = _names(number, row, source)
		_:
			built = _printings(number, row, source)
	if not bool(built.get("ok", false)):
		return built
	var readme := _file_bytes(source + "README.txt")
	if readme.is_empty():
		return _refusal("the game's own copy of %s is missing" % (String(row["dir"]) + "/README.txt"))
	var counts: Dictionary = built["counts"]
	var wanted := _contract_counts(number)
	for key: String in wanted:
		if int(counts.get(key, -1)) != int(wanted[key]):
			return _refusal("the Pack %d checklist in this build does not match its contract (%s)" % [number, key])
	var manifest: Dictionary = built["manifest"]
	if String(manifest.get("file_name", "")) != String(row["file"]) \
			or String(manifest.get("id", "")) != id:
		return _refusal("the Pack %d manifest in this build names another pack" % number)
	var metadata := {}
	# In the order the Python tools list them.
	metadata["catalog.json"] = PackJson.bytes(built["catalog"])
	metadata["cards.json"] = PackJson.bytes(built["cards"])
	metadata["README.txt"] = readme
	for name: String in metadata:
		if (metadata[name] as PackedByteArray).is_empty():
			return _refusal("Pack %d's %s could not be written (%s)" % [number, name, PackJson.refused])
	var info := about(id)
	return {"ok": true, "why": "", "id": id, "number": number, "title": info["title"],
		"file_name": String(row["file"]), "prefix": "card_packs/%s/" % String(row["dir"]),
		"jobs": built["jobs"], "entries": built["entries"], "manifest": manifest,
		"metadata": metadata, "max_entries": int(row["entries"]),
		"max_bytes": BLOCK_MAX_BYTES if number >= 8 else PLAIN_MAX_BYTES}


## Card name -> file name stem, exactly `fetch_card_art.snake` and
## `GameSkin._snake`: every character outside a-z and 0-9 is an underscore,
## runs of them one, none at either end ("Mishra's Factory" ->
## "mishra_s_factory", "Dandân" -> "dand_n").
static func snake(value: String) -> String:
	var out := ""
	for character in value.to_lower():
		var code := character.unicode_at(0)
		out += character if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")


## Card name -> the name of its script file, `gen_cards.slugify`: accents
## folded away first ("Dandân" -> "dandan"), then as [method snake]. Python
## folds with Unicode's NFKD table; the letters below are every one of its
## Latin-1 rows, and any other letter beyond ASCII is dropped, as Python
## drops what has no ASCII base.
static func slug(value: String) -> String:
	var folded := ""
	for character in value:
		var code := character.unicode_at(0)
		if code < 128:
			folded += character
		elif FOLD.has(code):
			folded += String(FOLD[code])
	var out := snake(folded)
	return out if out != "" else "card"


const FOLD := {
	0xC0: "A", 0xC1: "A", 0xC2: "A", 0xC3: "A", 0xC4: "A", 0xC5: "A", 0xC7: "C",
	0xC8: "E", 0xC9: "E", 0xCA: "E", 0xCB: "E", 0xCC: "I", 0xCD: "I", 0xCE: "I", 0xCF: "I",
	0xD1: "N", 0xD2: "O", 0xD3: "O", 0xD4: "O", 0xD5: "O", 0xD6: "O",
	0xD9: "U", 0xDA: "U", 0xDB: "U", 0xDC: "U", 0xDD: "Y",
	0xE0: "a", 0xE1: "a", 0xE2: "a", 0xE3: "a", 0xE4: "a", 0xE5: "a", 0xE7: "c",
	0xE8: "e", 0xE9: "e", 0xEA: "e", 0xEB: "e", 0xEC: "i", 0xED: "i", 0xEE: "i", 0xEF: "i",
	0xF1: "n", 0xF2: "o", 0xF3: "o", 0xF4: "o", 0xF5: "o", 0xF6: "o",
	0xF9: "u", 0xFA: "u", 0xFB: "u", 0xFC: "u", 0xFD: "y", 0xFF: "y",
}


## Python's `urlencode` of one value: everything but letters, digits and
## `_.-~` as %XX of its UTF-8 bytes, a space as `+`.
static func query_value(value: String) -> String:
	return value.uri_encode().replace("%20", "+")


## The questions for one card asked by name: its own set's printing first,
## any printing only when Scryfall has none in that set (a 404).
static func named_lookups(card_name: String, set_code: String) -> Array:
	return [NAMED + "exact=" + query_value(card_name) + "&set=" + query_value(set_code),
		NAMED + "exact=" + query_value(card_name)]


## What a job asked by name and set is known by — in a batch's answer, in
## the cache of answers: the name as its file is called, and the set.
static func named_key(card_name: String, set_code: String) -> String:
	return "n:%s|%s" % [snake(card_name), set_code.to_lower()]


## The same for a job asked by its Scryfall id.
static func id_key(scryfall_id: String) -> String:
	return "i:" + scryfall_id.to_lower()


# ---------------------------------------------------------------- base --

## The 1997 pictures: `fetch_card_art.pool()` — every card in the set lists
## under `cards/data/`, the first set that lists a name giving its picture,
## in name order — and the zip `mtg_assets.py --from-cardart` makes of
## them, `skin/cardart/<file>` in file-name order and nothing else.
static func _base() -> Dictionary:
	var files := _json_files_in(BASE_DATA)
	if files.is_empty():
		return _refusal("the game's own card lists are missing (cards/data)")
	var set_of := {}
	for file: String in files:
		var records: Variant = _read(BASE_DATA + file)
		if not (records is Array):
			continue   # sets.json is a table of sets, not a card list
		for card: Variant in records:
			if not (card is Dictionary) or not (card.get("name") is String) \
					or not (card.get("set") is String):
				return _refusal("cards/data/%s holds something that is not a card" % file)
			if not set_of.has(card["name"]):
				set_of[card["name"]] = String(card["set"])
	var names := PackJson.sorted(set_of.keys())
	var jobs: Array = []
	var cache := {}
	for card_name: String in names:
		var code := String(set_of[card_name])
		if not _code_ok(code) or snake(card_name) == "":
			return _refusal("a card the game cannot name a picture file for: " + card_name)
		var wanted: Array = []
		for variant: Array in VARIANTS:
			var file := snake(card_name) + String(variant[0])
			wanted.append([file, String(variant[1])])
			cache[file] = true
		jobs.append({"name": card_name, "lookups": named_lookups(card_name, code),
			"set": code, "number": "", "files": wanted,
			"ask": {"name": card_name, "set": code}, "key": named_key(card_name, code)})
	var entries: Array = []
	for file: String in PackJson.sorted(cache.keys()):
		entries.append(["skin/cardart/" + file, file])
	return {"ok": true, "why": "", "id": BASE, "number": 0, "title": BASE_TITLE,
		"file_name": BASE_FILE, "prefix": "", "jobs": jobs, "entries": entries,
		"manifest": {}, "metadata": {}, "max_entries": entries.size(),
		"max_bytes": 0}


# -------------------------------------------------------------- Pack 1 --

## `pack_1_dotp_complete.assembled()`: the eight 1997 sets' whole
## checklists, and for the pack every (set, name) the 897-card pool does
## not already hold under that set — 369 cross-set reprints and the four
## cards the base game leaves out.
static func _dotp(source: String) -> Dictionary:
	var missing: Variant = _read(source + "missing_cards.json")
	if not (missing is Array):
		return _refusal("the game's own copy of Pack 1's missing_cards.json is missing")
	var missing_by_set := {}
	var missing_names: Array = []
	for row: Variant in missing:
		if not _is_card(row):
			return _refusal("Pack 1's missing_cards.json holds something that is not a card")
		if not missing_by_set.has(row["set"]):
			missing_by_set[row["set"]] = []
		(missing_by_set[row["set"]] as Array).append(row)
		missing_names.append(String(row["name"]))
	if PackJson.sorted(missing_names) != PackJson.sorted(DOTP_MISSING):
		return _refusal("Pack 1's four cards are not the four this build knows")
	var sets := {}
	var all_names := {}
	var cards: Array = []
	var published := 0
	var named_entries := 0
	var base_pairs := 0
	for code: String in DOTP_SETS:
		var rows: Variant = _read(BASE_DATA + code + ".json")
		if not (rows is Array):
			return _refusal("the game's own card list cards/data/%s.json is missing" % code)
		var base_names := _unique_names(rows)
		var assigned := _assigned(code, base_names)
		if assigned.has(""):
			return _refusal("a card script under cards/sets/%s matches no one %s card: %s" % [
				code, code, String(assigned[""])])
		base_pairs += assigned.size()
		rows.append_array(missing_by_set.get(code, []))
		var first := {}
		var names: Array = []
		for row: Variant in rows:
			if not _is_card(row):
				return _refusal("cards/data/%s.json holds something that is not a card" % code)
			if not first.has(row["name"]):
				first[row["name"]] = row
				names.append(String(row["name"]))
		for card_name: String in names:
			if not assigned.has(card_name):
				cards.append(first[card_name])
			all_names[card_name] = true
		published += rows.size()
		named_entries += names.size()
		sets[code] = {"names": names, "named_cards": names.size(),
			"published_printings": rows.size()}
	if base_pairs != DOTP_BASE_CARDS:
		return _refusal("expected %d cards in the 1997 pool, found %d" % [DOTP_BASE_CARDS, base_pairs])
	var counts := {"published_printings": published, "named_set_entries": named_entries,
		"distinct_cards": all_names.size(), "pack_card_entries": cards.size(),
		"reprint_entries": cards.size() - missing.size(),
		"new_rules_identities": missing.size()}
	var manifest: Variant = _read(source + "manifest.json")
	if not (manifest is Dictionary):
		return _refusal("the game's own copy of Pack 1's manifest.json is missing")
	manifest["counts"] = counts
	manifest["new_rules_identities"] = missing_names
	var catalog := {"pack_format": manifest.get("pack_format"), "pack_id": manifest.get("id"),
		"counts": counts, "sets": sets}
	var prefix := "card_packs/%s/" % String(PACKS[1]["dir"])
	var jobs: Array = []
	var entries: Array = []
	var fallbacks: Array = []
	for row: Dictionary in cards:
		var code := String(row["set"])
		var card_name := String(row["name"])
		if not _code_ok(code) or snake(card_name) == "":
			return _refusal("a Pack 1 card the game cannot name a picture file for: " + card_name)
		var wanted: Array = []
		for variant: Array in VARIANTS:
			var file := snake(card_name) + String(variant[0])
			var cached := code + "/" + file
			wanted.append([cached, String(variant[1])])
			entries.append([prefix + "art/" + cached, cached])
			if DOTP_MISSING.has(card_name):
				fallbacks.append(["skin/cardart/" + file, cached])
		jobs.append({"name": card_name, "lookups": named_lookups(card_name, code),
			"set": code, "number": "", "files": wanted,
			"ask": {"name": card_name, "set": code}, "key": named_key(card_name, code)})
	entries.append_array(fallbacks)
	return {"ok": true, "counts": counts, "manifest": manifest, "catalog": catalog,
		"cards": cards, "jobs": jobs, "entries": entries}


## The names of [param code] the 1997 pool holds under that set: one for
## each card script in `cards/sets/<code>/`, matched by [method slug] as
## the Python tool matches them. A script that matches no one name comes
## back under the key "" (the caller refuses).
static func _assigned(code: String, names: Array) -> Dictionary:
	var by_file := {}
	for card_name: String in names:
		var stem := slug(card_name)
		if not by_file.has(stem):
			by_file[stem] = []
		(by_file[stem] as Array).append(card_name)
	var out := {}
	var listed := PackedStringArray()
	var dir := DirAccess.open(BASE_SCRIPTS + code)
	if dir == null:
		out[""] = "the folder cannot be opened"
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			listed.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	# The registry's own reading of a listing: a checkout lists `x.gd`, an
	# exported build `x.gdc` and `x.gd.remap` ([method
	# CardRegistry.card_files_in]).
	for file: String in CardRegistry.card_files_in(listed):
		var matches: Array = by_file.get(file.get_basename(), [])
		if matches.size() != 1:
			out[""] = file
			return out
		out[matches[0]] = true
	return out


# ---------------------------------------------------------- Packs 2–5 --

## `pack_2_fallen_empires.assembled()` … `pack_5_alliances.assembled()`:
## one set, one entry per name — the first printing listed — asked of
## Scryfall by name and set.
static func _names(number: int, row: Dictionary, source: String) -> Dictionary:
	var code := String((row["sets"] as Array)[0])
	var rows: Variant = _read(source + "cards.json")
	if not (rows is Array):
		return _refusal("the game's own copy of Pack %d's cards.json is missing" % number)
	var first := {}
	var cards: Array = []
	for card: Variant in rows:
		if not _is_card(card) or String(card["set"]) != code:
			return _refusal("Pack %d's cards.json holds a card of another set" % number)
		if not first.has(card["name"]):
			first[card["name"]] = card
			cards.append(card)
	var names := PackJson.sorted(first.keys())
	var added := names
	if number > 2:
		var reprints: Variant = _read(source + "reprint_names.json")
		if not (reprints is Array):
			return _refusal("the game's own copy of Pack %d's reprint_names.json is missing" % number)
		added = []
		for card_name: String in names:
			if not reprints.has(card_name):
				added.append(card_name)
	var counts := {"published_printings": rows.size(), "named_set_entries": cards.size(),
		"distinct_cards": cards.size(), "pack_card_entries": cards.size(),
		"reprint_entries": cards.size() - added.size(), "new_rules_identities": added.size()}
	var manifest: Variant = _read(source + "manifest.json")
	if not (manifest is Dictionary):
		return _refusal("the game's own copy of Pack %d's manifest.json is missing" % number)
	manifest["counts"] = counts
	manifest["new_rules_identities"] = added
	var set_block := {}
	set_block[code] = {"names": names, "named_cards": cards.size(),
		"published_printings": rows.size()}
	var catalog := {"pack_format": 1, "pack_id": "pack-%d" % number, "counts": counts,
		"sets": set_block}
	var prefix := "card_packs/%s/" % String(row["dir"])
	var with_fallback := {}
	for card_name: String in added:
		with_fallback[card_name] = true
	var jobs: Array = []
	var entries: Array = []
	for card: Dictionary in cards:
		var card_name := String(card["name"])
		if not _code_ok(code) or snake(card_name) == "":
			return _refusal("a Pack %d card the game cannot name a picture file for: %s" % [number, card_name])
		var wanted: Array = []
		for variant: Array in VARIANTS:
			var file := snake(card_name) + String(variant[0])
			var cached := code + "/" + file
			wanted.append([cached, String(variant[1])])
			entries.append([prefix + "art/" + cached, cached])
			if with_fallback.has(card_name):
				entries.append(["skin/cardart/" + file, cached])
		jobs.append({"name": card_name, "lookups": named_lookups(card_name, code),
			"set": code, "number": "", "files": wanted,
			"ask": {"name": card_name, "set": code}, "key": named_key(card_name, code)})
	return {"ok": true, "counts": counts, "manifest": manifest, "catalog": catalog,
		"cards": cards, "jobs": jobs, "entries": entries}


# --------------------------------------------------------- Packs 6–10 --

## `pack_6_portal.assembled()` … `pack_10_urza_block.assembled()`: every
## original numbered printing of one to three sets, each asked of Scryfall
## by the id its trusted row carries, so the picture is that printing's and
## no other's. A second printing of a name in its set is filed as
## `<name>__<collector number>`.
static func _printings(number: int, row: Dictionary, source: String) -> Dictionary:
	var codes: Array = row["sets"]
	var rows: Array = []
	for i in codes.size():
		var file := "cards.json" if i == 0 else "cards_%s.json" % String(codes[i])
		var part: Variant = _read(source + file)
		if not (part is Array):
			return _refusal("the game's own copy of Pack %d's %s is missing" % [number, file])
		rows.append_array(part)
	var first := {}
	var members := {}
	for code: String in codes:
		members[code] = {"names": {}, "printings": 0, "numbers": {}}
	for card: Variant in rows:
		if not _is_card(card) or not members.has(card["set"]) \
				or not (card.get("collector_number") is String) \
				or not (card.get("scryfall_id") is String):
			return _refusal("Pack %d's card lists hold a card of another set" % number)
		var of_set: Dictionary = members[card["set"]]
		of_set["names"][card["name"]] = true
		of_set["numbers"][card["collector_number"]] = true
		of_set["printings"] = int(of_set["printings"]) + 1
		if not first.has(card["name"]):
			first[card["name"]] = card
	var sets := {}
	var named_entries := 0
	for code: String in codes:
		var of_set: Dictionary = members[code]
		var printings := int(of_set["printings"])
		# Numbered 1 to N, each once: the original English set and nothing else.
		if (of_set["numbers"] as Dictionary).size() != printings:
			return _refusal("Pack %d's %s list repeats a collector number" % [number, code])
		for n in range(1, printings + 1):
			if not (of_set["numbers"] as Dictionary).has(str(n)):
				return _refusal("Pack %d's %s list is not numbered 1 to %d" % [number, code, printings])
		var set_names := PackJson.sorted((of_set["names"] as Dictionary).keys())
		named_entries += set_names.size()
		sets[code] = {"names": set_names, "named_cards": set_names.size(),
			"published_printings": printings}
	var reprints: Variant = _read(source + "reprint_names.json")
	if not (reprints is Array):
		return _refusal("the game's own copy of Pack %d's reprint_names.json is missing" % number)
	var added: Array = []
	for card_name: String in PackJson.sorted(first.keys()):
		if not reprints.has(card_name):
			added.append(card_name)
	var counts := {"published_printings": rows.size(), "named_set_entries": named_entries,
		"distinct_cards": first.size(), "pack_card_entries": rows.size(),
		"reprint_entries": named_entries - added.size(), "new_rules_identities": added.size()}
	var manifest: Variant = _read(source + "manifest.json")
	if not (manifest is Dictionary):
		return _refusal("the game's own copy of Pack %d's manifest.json is missing" % number)
	manifest["counts"] = counts
	manifest["new_rules_identities"] = added
	var catalog := {"pack_format": 1, "pack_id": "pack-%d" % number, "counts": counts,
		"sets": sets}
	# Whose first printing also travels as skin/cardart art.
	var with_fallback := {}
	var rule := String(row["fallback"])
	if rule.contains("new"):
		for card_name: String in added:
			with_fallback[card_name] = true
	if rule.contains("shared"):
		var shared: Variant = row.get("shared", null)
		if shared == null:
			shared = _read(source + "shared_names.json")
		# A list (Pack 6, in this file) or a table of name -> the set whose
		# script it shares (Packs 7-10): the names either way.
		if not (shared is Array or shared is Dictionary):
			return _refusal("the game's own copy of Pack %d's shared_names.json is missing" % number)
		for card_name: Variant in shared:
			with_fallback[String(card_name)] = true
	var prefix := "card_packs/%s/" % String(row["dir"])
	var jobs: Array = []
	var entries: Array = []
	var seen := {}
	var fallen := {}
	for card: Dictionary in rows:
		var code := String(card["set"])
		var card_name := String(card["name"])
		var collector := String(card["collector_number"])
		var scryfall_id := String(card["scryfall_id"])
		if not _code_ok(code) or snake(card_name) == "" or not collector.is_valid_int() \
				or not _id_ok(scryfall_id):
			return _refusal("a Pack %d card the game cannot name a picture file for: %s" % [number, card_name])
		var key := code + ":" + card_name
		var stem := snake(card_name) + ("__" + collector if seen.has(key) else "")
		seen[key] = true
		var wanted: Array = []
		for variant: Array in VARIANTS:
			var file := stem + String(variant[0])
			var cached := code + "/" + file
			wanted.append([cached, String(variant[1])])
			entries.append([prefix + "art/" + cached, cached])
			if with_fallback.has(card_name) and not fallen.has(card_name):
				entries.append(["skin/cardart/" + file, cached])
		fallen[card_name] = true
		jobs.append({"name": card_name, "lookups": [BY_ID + scryfall_id],
			"set": code, "number": collector, "files": wanted,
			"ask": {"id": scryfall_id}, "key": id_key(scryfall_id)})
	return {"ok": true, "counts": counts, "manifest": manifest, "catalog": catalog,
		"cards": rows, "jobs": jobs, "entries": entries}


# ------------------------------------------------------------- helpers --

static func _refusal(why: String) -> Dictionary:
	return {"ok": false, "why": why}


## The counts a pack's own contract in the game holds.
static func _contract_counts(number: int) -> Dictionary:
	match number:
		2: return FallenEmpiresPack.COUNTS
		3: return IceAgePack.COUNTS
		4: return HomelandsPack.COUNTS
		5: return AlliancesPack.COUNTS
		6: return PortalPack.COUNTS
		7: return FifthEditionPack.COUNTS
		8: return MirageBlockPack.COUNTS
		9: return TempestBlockPack.COUNTS
		10: return UrzaBlockPack.COUNTS
	return DOTP_COUNTS


static func _is_card(row: Variant) -> bool:
	return row is Dictionary and row.get("name") is String and row.get("set") is String \
		and String(row["name"]) != ""


## A set code is two to five lower-case letters or digits: it names a folder.
static func _code_ok(code: String) -> bool:
	if code.length() < 2 or code.length() > 5:
		return false
	for character in code:
		var point := character.unicode_at(0)
		if not ((point >= 97 and point <= 122) or (point >= 48 and point <= 57)):
			return false
	return true


## A Scryfall id is 36 characters of lower-case hex and hyphens: it goes
## into a URL.
static func _id_ok(value: String) -> bool:
	if value.length() != 36:
		return false
	for character in value:
		var point := character.unicode_at(0)
		if not ((point >= 97 and point <= 102) or (point >= 48 and point <= 57) or point == 45):
			return false
	return true


static func _unique_names(rows: Array) -> Array:
	var seen := {}
	var out: Array = []
	for row: Variant in rows:
		if row is Dictionary and row.get("name") is String and not seen.has(row["name"]):
			seen[row["name"]] = true
			out.append(String(row["name"]))
	return out


## A trusted JSON file of this build, parsed; null when it is not there or
## is not JSON.
static func _read(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path) if _there(path) else _own(path)
	var json := JSON.new()
	if text == "" or json.parse(text) != OK:
		return null
	return json.data


## A trusted text file's bytes as Python reads and writes them: every line
## end a single newline.
static func _file_bytes(path: String) -> PackedByteArray:
	var text := FileAccess.get_file_as_bytes(path).get_string_from_utf8() if _there(path) \
		else _own(path)
	return text.replace("\r\n", "\n").replace("\r", "\n").to_utf8_buffer()


## The `.json` files of a folder of this build, in name order.
static func _json_files_in(folder: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(folder.trim_suffix("/"))
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.get_extension() == "json":
			out.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return PackJson.sorted(out)


# ------------------------------------------------- Pack 1's own copy --

## PACK 1'S THREE TRUSTED FILES, CARRIED IN THE SCRIPT. Their folder,
## `packaging/card_packs/pack_1_dotp_complete/`, holds a `.gdignore` (the
## Python tool once kept its downloads there), and an export passes over
## such a folder whatever its filters say: no exported game has ever held
## these files, so no exported game could build Pack 1. The files are small
## and settled; here they are, line for line, and they are read only where
## the build does not carry the file itself ([method _own]). A checkout
## reads the files, and `test_c1123_pack_export.gd` holds these to them
## byte for byte, so a change to one that forgets the other fails there.
const PACK_ONE_MANIFEST := "{\n" \
	+ "  \"pack_format\": 1,\n" \
	+ "  \"id\": \"pack-1\",\n" \
	+ "  \"number\": 1,\n" \
	+ "  \"name\": \"DotP Complete\",\n" \
	+ "  \"file_name\": \"Pack-1-DotP-complete.zip\",\n" \
	+ "  \"version\": \"1.0.0\",\n" \
	+ "  \"minimum_game_version\": \"0.20.0\",\n" \
	+ "  \"set_order\": [\"2ed\", \"arn\", \"atq\", \"leg\", \"drk\", \"4ed\", \"past\", \"phpr\"],\n" \
	+ "  \"description\": \"Adds the 373 named set entries missing from the default pool: 369 cross-set reprints and four new rules identities, completing all eight Duels of the Planeswalkers card-group checklists.\",\n" \
	+ "  \"rules_note\": \"Chaos Orb, Falling Star, Shahrazad, and Word of Command use clearly marked digital adaptations because their tabletop procedures cannot be reproduced faithfully in this duel interface. Reprints share one name-based rules identity and the same copy accounting.\"\n" \
	+ "}\n"

const PACK_ONE_MISSING := "[\n" \
	+ "  {\n" \
	+ "    \"name\": \"Chaos Orb\",\n" \
	+ "    \"mana_cost\": \"{2}\",\n" \
	+ "    \"type_line\": \"Artifact\",\n" \
	+ "    \"oracle_text\": \"{1}, {T}: If this artifact is on the battlefield, flip it onto the battlefield from a height of at least one foot. If this artifact turns over completely at least once during the flip, destroy all nontoken permanents it touches. Then destroy this artifact.\",\n" \
	+ "    \"power\": null,\n" \
	+ "    \"toughness\": null,\n" \
	+ "    \"keywords\": [],\n" \
	+ "    \"colors\": [],\n" \
	+ "    \"rarity\": \"rare\",\n" \
	+ "    \"collector_number\": \"236\",\n" \
	+ "    \"artist\": \"Mark Tedin\",\n" \
	+ "    \"set\": \"2ed\"\n" \
	+ "  },\n" \
	+ "  {\n" \
	+ "    \"name\": \"Word of Command\",\n" \
	+ "    \"mana_cost\": \"{B}{B}\",\n" \
	+ "    \"type_line\": \"Instant\",\n" \
	+ "    \"oracle_text\": \"Look at target opponent's hand and choose a card from it. You control that player until Word of Command finishes resolving. The player plays that card if able. While doing so, the player can activate mana abilities only if they're from lands that player controls and only if mana they produce is spent to activate other mana abilities of lands the player controls and/or to play that card. If the chosen card is cast as a spell, you control the player while that spell is resolving.\",\n" \
	+ "    \"power\": null,\n" \
	+ "    \"toughness\": null,\n" \
	+ "    \"keywords\": [],\n" \
	+ "    \"colors\": [\"B\"],\n" \
	+ "    \"rarity\": \"rare\",\n" \
	+ "    \"collector_number\": \"137\",\n" \
	+ "    \"artist\": \"Jesper Myrfors\",\n" \
	+ "    \"set\": \"2ed\"\n" \
	+ "  },\n" \
	+ "  {\n" \
	+ "    \"name\": \"Shahrazad\",\n" \
	+ "    \"mana_cost\": \"{W}{W}\",\n" \
	+ "    \"type_line\": \"Sorcery\",\n" \
	+ "    \"oracle_text\": \"Players play a Magic subgame, using their libraries as their decks. Each player who doesn't win the subgame loses half their life, rounded up.\",\n" \
	+ "    \"power\": null,\n" \
	+ "    \"toughness\": null,\n" \
	+ "    \"keywords\": [],\n" \
	+ "    \"colors\": [\"W\"],\n" \
	+ "    \"rarity\": \"rare\",\n" \
	+ "    \"collector_number\": \"10\",\n" \
	+ "    \"artist\": \"Kaja Foglio\",\n" \
	+ "    \"set\": \"arn\"\n" \
	+ "  },\n" \
	+ "  {\n" \
	+ "    \"name\": \"Falling Star\",\n" \
	+ "    \"mana_cost\": \"{2}{R}\",\n" \
	+ "    \"type_line\": \"Sorcery\",\n" \
	+ "    \"oracle_text\": \"Flip Falling Star onto the playing area from a height of at least one foot. Falling Star deals 3 damage to each creature it lands on. Tap all creatures dealt damage by Falling Star. If Falling Star doesn't turn completely over at least once during the flip, it has no effect.\",\n" \
	+ "    \"power\": null,\n" \
	+ "    \"toughness\": null,\n" \
	+ "    \"keywords\": [],\n" \
	+ "    \"colors\": [\"R\"],\n" \
	+ "    \"rarity\": \"rare\",\n" \
	+ "    \"collector_number\": \"145\",\n" \
	+ "    \"artist\": \"Douglas Shuler\",\n" \
	+ "    \"set\": \"leg\"\n" \
	+ "  }\n" \
	+ "]\n"

const PACK_ONE_README := "PACK 1 — DOTP COMPLETE\n" \
	+ "\n" \
	+ "Pack-1-DotP-complete.zip completes the eight card groups represented by\n" \
	+ "ShandalarGodot's set badges. It carries the full published checklist for\n" \
	+ "each group, including cards reprinted in more than one set.\n" \
	+ "\n" \
	+ "Pack 1 itself adds 373 named set entries: 369 cross-set reprints plus four\n" \
	+ "new rules identities. The enabled pool therefore reports 1,270 set entries\n" \
	+ "across the eight checklists, representing 901 unique rules identities. Reprints\n" \
	+ "still share one deck entry and the same name-based copy count. The pack catalog\n" \
	+ "also records all 1,305 published collector slots; the remaining 35 slots are\n" \
	+ "alternate-art printings of the same name inside the same set.\n" \
	+ "\n" \
	+ "Four distinct cards are absent from the default 897-card pool because\n" \
	+ "their printed procedures require dexterity, a subgame, or control of\n" \
	+ "another player. Pack 1 supplies bounded digital adaptations:\n" \
	+ "\n" \
	+ "  Chaos Orb       first flips a coin, then may destroy one random permanent.\n" \
	+ "  Falling Star    flips once for each of one or two chosen creatures.\n" \
	+ "  Shahrazad       resolves its half-life result with a coin flip.\n" \
	+ "  Word of Command becomes a targeted nonland discard choice.\n" \
	+ "\n" \
	+ "Every adapted card says \"Digital adaptation\" in its displayed rules text.\n" \
	+ "The exact deviations, reusable engine mechanics, and AI policies are recorded\n" \
	+ "in docs/pack-1-mechanics.md and docs/simplified-cards.md in the source tree.\n" \
	+ "The manifest records pack version, minimum game version, SHA-256 hashes for\n" \
	+ "the metadata, and one deterministic SHA-256 over all artwork. The game refuses\n" \
	+ "a corrupt or incompatible file and explains why under Options > Card Packs.\n" \
	+ "The finished ZIP carries an art crop and a full-card scan for every one of\n" \
	+ "its 373 set entries. Set-specific files live in the pack's own catalog;\n" \
	+ "the four new identities are also exposed through skin/cardart/ so the game\n" \
	+ "can display them immediately. The fetch-art command keeps downloads in the\n" \
	+ "sibling shandalar-packs cache, never in git.\n" \
	+ "\n" \
	+ "The finished ZIP is a local gameplay artifact and is not distributed in a\n" \
	+ "ShandalarGodot release. The source repository distributes this construction\n" \
	+ "tool and its inputs instead.\n" \
	+ "\n" \
	+ "Build or verify this pack with the dedicated tool:\n" \
	+ "\n" \
	+ "  python3 tools/pack_1_dotp_complete.py fetch-art\n" \
	+ "  python3 tools/pack_1_dotp_complete.py\n" \
	+ "  python3 tools/pack_1_dotp_complete.py verify\n" \
	+ "\n" \
	+ "Card names and rules text are Wizards of the Coast material. Set and card\n" \
	+ "metadata are obtained through Scryfall's public API and remain subject to\n" \
	+ "their respective owners' terms. No card artwork is committed to the source\n" \
	+ "repository; the local build command places the fetched images in this ZIP.\n"
const PACK_ONE_OWN := {"manifest.json": PACK_ONE_MANIFEST,
	"missing_cards.json": PACK_ONE_MISSING, "README.txt": PACK_ONE_README}
