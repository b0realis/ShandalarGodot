class_name AdventureTransfer
extends RefCounted
## AN ADVENTURE CARRIED TO ANOTHER DEVICE AND BACK [QoL] (a player on
## Android asked where his saves are and whether he can copy them to a PC;
## the owner, 2026-11-06: *"Yes implement both point 1. And 2.!"*).
## **Export**, on the saved adventures ([LoadAdventureScreen]), packs every
## file of one adventure — its autosave, its Quickslot and its named slots,
## each with its `.bak` — into ONE zip the player puts where they like
## (on Android through the system's own file box, so Downloads will do);
## **Import** takes such a zip from anywhere and puts the adventure back
## among the saves. The same on every platform.
##
## THE FILE: `Shandalar adventure - <Hero> - <date>.zip` ([method
## file_name_for]), holding [constant MANIFEST] — this format and its
## version, the game's version, the adventure's id and hero, and each
## save's name, size and SHA-256 — and the saves under their own names.
## An adventure of "One life" whose final battle began or was lost carries
## the Hall's mark too ([method HallOfFame.one_life_state]), so a copy
## taken elsewhere cannot fight that battle again.
##
## NOTHING WRITTEN UNTIL ALL OF IT IS CHECKED ([method read_package]): the
## manifest there and of a known format; every member a plain file name of
## ONE adventure and of a save kind the game keeps; sizes bounded member by
## member and in all; each hash as the manifest says; each save one the
## game reads ([method AdventurePlayer.readable]), a save of a newer
## format refused as the lists word it — "saved by a newer version of the
## game". Then the saves are written whole and read back one by one
## ([method install]); a failure puts back what was there.
##
## A zip is made, and a chosen one checked, in the game's own folder
## ([constant STAGING]) — whole, as the game's other writers make a file —
## and only then put where the player chose ([method export_to]) or read
## into the saves.

const FORMAT := "shandalar-adventure-export"
const FORMAT_VERSION := 1
## The member that says what the zip holds.
const MANIFEST := "manifest.json"
## The largest save a member may be: the bound [method
## PortalPack.bounded_zip] holds every entry of a zip the game takes in
## to. A save with its journal full (10,000 lines) is about 2 MB.
const MAX_MEMBER_BYTES := 8 * 1024 * 1024
## The most members: the manifest, and twelve saves each with its `.bak`.
const MAX_ENTRIES := 1 + 2 * (SaveSlots.SLOTS + 2)
## The most bytes in all, the zip itself and its saves unpacked (a test
## lowers it).
static var max_total_bytes := 128 * 1024 * 1024
## Where a zip is made and checked before it goes out, and where a chosen
## one is copied and checked before anything is written.
const STAGING := "user://adventure_transfer"
const OUTGOING := STAGING + "/outgoing.zip"
const INCOMING := STAGING + "/incoming.zip"
## On Android a file the system's box hands over may refuse the write
## beside it and the rename ([method _write_in_place]).
static var on_android := OS.has_feature("android")

## What the player reads when a zip is refused; `%s` is the file's name.
const NOT_EXPORTED := "%s is not an adventure exported by Shandalar."
const NEWER := "%s was saved by a newer version of the game. Update the game to import it."
const MIXED := "%s holds files that are not the saves of one adventure."
const TOO_BIG := "%s is bigger than an exported adventure can be."
const DAMAGED := "%s is damaged: %s is not as it was exported."
const UNREADABLE := "%s is damaged: %s cannot be read as a save."
const NOT_READ := "%s could not be read."


# ------------------------------------------------------------ the files --

## The kinds of save an adventure keeps: the autosave, the Quickslot and
## the ten named slots ([SaveSlots]).
static func kinds() -> Array[String]:
	var out: Array[String] = [AdventurePlayer.AUTOSAVE, SaveSlots.QUICK_KIND]
	for slot in range(1, SaveSlots.SLOTS + 1):
		out.append(SaveSlots.kind(slot))
	return out


## Every file name adventure [param id] may have: each kind's save, then
## its `.bak`.
static func names_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for kind in kinds():
		var name := "%s.%s.json" % [id, kind]
		out.append(name)
		out.append(AdventurePlayer.backup_path(name))
	return out


## Whether [param id] is an adventure's id as [method AdventurePlayer.make_id]
## makes one: letters, digits, `-` and `_` only — no dot, no slash, so a
## file name built on it stays one plain name in one folder.
static func plain_id(id: String) -> bool:
	if id == "" or id.length() > 128:
		return false
	for i in id.length():
		var c := id.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 45 or c == 95):
			return false
	return true


## THE FILES OF ADVENTURE [param id] in [param folders] ([method
## AdventurePlayer.saves_folders] when empty): `{file name: path}`, each
## name from the first folder that has it.
static func files_of(id: String, folders: Array[String] = []) -> Dictionary:
	var out := {}
	if not plain_id(id):
		return out
	if folders.is_empty():
		folders = AdventurePlayer.saves_folders()
	for name in names_of(id):
		for folder in folders:
			var path := folder.path_join(name)
			if FileAccess.file_exists(path):
				out[name] = path
				break
	return out


## WHAT OF ADVENTURE [param id] IS HERE: `{files, saves, newest, hero}` —
## how many of its files there are, how many saves the lists read
## (without the `.bak` copies), the newest one's time as kept and its hero.
static func existing(id: String, folders: Array[String] = []) -> Dictionary:
	var found := files_of(id, folders)
	var out := {"files": found.size(), "saves": 0, "newest": "", "hero": ""}
	for name: String in found:
		if name.ends_with(AdventurePlayer.BACKUP_TAIL):
			continue
		var save := AdventurePlayer.save_at(String(found[name]))
		if save.is_empty() or save.get("unreadable", false):
			continue
		out["saves"] = int(out["saves"]) + 1
		if String(save["saved"]) >= String(out["newest"]):
			out["newest"] = String(save["saved"])
			out["hero"] = String(save["name"])
	return out


## `Shandalar adventure - Goya - 2026-11-06.zip` for hero [param hero] on
## [param date] (today on the player's clock by default): the characters
## no file system takes, and control characters, as `-`.
static func file_name_for(hero: String, date := "") -> String:
	if date == "":
		date = Time.get_date_string_from_system()
	var safe := ""
	for i in hero.length():
		var c := hero.unicode_at(i)
		safe += "-" if c < 32 or c == 127 or hero[i] in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "%", "#"] \
			else hero[i]
	safe = safe.left(40).strip_edges()
	while safe.begins_with(".") or safe.ends_with("."):
		safe = safe.trim_prefix(".").trim_suffix(".").strip_edges()
	return "Shandalar adventure - %s - %s.zip" % [safe if safe != "" else "Hero", date]


## The SHA-256 of [param bytes], in hex.
static func sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish().hex_encode()


# --------------------------------------------------------------- export --

## ADVENTURE [param id] PACKED into the zip at [param to] ([constant
## OUTGOING] by default) from [param folders], then read back and checked
## as an import would check it ([method read_package]):
## `{ok, message, id, hero, saves, left_out}`. A file of the adventure the
## game cannot read (damaged, of a newer version, or another adventure's
## under its name) is left out and counted, so the zip is always one
## Import takes.
static func pack(id: String, to := OUTGOING, folders: Array[String] = []) -> Dictionary:
	var out := {"ok": false, "message": "", "id": id, "hero": "", "saves": 0, "left_out": 0}
	var found := files_of(id, folders)
	var members: Array[Dictionary] = []
	var total := 0
	var newest := ""
	for name in names_of(id):
		if not found.has(name):
			continue
		var bytes: Variant = AdventurePlayer.whole_bytes(String(found[name]))
		var data := _save_of(bytes) if bytes is PackedByteArray \
			and (bytes as PackedByteArray).size() <= MAX_MEMBER_BYTES else {}
		if data.is_empty() or not AdventurePlayer.readable(data) \
				or String((data["adventure"] as Dictionary).get("id", "")) != id:
			out["left_out"] = int(out["left_out"]) + 1
			continue
		total += (bytes as PackedByteArray).size()
		members.append({"name": name, "bytes": bytes})
		if not name.ends_with(AdventurePlayer.BACKUP_TAIL):
			out["saves"] = int(out["saves"]) + 1
			var saved := String((data["adventure"] as Dictionary).get("saved", ""))
			if out["hero"] == "" or saved >= newest:
				newest = saved
				out["hero"] = String((data["hero"] as Dictionary).get("name", ""))
	if int(out["saves"]) == 0:
		out["message"] = "Nothing of that adventure could be read, so nothing was exported."
		return out
	if total > max_total_bytes:
		out["message"] = "That adventure is too big to export."
		return out
	var manifest := {"format": FORMAT, "version": FORMAT_VERSION,
		"game_version": String(ProjectSettings.get_setting("application/config/version", "")),
		"save_format_version": AdventurePlayer.FORMAT_VERSION,
		"adventure_id": id, "hero": out["hero"],
		"exported": Time.get_datetime_string_from_system(true) + "Z",
		"files": members.map(func(m: Dictionary) -> Dictionary:
			return {"name": m["name"], "bytes": (m["bytes"] as PackedByteArray).size(),
				"sha256": sha256(m["bytes"])})}
	var mark := HallOfFame.one_life_state(id)
	if mark != "":
		manifest["one_life"] = mark
	if not _ready_folder(to.get_base_dir()):
		out["message"] = "The game's folder could not be written."
		return out
	var pending := Settings.pending_path(to)
	var packed := _zip(pending, JSON.stringify(manifest, "\t").to_utf8_buffer(), members)
	var checked := read_package(pending) if packed else {}
	if not packed or not bool(checked.get("ok", false)):
		DirAccess.remove_absolute(pending)
		out["message"] = "The adventure could not be packed."
		return out
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	if DirAccess.rename_absolute(pending, to) != OK:
		DirAccess.remove_absolute(pending)
		out["message"] = "The adventure could not be packed."
		return out
	out["ok"] = true
	return out


## The bytes of adventure [param id] as one exported zip — [method pack]
## into [constant OUTGOING], read and taken away — in `bytes` beside what
## [method pack] says. For the browser's download.
static func packed_bytes(id: String, folders: Array[String] = []) -> Dictionary:
	var made := pack(id, OUTGOING, folders)
	if bool(made["ok"]):
		var bytes: Variant = AdventurePlayer.whole_bytes(OUTGOING)
		DirAccess.remove_absolute(OUTGOING)
		if bytes is PackedByteArray:
			made["bytes"] = bytes
		else:
			made["ok"] = false
			made["message"] = "The adventure could not be packed."
	return made


## EXPORT ADVENTURE [param id] to [param dest], the file the player chose:
## packed and checked ([method pack]), then written there whole beside it
## and renamed into place ([method Settings.write_atomically]) — a file
## the player made read-only is refused, a link stays a link. Where the
## system's file box handed over a file that takes no neighbour (Android's
## document picker) it is written in place and read back ([method
## _write_in_place]). `{ok, message, id, hero, saves, left_out}`.
static func export_to(id: String, dest: String, folders: Array[String] = []) -> Dictionary:
	var made := packed_bytes(id, folders)
	if not bool(made["ok"]):
		return made
	var bytes: PackedByteArray = made["bytes"]
	made.erase("bytes")
	var err := Settings.write_atomically(dest, bytes)
	if err != OK and err != ERR_FILE_NO_PERMISSION and (is_uri(dest) or on_android):
		err = _write_in_place(dest, bytes)
	if err != OK:
		made["ok"] = false
		made["message"] = "Could not write %s." % shown_name(dest)
	return made


## Whether [param path] is a document a system file box handed over by
## address (`content://…`) rather than a path in a folder.
static func is_uri(path: String) -> bool:
	return path.contains("://") and not path.begins_with("user://") and not path.begins_with("res://")


## [param path] as the player reads it: its file name, or "The file" for
## an address with no name in it.
static func shown_name(path: String) -> String:
	return "The file" if is_uri(path) or path.get_file() == "" else path.get_file()


## [param bytes] written over [param dest] in place, the write and the
## length that reached it checked, and — where the file can be read back —
## its bytes compared.
static func _write_in_place(dest: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(dest, FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	var stored := file.store_buffer(bytes)
	file.flush()
	var err := file.get_error()
	var length := file.get_length()
	file.close()
	if err != OK or not stored or length != bytes.size():
		return ERR_FILE_CANT_WRITE
	var back: Variant = AdventurePlayer.whole_bytes(dest)
	return ERR_FILE_CANT_WRITE if back is PackedByteArray and back != bytes else OK


## The zip at [param path]: [param manifest] first, then each member's
## bytes under its name. False when any step fails.
static func _zip(path: String, manifest: PackedByteArray, members: Array[Dictionary]) -> bool:
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return false
	var ok := true
	for member in [{"name": MANIFEST, "bytes": manifest}] + members:
		ok = ok and packer.start_file(String(member["name"])) == OK \
			and packer.write_file(member["bytes"]) == OK and packer.close_file() == OK
	return packer.close() == OK and ok


static func _ready_folder(folder: String) -> bool:
	return DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) == OK


# --------------------------------------------------------------- import --

## [param source], the file the player chose, copied whole into [constant
## INCOMING] and checked there ([method read_package]); the copy is gone
## again afterwards whatever came of it. [param shown] names it to the
## player ([method shown_name] by default). What [method read_package]
## says.
static func take_in(source: String, shown := "") -> Dictionary:
	if shown == "":
		shown = shown_name(source)
	if source == INCOMING:
		var read := read_package(INCOMING, shown)
		DirAccess.remove_absolute(INCOMING)
		return read
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		return _refused(NOT_READ % shown)
	var length := file.get_length()
	file.close()
	if length > max_total_bytes:
		return _refused(TOO_BIG % shown)
	if not _ready_folder(STAGING) or load("res://game/skin_pack.gd").copy_whole(source, INCOMING) != OK:
		return _refused(NOT_READ % shown)
	var read := read_package(INCOMING, shown)
	DirAccess.remove_absolute(INCOMING)
	return read


## THE ZIP AT [param path], CHECKED WHOLE before anything is written:
## `{ok, message, id, hero, files: {name: bytes}, saves, newest, one_life}`
## — `saves` how many saves the lists will show (without the `.bak`
## copies), `newest` the newest one's time as kept. Refused (`ok` false,
## `message` the words, [param shown] the file's name in them) when it is
## not a zip, has no manifest or one of another kind; is of a newer
## format or holds a save of a newer format; holds a member with a path,
## of another adventure or of no save kind, or one the manifest does not
## list; is too big, a member or in all; or a member's size or hash is not
## the manifest's, or it is not a save the game reads.
static func read_package(path: String, shown := "") -> Dictionary:
	if shown == "":
		shown = path.get_file()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _refused(NOT_READ % shown)
	var length := file.get_length()
	var head := file.get_buffer(4)
	file.close()
	if length > max_total_bytes:
		return _refused(TOO_BIG % shown)
	if not PortalPack.bounded_zip(path, MAX_ENTRIES, max_total_bytes):
		# A zip's own first bytes, `PK` 3 4 (or 5 6 for one with nothing
		# in it): a zip past the bounds, else no zip at all.
		var zip := head.size() == 4 and head[0] == 0x50 and head[1] == 0x4B \
			and ((head[2] == 3 and head[3] == 4) or (head[2] == 5 and head[3] == 6))
		return _refused((TOO_BIG if zip else NOT_EXPORTED) % shown)
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return _refused(NOT_EXPORTED % shown)
	var read := _read_members(reader, shown)
	reader.close()
	return read


static func _read_members(reader: ZIPReader, shown: String) -> Dictionary:
	var names := reader.get_files()
	if not MANIFEST in names:
		return _refused(NOT_EXPORTED % shown)
	var manifest := _json(reader.read_file(MANIFEST))
	if String(manifest.get("format", "")) != FORMAT or not _is_number(manifest.get("version")):
		return _refused(NOT_EXPORTED % shown)
	if int(manifest["version"]) > FORMAT_VERSION:
		return _refused(NEWER % shown)
	var id := String(manifest.get("adventure_id", "")) if manifest.get("adventure_id") is String else ""
	if int(manifest["version"]) < 1 or not manifest.get("files") is Array or not plain_id(id):
		return _refused(NOT_EXPORTED % shown)
	# Every member listed once, every listed one there: plain names of
	# this one adventure's saves.
	var allowed := {}
	for name in names_of(id):
		allowed[name] = true
	var listed := {}
	for row: Variant in manifest["files"]:
		if not row is Dictionary or not (row as Dictionary).get("name") is String \
				or not _is_number((row as Dictionary).get("bytes")) or not (row as Dictionary).get("sha256") is String:
			return _refused(NOT_EXPORTED % shown)
		var name := String(row["name"])
		if listed.has(name) or not allowed.has(name):
			return _refused(MIXED % shown)
		listed[name] = row
	var seen := {}
	for name in names:
		if name == MANIFEST:
			continue
		if seen.has(name) or not allowed.has(name) or not listed.has(name):
			return _refused(MIXED % shown)
		seen[name] = true
	for name: String in listed:
		if not seen.has(name):
			return _refused(DAMAGED % [shown, name])
	# Each save: its size and hash as listed, then read as the game reads one.
	var out := {"ok": true, "message": "", "id": id, "hero": "", "files": {}, "saves": 0, "newest": "",
		"one_life": ""}
	var total := 0
	for name: String in listed:
		var row: Dictionary = listed[name]
		if int(row["bytes"]) > MAX_MEMBER_BYTES:
			return _refused(TOO_BIG % shown)
		var bytes := reader.read_file(name)
		total += bytes.size()
		if bytes.size() > MAX_MEMBER_BYTES or total > max_total_bytes:
			return _refused(TOO_BIG % shown)
		if bytes.size() != int(row["bytes"]) or sha256(bytes) != String(row["sha256"]).to_lower():
			return _refused(DAMAGED % [shown, name])
		var data := _save_of(bytes)
		if String(data.get("format", "")) == AdventurePlayer.FORMAT and _is_number(data.get("version")) \
				and int(data["version"]) > AdventurePlayer.FORMAT_VERSION:
			return _refused(NEWER % shown)
		if not AdventurePlayer.readable(data):
			return _refused(UNREADABLE % [shown, name])
		if String((data["adventure"] as Dictionary).get("id", "")) != id:
			return _refused(MIXED % shown)
		(out["files"] as Dictionary)[name] = bytes
		if not name.ends_with(AdventurePlayer.BACKUP_TAIL):
			out["saves"] = int(out["saves"]) + 1
			var saved := String((data["adventure"] as Dictionary).get("saved", ""))
			if out["hero"] == "" or saved >= String(out["newest"]):
				out["newest"] = saved
				out["hero"] = String((data["hero"] as Dictionary).get("name", ""))
	if int(out["saves"]) == 0:
		return _refused(NOT_EXPORTED % shown)
	if String(manifest.get("one_life", "")) in HallOfFame.ONE_LIFE_STATES:
		out["one_life"] = String(manifest["one_life"])
	return out


## PUT THE CHECKED [param package] ([method read_package]) AMONG THE SAVES:
## each of its files written whole into the first of [param folders]
## ([method AdventurePlayer.saves_folders] when empty) and read back; then
## every other file of the adventure in those folders removed, so it is
## the imported adventure exactly. Should a write fail, what was there is
## put back and nothing else changes. A "One life" mark it carries is
## kept in the Hall ([method HallOfFame.mark_one_life]) unless the Hall
## knows a stronger one. `{ok, message, id, hero, saves}`.
static func install(package: Dictionary, folders: Array[String] = []) -> Dictionary:
	var id := String(package.get("id", ""))
	var files: Dictionary = package.get("files", {})
	var out := {"ok": false, "message": "", "id": id, "hero": String(package.get("hero", "")),
		"saves": int(package.get("saves", 0))}
	if not bool(package.get("ok", false)) or not plain_id(id) or files.is_empty():
		out["message"] = "Nothing was imported."
		return out
	if folders.is_empty():
		folders = AdventurePlayer.saves_folders()
	var to := folders[0]
	if not _ready_folder(to):
		out["message"] = "The saves folder could not be written, so nothing was imported."
		return out
	# What is there now, to put back should a write fail.
	var before := {}
	for folder in folders:
		for name in names_of(id):
			var path := folder.path_join(name)
			if FileAccess.file_exists(path):
				var bytes: Variant = AdventurePlayer.whole_bytes(path)
				if not bytes is PackedByteArray:
					out["message"] = "A save of that adventure here could not be read, so nothing was imported."
					return out
				before[path] = bytes
	var written: Array[String] = []
	for name in names_of(id):
		if not files.has(name):
			continue
		var path := to.path_join(name)
		written.append(path)
		var bytes: PackedByteArray = files[name]
		if Settings.write_atomically(path, bytes) != OK or AdventurePlayer.whole_bytes(path) != bytes:
			_put_back(before, written)
			out["message"] = "The saves could not be written, so nothing was imported."
			return out
	for path: String in before:
		if not path in written:
			DirAccess.remove_absolute(path)
	var mark := String(package.get("one_life", ""))
	var known := HallOfFame.one_life_state(id)
	if mark in HallOfFame.ONE_LIFE_STATES and known != HallOfFame.FAILED and known != mark:
		HallOfFame.mark_one_life(id, mark)
	out["ok"] = true
	out["message"] = imported_words(out["hero"], int(out["saves"]))
	return out


## "Imported Goya's adventure: 5 saves."
static func imported_words(hero: String, saves: int) -> String:
	return "Imported %s's adventure: %d %s." % [hero, saves, "save" if saves == 1 else "saves"]


## The files [param written] put back as [param before] had them: the
## bytes that were there, or none.
static func _put_back(before: Dictionary, written: Array[String]) -> void:
	for path in written:
		if before.has(path):
			Settings.write_atomically(path, before[path])
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


static func _refused(words: String) -> Dictionary:
	return {"ok": false, "message": words, "id": "", "hero": "", "files": {}, "saves": 0, "newest": "",
		"one_life": ""}


## The save [param bytes] hold as parsed JSON, `{}` when they are not a
## JSON record. Quietly: a damaged file is an answer here, not an error.
static func _save_of(bytes: Variant) -> Dictionary:
	if not bytes is PackedByteArray or (bytes as PackedByteArray).is_empty():
		return {}
	return _json(bytes)


static func _json(bytes: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {}
	return json.data


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
