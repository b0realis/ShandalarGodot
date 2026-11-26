class_name MpnArchive
extends RefCounted
## [QoL] Append-only MPN files, separate from the capped diagnostic log.
## No player metadata is used as a filesystem path. A partial file remains
## readable if the process exits; a result is never invented on shutdown.

signal failed(message: String)
var recorder: MpnRecorder
var path := ""
var error := ""
var record_id := new_id()
var _file: FileAccess
var _serial := 0
var _bytes := 0
## The bytes known to be on disk: whole lines only ([method _write]).
var _written := 0

static func allowed() -> bool:
	# Automated suites/soaks must not fill a player's archive. Tests use
	# start() explicitly with a disposable directory instead.
	return not OS.has_feature("shandalar_test")

static func new_id() -> String:
	return Crypto.new().generate_random_bytes(12).hex_encode()

static func utc_now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"

static func metadata(game: MtgGame, mode: String, match_id := "", game_number := 1) -> Dictionary:
	var rules := {}
	for key in RulesOptions.IMPLEMENTED: rules[key] = game.rules.get_fork(key)
	var started := utc_now()
	return {"Notation": MpnCodec.VERSION, "Visibility": "public", "Coverage": MpnCodec.COVERAGE,
		"Started": started, "MatchStarted": started, "Match": new_id() if match_id == "" else match_id, "Game": game_number,
		"Player.P1": game.players[0].player_name, "Player.P2": game.players[1].player_name,
		"RulesProfile": RulesOptions.preset_label(game.rules.preset()), "RulesOptions": rules,
		"CardPool": Array(CardRegistry.active_set_order()), "Mode": mode,
		"Recorder": "ShandalarGodot/" + String(ProjectSettings.get_setting("application/config/version", "unknown")),
		"Comments": []}

func start(game: MtgGame, headers: Dictionary, directory := "") -> bool:
	if recorder != null or _file != null: return false
	var folder := GamePaths.records_folder() if directory == "" else directory
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_fail("Past Games: cannot create the recordings folder.")
		return false
	path = folder.path_join(utc_now().replace(":", "").replace("-", "") + "-" + new_id() + ".mpn")
	if FileAccess.file_exists(path):
		_fail("Past Games: recording name already exists.")
		return false
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		_fail("Past Games: cannot open a recording file.")
		return false
	_write(MpnCodec.header_text(headers))
	if _file == null: return false
	prune(folder, KEEP_RECORDS, KEEP_BYTES, path)
	recorder = MpnRecorder.new(game)
	recorder.recorded.connect(_record)
	recorder.observe()
	return error == ""

func _record(kind: String, data: Dictionary) -> void:
	if _file == null: return
	if kind == "result":
		data = data.duplicate(true)
		data["ended"] = utc_now()
	if _serial >= MpnCodec.MAX_RECORDS:
		_fail("Past Games: recording stopped at the prototype event limit; the saved prefix remains available.")
		return
	_serial += 1
	_write(MpnCodec.record_text(_serial, kind, data))
	if kind == "result" and _file != null:
		_file.close()
		_file = null

## EVERY LINE IS CHECKED ON DISK (the bug campaign c12, h6-3). On a full
## disk the buffered store and its flush both reported no error, so the
## records after it were dropped while the recording carried on as if
## whole. After each flush the file's size on disk must be what was
## written; when it is not, the file is cut back to the last whole line
## (or removed, when not even the headers landed), so the prefix stays a
## readable record, and [signal failed] says so.
func _write(text: String) -> void:
	var size := text.to_utf8_buffer().size()
	_bytes += size
	if _bytes > MpnCodec.MAX_BYTES:
		_fail("Past Games: recording stopped at 32 MiB; the saved prefix remains available.")
		return
	if not _file.store_string(text) or _file.get_error() != OK:
		_cut_back("Past Games: the recording could not be written.")
		return
	_file.flush()
	if _file.get_error() != OK or _on_disk() != _written + size:
		_cut_back("Past Games: the recording could not be written to disk.")
		return
	_written += size


## The recording's size on disk; -1 when the file is gone (asked first, as
## FileAccess.get_size prints an engine ERROR for a missing file).
func _on_disk() -> int:
	return FileAccess.get_size(path) if FileAccess.file_exists(path) else -1


## A write that did not land: close the file (its buffer is not trusted),
## put it back to the [member _written] bytes that did, and fail.
func _cut_back(message: String) -> void:
	if _file != null:
		_file.close()
		_file = null
	if _written == 0:
		DirAccess.remove_absolute(path)
	else:
		var cut := FileAccess.open(path, FileAccess.READ_WRITE)
		if cut != null:
			cut.resize(_written)
			cut.close()
		message = message.trim_suffix(".") + "; the saved prefix remains available."
	_fail(message)

func _fail(message: String) -> void:
	error = message
	if recorder != null: recorder.finished = true
	if _file != null:
		_file.close()
		_file = null
	failed.emit(message)

func close() -> void:
	if recorder != null:
		recorder.detach()
		recorder = null
	if _file != null:
		_record("close", {"reason": "recording-stopped"})
		if _file != null: _file.close()
		_file = null

static func read(path_value: String) -> Dictionary:
	var file := FileAccess.open(path_value, FileAccess.READ)
	if file == null: return {"error": "Cannot open this recording."}
	if file.get_length() > MpnCodec.MAX_BYTES:
		file.close()
		return {"error": "Record exceeds the 32 MiB prototype limit."}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return MpnCodec.parse_bytes(bytes)

static func files(directory := "") -> Array[String]:
	var out: Array[String] = []
	var folder := GamePaths.records_folder() if directory == "" else directory
	var dir := DirAccess.open(folder)
	if dir == null: return out
	for name in dir.get_files():
		if name.get_extension().to_lower() == "mpn": out.append(folder.path_join(name))
	out.sort()
	out.reverse()
	return out


## THE FOLDER HAS A BOUND (campaign of 2026-11-26). Every duel that is not
## a test writes a recording of some 40 to 140 KB, and nothing removed
## one: a season of play was thousands of files that only a file manager
## could clear — and on the web, a handheld or a portable game they ride
## along with everything else. So the newest [constant KEEP_RECORDS]
## recordings are kept, and of those no more than [constant KEEP_BYTES]
## together; a new recording lets the oldest go ([method prune]). Past
## Games says the number and offers Delete and Delete all.
const KEEP_RECORDS := 500
const KEEP_BYTES := 64 * 1024 * 1024


## Whether [param name] is a recording this class named itself:
## `YYYYMMDDTHHMMSSZ-<24 hex digits>.mpn` ([method start]). Only such a
## file is ever pruned — never an imported one (`import-…`), nor a file
## the player put in the folder under a name of their own.
static func is_recorded_name(name: String) -> bool:
	if name.length() != 45 or not name.ends_with(".mpn") or name[8] != "T" or name[15] != "Z" or name[16] != "-":
		return false
	return (name.substr(0, 8) + name.substr(9, 6)).is_valid_int() and name.substr(17, 24).is_valid_hex_number()


## Remove the oldest recordings of [param directory] (the game's own
## folder when "") past [param keep_records] files or [param keep_bytes]
## bytes together; how many went. By name, which starts with the time —
## oldest first — and only names of [method is_recorded_name]; never
## [param spare] (the recording being written).
static func prune(directory := "", keep_records := KEEP_RECORDS, keep_bytes := KEEP_BYTES, spare := "") -> int:
	var folder := GamePaths.records_folder() if directory == "" else directory
	var dir := DirAccess.open(folder)
	if dir == null: return 0
	var names: Array[String] = []
	for name in dir.get_files():
		if is_recorded_name(name): names.append(name)
	names.sort()
	names.reverse()      # newest first
	var kept := 0
	var bytes := 0
	var removed := 0
	var full := false    # once the bound is met, everything older goes
	for name in names:
		var at := folder.path_join(name)
		var size := FileAccess.get_size(at)
		full = full or kept >= keep_records or bytes + size > keep_bytes
		if at == spare or not full:
			kept += 1
			bytes += maxi(0, size)
		elif not dir.is_link(name) and DirAccess.remove_absolute(at) == OK:
			removed += 1
	return removed


## Remove the recording at [param path_value] — only an `.mpn` file that
## sits in [param directory] itself (the game's own folder when "").
static func delete(path_value: String, directory := "") -> bool:
	var folder := GamePaths.records_folder() if directory == "" else directory
	if path_value.get_extension().to_lower() != "mpn" or path_value != folder.path_join(path_value.get_file()):
		return false
	return FileAccess.file_exists(path_value) and DirAccess.remove_absolute(path_value) == OK


## Remove every recording [method files] lists; how many went.
static func delete_all(directory := "") -> int:
	var removed := 0
	for at in files(directory):
		if delete(at, directory): removed += 1
	return removed
