extends GutTest
## A ZIP REPLACED WHILE IT IS WORN (the bug campaign c12, h6-8).
##
## The engine reads a mounted zip by its path, at the places its directory
## named when it was mounted. A newer zip chosen under the same name was
## written over the mounted one: every read of the old mount printed
## engine ERRORs and gave nothing, and after the remount the files only
## the old zip held stayed broken until the offered restart (a probe: zip
## A mounted, zip B copied over it — 5 ERRORs and 0 bytes per read). Now
## the newcomer is kept beside it as `<name>.next-<n>.zip`, the old one
## untouched and readable until the restart, and at the next start the
## newcomer takes its own name back ([method SkinPack.settle_successors]).
##
## A card art zip is used for the mount: it is read at `res://skin/cardart`
## and changes nothing a skin test reads. The run fails on any engine
## ERROR line, so a read of a broken mount fails it by itself.

const SCRATCH := "user://test_c12_f6_skin_zips"
const PACKS := SCRATCH + "/cardpacks"

var _saved_packs: Variant = null
var _saved_skin: Variant = null
var _scene_was: Node = null
var _elsewhere: Node = null
var _skins_made: Array[String] = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(PACKS)
	_saved_packs = Settings.get_value(GamePaths.KEY_CARDPACKS, null) \
		if Settings.has_value(GamePaths.KEY_CARDPACKS) else null
	_saved_skin = Settings.get_value(GamePaths.KEY_SKIN_ZIP, null) \
		if Settings.has_value(GamePaths.KEY_SKIN_ZIP) else null
	Settings.set_value(GamePaths.KEY_CARDPACKS, PACKS)
	# A pack arriving on the title screen reloads the scene; pin a stand-in.
	_scene_was = get_tree().current_scene
	_elsewhere = Node.new()
	get_tree().root.add_child(_elsewhere)
	get_tree().current_scene = _elsewhere


func after_each() -> void:
	SkinPack._hide_notice()
	get_tree().current_scene = _scene_was
	_elsewhere.queue_free()
	for key: String in [GamePaths.KEY_CARDPACKS, GamePaths.KEY_SKIN_ZIP]:
		var was: Variant = _saved_packs if key == GamePaths.KEY_CARDPACKS else _saved_skin
		if was == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, was)
	GameSkin.clear_caches()
	for path in _skins_made:
		DirAccess.remove_absolute(path)
	_skins_made.clear()
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


static func _png(color: Color) -> PackedByteArray:
	var img := Image.create(4, 6, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img.save_png_to_buffer()


## A card art zip at [param path]: one picture per name, all [param color].
static func _art_zip(path: String, color: Color, names: Array) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packer := ZIPPacker.new()
	assert(packer.open(path) == OK)
	for name in names:
		packer.start_file("skin/cardart/%s.png" % name)
		packer.write_file(_png(color))
		packer.close_file()
	packer.close()


func test_a_zip_chosen_over_the_one_worn_is_kept_beside_it() -> void:
	var first := SCRATCH + "/first/zz_c12_f6_art.zip"
	_art_zip(first, Color.RED, ["zz_c12_f6_both", "zz_c12_f6_only_first"])
	assert_true(SkinPack.adopt(first))
	var kept := PACKS + "/zz_c12_f6_art.zip"
	assert_has(SkinPack.mounted, kept)
	var worn := FileAccess.get_sha256(kept)
	# The same name again, fewer pictures, another color.
	var second := SCRATCH + "/second/zz_c12_f6_art.zip"
	_art_zip(second, Color.BLUE, ["zz_c12_f6_both"])
	assert_true(SkinPack.adopt(second))
	var beside := PACKS + "/zz_c12_f6_art.next-1.zip"
	assert_eq(FileAccess.get_sha256(kept), worn, "the zip worn is left exactly as it was mounted")
	assert_eq(FileAccess.get_sha256(beside), FileAccess.get_sha256(second), "the newcomer is beside it")
	assert_eq(SkinPack.mounted[0], beside, "and worn first")
	# Every picture reads, from whichever zip holds it, until the restart.
	assert_eq(FileAccess.get_file_as_bytes("res://skin/cardart/zz_c12_f6_both.png"), _png(Color.BLUE),
		"the newcomer's picture wins")
	assert_eq(FileAccess.get_file_as_bytes("res://skin/cardart/zz_c12_f6_only_first.png"), _png(Color.RED),
		"the old zip's own picture still reads, and prints no error")
	# A third arrival under the name, through the browser's door.
	var landed := SkinPack.ARRIVING
	DirAccess.make_dir_recursive_absolute(SkinPack.USER_DIR)
	_art_zip(landed, Color.GREEN, ["zz_c12_f6_both"])
	assert_true(SkinPack._take(landed, "zz_c12_f6_art.zip"))
	assert_true(FileAccess.file_exists(PACKS + "/zz_c12_f6_art.next-2.zip"), "past every name mounted")
	assert_eq(FileAccess.get_sha256(beside), FileAccess.get_sha256(second), "the first newcomer untouched")


func test_a_zip_whose_mounted_file_is_gone_takes_its_own_name() -> void:
	var first := SCRATCH + "/first/zz_c12_f6_gone.zip"
	_art_zip(first, Color.RED, ["zz_c12_f6_gone_a"])
	assert_true(SkinPack.adopt(first))
	var kept := PACKS + "/zz_c12_f6_gone.zip"
	DirAccess.remove_absolute(kept)
	var second := SCRATCH + "/second/zz_c12_f6_gone.zip"
	_art_zip(second, Color.BLUE, ["zz_c12_f6_gone_a"])
	assert_true(SkinPack.adopt(second))
	assert_eq(FileAccess.get_sha256(kept), FileAccess.get_sha256(second), "nothing there to keep readable")
	assert_false(FileAccess.file_exists(PACKS + "/zz_c12_f6_gone.next-1.zip"))


func test_the_next_start_gives_the_newest_its_own_name() -> void:
	_art_zip(PACKS + "/zz_c12_f6_set.zip", Color.RED, ["zz_c12_f6_set_a"])
	_art_zip(PACKS + "/zz_c12_f6_set.next-1.zip", Color.GREEN, ["zz_c12_f6_set_a"])
	_art_zip(PACKS + "/zz_c12_f6_set.next-2.zip", Color.BLUE, ["zz_c12_f6_set_a"])
	var newest := FileAccess.get_sha256(PACKS + "/zz_c12_f6_set.next-2.zip")
	SkinPack.settle_successors(PACKS)
	assert_eq(FileAccess.get_sha256(PACKS + "/zz_c12_f6_set.zip"), newest, "the newest under the name")
	assert_false(FileAccess.file_exists(PACKS + "/zz_c12_f6_set.next-1.zip"), "the older newcomer gone")
	assert_false(FileAccess.file_exists(PACKS + "/zz_c12_f6_set.next-2.zip"))


func test_the_skin_key_follows_the_newcomer_to_its_name() -> void:
	DirAccess.make_dir_recursive_absolute(SkinPack.USER_DIR)
	var proper := SkinPack.USER_DIR + "/zz_c12_f6_skin.zip"
	var newcomer := SkinPack.USER_DIR + "/zz_c12_f6_skin.next-1.zip"
	_skins_made.append_array([proper, newcomer])
	_art_zip(proper, Color.RED, ["zz_c12_f6_skin_a"])
	_art_zip(newcomer, Color.BLUE, ["zz_c12_f6_skin_a"])
	Settings.set_value(GamePaths.KEY_SKIN_ZIP, newcomer)
	SkinPack.settle_successors(SkinPack.USER_DIR)
	assert_false(FileAccess.file_exists(newcomer))
	assert_eq(String(Settings.get_value(GamePaths.KEY_SKIN_ZIP, "")), proper, "the key names the zip worn")


func test_only_a_numbered_tail_is_a_newcomer() -> void:
	assert_eq(SkinPack.proper_name("user://skins/original_skin.next-3.zip"), "user://skins/original_skin.zip")
	for own: String in ["user://skins/original_skin.zip", "user://skins/x.next-.zip",
			"user://skins/x.next-0.zip", "user://skins/x.next-a.zip", "user://skins/.next-1.zip"]:
		assert_eq(SkinPack.proper_name(own), own, own + " is a name of its own")
