extends GutTest
## Robustness campaign 2026-10-12 — deck files in and out.
##
##   * b2-9: an exported `.dec` keeps its title when a note line starts
##     "Name:", and its Deck notes come back on import.
##   * r3-6: Import reads other programs' exports (MTG Arena, Moxfield /
##     MTGO `SIDEBOARD:`, Forge `.dck`) on the lenient path only.
##   * r3-8: a lenient parse is linear in unknown names.
##   * r3-10: a refused Delete says so in its own words.
##   * r3-11 / r2-11: a long title still saves; its file name is capped,
##     two long titles stay two files, an older uncapped file is still found.

var _made: Array[String] = []


func before_all() -> void:
	CardRegistry.ensure_loaded()


func after_each() -> void:
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(DeckStore.USER_DIR), 493)
	for path in _made:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made.clear()


# ------------------------------------------------------------- b2-9 --

func _noted_model() -> DeckModel:
	var model := DeckModel.new()
	model.deck_name = "C2 Export Probe"
	for _i in 20:
		model.add("Mountain")
	for _i in 4:
		model.add("Lightning Bolt")
	model.add_side("Red Elemental Blast")
	model.notes = "Name: the sideboard plan\nBring in Red Elemental Blasts against blue."
	return model


func test_a_dec_export_keeps_its_title_and_its_notes() -> void:
	var model := _noted_model()
	var text := model.to_dec_text()
	assert_string_contains(text, "// note: Name: the sideboard plan")
	var report: Array = []
	var back := DeckStore.import_text(text, "fallback", report)
	assert_not_null(back)
	if back == null:
		return
	assert_eq(back.deck_name, "C2 Export Probe", "the title is the deck's, not the note's")
	assert_eq(back.notes, model.notes, "the notes come back")
	assert_eq(back.total(), 24)
	assert_eq(back.side_total(), 1)
	# Our own `.deck` notes read as before.
	assert_eq(DeckModel.notes_from_text(model.to_text()), model.notes)
	# And the strict parser — what another of our readers uses — agrees.
	var list := DeckList.new()
	list.parse(text, "fallback", true)
	assert_eq(list.deck_name, "C2 Export Probe")
	assert_eq(DeckStore.title_in(text), "C2 Export Probe")


# ------------------------------------------------------------- r3-6 --

func _import(text: String, ext := "") -> DeckModel:
	var report: Array = []
	if ext == "":
		return DeckStore.import_text(text, "pasted", report)
	var path := "user://c2_f_deck_import" + ext
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_made.append(path)
	return DeckStore.import_file(path, report)


func test_an_mtg_arena_export_is_read() -> void:
	var model := _import("About\nName Arena Burn\n\nDeck\n4 Lightning Bolt (M10) 146\n"
		+ "20 Mountain (M10) 242\n16 Hill Giant (M10) 143\n\nSideboard\n2 Red Elemental Blast (ICE) 213\n")
	assert_not_null(model, "an Arena export is read")
	if model == null:
		return
	assert_eq(model.deck_name, "Arena Burn")
	assert_eq(model.copies_of("Lightning Bolt"), 4, "with its set codes understood")
	assert_eq(model.total(), 40)
	assert_eq(model.side_count_of("Red Elemental Blast"), 2, "the Sideboard header opens the sideboard")
	assert_eq(model.proxy_names(), [] as Array[String], "no card became a proxy")


func test_a_moxfield_or_mtgo_list_with_a_sideboard_header_is_read() -> void:
	var model := _import("4 Lightning Bolt\n20 Mountain\n16 Hill Giant\n\nSIDEBOARD:\n2 Red Elemental Blast\n")
	assert_not_null(model)
	if model != null:
		assert_eq(model.total(), 40)
		assert_eq(model.side_count_of("Red Elemental Blast"), 2)
	var foil := _import("1 Lightning Bolt (2X2) 117 *F*\n3 Lightning Bolt [M10]\n20 Mountain\n")
	assert_not_null(foil)
	if foil != null:
		assert_eq(foil.copies_of("Lightning Bolt"), 4, "a foil marker and a bracketed set too")


func test_a_forge_dck_file_is_read() -> void:
	var forge := "[metadata]\nName=Forge Burn\nDescription=fast\n[Main]\n4 Lightning Bolt|M10\n" \
		+ "20 Mountain|M10|1\n16 Hill Giant|M10\n[Sideboard]\n2 Red Elemental Blast|ICE\n"
	var model := _import(forge, ".dck")
	assert_not_null(model, "a Forge .dck is read")
	if model != null:
		assert_eq(model.deck_name, "Forge Burn")
		assert_eq(model.total(), 40)
		assert_eq(model.side_count_of("Red Elemental Blast"), 2)
	var pasted := _import(forge)
	assert_not_null(pasted, "and pasted")
	# The 1997 `.dck` still goes to its own parser.
	var micro := _import("Burn (Red)\n.1\t4\tLightning Bolt\n.2\t20\tMountain\n.vNone\n.3\t2\tRed Elemental Blast\n", ".dck")
	assert_not_null(micro)
	if micro != null:
		assert_eq(micro.deck_name, "Burn")
		assert_eq(micro.total(), 24)


func test_an_unknown_card_from_another_program_is_a_proxy_by_its_name() -> void:
	var model := _import("Deck\n4 Not A Real Card (XYZ) 12\n20 Mountain\n")
	assert_not_null(model)
	if model != null:
		assert_eq(model.proxy_names(), ["Not A Real Card"] as Array[String])


func test_the_strict_loader_does_not_read_foreign_headers() -> void:
	var list := DeckList.new()
	list.parse("Deck\n4 Lightning Bolt (M10) 146\n20 Mountain\n", "x", true)
	assert_false(list.errors.is_empty(), "a strict .deck parse is unchanged")
	var lenient := DeckList.new()
	lenient.parse("Deck\n20 Mountain\n", "x", false)
	assert_false(lenient.errors.is_empty(), "and so is the plain lenient one")


# ------------------------------------------------------------- r3-8 --

func test_a_lenient_parse_is_linear_in_unknown_names() -> void:
	var lines := PackedStringArray(["// NAME : My collection"])
	for i in 40000:
		lines.append("1 Unknown Card Number %d" % i)
	lines.append("3 Unknown Card Number 7")
	var text := "\n".join(lines)
	var started := Time.get_ticks_msec()
	var lenient := DeckList.from_text(text, "user://decks/c2_big.dec", false)
	var ms := Time.get_ticks_msec() - started
	assert_eq(lenient.proxies.size(), 40000, "each unknown name once")
	assert_eq(lenient.proxies[7], "Unknown Card Number 7", "in first-seen order")
	assert_eq(lenient.cards.size(), 40003)
	# Quadratic, this was five to six seconds; linear, well under a tenth.
	assert_lt(ms, 1500, "40,000 unknown names parse in %d ms" % ms)


# ------------------------------------------------------------ r3-10 --

func test_a_refused_delete_does_not_talk_about_saving() -> void:
	var deck := DeckModel.new()
	deck.deck_name = "C2 Undeletable"
	for _i in 40:
		deck.add("Forest")
	assert_eq(DeckStore.save(deck), "")
	var path := DeckStore.path_for(deck.deck_name)
	_made.append(path)
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(DeckStore.USER_DIR), 365)
	var refusal := DeckStore.delete_deck(path)
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(DeckStore.USER_DIR), 493)
	if not FileAccess.file_exists(path):
		pending("this filesystem let the delete through (running as root?)")
		return
	assert_false(refusal.contains("has not been saved"), refusal)
	assert_string_contains(refusal, "%s could not be deleted (" % path.get_file())


func test_a_read_only_deck_file_is_said_to_be_read_only() -> void:
	var deck := DeckModel.new()
	deck.deck_name = "C2 Kept As Is"
	for _i in 40:
		deck.add("Forest")
	assert_eq(DeckStore.save(deck), "")
	var path := DeckStore.path_for(deck.deck_name)
	_made.append(path)
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(path), 292)   # r--r--r--
	deck.add("Island")
	var refusal := DeckStore.save(deck)
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(path), 420)
	assert_eq(refusal, DeckStore.READ_ONLY % path.get_file())
	assert_false(FileAccess.get_file_as_string(path).contains("Island"), "the file kept")


# ------------------------------------------------------------ r3-11 --

func test_a_long_title_saves_under_a_capped_name() -> void:
	var deck := DeckModel.new()
	deck.deck_name = "The Long Way Round ".repeat(16).strip_edges()     # 303 characters
	deck.add("Mountain")
	var path := DeckStore.path_for(deck.deck_name)
	_made.append(path)
	assert_eq(DeckStore.save(deck), "", "a 303-character title saves")
	assert_lte(path.get_file().to_utf8_buffer().size(),
		DeckStore.STEM_MAX + 11 + DeckStore.EXTENSION.length())
	assert_true(FileAccess.file_exists(path))
	assert_eq(DeckStore.load_deck(path, []).deck_name, deck.deck_name, "the title is whole inside")
	assert_true(DeckStore.exists(deck.deck_name))
	var export_path: Array = []
	assert_eq(DeckStore.export_deck(deck, ".dec", export_path), "", "and exports")
	if not export_path.is_empty():
		_made.append(String(export_path[0]))


func test_two_long_titles_that_begin_alike_are_two_files() -> void:
	var stem := "A Deck Built Around The Long Forgotten Wars Of Shandalar And Its Five Wizards "
	var one := DeckStore.file_stem(stem + "Version One")
	var two := DeckStore.file_stem(stem + "Version Two")
	assert_ne(one, two)
	assert_lte(one.length(), DeckStore.STEM_MAX + 11)
	assert_eq(DeckStore.file_stem("Short Deck"), "short_deck", "a short title keeps its stem")
	# A long title with letters beyond ASCII is capped the same way.
	assert_lte(DeckStore.file_stem("Ωmega " + stem + stem).length(), DeckStore.STEM_MAX + 11)


func test_a_long_title_saved_before_the_cap_keeps_its_file() -> void:
	var title := "An Older Deck With A Title Of More Than Eighty Characters In It Saved Before The Cap Indeed"
	var old_stem := DeckStore._ascii_fold(title.to_lower())
	assert_gt(old_stem.length(), DeckStore.STEM_MAX)
	var old := "%s/%s%s" % [DeckStore.USER_DIR, old_stem, DeckStore.EXTENSION]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(old, FileAccess.WRITE)
	file.store_string("name: %s\n20 Mountain\n" % title)
	file.close()
	_made.append(old)
	assert_eq(DeckStore.path_for(title), old, "a re-save writes it in place")
	_made.append("%s/%s%s" % [DeckStore.USER_DIR, DeckStore.file_stem(title), DeckStore.EXTENSION])
