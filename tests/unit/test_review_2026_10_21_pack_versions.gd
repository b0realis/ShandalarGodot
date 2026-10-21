extends GutTest
## PACKS 2-9 SAY WHICH VERSION IS WRONG (review 2026-10-21, cards-1).
##
## Every expansion contract compared the zip's manifest key by key with its
## trusted copy in `packaging/card_packs/<pack>/manifest.json` BEFORE its
## own `requires game version` check. A manifest that passes that
## comparison carries the trusted minimum, which this build always meets,
## so the friendly refusal could never be reached in any of the eight: a
## pack built for a newer game, or an older build of the same pack, was
## refused as `Pack N manifest mismatch: version` (Packs 2-5, whose keys
## are in writing order) or `… mismatch: minimum_game_version` (Packs 6-9,
## whose keys are alphabetical). Pack 1 always checked the versions first
## ([method CardPacks.inspect]), and now all nine do. The refusal stays;
## only its reason changes.
##
## Each case is the runner's own metadata-only pack (`SHANDALAR_PACK_N`)
## with its manifest changed and nothing else, so the layout check passes
## and the manifest is what decides.

const SCRATCH := "user://review_2026_10_21_pack_versions"
const FUTURE := "99.0.0"


## [number, file name, path prefix] for Packs 2-9.
func _packs() -> Array:
	return [
		[2, FallenEmpiresPack.FILE_NAME, FallenEmpiresPack.PREFIX],
		[3, IceAgePack.FILE_NAME, IceAgePack.PREFIX],
		[4, HomelandsPack.FILE_NAME, HomelandsPack.PREFIX],
		[5, AlliancesPack.FILE_NAME, AlliancesPack.PREFIX],
		[6, PortalPack.FILE_NAME, PortalPack.PREFIX],
		[7, FifthEditionPack.FILE_NAME, FifthEditionPack.PREFIX],
		[8, MirageBlockPack.FILE_NAME, MirageBlockPack.PREFIX],
		[9, TempestBlockPack.FILE_NAME, TempestBlockPack.PREFIX],
	]


func _inspect(number: int, path: String) -> Dictionary:
	match number:
		2: return FallenEmpiresPack.inspect(path)
		3: return IceAgePack.inspect(path)
		4: return HomelandsPack.inspect(path)
		5: return AlliancesPack.inspect(path)
		6: return PortalPack.inspect(path)
		7: return FifthEditionPack.inspect(path)
		8: return MirageBlockPack.inspect(path)
		9: return TempestBlockPack.inspect(path)
	return {}


func _trusted(prefix: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(
		"res://packaging/" + prefix + "manifest.json"))


## Pack [param number] rebuilt under `<SCRATCH>/<tag>/` from the runner's
## metadata-only zip, its manifest changed by [param tweak] (a null value
## takes the key out). Its path, or "" when the runner built no such pack.
func _build(row: Array, tweak: Dictionary, tag: String) -> String:
	var source := OS.get_environment("SHANDALAR_PACK_%d" % int(row[0]))
	if source == "" or not FileAccess.file_exists(source):
		return ""
	var prefix: String = row[2]
	var reader := ZIPReader.new()
	assert_eq(reader.open(source), OK)
	var entries := {}
	for name in reader.get_files():
		entries[name] = reader.read_file(name).get_string_from_utf8()
	reader.close()
	var manifest: Dictionary = JSON.parse_string(entries[prefix + "manifest.json"])
	for key in tweak:
		if tweak[key] == null:
			manifest.erase(key)
		else:
			manifest[key] = tweak[key]
	entries[prefix + "manifest.json"] = JSON.stringify(manifest, "  ")
	var folder := SCRATCH.path_join(tag)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := ProjectSettings.globalize_path(folder.path_join(String(row[1])))
	# Written by Python's zipfile, as the runner's packs are: ZIPPacker
	# adds a folder entry of its own, which no pack layout allows.
	var spec := path + ".json"
	var file := FileAccess.open(spec, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries))
	file.close()
	var output := []
	var status := OS.execute("python3", ["-I", "-c",
		"import json, sys, zipfile\nentries = json.load(open(sys.argv[1], encoding='utf-8'))\nwith zipfile.ZipFile(sys.argv[2], 'w', zipfile.ZIP_DEFLATED) as z:\n    for name, text in entries.items():\n        z.writestr(name, text.encode('utf-8'))\n",
		spec, path], output, true)
	assert_eq(status, 0, "\n".join(PackedStringArray(output)))
	return path


func _why(row: Array, tweak: Dictionary, tag: String) -> String:
	var path := _build(row, tweak, tag)
	if path == "":
		return "<no Pack %d from the runner>" % int(row[0])
	var report := _inspect(int(row[0]), path)
	assert_false(bool(report.get("ok", true)), "Pack %d is refused (%s)" % [int(row[0]), tag])
	return String(report.get("why", ""))


func test_the_copy_with_its_manifest_untouched_is_taken() -> void:
	# The harness itself: the rebuilt zip reaches the end of the contract,
	# so the refusals below are the manifest's and nothing else's.
	for row in _packs():
		var path := _build(row, {}, "same")
		assert_ne(path, "", "the runner built Pack %d" % int(row[0]))
		if path == "":
			continue
		var report := _inspect(int(row[0]), path)
		assert_true(bool(report.get("ok", false)),
			"Pack %d as built: %s" % [int(row[0]), report.get("why", "")])


func test_a_pack_built_for_a_newer_game_says_which_game_version_it_needs() -> void:
	var game := String(ProjectSettings.get_setting("application/config/version", ""))
	for row in _packs():
		var why := _why(row, {"minimum_game_version": FUTURE, "version": "9.0.0"}, "newer")
		assert_eq(why, "requires game version %s or newer (this is %s)" % [FUTURE, game],
			"Pack %d, in Pack 1's own words" % int(row[0]))


func test_a_newer_minimum_alone_is_still_the_game_versions_refusal() -> void:
	for row in _packs():
		var why := _why(row, {"minimum_game_version": FUTURE}, "minimum")
		assert_string_starts_with(why, "requires game version " + FUTURE,
			"Pack %d" % int(row[0]))


func test_an_older_build_of_the_pack_says_the_pack_and_game_versions_differ() -> void:
	for row in _packs():
		var number := int(row[0])
		var trusted := _trusted(String(row[2]))
		var why := _why(row, {"version": "0.9.0"}, "older")
		assert_eq(why, "this is Pack %d version 0.9.0, and this game needs version %s: rebuild %s with this release's tools/%s.py" % [
				number, String(trusted["version"]), String(row[1]),
				String(row[2]).get_slice("/", 1)],
			"Pack %d names both versions and the way out" % number)
		assert_false(why.contains("manifest mismatch"), "not the old cryptic reason")


func test_any_other_difference_is_still_a_manifest_mismatch() -> void:
	for row in _packs():
		assert_eq(_why(row, {"name": "Somebody Else's Pack"}, "renamed"),
			"Pack %d manifest mismatch: name" % int(row[0]))


func test_a_manifest_without_its_versions_is_refused_without_a_script_error() -> void:
	for row in _packs():
		var why := _why(row, {"minimum_game_version": null, "version": null}, "bare")
		assert_string_starts_with(why, "Pack %d manifest mismatch: " % int(row[0]))
	for row in _packs():
		var why := _why(row, {"minimum_game_version": 99, "version": 1}, "numbers")
		assert_string_starts_with(why, "Pack %d manifest mismatch: " % int(row[0]),
			"a version that is not text is the manifest's fault, not a game version")
