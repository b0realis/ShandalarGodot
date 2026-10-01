extends GutTest
## THE PLAYER'S OWN FACE — where it is looked for and what it is called.
##
## [PortraitLibrary] is the one place that knows the four folders a
## portrait can live in and the order they beat each other in. These pin
## that order, the naming rule the README promises, and the two states
## that are easy to get wrong: no folder at all, and a folder holding
## things that are not portraits.
##
## THE FOURTH FOLDER IS OURS (2026-10-01): `game/art/portraits/`, the
## faces this project ships, read through the import pipeline because an
## exported pack has no file to open. The tests at the foot hold it to
## the inventory `game/art/README.md` keeps — zero rows, zero faces; a
## row each, a face each — so they say the same thing on the day the
## folder is empty and on the day it is not.

const PLAYER_DIR := "user://portraits"
const SHIPPED_DIR := PortraitLibrary.SHIPPED_DIR
const ART_README := "res://game/art/README.md"

var _made: Array[String] = []


func before_each() -> void:
	# Only the player's own folder, so a machine WITH the 1997 faces
	# imported tests the same thing as one without (the seam's whole
	# purpose — see PortraitLibrary.dirs).
	PortraitLibrary.dirs = [PLAYER_DIR]
	PortraitLibrary.refresh()


func after_each() -> void:
	PortraitLibrary.dirs = PortraitLibrary.default_dirs()
	for path in _made:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made = []
	PortraitLibrary.refresh()


func _write(name: String, w := 8, h := 8) -> void:
	PortraitLibrary.ensure_folder()
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.4, 0.2, 0.6))
	var path := PLAYER_DIR.path_join(name)
	image.save_png(ProjectSettings.globalize_path(path))
	_made.append(path)
	PortraitLibrary.refresh()


func test_the_folder_explains_itself() -> void:
	var where := PortraitLibrary.ensure_folder()
	assert_true(DirAccess.dir_exists_absolute(where), "the folder exists")
	var readme := PLAYER_DIR.path_join(PortraitLibrary.README_NAME)
	assert_true(FileAccess.file_exists(readme),
		"and a player who opens it is told what to put there")
	var text := FileAccess.get_file_as_string(readme)
	assert_string_contains(text, "PNG")
	assert_string_contains(text, "Grey Wizard", "the naming rule, by example")


func test_a_file_name_becomes_the_name_under_the_portrait() -> void:
	assert_eq(PortraitLibrary.title_of("grey_wizard"), "Grey Wizard")
	assert_eq(PortraitLibrary.title_of("Sisay-the-Bold"), "Sisay The Bold")
	assert_eq(PortraitLibrary.title_of("ego_f"), "Ego F")


func test_a_dropped_in_portrait_is_found_and_named() -> void:
	_write("grey_wizard.png")
	var ids: Array[String] = []
	for entry in PortraitLibrary.all():
		ids.append(String(entry["id"]))
	assert_true(ids.has("grey_wizard"), "found in the player's own folder")
	for entry in PortraitLibrary.all():
		if entry["id"] == "grey_wizard":
			assert_eq(entry["name"], "Grey Wizard")


func test_the_readme_is_not_a_portrait_and_neither_is_a_stray_file() -> void:
	_write("grey_wizard.png")          # one real face to find...
	var junk := PLAYER_DIR.path_join("notes.txt")
	var file := FileAccess.open(junk, FileAccess.WRITE)
	file.store_string("not a face")
	file.close()
	_made.append(junk)
	PortraitLibrary.refresh()
	var ids: Array[String] = []
	for entry in PortraitLibrary.all():
		ids.append(String(entry["id"]))
	assert_true(ids.has("grey_wizard"), "...the face is found")
	assert_false(ids.has("notes"), "a .txt is not a portrait")
	assert_false(ids.has("README"), "nor is the README the game wrote")


func test_the_list_is_alphabetical_and_stable() -> void:
	_write("zeta_mage.png")
	_write("alpha_mage.png")
	var names: Array[String] = []
	for entry in PortraitLibrary.all():
		names.append(String(entry["name"]))
	var sorted := names.duplicate()
	sorted.sort()
	assert_eq(names, sorted, "a new portrait never reshuffles the others")


func test_a_portrait_loads_as_a_texture_by_its_id_not_its_index() -> void:
	_write("grey_wizard.png", 12, 16)
	var art := PortraitLibrary.texture("grey_wizard")
	assert_not_null(art, "the file is read as bytes, not as a resource")
	assert_eq(Vector2i(art.get_width(), art.get_height()), Vector2i(12, 16))
	assert_null(PortraitLibrary.texture("nobody_by_that_name"))


func test_the_players_own_folder_outranks_an_imported_face() -> void:
	# Same id in two folders: the one the player put there wins, which is
	# what makes "drop in your own version" work.
	assert_eq(PortraitLibrary.DEFAULT_DIRS[0], PLAYER_DIR,
		"the player's folder is searched first")
	assert_eq(PortraitLibrary.DEFAULT_DIRS.size(), 4,
		"player, imported skin, dev checkout, shipped")
	# The player's settings move the first two (Options > Skin names the
	# keys); with none written the search is the built-in one.
	if not Settings.has_value(GamePaths.KEY_PORTRAITS) \
			and not Settings.has_value(GamePaths.KEY_SKIN_FOLDER):
		assert_eq(PortraitLibrary.default_dirs(), PortraitLibrary.DEFAULT_DIRS)


func test_a_portable_build_looks_beside_its_own_executable() -> void:
	# A build on somebody else's machine has no user://original_skin and
	# no res://assets in its pack, so `skin/` and `portraits/` beside the
	# executable are searched too — that is what makes an unzip-and-run
	# package possible at all.
	assert_eq(GameSkin.portable_dir(), "",
		"in the editor there is nothing beside the executable but Godot")
	assert_eq(PortraitLibrary.portable_dirs(), [] as Array[String])
	# The order is the contract: the player's own folder still wins.
	assert_eq(GameSkin.search_dirs()[0], GamePaths.skin_folder())
	assert_eq(GameSkin.SEARCH_DIRS.size(), 2, "and res:// is still last")


# ------------------------------------------------------ the shipped faces --

## The `portraits/x.png` rows of `game/art/README.md`, as ids — the
## inventory the art test holds the folder to, read here so the chooser
## is held to the same list.
func _inventoried_ids() -> Array[String]:
	var out: Array[String] = []
	for line in FileAccess.get_file_as_string(ART_README).split("\n"):
		if not line.begins_with("| `portraits/"):
			continue
		var name := String(line.split("|")[1]).strip_edges() \
			.trim_prefix("`").trim_suffix("`")
		if name.ends_with(".png"):
			out.append(name.trim_prefix("portraits/").trim_suffix(".png"))
	out.sort()
	return out


func test_the_shipped_faces_are_searched_last_so_anything_the_player_has_wins() -> void:
	# Ours is a floor, not a ceiling: the same id in the player's folder,
	# in their 1997 import or in a checkout beats the one we ship.
	assert_eq(PortraitLibrary.DEFAULT_DIRS[3], SHIPPED_DIR, "the built-in order")
	assert_eq(PortraitLibrary.default_dirs()[3], SHIPPED_DIR,
		"…and the one the player's keys cannot move")
	assert_true(SHIPPED_DIR.begins_with(GameSkin.OUR_ART_DIR + "/"),
		"inside the folder the art inventory sweeps")
	assert_true(PortraitLibrary.is_shipped(SHIPPED_DIR.path_join("x.png")))
	assert_false(PortraitLibrary.is_shipped(PLAYER_DIR.path_join("x.png")))


func test_the_shipped_faces_are_exactly_the_ones_the_inventory_names() -> void:
	PortraitLibrary.dirs = [SHIPPED_DIR]
	PortraitLibrary.refresh()
	var ids: Array[String] = []
	for entry in PortraitLibrary.all():
		ids.append(String(entry["id"]))
		assert_true(PortraitLibrary.is_shipped(String(entry["path"])),
			"%s is found at its shipped path" % entry["id"])
	ids.sort()
	assert_eq(ids, _inventoried_ids(),
		"game/art/README.md names every shipped face and nothing else")
	assert_eq(PortraitLibrary.shipped_count(), ids.size())


func test_a_shipped_face_loads_through_the_import_pipeline() -> void:
	# `load`, not `Image.load_from_file` — in an exported pack the bytes
	# are not at the path, only the imported texture is. In a checkout
	# both ways work, so the assertion that matters is the accessor:
	# the texture IS the one `GameSkin.our_art` hands out.
	PortraitLibrary.dirs = [SHIPPED_DIR]
	PortraitLibrary.refresh()
	var ids := _inventoried_ids()
	if ids.is_empty():
		pass_test("no shipped faces yet — nothing to load")
		return
	for id in ids:
		var art := PortraitLibrary.texture(id)
		assert_not_null(art, "%s loads" % id)
		assert_eq(art, GameSkin.our_art("portraits/%s" % id),
			"%s: the same texture the rest of the shipped art is" % id)
		if art != null:
			assert_gt(art.get_width(), 0, "%s is a picture" % id)


func test_the_players_own_file_outranks_a_shipped_face() -> void:
	var ids := _inventoried_ids()
	if ids.is_empty():
		pass_test("no shipped faces yet — nothing to outrank")
		return
	PortraitLibrary.dirs = [PLAYER_DIR, SHIPPED_DIR]
	_write("%s.png" % ids[0])
	var seen := 0
	for entry in PortraitLibrary.all():
		if entry["id"] != ids[0]:
			continue
		seen += 1
		assert_true(String(entry["path"]).begins_with(PLAYER_DIR),
			"the player's %s wins over the shipped one" % ids[0])
	assert_eq(seen, 1, "and it is listed once")
	# Read as bytes, then: the player's file, not our texture.
	var art := PortraitLibrary.texture(ids[0])
	assert_not_null(art)
	if art != null:
		assert_eq(art.get_width(), 8, "the 8x8 the test wrote, not ours")


func test_an_exported_pack_lists_the_sidecar_and_the_fold_names_the_file() -> void:
	# What an exported build sees in the shipped folder: `x.png.import`
	# and no `x.png`. The listing folds the sidecar back to the file and
	# counts a file that has both once. Staged in the player's folder,
	# where the test may write; the rule is the same for every folder.
	_write("face.png")
	var sidecar := PLAYER_DIR.path_join("face.png.import")
	var file := FileAccess.open(sidecar, FileAccess.WRITE)
	file.store_string("[remap]\n")
	file.close()
	_made.append(sidecar)
	var alone := PLAYER_DIR.path_join("ghost.png.import")
	file = FileAccess.open(alone, FileAccess.WRITE)
	file.store_string("[remap]\n")
	file.close()
	_made.append(alone)
	PortraitLibrary.refresh()
	var ids: Array[String] = []
	for entry in PortraitLibrary.all():
		ids.append(String(entry["id"]))
	assert_eq(ids, ["face", "ghost"] as Array[String],
		"the sidecar stands for its file; the pair is one face")
	assert_eq(PortraitLibrary.own_count(), 2)
