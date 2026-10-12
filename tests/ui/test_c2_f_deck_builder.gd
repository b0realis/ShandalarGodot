extends GutTest
## Robustness campaign 2026-10-12 — the Deck Builder's Save and its
## legality window.
##
##   * b2-4: Save after Load writes the file that was loaded (a draft deck's
##     `draft-<stamp>.deck`, a hand-copied file), not a second same-titled
##     file; a new title is still a save-as; a shipped deck is never written.
##   * b2-6: the save-time legality window names the formats that really
##     refuse the deck (Highlander ignores the banned list).
##   * r3-11: the Deck Info title field is capped.

var screen: DeckBuilderScreen
var _made: Array[String] = []


func before_each() -> void:
	CardRegistry.ensure_loaded()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DeckStore.USER_DIR))
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	for path in _made:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made.clear()


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _answer(label: String) -> void:
	var dialogs := screen.open_dialogs()
	assert_gt(dialogs.size(), 0, "a dialog is asking")
	if dialogs.is_empty():
		return
	for node in _walk(dialogs[-1]):
		if node is Button and node.text == label:
			node.pressed.emit()
			return
	fail_test("no '%s' button in the dialog" % label)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_made.append(path)


func _files_titled(title: String) -> Array[String]:
	var out: Array[String] = []
	for path in DeckStore.deck_paths_in(DeckStore.USER_DIR):
		if DeckStore.title_in(FileAccess.get_file_as_string(path)) == title:
			out.append(path.get_file())
	return out


# ------------------------------------------------------------- b2-4 --

const DRAFT_FILE := "user://decks/draft-2026-10-12T10-00-00-c2c2c2c2c2c2.deck"
const DRAFT_TITLE := "Draft 2026-10-12 10:00:00 c2"


func test_save_after_load_writes_the_file_that_was_loaded() -> void:
	_write(DRAFT_FILE, "# Built in the Deck Builder.\nname: %s\n20 Mountain\n3 Lightning Bolt\n" % DRAFT_TITLE)
	_made.append(DeckStore.path_for(DRAFT_TITLE))
	screen._load_deck(DRAFT_FILE)
	assert_eq(screen.deck.deck_name, DRAFT_TITLE)
	screen._add_one("Lightning Bolt")
	screen._save_deck()
	# The 1997 `@DECKEXISTS` question stands in front of every overwrite,
	# and it names the file that will be written.
	var asked := ""
	for node in _walk(screen.open_dialogs()[-1]):
		if node is Label:
			asked += (node as Label).text
	assert_string_contains(asked, DRAFT_FILE.get_file())
	_answer("OK")
	await get_tree().process_frame
	assert_string_contains(FileAccess.get_file_as_string(DRAFT_FILE), "4 Lightning Bolt",
		"the opened file holds the edit")
	assert_eq(_files_titled(DRAFT_TITLE), [DRAFT_FILE.get_file()] as Array[String],
		"one file for the title")
	assert_string_contains(screen._status_label.text, DRAFT_FILE.get_file())
	assert_false(screen._dirty)
	# A second save goes to the same file again.
	screen._add_one("Mountain")
	screen._save_deck()
	_answer("OK")
	assert_string_contains(FileAccess.get_file_as_string(DRAFT_FILE), "21 Mountain")
	assert_eq(_files_titled(DRAFT_TITLE).size(), 1)


func test_a_renamed_deck_saves_as_a_new_file() -> void:
	_write(DRAFT_FILE, "# Built in the Deck Builder.\nname: %s\n20 Mountain\n" % DRAFT_TITLE)
	screen._load_deck(DRAFT_FILE)
	screen.deck.deck_name = "C2 Renamed Draft"
	_made.append(DeckStore.path_for("C2 Renamed Draft"))
	screen._add_one("Lightning Bolt")
	screen._save_deck()
	assert_true(FileAccess.file_exists(DeckStore.path_for("C2 Renamed Draft")), "save-as")
	assert_false(FileAccess.get_file_as_string(DRAFT_FILE).contains("Lightning Bolt"),
		"the loaded file is untouched")


func test_a_new_deck_in_the_slot_forgets_the_loaded_file() -> void:
	_write(DRAFT_FILE, "# Built in the Deck Builder.\nname: %s\n20 Mountain\n" % DRAFT_TITLE)
	screen._load_deck(DRAFT_FILE)
	assert_eq(screen._save_path(), DRAFT_FILE)
	screen._dirty = false
	screen._new_deck()
	assert_eq(screen._save_path(), DeckStore.path_for(screen.deck.deck_name))
	# ...and a copy into another slot never inherits the file.
	screen._load_deck(DRAFT_FILE)
	screen._copy_deck_to(1)
	screen._switch_slot(1)
	screen.deck.deck_name = DRAFT_TITLE
	assert_eq(screen._save_path(), DeckStore.path_for(DRAFT_TITLE))


func test_a_shipped_deck_is_never_written_back() -> void:
	var shipped := DeckStore.shipped_paths()[0]
	var before := FileAccess.get_file_as_string(shipped)
	screen._load_deck(shipped)
	assert_eq(screen._save_path(), DeckStore.path_for(screen.deck.deck_name),
		"a shipped file is not remembered")
	screen._add_one("Mountain")
	screen._save_deck()            # the provenance save-as takes over
	assert_eq(FileAccess.get_file_as_string(shipped), before)
	var probe := screen.deck.duplicate_model()
	probe.deck_name = "C2 Not A Shipped Name"
	assert_ne(DeckStore.save(probe, shipped), "", "the store refuses a path outside the decks folder")
	assert_eq(FileAccess.get_file_as_string(shipped), before)


func test_deleting_the_loaded_file_forgets_it() -> void:
	_write(DRAFT_FILE, "# Built in the Deck Builder.\nname: %s\n20 Mountain\n" % DRAFT_TITLE)
	screen._load_deck(DRAFT_FILE)
	assert_eq(DeckStore.delete_deck(DRAFT_FILE), "")
	assert_true(screen._mark_unsaved_after_delete(DRAFT_FILE, DRAFT_TITLE))
	assert_true(screen._dirty, "the surface deck lost its file")
	assert_eq(screen._save_path(), DeckStore.path_for(DRAFT_TITLE))


# ------------------------------------------------------------- b2-6 --

func _window_text() -> String:
	var said := ""
	for dialog in screen.open_dialogs():
		for node in _walk(dialog):
			if node is Label:
				said += (node as Label).text + "\n"
	return said


func test_the_legality_window_names_the_formats_that_refuse() -> void:
	var title := "C2 Banned Singleton"
	_made.append(DeckStore.path_for(title))
	screen.deck.deck_name = title
	assert_eq(screen.deck.add("Contract from Below"), "")
	for _i in 39:
		screen.deck.add("Swamp")
	screen._write_deck()
	var said := _window_text()
	assert_eq(DeckFormat.legal(screen.deck.to_card_list(), DeckFormat.HIGHLANDER), "",
		"Highlander accepts it")
	assert_false(said.contains("any of the other four formats"), said)
	assert_string_contains(said, "It is legal under Unrestricted and Highlander")
	assert_string_contains(said, "refuse it under Wild, Restricted (Type 1) and Tournament (Type 1.5).")


func test_a_deck_only_unrestricted_takes_keeps_the_old_sentence() -> void:
	var title := "C2 Five Bolts"
	_made.append(DeckStore.path_for(title))
	screen.deck.deck_name = title
	for _i in 5:
		screen.deck.add("Lightning Bolt")
	for _i in 30:
		screen.deck.add("Mountain")
	screen._write_deck()
	assert_string_contains(_window_text(),
		"It is Unrestricted, and the battle-setup screen will refuse it under any of the other four formats.")


func test_unrestricted_summary_does_not_read_as_wild_s_rule() -> void:
	var line: String = DeckFormat.SUMMARY[DeckFormat.UNRESTRICTED]
	assert_false(line.contains("no banned cards"), line)
	assert_string_contains(line, "nothing is banned")


# ------------------------------------------------------------ r3-11 --

func test_the_title_field_is_capped() -> void:
	screen._open_deck_info()
	var field: LineEdit = null
	for node in _walk(screen.open_dialogs()[-1]):
		if node is LineEdit:
			field = node
	assert_not_null(field)
	if field != null:
		assert_eq(field.max_length, DeckModel.TITLE_MAX)
	_answer("Cancel")
