extends GutTest
## FILES FROM OUTSIDE, AND FILES LEFT BEHIND (campaign of 2026-11-26).
##
##   * A zip with two lists of files showed the size guard one list and the
##     engine's reader the other, and was unpacked past every bound (save
##     Import, every card pack): [method PortalPack.bounded_zip] now takes
##     only a zip with one list a reader can find.
##   * settings.cfg could make the engine load a resource (and run the
##     script in it) while it was read: [method Settings.safe_text].
##   * Pending files of an interrupted write stayed for good:
##     [method Settings.sweep_pending].
##   * A tar's long-name entry was gathered whole whatever its size, and one
##     step of a tar that packs a thousandfold took over a second: [TarPack].
##   * A photo as a portrait was kept at its full size: [PortraitLibrary].
##   * The copy that makes a game portable could not be stopped, and a
##     folder in the making was left for good: [PortableMode].
##   * The recordings folder grew without bound: [MpnArchive].

const DIR := "user://c1126_files"
const SETTINGS := "user://settings.cfg"
const MB := 1024 * 1024

var _had := false
var _old := PackedByteArray()


func before_all() -> void:
	Settings.flush()
	_had = FileAccess.file_exists(SETTINGS)
	if _had:
		_old = FileAccess.get_file_as_bytes(SETTINGS)


func before_each() -> void:
	_wipe(DIR)
	DirAccess.make_dir_recursive_absolute(DIR)


func after_each() -> void:
	Engine.print_error_messages = true
	_wipe(DIR)
	PortableMode.available_override = -1
	PortableMode.folder_override = ""


func after_all() -> void:
	_restore_settings()


func _restore_settings() -> void:
	if _had:
		Settings.write_atomically(SETTINGS, _old)
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("settings.cfg.bad"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + name))
	Settings.reload_file()


## Delete [param dir], which must be this test's own.
static func _wipe(dir: String) -> void:
	if not dir.contains("c1126_files") or not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	here.include_hidden = true
	for sub in here.get_directories():
		_wipe(dir.path_join(sub))
	for name in here.get_files():
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


static func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


# ------------------------------------------------------------- the zips --

static func _local(name: String, packed: PackedByteArray, crc: int, usize: int) -> PackedByteArray:
	var n := name.to_utf8_buffer()
	var h := PackedByteArray()
	h.resize(30)
	h.encode_u32(0, 0x04034b50)
	h.encode_u16(4, 20)
	h.encode_u16(8, 8)
	h.encode_u32(14, crc)
	h.encode_u32(18, packed.size())
	h.encode_u32(22, usize)
	h.encode_u16(26, n.size())
	h.append_array(n)
	h.append_array(packed)
	return h


static func _row(name: String, packed_size: int, crc: int, usize: int, at: int) -> PackedByteArray:
	var n := name.to_utf8_buffer()
	var h := PackedByteArray()
	h.resize(46)
	h.encode_u32(0, 0x02014b50)
	h.encode_u16(4, 20)
	h.encode_u16(6, 20)
	h.encode_u16(10, 8)
	h.encode_u32(16, crc)
	h.encode_u32(20, packed_size)
	h.encode_u32(24, usize)
	h.encode_u16(28, n.size())
	h.encode_u32(42, at)
	h.append_array(n)
	return h


static func _end(count: int, dir_size: int, dir_at: int, comment: PackedByteArray) -> PackedByteArray:
	var e := PackedByteArray()
	e.resize(22)
	e.encode_u32(0, 0x06054b50)
	e.encode_u16(8, count)
	e.encode_u16(10, count)
	e.encode_u32(12, dir_size)
	e.encode_u32(16, dir_at)
	e.encode_u16(20, comment.size())
	e.append_array(comment)
	return e


## A zip of two lists: the first (the one whose end record's comment
## reaches the file's end) names [param small]; the second, inside that
## comment and found by the engine's reader, names [param big].
static func _two_lists(path: String, name: String, small: PackedByteArray, big: PackedByteArray) -> void:
	var a: Array = PackWriter.deflated(small)
	var b: Array = PackWriter.deflated(big)
	var out := PackedByteArray()
	out.append_array(_local(name, a[1], a[0], small.size()))
	var at_b := out.size()
	out.append_array(_local(name, b[1], b[0], big.size()))
	var dir_a_at := out.size()
	var dir_a := _row(name, (a[1] as PackedByteArray).size(), a[0], small.size(), 0)
	out.append_array(dir_a)
	var dir_b := _row(name, (b[1] as PackedByteArray).size(), b[0], big.size(), at_b)
	var comment := PackedByteArray()
	comment.append_array(dir_b)
	comment.append_array(_end(1, dir_b.size(), out.size() + 22, PackedByteArray()))
	comment.append(0x20)
	out.append_array(_end(1, dir_a.size(), dir_a_at, comment))
	_write(path, out)


## One honest entry, the plain zip a builder writes.
static func _one_list(path: String, name: String, body: PackedByteArray, comment := PackedByteArray()) -> void:
	var a: Array = PackWriter.deflated(body)
	var out := _local(name, a[1], a[0], body.size())
	var dir_at := out.size()
	var dir := _row(name, (a[1] as PackedByteArray).size(), a[0], body.size(), 0)
	out.append_array(dir)
	out.append_array(_end(1, dir.size(), dir_at, comment))
	_write(path, out)


func test_a_zip_of_two_lists_does_not_pass_the_size_guard() -> void:
	var big := PackedByteArray()
	big.resize(9 * MB)       # past the guard's 8 MiB an entry
	big.fill(0x20)
	var path := DIR.path_join("two.zip")
	_two_lists(path, "manifest.json", "{}".to_utf8_buffer(), big)
	# What made it a finding: the engine's reader sees the big entry.
	var reader := ZIPReader.new()
	assert_eq(reader.open(path), OK, "the engine opens it")
	assert_eq(Array(reader.get_files()), ["manifest.json"])
	reader.close()
	assert_false(PortalPack.bounded_zip(path, 27, 128 * MB), "two lists: refused before anything is unpacked")
	var before := OS.get_static_memory_peak_usage()
	var read := AdventureTransfer.read_package(path, "two.zip")
	assert_false(bool(read.get("ok", false)), "the save import refuses it")
	assert_lt(OS.get_static_memory_peak_usage() - before, 4 * MB, "and unpacked nothing of the 9 MB entry")


func test_every_pack_guard_is_the_shared_one() -> void:
	var big := PackedByteArray()
	big.resize(9 * MB)
	big.fill(0x20)
	var path := DIR.path_join(FifthEditionPack.FILE_NAME)
	_two_lists(path, "a.txt", "{}".to_utf8_buffer(), big)
	assert_false(FifthEditionPack._bounded_zip(path), "Pack 7 kept a copy of the guard")
	assert_false(bool(FifthEditionPack.inspect(path).get("ok", true)))
	var six := DIR.path_join(PortalPack.FILE_NAME)
	DirAccess.copy_absolute(path, six)
	assert_false(PortalPack._bounded_zip(six))
	var one := DIR.path_join(CardPacks.FILE_NAME)
	DirAccess.copy_absolute(path, one)
	assert_false(bool(CardPacks.inspect(one, false).get("ok", true)), "Pack 1 goes through the same guard")


func test_a_plain_zip_still_passes_with_or_without_a_comment() -> void:
	var plain := DIR.path_join("plain.zip")
	_one_list(plain, "a.txt", "hello".to_utf8_buffer())
	assert_true(PortalPack.bounded_zip(plain, 4))
	var noted := DIR.path_join("noted.zip")
	_one_list(noted, "a.txt", "hello".to_utf8_buffer(), "made by hand".to_utf8_buffer())
	assert_true(PortalPack.bounded_zip(noted, 4), "a comment that names no second list is fine")
	var packed := DIR.path_join("packed.zip")
	var packer := ZIPPacker.new()
	assert_eq(packer.open(packed), OK)
	packer.start_file("skin/a.txt")
	packer.write_file("hello".to_utf8_buffer())
	packer.close_file()
	packer.close()
	assert_true(PortalPack.bounded_zip(packed, 4), "the engine's own writer's zip")


func test_a_zip64_record_behind_the_list_is_refused() -> void:
	# A zip64 end record and its locator in the comment: the engine's
	# reader looks for those before the classic record.
	var body := "hello".to_utf8_buffer()
	var a: Array = PackWriter.deflated(body)
	var out := _local("a.txt", a[1], a[0], body.size())
	var dir_at := out.size()
	var dir := _row("a.txt", (a[1] as PackedByteArray).size(), a[0], body.size(), 0)
	out.append_array(dir)
	var end64_at := out.size() + 22
	var comment := PackedByteArray()
	comment.resize(56 + 20)
	comment.encode_u32(0, 0x06064b50)
	comment.encode_u32(56, 0x07064b50)
	comment.encode_s64(56 + 8, end64_at)
	out.append_array(_end(1, dir.size(), dir_at, comment))
	var path := DIR.path_join("z64.zip")
	_write(path, out)
	assert_false(PortalPack.bounded_zip(path, 4))


# ---------------------------------------------------------- settings.cfg --

func test_text_made_safe_keeps_every_string_and_breaks_every_object() -> void:
	var honest := "[options]\n\ndeck=\"Lost Object(s) and a Resource (\\\"x\\\")\"\nfolder=\"C:\\\\Resource(1)\\\\x\"\nvolume=0.5\n"
	var read := ConfigFile.new()
	assert_eq(read.parse(Settings.safe_text(honest)), OK)
	assert_eq(read.get_value("options", "deck"), "Lost Object(s) and a Resource (\"x\")", "a string reads as it was written")
	assert_eq(read.get_value("options", "folder"), "C:\\Resource(1)\\x")
	assert_eq(Settings.safe_text("[options]\nvolume=0.5\n"), "[options]\nvolume=0.5\n", "nothing to change, nothing changed")
	Engine.print_error_messages = false
	for hostile: String in ["a=Resource(\"user://x.tres\")", "a=Resource ; note\n  (\"user://x.tres\")",
			"a=[SubResource(\"1\")]", "a={\"k\": ExtResource(\"1\")}", "a=Object(Node,\"name\":\"x\")",
			"[a\"]\nb=Resource(\"user://x.tres\")", "a=\"\\\\\"\nb=Resource(\"user://x.tres\")"]:
		var made := ConfigFile.new()
		var err := made.parse(Settings.safe_text("[options]\n" + hostile + "\n"))
		var objects := 0
		for section in made.get_sections():
			for key in made.get_section_keys(section):
				if typeof(made.get_value(section, key)) == TYPE_OBJECT:
					objects += 1
				elif made.get_value(section, key) is Array or made.get_value(section, key) is Dictionary:
					objects += 1 if str(made.get_value(section, key)).contains("Object#") else 0
		assert_ne(err, OK, "does not parse: " + hostile)
		assert_eq(objects, 0, "and made nothing: " + hostile)
	Engine.print_error_messages = true


## A resource whose script writes [param marker] when it is made, and a
## settings file that names it.
func _hostile_settings(marker: String) -> String:
	var tres := DIR.path_join("evil.tres")
	_write(tres, ("[gd_resource type=\"Resource\" format=3]\n\n[sub_resource type=\"GDScript\" id=\"1\"]\n"
		+ "script/source = \"extends Resource\nfunc _init():\n\tvar f = FileAccess.open(\\\"" + marker + "\\\", FileAccess.WRITE)\n"
		+ "\tf.store_string(\\\"ran\\\")\n\tf.close()\n\"\n\n[resource]\nscript = SubResource(\"1\")\n").to_utf8_buffer())
	return "[options]\n\nhand_style=\"stack\"\nskin_zip=Resource(\"%s\")\nai_pace=0.25\n" % tres


func test_a_settings_file_that_names_a_resource_runs_nothing_and_is_kept_aside() -> void:
	var marker := DIR.path_join("ran.txt")
	var text := _hostile_settings(marker)
	# The fixture is live: the engine's own reader runs the script.
	var plain := ConfigFile.new()
	plain.parse(text)
	assert_true(FileAccess.file_exists(marker), "the fixture runs its script when read as it is")
	plain = null
	DirAccess.remove_absolute(marker)
	_write(SETTINGS, text.to_utf8_buffer())
	Engine.print_error_messages = false
	Settings.reload_file()
	var style: Variant = Settings.get_value("hand_style", "fan")
	var zip: Variant = Settings.get_value("skin_zip", null)
	Engine.print_error_messages = true
	assert_false(FileAccess.file_exists(marker), "nothing ran")
	assert_eq(style, "stack", "the keys above the line are read")
	assert_ne(typeof(zip), TYPE_OBJECT, "no object reached the settings")
	assert_eq(FileAccess.get_file_as_string(SETTINGS + ".bad"), text, "the file is kept aside as any that will not parse")
	assert_string_contains(Settings.problem(), "settings.cfg.bad")
	_restore_settings()


func test_a_settings_file_changed_under_the_game_runs_nothing_either() -> void:
	var marker := DIR.path_join("ran.txt")
	Settings.write_atomically(SETTINGS, "[options]\nhand_style=\"fan\"\n".to_utf8_buffer())
	Settings.reload_file()
	# Another resource file: the engine keeps one it has loaded.
	var text := _hostile_settings(marker).replace("evil.tres", "evil2.tres")
	DirAccess.rename_absolute(DIR.path_join("evil.tres"), DIR.path_join("evil2.tres"))
	_write(SETTINGS, text.to_utf8_buffer())
	Engine.print_error_messages = false
	Settings.set_value("ai_pace", 0.5)
	Engine.print_error_messages = true
	assert_false(FileAccess.file_exists(marker), "nothing ran at the save's re-read")
	assert_eq(FileAccess.get_file_as_string(SETTINGS + ".bad"), text)
	_restore_settings()


# ------------------------------------------------------- pending files --

func test_old_pending_files_are_swept_and_nothing_else_is() -> void:
	var now := Time.get_unix_time_from_system()
	var names := ["a.json.tmp.123.45", "settings.cfg.tmp.7.8", "a.json", "a.json.tmp", "a.tmp.12.x",
		"a.tmp.12", "a.tmp.1.2.3", "notes.tmp.12.34.txt"]
	for name: String in names:
		_write(DIR.path_join(name), "x".to_utf8_buffer())
	DirAccess.make_dir_recursive_absolute(DIR.path_join("folder.tmp.1.2"))
	for name: String in names:
		assert_eq(Settings.is_pending_name(name), name in ["a.json.tmp.123.45", "settings.cfg.tmp.7.8"], name)
	assert_eq(Settings.sweep_pending(DIR, now), 0, "written this minute: another instance may be at it")
	assert_eq(Settings.sweep_pending(DIR, now + 23 * 3600), 0, "not yet a day")
	assert_eq(Settings.sweep_pending(DIR, now + 25 * 3600), 2, "a day on, the two pending files go")
	var left := Array(DirAccess.get_files_at(DIR))
	left.sort()
	var expected := names.filter(func(name: String) -> bool: return not Settings.is_pending_name(name))
	expected.sort()
	assert_eq(left, expected, "every other file stays")
	assert_true(DirAccess.dir_exists_absolute(DIR.path_join("folder.tmp.1.2")), "a folder of such a name stays")
	assert_eq(Settings.pending_path(DIR.path_join("a.json")).get_file().begins_with("a.json.tmp."), true)
	assert_true(Settings.is_pending_name(Settings.pending_path(DIR.path_join("a.json")).get_file()),
		"the name a write takes is the name the sweep knows")


func test_the_start_sweep_reaches_the_games_folders() -> void:
	var saves := "user://adventures"
	var made_saves := not DirAccess.dir_exists_absolute(saves)
	DirAccess.make_dir_recursive_absolute(saves)
	var stale := saves.path_join("c1126_files.autosave.json.tmp.99999.1")
	var root := "user://c1126_files.cfg.tmp.99999.2"
	_write(stale, "x".to_utf8_buffer())
	_write(root, "x".to_utf8_buffer())
	assert_eq(GamePaths.sweep_pending(), 0, "fresh ones stay")
	assert_true(FileAccess.file_exists(stale))
	assert_gte(GamePaths.sweep_pending(Time.get_unix_time_from_system() + 25 * 3600), 2)
	assert_false(FileAccess.file_exists(stale), "the saves folder")
	assert_false(FileAccess.file_exists(root), "and the game's own folder")
	if made_saves:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saves))


# ---------------------------------------------------------------- tars --

static func _tar_header(name: String, size: int, type: String) -> PackedByteArray:
	var h := PackedByteArray()
	h.resize(512)
	var n := name.to_ascii_buffer()
	for i in n.size():
		h[i] = n[i]
	var digits := ("%011o" % size).to_ascii_buffer()
	for i in digits.size():
		h[124 + i] = digits[i]
	h[156] = type.unicode_at(0)
	for i in 5:
		h[257 + i] = "ustar".unicode_at(i)
	return h


static func _padded(body: PackedByteArray) -> PackedByteArray:
	var out := body.duplicate()
	out.resize(body.size() + (512 - body.size() % 512) % 512)
	return out


func test_a_tar_long_name_entry_past_the_bound_is_refused() -> void:
	var size := 4 * MB
	var tar := _tar_header("././@LongLink", size, "L")
	var body := PackedByteArray()
	body.resize(size)
	tar.append_array(body)
	tar.append_array(_tar_header("skin/a.png", 4, "0"))
	tar.append_array(_padded(PackedByteArray([1, 2, 3, 4])))
	tar.append_array(_padded(PackedByteArray([0])))
	tar.append_array(_padded(PackedByteArray([0])))
	var from := DIR.path_join("long.tar.gz")
	_write(from, tar.compress(FileAccess.COMPRESSION_GZIP))
	var report := TarPack.convert(from, DIR.path_join("long.zip"))
	assert_false(bool(report["ok"]), "a 4 MB name is no name")
	assert_eq(String(report["why"]), "has a header the game cannot read")
	assert_false(FileAccess.file_exists(DIR.path_join("long.zip")), "and no half zip is left")


func test_a_long_name_of_an_honest_length_still_names_its_file() -> void:
	var long_name := "skin/" + "d".repeat(180) + "/a.png"
	var name_body := long_name.to_ascii_buffer() + PackedByteArray([0])
	var tar := _tar_header("././@LongLink", name_body.size(), "L")
	tar.append_array(_padded(name_body))
	tar.append_array(_tar_header("skin/short", 4, "0"))
	tar.append_array(_padded(PackedByteArray([1, 2, 3, 4])))
	tar.append_array(_padded(PackedByteArray([0])))
	tar.append_array(_padded(PackedByteArray([0])))
	var from := DIR.path_join("name.tar.gz")
	_write(from, tar.compress(FileAccess.COMPRESSION_GZIP))
	var report := TarPack.convert(from, DIR.path_join("name.zip"))
	assert_true(bool(report["ok"]), String(report["why"]))
	var reader := ZIPReader.new()
	assert_eq(reader.open(DIR.path_join("name.zip")), OK)
	var listed := reader.get_files()
	assert_true(listed.has(long_name), "under the long name, not the header's short one")
	assert_false(listed.has("skin/short"))
	assert_eq(reader.read_file(long_name), PackedByteArray([1, 2, 3, 4]))
	reader.close()


func test_one_step_of_a_tar_that_packs_a_thousandfold_is_short() -> void:
	# 96 MB of zeros in one file entry: some 100 KB gzipped, one chunk.
	var size := 96 * MB
	var tar := _tar_header("skin/zeros.bin", size, "0")
	var body := PackedByteArray()
	body.resize(size)
	tar.append_array(body)
	body = PackedByteArray()
	tar.append_array(_padded(PackedByteArray([0])))
	tar.append_array(_padded(PackedByteArray([0])))
	var from := DIR.path_join("zeros.tar.gz")
	var packed := tar.compress(FileAccess.COMPRESSION_GZIP)
	tar = PackedByteArray()
	_write(from, packed)
	assert_lt(packed.size(), TarPack.CHUNK, "the whole tar is one chunk of input")
	var job := TarPack.new()
	assert_true(job.open(from, DIR.path_join("zeros.zip")))
	var steps := 0
	var worst := 0
	var started := Time.get_ticks_msec()
	while true:
		var at := Time.get_ticks_msec()
		var more := job.step()
		worst = maxi(worst, Time.get_ticks_msec() - at)
		steps += 1
		if not more:
			break
	gut.p("zeros tar: %d steps, worst %d ms, all %d ms, %d bytes on disk" % [steps, worst,
		Time.get_ticks_msec() - started, packed.size()])
	assert_true(job.ok, job.why)
	assert_eq(job.files, 1)
	assert_gt(steps, 4, "the one chunk is worked through in several steps")
	assert_lt(worst, 250, "and none of them is the whole file (it was one step of over a second)")
	var reader := ZIPReader.new()
	assert_eq(reader.open(DIR.path_join("zeros.zip")), OK)
	assert_eq(reader.read_file("skin/zeros.bin").size(), size, "every byte arrived")
	reader.close()


# ----------------------------------------------------------- portraits --

func test_a_photo_as_a_portrait_is_worn_small_and_only_so_many_are_kept() -> void:
	var folder := DIR.path_join("faces")
	DirAccess.make_dir_recursive_absolute(folder)
	var photo := Image.create(4000, 3000, false, Image.FORMAT_RGB8)
	photo.fill(Color(0.4, 0.5, 0.6))
	for i in 3:
		photo.save_jpg(folder.path_join("photo_%d.jpg" % i), 0.8)
	var small := Image.create(120, 150, false, Image.FORMAT_RGBA8)
	small.fill(Color(1, 0, 0))
	small.save_png(folder.path_join("small.png"))
	var tall := Image.create(600, 1500, false, Image.FORMAT_RGBA8)
	tall.save_png(folder.path_join("tall.png"))
	var kept := PortraitLibrary.dirs.duplicate()
	PortraitLibrary.dirs = [folder] as Array[String]
	PortraitLibrary.refresh()
	var before := OS.get_static_memory_usage()
	var started := Time.get_ticks_msec()
	var first := PortraitLibrary.texture("photo_0")
	var took := Time.get_ticks_msec() - started
	assert_not_null(first)
	assert_eq(Vector2i(first.get_size()), Vector2i(1024, 768), "the longer side brought to 1024, the shape kept")
	gut.p("portrait: 4000x3000 photo first shown in %d ms, memory +%d KB" % [took,
		(OS.get_static_memory_usage() - before) / 1024])
	assert_eq(Vector2i(PortraitLibrary.texture("small").get_size()), Vector2i(120, 150), "a small face is untouched")
	assert_eq(Vector2i(PortraitLibrary.texture("tall").get_size()), Vector2i(410, 1024))
	assert_same(PortraitLibrary.texture("photo_0"), first, "kept: the second showing reads nothing")
	# The warmed road ([method PortraitLibrary.keep_face]) bounds it too.
	var job := PortraitLibrary.face_job("photo_1")
	GameSkin.decode_picture(job)
	assert_eq(Vector2i(PortraitLibrary.keep_face(job).get_size()), Vector2i(1024, 768))
	# Past the bound the face shown longest ago goes, never the newest.
	PortraitLibrary.texture("photo_0")
	var third := PortraitLibrary.texture("photo_2")
	PortraitLibrary._keep_own("giant", _Sized.new(4096, 4096))    # 64 MiB by itself
	assert_true(PortraitLibrary._textures.has("giant"), "the one just made is kept")
	assert_false(PortraitLibrary._textures.has("photo_1"), "the one shown longest ago went")
	assert_false(PortraitLibrary._textures.has("photo_2"))
	assert_not_null(third)
	assert_eq(Vector2i(PortraitLibrary.texture("photo_1").get_size()), Vector2i(1024, 768), "and is read again when asked for")
	PortraitLibrary.dirs = kept
	PortraitLibrary.refresh()


class _Sized extends Texture2D:
	var _w := 0
	var _h := 0
	func _init(w: int, h: int) -> void:
		_w = w
		_h = h
	func _get_width() -> int:
		return _w
	func _get_height() -> int:
		return _h


# ------------------------------------------------------------ portable --

func test_the_portable_copy_can_be_stopped() -> void:
	var from := ProjectSettings.globalize_path(DIR.path_join("from"))
	var to := ProjectSettings.globalize_path(DIR.path_join("game/portable-making/godot/app_userdata/Shandalar"))
	for i in 40:
		_write(from.path_join("decks/d%02d.deck" % i), "x".repeat(2000).to_utf8_buffer())
	var job := PortableMode.start_copy(from, to, false)
	assert_eq(String(job.progress()["error"]), "", "a whole copy still arrives")
	assert_eq(int(job.progress()["files"]), 40)
	assert_false(bool(job.progress()["cancelled"]))
	# Stopped before its first file: nothing copied, and it says so.
	var stopped := PortableMode.Copy.new()
	stopped.from = from
	stopped.to = ProjectSettings.globalize_path(DIR.path_join("game/portable-making-2/godot/app_userdata/Shandalar"))
	stopped.files.assign(PortableMode.measure(from)["files"])
	stopped.cancel()
	stopped.run()
	var p := stopped.progress()
	assert_true(bool(p["finished"]) and bool(p["cancelled"]))
	assert_eq(int(p["files"]), 0)
	assert_ne(String(p["error"]), "", "a stopped copy is not a whole one")
	# On a worker: stop_copies stops and waits for whatever runs.
	var threaded := PortableMode.start_copy(from, stopped.to)
	var were := PortableMode.stop_copies()
	assert_true(were.has(threaded))
	assert_true(bool(threaded.progress()["finished"]), "waited for")
	assert_true(PortableMode._running.is_empty())


func test_a_folder_left_in_the_making_is_cleared_at_the_next_start() -> void:
	var game := ProjectSettings.globalize_path(DIR.path_join("game"))
	var user_dir := "/home/somebody/.local/share/godot/app_userdata/Shandalar"
	var ours := game.path_join("portable-making/godot/app_userdata/Shandalar/decks/a.deck")
	var ours_2 := game.path_join("portable-making-2/godot/app_userdata/Shandalar/settings.cfg")
	_write(ours, "x".to_utf8_buffer())
	_write(ours_2, "x".to_utf8_buffer())
	DirAccess.make_dir_recursive_absolute(game.path_join("portable-making-3"))          # empty: ours too
	_write(game.path_join("portable-making-4/notes.txt"), "mine".to_utf8_buffer())      # a file at its top: not ours
	_write(game.path_join("portable-making-5/godot/x.txt"), "x".to_utf8_buffer())
	_write(game.path_join("portable-making-5/other/x.txt"), "x".to_utf8_buffer())       # two folders: not ours
	_write(game.path_join("portable-making-old/godot/x.txt"), "x".to_utf8_buffer())     # no such name
	_write(game.path_join("portable-off/godot/app_userdata/Shandalar/settings.cfg"), "kept".to_utf8_buffer())
	_write(game.path_join("my-making/godot/x.txt"), "x".to_utf8_buffer())
	var found := PortableMode.stale_making(game.path_join("portable"), "linux", user_dir)
	found.sort()
	assert_eq(Array(found), [game.path_join("portable-making"), game.path_join("portable-making-2"),
		game.path_join("portable-making-3")])
	assert_eq(PortableMode.stale_making(game.path_join("portable"), "macos", user_dir).size(), 1,
		"a Mac's copy starts with Library, so only the empty one is its own")
	PortableMode.available_override = 1
	PortableMode.folder_override = game.path_join("portable")
	if PortableMode.platform() == "linux":
		assert_eq(PortableMode.clear_stale_making(), 3)
		for gone in ["portable-making", "portable-making-2", "portable-making-3"]:
			assert_false(DirAccess.dir_exists_absolute(game.path_join(gone)), gone)
		for stays in ["portable-making-4/notes.txt", "portable-making-5/godot/x.txt", "portable-making-old/godot/x.txt",
				"portable-off/godot/app_userdata/Shandalar/settings.cfg", "my-making/godot/x.txt"]:
			assert_true(FileAccess.file_exists(game.path_join(stays)), stays)
		assert_eq(PortableMode.making_name(game.path_join("portable")), game.path_join("portable-making"),
			"and the next try takes the first name again")
	else:
		pass_test("the removal is checked where the test's fixture is the platform's shape")


# ---------------------------------------------------------- recordings --

static func _recording(folder: String, stamp: String, bytes: int) -> String:
	var path := folder.path_join("%s-%s.mpn" % [stamp, MpnArchive.new_id()])
	_write(path, "x".repeat(bytes).to_utf8_buffer())
	return path


func test_the_recordings_folder_keeps_the_newest_and_never_a_file_of_another_name() -> void:
	var folder := DIR.path_join("records")
	var paths: Array[String] = []
	for day in range(1, 9):
		paths.append(_recording(folder, "202611%02dT120000Z" % day, 1000))
	var imported := folder.path_join("import-" + MpnArchive.new_id() + ".mpn")
	_write(imported, "x".to_utf8_buffer())
	var own := folder.path_join("my best game.mpn")
	_write(own, "x".to_utf8_buffer())
	_write(folder.path_join("notes.txt"), "x".to_utf8_buffer())
	assert_true(MpnArchive.is_recorded_name(paths[0].get_file()))
	for other: String in ["import-0123456789abcdef01234567.mpn", "my best game.mpn",
			"20261101T120000Z-0123456789abcdef0123456g.mpn", "20261101X120000Z-0123456789abcdef01234567.mpn",
			"20261101T120000Z-0123456789abcdef01234567.txt"]:
		assert_false(MpnArchive.is_recorded_name(other), other)
	assert_eq(MpnArchive.prune(folder), 0, "within the bound nothing goes")
	assert_eq(MpnArchive.prune(folder, 5, 1 << 30), 3, "the three oldest go")
	for i in 8:
		assert_eq(FileAccess.file_exists(paths[i]), i >= 3, "day %d" % (i + 1))
	assert_eq(MpnArchive.prune(folder, 100, 2500), 3, "and by size: two of 1000 bytes fit in 2500")
	assert_true(FileAccess.file_exists(paths[7]) and FileAccess.file_exists(paths[6]))
	assert_eq(MpnArchive.prune(folder, 0, 0, paths[6]), 1, "the one being written is never removed")
	assert_true(FileAccess.file_exists(paths[6]))
	for kept: String in [imported, own, folder.path_join("notes.txt")]:
		assert_true(FileAccess.file_exists(kept), kept.get_file())
	# Delete: one file of the folder, and nothing outside it.
	var outside := DIR.path_join("elsewhere.mpn")
	_write(outside, "x".to_utf8_buffer())
	assert_false(MpnArchive.delete(outside, folder), "not in the folder")
	assert_false(MpnArchive.delete(folder.path_join("../elsewhere.mpn"), folder))
	assert_false(MpnArchive.delete(folder.path_join("notes.txt"), folder), "not a recording")
	assert_true(MpnArchive.delete(own, folder))
	assert_false(FileAccess.file_exists(own))
	assert_eq(MpnArchive.delete_all(folder), 2, "the recording and the imported one")
	assert_true(FileAccess.file_exists(outside) and FileAccess.file_exists(folder.path_join("notes.txt")))
	assert_eq(MpnArchive.KEEP_RECORDS, 500)
	assert_eq(MpnArchive.KEEP_BYTES, 64 * MB)
