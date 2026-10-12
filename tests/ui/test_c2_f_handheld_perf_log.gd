extends GutTest
## THE TIMING LOG, 2026-10-12 hunt ([PerfLog]; hunts b1-4, b1-5, b1-6,
## r5-7, r5-9). What it pins:
##   - a job inside another job is its own line, named as inside it, and
##     the outer job's time leaves it out (the computer's decision held
##     the screen refreshes its moves caused, and the log blamed the
##     computer for the screen's time and counted it twice);
##   - a tool run (anything headless: the Deck Lab, lab_query, the
##     referee, the pack checks) never starts the log — its stdout is a
##     report a program reads — and the log's lines go to stderr, which
##     ArkOS's portmaster.log takes as well as stdout;
##   - a long sleep writes one summary, not one per minute slept;
##   - the marker file is looked for where the game keeps its other
##     files beside it ([method GamePaths.executable_dir]: beside the
##     macOS app, not inside it) and, on the Quest, in the game's files
##     folder, where the log is then written too.

var _made: Array[String] = []


class Catch extends Logger:
	var lines: Array = []    # [message, to stderr]
	func _log_message(message: String, error: bool) -> void:
		if message.begins_with("[perf]"):
			lines.append([message, error])


func after_each() -> void:
	OS.unset_environment(PerfLog.ENV)
	# A log a failing test let start: off again, so no other test sees one.
	for child in get_tree().root.get_children():
		if child is PerfLog:
			get_tree().root.remove_child(child)
			child.free()
	for folder in _made:
		var absolute := ProjectSettings.globalize_path(folder)
		var dir := DirAccess.open(absolute)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
		DirAccess.remove_absolute(absolute)
	_made.clear()


func _scratch() -> String:
	var folder := "user://c2_perf_%d_%d" % [Time.get_ticks_usec(), _made.size()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_made.append(folder)
	return folder


func _log_in(folder: String) -> PerfLog:
	var node := PerfLog.new()
	node.path = folder.path_join("perf.log")
	node.asked_by = "a test"
	add_child_autofree(node)
	return node


func _busy(ms: float) -> void:
	var until := Time.get_ticks_usec() + int(ms * 1000.0)
	while Time.get_ticks_usec() < until:
		pass


func _labels(node: PerfLog) -> Array:
	return node._frame_spans.map(func(s: Array) -> String: return String(s[0]))


# ------------------------------------------------------- nested spans (b1-4) --

func test_a_job_inside_another_is_named_so_and_the_outer_leaves_it_out() -> void:
	var node := _log_in(_scratch())
	var wall_start := Time.get_ticks_usec()
	var outer := PerfLog.now()
	_busy(4.0)
	var inner := PerfLog.now()
	_busy(12.0)
	PerfLog.span("screen refresh", inner)
	_busy(4.0)
	PerfLog.span("computer decision", outer)
	var wall_ms := float(Time.get_ticks_usec() - wall_start) / 1000.0
	var labels := _labels(node)
	assert_eq(labels, ["computer decision", "screen refresh (inside computer decision)"],
		"the refresh is named as inside the decision, after it")
	assert_false(node._run_spans.has("screen refresh"), "no plain refresh: it ran inside the decision")
	var decision: float = node._run_spans.get("computer decision", [0, 0.0, 0.0])[1]
	var refresh: float = node._run_spans.get("screen refresh (inside computer decision)", [0, 0.0, 0.0])[1]
	assert_gte(refresh, 12.0, "the refresh's own time")
	assert_gte(decision, 8.0, "the decision's own time")
	assert_lte(decision + refresh, wall_ms,
		"no millisecond counted twice: decision %.1f + refresh %.1f ms in %.1f ms of wall time" % [decision, refresh, wall_ms])


func test_jobs_side_by_side_are_not_nested() -> void:
	var node := _log_in(_scratch())
	var first := PerfLog.now()
	_busy(2.0)
	PerfLog.span("computer decision", first)
	var second := PerfLog.now()
	_busy(2.0)
	PerfLog.span("screen refresh", second)
	assert_eq(_labels(node), ["computer decision", "screen refresh"])


func test_two_levels_down_each_names_its_own_parent() -> void:
	var node := _log_in(_scratch())
	var a := PerfLog.now()
	var b := PerfLog.now()
	var c := PerfLog.now()
	_busy(3.0)
	PerfLog.span("c", c)
	PerfLog.span("b", b)
	PerfLog.span("a", a)
	assert_eq(_labels(node), ["a", "b (inside a)", "c (inside b)"])


func test_a_job_never_ended_does_not_swallow_the_next_frame() -> void:
	# A caller that asked for the clock and returned before its span: at
	# most its own frame reads the jobs after it as inside it — they still
	# reach the log, at the frame's end — and the next frame is clean.
	var node := _log_in(_scratch())
	var t := node._started_us
	var _forgotten := PerfLog.now()
	var job := PerfLog.now()
	PerfLog.span("screen refresh", job)
	t += 33000
	node._frame(33.0, t)
	assert_true(node._run_spans.has("screen refresh"), str(node._run_spans.keys()))
	var later := PerfLog.now()
	PerfLog.span("computer decision", later)
	assert_eq(_labels(node), ["computer decision"], "the forgotten one is gone with its frame")


func test_a_hitch_line_names_the_job_inside_the_job() -> void:
	var node := _log_in(_scratch())
	var outer := PerfLog.now()
	var inner := PerfLog.now()
	_busy(2.0)
	PerfLog.span("screen refresh", inner)
	PerfLog.span("computer decision", outer)
	node._frame(150.0, node._started_us + 150000)
	var text := FileAccess.get_file_as_string(node.path)
	assert_string_contains(text, "HITCH 150 ms — inside it: computer decision ")
	assert_string_contains(text, "screen refresh (inside computer decision) ")


func _duel() -> DuelScreen:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	return screen


func test_the_computers_decision_leaves_out_the_refreshes_it_caused() -> void:
	var screen := _duel()
	await get_tree().process_frame
	var node := _log_in(_scratch())
	var g: MtgGame = screen.game
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1
	screen.mode = DuelScreen.Mode.NORMAL
	node._frame_spans.clear()
	screen._ai_step()
	var labels := _labels(node)
	var at := labels.find("computer decision")
	assert_gt(at, -1, str(labels))
	assert_eq(labels.slice(0, at).count("screen refresh"), 0,
		"no plain refresh is counted before the decision that held it: %s" % str(labels))
	assert_eq(labels.back(), "screen refresh", "the refresh after the decision is the screen's own: %s" % str(labels))
	for label in labels:
		assert_true(label in ["computer decision", "screen refresh", "screen refresh (inside computer decision)"],
			"an unexpected label %s" % label)


# ------------------------------------------- tool runs and stderr (b1-5/r5-7) --

func test_a_tool_run_never_asks() -> void:
	var none := PackedStringArray()
	assert_true(PerfLog.is_tool_run("headless", none), "headless: the Deck Lab, lab_query, the referee, a test")
	for flag in ["--deck-lab", "--auto-deck", "--lab-query", "--referee", "--verify-pack-1", "--verify-pack-9"]:
		assert_true(PerfLog.is_tool_run("X11", PackedStringArray([flag])), flag)
	assert_false(PerfLog.is_tool_run("X11", none), "the game in a window")
	assert_false(PerfLog.is_tool_run("Wayland", PackedStringArray(["--perf-log"])))


func test_the_environment_variable_does_not_start_it_headless() -> void:
	# The headless run IS this test run: the variable a Steam launch
	# option sets would put [perf] lines into a tool's JSON and rename the
	# game's own perf.log away.
	OS.set_environment(PerfLog.ENV, "1")
	assert_eq(PerfLog.asked(), "", "a headless run never asks")
	PerfLog.start_if_asked(get_tree())
	await get_tree().process_frame
	assert_false(PerfLog.is_active(), "no log started")
	var joined := false
	for child in get_tree().root.get_children():
		joined = joined or child is PerfLog
	assert_false(joined, "no log node joined the tree")


func test_the_lines_go_to_stderr_not_stdout() -> void:
	var catch := Catch.new()
	OS.add_logger(catch)
	var node := _log_in(_scratch())
	node._frame(150.0, node._started_us + 150000)
	OS.remove_logger(catch)
	assert_gt(catch.lines.size(), 3, "the header and the hitch were written")
	for item in catch.lines:
		assert_true(item[1], "on stderr: %s" % String(item[0]).strip_edges())


# ------------------------------------------------------- a long sleep (b1-6) --

func test_a_long_sleep_writes_one_summary() -> void:
	var node := _log_in(_scratch())
	var t := node._started_us
	for i in 30:
		t += 33000
		node._frame(33.0, t)
	t += 10 * 60 * 1000000                 # ten minutes asleep
	node._frame(600000.0, t)
	for i in 12:
		t += 33000
		node._frame(33.0, t)
	var text := FileAccess.get_file_as_string(node.path)
	assert_eq(text.count("SUMMARY (every minute)"), 1, "one summary after the sleep")
	# and the minute after it still writes the next one
	for i in 70:
		t += 1000000
		node._frame(33.0, t)
	text = FileAccess.get_file_as_string(node.path)
	assert_eq(text.count("SUMMARY (every minute)"), 2, "the next minute writes the next summary")


# ------------------------------------------- where the marker is (r5-9) --

func test_the_marker_is_looked_for_beside_the_game_and_in_the_quests_folder() -> void:
	assert_eq(PerfLog.marker_dir("/opt/Shandalar/Shandalar.x86_64", false, ""), "/opt/Shandalar")
	assert_eq(PerfLog.marker_dir("/Applications/Shandalar.app/Contents/MacOS/Shandalar", true, ""),
		"/Applications", "beside the app, like skin/ and cardpacks/")
	assert_eq(PerfLog.marker_dir("/data/app/x/lib/libgodot.so", false, "/sdcard/Android/data/p/files"),
		"/sdcard/Android/data/p/files", "the Quest: the folder adb can reach")
	assert_eq(PerfLog.marker_dir("", false, ""), "", "the editor: nowhere")


func test_a_marker_in_the_quests_folder_asks() -> void:
	var folder := ProjectSettings.globalize_path(_scratch())
	var none := PackedStringArray()
	var looked_in := PerfLog.marker_dir("/data/app/x/lib/libgodot.so", false, folder)
	assert_eq(PerfLog.asked_from("", none, looked_in), "")
	var file := FileAccess.open(folder.path_join("perf-log"), FileAccess.WRITE)
	file.close()
	assert_string_contains(PerfLog.asked_from("", none, looked_in), "perf-log")
	DirAccess.remove_absolute(folder.path_join("perf-log"))


func test_on_the_quest_the_log_is_written_where_adb_can_fetch_it() -> void:
	assert_eq(PerfLog.log_path(""), PerfLog.PATH, "everywhere else: user://logs")
	assert_eq(PerfLog.log_path("/sdcard/Android/data/p/files"), "/sdcard/Android/data/p/files/perf.log")


func test_the_previous_run_is_kept_beside_the_log() -> void:
	var folder := _scratch()
	var first := FileAccess.open(folder.path_join("perf.log"), FileAccess.WRITE)
	first.store_line("GAME RUN")
	first.close()
	var node := PerfLog.new()
	node.path = folder.path_join("perf.log")
	node.asked_by = "a test"
	node.keep_previous = true
	add_child_autofree(node)
	assert_string_contains(FileAccess.get_file_as_string(folder.path_join("perf.previous.log")), "GAME RUN")
	assert_false(FileAccess.get_file_as_string(node.path).contains("GAME RUN"))
