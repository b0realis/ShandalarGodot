extends GutTest
## THE FIDELITY LEDGER, PINNED TO THE CODE — CONTRIBUTING.md rule 6 says a card
## with a rules shortcut carries the word `SIMPLIFIED` at the site AND a
## row in `docs/simplified-cards.md`, and until 2026-09-02 nothing checked
## that the two agreed: the ledger itself asks for `grep -rl SIMPLIFIED
## cards/sets/` to "always agree with this table", and the first run of
## this file found two cards named in group rows whose files did not carry
## the word at all (Old Man of the Sea, Master of the Hunt).
##
## Three directions, because each catches a different way of drifting:
##
## 1. **Every marked file is named in the ledger** — a shortcut that was
##    marked at the site and never written down.
## 2. **Every card a row names carries the marker** — a row that outlived
##    its marker (the shortcut was lifted and the row forgotten), or a
##    group row that named a member nobody marked.
## 3. **Every marker under `engine/` names a doc that carries its row**
##    (added 2026-09-11) — the ENGINE-wide half of rule 6, which nothing
##    checked at all until now. See "THE ENGINE HALF" below.
##
## The ledger is prose, so "named" means the card's registry name as a
## whole word — `Mountain Stronghold` does not name `Mountain`, which is
## why names are matched longest first and cut out of the text as they
## are found. Rows struck through as LIFTED are history, not claims.
##
## Card names come from each file's own header line (`## Name — cost —
## type — (set, rarity)`, rule 4), not from the registry, so this test
## needs no card loaded and runs in a few milliseconds.
##
## ---------------------------------------------------------------------
## THE ENGINE HALF (2026-09-11). Rule 6 asks for a row in `ROADMAP.md`
## (engine-wide) as well as one in `simplified-cards.md` (card-scoped),
## and directions 1-2 never looked at `engine/`. The 2026-09-11 audit
## found what that cost: a row citing `mtg_game.gd:1003`, `:1170` for
## sites a thousand lines further down, and a SIXTH marker in
## `mtg_game.gd` uncounted for months because it writes `SIMPLIFIED
## (engine-wide, …)` where `grep "SIMPLIFIED:"` wanted a colon.
##
## So this direction is built to survive both of those, and the two
## decisions that make it durable are worth stating:
##
## **The matcher takes the marker in every form it is written, and the
## one mention that is NOT a marker is excluded by a rule rather than by
## a line number.** A marker OPENS the sentence it labels — `SIMPLIFIED:`,
## `SIMPLIFIED (docs/ROADMAP.md)`, `SIMPLIFIED (docs/ROADMAP.md, "…")`,
## `SIMPLIFIED (engine-wide, docs/ROADMAP.md)`, and the two that continue
## a wrapped comment (`… all fire). SIMPLIFIED (…)`) all do. `MtgGame`'s
## own header says *"Every one of them is marked SIMPLIFIED: inline at
## the exact spot"* — there the word is the OBJECT of a sentence about
## markers, so it labels nothing and is not one. Every mention the rule
## rejects must still be named in [constant PROSE_MENTIONS] with the
## words that make it prose, so a new one cannot slip past in silence.
##
## **Nothing is pinned by a line number, because line numbers are what
## drifted.** A marker is pinned to a doc by an ANCHOR that survives an
## engine pass: the row's own quoted key (`SIMPLIFIED (docs/ROADMAP.md,
## "The crack-back search")`), the NAME of the code the marker labels —
## the function it sits in, the member or function its doc comment
## introduces, the class whose docstring holds it, or the declarations a
## section banner covers — or, for a file carrying exactly ONE marker,
## the file's own name, because there the file IS the site. Six markers
## live in `mtg_game.gd`, so `mtg_game.gd` names no site and those six
## must be found by key or by symbol.
##
## "Carries its row" means: of the docs a marker names, at least one
## holds one of its anchors. At least one and not all, because rule 6
## asks for A row — a marker that names two docs is offering further
## reading, not promising two ledgers. Every doc named must EXIST, which
## is the half that cannot be satisfied by accident.
##
## The count is deliberately not asserted. Ten rows stood on 2026-09-11
## and the ledger is meant to shrink; a hard ten would fail on the day
## someone lifts one, which is the opposite of what this file is for.

const LEDGER := "res://docs/simplified-cards.md"
const SETS_ROOT := "res://cards/sets"
const ENGINE_ROOT := "res://engine"
static var MARKER := RegEx.create_from_string("\\bSIMPLIFIED\\b")
static var HEADER := RegEx.create_from_string("^## (.+?) — ")
static var DOC_PATH := RegEx.create_from_string("docs/[\\w.-]+\\.md")
static var PAREN := RegEx.create_from_string("\\(([^()]*)\\)")
static var DOC_TAIL := RegEx.create_from_string("docs/[\\w.-]+\\.md\\s*$")
static var QUOTED := RegEx.create_from_string("[\"“]([^\"”]+)[\"”]")
static var DECL := RegEx.create_from_string(
	"^(?:static func |func |var |const |signal |@export var |class )([A-Za-z_][A-Za-z_0-9]*)")
static var FUNC_DECL := RegEx.create_from_string("^(?:static )?func ([A-Za-z_0-9]+)")
static var CLASS_DECL := RegEx.create_from_string("^class_name ([A-Za-z_0-9]+)")
static var BANNER := RegEx.create_from_string("^# -{3,}")

## The mentions of the word under `engine/` that are PROSE ABOUT the
## convention rather than markers on a site — keyed by file, valued by
## the words that make them prose. The matcher rejects them on its own
## rule (they do not open their sentence); this list is what stops a new
## one from being rejected in silence, and it is checked in both
## directions: no unexplained mention, and no exemption left behind.
const PROSE_MENTIONS := {
	"res://engine/mtg_game.gd":
		["marked SIMPLIFIED: inline at the exact spot"],
}

## name → path, for every card file under cards/sets/.
var _files := {}
## The whole ledger, and its data rows' first cells.
var _ledger := ""
var _row_cells: Array[String] = []
## Every `.gd` under engine/, and every mention of the word in them,
## classified into markers and prose (direction 3).
var _engine_files: Array[String] = []
var _engine_marks: Array[Dictionary] = []
var _engine_prose: Array[Dictionary] = []
## doc path → its text, read once.
var _docs := {}


func before_all() -> void:
	for set_dir in DirAccess.get_directories_at(SETS_ROOT):
		var dir_path := "%s/%s" % [SETS_ROOT, set_dir]
		for file in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".gd") or file.begins_with("_"):
				continue
			var path := "%s/%s" % [dir_path, file]
			var card_name := _header_name(path)
			if card_name != "":
				_files[card_name] = path
	_ledger = FileAccess.get_file_as_string(LEDGER)
	var seen_header := false
	for line in _ledger.split("\n"):
		if not line.begins_with("|"):
			continue
		if not seen_header:
			seen_header = true          # `| Card | What's simplified | ...`
			continue
		if line.begins_with("|---"):
			continue
		_row_cells.append(line.split("|")[1])
	_gd_files_under(ENGINE_ROOT, _engine_files)
	_engine_files.sort()
	var marked_files := {}
	for path in _engine_files:
		for mention in _mentions_in(path):
			if bool(mention["is_marker"]):
				_engine_marks.append(mention)
				marked_files[path] = int(marked_files.get(path, 0)) + 1
			else:
				_engine_prose.append(mention)
	# A file's own name identifies the site only while it holds ONE marker.
	for mention in _engine_marks:
		mention["file_is_the_site"] = int(marked_files[mention["path"]]) == 1


## The card's name from its header comment — the first `## Name — ` line
## among the file's first three.
static func _header_name(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	for _i in 3:
		if file.eof_reached():
			break
		var m := HEADER.search(file.get_line())
		if m != null:
			return m.get_string(1)
	return ""


static func _is_marked(path: String) -> bool:
	return MARKER.search(FileAccess.get_file_as_string(path)) != null


## Is [param card_name] in [param text] as a whole word? A letter or an
## apostrophe on either side means it is part of another word.
static func _names_in_text(card_name: String, text: String) -> bool:
	var pattern := RegEx.create_from_string(
		"(?<![\\w'])%s(?![\\w'])" % _escape(card_name))
	return pattern.search(text) != null


static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		if "\\^$.|?*+()[]{}".contains(ch):
			out += "\\"
		out += ch
	return out


## Every registry card a cell names — longest names first, each cut out
## of the text once found, so a name inside a longer name is not counted.
func _cards_named_in(cell: String) -> Array[String]:
	var names: Array[String] = []
	names.assign(_files.keys())
	names.sort_custom(func(a: String, b: String) -> bool:
		return a.length() > b.length())
	var out: Array[String] = []
	var text := cell
	for card_name in names:
		if _names_in_text(card_name, text):
			out.append(card_name)
			text = text.replace(card_name, " ")
	return out


func test_the_scan_found_the_pool_and_the_ledger() -> void:
	assert_gt(_files.size(), 800, "every card file has a header name")
	# The ledger is MEANT to shrink toward empty (each lift deletes a row),
	# so the floor is "the table was found", not a row count.
	assert_true(_ledger.contains("| Card | What's simplified |"),
		"the ledger's table was read")
	assert_true(_files.has("Grizzly Bears"))


func test_every_marked_card_is_named_in_the_ledger() -> void:
	var unlisted: Array[String] = []
	for card_name in _files:
		if not _is_marked(_files[card_name]):
			continue
		if not _names_in_text(card_name, _ledger):
			unlisted.append("%s (%s)" % [card_name, _files[card_name]])
	assert_eq(unlisted, [],
		"marked SIMPLIFIED but not named anywhere in docs/simplified-cards.md")


func test_every_card_a_row_names_carries_the_marker() -> void:
	var unmarked: Array[String] = []
	for cell in _row_cells:
		if cell.contains("LIFTED"):
			continue                    # struck through: history, not a claim
		var cards := _cards_named_in(cell)
		assert_false(cards.is_empty(),
			"a row that names no card in the pool: %s" % cell.strip_edges().left(60))
		for card_name in cards:
			if not _is_marked(_files[card_name]):
				unmarked.append("%s — row %s" % [card_name, cell.strip_edges().left(50)])
	assert_eq(unmarked, [],
		"named in the ledger but the file carries no SIMPLIFIED marker")


func test_a_name_inside_a_longer_name_is_not_a_match() -> void:
	# `Mountain Stronghold` in the banding row must not drag `Mountain` in.
	var cards := _cards_named_in("(Mountain Stronghold, Seafarer's Quay)")
	assert_has(cards, "Mountain Stronghold")
	assert_has(cards, "Seafarer's Quay")
	assert_does_not_have(cards, "Mountain")
	assert_false(_names_in_text("Jandor", "Jandor's Ring"),
		"an apostrophe after the word means another word")
	assert_true(_names_in_text("Jandor's Ring", "the Jandor's Ring row"))


# ------------------------------------------------------------------------
# DIRECTION 3 (2026-09-11): the markers under engine/ and the docs that
# carry their rows. Everything below is pure enough to be handed a made-up
# file, which is how the two failure modes are pinned rather than merely
# demonstrated (see the last two tests).


## Every `.gd` under [param root], recursively.
static func _gd_files_under(root: String, out: Array[String]) -> void:
	for file in DirAccess.get_files_at(root):
		if file.ends_with(".gd"):
			out.append("%s/%s" % [root, file])
	for sub in DirAccess.get_directories_at(root):
		_gd_files_under("%s/%s" % [root, sub], out)


static func _is_comment(line: String) -> bool:
	return line.strip_edges().begins_with("#")


## A comment line's own words: `\t## the words` → `the words`. A comment
## line with nothing after the hashes gives "", which is what separates
## one PARAGRAPH of a comment block from the next.
static func _comment_text(line: String) -> String:
	return line.strip_edges().lstrip("#").strip_edges()


## The comment paragraph around line [param i] — the run of comment lines
## it belongs to, bounded by a blank comment line (`##`) or by code.
static func _paragraph(lines: PackedStringArray, i: int) -> Vector2i:
	var a := i
	while a > 0 and _is_comment(lines[a - 1]) and _comment_text(lines[a - 1]) != "":
		a -= 1
	var b := i
	while b + 1 < lines.size() and _is_comment(lines[b + 1]) \
			and _comment_text(lines[b + 1]) != "":
		b += 1
	return Vector2i(a, b)


static func _paragraph_text(lines: PackedStringArray, a: int, b: int) -> String:
	var out := ""
	for j in range(a, b + 1):
		out += _comment_text(lines[j]) + " "
	return out.strip_edges()


## Does the marker on line [param i] OPEN the sentence it labels? That is
## what tells a marker from a mention of one: everything before it in its
## own paragraph is either nothing or a finished sentence. A closing
## bracket or quote does not end a sentence, so they are stripped before
## the last character is read (`… all fire). SIMPLIFIED` is a marker).
static func _opens_its_sentence(lines: PackedStringArray, a: int, i: int) -> bool:
	var own := _comment_text(lines[i])
	var m := MARKER.search(own)
	if m == null:
		return false
	var head := _paragraph_text(lines, a, i - 1) if i > a else ""
	head = (head + " " + own.substr(0, m.get_start())).strip_edges()
	head = head.rstrip(")]\"”’'`*")
	if head == "":
		return true
	return ".!?".contains(head.right(1))


## The quoted keys a marker cites — the row's own words. A key counts only
## inside a parenthesis that names a doc or follows one: `(docs/ROADMAP.md,
## "The crack-back search")`, `docs/ROADMAP.md ("mid-resolution choices")`.
## Any other quotation in the paragraph is prose, not a citation.
static func _citation_keys(text: String) -> Array[String]:
	var out: Array[String] = []
	for group in PAREN.search_all(text):
		var inner := group.get_string(1)
		var before := text.substr(0, group.get_start())
		if DOC_PATH.search(inner) == null and DOC_TAIL.search(before) == null:
			continue
		for quoted in QUOTED.search_all(inner):
			out.append(quoted.get_string(1))
	return out


## The NAMES of the code a marker labels, which is what survives an engine
## pass. Four shapes, in the order they are told apart:
##   * a marker indented inside a body labels the function it is in;
##   * a comment block with no declaration above it is the class docstring
##     and labels the class;
##   * a doc comment labels the declaration on the line below it;
##   * a section banner labels every declaration down to the next banner.
static func _labelled_symbols(lines: PackedStringArray, a: int, b: int) -> Array[String]:
	if lines[a].begins_with(" ") or lines[a].begins_with("\t"):
		for j in range(a, -1, -1):
			var fn := FUNC_DECL.search(lines[j])
			if fn != null:
				return [fn.get_string(1)]
	var any_decl_above := false
	for j in a:
		if DECL.search(lines[j]) != null:
			any_decl_above = true
			break
	if not any_decl_above:
		for j in mini(4, lines.size()):
			var cd := CLASS_DECL.search(lines[j])
			if cd != null:
				return [cd.get_string(1)]
	if b + 1 < lines.size():
		var next_decl := DECL.search(lines[b + 1])
		if next_decl != null:
			return [next_decl.get_string(1)]
	var out: Array[String] = []
	for j in range(b + 1, lines.size()):
		if BANNER.search(lines[j]) != null:
			break
		var decl := DECL.search(lines[j])
		if decl != null:
			out.append(decl.get_string(1))
	return out


## Every mention of the word in one file, classified. A mention that is
## not a comment at all, or whose word does not open its sentence, is not
## a marker — [constant PROSE_MENTIONS] is where those must be explained.
func _mentions_in(path: String) -> Array[Dictionary]:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var out: Array[Dictionary] = []
	for i in lines.size():
		if MARKER.search(lines[i]) == null:
			continue
		var is_comment := _is_comment(lines[i])
		var span := _paragraph(lines, i) if is_comment else Vector2i(i, i)
		var text := _paragraph_text(lines, span.x, span.y) if is_comment else lines[i]
		var is_marker := is_comment and _opens_its_sentence(lines, span.x, i)
		var docs: Array[String] = []
		for hit in DOC_PATH.search_all(text):
			var doc := "res://%s" % hit.get_string(0)
			if not docs.has(doc):
				docs.append(doc)
		var keys: Array[String] = []
		var symbols: Array[String] = []
		if is_marker:
			keys = _citation_keys(text)
			symbols = _labelled_symbols(lines, span.x, span.y)
		out.append({
			"path": path,
			"line": i + 1,
			"is_marker": is_marker,
			"quote": lines[i].strip_edges(),
			"text": text,
			"docs": docs,
			"keys": keys,
			"symbols": symbols,
			"file_is_the_site": false,
		})
	return out


func _doc_text(doc: String) -> String:
	if not _docs.has(doc):
		_docs[doc] = FileAccess.get_file_as_string(doc)
	return _docs[doc]


## A symbol is named as a whole word — `_build` is not `_build_combat_model`.
## Backticks, dots and brackets around it are not part of the name.
static func _symbol_in_text(symbol: String, text: String) -> bool:
	var pattern := RegEx.create_from_string(
		"(?<![\\w])%s(?![\\w])" % _escape(symbol))
	return pattern.search(text) != null


## Which doc carries this marker's row, and by which anchor? Returns the
## empty dictionary when none of them does — the finding this direction
## exists to make.
func _anchor_hit(mention: Dictionary) -> Dictionary:
	var docs: Array = mention["docs"]
	var keys: Array = mention["keys"]
	var symbols: Array = mention["symbols"]
	for doc in docs:
		var text: String = _doc_text(doc)
		# A key is the row's own words: matched whole, and case-insensitively,
		# because a doc sentence-cases a row title when it opens a sentence
		# ("Text changes (Magical Hack…)" for the marker's "text changes").
		for key in keys:
			if text.to_lower().contains(String(key).to_lower()):
				return {"doc": doc, "kind": "key", "anchor": key}
		for symbol in symbols:
			if _symbol_in_text(String(symbol), text):
				return {"doc": doc, "kind": "symbol", "anchor": symbol}
		if bool(mention["file_is_the_site"]):
			var base: String = String(mention["path"]).get_file()
			if _symbol_in_text(base, text):
				return {"doc": doc, "kind": "file", "anchor": base}
	return {}


static func _describe(mention: Dictionary) -> String:
	return "%s:%d — %s" % [mention["path"], mention["line"],
		String(mention["quote"]).left(72)]


func test_the_engine_scan_read_the_tree() -> void:
	# The floor is "engine/ was read", not a marker count: the engine
	# ledger is meant to shrink toward empty, one lifted row at a time,
	# and a count here would fail the pass that lifts one.
	assert_gt(_engine_files.size(), 50, "every .gd under engine/ was scanned")
	assert_true(_engine_files.has("res://engine/mtg_game.gd"))


func test_every_engine_marker_names_a_doc_that_carries_its_row() -> void:
	var unpinned: Array[String] = []
	for mention in _engine_marks:
		var docs: Array = mention["docs"]
		if docs.is_empty():
			unpinned.append("%s\n      names no doc at all — rule 6 wants a row in docs/"
				% _describe(mention))
			continue
		var missing: Array[String] = []
		for doc in docs:
			if not FileAccess.file_exists(doc):
				missing.append(String(doc))
		if not missing.is_empty():
			unpinned.append("%s\n      names a doc that does not exist: %s"
				% [_describe(mention), ", ".join(missing)])
			continue
		if _anchor_hit(mention).is_empty():
			var keys: Array = mention["keys"]
			var symbols: Array = mention["symbols"]
			unpinned.append(("%s\n      no row in %s carries it — looked for "
				+ "key(s) %s and symbol(s) %s") % [_describe(mention),
				", ".join(PackedStringArray(docs)), str(keys), str(symbols)])
	# GUT elides the middle of a long array in its failure line, so the
	# findings are printed in full first: an unpinned marker is worth a
	# reader's time, and the elided form is not.
	for finding in unpinned:
		gut.p("UNPINNED ENGINE MARKER — %s" % finding)
	assert_eq(unpinned, [], ("marked SIMPLIFIED under engine/ with no row in "
		+ "the doc it names — either the row was deleted and the marker left "
		+ "behind, or the marker was added and never written down"))


func test_every_mention_that_is_not_a_marker_is_a_named_one() -> void:
	# The matcher's exclusion is a rule, not a line number — and this is
	# what stops the rule from quietly swallowing a real marker: every
	# mention it rejects has to be one of the ones we have read and named.
	var unexplained: Array[String] = []
	var used := {}
	for mention in _engine_prose:
		var listed: Array = PROSE_MENTIONS.get(mention["path"], [])
		var text: String = mention["text"]
		var matched := false
		for phrase in listed:
			if text.contains(String(phrase)):
				matched = true
				used[phrase] = true
		if not matched:
			unexplained.append(_describe(mention))
	for finding in unexplained:
		gut.p("UNEXPLAINED MENTION — %s" % finding)
	assert_eq(unexplained, [], ("a mention of SIMPLIFIED under engine/ that is "
		+ "neither a marker (it does not open its sentence) nor named in "
		+ "PROSE_MENTIONS — open the sentence to make it a marker, or add it "
		+ "there with the words that make it prose"))
	var stale: Array[String] = []
	for path in PROSE_MENTIONS:
		for phrase in PROSE_MENTIONS[path]:
			if not used.has(phrase):
				stale.append("%s — %s" % [path, phrase])
	assert_eq(stale, [], "PROSE_MENTIONS still exempts wording nothing says any more")


func test_a_marker_opens_its_sentence_and_a_mention_of_one_does_not() -> void:
	# Every form the marker is actually written in, and the one that is not
	# a marker: MtgGame's header, describing the convention itself.
	var forms := PackedStringArray([
		"\t# SIMPLIFIED: the description names the caster",
		"## SIMPLIFIED (docs/ROADMAP.md): \"X target creatures\" with",
		"## SIMPLIFIED (docs/ROADMAP.md, \"The crack-back search\"): neither",
		"# triggers all fire). SIMPLIFIED (engine-wide, docs/ROADMAP.md): only",
		"# point. SIMPLIFIED (docs/ROADMAP.md), and only under the 1997",
	])
	for form in forms:
		var lines := PackedStringArray([form])
		assert_true(_opens_its_sentence(lines, 0, 0), "a marker: %s" % form)
	var header := PackedStringArray([
		"## have no dependency analysis. Every one of them is",
		"## marked SIMPLIFIED: inline at the exact spot a future implementation",
		"## replaces.",
	])
	assert_false(_opens_its_sentence(header, 0, 1),
		"the convention's own description is not a marker")


func test_a_marker_with_no_row_is_reported() -> void:
	# A marker added and never written down — the first failure mode, on a
	# made-up file so the finding is pinned rather than merely demonstrated.
	var lines := PackedStringArray([
		"class_name Invented",
		"extends RefCounted",
		"",
		"func lose_the_game() -> void:",
		"\t# SIMPLIFIED (docs/ROADMAP.md): nobody wrote this one down.",
		"\tpass",
	])
	var span := _paragraph(lines, 4)
	assert_true(_opens_its_sentence(lines, span.x, 4), "it is a marker")
	assert_eq(_labelled_symbols(lines, span.x, span.y), ["lose_the_game"],
		"and the doc would have to name the function")
	var mention := {
		"path": "res://engine/invented.gd", "line": 5, "is_marker": true,
		"quote": lines[4], "text": _paragraph_text(lines, span.x, span.y),
		"docs": ["res://docs/ROADMAP.md"], "keys": [],
		"symbols": ["lose_the_game"], "file_is_the_site": true,
	}
	assert_eq(_anchor_hit(mention), {},
		"a function no ledger names is an unpinned marker")
	mention["docs"] = []
	assert_eq(_anchor_hit(mention), {}, "and naming no doc at all is worse")


func test_a_row_deleted_from_under_a_live_marker_is_reported() -> void:
	# The second failure mode: the row goes, the marker stays. Read a real
	# marker, then ask it of a doc that no longer carries it.
	var mentions := _mentions_in("res://engine/core/target_plan.gd")
	var marker := {}
	for mention in mentions:
		if bool(mention["is_marker"]):
			marker = mention
	assert_false(marker.is_empty(), "target_plan.gd carries one")
	marker["file_is_the_site"] = true
	assert_false(_anchor_hit(marker).is_empty(), "pinned as the tree stands")
	_docs["res://docs/INVENTED.md"] = "a ledger with every row lifted"
	marker["docs"] = ["res://docs/INVENTED.md"]
	assert_eq(_anchor_hit(marker), {},
		"a doc that carries the row no more leaves the marker unpinned")
