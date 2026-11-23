extends GutTest
## THE GAME'S OWN PACK RECIPES ARE THE PYTHON TOOLS' (campaign 2026-11-23).
##
## [PackRecipes] ports `tools/fetch_card_art.py` and `tools/pack_N_*.py`:
## which cards a pack holds, what Scryfall is asked, what each file is
## called and what the zip lists. [PackJson] ports the tools' JSON writer,
## whose bytes each tool's `verify` compares. Here every one of the eleven
## recipes is held to the digests the Python tools compute
## (`tests/fixtures/c1123_pack_digests.json`, which
## `tools/test_c1123_pack_digests.py` keeps true), to the pack contracts in
## the game, and — where the owner's own built packs lie beside the
## checkout — to their entry lists, read only.

const DIGESTS := "res://tests/fixtures/c1123_pack_digests.json"
const BUILT := "res://../shandalar-packs/"

var _python := {}


func before_all() -> void:
	_python = JSON.parse_string(FileAccess.get_file_as_string(DIGESTS))


func _sha(payload: PackedByteArray) -> String:
	return PackWriter.sha256(payload)


func _lines(names: Array) -> String:
	return _sha("\n".join(PackedStringArray(PackJson.sorted(names))).to_utf8_buffer())


func test_the_json_writer_writes_python_s_bytes() -> void:
	var value := {"b": [1, 2.0, "x"], "a": {"z": null, "é": true, "A": false},
		"empty": [], "none": {}, "text": "q\"\\\n\t\u0001é—"}
	var wanted := "{\n  \"a\": {\n    \"A\": false,\n    \"z\": null,\n    \"é\": true\n  },\n" \
		+ "  \"b\": [\n    1,\n    2,\n    \"x\"\n  ],\n  \"empty\": [],\n  \"none\": {},\n" \
		+ "  \"text\": \"q\\\"\\\\\\n\\t\\u0001é—\"\n}\n"
	assert_eq(PackJson.bytes(value).get_string_from_utf8(), wanted)
	assert_eq(PackJson.bytes([]).get_string_from_utf8(), "[]\n")
	assert_true(PackJson.bytes({"half": 0.5}).is_empty(), "a fraction is refused, not guessed")
	assert_ne(PackJson.refused, "")


func test_names_sort_as_python_sorts_them() -> void:
	assert_eq(PackJson.sorted(["b", "a", "Z", "ab", "é", "a b", "Æther", "a"]),
		["Z", "a", "a", "a b", "ab", "b", "Æther", "é"])


func test_file_names_and_script_names() -> void:
	assert_eq(PackRecipes.snake("Mishra's Factory"), "mishra_s_factory")
	assert_eq(PackRecipes.snake("Dandân"), "dand_n")
	assert_eq(PackRecipes.snake("Will-o'-the-Wisp"), "will_o_the_wisp")
	assert_eq(PackRecipes.slug("Dandân"), "dandan")
	assert_eq(PackRecipes.slug("Ifh-Bíff Efreet"), "ifh_biff_efreet")
	assert_eq(PackRecipes.slug("Ring of Ma'rûf"), "ring_of_ma_ruf")
	assert_eq(PackRecipes.query_value("Ring of Ma'rûf"), "Ring+of+Ma%27r%C3%BBf")
	assert_eq(PackRecipes.named_lookups("Dandân", "arn"), [
		"https://api.scryfall.com/cards/named?exact=Dand%C3%A2n&set=arn",
		"https://api.scryfall.com/cards/named?exact=Dand%C3%A2n"])


func test_eleven_recipes_in_the_window_s_order() -> void:
	assert_eq(PackRecipes.ids(), ["base", "pack-1", "pack-2", "pack-3", "pack-4", "pack-5",
		"pack-6", "pack-7", "pack-8", "pack-9", "pack-10"])
	assert_eq(PackRecipes.BASE_FILE, SkinPack.ART_FILE_NAME)
	assert_eq(PackRecipes.number_of("pack-10"), 10)
	assert_eq(PackRecipes.number_of("pack-11"), 0)
	assert_false(bool(PackRecipes.recipe("pack-11").get("ok", true)))
	assert_eq(PackRecipes.about("nothing"), {})


func test_a_build_that_lacks_a_pack_s_list_says_which_file() -> void:
	for id: String in PackRecipes.ids():
		assert_eq(PackRecipes.lacking(id), "", id + " is whole in a checkout")
		for path: String in PackRecipes.sources(id):
			assert_true(path.begins_with("res://cards/data/") or path.begins_with("res://packaging/card_packs/"), path)
	assert_eq(PackRecipes.lacking("pack-11"), "pack-11")
	# An export whose filters left the packs' lists out.
	PackRecipes.packaging = "res://packaging/no_such_folder/"
	assert_eq(PackRecipes.lacking("pack-1"), "packaging/no_such_folder/pack_1_dotp_complete/manifest.json")
	assert_eq(PackRecipes.lacking("pack-7"), "packaging/no_such_folder/pack_7_fifth_edition/manifest.json")
	assert_eq(PackRecipes.lacking("base"), "", "the 1997 pictures need only cards/data")
	var refused := PackRecipes.recipe("pack-1")
	assert_false(bool(refused.get("ok", true)))
	assert_string_contains(String(refused.get("why")), "missing")
	assert_false(bool(PackRecipes.recipe("pack-8").get("ok", true)))
	PackRecipes.packaging = PackRecipes.PACKAGING
	assert_true(bool(PackRecipes.recipe("pack-1").get("ok", false)))


func after_each() -> void:
	PackRecipes.packaging = PackRecipes.PACKAGING


func test_every_numbered_recipe_is_its_python_tool_s() -> void:
	for number in range(1, 11):
		var id := "pack-%d" % number
		var python: Dictionary = _python[str(number)]
		var recipe := PackRecipes.recipe(id)
		assert_true(bool(recipe.get("ok", false)), "%s: %s" % [id, recipe.get("why", "")])
		if not bool(recipe.get("ok", false)):
			continue
		var about := PackRecipes.about(id)
		assert_eq(recipe["file_name"], python["file_name"], id)
		assert_eq(recipe["file_name"], CardPacks.file_name_for(id), id)
		assert_eq(about["title"], "Pack %d: %s" % [number, python["name"]], id)
		var metadata: Dictionary = recipe["metadata"]
		assert_eq(metadata.keys(), ["catalog.json", "cards.json", "README.txt"], id)
		for name: String in metadata:
			assert_eq(_sha(metadata[name]), python[name], "%s %s" % [id, name])
		assert_eq(_sha(PackJson.bytes(recipe["manifest"])), python["manifest"], id + " manifest")
		var names: Array = []
		var pictures := {}
		for entry: Array in recipe["entries"]:
			names.append(entry[0])
			pictures[entry[1]] = true
		assert_eq(names.size(), int(python["art_entries"]), id + " entries")
		assert_eq(_lines(names), python["art_names"], id + " entry names")
		assert_eq(pictures.size(), int(python["pictures"]), id + " pictures")
		assert_eq(_lines(pictures.keys()), python["picture_names"], id + " picture names")
		assert_eq((recipe["jobs"] as Array).size(), int(python["jobs"]), id + " jobs")
		# What the window says before a recipe is read.
		assert_eq(int(about["pictures"]), pictures.size(), id + " about.pictures")
		assert_eq(int(about["entries"]), names.size() + 4, id + " about.entries")
		assert_eq(int(recipe["max_entries"]), names.size() + 4, id)
		# Every picture a job fetches is one the zip holds, and the other way.
		var fetched := {}
		for job: Dictionary in recipe["jobs"]:
			for file: Array in job["files"]:
				fetched[file[0]] = true
				assert_true(String(file[1]) in ["art_crop", "border_crop"])
			for url: String in job["lookups"]:
				assert_true(url.begins_with("https://api.scryfall.com/cards/"), url)
				assert_false(PackTransport.parts_of(url).is_empty(), url)
		assert_eq(PackJson.sorted(fetched.keys()), PackJson.sorted(pictures.keys()), id)


func test_the_contracts_bounds_are_the_recipes() -> void:
	var contracts := {2: FallenEmpiresPack, 3: IceAgePack, 4: HomelandsPack, 5: AlliancesPack,
		6: PortalPack, 7: FifthEditionPack, 8: MirageBlockPack, 9: TempestBlockPack,
		10: UrzaBlockPack}
	assert_eq(int(PackRecipes.PACKS[1]["entries"]), CardPacks.MAX_ENTRIES)
	assert_eq(String(PackRecipes.PACKS[1]["file"]), CardPacks.FILE_NAME)
	assert_eq(PackRecipes.DOTP_COUNTS, CardPacks.EXPECTED_COUNTS)
	assert_eq(PackRecipes.DOTP_MISSING, CardPacks.ADDED_NAMES)
	for number: int in contracts:
		var contract: Script = contracts[number]
		var row: Dictionary = PackRecipes.PACKS[number]
		assert_eq(int(row["entries"]), int(contract.MAX_ENTRIES), "Pack %d" % number)
		assert_eq(String(row["file"]), String(contract.FILE_NAME))
		assert_eq("card_packs/%s/" % row["dir"], String(contract.PREFIX))
	for number in [8, 9, 10]:
		assert_eq(PackRecipes.BLOCK_MAX_BYTES, int((contracts[number] as Script).MAX_BYTES))


func test_the_1997_pictures_are_fetch_card_art_s() -> void:
	var python: Dictionary = _python["base"]
	var recipe := PackRecipes.recipe(PackRecipes.BASE)
	assert_true(bool(recipe.get("ok", false)), String(recipe.get("why", "")))
	var jobs: Array = recipe["jobs"]
	assert_eq(jobs.size(), int(python["jobs"]))
	var pool := PackedStringArray()
	for job: Dictionary in jobs:
		pool.append("%s|%s" % [job["name"], job["set"]])
		assert_eq(job["lookups"], PackRecipes.named_lookups(job["name"], job["set"]))
	assert_eq(_sha("\n".join(pool).to_utf8_buffer()), python["pool"], "the pool, in its order")
	var files: Array = []
	for entry: Array in recipe["entries"]:
		assert_eq(entry[0], "skin/cardart/" + String(entry[1]))
		files.append(entry[1])
	assert_eq(files.size(), int(python["pictures"]))
	assert_eq(_lines(files), python["picture_names"])
	assert_eq(files, PackJson.sorted(files), "in file-name order, as the tool zips them")
	assert_eq(int(PackRecipes.about("base")["pictures"]), files.size())
	assert_eq(recipe["file_name"], "cardart.zip")
	assert_eq(recipe["metadata"], {})


## Read only, and only when they are there: the packs the owner built with
## the Python tools list exactly what the recipes list.
func test_the_built_packs_beside_the_checkout_list_the_same_entries() -> void:
	var folder := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() \
		.path_join("shandalar-packs")
	var compared := 0
	for number in range(1, 11):
		var id := "pack-%d" % number
		var path := folder.path_join(String(PackRecipes.about(id)["file_name"]))
		if not FileAccess.file_exists(path):
			continue
		var reader := ZIPReader.new()
		if reader.open(path) != OK:
			continue
		var listed := Array(reader.get_files())
		reader.close()
		var recipe := PackRecipes.recipe(id)
		if not bool(recipe.get("ok", false)):
			fail_test("%s: %s" % [id, recipe.get("why", "")])
			continue
		var wanted: Array = []
		for entry: Array in recipe["entries"]:
			wanted.append(entry[0])
		for name: String in ["manifest.json", "catalog.json", "cards.json", "README.txt"]:
			wanted.append(String(recipe["prefix"]) + name)
		assert_eq(PackJson.sorted(listed), PackJson.sorted(wanted), id)
		compared += 1
	if compared == 0:
		pass_test("no built packs beside this checkout: nothing to compare")
	else:
		gut.p("compared %d built packs" % compared)
