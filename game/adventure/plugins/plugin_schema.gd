class_name PluginSchema
extends RefCounted
## ADVENTURE PLUGINS — the content schema, API v1. Reads a plugin's content
## files, checks them against `schema_v1.json` (the one description the
## game and `tools/adventure_plugin.py` share) and against each other, and
## normalizes them into the data [DataRegion] interprets: every number an
## int where the schema says int, every default filled in, every `complete`
## resolved to its effects. Nothing is loaded as a resource or run; the
## files arrive as bytes ([PluginPackage]).
##
## The checks beyond the shapes: every text key exists and uses only the
## closed placeholders ([PluginText]); every card is a card of a required
## pack (its trusted list) or of the base game; every foe, flag, objective,
## completion, quest index and picture named exists; slots are unique and
## inside the 128 sites; a quest's last step is its duel and only its first
## may be an accept; picture keys begin with the plugin's id.

const SCHEMA_PATH := "res://game/adventure/plugins/schema_v1.json"
const CONTENT := ["world.json", "places.json", "quests.json", "foes.json", "rewards.json", "text.json"]
## Region metadata keys a declared flag may not shadow (`world.expansion`
## carries each flag's value) and progress keys it may not take.
const RESERVED_FLAGS := ["region", "layout_version", "port", "castle", "town_names", "dungeon_names",
	"objectives", "banners", "freed_communities", "entries", "adventures", "appearance",
	"quests", "pending", "stages", "reward_choices", "expansion", "plugin"]
const MARKERS: Array[String] = ["port", "castle"]

static var _schema := {}
static var _patterns := {}


## The parsed `schema_v1.json` (cached).
static func schema() -> Dictionary:
	if _schema.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
		_schema = parsed if parsed is Dictionary else {}
	return _schema


## Validate [param files] (`{rel: PackedByteArray}`) against the parsed
## [param manifest]. Returns `{data: Dictionary, problems: Array[String]}`;
## `data` is {} whenever there is a problem.
static func read(manifest: Dictionary, files: Dictionary) -> Dictionary:
	var problems: Array[String] = []
	var spec := schema()
	if spec.is_empty():
		return {"data": {}, "problems": ["The game's plugin schema is missing."] as Array[String]}
	var id := String(manifest.get("id", ""))
	var refs := {"text": [], "card": [], "picture": [], "file": []}
	var content := {}
	var sites := AdventurePlugins.manifest_kind(manifest) == AdventurePlugins.KIND_SITES
	var listed: Dictionary = spec["site_files"] if sites else spec["files"]
	for name in listed:
		var rule: Dictionary = listed[name]
		if not files.has(name):
			if bool(rule.get("required", false)): problems.append("%s is missing." % name)
			continue
		var parsed: Variant = _parse(name, files[name], problems)
		if parsed == null: continue
		var errors: Array[String] = []
		var value: Variant = _check(parsed, {"kind": "ref", "type": rule["type"]}, name, errors, refs, files)
		problems.append_array(errors)
		content[name] = value
	if not problems.is_empty():
		return {"data": {}, "problems": problems}
	if sites:
		return _read_sites(manifest, content, refs, files)
	var data := {
		"id": id,
		"manifest": manifest.duplicate(true),
		"world": content["world.json"],
		"places": content["places.json"],
		"quests": content["quests.json"],
		"foes": content["foes.json"],
		"rewards": content.get("rewards.json", {"count": 6, "bundles": []}),
		"text": content["text.json"],
		"packs": _packs(manifest),
	}
	data["world"]["region"] = id
	_cross_check(data, refs, files, problems)
	_check_palette(manifest, problems)
	if not problems.is_empty():
		return {"data": {}, "problems": problems}
	return {"data": data, "problems": problems}


## The [AdventureExpansions] descriptor for a validated plugin: `pack`,
## `packs`, `title`, `salt`, `palette`, `required_markers`,
## `required_sites`, `progress_schema`, `initial_progress`, `castle_name`,
## `pictures`, `sprites`, `mana_links`, `plugin: true`, `id`, `generator`
## (the label a save writes beside the region's map), `layout_version`. An object palette is registered here as
## `plugin:<id>` ([method WorldTerrainPalette.register_profile]).
static func descriptor(manifest: Dictionary, data: Dictionary) -> Dictionary:
	if data.is_empty(): return {}
	var region: Dictionary = manifest.get("region", {}) if manifest.get("region") is Dictionary else {}
	var id := String(manifest.get("id", data.get("id", "")))
	var quests: Dictionary = data["quests"]
	# Each quest's own stage limit, its steps less one (the stage saved is
	# the number of steps done; the last, its duel, finishes it).
	var limits: Array[int] = []
	for quest in quests["quests"]:
		limits.append(quest["steps"].size() - 1)
	var flags: Array = quests.get("flags", [])
	# The waiting cards: every quest's reward choice at once, never fewer
	# than the built-in sixty.
	var pending := maxi(60, quests["quests"].size() * int(data["rewards"].get("count", 6)))
	# The finale's flag, when the finale needs every quest: a save holding it
	# set with a quest open does not fit this plugin, and the land is held
	# (its progress kept, its ships stilled) rather than read wrongly.
	var complete_flags: Array = []
	for condition in quests["finale"].get("conditions", []):
		if condition.get("quests_done") is String and String(condition["quests_done"]) == "all":
			complete_flags.append(String(quests["finale"]["done_flag"]))
	var initial := {"quests": [], "pending": []}
	for flag in flags: initial[flag] = false
	var sites: Array[int] = []
	for town in data["world"]["towns"]["list"]: sites.append(int(town["slot"]))
	var sprites := {}
	for kind in MARKERS:
		var sprite: Variant = data["places"]["markers"][kind].get("sprite")
		if sprite is Dictionary: sprites[kind] = [String(sprite["file"]), float(sprite["width"])]
	var palette: Variant = region.get("palette", WorldTerrainPalette.SHANDALAR)
	var palette_name := WorldTerrainPalette.SHANDALAR
	if palette is Dictionary:
		palette_name = "plugin:" + id
		if WorldTerrainPalette.register_profile(palette_name, palette) != "": palette_name = WorldTerrainPalette.SHANDALAR
	elif palette is String and WorldTerrainPalette.has_profile(palette):
		palette_name = palette
	var packs: Array = data.get("packs", [])
	return {"id": id, "plugin": true, "pack": String(packs[0]) if not packs.is_empty() else "", "packs": packs.duplicate(),
		"title": String(region.get("title", manifest.get("name", id))), "salt": int(region.get("salt", 0)),
		"palette": palette_name, "required_markers": MARKERS.duplicate(), "required_sites": sites,
		"progress_schema": {"quests": quests["quests"].size(), "max_stage": limits.max() if not limits.is_empty() else 0,
			"stage_limits": limits, "max_pending": pending, "flags": flags.duplicate(), "complete_flags": complete_flags},
		"initial_progress": initial, "castle_name": String(region.get("castle_name", data["places"]["markers"]["castle"]["name"])),
		"pictures": data["places"]["pictures"].duplicate(), "sprites": sprites, "mana_links": bool(region.get("mana_links", false)),
		"generator": "island (%dx%d from 1997 terrain), plugin %s %s" % [int(data["world"]["side"]), int(data["world"]["side"]), id, String(manifest.get("version", ""))],
		"layout_version": int(data["world"]["layout_version"])}


## The card pack ids [param manifest] requires, in its order.
static func _packs(manifest: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var requires: Variant = manifest.get("requires", {})
	if not requires is Dictionary or not requires.get("card_packs") is Array: return out
	for row in requires["card_packs"]:
		if row is Dictionary and row.get("id") is String and not String(row["id"]) in out: out.append(String(row["id"]))
	return out


static func _parse(name: String, bytes: Variant, problems: Array[String]) -> Variant:
	if not bytes is PackedByteArray:
		problems.append("%s could not be read." % name)
		return null
	var limits: Dictionary = schema()["limits"]
	if (bytes as PackedByteArray).size() > int(limits["json_bytes"]):
		problems.append("%s is larger than %d bytes." % [name, int(limits["json_bytes"])])
		return null
	var json := JSON.new()
	if json.parse((bytes as PackedByteArray).get_string_from_utf8()) != OK:
		# Counted from 1, as an editor counts lines (the engine counts from 0).
		problems.append("%s: line %d: %s" % [name, json.get_error_line() + 1, json.get_error_message()])
		return null
	if _depth(json.data) > int(limits["json_depth"]):
		problems.append("%s nests deeper than %d." % [name, int(limits["json_depth"])])
		return null
	if not json.data is Dictionary:
		problems.append("%s must hold one object." % name)
		return null
	return json.data


static func _depth(value: Variant) -> int:
	if value is Dictionary:
		var most := 0
		for key in value: most = maxi(most, _depth(value[key]))
		return most + 1
	if value is Array:
		var most := 0
		for item in value: most = maxi(most, _depth(item))
		return most + 1
	return 0


# ------------------------------------------------------------- the shapes --

## [param value] checked against [param spec] at [param path]; returns it
## normalized. Problems go to [param problems]; text keys, cards, pictures
## and files met go to [param refs] for the cross checks.
static func _check(value: Variant, spec: Dictionary, path: String, problems: Array[String], refs: Dictionary, files: Dictionary) -> Variant:
	var kind := String(spec.get("kind", ""))
	match kind:
		"ref":
			var named: Variant = schema()["types"].get(String(spec["type"]))
			if not named is Dictionary:
				problems.append("%s: the schema has no type %s." % [path, spec["type"]])
				return null
			return _check(value, named, path, problems, refs, files)
		"int":
			if not _number(value) or float(value) != floorf(float(value)):
				problems.append("%s: a whole number is needed." % path)
				return null
			if spec.has("min") and value < float(spec["min"]) or spec.has("max") and value > float(spec["max"]):
				problems.append("%s: %s is outside %s..%s." % [path, str(int(value)), _num(spec.get("min")), _num(spec.get("max"))])
				return null
			return int(value)
		"number":
			if not _number(value) or not is_finite(float(value)):
				problems.append("%s: a number is needed." % path)
				return null
			if spec.has("min") and value < float(spec["min"]) or spec.has("max") and value > float(spec["max"]):
				problems.append("%s: %s is outside %s..%s." % [path, str(value), _num(spec.get("min")), _num(spec.get("max"))])
				return null
			return float(value)
		"bool":
			if not value is bool:
				problems.append("%s: true or false is needed." % path)
				return null
			return value
		"string", "text", "card", "hex", "file", "picture":
			return _check_string(value, spec, kind, path, problems, refs, files)
		"enum":
			for option in spec["values"]:
				if _number(option) and _number(value) and float(option) == float(value): return int(option)
				if option is String and value is String and option == value: return value
			problems.append("%s: one of %s is needed." % [path, ", ".join(spec["values"].map(func(v: Variant) -> String: return _num(v) if _number(v) else str(v)))])
			return null
		"array":
			if not value is Array:
				problems.append("%s: a list is needed." % path)
				return null
			if value.size() < int(spec.get("min", 0)) or value.size() > int(spec.get("max", 512)):
				problems.append("%s: %d entries; %d to %d are allowed." % [path, value.size(), int(spec.get("min", 0)), int(spec.get("max", 512))])
				return null
			var out := []
			for i in value.size():
				out.append(_check(value[i], spec["items"], "%s[%d]" % [path, i], problems, refs, files))
			return out
		"map":
			if not value is Dictionary:
				problems.append("%s: an object is needed." % path)
				return null
			if value.size() < int(spec.get("min", 0)) or value.size() > int(spec.get("max", 512)):
				problems.append("%s: %d entries; %d to %d are allowed." % [path, value.size(), int(spec.get("min", 0)), int(spec.get("max", 512))])
				return null
			var out := {}
			for key in value:
				var errors: Array[String] = []
				_check(key, spec["keys"], "%s key %s" % [path, key], errors, refs, files)
				if not errors.is_empty():
					problems.append_array(errors)
					continue
				out[key] = _check(value[key], spec["values"], "%s.%s" % [path, key], problems, refs, files)
			return out
		"object":
			if not value is Dictionary:
				problems.append("%s: an object is needed." % path)
				return null
			var fields: Dictionary = spec.get("fields", {})
			var out := {}
			for key in value:
				if not fields.has(key): problems.append("%s: unknown field %s." % [path, key])
			for key in fields:
				var field: Dictionary = fields[key]
				var at: String = ("%s.%s" % [path, key]) if path != "" else String(key)
				if value.has(key):
					out[key] = _check(value[key], field, at, problems, refs, files)
				elif field.has("default"):
					out[key] = _check(field["default"], field, at, problems, {"text": [], "card": [], "picture": [], "file": []}, files)
				elif bool(field.get("required", false)):
					problems.append("%s: %s is required." % [path, key])
			return out
		"oneof":
			var tries: Array[String] = []
			for option in spec["options"]:
				var errors: Array[String] = []
				var found := {"text": [], "card": [], "picture": [], "file": []}
				var out: Variant = _check(value, option, path, errors, found, files)
				if errors.is_empty():
					for group in found: refs[group].append_array(found[group])
					return out
				tries.append(errors[0])
			problems.append("%s: none of its forms fits (%s)." % [path, "; ".join(tries)])
			return null
		"single":
			if not value is Dictionary or value.size() != 1:
				problems.append("%s: an object with one of %s is needed." % [path, ", ".join(spec["options"].keys())])
				return null
			var key: String = value.keys()[0]
			if not spec["options"].has(key):
				problems.append("%s: %s is not one of %s." % [path, key, ", ".join(spec["options"].keys())])
				return null
			return {key: _check(value[key], spec["options"][key], "%s.%s" % [path, key], problems, refs, files)}
	problems.append("%s: the schema's kind %s is unknown." % [path, kind])
	return null


static func _check_string(value: Variant, spec: Dictionary, kind: String, path: String, problems: Array[String], refs: Dictionary, files: Dictionary) -> Variant:
	if not value is String:
		problems.append("%s: text in quotes is needed." % path)
		return null
	var limit := int(spec.get("max", schema()["limits"]["text_chars"]))
	if value.length() < int(spec.get("min", 1 if kind != "string" else 0)) or value.length() > limit:
		problems.append("%s: %d characters; at most %d are allowed." % [path, value.length(), limit])
		return null
	if spec.has("pattern") and not _matches(String(spec["pattern"]), value):
		problems.append("%s: %s does not fit %s." % [path, value, spec["pattern"]])
		return null
	match kind:
		"hex":
			if value.length() != 6 or not value.is_valid_hex_number():
				problems.append("%s: six hex digits are needed (like e0bc60)." % path)
				return null
		"file":
			var classes: Dictionary = schema()["extensions"]
			var allowed: Array = classes.get(String(spec.get("class", "")), classes["allowed"])
			if not "." + value.get_extension().to_lower() in allowed:
				problems.append("%s: %s must end in %s." % [path, value, ", ".join(allowed)])
				return null
			if not files.has(value):
				problems.append("%s: the plugin has no file %s." % [path, value])
				return null
			refs["file"].append(value)
		"text", "card", "picture":
			refs[kind].append([value, path])
	return value


static func _matches(pattern: String, value: String) -> bool:
	if not _patterns.has(pattern):
		var expression := RegEx.new()
		expression.compile(pattern)
		_patterns[pattern] = expression
	return (_patterns[pattern] as RegEx).search(value) != null


static func _number(value: Variant) -> bool:
	return value is int or value is float


static func _num(value: Variant) -> String:
	if value == null: return "?"
	return str(int(value)) if float(value) == floorf(float(value)) else str(value)


# ------------------------------------------------------ a sites plugin --

## A SITES PLUGIN'S CONTENT (API 2) read from its checked files: `{id,
## manifest, sites, text, packs}`, `sites` being `sites.json` normalized,
## and its cross checks — the words, the pictures, the cards, the flags,
## the actions and the dungeons named.
static func _read_sites(manifest: Dictionary, content: Dictionary, refs: Dictionary, files: Dictionary) -> Dictionary:
	var problems: Array[String] = []
	var id := String(manifest.get("id", ""))
	var data := {"id": id, "kind": AdventurePlugins.KIND_SITES, "manifest": manifest.duplicate(true),
		"sites": content["sites.json"], "text": content["text.json"], "packs": _packs(manifest)}
	_check_words(data["text"], refs, problems)
	_check_pictures(id, "sites.json", data["sites"]["pictures"], refs, problems)
	_check_cards(data["packs"], refs, problems)
	_check_sites(data["sites"], problems, int(manifest.get("api_version", AdventurePlugins.SITES_API)))
	if not problems.is_empty():
		return {"data": {}, "problems": problems}
	return {"data": data, "problems": problems}


## The [AdventureSites] descriptor of a validated sites plugin: `id`,
## `plugin`, `kind`, `packs`, `pack`, `salt`, `pictures`, `sprites`
## (`{site: [file, width]}`) and `sites` (`{site: {name, where, gap}}`).
static func site_descriptor(manifest: Dictionary, data: Dictionary) -> Dictionary:
	if data.is_empty(): return {}
	var file: Dictionary = data["sites"]
	var sprites := {}
	var places := {}
	for key in file["sites"]:
		var site: Dictionary = file["sites"][key]
		sprites[key] = [String(site["sprite"]["file"]), float(site["sprite"]["width"])]
		places[key] = {"name": String(site["name"]), "where": (site["where"] as Array).duplicate(), "gap": int(site["gap"])}
	var packs: Array = data.get("packs", [])
	return {"id": String(manifest.get("id", data.get("id", ""))), "plugin": true, "kind": AdventurePlugins.KIND_SITES,
		"version": String(manifest.get("version", "")), "name": String(manifest.get("name", "")),
		"pack": String(packs[0]) if not packs.is_empty() else "", "packs": packs.duplicate(),
		"salt": int(file["salt"]), "pictures": (file["pictures"] as Dictionary).duplicate(), "sprites": sprites, "sites": places}


## A sites plugin's own checks: the flags and counters its conditions and
## effects name are declared, the actions a condition names stand in the
## site named (`used_up` one with prices), the dungeons, foes, panes and
## places named exist, an action's id is its site's once, a dungeon's
## nearest no farther than its farthest; a place always opens on a pane
## and every pane can be left (the campaign of 2026-11-22: a place with
## neither held the hero until Escape); each kind of action carries only
## its own fields; a card or amulets given have a price; and a word of API
## 3 stands only in a plugin that declares [param api] 3 ([method
## _check_api]).
static func _check_sites(file: Dictionary, problems: Array[String], api := 3) -> void:
	var dungeons: Dictionary = file["dungeons"]
	var foes: Dictionary = file.get("foes", {})
	var words: Array = []
	for part in ["counters", "foes", "tasks"]:
		if not file.get(part, []).is_empty(): words.append([part, "sites.json: " + part])
	for i in file.get("counters", []).size():
		if file["counters"].find(file["counters"][i]) != i: problems.append("sites.json: counters[%d]: %s is named twice." % [i, file["counters"][i]])
	for key in dungeons:
		var distance: Dictionary = dungeons[key]["distance"]
		if int(distance["min"]) > int(distance["max"]):
			problems.append("sites.json: dungeons.%s.distance: min %d is more than max %d." % [key, int(distance["min"]), int(distance["max"])])
	for name in foes:
		_check_foe(foes[name], "sites.json: foes.%s" % name, problems)
	# Every site's actions first: a condition may name another site's.
	var all := {}
	for key in file["sites"]:
		var site: Dictionary = file["sites"][key]
		var actions := {}
		for p in site["panes"].size():
			for a in site["panes"][p]["actions"].size():
				var action: Dictionary = site["panes"][p]["actions"][a]
				var name := String(action["id"])
				if actions.has(name) and actions[name] != action:
					problems.append("sites.json: sites.%s.panes[%d].actions[%d].id: %s names another action of this site; an id is one action (the same action may stand in several panes)." % [key, p, a, name])
				elif not actions.has(name):
					actions[name] = action
		all[key] = actions
	var known := {"flags": file["flags"], "counters": file.get("counters", []), "dungeons": dungeons, "sites": all, "words": words}
	for key in file["sites"]:
		var site: Dictionary = file["sites"][key]
		var at := "sites.json: sites.%s" % key
		var actions: Dictionary = all[key]
		var panes := {}
		var opening := -1
		for p in site["panes"].size():
			var pane: Dictionary = site["panes"][p]
			if pane.has("id"):
				words.append(["id", "%s.panes[%d].id" % [at, p]])
				if panes.has(pane["id"]): problems.append("%s.panes[%d].id: %s is another pane's id; a pane's id is its site's once." % [at, p, pane["id"]])
				panes[pane["id"]] = true
			else:
				opening = p
		# A WAY IN AND A WAY OUT: without them the place showed an empty pane
		# with no button.
		if opening < 0:
			problems.append("%s.panes: every pane has an id, so none opens by itself; the place needs a pane without an id to open on." % at)
		elif not (site["panes"][opening]["when"] as Array).is_empty():
			problems.append("%s.panes[%d].when: the last pane without an id must have no when, so the place always has a pane to show; add one more pane without a when after it." % [at, opening])
		for p in site["panes"].size():
			var pane: Dictionary = site["panes"][p]
			var here := "%s.panes[%d]" % [at, p]
			_check_site_conditions(pane["when"], here + ".when", known, actions, problems)
			_check_site_lines(pane["lines"], here + ".lines", known, actions, problems)
			var way_out := false
			for a in pane["actions"].size():
				var action: Dictionary = pane["actions"][a]
				var spot := "%s.actions[%d]" % [here, a]
				if String(action["do"]) == "leave" and (action["when"] as Array).is_empty(): way_out = true
				_check_site_conditions(action["when"], spot + ".when", known, actions, problems)
				_check_site_lines(action["result"], spot + ".result", known, actions, problems)
				_check_site_action(action, spot, known, actions, panes, foes, problems)
			if not way_out:
				problems.append("%s.actions: a pane needs an action that does \"leave\" and has no when, so the hero can always walk away." % here)
	var tasks: Dictionary = file.get("tasks", {})
	for name in tasks:
		var task: Dictionary = tasks[name]
		var at := "sites.json: tasks.%s" % name
		var target := String(task.get("at", ""))
		var actions := {}
		var placed := target.begins_with("place:")
		if placed:
			if not all.has(target.trim_prefix("place:")): problems.append("%s.at: no place %s in sites.json sites." % [at, target.trim_prefix("place:")])
			else: actions = all[target.trim_prefix("place:")]
		elif target.begins_with("dungeon:") and not dungeons.has(target.trim_prefix("dungeon:")):
			problems.append("%s.at: no dungeon %s in sites.json dungeons." % [at, target.trim_prefix("dungeon:")])
		for part in ["when", "done_when"]:
			if not placed:
				for word in ["used", "used_up"]:
					if DataSites._named_condition(task[part], word) != null:
						problems.append("%s.%s: %s reads the place a task is at; give the task \"at\": \"place:…\", or use site_used." % [at, part, word])
						task[part] = []
			_check_site_conditions(task[part], "%s.%s" % [at, part], known, actions, problems)
	_check_api(words, api, problems)


## A WORD OF API 3 IN A PLUGIN THAT DECLARES LESS is refused, each word
## once and by name: a game that reads only API 2 would refuse the file for
## a word it does not know, or worse, skip it; declared 3, that game says
## plainly that a newer one is needed.
static func _check_api(words: Array, api: int, problems: Array[String]) -> void:
	if api >= 3: return
	var named := {}
	for pair in words:
		if named.has(pair[0]): continue
		named[pair[0]] = true
		problems.append("%s: \"%s\" is a word of plugin API 3, and plugin.json declares api_version %d. Set \"api_version\": 3 there (the plugin then needs a game that reads API 3)." % [pair[1], pair[0], api])


## The API 3 words of the schema's group [param group] (`v3_words`).
static func _v3(group: String) -> Array:
	return schema().get("v3_words", {}).get(group, [])


static func _check_foe(foe: Dictionary, at: String, problems: Array[String]) -> void:
	var cards := 0
	for card in foe["deck"]: cards += int(foe["deck"][card])
	if cards < 1 or cards > 250: problems.append("%s.deck holds %d cards; 1 to 250 are allowed." % [at, cards])
	if not CreatureBook.is_row(int(foe["face"])) or int(foe["face"]) == CreatureBook.LAIR:
		problems.append("%s.face: %d is not a creature row." % [at, int(foe["face"])])


static func _check_site_lines(lines: Array, at: String, known: Dictionary, actions: Dictionary, problems: Array[String]) -> void:
	for l in lines.size():
		if not lines[l] is Dictionary: continue
		if lines[l].has("one_of"): known["words"].append(["one_of", "%s[%d]" % [at, l]])
		_check_site_conditions(lines[l]["when"], "%s[%d].when" % [at, l], known, actions, problems)


## One action's checks: the fields of its kind, what it names, its effects.
static func _check_site_action(action: Dictionary, spot: String, known: Dictionary, actions: Dictionary, panes: Dictionary, foes: Dictionary, problems: Array[String]) -> void:
	var kind := String(action["do"])
	var words: Array = known["words"]
	if kind in _v3("do"): words.append([kind, spot + ".do"])
	# Each field where it means something: a field that would be silently
	# ignored is a mistake the author should hear of.
	var allowed := {"effects": ["effects", "talk"], "prices": ["effects", "talk", "copy_card", "duel"], "needs": ["effects", "talk", "copy_card", "duel"],
		"result": ["effects", "copy_card", "buy_card", "sell_card"], "to": ["talk"], "foe": ["duel"], "win": ["duel"], "lose": ["duel"],
		"cards": ["buy_card", "sell_card"], "stock": ["buy_card", "sell_card"]}
	for field in allowed:
		var value: Variant = action.get(field)
		var given: bool = value != null and not ((value is Array or value is Dictionary) and value.is_empty())
		if field in ["win", "lose"]: given = value is Dictionary and not ((value["effects"] as Array).is_empty() and (value["result"] as Array).is_empty())
		if not given: continue
		if field in _v3("action"): words.append([field, "%s.%s" % [spot, field]])
		if not kind in allowed[field]:
			problems.append("%s.%s: only an action that does %s has %s." % [spot, field, " or ".join(allowed[field]), field])
	if String(action.get("count", "press")) != "press":
		words.append(["count", spot + ".count"])
		if kind != "duel": problems.append("%s.count: only an action that does duel has count." % spot)
	match kind:
		"talk":
			if not action.has("to"): problems.append("%s: a talk needs \"to\": the id of the pane to open." % spot)
			elif not panes.has(action["to"]): problems.append("%s.to: this site has no pane with the id %s." % [spot, action["to"]])
		"duel":
			if not action.has("foe"): problems.append("%s: a duel needs \"foe\": a key of sites.json foes." % spot)
			elif not foes.has(action["foe"]): problems.append("%s.foe: no foe %s in sites.json foes." % [spot, action["foe"]])
		"buy_card", "sell_card":
			if (action["cards"] as Dictionary).is_empty(): problems.append("%s: %s needs \"cards\": each card and its price." % [spot, kind])
	var priced: bool = not (action["prices"] as Array).is_empty() or not (action["needs"] as Array).is_empty()
	_check_site_effects(action["effects"], spot + ".effects", known, actions, priced, 0, problems)
	for branch in ["win", "lose"]:
		_check_site_effects(action[branch]["effects"], "%s.%s.effects" % [spot, branch], known, actions, priced, 2, problems)
		_check_site_lines(action[branch]["result"], "%s.%s.result" % [spot, branch], known, actions, problems)


## A list of effects' checks. [param priced]: its action has prices or
## needs; [param inside] 0 an action's own list, 1 a roll's outcome, 2 a
## duel's branch.
static func _check_site_effects(effects: Array, at: String, known: Dictionary, actions: Dictionary, priced: bool, inside: int, problems: Array[String]) -> void:
	var rolls := 0
	for e in effects.size():
		var effect: Dictionary = effects[e]
		var name: String = effect.keys()[0]
		var value: Variant = effect[name]
		var spot := "%s[%d].%s" % [at, e, name]
		if name in _v3("effect"): known["words"].append([name, spot])
		match name:
			"set_flag", "clear_flag":
				if not value in known["flags"]: problems.append("%s: no flag %s in sites.json flags." % [spot, value])
			"spawn_dungeon":
				if not known["dungeons"].has(value): problems.append("%s: no dungeon %s in sites.json dungeons." % [spot, value])
			"counter":
				if not value["name"] in known["counters"]: problems.append("%s: no counter %s in sites.json counters." % [spot, value["name"]])
				if value.has("add") == value.has("set"): problems.append("%s: one of add or set is needed, not both." % spot)
			"amulet":
				if int(value["count"]) == 0: problems.append("%s: count 0 gives nothing." % spot)
				elif int(value["count"]) > 0 and not priced: problems.append("%s: amulets are given without end; give the action prices (a ladder that ends) or needs." % spot)
			"give_card":
				if not priced: problems.append("%s: a card is given without end; give the action prices (a ladder that ends) or needs." % spot)
			"next_duel":
				var gifts := 0
				for gift in ["life", "first_move", "card"]:
					if value.has(gift): gifts += 1
				if gifts != 1: problems.append("%s: exactly one of life, first_move or card is needed (one gift waits at a time)." % spot)
				elif value.has("first_move") and not bool(value["first_move"]): problems.append("%s: first_move is true, or left out." % spot)
			"reveal_map":
				var around := String(value["around"])
				if around.begins_with("dungeon:") and not known["dungeons"].has(around.trim_prefix("dungeon:")):
					problems.append("%s.around: no dungeon %s in sites.json dungeons." % [spot, around.trim_prefix("dungeon:")])
			"roll":
				rolls += 1
				if inside == 1: problems.append("%s: no roll inside a roll's outcome." % spot)
				elif inside == 2: problems.append("%s: no roll in a duel's win or lose; the duel is the gamble." % spot)
				elif rolls > 1: problems.append("%s: one roll an action; put every outcome in it." % spot)
				for o in value["outcomes"].size():
					var outcome: Dictionary = value["outcomes"][o]
					_check_site_effects(outcome["effects"], "%s.outcomes[%d].effects" % [spot, o], known, actions, priced, 1, problems)
					_check_site_lines(outcome["result"], "%s.outcomes[%d].result" % [spot, o], known, actions, problems)


## [param known]: `{flags, counters, dungeons, sites: {site: {action id:
## action}}, words}`; [param actions] the actions of the site the
## conditions stand in.
static func _check_site_conditions(conditions: Array, at: String, known: Dictionary, actions: Dictionary, problems: Array[String], inside := false) -> void:
	for i in conditions.size():
		var name: String = conditions[i].keys()[0]
		var value: Variant = conditions[i][name]
		if name in _v3("condition"): known["words"].append([name, "%s[%d].%s" % [at, i, name]])
		match name:
			"flag", "not_flag":
				if not value in known["flags"]: problems.append("%s[%d].%s: no flag %s in sites.json flags." % [at, i, name, value])
			"used":
				if not actions.has(value["action"]): problems.append("%s[%d].used: this site has no action %s." % [at, i, value["action"]])
			"used_up":
				if not actions.has(value): problems.append("%s[%d].used_up: this site has no action %s." % [at, i, value])
				elif (actions[value]["prices"] as Array).is_empty(): problems.append("%s[%d].used_up: the action %s has no prices, so it is never used up." % [at, i, value])
			"dungeon":
				if not known["dungeons"].has(value["dungeon"]): problems.append("%s[%d].dungeon: no dungeon %s in sites.json dungeons." % [at, i, value["dungeon"]])
			"counter":
				if not value["name"] in known["counters"]: problems.append("%s[%d].counter: no counter %s in sites.json counters." % [at, i, value["name"]])
				if int(value["min"]) > int(value["max"]): problems.append("%s[%d].counter: min %d is more than max %d." % [at, i, int(value["min"]), int(value["max"])])
			"difficulty":
				if int(value["min"]) > int(value["max"]): problems.append("%s[%d].difficulty: min %d is more than max %d." % [at, i, int(value["min"]), int(value["max"])])
			"site_used":
				if not known["sites"].has(value["site"]): problems.append("%s[%d].site_used: no place %s in sites.json sites." % [at, i, value["site"]])
				elif not known["sites"][value["site"]].has(value["action"]): problems.append("%s[%d].site_used: the place %s has no action %s." % [at, i, value["site"], value["action"]])
			"any":
				if inside: problems.append("%s[%d].any: no any inside an any; list its conditions in the outer one." % [at, i])
				else: _check_site_conditions(value, "%s[%d].any" % [at, i], known, actions, problems, true)


# ------------------------------------------------------ the cross checks --

## Every text names placeholders of the closed list, and every text key
## named is one of text.json's (or an engine default's).
static func _check_words(words: Dictionary, refs: Dictionary, problems: Array[String]) -> void:
	for key in words:
		var unknown := PluginText.unknown_placeholders(String(words[key]))
		if not unknown.is_empty():
			problems.append("text.json: %s: unknown placeholder %s (the list: %s)." % [key, ", ".join(unknown.map(func(w: String) -> String: return "{" + w + "}")), ", ".join(PluginText.PLACEHOLDERS)])
	for pair in refs["text"]:
		if not words.has(pair[0]) and not PluginText.DEFAULTS.has(pair[0]):
			problems.append("%s: text.json has no %s." % [pair[1], pair[0]])


## Picture keys begin with the plugin's id; every picture named is one of
## [param pictures] (the plugin's, listed in [param file]) or a skin's.
static func _check_pictures(id: String, file: String, pictures: Dictionary, refs: Dictionary, problems: Array[String]) -> void:
	for key in pictures:
		if not String(key).begins_with(id + "_"):
			problems.append("%s: pictures.%s: a picture key begins with the plugin id and _ (%s_…)." % [file, key, id])
	var skin: Array = schema()["skin_pictures"]
	for pair in refs["picture"]:
		if not pictures.has(pair[0]) and not pair[0] in skin:
			problems.append("%s: %s is neither a picture of %s nor a skin picture (%s)." % [pair[1], pair[0], file, ", ".join(skin)])


static func _check_cards(packs: Array, refs: Dictionary, problems: Array[String]) -> void:
	for pair in refs["card"]:
		if not card_known(String(pair[0]), packs):
			problems.append("%s: %s is not a card of the base game or of a required pack (%s)." % [pair[1], pair[0], ", ".join(packs) if not packs.is_empty() else "none"])


static func _cross_check(data: Dictionary, refs: Dictionary, _files: Dictionary, problems: Array[String]) -> void:
	_check_words(data["text"], refs, problems)
	_check_pictures(String(data["id"]), "places.json", data["places"]["pictures"], refs, problems)
	_check_cards(data["packs"], refs, problems)
	_check_world(data["world"], problems)
	_check_quests(data, problems)
	_check_foes(data, problems)


static func _check_world(world: Dictionary, problems: Array[String]) -> void:
	if int(world["offset"]) + int(world["side"]) > 64:
		problems.append("world.json: offset + side is %d; the map is 64 tiles." % (int(world["offset"]) + int(world["side"])))
	if (int(world["side"]) - 1) * int(world["step"]) >= 64:
		problems.append("world.json: side x step reads past the 64-tile source map.")
	if int(world["dungeon"]["from"]) + int(world["dungeon"]["choices"]) > 15:
		problems.append("world.json: dungeon.from + dungeon.choices reaches past the source's 15 dungeons.")
	var slots := {}
	for town in world["towns"]["list"]:
		_claim_slot(slots, int(town["slot"]), "towns", problems)
	for place in world["places"]["list"]:
		_claim_slot(slots, int(place["slot"]), "places", problems)
	var villages: Dictionary = world["villages"]
	var low := int(villages["count"][0])
	var high := int(villages["count"][1])
	if high < low: problems.append("world.json: villages.count must read least, most.")
	if villages["names"].size() < high: problems.append("world.json: villages.names holds %d names for up to %d villages." % [villages["names"].size(), high])
	for i in high:
		var slot := (i + 1) * int(villages["slot_step"])
		if slot > 127: problems.append("world.json: village %d would take slot %d; slots end at 127." % [i + 1, slot])
		else: _claim_slot(slots, slot, "villages", problems)


static func _claim_slot(slots: Dictionary, slot: int, part: String, problems: Array[String]) -> void:
	if slots.has(slot): problems.append("world.json: slot %d is taken twice (%s and %s)." % [slot, slots[slot], part])
	else: slots[slot] = part


static func _check_quests(data: Dictionary, problems: Array[String]) -> void:
	var quests: Dictionary = data["quests"]
	var world: Dictionary = data["world"]
	var flags: Array = quests["flags"]
	for flag in flags:
		if flag in RESERVED_FLAGS: problems.append("quests.json: flags: %s is a reserved name." % flag)
	var traders := {}
	for town in world["towns"]["list"]: traders[int(town["slot"])] = true
	for place in world["places"]["list"]:
		if String(place["kind"]) != "village": traders[int(place["slot"])] = true
	var foes: Dictionary = data["foes"]["foes"]
	var givers := {}
	var count: int = quests["quests"].size()
	var uses := {"flags": [], "quests": [], "objectives": [], "sites": [], "packs": [], "rewards": false}
	for index in count:
		var quest: Dictionary = quests["quests"][index]
		var at := "quests.json: quests[%d]" % index
		var giver := int(quest["giver"])
		if not traders.has(giver): problems.append("%s.giver: slot %d is not a town or place of world.json." % [at, giver])
		if givers.has(giver): problems.append("%s.giver: slot %d already gives quest %d." % [at, giver, givers[giver]])
		givers[giver] = index
		if not foes.has(quest["foe"]): problems.append("%s.foe: foes.json has no %s." % [at, quest["foe"]])
		var steps: Array = quest["steps"]
		for s in steps.size():
			var step: Dictionary = steps[s]
			var where := "%s.steps[%d]" % [at, s]
			match String(step["do"]):
				"accept":
					if s != 0: problems.append("%s: only a quest's first step may be accept." % where)
				"go":
					for field in ["to", "action", "guidance", "task"]:
						if not step.has(field): problems.append("%s: a go step needs %s." % [where, field])
					if step.has("to"): _target_uses(step["to"], uses)
				"duel":
					if step.has("at"): _target_uses(step["at"], uses)
			if String(step["do"]) == "duel" and s != steps.size() - 1:
				problems.append("%s: the duel ends the quest; it must be the last step." % where)
		if String(steps.back()["do"]) != "duel": problems.append("%s.steps: the last step must be the duel." % at)
		var done: Variant = quest["complete"]
		if done is String:
			if not quests["completions"].has(done): problems.append("%s.complete: quests.json completions has no %s." % [at, done])
			else: quest["complete"] = quests["completions"][done].duplicate(true)
		if quest["complete"] is Array:
			_effect_uses(quest["complete"], uses)
			_check_effects(quest["complete"], "%s.complete" % at, quests, problems, false)
	var finale: Dictionary = quests["finale"]
	_check_effects(finale["effects"], "quests.json: finale.effects", quests, problems, true)
	if not foes.has(finale["foe"]): problems.append("quests.json: finale.foe: foes.json has no %s." % finale["foe"])
	uses["flags"].append(finale["done_flag"])
	_condition_uses(finale["conditions"], uses)
	_effect_uses(finale["effects"], uses)
	for kind in MARKERS:
		var marker: Dictionary = data["places"]["markers"][kind]
		if marker.has("banner"): uses["flags"].append(marker["banner"]["flag"])
		for pane in marker["panes"]:
			_condition_uses(pane["when"], uses)
			for line in pane["lines"]:
				if line is Dictionary: _condition_uses(line.get("when", []), uses)
			for action in pane["actions"]: _condition_uses(action["when"], uses)
	for group in [quests["status"], quests["talk"].get("news", []), quests["talk"].get("applause", []), quests["talk"].get("roaming", []), quests["talk"].get("tribute", [])]:
		for line in group:
			if line is Dictionary: _condition_uses(line.get("when", []), uses)
	for flag in uses["flags"]:
		if not flag in flags: problems.append("quests.json: the flag %s is not declared in flags." % flag)
	for quest in uses["quests"]:
		if quest >= count: problems.append("quests.json: quest %d is named; there are %d." % [quest, count])
	for name in uses["objectives"]:
		if not world["objectives"].has(name): problems.append("quests.json: the objective %s is not in world.json objectives." % name)
	for slot in uses["sites"]:
		if not traders.has(slot): problems.append("quests.json: site %d is not a town or place of world.json." % slot)
	for pack in uses["packs"]:
		if not pack in data["packs"]: problems.append("quests.json: deck_share names %s, which the manifest does not require." % pack)
	if uses["rewards"] and data["rewards"]["bundles"].is_empty():
		problems.append("quests.json: a reward_choice needs rewards.json bundles.")


## Effects that would write a progress record the save check refuses
## (the review of 2026-11-10, RV2-1, RV2-2): a second reward choice for one
## quest, a reward choice owed by the finale, a stage past its quest's
## steps, and the finale's flag set by anything but the finale.
static func _check_effects(effects: Array, at: String, quests: Dictionary, problems: Array[String], finale: bool) -> void:
	var choices := 0
	var count: int = quests["quests"].size()
	var done_flag := String(quests["finale"]["done_flag"])
	for effect in effects:
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		match key:
			"reward_choice":
				if not bool(value): continue
				if finale:
					problems.append("%s: a reward_choice belongs to a quest's completion, not the finale." % at)
				else:
					choices += 1
			"set_stage":
				var quest := int(value["quest"])
				if quest >= count: continue
				var most: int = quests["quests"][quest]["steps"].size() - 1
				if int(value["value"]) > most:
					problems.append("%s: set_stage: quest %d has %d step%s; its stage goes up to %d." % [at, quest, most + 1, "" if most == 0 else "s", most])
			"set_flag":
				if not finale and String(value) == done_flag:
					problems.append("%s: set_flag: %s is the finale's flag; only the finale's effects set it." % [at, value])
	if choices > 1:
		problems.append("%s: one reward_choice at most; a quest owes one reward choice." % at)


static func _target_uses(target: Variant, uses: Dictionary) -> void:
	if target is Dictionary:
		if target.has("objective"): uses["objectives"].append(target["objective"])
		if target.has("site"): uses["sites"].append(int(target["site"]))


static func _condition_uses(conditions: Array, uses: Dictionary) -> void:
	for condition in conditions:
		var key: String = condition.keys()[0]
		var value: Variant = condition[key]
		match key:
			"flag", "not_flag": uses["flags"].append(value)
			"stage": uses["quests"].append(int(value["quest"]))
			"quest_done": uses["quests"].append(int(value))
			"deck_share": uses["packs"].append(value["pack"])
			"here": _target_uses(value, uses)


static func _effect_uses(effects: Array, uses: Dictionary) -> void:
	for effect in effects:
		var key: String = effect.keys()[0]
		match key:
			"set_flag": uses["flags"].append(effect[key])
			"set_stage": uses["quests"].append(int(effect[key]["quest"]))
			"reward_choice": if bool(effect[key]): uses["rewards"] = true


static func _check_foes(data: Dictionary, problems: Array[String]) -> void:
	var foes: Dictionary = data["foes"]["foes"]
	for name in foes:
		var foe: Dictionary = foes[name]
		var cards := 0
		for card in foe["deck"]: cards += int(foe["deck"][card])
		if cards < 1 or cards > 250: problems.append("foes.json: foes.%s.deck holds %d cards; 1 to 250 are allowed." % [name, cards])
		if not CreatureBook.is_row(int(foe["face"])) or int(foe["face"]) == CreatureBook.LAIR:
			problems.append("foes.json: foes.%s.face: %d is not a creature row." % [name, int(foe["face"])])
	var roaming: Variant = data["foes"].get("roaming")
	if roaming is Dictionary:
		for i in roaming["decks"].size():
			if not foes.has(roaming["decks"][i]["foe"]): problems.append("foes.json: roaming.decks[%d].foe: no foe %s." % [i, roaming["decks"][i]["foe"]])


static func _check_palette(manifest: Dictionary, problems: Array[String]) -> void:
	var region: Variant = manifest.get("region", {})
	if not region is Dictionary: return
	var palette: Variant = region.get("palette")
	if palette == null: return
	if palette is String:
		if not WorldTerrainPalette.has_profile(palette): problems.append("plugin.json: region.palette: %s is not a built-in palette." % palette)
	elif palette is Dictionary:
		var why := WorldTerrainPalette.profile_problem(palette)
		if why != "": problems.append("plugin.json: region.palette: " + why)
	else:
		problems.append("plugin.json: region.palette: a palette name or a palette object is needed.")


# ------------------------------------------------------------- the cards --

## Whether [param card] may stand in a plugin needing [param packs]: a card
## of one of their trusted lists (shipped in the game, never a zip's word),
## or a base-game card — one the registry knows that no numbered pack
## introduced.
static func card_known(card: String, packs: Array) -> bool:
	for pack in packs:
		if card in pack_cards(String(pack)): return true
	return AdventurePacks.owner_of(card) == "" and CardRegistry.has_card(card)


## The trusted card list of card pack [param pack] ([method
## FallenEmpiresPack.names] and its kin), [] when this build has no such
## pack or no pack service runs.
static func pack_cards(pack: String) -> Array[String]:
	var service := AdventureExpansions.packs()
	if service == null: return []
	for contract in service.expansions():
		if String(contract.ID) == pack: return contract.names()
	return []
