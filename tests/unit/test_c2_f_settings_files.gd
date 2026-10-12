extends GutTest
## THE PLAYER'S FILES, WRITTEN WHERE THEY ARE AND AS THEY ARE (robustness
## campaign of 2026-10-12). [method Settings.write_atomically] — the one
## writer behind settings.cfg, deck saves and exports, the pack seals and
## now the Deck Lab's Elo ledger — wrote a pending file and renamed it
## over the path. That is whole-or-nothing, and it also:
##
##   * replaced a LINK with a plain file: a deck in user://decks linked to
##     a synced folder, or a settings.cfg kept in a dotfiles repository,
##     stopped being a link on the first save and the real file never
##     heard of it — while the game said "has been saved";
##   * replaced a file the player had made READ-ONLY to keep it as it was,
##     and reset its mode;
##   * used ONE pending name per file, so two game instances on one
##     profile (a LAN host and its client on one desk) saving at once
##     wrote into each other's pending file and renamed a mixture into
##     place (1377 errors and 256 mixed files in 3000 saves);
##   * and [Settings] wrote its whole cached file, so the second instance
##     erased whatever the first had saved meanwhile.
##
## The Elo ledger (`decks/ratings.txt`) was the last writer outside it:
## written in place, a full disk left 108 of 402 decks.

const SETTINGS := "user://settings.cfg"
const OUTSIDE := "user://c2_f_settings_outside"
const HERE := "user://c2_f_settings_here"
const RACE := "user://c2_f_settings_here/race.txt"
## r--r--r-- and rw-------, as numbers (GDScript has no octal literal).
const READ_ONLY := 292
const OWNER_ONLY := 384

var _had := false
var _old := PackedByteArray()
var _stop := false
var _decks: Array[String] = []


func before_all() -> void:
	CardRegistry.ensure_loaded()
	Settings.flush()
	_had = FileAccess.file_exists(SETTINGS)
	if _had:
		_old = FileAccess.get_file_as_bytes(SETTINGS)


func before_each() -> void:
	for dir in [OUTSIDE, HERE]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


func after_each() -> void:
	Engine.print_error_messages = true
	for dir in [OUTSIDE, HERE]:
		_empty(dir)
	for path in _decks:
		_remove(path)
	_decks.clear()
	_restore_settings()


func after_all() -> void:
	_restore_settings()


func _restore_settings() -> void:
	var root := DirAccess.open("user://")
	if root != null and root.is_link(SETTINGS.get_file()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	if _had:
		Settings.write_atomically(SETTINGS, _old)
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("settings.cfg.bad"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + name))
	Settings.reload_file()


static func _remove(path: String) -> void:
	var global := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global):
		FileAccess.set_unix_permissions(global, 420)
	var dir := DirAccess.open(path.get_base_dir())
	if FileAccess.file_exists(global) or (dir != null and dir.is_link(path.get_file())):
		DirAccess.remove_absolute(global)


static func _empty(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.include_hidden = true
	for name in dir.get_files():
		_remove(dir_path.path_join(name))
	for name in dir.get_directories():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path))


static func _write_plain(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _link(target: String, link: String) -> Error:
	return DirAccess.open("user://").create_link(target, ProjectSettings.globalize_path(link))


static func _is_link(path: String) -> bool:
	var dir := DirAccess.open(path.get_base_dir())
	return dir != null and dir.is_link(path.get_file())


## Every name in [param dir_path] that is a pending write left behind.
static func _pending_left(dir_path: String) -> Array:
	return Array(DirAccess.get_files_at(dir_path)).filter(func(name: String) -> bool:
		return name.contains(Settings.PENDING_TAIL))


static func _posix() -> bool:
	return OS.get_name() in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]


# --------------------------------------------------------------- links --

func test_a_write_through_a_link_reaches_its_file_and_the_link_stays() -> void:
	var target := ProjectSettings.globalize_path(OUTSIDE.path_join("synced.txt"))
	_write_plain(target, "old\n")
	var link := HERE.path_join("linked.txt")
	assert_eq(_link(target, link), OK)
	assert_eq(Settings.write_atomically(link, "new\n".to_utf8_buffer()), OK)
	assert_eq(FileAccess.get_file_as_string(target), "new\n", "the file the link names has it")
	assert_true(_is_link(link), "the link is still a link")
	assert_eq(FileAccess.get_file_as_string(link), "new\n", "and reads the same")
	assert_eq(_pending_left(HERE), [], "nothing pending beside the link")
	assert_eq(_pending_left(OUTSIDE), [], "nothing pending beside the file")


func test_a_relative_link_and_a_chain_of_links() -> void:
	var target := ProjectSettings.globalize_path(HERE.path_join("real.txt"))
	_write_plain(target, "old\n")
	# A relative link (`ln -s real.txt first.txt`), and a link to that link.
	var dir := DirAccess.open(HERE)
	assert_eq(dir.create_link("real.txt", ProjectSettings.globalize_path(HERE.path_join("first.txt"))), OK)
	assert_eq(_link(ProjectSettings.globalize_path(HERE.path_join("first.txt")), OUTSIDE.path_join("second.txt")), OK)
	assert_eq(Settings.write_atomically(OUTSIDE.path_join("second.txt"), "new\n".to_utf8_buffer()), OK)
	assert_eq(FileAccess.get_file_as_string(target), "new\n")
	assert_true(_is_link(HERE.path_join("first.txt")) and _is_link(OUTSIDE.path_join("second.txt")),
		"both links stay links")


func test_a_linked_deck_saves_into_the_synced_copy() -> void:
	var target := ProjectSettings.globalize_path(OUTSIDE.path_join("synced.deck"))
	_write_plain(target, "name: C2 Linked Probe\n40 Forest\n")
	var link := DeckStore.USER_DIR.path_join("c2_linked_probe.deck")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DeckStore.USER_DIR))
	_decks.append(link)
	assert_eq(_link(target, link), OK)
	var report := []
	var model := DeckStore.load_deck(link, report)
	assert_not_null(model)
	if model == null:
		return
	assert_eq(DeckStore.path_for(model.deck_name), link, "it saves back to the same path")
	model.add("Island")
	assert_eq(DeckStore.save(model), "")
	assert_string_contains(FileAccess.get_file_as_string(target), "Island",
		"the save reached the synced file")
	assert_true(_is_link(link), "and the deck is still the link the player made")


func test_a_linked_settings_file_is_read_and_written_through_the_link() -> void:
	var target := ProjectSettings.globalize_path(OUTSIDE.path_join("settings.cfg"))
	_write_plain(target, "[options]\nmusic_enabled=false\n")
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	assert_eq(_link(target, SETTINGS), OK)
	Settings.reload_file()
	assert_false(Settings.music_enabled(), "read through the link")
	Settings.set_value("c2_probe", 7)
	assert_false(Settings.is_dirty())
	assert_string_contains(FileAccess.get_file_as_string(target), "c2_probe=7")
	assert_true(_is_link(SETTINGS), "settings.cfg is still a link")


# ----------------------------------------------------------- read-only --

func test_a_read_only_file_is_refused_and_left_as_it_was() -> void:
	if not _posix():
		pass_test("mode bits are how a desk test makes a file read-only; not here")
		return
	var path := HERE.path_join("kept.txt")
	_write_plain(path, "kept\n")
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(path), READ_ONLY)
	assert_eq(Settings.write_atomically(path, "new\n".to_utf8_buffer()), ERR_FILE_NO_PERMISSION)
	assert_eq(FileAccess.get_file_as_string(path), "kept\n", "the player's file is untouched")
	assert_eq(FileAccess.get_unix_permissions(ProjectSettings.globalize_path(path)) & 511, READ_ONLY,
		"and keeps its mode")
	assert_eq(_pending_left(HERE), [], "nothing pending left behind")


func test_a_read_only_deck_is_not_saved_over() -> void:
	if not _posix():
		pass_test("mode bits are how a desk test makes a file read-only; not here")
		return
	var deck := DeckModel.new()
	deck.deck_name = "C2 Read Only Probe"
	for i in 40: deck.add("Forest")
	var path := DeckStore.path_for(deck.deck_name)
	_decks.append(path)
	assert_eq(DeckStore.save(deck), "")
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(path), READ_ONLY)
	deck.add("Island")
	assert_ne(DeckStore.save(deck), "", "a refusal is said")
	assert_false(FileAccess.get_file_as_string(path).contains("Island"), "and the file is as it was")


func test_a_rewritten_file_keeps_its_mode() -> void:
	if not _posix():
		pass_test("no mode bits here")
		return
	var path := HERE.path_join("private.txt")
	_write_plain(path, "old\n")
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(path), OWNER_ONLY)
	assert_eq(Settings.write_atomically(path, "new\n".to_utf8_buffer()), OK)
	assert_eq(FileAccess.get_file_as_string(path), "new\n")
	assert_eq(FileAccess.get_unix_permissions(ProjectSettings.globalize_path(path)) & 511, OWNER_ONLY,
		"rw------- stays rw-------")


# ------------------------------------------------- two writers at once --

func test_each_process_and_thread_has_its_own_pending_name() -> void:
	var path := HERE.path_join("x.txt")
	var mine := Settings.pending_path(path)
	assert_true(mine.begins_with(path + Settings.PENDING_TAIL), mine)
	assert_string_contains(mine, str(OS.get_process_id()))
	var thread := Thread.new()
	thread.start(func() -> String: return Settings.pending_path(path))
	var theirs: String = thread.wait_to_finish()
	assert_ne(mine, theirs, "another thread pends under another name")
	assert_eq(Settings.pending_path(path), mine, "and one thread under one name")


func _writer(bytes: PackedByteArray) -> void:
	while not _stop:
		Settings.write_atomically(RACE, bytes)


func test_two_writers_at_once_never_leave_a_mixture() -> void:
	var a := PackedByteArray()
	a.resize(1200)
	a.fill(0x61)
	var b := PackedByteArray()
	b.resize(1000)
	b.fill(0x62)
	_stop = false
	var thread := Thread.new()
	thread.start(_writer.bind(a))
	var mixed := 0
	var errors := 0
	for i in 600:
		if Settings.write_atomically(RACE, b) != OK:
			errors += 1
		var now := FileAccess.get_file_as_bytes(RACE)
		if now.size() > 0 and now != a and now != b:
			mixed += 1
	_stop = true
	thread.wait_to_finish()
	assert_eq(mixed, 0, "the live file is always one whole version")
	assert_eq(errors, 0, "and neither writer's save failed")
	assert_eq(_pending_left(HERE), [], "nothing pending left behind")


func test_a_second_instance_change_survives_this_ones_save() -> void:
	Settings.write_atomically(SETTINGS, "[options]\nmusic_enabled=true\nhand_style=\"fan\"\nai_pace=0.5\n".to_utf8_buffer())
	Settings.reload_file()
	assert_true(Settings.music_enabled())
	# The other instance saves its own change, the whole file, atomically —
	# a pack switched on, the hand style changed back and the pace cleared.
	Settings.write_atomically(SETTINGS,
		"[options]\nmusic_enabled=true\nhand_style=\"stack\"\nenabled_card_packs=[\"pack-2\"]\n".to_utf8_buffer())
	Settings.set_value("sound_enabled", false)     # this one saves an unrelated option
	var now := ConfigFile.new()
	assert_eq(now.load(SETTINGS), OK)
	assert_eq(now.get_value("options", "enabled_card_packs", []), ["pack-2"], "the other's pack survives")
	assert_eq(now.get_value("options", "hand_style", ""), "stack", "and its hand style")
	assert_false(now.has_section_key("options", "ai_pace"), "and the key it cleared stays cleared")
	assert_eq(now.get_value("options", "sound_enabled", true), false, "with this one's change")
	assert_eq(Settings.hand_style(), "stack", "and this instance now reads what is on disk")
	# Both change the same key: the later save is the one that stands.
	Settings.write_atomically(SETTINGS, FileAccess.get_file_as_string(SETTINGS)
		.replace("sound_enabled=false", "sound_enabled=true").to_utf8_buffer())
	Settings.clear_value("enabled_card_packs")
	Settings.set_value("music_enabled", false)
	now = ConfigFile.new()
	now.load(SETTINGS)
	assert_false(now.has_section_key("options", "enabled_card_packs"), "this one's clear holds")
	assert_eq(now.get_value("options", "music_enabled", true), false, "and its change")
	assert_eq(now.get_value("options", "sound_enabled", false), true,
		"a key this one did not touch again is the other's")


func test_a_file_changed_into_one_that_will_not_parse_is_kept_before_this_one_saves() -> void:
	Settings.write_atomically(SETTINGS, "[options]\nhand_style=\"fan\"\n".to_utf8_buffer())
	Settings.reload_file()
	var broken := "[options]\nhand_style=\"stack\"\nmusic_folder=~/Music\nportrait_0=\"a\"\n"
	_write_plain(SETTINGS, broken)
	Engine.print_error_messages = false
	Settings.set_value("ai_pace", 0.5)
	Engine.print_error_messages = true
	assert_eq(FileAccess.get_file_as_string(SETTINGS + ".bad"), broken,
		"the hand edit is kept byte for byte")
	var now := ConfigFile.new()
	assert_eq(now.load(SETTINGS), OK, "what is written reads")
	assert_eq(now.get_value("options", "ai_pace", 0.0), 0.5)
	assert_string_contains(Settings.problem(), "settings.cfg.bad", "and the player is told where it is")


# ----------------------------------------------------------- the ledger --

func test_the_elo_ledger_is_written_whole_or_not_at_all() -> void:
	var path := HERE.path_join("ratings.txt")
	var ledger := EloLedger.new()
	ledger.path = path
	ledger.record_matchup("Old Deck A", "Old Deck B", 3, 1)
	assert_true(ledger.save())
	var before := FileAccess.get_file_as_string(path)
	assert_eq(EloLedger.load_from(path).entries.size(), 2)
	# A write that cannot finish: its pending name is taken by a folder.
	var pending := Settings.pending_path(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pending))
	var bigger := EloLedger.load_from(path)
	for i in 40:
		bigger.record_matchup("Deck %02d" % i, "Old Deck A", 1, 0)
	assert_false(bigger.save(), "the failed save says so")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pending))
	assert_eq(FileAccess.get_file_as_string(path), before, "and the old ledger is whole")
	assert_true(bigger.save(), "the next save goes through")
	assert_eq(EloLedger.load_from(path).entries.size(), 42)
	assert_eq(_pending_left(HERE), [])


func test_the_elo_ledger_writes_through_a_link() -> void:
	var target := ProjectSettings.globalize_path(OUTSIDE.path_join("ratings.txt"))
	_write_plain(target, "# old\n")
	var link := HERE.path_join("ratings.txt")
	assert_eq(_link(target, link), OK)
	var ledger := EloLedger.new()
	ledger.path = link
	ledger.record_matchup("A", "B", 1, 0)
	assert_true(ledger.save())
	assert_true(_is_link(link))
	assert_eq(EloLedger.load_from(target).entries.size(), 2)
