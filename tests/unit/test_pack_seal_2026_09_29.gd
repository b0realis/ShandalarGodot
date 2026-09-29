extends GutTest
## THE SEAL ON A CARD PACK — [PackSeal] (2026-09-29, the first Meta Quest
## report: *"very long load time — time is spent on 'card pack found'"*).
##
## Every start read every picture of every pack out of the zip to hash it
## against the manifest — 7.5 s on a desk, far longer on a headset. Now a
## pack whose pictures passed once is sealed by its fingerprint (the file
## size and the zip's central directory), and at the next start the
## manifest's word for the artwork digest stands without a picture read.
## What these pin:
##
##   1. The fingerprint is stable for one file, differs for a file with
##      another table (one picture changed, one entry more) and is "" for
##      no file or a file that is not a zip — never sealed, hashed as
##      before.
##   2. The seal list: seal / sealed / clear, newest last, at most KEPT,
##      a seal twice is one entry, "" is never sealed, a broken file is
##      an empty list.
##   3. The artwork digest is the builder's stream (sorted names, name,
##      zero byte, hex digest, newline into one SHA-256) and counts the
##      pictures it read; with a trusted value it reads nothing; with no
##      pictures the trusted value is not taken (a metadata-only pack is
##      hashed the cheap way, as before).
##   4. The manifest's claim: `checksums.artwork.sha256` or "".
##   5. End to end on a Pack 2 built with pictures: hashed, it passes and
##      counts its 408 pictures; the same pack with one picture changed
##      under an unchanged manifest is refused when hashed and passes when
##      trusted with no picture read — that is what the seal grants, and
##      the changed file has another fingerprint so it never inherits the
##      good one's seal.
##   6. `CardPacks.discover` seals every pack it accepts.

const SCRATCH := "user://pack_seal_test"
const GOOD := SCRATCH + "/good/" + FallenEmpiresPack.FILE_NAME
const CHANGED := SCRATCH + "/changed/" + FallenEmpiresPack.FILE_NAME
const BIGGER := SCRATCH + "/bigger/" + FallenEmpiresPack.FILE_NAME
const PLAIN := SCRATCH + "/plain.zip"
const NOT_A_ZIP := SCRATCH + "/not_a_zip.zip"
const PREFIX := FallenEmpiresPack.PREFIX

var _saved_seals := ""
var _had_seals := false


func before_all() -> void:
	_had_seals = FileAccess.file_exists(PackSeal.FILE)
	_saved_seals = FileAccess.get_file_as_string(PackSeal.FILE) if _had_seals else ""


func before_each() -> void:
	PackSeal.clear()
	for folder in ["good", "changed", "bigger"]:
		DirAccess.make_dir_recursive_absolute(SCRATCH.path_join(folder))
	_zip(PLAIN, {"a.txt": "a", "b.txt": "bb"})
	var file := FileAccess.open(NOT_A_ZIP, FileAccess.WRITE)
	file.store_string("this is not a zip file at all, whatever its name says")
	file.close()


func after_all() -> void:
	PackSeal.clear()
	if _had_seals:
		var file := FileAccess.open(PackSeal.FILE, FileAccess.WRITE)
		file.store_string(_saved_seals)
		file.close()
	_remove_tree(SCRATCH)


# 1. The fingerprint.

func test_the_fingerprint_is_stable_for_one_file() -> void:
	var first := PackSeal.fingerprint(PLAIN)
	assert_eq(first.length(), 64)
	assert_eq(PackSeal.fingerprint(PLAIN), first)


func test_the_fingerprint_differs_with_another_table() -> void:
	var plain := PackSeal.fingerprint(PLAIN)
	_zip(SCRATCH + "/other.zip", {"a.txt": "a", "b.txt": "bc"})
	assert_ne(PackSeal.fingerprint(SCRATCH + "/other.zip"), plain,
		"one byte of one entry is another CRC in the central directory")
	_zip(SCRATCH + "/more.zip", {"a.txt": "a", "b.txt": "bb", "c.txt": "c"})
	assert_ne(PackSeal.fingerprint(SCRATCH + "/more.zip"), plain, "one entry more")


func test_no_file_and_no_zip_have_no_fingerprint() -> void:
	assert_eq(PackSeal.fingerprint(SCRATCH + "/absent.zip"), "")
	assert_eq(PackSeal.fingerprint(NOT_A_ZIP), "")
	assert_false(PackSeal.sealed(""), "\"\" is never sealed")
	PackSeal.seal("")
	assert_false(FileAccess.file_exists(PackSeal.FILE), "and never written")


# 2. The list.

func test_seal_sealed_clear() -> void:
	assert_false(PackSeal.sealed("abc"))
	PackSeal.seal("abc")
	assert_true(PackSeal.sealed("abc"))
	assert_true(FileAccess.file_exists(PackSeal.FILE))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PackSeal.FILE))
	assert_eq(parsed, {"seals": ["abc"]})
	PackSeal.seal("def")
	PackSeal.seal("abc")
	assert_eq(PackSeal._seals(), ["def", "abc"], "a seal twice is one entry, newest last")
	PackSeal.clear()
	assert_false(PackSeal.sealed("abc"))
	assert_false(FileAccess.file_exists(PackSeal.FILE))


func test_the_list_keeps_the_newest_kept_seals() -> void:
	for i in PackSeal.KEPT + 3:
		PackSeal.seal("seal-%03d" % i)
	var seals := PackSeal._seals()
	assert_eq(seals.size(), PackSeal.KEPT)
	assert_eq(seals[0], "seal-003")
	assert_eq(seals[-1], "seal-%03d" % (PackSeal.KEPT + 2))
	assert_false(PackSeal.sealed("seal-000"))
	assert_true(PackSeal.sealed("seal-003"))


func test_a_broken_list_is_an_empty_one() -> void:
	for body in ["[1, 2]", "{\"seals\": \"abc\"}", "{\"seals\": [1, \"abc\"]}"]:
		var file := FileAccess.open(PackSeal.FILE, FileAccess.WRITE)
		file.store_string(body)
		file.close()
		assert_eq(PackSeal._seals(), ["abc"] if body.contains("[1, \"abc\"]") else [], body)
	PackSeal.clear()


# 3. The digest.

func test_the_artwork_digest_is_the_builders_stream() -> void:
	_zip(SCRATCH + "/art.zip", {"z.jpg": "zzz", "a.jpg": "aaa", "m.jpg": "mmm"})
	var reader := ZIPReader.new()
	assert_eq(reader.open(SCRATCH + "/art.zip"), OK)
	var before := PackSeal.pictures_hashed
	var digest := PackSeal.artwork_sha256(reader, ["z.jpg", "a.jpg", "m.jpg"])
	assert_eq(digest, _builder_digest({"a.jpg": "aaa", "m.jpg": "mmm", "z.jpg": "zzz"}))
	assert_eq(PackSeal.pictures_hashed, before + 3, "three pictures read")
	assert_eq(PackSeal.artwork_sha256(reader, ["a.jpg", "m.jpg", "z.jpg"]), digest,
		"the order given does not matter")
	reader.close()


func test_a_trusted_value_stands_without_a_read() -> void:
	var before := PackSeal.pictures_hashed
	var unopened := ZIPReader.new()
	assert_eq(PackSeal.artwork_sha256(unopened, ["x.jpg"], "claimed"), "claimed")
	assert_eq(PackSeal.pictures_hashed, before, "nothing read from a reader never opened")
	assert_eq(PackSeal.artwork_sha256(unopened, [], "claimed"), _builder_digest({}),
		"no pictures: the empty stream, not the claim")
	assert_eq(_builder_digest({}),
		"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")


# 4. The claim.

func test_the_manifests_claim() -> void:
	assert_eq(PackSeal.claimed_artwork({"checksums": {"artwork": {"sha256": "abc"}}}), "abc")
	assert_eq(PackSeal.claimed_artwork({"checksums": {"artwork": {}}}), "")
	assert_eq(PackSeal.claimed_artwork({"checksums": {"artwork": "abc"}}), "")
	assert_eq(PackSeal.claimed_artwork({"checksums": "abc"}), "")
	assert_eq(PackSeal.claimed_artwork({}), "")
	assert_eq(PackSeal.claimed_artwork(null), "")
	assert_eq(PackSeal.claimed_artwork("abc"), "")


# 5. End to end on Pack 2.

func test_a_pack_with_pictures_passes_hashed_and_counts_them() -> void:
	_build_pack(GOOD, "good")
	var before := PackSeal.pictures_hashed
	var report := FallenEmpiresPack.inspect(GOOD)
	assert_true(bool(report.get("ok", false)), String(report.get("why", "")))
	assert_true(bool(report.get("has_art", false)))
	assert_eq(PackSeal.pictures_hashed, before + 408, "every picture read once")
	assert_eq(CardPacks.inspect(GOOD).get("ok"), true, "through the dispatcher too")


func test_a_changed_picture_is_refused_hashed_and_passes_trusted() -> void:
	_build_pack(GOOD, "good")
	_build_pack(CHANGED, "changed")
	var before := PackSeal.pictures_hashed
	var hashed := FallenEmpiresPack.inspect(CHANGED)
	assert_false(bool(hashed.get("ok", false)))
	assert_true(String(hashed.get("why", "")).contains("artwork checksum"),
		String(hashed.get("why", "")))
	assert_eq(PackSeal.pictures_hashed, before + 408)
	var trusted := FallenEmpiresPack.inspect(CHANGED, true)
	assert_true(bool(trusted.get("ok", false)), "the manifest's word stands on a sealed pack")
	assert_eq(PackSeal.pictures_hashed, before + 408, "and no picture was read for it")
	assert_eq(CardPacks.inspect(CHANGED, true).get("ok"), true)
	assert_ne(PackSeal.fingerprint(CHANGED), PackSeal.fingerprint(GOOD),
		"the changed file has another fingerprint: it never inherits the seal")


func test_a_metadata_only_pack_takes_no_word_for_pictures_it_has_not() -> void:
	var path := OS.get_environment("SHANDALAR_PACK_2")
	assert_true(FileAccess.file_exists(path), "the wrapper's metadata-only Pack 2")
	var before := PackSeal.pictures_hashed
	assert_true(bool(FallenEmpiresPack.inspect(path, true).get("ok", false)))
	assert_eq(PackSeal.pictures_hashed, before)
	assert_false(bool(FallenEmpiresPack.inspect(path, true).get("has_art", true)))


# 6. Discovery seals.

func test_discovery_seals_every_pack_it_accepts() -> void:
	PackSeal.clear()
	var paths: Array[String] = []
	for id in ["pack-2", "pack-6"]:
		var path := OS.get_environment("SHANDALAR_PACK_" + id.trim_prefix("pack-"))
		if FileAccess.file_exists(path):
			paths.append(path)
	assert_false(paths.is_empty(), "the wrapper points at its packs")
	for path in paths:
		assert_false(PackSeal.sealed(PackSeal.fingerprint(path)), path)
	CardPacks.rescan()
	for path in paths:
		assert_true(PackSeal.sealed(PackSeal.fingerprint(path)), path)
	assert_true(FileAccess.get_file_as_string("res://game/card_packs.gd").contains(
		'"sealed" if was_sealed else "hashed"'), "and says which in the log")
	# The lines it said, for the Android start report: one per pack,
	# hashed at this scan (the seals were cleared), with its cost.
	var said := RegEx.create_from_string("^card pack: found (.*) \\((sealed|hashed), (\\d+) ms\\)$")
	var found: Array[String] = []
	for line in CardPacks.report_lines:
		var hit := said.search(line)
		assert_not_null(hit, line)
		if hit == null:
			continue
		found.append(hit.get_string(1))
		assert_eq(hit.get_string(2), "hashed", line)
	for path in paths:
		assert_has(found, path)
	CardPacks.rescan()
	assert_eq(CardPacks.report_lines.size(), found.size(), "a rescan starts the list over")
	for line in CardPacks.report_lines:
		assert_eq(said.search(line).get_string(2), "sealed", line)


# Helpers.

## The 408 Pack 2 picture names.
static func _picture_names() -> Array:
	var out := []
	for name in FallenEmpiresPack.names():
		for suffix in [".jpg", "_card.jpg"]:
			out.append(PREFIX + "art/fem/" + FallenEmpiresPack.snake(name) + suffix)
			out.append("skin/cardart/" + FallenEmpiresPack.snake(name) + suffix)
	return out


## Pack 2 at [param path] with pictures, built by Python's zipfile the
## way the pack tools build one (ZIPPacker adds folder entries, which a
## pack's exact file list refuses): the wrapper's metadata-only zip's four
## core files, the manifest given the checksums, and a small picture per
## name. [param mode] `good` is the pack as built; `changed` has one
## picture changed under the good pack's manifest.
func _build_pack(path: String, mode: String) -> void:
	var source := OS.get_environment("SHANDALAR_PACK_2")
	assert_true(FileAccess.file_exists(source), "the wrapper's metadata-only Pack 2")
	var names_file := ProjectSettings.globalize_path(SCRATCH + "/names.json")
	var file := FileAccess.open(names_file, FileAccess.WRITE)
	file.store_string(JSON.stringify(_picture_names()))
	file.close()
	var script := ProjectSettings.globalize_path(SCRATCH + "/build_pack.py")
	file = FileAccess.open(script, FileAccess.WRITE)
	file.store_string(BUILDER)
	file.close()
	var output := []
	var code := OS.execute("python3", [script, ProjectSettings.globalize_path(source),
		ProjectSettings.globalize_path(path), names_file, PREFIX, mode], output, true)
	assert_eq(code, 0, "\n".join(PackedStringArray(output)))


const BUILDER := """
import hashlib
import json
import sys
import zipfile

source, out, names_file, prefix, mode = sys.argv[1:6]
CORE = ["catalog.json", "cards.json", "README.txt"]
with open(names_file) as handle:
    names = json.load(handle)
pictures = {name: ("picture of " + name).encode("utf-8") for name in names}
claimed = dict(pictures)
if mode == "changed":
    pictures[sorted(pictures)[0]] = b"another picture"


def sha256(payload):
    return hashlib.sha256(payload).hexdigest()


def artwork_sha256(entries):
    digest = hashlib.sha256()
    for name, payload in sorted(entries.items()):
        digest.update(name.encode("utf-8") + b"\\0" + sha256(payload).encode("ascii") + b"\\n")
    return digest.hexdigest()


with zipfile.ZipFile(source) as archive:
    core = {name: archive.read(prefix + name) for name in CORE}
    manifest = json.loads(archive.read(prefix + "manifest.json"))
manifest["checksums"] = {
    "algorithm": "sha256",
    "metadata": {name: sha256(core[name]) for name in CORE},
    "artwork": {"files": len(pictures), "sha256": artwork_sha256(claimed)},
}
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
    archive.writestr(prefix + "manifest.json", json.dumps(manifest, indent=2))
    for name in CORE:
        archive.writestr(prefix + name, core[name])
    for name in sorted(pictures):
        archive.writestr(name, pictures[name])
"""


## The Python builder's artwork digest of [param pictures] (name → body).
static func _builder_digest(pictures: Dictionary) -> String:
	var names := pictures.keys()
	names.sort()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for name in names:
		var body: Variant = pictures[name]
		var payload: PackedByteArray = body if body is PackedByteArray else String(body).to_utf8_buffer()
		var inner := HashingContext.new()
		inner.start(HashingContext.HASH_SHA256)
		inner.update(payload)
		hashing.update(String(name).to_utf8_buffer())
		hashing.update(PackedByteArray([0]))
		hashing.update(inner.finish().hex_encode().to_utf8_buffer())
		hashing.update("\n".to_utf8_buffer())
	return hashing.finish().hex_encode()


static func _zip(path: String, entries: Dictionary) -> void:
	var packer := ZIPPacker.new()
	assert(packer.open(path) == OK)
	for name in entries:
		packer.start_file(name)
		var body: Variant = entries[name]
		packer.write_file(body if body is PackedByteArray else String(body).to_utf8_buffer())
		packer.close_file()
	packer.close()


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
