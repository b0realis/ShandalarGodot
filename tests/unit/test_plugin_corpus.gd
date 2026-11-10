extends GutTest
## THE PLUGIN CORPUS, JUDGED BY THE GAME (adventure plugins, 2026-11-10; the
## spec's §5 and §7: "the bad-plugin corpus is refused by both validators
## with the same reasons"). `tools/plugin_fixtures/expected.json` lists good
## and bad plugins as recipes — a base folder, edits, added files, zips
## written byte by byte — and each one's verdict and first reason. Every
## case is built here under the test profile exactly as
## `tools/test_adventure_plugin.py` builds it for the authoring tool, then
## put alone in a plugins folder and judged by the game's own registry
## ([method AdventurePlugins.scan]: the package, the manifest, its files
## list, the content). Both tests hold to the same file, so the game's
## loader and `tools/adventure_plugin.py validate` agree case for case.
##
## And the plugin that `adventure_plugin.py new` writes (the corpus's
## `good_minimal`) not only loads but plays: its island is made, its port
## and castle stand on it, and its quest and finale run.

const ZIPS := preload("res://tests/support/plugin_zips.gd")
const CAMPAIGN := preload("res://tools/expansion_testing/lab_campaign.gd")
## A second quest for the campaign's own cases: a duel at the second town.
const SECOND := {"giver": 2, "title": "tale.keep.title", "petition": "tale.keep", "epilogue": "tale.keep",
	"foe": "smuggler", "steps": [{"do": "duel"}]}
const FIXTURES := "res://tools/plugin_fixtures"
const WORK := "user://plugin_corpus_tests"

var _corpus := {}


func before_all() -> void:
	var parser := JSON.new()
	assert_eq(parser.parse(FileAccess.get_file_as_string(FIXTURES.path_join("expected.json"))), OK, "expected.json parses")
	_corpus = parser.data
	AdventurePlugins.content_reader = Callable()


func after_all() -> void:
	ZIPS.remove(WORK)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.content_reader = Callable()
	AdventurePlugins.scan()


func after_each() -> void:
	AdventurePlugins.content_reader = Callable()


# ------------------------------------------------------------ the builder --

## A recipe value: {$repeat: [text, n]}, {$list: [value, n]}, {$nest: n}.
func _expand(value: Variant) -> Variant:
	if value is Dictionary and value.size() == 1:
		var key: String = value.keys()[0]
		match key:
			"$repeat": return String(value[key][0]).repeat(int(value[key][1]))
			"$list":
				var out := []
				for n in int(value[key][1]): out.append(_expand(value[key][0]))
				return out
			"$nest":
				var nest := []
				for n in int(value[key]) - 1: nest = [nest]
				return nest
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = _expand(value[key])
		return out
	if value is Array:
		var out := []
		for item in value: out.append(_expand(item))
		return out
	return value


func _walk_to(data: Variant, path: Array) -> Variant:
	for i in path.size() - 1:
		data = data[int(path[i])] if data is Array else data[String(path[i])]
	return data


func _put_at(data: Variant, path: Array, value: Variant) -> void:
	var holder: Variant = _walk_to(data, path)
	if holder is Array:
		if int(path.back()) == holder.size(): holder.append(value)
		else: holder[int(path.back())] = value
	else:
		holder[String(path.back())] = value


func _drop_at(data: Variant, path: Array) -> void:
	var holder: Variant = _walk_to(data, path)
	if holder is Array: holder.remove_at(int(path.back()))
	else: holder.erase(String(path.back()))


func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _copy_tree(from: String, to: String) -> void:
	var dir := DirAccess.open(from)
	if dir == null: return
	dir.include_hidden = true
	DirAccess.make_dir_recursive_absolute(to)
	for name in dir.get_files():
		_write(to.path_join(name), FileAccess.get_file_as_bytes(from.path_join(name)))
	for name in dir.get_directories():
		_copy_tree(from.path_join(name), to.path_join(name))


func _png_header(width: int, height: int) -> PackedByteArray:
	var body := PackedByteArray()
	body.resize(13)
	body.encode_u32(0, _be(width))
	body.encode_u32(4, _be(height))
	body[8] = 8
	body[9] = 6
	var out := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
	out.append_array(_chunk("IHDR", body))
	out.append_array(_chunk("IEND", PackedByteArray()))
	return out


func _chunk(kind: String, body: PackedByteArray) -> PackedByteArray:
	var head := PackedByteArray()
	head.resize(4)
	head.encode_u32(0, _be(body.size()))
	var named := kind.to_ascii_buffer()
	named.append_array(body)
	var tail := PackedByteArray()
	tail.resize(4)
	tail.encode_u32(0, _be(ZIPS.crc32(named)))
	head.append_array(named)
	head.append_array(tail)
	return head


## [param value] byte-swapped, so encode_u32 (little-endian) writes it big-endian.
func _be(value: int) -> int:
	return ((value & 0xFF) << 24) | ((value & 0xFF00) << 8) | ((value >> 8) & 0xFF00) | ((value >> 24) & 0xFF)


## The recipe's items, each `count` expanded ({n} in rel or name numbering them).
func _items(items: Array) -> Array:
	var out := []
	for item: Dictionary in items:
		if not item.has("count"):
			out.append(item)
			continue
		for n in int(item["count"]):
			var one := {}
			for key in item:
				if key == "count": continue
				one[key] = String(item[key]).replace("{n}", str(n)) if key in ["rel", "name"] and item[key] is String else item[key]
			out.append(one)
	return out


func _add(folder: String, items: Array) -> void:
	for item: Dictionary in _items(items):
		var target := folder.path_join(String(item["rel"]))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if item.has("prefix_hex"):
			var bytes := String(item["prefix_hex"]).hex_decode()
			bytes.append_array(FileAccess.get_file_as_bytes(target))
			_write(target, bytes)
		elif item.has("append"):
			var bytes := FileAccess.get_file_as_bytes(target)
			bytes.append_array(String(item["append"]).to_utf8_buffer())
			_write(target, bytes)
		elif bool(item.get("delete", false)):
			DirAccess.remove_absolute(target)
		elif item.has("link"):
			assert_eq(DirAccess.open(target.get_base_dir()).create_link(String(item["link"]),
				ProjectSettings.globalize_path(target)), OK, "a symbolic link made")
		elif item.has("dirs"):
			DirAccess.make_dir_recursive_absolute(target)
		elif item.has("png"):
			_write(target, _png_header(int(item["png"][0]), int(item["png"][1])))
		elif item.has("repeat"):
			_write(target, String(item["repeat"][0]).repeat(int(item["repeat"][1])).to_utf8_buffer())
		elif item.has("hex"):
			_write(target, String(item["hex"]).hex_decode())
		else:
			_write(target, String(item["text"]).to_utf8_buffer())


func _json_file(path: String) -> Variant:
	var parser := JSON.new()
	assert_eq(parser.parse(FileAccess.get_file_as_string(path)), OK, path)
	return parser.data


func _store_json(path: String, value: Variant) -> void:
	_write(path, (JSON.stringify(value, "\t", false) + "\n").to_utf8_buffer())


## Stored entries, byte for byte as tools/test_adventure_plugin.py's
## raw_zip writes them: {name (bytes), data, method, flags, made_by,
## external, size (claimed)}.
func _raw_zip(entries: Array) -> PackedByteArray:
	var out := PackedByteArray()
	var central := PackedByteArray()
	for entry: Dictionary in entries:
		var name: PackedByteArray = entry["name"]
		var data: PackedByteArray = entry["data"]
		var claimed := entry.has("size")
		var size := int(entry["size"]) if claimed else data.size()
		var crc := 0 if claimed else ZIPS.crc32(data)
		var offset := out.size()
		var local := PackedByteArray()
		local.resize(30)
		local.encode_u32(0, 0x04034b50)
		local.encode_u16(4, 20)
		local.encode_u16(6, int(entry.get("flags", 0)))
		local.encode_u16(8, int(entry.get("method", 0)))
		local.encode_u32(14, crc)
		local.encode_u32(18, data.size())
		local.encode_u32(22, size)
		local.encode_u16(26, name.size())
		out.append_array(local)
		out.append_array(name)
		out.append_array(data)
		var record := PackedByteArray()
		record.resize(46)
		record.encode_u32(0, 0x02014b50)
		record.encode_u16(4, int(entry.get("made_by", 0x0014)))
		record.encode_u16(6, 20)
		record.encode_u16(8, int(entry.get("flags", 0)))
		record.encode_u16(10, int(entry.get("method", 0)))
		record.encode_u32(16, crc)
		record.encode_u32(20, data.size())
		record.encode_u32(24, size)
		record.encode_u16(28, name.size())
		record.encode_u32(38, int(entry.get("external", 0)))
		record.encode_u32(42, offset)
		central.append_array(record)
		central.append_array(name)
	var at := out.size()
	out.append_array(central)
	var end := PackedByteArray()
	end.resize(22)
	end.encode_u32(0, 0x06054b50)
	end.encode_u16(8, entries.size())
	end.encode_u16(10, entries.size())
	end.encode_u32(12, central.size())
	end.encode_u32(16, at)
	out.append_array(end)
	return out


## The zip with zip64 end records, its classic end record marked "see zip64".
func _zip64(data: PackedByteArray) -> PackedByteArray:
	var count := data.decode_u16(data.size() - 12)
	var size := data.decode_u32(data.size() - 10)
	var offset := data.decode_u32(data.size() - 6)
	var out := data.slice(0, data.size() - 22)
	var record_at := out.size()
	var record := PackedByteArray()
	record.resize(56)
	record.encode_u32(0, 0x06064b50)
	record.encode_u64(4, 44)
	record.encode_u16(12, 45)
	record.encode_u16(14, 45)
	record.encode_u64(24, count)
	record.encode_u64(32, count)
	record.encode_u64(40, size)
	record.encode_u64(48, offset)
	var locator := PackedByteArray()
	locator.resize(20)
	locator.encode_u32(0, 0x07064b50)
	locator.encode_u64(8, record_at)
	locator.encode_u32(16, 1)
	var end := PackedByteArray()
	end.resize(22)
	end.encode_u32(0, 0x06054b50)
	end.encode_u16(8, 0xFFFF)
	end.encode_u16(10, 0xFFFF)
	end.encode_u32(12, 0xFFFFFFFF)
	end.encode_u32(16, 0xFFFFFFFF)
	out.append_array(record)
	out.append_array(locator)
	out.append_array(end)
	return out


## The plugin [param recipe] describes, alone in its own plugins folder:
## its path (a folder or a zip).
func build(recipe: Dictionary) -> String:
	var top := String(_corpus["base_top"])
	var staging := WORK.path_join("staging").path_join(String(recipe["name"]))
	ZIPS.remove(staging)
	DirAccess.make_dir_recursive_absolute(staging)
	for layer in ["base", "folder"]:
		if recipe.has(layer): _copy_tree(FIXTURES.path_join(String(recipe[layer])), staging)
	var edits: Dictionary = recipe.get("edit", {})
	for rel: String in edits:
		var data: Variant = _json_file(staging.path_join(rel))
		for step: Dictionary in edits[rel].get("set", []):
			_put_at(data, step["path"], _expand(step["value"]))
		for path: Array in edits[rel].get("remove", []):
			_drop_at(data, path)
		_store_json(staging.path_join(rel), data)
	_add(staging, recipe.get("add", []))
	for rel: String in recipe.get("remove", []):
		DirAccess.remove_absolute(staging.path_join(rel))
	if bool(recipe.get("hash_files", false)):
		var files: Dictionary = PluginPackage.read(staging)["files"]
		var manifest: Dictionary = _json_file(staging.path_join("plugin.json"))
		var rels: Array = files.keys()
		rels.sort()
		var hashes := {}
		for rel: String in rels:
			if rel != "plugin.json": hashes[rel] = PluginPackage.sha256(files[rel])
		manifest["files"] = hashes
		_store_json(staging.path_join("plugin.json"), manifest)
	_add(staging, recipe.get("after", []))
	var out := WORK.path_join("cases").path_join(String(recipe["name"]))
	ZIPS.remove(out)
	DirAccess.make_dir_recursive_absolute(out)
	if not recipe.has("zip"):
		_copy_tree(staging, out.path_join(top))
		for item: Dictionary in _items(recipe.get("add", []) + recipe.get("after", [])):
			if item.has("link"):
				DirAccess.remove_absolute(out.path_join(top).path_join(String(item["rel"])))
				DirAccess.open(out).create_link(String(item["link"]),
					ProjectSettings.globalize_path(out.path_join(top).path_join(String(item["rel"]))))
		return out.path_join(top)
	var zip: Dictionary = recipe["zip"]
	var zip_top := String(zip.get("top", top))
	var target := out.path_join(zip_top + ".zip")
	if zip.has("raw_text"):
		_write(target, String(zip["raw_text"]).to_utf8_buffer())
		return target
	var entries := []
	for rel in ZIPS.files_of(staging):
		entries.append({"name": (zip_top + "/" + rel).to_utf8_buffer(), "data": FileAccess.get_file_as_bytes(staging.path_join(rel))})
	for extra: Dictionary in _items(zip.get("extra", [])):
		var entry := {"name": String(extra["name_hex"]).hex_decode() if extra.has("name_hex") else String(extra["name"]).to_utf8_buffer(),
			"data": String(extra["hex"]).hex_decode() if extra.has("hex") else String(extra.get("text", "")).to_utf8_buffer()}
		for key in ["method", "flags", "made_by", "external", "size"]:
			if extra.has(key): entry[key] = int(extra[key])
		entries.append(entry)
	var bytes := _raw_zip(entries)
	_write(target, _zip64(bytes) if bool(zip.get("zip64", false)) else bytes)
	return target


## The game's verdict on the plugin at [param path], alone in its folder:
## its registry row.
func judge(path: String) -> Dictionary:
	AdventurePlugins.folders_override = [path.get_base_dir()] as Array[String]
	AdventurePlugins.scan()
	var rows := AdventurePlugins.all()
	assert_eq(rows.size(), 1, "%s: one plugin found" % path)
	return rows[0] if not rows.is_empty() else {"problems": ["(not found)"]}


# -------------------------------------------------------------- the tests --

func test_the_corpus_is_the_one_the_tool_reads() -> void:
	assert_gt((_corpus.get("cases", []) as Array).size(), 25)
	assert_true(FileAccess.file_exists(FIXTURES.path_join(".gdignore")), "the corpus is never imported")
	assert_true(FileAccess.file_exists("res://tools/adventure_plugin.py"))


func test_every_case_is_judged_as_the_corpus_says() -> void:
	var version := AdventurePlugins.game_version()
	var wrong: Array[String] = []
	for recipe: Dictionary in _corpus["cases"]:
		var path := build(recipe)
		var row := judge(path)
		var problems: Array = row["problems"]
		var first := String(problems[0]) if not problems.is_empty() else ""
		var name := String(recipe["name"])
		if problems.is_empty() != bool(recipe["valid"]):
			wrong.append("%s: valid %s, the corpus says %s: %s" % [name, problems.is_empty(), recipe["valid"], "; ".join(problems)])
		elif recipe.has("reason_prefix"):
			if not first.begins_with(String(recipe["reason_prefix"])):
				wrong.append("%s: %s (wanted it to begin %s)" % [name, first, recipe["reason_prefix"]])
		elif first != String(recipe["reason"]).replace("{game_version}", version):
			wrong.append("%s:\n   game: %s\n corpus: %s" % [name, first, recipe["reason"]])
		ZIPS.remove(WORK.path_join("staging").path_join(name))
		ZIPS.remove(WORK.path_join("cases").path_join(name))
	assert_eq(wrong, [] as Array[String], "the game's loader and the corpus agree:\n" + "\n".join(wrong))


func test_what_new_writes_loads_and_plays() -> void:
	var path := build({"name": "plays", "base": "good_minimal"})
	var row := judge(path)
	assert_eq(row["problems"], [] as Array[String])
	assert_true(AdventurePlugins.valid("corpus_isle"))
	var data := AdventurePlugins.data("corpus_isle")
	var region := DataRegion.new("corpus_isle", data)
	for seed_value in [5, 37, 48271]:
		var world := IslandGenerator.generate(data["world"], seed_value, 1, 1)
		assert_not_null(world, "an island for seed %d" % seed_value)
		assert_eq(AdventureRegions.id(world), "corpus_isle")
		var land := RegionGeography.component(world, world.start_tile())
		for kind in ["port", "castle"]:
			var point: Variant = world.expansion.get(kind)
			assert_true(point is Array and Vector2i(int(point[0]), int(point[1])) in land, "%s stands on the island (seed %d)" % [kind, seed_value])
		for slot in [1, 2]:
			var site: Dictionary = world.sites[slot]
			assert_true(Vector2i(int(site["x"]), int(site["y"])) in land, "town %d stands on the island (seed %d)" % [slot, seed_value])
	assert_eq(region.quest_count(), 1)
	assert_eq(DataRegion.deck_of(region.foe_for(0)).size(), 40, "the quest's foe has a 40-card deck")
	assert_eq(DataRegion.deck_of(data["foes"]["foes"]["warden"]).size(), 40, "so does the finale's")
	assert_eq(region.say("castle.count", {"pledges": 0, "quests_total": 1}), "Quests done: 0 of 1.")
	var descriptor := AdventurePlugins.descriptor("corpus_isle")
	assert_eq(descriptor["sprites"].keys(), ["port", "castle"], "both markers have a map picture")
	assert_not_null(AdventurePlugins.texture("corpus_isle", "art/corpus_isle_castle_map.png"), "the castle's picture decodes")
	assert_not_null(AdventurePlugins.texture("corpus_isle", "art/corpus_isle_port_map.png"), "the port's picture decodes")
	ZIPS.remove(WORK)


# ------------------------------------------- the Expansion Lab's campaign --

func test_the_labs_campaign_wins_what_new_writes_and_reads_its_saves_back() -> void:
	var row := judge(build({"name": "campaign", "base": "good_minimal", "edit": {"quests.json": {"set": [{"path": ["quests", 1], "value": SECOND}]}}}))
	assert_eq(row["problems"], [] as Array[String])
	for seed_value in [5, 37]:
		var run: Dictionary = CAMPAIGN.play("corpus_isle", seed_value)
		assert_eq(run["failures"], [] as Array[String], "seed %d" % seed_value)
		assert_eq(run["quests"], 2, "every quest won, stage by stage")
		assert_true(run["finale"], "and the finale")
		assert_gt(int(run["save_bytes"]), 0)
	ZIPS.remove(WORK)


func test_the_labs_campaign_finds_a_land_held_when_its_save_is_read_back() -> void:
	# The installed descriptor counts one quest fewer than the data plays:
	# the save the campaign writes is then one the game holds (a CHANGED
	# land), as a plugin whose saves outgrow its schema would be.
	AdventurePlugins.content_reader = func(manifest: Dictionary, files: Dictionary) -> Dictionary:
		var read := PluginSchema.read(manifest, files)
		var short: Dictionary = read["data"].duplicate(true)
		(short["quests"]["quests"] as Array).pop_back()
		return {"data": read["data"], "problems": read["problems"], "descriptor": PluginSchema.descriptor(manifest, short)}
	var row := judge(build({"name": "held", "base": "good_minimal", "edit": {"quests.json": {"set": [{"path": ["quests", 1], "value": SECOND}]}}}))
	assert_eq(row["problems"], [] as Array[String])
	var run: Dictionary = CAMPAIGN.play("corpus_isle", 5)
	assert_true((run["failures"] as Array).any(func(line: String) -> bool: return "held" in line),
		"the campaign says the land is held: %s" % [run["failures"]])
	ZIPS.remove(WORK)


func test_the_labs_campaign_finds_a_finale_no_one_can_win() -> void:
	var row := judge(build({"name": "unwinnable", "base": "good_minimal", "edit": {"quests.json": {"set": [
		{"path": ["finale", "conditions"], "value": [{"flag": "freed"}]}]}}}))
	assert_eq(row["problems"], [] as Array[String])
	var run: Dictionary = CAMPAIGN.play("corpus_isle", 5)
	assert_false(run["finale"])
	assert_true((run["failures"] as Array).any(func(line: String) -> bool: return "finale" in line), str(run["failures"]))
	ZIPS.remove(WORK)
