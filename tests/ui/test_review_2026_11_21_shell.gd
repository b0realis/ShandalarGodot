extends GutTest
## THE WHOLE-PROJECT REVIEW OF 2026-11-21, the shell and the deck builder:
##
## 1. Asking to make the game portable made the `portable` folder (the write
##    probe did), and Cancel or a failed copy left it: the next start entered
##    an empty or half-filled portable folder, the settings, decks and
##    adventures seeming gone. Asking now makes nothing, and a first copy is
##    made beside the folder and renamed once whole.
## 2. Escape with the portable window up left Options (and, mid-copy, dropped
##    the restart). It is the window's Cancel now, and nothing while copying.
## 3. Closing the game's window from the adventure's deck builder went past
##    the Extra Cards box that Done and Exit game ask.
## 4. An adventure deck past what the builder holds (200 different cards,
##    500 in all) lost the rest unsaid when the builder was left.
##
## Everything here is under `user://` of the test profile.

const ROOT := "user://review_1121_shell_test"

var _root := ""
var _had_extras := false
var _extras: Variant = null


## The adventure's builder, its end counted instead of ending the run.
class Probe extends AdventureBuilder:
	var ends := 0

	func _ready() -> void:
		super._ready()
		exit_requested.connect(func() -> void: ends += 1)


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_had_extras = Settings.has_value(DeckBuilderScreen.EXTRAS_SETTING)
	_extras = Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, null)
	_root = ProjectSettings.globalize_path(ROOT)
	DirAccess.make_dir_recursive_absolute(_root.path_join("game"))
	PortableMode.folder_override = _root.path_join("game/portable")
	PortableMode.available_override = 1


func after_each() -> void:
	PortableMode.available_override = -1
	PortableMode.folder_override = ""
	_wipe(_root)
	if _had_extras:
		Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING, _extras)
	else:
		Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)
	ShellMusic.stop()


func _wipe(dir: String) -> void:
	if not dir.contains("review_1121_shell_test") or not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	here.include_hidden = true
	for sub in here.get_directories():
		FileAccess.set_unix_permissions(dir.path_join(sub), FileAccess.UNIX_READ_OWNER
			| FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
		_wipe(dir.path_join(sub))
	for name in here.get_files():
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


func _options() -> Control:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func _escape() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _button(root: Node, text: String) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if (button as Button).text == text:
			return button as Button
	return null


# ------------------------------------------------------------ portable --

func test_asking_makes_no_portable_folder_and_cancel_leaves_none() -> void:
	var screen: Control = await _options()
	screen.ask_portable("make")
	await get_tree().process_frame
	var window := screen.find_child("PortableWindow", true, false)
	assert_not_null(window)
	assert_not_null(window.find_child("PortableGo", true, false), "the game folder can be written: the copy is offered")
	assert_false(DirAccess.dir_exists_absolute(PortableMode.folder()), "asking made nothing")
	_button(window, "Cancel").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(DirAccess.dir_exists_absolute(PortableMode.folder()),
		"Cancel leaves no portable folder for the next start to enter")
	assert_eq(DirAccess.get_directories_at(_root.path_join("game")).size(), 0, "nor anything else")


func test_can_hold_probes_without_making_the_folder() -> void:
	var dir := _root.path_join("game/deep/portable")
	assert_true(PortableMode.can_hold(dir))
	assert_false(DirAccess.dir_exists_absolute(_root.path_join("game/deep")), "nothing made")
	assert_false(FileAccess.file_exists(_root.path_join("game/.shandalar-write-test")), "the probe is gone")
	var locked := _root.path_join("locked")
	DirAccess.make_dir_recursive_absolute(locked)
	FileAccess.set_unix_permissions(locked, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	assert_false(PortableMode.can_hold(locked.path_join("portable")), "a folder that cannot be written")
	assert_false(PortableMode.can_hold(locked), "nor one that is there and cannot be")


func test_a_first_copy_that_fails_leaves_no_portable_folder() -> void:
	# The game folder turns read-only after the question (a stick pulled, a
	# full disk): the copy cannot start.
	var locked := _root.path_join("locked")
	DirAccess.make_dir_recursive_absolute(locked)
	PortableMode.folder_override = locked.path_join("portable")
	var screen: Control = await _options()
	screen.ask_portable("make")
	await get_tree().process_frame
	FileAccess.set_unix_permissions(locked, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	var problem: String = await screen._copy_portable("make")
	FileAccess.set_unix_permissions(locked, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
		| FileAccess.UNIX_EXECUTE_OWNER)
	assert_ne(problem, "", "the copy says why")
	assert_engine_error_count(0, "a plain refusal, no engine error")
	assert_false(screen._portable_copying)
	assert_eq(DirAccess.get_directories_at(locked).size(), 0, "no portable folder, no folder in the making")


func test_a_copy_stopped_halfway_is_removed_and_never_the_portable_folder() -> void:
	# What a failed copy leaves is the folder in the making, and that goes.
	var folder := PortableMode.folder()
	var making := PortableMode.making_name(folder)
	assert_eq(making, folder + "-making")
	DirAccess.make_dir_recursive_absolute(making.path_join("godot/app_userdata/Shandalar/decks"))
	var file := FileAccess.open(making.path_join("godot/app_userdata/Shandalar/decks/a.deck"), FileAccess.WRITE)
	file.store_string("1 Forest\n")
	file.close()
	assert_eq(PortableMode.making_name(folder), folder + "-making-2", "a name in use is not taken again")
	PortableMode.remove_made(making)
	assert_false(DirAccess.dir_exists_absolute(making))
	assert_false(DirAccess.dir_exists_absolute(folder))


func test_a_first_copy_arrives_whole_under_the_portable_folder() -> void:
	var found := PortableMode.measure(OS.get_user_data_dir())
	if int(found["bytes"]) > 64 * 1024 * 1024:
		pending("the test profile is too big to copy here")
		return
	var marker := FileAccess.open(ROOT.path_join("marker.txt"), FileAccess.WRITE)
	marker.store_string("here")
	marker.close()
	var screen: Control = await _options()
	screen.ask_portable("make")
	await get_tree().process_frame
	var problem: String = await screen._copy_portable("make")
	assert_eq(problem, "")
	var folder := PortableMode.folder()
	assert_true(DirAccess.dir_exists_absolute(folder), "the portable folder is there once the copy is whole")
	assert_false(DirAccess.dir_exists_absolute(folder + "-making"), "the folder in the making became it")
	var arrived := PortableMode.user_dir_in(PortableMode.platform(), folder, OS.get_user_data_dir())
	assert_true(FileAccess.file_exists(arrived.path_join("review_1121_shell_test/marker.txt")),
		"where the question said it would be")


func test_a_portable_folder_already_there_is_copied_into_and_kept() -> void:
	# Never staged, never removed: a real portable folder with a file of the
	# player's in it, and a copy that cannot be made into it.
	var folder := PortableMode.folder()
	DirAccess.make_dir_recursive_absolute(folder)
	var kept := FileAccess.open(folder.path_join("mine.txt"), FileAccess.WRITE)
	kept.store_string("mine")
	kept.close()
	var screen: Control = await _options()
	screen.ask_portable("make")
	await get_tree().process_frame
	FileAccess.set_unix_permissions(folder, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	var problem: String = await screen._copy_portable("make")
	FileAccess.set_unix_permissions(folder, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
		| FileAccess.UNIX_EXECUTE_OWNER)
	assert_ne(problem, "")
	assert_engine_error_count(0, "a plain refusal, no engine error")
	assert_true(FileAccess.file_exists(folder.path_join("mine.txt")), "the folder that was there stays")


func test_escape_closes_the_portable_window_and_stays_in_options() -> void:
	var screen: Control = await _options()
	screen.ask_portable("make")
	await get_tree().process_frame
	assert_not_null(screen.find_child("PortableWindow", true, false))
	screen._unhandled_input(_escape())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(screen.find_child("PortableWindow", true, false), "Escape is the window's Cancel")
	assert_true(is_instance_valid(screen) and screen.is_inside_tree(), "and Options stays")
	assert_false(DirAccess.dir_exists_absolute(PortableMode.folder()))


func test_escape_is_swallowed_while_the_copy_runs() -> void:
	var screen: Control = await _options()
	screen.ask_portable("make")
	await get_tree().process_frame
	screen._portable_copying = true
	screen._unhandled_input(_escape())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(screen.find_child("PortableWindow", true, false), "the window stays until the copy is done")
	assert_true(screen.is_inside_tree())
	screen._portable_copying = false


# ------------------------------------------------- the adventure's builder --

func _hero(bears: int) -> AdventurePlayer:
	var hero := AdventurePlayer.new()
	hero.gold = 120
	hero.difficulty = 1
	for i in bears:
		hero.cards.append({"card": "Grizzly Bears", "decks": [0]})
	for i in 40:
		hero.cards.append({"card": "Forest", "decks": [0]})
	return hero


func _open(hero: AdventurePlayer) -> Probe:
	var builder := Probe.new()
	builder.player = hero
	add_child_autofree(builder)
	await get_tree().process_frame
	return builder


func _bears_in_deck(hero: AdventurePlayer) -> int:
	var count := 0
	for card in hero.cards:
		if String(card["card"]) == "Grizzly Bears" and (card["decks"] as Array).has(0):
			count += 1
	return count


func test_the_window_s_close_asks_about_extra_cards_as_done_does() -> void:
	var hero := _hero(6)
	var builder: Probe = await _open(hero)
	assert_false(builder.deck.over_duplicate_limit(false, builder._copy_rule()).is_empty(),
		"six of a card is over the 1997 builder's rule")
	builder._on_window_close_request()
	await get_tree().process_frame
	assert_eq(builder.ends, 0, "asked first")
	assert_true(builder._dialog_busy(), "the Extra Cards box is up")
	# A second close with the box up says what to do, and ends nothing.
	builder._on_window_close_request()
	assert_eq(builder.ends, 0)
	assert_string_contains(builder._status_label.text, "too many copies")
	var remove := _button(builder, "Remove Extra Cards")
	assert_not_null(remove)
	remove.pressed.emit()
	await get_tree().process_frame
	assert_eq(builder.ends, 1, "the extras out, the game ends")
	assert_true(builder.deck.over_duplicate_limit(false, builder._copy_rule()).is_empty())
	assert_lt(_bears_in_deck(hero), 6, "and the deck written back is the trimmed one")
	assert_eq(_bears_in_deck(hero), builder.deck.count_of("Grizzly Bears"))


func test_the_window_s_close_keeps_the_deck_on_edit_deck() -> void:
	var hero := _hero(6)
	var builder: Probe = await _open(hero)
	builder._on_window_close_request()
	await get_tree().process_frame
	_button(builder, "Edit Deck").pressed.emit()
	await get_tree().process_frame
	assert_eq(builder.ends, 0, "the window stays")
	assert_eq(builder.deck.count_of("Grizzly Bears"), 6)


func test_a_deck_within_the_rule_closes_at_once() -> void:
	var hero := _hero(3)
	var builder: Probe = await _open(hero)
	builder._on_window_close_request()
	assert_eq(builder.ends, 1)
	assert_eq(_bears_in_deck(hero), 3)


func test_a_builder_that_only_looks_closes_at_once() -> void:
	var hero := _hero(6)
	var builder := Probe.new()
	builder.player = hero
	builder.looking = true
	add_child_autofree(builder)
	await get_tree().process_frame
	builder._on_window_close_request()
	assert_eq(builder.ends, 1)
	assert_eq(_bears_in_deck(hero), 6, "nothing changed")


func test_a_deck_past_what_the_builder_holds_keeps_every_card() -> void:
	var hero := AdventurePlayer.new()
	var names := CardRegistry.all_names()
	var most := DeckModel.MAX_UNIQUE + 7
	assert_gt(names.size(), most)
	for i in most:
		hero.cards.append({"card": String(names[i]), "decks": [0]})
	var builder: Probe = await _open(hero)
	assert_eq(builder.deck.unique(), DeckModel.MAX_UNIQUE, "the builder shows what it can hold")
	assert_eq(builder.beyond_total(0), 7)
	assert_string_contains(builder._status_label.text, "7 more cards", "and says so")
	builder.write_back()
	var kept := 0
	for card in hero.cards:
		if (card["decks"] as Array).has(0):
			kept += 1
	assert_eq(kept, most, "every card is still in its deck")
	# The cards shown still move as before: one taken out leaves the deck.
	var shown := String(builder.deck.names()[0])
	builder._remove_one(shown)
	builder.write_back()
	kept = 0
	for card in hero.cards:
		if (card["decks"] as Array).has(0):
			kept += 1
	assert_eq(kept, most - 1)


func test_an_ordinary_deck_has_nothing_beyond() -> void:
	var hero := _hero(3)
	var builder: Probe = await _open(hero)
	for slot in DeckBuilderScreen.SLOTS:
		assert_eq(builder.beyond_total(slot), 0)
	assert_string_contains(builder._status_label.text, "Your cards: 43")
	builder.write_back()
	assert_eq(_bears_in_deck(hero), 3)
