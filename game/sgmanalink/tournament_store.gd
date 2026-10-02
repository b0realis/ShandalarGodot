class_name SgTournamentStore
extends RefCounted
## [QoL] Private organiser checkpoints with atomic replacement and last-good backup.
## Paths are local-only. Neither import paths nor checkpoint data are wire commands.

## The digest of each checkpoint this process wrote: a primary that still
## reads as what we wrote is known good and rotates to the backup without
## the full read-back — the checkpoint validation of forty entrants' decks
## against the card pool, which a round draw ran once per table
## (2026-10-02). A primary changed by anything else is read back as before.
static var _written: Dictionary = {}


static func save(event: SgTournament, folder: String) -> Error:
	if folder.is_empty() or not SgProtocol.token(event.id): return ERR_INVALID_PARAMETER
	var result := DirAccess.make_dir_recursive_absolute(folder)
	if result != OK: return result
	var path := folder.path_join(event.id + ".json")
	var text := SgProtocol.encode(event.checkpoint())
	# What cannot be read back must not be written: _read_one refuses a
	# file past MAX_BYTES, and a checkpoint saved past it would have been
	# unrecoverable while reporting OK (2026-10-02).
	if text.length() > SgProtocol.MAX_BYTES: return ERR_OUT_OF_MEMORY
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	result = file.get_error()
	file.close()
	if result != OK: return result
	# A damaged primary must not replace an intact last-good backup during
	# recovery. Rename-overwrite installs the new checked data in its place.
	var intact: bool = _written.has(path) and FileAccess.get_sha256(path) == _written[path]
	if intact or not _read_one(path).is_empty():
		result = DirAccess.rename_absolute(path, path + ".bak")
		if result != OK: return result
	result = DirAccess.rename_absolute(path + ".tmp", path)
	if result == OK: _written[path] = text.sha256_text()
	return result


static func read_checkpoint(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		var data := _read_one(candidate)
		if not data.is_empty(): return data
	return {}


static func _read_one(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > SgProtocol.MAX_BYTES: return {}
	var data := SgProtocol.decode_payload(file.get_buffer(file.get_length()))
	return data if SgTournamentProtocol.checkpoint(data) else {}


static func available(folder: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(folder)
	if dir == null: return result
	var found := {}
	for filename in dir.get_files():
		var base := filename.trim_suffix(".bak")
		if base.ends_with(".json") and SgProtocol.token(base.trim_suffix(".json")): found[base] = true
	var names := found.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(folder.path_join(a)) > FileAccess.get_modified_time(folder.path_join(b)))
	for filename in names:
		if result.size() >= 32: break
		var path := folder.path_join(filename)
		var data := read_checkpoint(path)
		if not data.is_empty(): result.append({"path": path, "name": data.config.name, "phase": data.phase, "round": data.rounds.size()})
	return result
