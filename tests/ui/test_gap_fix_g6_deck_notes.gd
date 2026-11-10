extends GutTest
## THE GAP REVIEW OF 2026-11-10 (r6-1): Deck notes keep their FIRST line's
## indent.
##
## WAS: the 2026-10-21 fix kept every line of the notes as typed — but
## `DeckModel.note_lines` and the Deck Builder's `Deck notes` dialog still
## ran `strip_edges()` over the WHOLE text, which takes the leading spaces
## of its first line with it: notes that open on an indented list lost
## that line's indent (and only that line's) at OK and at every save. And
## the dialog compared the stripped text with the notes it showed, so OK
## on unchanged notes opening on an indent counted as an edit: an undo
## step and an unsaved deck for nothing. NOW both read the notes through
## `DeckModel.notes_as_typed`: the blank lines above the first line and
## the spaces after the last go, every line's own indent stays.

const INDENTED := "  - swap in Disenchant\n  - keep Ancestral\n\nWeak to fliers."

var screen: DeckBuilderScreen


func after_each() -> void:
	screen = null


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _screen() -> DeckBuilderScreen:
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


## Types [param text] into the open Deck notes dialog and presses OK.
func _type_notes(text: String) -> void:
	screen._open_notes_dialog()
	var dialog: Node = screen.open_dialogs()[-1]
	for node in _walk(dialog):
		if node is TextEdit:
			node.text = text
	for node in _walk(dialog):
		if node is Button and node.text == "OK":
			node.pressed.emit()
			return
	fail_test("the Deck notes dialog has an OK button")


# ---------------------------------------------------------- the files --

func test_the_first_lines_indent_survives_a_deck_file_and_a_dec_export() -> void:
	var deck := DeckModel.new()
	deck.notes = INDENTED
	assert_string_contains(deck.to_text(), "# note:   - swap in Disenchant\n")
	assert_eq(DeckModel.notes_from_text(deck.to_text()), INDENTED, ".deck")
	assert_eq(DeckModel.notes_from_text(deck.to_dec_text()), INDENTED, ".dec")


func test_blank_lines_above_and_spaces_after_are_still_trimmed() -> void:
	var deck := DeckModel.new()
	deck.notes = "\n  \n  - swap in Disenchant\n\nWeak to fliers.  \n\n "
	assert_eq(DeckModel.notes_from_text(deck.to_text()),
		"  - swap in Disenchant\n\nWeak to fliers.")


func test_notes_of_only_spaces_still_write_no_note_line() -> void:
	var deck := DeckModel.new()
	deck.notes = " \n\t\n "
	assert_false(deck.to_text().contains("# note:"))


# --------------------------------------------------------- the dialog --

func test_the_notes_dialog_keeps_the_first_lines_indent() -> void:
	await _screen()
	_type_notes(INDENTED)
	assert_eq(screen.deck.notes, INDENTED, "the notes as typed")


func test_the_notes_dialog_trims_what_is_around_the_notes() -> void:
	await _screen()
	_type_notes("\n\n  - swap in Disenchant\nWeak to fliers. \n")
	assert_eq(screen.deck.notes, "  - swap in Disenchant\nWeak to fliers.")


func test_ok_on_unchanged_indented_notes_is_no_edit() -> void:
	await _screen()
	screen.deck.notes = INDENTED    # as a deck file opened them
	screen._dirty = false
	var steps: int = screen._undo_steps.size()
	_type_notes(INDENTED)           # the dialog shows them; OK
	assert_eq(screen.deck.notes, INDENTED, "unchanged")
	assert_false(screen._dirty, "the deck is not marked unsaved")
	assert_eq(screen._undo_steps.size(), steps, "and no undo step for nothing")
