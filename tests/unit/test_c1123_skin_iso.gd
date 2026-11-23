extends GutTest
## THE SKIN BUILT FROM A CD IMAGE (builders 2026-11-23; the owner: *"Can
## skin be built also from 1997 Shandalar CD or its iso image?"*, *"Yes
## choose iso add it."*) — the reader of images ([SkinIsoImage]) and the
## index, the check and the build reading through it. Every image is made
## in the test by a writer written apart from the reader ([C1123SkinIso]),
## of made-up files. What these hold:
##
##   1. A plain image, a Joliet one, raw sectors of both modes and a `.cue`
##      are read, a file found whatever its case and read back whole.
##   2. A hostile image — cut short, pointing past its end or back at
##      itself, with records that lie about their length, with a hundred
##      thousand files — is refused or bounded, never a crash or a hang.
##   3. A `.cue` is followed to the image beside it and nowhere else.
##   4. An image is a source like a folder: the first source wins, the
##      check says what it is, and the build from it gives the same zip
##      as the build from the folder it was made of.

const F := preload("res://tests/support/c1123_skin_fixtures.gd")
const ISO := preload("res://tests/support/c1123_skin_iso.gd")
const SCRATCH := "user://test_c1123_skin_iso"

var root := ""


func before_each() -> void:
	root = ProjectSettings.globalize_path(SCRATCH)
	F.remove_tree(root)
	DirAccess.make_dir_recursive_absolute(root)


func after_each() -> void:
	F.remove_tree(root)


## A few made-up files: nested, long-named, one over several sectors.
func _files() -> Dictionary:
	return {
		"Title.pic": F.noise(300, 1),
		"README": F.noise(10, 2),
		"Sound/Dueltune.wav": F.noise(5000, 3),
		"Statwin/Blu-Sprt.bmp": F.noise(2048, 4),
		"Duelart/Winbk_Startduelbuttondepressed.pic": F.noise(70, 5),
		"Deep/Er/Still/empty.txt": PackedByteArray(),
	}


func _write(name: String, bytes: PackedByteArray) -> String:
	var path := root.path_join(name)
	F.write_file(path, bytes)
	return path


func _open(name: String, bytes: PackedByteArray) -> SkinIsoImage:
	var image := SkinIsoImage.new()
	var why := image.open(_write(name, bytes))
	assert_eq(why, "", name)
	return image


func _paths(image: SkinIsoImage) -> Array:
	var out: Array = image.entries().map(func(entry: Dictionary) -> String: return entry["path"])
	out.sort()
	return out


# ----------------------------------------------------- 1. images read --

func test_a_plain_image_is_read_by_its_primary_names() -> void:
	var files := _files()
	var image := _open("disc.iso", ISO.make(files, false)["bytes"])
	assert_false(image.joliet)
	assert_eq([image.sector_size, image.data_offset], [2048, 0])
	assert_eq(_paths(image), ["DEEP/ER/STILL/EMPTY.TXT", "DUELART/WINBK_STARTDUELBUTTONDEPRESSED.PIC",
		"README", "SOUND/DUELTUNE.WAV", "STATWIN/BLU-SPRT.BMP", "TITLE.PIC"],
		"the ;1 and the trailing dot taken off")
	var folders: Array = Array(image.folders())
	folders.sort()
	assert_eq(folders, ["DEEP", "DEEP/ER", "DEEP/ER/STILL", "DUELART", "SOUND", "STATWIN"])
	for path: String in files:
		assert_eq(image.read(path), files[path], path + ", whatever its case")
		assert_eq(image.size_of(path.to_upper()), (files[path] as PackedByteArray).size())
	assert_eq(image.read("sound/DUELTUNE.wav").size(), 5000, "a file over three sectors, whole")
	assert_eq(image.size_of("nothing.pic"), -1)
	assert_eq(image.read_checked("nothing.pic")["error"], "it is not in the image")
	assert_string_contains(image.read_checked("Sound/Dueltune.wav", 4999)["error"], "larger")
	assert_eq(image.read_checked("Sound/Dueltune.wav", 100, 8)["bytes"], F.noise(5000, 3).slice(0, 8),
		"the first bytes alone, whatever the bound")
	image.close()
	assert_false(image.is_open())
	assert_eq(image.entries(), [])


func test_the_joliet_names_are_preferred() -> void:
	var files := _files()
	files["Señor Über.txt"] = F.noise(20, 9)
	var image := _open("disc.iso", ISO.make(files, true)["bytes"])
	assert_true(image.joliet)
	assert_eq(_paths(image), ["Deep/Er/Still/empty.txt", "Duelart/Winbk_Startduelbuttondepressed.pic",
		"README", "Señor Über.txt", "Sound/Dueltune.wav", "Statwin/Blu-Sprt.bmp", "Title.pic"],
		"as Windows wrote them")
	for path: String in files:
		assert_eq(image.read(path), files[path], path)
	assert_eq(image.read("TITLE.PIC"), files["Title.pic"], "and still whatever the case")
	# Names with no version on them read the same.
	var bare := _open("bare.iso", ISO.make(_files(), true, false)["bytes"])
	assert_eq(_paths(bare).has("Title.pic"), true)
	assert_eq(bare.read("readme"), F.noise(10, 2))


func test_raw_sectors_of_both_modes() -> void:
	var files := _files()
	var plain: PackedByteArray = ISO.make(files, true)["bytes"]
	for mode in [1, 2]:
		var image := _open("disc_m%d.bin" % mode, ISO.raw(plain, mode))
		assert_eq([image.sector_size, image.data_offset], [2352, 16 if mode == 1 else 24], "mode %d" % mode)
		assert_true(image.joliet)
		for path: String in files:
			assert_eq(image.read(path), files[path], "mode %d: %s" % [mode, path])
	# And one whose data runs over more sectors than are read at a go.
	var long_data := PackedByteArray()
	var piece := F.noise(4096, 6)
	for i in SkinIsoImage.RAW_CHUNK / 2:
		piece[0] = i & 0xFF
		long_data.append_array(piece)
	long_data.append_array(F.noise(3000, 7))
	var big := {"Big.bin": long_data}
	var image := _open("big.img", ISO.raw(ISO.make(big, false)["bytes"], 1))
	assert_eq(image.read("big.bin"), big["Big.bin"])


func test_what_is_no_image_is_refused_in_words() -> void:
	var image := SkinIsoImage.new()
	assert_eq(image.open(root.path_join("nowhere.iso")), "it is not there")
	for junk: PackedByteArray in [PackedByteArray(), F.noise(40, 1), F.noise(70000, 2),
			F.noise(40 * 2048, 3), "PK\u0003\u0004 a zip".to_utf8_buffer()]:
		var why := image.open(_write("junk.iso", junk))
		assert_string_contains(why, "not a CD image the game can read")
		assert_false(image.is_open())
	# A volume with blocks of another size, and one with no volume to read.
	var odd: PackedByteArray = ISO.make(_files(), false)["bytes"]
	odd.encode_u16(16 * 2048 + 128, 512)
	assert_string_contains(image.open(_write("odd.iso", odd)), "2048")
	var none: PackedByteArray = ISO.make(_files(), false)["bytes"]
	none[16 * 2048] = 3
	assert_string_contains(image.open(_write("none.iso", none)), "no volume")


# ---------------------------------------------------- 2. hostile images --

func test_an_image_cut_short_gives_what_is_whole() -> void:
	var files := _files()
	var made: Dictionary = ISO.make(files, true)
	var whole: PackedByteArray = made["bytes"]
	# Cut inside the long sound: it and what lies after it are gone.
	var cut_at := int(made["files"]["Sound/Dueltune.wav"]) * 2048 + 3000
	var image := _open("cut.iso", whole.slice(0, cut_at))
	assert_eq(image.damaged, 3, "the files past the end are counted")
	assert_eq(_paths(image), ["Deep/Er/Still/empty.txt", "README", "Title.pic"],
		"what lies before the cut, and a file of no bytes")
	assert_eq(image.read("Title.pic"), files["Title.pic"])
	assert_eq(image.size_of("Sound/Dueltune.wav"), -1)
	# Cut inside its list of files: refused.
	var early := SkinIsoImage.new()
	assert_string_contains(early.open(_write("early.iso", whole.slice(0, 18 * 2048))), "cut short")
	# No cut anywhere crashes or hangs, plain or raw.
	var started := Time.get_ticks_msec()
	var raw := ISO.raw(whole, 2)
	for length in range(0, whole.size(), 331):
		var probe := SkinIsoImage.new()
		if probe.open(_write("probe.iso", whole.slice(0, length))) == "":
			for entry: Dictionary in probe.entries():
				assert_eq(probe.read(entry["path"]).size(), int(entry["size"]))
	for length in range(0, raw.size(), 1777):
		var probe := SkinIsoImage.new()
		if probe.open(_write("probe.bin", raw.slice(0, length))) == "":
			for entry: Dictionary in probe.entries():
				assert_eq(probe.read(entry["path"]).size(), int(entry["size"]))
	assert_lt(Time.get_ticks_msec() - started, 30000)


func test_an_image_cut_after_it_was_opened() -> void:
	var files := _files()
	var whole: PackedByteArray = ISO.make(files, false)["bytes"]
	var image := _open("later.iso", whole)
	F.write_file(root.path_join("later.iso"), whole.slice(0, 20 * 2048))
	assert_string_contains(image.read_checked("Sound/Dueltune.wav")["error"], "cut short")
	DirAccess.remove_absolute(root.path_join("later.iso"))
	assert_string_contains(image.read_checked("Title.pic")["error"], "could not be opened")


func test_a_file_or_a_size_that_lies() -> void:
	var files := _files()
	var made: Dictionary = ISO.make(files, false)
	var at := ISO.find_record(made["bytes"], int(made["primary_root"]), ISO.primary_name("Title.pic", false))
	assert_gt(at, 0)
	# Its data past the end of the image.
	var far: PackedByteArray = (made["bytes"] as PackedByteArray).duplicate()
	far.encode_u32(at + 2, 0x7FFFFFF0)
	var image := _open("far.iso", far)
	assert_eq(image.damaged, 1)
	assert_eq(image.size_of("Title.pic"), -1)
	assert_eq(image.read("README"), files["README"], "the others are read")
	# A size no image holds.
	var huge: PackedByteArray = (made["bytes"] as PackedByteArray).duplicate()
	huge.encode_u32(at + 10, 0xFFFFFFFF)
	image = _open("huge.iso", huge)
	assert_eq(image.damaged, 1)
	assert_eq(image.size_of("Title.pic"), -1)
	# A file in several pieces, or interleaved: left out, counted.
	for patch: Array in [[25, 0x80], [26, 1], [27, 1]]:
		var pieces: PackedByteArray = (made["bytes"] as PackedByteArray).duplicate()
		pieces[at + int(patch[0])] = int(patch[1])
		image = _open("pieces.iso", pieces)
		assert_eq(image.unsupported, 1)
		assert_eq(image.size_of("Title.pic"), -1)
	# A root that claims four thousand megabytes of directory.
	var root_lies: PackedByteArray = (made["bytes"] as PackedByteArray).duplicate()
	root_lies.encode_u32(16 * 2048 + 166, 0xFFFFFFFF)
	var refused := SkinIsoImage.new()
	assert_string_contains(refused.open(_write("root.iso", root_lies)), "cut short")


func test_records_that_lie_about_their_length() -> void:
	var files := _files()
	var made: Dictionary = ISO.make(files, false)
	var image_bytes: PackedByteArray = made["bytes"]
	var first := ISO.find_record(image_bytes, int(made["primary_root"]), ISO.primary_name("Deep", true))
	assert_gt(first, 0)
	for length in [0, 1, 33]:
		var bent := image_bytes.duplicate()
		bent[first] = length
		var image := _open("bent.iso", bent)
		assert_eq(_paths(image), ["DUELART/WINBK_STARTDUELBUTTONDEPRESSED.PIC", "SOUND/DUELTUNE.WAV",
			"STATWIN/BLU-SPRT.BMP"], "length %d: the rest of that sector is passed over" % length)
		for entry: Dictionary in image.entries():
			assert_eq(image.read(entry["path"]).size(), int(entry["size"]))
	# A record that runs over its sector's end: it is passed over, and the
	# directory's next sector is still read.
	var many := {}
	for i in 60:
		many["file_number_%02d.dat" % i] = F.bytes([i])
	var crowded: Dictionary = ISO.make(many, false)
	var crowd: PackedByteArray = crowded["bytes"]
	var pos := int(crowded["primary_root"]) * 2048
	var last := pos
	while crowd[pos] >= 34:
		last = pos
		pos += crowd[pos]
	assert_gt(_open("crowd.iso", crowd).entries().size(), 59)
	crowd[last] = 255
	var crowded_image := _open("crowd.iso", crowd)
	assert_eq(crowded_image.entries().size(), 59, "one record lost, the next sector read")
	# A name longer than its record.
	var long_name := image_bytes.duplicate()
	long_name[first + 32] = 250
	var image := _open("name.iso", long_name)
	assert_false(_paths(image).has("DEEP/ER/STILL/EMPTY.TXT"))
	# Names that would be paths are not names.
	for name in ["..", ".", "A/B", "A\\B"]:
		var odd := image_bytes.duplicate()
		var at := ISO.find_record(odd, int(made["primary_root"]), ISO.primary_name("README", false))
		var bytes: PackedByteArray = String(name).to_ascii_buffer()
		odd[at + 32] = bytes.size()
		for i in bytes.size():
			odd[at + 33 + i] = bytes[i]
		image = _open("odd.iso", odd)
		for path: String in _paths(image):
			assert_false(path == name or path.contains("\\") or path.begins_with("."), "%s is no name" % name)


func test_a_directory_that_points_back_at_itself_ends() -> void:
	var made: Dictionary = ISO.make(_files(), false)
	var looped: PackedByteArray = (made["bytes"] as PackedByteArray).duplicate()
	var at := ISO.find_record(looped, int(made["primary_root"]), ISO.primary_name("Deep", true))
	looped.encode_u32(at + 2, int(made["primary_root"]))
	looped.encode_u32(at + 10, 2048)
	var started := Time.get_ticks_msec()
	var image := _open("loop.iso", looped)
	assert_lt(Time.get_ticks_msec() - started, 3000)
	assert_eq(_paths(image), ["DUELART/WINBK_STARTDUELBUTTONDEPRESSED.PIC", "README", "SOUND/DUELTUNE.WAV",
		"STATWIN/BLU-SPRT.BMP", "TITLE.PIC"], "each directory once, the loop not followed")
	# Two directories that point at each other.
	var two: PackedByteArray = (made["bytes"] as PackedByteArray).duplicate()
	var sound := ISO.find_record(two, int(made["primary_root"]), ISO.primary_name("Sound", true))
	var statwin := ISO.find_record(two, int(made["primary_root"]), ISO.primary_name("Statwin", true))
	var sound_at := two.decode_u32(sound + 2)
	var inner := ISO.find_record(two, sound_at, ISO.primary_name("Dueltune.wav", false))
	two[inner + 25] = 0x02
	two.encode_u32(inner + 2, two.decode_u32(statwin + 2))
	two.encode_u32(inner + 10, 2048)
	var back := ISO.find_record(two, two.decode_u32(statwin + 2), ISO.primary_name("Blu-Sprt.bmp", false))
	two[back + 25] = 0x02
	two.encode_u32(back + 2, sound_at)
	two.encode_u32(back + 10, 2048)
	started = Time.get_ticks_msec()
	image = _open("two.iso", two)
	assert_true(image.is_open())
	assert_lt(Time.get_ticks_msec() - started, 3000)
	assert_eq(image.entries().size(), 4, "the two that became directories are no files")


func test_a_tree_too_deep_is_cut() -> void:
	var files := {}
	var path := ""
	for i in 40:
		path += "d%d/" % i
	files[path + "bottom.txt"] = F.noise(5, 1)
	files["top.txt"] = F.noise(5, 2)
	var image := _open("deep.iso", ISO.make(files, false)["bytes"])
	assert_true(image.cut_short)
	assert_eq(_paths(image), ["TOP.TXT"])
	assert_lt(image.folders().size(), 40)


func test_a_hundred_thousand_files_are_bounded() -> void:
	var records: Array = [ISO.record(PackedByteArray([0]), 18, 0, true), ISO.record(PackedByteArray([1]), 18, 0, true)]
	for i in 100_000:
		records.append(ISO.record(("F%05d.X;1" % i).to_ascii_buffer(), 0, 0, false))
	var directory := ISO.directory(records)
	var whole: PackedByteArray = ISO.make({}, false)["bytes"].slice(0, 18 * 2048)
	whole.encode_u32(16 * 2048 + 158, 18)
	whole.encode_u32(16 * 2048 + 166, directory.size())
	whole.append_array(directory)
	var started := Time.get_ticks_msec()
	var image := _open("many.iso", whole)
	assert_lt(Time.get_ticks_msec() - started, 10000)
	assert_true(image.cut_short)
	assert_eq(image.entries().size(), SkinIsoImage.MAX_ENTRIES)
	var few := SkinIsoImage.new()
	few.max_entries = 10
	assert_eq(few.open(root.path_join("many.iso")), "")
	assert_eq(few.entries().size(), 10)
	# And the index takes no more than its own bound.
	var index := SkinSourceIndex.new()
	index.max_files = 25
	index.begin([root.path_join("many.iso")])
	index.step()
	assert_eq(index.file_count, 25)
	assert_true(index.cut_short)


# ------------------------------------------------------------ 3. a .cue --

func test_a_cue_is_followed_to_the_image_beside_it() -> void:
	var files := _files()
	var plain: PackedByteArray = ISO.make(files, true)["bytes"]
	_write("Game.BIN", ISO.raw(plain, 1))
	for sheet: Array in [["quoted.cue", ISO.cue("Game.BIN")], ["bare.cue", ISO.cue("Game.BIN", 1, false)],
			["other_case.cue", ISO.cue("game.bin")]]:
		var image := _open(sheet[0], sheet[1])
		assert_eq(image.path, root.path_join("Game.BIN"), sheet[0])
		assert_eq(image.sector_size, 2352)
		assert_eq(image.read("Title.pic"), files["Title.pic"])
	# A plain .iso may be named by a sheet too.
	_write("plain.iso", plain)
	assert_eq(_open("iso.cue", ISO.cue("plain.iso")).read("readme"), files["README"])


func test_a_cue_leads_nowhere_but_its_own_folder() -> void:
	var plain: PackedByteArray = ISO.make(_files(), true)["bytes"]
	F.write_file(root.path_join("outside.bin"), plain)
	F.write_file(root.path_join("sub/inner.bin"), plain)
	DirAccess.make_dir_recursive_absolute(root.path_join("sheets"))
	var image := SkinIsoImage.new()
	for name in ["../outside.bin", root.path_join("outside.bin"), "C:\\outside.bin", "..", "",
			"..\\outside.bin", "sub/../../outside.bin"]:
		var why := image.open(_write("sheets/bad.cue", ISO.cue(name)))
		assert_string_contains(why, "outside its own folder", name)
		assert_false(image.is_open())
	assert_string_contains(image.open(_write("sub.cue", ISO.cue("sub/inner.bin"))), "outside its own folder",
		"not even a folder below it")
	assert_string_contains(image.open(_write("gone.cue", ISO.cue("gone.bin"))), "gone.bin, which is not beside it")
	# A sheet that names a sheet, or a file that is no image.
	_write("first.cue", ISO.cue("second.cue"))
	_write("second.cue", ISO.cue("outside.bin"))
	assert_string_contains(image.open(root.path_join("first.cue")), "not a CD image")
	_write("noise.bin", F.noise(5000, 1))
	assert_string_contains(image.open(_write("noise.cue", ISO.cue("noise.bin"))), "not a CD image")
	assert_string_contains(image.open(_write("words.cue", "just some words\r\n".to_ascii_buffer())),
		"not a CD image")


# ------------------------------------------- 4. a source like a folder --

func test_an_image_and_a_folder_and_the_first_wins() -> void:
	var folder := root.path_join("Install")
	F.write_file(folder.path_join("Title.pic"), F.bytes([1]))
	F.write_file(folder.path_join("Only_here.pic"), F.bytes([2]))
	var disc := _write("disc.iso", ISO.make(_files(), true)["bytes"])
	var image_first := SkinSourceIndex.of([disc, folder])
	assert_eq(image_first.sources, [disc, folder] as Array[String])
	assert_true(image_first.is_image(disc) and not image_first.is_image(folder))
	assert_eq(image_first.find("title.pic"), disc.path_join("Title.pic"))
	assert_eq(image_first.read(image_first.find("TITLE.PIC"), 1000)["bytes"], F.noise(300, 1))
	assert_eq(image_first.find("only_here.pic"), folder.path_join("Only_here.pic"))
	assert_eq(image_first.find("sound/dueltune.wav"), disc.path_join("Sound/Dueltune.wav"), "by its folder")
	assert_eq(image_first.find("still/empty.txt"), disc.path_join("Deep/Er/Still/empty.txt"))
	assert_eq(image_first.head(image_first.find("dueltune.wav"), 8), F.noise(5000, 3).slice(0, 8))
	assert_string_contains(image_first.read(image_first.find("dueltune.wav"), 100)["error"], "larger")
	assert_true(image_first.has_name("statwin", disc) and image_first.has_name("blu-sprt.bmp", disc))
	assert_false(image_first.has_name("statwin", folder))
	assert_eq(image_first.file_count, 6 + 2)
	var folder_first := SkinSourceIndex.of([folder, disc])
	assert_eq(folder_first.find("title.pic"), folder.path_join("Title.pic"))
	assert_eq(folder_first.read(folder_first.find("title.pic"), 1000)["bytes"], F.bytes([1]))
	assert_eq(folder_first.find("dueltune.wav"), disc.path_join("Sound/Dueltune.wav"))


func test_a_file_that_is_no_image_is_told() -> void:
	var noise := _write("noise.iso", F.noise(40 * 2048, 1))
	var disc := _write("disc.iso", ISO.make(_files(), true)["bytes"])
	var index := SkinSourceIndex.of([noise, disc, root.path_join("nowhere.iso")])
	assert_eq(index.sources, [disc] as Array[String])
	assert_eq(index.not_folders, [noise, root.path_join("nowhere.iso")] as Array[String])
	assert_string_contains(index.problems[noise], "not a CD image")
	assert_false(index.problems.has(root.path_join("nowhere.iso")), "a path that is not there is no image at all")


func test_a_plain_disc_s_strict_names_answer() -> void:
	var files := _files()
	files["Statwin/Blu_Sprt.bmp"] = files["Statwin/Blu-Sprt.bmp"]
	files.erase("Statwin/Blu-Sprt.bmp")
	var plain := SkinSourceIndex.of([_write("plain.iso", ISO.make(files, false)["bytes"])])
	assert_eq(plain.find("Statwin/Blu-Sprt.bmp").get_file(), "BLU_SPRT.BMP",
		"a disc with no long names spells the dash as an underline")
	assert_eq(SkinSourceIndex.strict_name("statwin/blu-sprt 2.bmp"), "statwin/blu_sprt_2.bmp")
	# Not on a disc that has long names, and not in a folder.
	var long := SkinSourceIndex.of([_write("long.iso", ISO.make(files, true)["bytes"])])
	assert_eq(long.find("Statwin/Blu-Sprt.bmp"), "")
	var folder := root.path_join("Install")
	F.write_file(folder.path_join("Statwin/Blu_Sprt.bmp"), F.bytes([1]))
	assert_eq(SkinSourceIndex.of([folder]).find("Statwin/Blu-Sprt.bmp"), "")


## Every file under [param folder], by its path from it.
func _tree(folder: String, under := "") -> Dictionary:
	var out := {}
	var here := folder if under == "" else folder.path_join(under)
	for name in DirAccess.get_files_at(here):
		var inner := name if under == "" else under + "/" + name
		out[inner] = FileAccess.get_file_as_bytes(folder.path_join(inner))
	for name in DirAccess.get_directories_at(here):
		out.merge(_tree(folder, name if under == "" else under + "/" + name))
	return out


func _zip_files(path: String) -> Dictionary:
	var out := F.read_zip(path)
	for name: String in out.keys():
		if name.ends_with("/"):
			out.erase(name)
	return out


func test_the_check_calls_an_image_what_it_is() -> void:
	var install := root.path_join("MagicTG")
	F.make_install(install)
	var disc := _write("disc.iso", ISO.make(_tree(install), true)["bytes"])
	var report := SkinInstallCheck.survey(SkinSourceIndex.of([disc]))
	assert_eq(report["kind"], SkinInstallCheck.IMAGE)
	assert_true(report["buildable"])
	assert_eq(report["images"], 1)
	assert_eq(report["files"], 10, "what the folder it was made of gives")
	assert_eq(report["portraits"], 5)
	var said := "\n".join(PackedStringArray(report["lines"]))
	assert_string_contains(said, "This is a CD image of the 1997 game.")
	assert_string_contains(said, "Found: ")
	assert_true(report["packed"], "far fewer files than an installed game gives")
	assert_string_contains(said, "Some of the game's files may be packed inside the CD's installer; the game cannot unpack those. Install the game and add its folder too.")
	# The folder itself is an install, and is not told that.
	var of_folder := SkinInstallCheck.survey(SkinSourceIndex.of([install]))
	assert_eq(of_folder["kind"], SkinInstallCheck.INSTALL)
	assert_false(of_folder["packed"])
	assert_eq(of_folder["images"], 0)
	# An image and the folder together: an install, read from both.
	var both := SkinInstallCheck.survey(SkinSourceIndex.of([disc, install]))
	assert_eq(both["kind"], SkinInstallCheck.INSTALL)
	assert_eq(both["images"], 1)
	# An image with nothing of the game on it.
	var other := _write("other.iso", ISO.make({"photo.png": F.noise(50, 1), "notes/todo.txt": F.noise(9, 2)}, true)["bytes"])
	var index := SkinSourceIndex.of([other])
	assert_false(SkinInstallCheck.is_copy(index, other))
	var nothing := SkinInstallCheck.survey(index)
	assert_eq(nothing["kind"], SkinInstallCheck.NOTHING)
	assert_eq(nothing["lines"], ["This is not a CD image of the 1997 game: none of its files were found in it."])
	# One cut short says how much of it is gone.
	var whole := FileAccess.get_file_as_bytes(disc)
	var cut := SkinInstallCheck.survey(SkinSourceIndex.of([_write("cut.iso", whole.slice(0, whole.size() / 2))]))
	assert_string_contains("\n".join(PackedStringArray(cut["lines"])), "The image is cut short: ")


func test_the_build_from_an_image_is_the_build_from_its_folder() -> void:
	var install := root.path_join("MagicTG")
	F.make_install(install)
	var of_folder := SkinBuildJob.build([install], root.path_join("out/folder.zip"))
	assert_true(of_folder["ok"])
	var wanted := _zip_files(root.path_join("out/folder.zip"))
	assert_eq(wanted.size(), 29)
	var plain: PackedByteArray = ISO.make(_tree(install), true)["bytes"]
	_write("disc.iso", plain)
	_write("disc_m1.bin", ISO.raw(plain, 1))
	_write("disc_m2.img", ISO.raw(plain, 2))
	_write("disc_m2.cue", ISO.cue("disc_m2.img", 2))
	for name in ["disc.iso", "disc_m1.bin", "disc_m2.cue"]:
		var zip := root.path_join("out/%s.zip" % name)
		var result := SkinBuildJob.build([root.path_join(name)], zip)
		assert_true(result["ok"], name + ": " + String(result["why"]))
		assert_eq(result["skipped"], [], name)
		assert_eq(result["files"], 29, name)
		var got := _zip_files(zip)
		assert_eq(got.keys(), wanted.keys(), name + ": the same names")
		for entry: String in wanted:
			assert_true(got[entry] == wanted[entry], "%s: %s is the same file" % [name, entry])
		var seen: Dictionary = SkinPack.inspect(zip)
		assert_true(seen["ok"], name)
		assert_eq([seen["kind"], seen["files"]], ["skin", 29], name)


func test_the_build_from_an_image_on_a_thread() -> void:
	var install := root.path_join("MagicTG")
	F.make_install(install)
	var disc := _write("disc.bin", ISO.raw(ISO.make(_tree(install), true)["bytes"], 1))
	var job := SkinBuildJob.new()
	assert_true(job.open(SkinSourceIndex.of([disc]), root.path_join("out/thread.zip")))
	assert_true(job.start_thread())
	var waited := 0
	while not bool(job.progress()["finished"]) and waited < 3000:
		await get_tree().process_frame
		waited += 1
	job.wait()
	assert_true(job.result()["ok"])
	assert_eq(_zip_files(root.path_join("out/thread.zip")).size(), 29)


func test_a_plain_disc_without_long_names_still_builds() -> void:
	var install := root.path_join("MagicTG")
	F.make_install(install)
	var files := _tree(install)
	# What a mastering tool does to a dash on such a disc.
	files["Statwin/Blu_Sprt.bmp"] = files["Statwin/Blu-Sprt.bmp"]
	files.erase("Statwin/Blu-Sprt.bmp")
	var result := SkinBuildJob.build([_write("plain.iso", ISO.make(files, false)["bytes"])],
		root.path_join("out/plain.zip"))
	assert_true(result["ok"])
	assert_eq(result["files"], 29, "every file, the dashed one by its strict name")
	var got := _zip_files(root.path_join("out/plain.zip"))
	assert_true(got.has("skin/wizards_figure_blue.png"))
	var layout: Dictionary = JSON.parse_string((got["skin/world_landtile.json"] as PackedByteArray).get_string_from_utf8())
	assert_eq(layout["source"], "LANDTILE.SPR", "the name as that disc spells it")


func test_an_image_that_breaks_under_the_build() -> void:
	var install := root.path_join("MagicTG")
	F.make_install(install)
	var disc := _write("disc.iso", ISO.make(_tree(install), true)["bytes"])
	var job := SkinBuildJob.new()
	assert_true(job.open(SkinSourceIndex.of([disc]), root.path_join("out/broken.zip")))
	assert_true(job.step(0), "a first file is in")
	# The image goes away under it: every file after that is left out.
	DirAccess.remove_absolute(disc)
	job.step()
	var result := job.result()
	assert_true(result["ok"], "what was read is kept")
	assert_gt((result["skipped"] as Array).size(), 5)
	for row: Dictionary in result["skipped"]:
		assert_ne(String(row["why"]), "")
	assert_true(bool(SkinPack.inspect(root.path_join("out/broken.zip"))["ok"]))
