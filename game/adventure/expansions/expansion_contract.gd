class_name ExpansionContract
extends RefCounted
## Metadata-only persistence contract. No provider or artwork loads on validation.
##
## THE PROVIDER FENCE (adventure plugins, 2026-11-10; the spec's §0.1): a
## development fixture's provider is a script of the game's own, under
## `res://` — never a path a player's folder could reach. A plugin's
## descriptor names none at all: its provider is the res:// interpreter
## [DataRegion] ([method AdventureExpansions.provider]).
##
## THE PROGRESS A REGION KEEPS, by its descriptor's `progress_schema`:
##  - `fields`: a development fixture's own record, every field declared;
##  - `quests` (a plugin's): the quests done (`quests`, indices), their
##    stages (`stages`, `"i"` → 0 to that quest's `stage_limits[i]`, else
##    `max_stage`), the rewards still to
##    choose (`reward_choices`), the cards waiting (`pending`, at most
##    `max_pending`) and the switches `flags` declares (true or false,
##    absent false). A switch named in `complete_flags` is on only with
##    every quest done (the Refuge's `liberated`: its finale asks for all of
##    them); with none named, nothing is held to the quests.
##  - A region no installed plugin describes ([method opaque_progress]):
##    carried as it is, held only to its bounds, so a plugin missing for a
##    while loses nothing (§0.5).

## The bounds of progress carried for a region nothing describes.
const OPAQUE_BYTES := 262144
const OPAQUE_DEPTH := 32

## HOW A SAVED LAND READS AGAINST THE VERSION INSTALLED NOW (adventure
## plugins, 2026-11-10; the lead's rule on the guide writer's finding): FINE;
## BROKEN — damaged under any version, which refuses the save as ever; or
## CHANGED — whole, but not what the installed version describes (a town
## moved, a quest taken out, a longer quest shortened), which holds the land
## as a missing plugin's is held ([method AdventureExpansions.held]).
const FINE := 0
const BROKEN := 1
const CHANGED := 2


static func valid_descriptor(data: Dictionary) -> bool:
	if not bool(data.get("plugin", false)):
		var provider: Variant = data.get("provider")
		if not provider is String or not String(provider).begins_with("res://") or String(provider).contains("..") \
				or not FileAccess.file_exists(provider):
			return false
	if not data.get("title") is String or not data.get("progress_schema") is Dictionary: return false
	return valid_progress(data, data.get("initial_progress", {}))


static func valid_progress(descriptor: Dictionary, state: Dictionary) -> bool:
	if descriptor.is_empty():
		return opaque_progress(state)
	var schema: Dictionary = descriptor.get("progress_schema", {})
	if schema.has("fields"):
		for key in state:
			if not schema["fields"].has(key): return false
		for key in schema["fields"]:
			var rule: Dictionary = schema["fields"][key]
			var value: Variant = state.get(key)
			if rule.get("type") == "bool":
				if not value is bool: return false
			elif rule.get("type") == "int":
				if not AdventurePlayer._is_number(value) or int(value) != value or value < rule.get("min", 0) or value > rule.get("max", 999): return false
			else: return false
		return true
	var count := int(schema.get("quests", 0))
	if count == 0: return false
	var done: Variant = state.get("quests", [])
	var pending: Variant = state.get("pending", [])
	if not done is Array or not pending is Array: return false
	var flags: Variant = schema.get("flags", [])
	if not flags is Array: return false
	# Other keys are kept as they are.
	for flag: Variant in flags:
		if state.has(flag) and not state[flag] is bool: return false
	if done.size() > count or pending.size() > int(schema.get("max_pending", 60)): return false
	var unique := {}
	for index in done:
		if not AdventurePlayer._is_number(index) or int(index) != index or index < 0 or index >= count or unique.has(int(index)): return false
		unique[int(index)] = true
	for card in pending:
		if not card is String or card.is_empty() or card.length() > 200: return false
	var stages: Variant = state.get("stages", {})
	var choices: Variant = state.get("reward_choices", [])
	if not stages is Dictionary or not choices is Array or choices.size() > count: return false
	# Each quest its own longest stage when the schema lists them (the lead's
	# ruling, 2026-11-10, after RV2-2), else the longest quest's.
	var limits: Variant = schema.get("stage_limits")
	for key in stages:
		if not key is String or not key.is_valid_int() or int(key) < 0 or int(key) >= count: return false
		var most := int(schema.get("max_stage", 2))
		if limits is Array and int(key) < (limits as Array).size() and AdventurePlayer._is_number(limits[int(key)]):
			most = int(limits[int(key)])
		if not AdventurePlayer._is_number(stages[key]) or int(stages[key]) != stages[key] or stages[key] < 0 or stages[key] > most: return false
	var owed := {}
	for index in choices:
		if not AdventurePlayer._is_number(index) or int(index) != index or not unique.has(int(index)) or owed.has(int(index)): return false
		owed[int(index)] = true
	# A switch the finale sets only with every quest done is never on before
	# (the Refuge's `liberated`).
	var complete: Variant = schema.get("complete_flags", [])
	if complete is Array:
		for flag: Variant in complete:
			if flag is String and state.get(flag, false) is bool and state.get(flag, false) and done.size() < count: return false
	return true


## [param state], a land's saved progress, against [param descriptor] (the
## installed version's; {} for a land nothing describes): [constant FINE],
## [constant BROKEN] or [constant CHANGED]. Damage is what no version could
## have written — beyond the carried bounds, or the record's shape wrong (a
## pledge list that is no list of indices, a stage that is no number, a
## switch that is no switch); a number outside what the installed version
## counts (its quests, stages, waiting cards, a finale switch on before
## every quest) is a change.
static func progress_state(descriptor: Dictionary, state: Variant) -> int:
	if not opaque_progress(state):
		return BROKEN
	if descriptor.is_empty() or valid_progress(descriptor, state):
		return FINE
	return BROKEN if progress_broken(descriptor, state) else CHANGED


## Whether [param state] is shaped wrong under any version of
## [param descriptor]'s land (the quests record's shape; a development
## fixture's own fields are its version's to say).
static func progress_broken(descriptor: Dictionary, state: Dictionary) -> bool:
	var schema: Dictionary = descriptor.get("progress_schema", {})
	if schema.has("fields"):
		return false
	var done: Variant = state.get("quests", [])
	var pending: Variant = state.get("pending", [])
	var stages: Variant = state.get("stages", {})
	var choices: Variant = state.get("reward_choices", [])
	if not done is Array or not pending is Array or not stages is Dictionary or not choices is Array:
		return true
	var unique := {}
	for index: Variant in done:
		if not _index(index) or unique.has(int(index)): return true
		unique[int(index)] = true
	for card: Variant in pending:
		if not card is String or String(card).is_empty() or String(card).length() > 200: return true
	for key: Variant in stages:
		if not key is String or not String(key).is_valid_int() or int(key) < 0 or not _index(stages[key]): return true
	var owed := {}
	for index: Variant in choices:
		if not _index(index) or not unique.has(int(index)) or owed.has(int(index)): return true
		owed[int(index)] = true
	var flags: Variant = schema.get("flags", [])
	for flag: Variant in (flags if flags is Array else []):
		if state.has(flag) and not state[flag] is bool: return true
	return false


static func _index(value: Variant) -> bool:
	return AdventurePlayer._is_number(value) and int(value) == value and value >= 0


## Whether [param state], the progress of a region nothing describes now (its
## plugin missing or refused), may be carried: a record, its keys words, at
## most [constant OPAQUE_DEPTH] deep and [constant OPAQUE_BYTES] as JSON.
static func opaque_progress(state: Variant) -> bool:
	if not state is Dictionary:
		return false
	for key: Variant in state:
		if not key is String:
			return false
	return opaque(state)


## Whether [param value] is plain data within the bounds of [constant
## OPAQUE_BYTES] and [constant OPAQUE_DEPTH] — carried as it is.
static func opaque(value: Variant) -> bool:
	return PluginPackage.depth(value, OPAQUE_DEPTH + 1) <= OPAQUE_DEPTH and JSON.stringify(value).length() <= OPAQUE_BYTES
