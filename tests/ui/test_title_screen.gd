extends GutTest
## THE FRONT DOOR — the boot splash and the title screen's bed. Both come
## from the owner's playtest of 2026-09-04:
##
##   *"Play a suitable soothing music at the main menu."*
##   *"Splash screen could be a bit longer."*
##
## **WHAT THE 1997 SHELL PLAYED, because that was the first question.**
## Nothing. The original's shell is `Magic.exe`'s own window class
## (`wndproc_MagicShellClass`, `shandalar-src/src/Magic-trace.c:4124`,
## entry `4CC770`); it loads `\ShellArt` and the five `@SHELLSCREEN_*`
## pages, and its whole audio vocabulary is the 68-entry ONE-SHOT table at
## `shandalar-src/src/functions/windows.c:1181-1266`. The only shell
## entries in it are seven cues (`defs.h:2232-2252`), of which the five
## page cues measure 2.8-6.1 s — stingers, one per page, not a bed. Every
## looping-bed literal in the original (`x:sound\dueltune.wav`,
## `x:sound\locmus0..19.wav`, `x:sound\tmplmus1.wav`,
## `x:sound\[bgruw]castle.wav`) lives in `Shandalar.exe`, the ADVENTURE.
## So the shell's music is `[QoL]` and the bed is ours to choose;
## `MainScreen.MENU_BEDS` carries the measurements it was chosen on.
##
## THE MUSIC SEAMS are [MusicLibrary]'s own `dirs` / `skin_dirs`, pointed
## at scratch folders exactly as `tests/ui/test_options_music.gd` and
## `tests/ui/test_deck_sound.gd` point them: otherwise this file would
## test one thing on a machine that has the 1997 `Sound/` folder imported
## and a different thing on a machine that has not.

const PLAYER_DIR := "user://test_title_music_player"
const SKIN_DIR := "user://test_title_music_skin"

## The route taken for the splash, pinned as a number: Godot 4.7 has
## `application/boot_splash/minimum_display_time` (an int in ms), so there
## is NO splash scene and the title screen is still the first thing that
## runs. Measured on this project under Xvfb with `--quit-after 3`: the
## wait is added to the engine's ~1.0 s start, so 0 ms reaches the game in
## 1.5 s, 1000 ms in 2.0 s, 1500 ms in 2.5 s and 2000 ms in 3.0 s.
const SPLASH_MS := 1000
## The owner's ceiling — *"Do not make the game slower to reach than about
## two seconds"* — expressed in the setting's own units, given the ~1.0 s
## of engine start the wait is added to.
const SPLASH_MS_CEILING := 1000

var screen: Control
var _made: Array[String] = []
var _saved: Dictionary = {}


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_saved = {}
	_made = []
	MusicLibrary.dirs = [PLAYER_DIR]
	MusicLibrary.skin_dirs = [SKIN_DIR]
	MusicLibrary.refresh()
	MusicPlayer.reset_order()


func after_each() -> void:
	for path in _made:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made = []
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PLAYER_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SKIN_DIR))
	MusicLibrary.dirs = ["user://music"]
	MusicLibrary.skin_dirs = null
	MusicLibrary.refresh()
	MusicPlayer.reset_order()
	for key in _saved:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])


## Snapshot the player's own value before a test writes the key.
func _touch(key: String) -> void:
	if _saved.has(key):
		return
	_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null


## …and take it out of the file, for a test that reads a shipped default.
## The player's own `user://settings.cfg` must never decide what a test of
## a DEFAULT sees (`tests/ui/test_duel_options.gd`, `_unset`).
func _unset(key: String) -> void:
	_touch(key)
	Settings.clear_value(key)


## The shell, built AFTER the library seams are in place — its `_ready`
## starts the bed, so a screen built first would have drawn from whatever
## music this machine happens to have imported.
func _build() -> Control:
	screen = load("res://game/main.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


## A real, minimal PCM wav — 22 050 Hz, mono, 16-bit, like every file the
## original ships. Written rather than copied: no original bytes travel
## with this suite. (Same fixture as `tests/ui/test_options_music.gd`.)
func _wav(frames: int) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)
	pcm.fill(0)
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_data("RIFF".to_ascii_buffer())
	buf.put_u32(36 + pcm.size())
	buf.put_data("WAVEfmt ".to_ascii_buffer())
	buf.put_u32(16)
	buf.put_16(1)
	buf.put_16(1)
	buf.put_u32(22050)
	buf.put_u32(44100)
	buf.put_16(2)
	buf.put_16(16)
	buf.put_data("data".to_ascii_buffer())
	buf.put_u32(pcm.size())
	buf.put_data(pcm)
	return buf.data_array


func _write(dir_path: String, name: String) -> String:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(dir_path))
	var path := dir_path.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(_wav(64))
	file.close()
	_made.append(path)
	MusicLibrary.refresh()
	return path


## The whole 1997 library, so a test sees the same choice the owner's
## machine would offer.
func _write_every_original_track() -> void:
	for row in MusicLibrary.ORIGINAL_TRACKS:
		_write(SKIN_DIR, String(row[0]) + ".wav")


# ================================================== 1. THE SHELL'S BED ==

func test_the_shell_asks_for_one_bed_and_loops_it() -> void:
	# THE WHOLE ITEM: *"Play a suitable soothing music at the main menu."*
	# One bed on repeat — `play_one`, not the front of a shuffle — and the
	# single track listed TWICE inside the playlist, which is what gives
	# the wrap a seam to crossfade instead of the click a patched loop
	# marker makes.
	_unset(MusicLibrary.SETTING)
	_unset("music_enabled")
	_write_every_original_track()
	await _build()
	assert_not_null(screen._music, "the screen holds its own player")
	screen._music.silent = false
	screen._apply_music_switch()
	assert_eq(screen._music.tracks.size(), 1, "one bed, not eight")
	assert_eq(screen._music.tracks[0], _first_bed(),
		"the bed MENU_BEDS names first")
	assert_eq(screen._music.key, screen._music.tracks[0],
		"…and it names it, so re-applying the switch does not restart it")
	var list := screen._music.stream as AudioStreamPlaylist
	assert_not_null(list, "an AudioStreamPlaylist, as every bed here is")
	assert_true(list.loop, "it LOOPS — a title screen is not ten seconds")
	assert_eq(list.get_stream_count(), 2,
		"the same stream twice, so the wrap has a seam")
	assert_gt(list.fade_time, 0.0, "and the seam is crossfaded, not butted")
	assert_false(list.shuffle, "our order, not the audio thread's")


func test_the_bed_is_a_measured_choice_and_one_line_to_change() -> void:
	# The pick is a judgement made WITHOUT hearing the music, so what is
	# pinned is that it is a deliberate, ordered list of real track ids
	# with the chosen one at the head — not "whatever the library returns
	# first", which is what a weaker test would allow back in.
	var beds := _beds()
	assert_gt(beds.size(), 1, "a first choice AND fallbacks behind it")
	assert_eq(beds[0], "music_location_15",
		"LocMus15: 0.06 transients/s over 36 s, 816 zero-crossings/s, "
		+ "8.3 dB of loudness spread and no frame under -50 dBFS — the "
		+ "calmest bed the Deck Builder does not already own")
	var ids := MusicLibrary.ids_of(_original_rows())
	for id in beds:
		assert_true(ids.has(id), "%s is a real track of the original" % id)
	assert_eq(beds.size(), _unique(beds).size(), "no id twice")


func test_the_shell_does_not_take_the_deck_builders_bed() -> void:
	# Sharing it would mean the same track restarting from zero every time
	# the player crossed between the two screens — a stutter, not
	# continuity. The Deck Builder walks LocMus1..19 and so takes LocMus1.
	_unset(MusicLibrary.SETTING)
	_write_every_original_track()
	var builder := MusicLibrary.single_for(MusicLibrary.deck_builder_beds())
	var shell := MusicLibrary.single_for(_beds())
	assert_eq(builder, "music_location_1", "the Deck Builder's own")
	assert_ne(shell, builder, "and the shell's is a different tune")


func test_the_same_bed_comes_back_every_time_the_shell_opens() -> void:
	# A title screen the player returns to a hundred times must sound like
	# the same place. A shuffle's first track would name nothing.
	_unset(MusicLibrary.SETTING)
	_write_every_original_track()
	var first := MusicLibrary.single_for(_beds())
	for _i in 12:
		assert_eq(MusicLibrary.single_for(_beds()), first,
			"stable across calls")


func test_the_options_choice_wins_over_the_shells_own_pick() -> void:
	# A player who picked ONE track under Options -> Music asked for that
	# track everywhere, the title screen included.
	_touch(MusicLibrary.SETTING)
	_unset("music_enabled")
	_write_every_original_track()
	_write(PLAYER_DIR, "windswept_march.wav")
	MusicLibrary.set_choice("windswept_march")
	await _build()
	screen._music.silent = false
	screen._apply_music_switch()
	assert_eq(screen._music.tracks, ["windswept_march"] as Array[String],
		"the player's own track, on the shell too")
	# …and the two "you choose" modes hand the decision back to MENU_BEDS.
	for mode in [MusicLibrary.CHOICE_SHUFFLE, MusicLibrary.CHOICE_ORIGINAL]:
		MusicLibrary.set_choice(mode)
		assert_eq(MusicLibrary.single_for(_beds()),
			_first_bed(), "%s leaves the bed to us" % mode)


func test_the_global_music_switch_silences_the_shell() -> void:
	# The shell has no screen-scoped switch of its own — the Deck
	# Builder's `deck_builder_music` is that screen's and must not reach
	# here — so the global `music_enabled` is the whole rule.
	_unset(MusicLibrary.SETTING)
	_touch("music_enabled")
	Settings.clear_value("music_enabled")
	_write_every_original_track()
	await _build()
	screen._music.silent = false
	screen._apply_music_switch()
	assert_eq(screen._music.tracks.size(), 1, "the bed is up by default")
	Settings.set_value("music_enabled", false)
	screen._apply_music_switch()
	assert_eq(screen._music.tracks.size(), 0, "and switching music off stops it")
	assert_false(screen._music.playing)
	assert_null(screen._music.stream, "and lets go of the PCM")
	Settings.set_value("music_enabled", true)
	screen._apply_music_switch()
	assert_eq(screen._music.tracks.size(), 1, "…and comes back")


func test_the_deck_builders_own_switch_does_not_reach_the_shell() -> void:
	# `deck_builder_music` is SCREEN-scoped. A player who silenced the
	# builder has said nothing about the title screen.
	_unset(MusicLibrary.SETTING)
	_touch(DeckAudio.MUSIC_SETTING)
	_touch("music_enabled")
	Settings.set_value("music_enabled", true)
	DeckAudio.set_music(false)
	_write_every_original_track()
	await _build()
	screen._music.silent = false
	screen._apply_music_switch()
	assert_false(DeckAudio.music_on(), "the builder is quiet")
	assert_eq(screen._music.tracks.size(), 1, "the shell is not")


func test_leaving_the_shell_stops_the_bed() -> void:
	# *"it stops when the shell leaves"*: the next screen must start its
	# own bed against silence, and nothing may sit on megabytes of PCM
	# that nobody can hear. `_open` stops it the moment the button is
	# pressed (change_scene_to_file is deferred to the end of the frame);
	# `_exit_tree` catches every other way out, which is what this drives.
	_unset(MusicLibrary.SETTING)
	_unset("music_enabled")
	_write_every_original_track()
	await _build()
	screen._music.silent = false
	screen._apply_music_switch()
	var player: MusicPlayer = screen._music
	assert_eq(player.tracks.size(), 1, "playing")
	remove_child(screen)
	await get_tree().process_frame
	assert_eq(player.key, "", "the shell let go of its tune")
	assert_eq(player.tracks, [] as Array[String])
	assert_false(player.playing)
	assert_null(player.stream, "and of the audio behind it")


func test_a_shell_with_no_music_imported_is_silence_not_an_error() -> void:
	# A player who never ran the importer has an empty library. Silence,
	# no error, no missing-file warning.
	_unset(MusicLibrary.SETTING)
	_unset("music_enabled")
	assert_eq(MusicLibrary.single_for(_beds()), "")
	await _build()
	screen._music.silent = false
	screen._apply_music_switch()
	assert_eq(screen._music.tracks, [] as Array[String])
	assert_false(screen._music.playing)


func test_a_partial_import_falls_back_down_the_list_in_order() -> void:
	# The fallbacks are in measured order behind the first choice, so a
	# player missing LocMus15 still gets the next calmest bed they have
	# rather than an arbitrary one.
	_unset(MusicLibrary.SETTING)
	var beds := _beds()
	for i in range(1, beds.size()):
		MusicLibrary.refresh()
		for path in _made:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		_made = []
		# Everything from position i onwards is present; the ones before
		# it are not.
		for j in range(i, beds.size()):
			_write(SKIN_DIR, String(beds[j]) + ".wav")
		assert_eq(MusicLibrary.single_for(beds), String(beds[i]),
			"the first bed the player actually has")


func test_a_library_with_none_of_them_still_finds_a_tune() -> void:
	# A player with no imported original and one file of their own gets
	# their file. Silence is reserved for a genuinely empty library.
	_unset(MusicLibrary.SETTING)
	_write(PLAYER_DIR, "windswept_march.wav")
	assert_eq(MusicLibrary.single_for(_beds()),
		"windswept_march")


func test_a_headless_shell_loads_nothing_and_starts_no_voice() -> void:
	# The rule for the whole suite and the soak: no audio device, no
	# sample read, no voice. The shell must not be the screen that breaks
	# it — it is the one every headless run opens.
	_unset(MusicLibrary.SETTING)
	_unset("music_enabled")
	_write_every_original_track()
	await _build()
	assert_true(screen._music.silent, "a headless run says so for itself")
	assert_eq(screen._music.tracks, [] as Array[String])
	assert_null(screen._music.stream)
	assert_false(screen._music.playing)


# =================================================== 2. THE BOOT SPLASH ==
#
# THE ROUTE, and why there is no splash scene. Godot 4.7.2 registers
# `application/boot_splash/minimum_display_time` (int, hint
# `0,100,1,or_greater,suffix:ms`, default 0), so the owner's picture is
# held by the ENGINE, where it already lives, and nothing runs before the
# title screen. That is also why there is nothing to make skippable: the
# boot image is drawn before a single line of GDScript, and the wait is
# bounded to one second rather than being a scene a player could be stuck
# in.

func test_the_splash_is_held_rather_than_flashing_past() -> void:
	# *"Splash screen could be a bit longer."* Without this the picture is
	# up only for as long as the engine happens to take to load, which on
	# a fast machine is a flash.
	var held: int = int(ProjectSettings.get_setting(
		"application/boot_splash/minimum_display_time", 0))
	assert_eq(held, SPLASH_MS, "one key, in milliseconds, and no code")
	assert_gt(held, 0, "the whole point: the engine holds the image")


func test_the_wait_stays_under_the_owners_two_seconds() -> void:
	# *"Do not make the game slower to reach than about two seconds — the
	# owner wants to see their picture, not wait for it."* Measured under
	# Xvfb with `--quit-after 3`, the wait is ADDED to the engine's ~1.0 s
	# start: 0 ms -> 1.5 s, 1000 ms -> 2.0 s, 1500 ms -> 2.5 s, 2000 ms ->
	# 3.0 s. So the ceiling in the setting's own units is 1000.
	var held: int = int(ProjectSettings.get_setting(
		"application/boot_splash/minimum_display_time", 0))
	assert_lte(held, SPLASH_MS_CEILING,
		"about a second of engine start plus this must stay near 2 s")


func test_it_is_still_the_owners_picture_on_their_black() -> void:
	# The route must not have quietly changed what is shown.
	assert_eq(String(ProjectSettings.get_setting(
		"application/boot_splash/image", "")), "res://game/boot_splash.png")
	assert_true(FileAccess.file_exists("res://game/boot_splash.png"),
		"and it ships — the boot image is drawn before the game runs, so "
		+ "it has to be inside the .pck")
	assert_eq(ProjectSettings.get_setting(
		"application/boot_splash/bg_color", Color.WHITE), Color(0, 0, 0, 1),
		"the black the artwork already sits on, so there is no seam")
	assert_true(bool(ProjectSettings.get_setting(
		"application/boot_splash/show_image", false)), "and it is shown")


func test_the_title_screen_is_still_the_first_scene() -> void:
	# THE ROUTE, pinned: no scene was added ahead of the shell, so
	# `tools/screenshot_tour.gd` (which instantiates main.tscn directly)
	# and the `--quit-after` smoke in `build_release.sh` are untouched,
	# and nothing that assumes the title screen is first can break.
	assert_eq(String(ProjectSettings.get_setting(
		"application/run/main_scene", "")), "res://game/main.tscn")


# ------------------------------------------------------------ plumbing --

func _original_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in MusicLibrary.ORIGINAL_TRACKS:
		out.append({"id": String(row[0])})
	return out


func _unique(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		if not out.has(id):
			out.append(id)
	return out


## `game/main.gd` carries no `class_name` (it is a scene script, like every
## other screen here), so its constant is read off the script resource
## rather than through a type. Doing it in one place means a rename of
## `MENU_BEDS` fails these tests loudly instead of silently testing
## nothing.
func _beds() -> Array[String]:
	var script: GDScript = load("res://game/main.gd")
	var constants := script.get_script_constant_map()
	assert_true(constants.has("MENU_BEDS"),
		"game/main.gd names the shell's beds in MENU_BEDS")
	var out: Array[String] = []
	for id in constants.get("MENU_BEDS", []):
		out.append(String(id))
	return out


## The bed the shell plays when the player has the whole library.
func _first_bed() -> String:
	var beds := _beds()
	return beds[0] if not beds.is_empty() else ""

# ------------------------------------------ where the menu column sits --
#
# THE COLUMN IS PLACED OFF THE PAINTING, so the numbers below are
# measurements of `Shellscreen`, not taste. The owner's 2026-09-04
# playtest asked for the menu *"juuust a bit left, in the middle of the
# subtitle 'the gathering'"*, and then that Exit not sit on the screen
# edge. `title_background` is 640x480 shown COVERED in a 1280x800 window,
# so it scales exactly x2 and the horizontal mapping is 2x with no crop;
# vertically it renders 1280x960 centred, so image y maps to (y-40)*2.
#
# Measured on the rendered screen:
#   * the lettering of "The Gathering" runs x=612..1178 -> CENTRE 895.
#     The (R) sits outside the words, at ~1205; the column is centred on
#     the WORDS, which is what the eye reads as centred.
#   * the subtitle's lowest ink is NOT its baseline (~420) but the
#     descender of the g, which reaches y=432.
#
# That leaves 368px of strip for the column, which is why MENU_GAP is 6
# and not 10: at 10 the column stood 358 tall and the whole budget was
# TEN pixels, spent 6 above and 4 below — Exit on the screen edge.

## The centre of "The Gathering"'s lettering, in window pixels.
const SUBTITLE_CENTRE_X := 895.0
## The lowest ink in the subtitle — the g's descender, not the baseline.
const SUBTITLE_BOTTOM_Y := 432.0


## The shell in a rect the SIZE OF THE SHIPPED WINDOW. The measurements
## below are window pixels, and the column is anchored to the BOTTOM — in
## GUT's own tree the root is a different height, so a bottom-anchored
## rect read there is measuring the test runner, not the game.
const WINDOW := Vector2(1280, 800)


func _build_at_window_size() -> Control:
	var holder := Control.new()
	add_child_autofree(holder)
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.size = WINDOW
	screen = load("res://game/main.tscn").instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


func _button_size(screen: Control) -> Vector2:
	return screen.MENU_BUTTON


func _menu_column(screen: Control) -> VBoxContainer:
	for child in screen.get_children():
		if child is VBoxContainer and (child as Control).size.x \
				== _button_size(screen).x:
			return child
	return null


func test_the_menu_column_is_centred_on_the_subtitle() -> void:
	var screen := await _build_at_window_size()
	var column := _menu_column(screen)
	assert_not_null(column, "the shell must have a menu column")
	var centre := column.get_global_rect().get_center().x \
		- screen.get_global_rect().position.x
	assert_almost_eq(centre, SUBTITLE_CENTRE_X, 1.0,
		"the column is centred on 'The Gathering', not on the window")


func test_the_menu_column_clears_the_subtitles_descender() -> void:
	var screen := await _build_at_window_size()
	var column := _menu_column(screen)
	var top := column.get_global_rect().position.y \
		- screen.get_global_rect().position.y
	assert_gt(top, SUBTITLE_BOTTOM_Y,
		"the column must start below the g of 'Gathering'")


func test_exit_does_not_sit_on_the_screen_edge() -> void:
	var screen := await _build_at_window_size()
	var column := _menu_column(screen)
	var below := screen.get_global_rect().end.y - column.get_global_rect().end.y
	assert_gt(below, 16.0,
		"the last entry needs real air under it (it had 4px until 2026-09-04)")


func test_the_menu_font_is_the_largest_that_keeps_the_button_height() -> void:
	# 21 is a CEILING, not a preference: at 22 the line box pushes each
	# button from 36 to 38, the column grows 330 -> 346, and its top lands
	# at y=428 — four pixels INSIDE the descender above it.
	var screen := await _build_at_window_size()
	var column := _menu_column(screen)
	for button in column.get_children():
		assert_almost_eq((button as Control).size.y,
			_button_size(screen).y, 0.5,
			"%s grew taller than the column budget" % (button as Button).text)


func test_the_menu_letters_are_emboldened_because_there_is_no_bold_cut() -> void:
	# MagicMedieval ships ONE cut (Regular, usWeightClass 400) and no bold
	# companion exists in any of the 28 .ttf files in `shandalar-src`, so
	# the weight is synthesised by growing the outline.
	var screen := await _build_at_window_size()
	var column := _menu_column(screen)
	var face: Font = (column.get_child(0) as Button).get_theme_font("font")
	if GameSkin.font("font_title") == null:
		pass_test("no skin imported: there is no face to embolden")
		return
	assert_true(face is FontVariation,
		"the shell's buttons wear a synthesised weight")
	assert_almost_eq((face as FontVariation).variation_embolden,
		float(screen.MENU_BOLD), 0.001, "the emboldening is the one main.gd asks for")
