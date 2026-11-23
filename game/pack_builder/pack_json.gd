class_name PackJson
extends RefCounted
## THE PACK TOOLS' JSON, BYTE FOR BYTE. Every numbered pack's `catalog.json`,
## `cards.json` and `manifest.json` is written by `tools/pack_N_*.py` as
##
##     json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
##
## and each tool's `verify` compares the metadata in a zip with what it
## writes itself, byte for byte. A pack the game builds ([PackWriter]) has
## to pass that check too, so this is that writer and nothing else: keys in
## code-point order, two spaces a level, `": "` and `","` with no trailing
## blank, `[]` and `{}` for the empty ones, text as it is (no `\uXXXX` for
## letters beyond ASCII) with only `"`, `\` and the control characters
## escaped the way Python escapes them.
##
## NUMBERS. The engine's reader hands every number over as a float; the
## trusted files hold whole numbers only (counts, a pack's number), so a
## whole float is written as the integer it was. Anything else — a fraction,
## an infinity — is not something the pack tools ever write, and [method
## bytes] returns nothing rather than a guess ([member refused] says what).

## What the last [method bytes] could not write, or "".
static var refused := ""


## [param value] as the pack tools write it, with the closing newline; an
## empty array when it holds something they never write.
static func bytes(value: Variant) -> PackedByteArray:
	refused = ""
	var parts := PackedStringArray()
	if not _write(value, 0, parts):
		return PackedByteArray()
	parts.append("\n")
	return "".join(parts).to_utf8_buffer()


static func _write(value: Variant, depth: int, parts: PackedStringArray) -> bool:
	match typeof(value):
		TYPE_NIL:
			parts.append("null")
		TYPE_BOOL:
			parts.append("true" if value else "false")
		TYPE_INT:
			parts.append(str(int(value)))
		TYPE_FLOAT:
			var number: float = value
			if is_nan(number) or is_inf(number) or number != floorf(number) \
					or absf(number) > 9007199254740992.0:
				refused = "a number that is not whole: %s" % str(number)
				return false
			parts.append(str(int(number)))
		TYPE_STRING, TYPE_STRING_NAME:
			parts.append(_text(String(value)))
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var items: Array = Array(value)
			if items.is_empty():
				parts.append("[]")
				return true
			var inner := "  ".repeat(depth + 1)
			parts.append("[\n")
			for i in items.size():
				parts.append(inner)
				if not _write(items[i], depth + 1, parts):
					return false
				parts.append(",\n" if i < items.size() - 1 else "\n")
			parts.append("  ".repeat(depth) + "]")
		TYPE_DICTIONARY:
			var table: Dictionary = value
			if table.is_empty():
				parts.append("{}")
				return true
			var keys: Array = []
			for key: Variant in table.keys():
				if not (key is String or key is StringName):
					refused = "a key that is not text"
					return false
				keys.append(String(key))
			keys.sort_custom(less)
			var inner := "  ".repeat(depth + 1)
			parts.append("{\n")
			for i in keys.size():
				parts.append(inner + _text(keys[i]) + ": ")
				if not _write(table[keys[i]], depth + 1, parts):
					return false
				parts.append(",\n" if i < keys.size() - 1 else "\n")
			parts.append("  ".repeat(depth) + "}")
		_:
			refused = "a value JSON has no word for (type %d)" % typeof(value)
			return false
	return true


## Python's order for two texts: code point by code point, the shorter
## first when one begins the other. Named, not left to the engine's own
## sort, because the bytes depend on it.
static func less(a: String, b: String) -> bool:
	var shared := mini(a.length(), b.length())
	for i in shared:
		var left := a.unicode_at(i)
		var right := b.unicode_at(i)
		if left != right:
			return left < right
	return a.length() < b.length()


## [param names] in that order, a copy.
static func sorted(names: Array) -> Array:
	var out := names.duplicate()
	out.sort_custom(less)
	return out


static func _text(value: String) -> String:
	var out := PackedStringArray(["\""])
	var run_from := 0
	for i in value.length():
		var code := value.unicode_at(i)
		var escaped := ""
		match code:
			0x22: escaped = "\\\""
			0x5C: escaped = "\\\\"
			0x0A: escaped = "\\n"
			0x0D: escaped = "\\r"
			0x09: escaped = "\\t"
			0x08: escaped = "\\b"
			0x0C: escaped = "\\f"
			_:
				if code < 0x20:
					escaped = "\\u%04x" % code
		if escaped != "":
			if i > run_from:
				out.append(value.substr(run_from, i - run_from))
			out.append(escaped)
			run_from = i + 1
	if run_from < value.length():
		out.append(value.substr(run_from))
	out.append("\"")
	return "".join(out)
