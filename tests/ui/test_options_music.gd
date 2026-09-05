extends GutTest
## THE MUSIC SYSTEM — the owner's 2026-09-03 playtest, pinned.
##
## *"Music in the duel is wrong — now it is repeating a short sample —
## unacceptable. Check music songs available (expose this also in music
## and user can add their own)."*
##
## Every test here fails against the code as it stood that morning:
## [MusicLibrary] did not exist, [MusicPlayer] took a single manifest key
## and patched `LOOP_FORWARD` onto it, and the manifest had twenty music
## entries rather than twenty-seven.
##
## NOTHING HERE TESTS A PHASE SOUND, and that is the second half of the
## same playtest. A `GameAudio.play_phase()` and its tests lived here for
## part of the day, until the owner settled it: *"The changing phases or
## combat phases have no sound by themselves. Card action and other
## actions that happen in phases have sound effects."* See
## `game/audio.gd`, "NOT A PHASE CUE".
##
## THE SEAMS. `MusicLibrary.dirs` and `MusicLibrary.skin_dirs` are pointed
## at scratch folders throughout, because this suite must test the same
## thing on a machine that HAS the 1997 music imported and on one that
## does not — the reason [member PortraitLibrary.dirs] is a `var` too.

const PLAYER_DIR := "user://test_music_player"
const SKIN_DIR := "user://test_music_skin"

var _made: Array[String] = []
var _saved: Dictionary = {}


func before_each() -> void:
	MusicLibrary.dirs = [PLAYER_DIR]
	MusicLibrary.skin_dirs = [SKIN_DIR]
	MusicLibrary.refresh()
	MusicPlayer.reset_order()
	_saved = {}


func after_each() -> void:
	for path in _made:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made = []
	# The Options screen writes the README itself, the first time it is
	# built — the same gesture the setup screen makes for portraits.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		PLAYER_DIR.path_join(MusicLibrary.README_NAME)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PLAYER_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SKIN_DIR))
	MusicLibrary.dirs = ["user://music"]
	MusicLibrary.skin_dirs = null
	MusicLibrary.refresh()
	MusicPlayer.reset_order()
	# The player's own file must not keep anything a test set — writing a
	# default back would MATERIALISE it, which is what clear_value is for
	# (`tests/ui/test_duel_options.gd`, `_unset`).
	for key in _saved:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])


## Call BEFORE writing [param key]: snapshots the player's own value and
## takes it out of the file, so a test that reads a DEFAULT reads the
## shipped one and not whatever this machine happens to hold.
func _unset(key: String) -> void:
	if not _saved.has(key):
		_saved[key] = Settings.get_value(key, null) \
			if Settings.has_value(key) else null
	Settings.clear_value(key)


# ------------------------------------------------------------ fixtures --

## A real, minimal PCM wav — 22 050 Hz, mono, 16-bit, like every file the
## original ships. Written rather than copied: no original bytes travel
## with this suite.
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
	buf.put_16(1)                       # PCM
	buf.put_16(1)                       # mono
	buf.put_u32(22050)
	buf.put_u32(44100)
	buf.put_16(2)
	buf.put_16(16)
	buf.put_data("data".to_ascii_buffer())
	buf.put_u32(pcm.size())
	buf.put_data(pcm)
	return buf.data_array


func _write(dir_path: String, name: String, body := PackedByteArray()) -> String:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(dir_path))
	var path := dir_path.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(body if not body.is_empty() else _wav(64))
	file.close()
	_made.append(path)
	MusicLibrary.refresh()
	return path


func _ids() -> Array[String]:
	return MusicLibrary.ids_of(MusicLibrary.all())


# =========================================================== THE LIBRARY ==

func test_the_original_has_twenty_seven_beds_not_one() -> void:
	# The count is the finding, and it is what defect A came down to:
	# `Sound/` holds Dueltune, LocMus0..19, Tmplmus1 and five castle
	# themes. Twenty of them were in the manifest and one of them played.
	assert_eq(MusicLibrary.ORIGINAL_TRACKS.size(), 27)
	var ids: Array[String] = []
	for row in MusicLibrary.ORIGINAL_TRACKS:
		ids.append(String(row[0]))
	assert_true(ids.has("music_duel"), "the duel's own bed")
	assert_true(ids.has("music_location_0"),
		"LocMus0 — the adventure's, left out while only the deck "
		+ "builder's 1..19 mattered")
	assert_true(ids.has("music_location_19"))
	assert_true(ids.has("music_temple"))
	for colour in ["white", "blue", "black", "red", "green"]:
		assert_true(ids.has("music_castle_" + colour), colour + " castle")
	assert_eq(ids.size(), _unique(ids).size(), "no id twice")


func test_a_stinger_is_not_a_track() -> void:
	# A one-shot inside a shuffle is a jump-scare. `Wingame.wav` and
	# `Dngnduel.wav` are stings, and the duel's win/lose pair are already
	# sfx_win/sfx_lose.
	var ids: Array[String] = []
	for row in MusicLibrary.ORIGINAL_TRACKS:
		ids.append(String(row[0]))
	for absent in ["music_wingame", "music_dungeon", "music_win",
			"music_lose"]:
		assert_false(ids.has(absent), absent + " is a sting, not a bed")


func test_an_imported_track_is_found_under_its_manifest_key() -> void:
	_write(SKIN_DIR, "music_duel.wav")
	assert_true(_ids().has("music_duel"))
	assert_eq(MusicLibrary.name_of("music_duel"), "Duel")


func test_a_dropped_in_track_is_found_and_named_after_the_file() -> void:
	_write(PLAYER_DIR, "windswept_march.ogg", _wav(64))
	assert_true(_ids().has("windswept_march"))
	assert_eq(MusicLibrary.name_of("windswept_march"), "Windswept March")
	assert_eq(MusicLibrary.title_of("Grim-Tutor"), "Grim Tutor")


func test_a_player_file_replaces_an_imported_track_of_the_same_name() -> void:
	# The promise the README makes, and the one PortraitLibrary already
	# keeps for faces: same file name, your version.
	_write(SKIN_DIR, "music_duel.wav")
	var mine := _write(PLAYER_DIR, "music_duel.wav")
	var found := 0
	for entry in MusicLibrary.all():
		if entry["id"] != "music_duel":
			continue
		found += 1
		assert_eq(entry["path"], mine, "the player's own file wins")
		assert_true(bool(entry["mine"]))
		assert_eq(entry["name"], "Duel", "and keeps the readable name")
	assert_eq(found, 1, "listed once, not twice")


func test_the_originals_order_comes_first_then_the_players_own() -> void:
	_write(SKIN_DIR, "music_duel.wav")
	_write(SKIN_DIR, "music_temple.wav")
	_write(PLAYER_DIR, "aardvark.wav")
	assert_eq(_ids(), ["music_duel", "music_temple", "aardvark"] as Array[String])


func test_the_readme_and_anything_else_is_not_a_track() -> void:
	_write(PLAYER_DIR, "windswept_march.ogg", _wav(64))
	_write(PLAYER_DIR, "notes.txt", "hello".to_ascii_buffer())
	_write(PLAYER_DIR, "cover.png", "not audio".to_ascii_buffer())
	assert_eq(_ids(), ["windswept_march"] as Array[String])


func test_nothing_imported_and_nothing_dropped_in_is_silence_not_an_error() -> void:
	assert_eq(MusicLibrary.all(), [] as Array[Dictionary])
	assert_eq(MusicLibrary.playlist_for("music_duel"), [] as Array[String])
	assert_null(MusicLibrary.stream("music_duel"))
	assert_null(MusicPlayer.build_stream([] as Array[String]))


func test_the_folder_explains_itself() -> void:
	var where := MusicLibrary.ensure_folder()
	assert_true(DirAccess.dir_exists_absolute(where))
	var readme := PLAYER_DIR.path_join(MusicLibrary.README_NAME)
	_made.append(readme)
	assert_true(FileAccess.file_exists(readme))
	var text := FileAccess.get_file_as_string(readme)
	assert_string_contains(text, "OGG")
	assert_string_contains(text, "Windswept March", "the naming rule, by example")
	assert_string_contains(text, "music_duel", "and how to replace a track")


func test_a_track_loads_without_an_import_companion() -> void:
	# The whole reason loading goes through `load_from_file`: a file
	# dropped in after the game shipped has no `.import` beside it.
	_write(PLAYER_DIR, "windswept_march.wav", _wav(256))
	var stream := MusicLibrary.stream("windswept_march")
	assert_not_null(stream)
	assert_true(stream is AudioStreamWAV)


# ============================================================ THE CHOICE ==

func test_shuffle_is_what_a_player_gets_out_of_the_box() -> void:
	_unset(MusicLibrary.SETTING)
	assert_eq(MusicLibrary.choice(), MusicLibrary.CHOICE_SHUFFLE)


func test_the_choice_round_trips_and_clearing_restores_the_default() -> void:
	_unset(MusicLibrary.SETTING)
	MusicLibrary.set_choice(MusicLibrary.CHOICE_ORIGINAL)
	assert_eq(MusicLibrary.choice(), MusicLibrary.CHOICE_ORIGINAL)
	Settings.clear_value(MusicLibrary.SETTING)
	assert_eq(MusicLibrary.choice(), MusicLibrary.CHOICE_SHUFFLE)


func test_the_1997_choice_is_one_bed_for_the_screen_that_asked() -> void:
	_unset(MusicLibrary.SETTING)
	for key in ["music_duel", "music_location_7"]:
		_write(SKIN_DIR, key + ".wav")
	MusicLibrary.set_choice(MusicLibrary.CHOICE_ORIGINAL)
	assert_eq(MusicLibrary.playlist_for("music_duel"),
		["music_duel"] as Array[String], "Dueltune in a duel")
	assert_eq(MusicLibrary.playlist_for("music_location_7"),
		["music_location_7"] as Array[String], "the deck builder's draw")


func test_one_chosen_track_plays_whatever_screen_asks() -> void:
	_unset(MusicLibrary.SETTING)
	_write(SKIN_DIR, "music_duel.wav")
	_write(SKIN_DIR, "music_temple.wav")
	MusicLibrary.set_choice("music_temple")
	assert_eq(MusicLibrary.playlist_for("music_duel"),
		["music_temple"] as Array[String])


func test_a_chosen_track_that_is_gone_is_silence_not_an_error() -> void:
	_unset(MusicLibrary.SETTING)
	_write(SKIN_DIR, "music_duel.wav")
	MusicLibrary.set_choice("music_from_a_machine_i_no_longer_have")
	assert_eq(MusicLibrary.playlist_for("music_duel"), [] as Array[String])


func test_shuffle_takes_everything_and_still_opens_on_the_screens_bed() -> void:
	_unset(MusicLibrary.SETTING)
	for key in ["music_duel", "music_temple", "music_location_3"]:
		_write(SKIN_DIR, key + ".wav")
	_write(PLAYER_DIR, "windswept_march.wav")
	MusicLibrary.set_choice(MusicLibrary.CHOICE_SHUFFLE)
	var list := MusicLibrary.playlist_for("music_duel")
	assert_eq(list.size(), 4, "every track, the player's own included")
	assert_eq(list[0], "music_duel",
		"a duel still opens on Dueltune — what changes is what comes next")


# ========================================================== THE PLAYLIST ==

func test_the_playlist_is_whole_tracks_that_loop_and_crossfade() -> void:
	# THE DEFECT, exactly: a twenty-second sample with LOOP_FORWARD
	# patched onto it, clicking every twenty seconds for a whole duel.
	_write(SKIN_DIR, "music_duel.wav", _wav(512))
	_write(SKIN_DIR, "music_temple.wav", _wav(512))
	var built := MusicPlayer.build_stream(
		["music_duel", "music_temple"] as Array[String])
	assert_true(built is AudioStreamPlaylist)
	var list: AudioStreamPlaylist = built
	assert_eq(list.get_stream_count(), 2)
	assert_true(list.loop, "and it never runs out")
	assert_gt(list.fade_time, 0.0, "a crossfade, so the seam cannot click")
	assert_false(list.shuffle, "our order, not the audio thread's")


func test_a_single_track_is_listed_twice_so_the_wrap_can_crossfade() -> void:
	# A one-entry playlist has no seam to fade ACROSS and would click
	# exactly like the old loop. The same Resource twice costs nothing.
	_write(SKIN_DIR, "music_duel.wav", _wav(512))
	var list: AudioStreamPlaylist = MusicPlayer.build_stream(
		["music_duel"] as Array[String])
	assert_eq(list.get_stream_count(), 2)
	assert_eq(list.get_list_stream(0), list.get_list_stream(1),
		"one tune, one copy in memory, two entries")


func test_the_playlist_is_capped_so_a_duel_cannot_hold_the_whole_library() -> void:
	# Twenty-seven imported tracks are 76 MB of resident PCM. Eight is
	# about nine minutes of music and about 22 MB.
	var ids: Array[String] = []
	for i in MusicPlayer.MAX_TRACKS + 4:
		var id := "music_location_%d" % i
		_write(SKIN_DIR, id + ".wav", _wav(128))
		ids.append(id)
	var list: AudioStreamPlaylist = MusicPlayer.build_stream(ids)
	assert_eq(list.get_stream_count(), MusicPlayer.MAX_TRACKS)


func test_the_window_moves_so_the_next_duel_is_not_the_same_eight() -> void:
	# "It must survive a duel ending": the shuffle and the place in it are
	# the SESSION's, not the duel screen's, so a second duel picks up
	# where the first left off instead of replaying the same tracks.
	_unset(MusicLibrary.SETTING)
	MusicLibrary.set_choice(MusicLibrary.CHOICE_SHUFFLE)
	for i in MusicPlayer.MAX_TRACKS * 2:
		_write(SKIN_DIR, "music_location_%d.wav" % i, _wav(64))
	var first := MusicPlayer.next_tracks("music_duel")
	assert_eq(first.size(), MusicPlayer.MAX_TRACKS)
	assert_eq(MusicPlayer.cursor(), MusicPlayer.MAX_TRACKS,
		"the session moved on")
	var second := MusicPlayer.next_tracks("music_duel")
	assert_ne(first, second, "a second duel is not the first one again")


func test_a_single_track_choice_does_not_move_the_window() -> void:
	_unset(MusicLibrary.SETTING)
	_write(SKIN_DIR, "music_temple.wav")
	MusicLibrary.set_choice("music_temple")
	MusicPlayer.next_tracks("music_duel")
	assert_eq(MusicPlayer.cursor(), 0, "there is nothing to advance through")


func test_a_headless_player_loads_nothing_and_starts_nothing() -> void:
	# The rule for the whole suite and the soak: no audio device, no
	# sample read, no voice.
	_write(SKIN_DIR, "music_duel.wav", _wav(512))
	var player := MusicPlayer.new()
	add_child_autofree(player)
	await get_tree().process_frame
	assert_true(player.silent, "a headless run says so for itself")
	player.play_key("music_duel")
	assert_false(player.playing)
	assert_null(player.stream)
	assert_eq(player.tracks, [] as Array[String])


func test_stopping_lets_go_of_the_audio() -> void:
	_write(SKIN_DIR, "music_duel.wav", _wav(512))
	var player := MusicPlayer.new()
	add_child_autofree(player)
	await get_tree().process_frame
	player.silent = false
	player.play_tracks(["music_duel"] as Array[String])
	assert_not_null(player.stream, "playing")
	player.stop_music()
	assert_eq(player.key, "")
	assert_eq(player.tracks, [] as Array[String])
	assert_null(player.stream,
		"a stopped screen must not sit on megabytes of PCM")


# ============================================================== plumbing ==

func _unique(values: Array[String]) -> Array[String]:
	var seen := {}
	var out: Array[String] = []
	for value in values:
		if not seen.has(value):
			seen[value] = true
			out.append(value)
	return out
