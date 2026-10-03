extends GutTest
## THE PLAYER'S FILES, WRITTEN WHOLE (bug pass of 2026-10-03).
##
##   1. A hand-edited `settings.cfg` that will not parse (an unquoted
##      path, a Windows path whose `\U` reads as an escape) left
##      [Settings] holding only the keys above the bad line, and the next
##      save rewrote the file from that — every key below it gone. The
##      file is now copied aside (`settings.cfg.bad`) before anything can
##      be written over it; one that cannot even be read is never
##      written this session.
##   2. [method DeckStore.save], [method DeckStore.export_deck],
##      [Settings] and [method PackSeal.seal] truncated their file in
##      place and never asked whether the write went through — a full
##      disk reported "has been saved" over a deck that was gone. Each
##      now writes a pending file and renames it over the old one
##      ([method Settings.write_atomically]); the tests block the pending
##      name with a folder, which is the one write failure a test can
##      cause on purpose, and hold the old file to its bytes.
##   3. [method DeckStore.file_stem] folded every title with no Latin
##      letter or digit to `new_deck` — two decks, one file.

## The pending file's tail, written out rather than read off the class
## so the test speaks of the file on disk.
const PENDING := ".tmp"

var _settings_path := ""
var _settings_existed := false
var _settings_backup := PackedByteArray()
var _deck_files: Array[String] = []


func before_all() -> void:
	CardRegistry.ensure_loaded()


func before_each() -> void:
	# The suite profile's settings file is shared: copy it out byte for
	# byte and put it back, whatever the test wrote.
	Settings.flush()
	_settings_path = ProjectSettings.globalize_path(Settings.PATH)
	_settings_existed = FileAccess.file_exists(_settings_path)
	if _settings_existed:
		_settings_backup = FileAccess.get_file_as_bytes(_settings_path)
	_deck_files = []


func after_each() -> void:
	Engine.print_error_messages = true
	if OS.get_name() in ["Linux", "macOS"] and FileAccess.file_exists(_settings_path):
		OS.execute("chmod", ["644", _settings_path])
	DirAccess.remove_absolute(_settings_path + PENDING)
	if _settings_existed:
		var file := FileAccess.open(_settings_path, FileAccess.WRITE)
		file.store_buffer(_settings_backup)
		file.close()
	elif FileAccess.file_exists(_settings_path):
		DirAccess.remove_absolute(_settings_path)
	for name in DirAccess.get_files_at(_settings_path.get_base_dir()):
		if name.begins_with("settings.cfg.bad"):
			DirAccess.remove_absolute(_settings_path.get_base_dir().path_join(name))
	Settings.reload_file()
	for path in _deck_files:
		DirAccess.remove_absolute(path + PENDING)
		DirAccess.remove_absolute(path)


func _write_settings(text: String) -> void:
	var file := FileAccess.open(Settings.PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Read the file as a fresh boot would, with Godot's own parse complaint
## kept off the log: the run fails on any engine ERROR line, and this one
## is the point of the test. `Settings.reload_file()` forgets the cache
## and reads the file again inside the quiet window (`has_value` makes
## sure of it).
func _boot_quietly() -> void:
	Engine.print_error_messages = false
	Settings.reload_file()
	Settings.has_value("hand_style")
	Engine.print_error_messages = true


func _deck(title: String, cards: Array) -> DeckModel:
	var deck := DeckModel.new()
	deck.deck_name = title
	for card_name in cards:
		assert_eq(deck.add(String(card_name)), "", card_name)
	return deck


# ------------------------------------------------ 1. a hand edit kept --

func test_a_hand_edited_settings_file_that_will_not_parse_is_kept_before_the_next_save() -> void:
	for bad in ['music_folder=~/Music', 'music_folder="C:\\Users\\zz\\Music"']:
		var text: String = "[options]\n\nsound_enabled=false\nhand_style=\"fan\"\n" \
			+ bad + "\nportrait_0=\"grey_wizard\"\n"
		_write_settings(text)
		for name in DirAccess.get_files_at(_settings_path.get_base_dir()):
			if name.begins_with("settings.cfg.bad"):
				DirAccess.remove_absolute(_settings_path.get_base_dir().path_join(name))
		_boot_quietly()
		assert_eq(Settings.get_value("hand_style", "stack"), "fan",
			"what parsed above the bad line is still read: " + bad)
		Settings.set_value("ai_pace", 0.5)
		assert_true(FileAccess.file_exists(Settings.PATH + ".bad"),
			"the player's file is copied aside before it is written over: " + bad)
		assert_eq(FileAccess.get_file_as_string(Settings.PATH + ".bad"), text,
			"byte for byte, the bad line and every key below it: " + bad)
		var now := ConfigFile.new()
		assert_eq(now.load(Settings.PATH), OK, "what is written is a file that reads")
		assert_eq(now.get_value("options", "ai_pace", null), 0.5)


func test_the_same_broken_file_is_kept_once_and_another_never_overwrites_it() -> void:
	var first := "[options]\n\nhand_style=\"fan\"\nmusic_folder=~/Music\nportrait_0=\"a\"\n"
	_write_settings(first)
	_boot_quietly()
	_boot_quietly()   # a second start that saved nothing in between
	var copies := Array(DirAccess.get_files_at(_settings_path.get_base_dir())).filter(
		func(name: String) -> bool: return name.begins_with("settings.cfg.bad"))
	assert_eq(copies, ["settings.cfg.bad"], "the same file is not copied twice")
	var second := "[options]\n\nhand_style=\"stack\"\nmusic_folder=~/Tunes\n"
	_write_settings(second)
	_boot_quietly()
	assert_eq(FileAccess.get_file_as_string(Settings.PATH + ".bad"), first,
		"the first copy is not overwritten by a later broken file")
	copies = Array(DirAccess.get_files_at(_settings_path.get_base_dir())).filter(
		func(name: String) -> bool: return name.begins_with("settings.cfg.bad"))
	assert_eq(copies.size(), 2, "the later one is kept beside it")


func test_a_settings_file_that_cannot_be_read_is_never_written_over() -> void:
	if not OS.get_name() in ["Linux", "macOS"]:
		pass_test("mode bits are how a desk test makes a file unreadable; not here")
		return
	var text := "[options]\n\nhand_style=\"fan\"\nportrait_0=\"grey_wizard\"\n"
	_write_settings(text)
	OS.execute("chmod", ["000", _settings_path])
	if FileAccess.open(Settings.PATH, FileAccess.READ) != null:
		OS.execute("chmod", ["644", _settings_path])
		pass_test("this user reads every file (root); the test cannot pose the case")
		return
	Settings.reload_file()
	Settings.set_value("ai_pace", 0.5)
	assert_true(Settings.is_dirty(), "the change stays pending")
	OS.execute("chmod", ["644", _settings_path])
	assert_eq(FileAccess.get_file_as_string(Settings.PATH), text,
		"a file the game could not read is not replaced by what it could")


# ------------------------------------------- 2. written whole or not --

func test_a_settings_write_that_cannot_finish_leaves_the_file_and_stays_pending() -> void:
	var text := "[options]\n\nhand_style=\"fan\"\n"
	_write_settings(text)
	Settings.reload_file()
	DirAccess.make_dir_recursive_absolute(_settings_path + PENDING)
	Settings.set_value("ai_pace", 0.5)
	DirAccess.remove_absolute(_settings_path + PENDING)
	assert_true(Settings.is_dirty(), "a write that did not happen is still pending")
	assert_eq(FileAccess.get_file_as_string(Settings.PATH), text,
		"the file is never opened for writing in place")
	Settings.flush()
	assert_false(Settings.is_dirty(), "and the next try writes it")
	assert_eq(Settings.get_value("ai_pace", 0.0), 0.5)


func test_a_deck_save_that_cannot_finish_keeps_the_old_deck_and_says_so() -> void:
	var deck := _deck("zz Pending Probe", ["Lightning Bolt", "Lightning Bolt", "Mountain"])
	var path := DeckStore.path_for(deck.deck_name)
	_deck_files.append(path)
	assert_eq(DeckStore.save(deck), "")
	var before := FileAccess.get_file_as_string(path)
	DirAccess.make_dir_recursive_absolute(path + PENDING)
	deck.add("Mountain")
	assert_eq(DeckStore.save(deck), DeckStore.SAVE_ERROR % path.get_file(),
		"a save that did not happen says so")
	DirAccess.remove_absolute(path + PENDING)
	assert_eq(FileAccess.get_file_as_string(path), before, "and the old deck is whole")
	assert_eq(DeckStore.save(deck), "", "the next save goes through")
	var report := []
	assert_eq(DeckStore.load_deck(path, report).total(), 4)
	assert_false(FileAccess.file_exists(path + PENDING), "nothing pending left behind")


func test_an_export_that_cannot_finish_says_so() -> void:
	var deck := _deck("zz Export Pending Probe", ["Lightning Bolt", "Mountain"])
	var path := "%s/%s.dec" % [DeckStore.EXPORT_DIR, DeckStore.file_stem(deck.deck_name)]
	_deck_files.append(path)
	DirAccess.make_dir_recursive_absolute(path + PENDING)
	var written := []
	assert_eq(DeckStore.export_deck(deck, ".dec", written),
		DeckStore.SAVE_ERROR % path.get_file())
	assert_eq(written, [], "no path is named for a file that was not written")
	DirAccess.remove_absolute(path + PENDING)
	assert_eq(DeckStore.export_deck(deck, ".dec", written), "")
	assert_eq(written, [path])
	assert_string_contains(FileAccess.get_file_as_string(path), "Lightning Bolt")


# ------------------------------------------- 3. a title of its own --

func test_a_title_with_no_latin_letters_gets_a_file_of_its_own() -> void:
	var fire := DeckStore.file_stem("Колода огня")
	var dragon := DeckStore.file_stem("龍のデッキ")
	assert_ne(fire, "new_deck", "not the default deck's file")
	assert_ne(dragon, "new_deck")
	assert_ne(fire, dragon, "two titles, two files")
	assert_true(fire.begins_with("deck_"), fire)
	assert_eq(DeckStore.file_stem("Колода огня"), fire, "the same title, the same file")
	assert_eq(DeckStore.file_stem("  колода огня "), fire,
		"spacing and case fold as they do for a Latin title")
	assert_eq(DeckStore.file_stem("New Deck"), "new_deck", "existing stems are unchanged")
	assert_eq(DeckStore.file_stem("Ωmega"), "mega")
	assert_eq(DeckStore.file_stem("Knights!"), "knights")
	assert_eq(DeckStore.file_stem(""), "new_deck", "an empty title is still the default")
	var a := _deck("Колода огня", ["Lightning Bolt"])
	var b := _deck("龍のデッキ", ["Forest"])
	_deck_files.append(DeckStore.path_for(a.deck_name))
	_deck_files.append(DeckStore.path_for(b.deck_name))
	assert_eq(DeckStore.save(a), "")
	assert_false(DeckStore.exists(b.deck_name), "the second title finds no file waiting")
	assert_eq(DeckStore.save(b), "")
	var report := []
	assert_eq(DeckStore.load_deck(DeckStore.path_for(a.deck_name), report).deck_name,
		"Колода огня", "the first deck is still the first deck")
