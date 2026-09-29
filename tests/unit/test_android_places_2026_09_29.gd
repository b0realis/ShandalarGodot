extends GutTest
## THE PLAYER'S PLACES ON ANDROID — `GamePaths.android_files_dir`,
## `GamePaths.player_place`, `GameSkin.portable_dir_for`,
## `Settings.handheld` (2026-09-29, the Meta Quest panel build).
##
## On Android `user://` is the app's private folder: nothing outside the
## app can write into it, so a card zip could never reach the card
## folder. The three folders the player fills — cards, portraits, music
## — and the `skin/` corner therefore sit in the app's shared-storage
## folder, `/sdcard/Android/data/com.b0realis.shandalar/files`, where
## `adb push` writes and the app reads without a permission. What these
## pin:
##
##   1. Off Android the corner is "" and every default is exactly the
##      `user://` place it always was — nothing moves on a desk.
##   2. With a corner, the pure mapping puts `user://cardpacks` at
##      `<corner>/cardpacks` (and so on), leaves a non-`user://` value
##      alone, and tolerates a trailing slash on the corner.
##   3. The skin corner is `<corner>/skin` — the play copy's layout —
##      and beside the executable where there is no corner.
##   4. A written key still wins: the corner is only the default.
##   5. `Settings.handheld` is the launcher's word first, `android` only
##      on an Android build, and "" on a desk.
##   6. The Android back gesture is an Escape press and release, not a
##      quit (`Lifecycle._notification`, `quit_on_go_back` off).

const CORNER := "/storage/emulated/0/Android/data/com.b0realis.shandalar/files"
const KEYS: Array[String] = [GamePaths.KEY_CARDPACKS, GamePaths.KEY_PORTRAITS,
	GamePaths.KEY_MUSIC]

var _saved: Dictionary = {}
var _had_env := false
var _env := ""


func before_each() -> void:
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	_had_env = OS.has_environment(Settings.HANDHELD_ENV)
	_env = OS.get_environment(Settings.HANDHELD_ENV) if _had_env else ""
	OS.unset_environment(Settings.HANDHELD_ENV)


func after_each() -> void:
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	if _had_env:
		OS.set_environment(Settings.HANDHELD_ENV, _env)
	else:
		OS.unset_environment(Settings.HANDHELD_ENV)


func test_off_android_there_is_no_corner_and_nothing_moves() -> void:
	assert_false(OS.has_feature("android"), "this suite runs on a desk")
	assert_eq(GamePaths.android_files_dir(), "")
	assert_eq(GamePaths.cardpacks_folder(), GamePaths.DEFAULT_CARDPACKS)
	assert_eq(GamePaths.portraits_folder(), GamePaths.DEFAULT_PORTRAITS)
	assert_eq(GamePaths.music_folder(), GamePaths.DEFAULT_MUSIC)
	for key in KEYS:
		assert_false(Settings.has_value(key), "reading %s leaves no trace" % key)


func test_the_pure_mapping_puts_a_user_place_under_the_corner() -> void:
	assert_eq(GamePaths.player_place("user://cardpacks", CORNER), CORNER + "/cardpacks")
	assert_eq(GamePaths.player_place("user://portraits", CORNER), CORNER + "/portraits")
	assert_eq(GamePaths.player_place("user://music", CORNER + "/"), CORNER + "/music",
		"a trailing slash on the corner is tolerated")
	assert_eq(GamePaths.player_place("user://cardpacks", ""), "user://cardpacks",
		"no corner: the user:// place itself")
	assert_eq(GamePaths.player_place("/srv/mtg/packs", CORNER), "/srv/mtg/packs",
		"a place that is not user:// is left alone")
	assert_eq(GamePaths.player_place("res://assets", CORNER), "res://assets")


func test_the_skin_corner_is_the_play_copys_layout() -> void:
	assert_eq(GameSkin.portable_dir_for(CORNER), CORNER + "/skin")
	assert_eq(GameSkin.portable_dir_for(CORNER + "/"), CORNER + "/skin")
	var beside := GamePaths.executable_dir(OS.get_executable_path(),
		OS.has_feature("macos")).path_join("skin")
	assert_eq(GameSkin.portable_dir_for(""), beside, "no corner: beside the executable")
	assert_eq(GameSkin.portable_dir(), "", "the editor has no portable copy at all")


func test_a_written_key_still_wins_over_the_default() -> void:
	Settings.set_value(GamePaths.KEY_CARDPACKS, "/srv/mtg/packs/")
	assert_eq(GamePaths.cardpacks_folder(), "/srv/mtg/packs")
	assert_eq(GamePaths.portraits_folder(), GamePaths.DEFAULT_PORTRAITS, "the others untouched")


func test_the_handheld_word_is_the_launchers_first_and_android_only_there() -> void:
	assert_eq(Settings.handheld(), "", "a desk with no launcher")
	assert_eq(Settings.ANDROID_HANDHELD, "android")
	OS.set_environment(Settings.HANDHELD_ENV, " steam-deck ")
	assert_eq(Settings.handheld(), "steam-deck", "the launcher's word, trimmed")
	OS.unset_environment(Settings.HANDHELD_ENV)
	assert_eq(Settings.handheld(), "")
	# The Android word comes from the build feature alone; a desk cannot
	# fake it, and the defaults it unlocks are the Deck's three.
	for key in ["fullscreen", "fullscreen_cards", "power_saver"]:
		assert_true(Settings.HANDHELD_DEFAULTS.has(key))


## A key seen by the tree, the way a screen would see it.
class KeyWatch extends Node:
	var keys: Array[InputEventKey] = []
	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			keys.append(event)


func test_the_android_back_gesture_is_an_escape_press_and_release() -> void:
	assert_false(bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)),
		"the engine must not quit on the gesture")
	var watch := KeyWatch.new()
	add_child_autofree(watch)
	Lifecycle.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	await get_tree().process_frame
	var escapes := watch.keys.filter(func(k: InputEventKey) -> bool: return k.keycode == KEY_ESCAPE)
	assert_eq(escapes.size(), 2, "one press and one release")
	if escapes.size() == 2:
		assert_true(escapes[0].pressed, "the press first")
		assert_false(escapes[1].pressed, "then the release")
	assert_true(is_instance_valid(get_tree()), "the tree is still here")
