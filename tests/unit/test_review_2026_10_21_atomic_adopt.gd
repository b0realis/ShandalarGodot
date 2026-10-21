extends GutTest
## A CHOSEN FILE IS KEPT WHOLE OR NOT AT ALL (review of 2026-10-21,
## finding nettools-6).
##
## Choosing a skin or card art zip ([method SkinPack.adopt]) and choosing
## a card back ([method CardBack.adopt_bytes]) wrote the new file straight
## over the one the game kept — `DirAccess.copy_absolute` onto the kept
## zip, `Image.save_png` onto `card_back.png` — and both truncate the old
## file the moment they open it. A full disk or a crash part way through
## left half a file where a working one had been: the next start mounted
## no skin and fell back to the plain look, or wore no card back. They
## were the last player files in that corner not written the way decks,
## settings and pack seals are ([method Settings.write_atomically]): a
## pending file beside the kept one, checked, then renamed over it.
##
## The tests block the pending name with a folder — the one write failure
## a test can cause on purpose (tests/unit/test_bug_pass_2026_10_03_shell_io.gd
## does the same) — and hold the kept file to its bytes.
##
## The same door's other half (found by the review's verifier): a tar
## that is chosen or dropped, and a browser's download, are moved from the
## skins folder to their home ([method SkinPack._take]), and that move
## deleted the kept zip FIRST and renamed after — a rename that was then
## refused left neither zip. A rename replaces the file at its target on
## every platform the game runs on, so the kept zip now stays until the
## new one is in its place.

const SCRATCH := "user://review_2026_10_21_atomic_adopt"
## The card folder, pointed at scratch through its own key.
const PACKS := SCRATCH + "/cardpacks"

var _saved_packs: Variant = null
var _scene_was: Node = null
var _elsewhere: Node = null
## A folder a test made read-only, given its rights back before cleanup.
var _read_only := ""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(PACKS)
	_saved_packs = Settings.get_value(GamePaths.KEY_CARDPACKS, null) \
		if Settings.has_value(GamePaths.KEY_CARDPACKS) else null
	Settings.set_value(GamePaths.KEY_CARDPACKS, PACKS)
	# A pack arriving on the title screen reloads the scene; pin a stand-in
	# so every arrival here is "any other screen".
	_scene_was = get_tree().current_scene
	_elsewhere = Node.new()
	get_tree().root.add_child(_elsewhere)
	get_tree().current_scene = _elsewhere
	CardBack.place = SCRATCH + "/card_back.png"
	CardBack.forget_cache()


func after_each() -> void:
	SkinPack._hide_notice()
	get_tree().current_scene = _scene_was
	_elsewhere.queue_free()
	if _saved_packs == null:
		Settings.clear_value(GamePaths.KEY_CARDPACKS)
	else:
		Settings.set_value(GamePaths.KEY_CARDPACKS, _saved_packs)
	CardBack.place = ""
	CardBack.forget_cache()
	GameSkin.clear_caches()
	if _read_only != "":
		FileAccess.set_unix_permissions(_read_only, FileAccess.UNIX_READ_OWNER
			| FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
		_read_only = ""
	_remove_tree(ProjectSettings.globalize_path(SCRATCH))


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


static func _png(color: Color, w := 4, h := 6) -> PackedByteArray:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img.save_png_to_buffer()


## A card art zip: card pictures alone, one per name.
static func _art_zip(path: String, color: Color, names: Array) -> void:
	var packer := ZIPPacker.new()
	assert(packer.open(path) == OK)
	for name in names:
		packer.start_file("skin/cardart/%s.png" % name)
		packer.write_file(_png(color))
		packer.close_file()
	packer.close()


## The files in [param folder] other than [param kept]: what a write left.
static func _left_beside(folder: String, kept: String) -> Array:
	var out := []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	for name in dir.get_files():
		if name != kept:
			out.append(name)
	for name in dir.get_directories():
		out.append(name + "/")
	return out


# ------------------------------------------------------------ the zip --

func test_a_zip_that_could_not_be_copied_leaves_the_kept_one() -> void:
	var chosen := SCRATCH + "/zz_review_art.zip"
	_art_zip(chosen, Color.BLUE, ["zz_review_new_a", "zz_review_new_b"])
	var kept := SkinPack.home_for("cardart", chosen)
	assert_eq(kept, PACKS + "/zz_review_art.zip", "kept in the card folder by name")
	_art_zip(kept, Color.RED, ["zz_review_old"])
	var before := FileAccess.get_sha256(kept)
	# The copy cannot land: its pending name is a folder.
	var pending := Settings.pending_path(kept)
	DirAccess.make_dir_recursive_absolute(pending)
	assert_false(SkinPack.adopt(chosen), "the copy failed, and adopt says so")
	assert_eq(FileAccess.get_sha256(kept), before,
		"the kept zip is exactly the one that worked before")
	assert_does_not_have(SkinPack.mounted, kept, "nothing half-copied was mounted")
	assert_not_null(SkinPack.notice(), "the refusal is said on the screen")
	DirAccess.remove_absolute(pending)
	assert_eq(_left_beside(PACKS, kept.get_file()), [], "no pending file left behind")


func test_a_chosen_zip_replaces_the_kept_one_whole() -> void:
	var chosen := SCRATCH + "/zz_review_whole.zip"
	_art_zip(chosen, Color.BLUE, ["zz_review_whole_a", "zz_review_whole_b"])
	var kept := SkinPack.home_for("cardart", chosen)
	_art_zip(kept, Color.RED, ["zz_review_whole_old"])
	assert_true(SkinPack.adopt(chosen))
	assert_eq(FileAccess.get_sha256(kept), FileAccess.get_sha256(chosen),
		"the kept zip is now the chosen one, byte for byte")
	assert_has(SkinPack.mounted, kept)
	assert_eq(_left_beside(PACKS, kept.get_file()), [], "no pending file left behind")
	assert_true(FileAccess.file_exists(chosen), "the chosen file itself is not touched")


func test_a_repacked_zip_that_cannot_be_moved_leaves_the_kept_one() -> void:
	# The move is refused: the folder the repacked zip waits in may not be
	# changed, so the zip cannot leave it — while the card folder, where
	# the kept zip is, may be.
	var waiting := SCRATCH + "/read_only"
	DirAccess.make_dir_recursive_absolute(waiting)
	var landed := waiting + "/zz_review_landed.zip"
	_art_zip(landed, Color.BLUE, ["zz_review_moved_new"])
	var kept := PACKS + "/zz_review_moved.zip"
	_art_zip(kept, Color.RED, ["zz_review_moved_old"])
	var before := FileAccess.get_sha256(kept)
	FileAccess.set_unix_permissions(waiting, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	_read_only = waiting
	var took := SkinPack._take(landed, "zz_review_moved.tar.gz", "zz_review_moved.zip")
	if took:
		pass_test("this account may write a read-only folder (root): the move cannot be refused here")
		return
	assert_eq(FileAccess.get_sha256(kept), before,
		"the kept zip is exactly the one that worked before")
	assert_eq(_left_beside(PACKS, kept.get_file()), [], "nothing else in the card folder")


# ----------------------------------------------------------- the back --

func test_a_card_back_that_could_not_be_saved_leaves_the_old_one() -> void:
	assert_eq(CardBack.adopt_bytes(_png(Color.RED, 64, 90)), "", "the first back is kept")
	var before := FileAccess.get_sha256(CardBack.place)
	assert_ne(before, "", "a card back is there to keep")
	var pending := Settings.pending_path(CardBack.place)
	DirAccess.make_dir_recursive_absolute(pending)
	assert_eq(CardBack.adopt_bytes(_png(Color.BLUE, 64, 90)), CardBack.NOT_SAVED,
		"the save failed, and the row is told so")
	assert_eq(FileAccess.get_sha256(CardBack.place), before,
		"card_back.png is exactly the back that was worn")
	DirAccess.remove_absolute(pending)
	assert_eq(_left_beside(SCRATCH, CardBack.place.get_file()), ["cardpacks/"],
		"no pending file left behind")


func test_a_new_card_back_replaces_the_old_one_whole() -> void:
	assert_eq(CardBack.adopt_bytes(_png(Color.RED, 64, 90)), "")
	var first := FileAccess.get_sha256(CardBack.place)
	assert_eq(CardBack.adopt_bytes(_png(Color.BLUE, 64, 90)), "")
	assert_ne(FileAccess.get_sha256(CardBack.place), first, "the new back is the one kept")
	var img := Image.new()
	assert_eq(img.load_png_from_buffer(FileAccess.get_file_as_bytes(CardBack.place)), OK,
		"a whole PNG")
	assert_eq(img.get_size(), CardBack.SIZE)
	assert_eq(_left_beside(SCRATCH, CardBack.place.get_file()), ["cardpacks/"],
		"no pending file left behind")
