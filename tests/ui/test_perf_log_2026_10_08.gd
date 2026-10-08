extends GutTest
## THE OPT-IN TIMING LOG ([PerfLog], 2026-10-08) — for the R36 Ultra
## tester whose game stutters on ArkOS. The owner: *"can we make it opt in
## so it does not run every time?"* So the first thing pinned is that a
## launch which did not ask builds nothing and writes nothing; then how a
## launch asks (the environment, `-- --perf-log`, a `perf-log` file beside
## the executable); then what the log says about a frame, a hitch and the
## duel's two labelled jobs, the computer's decision and the screen's
## refresh.

var _made: Array[String] = []


func after_each() -> void:
	for folder in _made:
		var absolute := ProjectSettings.globalize_path(folder)
		var dir := DirAccess.open(absolute)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
		DirAccess.remove_absolute(absolute)
	_made.clear()


func _scratch() -> String:
	var folder := "user://perf_log_test_%d_%d" % [Time.get_ticks_usec(), _made.size()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_made.append(folder)
	return folder


func _log_in(folder: String) -> PerfLog:
	var node := PerfLog.new()
	node.path = folder.path_join("perf.log")
	node.asked_by = "a test"
	add_child_autofree(node)
	return node


func _text(node: PerfLog) -> String:
	return FileAccess.get_file_as_string(node.path)


# ------------------------------------------------------------ off unless --

func test_a_launch_that_did_not_ask_builds_nothing() -> void:
	assert_eq(PerfLog.asked(), "", "the test run asked for nothing")
	assert_false(PerfLog.is_active(), "no log node anywhere")
	assert_eq(PerfLog.now(), 0, "a caller pays no clock")
	PerfLog.span("anything", PerfLog.now())   # and a span is a no-op
	assert_false(PerfLog.is_active())


func test_how_a_launch_asks() -> void:
	var none := PackedStringArray()
	assert_eq(PerfLog.asked_from("", none, ""), "")
	assert_eq(PerfLog.asked_from("0", none, ""), "", "0 is no")
	assert_string_contains(PerfLog.asked_from("1", none, ""), PerfLog.ENV)
	assert_string_contains(PerfLog.asked_from("on", none, ""), PerfLog.ENV)
	assert_string_contains(PerfLog.asked_from("", PackedStringArray(["--perf-log"]), ""), "--perf-log")
	var folder := ProjectSettings.globalize_path(_scratch())
	assert_eq(PerfLog.asked_from("", none, folder), "", "an empty folder asks nothing")
	for marker in PerfLog.MARKERS:
		var file := FileAccess.open(folder.path_join(marker), FileAccess.WRITE)
		file.close()
		assert_string_contains(PerfLog.asked_from("", none, folder), marker,
			"an empty file named %s beside the executable asks" % marker)
		DirAccess.remove_absolute(folder.path_join(marker))


# -------------------------------------------------------------- the log --

func test_the_log_names_the_work_inside_a_hitch() -> void:
	var node := _log_in(_scratch())
	assert_true(PerfLog.is_active())
	var t0 := node._started_us
	node._frame(33.0, t0 + 33000)
	node._record("computer decision", 380.0)
	node._record("screen refresh", 12.0)
	node._frame(412.0, t0 + 445000)      # the frame that held both
	node._frame(33.0, t0 + 478000)
	node._frame(33.0, t0 + 1100000)      # the next second closes the first
	var text := _text(node)
	assert_string_contains(text, "timing log")
	assert_string_contains(text, "after the process started", "the start's length is in the header")
	assert_string_contains(text, "HITCH 412 ms — inside it: computer decision 380 ms, screen refresh 12 ms")
	assert_string_contains(text, "computer decision 1× avg 380.0 ms worst 380 ms",
		"the slow second is a line with what the work cost in it")
	assert_string_contains(text, "worst 412 ms")


func test_a_hitch_with_no_labelled_work_says_so() -> void:
	var node := _log_in(_scratch())
	node._frame(150.0, node._started_us + 150000)
	assert_string_contains(_text(node), "HITCH 150 ms — no labelled work inside it")


func test_quiet_seconds_write_no_lines() -> void:
	var node := _log_in(_scratch())
	var before := _text(node).count("\n")
	var t := node._started_us
	for i in 90:
		t += 33000
		node._frame(33.0, t)
	assert_eq(_text(node).count("\n"), before, "three quiet seconds, no lines")


func test_the_summary_has_percentiles_and_every_label() -> void:
	var folder := _scratch()
	var node := _log_in(folder)
	var t := node._started_us
	for i in 99:
		t += 30000
		node._frame(30.0, t)
	node._record("computer decision", 200.0)
	t += 250000
	node._frame(250.0, t)
	assert_eq(node.percentile(0.50), 30)
	assert_eq(node.percentile(0.99), 30)
	assert_eq(node.percentile(1.0), 250)
	var path := node.path
	remove_child(node)       # leaving the tree writes the exit summary
	node.free()
	assert_false(PerfLog.is_active(), "gone with its node")
	var text := FileAccess.get_file_as_string(path)
	assert_string_contains(text, "SUMMARY (exit)")
	assert_string_contains(text, "100 frames, frame ms p50 30 / p95 30 / p99 30 / worst 250")
	assert_string_contains(text, "computer decision: 1×, avg 200.0 ms, worst 200 ms")


# ------------------------------------------------------------- the duel --

func _duel() -> DuelScreen:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	return screen


func test_the_duel_reports_the_computers_decision_and_its_refresh() -> void:
	var screen := _duel()
	await get_tree().process_frame
	var node := _log_in(_scratch())
	var g: MtgGame = screen.game
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1
	screen.mode = DuelScreen.Mode.NORMAL
	screen._ai_step()
	assert_true(node._run_spans.has("computer decision"), str(node._run_spans.keys()))
	assert_true(node._run_spans.has("screen refresh"), str(node._run_spans.keys()))


func test_the_duel_without_the_log_still_plays() -> void:
	var screen := _duel()
	await get_tree().process_frame
	var g: MtgGame = screen.game
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1
	screen.mode = DuelScreen.Mode.NORMAL
	screen._ai_step()
	assert_false(PerfLog.is_active())
	assert_false(FileAccess.file_exists(PerfLog.PATH) and
		FileAccess.get_modified_time(PerfLog.PATH) >= Time.get_unix_time_from_system() - 5,
		"nothing written by a launch that did not ask")
