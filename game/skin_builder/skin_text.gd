class_name SkinText
extends RefCounted
## THE TEXT A 1997 INSTALL HOLDS, READ THE WAY THE PYTHON IMPORTER READS IT.
##
## The skin builder ([SkinBuildJob]) is a port of `tools/import_original.py`
## and must write the same skin, so the few places where the importer leans
## on Python's own text rules are done here by those rules, not the
## engine's: which bytes a code page turns into which letters, where a
## line ends ([method lines]), what counts as white space ([method strip],
## [method words]), how a CSV row is cut ([method csv_rows]) and how a
## value is written as JSON ([method json]). Pure functions on private
## data: any thread may call them.

## Windows-1252's own letters for the bytes 0x80-0x9F (the rest is
## Latin-1); 0xFFFD where the code page names none — Python's
## `errors="replace"`.
const CP1252_HIGH: Array[int] = [
	0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
	0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
	0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
	0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178,
]

## Python's `str.splitlines` boundaries besides `\n` and `\r`.
const LINE_ENDS: Array[int] = [0x0B, 0x0C, 0x1C, 0x1D, 0x1E, 0x85, 0x2028, 0x2029]

## What Python's `str.strip` and `str.split` call white space.
const SPACES: Array[int] = [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
	0x85, 0xA0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006,
	0x2007, 0x2008, 0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000]


## [param bytes] as text: Latin-1, or Windows-1252 with [param cp1252].
## A NUL byte, which a String cannot hold, becomes a space.
static func decode(bytes: PackedByteArray, cp1252 := false) -> String:
	var n := bytes.size()
	var points := PackedInt32Array()
	points.resize(n)
	for i in n:
		var b := bytes[i]
		if b == 0:
			b = 0x20
		elif cp1252 and b >= 0x80 and b < 0xA0:
			b = CP1252_HIGH[b - 0x80]
		points[i] = b
	return points.to_byte_array().get_string_from_utf32()


## [param text] cut where Python's `str.splitlines` cuts it, the line
## ends left out; `\r\n` is one end.
static func lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var n := text.length()
	var start := 0
	var i := 0
	while i < n:
		var c := text.unicode_at(i)
		if c == 0x0A or c == 0x0D or (c >= 0x0B and LINE_ENDS.has(c)):
			out.append(text.substr(start, i - start))
			if c == 0x0D and i + 1 < n and text.unicode_at(i + 1) == 0x0A:
				i += 1
			start = i + 1
		i += 1
	if start < n:
		out.append(text.substr(start))
	return out


static func is_space(code: int) -> bool:
	return code == 0x20 or (code >= 0x09 and code <= 0x0D) or (code > 0x1B and SPACES.has(code))


## Python's `str.strip()`.
static func strip(text: String) -> String:
	var from := 0
	var to := text.length()
	while from < to and is_space(text.unicode_at(from)):
		from += 1
	while to > from and is_space(text.unicode_at(to - 1)):
		to -= 1
	return text.substr(from, to - from)


## Python's `str.split()` with no argument: the words between runs of
## white space.
static func words(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var n := text.length()
	var start := -1
	for i in n:
		if is_space(text.unicode_at(i)):
			if start >= 0:
				out.append(text.substr(start, i - start))
				start = -1
		elif start < 0:
			start = i
	if start >= 0:
		out.append(text.substr(start))
	return out


## Whether [param text] is one or more of the digits 0-9 and nothing else.
static func is_digits(text: String) -> bool:
	if text == "":
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		if c < 0x30 or c > 0x39:
			return false
	return true


## The rows of a CSV, as Python's `csv.reader` cuts a list of lines in its
## default dialect: commas, double quotes, a doubled quote inside quotes
## for one, a quoted field running on into the next line (the lines
## come without their ends, so nothing stands between the two), and
## nothing refused.
static func csv_rows(rows_text: PackedStringArray) -> Array:
	var out: Array = []
	var fields: Array = []
	var field := ""
	var quoted := false      # inside quotes
	var after_quote := false # a quote seen inside quotes: the end, or half of a doubled one
	var in_field := false
	var open := false        # a record is under way
	for line in rows_text:
		var n := line.length()
		var i := 0
		if not open:
			fields = []
			field = ""
			in_field = false
			open = true
		while i < n:
			var ch := line[i]
			if quoted:
				if after_quote:
					after_quote = false
					if ch == "\"":
						field += "\""
					elif ch == ",":
						fields.append(field)
						field = ""
						quoted = false
						in_field = false
					else:
						field += ch
						quoted = false
						in_field = true
				elif ch == "\"":
					after_quote = true
				else:
					# Whole runs at a time: a card's text is long.
					var stop := line.find("\"", i)
					if stop < 0:
						stop = n
					field += line.substr(i, stop - i)
					i = stop - 1
			elif not in_field:
				if ch == "\"":
					quoted = true
				elif ch == ",":
					fields.append("")
				else:
					field += ch
					in_field = true
			elif ch == ",":
				fields.append(field)
				field = ""
				in_field = false
			else:
				var stop := line.find(",", i)
				if stop < 0:
					stop = n
				field += line.substr(i, stop - i)
				i = stop - 1
			i += 1
		# The line's end.
		if quoted and not after_quote:
			continue
		if n > 0 or quoted:
			fields.append(field)
		quoted = false
		after_quote = false
		in_field = false
		field = ""
		out.append(fields)
		open = false
	if open and quoted:
		fields.append(field)
		out.append(fields)
	return out


## [param value] as JSON text: dictionaries with their keys sorted when
## [param sorted] (Python's `sort_keys`), whole numbers without a point,
## and every control character escaped — the engine's own writer leaves
## some raw, which a strict reader refuses.
static func json(value: Variant, sorted := false) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return String.num(value, 17) if value != floorf(value) else "%d.0" % int(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return _json_string(String(value))
		TYPE_DICTIONARY:
			var keys: Array = (value as Dictionary).keys()
			if sorted:
				keys.sort()
			var parts := PackedStringArray()
			for key in keys:
				parts.append(_json_string(String(key)) + ": " + json(value[key], sorted))
			return "{" + ", ".join(parts) + "}"
		_:
			var parts := PackedStringArray()
			for item in value:
				parts.append(json(item, sorted))
			return "[" + ", ".join(parts) + "]"


static func _json_string(text: String) -> String:
	var out := "\""
	var start := 0
	var n := text.length()
	for i in n:
		var c := text.unicode_at(i)
		if c >= 0x20 and c != 0x22 and c != 0x5C:
			continue
		out += text.substr(start, i - start)
		start = i + 1
		match c:
			0x22:
				out += "\\\""
			0x5C:
				out += "\\\\"
			0x0A:
				out += "\\n"
			0x0D:
				out += "\\r"
			0x09:
				out += "\\t"
			_:
				out += "\\u%04x" % c
	return out + text.substr(start) + "\""
