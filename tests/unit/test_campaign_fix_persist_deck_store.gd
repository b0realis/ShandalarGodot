extends GutTest
## WHERE THE PLAYER'S DECKS LIVE (whole-game campaign 2026-10, w7 LOWs).
##
##   1. Two DIFFERENT non-English titles shared one file. [method
##      DeckStore.file_stem] kept only a-z/0-9, so a title's Cyrillic,
##      Greek, CJK or accented letters vanished whenever any Latin letter
##      or digit was left: "Красная 2" and "Синяя 2" both saved to
##      `2.deck`, and the second save asked to overwrite a file named for
##      neither ("2.deck already exists") — OK replaced the OTHER deck.
##      A title with such letters now gets its fold plus a digest of the
##      whole title. Every all-ASCII title keeps the stem it had, the
##      all-non-Latin titles keep the 2026-10-03 `deck_<digest>` stems, and
##      a deck ALREADY saved under the old fold keeps its file
##      ([method DeckStore.path_for] finds it by the title inside).
##   2. A player who keeps `user://decks` as a SYMLINK (a synced folder)
##      lost the `User-created` heading on every deck they own, and Delete
##      refused with "is one of the decks the game ships":
##      [method DeckStore.is_user_deck] asked [method GamePaths.is_own],
##      whose rule refuses every linked place for "Forget my zips".

const ASIDE := "user://decks_campaign_fix_persist_aside"
const SYNCED := "user://campaign_fix_persist_synced"
const OUTSIDE := "user://campaign_fix_persist_outside"

var _moved := false
var _files: Array[String] = []


func before_all() -> void:
	CardRegistry.ensure_loaded()


func after_each() -> void:
	# Newest first, so a link goes before the file it points at, and a
	# link is removed even when it dangles (file_exists follows it).
	for i in range(_files.size() - 1, -1, -1):
		var path := _files[i]
		var dir := DirAccess.open(path.get_base_dir())
		if FileAccess.file_exists(path) or (dir != null and dir.is_link(path.get_file())):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_files.clear()
	var inner := DirAccess.open(DeckStore.USER_DIR)
	if inner != null and inner.is_link("campaign_linked_dir"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DeckStore.USER_DIR.path_join("campaign_linked_dir")))
	var decks := ProjectSettings.globalize_path(DeckStore.USER_DIR)
	var root := DirAccess.open("user://")
	if root != null and root.is_link("decks"):
		DirAccess.remove_absolute(decks)
	for folder in [SYNCED, OUTSIDE]:
		_empty(folder)
	if _moved:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(ASIDE), decks)
		_moved = false


func _empty(folder: String) -> void:
	var full := ProjectSettings.globalize_path(folder)
	var dir := DirAccess.open(full)
	if dir == null:
		return
	for sub in dir.get_directories():
		if dir.is_link(sub):
			DirAccess.remove_absolute(full.path_join(sub))
		else:
			_empty(folder.path_join(sub))
	for f in dir.get_files():
		DirAccess.remove_absolute(full.path_join(f))
	DirAccess.remove_absolute(full)


func _deck(title: String) -> DeckModel:
	var deck := DeckModel.new()
	deck.deck_name = title
	for i in 40: deck.add("Forest")
	return deck


func _user_paths_titled(title: String) -> Array:
	var out := []
	for path in DeckStore.deck_paths_in(DeckStore.USER_DIR):
		if DeckStore.title_in(DeckStore.read_text(path)) == title:
			out.append(path)
	return out


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_files.append(path)


# ------------------------------------------- 1. a title of its own --

func test_titles_in_other_scripts_get_files_of_their_own() -> void:
	for pair in [["Красная 2", "Синяя 2"], ["白デッキ2", "黒デッキ2"], ["Ωmega", "Σmega"],
			["Café Deck", "Cafè Deck"], ["Ñu 1", "Üu 1"]]:
		assert_ne(DeckStore.file_stem(pair[0]), DeckStore.file_stem(pair[1]),
			"'%s' and '%s' share %s" % [pair[0], pair[1], DeckStore.file_stem(pair[0])])
		assert_ne(DeckStore.path_for(pair[0]), DeckStore.path_for(pair[1]))


func test_such_a_stem_is_stable_and_still_reads_as_its_title() -> void:
	var red := DeckStore.file_stem("Красная 2")
	assert_eq(DeckStore.file_stem("  красная 2 "), red, "spacing and case fold as for a Latin title")
	assert_eq(DeckStore.file_stem("Красная 2"), red, "the same title, the same file")
	assert_true(red.begins_with("2_"), "the part that folds is still the start of the name: " + red)
	assert_true(DeckStore.file_stem("Café Deck").begins_with("caf_deck_"), DeckStore.file_stem("Café Deck"))
	assert_true(DeckStore.file_stem("Con ж").begins_with("con_"),
		"a digest stem is never a Windows device name: " + DeckStore.file_stem("Con ж"))
	for stem in [red, DeckStore.file_stem("白デッキ2"), DeckStore.file_stem("Ωmega")]:
		for ch in stem:
			assert_true((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_",
				"%s is a portable ASCII file name" % stem)


func test_every_ascii_title_keeps_the_stem_it_had() -> void:
	var cases := {"New Deck": "new_deck", "Knights!": "knights", "Knights?": "knights",
		"Big Green": "big_green", "  Cleric  ": "cleric", "CON": "deck_con", "lpt1": "deck_lpt1",
		"": "new_deck", "Gut Test Deck": "gut_test_deck", "R&D 2": "r_d_2"}
	for title in cases:
		assert_eq(DeckStore.file_stem(title), cases[title], "'%s'" % title)
	# Punctuation from outside ASCII is still punctuation: a dash, curly
	# quotes, an ellipsis and a no-break space fold as their ASCII twins.
	assert_eq(DeckStore.file_stem("Red — Deck"), "red_deck")
	assert_eq(DeckStore.file_stem("Mishra’s “Deck”…"), "mishra_s_deck")
	assert_eq(DeckStore.file_stem("Big Green"), "big_green")
	assert_eq(DeckStore.file_stem("Dark × Light"), "dark_light")


func test_titles_with_nothing_latin_keep_their_2026_10_03_stems() -> void:
	for title in ["Колода огня", "龍のデッキ"]:
		assert_eq(DeckStore.file_stem(title), "deck_" + title.to_lower().md5_text().left(10), title)


func test_two_titles_save_to_two_files_and_neither_reads_as_existing() -> void:
	var red := _deck("Красная 2")
	_files.append(DeckStore.path_for(red.deck_name))
	_files.append(DeckStore.path_for("Синяя 2"))
	assert_eq(DeckStore.save(red), "")
	assert_false(DeckStore.exists("Синяя 2"), "no @DECKEXISTS for a deck never saved")
	var blue := _deck("Синяя 2")
	assert_eq(DeckStore.save(blue), "")
	assert_eq(DeckStore.load_deck(DeckStore.path_for("Красная 2"), []).deck_name, "Красная 2",
		"the first deck is still the first deck")
	assert_eq(DeckStore.load_deck(DeckStore.path_for("Синяя 2"), []).deck_name, "Синяя 2")


## A deck saved before this fix under the old fold keeps its file: a
## re-save writes it in place rather than leaving a second copy beside it,
## and a DIFFERENT title that shared the fold is no longer told it exists.
func test_a_deck_saved_under_the_old_fold_keeps_its_file() -> void:
	var old := DeckStore.USER_DIR.path_join("2.deck")
	if FileAccess.file_exists(old):
		pass_test("the test profile already holds a 2.deck; nothing to prove here")
		return
	_write(old, "# Built in the Deck Builder.\nname: Красная 2\n40 Mountain\n")
	_files.append(DeckStore.USER_DIR.path_join(DeckStore.file_stem("Красная 2") + DeckStore.EXTENSION))
	_files.append(DeckStore.path_for("Синяя 2"))
	assert_eq(DeckStore.path_for("Красная 2"), old, "the title's own file, as it was saved")
	assert_eq(DeckStore.path_for("  КРАСНАЯ 2 "), old, "folded as the title is")
	assert_true(DeckStore.exists("Красная 2"))
	assert_ne(DeckStore.path_for("Синяя 2"), old)
	assert_false(DeckStore.exists("Синяя 2"), "the other title is not offered an overwrite")
	var red := DeckStore.load_deck(old, [])
	red.add("Mountain")
	assert_eq(DeckStore.save(red), "")
	assert_eq(DeckStore.saved_message(red), DeckStore.SAVED % "2.deck")
	assert_string_contains(FileAccess.get_file_as_string(old), "41 Mountain", "written in place")
	assert_eq(_user_paths_titled("Красная 2"), [old], "and no second copy beside it")


func test_a_shipped_title_in_another_script_is_still_guarded() -> void:
	var found := ""
	for path in DeckStore.shipped_paths():
		var title := DeckStore.title_in(DeckStore.read_text(path))
		for ch in title:
			if ch.unicode_at(0) >= 0xC0 and (ch.unicode_at(0) < 0x2000 or ch.unicode_at(0) > 0x206F):
				found = title
				break
		if found != "":
			break
	assert_ne(found, "", "some shipped deck's title has a letter beyond ASCII")
	assert_true(DeckStore.is_shipped_name(found), found)
	assert_true(DeckStore.is_shipped_name(found.to_upper()), "case-blind as before")


# ------------------------------------------- 2. a linked decks folder --

func _link_decks() -> bool:
	var decks := ProjectSettings.globalize_path(DeckStore.USER_DIR)
	if DirAccess.dir_exists_absolute(decks):
		_moved = DirAccess.rename_absolute(decks, ProjectSettings.globalize_path(ASIDE)) == OK
		if not _moved:
			return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SYNCED))
	return DirAccess.open("user://").create_link(ProjectSettings.globalize_path(SYNCED), decks) == OK


func test_decks_in_a_linked_decks_folder_are_the_players() -> void:
	if OS.get_name() == "Windows":
		pass_test("creating a link needs elevation on Windows")
		return
	assert_true(_link_decks(), "user://decks is a link to a real folder")
	var deck := _deck("Campaign Synced Deck")
	assert_eq(DeckStore.save(deck), "", "the save works through the link")
	var path := DeckStore.path_for(deck.deck_name)
	assert_true(DeckStore.all_deck_paths().has(path), "listed")
	assert_true(DeckStore.is_user_deck(path), "a deck the player saved is the player's")
	assert_eq(DeckGroups.of(path), DeckGroups.USER)
	assert_eq(DeckStore.delete_deck(path), "", "Delete is offered and works")
	assert_false(FileAccess.file_exists(ProjectSettings.globalize_path(SYNCED).path_join(path.get_file())),
		"the deck is gone from the synced folder")


func test_a_linked_deck_file_deletes_only_the_link() -> void:
	if OS.get_name() == "Windows":
		pass_test("creating a link needs elevation on Windows")
		return
	var target := OUTSIDE.path_join("kept.deck")
	_write(target, "name: Kept Elsewhere\n40 Forest\n")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var link := DeckStore.USER_DIR.path_join("campaign_linked_file.deck")
	assert_eq(DirAccess.open(DeckStore.USER_DIR).create_link(
		ProjectSettings.globalize_path(target), "campaign_linked_file.deck"), OK)
	_files.append(link)
	assert_true(DeckStore.is_user_deck(link), "listed under the player's decks, so theirs")
	assert_eq(DeckStore.delete_deck(link), "")
	assert_false(DirAccess.open(DeckStore.USER_DIR).file_exists("campaign_linked_file.deck"), "the link is gone")
	assert_true(FileAccess.file_exists(target), "the file it pointed at is untouched")


func test_the_containment_rules_still_hold() -> void:
	for path in ["user://decks/../music/keep.deck", "user://decks/../../other-game/keep.deck",
			"user://decks", "user://decks/", "user://decks_guard_probe.deck", "user://other/decks/x.deck",
			"user://decks\\..\\music\\keep.deck", "res://decks/big_green.deck", "/tmp/decks/x.deck",
			"user://decks/sub/../x.deck"]:
		assert_false(DeckStore.is_user_deck(path), path)
	assert_true(DeckStore.is_user_deck("user://decks/my_deck.deck"))
	assert_true(DeckStore.is_user_deck("user://decks/./my_deck.deck"))


func test_a_linked_folder_below_the_decks_folder_is_not_ours_to_delete_from() -> void:
	if OS.get_name() == "Windows":
		pass_test("creating a link needs elevation on Windows")
		return
	var target := OUTSIDE.path_join("inner.deck")
	_write(target, "name: Inner\n40 Forest\n")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DeckStore.USER_DIR))
	assert_eq(DirAccess.open(DeckStore.USER_DIR).create_link(
		ProjectSettings.globalize_path(OUTSIDE), "campaign_linked_dir"), OK)
	var through := DeckStore.USER_DIR.path_join("campaign_linked_dir/inner.deck")
	assert_false(DeckStore.is_user_deck(through), "a folder linked in below user://decks leads elsewhere")
	assert_ne(DeckStore.delete_deck(through), "")
	assert_true(FileAccess.file_exists(target), "and nothing was deleted through it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DeckStore.USER_DIR.path_join("campaign_linked_dir")))
