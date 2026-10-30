extends GutTest
## THE SEAL IS A FILE'S, A REFUSAL IS REMEMBERED, AND THE PICTURE READER
## TAKES NO LOCAL HEADER THE ZIP LIBRARY WOULD REFUSE (robustness campaign
## of 2026-10-12: r3-4, r5-5, b1-7, and Pack 1's order).
##
##   1. r3-4. The seal was the SHA-256 of the file's size and central
##      directory — the same for a copy damaged in its DATA. A damaged copy
##      in the card folder was refused, the good copy of the same pack in
##      another folder was hashed and sealed, and at the next start the
##      damaged copy was taken as sealed. Now the seal binds the directory
##      to the file — its path and modification time — so a copy elsewhere,
##      or a copy over the same name, is checked for itself. An older
##      build's seal (the directory alone) still stands for the one file
##      that has that directory, so no player waits for every pack again;
##      where two files share it, both are checked.
##   2. r5-5. A pack refused after its pictures were read was read again at
##      every start (the check screen at every start, three engine errors
##      each time): the refusal is now remembered for that file and this
##      game version. The screen counts only the packs that will be read.
##   3. b1-7. The one-pass reader ([method PackSeal._indexed_sha256s]) took
##      a picture whose local header disagrees with the directory, which
##      the zip library (and so the mounted pack) refuses: it now gives up
##      on such a zip ({}), and the zip is read the old way, which decides.
##   4. Pack 1 read its pictures before its version and identity checks;
##      a Pack 1 refused by those reads nothing now, as Packs 2–9 never did.

const SCRATCH := "user://c2_f_packs_seal"
const GOOD := SCRATCH + "/good/" + FallenEmpiresPack.FILE_NAME
const DAMAGED := SCRATCH + "/damaged/" + FallenEmpiresPack.FILE_NAME
const LAYOUT := SCRATCH + "/layout/" + FallenEmpiresPack.FILE_NAME
const FUTURE := SCRATCH + "/future/" + CardPacks.FILE_NAME
const PLAIN := SCRATCH + "/plain/plain.zip"
const COPY := SCRATCH + "/copy/plain.zip"

var _had_seals := false
var _saved_seals := ""
var _available: Dictionary = {}
var _rejections: Array[Dictionary] = []
var _lines: Array[String] = []


func before_all() -> void:
	_had_seals = FileAccess.file_exists(PackSeal.FILE)
	_saved_seals = FileAccess.get_file_as_string(PackSeal.FILE) if _had_seals else ""
	for folder in ["good", "damaged", "layout", "future", "plain", "copy"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH.path_join(folder)))
	_build_pack_2(GOOD, "good")
	_build_pack_2(DAMAGED, "damaged")
	var packer := ZIPPacker.new()
	assert_eq(packer.open(ProjectSettings.globalize_path(LAYOUT)), OK)
	packer.start_file("card_packs/pack_2_fallen_empires/README.txt")
	packer.write_file("not the layout".to_utf8_buffer())
	packer.close_file()
	packer.close()


func after_all() -> void:
	PackSeal.clear()
	if _had_seals:
		var file := FileAccess.open(PackSeal.FILE, FileAccess.WRITE)
		file.store_string(_saved_seals)
		file.close()
	_remove_tree(SCRATCH)


func before_each() -> void:
	PackSeal.clear()
	_available = CardPacks._available.duplicate()
	_rejections = CardPacks._rejections.duplicate()
	_lines = CardPacks.report_lines.duplicate()
	CardPacks._available.clear()
	CardPacks._rejections.clear()
	CardPacks.report_lines.clear()


func after_each() -> void:
	PackSeal.progress = Callable()
	CardPacks._available = _available
	CardPacks._rejections = _rejections
	CardPacks.report_lines = _lines


# 1. The seal is the file's.

func test_a_byte_for_byte_copy_elsewhere_has_a_seal_of_its_own() -> void:
	_zip(PLAIN, {"a.txt": "a", "b.txt": "bb"})
	DirAccess.copy_absolute(ProjectSettings.globalize_path(PLAIN), ProjectSettings.globalize_path(COPY))
	assert_eq(PackSeal.table_fingerprint(COPY), PackSeal.table_fingerprint(PLAIN),
		"the same directory: what the old seal was")
	assert_ne(PackSeal.fingerprint(COPY), PackSeal.fingerprint(PLAIN),
		"but each file is sealed for itself")
	assert_eq(PackSeal.fingerprint(PLAIN), PackSeal.fingerprint(PLAIN), "stable for one file")
	assert_eq(PackSeal.fingerprint(PLAIN).length(), 64)


func test_a_file_copied_over_the_same_name_is_checked_again() -> void:
	_zip(PLAIN, {"a.txt": "a", "b.txt": "bb"})
	var before := PackSeal.fingerprint(PLAIN)
	assert_eq(OS.execute("touch", ["-d", "2001-02-03 04:05:06", ProjectSettings.globalize_path(PLAIN)]), 0)
	assert_ne(PackSeal.fingerprint(PLAIN), before,
		"another modification time: another file as far as the seal knows")


func test_a_damaged_copy_never_inherits_the_good_copys_seal() -> void:
	assert_eq(PackSeal.table_fingerprint(DAMAGED), PackSeal.table_fingerprint(GOOD),
		"damaged in its data only: the directory is the good pack's")
	var start := PackSeal.pictures_hashed
	CardPacks._take_packs([DAMAGED, GOOD], false)
	assert_eq(String(CardPacks.status(FallenEmpiresPack.ID).get("path", "")), GOOD,
		"the good copy is the pack")
	assert_true(_refused(DAMAGED).contains("checksum"), _refused(DAMAGED))
	assert_gt(PackSeal.pictures_hashed, start, "both were read, the first time")
	assert_true(PackSeal.sealed(PackSeal.fingerprint(GOOD)))
	assert_false(PackSeal.sealed(PackSeal.fingerprint(DAMAGED)))
	# The next start.
	CardPacks._available.clear()
	CardPacks._rejections.clear()
	CardPacks.report_lines.clear()
	var second := PackSeal.pictures_hashed
	CardPacks._take_packs([DAMAGED, GOOD], false)
	assert_eq(String(CardPacks.status(FallenEmpiresPack.ID).get("path", "")), GOOD,
		"the damaged copy is refused again, not taken as sealed")
	assert_true(_refused(DAMAGED).contains("checksum"), _refused(DAMAGED))
	assert_eq(PackSeal.pictures_hashed, second,
		"and nothing was read: the good copy is sealed, the damaged one remembered")
	assert_has(CardPacks.report_lines, _found_line(GOOD, "sealed"))


func test_an_older_builds_seal_stands_for_the_one_file_with_that_directory() -> void:
	PackSeal.seal(PackSeal.table_fingerprint(GOOD))
	var start := PackSeal.pictures_hashed
	CardPacks._take_packs([GOOD], false)
	assert_true(CardPacks.has_pack(FallenEmpiresPack.ID))
	assert_eq(PackSeal.pictures_hashed, start, "no picture read for a pack sealed by an older build")
	assert_true(PackSeal.sealed(PackSeal.fingerprint(GOOD)), "now sealed as a file")
	assert_false(PackSeal.sealed(PackSeal.table_fingerprint(GOOD)), "the old seal is used up")


func test_an_older_builds_seal_shared_by_two_files_stands_for_neither() -> void:
	PackSeal.seal(PackSeal.table_fingerprint(GOOD))
	CardPacks._take_packs([DAMAGED, GOOD], false)
	assert_true(_refused(DAMAGED).contains("checksum"),
		"the damaged twin is read and refused: " + _refused(DAMAGED))
	assert_eq(String(CardPacks.status(FallenEmpiresPack.ID).get("path", "")), GOOD)


# 2. A refusal remembered; the count.

func test_a_refusal_is_remembered_for_this_file_and_this_version() -> void:
	PackSeal.refuse("abc", "its artwork checksum does not match")
	assert_eq(PackSeal.refusal("abc"), "its artwork checksum does not match")
	assert_eq(PackSeal.refusal("def"), "")
	assert_eq(PackSeal.refusal(""), "")
	PackSeal.seal("abc")
	assert_eq(PackSeal.refusal("abc"), "", "a file sealed is no longer refused")
	PackSeal.refuse("abc", "why")
	assert_false(PackSeal.sealed("abc"), "nor a file refused sealed")
	# Another game version reads it again: it may judge the file otherwise.
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PackSeal.FILE))
	parsed["refused"]["abc"]["game"] = "0.0.1"
	var file := FileAccess.open(PackSeal.FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()
	assert_eq(PackSeal.refusal("abc"), "", "remembered by another version: not taken")


func test_a_pack_refused_before_any_picture_is_read_is_not_remembered() -> void:
	CardPacks._take_packs([LAYOUT], false)
	assert_ne(_refused(LAYOUT), "")
	assert_eq(PackSeal.refusal(PackSeal.fingerprint(LAYOUT)), "",
		"refused in milliseconds: nothing to save by remembering it")


func test_the_check_counts_only_the_packs_whose_pictures_will_be_read() -> void:
	CardPacks._take_packs([DAMAGED], false)   # read once, refused, remembered
	var plan := CardPacks._hash_plan([LAYOUT, DAMAGED, GOOD])
	assert_eq(int(plan["to_hash"]), 1,
		"the bad layout is refused at once, the damaged copy is remembered: one pack to read")
	PackSeal.seal(PackSeal.fingerprint(GOOD))
	assert_eq(int(CardPacks._hash_plan([LAYOUT, DAMAGED, GOOD])["to_hash"]), 0, "and none once sealed")


func test_hashing_an_empty_picture_is_quiet() -> void:
	# HashingContext.update errors on an empty buffer (an engine ERROR line
	# at every start for a pack with an entry that read back empty).
	assert_eq(PackSeal._sha256(PackedByteArray()),
		"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")


# 3. The local header.

func test_a_local_header_that_disagrees_with_the_directory_is_not_taken() -> void:
	var files := {}
	for i in 5:
		files["card_packs/test/art/card_%d.jpg" % i] = ("picture %d " % i).repeat(40 + i).to_utf8_buffer()
	var names: Array = files.keys()
	for field in [{"at": 14, "what": "its CRC"}, {"at": 8, "what": "its method"},
			{"at": 22, "what": "its size"}, {"at": 30, "what": "its name"}]:
		var path := SCRATCH.path_join("plain/local_%d.zip" % int(field["at"]))
		_zip(path, files)
		var clean := PackSeal._indexed_sha256s(path, names)
		assert_eq(clean.size(), names.size(), "read whole before the change")
		_flip_local(path, String(names[2]), int(field["at"]))
		assert_eq(PackSeal._indexed_sha256s(path, names), {},
			"a local header that disagrees in %s: the zip is left to the zip library" % field["what"])


# 4. Pack 1's order.

func test_a_pack_1_refused_for_its_version_reads_no_picture() -> void:
	_build_pack_1(FUTURE)
	var start := PackSeal.pictures_hashed
	var report := CardPacks.inspect(FUTURE)
	assert_false(bool(report.get("ok", true)))
	assert_string_contains(String(report.get("why", "")), "requires game version")
	assert_eq(PackSeal.pictures_hashed, start, "refused before a single picture is read")


# Helpers.

func _refused(path: String) -> String:
	for one in CardPacks._rejections:
		if String(one.get("path", "")) == path:
			return String(one.get("why", ""))
	return ""


func _found_line(path: String, how: String) -> String:
	for line in CardPacks.report_lines:
		if line.begins_with("card pack: found %s (%s," % [path, how]):
			return line
	return "card pack: found %s (%s, …)" % [path, how]


## Flip the byte at [param offset] in the local header of [param name].
func _flip_local(path: String, name: String, offset: int) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var bytes := FileAccess.get_file_as_bytes(absolute)
	var at := 0
	while at + 30 < bytes.size():
		if bytes.decode_u32(at) == 0x04034B50:
			var size := bytes.decode_u16(at + 26)
			if bytes.slice(at + 30, at + 30 + size).get_string_from_utf8() == name:
				bytes[at + offset] = bytes[at + offset] ^ (0x08 if offset == 8 else 0x5A)
				break
		at += 1
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


static func _zip(path: String, entries: Dictionary) -> void:
	var packer := ZIPPacker.new()
	assert(packer.open(ProjectSettings.globalize_path(path)) == OK)
	for name in entries:
		packer.start_file(name)
		var body: Variant = entries[name]
		packer.write_file(body if body is PackedByteArray else String(body).to_utf8_buffer())
		packer.close_file()
	packer.close()


## Pack 2 at [param path], its pictures STORED (so a changed byte is found
## by the digest, not by an inflate whose CRC failure the engine logs);
## `damaged` flips one byte inside one picture's data afterwards, leaving
## the size and the central directory exactly the good pack's.
func _build_pack_2(path: String, mode: String) -> void:
	var names: Array = []
	for name in FallenEmpiresPack.names():
		for suffix in [".jpg", "_card.jpg"]:
			names.append(FallenEmpiresPack.PREFIX + "art/fem/" + FallenEmpiresPack.snake(name) + suffix)
			names.append("skin/cardart/" + FallenEmpiresPack.snake(name) + suffix)
	_python(PACK_2, [OS.get_environment("SHANDALAR_PACK_2"), path, names,
		FallenEmpiresPack.PREFIX, mode])


## Pack 1 at [param path] with all its pictures and a manifest asking for a
## game version from the future.
func _build_pack_1(path: String) -> void:
	var source := OS.get_environment("SHANDALAR_PACK_1")
	var reader := ZIPReader.new()
	assert_eq(reader.open(source), OK)
	var cards: Variant = JSON.parse_string(reader.read_file(CardPacks.CARDS).get_string_from_utf8())
	reader.close()
	_python(PACK_1, [source, path, CardPacks._expected_art_files(cards), CardPacks.PREFIX, "future"])


func _python(code: String, args: Array) -> void:
	assert_true(FileAccess.file_exists(String(args[0])), "the wrapper's metadata-only pack")
	var names_file := ProjectSettings.globalize_path(SCRATCH + "/names.json")
	var file := FileAccess.open(names_file, FileAccess.WRITE)
	file.store_string(JSON.stringify(args[2]))
	file.close()
	var script := ProjectSettings.globalize_path(SCRATCH + "/build.py")
	file = FileAccess.open(script, FileAccess.WRITE)
	file.store_string(code)
	file.close()
	var output := []
	var status := OS.execute("python3", ["-I", script, ProjectSettings.globalize_path(String(args[0])),
		ProjectSettings.globalize_path(String(args[1])), names_file, String(args[3]), String(args[4])],
		output, true)
	assert_eq(status, 0, "\n".join(PackedStringArray(output)))


const PACK_2 := """
import hashlib, json, sys, zipfile

source, out, names_file, prefix, mode = sys.argv[1:6]
CORE = ["catalog.json", "cards.json", "README.txt"]
names = json.load(open(names_file))
pictures = {name: ("picture of " + name).encode("utf-8") * 4 for name in names}

def sha(b):
    return hashlib.sha256(b).hexdigest()

# One fixed date for every entry: writestr stamps the clock (2-second steps),
# so a good and a damaged build on either side of a tick had different
# directories (a CI failure of 2026-10-30).
def put(z, name, data):
    info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
    info.external_attr = 0o600 << 16
    z.writestr(info, data)

def art(entries):
    d = hashlib.sha256()
    for name, payload in sorted(entries.items()):
        d.update(name.encode("utf-8") + b"\\0" + sha(payload).encode("ascii") + b"\\n")
    return d.hexdigest()

with zipfile.ZipFile(source) as z:
    core = {n: z.read(prefix + n) for n in CORE}
    manifest = json.loads(z.read(prefix + "manifest.json"))
manifest["checksums"] = {"algorithm": "sha256", "metadata": {n: sha(core[n]) for n in CORE},
    "artwork": {"files": len(pictures), "sha256": art(pictures)}}
with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
    put(z, prefix + "manifest.json", json.dumps(manifest, indent=2))
    for n in CORE:
        put(z, prefix + n, core[n])
    for n in sorted(pictures):
        put(z, n, pictures[n])
if mode == "damaged":
    victim = sorted(pictures)[len(pictures) // 2]
    with zipfile.ZipFile(out) as z:
        info = z.getinfo(victim)
    with open(out, "r+b") as f:
        f.seek(info.header_offset + 26)
        lengths = f.read(4)
        start = info.header_offset + 30 + int.from_bytes(lengths[:2], "little") + int.from_bytes(lengths[2:], "little")
        f.seek(start + 5)
        b = f.read(1)
        f.seek(start + 5)
        f.write(bytes([b[0] ^ 0xFF]))
"""


const PACK_1 := """
import hashlib, json, sys, zipfile

source, out, names_file, prefix, mode = sys.argv[1:6]
CORE = ["catalog.json", "cards.json", "README.txt"]
names = json.load(open(names_file))
pictures = {name: ("picture of " + name).encode("utf-8") for name in names}

def sha(b):
    return hashlib.sha256(b).hexdigest()

def art(entries):
    d = hashlib.sha256()
    for name, payload in sorted(entries.items()):
        d.update(name.encode("utf-8") + b"\\0" + sha(payload).encode("ascii") + b"\\n")
    return d.hexdigest()

with zipfile.ZipFile(source) as z:
    core = {n: z.read(prefix + n) for n in CORE}
    manifest = json.loads(z.read(prefix + "manifest.json"))
manifest["checksums"] = {"algorithm": "sha256", "metadata": {n: sha(core[n]) for n in CORE},
    "artwork": {"files": len(pictures), "sha256": art(pictures)}}
if mode == "future":
    manifest["minimum_game_version"] = "99.0.0"
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr(prefix + "manifest.json", json.dumps(manifest, indent=2))
    for n in CORE:
        z.writestr(prefix + n, core[n])
    for n in sorted(pictures):
        z.writestr(n, pictures[n])
"""


static func _remove_tree(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var child := folder.path_join(name)
		if dir.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(folder)
