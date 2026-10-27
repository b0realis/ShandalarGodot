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
	var bytes := text.to_utf8_buffer()
	# What cannot be read back must not be written: _read_one refuses a
	# file past MAX_BYTES, and a checkpoint saved past it would have been
	# unrecoverable while reporting OK (2026-10-02). In BYTES, as _read_one
	# measures it — an entrant's name past ASCII is more than one.
	if bytes.size() > SgProtocol.MAX_BYTES: return ERR_OUT_OF_MEMORY
	# THE NEW CHECKPOINT IS WHOLE BEFORE ANYTHING MOVES (the bug campaign
	# c12, h6-2). It went to a shared `.tmp` with the store's result
	# unread, and a buffered write's flush reports no full disk — so a cut
	# checkpoint was renamed in, the save said OK, and the `.bak` stayed
	# frozen at the last good one while every later save said OK too.
	# [method Settings.write_atomically] checks the length that reached
	# the disk, and the pending name is this process's own
	# ([method Settings.pending_path]), so two instances restoring one
	# event never write or move each other's.
	var pending := Settings.pending_path(path)
	result = Settings.write_atomically(pending, bytes)
	if result != OK: return result
	# A damaged primary must not replace an intact last-good backup during
	# recovery. Rename-overwrite installs the new checked data in its place.
	var intact: bool = _written.has(path) and FileAccess.get_sha256(path) == _written[path]
	if intact or not _read_one(path).is_empty():
		result = DirAccess.rename_absolute(path, path + ".bak")
		if result != OK:
			DirAccess.remove_absolute(pending)
			return result
	result = DirAccess.rename_absolute(pending, path)
	if result == OK: _written[path] = text.sha256_text()
	else: DirAccess.remove_absolute(pending)
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
