extends GutTest
## THE TAR AT THE DOOR — [TarPack] (2026-09-08, `[QoL]`): a tar, plain
## or gzipped, repacked into the zip the engine can mount. The owner:
## *"Can we use also tar.gz not only zip? As an alternative for card
## packs and original skin file?"* Tars are written here by hand —
## ustar headers with their checksum, a GNU long-name entry, a pax
## header — and gzipped with the engine's own deflate, so the contract
## holds in a checkout with no `tar` on the path: every entry comes out
## under its name with its bytes, the names a tar hands down in pieces
## are put together, what is not a file is left out, a broken tar
## leaves nothing behind, and a big one is read in steps that each
## make progress.

const SCRATCH := "user://tar_pack_test"
const BLOCK := 512

var _seed := 0


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)


func after_each() -> void:
	for name in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(name))
	DirAccess.remove_absolute(SCRATCH)


# ------------------------------------------------------------ the tars --

## One ustar header. [param type] is the tar's own letter ("0" a file,
## "5" a directory, "L" a GNU long name, "x" a pax header).
static func _header(name: String, size: int, type: String) -> PackedByteArray:
	var h := PackedByteArray()
	h.resize(BLOCK)
	h.fill(0)
	_put(h, 0, name.to_utf8_buffer().slice(0, 100))
	_put(h, 100, "0000644".to_ascii_buffer())
	_put(h, 108, "0001000".to_ascii_buffer())
	_put(h, 116, "0001000".to_ascii_buffer())
	_put(h, 124, ("%011o" % size).to_ascii_buffer())
	_put(h, 136, "00000000000".to_ascii_buffer())
	_put(h, 148, "        ".to_ascii_buffer())
	_put(h, 156, type.to_ascii_buffer() if type != "" else PackedByteArray([0]))
	_put(h, 257, "ustar".to_ascii_buffer())
	_put(h, 263, "00".to_ascii_buffer())
	var sum := 0
	for b in h:
		sum += b
	_put(h, 148, ("%06o" % sum).to_ascii_buffer() + PackedByteArray([0, 0x20]))
	return h


static func _put(into: PackedByteArray, at: int, bytes: PackedByteArray) -> void:
	for i in bytes.size():
		into[at + i] = bytes[i]


## A whole tar: [param entries] in order, each `[name, body, type]`
## (`type` "0" when left out), the two zero blocks at the end.
static func _tar(entries: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for entry in entries:
		var name: String = entry[0]
		var body: PackedByteArray = entry[1] if entry[1] is PackedByteArray \
			else String(entry[1]).to_utf8_buffer()
		var type: String = entry[2] if entry.size() > 2 else "0"
		out.append_array(_header(name, body.size(), type))
		out.append_array(body)
		var pad := (BLOCK - body.size() % BLOCK) % BLOCK
		if pad > 0:
			var zeros := PackedByteArray()
			zeros.resize(pad)
			zeros.fill(0)
			out.append_array(zeros)
	var tail := PackedByteArray()
	tail.resize(BLOCK * 2)
	tail.fill(0)
	out.append_array(tail)
	return out


static func _write(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _bytes(n: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	_seed += 1
	rng.seed = _seed
	for i in n:
		out[i] = rng.randi() & 0xFF
	return out


static func _entries_of(zip: String) -> Dictionary:
	var out := {}
	var reader := ZIPReader.new()
	if reader.open(zip) != OK:
		return out
	for name in reader.get_files():
		if not name.ends_with("/"):
			out[name] = reader.read_file(name)
	reader.close()
	return out


# ---------------------------------------------------------- the names --

func test_a_tars_name_becomes_the_zips() -> void:
	assert_eq(TarPack.zip_name("my_skin.tar.gz"), "my_skin.zip")
	assert_eq(TarPack.zip_name("My_Skin.TGZ"), "My_Skin.zip", "the tail in any case")
	assert_eq(TarPack.zip_name("cards.tar"), "cards.zip")
	assert_eq(TarPack.zip_name("v2.cards.tar.gz"), "v2.cards.zip", "only the tail goes")
	assert_eq(TarPack.zip_name("cards.zip"), "cards.zip", "a zip is left alone")
	assert_eq(TarPack.zip_name("notes.txt"), "notes.txt")


func test_a_tar_is_known_by_its_bytes_not_its_name() -> void:
	var plain := SCRATCH + "/plain.bin"
	_write(plain, _tar([["skin/a.txt", "a"]]))
	var gz := SCRATCH + "/gz.bin"
	_write(gz, _tar([["skin/a.txt", "a"]]).compress(FileAccess.COMPRESSION_GZIP))
	var zip := SCRATCH + "/zip.tar.gz"
	var packer := ZIPPacker.new()
	packer.open(zip)
	packer.start_file("skin/a.txt")
	packer.write_file("a".to_utf8_buffer())
	packer.close_file()
	packer.close()
	assert_true(TarPack.is_tar(plain), "ustar at 257")
	assert_true(TarPack.is_tar(gz), "the gzip magic")
	assert_false(TarPack.is_tar(zip), "a zip named like a tar is a zip")
	assert_false(TarPack.is_tar(SCRATCH + "/no_such_file"))


# --------------------------------------------------------- the repack --

func test_every_file_comes_out_under_its_name_with_its_bytes() -> void:
	var big := _bytes(300 * 1024 + 17)
	var tar := _tar([
		["skin/", PackedByteArray(), "5"],
		["skin/cardart/", PackedByteArray(), "5"],
		["skin/cardart/zz_a.jpg", big],
		["skin/cardart/zz_b.jpg", "bee"],
		["skin/empty.txt", PackedByteArray()],
	])
	var src := SCRATCH + "/art.tar.gz"
	_write(src, tar.compress(FileAccess.COMPRESSION_GZIP))
	var dest := SCRATCH + "/art.zip"
	var report := TarPack.convert(src, dest)
	assert_true(bool(report["ok"]), String(report["why"]))
	assert_eq(int(report["files"]), 3, "directories are not files")
	var got := _entries_of(dest)
	assert_eq(got.keys().size(), 3)
	assert_eq(got.get("skin/cardart/zz_a.jpg", PackedByteArray()), big,
		"a body over many blocks, byte for byte")
	assert_eq((got.get("skin/cardart/zz_b.jpg", PackedByteArray()) as PackedByteArray)
		.get_string_from_utf8(), "bee")
	assert_true(got.has("skin/empty.txt"), "an empty file is still a file")
	var about := SkinPack.inspect(dest)
	assert_true(bool(about["ok"]))
	assert_eq(String(about["kind"]), "skin", "empty.txt makes it a skin, not card art")


func test_a_plain_tar_works_the_same() -> void:
	var src := SCRATCH + "/cards.tar"
	_write(src, _tar([["skin/cardart/zz_c.jpg", "sea"]]))
	var dest := SCRATCH + "/cards.zip"
	var report := TarPack.convert(src, dest)
	assert_true(bool(report["ok"]), String(report["why"]))
	assert_eq(String(SkinPack.inspect(dest)["kind"]), "cardart")


func test_the_names_a_tar_hands_down_in_pieces_are_put_together() -> void:
	var long_name := "skin/" + "a_folder_with_a_name_so_long_it_will_not_fit/".repeat(3) + "picture.png"
	assert_gt(long_name.length(), 100, "the header's own field is 100 bytes")
	var pax := "26 path=skin/from_pax.txt\n"   # "<length> path=<name>\n"
	var tar := _tar([
		["././@LongLink", long_name.to_utf8_buffer() + PackedByteArray([0]), "L"],
		[long_name.substr(0, 100), "long"],
		["./PaxHeaders/x", pax, "x"],
		["skin/short_name.txt", "pax"],
		["./skin/dotted.txt", "dot"],
	])
	var src := SCRATCH + "/names.tar"
	_write(src, tar)
	var dest := SCRATCH + "/names.zip"
	var report := TarPack.convert(src, dest)
	assert_true(bool(report["ok"]), String(report["why"]))
	var got := _entries_of(dest)
	assert_true(got.has(long_name), "the GNU long name, whole: %s" % [got.keys()])
	assert_true(got.has("skin/from_pax.txt"), "the pax path wins over the header's")
	assert_false(got.has("skin/short_name.txt"))
	assert_true(got.has("skin/dotted.txt"), "./ at the front dropped")
	assert_false(got.has("././@LongLink"), "the name entries are not files")
	assert_eq(int(report["files"]), 3)


func test_a_file_outside_skin_is_refused_by_the_same_words_as_a_zip() -> void:
	var src := SCRATCH + "/loose.tar.gz"
	_write(src, _tar([["skin/a.png", "a"], ["readme.txt", "loose"]])
		.compress(FileAccess.COMPRESSION_GZIP))
	var dest := SCRATCH + "/loose.zip"
	assert_true(bool(TarPack.convert(src, dest)["ok"]), "the repack judges nothing")
	var about := SkinPack.inspect(dest)
	assert_false(bool(about["ok"]))
	assert_string_contains(String(about["why"]), "an entry outside skin/: readme.txt")


func test_a_tar_cut_short_leaves_no_zip_behind() -> void:
	var whole := _tar([["skin/zz.png", _bytes(5000)]])
	var src := SCRATCH + "/short.tar"
	_write(src, whole.slice(0, BLOCK + 3000))
	var dest := SCRATCH + "/short.zip"
	var report := TarPack.convert(src, dest)
	assert_false(bool(report["ok"]))
	assert_eq(String(report["why"]), "ends before its last file does")
	assert_false(FileAccess.file_exists(dest), "a half zip would be mounted at the next start")


func test_bytes_that_are_no_tar_are_said_so() -> void:
	var src := SCRATCH + "/noise.tar"
	_write(src, _bytes(2000))
	var dest := SCRATCH + "/noise.zip"
	var report := TarPack.convert(src, dest)
	assert_false(bool(report["ok"]))
	assert_eq(String(report["why"]), "has a header the game cannot read")
	assert_false(FileAccess.file_exists(dest))
	var empty := SCRATCH + "/empty.tar"
	_write(empty, _tar([]))
	report = TarPack.convert(empty, SCRATCH + "/empty.zip")
	assert_false(bool(report["ok"]))
	assert_eq(String(report["why"]), "holds no files")


## A tar bigger than one chunk, with an entry straddling every chunk
## edge: read in steps, each further along, the last one done.
func test_a_big_tar_is_read_in_steps_that_each_make_progress() -> void:
	var entries := []
	var bodies := {}
	for i in 5:
		var body := _bytes(TarPack.CHUNK / 2 + 1000 * i + 7)
		bodies["skin/cardart/zz_%d.jpg" % i] = body
		entries.append(["skin/cardart/zz_%d.jpg" % i, body])
	var src := SCRATCH + "/big.tar"
	_write(src, _tar(entries))
	var dest := SCRATCH + "/big.zip"
	var job := TarPack.new()
	assert_true(job.open(src, dest), job.why)
	var steps := 0
	var last := 0.0
	while job.step():
		steps += 1
		assert_true(job.progress() >= last, "progress never goes back")
		last = job.progress()
		assert_lt(steps, 100, "a runaway")
	assert_true(job.done)
	assert_true(job.ok, job.why)
	assert_gt(steps, 1, "more than one chunk")
	assert_eq(job.files, 5)
	var got := _entries_of(dest)
	for name in bodies:
		assert_eq(got.get(name, PackedByteArray()), bodies[name], name)
	assert_false(job.step(), "nothing more once done")
