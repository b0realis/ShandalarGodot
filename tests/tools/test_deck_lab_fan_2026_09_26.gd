extends GutTest
## The process fan-out's answer files and its retry (2026-09-26). The
## first thousand-deck tournament — 430,000 games over eight children,
## 3 h 21 m — ended with nothing: the parent took a child's answer file
## for its landing the instant the file was OPENED, took the run for
## finished when the last one appeared, killed the children still
## running (the last one, mid-write), read an empty file, threw all
## eight slices away and replayed every game in the thread pool, where
## it crashed. Now a child writes its answer under another name and
## renames it whole; the parent lands a slice only under its final name,
## reads it as it lands, and a slice that comes back without records —
## a dead child, a file that is not a slice — is asked of a fresh child
## up to FAN_ATTEMPTS times before the run is given up with the game the
## last heartbeat was on. Nothing is ever replayed in-process.
##
## Two tests here start a REAL child (one Godot, one game each): the
## suite's rule that spawning is not unit-tested (test_deck_lab.gd) was
## written before a spawn bug cost three hours of games, and one child
## for one game is a second of the suite's time.

var _made: Array[String] = []


func after_each() -> void:
	for path in _made:
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute):
			var dir := DirAccess.open(absolute)
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(absolute)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
	_made.clear()


func _lab():
	return autofree(load("res://DeckLab/simulate.gd").new())


func _sim_const(name: String) -> Variant:
	return load("res://DeckLab/simulate.gd").get_script_constant_map()[name]


## A fan directory of the parent's own shape, absolute so that a child
## reads the same path the parent wrote.
func _fan_dir() -> String:
	var path := "user://deck_lab_fan_test_%d" % Time.get_ticks_usec()
	_made.append(path)
	assert_eq(DirAccess.make_dir_recursive_absolute(path), OK)
	return ProjectSettings.globalize_path(path)


## A lab with [param games] one-duel tasks and the slice file a child
## would read for them, written where a real fan-out writes it.
func _lab_with_slice(games: int, dir: String) -> Dictionary:
	var lab = _lab()
	var deck := DeckList.load_file("res://decks/mountain_artillery.deck")
	lab._duel_opts = {"fingerprint": true, "best_of": 0, "sideboard": false}
	for i in games:
		lab._tasks.append({"pair": 0, "seed": 4242 + i, "a_on_play": i % 2 == 0,
			"deck_a": deck.cards, "deck_b": deck.cards,
			"sb_a": deck.sideboard, "sb_b": deck.sideboard,
			"profile_a": "wizard", "profile_b": "wizard"})
	lab._results.resize(games)
	var slice := {"lo": 0, "hi": games, "in": dir.path_join("slice_0.json"),
		"out": dir.path_join("done_0.json"), "beat": dir.path_join("beat_0.txt"),
		"pid": 0, "attempts": 0, "landed": false}
	assert_true(lab._write(String(slice["in"]), JSON.stringify(lab._worker_payload(0, games))))
	return {"lab": lab, "slice": slice}


## The process id of a child of ours that has exited — what a parent
## holds once its worker has died. It has to be a real child: asking
## `is_process_running` about a made-up number is an engine error, not
## a false. (Where a test only needs "no live process", pid 0 says so
## without a spawn — the parent never asks about 0.)
func _dead_pid() -> int:
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(["--version"]))
	assert_gt(pid, 0, "a child to lose")
	var waited := 0
	while OS.is_process_running(pid) and waited < 20000:
		OS.delay_msec(50)
		waited += 50
	assert_false(OS.is_process_running(pid), "…and it has gone")
	return pid


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ----------------------------------------------------------- the answer --

func test_a_child_writes_its_answer_whole_or_not_at_all() -> void:
	# THE BUG: the parent lands a slice on the existence of its file, and
	# the child used to open that file and THEN spend seconds turning
	# 54,000 records into text. The answer now appears under its final
	# name only once it is closed.
	var dir := _fan_dir()
	var made := _lab_with_slice(1, dir)
	var lab = made["lab"]
	var slice: Dictionary = made["slice"]
	assert_eq(lab._run_worker(String(slice["in"]), String(slice["out"])), 0)
	assert_true(FileAccess.file_exists(String(slice["out"])), "the answer, under its final name")
	assert_false(FileAccess.file_exists(String(slice["out"]) + lab.SLICE_PART),
		"the working name is gone: renamed, not copied")
	var records: Variant = lab.slice_records(String(slice["out"]))
	assert_true(records is Array)
	assert_eq((records as Array).size(), 1)
	assert_true((records as Array)[0].has("fingerprint"))


func test_only_a_whole_slice_is_records() -> void:
	var dir := _fan_dir()
	var lab = _lab()
	var path := dir.path_join("done_0.json")
	assert_null(lab.slice_records(path), "no file")
	_put(path, "")
	assert_null(lab.slice_records(path), "an empty file — the crash's exact shape")
	_put(path, '[{"winner": "A"}, {"win')
	assert_null(lab.slice_records(path), "cut short")
	_put(path, '{"winner": "A"}')
	assert_null(lab.slice_records(path), "not an array")
	_put(path, '[{"winner": "A"}]')
	var records: Variant = lab.slice_records(path)
	assert_true(records is Array)
	assert_eq((records as Array).size(), 1)


func test_a_slice_lands_only_under_its_final_name() -> void:
	var dir := _fan_dir()
	var lab = _lab()
	var slice := {"lo": 0, "hi": 1, "out": dir.path_join("done_0.json"),
		"beat": dir.path_join("beat_0.txt"), "pid": 0, "attempts": 1, "landed": false}
	assert_eq(lab._slice_status(slice), lab.SLICE_DEAD, "no file, no process: dead")
	_put(String(slice["out"]) + lab.SLICE_PART, "[")
	assert_eq(lab._slice_status(slice), lab.SLICE_DEAD,
		"a child's working file is not a landing")
	_put(String(slice["out"]), "[]")
	assert_eq(lab._slice_status(slice), lab.SLICE_LANDED,
		"the final name is, whether or not the process is still there")
	assert_eq(lab._slice_status({"out": String(slice["out"]), "pid": OS.get_process_id()}),
		lab.SLICE_LANDED)


func test_a_landed_file_must_hold_one_record_per_task() -> void:
	var dir := _fan_dir()
	var lab = _lab()
	lab._results.resize(3)
	var slice := {"lo": 1, "hi": 3, "out": dir.path_join("done_0.json"), "landed": false}
	_put(String(slice["out"]), '[{"turns": 5}]')
	assert_false(lab._take_slice(slice), "one record for two games is not the slice")
	assert_false(slice["landed"])
	assert_null(lab._results[1])
	_put(String(slice["out"]), '[{"turns": 5}, {"turns": 7}]')
	assert_true(lab._take_slice(slice))
	assert_true(slice["landed"])
	assert_null(lab._results[0], "the slice's records go where its tasks came from")
	assert_eq(int(lab._results[1]["turns"]), 5)
	assert_eq(int(lab._results[2]["turns"]), 7)


# ------------------------------------------------------------- the retry --

func test_a_child_that_died_is_replaced_by_a_fresh_one() -> void:
	# The crash's exact shape: the child is gone, its answer file is
	# there and empty. The parent asks a fresh child — a real one — for
	# the same slice, and the records land where the first child's would
	# have. Starts one Godot for one game.
	var dir := _fan_dir()
	var made := _lab_with_slice(1, dir)
	var lab = made["lab"]
	var slice: Dictionary = made["slice"]
	slice["pid"] = _dead_pid()
	slice["attempts"] = 1
	_put(String(slice["out"]), "")
	var direct: Dictionary = lab._play_task(lab._tasks[0])
	lab._progress_mode = lab.PROGRESS_LOG
	assert_true(lab._gather([slice], OS.get_executable_path(),
		ProjectSettings.globalize_path("res://"), "games", Time.get_ticks_msec()))
	assert_eq(int(slice["attempts"]), 2, "one fresh child, no more")
	assert_true(slice["landed"])
	assert_not_null(lab._results[0], "the retried child's record is in place")
	assert_eq(lab._results[0]["fingerprint"], direct["fingerprint"],
		"the same game with the same seed: nothing was re-decided")
	if int(slice["pid"]) > 0 and OS.is_process_running(int(slice["pid"])):
		OS.kill(int(slice["pid"]))


func test_a_slice_no_child_can_finish_stops_the_run_and_names_the_game() -> void:
	# After the last child the parent gives the run up rather than
	# replaying the slice itself: a game that kills three children would
	# kill the parent too, and with it the slices that did come back.
	var dir := _fan_dir()
	var made := _lab_with_slice(4, dir)
	var lab = made["lab"]
	var slice: Dictionary = made["slice"]
	slice["pid"] = 0
	slice["attempts"] = int(_sim_const("FAN_ATTEMPTS"))
	lab._beat(String(slice["beat"]), 2)
	lab._progress_mode = lab.PROGRESS_LOG
	assert_false(lab._gather([slice], OS.get_executable_path(),
		ProjectSettings.globalize_path("res://"), "games", Time.get_ticks_msec()))
	assert_eq(int(slice["attempts"]), int(_sim_const("FAN_ATTEMPTS")), "no fourth child")
	assert_false(slice["landed"])
	assert_eq(lab.missing_records(lab._results), 4, "nothing was played in-process")
	var message: String = lab._abandon_message(0, slice)
	assert_string_contains(message, "slice 1 died 3 times")
	assert_string_contains(message, "games 1 to 4 are unplayed")
	assert_string_contains(message, "the run is not a result")
	assert_string_contains(message, "game 3 (pair 0, seed 4244)",
		"two games beat: the third is the one the child was on")
	# A heartbeat past the end (the child died writing its answer) names
	# the slice's last game rather than one past it.
	lab._beat(String(slice["beat"]), 9)
	assert_string_contains(lab._abandon_message(0, slice), "game 4 (pair 0, seed 4245)")


func test_a_fresh_child_starts_from_a_clean_slate() -> void:
	# What an earlier child left — its heartbeat, its half answer, an
	# answer that was not one — is gone before the next one starts, so
	# the parent cannot land the old attempt's leavings as the new one's.
	# Starts one Godot for one game.
	var dir := _fan_dir()
	var made := _lab_with_slice(1, dir)
	var lab = made["lab"]
	var slice: Dictionary = made["slice"]
	_put(String(slice["out"]), "not a slice")
	_put(String(slice["out"]) + lab.SLICE_PART, "[")
	lab._beat(String(slice["beat"]), 77)
	assert_true(lab._launch(OS.get_executable_path(),
		ProjectSettings.globalize_path("res://"), slice))
	assert_gt(int(slice["pid"]), 0)
	assert_eq(int(slice["attempts"]), 1)
	# Looked at right after the spawn, before a child that takes a second
	# to import could have written anything.
	assert_false(FileAccess.file_exists(String(slice["out"]) + lab.SLICE_PART))
	assert_eq(lab._slice_beat(String(slice["beat"])), 0)
	# Then let it land, so the directory can be removed.
	var waited := 0
	while lab._slice_status(slice) == lab.SLICE_RUNNING and waited < 60000:
		OS.delay_msec(100)
		waited += 100
	assert_eq(lab._slice_status(slice), lab.SLICE_LANDED, "the fresh child answered")
	assert_true(lab._take_slice(slice))


func test_the_fan_out_never_replays_a_run_in_process() -> void:
	# The doc of _fan_out and _play_tasks say so; the constant says how
	# patient the retry is. Three children in all: the first and two more.
	assert_eq(int(_sim_const("FAN_ATTEMPTS")), 3)
	var lab = _lab()
	var source: String = (lab.get_script() as GDScript).source_code
	assert_string_contains(source, "It is NEVER replayed in-process")
	assert_false(source.contains("running in-process instead"),
		"the old fallback message is gone with the fallback")
