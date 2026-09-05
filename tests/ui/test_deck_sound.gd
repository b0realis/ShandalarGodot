extends GutTest
## THE DECK BUILDER'S SOUND — its one looping bed, its new stone grind, and
## the two switches that silence either.
##
## The owner's playtest, 2026-09-04:
##
##   *"Deck builder: only the first song you now use should loop over."*
##   *"A quick stone grinding sound when pressing the stone filter buttons,
##    based on my sample."* … *"Shorten the sample to make the sound snap
##    with the button press, but this stone grinding should be heard nicely
##    still."*
##   *"The menu should contain also deck builder SFX and music checkboxes,
##    as a user may be annoyed by SFX or music while deck building."*
##
## THREE THINGS ARE PINNED HARDEST HERE, because all three rot quietly:
##
##  1. **WHICH BED.** "The first song" has to mean the same tune tomorrow,
##     so it is [constant MusicLibrary.ORIGINAL_TRACKS]' own order and never
##     the shuffle's. A test that asserted "some track plays" would pass
##     against the random pick this replaced.
##  2. **THE SHIPPED FILE ITSELF.** Its length and its shape are read out of
##     the bytes on disk, not out of a constant — the file is the artefact,
##     and a re-trim that made it two seconds long would otherwise pass.
##  3. **WHICH SWITCH WINS.** Global off beats screen-on, and the default is
##     ON and is NOT IN THE FILE (`Settings.clear_value`; see
##     `tests/ui/test_duel_options.gd`'s `_unset` for why a test that reads
##     a default must own the absence of the key).
##
## THE MUSIC SEAMS are [MusicLibrary]'s own `dirs` / `skin_dirs`, pointed at
## scratch folders exactly as `tests/ui/test_options_music.gd` points them:
## otherwise this file would test one thing on a machine that has the 1997
## `Sound/` folder imported and a different thing on a machine that has not.

const PLAYER_DIR := "user://test_deck_sound_player"
const SKIN_DIR := "user://test_deck_sound_skin"

var screen: DeckBuilderScreen
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
func _unset(key: String) -> void:
	_touch(key)
	Settings.clear_value(key)


## The screen, built after the library seams are in place — its `_ready`
## starts the bed, so a screen built first would have drawn from the
## machine's own music instead of this test's.
func _build() -> DeckBuilderScreen:
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


# ------------------------------------------------------------ fixtures --

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


# ======================================================= 1. THE ONE BED ==

func test_the_deck_builders_beds_are_the_1997_range() -> void:
	# `sprintf(path, "Sound\\LocMus%d.wav", RANDRANGE(1, 19))`
	# (`shandalar-src/src/deck/deckdll.cpp:2047`), and RANDRANGE is
	# inclusive at BOTH ends (`:746`) — so nineteen, 1 through 19.
	# LocMus0 is the adventure's own and must not be in here.
	var beds := MusicLibrary.deck_builder_beds()
	assert_eq(beds.size(), 19, "LocMus1..LocMus19")
	assert_eq(beds[0], "music_location_1")
	assert_eq(beds[18], "music_location_19")
	assert_false(beds.has("music_location_0"), "the adventure's own is not ours")


func test_the_bed_is_the_librarys_first_and_not_the_shuffles() -> void:
	# THE WHOLE ITEM: *"only the first song you now use should loop over."*
	# Three of the nineteen are present, out of order in the folder — the
	# answer must be the LIBRARY's order (LocMus4 before 9 before 17), not
	# the file system's and not a shuffle's.
	_unset(MusicLibrary.SETTING)
	_write(SKIN_DIR, "music_location_17.wav")
	_write(SKIN_DIR, "music_location_9.wav")
	_write(SKIN_DIR, "music_location_4.wav")
	assert_eq(MusicLibrary.single_for(MusicLibrary.deck_builder_beds()),
		"music_location_4", "the lowest-numbered bed the player HAS")


func test_the_same_bed_comes_back_every_time_the_screen_opens() -> void:
	# The pick this replaced was `randi() % 19 + 1`, so it was a different
	# tune every time — which is why "the first song" could not name one.
	_unset(MusicLibrary.SETTING)
	for id in ["music_location_11", "music_location_3", "music_location_8"]:
		_write(SKIN_DIR, id + ".wav")
	var first := MusicLibrary.single_for(MusicLibrary.deck_builder_beds())
	for _i in 12:
		assert_eq(MusicLibrary.single_for(MusicLibrary.deck_builder_beds()),
			first, "stable across calls")
	assert_eq(first, "music_location_3")


func test_the_options_choice_still_wins_when_the_player_picked_a_track() -> void:
	# *"keep the Options music choice honoured if the player has set one."*
	_touch(MusicLibrary.SETTING)
	_write(SKIN_DIR, "music_location_2.wav")
	_write(PLAYER_DIR, "my_own_tune.wav")
	MusicLibrary.set_choice("my_own_tune")
	assert_eq(MusicLibrary.single_for(MusicLibrary.deck_builder_beds()),
		"my_own_tune", "the player asked for that one, everywhere")
	# ...and the two "you choose" modes hand the decision back.
	for mode in [MusicLibrary.CHOICE_SHUFFLE, MusicLibrary.CHOICE_ORIGINAL]:
		MusicLibrary.set_choice(mode)
		assert_eq(MusicLibrary.single_for(MusicLibrary.deck_builder_beds()),
			"music_location_2", "%s leaves the bed to us" % mode)


func test_a_library_with_nothing_of_the_range_still_finds_a_tune() -> void:
	# A player with no imported original and one file of their own gets
	# their file. Silence is for a library that is genuinely empty.
	_unset(MusicLibrary.SETTING)
	_write(PLAYER_DIR, "windswept_march.wav")
	assert_eq(MusicLibrary.single_for(MusicLibrary.deck_builder_beds()),
		"windswept_march")


func test_an_empty_library_is_silence_and_not_an_error() -> void:
	_unset(MusicLibrary.SETTING)
	assert_eq(MusicLibrary.single_for(MusicLibrary.deck_builder_beds()), "")


func test_one_bed_means_one_stream_looped_and_not_a_playlist() -> void:
	# [method MusicPlayer.play_one]: one id, and the list carries it TWICE
	# so the wrap is a crossfade instead of the click the 1997 loop marker
	# made every ten seconds.
	_unset(MusicLibrary.SETTING)
	_write(SKIN_DIR, "music_location_1.wav")
	var player := MusicPlayer.new()
	add_child_autofree(player)
	player.silent = false
	player.play_one("music_location_1")
	assert_eq(player.tracks, ["music_location_1"] as Array[String],
		"exactly one bed")
	assert_eq(player.key, "music_location_1", "…and it names it, so a"
		+ " re-apply of the switches does not restart the tune")
	var list := player.stream as AudioStreamPlaylist
	assert_not_null(list, "an AudioStreamPlaylist, as every bed here is")
	assert_true(list.loop, "it LOOPS — that is the whole ask")
	assert_eq(list.get_stream_count(), 2, "the same stream twice, for the seam")
	assert_gt(list.fade_time, 0.0, "and the seam is crossfaded")


func test_the_screen_plays_that_one_bed_and_nothing_after_it() -> void:
	_unset(MusicLibrary.SETTING)
	for i in [1, 5, 12]:
		_write(SKIN_DIR, "music_location_%d.wav" % i)
	await _build()
	assert_not_null(screen._music, "the screen holds its player")
	screen._music.silent = false
	screen._apply_music_switch()
	assert_eq(screen._music.tracks.size(), 1,
		"one bed, not the shuffle's eight")
	assert_eq(screen._music.tracks[0], "music_location_1")


# ================================================== 2. THE STONE GRIND ==
#
# The file is read out of the bytes on disk. A constant would only pin what
# we believed we wrote.

func _wav_header(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "the sample is where it says it is: %s" % path)
	if file == null:
		return {}
	var bytes := file.get_buffer(44)
	file.close()
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	buf.seek(0)
	buf.big_endian = false
	var riff := buf.get_utf8_string(4)
	buf.get_u32()
	var wave := buf.get_utf8_string(8)      # "WAVEfmt "
	buf.get_u32()                           # fmt chunk size
	var format := buf.get_16()
	var channels := buf.get_16()
	var rate := buf.get_u32()
	buf.get_u32()                           # byte rate
	buf.get_16()                            # block align
	var bits := buf.get_16()
	buf.get_utf8_string(4)                  # "data"
	var data_bytes := buf.get_u32()
	return {"riff": riff, "wave": wave, "format": format,
		"channels": channels, "rate": rate, "bits": bits,
		"bytes": data_bytes,
		"seconds": float(data_bytes) / float(maxi(rate, 1)
			* channels * (bits / 8))}


func test_the_shipped_sample_is_a_short_punchy_grind() -> void:
	# *"Shorten the sample to make the sound snap with the button press,
	# but this stone grinding should be heard nicely still."* The source is
	# 2.35 s of continuous scraping; a button cue that long is a drone.
	var head := _wav_header(DeckAudio.GRIND)
	assert_eq(head.get("riff", ""), "RIFF")
	assert_eq(head.get("wave", ""), "WAVEfmt ")
	assert_eq(int(head.get("format", 0)), 1, "plain PCM")
	assert_eq(int(head.get("channels", 0)), 1, "mono, like every 1997 cue")
	assert_eq(int(head.get("rate", 0)), 22050, "and at the original's rate")
	assert_eq(int(head.get("bits", 0)), 16)
	var seconds := float(head.get("seconds", 0.0))
	assert_between(seconds, 0.15, 0.35,
		"a snap, not a drone (it is %.3f s)" % seconds)


func test_the_sample_starts_and_ends_at_silence_so_it_cannot_click() -> void:
	# A cut that lands on a non-zero sample clicks at both ends — which is
	# exactly the defect the duel's old ten-second loop had.
	var file := FileAccess.open(DeckAudio.GRIND, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var bytes := file.get_buffer(int(file.get_length()))
	file.close()
	assert_gt(bytes.size(), 44, "there is audio in it")
	assert_eq(bytes.decode_s16(44), 0, "the first frame is silence")
	assert_eq(bytes.decode_s16(bytes.size() - 2), 0, "and so is the last")
	# ...and it is not silent in the middle, which a fade bug could make it.
	var peak := 0
	for i in range(44, bytes.size() - 1, 2):
		peak = maxi(peak, absi(bytes.decode_s16(i)))
	assert_gt(peak, 16000, "there is a real grind between the two fades")


func test_the_sample_ships_inside_the_pack_as_a_normal_resource() -> void:
	# NOT under `assets/` — that whole directory is excluded from the
	# export (`export_presets.cfg`), because the 1997 art is the player's
	# own copy. Ours is our file, so it goes in the pack the way
	# `game/boot_splash.png` does and is loaded like any other resource.
	assert_true(DeckAudio.GRIND.begins_with("res://game/"),
		"under game/, which the export ships")
	assert_false(DeckAudio.GRIND.begins_with("res://assets/"),
		"assets/ is excluded from the .pck")
	assert_true(ResourceLoader.exists(DeckAudio.GRIND),
		"and the import pipeline knows it")
	var stream := DeckAudio.stream_for(DeckAudio.CUE_FILTER)
	assert_not_null(stream, "it loads")
	assert_true(stream is AudioStreamWAV)
	assert_between(stream.get_length(), 0.15, 0.35,
		"the loaded resource is the short one, not the source mp3")


func test_pressing_a_stone_filter_button_grinds() -> void:
	_unset(DeckAudio.SFX_SETTING)
	await _build()
	screen._audio.recent.clear()
	var buttons: Array = screen._filter_bar.group_buttons("Type Filters")
	assert_gt(buttons.size(), 0, "there are medallions to press")
	buttons[0].pressed.emit()
	assert_true(screen._audio.recent.has(DeckAudio.CUE_FILTER),
		"the stone ground when the stone went down")


func test_every_filter_medallion_grinds_and_the_sort_button_does_not() -> void:
	# The strip's `changed` signal is also emitted by the sort menu and by
	# `Select All`, neither of which is a stone button — which is why the
	# cue rides the PRESS and not the signal.
	_unset(DeckAudio.SFX_SETTING)
	await _build()
	for group in screen._filter_bar.group_names():
		for button in screen._filter_bar.group_buttons(group):
			screen._audio.recent.clear()
			button.pressed.emit()
			assert_true(screen._audio.recent.has(DeckAudio.CUE_FILTER),
				"%s: every medallion grinds" % group)
	screen._audio.recent.clear()
	screen._filter_bar.sort_button.pressed.emit()
	assert_false(screen._audio.recent.has(DeckAudio.CUE_FILTER),
		"the sort button is not a stone filter")


func test_a_headless_run_makes_no_voice_and_no_error() -> void:
	_unset(DeckAudio.SFX_SETTING)
	await _build()
	assert_true(screen._audio.silent,
		"no device under --headless, so no sample is even read")
	screen._audio.recent.clear()
	for _i in 20:
		screen._audio.play(DeckAudio.CUE_FILTER)
	assert_eq(screen._audio.recent.size(), 20, "the cue is still DECIDED")
	assert_eq(screen._audio._voices.size(), 0, "and no player was allocated")


func test_the_1997_deck_surface_cues_are_the_four_slots_it_loaded() -> void:
	# `init_sounds_and_music` (`deckdll.cpp:2040-2056`): music 1, Draw 2,
	# Discard 3, Button 4.
	_unset(DeckAudio.SFX_SETTING)
	await _build()
	screen._audio.recent.clear()
	screen._add_one("Mountain")
	assert_true(screen._audio.recent.has(DeckAudio.CUE_ADD), "Draw.wav, in")
	screen._audio.recent.clear()
	screen._remove_one("Mountain")
	assert_true(screen._audio.recent.has(DeckAudio.CUE_REMOVE),
		"Discard.wav, out")
	screen._audio.recent.clear()
	screen._run_command("Sort deck")
	assert_true(screen._audio.recent.has(DeckAudio.CUE_BUTTON),
		"Button.wav, on every command")


# ================================================== 3. THE TWO SWITCHES ==

func test_the_two_boxes_default_on_and_write_nothing() -> void:
	# ABSENCE OF A KEY IS THE DEFAULT. Writing the default in materialises
	# it — the bug that shipped a "fan" hand once.
	_unset(DeckAudio.SFX_SETTING)
	_unset(DeckAudio.MUSIC_SETTING)
	_touch("sound_enabled")
	_touch("music_enabled")
	Settings.clear_value("sound_enabled")
	Settings.clear_value("music_enabled")
	assert_true(DeckAudio.sfx_on(), "effects on out of the box")
	assert_true(DeckAudio.music_on(), "and the bed too")
	assert_false(Settings.has_value(DeckAudio.SFX_SETTING),
		"and nothing was written to say so")
	assert_false(Settings.has_value(DeckAudio.MUSIC_SETTING))
	# Turning one OFF is a real choice and is stored…
	DeckAudio.set_sfx(false)
	assert_true(Settings.has_value(DeckAudio.SFX_SETTING))
	assert_false(DeckAudio.sfx_on())
	# …and turning it back on REMOVES the key rather than writing `true`.
	DeckAudio.set_sfx(true)
	assert_false(Settings.has_value(DeckAudio.SFX_SETTING),
		"back to the default means back to no key at all")


func test_the_screens_own_box_silences_the_grind() -> void:
	_touch(DeckAudio.SFX_SETTING)
	_touch("sound_enabled")
	Settings.clear_value("sound_enabled")
	await _build()
	DeckAudio.set_sfx(false)
	screen._audio.recent.clear()
	screen._filter_bar.group_buttons("Type Filters")[0].pressed.emit()
	assert_eq(screen._audio.recent.size(), 0,
		"the box is unticked: the screen decides nothing")
	DeckAudio.set_sfx(true)
	screen._filter_bar.group_buttons("Type Filters")[0].pressed.emit()
	assert_true(screen._audio.recent.has(DeckAudio.CUE_FILTER),
		"and ticking it brings the grind back on the very next press")


func test_it_silences_every_effect_this_screen_plays_not_only_the_grind() -> void:
	_touch(DeckAudio.SFX_SETTING)
	_touch("sound_enabled")
	Settings.clear_value("sound_enabled")
	await _build()
	DeckAudio.set_sfx(false)
	screen._audio.recent.clear()
	screen._add_one("Mountain")
	screen._remove_one("Mountain")
	screen._run_command("Sort deck")
	screen._filter_bar.group_buttons("Type Filters")[0].pressed.emit()
	assert_eq(screen._audio.recent.size(), 0,
		"card in, card out, a command and a filter — all four silent")


func test_the_global_switch_wins_when_it_is_off() -> void:
	# *"a player who turned all sound off globally should not get grinding
	# stone because the builder's own box is ticked."*
	_touch(DeckAudio.SFX_SETTING)
	_touch(DeckAudio.MUSIC_SETTING)
	_touch("sound_enabled")
	_touch("music_enabled")
	DeckAudio.set_sfx(true)
	DeckAudio.set_music(true)
	Settings.set_value("sound_enabled", false)
	Settings.set_value("music_enabled", false)
	assert_false(DeckAudio.sfx_on(), "global off beats screen-on")
	assert_false(DeckAudio.music_on())
	Settings.set_value("sound_enabled", true)
	Settings.set_value("music_enabled", true)
	assert_true(DeckAudio.sfx_on(), "and giving it back gives it back")
	assert_true(DeckAudio.music_on())


func test_silencing_the_builder_does_not_silence_a_duel() -> void:
	# These are SCREEN-scoped. The duel reads the global keys and nothing
	# else, so its own switch must be untouched by this screen's.
	_touch(DeckAudio.SFX_SETTING)
	_touch(DeckAudio.MUSIC_SETTING)
	_touch("sound_enabled")
	_touch("music_enabled")
	Settings.set_value("sound_enabled", true)
	Settings.set_value("music_enabled", true)
	DeckAudio.set_sfx(false)
	DeckAudio.set_music(false)
	assert_false(DeckAudio.sfx_on(), "the builder is quiet")
	assert_true(Settings.sound_enabled(), "the duel's effects are not")
	assert_true(Settings.music_enabled(), "nor its music")


func test_unticking_music_stops_the_bed_on_the_spot() -> void:
	# *"They must take effect immediately, not at the next screen."*
	_unset(MusicLibrary.SETTING)
	_touch(DeckAudio.MUSIC_SETTING)
	_touch("music_enabled")
	Settings.clear_value("music_enabled")
	_write(SKIN_DIR, "music_location_1.wav")
	await _build()
	screen._music.silent = false
	screen._apply_music_switch()
	assert_eq(screen._music.tracks.size(), 1, "the bed is up")
	DeckAudio.set_music(false)
	screen._apply_music_switch()
	assert_eq(screen._music.tracks.size(), 0, "and it stopped")
	assert_false(screen._music.playing)
	DeckAudio.set_music(true)
	screen._apply_music_switch()
	assert_eq(screen._music.tracks.size(), 1, "…and comes back")
