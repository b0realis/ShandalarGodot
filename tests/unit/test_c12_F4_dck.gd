extends GutTest
## THE 1997 `.dck`, BOTH WAYS (the bug campaign c12, h5-2).
##
##   1. A deck the 1997 deck builder saved — a player's deck, as in the
##      game's Playdeck folder — opens with eight `;` lines (deckdll.c
##      `save_deck`, 5249-5268 in the decompilation): name, description,
##      author, e-mail, date, deck face, edition, comments. Our reader took
##      the first as a bare title and the other seven as broken card lines,
##      so Import refused every such deck.
##   2. Our reader cut every `.dck` name at " (" — right for the numbered
##      opponent decks ("Lord of Fate (Bl/Wh, 4th Edition)"), wrong for a
##      name of the player's: "Sligh (1997 tribute)" came back "Sligh".
##   3. Our export wrote the bare name and a blank line. The 1997 deck
##      builder's load gives up on a file without the eight `;` lines
##      (5306-5370) and its Load list leaves it out (2244-2262), so "for the
##      original game" was not true. The 1997 loader is modelled here byte
##      for byte — fgets() into the buffer sizes it uses — and the export
##      is held to it.
##
## The player deck below is SHAPED like the game's own (CRLF, the `;`
## lines, `.id TAB count TAB name`) with neutral words of ours in it.

const PLAYER_DECK := ";Fire and Ice\r\n;\r\n;A. Player\r\n;\r\n;November 25, 1997\r\n;1\r\n;4th Edition\r\n;Keep two blue open for the counterspell.\r\n\r\n.48\t4\tCounterspell\r\n.145\t4\tLightning Bolt\r\n.164\t10\tMountain\r\n.126\t10\tIsland\r\n"

## The fgets() buffer sizes of the 1997 `load_deck`, one per `;` line.
const LOAD_BUFFERS := [0x1f, 0x15, 0x51, 0x51, 0x16, 0x10, 0x10, 0x191]

var _made: Array[String] = []


func after_each() -> void:
	for path in _made:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made.clear()


# ------------------------------------------------ 1. a player's deck --

func test_a_1997_player_deck_reads_with_its_name_and_its_cards() -> void:
	var deck := DeckList.from_text(PLAYER_DECK, "fire_and_ice.dck", true)
	assert_eq(deck.errors, [], "the seven other `;` lines are not card lines")
	assert_eq(deck.deck_name, "Fire and Ice", "the name is the first `;` line")
	assert_eq(deck.cards.size(), 28)
	assert_eq(deck.cards.count("Counterspell"), 4)


func test_import_opens_a_1997_player_deck_from_a_file_and_from_a_paste() -> void:
	var path := "user://c12_f4_fire_and_ice.dck"
	_made.append(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(PLAYER_DECK)
	file.close()
	var report := []
	var model := DeckStore.import_file(path, report)
	assert_not_null(model, str(report))
	if model != null:
		assert_eq(model.deck_name, "Fire and Ice")
		assert_eq(model.total(), 28)
	var pasted := DeckStore.import_text(PLAYER_DECK, "pasted", report)
	assert_not_null(pasted, str(report))
	if pasted != null:
		assert_eq(pasted.deck_name, "Fire and Ice")


func test_a_name_line_with_the_semicolon_is_kept_whole() -> void:
	var deck := DeckList.new()
	deck.parse_dck(";Sligh (1997 tribute)\n;\n;\n;\n;\n;1\n;4th Edition\n;\n\n.164\t2\tMountain\n",
		"fallback", true)
	assert_eq(deck.errors, [])
	assert_eq(deck.deck_name, "Sligh (1997 tribute)", "not cut at \" (\"")


func test_an_opponent_deck_without_the_header_reads_as_it_always_did() -> void:
	var deck := DeckList.new()
	deck.parse_dck("Lord of Fate (Bl/Wh, 4th Edition)\n\n.164\t2\tMountain\n", "fallback", true)
	assert_eq(deck.errors, [])
	assert_eq(deck.deck_name, "Lord of Fate", "the colours and edition are still cut off")
	var stray := DeckList.new()
	stray.parse_dck("Old Deck\n;not a card\n.164\t2\tMountain\n", "fallback", true)
	assert_eq(stray.errors.size(), 1,
		"a `;` line is passed over only in a deck that opens with the header")


func test_an_empty_name_line_falls_back_to_the_file_name() -> void:
	var deck := DeckList.from_text(";\n;\n;\n;\n;\n;1\n;4th Edition\n;\n\n.164\t2\tMountain\n",
		"nameless.dck", true)
	assert_eq(deck.errors, [])
	assert_eq(deck.deck_name, "nameless")


# ---------------------------------------------------- 2-3. the export --

func test_the_export_writes_the_deck_builders_eight_lines_then_a_blank_one() -> void:
	var model := _model("Sligh (1997 tribute)")
	model.notes = "Burn them out.\nSide in the Shatters."
	var lines := model.to_dck_text(DeckStore.dck_ids()).split("\n")
	assert_eq(Array(lines.slice(0, 4)), [";Sligh (1997 tribute)", ";", ";", ";"],
		"name, then description, author and e-mail left empty")
	var date := RegEx.create_from_string("^;(January|February|March|April|May|June|July|August|September|October|November|December) \\d\\d, \\d{4}$")
	assert_not_null(date.search(lines[4]), "today, as the 1997 dialog writes a date: " + lines[4])
	assert_eq(Array(lines.slice(5, 9)), [";1", ";4th Edition", ";Burn them out. Side in the Shatters.", ""],
		"the first deck face, the edition, the notes on one line, a blank line")
	assert_true(lines[9].begins_with(".") and lines[9].contains("\t"), "the cards follow: " + lines[9])


func test_our_export_reads_back_whole() -> void:
	var model := _model("Sligh (1997 tribute)")
	model.sideboard["Shatter"] = 2
	var back := DeckList.new()
	back.parse_dck(model.to_dck_text(DeckStore.dck_ids()), "fallback", true)
	assert_eq(back.errors, [])
	assert_eq(back.deck_name, "Sligh (1997 tribute)")
	assert_eq(back.cards.count("Mountain"), 20)
	assert_eq(back.cards.count("Lightning Bolt"), 4)
	assert_eq(back.sideboard.count("Shatter"), 2)


func test_the_1997_loader_takes_the_export_however_long_its_fields() -> void:
	# A long title, notes past the Comments box in a script past ASCII:
	# each field must fit the buffer the 1997 load reads it into, or the
	# file is refused there.
	var model := _model("A Very Long Deck Title — Ωmega Éowyn Edition of Doom")
	var paragraph := "Ærøskøbing plans: " + "hold the counter, then burn. ".repeat(30)
	model.notes = paragraph + "\n" + paragraph
	var text := model.to_dck_text(DeckStore.dck_ids())
	var loaded := _load_1997(text.to_utf8_buffer())
	assert_eq(loaded.get("error", ""), "", "the 1997 loader takes it")
	# ASCII, and cut at the 28 characters the Deck Info title box takes.
	assert_eq(loaded.get("name", ""), "A Very Long Deck Title mega")
	for i in 8:
		var line := text.split("\n")[i]
		assert_eq(line.to_utf8_buffer().size(), line.length(), "line %d is plain ASCII" % (i + 1))
	assert_eq(int(loaded.get("cards", 0)), 24, "and every card line after the header")


func test_the_exported_file_is_named_as_the_1997_load_list_opens_it() -> void:
	# The Load list reads the first line and opens `playdeck\<name>.dck`.
	var model := _model("Sligh (1997 tribute)")
	var written := []
	assert_eq(DeckStore.export_deck(model, ".dck", written), "")
	assert_eq(written.size(), 1)
	if written.is_empty():
		return
	var path := String(written[0])
	_made.append(path)
	assert_eq(path.get_file(), "Sligh (1997 tribute).dck")
	var bytes := FileAccess.get_file_as_bytes(path)
	var loaded := _load_1997(bytes)
	assert_eq(loaded.get("error", ""), "")
	assert_eq(String(loaded.get("name", "")) + ".dck", path.get_file(),
		"the name on its first line is its file's name")
	var back := DeckList.load_file(path, true)
	assert_eq(back.deck_name, "Sligh (1997 tribute)")


func test_a_title_no_windows_file_could_hold_is_made_one_that_can() -> void:
	assert_eq(_title("Burn: the <Deck>?"), "Burn the Deck")
	assert_eq(_title("con"), "con deck", "CON.dck would open the console")
	assert_eq(_title("Lpt1"), "Lpt1 deck")
	var cyrillic := _title("Колода огня")
	assert_true(cyrillic.begins_with("Deck ") and cyrillic.length() == 13, cyrillic)
	assert_ne(cyrillic, _title("Колода воды"), "two such titles stay two files")


# ------------------------------------------------------------ helpers --

## The name an export of a deck titled [param title] carries for 1997.
func _title(title: String) -> String:
	return _model(title).to_dck_text({}).split("\n")[0].substr(1)


func _model(title: String) -> DeckModel:
	var model := DeckModel.new()
	model.deck_name = title
	model.counts["Mountain"] = 20
	model.counts["Lightning Bolt"] = 4
	return model


## The 1997 deck builder's `load_deck` (deckdll.c 5306-5383), on bytes:
## eight fgets() into the buffers it uses, each line beginning with `;`,
## then card lines up to the first version line. fgets(n) reads at most
## n-1 bytes, stopping after a newline; a longer line runs on into the
## next read. Text mode makes CRLF one newline.
func _load_1997(bytes: PackedByteArray) -> Dictionary:
	var text := PackedByteArray()
	for i in bytes.size():
		if not (bytes[i] == 13 and i + 1 < bytes.size() and bytes[i + 1] == 10):
			text.append(bytes[i])
	var at := 0
	var name := ""
	for i in LOAD_BUFFERS.size():
		var start := at
		while at < text.size() and at - start < int(LOAD_BUFFERS[i]) - 1:
			at += 1
			if text[at - 1] == 10:
				break
		var line := text.slice(start, at).get_string_from_ascii()
		if not line.begins_with(";"):
			return {"error": "line %d does not begin with ';': %s" % [i + 1, line]}
		if i == 0:
			name = line.substr(1).trim_suffix("\n")
	var cards := 0
	for raw in text.slice(at).get_string_from_ascii().split("\n"):
		if raw.begins_with("v") or raw.begins_with(".v"):
			break
		if raw.begins_with("."):
			cards += raw.substr(1).split("\t")[1].to_int()
	return {"error": "", "name": name, "cards": cards}
