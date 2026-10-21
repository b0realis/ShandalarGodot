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

func _write(text: String) -> void:
	_bytes += text.to_utf8_buffer().size()
	if _bytes > MpnCodec.MAX_BYTES:
		_fail("Past Games: recording stopped at 32 MiB; the saved prefix remains available.")
		return
	if not _file.store_string(text) or _file.get_error() != OK:
		_fail("Past Games: the recording could not be written.")
		return
	_file.flush()
	if _file.get_error() != OK: _fail("Past Games: the recording could not be flushed to disk.")

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
	var text := file.get_as_text()
	file.close()
	return MpnCodec.parse(text)

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
