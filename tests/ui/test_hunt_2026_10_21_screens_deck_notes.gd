extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: Deck notes kept as
## typed.
##
## WAS: `DeckModel.to_text` (and `to_dec_text`) wrote each line of the
## Deck notes with its edges stripped and its blank lines skipped, and
## `notes_from_text` stripped them again on the way in: notes written as
## a plan with an indented list and a blank line between paragraphs came
## back, once saved and opened, as one flush block. NOW every line is
## kept as typed (`DeckModel.note_lines`), the blank ones too; the one
## space after `# note:` is the format's, not the note's.

const NOTES := "Plan:\n  - swap in Disenchant\n  - keep Ancestral\n\nWeak to fliers."


func _deck() -> DeckModel:
	var deck := DeckModel.new()
	deck.notes = NOTES
	return deck


func test_the_deck_file_keeps_blank_lines_and_indents() -> void:
	var text := _deck().to_text()
	assert_string_contains(text, "# note: Plan:\n# note:   - swap in Disenchant\n")
	assert_string_contains(text, "# note:\n# note: Weak to fliers.\n", "a blank line is a bare `# note:`")
	assert_eq(DeckModel.notes_from_text(text), NOTES)


func test_the_dec_export_keeps_them_too() -> void:
	var text := _deck().to_dec_text()
	assert_string_contains(text, "// note:   - keep Ancestral\n// note:\n")
	assert_eq(DeckModel.notes_from_text(text), NOTES)


func test_a_deck_written_before_reads_as_it_did() -> void:
	# The older files: one space after the prefix, no blank lines.
	var old := "name: Old\n# note: Weak to artifacts.\n# note:Swap in Disenchant.\n4 Plains\n"
	assert_eq(DeckModel.notes_from_text(old), "Weak to artifacts.\nSwap in Disenchant.")


func test_no_notes_still_writes_no_note_line() -> void:
	var deck := DeckModel.new()
	deck.notes = "  \n "
	assert_false(deck.to_text().contains("# note:"))
	assert_false(deck.to_dec_text().contains("// note:"))


func test_a_deck_file_opened_again_keeps_its_notes() -> void:
	var dir := ProjectSettings.globalize_path("user://").path_join("hunt_screens_deck_notes")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("notes.deck")
	var deck := _deck()
	deck.deck_name = "Notes"
	assert_eq(deck.add("Plains"), "", "a card in it")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(deck.to_text())
	file.close()
	var report := []
	var back := DeckStore.load_deck(path, report)
	assert_not_null(back, str(report))
	if back != null:
		assert_eq(back.notes, NOTES, "the Deck Builder opens it as it was typed")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
