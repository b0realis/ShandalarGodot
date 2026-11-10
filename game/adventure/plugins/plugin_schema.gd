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
	for name in spec["files"]:
		var rule: Dictionary = spec["files"][name]
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


# ------------------------------------------------------ the cross checks --

static func _cross_check(data: Dictionary, refs: Dictionary, _files: Dictionary, problems: Array[String]) -> void:
	var id: String = data["id"]
	var words: Dictionary = data["text"]
	for key in words:
		var unknown := PluginText.unknown_placeholders(String(words[key]))
		if not unknown.is_empty():
			problems.append("text.json: %s: unknown placeholder %s (the list: %s)." % [key, ", ".join(unknown.map(func(w: String) -> String: return "{" + w + "}")), ", ".join(PluginText.PLACEHOLDERS)])
	for pair in refs["text"]:
		if not words.has(pair[0]) and not PluginText.DEFAULTS.has(pair[0]):
			problems.append("%s: text.json has no %s." % [pair[1], pair[0]])
	var pictures: Dictionary = data["places"]["pictures"]
	for key in pictures:
		if not String(key).begins_with(id + "_"):
			problems.append("places.json: pictures.%s: a picture key begins with the plugin id and _ (%s_…)." % [key, id])
	var skin: Array = schema()["skin_pictures"]
	for pair in refs["picture"]:
		if not pictures.has(pair[0]) and not pair[0] in skin:
			problems.append("%s: %s is neither a picture of places.json nor a skin picture (%s)." % [pair[1], pair[0], ", ".join(skin)])
	var packs: Array = data["packs"]
	for pair in refs["card"]:
		if not card_known(String(pair[0]), packs):
			problems.append("%s: %s is not a card of the base game or of a required pack (%s)." % [pair[1], pair[0], ", ".join(packs) if not packs.is_empty() else "none"])
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
