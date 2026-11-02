class_name ExpansionContract
extends RefCounted
## Metadata-only persistence contract. No provider or artwork loads on validation.
static func valid_descriptor(data: Dictionary) -> bool:
	if not data.get("provider") is String or not FileAccess.file_exists(data["provider"]): return false
	if not data.get("title") is String or not data.get("progress_schema") is Dictionary: return false
	return valid_progress(data, data.get("initial_progress", {}))

static func valid_progress(descriptor: Dictionary, state: Dictionary) -> bool:
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
	var count := int(schema.get("quests", descriptor.get("pledges", 0)))
	if count == 0: return false
	var done: Variant = state.get("quests", [])
	var pending: Variant = state.get("pending", [])
	if not done is Array or not pending is Array or not state.get("liberated", false) is bool: return false
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
	for key in stages:
		if not key is String or not key.is_valid_int() or int(key) < 0 or int(key) >= count: return false
		if not AdventurePlayer._is_number(stages[key]) or int(stages[key]) != stages[key] or stages[key] < 0 or stages[key] > int(schema.get("max_stage", 2)): return false
	var owed := {}
	for index in choices:
		if not AdventurePlayer._is_number(index) or int(index) != index or not unique.has(int(index)) or owed.has(int(index)): return false
		owed[int(index)] = true
	return not bool(state.get("liberated", false)) or done.size() == count
