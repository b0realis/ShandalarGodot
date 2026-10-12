extends GutTest
## THE FIRST-START CARD PACK CHECK, FASTER AND ON THE SCREEN (2026-10-11,
## the owner's Meta Quest: *"the check took 6 mins for all 9 packs"*, on a
## splash screen that never moved).
##
## [method PackSeal.artwork_sha256] given the pack's path reads the zip's
## directory once and the pictures in file order ([method
## PackSeal._indexed_sha256s]) instead of [method ZIPReader.read_file]'s
## walk from the first record for every picture — the same digest, several
## times faster. What these pin:
##
##   1. The digest is the same either way, for deflated and stored zips,
##      and the indexed reader really read every picture.
##   2. Anything it does not take — no file, a name the zip lacks — is {}
##      and the digest falls back to ZIPReader, as before; a changed
##      picture changes the digest either way.
##   3. The progress callback hears every picture, ending at (n, n).
##   4. [PackCheckScreen]: none where there is no screen; the words it
##      shows; discovery leaves no callback behind.

const SCRATCH := "user://pack_check_test"

var _made: Array[String] = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))


func after_each() -> void:
	PackSeal.progress = Callable()
	for path in _made:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made.clear()


## A zip of [param files] {name: bytes}, at [param level] compression.
func _zip(file_name: String, files: Dictionary, level := ZIPPacker.COMPRESSION_DEFAULT) -> String:
	var path := SCRATCH.path_join(file_name)
	var packer := ZIPPacker.new()
	assert_eq(packer.open(path), OK)
	packer.compression_level = level
	for name: String in files:
		packer.start_file(name)
		packer.write_file(files[name])
		packer.close_file()
	packer.close()
	_made.append(path)
	return path


func _pictures(count: int) -> Dictionary:
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261011
	for i in count:
		var bytes := PackedByteArray()
		bytes.resize(3000 + i * 37)
		for j in bytes.size():
			# Half random, half runs: something deflate has work to do on.
			bytes[j] = rng.randi_range(0, 255) if j % 2 == 0 else (j / 64) % 256
		out["card_packs/test/art/card_%03d.jpg" % i] = bytes
	out["card_packs/test/manifest.json"] = "{}".to_utf8_buffer()
	return out


func _digest_both(path: String, names: Array) -> Array:
	var reader := ZIPReader.new()
	reader.open(path)
	var plain := PackSeal.artwork_sha256(reader, names)
	var indexed := PackSeal.artwork_sha256(reader, names, "", path)
	reader.close()
	return [plain, indexed]


func _art_names(files: Dictionary) -> Array:
	return files.keys().filter(func(n: String) -> bool: return n.ends_with(".jpg"))


func test_the_same_digest_deflated_and_stored() -> void:
	var files := _pictures(40)
	var names := _art_names(files)
	for level in [ZIPPacker.COMPRESSION_DEFAULT, ZIPPacker.COMPRESSION_NONE]:
		var path := _zip("pack_%d.zip" % level, files, level)
		var both := _digest_both(path, names)
		assert_eq(both[1], both[0], "level %d: the indexed reader's digest is ZIPReader's" % level)
		var sums := PackSeal._indexed_sha256s(path, names)
		assert_eq(sums.size(), names.size(), "level %d: every picture was read by the indexed reader" % level)
		for name: String in names:
			assert_eq(sums[name], PackSeal._sha256(files[name]), name)


func test_what_it_does_not_take_falls_back_to_zipreader() -> void:
	var files := _pictures(6)
	var names := _art_names(files)
	var path := _zip("fallback.zip", files)
	assert_eq(PackSeal._indexed_sha256s(SCRATCH.path_join("no_such.zip"), names), {})
	var with_missing := names + ["card_packs/test/art/not_in_the_zip.jpg"]
	assert_eq(PackSeal._indexed_sha256s(path, with_missing), {}, "a name the zip lacks")
	var reader := ZIPReader.new()
	reader.open(path)
	assert_eq(PackSeal.artwork_sha256(reader, names, "", SCRATCH.path_join("no_such.zip")),
		PackSeal.artwork_sha256(reader, names), "a path it cannot read: ZIPReader's digest, as before")
	reader.close()


## A changed picture changes the digest through the indexed reader, so a
## pack whose pictures are not the manifest's is refused as before — end to
## end on a built Pack 2 in `test_pack_seal_2026_09_29.gd`. (A zip whose
## entry fails its CRC is {} here and ZIPReader decides, as before; it is
## not pinned in the gate, because both readers log an engine error on it
## and the gate fails on any.)
func test_a_changed_picture_changes_the_digest() -> void:
	var files := _pictures(8)
	var names := _art_names(files)
	var good := _digest_both(_zip("good.zip", files), names)
	var changed_files := files.duplicate()
	var picture: PackedByteArray = changed_files[names[3]].duplicate()
	picture[100] = picture[100] ^ 0xFF
	changed_files[names[3]] = picture
	var changed := _digest_both(_zip("changed.zip", changed_files), names)
	assert_eq(changed[1], changed[0], "both readers agree on the changed pack")
	assert_ne(changed[1], good[1], "and it is not the good pack's digest: refused against its manifest")


func test_progress_hears_every_picture() -> void:
	var files := _pictures(25)
	var names := _art_names(files)
	var path := _zip("progress.zip", files)
	var heard: Array = []
	PackSeal.progress = func(done: int, of: int) -> void: heard.append([done, of])
	var reader := ZIPReader.new()
	reader.open(path)
	PackSeal.artwork_sha256(reader, names, "", path)
	reader.close()
	assert_eq(heard.size(), names.size())
	assert_eq(heard.back(), [names.size(), names.size()])
	heard.clear()
	reader.open(path)
	PackSeal.artwork_sha256(reader, names, PackSeal._sha256(PackedByteArray([1])), path)
	reader.close()
	assert_eq(heard.size(), 0, "a sealed pack's trusted digest reads nothing, reports nothing")


func test_the_screen_says_which_pack_and_how_far() -> void:
	assert_null(PackCheckScreen.open(get_viewport()), "no screen in a headless run: the tests, the Deck Lab, the probes")
	var screen := PackCheckScreen.new()   # no canvas: the words, not the drawing
	screen.begin_pack(3, 9, "Pack-3-Ice_Age.zip")
	screen.pictures(777, 1438)
	var text := screen.text()
	assert_string_contains(text, "Checking the card packs")
	assert_string_contains(text, "Pack 3 of 9 · Pack-3-Ice_Age.zip · 54%")
	assert_string_contains(text, "Later starts skip this")
	screen.begin_pack(10, 9, "Pack-9-Tempest-Block.zip")
	assert_string_contains(screen.text(), "Pack 10 of 10", "a count that grows past its estimate")
	screen.close()   # nothing to free, and no error


func test_discovery_leaves_no_callback_behind() -> void:
	CardPacks.discover()
	assert_false(PackSeal.progress.is_valid())
