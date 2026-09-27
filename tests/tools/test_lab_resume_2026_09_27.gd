extends GutTest
## THE RESUME (2026-09-27): a run writes run.json with `exit: null`
## before its first game and a record into OUT/checkpoint.jsonl as each
## game lands; `--resume OUT` reads the line back from run.json, keeps
## the checkpointed games, plays the rest and writes the report as if
## nothing had happened, with `resumed {from, reused, played}` in the
## final run.json and the checkpoint gone. Pinned in-process, over a
## real four-game duel that is then dressed as an interrupted one.

var _made: Array[String] = []


func after_each() -> void:
	for path in _made:
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute):
			_remove_tree(absolute)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
	_made.clear()


static func _remove_tree(absolute: String) -> void:
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	dir.include_hidden = true
	for sub in dir.get_directories():
		_remove_tree(absolute.path_join(sub))
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(absolute)


func _lab():
	return autofree(load("res://DeckLab/simulate.gd").new())


func _scratch(kind: String) -> String:
	var path := "user://resume_%s_%d_%d" % [kind, Time.get_ticks_usec(), _made.size()]
	_made.append(path)
	return path


func _json(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "expected " + path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "a JSON object in " + path)
	return parsed if parsed is Dictionary else {}


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "cannot write " + path)
	if file != null:
		file.store_string(text)
		file.close()


func _logs_in(out: String) -> PackedStringArray:
	var names := PackedStringArray()
	var dir := DirAccess.open(out.path_join("records"))
	if dir == null:
		return names
	for file_name in dir.get_files():
		if file_name.ends_with(".log"):
			names.append(file_name)
	names.sort()
	return names


const DUEL := ["--deck-a", "big_green.deck", "--deck-b", "white_knights.deck"]
const QUIET := ["--procs", "1", "--jobs", "1", "--quiet", "--no-elo", "--no-svg"]


# ------------------------------------------------------------- keys --

func test_a_task_is_named_by_arm_pair_and_seed() -> void:
	var lab = _lab()
	assert_eq(lab.task_key({"pair": 3, "seed": 41}), "-1/3/41", "no arm outside a sweep")
	assert_eq(lab.task_key({"arm": 2, "pair": 0, "seed": 7}), "2/0/7")
	assert_eq(lab.task_key({}), "-1/0/0")


func test_a_checkpoint_reads_back_whole_lines_and_skips_a_torn_one() -> void:
	var lab = _lab()
	var path := _scratch("torn")
	var whole := {"arm": -1, "pair": 0, "seed": 5,
		"record": {"a_won": true, "a_on_play": true, "turns": 9, "stalled": false, "drawn": false}}
	var other := {"arm": 1, "pair": 2, "seed": 6, "record": {"a_won": false, "a_on_play": false,
		"turns": 4, "stalled": false, "drawn": false}}
	_write(path, JSON.stringify(whole) + "\n" + "not json at all\n"
		+ JSON.stringify({"arm": -1, "pair": 0, "seed": 99}) + "\n"
		+ JSON.stringify(other) + "\n" + '{"arm": -1, "pair": 0, "seed": 7, "record": {"a_w')
	var records: Dictionary = lab.checkpoint_records(path)
	assert_eq(records.size(), 2, str(records.keys()))
	assert_true(records.has("-1/0/5"))
	assert_true(records.has("1/2/6"))
	assert_eq(int(records["-1/0/5"].turns), 9)
	assert_false(records.has("-1/0/99"), "a line without a record is not a game")
	assert_false(records.has("-1/0/7"), "the torn last line of a kill")
	assert_eq(lab.checkpoint_records("user://no_such_checkpoint.jsonl").size(), 0)


func test_the_checkpoint_appends_after_a_torn_line_and_flushes_each_record() -> void:
	var lab = _lab()
	var out := _scratch("append")
	var absolute := ProjectSettings.globalize_path(out)
	assert_eq(DirAccess.make_dir_recursive_absolute(absolute), OK)
	_write(out.path_join(lab.CHECKPOINT),
		JSON.stringify({"arm": -1, "pair": 0, "seed": 1, "record": {"a_won": true,
			"a_on_play": true, "turns": 3, "stalled": false, "drawn": false}}) + "\n{\"torn")
	lab._out_absolute = absolute
	lab._tasks = [{"pair": 0, "seed": 2}, {"arm": 4, "pair": 1, "seed": 3}]
	lab._results = [{"a_won": false, "a_on_play": true, "turns": 5, "stalled": false, "drawn": false},
		{"a_won": true, "a_on_play": false, "turns": 6, "stalled": false, "drawn": false}]
	lab._checkpoint_open()
	assert_not_null(lab._checkpoint, "the file opens for appending")
	lab._checkpoint_record(0)
	# Flushed as written: readable before the file is closed.
	var mid: Dictionary = lab.checkpoint_records(out.path_join(lab.CHECKPOINT))
	assert_eq(mid.size(), 2, "the whole first line, the torn one skipped, the new one: " + str(mid.keys()))
	lab._checkpoint_record(1)
	lab._checkpoint_close()
	assert_null(lab._checkpoint)
	var text := FileAccess.get_file_as_string(out.path_join(lab.CHECKPOINT))
	var lines := text.split("\n", false)
	assert_eq(lines.size(), 4, "torn line, then the two new ones on lines of their own: " + text)
	assert_eq(lines[1], '{"torn', "the torn line is left as it was, ended")
	var all: Dictionary = lab.checkpoint_records(out.path_join(lab.CHECKPOINT))
	assert_eq(all.size(), 3, str(all.keys()))
	assert_true(all.has("-1/0/2"))
	assert_true(all.has("4/1/3"))
	assert_eq(int(all["4/1/3"].turns), 6)


func test_a_landed_slice_is_checkpointed_by_the_parent() -> void:
	var lab = _lab()
	var out := _scratch("slice")
	var absolute := ProjectSettings.globalize_path(out)
	assert_eq(DirAccess.make_dir_recursive_absolute(absolute), OK)
	lab._out_absolute = absolute
	lab._tasks = [{"pair": 0, "seed": 1}, {"pair": 0, "seed": 2}, {"pair": 1, "seed": 3}]
	lab._results.resize(3)
	_write(out.path_join("done_0.json"), '[{"turns": 5, "a_won": true, "a_on_play": true, "stalled": false},'
		+ ' {"turns": 7, "a_won": false, "a_on_play": false, "stalled": false}]')
	lab._checkpoint_open()
	var slice := {"lo": 1, "hi": 3, "out": absolute.path_join("done_0.json"), "landed": false}
	assert_true(lab._take_slice(slice))
	lab._checkpoint_close()
	var records: Dictionary = lab.checkpoint_records(out.path_join(lab.CHECKPOINT))
	assert_eq(records.size(), 2, "the slice's two games, none for the task it did not hold: " + str(records.keys()))
	assert_true(records.has("-1/0/2"))
	assert_true(records.has("-1/1/3"))
	assert_eq(int(records["-1/1/3"].turns), 7)


func test_a_run_of_its_own_has_no_checkpoint_to_open() -> void:
	var lab = _lab()
	lab._checkpoint_open()
	assert_null(lab._checkpoint, "no output folder yet, nothing to write")
	lab._checkpoint_record(0)
	lab._checkpoint_close()
	pass_test("a record before the folder exists is dropped, not a crash")


# ------------------------------------------------------ the first word --

func test_run_json_says_exit_null_first_and_the_report_replaces_it() -> void:
	var lab = _lab()
	var out := _scratch("first_word")
	var absolute := ProjectSettings.globalize_path(out)
	assert_eq(DirAccess.make_dir_recursive_absolute(absolute), OK)
	lab._argv = PackedStringArray(["--deck-a", "x.deck"])
	_write(out.path_join(lab.CHECKPOINT), "{}\n")
	assert_true(lab._run_json(out, null, {"mode": "duel", "seed": 1, "elapsed_seconds": null,
		"files": [], "next": null}))
	var run := _json(out.path_join(lab.RUN_JSON))
	assert_true(run.has("exit"), "the key is there")
	assert_null(run.get("exit", 0), "and null: the run has not finished")
	assert_eq(Array(run.argv), ["--deck-a", "x.deck"])
	assert_false(run.has("resumed"), "a run of its own")
	assert_true(FileAccess.file_exists(out.path_join(lab.CHECKPOINT)), "an unfinished run keeps its checkpoint")
	assert_true(lab._run_json(out, 1, {"mode": "duel", "seed": 1, "elapsed_seconds": null,
		"files": [], "next": null}))
	assert_true(FileAccess.file_exists(out.path_join(lab.CHECKPOINT)), "a failed run keeps it too")
	assert_true(lab._run_json(out, 0, {"mode": "duel", "seed": 1, "elapsed_seconds": 2.0,
		"files": [], "next": null}))
	run = _json(out.path_join(lab.RUN_JSON))
	assert_eq(int(run.exit), 0)
	assert_false(FileAccess.file_exists(out.path_join(lab.CHECKPOINT)), "a finished run has no checkpoint")
	# The pin on the order: the first word is written before a game is played.
	var source := FileAccess.get_file_as_string("res://DeckLab/simulate.gd")
	var first := source.find("if not _run_json(out_dir, null, {")
	var played := source.find("var elapsed := _play_tasks(opts, jobs, unit)")
	assert_true(first > 0 and played > first, "run.json before _play_tasks in _main")


func test_a_dry_run_and_a_refused_line_write_no_run_json() -> void:
	var lab = _lab()
	var out := _scratch("dry")
	var code: int = lab._main(PackedStringArray(DUEL + QUIET + ["--games", "1", "--dry-run", "--out", out]))
	assert_eq(code, 0, str(lab.last_error))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(out)),
		"a dry run makes nothing")


# ------------------------------------------------------------ resume --

func test_resume_keeps_the_checkpointed_games_and_plays_the_rest() -> void:
	var lab = _lab()
	var out := _scratch("resume")
	var argv := PackedStringArray(DUEL + QUIET + ["--games", "4", "--seed", "5",
		"--record", "all", "--out", out])
	var code: int = lab._main(argv)
	assert_eq(code, 0, str(lab.last_error))
	var run := _json(out.path_join(lab.RUN_JSON))
	assert_eq(int(run.exit), 0)
	assert_false(FileAccess.file_exists(out.path_join(lab.CHECKPOINT)), "finished: no checkpoint")
	var finished := _json(out.path_join("results.json"))
	assert_eq(int(finished.matchups[0].games), 4)
	# Dress it as a run that was killed after its second game: run.json
	# with `exit: null` (the first word, as written before the games), a
	# checkpoint holding two records, and no report.
	run["exit"] = null
	run["files"] = []
	run["elapsed_seconds"] = null
	run["next"] = null
	_write(out.path_join(lab.RUN_JSON), JSON.stringify(run, "  ") + "\n")
	var fake_a := {"a_won": true, "a_on_play": true, "turns": 77, "stalled": false, "drawn": false}
	var fake_b := {"a_won": false, "a_on_play": false, "turns": 0, "stalled": true, "drawn": false}
	_write(out.path_join(lab.CHECKPOINT),
		JSON.stringify({"arm": -1, "pair": 0, "seed": 5, "record": fake_a}) + "\n"
		+ JSON.stringify({"arm": -1, "pair": 0, "seed": 6, "record": fake_b}) + "\n"
		+ '{"arm": -1, "pair": 0, "seed": 7, "record": {"a_won": tr')
	for name in ["results.json", "report.txt", "matchups.csv"]:
		if FileAccess.file_exists(out.path_join(name)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(out.path_join(name)))
	_remove_tree(ProjectSettings.globalize_path(out.path_join("records")))
	var again = _lab()
	code = again._main(PackedStringArray(["--resume", out]))
	assert_eq(code, 0, str(again.last_error))
	assert_eq(again._resumed, {"reused": 2, "played": 2})
	var logs := _logs_in(out)
	assert_eq(logs.size(), 2, "only the two games left were played: " + str(logs))
	if logs.size() == 2:
		assert_true(logs[0].begins_with("pair0_seed7_"), logs[0])
		assert_true(logs[1].begins_with("pair0_seed8_"), logs[1])
	var results := _json(out.path_join("results.json"))
	assert_eq(int(results.matchups[0].games), 4, "two kept, two played")
	assert_eq(int(results.matchups[0].stalled), 1, "the fake stall was kept as played")
	assert_eq(int(results.matchups[0].a_wins) + int(results.matchups[0].b_wins)
		+ int(results.matchups[0].get("draws", 0)) + int(results.matchups[0].stalled), 4)
	assert_true(float(results.matchups[0].avg_turns) > 20.0,
		"the 77-turn fake is in the average: %s" % results.matchups[0].avg_turns)
	run = _json(out.path_join(lab.RUN_JSON))
	assert_eq(int(run.exit), 0)
	assert_eq(Array(run.argv), Array(argv), "the line that started the run, not `--resume OUT`")
	assert_true(run.has("resumed"), str(run.keys()))
	if run.has("resumed"):
		assert_eq(String(run.resumed.from), out)
		assert_eq(int(run.resumed.reused), 2)
		assert_eq(int(run.resumed.played), 2)
	assert_false(FileAccess.file_exists(out.path_join(lab.CHECKPOINT)), "finished: the checkpoint is gone")
	assert_true(FileAccess.file_exists(out.path_join("report.txt")))
	# A finished run cannot be resumed.
	var third = _lab()
	code = third._main(PackedStringArray(["--resume", out]))
	assert_eq(code, 2)
	assert_eq(third.last_error.kind, "resume", str(third.last_error))
	assert_eq(int(third.last_error.exit), 2, "the refusal's own exit")
	assert_eq(int(third.last_error.run_exit), 0, "the detail names the exit the run had")
	assert_true(String(third.last_error.message).contains("finished (exit 0)"), third.last_error.message)


func test_resume_with_an_empty_checkpoint_plays_everything() -> void:
	var lab = _lab()
	var out := _scratch("empty")
	var argv := PackedStringArray(DUEL + QUIET + ["--games", "2", "--seed", "5", "--out", out])
	assert_eq(lab._main(argv), 0, str(lab.last_error))
	var run := _json(out.path_join(lab.RUN_JSON))
	run["exit"] = null
	_write(out.path_join(lab.RUN_JSON), JSON.stringify(run, "  ") + "\n")
	var again = _lab()
	assert_eq(again._main(PackedStringArray(["--resume", out])), 0, str(again.last_error))
	assert_eq(again._resumed, {"reused": 0, "played": 2})
	run = _json(out.path_join(lab.RUN_JSON))
	assert_eq(int(run.exit), 0)
	assert_eq(int(run.resumed.reused), 0)
	assert_eq(int(run.resumed.played), 2)


func test_resume_refusals() -> void:
	var lab = _lab()
	var code: int = lab._main(PackedStringArray(["--resume"]))
	assert_eq(code, 2)
	assert_eq(lab.last_error.flag, "--resume", str(lab.last_error))
	assert_true(String(lab.last_error.message).contains("needs a value"), lab.last_error.message)
	var nowhere := _scratch("nowhere")
	lab = _lab()
	code = lab._main(PackedStringArray(["--resume", nowhere, "--games", "1"]))
	assert_eq(code, 2, "no other switch")
	assert_eq(lab.last_error.kind, "option", str(lab.last_error))
	assert_true(String(lab.last_error.message).contains("takes only the run's folder"), lab.last_error.message)
	lab = _lab()
	code = lab._main(PackedStringArray(["--games", "1", "--resume", nowhere]))
	assert_eq(code, 2, "nor before it")
	lab = _lab()
	code = lab._main(PackedStringArray(["--resume", nowhere]))
	assert_eq(code, 2)
	assert_eq(lab.last_error.kind, "resume", str(lab.last_error))
	assert_eq(lab.last_error.path, nowhere)
	assert_true(String(lab.last_error.message).contains("nothing to resume"), lab.last_error.message)
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(nowhere)), "nothing made")
	# A run.json the Lab did not write.
	var foreign := _scratch("foreign")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(foreign)), OK)
	_write(foreign.path_join(lab.RUN_JSON), JSON.stringify({"tool": "auto_deck", "argv": [], "exit": null}))
	lab = _lab()
	code = lab._main(PackedStringArray(["--resume", foreign]))
	assert_eq(code, 2)
	assert_true(String(lab.last_error.message).contains("not a run.json the Deck Lab wrote"), lab.last_error.message)
	_write(foreign.path_join(lab.RUN_JSON), "[1, 2]")
	lab = _lab()
	assert_eq(lab._main(PackedStringArray(["--resume", foreign])), 2, "not even an object")


func test_resume_is_a_documented_switch() -> void:
	var lab = _lab()
	assert_true(lab.FLAG_HINTS.has("--resume"))
	assert_true(String(lab.HELP).contains("--resume OUT"))
	assert_true(String(lab.HELP).contains("checkpoint.jsonl"))
	var opts: Dictionary = lab._parse_args(PackedStringArray(DUEL))
	assert_eq(opts.resume, "", "the parser knows the key, `_main` acts on it first")
	var agents := FileAccess.get_file_as_string("res://AGENTS.md")
	assert_true(agents.contains("--resume"), "the contract page names it")
	assert_true(agents.contains("checkpoint.jsonl"))
	var readme := FileAccess.get_file_as_string("res://DeckLab/README.md")
	assert_true(readme.contains("--resume"), "the Lab manual names it")
