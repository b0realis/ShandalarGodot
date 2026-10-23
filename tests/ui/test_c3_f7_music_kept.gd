extends GutTest
## Adventure campaign fix pass 2026-10-23, h5-10 round 2: THE DECK
## BUILDER'S BED IS READ ONCE. Every opening of a deck builder (the
## adventure's F1 among them) asked [method MusicLibrary.stream] for the
## same bed, and every ask read the whole WAV off the disk again — 19-22 ms
## of each opening on the desk. The library now keeps the last few tunes
## it read ([constant MusicLibrary.KEPT_TUNES]: the builder's bed, and the
## shell's bed and the place's tune the world plays between two openings),
## by path and modified time, and hands them out again while the file is
## unchanged; a few tunes, so memory stays bounded the way the class doc
## promises.
##
## The music seams are [MusicLibrary]'s own `dirs` / `skin_dirs`, pointed
## at scratch folders as `tests/ui/test_deck_sound.gd` points them.

const PLAYER_DIR := "user://test_c3_f7_music_player"
const SKIN_DIR := "user://test_c3_f7_music_skin"

var _made: Array[String] = []
var _had_choice := false
var _choice: Variant = null


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_made = []
	_had_choice = Settings.has_value(MusicLibrary.SETTING)
	_choice = Settings.get_value(MusicLibrary.SETTING, null)
	Settings.clear_value(MusicLibrary.SETTING)
	MusicLibrary.dirs = [PLAYER_DIR]
	MusicLibrary.skin_dirs = [SKIN_DIR]
	MusicLibrary.refresh()
	MusicPlayer.reset_order()


func after_each() -> void:
	for path in _made:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PLAYER_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SKIN_DIR))
	MusicLibrary.dirs = [GamePaths.music_folder()]
	MusicLibrary.skin_dirs = null
	MusicLibrary.refresh()
	MusicPlayer.reset_order()
	if _had_choice:
		Settings.set_value(MusicLibrary.SETTING, _choice)
	ShellMusic.stop()


## A real, minimal PCM wav of [param frames] frames — 22 050 Hz, mono,
## 16-bit (the fixture of `tests/ui/test_deck_sound.gd`).
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


func _write(dir_path: String, file_name: String, frames := 64) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var path := dir_path.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(_wav(frames))
	file.close()
	if not _made.has(path):
		_made.append(path)
	MusicLibrary.refresh()
	return path


func test_the_same_tune_asked_twice_is_read_once() -> void:
	_write(SKIN_DIR, "music_location_1.wav")
	var first := MusicLibrary.stream("music_location_1")
	assert_not_null(first)
	assert_same(MusicLibrary.stream("music_location_1"), first, "the kept tune, not a second read")


func test_a_tune_rewritten_on_disk_is_read_again() -> void:
	_write(SKIN_DIR, "music_location_1.wav", 64)
	var first := MusicLibrary.stream("music_location_1") as AudioStreamWAV
	# The modified time counts whole seconds: the rewrite lands in the next.
	OS.delay_msec(1100)
	var path := SKIN_DIR.path_join("music_location_1.wav")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(_wav(256))
	file.close()
	var again := MusicLibrary.stream("music_location_1") as AudioStreamWAV
	assert_not_same(again, first, "a changed file is read afresh")
	assert_eq(again.data.size(), 512, "and it is the new file")


func test_a_few_tunes_are_kept_not_the_library() -> void:
	var ids: Array[String] = []
	for i in MusicLibrary.KEPT_TUNES + 1:
		ids.append("music_location_%d" % (i + 1))
		_write(SKIN_DIR, ids[-1] + ".wav")
	var first := MusicLibrary.stream(ids[0])
	var last := first
	for i in range(1, ids.size()):
		last = MusicLibrary.stream(ids[i])
	assert_same(MusicLibrary.stream(ids[-1]), last, "the youngest is kept")
	assert_not_same(MusicLibrary.stream(ids[0]), first,
		"the oldest made room: %d tunes held, not twenty-seven" % MusicLibrary.KEPT_TUNES)


## The adventure's F1: the builder's bed, then on the way back the
## shell's bed and the tune of the place the hero stands by, then the
## builder's bed again — the bed is still kept.
func test_the_world_s_tunes_between_two_openings_keep_the_bed() -> void:
	for id in ["music_location_1", "music_location_2", "music_location_3"]:
		_write(SKIN_DIR, id + ".wav")
	var bed := MusicLibrary.stream("music_location_1")
	var shell := MusicLibrary.stream("music_location_2")
	var place := MusicLibrary.stream("music_location_3")
	assert_same(MusicLibrary.stream("music_location_1"), bed, "the builder's bed")
	assert_same(MusicLibrary.stream("music_location_2"), shell, "the shell's")
	assert_same(MusicLibrary.stream("music_location_3"), place, "the place's")


func test_refresh_lets_the_kept_tune_go() -> void:
	_write(SKIN_DIR, "music_location_1.wav")
	var first := MusicLibrary.stream("music_location_1")
	MusicLibrary.refresh()
	assert_not_same(MusicLibrary.stream("music_location_1"), first,
		"looking again at the folders reads again")


func test_an_unknown_tune_is_still_silence() -> void:
	assert_null(MusicLibrary.stream("music_location_1"), "nothing imported here")
	_write(SKIN_DIR, "music_location_1.wav")
	assert_not_null(MusicLibrary.stream("music_location_1"))
	assert_null(MusicLibrary.stream("no_such_tune"))


func test_the_builder_s_bed_is_read_once_across_openings() -> void:
	_write(SKIN_DIR, "music_location_1.wav")
	var beds: Array[AudioStream] = []
	for i in 2:
		var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
		add_child(screen)
		await get_tree().process_frame
		screen._music.silent = false
		screen._apply_music_switch()
		assert_eq(screen._music.tracks, ["music_location_1"] as Array[String], "the bed is up")
		var playlist := screen._music.stream as AudioStreamPlaylist
		assert_not_null(playlist)
		if playlist != null:
			beds.append(playlist.get_list_stream(0))
		screen._music.stop_music()
		screen.queue_free()
		await get_tree().process_frame
	assert_eq(beds.size(), 2)
	if beds.size() == 2:
		assert_same(beds[1], beds[0], "the second opening plays the tune the first one read")
