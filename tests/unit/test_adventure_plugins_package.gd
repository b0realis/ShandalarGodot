extends GutTest
## ONE ADVENTURE PLUGIN READ AS DATA (adventure plugins, 2026-11-10; the
## spec's §0.1, §0.10 and §1): a zip under one top folder or an unpacked
## folder, read into bytes by [PluginPackage] — the paths, the kinds of file,
## the limits and the headers checked, the litter passed over, nothing
## mounted, loaded or run. The zips the loader must refuse are written byte
## by byte (tests/support/plugin_zips.gd).

const ZIPS := preload("res://tests/support/plugin_zips.gd")
const FIXTURE := ZIPS.FIXTURE
const SCRATCH := "user://plugin_package_tests"


func after_each() -> void:
	ZIPS.remove(SCRATCH)


func _problems(path: String) -> Array:
	return PluginPackage.read(path)["problems"]


func _says(problems: Array, words: String) -> bool:
	return problems.any(func(problem: String) -> bool: return problem.contains(words))


func _zip_of(name: String, entries: Array) -> String:
	var path := SCRATCH.path_join(name + ".zip")
	ZIPS.write(path, entries)
	return path


func test_the_fixture_folder_reads_whole() -> void:
	var read := PluginPackage.read(FIXTURE)
	assert_eq(read["problems"], [] as Array[String])
	assert_eq(read["kind"], "folder")
	var files: Dictionary = read["files"]
	for rel in ["plugin.json", "world.json", "places.json", "quests.json", "foes.json", "text.json",
			"README.txt", "art/tiny_isle_harbor.png", "music/tiny_isle_tide.ogg"]:
		assert_true(files.has(rel), rel)
	assert_eq(files["plugin.json"], FileAccess.get_file_as_bytes(FIXTURE.path_join("plugin.json")), "the bytes as they are")


func test_a_deflated_zip_reads_as_its_folder_does() -> void:
	var path := SCRATCH.path_join("Tiny_Isle.zip")
	ZIPS.zip_folder(FIXTURE, path, "Any_Name_At_All")
	var read := PluginPackage.read(path)
	assert_eq(read["problems"], [] as Array[String])
	assert_eq(read["kind"], "zip")
	assert_eq(read["top"], "Any_Name_At_All", "the top folder's name is free")
	var folder: Dictionary = PluginPackage.read(FIXTURE)["files"]
	var files: Dictionary = read["files"]
	assert_eq(files.keys().size(), folder.keys().size())
	for rel: String in folder:
		assert_eq(files.get(rel), folder[rel], rel)
	var raw := _zip_of("raw", ZIPS.fixture_entries())
	assert_eq(_problems(raw), [], "stored entries read too")


func test_every_file_goes_under_one_top_folder() -> void:
	var loose: Array = []
	for entry: Dictionary in ZIPS.fixture_entries():
		loose.append({"name": String(entry["name"]).trim_prefix("tiny_isle/"), "bytes": entry["bytes"]})
	assert_true(_says(_problems(_zip_of("loose", loose)), "inside one top folder"), "files at the zip's top")
	var two := ZIPS.fixture_entries()
	two.append({"name": "other/readme.txt", "bytes": "hello".to_utf8_buffer()})
	assert_true(_says(_problems(_zip_of("two", two)), "ONE top folder; found 2"))
	var none := ZIPS.fixture_entries().filter(func(entry: Dictionary) -> bool: return not String(entry["name"]).ends_with("plugin.json"))
	assert_true(_says(_problems(_zip_of("none", none)), "plugin.json is missing"))


func test_unsafe_paths_are_refused_and_named() -> void:
	for name in ["tiny_isle/../evil.json", "/tiny_isle/abs.json", "tiny_isle\\back.json", "tiny_isle/c:drive.json",
			"tiny_isle//empty.json", "tiny_isle/./here.json", "tiny_isle/" + "x".repeat(200) + ".json",
			"tiny_isle/bell\u0007.json"]:
		var entries := ZIPS.fixture_entries()
		entries.append({"name": name, "bytes": "{}".to_utf8_buffer()})
		var problems := _problems(_zip_of("path", entries))
		assert_eq(problems.size(), 1, name)
		assert_true(problems.size() == 1 and String(problems[0]).contains("path"), "%s: %s" % [name, problems])
	assert_eq(PluginPackage.path_problem("art/harbor.png"), "")
	assert_ne(PluginPackage.path_problem("art/../../x.png"), "")


func test_scripts_scenes_binaries_and_unknown_kinds_are_refused() -> void:
	for extension in ["gd", "GD", "gdc", "gdextension", "tscn", "scn", "tres", "res", "import", "remap", "pck",
			"so", "dll", "dylib", "exe", "bin", "html"]:
		var entries := ZIPS.fixture_entries()
		entries.append({"name": "tiny_isle/art/payload." + extension, "bytes": "print('x')".to_utf8_buffer()})
		var problems := _problems(_zip_of("kind", entries))
		assert_true(_says(problems, "payload.%s: this kind of file is not allowed" % extension), "%s in a zip" % extension)
	var entries := ZIPS.fixture_entries()
	entries.append({"name": "tiny_isle/LICENSE", "bytes": "GPL".to_utf8_buffer()})
	assert_true(_says(_problems(_zip_of("bare", entries)), "LICENSE: this kind of file"), "a file with no extension")
	var folder := SCRATCH.path_join("with_script")
	ZIPS.copy_fixture(folder, {"quests.gd": "extends Node".to_utf8_buffer()})
	assert_true(_says(_problems(folder), "quests.gd: this kind of file is not allowed"), "in a folder too")


func test_symbolic_links_are_refused() -> void:
	var entries := ZIPS.fixture_entries()
	entries.append({"name": "tiny_isle/art/link.png", "bytes": "/etc/passwd".to_utf8_buffer(), "made_by": ZIPS.UNIX,
		"external": ZIPS.LINK_MODE << 16})
	assert_true(_says(_problems(_zip_of("link", entries)), "art/link.png: a symbolic link"))
	var folder := SCRATCH.path_join("linked")
	ZIPS.copy_fixture(folder)
	var outside := ProjectSettings.globalize_path(SCRATCH.path_join("outside"))
	DirAccess.make_dir_recursive_absolute(outside)
	assert_eq(DirAccess.open(ProjectSettings.globalize_path(folder)).create_link(outside,
		ProjectSettings.globalize_path(folder.path_join("art/elsewhere"))), OK, "a link made to test")
	assert_true(_says(_problems(folder), "art/elsewhere: a symbolic link"))


func test_locked_unusual_and_doubled_entries_are_refused() -> void:
	var locked := ZIPS.fixture_entries()
	locked.append({"name": "tiny_isle/secret.json", "bytes": "{}".to_utf8_buffer(), "flags": 1})
	assert_true(_says(_problems(_zip_of("locked", locked)), "secret.json: encrypted"))
	var packed := ZIPS.fixture_entries()
	packed.append({"name": "tiny_isle/odd.json", "bytes": "{}".to_utf8_buffer(), "method": 12})
	assert_true(_says(_problems(_zip_of("method", packed)), "odd.json: packed in a way"))
	var doubled := ZIPS.fixture_entries()
	doubled.append({"name": "tiny_isle/WORLD.json", "bytes": "{}".to_utf8_buffer()})
	assert_true(_says(_problems(_zip_of("doubled", doubled)), "two entries have this name"), "letter case ignored")
	var broken := SCRATCH.path_join("broken.zip")
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_buffer("PK not a zip at all, only words that go on for a while".to_utf8_buffer())
	file.close()
	assert_true(_says(_problems(broken), "not a whole zip"))
	assert_true(_says(_problems(SCRATCH.path_join("absent.txt")), "not a .zip file or a folder"))


func test_the_limits_refuse_before_anything_is_read() -> void:
	var big_json := ZIPS.fixture_entries()
	big_json.append({"name": "tiny_isle/huge.json", "size": PluginPackage.MAX_JSON + 1})
	assert_true(_says(_problems(_zip_of("json", big_json)), "huge.json: 1.0 MiB is bigger than the 1 MiB"))
	var big_ogg := ZIPS.fixture_entries()
	big_ogg.append({"name": "tiny_isle/music/long.ogg", "size": PluginPackage.MAX_OGG + 1})
	assert_true(_says(_problems(_zip_of("ogg", big_ogg)), "long.ogg: 16.0 MiB is bigger than the 16 MiB"))
	var big := ZIPS.fixture_entries()
	for n in 3:
		big.append({"name": "tiny_isle/art/p%d.png" % n, "size": 12 * 1024 * 1024})
	assert_true(_says(_problems(_zip_of("total", big)), "bigger than 32 MiB unpacked"))
	var many := ZIPS.fixture_entries()
	for n in PluginPackage.MAX_FILES:
		many.append({"name": "tiny_isle/notes/n%03d.txt" % n, "bytes": PackedByteArray([0x61])})
	assert_true(_says(_problems(_zip_of("many", many)), "more than 512 files"))
	var folder := SCRATCH.path_join("folder_json")
	var text := PackedByteArray()
	text.resize(PluginPackage.MAX_JSON + 1)
	text.fill(0x20)
	ZIPS.copy_fixture(folder, {"text.json": text})
	assert_true(_says(_problems(folder), "text.json: 1.0 MiB is bigger"), "a folder's file by its length")


func test_pictures_music_and_text_are_what_they_say() -> void:
	var png := FileAccess.get_file_as_bytes(FIXTURE.path_join("art/tiny_isle_harbor.png"))
	var wide := png.duplicate()
	wide.encode_u32(16, 0)
	wide[16] = 0
	wide[17] = 0
	wide[18] = 0x13
	wide[19] = 0x88   # 5000 pixels wide
	var cases := {
		"tiny_isle/art/wide.png": [wide, "5000 x 4 pixels; 4096 is the most"],
		"tiny_isle/art/fake.png": [PackedByteArray([0xFF, 0xD8, 0xFF, 0xE0, 0, 16]), "fake.png: not a PNG picture"],
		"tiny_isle/art/fake.jpg": [png, "fake.jpg: not a JPG picture"],
		"tiny_isle/music/fake.ogg": ["OggS but not really".to_utf8_buffer(), "fake.ogg: not Ogg Vorbis"],
		"tiny_isle/notes.txt": [PackedByteArray([0x68, 0xFF, 0x69]), "notes.txt: the text is not UTF-8"],
	}
	for name: String in cases:
		var entries := ZIPS.fixture_entries()
		entries.append({"name": name, "bytes": cases[name][0]})
		assert_true(_says(_problems(_zip_of("content", entries)), cases[name][1]), name)


func test_the_litter_of_other_systems_is_passed_over() -> void:
	var entries := ZIPS.fixture_entries()
	entries.append({"name": "__MACOSX/tiny_isle/._plugin.json", "bytes": PackedByteArray([0, 5, 22, 7])})
	entries.append({"name": "tiny_isle/.DS_Store", "bytes": PackedByteArray([0, 0, 0, 1])})
	entries.append({"name": "tiny_isle/art/Thumbs.db", "bytes": PackedByteArray([0xD0, 0xCF])})
	entries.append({"name": "tiny_isle/desktop.ini", "bytes": "[.ShellClassInfo]".to_utf8_buffer()})
	var read := PluginPackage.read(_zip_of("litter", entries))
	assert_eq(read["problems"], [] as Array[String])
	for rel: String in read["files"]:
		assert_false(rel.contains(".DS_Store") or rel.contains("Thumbs") or rel.contains("desktop.ini"), rel)
	var folder := SCRATCH.path_join("litter_folder")
	ZIPS.copy_fixture(folder, {".DS_Store": PackedByteArray([0, 0, 0, 1]), ".git/config": "[core]".to_utf8_buffer()})
	assert_eq(_problems(folder), [], "hidden files and folders are never read")


func test_picture_headers_give_kind_and_size_without_decoding() -> void:
	var png := FileAccess.get_file_as_bytes(FIXTURE.path_join("art/tiny_isle_harbor.png"))
	assert_eq(PluginPackage.picture_kind(png), "png")
	assert_eq(PluginPackage.picture_size(png), Vector2i(8, 4))
	var jpeg := PackedByteArray([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x04, 0x4A, 0x46,
		0xFF, 0xC0, 0x00, 0x11, 0x08, 0x01, 0xE0, 0x02, 0x80, 0x03])
	assert_eq(PluginPackage.picture_kind(jpeg), "jpg")
	assert_eq(PluginPackage.picture_size(jpeg), Vector2i(640, 480), "the first start-of-frame, height before width")
	var webp := "RIFF".to_utf8_buffer() + PackedByteArray([0, 0, 0, 0]) + "WEBPVP8X".to_utf8_buffer()
	webp.resize(30)
	webp[24] = 0xFF   # canvas 256 x 2 (stored less one)
	webp[27] = 0x01
	assert_eq(PluginPackage.picture_kind(webp), "webp")
	assert_eq(PluginPackage.picture_size(webp), Vector2i(256, 2))
	assert_eq(PluginPackage.picture_size("not a picture".to_utf8_buffer()), Vector2i.ZERO)
	assert_true(PluginPackage.is_vorbis(FileAccess.get_file_as_bytes(FIXTURE.path_join("music/tiny_isle_tide.ogg"))))


func test_utf8_is_checked_without_the_engine_complaining() -> void:
	assert_true(PluginPackage.is_utf8("plain words".to_utf8_buffer()))
	assert_true(PluginPackage.is_utf8("Ebon Crown — Havenwood's élan, ✓ 𝄞".to_utf8_buffer()))
	for bad in [PackedByteArray([0xFF]), PackedByteArray([0xC0, 0x80]), PackedByteArray([0xED, 0xA0, 0x80]),
			PackedByteArray([0xE2, 0x82]), PackedByteArray([0x61, 0x80]), PackedByteArray([0xF5, 0x80, 0x80, 0x80])]:
		assert_false(PluginPackage.is_utf8(bad), str(bad))


func test_json_is_parsed_quietly_within_its_limits() -> void:
	var good := PluginPackage.json("a.json", "﻿{\"n\": [1, 2]}".to_utf8_buffer())
	assert_eq(good["problem"], "", "a byte-order mark is allowed")
	assert_eq(good["value"], {"n": [1.0, 2.0]})
	var bad := PluginPackage.json("b.json", "{\n\"n\": [1, 2,\n".to_utf8_buffer())
	assert_string_contains(String(bad["problem"]), "b.json: line ")
	# "FILE: line N: MESSAGE", lines counted from 1 as an editor counts them
	# (the lead's ruling; the content schema's shape).
	assert_eq(PluginPackage.json("c.json", "{\"a\": }".to_utf8_buffer())["problem"], "c.json: line 1: %s" % _parse_error("{\"a\": }"))
	assert_string_contains(String(PluginPackage.json("d.json", "{\n\n\"a\": }".to_utf8_buffer())["problem"]), "d.json: line 3: ")
	var deep := "[".repeat(PluginPackage.MAX_DEPTH + 1) + "]".repeat(PluginPackage.MAX_DEPTH + 1)
	assert_string_contains(String(PluginPackage.json("c.json", deep.to_utf8_buffer())["problem"]), "nested deeper than 32")
	var edge := "[".repeat(PluginPackage.MAX_DEPTH) + "]".repeat(PluginPackage.MAX_DEPTH)
	assert_eq(PluginPackage.json("d.json", edge.to_utf8_buffer())["problem"], "", "32 levels are allowed")
	assert_eq(PluginPackage.depth({"a": [{"b": 1}]}), 3)


func _parse_error(text: String) -> String:
	var parser := JSON.new()
	parser.parse(text)
	return parser.get_error_message()


func test_one_file_is_read_again_from_either_kind() -> void:
	var path := SCRATCH.path_join("again.zip")
	ZIPS.zip_folder(FIXTURE, path, "Top")
	var png := FileAccess.get_file_as_bytes(FIXTURE.path_join("art/tiny_isle_harbor.png"))
	assert_eq(PluginPackage.read_one(path, "zip", "Top", "art/tiny_isle_harbor.png"), png)
	assert_eq(PluginPackage.read_one(FIXTURE, "folder", "", "art/tiny_isle_harbor.png"), png)
	assert_true(PluginPackage.read_one(FIXTURE, "folder", "", "../tiny_isle/plugin.json").is_empty(), "never outside")
	assert_true(PluginPackage.read_one(path, "zip", "Top", "art/absent.png").is_empty())
	assert_eq(PluginPackage.sha256(PackedByteArray()), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
