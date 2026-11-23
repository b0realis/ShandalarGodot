extends GutTest
## IS A SKIN WORN RIGHT NOW? — [method GameSkin.is_worn] (builders
## 2026-11-23), for the title's no-skin notice. [method GameSkin.is_present]
## cannot say: a skin folder holding nothing but `SKIN.txt` is "present".
## The question is asked of a scratch skin folder; a development checkout's
## own `assets/original` is searched after it whatever the test does, so
## where that holds a skin the answer is yes throughout, and the first
## test says which machine it ran on.

const SCRATCH := "user://test_c1123_skin_worn"
const KEYS: Array[String] = [GamePaths.KEY_SKIN_FOLDER, GamePaths.KEY_USE_SKIN_FOLDER]

var _saved := {}
var _was_worn := false
var _was_mounted := false


func before_each() -> void:
	_was_worn = GameSkin.zip_worn
	_was_mounted = GameSkin.pack_mounted
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	_empty()
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SCRATCH)
	GameSkin.zip_worn = false
	GameSkin.pack_mounted = false
	GameSkin.clear_caches()


func after_each() -> void:
	for key: String in _saved:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	GameSkin.zip_worn = _was_worn
	GameSkin.pack_mounted = _was_mounted
	GameSkin.clear_caches()
	_empty()


func _empty() -> void:
	var dir := DirAccess.open(SCRATCH)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


## Whether the checkout itself holds one of the landmark pictures.
func _checkout_wears_one() -> bool:
	for key in GameSkin.WORN_MARKS:
		for name: String in [key + ".png", GameSkin.scaled_path(key + ".png")]:
			if FileAccess.file_exists(ProjectSettings.globalize_path(
					String(GameSkin.SEARCH_DIRS[1]).path_join(name))):
				return true
	return false


func test_a_folder_with_only_the_catalogue_is_present_and_not_worn() -> void:
	var note := FileAccess.open(SCRATCH + "/SKIN.txt", FileAccess.WRITE)
	note.store_string("every file a skin may hold\n")
	note.close()
	assert_true(GameSkin.is_present(), "the folder is there")
	assert_eq(GameSkin.is_worn(), _checkout_wears_one(),
		"and dresses nothing: only a checkout's own skin can answer yes here")
	if not _checkout_wears_one():
		assert_false(GameSkin.is_worn(), "no skin on this machine: not worn")


func test_one_landmark_picture_is_a_skin_worn_title_or_not() -> void:
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.4, 0.3, 0.2))
	assert_eq(image.save_png(ProjectSettings.globalize_path(SCRATCH + "/panel_stone.png")), OK)
	GameSkin.clear_caches()
	assert_true(GameSkin.is_worn(), "a skin built from a copy with no Title.pic is still a skin")
	assert_true(GameSkin.is_kept("panel_stone") or GameSkin.is_kept(GameSkin.WORN_MARKS[0]),
		"what was read to answer is kept: asking again reads no file")


func test_the_landmarks_are_pictures_a_1997_skin_holds() -> void:
	assert_true(GameSkin.WORN_MARKS.has("title_background"))
	for key in GameSkin.WORN_MARKS:
		assert_true(SkinRecipes.MANIFEST.has(key), key)
		assert_false(SkinRecipes.NOT_READ.has(key), key)
