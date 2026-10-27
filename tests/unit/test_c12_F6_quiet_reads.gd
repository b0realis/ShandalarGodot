extends GutTest
## DAMAGED FILES READ QUIETLY, AND ONCE (the bug campaign c12, h6-9).
##
##   * A damaged `pack_seals.json` printed "Parse JSON failed" — an engine
##     ERROR — on every [method PackSeal.sealed] / [method PackSeal.refusal]
##     call: 56 of them at one start. Now it is parsed once per content,
##     quietly. The run fails on any ERROR line, and the test counts the
##     ones the error tracker sees.
##   * A broken picture or tune of the player's own printed the engine's
##     ERRORs every time it was asked for. Now it is remembered as failed
##     while the file is unchanged ([member GameSkin._unreadable],
##     [member MusicLibrary._unreadable]). The first failing read is the
##     engine's own and is kept off the log here (as
##     tests/unit/test_bug_pass_2026_10_03_shell_io.gd does); whether the
##     file is read again is told by a GOOD file put in its place within
##     the same second: a game that read it again would have found it.

const SCRATCH := "user://test_c12_f6_quiet_reads"

var _seals_existed := false
var _seals_backup := PackedByteArray()


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	_seals_existed = FileAccess.file_exists(PackSeal.FILE)
	if _seals_existed:
		_seals_backup = FileAccess.get_file_as_bytes(PackSeal.FILE)
	MusicLibrary.dirs = [SCRATCH]
	MusicLibrary.skin_dirs = []
	MusicLibrary.refresh()


func after_each() -> void:
	Engine.print_error_messages = true
	if _seals_existed:
		var file := FileAccess.open(PackSeal.FILE, FileAccess.WRITE)
		file.store_buffer(_seals_backup)
		file.close()
	else:
		PackSeal.clear()
	MusicLibrary.dirs = [GamePaths.music_folder()]
	MusicLibrary.skin_dirs = null
	MusicLibrary.refresh()
	GameSkin.clear_caches()
	for name in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(name))
	DirAccess.remove_absolute(SCRATCH)


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## A real, minimal PCM wav: 22 050 Hz, mono, 16-bit, [param frames] long.
static func _wav(frames: int) -> PackedByteArray:
	var out := PackedByteArray()
	var data := frames * 2
	out.append_array("RIFF".to_ascii_buffer())
	out.append_array(_u32(36 + data))
	out.append_array("WAVEfmt ".to_ascii_buffer())
	out.append_array(_u32(16))
	out.append_array(PackedByteArray([1, 0, 1, 0]))
	out.append_array(_u32(22050))
	out.append_array(_u32(44100))
	out.append_array(PackedByteArray([2, 0, 16, 0]))
	out.append_array("data".to_ascii_buffer())
	out.append_array(_u32(data))
	out.resize(out.size() + data)
	return out


static func _u32(value: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, value)
	return out


# ----------------------------------------------------------- the seals --

func test_a_damaged_seal_list_is_read_quietly() -> void:
	_write(PackSeal.FILE, "{\"seals\": [\"abc\", ".to_utf8_buffer())
	for i in 30:
		assert_false(PackSeal.sealed("abc"), "a damaged list holds no seal")
		assert_eq(PackSeal.refusal("abc"), "")
	assert_engine_error_count(0, "no engine error for a damaged list, however often it is asked")


func test_the_list_is_read_again_when_it_changes() -> void:
	_write(PackSeal.FILE, "not json at all".to_utf8_buffer())
	assert_false(PackSeal.sealed("abc"))
	PackSeal.seal("abc")
	assert_true(PackSeal.sealed("abc"), "the next write heals it, and the new list is read")
	PackSeal.refuse("def", "damaged")
	assert_eq(PackSeal.refusal("def"), "damaged")
	assert_true(PackSeal.sealed("abc"))
	assert_engine_error_count(0)


# ------------------------------------------------------ pictures, tunes --

func test_a_broken_picture_is_not_read_again_while_unchanged() -> void:
	for attempt in 3:
		var path := ProjectSettings.globalize_path(SCRATCH.path_join("face_%d.png" % attempt))
		_write(path, "not a picture".to_utf8_buffer())
		Engine.print_error_messages = false
		var first := GameSkin.picture(path)
		Engine.print_error_messages = true
		assert_null(first, "a broken picture is no picture")
		var stamp := FileAccess.get_modified_time(path)
		var good := Image.create(4, 6, false, Image.FORMAT_RGBA8)
		good.fill(Color.RED)
		_write(path, good.save_png_to_buffer())
		if FileAccess.get_modified_time(path) != stamp:
			continue   # the second turned between the writes: try again
		assert_null(GameSkin.picture(path), "not asked of the engine again while its time is the same")
		GameSkin.clear_caches()
		assert_not_null(GameSkin.picture(path), "forgotten with the caches, and read afresh")
		return
	pass_test("the clock turned a second between every pair of writes")


func test_a_broken_tune_is_not_read_again_while_unchanged() -> void:
	for attempt in 3:
		var name := "march_%d" % attempt
		var path := SCRATCH.path_join(name + ".wav")
		_write(path, "not a tune".to_utf8_buffer())
		MusicLibrary.refresh()
		Engine.print_error_messages = false
		var first := MusicLibrary.stream(name)
		Engine.print_error_messages = true
		assert_null(first, "a broken tune is silence")
		var stamp := FileAccess.get_modified_time(path)
		_write(path, _wav(256))
		if FileAccess.get_modified_time(path) != stamp:
			continue
		assert_null(MusicLibrary.stream(name), "not asked of the engine again while its time is the same")
		MusicLibrary.refresh()
		assert_not_null(MusicLibrary.stream(name), "forgotten with the library, and read afresh")
		return
	pass_test("the clock turned a second between every pair of writes")
