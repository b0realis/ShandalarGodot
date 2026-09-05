extends GutTest
## THE FIDELITY LEDGER, PINNED TO THE CODE — CONTRIBUTING.md rule 6 says a card
## with a rules shortcut carries the word `SIMPLIFIED` at the site AND a
## row in `docs/simplified-cards.md`, and until 2026-09-02 nothing checked
## that the two agreed: the ledger itself asks for `grep -rl SIMPLIFIED
## cards/sets/` to "always agree with this table", and the first run of
## this file found two cards named in group rows whose files did not carry
## the word at all (Old Man of the Sea, Master of the Hunt).
##
## Both directions, because each catches a different way of drifting:
##
## 1. **Every marked file is named in the ledger** — a shortcut that was
##    marked at the site and never written down.
## 2. **Every card a row names carries the marker** — a row that outlived
##    its marker (the shortcut was lifted and the row forgotten), or a
##    group row that named a member nobody marked.
##
## The ledger is prose, so "named" means the card's registry name as a
## whole word — `Mountain Stronghold` does not name `Mountain`, which is
## why names are matched longest first and cut out of the text as they
## are found. Rows struck through as LIFTED are history, not claims.
##
## Card names come from each file's own header line (`## Name — cost —
## type — (set, rarity)`, rule 4), not from the registry, so this test
## needs no card loaded and runs in a few milliseconds.

const LEDGER := "res://docs/simplified-cards.md"
const SETS_ROOT := "res://cards/sets"
static var MARKER := RegEx.create_from_string("\\bSIMPLIFIED\\b")
static var HEADER := RegEx.create_from_string("^## (.+?) — ")

## name → path, for every card file under cards/sets/.
var _files := {}
## The whole ledger, and its data rows' first cells.
var _ledger := ""
var _row_cells: Array[String] = []


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
