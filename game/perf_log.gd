class_name PerfLog
extends Node
## THE TIMING LOG — opt-in, for a tester whose game stutters (the R36
## Ultra tester on ArkOS, 2026-10-08: *"it works, albeit with a bit of
## stuttering"*). Nothing in the game timed itself, so a report said THAT
## it stuttered and never WHY: the drawing, a screen refresh, or the
## computer opponent thinking on the thread that draws the screen.
##
## OFF UNLESS ASKED, EVERY LAUNCH. Nothing is built, nothing processes
## and nothing is written unless THIS launch asks for it ([method asked]):
##
##   - the environment variable `SHANDALAR_PERF_LOG=1` (a Steam launch
##     option: `SHANDALAR_PERF_LOG=1 %command%`);
##   - `--perf-log` after `--` on the command line
##     (`Shandalar.x86_64 -- --perf-log`);
##   - an empty file named `perf-log` (or `perf-log.txt`) beside the
##     executable — on ArkOS the `shandalar/` folder in `ports/`, where no
##     script has to be edited; on a Mac beside `Shandalar.app`, where
##     `skin/` and `cardpacks/` go ([method GamePaths.executable_dir]); on
##     the Meta Quest in the game's files folder
##     ([method GamePaths.android_files_dir]), the one place adb reaches.
##     Delete the file and the next launch is back to normal.
##
## NEVER IN A TOOL RUN (2026-10-12). The Deck Lab, `lab_query`, the
## referee, the auto-deck builder and the pack checks are this same
## executable, run headless, and their stdout is a report a program reads:
## a marker left in the release folder or the variable left set put
## `[perf]` lines into their JSON, and each run renamed the game's own
## `perf.log` away. A headless run, or one with a tool's flag, never
## starts the log ([method is_tool_run]); there is nothing on a screen to
## time in one anyway.
##
## Asked, one node joins the root and measures every main-loop frame (the
## time between two of its own `_process` calls — so a frame the screen
## spent waiting on the computer opponent counts, which a rendering
## counter alone would hide), and the game reports labelled work through
## [method now] and [method span]: each computer decision
## (`DuelScreen._ai_step`) and each duel screen refresh
## (`DuelScreen._refresh`). A call is one bool test when the log is off.
##
## A JOB INSIDE A JOB (2026-10-12). Labelled work can run inside other
## labelled work — a screen refresh the computer's move set off, inside
## the computer's decision. Each job then counts its OWN time: the inner
## one is its own row, named `screen refresh (inside computer decision)`,
## and the outer one's time leaves it out, so no millisecond is blamed on
## two jobs or counted twice in a summary. [method now] opens a job and
## [method span] closes it; a job never closed is dropped at the end of
## its frame.
##
## WHAT IT WRITES — `user://logs/perf.log` (on the Quest `perf.log` in the
## game's files folder, for `adb pull`; the previous run's kept as
## `perf.previous.log`), every line also on stderr with a `[perf]` prefix,
## which on ArkOS is `portmaster.log` in the game folder and on the Quest
## the system log (`adb logcat`):
##
##   - a header: version, system, processor, renderer, screen, window,
##     frame cap, power saver, the handheld the launcher named, and how
##     long the start took before the log began;
##   - a line for each second in which something was slow (a frame of
##     twice the screen's refresh period or more, or labelled work over
##     20 ms) — the frames, their average and worst, and what the labelled
##     work cost in that second;
##   - a HITCH line for each frame of four refresh periods or more, naming
##     the labelled work that ran inside it;
##   - a SUMMARY every minute and on exit: frame-time percentiles and every
##     label's count, average, worst and total. Written a minute at a time
##     so a run ended by the power button still leaves one.
## The lines are flushed as they are written.
##
## THE THRESHOLDS FOLLOW THE SCREEN (the smoothness pass, 0.50.66; the
## owner, 2026-10-29: *"silky butter smooth and high fps if needed"*).
## Until then a frame was slow at 50 ms and a hitch at 100 — and the walk's
## hitches, a tune or a sheet read on the thread that draws, were 15-60 ms:
## a player's log showed none of them. Now a frame is SLOW at [constant
## SLOW_PERIODS] of the screen's refresh period ([method frame_period_ms]:
## the screen's rate, or the frame cap when that is lower; 60 Hz when
## neither is known) — 33 ms at 60 Hz, 14 at 144 — and a HITCH at
## [constant HITCH_PERIODS] — 67 ms at 60 Hz, 28 at 144; never later than
## the old 50 and 100 ([method slow_for], [method hitch_for]). The header
## says which, and the summary every minute looks at the screen again (a
## frame cap changed in the Options).

const ENV := "SHANDALAR_PERF_LOG"
const FLAG := "--perf-log"
## The marker's names beside the executable.
const MARKERS: Array[String] = ["perf-log", "perf-log.txt"]
const PATH := "user://logs/perf.log"
const PREVIOUS := "user://logs/perf.previous.log"
## A frame this long is a hitch, and gets a line of its own — at the most
## ([method hitch_for]: [constant HITCH_PERIODS] refresh periods, sooner).
const HITCH_MS := 100.0
## A frame this long makes its second worth a line — at the most ([method
## slow_for]: [constant SLOW_PERIODS] refresh periods, sooner).
const SLOW_MS := 50.0
## A frame of this many refresh periods is slow, of this many a hitch.
const SLOW_PERIODS := 2.0
const HITCH_PERIODS := 4.0
## The refresh rate taken when the screen gives none.
const FALLBACK_HZ := 60.0
## Labelled work this long makes its second worth a line.
const SLOW_SPAN_MS := 20.0
## Frame times are kept as a millisecond histogram up to this, the rest
## in the last bucket — percentiles without keeping every frame.
const HISTOGRAM_MS := 2000
const SUMMARY_EVERY_S := 60.0
## The flags that make this executable a tool rather than the game
## (`game/main.gd`): the Deck Lab, the auto-deck builder, lab_query, the
## referee; and every `--verify-pack-N` ([constant TOOL_FLAG_PREFIX]).
const TOOL_FLAGS: Array[String] = ["--deck-lab", "--auto-deck", "--lab-query", "--referee"]
const TOOL_FLAG_PREFIX := "--verify-pack-"

static var _active: PerfLog = null

## Where this run's lines go; a test points it elsewhere before adding the
## node to the tree.
var path := PATH
## Rename a log already at [member path] to `perf.previous.log` before
## writing: the launch's own log does, a test's scratch one does not.
var keep_previous := false
## How this launch asked (for the header).
var asked_by := ""
## The refresh period the thresholds are taken from, in ms; 0 (the game's)
## is the screen's ([method frame_period_ms]), looked at again each
## summary. A test sets its own before adding the node to the tree.
var period_ms := 0.0
## This run's thresholds ([method slow_for], [method hitch_for]).
var slow_ms := SLOW_MS
var hitch_ms := HITCH_MS
## The refresh period they were taken from, in ms (for the header).
var _period_now := 1000.0 / FALLBACK_HZ

var _file: FileAccess = null
var _started_us := 0
var _last_us := 0
var _frames := 0
var _histogram := PackedInt32Array()
var _hitches := 0
var _worst_ms := 0.0
var _next_summary_s := SUMMARY_EVERY_S
# The second being gathered.
var _second := 0
var _sec_frames := 0
var _sec_sum_ms := 0.0
var _sec_worst_ms := 0.0
var _sec_slow := 0
var _sec_hitches := 0
var _sec_spans := {}        # label -> [count, total_ms, worst_ms]
# The labelled work since the last frame (named by a HITCH line).
var _frame_spans: Array = []  # [label, ms]
# The whole run: label -> [count, total_ms, worst_ms]
var _run_spans := {}
# The jobs opened with [method now] and not yet closed, innermost last.
var _open_jobs := PackedInt64Array()
# Jobs closed inside one still open, waiting for its label:
# [started_us, label, own_ms, total_ms, children (the same shape)].
var _held_jobs: Array = []


## Does THIS launch ask for the log? "" when not, and always "" in a tool
## run ([method is_tool_run]); otherwise the way it asked, for the header.
static func asked() -> String:
	if is_tool_run(DisplayServer.get_name(), OS.get_cmdline_user_args()):
		return ""
	return asked_from(OS.get_environment(ENV), OS.get_cmdline_user_args(),
		marker_dir("" if OS.has_feature("editor") else OS.get_executable_path(),
			OS.has_feature("macos"), GamePaths.android_files_dir()))


## Whether this run is a tool's, not the game's: headless (the Deck Lab,
## lab_query, the referee, the auto-deck builder and the test suite all
## run so), or with a tool's flag after `--`.
static func is_tool_run(display_server: String, user_args: PackedStringArray) -> bool:
	if display_server == "headless":
		return true
	for arg in user_args:
		if arg in TOOL_FLAGS or arg.begins_with(TOOL_FLAG_PREFIX):
			return true
	return false


## The folder a marker file is looked for in: beside the game, the way
## its other files are ([method GamePaths.executable_dir] — beside a
## macOS app, not inside it), or on Android the game's files folder
## ([param files_dir]), the one place adb can put a file. "" for an
## editor run ([param executable] "").
static func marker_dir(executable: String, macos: bool, files_dir: String) -> String:
	if files_dir != "":
		return files_dir
	return "" if executable == "" else GamePaths.executable_dir(executable, macos)


## Where this launch's log is written: `user://logs/perf.log`, or on
## Android `perf.log` in the game's files folder ([param files_dir]),
## where `adb pull` fetches it — `user://` is private there.
static func log_path(files_dir: String) -> String:
	return PATH if files_dir == "" else files_dir.path_join("perf.log")


## [method asked] on its inputs, for the tests: the environment value,
## the user args and the folder a marker is looked for in
## ([method marker_dir]; "" for none).
static func asked_from(env_value: String, user_args: PackedStringArray, executable_dir: String) -> String:
	if env_value.strip_edges().to_lower() in ["1", "on", "yes", "true"]:
		return "environment %s=%s" % [ENV, env_value.strip_edges()]
	if user_args.has(FLAG):
		return "command line %s" % FLAG
	if executable_dir != "":
		for marker in MARKERS:
			if FileAccess.file_exists(executable_dir.path_join(marker)):
				return "marker file %s" % executable_dir.path_join(marker)
	return ""


## The process-start hook ([code]Lifecycle._ready[/code]): the log joins
## the root if this launch asked for it, and nothing happens otherwise.
static func start_if_asked(tree: SceneTree) -> void:
	if _active != null:
		return
	var how := asked()
	if how == "":
		return
	var node := PerfLog.new()
	node.asked_by = how
	node.path = log_path(GamePaths.android_files_dir())
	node.keep_previous = true
	tree.root.add_child.call_deferred(node)


## A clock reading for [method span], which opens a job: every job
## opened after it and closed before its [method span] is inside it. 0
## when the log is off, so a caller pays one test and no clock.
static func now() -> int:
	if _active == null:
		return 0
	var started := Time.get_ticks_usec()
	_active._open_jobs.append(started)
	return started


## Labelled work that began at [param started_us] ([method now]) has ended.
static func span(label: String, started_us: int) -> void:
	if _active == null or started_us == 0:
		return
	_active._close_job(label, started_us, Time.get_ticks_usec())


static func is_active() -> bool:
	return _active != null


## THE PERIOD A FRAME SHOULD TAKE, in ms: the screen's refresh
## ([param refresh_hz], what V-Sync waits for), or the frame cap
## [param max_fps] when that is lower (0: no cap); [constant FALLBACK_HZ]
## when the screen gives no rate.
static func frame_period_ms(refresh_hz: float, max_fps: int) -> float:
	var hz := refresh_hz if refresh_hz > 0.0 else FALLBACK_HZ
	if max_fps > 0:
		hz = minf(hz, float(max_fps))
	return 1000.0 / hz


## A frame of this many ms or more is slow, at [param period] ms a
## refresh: [constant SLOW_PERIODS] periods, [constant SLOW_MS] at most.
static func slow_for(period: float) -> float:
	return minf(SLOW_MS, SLOW_PERIODS * period)


## A frame of this many ms or more is a hitch: [constant HITCH_PERIODS]
## periods, [constant HITCH_MS] at most.
static func hitch_for(period: float) -> float:
	return minf(HITCH_MS, HITCH_PERIODS * period)


## The thresholds from [member period_ms], or from the screen as it is now.
func _take_thresholds() -> void:
	var period := period_ms
	if period <= 0.0:
		var hz := DisplayServer.screen_get_refresh_rate() if DisplayServer.get_name() != "headless" else -1.0
		period = frame_period_ms(hz, Engine.max_fps)
	_period_now = period
	slow_ms = slow_for(period)
	hitch_ms = hitch_for(period)


func _enter_tree() -> void:
	name = "PerfLog"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Last of the root's children, so each frame is measured after
	# everything else in it has run.
	process_priority = 1000000
	_active = self
	_histogram.resize(HISTOGRAM_MS + 1)
	_histogram.fill(0)
	_take_thresholds()
	_open()
	_started_us = Time.get_ticks_usec()
	_last_us = _started_us
	for line in header():
		_say(line)


func _exit_tree() -> void:
	_flush_jobs()
	_close_second()
	_summary("SUMMARY (exit)")
	if _file != null:
		_file.close()
		_file = null
	if _active == self:
		_active = null


func _process(_delta: float) -> void:
	var now_us := Time.get_ticks_usec()
	_frame(float(now_us - _last_us) / 1000.0, now_us)
	_last_us = now_us


## One main-loop frame of [param ms], ending at [param now_us]. The test
## seam: a test feeds frames here without a real clock.
func _frame(ms: float, now_us: int) -> void:
	_flush_jobs()
	var second := int(float(now_us - _started_us) / 1000000.0)
	if second != _second:
		_close_second()
		_second = second
	_frames += 1
	_histogram[clampi(int(ms), 0, HISTOGRAM_MS)] += 1
	_worst_ms = maxf(_worst_ms, ms)
	_sec_frames += 1
	_sec_sum_ms += ms
	_sec_worst_ms = maxf(_sec_worst_ms, ms)
	if ms >= slow_ms:
		_sec_slow += 1
	if ms >= hitch_ms:
		_hitches += 1
		_sec_hitches += 1
		var inside := PackedStringArray()
		for item in _frame_spans:
			inside.append("%s %.0f ms" % [item[0], item[1]])
		_say("[%6.1fs] HITCH %.0f ms%s" % [float(now_us - _started_us) / 1000000.0, ms,
			(" — inside it: " + ", ".join(inside)) if not inside.is_empty() else " — no labelled work inside it (drawing, loading or the system)"])
	_frame_spans.clear()
	var elapsed_s := float(now_us - _started_us) / 1000000.0
	if elapsed_s >= _next_summary_s:
		# Past the elapsed time in one step: a frame that came back from a
		# ten-minute sleep is one summary, not one per minute slept.
		_next_summary_s = (floorf(elapsed_s / SUMMARY_EVERY_S) + 1.0) * SUMMARY_EVERY_S
		_summary("SUMMARY (every minute)")
		_take_thresholds()


## A job opened at [param started_us] has closed at [param ended_us]: its
## own time is its length less the jobs closed inside it. With no job
## still open around it, it and the jobs inside it are recorded now;
## otherwise it waits for the job around it, whose label it is named by.
func _close_job(label: String, started_us: int, ended_us: int) -> void:
	var total_ms := float(ended_us - started_us) / 1000.0
	var at := -1
	for i in range(_open_jobs.size() - 1, -1, -1):
		if _open_jobs[i] == started_us:
			at = i
			break
	if at == -1:      # opened before this log began
		_record(label, total_ms)
		return
	_open_jobs.resize(at)    # and any opened inside it and never closed
	var children: Array = []
	var waiting: Array = []
	var inner_ms := 0.0
	for held in _held_jobs:
		if int(held[0]) >= started_us:
			children.append(held)
			inner_ms += float(held[3])
		else:
			waiting.append(held)
	var job := [started_us, label, maxf(total_ms - inner_ms, 0.0), total_ms, children]
	if _open_jobs.is_empty():
		_held_jobs = waiting
		_commit_job(job, "")
	else:
		waiting.append(job)
		_held_jobs = waiting


## [param job] and the jobs inside it into the tables, each inner one
## named by the job around it.
func _commit_job(job: Array, around: String) -> void:
	var label := String(job[1])
	_record(label if around == "" else "%s (inside %s)" % [label, around], float(job[2]))
	for child in job[4]:
		_commit_job(child, label)


## The end of a frame: a job opened and never closed is dropped, and the
## jobs that were waiting for it are recorded as they stand.
func _flush_jobs() -> void:
	_open_jobs.clear()
	var held := _held_jobs
	_held_jobs = []
	for job in held:
		_commit_job(job, "")


func _record(label: String, ms: float) -> void:
	_frame_spans.append([label, ms])
	for table in [_sec_spans, _run_spans]:
		var row: Array = table.get(label, [0, 0.0, 0.0])
		row[0] = int(row[0]) + 1
		row[1] = float(row[1]) + ms
		row[2] = maxf(float(row[2]), ms)
		table[label] = row


## The second just gathered, as a line if anything in it was slow.
func _close_second() -> void:
	var slow_work := false
	for label in _sec_spans:
		if float(_sec_spans[label][2]) >= SLOW_SPAN_MS:
			slow_work = true
	if _sec_frames > 0 and (_sec_slow > 0 or slow_work):
		var parts := PackedStringArray(["[%5ds] frames %d  avg %.1f ms  worst %.0f ms  >%.0fms %d  >%.0fms %d"
			% [_second, _sec_frames, _sec_sum_ms / _sec_frames, _sec_worst_ms,
			slow_ms, _sec_slow, hitch_ms, _sec_hitches]])
		for label in _sec_spans:
			var row: Array = _sec_spans[label]
			parts.append("%s %d× avg %.1f ms worst %.0f ms" % [label, row[0], float(row[1]) / int(row[0]), row[2]])
		_say(" | ".join(parts))
	_sec_frames = 0
	_sec_sum_ms = 0.0
	_sec_worst_ms = 0.0
	_sec_slow = 0
	_sec_hitches = 0
	_sec_spans.clear()


func _summary(title: String) -> void:
	_say("%s after %.0f s: %d frames, frame ms p50 %d / p95 %d / p99 %d / worst %.0f, %d hitches of %.0f ms or more"
		% [title, float(Time.get_ticks_usec() - _started_us) / 1000000.0, _frames,
		percentile(0.50), percentile(0.95), percentile(0.99), _worst_ms, _hitches, hitch_ms])
	for label in _run_spans:
		var row: Array = _run_spans[label]
		_say("  %s: %d×, avg %.1f ms, worst %.0f ms, total %.1f s"
			% [label, row[0], float(row[1]) / int(row[0]), row[2], float(row[1]) / 1000.0])


## The frame time below which [param fraction] of the frames fell, in
## whole milliseconds.
func percentile(fraction: float) -> int:
	if _frames == 0:
		return 0
	var wanted := int(ceil(fraction * _frames))
	var seen := 0
	for ms in _histogram.size():
		seen += _histogram[ms]
		if seen >= wanted:
			return ms
	return HISTOGRAM_MS


func header() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Shandalar %s timing log, %s (asked by %s)" % [
		String(ProjectSettings.get_setting("application/config/version", "dev")),
		Time.get_datetime_string_from_system(), asked_by])
	lines.append("system: %s %s; processor: %s, %d threads" % [OS.get_name(),
		OS.get_version(), OS.get_processor_name(), OS.get_processor_count()])
	lines.append("renderer: %s (%s), %s" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version()])
	var window := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	lines.append("screen %s, window %s; frame cap %s; power saver %s; handheld %s" % [
		DisplayServer.screen_get_size(), window,
		"none" if Engine.max_fps == 0 else str(Engine.max_fps),
		"on" if OS.low_processor_usage_mode else "off",
		Settings.handheld() if Settings.handheld() != "" else "none"])
	lines.append("the log began %.1f s after the process started (the skin, the card packs, the title screen)"
		% (float(Time.get_ticks_msec()) / 1000.0))
	lines.append("file: %s" % ProjectSettings.globalize_path(path))
	lines.append(("A line per second with a frame of %.1f ms or more or labelled work over %d ms; HITCH = one frame"
		+ " of %.1f ms or more (the screen's refresh period %.1f ms: %.0f and %.0f of them, at most %d and %d ms).")
		% [slow_ms, int(SLOW_SPAN_MS), hitch_ms, _period_now, SLOW_PERIODS, HITCH_PERIODS, int(SLOW_MS), int(HITCH_MS)])
	lines.append("Each job counts its own time: work done inside another job is its own row, \"(inside …)\".")
	return lines


func _open() -> void:
	var folder := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if keep_previous and FileAccess.file_exists(path):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(folder.path_join(PREVIOUS.get_file())))
	_file = FileAccess.open(path, FileAccess.WRITE)


## A line to the file and to stderr: never stdout, which a tool's report
## owns (ArkOS's launcher sends both to portmaster.log).
func _say(line: String) -> void:
	printerr("[perf] " + line)
	if _file != null:
		_file.store_line(line)
		_file.flush()
