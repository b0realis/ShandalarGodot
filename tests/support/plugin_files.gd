extends RefCounted
## Test helper: a plugin folder read as bytes and checked by [PluginSchema]
## directly — the schema's and the interpreter's tests stand apart from the
## registry's discovery ([AdventurePlugins]).

const REFUGE := "res://expanded_adventure/Fallen_Empires_Refuge_prototype"


## Every file under [param root], `{rel: PackedByteArray}`.
static func folder(root: String) -> Dictionary:
	var out := {}
	_walk(root, "", out)
	return out


static func _walk(root: String, rel: String, out: Dictionary) -> void:
	var dir := DirAccess.open(root.path_join(rel) if rel != "" else root)
	if dir == null: return
	dir.include_hidden = false
	for name in dir.get_files():
		var path := rel.path_join(name) if rel != "" else name
		out[path] = FileAccess.get_file_as_bytes(root.path_join(path))
	for name in dir.get_directories():
		_walk(root, rel.path_join(name) if rel != "" else name, out)


static func manifest(files: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string((files.get("plugin.json", PackedByteArray()) as PackedByteArray).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


## [PluginSchema.read] of the folder at [param root], with [param edit]
## applied to the parsed files first (`func(files: Dictionary) -> void`,
## each JSON file as a Dictionary to change; written back as bytes).
static func read(root := REFUGE, edit := Callable()) -> Dictionary:
	var files := folder(root)
	if edit.is_valid():
		var parsed := {}
		for rel in files:
			if rel.ends_with(".json"): parsed[rel] = JSON.parse_string((files[rel] as PackedByteArray).get_string_from_utf8())
		edit.call(parsed)
		for rel in parsed:
			if parsed[rel] == null: files.erase(rel)
			else: files[rel] = JSON.stringify(parsed[rel]).to_utf8_buffer()
	return PluginSchema.read(manifest(files), files)


## The Refuge's interpreter on its own data (no registry needed).
static func refuge() -> DataRegion:
	return DataRegion.new("refuge", read()["data"])
