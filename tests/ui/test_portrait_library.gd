extends GutTest
## THE PLAYER'S OWN FACE — where it is looked for and what it is called.
##
## [PortraitLibrary] is the one place that knows the three folders a
## portrait can live in and the order they beat each other in. These pin
## that order, the naming rule the README promises, and the two states
## that are easy to get wrong: no folder at all, and a folder holding
## things that are not portraits.

const PLAYER_DIR := "user://portraits"

var _made: Array[String] = []


func before_each() -> void:
	# Only the player's own folder, so a machine WITH the 1997 faces
	# imported tests the same thing as one without (the seam's whole
	# purpose — see PortraitLibrary.dirs).
	PortraitLibrary.dirs = [PLAYER_DIR]
	PortraitLibrary.refresh()


func after_each() -> void:
	PortraitLibrary.dirs = PortraitLibrary.DEFAULT_DIRS.duplicate()
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
	assert_eq(PortraitLibrary.DEFAULT_DIRS.size(), 3,
		"player, imported skin, dev checkout")


func test_a_portable_build_looks_beside_its_own_executable() -> void:
	# A build on somebody else's machine has no user://original_skin and
	# no res://assets in its pack, so `skin/` and `portraits/` beside the
	# executable are searched too — that is what makes an unzip-and-run
	# package possible at all.
	assert_eq(GameSkin.portable_dir(), "",
		"in the editor there is nothing beside the executable but Godot")
	assert_eq(PortraitLibrary.portable_dirs(), [] as Array[String])
	# The order is the contract: the player's own folder still wins.
	assert_eq(GameSkin.search_dirs()[0], "user://original_skin")
	assert_eq(GameSkin.SEARCH_DIRS.size(), 2, "and res:// is still last")
