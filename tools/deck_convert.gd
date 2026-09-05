extends SceneTree
## DECK CONVERT — command-line converter between the deck formats the
## project speaks. Run via ./deck_convert.sh; formats inferred from file
## extensions:
##   .deck / .dec  the community (Dojo/Apprentice) text format —
##                 '4 Card Name' lines, '//' comments, 'SB:' sideboard
##   .dck          the ORIGINAL MicroProse 1997 format — '.ID<TAB>count
##                 <TAB>name' lines with per-opponent-color sideboard
##                 sections (.vNone/.vBlack/...)
##
## Reading ignores .dck numeric ids (names are authoritative). Writing
## .dck re-emits AUTHENTIC ids from cards/data/dck_ids.txt (369 ids
## harvested from an original game copy's deck files); cards without a
## known id get '.0' plus a warning — fine for interchange and editing,
## and re-harvestable as the id table grows.
##
## Conversion is LENIENT: historic decks full of cards this engine hasn't
## implemented yet convert fine (only the Deck Lab / gameplay demand
## implemented cards). The original's per-color sideboards fold into one
## combined sideboard (max count per name) when leaving .dck, and a
## combined sideboard becomes a single .vNone section when entering it —
## both directions documented and lossy ONLY in the per-color split.

const HELP := """
Deck Convert — translate between Shandalar deck formats
========================================================

USAGE
  ./deck_convert.sh INPUT OUTPUT
  ./deck_convert.sh -h | --help

  INPUT/OUTPUT formats come from their extensions:
    .deck  .dec   community text format ('4 Lightning Bolt', SB: lines)
    .dck           original MicroProse 1997 format

EXAMPLES
  ./deck_convert.sh "Decks - Original/0010.dck" lord_of_fate.dec
  ./deck_convert.sh my_brew.deck my_brew.dck

NOTES
  - Conversion never requires cards to be implemented in the engine.
  - Writing .dck uses authentic MicroProse card ids where known
    (cards/data/dck_ids.txt); unknown cards get id 0 with a warning.
  - .dck per-opponent-color sideboards fold into one combined sideboard
    on the way out (max count per name), and a combined sideboard emits
    as a single .vNone section on the way in.
"""

const ID_TABLE_PATH := "res://cards/data/dck_ids.txt"


func _initialize() -> void:
	quit(_main(OS.get_cmdline_user_args()))


func _main(argv: PackedStringArray) -> int:
	if argv.size() == 1 and (argv[0] == "-h" or argv[0] == "--help"):
		print(HELP)
		return 0
	if argv.size() != 2:
		printerr("deck_convert: expected INPUT OUTPUT (try --help)")
		return 2
	var input_path := argv[0]
	var output_path := argv[1]
	var deck := DeckList.load_file(input_path, false)   # lenient
	if not deck.errors.is_empty():
		printerr("deck_convert: problems reading '%s':" % input_path)
		for problem in deck.errors:
			printerr("  " + problem)
		return 2
	if deck.cards.is_empty():
		printerr("deck_convert: '%s' contains no cards" % input_path)
		return 2
	var out_text: String
	match output_path.get_extension().to_lower():
		"deck", "dec":
			out_text = _write_dec(deck)
		"dck":
			out_text = _write_dck(deck)
		_:
			printerr("deck_convert: unknown output format '.%s'" % output_path.get_extension())
			return 2
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("deck_convert: cannot write '%s'" % output_path)
		return 2
	file.store_string(out_text)
	print("converted '%s' (%d + %d sideboard) -> '%s'" % [
		deck.deck_name, deck.cards.size(), deck.sideboard.size(), output_path])
	return 0


## Collapse an expanded card list to [[name, count], ...] in first-seen order.
static func _grouped(expanded: Array[String]) -> Array:
	var order: Array = []
	var counts := {}
	for card_name in expanded:
		if not counts.has(card_name):
			order.append(card_name)
		counts[card_name] = int(counts.get(card_name, 0)) + 1
	var out: Array = []
	for card_name in order:
		out.append([card_name, counts[card_name]])
	return out


static func _write_dec(deck: DeckList) -> String:
	var lines := PackedStringArray()
	lines.append("// NAME : %s" % deck.deck_name)
	lines.append("// converted by Shandalar deck_convert")
	for entry in _grouped(deck.cards):
		lines.append("%d %s" % [entry[1], entry[0]])
	for entry in _grouped(deck.sideboard):
		lines.append("SB: %d %s" % [entry[1], entry[0]])
	return "\n".join(lines) + "\n"


func _write_dck(deck: DeckList) -> String:
	var ids := _load_id_table()
	var missing := PackedStringArray()
	var lines := PackedStringArray()
	lines.append(deck.deck_name)
	lines.append("")
	for entry in _grouped(deck.cards):
		lines.append(_dck_line(entry[0], entry[1], ids, missing))
	if not deck.sideboard.is_empty():
		lines.append("")
		lines.append(".vNone")
		for entry in _grouped(deck.sideboard):
			lines.append(_dck_line(entry[0], entry[1], ids, missing))
	if not missing.is_empty():
		printerr("deck_convert: no MicroProse id known for: %s (emitted .0)"
			% ", ".join(missing))
	return "\n".join(lines) + "\n"


static func _dck_line(card_name: String, count: int, ids: Dictionary,
		missing: PackedStringArray) -> String:
	var id := int(ids.get(card_name, 0))
	if id == 0:
		missing.append(card_name)
	return ".%d\t%d\t%s" % [id, count, card_name]


static func _load_id_table() -> Dictionary:
	var ids := {}
	var file := FileAccess.open(ID_TABLE_PATH, FileAccess.READ)
	if file == null:
		return ids
	for raw_line in file.get_as_text().split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var split := line.rsplit("|", true, 1)
		if split.size() == 2:
			ids[split[0].strip_edges()] = split[1].strip_edges().to_int()
	return ids
