extends RefCounted
## ZIPS FOR THE ADVENTURE PLUGIN LOADER'S TESTS (adventure plugins,
## 2026-11-10): a plugin folder zipped as a player's tool would (deflated,
## [ZIPPacker]), and raw zips written byte by byte — stored entries with any
## name, flag, method, size or Unix file kind — for the zips the loader must
## refuse ([PluginPackage]). Data only, written under the test profile.

const FIXTURE := "res://tests/fixtures/adventure_plugins/tiny_isle"
## A Unix "made by" (high byte 3), and a symbolic link's file kind.
const UNIX := 0x031E
const LINK_MODE := 0xA1FF


## Every file under [param folder], `/`-separated, by name.
static func files_of(folder: String, under := "") -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(folder.path_join(under) if under != "" else folder)
	if dir == null:
		return out
	var names: Array[String] = []
	names.assign(dir.get_files())
	names.sort()
	for name in names:
		out.append(under.path_join(name) if under != "" else name)
	names.assign(dir.get_directories())
	names.sort()
	for name in names:
		out.append_array(files_of(folder, under.path_join(name) if under != "" else name))
	return out


## [param folder] zipped to [param path] under the top folder [param top],
## deflated, with [param extra] `{name: bytes}` added and [param skip] left
## out (names under the top).
static func zip_folder(folder: String, path: String, top := "tiny_isle", extra := {}, skip: Array = []) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packer := ZIPPacker.new()
	packer.open(path)
	for rel in files_of(folder):
		if rel in skip:
			continue
		packer.start_file(top + "/" + rel)
		packer.write_file(FileAccess.get_file_as_bytes(folder.path_join(rel)))
		packer.close_file()
	for name: String in extra:
		packer.start_file(name)
		packer.write_file(extra[name])
		packer.close_file()
	packer.close()


## The fixture's files as raw entries under [param top] (for [method write]).
static func fixture_entries(top := "tiny_isle") -> Array:
	var out: Array = []
	for rel in files_of(FIXTURE):
		out.append({"name": top + "/" + rel, "bytes": FileAccess.get_file_as_bytes(FIXTURE.path_join(rel))})
	return out


## A raw zip at [param path] of [param entries], each `{name, bytes}` and
## optionally `method`, `flags`, `made_by`, `external` (the attributes) and
## `size` (the unpacked size it claims: its bytes are then not what it says,
## and nothing should ever read them).
static func write(path: String, entries: Array) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var out := PackedByteArray()
	var central := PackedByteArray()
	for entry: Dictionary in entries:
		var name := String(entry["name"]).to_utf8_buffer()
		var data: PackedByteArray = entry.get("bytes", PackedByteArray())
		var size := int(entry.get("size", data.size()))
		var crc := crc32(data) if not entry.has("size") else 0
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
	var directory_at := out.size()
	out.append_array(central)
	var end := PackedByteArray()
	end.resize(22)
	end.encode_u32(0, 0x06054b50)
	end.encode_u16(8, entries.size())
	end.encode_u16(10, entries.size())
	end.encode_u32(12, central.size())
	end.encode_u32(16, directory_at)
	out.append_array(end)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(out)
	file.close()


static func crc32(bytes: PackedByteArray) -> int:
	var crc := 0xFFFFFFFF
	for byte in bytes:
		crc ^= byte
		for k in 8:
			crc = (crc >> 1) ^ (0xEDB88320 if crc & 1 else 0)
	return crc ^ 0xFFFFFFFF


## [param folder]'s fixture copy at [param path] (an unpacked plugin to
## change), with [param extra] `{rel: bytes}` written into it.
static func copy_fixture(path: String, extra := {}) -> void:
	for rel in files_of(FIXTURE):
		DirAccess.make_dir_recursive_absolute(path.path_join(rel).get_base_dir())
		var file := FileAccess.open(path.path_join(rel), FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE.path_join(rel)))
		file.close()
	for rel: String in extra:
		DirAccess.make_dir_recursive_absolute(path.path_join(rel).get_base_dir())
		var file := FileAccess.open(path.path_join(rel), FileAccess.WRITE)
		file.store_buffer(extra[rel])
		file.close()


## A folder and all it holds deleted (test scratch under user:// only).
static func remove(path: String) -> void:
	if not path.begins_with("user://"):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	dir.include_hidden = true
	for name in dir.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name in dir.get_directories():
		if dir.is_link(name):
			DirAccess.remove_absolute(path.path_join(name))
		else:
			remove(path.path_join(name))
	DirAccess.remove_absolute(path)


## A manifest's JSON bytes: the fixture's, its fields replaced by
## [param changes] (a null value removes the field).
static func manifest_bytes(changes := {}) -> PackedByteArray:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE.path_join("plugin.json")))
	for key: String in changes:
		if changes[key] == null:
			parsed.erase(key)
		else:
			parsed[key] = changes[key]
	return JSON.stringify(parsed, "\t").to_utf8_buffer()


## A test's stand-in for the content schema ([member AdventurePlugins.content_reader]):
## every content file valid, the data a list of what was read.
static func reader(manifest: Dictionary, files: Dictionary) -> Dictionary:
	var names: Array = files.keys()
	names.sort()
	return {"data": {"files": names, "id": manifest.get("id", "")}, "problems": [] as Array[String],
		"descriptor": {"pictures": {"tiny_isle_harbor": "art/tiny_isle_harbor.png"},
			"sprites": {"port": ["art/tiny_isle_harbor.png", 64.0]}}}
