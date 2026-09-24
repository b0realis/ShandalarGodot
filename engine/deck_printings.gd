class_name DeckPrintings
extends RefCounted
## Optional cosmetic deck metadata. Counts, legality and rules stay name-based.
## Values are catalogue identifiers, never paths, URLs or executable resources.
const PREFIX := "# printing:"
const DEC_PREFIX := "// printing:"
const LIMIT := 200

static func valid_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 32: return false
	var parts: PackedStringArray = value.split(":")
	if parts.size() > 2 or parts[0].length() < 2 or parts[0].length() > 8: return false
	for part in parts:
		if part.is_empty(): return false
		for c in part:
			if not "abcdefghijklmnopqrstuvwxyz0123456789".contains(c): return false
	return true

static func valid_map(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size() > LIMIT: return false
	for name in value:
		if not name is String or name.length() > 128 or not names.has(name) or not valid_id(value[name]): return false
	return true

static func keep_present(value: Dictionary, names: Array) -> Dictionary:
	var out := {}
	for name in names:
		if out.size() >= LIMIT: break
		if name is String and name.length() <= 128 and valid_id(value.get(name)):
			out[name] = value[name]
	return out

static func read_comment(line: String, into: Dictionary) -> bool:
	var prefix := PREFIX if line.begins_with(PREFIX) else DEC_PREFIX
	if not line.begins_with(prefix): return false
	if line.length() > 512 or into.size() >= LIMIT: return true
	var parser := JSON.new()
	if parser.parse(line.substr(prefix.length())) != OK: return true
	var row: Variant = parser.data
	if row is Array and row.size() == 2 and row[0] is String \
			and not row[0].is_empty() and row[0].length() <= 128 and valid_id(row[1]):
		into[row[0]] = row[1]
	return true

static func comments(value: Dictionary, names: Array, community := false) -> PackedStringArray:
	var out := PackedStringArray()
	var choices := keep_present(value, names)
	var ordered := choices.keys()
	ordered.sort()
	for name in ordered:
		out.append((DEC_PREFIX if community else PREFIX) + " " + JSON.stringify([name, choices[name]]))
	return out
