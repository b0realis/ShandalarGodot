class_name CommunityCards
extends RefCounted
## THE COMMUNITY CARDS — cards players make in the card creator
## ([CardForgeScreen]) and share as zips: one card a zip, `card.json`, its
## set icon and its art under one top folder, data only ([CommunityCard]
## builds it; [PluginPackage] reads it, nothing in it is ever loaded as a
## resource or run). Found in `community_cards/` in the game's data folder
## and beside the game; the first copy of a name wins. Shown as the `comm`
## set ([constant CommunityCard.SET_CODE]) in the Deck Builder and duels.
##
## THE TWO PICTURES follow guidelines, checked when chosen in the creator
## and again when a zip is read, so no picture can upset the card:
## [constant ART_GUIDE] and [constant ICON_GUIDE] ([method art_problem],
## [method icon_problem]). The art is placed by the card's own crop —
## zoom and position over the art window's shape ([method crop_region]).

const FOLDER := "community_cards"
const MANIFEST := "card.json"
## A SET ZIP: many cards in one, each in its own folder under the top one,
## listed by `set.json` ([method write_set_zip]); read like single zips.
const SET_MANIFEST := "set.json"
const SET_FORMAT := "shandalar-community-set"
const SET_MAX_CARDS := 150
const ART_NAMES: Array[String] = ["art.png", "art.jpg", "art.webp"]
const ICON_NAMES: Array[String] = ["icon.png", "icon.webp"]
## THE FOUR SET ICONS a card may give, by the game's own set symbol tiers
## ([method GameSkin.set_symbol_tier]: a mythic or a legendary card wears
## the legendary one) — `icon_common.png` and the like. A card's icon is
## ONE picture (`icon.png`, every rarity) or a picture for each of some
## tiers; a rarity without its own wears the first one given, in this
## order ([method icon_for_tier]).
const ICON_TIERS: Array[String] = ["common", "uncommon", "rare", "legendary"]

## The art window of the large card is 255 by 198 (9:7).
const ART_ASPECT := 255.0 / 198.0
const ART_GUIDE := {"kinds": ["png", "jpg", "webp"], "min": Vector2i(255, 198),
	"ideal": Vector2i(765, 594), "max": Vector2i(2040, 1584), "bytes": 4 * 1024 * 1024,
	"aspect": [1.1, 1.5]}
const ICON_GUIDE := {"kinds": ["png", "webp"], "min": 32, "ideal": 64, "max": 128,
	"bytes": 64 * 1024, "aspect": [0.9, 1.1]}
## What the creator shows of the guidelines.
const ART_WORDS := "Art: PNG, JPG or WEBP, 9:7 like the card's art window (best 765 x 594 pixels; " \
	+ "from 255 x 198 to 2040 x 1584), at most 4 MB. Zoom and position it on the Look page."
const ICON_WORDS := "Set icon: a square PNG or WEBP with a transparent background, 32 to 128 " \
	+ "pixels a side (best 64 x 64), at most 64 KB. It is printed at the right of the type line."

## Tests: the folders to look in; empty asks the game.
static var folders_override: Array[String] = []

## Every card found: `{name, path, spec, problems: []}`, by the order found.
## Plain data (the registry's rule: no [CardData]).
static var _rows: Array[Dictionary] = []
static var _scanned := false
## name → its playable row (the lookups of every tooltip and deck).
static var _by_name: Dictionary = {}
## name → {art: {bytes, kind}, icon: {bytes, kind}}, and the textures made.
static var _files: Dictionary = {}
static var _textures: Dictionary = {}
## name → the zip it was read from, as path|modified|size: a texture made
## for a card is kept over a scan while its zip stays the same.
static var _stamps: Dictionary = {}
## THE SCAN'S MEMORY: path → {key, rows} — each zip's rows as read, kept
## while its key (modified time, size, and each entry's name, size and
## CRC-32 from the zip's own list) stays the same, so a scan after a Save
## reads again only the zip that changed. The rows are copied out, never
## handed over (the scan marks second copies on its copy).
static var _read_cache: Dictionary = {}
## THE DRAFT: the card the creator is making, shown live before it is
## saved — its spec and pictures answer for its name ([method set_draft]).
static var _draft: Dictionary = {}
static var _draft_art: Texture2D = null
static var _draft_icons: Dictionary = {}


# ------------------------------------------------------------ the places --

## The player's own folder, where the creator saves.
static func own_folder() -> String:
	return "user://" + FOLDER


static func folders() -> Array[String]:
	if not folders_override.is_empty():
		return folders_override.duplicate()
	var out: Array[String] = [own_folder()]
	if not OS.has_feature("web"):
		var beside := GamePaths.android_files_dir()
		if beside == "":
			beside = GamePaths.executable_dir(OS.get_executable_path(), OS.has_feature("macos"))
		out.append(beside.path_join(FOLDER))
	return out


static func ensure_own_folder() -> String:
	var dir := ProjectSettings.globalize_path(own_folder())
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


# -------------------------------------------------------------- the scan --

## Look in the folders again; the registry builds the cards at its next
## load ([method configure]).
static func scan() -> void:
	_rows.clear()
	_files.clear()
	_by_name.clear()
	# Only the zips still there are remembered past this scan.
	var cache := {}
	var old_stamps := _stamps
	_stamps = {}
	# Names are told apart regardless of case ("Elf Lord" and "ELF LORD").
	var seen := {}
	for folder in folders():
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		var names := Array(dir.get_files())
		names.sort()
		# Single-card zips first: a card saved alone (edited from a set)
		# is the copy that plays, the set's own is then "found first".
		var singles: Array[String] = []
		var sets: Array[String] = []
		for name in names:
			if String(name).get_extension().to_lower() != "zip" or String(name).begins_with("."):
				continue
			var path := String(folder).path_join(name)
			if is_set_zip(path):
				sets.append(path)
			else:
				singles.append(path)
		for path in singles + sets:
			for row in _rows_of(path, sets.has(path), cache):
				var card := String(row["name"])
				if (row["problems"] as Array).is_empty() and seen.has(card.to_lower()):
					row["problems"] = ["A card named %s was found first in %s." % [card,
						GamePaths.shown(String(seen[card.to_lower()]))]] as Array[String]
					# Whole, but behind the copy that plays (said as data).
					row["shadowed"] = true
				if (row["problems"] as Array).is_empty():
					seen[card.to_lower()] = row["path"]
					_files[card] = row["files"]
					_by_name[card] = row
					_stamps[card] = "%s|%d|%d" % [path, FileAccess.get_modified_time(path), _size_of(path)]
				row.erase("files")
				_rows.append(row)
	_read_cache = cache
	# The textures of a card whose zip changed (or went) are made again.
	for key in _textures.keys():
		var card := String(key).get_slice("|", 1)
		if not _stamps.has(card) or old_stamps.get(card, "") != _stamps[card]:
			_textures.erase(key)
	_scanned = true


## The rows of the zip at [param path] — read again only when its key
## changed since the last scan ([member _read_cache]); copies either way.
static func _rows_of(path: String, as_set: bool, cache: Dictionary) -> Array[Dictionary]:
	var key := _zip_key(path)
	var kept: Dictionary = _read_cache.get(path, {})
	var rows: Array[Dictionary] = []
	if key != "" and String(kept.get("key", "")) == key:
		rows.assign(kept["rows"])
	else:
		if as_set:
			rows = read_set(path)
		else:
			rows.append(read(path))
	if key != "":
		cache[path] = {"key": key, "rows": rows}
	var out: Array[Dictionary] = []
	for row in rows:
		var copy := row.duplicate()
		copy["problems"] = (row["problems"] as Array).duplicate()
		out.append(copy)
	return out


## What tells a zip apart from its last scan ("" when it can't be read).
static func _zip_key(path: String) -> String:
	var listed := PluginPackage.zip_entries(path)
	if String(listed["problem"]) != "":
		return ""
	var parts: Array[String] = ["%d|%d" % [FileAccess.get_modified_time(path), _size_of(path)]]
	for entry: Dictionary in listed["entries"]:
		parts.append("%s:%d:%d" % [entry["name"], int(entry["size"]), int(entry.get("crc", 0))])
	return "|".join(parts)


static func _size_of(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return int(file.get_length()) if file != null else -1


static func _ensure() -> void:
	if not _scanned:
		scan()


## One card's zip, read and checked: its row (`files` the pictures).
static func read(path: String) -> Dictionary:
	var row := {"name": path.get_file().get_basename(), "path": path, "spec": {},
		"problems": [] as Array[String], "files": {}}
	var problems: Array[String] = row["problems"]
	var listed := _entries_problem(path, false)
	if listed != "":
		problems.append(listed)
		return row
	var package := PluginPackage.read(path, MANIFEST)
	for p in package["problems"]:
		problems.append(String(p))
	if not problems.is_empty():
		return row
	return _card_row(row, package["files"])


## Whether the zip at [param path] is a set zip (a `set.json` in its top
## folder) — read from the zip's own list of entries, nothing inflated.
static func is_set_zip(path: String) -> bool:
	var listed := PluginPackage.zip_entries(path)
	if String(listed["problem"]) != "":
		return false
	for entry: Dictionary in listed["entries"]:
		var parts := String(entry["name"]).split("/")
		if parts.size() == 2 and parts[1] == SET_MANIFEST:
			return true
	return false


## THE ZIP'S OWN LIST held to a card's files, before anything is inflated
## ("" when fine): only `card.json`, one art and one icon (a set: `set.json`
## and those in each card's folder), each no bigger than such a file may
## be — a picture padded past its size, a stray file or a set smuggled into
## a card zip is refused here.
static func _entries_problem(path: String, as_set: bool) -> String:
	var listed := PluginPackage.zip_entries(path)
	if String(listed["problem"]) != "":
		return String(listed["problem"])
	for entry: Dictionary in listed["entries"]:
		var name := String(entry["name"])
		if name.ends_with("/"):
			continue
		var parts := name.split("/")
		if Array(parts).any(func(part: String) -> bool: return part != "" and PluginPackage.ignored(part)):
			continue
		var file := parts[parts.size() - 1]
		var depth := 2 if file == SET_MANIFEST or not as_set else 3
		var limit := _limit_of(file)
		if parts.size() != depth or limit < 0 or (file == SET_MANIFEST) != (as_set and depth == 2):
			return "%s: a card zip holds only card.json, its art and its set icons%s." % [name,
				" (a set zip: set.json and a folder a card)" if as_set else ""]
		if int(entry["size"]) > limit:
			return "%s is bigger than a card's file may be." % name
	return ""


## The most bytes a card's file may hold (-1: no file of a card).
static func _limit_of(file: String) -> int:
	if file == MANIFEST or file == SET_MANIFEST:
		return 256 * 1024
	if file in ART_NAMES:
		return int(ART_GUIDE["bytes"])
	if is_icon_file(file):
		return int(ICON_GUIDE["bytes"])
	return -1


## A set zip's cards, read and checked one by one: a row each (one refused
## row for the whole zip when the zip itself is wrong). Every card is held
## to the very checks a single zip is.
static func read_set(path: String) -> Array[Dictionary]:
	var whole := {"name": path.get_file().get_basename(), "path": path, "spec": {},
		"problems": [] as Array[String], "files": {}, "set": true}
	var problems: Array[String] = whole["problems"]
	var listed := _entries_problem(path, true)
	if listed != "":
		problems.append(listed)
		return [whole]
	var package := PluginPackage.read(path, SET_MANIFEST)
	for p in package["problems"]:
		problems.append(String(p))
	if not problems.is_empty():
		return [whole]
	var files: Dictionary = package["files"]
	var parsed := PluginPackage.json(SET_MANIFEST, files[SET_MANIFEST])
	var manifest: Variant = parsed["value"]
	if String(parsed["problem"]) != "":
		problems.append(String(parsed["problem"]))
	elif not manifest is Dictionary or manifest.get("format") != SET_FORMAT \
			or not manifest.get("cards") is Array or (manifest["cards"] as Array).size() > SET_MAX_CARDS \
			or not (manifest["cards"] as Array).all(func(f: Variant) -> bool:
				return f is String and f != "" and not (f as String).contains("/") and (f as String).length() <= 60):
		problems.append("%s is not a set of community cards (at most %d)." % [SET_MANIFEST, SET_MAX_CARDS])
	if not problems.is_empty():
		return [whole]
	var rows: Array[Dictionary] = []
	var folders_seen := {}
	var names_seen := {}
	for folder in manifest["cards"]:
		# The zip never holds two folders differing by case alone (its
		# reader refuses them), so a folder listed twice is the same name.
		if folders_seen.has(String(folder)):
			rows.append({"name": String(folder), "path": path, "spec": {}, "files": {}, "set": true,
				"problems": ["%s is listed twice in %s." % [folder, SET_MANIFEST]] as Array[String]})
			continue
		folders_seen[String(folder)] = true
		var own := {}
		for rel in files:
			var at := String(rel)
			if at.begins_with(String(folder) + "/") and at.count("/") == 1:
				own[at.get_file()] = files[rel]
		var row := {"name": String(folder), "path": path, "spec": {}, "problems": [] as Array[String],
			"files": {}, "set": true}
		if not own.has(MANIFEST):
			(row["problems"] as Array).append("%s/%s is missing." % [folder, MANIFEST])
			rows.append(row)
			continue
		var read_row := _card_row(row, own)
		var lower := String(read_row["name"]).to_lower()
		if (read_row["problems"] as Array).is_empty() and names_seen.has(lower):
			(read_row["problems"] as Array).append("Two cards of the set are named %s." % read_row["name"])
		names_seen[lower] = true
		rows.append(read_row)
	return rows


## [param row] filled from one card's [param files] (`card.json`, its
## pictures): the spec checked, the pictures held to the guidelines.
static func _card_row(row: Dictionary, files: Dictionary) -> Dictionary:
	var problems: Array[String] = row["problems"]
	var parsed := PluginPackage.json(MANIFEST, files[MANIFEST])
	if String(parsed["problem"]) != "":
		problems.append(String(parsed["problem"]))
		return row
	var spec: Variant = parsed["value"]
	problems.append_array(CommunityCard.problems(spec))
	if not problems.is_empty():
		return row
	row["spec"] = spec
	row["name"] = String(spec["name"]).strip_edges()
	var pictures := {}
	for art in ART_NAMES:
		if files.has(art):
			var why := art_problem(files[art], art.get_extension())
			if why != "":
				problems.append(why)
			pictures["art"] = {"bytes": files[art], "kind": art.get_extension()}
			break
	var one := {}
	for icon in ICON_NAMES:
		if files.has(icon):
			var why := icon_problem(files[icon], icon.get_extension())
			if why != "":
				problems.append(why)
			one = {"bytes": files[icon], "kind": icon.get_extension()}
			break
	var tiers := {}
	for file in files:
		var tier := icon_tier_of(String(file))
		if tier != "" and not tiers.has(tier):
			var why := icon_problem(files[file], String(file).get_extension())
			if why != "":
				problems.append(why)
			tiers[tier] = {"bytes": files[file], "kind": String(file).get_extension()}
	# An icon.png beside tier icons serves the rarities without their own.
	if not one.is_empty() and not tiers.is_empty() and not tiers.has(ICON_TIERS[0]):
		tiers[ICON_TIERS[0]] = one
	if not tiers.is_empty():
		pictures["icon"] = icon_pack(tiers)
	elif not one.is_empty():
		pictures["icon"] = one
	if not pictures.has("icon"):
		problems.append("The set icon is missing (icon.png or icon.webp, or icon_common.png and the like).")
	row["files"] = pictures
	return row


## THE EXAMPLE CARDS shipped with the game (`game/community_examples/`),
## read like any zip: shown in the creator's Open list to start from, never
## in the pool until the player saves one.
const EXAMPLES := "res://game/community_examples"


static func examples() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var names := Array(DirAccess.get_files_at(EXAMPLES))
	names.sort()
	for name in names:
		if String(name).get_extension().to_lower() == "zip":
			var row := read(EXAMPLES.path_join(name))
			if (row["problems"] as Array).is_empty():
				out.append(row)
	return out


## Every card found, refused ones too.
static func all() -> Array[Dictionary]:
	_ensure()
	return _rows.duplicate()


static func playable() -> Array[Dictionary]:
	_ensure()
	return _rows.filter(func(row: Dictionary) -> bool: return (row["problems"] as Array).is_empty())


## Hand the cards to the registry for its next load.
static func configure() -> void:
	_ensure()
	var specs: Array = []
	var records: Array = []
	for row in playable():
		var spec: Dictionary = row["spec"]
		specs.append(spec)
		records.append({"name": row["name"], "set": CommunityCard.SET_CODE,
			"rarity": String(spec.get("rarity", "common")), "artist": String(spec.get("artist", ""))})
	CardRegistry.configure_community(specs, records)


## The spec of the community card [param card_name] ({} when none) — the
## card being made first.
static func spec_of(card_name: String) -> Dictionary:
	if _is_draft(card_name):
		return _draft
	_ensure()
	var row: Dictionary = _by_name.get(card_name, {})
	return row.get("spec", {})


## The SAVED spec of [param card_name], never the card being made ({} when
## none) — what plays at a LAN table.
static func saved_spec(card_name: String) -> Dictionary:
	_ensure()
	return (_by_name.get(card_name, {}) as Dictionary).get("spec", {})


static func _is_draft(card_name: String) -> bool:
	return not _draft.is_empty() and String(_draft.get("name", "")).strip_edges() == card_name


## Whether [param card_name] is a community card in play — the card being
## made, or one the registry took (a zip named like a game card is not).
static func is_community(card_name: String) -> bool:
	if _is_draft(card_name):
		return true
	return not spec_of(card_name).is_empty() and CardRegistry.has_community(card_name)


## Whether a card named [param card_name] was found in a folder (the
## card being made not counted).
static func found(card_name: String) -> bool:
	_ensure()
	return _by_name.has(card_name)


## Where [param card_name] is saved in the own folder ("" when it is not
## there) — the zip it was read from, whatever that zip is called.
static func own_path_of(card_name: String) -> String:
	_ensure()
	var row: Dictionary = _by_name.get(card_name, {})
	if row.is_empty():
		return ""
	# A card of a set zip is never saved over alone (the set would go).
	if row.get("set", false):
		return ""
	var path := ProjectSettings.globalize_path(String(row["path"]))
	return path if path.begins_with(ProjectSettings.globalize_path(own_folder())) else ""


## The art and icon bytes of a found card: `{art: {bytes, kind}, icon: …}`.
static func files_of(card_name: String) -> Dictionary:
	_ensure()
	return _files.get(card_name, {})


# ---------------------------------------------------------- the pictures --

## Why [param bytes] cannot be a card's art ("" when it can).
static func art_problem(bytes: PackedByteArray, kind: String) -> String:
	kind = "jpg" if kind.to_lower() == "jpeg" else kind.to_lower()
	if not (ART_GUIDE["kinds"] as Array).has(kind):
		return "The art is a PNG, JPG or WEBP picture."
	if bytes.size() > int(ART_GUIDE["bytes"]):
		return "The art is at most 4 MB (this one is %s)." % PortableMode.size_words(bytes.size())
	var size := picture_size(bytes, kind)
	if size.x <= 0 or size.y <= 0:
		return "The art could not be read as a %s picture." % kind.to_upper()
	var low: Vector2i = ART_GUIDE["min"]
	var high: Vector2i = ART_GUIDE["max"]
	if size.x < low.x or size.y < low.y or size.x > high.x or size.y > high.y:
		return "The art is %d x %d pixels; it must be from %d x %d to %d x %d." % [
			size.x, size.y, low.x, low.y, high.x, high.y]
	var aspect := float(size.x) / size.y
	if aspect < float(ART_GUIDE["aspect"][0]) or aspect > float(ART_GUIDE["aspect"][1]):
		return "The art is %d x %d: its shape must be near 9:7 (best 765 x 594)." % [size.x, size.y]
	return ""


## Whether [param file] is a card's set icon: `icon.png`, or one of the
## tiers' (`icon_rare.webp`).
static func is_icon_file(file: String) -> bool:
	return ICON_NAMES.has(file) or icon_tier_of(file) != ""


## The tier of the icon file [param file] ("" when it is none of theirs).
static func icon_tier_of(file: String) -> String:
	for tier in ICON_TIERS:
		for kind in ICON_GUIDE["kinds"]:
			if file == "icon_%s.%s" % [tier, kind]:
				return tier
	return ""


## A card's icon as tiers: one picture is the common one (and so every
## rarity's), a set of tiers is kept as given.
static func icon_tiers(icon: Dictionary) -> Dictionary:
	if icon.has("bytes"):
		return {ICON_TIERS[0]: icon}
	var out := {}
	for tier in ICON_TIERS:
		if icon.get(tier) is Dictionary and (icon[tier] as Dictionary).has("bytes"):
			out[tier] = icon[tier]
	return out


## The picture a card of [param tier] wears: its own, else the first given
## (common, uncommon, rare, legendary) — one icon alone is every rarity's.
## A "mythic" tier is the legendary one.
static func icon_for_tier(icon: Dictionary, tier: String) -> Dictionary:
	var tiers := icon_tiers(icon)
	var own := "legendary" if tier == "mythic" else tier
	if tiers.has(own):
		return tiers[own]
	for each in ICON_TIERS:
		if tiers.has(each):
			return tiers[each]
	return {}


## Tiers as a card keeps them: one picture when only one is given (so a
## card of one icon is written as every card was, `icon.png`).
static func icon_pack(tiers: Dictionary) -> Dictionary:
	var given := icon_tiers(tiers)
	if given.size() == 1:
		return given.values()[0]
	return given


## Every picture of a card's icon.
static func icon_pictures(icon: Dictionary) -> Array:
	return icon_tiers(icon).values()


## Why [param icon] cannot be a card's ("" when it can): at least one
## picture, each following the guidelines.
static func icons_problem(icon: Dictionary) -> String:
	var tiers := icon_tiers(icon)
	if tiers.is_empty():
		return "Choose the set icon first."
	for tier in tiers:
		var why := icon_problem(tiers[tier]["bytes"], String(tiers[tier]["kind"]))
		if why != "":
			return why
	return ""


## A card's icon as zip entries: `icon.png` for one, `icon_<tier>.png`
## for each of several.
static func icon_entries(icon: Dictionary) -> Array:
	var packed := icon_pack(icon)
	if packed.has("bytes"):
		return [["icon." + String(packed["kind"]).to_lower(), packed["bytes"]]]
	var out := []
	for tier in ICON_TIERS:
		if packed.has(tier):
			out.append(["icon_%s.%s" % [tier, String(packed[tier]["kind"]).to_lower()], packed[tier]["bytes"]])
	return out


## Why [param bytes] cannot be a set icon ("" when it can).
static func icon_problem(bytes: PackedByteArray, kind: String) -> String:
	kind = kind.to_lower()
	if not (ICON_GUIDE["kinds"] as Array).has(kind):
		return "The set icon is a PNG or WEBP picture."
	if bytes.size() > int(ICON_GUIDE["bytes"]):
		return "The set icon is at most 64 KB (this one is %s)." % PortableMode.size_words(bytes.size())
	var size := picture_size(bytes, kind)
	if size.x <= 0 or size.y <= 0:
		return "The set icon could not be read as a %s picture." % kind.to_upper()
	var w := size.x
	var h := size.y
	if w < int(ICON_GUIDE["min"]) or h < int(ICON_GUIDE["min"]) \
			or w > int(ICON_GUIDE["max"]) or h > int(ICON_GUIDE["max"]):
		return "The set icon is %d x %d pixels; it must be 32 to 128 a side (best 64 x 64)." % [w, h]
	var aspect := float(w) / h
	if aspect < float(ICON_GUIDE["aspect"][0]) or aspect > float(ICON_GUIDE["aspect"][1]):
		return "The set icon is %d x %d: it must be square." % [w, h]
	return ""


## A picture's size read from its header, without decoding it (the scan
## checks every zip's pictures at each start): (-1, -1) when the header is
## not that of a [param kind] picture. A header that lies still fails
## safely when the picture is decoded to be shown.
static func picture_size(bytes: PackedByteArray, kind: String) -> Vector2i:
	var none := Vector2i(-1, -1)
	if not _signed_as(bytes, kind):
		return none
	match kind.to_lower():
		"png":
			if bytes.size() < 24 or bytes.slice(12, 16).get_string_from_ascii() != "IHDR":
				return none
			return Vector2i(_be32(bytes, 16), _be32(bytes, 20))
		"webp":
			if bytes.size() < 30:
				return none
			match bytes.slice(12, 16).get_string_from_ascii():
				"VP8X":
					return Vector2i(1 + _le24(bytes, 24), 1 + _le24(bytes, 27))
				"VP8 ":
					if bytes[23] != 0x9D or bytes[24] != 0x01 or bytes[25] != 0x2A:
						return none
					return Vector2i((bytes[26] | (bytes[27] << 8)) & 0x3FFF, (bytes[28] | (bytes[29] << 8)) & 0x3FFF)
				"VP8L":
					if bytes[20] != 0x2F:
						return none
					var b1 := bytes[22]
					return Vector2i(1 + (bytes[21] | ((b1 & 0x3F) << 8)),
						1 + (((b1 & 0xC0) >> 6) | (bytes[23] << 2) | ((bytes[24] & 0x0F) << 10)))
			return none
		"jpg", "jpeg":
			var i := 2
			var guard := 0
			while i + 9 < bytes.size() and guard < 4096:
				guard += 1
				if bytes[i] != 0xFF:
					return none
				var marker := bytes[i + 1]
				if marker == 0xFF:
					i += 1
					continue
				if marker >= 0xC0 and marker <= 0xCF and marker not in [0xC4, 0xC8, 0xCC]:
					return Vector2i((bytes[i + 7] << 8) | bytes[i + 8], (bytes[i + 5] << 8) | bytes[i + 6])
				if marker == 0x01 or (marker >= 0xD0 and marker <= 0xD8):
					i += 2
					continue
				i += 2 + ((bytes[i + 2] << 8) | bytes[i + 3])
			return none
	return none


static func _be32(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]


static func _le24(bytes: PackedByteArray, at: int) -> int:
	return bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16)


static func image_from(bytes: PackedByteArray, kind: String) -> Image:
	if bytes.is_empty() or not _signed_as(bytes, kind):
		return null
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match kind.to_lower():
		"png": err = image.load_png_from_buffer(bytes)
		"jpg", "jpeg": err = image.load_jpg_from_buffer(bytes)
		"webp": err = image.load_webp_from_buffer(bytes)
	return image if err == OK and not image.is_empty() else null


## Whether [param bytes] begin as a [param kind] picture does — a file
## that does not is refused before the decoder sees it.
static func _signed_as(bytes: PackedByteArray, kind: String) -> bool:
	if bytes.size() < 12:
		return false
	match kind.to_lower():
		"png":
			return bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
		"jpg", "jpeg":
			return bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF
		"webp":
			return bytes.slice(0, 4).get_string_from_ascii() == "RIFF" \
				and bytes.slice(8, 12).get_string_from_ascii() == "WEBP"
	return false


static func texture_from(bytes: PackedByteArray, kind: String) -> Texture2D:
	var image := image_from(bytes, kind)
	return ImageTexture.create_from_image(image) if image != null else null


## THE CROP: the part of a [param size] picture the art window shows —
## the window's own 9:7 shape, cut [param zoom] times closer (1 to 3), its
## corner at [param x], [param y] of the room left over (0 to 1; a half
## each is the middle).
static func crop_region(size: Vector2, zoom: float, x: float, y: float) -> Rect2:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return Rect2()
	var cut := Vector2(h * ART_ASPECT, h) if w / h > ART_ASPECT else Vector2(w, w / ART_ASPECT)
	cut /= clampf(zoom, 1.0, 3.0)
	var room := Vector2(w, h) - cut
	return Rect2(Vector2(room.x * clampf(x, 0.0, 1.0), room.y * clampf(y, 0.0, 1.0)), cut)


## The card's own crop, from its spec.
static func crop_of(spec: Dictionary) -> Dictionary:
	var look: Variant = spec.get("look", {})
	var art: Variant = look.get("art", {}) if look is Dictionary else {}
	if not art is Dictionary:
		art = {}
	return {"zoom": float(art.get("zoom", 1.0)), "x": float(art.get("x", 0.5)), "y": float(art.get("y", 0.5))}


## [param picture] cut by [param spec]'s crop.
static func cropped(picture: Texture2D, spec: Dictionary) -> Texture2D:
	if picture == null:
		return null
	var crop := crop_of(spec)
	var atlas := AtlasTexture.new()
	atlas.atlas = picture
	atlas.region = crop_region(picture.get_size(), crop["zoom"], crop["x"], crop["y"])
	return atlas


## The art of [param card_name], cut by its crop (null when none).
static func art_texture(card_name: String) -> Texture2D:
	if _is_draft(card_name):
		return cropped(_draft_art, _draft)
	_ensure()
	var key := "art|" + card_name
	if not _textures.has(key):
		var art: Dictionary = (_files.get(card_name, {}) as Dictionary).get("art", {})
		var raw := texture_from(art["bytes"], String(art["kind"])) if not art.is_empty() else null
		_textures[key] = cropped(raw, spec_of(card_name))
	return _textures[key]


## The art of [param card_name] when it is made already (null when it is
## not: nothing is decoded here) — for a list that fills its art later.
static func made_art(card_name: String) -> Texture2D:
	if _is_draft(card_name):
		return null
	return _textures.get("art|" + card_name)


## [param card_name]'s set icon for the set symbol [param tier] (common,
## uncommon, rare or legendary — [method GameSkin.set_symbol_tier]), the
## creator's own picture ([method icon_for_tier]).
static func icon_texture(card_name: String, tier := "") -> Texture2D:
	if _is_draft(card_name):
		var own := "legendary" if tier == "mythic" else tier
		if _draft_icons.has(own):
			return _draft_icons[own]
		for each in ICON_TIERS:
			if _draft_icons.has(each):
				return _draft_icons[each]
		return null
	_ensure()
	var tiers := icon_tiers((_files.get(card_name, {}) as Dictionary).get("icon", {}))
	var used := "legendary" if tier == "mythic" else tier
	if not tiers.has(used):
		used = ""
		for each in ICON_TIERS:
			if tiers.has(each):
				used = each
				break
	if used == "":
		return null
	var key := "icon|%s|%s" % [card_name, used]
	if not _textures.has(key):
		_textures[key] = texture_from(tiers[used]["bytes"], String(tiers[used]["kind"]))
	return _textures[key]


## The border color a card asked for.
static func border_color(card_name: String) -> Color:
	var look: Variant = spec_of(card_name).get("look", {})
	match String(look.get("border", "black")) if look is Dictionary else "black":
		"white": return Color8(236, 232, 222)
		"silver": return Color8(168, 172, 178)
	return Color8(12, 12, 12)


## The frame a card asked for ("auto" — its colors decide).
static func frame_of(card_name: String) -> String:
	var look: Variant = spec_of(card_name).get("look", {})
	return String(look.get("frame", "auto")) if look is Dictionary else "auto"


## The line a card's tooltip adds for a community card: its set's name.
static func tooltip_extra(data: CardData) -> String:
	if data == null or data.set_code != CommunityCard.SET_CODE:
		return ""
	var set_name := String(spec_of(data.card_name).get("set_name", "")).strip_edges()
	return "\nSet: %s (community card)" % set_name if set_name != "" else "\nCommunity card"


## Show [param spec] and its pictures as the card being made ([param
## icons]: tier → texture, the tiers given).
static func set_draft(spec: Dictionary, art: Texture2D, icons: Dictionary) -> void:
	_draft = spec.duplicate(true)
	_draft_art = art
	_draft_icons = icons.duplicate()


static func clear_draft() -> void:
	_draft = {}
	_draft_art = null
	_draft_icons = {}


# ---------------------------------------------------- saving and sharing --

## A file name for [param card_name]: letters, digits and _ only.
static func file_name(card_name: String) -> String:
	var out := ""
	for ch in card_name.strip_edges():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_").to_lower()


## Write [param spec], its art and its icon (`{bytes, kind}` each, the art
## may be {}) as one zip at [param path]: "" when written, else why not.
static func write_zip(path: String, spec: Dictionary, art: Dictionary, icon: Dictionary) -> String:
	var problems := CommunityCard.problems(spec)
	if not problems.is_empty():
		return problems[0]
	var why := icons_problem(icon)
	if why == "" and not art.is_empty():
		why = art_problem(art["bytes"], String(art["kind"]))
	if why != "":
		return why
	var top := file_name(String(spec["name"]))
	var zip := ZIPPacker.new()
	# Written beside, then put in place: a failed write never loses the
	# card that was there (".part" is never read as a card).
	var final_path := path
	path += ".part"
	if zip.open(path) != OK:
		return "%s could not be written." % GamePaths.shown(final_path)
	var entries := [[MANIFEST, JSON.stringify(spec, "\t", false).to_utf8_buffer()]]
	entries.append_array(icon_entries(icon))
	if not art.is_empty():
		var kind := String(art["kind"]).to_lower()
		entries.append(["art." + ("jpg" if kind == "jpeg" else kind), art["bytes"]])
	var failed := false
	for entry in entries:
		failed = zip.start_file(top + "/" + String(entry[0])) != OK or zip.write_file(entry[1]) != OK \
			or zip.close_file() != OK or failed
	failed = zip.close() != OK or failed
	if failed:
		DirAccess.remove_absolute(path)
		return "%s could not be written." % GamePaths.shown(final_path)
	return _put_in_place(path, final_path)


## Move the written [param part] over [param path] ("" when done): the
## part must read as a whole zip first (a full disk leaves a cut one), and
## the old file is moved aside, not deleted, until the new one is in place.
static func _put_in_place(part: String, path: String) -> String:
	var listed := PluginPackage.zip_entries(part)
	if String(listed["problem"]) != "" or (listed["entries"] as Array).is_empty():
		DirAccess.remove_absolute(part)
		return "%s could not be written whole." % GamePaths.shown(path)
	var old := path + ".old"
	var had := FileAccess.file_exists(path)
	if had:
		DirAccess.remove_absolute(old)
		if DirAccess.rename_absolute(path, old) != OK:
			DirAccess.remove_absolute(part)
			return "%s could not be replaced." % GamePaths.shown(path)
	if DirAccess.rename_absolute(part, path) != OK:
		if had:
			DirAccess.rename_absolute(old, path)
		DirAccess.remove_absolute(part)
		return "%s could not be written." % GamePaths.shown(path)
	if had:
		DirAccess.remove_absolute(old)
	return ""


## Save into the own folder (replacing an earlier save of the same card).
## Save over the card's own zip when it has one in the own folder
## (whatever it is called), else in a free file of its name — never over
## another card that happens to share the file name ("Elf-Lord", "Elf Lord").
static func save(spec: Dictionary, art: Dictionary, icon: Dictionary) -> String:
	var card_name := String(spec.get("name", "")).strip_edges()
	# The card of this name in any case: a new spelling saves over it.
	var had := found_like(card_name)
	var path := own_path_of(had) if had != "" else ""
	if path == "":
		path = _free_path(card_name)
	return write_zip(path, spec, art, icon)


static func _free_path(card_name: String) -> String:
	var dir := ensure_own_folder()
	var base := file_name(card_name)
	if base == "":
		base = "card"
	var path := dir.path_join(base + ".zip")
	var n := 2
	while FileAccess.file_exists(path) and _name_at(path) != card_name:
		path = dir.path_join("%s_%d.zip" % [base, n])
		n += 1
	return path


## The card the zip at [param path] holds, as last scanned ("" for none).
static func _name_at(path: String) -> String:
	_ensure()
	for row in _rows:
		# A set zip is no one card's file: never saved over as one.
		if ProjectSettings.globalize_path(String(row["path"])) == path and (row["problems"] as Array).is_empty() \
				and not row.get("set", false):
			return String(row["name"])
	return ""


## Delete the own copy of [param card_name] (only ever in the own folder).
static func delete_own(card_name: String) -> bool:
	var path := own_path_of(card_name)
	if path == "" or not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK


## The largest card zip taken from elsewhere (its art at most 4 MB, its icon
## 64 KB, its card.json far less).
const MAX_ZIP := 6 * 1024 * 1024


## The found card named [param card_name] in any case ("" when none).
static func found_like(card_name: String) -> String:
	_ensure()
	var lower := card_name.strip_edges().to_lower()
	for key in _by_name:
		if String(key).to_lower() == lower:
			return String(key)
	return ""


## INSTALL A CARD ZIP from elsewhere — the creator's Import, a LAN table's
## card transfer: [param bytes] are checked as a whole card zip first (in a
## side file the scan never reads), then saved in the own folder under a
## free file name. A card of the same name already found is replaced only
## when [param replace] and it is the player's own copy. Returns `{name,
## path, problem}` ("" when installed); the caller refreshes the pool.
static func install(bytes: PackedByteArray, replace := false) -> Dictionary:
	var out := {"name": "", "path": "", "problem": ""}
	if bytes.is_empty() or bytes.size() > MAX_ZIP:
		out["problem"] = "A card zip is at most %s." % PortableMode.size_words(MAX_ZIP)
		return out
	var dir := ensure_own_folder()
	# A folder of its own: the scan reads only the folder's own files.
	DirAccess.make_dir_recursive_absolute(dir.path_join(".incoming"))
	var side := dir.path_join(".incoming").path_join("card.zip")
	var file := FileAccess.open(side, FileAccess.WRITE)
	if file == null:
		out["problem"] = "%s could not be written." % GamePaths.shown(dir)
		return out
	file.store_buffer(bytes)
	file.close()
	if is_set_zip(side):
		DirAccess.remove_absolute(side)
		out["problem"] = "A set zip is taken whole by the card creator's Import, not as one card."
		return out
	var row := read(side)
	var card := String(row["name"])
	out["name"] = card
	out["here"] = false
	var problems: Array = row["problems"]
	if problems.is_empty():
		var game_card := CardRegistry.game_name_like(card)
		if game_card != "":
			problems.append("A card named %s is already in the game." % game_card)
	var path := ""
	if problems.is_empty():
		var had := found_like(card)
		if had == "":
			path = _free_path(card)
		elif own_path_of(had) == "":
			problems.append(_kept_words(had))
		elif not replace:
			problems.append("%s is here already." % had)
			out["here"] = true
		else:
			path = own_path_of(had)
	if not problems.is_empty():
		DirAccess.remove_absolute(side)
		out["problem"] = String(problems[0])
		return out
	var why := _put_in_place(side, path)
	if why != "":
		out["problem"] = why
		return out
	out["path"] = path
	return out


## THE ZIP OF ONE CARD, as it would be shared ([] when there is no such
## card): the card packed alone from its files, as Export writes it.
static func zip_bytes_of(card_name: String) -> PackedByteArray:
	_ensure()
	var row: Dictionary = _by_name.get(card_name, {})
	if row.is_empty():
		return PackedByteArray()
	# Always packed afresh from the card's files, as Export writes it: a
	# zip of its own may carry what another game refuses (a Mac's litter,
	# a second art).
	var dir := ensure_own_folder().path_join(".incoming")
	DirAccess.make_dir_recursive_absolute(dir)
	var out := dir.path_join("card_out.zip")
	var files: Dictionary = _files.get(card_name, {})
	if write_zip(out, row["spec"], files.get("art", {}), files.get("icon", {})) != "":
		return PackedByteArray()
	var bytes := FileAccess.get_file_as_bytes(out)
	DirAccess.remove_absolute(out)
	return bytes


## Every playable card whose set name is [param set_name] (case and edge
## spaces ignored): `{spec, art, icon}` each, by name.
static func cards_of_set(set_name: String) -> Array[Dictionary]:
	_ensure()
	var wanted := set_name.strip_edges().to_lower()
	var out: Array[Dictionary] = []
	var names: Array = _by_name.keys()
	names.sort()
	for card in names:
		var spec: Dictionary = (_by_name[card] as Dictionary)["spec"]
		if String(spec.get("set_name", "")).strip_edges().to_lower() == wanted:
			var files: Dictionary = _files.get(card, {})
			out.append({"spec": spec, "art": files.get("art", {}), "icon": files.get("icon", {})})
	return out


## WRITE A SET ZIP at [param path]: [param cards] (`{spec, art, icon}` each,
## every one whole) under one top folder, a folder each, listed by
## `set.json`: "" when written, else why not. Held to the limits a zip is
## read with ([PluginPackage]).
static func write_set_zip(path: String, set_name: String, cards: Array) -> String:
	if cards.is_empty():
		return "The set has no card."
	if cards.size() > SET_MAX_CARDS:
		return "A set zip holds at most %d cards." % SET_MAX_CARDS
	var total := 0
	var folders: Array[String] = []
	var names := {}
	for card in cards:
		var spec: Dictionary = card["spec"]
		var problems := CommunityCard.problems(spec)
		if not problems.is_empty():
			return "%s: %s" % [String(spec.get("name", "?")), problems[0]]
		var lower := String(spec["name"]).strip_edges().to_lower()
		if names.has(lower):
			return "Two cards of the set are named %s." % String(spec["name"]).strip_edges()
		names[lower] = true
		if icon_tiers(card["icon"]).is_empty():
			return "%s has no set icon." % String(spec["name"])
		for picture: Dictionary in icon_pictures(card["icon"]):
			total += (picture["bytes"] as PackedByteArray).size()
		if not (card["art"] as Dictionary).is_empty():
			total += ((card["art"] as Dictionary)["bytes"] as PackedByteArray).size()
		var folder := file_name(String(spec["name"]))
		if folder == "":
			folder = "card"
		var unique := folder
		var n := 2
		while folders.has(unique):
			unique = "%s_%d" % [folder, n]
			n += 1
		folders.append(unique)
	if total > PluginPackage.MAX_TOTAL - 1024 * 1024:
		return "The set's pictures come to %s; a set zip holds at most 31 MB. Export fewer cards or smaller art." \
			% PortableMode.size_words(total)
	var top := file_name(set_name)
	if top == "":
		top = "set"
	var zip := ZIPPacker.new()
	if zip.open(path + ".part") != OK:
		return "%s could not be written." % GamePaths.shown(path)
	var manifest := {"format": SET_FORMAT, "version": 1, "name": set_name.strip_edges(), "cards": folders}
	var failed := zip.start_file(top + "/" + SET_MANIFEST) != OK \
		or zip.write_file(JSON.stringify(manifest, "\t", false).to_utf8_buffer()) != OK or zip.close_file() != OK
	for i in cards.size():
		var card: Dictionary = cards[i]
		var entries := [[MANIFEST, JSON.stringify(card["spec"], "\t", false).to_utf8_buffer()]]
		entries.append_array(icon_entries(card["icon"]))
		if not (card["art"] as Dictionary).is_empty():
			var kind := String(card["art"]["kind"]).to_lower()
			entries.append(["art." + ("jpg" if kind == "jpeg" else kind), card["art"]["bytes"]])
		for entry in entries:
			failed = zip.start_file("%s/%s/%s" % [top, folders[i], entry[0]]) != OK \
				or zip.write_file(entry[1]) != OK or zip.close_file() != OK or failed
	failed = zip.close() != OK or failed
	if failed:
		DirAccess.remove_absolute(path + ".part")
		return "%s could not be written." % GamePaths.shown(path)
	return _put_in_place(path + ".part", path)


## IMPORT a card zip or a set zip from [param path] into the own folder,
## each card checked as any zip is: `{names, problems, here}` — the cards
## taken, why others were not, and the names already here (taken only
## with [param replace], over the player's own copies). The caller
## refreshes the pool.
static func import_file(path: String, replace := false) -> Dictionary:
	var out := {"names": [] as Array[String], "problems": [] as Array[String], "here": [] as Array[String]}
	if not FileAccess.file_exists(path) or path.get_extension().to_lower() != "zip":
		(out["problems"] as Array).append("%s is not a .zip file." % path.get_file())
		return out
	if _size_of(path) > PluginPackage.MAX_TOTAL:
		(out["problems"] as Array).append("%s is bigger than a card or set zip can be." % path.get_file())
		return out
	if not is_set_zip(path):
		var one := install(FileAccess.get_file_as_bytes(path), replace)
		if String(one["problem"]) == "":
			(out["names"] as Array).append(String(one["name"]))
		elif bool(one.get("here", false)):
			(out["here"] as Array).append(String(one["name"]))
		else:
			(out["problems"] as Array).append(String(one["problem"]))
		return out
	for row in read_set(path):
		var card := String(row["name"])
		if not (row["problems"] as Array).is_empty():
			(out["problems"] as Array).append("%s: %s" % [card, String(row["problems"][0])])
			continue
		if CardRegistry.game_name_like(card) != "":
			(out["problems"] as Array).append("%s: a card of that name is already in the game." % card)
			continue
		var had := found_like(card)
		var target := ""
		if had == "":
			target = _free_path(card)
		elif own_path_of(had) == "":
			(out["problems"] as Array).append(_kept_words(had))
			continue
		elif not replace:
			(out["here"] as Array).append(had)
			continue
		else:
			target = own_path_of(had)
		var files: Dictionary = row["files"]
		var why := write_zip(target, row["spec"], files.get("art", {}), files.get("icon", {}))
		if why != "":
			(out["problems"] as Array).append("%s: %s" % [card, why])
		else:
			(out["names"] as Array).append(card)
	return out


## Why the found [param card_name] cannot be replaced from elsewhere.
static func _kept_words(card_name: String) -> String:
	var row: Dictionary = _by_name.get(card_name, {})
	if row.get("set", false):
		return "%s is here already, in the set zip %s; it is not replaced." % [card_name,
			String(row["path"]).get_file()]
	return "%s is here already, outside the community_cards folder of your data." % card_name


## The cards saved in the own folder.
static func own_names() -> Array[String]:
	var mine := ProjectSettings.globalize_path(own_folder())
	var out: Array[String] = []
	for row in all():
		if ProjectSettings.globalize_path(String(row["path"])).begins_with(mine) \
				and (row["problems"] as Array).is_empty():
			out.append(String(row["name"]))
	out.sort()
	return out


## Scan again and rebuild the pool with the cards found now.
static func refresh() -> void:
	scan()
	configure()
	CardRegistry.ensure_loaded()
