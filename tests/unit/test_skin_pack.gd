extends GutTest
## THE SKIN PACK — [SkinPack] (2026-09-08, `[QoL]`): the skin as one zip
## mounted at `res://skin`, read by [GameSkin], [PortraitLibrary] and
## [MusicLibrary] in place. A tiny zip is built here with [ZIPPacker]
## (a 4x6 PNG, a portrait, a sidecar), so the contract is tested in a
## checkout with no 1997 art at all: what a valid zip is, what happens
## when one is mounted, where the browser looks, and what a drop keeps.
##
## A mount is for the life of the process (the engine has no unmount),
## so the probe's keys are `zz_`-prefixed and the world is put back
## through [member GameSkin.pack_mounted], which is what makes the
## mounted folder visible to the searches at all.

const SCRATCH := "user://skin_pack_test"
const GOOD := SCRATCH + "/probe.zip"
const OUTSIDE := SCRATCH + "/outside.zip"
const CLIMBING := SCRATCH + "/climbing.zip"
const EMPTY := SCRATCH + "/empty.zip"
const NOT_A_ZIP := SCRATCH + "/not_a_zip.zip"
## Kept aside while a test stores its own zip where the player's goes.
const ASIDE := SCRATCH + "/aside.zip"

var _was_mounted := false
var _had_user_zip := false


func before_each() -> void:
	_was_mounted = GameSkin.pack_mounted
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	_had_user_zip = FileAccess.file_exists(SkinPack.USER_ZIP)
	if _had_user_zip:
		DirAccess.rename_absolute(SkinPack.USER_ZIP, ASIDE)
	_write_probe()


func after_each() -> void:
	GameSkin.pack_mounted = _was_mounted
	GameSkin.clear_caches()
	PortraitLibrary.refresh()
	MusicLibrary.refresh()
	SkinPack._hide_notice()
	if FileAccess.file_exists(SkinPack.USER_ZIP):
		DirAccess.remove_absolute(SkinPack.USER_ZIP)
	if _had_user_zip:
		DirAccess.rename_absolute(ASIDE, SkinPack.USER_ZIP)
	for name in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(name))
	DirAccess.remove_absolute(SCRATCH)


## A 4x6 picture, so a texture read back through the mount is measurable.
static func _png() -> PackedByteArray:
	var img := Image.create(4, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.ORANGE_RED)
	return img.save_png_to_buffer()


static func _zip(path: String, entries: Dictionary) -> void:
	var packer := ZIPPacker.new()
	assert(packer.open(path) == OK)
	for name in entries:
		packer.start_file(name)
		var body: Variant = entries[name]
		packer.write_file(body if body is PackedByteArray else String(body).to_utf8_buffer())
		packer.close_file()
	packer.close()


func _write_probe() -> void:
	_zip(GOOD, {
		"skin/zz_pack_probe.png": _png(),
		"skin/zz_pack_probe.json": '{"cols": 7, "rows": 9}',
		"skin/portraits/zz_probe_face.png": _png(),
		"skin/music/README.txt": "not a tune",
	})
	_zip(OUTSIDE, {"skin/zz_x.png": _png(), "readme.txt": "loose"})
	_zip(CLIMBING, {"skin/../zz_escape.png": _png()})
	_zip(EMPTY, {"skin/": PackedByteArray()})
	var file := FileAccess.open(NOT_A_ZIP, FileAccess.WRITE)
	file.store_string("<html>404 Not Found</html>")
	file.close()


# ---------------------------------------------------------- the contract --

func test_a_zip_with_everything_under_skin_is_a_skin() -> void:
	var report := SkinPack.inspect(GOOD)
	assert_true(report["ok"], String(report["why"]))
	assert_eq(int(report["files"]), 4, "four files, no folder entries")


func test_an_entry_outside_skin_refuses_the_whole_zip() -> void:
	var report := SkinPack.inspect(OUTSIDE)
	assert_false(report["ok"])
	assert_string_contains(String(report["why"]), "readme.txt")


func test_a_climbing_entry_refuses_the_zip() -> void:
	assert_false(SkinPack.inspect(CLIMBING)["ok"])


func test_an_empty_zip_is_not_a_skin() -> void:
	var report := SkinPack.inspect(EMPTY)
	assert_false(report["ok"])
	assert_string_contains(String(report["why"]), "no skin/ folder")


func test_a_404_page_saved_as_a_zip_is_not_a_skin() -> void:
	var report := SkinPack.inspect(NOT_A_ZIP)
	assert_false(report["ok"])
	assert_eq(String(report["why"]), "not a zip file")


func test_a_missing_file_is_not_a_skin() -> void:
	assert_false(SkinPack.inspect(SCRATCH + "/nowhere.zip")["ok"])


# ------------------------------------------------------------- the mount --

func test_a_mounted_pack_is_read_by_the_skin_in_place() -> void:
	assert_true(SkinPack.mount(GOOD, true), "the probe mounts")
	assert_true(GameSkin.pack_mounted)
	assert_has(GameSkin.search_dirs(), GameSkin.PACK_DIR)
	assert_true(GameSkin.is_present(), "a mounted pack counts as a skin")
	GameSkin.clear_caches()
	var tex := GameSkin.texture("zz_pack_probe")
	assert_not_null(tex, "the PNG inside the zip, as a texture")
	if tex != null:
		assert_eq(tex.get_width(), 4)
		assert_eq(tex.get_height(), 6)
	var meta := GameSkin.metadata("zz_pack_probe")
	assert_eq(int(meta.get("cols", 0)), 7, "the sidecar beside it")
	assert_null(GameSkin.texture("zz_not_in_the_zip"))


func test_the_pack_sits_after_the_players_own_folder_and_before_a_checkout() -> void:
	GameSkin.pack_mounted = true
	var dirs := GameSkin.search_dirs()
	assert_eq(dirs[0], GameSkin.SEARCH_DIRS[0], "user://original_skin first")
	assert_eq(dirs[dirs.size() - 1], GameSkin.SEARCH_DIRS[1], "res://assets/original last")
	assert_lt(dirs.find(GameSkin.PACK_DIR), dirs.size() - 1)
	GameSkin.pack_mounted = false
	assert_does_not_have(GameSkin.search_dirs(), GameSkin.PACK_DIR,
		"invisible until a pack is mounted")


func test_the_mounted_pack_supplies_portraits() -> void:
	assert_true(SkinPack.mount(GOOD, true))
	assert_has(PortraitLibrary.portable_dirs(), GameSkin.PACK_DIR.path_join("portraits"))
	PortraitLibrary.refresh()
	var ids := PackedStringArray()
	for face in PortraitLibrary.all():
		ids.append(String(face["id"]))
	assert_has(ids, "zz_probe_face", "the portrait inside the zip is in the chooser")
	GameSkin.pack_mounted = false
	assert_does_not_have(PortraitLibrary.portable_dirs(), GameSkin.PACK_DIR.path_join("portraits"))


func test_the_mounted_pack_is_searched_for_music() -> void:
	GameSkin.pack_mounted = true
	assert_has(MusicLibrary._search_dirs(), GameSkin.PACK_DIR.path_join("music"))
	GameSkin.pack_mounted = false
	assert_does_not_have(MusicLibrary._search_dirs(), GameSkin.PACK_DIR.path_join("music"))


func test_a_zip_that_is_not_a_skin_does_not_mount() -> void:
	var before := SkinPack.mounted.size()
	assert_false(SkinPack.mount(OUTSIDE, true))
	assert_false(SkinPack.mount(NOT_A_ZIP, true))
	assert_eq(SkinPack.mounted.size(), before)


# ------------------------------------------------------------- the drop --

func test_a_dropped_zip_is_kept_as_the_players_own_and_mounted() -> void:
	# The arrival plan reads the tree's current scene, and an earlier suite
	# may have left the title there (a "back" button on the setup or
	# options screen changes to main.tscn for the rest of the run). Pin
	# the scene to a stand-in, so this is "any other screen" every time.
	var was := get_tree().current_scene
	var elsewhere := Node.new()
	get_tree().root.add_child(elsewhere)
	get_tree().current_scene = elsewhere
	SkinPack._on_files_dropped(PackedStringArray([
		ProjectSettings.globalize_path(SCRATCH + "/notes.txt"),
		ProjectSettings.globalize_path(GOOD)]))
	assert_true(FileAccess.file_exists(SkinPack.USER_ZIP), "copied where the player's zip lives")
	assert_has(SkinPack.mounted, SkinPack.USER_ZIP)
	assert_true(GameSkin.pack_mounted)
	assert_not_null(SkinPack.notice(), "off the title screen, the game offers a restart")
	var later := SkinPack.notice().find_child("Later", true, false) as Button
	assert_not_null(later)
	if later != null:
		later.pressed.emit()
	assert_null(SkinPack.notice(), "Later takes the notice down")
	get_tree().current_scene = was
	elsewhere.queue_free()


func test_a_dropped_zip_that_is_not_a_skin_is_refused_and_said_so() -> void:
	SkinPack._on_files_dropped(PackedStringArray([ProjectSettings.globalize_path(OUTSIDE)]))
	assert_false(FileAccess.file_exists(SkinPack.USER_ZIP), "nothing kept")
	assert_not_null(SkinPack.notice(), "and the player is told")
	var ok := SkinPack.notice().find_child("Later", true, false) as Button
	assert_not_null(ok)
	if ok != null:
		assert_eq(ok.text, "OK")
		assert_null(SkinPack.notice().find_child("Restart", true, false),
			"no restart offered for a refused zip")


func test_a_drop_without_a_zip_does_nothing() -> void:
	SkinPack._on_files_dropped(PackedStringArray([
		ProjectSettings.globalize_path(SCRATCH + "/notes.txt")]))
	assert_false(FileAccess.file_exists(SkinPack.USER_ZIP))
	assert_null(SkinPack.notice())


# ------------------------------------------------------------ the browser --

func test_the_browser_looks_beside_its_page() -> void:
	assert_eq(SkinPack.pack_url("http://localhost:8000/"),
		"http://localhost:8000/skin/original_skin.zip")
	assert_eq(SkinPack.pack_url("http://localhost:8000/index.html"),
		"http://localhost:8000/skin/original_skin.zip")
	assert_eq(SkinPack.pack_url("https://b0realis.github.io/shandalar/index.html?v=3#top"),
		"https://b0realis.github.io/shandalar/skin/original_skin.zip")
	assert_eq(SkinPack.pack_url("https://example.org/play/"),
		"https://example.org/play/skin/original_skin.zip")


func test_the_fetch_progress_is_unknown_when_nothing_is_in_flight() -> void:
	assert_eq(SkinPack.fetch_progress(), -1.0)
	assert_false(SkinPack.fetching)


func test_the_shipped_zip_has_no_place_under_the_editor() -> void:
	assert_eq(SkinPack.portable_zip(), "", "no executable to be beside")


func test_the_title_is_rebuilt_and_any_other_screen_offered_a_restart() -> void:
	assert_eq(SkinPack.plan_after_arrival(SkinPack.TITLE_SCENE), "reload")
	assert_eq(SkinPack.plan_after_arrival("res://game/duel/duel_screen.tscn"), "restart")
	assert_eq(SkinPack.plan_after_arrival(""), "restart")
