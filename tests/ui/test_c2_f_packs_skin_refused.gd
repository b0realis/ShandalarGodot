extends GutTest
## A SKIN ZIP THE GAME WILL NOT WEAR IS LEFT WHERE IT IS, AND WHY IS SAID
## (robustness campaign of 2026-10-12, r3-1). At every start [SkinPack]
## mounts the player's own skin zip — `user://skins/original_skin.zip`,
## or the one the `skin_zip` key names — and a zip it refused there was
## DELETED: a hand-made zip with one README beside its `skin/` folder, a
## copy cut short, a file the game may not read. The deletion was written
## for the browser, where that folder holds only what the game itself
## fetched or read in (a 404 page saved as a zip); on a desktop or a
## handheld it is the player's own file. What these pin:
##
##   1. On a desktop a refused zip in the skins folder stays; only a
##      browser's stored copy is the game's to clear.
##   2. The refusal is kept with its reason, said in words while the file
##      is there and not worn, and forgotten once the zip is worn.
##   3. A file the game may not open is said so, not "not a zip file".
##   4. Options > Skin shows the line, and re-reads it when a pack arrives.

const ZIP := "user://skins/c2_f_packs_refused.zip"
const LOCKED := "user://skins/c2_f_packs_locked.zip"

var screen: Control


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://skins"))


func after_each() -> void:
	for path in [ZIP, LOCKED]:
		if FileAccess.file_exists(path):
			FileAccess.set_unix_permissions(path, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
				| FileAccess.UNIX_READ_GROUP | FileAccess.UNIX_READ_OTHER)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		SkinPack.refused.erase(path)


## A zip made by hand: the skin's files, and a README beside the folder.
func _hand_made(path: String) -> void:
	var packer := ZIPPacker.new()
	assert_eq(packer.open(ProjectSettings.globalize_path(path)), OK)
	packer.start_file("README.txt")
	packer.write_file("my own skin, made by hand\n".to_utf8_buffer())
	packer.close_file()
	packer.start_file("skin/misc/panel.bmp")
	packer.write_file(PackedByteArray([1, 2, 3, 4]))
	packer.close_file()
	packer.close()


# 1. Kept.

func test_a_refused_zip_in_the_skins_folder_is_kept_on_a_desktop() -> void:
	_hand_made(ZIP)
	assert_false(bool(SkinPack.inspect(ZIP)["ok"]), "refused: an entry outside skin/")
	SkinPack._mount_if_present(ZIP, false)
	assert_true(FileAccess.file_exists(ZIP), "the player's own zip is still there")
	assert_false(SkinPack.mounted.has(ZIP), "and not worn")


func test_only_a_browsers_stored_copy_is_the_games_to_clear() -> void:
	assert_false(SkinPack.refused_zip_is_disposable(SkinPack.USER_ZIP, false),
		"a desktop: the skins folder is the player's")
	assert_false(SkinPack.refused_zip_is_disposable(ZIP, false))
	assert_true(SkinPack.refused_zip_is_disposable(SkinPack.USER_ZIP, true),
		"a browser: what is stored there was fetched or read in by the game")
	assert_false(SkinPack.refused_zip_is_disposable(
		GamePaths.cardpacks_folder().path_join("cardart.zip"), true),
		"never a zip outside the skins folder")


# 2. Said.

func test_the_reason_is_kept_and_said_while_the_zip_is_there() -> void:
	_hand_made(ZIP)
	SkinPack._mount_if_present(ZIP, false)
	assert_string_contains(String(SkinPack.refused.get(ZIP, "")), "README.txt",
		"the reason, kept by path")
	var said := "\n".join(SkinPack.refusal_lines())
	assert_string_contains(said, GamePaths.shown(ZIP), "the line names the file the player can open")
	assert_string_contains(said, "an entry outside skin/: README.txt", "and why")
	assert_string_contains(said, "Not worn", said)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ZIP))
	assert_false("\n".join(SkinPack.refusal_lines()).contains(GamePaths.shown(ZIP)),
		"a zip the player has since removed is not talked about")


func test_a_zip_worn_after_all_is_no_longer_refused() -> void:
	SkinPack.refused[ZIP] = "an entry outside skin/: README.txt"
	var packer := ZIPPacker.new()
	assert_eq(packer.open(ProjectSettings.globalize_path(ZIP)), OK)
	packer.start_file("skin/zz_c2_f_packs_probe.json")
	packer.write_file('{"cols": 1}'.to_utf8_buffer())
	packer.close_file()
	packer.close()
	var was := GameSkin.pack_mounted
	var worn := GameSkin.zip_worn
	assert_true(SkinPack.mount(ZIP, false), "the repaired zip mounts")
	GameSkin.pack_mounted = was
	GameSkin.zip_worn = worn
	assert_false(SkinPack.refused.has(ZIP), "and is no longer said to be refused")
	assert_false("\n".join(SkinPack.refusal_lines()).contains(GamePaths.shown(ZIP)))
	SkinPack.mounted.erase(ZIP)
	SkinPack._reports.erase(ZIP)


# 3. A file the game may not open.

func test_a_zip_the_game_may_not_read_is_said_so() -> void:
	_hand_made(LOCKED)
	FileAccess.set_unix_permissions(LOCKED, 0)
	if FileAccess.open(LOCKED, FileAccess.READ) != null:
		pass_test("this account reads any file (root?): nothing to check")
		return
	var why := String(SkinPack.inspect(LOCKED)["why"])
	assert_string_contains(why, "may not read", why)
	SkinPack._mount_if_present(LOCKED, false)
	assert_true(FileAccess.file_exists(LOCKED), "kept")
	assert_string_contains("\n".join(SkinPack.refusal_lines()), "may not read")


# 4. Options > Skin.

func test_options_shows_the_line_and_re_reads_it() -> void:
	_hand_made(ZIP)
	SkinPack._mount_if_present(ZIP, false)
	screen = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var line := screen.find_child("SkinRefused", true, false) as Label
	assert_not_null(line, "a line under the skin row")
	if line == null:
		return
	assert_true(line.visible)
	assert_string_contains(line.text, GamePaths.shown(ZIP))
	assert_string_contains(line.text, "README.txt")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ZIP))
	SkinPack.changed.emit("skin")
	assert_false(line.text.contains(GamePaths.shown(ZIP)), "re-read when the skins change: " + line.text)


func test_with_nothing_refused_the_line_is_hidden() -> void:
	var kept := SkinPack.refused.duplicate()
	SkinPack.refused.clear()
	screen = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var line := screen.find_child("SkinRefused", true, false) as Label
	assert_not_null(line)
	if line != null:
		assert_false(line.visible, "no empty line in the list")
	SkinPack.refused = kept
