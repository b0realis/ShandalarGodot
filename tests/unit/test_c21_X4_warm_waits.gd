extends GutTest
## THE WARMERS' THREADS AND THE CARD ART THEY KEEP, the bug campaign of
## 0.50.66 (fixer X4):
##  - h1-3 a warmer let go never waits on a task that has not started — on
##    a machine whose engine runs one low-priority task at a time it waited
##    for every warm-up queued ahead of it ([method SkinWarmer.release]);
##    as the game closes every job is told to stop before any is waited
##    for ([method SkinWarmer._reclaim_all]); the card art's warmer lives
##    under the root;
##  - h1-2 the stakes warmed ahead have a budget of their own, apart from
##    the pictures on show ([constant GameSkin.ART_AHEAD_CAP]), and only
##    the nearest creatures' are warmed.
## The queue is filled with blockers the test holds (one per core, more
## than the engine's low-priority threads), so a warm-up's task is
## certainly waiting behind them; each blocker gives up on its own after
## [constant HOLD_MS], so a wait the fix removed shows as that long a call
## instead of a hang.

const FOLDER := "user://c21_x4_warm_waits"
const HOLD_MS := 1500
## A call that does not wait behind the blockers returns well inside this.
const QUICK_MS := 300


## What a blocker holds on: the test opens it.
class Gate extends RefCounted:
	var open := false
	var running := 0
	var lock := Mutex.new()

	func hold() -> void:
		lock.lock()
		running += 1
		lock.unlock()
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < HOLD_MS:
			lock.lock()
			var done := open
			lock.unlock()
			if done:
				return
			OS.delay_msec(1)


## A job as a warmer's is: `lock`, `stop`, `started` — its run waits for
## `stop` (or gives up after [constant HOLD_MS]).
class Endless extends RefCounted:
	var stop := false
	var started := false
	var lock := Mutex.new()
	var ran := false

	func run() -> void:
		lock.lock()
		started = true
		lock.unlock()
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < HOLD_MS:
			lock.lock()
			var stopped := stop
			lock.unlock()
			if stopped:
				return
			OS.delay_msec(1)
		ran = true


var holder: Node
var gate: Gate
var blockers: Array[int] = []
var _names: Array[String] = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	holder = Node.new()
	add_child_autofree(holder)
	gate = Gate.new()
	blockers = []
	_names = []


func after_each() -> void:
	_open_gate()
	SkinWarmer.forced = -1
	MusicPlayer.threaded = -1
	for card_name in _names:
		var key := "cardart/" + GameSkin._snake(card_name)
		GameSkin._art_cache.erase(key)
		GameSkin._art_ahead.erase(key)
		GameSkin._art_missing.erase(key)
	for file_name in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER.path_join(file_name))
	DirAccess.remove_absolute(FOLDER)
	for i in 3:
		await get_tree().process_frame


## Every low-priority thread taken by a blocker, and more queued behind.
func _fill_the_queue() -> void:
	for i in maxi(OS.get_processor_count(), 2):
		blockers.append(WorkerThreadPool.add_task(gate.hold, false, "c21 X4 blocker"))
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 500:
		gate.lock.lock()
		var running := gate.running
		gate.lock.unlock()
		if running > 0:
			break
		OS.delay_msec(1)


func _open_gate() -> void:
	gate.lock.lock()
	gate.open = true
	gate.lock.unlock()
	for task in blockers:
		WorkerThreadPool.wait_for_task_completion(task)
	blockers = []


func _picture(card_name: String) -> String:
	var image := Image.create(32, 24, false, Image.FORMAT_RGB8)
	image.fill(Color(0.2, 0.5, 0.3))
	var path := ProjectSettings.globalize_path(FOLDER.path_join(GameSkin._snake(card_name) + ".png"))
	image.save_png(path)
	_names.append(card_name)
	return path


func _job(count: int, prefix: String, ahead := false) -> CardArtWarmer.Job:
	var job := CardArtWarmer.Job.new()
	job.ahead = ahead
	for i in count:
		var card_name := "%s %d" % [prefix, i]
		job.paths.append(_picture(card_name))
		job.skin_names.append(card_name)
	job.images.resize(job.paths.size())
	return job


func _until_reclaimed() -> void:
	for i in 200:
		if SkinWarmer.unclaimed() == 0:
			return
		await get_tree().process_frame


# ------------------------------------------- h1-3: never wait behind --

func test_a_card_art_warmer_let_go_waits_for_no_warm_up_ahead_of_it() -> void:
	_fill_the_queue()
	var job := _job(3, "X4 Queued Art")
	var warmer := CardArtWarmer._start(holder, job)
	assert_not_null(warmer)
	var before := SkinWarmer.unclaimed()
	var start := Time.get_ticks_msec()
	warmer._finish()                  # a screen left, the registry rebuilt…
	var took := Time.get_ticks_msec() - start
	assert_lt(took, QUICK_MS, "let go at once, not after the blockers (%d ms)" % took)
	assert_true(job.stop, "told to stop")
	assert_false(job.started, "its task had not started")
	assert_eq(SkinWarmer.unclaimed(), before + 1, "held until its task has run")
	_open_gate()
	await _until_reclaimed()
	assert_eq(SkinWarmer.unclaimed(), 0, "reclaimed once it ran")
	assert_eq(job.done, 0, "and it decoded nothing: it saw stop first")


func test_the_card_art_warmer_lives_under_the_root() -> void:
	var warmer := CardArtWarmer._start(holder, _job(2, "X4 Rooted Art"))
	assert_not_null(warmer)
	await get_tree().process_frame
	if is_instance_valid(warmer) and warmer.is_inside_tree():
		assert_eq(warmer.get_parent(), get_tree().root, "the caches', not a screen's")
	assert_eq(holder.get_child_count(), 0, "nothing under the asker")
	for i in 300:
		if not is_instance_valid(warmer) or warmer.finished():
			break
		await get_tree().process_frame
	assert_true(GameSkin.card_art_known("X4 Rooted Art 0"))


func test_a_skin_warmer_leaving_waits_for_no_warm_up_ahead_of_it() -> void:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var path := ProjectSettings.globalize_path(FOLDER.path_join("zz_x4_sheet.png"))
	image.save_png(path)
	SkinWarmer.forced = 1
	_fill_the_queue()
	var job := SkinWarmer.Job.new()
	job.entries = [{"kind": "picture", "key": "zz_x4_sheet", "path": path}] as Array[Dictionary]
	var warmer := SkinWarmer.new()
	warmer._job = job
	warmer._task = SkinWarmer.track(job, WorkerThreadPool.add_task(job.run, false, "c21 X4 skin"))
	var start := Time.get_ticks_msec()
	warmer._exit_tree()               # as the tree tells it on the way out
	var took := Time.get_ticks_msec() - start
	assert_lt(took, QUICK_MS, "no wait behind the blockers (%d ms)" % took)
	assert_true(job.stop)
	_open_gate()
	await _until_reclaimed()
	assert_eq(SkinWarmer.unclaimed(), 0)
	assert_eq(job.done, 0)
	warmer.free()


func test_the_music_window_dropped_waits_for_no_warm_up_ahead_of_it() -> void:
	MusicPlayer.threaded = 1
	_fill_the_queue()
	var player := MusicPlayer.new()
	add_child_autofree(player)
	var window := MusicPlayer.TuneWindow.new()
	window.jobs = [{"path": "zz_x4_none.wav"}] as Array[Dictionary]
	player._window = window
	player._window_key = "music_duel"
	player._task = SkinWarmer.track(window, WorkerThreadPool.add_task(window.run, false, "c21 X4 music"))
	var start := Time.get_ticks_msec()
	player.stop_music()
	var took := Time.get_ticks_msec() - start
	assert_lt(took, QUICK_MS, "stopped at once (%d ms)" % took)
	assert_false(player.window_pending())
	assert_true(window.stop)
	_open_gate()
	await _until_reclaimed()
	assert_eq(window.done, 0, "no tune decoded after the stop")


func test_a_started_task_is_waited_for_and_ends_after_the_one_in_hand() -> void:
	var job := Endless.new()
	var task := SkinWarmer.track(job, WorkerThreadPool.add_task(job.run, false, "c21 X4 endless"))
	var start := Time.get_ticks_msec()
	while not job.started and Time.get_ticks_msec() - start < 1000:
		OS.delay_msec(1)
	assert_true(job.started)
	start = Time.get_ticks_msec()
	assert_true(SkinWarmer.release(job, task), "a started task is waited for")
	assert_lt(Time.get_ticks_msec() - start, QUICK_MS, "and it stops at once")
	assert_false(job.ran, "it saw stop, it did not run on")


func test_as_the_game_closes_every_job_is_told_to_stop_first() -> void:
	var jobs: Array[Endless] = []
	for i in 3:
		var job := Endless.new()
		SkinWarmer.track(job, WorkerThreadPool.add_task(job.run, false, "c21 X4 closing"))
		jobs.append(job)
	var start := Time.get_ticks_msec()
	SkinWarmer._reclaim_all()        # the root leaving the tree
	var took := Time.get_ticks_msec() - start
	assert_lt(took, QUICK_MS, "no job ran on while another was waited for (%d ms)" % took)
	for job in jobs:
		assert_true(job.stop)
		assert_false(job.ran)
	assert_eq(SkinWarmer.unclaimed(), 0)
	assert_true(SkinWarmer._at_work.is_empty(), "every task claimed")


# ------------------------------------- h1-2: the stakes' own budget --

func _art(color: Color) -> Image:
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(color)
	return image


func test_a_picture_warmed_ahead_is_kept_apart_until_a_card_asks() -> void:
	var card := "X4 Ahead Stake"
	_names.append(card)
	var key := "cardart/" + GameSkin._snake(card)
	var warmed := GameSkin.keep_card_art(card, _art(Color.RED), true)
	assert_false(GameSkin._art_cache.has(key), "not among the pictures on show")
	assert_true(GameSkin._art_ahead.has(key))
	assert_true(GameSkin.card_art_known(card), "known: no file read for it again")
	assert_same(GameSkin.card_art(card), warmed, "the card gets the texture warmed")
	assert_true(GameSkin._art_cache.has(key), "shown now, so kept as shown")
	assert_false(GameSkin._art_ahead.has(key))


func test_the_pictures_warmed_ahead_never_push_a_shown_one_out() -> void:
	var shown: Array[String] = []
	for i in GameSkin.ART_CACHE_CAP:
		var card := "X4 Shown %d" % i
		_names.append(card)
		shown.append(card)
		GameSkin.keep_card_art(card, _art(Color.BLUE))
	for i in GameSkin.ART_AHEAD_CAP + 8:
		var card := "X4 Warmed %d" % i
		_names.append(card)
		GameSkin.keep_card_art(card, _art(Color.GREEN), true)
	for card in shown:
		assert_true(GameSkin._art_cache.has("cardart/" + GameSkin._snake(card)),
			"%s still kept" % card)
	assert_eq(GameSkin._art_ahead.size(), GameSkin.ART_AHEAD_CAP, "a budget of its own")
	assert_false(GameSkin._art_ahead.has("cardart/" + GameSkin._snake("X4 Warmed 0")),
		"the oldest warmed goes first")
	assert_true(GameSkin._art_ahead.has("cardart/" + GameSkin._snake("X4 Warmed %d" % (GameSkin.ART_AHEAD_CAP + 7))))


func test_the_stakes_warmer_keeps_its_pictures_ahead() -> void:
	var job := _job(3, "X4 Stake Art", true)
	var warmer := CardArtWarmer._start(holder, job)
	for i in 300:
		if not is_instance_valid(warmer) or warmer.finished():
			break
		await get_tree().process_frame
	for i in 3:
		var key := "cardart/" + GameSkin._snake("X4 Stake Art %d" % i)
		assert_true(GameSkin._art_ahead.has(key), "warmed ahead: %s" % key)
		assert_false(GameSkin._art_cache.has(key), "not among the shown")


func test_a_warm_ahead_asks_for_the_skins_pictures_alone() -> void:
	var names: Array[String] = ["Shivan Dragon", "Serra Angel"]
	assert_true(CardArtWarmer._job_for(names, true).ahead)
	assert_false(CardArtWarmer._job_for(names).ahead)
	for skin_name in CardArtWarmer._job_for(names, true).skin_names:
		assert_ne(skin_name, "", "a pack's picture is left to be decoded when asked")


func test_only_the_nearest_creatures_stakes_are_warmed() -> void:
	var near: Array[Array] = [[300, 5], [100, 7], [200, 7], [150, 9], [120, 4]]
	assert_eq(WorldSoundscape.nearest_rows(near, 2), [7, 4] as Array[int])
	assert_eq(WorldSoundscape.nearest_rows(near, 9), [7, 4, 9, 5] as Array[int], "each row once")
	assert_eq(WorldSoundscape.nearest_rows([] as Array[Array], 2), [] as Array[int])
	assert_true(WorldSoundscape.STAKES_WARMED * 16 <= GameSkin.ART_AHEAD_CAP,
		"the budget holds the nearest creatures' stakes")
