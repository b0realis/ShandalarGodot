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
##     script has to be edited. Delete the file and the next launch is
##     back to normal.
##
## Asked, one node joins the root and measures every main-loop frame (the
## time between two of its own `_process` calls — so a frame the screen
## spent waiting on the computer opponent counts, which a rendering
## counter alone would hide), and the game reports labelled work through
## [method span]: each computer decision (`DuelScreen._ai_step`) and each
## duel screen refresh (`DuelScreen._refresh`). A call is one bool test
## when the log is off.
##
## WHAT IT WRITES — `user://logs/perf.log` (the previous run's kept as
## `perf.previous.log`), every line also on stdout with a `[perf]` prefix,
## which on ArkOS is `portmaster.log` in the game folder:
##
##   - a header: version, system, processor, renderer, screen, window,
##     frame cap, power saver, the handheld the launcher named, and how
##     long the start took before the log began;
##   - a line for each second in which something was slow (a frame over
##     50 ms, or labelled work over 20 ms) — the frames, their average and
##     worst, and what the labelled work cost in that second;
##   - a HITCH line for each frame of 100 ms or more, naming the labelled
##     work that ran inside it;
##   - a SUMMARY every minute and on exit: frame-time percentiles and every
##     label's count, average, worst and total. Written a minute at a time
##     so a run ended by the power button still leaves one.
## The lines are flushed as they are written.

const ENV := "SHANDALAR_PERF_LOG"
const FLAG := "--perf-log"
## The marker's names beside the executable.
const MARKERS: Array[String] = ["perf-log", "perf-log.txt"]
const PATH := "user://logs/perf.log"
const PREVIOUS := "user://logs/perf.previous.log"
## A frame this long is a hitch, and gets a line of its own.
const HITCH_MS := 100.0
## A frame this long makes its second worth a line.
const SLOW_MS := 50.0
## Labelled work this long makes its second worth a line.
const SLOW_SPAN_MS := 20.0
## Frame times are kept as a millisecond histogram up to this, the rest
## in the last bucket — percentiles without keeping every frame.
const HISTOGRAM_MS := 2000
const SUMMARY_EVERY_S := 60.0

static var _active: PerfLog = null

## Where this run's lines go; a test points it elsewhere before adding the
## node to the tree.
var path := PATH
## How this launch asked (for the header).
var asked_by := ""

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


## Does THIS launch ask for the log? "" when not; otherwise the way it
## asked, for the header.
static func asked() -> String:
	return asked_from(OS.get_environment(ENV), OS.get_cmdline_user_args(),
		"" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir())


## [method asked] on its inputs, for the tests.
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
	tree.root.add_child.call_deferred(node)


## A clock reading for [method span]; 0 when the log is off, so a caller
## pays one test and no clock.
static func now() -> int:
	return Time.get_ticks_usec() if _active != null else 0


## Labelled work that began at [param started_us] ([method now]) has ended.
static func span(label: String, started_us: int) -> void:
	if _active == null or started_us == 0:
		return
	_active._record(label, float(Time.get_ticks_usec() - started_us) / 1000.0)


static func is_active() -> bool:
	return _active != null


func _enter_tree() -> void:
	name = "PerfLog"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Last of the root's children, so each frame is measured after
	# everything else in it has run.
	process_priority = 1000000
	_active = self
	_histogram.resize(HISTOGRAM_MS + 1)
	_histogram.fill(0)
	_open()
	_started_us = Time.get_ticks_usec()
	_last_us = _started_us
	for line in header():
		_say(line)


func _exit_tree() -> void:
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
	if ms >= SLOW_MS:
		_sec_slow += 1
	if ms >= HITCH_MS:
		_hitches += 1
		_sec_hitches += 1
		var inside := PackedStringArray()
		for item in _frame_spans:
			inside.append("%s %.0f ms" % [item[0], item[1]])
		_say("[%6.1fs] HITCH %.0f ms%s" % [float(now_us - _started_us) / 1000000.0, ms,
			(" — inside it: " + ", ".join(inside)) if not inside.is_empty() else " — no labelled work inside it (drawing, loading or the system)"])
	_frame_spans.clear()
	if float(now_us - _started_us) / 1000000.0 >= _next_summary_s:
		_next_summary_s += SUMMARY_EVERY_S
		_summary("SUMMARY (every minute)")


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
		var parts := PackedStringArray(["[%5ds] frames %d  avg %.1f ms  worst %.0f ms  >%dms %d  >%dms %d"
			% [_second, _sec_frames, _sec_sum_ms / _sec_frames, _sec_worst_ms,
			int(SLOW_MS), _sec_slow, int(HITCH_MS), _sec_hitches]])
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
	_say("%s after %.0f s: %d frames, frame ms p50 %d / p95 %d / p99 %d / worst %.0f, %d hitches of %d ms or more"
		% [title, float(Time.get_ticks_usec() - _started_us) / 1000000.0, _frames,
		percentile(0.50), percentile(0.95), percentile(0.99), _worst_ms, _hitches, int(HITCH_MS)])
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
	lines.append("A line per second with a frame over %d ms or labelled work over %d ms; HITCH = one frame of %d ms or more."
		% [int(SLOW_MS), int(SLOW_SPAN_MS), int(HITCH_MS)])
	return lines


func _open() -> void:
	var folder := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if path == PATH and FileAccess.file_exists(PATH):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH),
			ProjectSettings.globalize_path(PREVIOUS))
	_file = FileAccess.open(path, FileAccess.WRITE)


func _say(line: String) -> void:
	print("[perf] " + line)
	if _file != null:
		_file.store_line(line)
		_file.flush()
