extends GutTest
## THE GAME'S OWN DECKS ARE NOT WRITABLE, AND NOT SHADOWABLE EITHER.
##
## The owner's playtest, 2026-09-04: *"Default decks of the game should not
## be overwritable by the deck builder! (To keep provenance of deck builds
## from 1997.)"*
##
## The 1997 game asks for the same thing in its own words, which is why
## this is fidelity and not only safety — the printed manual, p.148:
##
## > *"If you load and change one of the creature decks used in the full
## > game, you must save your version of the deck under a new name."*
##
## TWO PROMISES ARE PINNED HERE, and the second is the one that was
## missing. A shipped FILE could never be written — [method DeckStore.save]
## builds its path out of [constant DeckStore.USER_DIR] and nothing else —
## but a deck saved as `Cleric` landed in `user://decks/cleric.deck` and
## the Load list then held two decks called Cleric with no way to tell
## which was the 1997 original. So:
##
##   1. every door that can reach [method DeckStore.save] refuses a
##      shipped NAME (file name or title), out loud and with the manual's
##      reason, offering a name that works;
##   2. the shipped files are byte-identical after every one of those
##      doors has been driven at them.
##
## `tests/unit/test_decks_1997.gd` owns what the shipped decks ARE (the
## counts, the groups, the card lists). This file owns what may happen to
## them.

var screen: DeckBuilderScreen

## The shipped deck this file picks on. Its title and its file name are
## the same word, which is the plain case; [method
## test_a_shipped_title_is_refused_even_when_the_file_name_differs] takes
## the other one.
const VICTIM := "res://decks/1997/originals/cleric.deck"
## How many files `res://decks` holds. `tests/unit/test_decks_1997.gd`
## owns the breakdown (5 starters + 312 ported); this is the number the
## fingerprint below covers, pinned so a deck added later is covered too
## rather than silently skipped.
const SHIPPED_FILES := 317

var _written: Array[String] = []


func before_each() -> void:
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	# Every user deck this file wrote, gone — `user://` is the suite's own
	# scratch data home (`run_tests.sh`), but a deck left behind would
	# still be in the NEXT test's Load list.
	for path in _written:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_written.clear()


func _watch(path: String) -> String:
	_written.append(path)
	return path


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


## Every string a dialog is showing, joined — the labels and the field.
func _dialog_text() -> String:
	var dialogs := screen.open_dialogs()
	if dialogs.is_empty():
		return ""
	var out := ""
	for node in _walk(dialogs[-1]):
		if node is Label:
			out += (node as Label).text + "\n"
		elif node is LineEdit:
			out += (node as LineEdit).text + "\n"
		elif node is Button:
			out += (node as Button).text + "\n"
	return out


func _field() -> LineEdit:
	var dialogs := screen.open_dialogs()
	if dialogs.is_empty():
		return null
	for node in _walk(dialogs[-1]):
		if node is LineEdit:
			return node
	return null


func _answer(label: String) -> void:
	var dialogs := screen.open_dialogs()
	assert_gt(dialogs.size(), 0, "a dialog is asking")
	for node in _walk(dialogs[-1]):
		if node is Button and (node as Button).text == label:
			(node as Button).pressed.emit()
			return
	fail_test("no '%s' button in the dialog" % label)


## Put a shipped deck on the surface and dirty it — the exact situation
## the manual is talking about: *"if you load and change one of the
## creature decks used in the full game…"*
func _load_and_change_a_shipped_deck(path := VICTIM) -> void:
	screen._load_deck(path)
	assert_gt(screen.deck.total(), 20, "a real deck arrived")
	screen._add_one("Mountain")
	assert_true(screen._dirty, "and it has been changed")


## path -> md5, for every file the game ships.
func _fingerprint() -> Dictionary:
	var out := {}
	for path in DeckStore.shipped_paths():
		out[path] = FileAccess.get_md5(path)
	return out


# ============================================== what 1997 actually says --

func test_the_manual_is_quoted_verbatim() -> void:
	# The sentence is the reason the player is shown, so it is the one
	# string in this feature that may not be paraphrased. [DeckGroups]
	# quotes the same line for the other half of the rule.
	assert_eq(DeckStore.NEW_NAME_RULE,
		"If you load and change one of the creature decks used in the full"
		+ " game, you must save your version of the deck under a new name.")
	assert_string_contains(DeckStore.shipped_reason("Cleric"),
		DeckStore.NEW_NAME_RULE, "the dialog says it in full")
	assert_string_contains(DeckStore.shipped_reason("Cleric"), "p.148",
		"…and says where it is from")


# ================================= what counts as one of the game's own --

func test_every_shipped_deck_name_is_known_to_the_guard() -> void:
	var paths := DeckStore.shipped_paths()
	assert_eq(paths.size(), SHIPPED_FILES,
		"every file res://decks holds (test_decks_1997.gd owns the breakdown)")
	for path in paths:
		var stem := path.get_file().get_basename()
		assert_true(DeckStore.is_shipped_name(stem),
			"%s: its file name is a shipped name" % path)
		var title := DeckStore.title_in(DeckStore.read_text(path))
		assert_ne(title, "", "%s: it names itself" % path)
		assert_true(DeckStore.is_shipped_name(title),
			"%s: its title '%s' is a shipped name too" % [path, title])


func test_a_shipped_title_is_refused_even_when_the_file_name_differs() -> void:
	# 233 of the shipped files carry a title that does not slugify to
	# their own file name — `wc1996_rade.deck` is *"Råde — Worlds 1996
	# (Erhnamgeddon)"*. A file-name-only check would have let a second
	# deck with that TITLE onto the Load list, which is exactly the
	# muddle the guard exists to prevent, because the list shows the
	# title (`DeckStore.describe`).
	var found := ""
	for path in DeckStore.shipped_paths():
		var title := DeckStore.title_in(DeckStore.read_text(path))
		if title != "" and DeckStore.file_stem(title) \
				!= DeckStore.file_stem(path.get_file().get_basename()):
			found = title
			break
	assert_ne(found, "", "some shipped deck's title is not its file name")
	assert_true(DeckStore.is_shipped_name(found),
		"'%s' is one of the game's own names" % found)


func test_case_and_punctuation_cannot_slip_a_shadow_past() -> void:
	# `path_for` is many-to-one — "Knights!" and "Knights?" are one file —
	# so the guard is many-to-one in exactly the same way, or a capital
	# letter would have been a way around it.
	for name_tried in ["Cleric", "cleric", "CLERIC", "Cleric!", "  Cleric  "]:
		assert_true(DeckStore.is_shipped_name(name_tried),
			"'%s' still lands on cleric.deck" % name_tried)


func test_a_name_of_the_players_own_is_not_refused() -> void:
	assert_false(DeckStore.is_shipped_name("Gut Provenance Deck"))
	assert_false(DeckStore.is_shipped_name("My Cleric"),
		"and the name the guard itself suggests is free")


func test_the_suggested_name_is_the_manuals_own_words() -> void:
	# *"your version of the deck"* — so "My Cleric", not "Cleric (1)".
	assert_eq(DeckStore.suggest_name("Cleric"), "My Cleric")
	assert_false(DeckStore.is_shipped_name(DeckStore.suggest_name("Cleric")))
	for path in DeckStore.shipped_paths():
		var stem := path.get_file().get_basename()
		assert_false(DeckStore.is_shipped_name(DeckStore.suggest_name(stem)),
			"%s: the offer always clears the shipped names" % path)


# ================================================ the store's own belt --

func test_the_store_refuses_to_write_a_shipped_name() -> void:
	var deck := DeckModel.new()
	deck.deck_name = "Cleric"
	deck.counts["Mountain"] = 40
	var refusal := DeckStore.save(deck)
	assert_ne(refusal, "", "it refuses")
	assert_string_contains(refusal, "cleric.deck",
		"naming the file, the way @DECKEXISTS does")
	assert_string_contains(refusal, "new name", "and saying what to do")
	assert_false(FileAccess.file_exists(DeckStore.path_for("Cleric")),
		"and nothing was written")


func test_the_store_still_writes_a_deck_of_the_players_own() -> void:
	var deck := DeckModel.new()
	deck.deck_name = "Gut Provenance Deck"
	deck.counts["Mountain"] = 40
	assert_eq(DeckStore.save(deck), "", "the ordinary case still works")
	assert_true(FileAccess.file_exists(
		_watch(DeckStore.path_for("Gut Provenance Deck"))))


func test_a_save_can_only_ever_land_in_the_players_own_folder() -> void:
	# The structural half of "a shipped deck can never be written": there
	# is no name at all that makes `path_for` point outside user://decks.
	for name_tried in ["Cleric", "../../evil", "res://decks/cleric",
			"", "....", "Big Green"]:
		assert_true(DeckStore.path_for(name_tried).begins_with(
			DeckStore.USER_DIR + "/"), "'%s'" % name_tried)


# ============================================ door 1: `Save deck` ======

func test_saving_a_changed_shipped_deck_becomes_a_save_as() -> void:
	_load_and_change_a_shipped_deck()
	screen._run_command("Save deck")
	assert_false(FileAccess.file_exists(DeckStore.path_for("Cleric")),
		"no second Cleric was written")
	assert_string_contains(screen._status_label.text, "new name",
		"the status line says what happened")
	assert_eq(screen.open_dialogs().size(), 1, "and Deck Info opened for a name")
	var said := _dialog_text()
	assert_string_contains(said, DeckStore.NEW_NAME_RULE,
		"carrying the manual's own reason, in full")
	assert_string_contains(said, "p.148", "and its page")
	var field := _field()
	assert_not_null(field, "the name field is there")
	assert_eq(field.text, "My Cleric",
		"already holding a name that will work — one keystroke, not a puzzle")


func test_the_offered_name_finishes_the_save_it_was_asked_for() -> void:
	_load_and_change_a_shipped_deck()
	var before := FileAccess.get_md5(VICTIM)
	screen._run_command("Save deck")
	_answer("OK")
	var mine := _watch(DeckStore.path_for("My Cleric"))
	assert_true(FileAccess.file_exists(mine), "the player's version is written")
	assert_eq(screen.deck.deck_name, "My Cleric", "and the surface is renamed")
	assert_false(screen._dirty, "the screen knows it is saved")
	assert_eq(FileAccess.get_md5(VICTIM), before,
		"and the 1997 file is untouched, byte for byte")
	assert_string_contains(screen._status_label.text, "has been saved", "@SAVED")


func test_the_players_version_is_the_players_own_deck() -> void:
	# THE PROVENANCE ITSELF, and the reason the manual's rule is a rule:
	# the saved copy files under the player's heading and the 1997 file
	# keeps its own. [DeckGroups] derives USER from the PATH, so this
	# cannot be forged by the `# group:` line the save carries through.
	_load_and_change_a_shipped_deck()
	screen._run_command("Save deck")
	_answer("OK")
	var mine := _watch(DeckStore.path_for("My Cleric"))
	assert_eq(DeckGroups.of(mine), DeckGroups.USER,
		"the player's version is theirs")
	assert_eq(DeckGroups.of(VICTIM), DeckGroups.ORIGINALS,
		"and the 1997 deck is still a 1997 deck")
	assert_ne(mine.get_file(), VICTIM.get_file(),
		"two different files, so the list can tell them apart")


func test_an_ok_that_changes_nothing_does_not_save_anything() -> void:
	# The one way this could still have written the shipped name: press OK
	# on the offered name after typing the shipped one back in.
	_load_and_change_a_shipped_deck()
	screen._run_command("Save deck")
	_field().text = "Cleric"
	_answer("OK")
	assert_false(FileAccess.file_exists(DeckStore.path_for("Cleric")),
		"still nothing written under the game's own name")
	assert_true(screen._dirty, "and the deck is still unsaved")


# =========================== door 2: the Q/Esc menu's `Save current deck` --

func test_the_q_esc_menus_save_is_the_same_door() -> void:
	_load_and_change_a_shipped_deck()
	var ev := InputEventKey.new()
	ev.keycode = KEY_Q
	ev.pressed = true
	screen._unhandled_key_input(ev)
	assert_true(screen.is_menu_open())
	for node in _walk(screen._menu):
		if node is Button and (node as Button).text == "Save current deck":
			(node as Button).pressed.emit()
	assert_false(FileAccess.file_exists(DeckStore.path_for("Cleric")))
	assert_string_contains(_dialog_text(), DeckStore.NEW_NAME_RULE)


# ============================================== door 3: the Ctrl+S key --

func test_ctrl_s_is_the_same_door() -> void:
	_load_and_change_a_shipped_deck()
	var ev := InputEventKey.new()
	ev.keycode = KEY_S
	ev.pressed = true
	ev.ctrl_pressed = true
	screen._unhandled_key_input(ev)
	assert_false(FileAccess.file_exists(DeckStore.path_for("Cleric")))
	assert_string_contains(_dialog_text(), DeckStore.NEW_NAME_RULE)


# ================================ door 4: `@SAVE` on the way out ======

func test_the_save_prompt_on_the_way_out_is_the_same_door() -> void:
	# `Yes` to *"Do you wish to save Cleric?"* — the door that runs a save
	# and then throws the deck away. It must not write, and it must not
	# throw the deck away either, because the save did not happen.
	_load_and_change_a_shipped_deck()
	var carried_on: Array = []
	screen._confirm_discard(func() -> void: carried_on.append("then"))
	assert_eq(screen.open_dialogs().size(), 1, "@SAVE is asking")
	_answer("Yes")
	assert_false(FileAccess.file_exists(DeckStore.path_for("Cleric")))
	assert_string_contains(_dialog_text(), DeckStore.NEW_NAME_RULE,
		"it became a save-as instead")
	assert_eq(carried_on.size(), 0,
		"and nothing was discarded on the strength of a save that did not happen")


# ================================== door 5: `_write_deck` without a gate --

func test_the_write_itself_cannot_be_talked_into_it() -> void:
	# THE BELT UNDER THE FIVE DOORS. Every one of them goes through
	# `_save_deck`, which catches this earlier and says more about it —
	# but a future command that calls the write directly (a test, a tool,
	# the next audit pass's new entry) still cannot put a second Cleric in
	# `user://decks`.
	_load_and_change_a_shipped_deck()
	screen._write_deck()
	assert_false(FileAccess.file_exists(DeckStore.path_for("Cleric")))
	assert_string_contains(screen._status_label.text, "new name")
	assert_true(screen._dirty, "and a refused save is not a save")


# ============================== door 6: Delete, which is not a write ==

func test_delete_refuses_one_of_the_games_own() -> void:
	var refusal := DeckStore.delete_deck(VICTIM)
	assert_ne(refusal, "", "it refuses")
	assert_string_contains(refusal, "new name")
	assert_true(FileAccess.file_exists(VICTIM), "and the file is still there")


func test_the_load_list_offers_delete_only_on_the_players_own() -> void:
	# The button is not even drawn beside a shipped deck, so the refusal
	# above is a belt too rather than the whole answer.
	var deck := DeckModel.new()
	deck.deck_name = "Gut Provenance Deck"
	deck.counts["Mountain"] = 40
	assert_eq(DeckStore.save(deck), "")
	_watch(DeckStore.path_for("Gut Provenance Deck"))
	screen._run_command("Load deck")
	var rows := 0
	var drops := 0
	for node in _walk(screen.open_dialogs()[0]):
		if node is HBoxContainer:
			rows += 1
			for child in (node as HBoxContainer).get_children():
				if child is Button and (child as Button).text == "Delete":
					drops += 1
	assert_gt(rows, 300, "the whole list is there")
	assert_eq(drops, DeckStore.deck_paths_in(DeckStore.USER_DIR).size(),
		"one Delete per deck of the player's own, and none beside a shipped one")
	assert_gt(drops, 0, "…and the player really has one")


# ================================ door 7: Export, which is allowed ====

func test_export_is_the_one_write_a_shipped_deck_still_allows() -> void:
	# Exporting the game's own Cleric as a `.dck` for the 1997 program to
	# open is a USE of the provenance, not a threat to it: it writes to
	# `user://decks/export/`, which `deck_paths_in` never descends into,
	# so it can shadow nothing.
	screen._load_deck(VICTIM)
	screen._export_deck(".dck")
	var exported := "%s/cleric.dck" % DeckStore.EXPORT_DIR
	assert_true(FileAccess.file_exists(exported), "the export was written")
	assert_false(DeckStore.all_deck_paths().has(exported),
		"and the deck list never offers it")
	for path in DeckStore.all_deck_paths():
		assert_false(path.begins_with(DeckStore.EXPORT_DIR),
			"nothing under export/ is listed as a deck")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(exported))


# ============================================ nothing is shadowed =====

func test_no_deck_the_builder_writes_can_shadow_a_shipped_one() -> void:
	# THE WHOLE POINT, stated as the list sees it: two decks with one name
	# and no way to tell which is the 1997 original.
	var shipped_files := {}
	for path in DeckStore.shipped_paths():
		shipped_files[path.get_file()] = path
	var before := DeckStore.deck_paths_in(DeckStore.USER_DIR)
	# Drive the ordinary door at four of the game's own decks — one whose
	# title IS its file name, one starter deck, the second Cleric (whose
	# title is *"Cleric (Spells of the Ancients)"*, a different file name),
	# and a tournament deck whose title is nothing like its file name.
	for path in [VICTIM, "res://decks/big_green.deck",
			"res://decks/1997/ancients/cleric.deck",
			"res://decks/tournament/wc1996_rade.deck"]:
		screen._load_deck(path)
		screen._add_one("Mountain")
		screen._run_command("Save deck")
		if not screen.open_dialogs().is_empty():
			_answer("Cancel")
	for path in DeckStore.deck_paths_in(DeckStore.USER_DIR):
		assert_false(shipped_files.has(path.get_file()),
			"%s would shadow %s" % [path, shipped_files.get(path.get_file(), "")])
	assert_eq(DeckStore.deck_paths_in(DeckStore.USER_DIR), before,
		"in fact nothing new was written at all")


func test_the_shipped_files_are_byte_identical_after_every_door() -> void:
	var before := _fingerprint()
	assert_eq(before.size(), SHIPPED_FILES)
	# Every door that can reach a write, one after another, all aimed at
	# the game's own decks.
	_load_and_change_a_shipped_deck()
	screen._run_command("Save deck")            # the mini-menu / the bar
	_answer("Cancel")
	screen._write_deck()                        # the write, ungated
	var deck := DeckModel.new()
	deck.deck_name = "Cleric"
	deck.counts["Mountain"] = 40
	DeckStore.save(deck)                        # the store itself
	DeckStore.delete_deck(VICTIM)               # and the destructive door
	screen._export_deck(".dck")                 # the one that is allowed
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		"%s/cleric.dck" % DeckStore.EXPORT_DIR))
	var after := _fingerprint()
	assert_eq(after.size(), before.size(), "no shipped file appeared or left")
	for path in before:
		assert_eq(after.get(path, ""), before[path],
			"%s is byte-identical" % path)


# ================== the ROADMAP one-liner: Import asks first ==========

func test_import_asks_before_it_replaces_the_deck_on_the_surface() -> void:
	# *"`Import deck` does not ask before it replaces the deck on the
	# surface"* (docs/ROADMAP.md, "Left open by this pass"). `Load deck`
	# has asked since the second audit pass and *"From disk…"* inherits
	# it; this door walked straight into `_take_import`, so an hour's
	# unsaved building went the moment a file was picked.
	screen.deck.deck_name = "Work In Progress"
	screen._add_one("Mountain")
	assert_true(screen._dirty)
	screen._run_command("Import deck")
	assert_eq(screen.open_dialogs().size(), 1, "one dialog")
	assert_string_contains(_dialog_text(),
		DeckStore.SAVE_QUESTION % "Work In Progress",
		"@SAVE, not the import dialog")
	_answer("No")
	assert_string_contains(_dialog_text(), "Paste a decklist…",
		"…and only then the import dialog")


func test_import_opens_straight_away_when_there_is_nothing_to_lose() -> void:
	screen._run_command("Import deck")
	assert_eq(screen.open_dialogs().size(), 1)
	assert_string_contains(_dialog_text(), "From a file…",
		"an untouched surface is not worth a question")
