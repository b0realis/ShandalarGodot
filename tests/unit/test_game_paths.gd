extends GutTest
## `[QoL]` THE PLAYER'S PLACES — [GamePaths]: six keys in
## `user://settings.cfg` that move the skin zip, the skin folder, the
## card folder, the portraits folder and the music folder, none of them
## ever written by the game as a default. The owner, 2026-09-08: *"the
## default folder location should be shown in settings but can also be
## changed in cfg"*.

## Remembered and put back — never written back as a default.
const KEYS: Array[String] = [GamePaths.KEY_SKIN_ZIP, GamePaths.KEY_USE_SKIN_FOLDER,
	GamePaths.KEY_SKIN_FOLDER, GamePaths.KEY_CARDPACKS, GamePaths.KEY_PORTRAITS,
	GamePaths.KEY_MUSIC]

var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)


func after_each() -> void:
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])


func test_the_built_in_places_when_no_key_is_written() -> void:
	assert_eq(GamePaths.skin_zip(), "", "the game's own pick")
	assert_false(GamePaths.use_skin_folder())
	assert_eq(GamePaths.skin_folder(), "user://original_skin")
	assert_eq(GamePaths.cardpacks_folder(), "user://cardpacks")
	assert_eq(GamePaths.portraits_folder(), "user://portraits")
	assert_eq(GamePaths.music_folder(), "user://music")
	for key in KEYS:
		assert_false(Settings.has_value(key), "reading %s leaves no trace" % key)


func test_a_key_moves_its_place() -> void:
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, "/srv/mtg/skin")
	Settings.set_value(GamePaths.KEY_CARDPACKS, "/srv/mtg/packs/")
	Settings.set_value(GamePaths.KEY_PORTRAITS, "  user://faces  ")
	Settings.set_value(GamePaths.KEY_MUSIC, "~/Music/shandalar")
	Settings.set_value(GamePaths.KEY_SKIN_ZIP, "~/skins/mine.zip")
	assert_eq(GamePaths.skin_folder(), "/srv/mtg/skin")
	assert_eq(GamePaths.cardpacks_folder(), "/srv/mtg/packs", "a trailing slash dropped")
	assert_eq(GamePaths.portraits_folder(), "user://faces", "edges trimmed")
	var home := OS.get_environment("HOME")
	assert_eq(GamePaths.music_folder(), home + "/Music/shandalar", "~ is the home folder")
	assert_eq(GamePaths.skin_zip(), home + "/skins/mine.zip")


func test_an_empty_or_wrong_typed_key_is_the_built_in_place() -> void:
	Settings.set_value(GamePaths.KEY_MUSIC, "")
	assert_eq(GamePaths.music_folder(), "user://music")
	Settings.set_value(GamePaths.KEY_MUSIC, "   ")
	assert_eq(GamePaths.music_folder(), "user://music")
	Settings.set_value(GamePaths.KEY_PORTRAITS, 42)
	assert_eq(GamePaths.portraits_folder(), "user://portraits", "a number is not a path")
	Settings.set_value(GamePaths.KEY_SKIN_ZIP, false)
	assert_eq(GamePaths.skin_zip(), "")
	Settings.set_value(GamePaths.KEY_CARDPACKS, "/")
	assert_eq(GamePaths.cardpacks_folder(), "/", "the root keeps its one slash")


func test_the_folder_switch_is_a_key_written_only_when_moved() -> void:
	GamePaths.set_use_skin_folder(true)
	assert_true(GamePaths.use_skin_folder())
	assert_true(Settings.has_value(GamePaths.KEY_USE_SKIN_FOLDER))
	GamePaths.set_use_skin_folder(false)
	assert_false(GamePaths.use_skin_folder())
	Settings.set_value(GamePaths.KEY_USE_SKIN_FOLDER, "yes")
	assert_true(GamePaths.use_skin_folder(), "a hand-typed non-empty string reads as on")


func test_expand_touches_only_a_leading_tilde() -> void:
	var home := OS.get_environment("HOME")
	assert_eq(GamePaths.expand("~"), home)
	assert_eq(GamePaths.expand("~/x"), home + "/x")
	assert_eq(GamePaths.expand("/a/~/b"), "/a/~/b")
	assert_eq(GamePaths.expand("~user/x"), "~user/x", "somebody else's home is not guessed")
	assert_eq(GamePaths.expand("user://x"), "user://x")


func test_a_place_is_shown_as_a_path_a_human_can_open() -> void:
	assert_eq(GamePaths.shown(""), "")
	assert_eq(GamePaths.shown("/srv/x"), "/srv/x")
	var home := OS.get_environment("HOME")
	assert_eq(GamePaths.shown(home + "/Music"), "~/Music", "the home folder as ~")
	assert_eq(GamePaths.shown(home), "~")
	assert_eq(GamePaths.shown(home + "sib/x"), home + "sib/x", "a sibling that shares the prefix is not home")
	var music := ProjectSettings.globalize_path("user://music")
	if music.begins_with(home + "/"):
		assert_eq(GamePaths.shown("user://music"), "~" + music.substr(home.length()))
	else:
		assert_eq(GamePaths.shown("user://music"), music)
	assert_true(GamePaths.settings_file().ends_with("/settings.cfg"))
	assert_eq(GamePaths.settings_file(), GamePaths.shown(Settings.PATH))


func test_only_the_games_own_home_is_its_to_empty() -> void:
	assert_true(GamePaths.is_own("user://cardpacks"))
	assert_true(GamePaths.is_own("user://skins/mine.zip"))
	assert_false(GamePaths.is_own("/home/somebody/cardpacks"))
	assert_false(GamePaths.is_own("res://assets/cardart"))
	assert_false(GamePaths.is_own(ProjectSettings.globalize_path("user://cardpacks")),
		"a globalised path is not recognised — the keys are compared as written")


func test_the_place_keys_are_the_ones_the_options_note_names() -> void:
	assert_eq(GamePaths.PLACE_KEYS, ["skin_zip", "skin_folder", "cardpacks_folder",
		"portraits_folder", "music_folder"] as Array[String])
	assert_false(GamePaths.KEY_USE_SKIN_FOLDER in GamePaths.PLACE_KEYS,
		"the switch has its own row; it is not a place")
