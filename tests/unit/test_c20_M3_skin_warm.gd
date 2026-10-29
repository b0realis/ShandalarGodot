extends GutTest
## THE SMOOTHNESS PASS, M3 (0.50.66) — THE SKIN READ OFF THE THREAD THAT
## DRAWS. The world read a place's tune, a sheet, a meeting's pictures on
## the main thread the first time each was wanted (the walk's 15-60 ms
## hitches). Pinned here:
##  - [method GameSkin.picture_job] / [method GameSkin.decode_picture] /
##    [method GameSkin.keep_picture] give EXACTLY what [method
##    GameSkin.picture] gives — a 1x picture, a 2x one beside its 1x file,
##    a 2x one alone, a slot whose size only its own 1x file says, a
##    missing key, a broken file — and keep it where [method
##    GameSkin.texture] finds it; the decode runs on a worker thread and
##    touches no cache; the sounds' three steps likewise;
##  - [MusicLibrary]'s tune steps hand [method MusicLibrary.stream] the tune
##    decoded, and six tunes are kept;
##  - [SkinWarmer] runs nowhere headless unless forced, and warms what it is
##    given; [method WorldArt.sheet_ready] is true at once headless, false
##    while its sheet is decoded, true once it is kept;
##  - the soundscape's pane pictures, the stage's spoils warmed;
##  - [PerfLog] flags a frame of twice the refresh period and a hitch at
##    four (a 40 ms frame and a 70 ms one at 60 Hz: neither was a line
##    before);
##  - [TileReveal.Snapshot] is held while a cover shows it and let go after.
## The fixtures are written into a scratch skin folder, so no 1997 file is
## needed on the machine running the suite.

const SCRATCH := "user://c20_m3_skin_warm"
const SKIN := SCRATCH + "/skin"
const MUSIC := SCRATCH + "/music"
const KEYS: Array[String] = [GamePaths.KEY_SKIN_FOLDER, GamePaths.KEY_USE_SKIN_FOLDER]
## A slot [constant GameSkin.SIZES] knows (296 x 54), and one it does not.
const SIZED := "end_plaque"
const UNSIZED := "c20_m3_sheet"

var _saved: Dictionary = {}
var _was_worn := false


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SKIN))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MUSIC))
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SKIN)
	_was_worn = GameSkin.zip_worn
	GameSkin.zip_worn = false
	GameSkin.clear_caches()
	SkinWarmer.forced = -1


func after_each() -> void:
	Engine.print_error_messages = true
	SkinWarmer.forced = -1
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	GameSkin.zip_worn = _was_worn
	MusicLibrary.dirs = [GamePaths.music_folder()]
	MusicLibrary.skin_dirs = null
	MusicLibrary.refresh()
	_wipe(SCRATCH)
	GameSkin.clear_caches()


static func _wipe(folder: String) -> void:
	var absolute := ProjectSettings.globalize_path(folder)
	for sub in DirAccess.get_directories_at(absolute):
		_wipe(folder.path_join(sub))
	for file_name in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)


# ------------------------------------------------------------- fixtures --

## A picture of [param size] in four coloured quarters (a ninth of it see-
## through), [param salt] moving the colours.
static func _picture(size: Vector2i, salt := 0) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var inks: Array[Color] = [Color(0.8, 0.2, 0.1), Color(0.1, 0.5, 0.9), Color(0.2, 0.7, 0.3),
		Color(0.9, 0.85, 0.2)]
	var half := size / 2
	img.fill_rect(Rect2i(Vector2i.ZERO, half), inks[salt % 4])
	img.fill_rect(Rect2i(Vector2i(half.x, 0), Vector2i(size.x - half.x, half.y)), inks[(salt + 1) % 4])
	img.fill_rect(Rect2i(Vector2i(0, half.y), Vector2i(half.x, size.y - half.y)), inks[(salt + 2) % 4])
	img.fill_rect(Rect2i(half, size - half), inks[(salt + 3) % 4])
	img.fill_rect(Rect2i(Vector2i.ZERO, size / 3), Color(0, 0, 0, 0))
	return img


func _write_png(file_name: String, img: Image) -> String:
	var path := ProjectSettings.globalize_path(SKIN.path_join(file_name))
	img.save_png(path)
	return path


## A real, minimal PCM wav of [param frames] frames (`test_deck_sound.gd`'s).
static func _wav(frames: int) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)
	pcm.fill(0)
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_data("RIFF".to_ascii_buffer())
	buf.put_u32(36 + pcm.size())
	buf.put_data("WAVEfmt ".to_ascii_buffer())
	buf.put_u32(16)
	buf.put_16(1)
	buf.put_16(1)
	buf.put_u32(22050)
	buf.put_u32(44100)
	buf.put_16(2)
	buf.put_16(16)
	buf.put_data("data".to_ascii_buffer())
	buf.put_u32(pcm.size())
	buf.put_data(pcm)
	return buf.data_array


func _write_wav(folder: String, file_name: String, frames := 64) -> String:
	var path := ProjectSettings.globalize_path(folder.path_join(file_name))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(_wav(frames))
	file.close()
	return path


## [param key] read the on-demand way ([method GameSkin.picture], caches
## cleared before and after) — the reference.
func _reference(key: String) -> Texture2D:
	GameSkin.clear_caches()
	var found := GameSkin._slot(key + ".png")
	var path := String(found["path"])
	var tex: Texture2D = GameSkin.picture(path, key, String(found["own"])) if path != "" else null
	GameSkin.clear_caches()
	return tex


## [param key] in the three steps, the decode on a worker thread.
func _warmed(key: String) -> Texture2D:
	var job := GameSkin.picture_job(key)
	var cached := GameSkin._texture_cache.size()
	var task := WorkerThreadPool.add_task(GameSkin.decode_picture.bind(job))
	WorkerThreadPool.wait_for_task_completion(task)
	assert_eq(GameSkin._texture_cache.size(), cached, "the decode keeps nothing itself")
	return GameSkin.keep_picture(job)


func _assert_same_picture(got: Texture2D, want: Texture2D, what: String) -> void:
	assert_not_null(got, what + ": a texture")
	assert_not_null(want, what + ": the reference")
	if got == null or want == null:
		return
	assert_eq(got.get_size(), want.get_size(), what + ": the drawn size")
	assert_eq(GameSkin.scale_of(got), GameSkin.scale_of(want), what + ": the scale")
	assert_eq(got.get_meta(GameSkin.ORIGINAL_META, ""), want.get_meta(GameSkin.ORIGINAL_META, ""),
		what + ": the 1x file it remembers")
	assert_eq(got.get_class(), want.get_class(), what + ": the same kind of texture")
	var a := got.get_image()
	var b := want.get_image()
	assert_eq(a.get_size(), b.get_size(), what + ": the pixels' size")
	assert_eq(a.get_data(), b.get_data(), what + ": the same pixels")


# ------------------------------------------------- the pictures' steps --

func test_a_1x_picture_kept_is_what_picture_makes() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	var want := _reference(SIZED)
	var got := _warmed(SIZED)
	_assert_same_picture(got, want, "1x")
	assert_same(GameSkin.texture(SIZED), got, "kept where texture() finds it")
	assert_same(GameSkin.keep_picture({"key": SIZED, "path": "anything", "own": ""}), got,
		"keeping again hands back the one kept")
	assert_eq(GameSkin.picture_job(SIZED), {}, "a kept picture needs no job")


func test_a_2x_picture_beside_its_1x_file_is_what_picture_makes() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	_write_png(SIZED + "@2x.png", _picture(Vector2i(592, 108)))
	var want := _reference(SIZED)
	assert_eq(GameSkin.scale_of(want), 2, "the fixture is worn at 2x")
	_assert_same_picture(_warmed(SIZED), want, "2x beside its 1x")


func test_a_2x_picture_alone_is_what_picture_makes() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(592, 108), 1))
	var want := _reference(SIZED)
	assert_eq(GameSkin.scale_of(want), 2, "the slot's 1997 size says 2x")
	_assert_same_picture(_warmed(SIZED), want, "2x alone")


func test_a_slot_only_its_1x_file_measures_is_what_picture_makes() -> void:
	_write_png(UNSIZED + ".png", _picture(Vector2i(20, 10), 2))
	_write_png(UNSIZED + "@2x.png", _picture(Vector2i(40, 20), 3))
	var want := _reference(UNSIZED)
	assert_eq(GameSkin.scale_of(want), 2, "the 1x file beside it says 2x")
	var job := GameSkin.picture_job(UNSIZED)
	GameSkin.decode_picture(job)
	assert_true(job.has("own_img"), "the 1x file is decoded too, off the main thread")
	_assert_same_picture(GameSkin.keep_picture(job), want, "measured by its 1x file")


func test_a_kept_picture_s_file_job_for_a_worker_that_derives_from_it() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	var kept := GameSkin.texture(SIZED)
	assert_not_null(kept)
	assert_eq(GameSkin.picture_job(SIZED), {}, "kept: no job by default")
	var job := GameSkin.picture_job(SIZED, true)
	assert_eq(String(job.get("key", "")), SIZED, "kept_too: the file's job all the same")
	GameSkin.decode_picture(job)
	var img: Image = job["img"]
	assert_eq(img.get_size(), Vector2i(296, 54), "the file decoded")
	assert_same(GameSkin.texture(SIZED), kept, "and the kept texture untouched")
	assert_eq(GameSkin.picture_job("c20_m3_missing", true), {}, "missing: still no job")


func test_a_missing_key_needs_no_job() -> void:
	assert_eq(GameSkin.picture_job("c20_m3_no_such_picture"), {})
	assert_eq(GameSkin.picture_job(""), {})
	assert_null(GameSkin.keep_picture({}), "an empty job keeps nothing")
	assert_null(GameSkin.texture("c20_m3_no_such_picture"))


func test_a_broken_file_is_kept_as_nothing_like_on_demand() -> void:
	var path := ProjectSettings.globalize_path(SKIN.path_join(UNSIZED + ".png"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a picture")
	file.close()
	var job := GameSkin.picture_job(UNSIZED)
	# The engine's own complaint about the file kept off the log (as
	# tests/unit/test_c12_F6_quiet_reads.gd keeps it).
	Engine.print_error_messages = false
	GameSkin.decode_picture(job)
	Engine.print_error_messages = true
	assert_null(GameSkin.keep_picture(job))
	assert_true(GameSkin._texture_cache.has(UNSIZED) and GameSkin._texture_cache[UNSIZED] == null,
		"kept as null, as texture() keeps a file that would not read")
	assert_eq(GameSkin.picture_job(UNSIZED), {}, "and not asked for again")


func test_a_job_whose_place_changed_is_not_kept() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	var job := GameSkin.picture_job(SIZED)
	GameSkin.decode_picture(job)
	DirAccess.remove_absolute(String(job["path"]))
	assert_null(GameSkin.keep_picture(job), "a skin that changed meanwhile: nothing kept")
	assert_false(GameSkin._texture_cache.has(SIZED), "the on-demand read answers instead")


func test_a_job_never_decoded_is_not_kept() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	assert_null(GameSkin.keep_picture(GameSkin.picture_job(SIZED)))
	assert_false(GameSkin._texture_cache.has(SIZED))


# ------------------------------------------------------------ the faces --

func test_a_face_in_three_steps_is_what_texture_gives() -> void:
	var faces := SCRATCH.path_join("faces")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(faces))
	_picture(Vector2i(40, 40), 1).save_png(ProjectSettings.globalize_path(faces.path_join("c20_m3_face.png")))
	var kept_dirs := PortraitLibrary.dirs
	PortraitLibrary.dirs = [faces]
	PortraitLibrary.refresh()
	var want := PortraitLibrary.texture("c20_m3_face")
	PortraitLibrary.refresh()
	var job := PortraitLibrary.face_job("c20_m3_face")
	assert_false(job.is_empty(), "a face of the player's own: a job")
	var task := WorkerThreadPool.add_task(GameSkin.decode_picture.bind(job))
	WorkerThreadPool.wait_for_task_completion(task)
	var stale := job.duplicate()
	var got := PortraitLibrary.keep_face(job)
	_assert_same_picture(got, want, "the face")
	assert_same(PortraitLibrary.texture("c20_m3_face"), got, "kept where texture() finds it")
	assert_eq(PortraitLibrary.face_job("c20_m3_face"), {}, "a kept face needs no job")
	PortraitLibrary.refresh()
	assert_null(PortraitLibrary.keep_face(stale), "a job from before the faces were looked for again is not kept")
	assert_eq(PortraitLibrary.face_job("c20_m3_no_face"), {}, "nor is a face not there")
	PortraitLibrary.dirs = kept_dirs
	PortraitLibrary.refresh()


func test_the_transitions_shader_is_warmed_unseen() -> void:
	assert_null(TileReveal.warm_shader(self), "headless: nothing")
	TileReveal.forced = 1
	var dot := TileReveal.warm_shader(self)
	TileReveal.forced = -1
	assert_not_null(dot)
	if dot != null:
		var material := dot.material as ShaderMaterial
		assert_same(material.shader, TileReveal._shader, "the covers' own shader")
		assert_eq(float(material.get_shader_parameter("shown")), 255.0, "every tile come: every fragment dropped")
		dot.free()


# ---------------------------------------------------- the sounds' steps --

func test_a_sound_in_three_steps_is_what_sound_gives() -> void:
	_write_wav(SKIN, "sfx_c20_m3.wav", 96)
	var want := GameSkin.sound("sfx_c20_m3") as AudioStreamWAV
	GameSkin.clear_caches()
	var job := GameSkin.sound_job("sfx_c20_m3")
	var task := WorkerThreadPool.add_task(GameSkin.decode_sound.bind(job))
	WorkerThreadPool.wait_for_task_completion(task)
	assert_false(GameSkin._sound_cache.has("sfx_c20_m3"), "the decode keeps nothing itself")
	var got := GameSkin.keep_sound(job) as AudioStreamWAV
	assert_not_null(got)
	assert_eq(got.data, want.data, "the same sound")
	assert_same(GameSkin.sound("sfx_c20_m3"), got, "kept where sound() finds it")
	assert_eq(GameSkin.sound_job("sfx_c20_m3"), {}, "a kept sound needs no job")
	assert_eq(GameSkin.sound_job("sfx_c20_m3_none"), {}, "nor a missing one")


# ------------------------------------------------------------- the tunes --

func test_a_tune_in_three_steps_is_what_stream_hands_out() -> void:
	MusicLibrary.dirs = [MUSIC]
	MusicLibrary.skin_dirs = [MUSIC]
	_write_wav(MUSIC, "music_location_3.wav", 128)
	MusicLibrary.refresh()
	var job := MusicLibrary.tune_job("music_location_3")
	assert_false(job.is_empty())
	var task := WorkerThreadPool.add_task(MusicLibrary.decode_tune.bind(job))
	WorkerThreadPool.wait_for_task_completion(task)
	var kept := MusicLibrary.keep_tune(job)
	assert_not_null(kept)
	assert_same(MusicLibrary.stream("music_location_3"), kept, "stream() hands out the tune decoded")
	assert_eq(MusicLibrary.tune_job("music_location_3"), {}, "a kept tune needs no job")
	assert_eq(MusicLibrary.tune_job("music_location_4"), {}, "nor a missing one")


func test_a_place_tune_not_warmed_starts_once_decoded() -> void:
	MusicLibrary.dirs = [MUSIC]
	MusicLibrary.skin_dirs = [MUSIC]
	_write_wav(MUSIC, "music_location_3.wav", 2048)
	MusicLibrary.refresh()
	var world := ShandalarWorld.new()
	world.sites = [{"type": ShandalarWorld.VILLAGE + 1, "x": 1, "y": 1},
		{"type": ShandalarWorld.VILLAGE + 1, "x": 9, "y": 9}, {"type": ShandalarWorld.VILLAGE + 1, "x": 5, "y": 5}]
	assert_eq(WorldSoundscape.tune_key(world, 2), "music_location_3", "the fixture's place")
	var player := AdventurePlayer.new()
	player.world = world
	player.position = Vector2i(5 * 32 + 16, 5 * 32 + 16)
	var sounds := WorldSoundscape.new()
	add_child_autofree(sounds)
	sounds._quiet = false
	sounds._tune.silent = false
	SkinWarmer.forced = 1
	sounds.player = player
	sounds.hear_places()
	assert_eq(sounds.site, 2, "the place heard")
	assert_eq(sounds._tune.key, "", "not read on this frame: decoded on a worker first")
	assert_eq(sounds._tune_waiting, "music_location_3")
	var frames := 0
	while sounds._tune.key == "" and frames < 120:
		await get_tree().process_frame
		frames += 1
	assert_eq(sounds._tune.key, "music_location_3", "it starts as it is kept (%d frames)" % frames)
	assert_eq(sounds._tune_waiting, "")
	sounds._tune.stop_music()


func test_six_tunes_are_kept() -> void:
	assert_eq(MusicLibrary.KEPT_TUNES, 6, "the three of F1 and the places a walk passes")
	MusicLibrary.dirs = [MUSIC]
	MusicLibrary.skin_dirs = [MUSIC]
	for i in 6:
		_write_wav(MUSIC, "music_location_%d.wav" % (i + 1))
	MusicLibrary.refresh()
	var first := MusicLibrary.stream("music_location_1")
	for i in range(2, 7):
		MusicLibrary.stream("music_location_%d" % i)
	assert_same(MusicLibrary.stream("music_location_1"), first, "the first of six still kept")


# ---------------------------------------------------- the warmer, the art --

func test_no_warmer_runs_headless_unless_forced() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	assert_false(SkinWarmer.runs_here(), "the suite runs headless")
	assert_null(SkinWarmer.warm(self, [SIZED] as Array[String]))
	assert_false(GameSkin._texture_cache.has(SIZED), "nothing read")


func test_a_warmer_keeps_what_it_decodes() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	_write_wav(SKIN, "sfx_c20_m3.wav")
	SkinWarmer.forced = 1
	var warmer := SkinWarmer.warm(self, [SIZED, "c20_m3_missing"] as Array[String],
		["sfx_c20_m3"] as Array[String])
	assert_not_null(warmer)
	assert_true(SkinWarmer.picture_pending(SIZED), "in flight")
	assert_false(SkinWarmer.picture_pending("c20_m3_missing"), "a missing picture is not warmed")
	assert_null(SkinWarmer.warm(self, [SIZED] as Array[String]), "nor one already in flight")
	warmer.finish_now()
	assert_true(GameSkin._texture_cache.has(SIZED), "the picture kept")
	assert_true(GameSkin._sound_cache.has("sfx_c20_m3"), "the sound kept")
	assert_false(SkinWarmer.picture_pending(SIZED), "and no longer in flight")
	assert_true(warmer.finished())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(warmer) and not warmer.is_queued_for_deletion(), "it leaves once done")


func test_every_warmer_finished_at_once() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	_write_png(UNSIZED + ".png", _picture(Vector2i(20, 10)))
	SkinWarmer.forced = 1
	SkinWarmer.warm(self, [SIZED] as Array[String])
	SkinWarmer.warm(self, [UNSIZED] as Array[String])
	SkinWarmer.finish_all()
	assert_true(GameSkin._texture_cache.has(SIZED) and GameSkin._texture_cache.has(UNSIZED),
		"both warmers' pictures kept this frame")
	assert_true(SkinWarmer._live.is_empty(), "and none left at work")
	await get_tree().process_frame
	await get_tree().process_frame


func test_a_warmer_that_leaves_lets_go_of_what_it_did_not_keep() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	SkinWarmer.forced = 1
	var warmer := SkinWarmer.warm(self, [SIZED] as Array[String])
	assert_true(SkinWarmer.picture_pending(SIZED))
	warmer._exit_tree()      # as the tree tells it on the way out
	assert_false(SkinWarmer.picture_pending(SIZED), "a warmer gone holds nothing in flight")
	assert_false(GameSkin._texture_cache.has(SIZED), "and keeps nothing after")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(warmer) and not warmer.is_queued_for_deletion(), "it is let go")


func test_sheet_ready_is_true_at_once_headless() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	var art := WorldArt.new()
	assert_true(art.sheet_ready(SIZED), "headless: read on demand, as before")
	assert_true(art.sheet_ready(""), "no figure")
	assert_true(art.sheet_ready("c20_m3_missing"), "a missing sheet")


func test_sheet_ready_waits_for_its_sheet_off_the_main_thread() -> void:
	_write_png(SIZED + ".png", _picture(Vector2i(296, 54)))
	SkinWarmer.forced = 1
	var art := WorldArt.new()
	assert_false(art.sheet_ready(SIZED), "the first ask starts the decode")
	assert_false(GameSkin._texture_cache.has(SIZED), "nothing read on this thread")
	assert_false(art.sheet_ready(SIZED), "still in flight")
	var frames := 0
	while not art.sheet_ready(SIZED) and frames < 120:
		await get_tree().process_frame
		frames += 1
	assert_true(art.sheet_ready(SIZED), "kept by the warmer within %d frames: ready" % frames)
	assert_true(art._textures.has(SIZED), "and in hand: one look-up from now on")
	assert_true(art.sheet_ready(SIZED))


func test_the_place_sheets_are_the_world_s_place_sheets() -> void:
	for key in WorldArt.PLACE_SHEETS:
		assert_true(WorldArt.LAYOUT.has(key), "%s is a sheet the world draws" % key)
	assert_eq(WorldArt.PLACE_SHEETS.size(), 9)


func test_a_place_s_pane_picture() -> void:
	var world := ShandalarWorld.new()
	world.sites = [{"type": ShandalarWorld.VILLAGE, "x": 1, "y": 1},
		{"type": ShandalarWorld.VILLAGE + 1, "x": 2, "y": 2}, {"type": 0, "x": 3, "y": 3}]
	assert_eq(WorldSoundscape.pane_picture(world, 0), "visit_village")
	assert_eq(WorldSoundscape.pane_picture(world, 1), "visit_city")
	assert_eq(WorldSoundscape.pane_picture(world, 2), "", "no place")
	assert_eq(WorldSoundscape.pane_picture(world, 9), "", "no slot")


func test_the_stage_warms_the_spoils() -> void:
	_write_png("win_back_cards.png", _picture(Vector2i(640, 480)))
	SkinWarmer.forced = 1
	var stage := EncounterStage.new()
	add_child_autofree(stage)
	var warmer := stage.warm_spoils()
	assert_not_null(warmer, "a warmer for the spoils")
	if warmer != null:
		warmer.finish_now()
	assert_true(GameSkin._texture_cache.has("win_back_cards"), "the cards won's ground kept")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(warmer) and not warmer.is_queued_for_deletion(), "and the warmer gone")


# -------------------------------------------------------- the timing log --

func test_the_log_s_thresholds_follow_the_refresh() -> void:
	assert_almost_eq(PerfLog.frame_period_ms(60.0, 0), 16.667, 0.01)
	assert_almost_eq(PerfLog.frame_period_ms(144.0, 0), 6.944, 0.01)
	assert_almost_eq(PerfLog.frame_period_ms(144.0, 60), 16.667, 0.01, "a cap lower than the screen")
	assert_almost_eq(PerfLog.frame_period_ms(-1.0, 0), 16.667, 0.01, "no rate known: 60 Hz")
	assert_almost_eq(PerfLog.slow_for(16.667), 33.33, 0.01, "twice the period")
	assert_almost_eq(PerfLog.hitch_for(16.667), 66.67, 0.01, "four times")
	assert_almost_eq(PerfLog.slow_for(6.944), 13.89, 0.01, "144 Hz")
	assert_eq(PerfLog.slow_for(33.333), PerfLog.SLOW_MS, "never later than before")
	assert_eq(PerfLog.hitch_for(33.333), PerfLog.HITCH_MS)


func test_the_walk_s_hitches_reach_the_log() -> void:
	var folder := SCRATCH.path_join("perf")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var node := PerfLog.new()
	node.path = folder.path_join("perf.log")
	node.asked_by = "a test"
	node.period_ms = 1000.0 / 60.0
	add_child_autofree(node)
	var t := node._started_us
	for ms in [16.7, 40.0, 16.7, 70.0, 16.7]:
		t += int(ms * 1000.0)
		node._frame(ms, t)
	node._frame(16.7, node._started_us + 1100000)
	var text := FileAccess.get_file_as_string(node.path)
	assert_string_contains(text, "HITCH 70 ms", "a 70 ms frame at 60 Hz is a hitch (it was not, under 100)")
	assert_string_contains(text, ">33ms 2", "the 40 and the 70 ms frames are slow (neither was, under 50)")
	assert_string_contains(text, "refresh period 16.7 ms", "the header says what they follow")


# ------------------------------------------------------ the screen kept --

func test_a_snapshot_is_held_while_a_cover_shows_it() -> void:
	var source := ImageTexture.create_from_image(Image.create_empty(8, 8, false, Image.FORMAT_RGBA8))
	var shot := TileReveal.Snapshot.make(self, source, Vector2i(8, 8))
	var picture := shot.get_texture()
	assert_same(TileReveal.Snapshot.of(picture), shot, "the picture knows its snapshot")
	assert_eq(Vector2i(picture.get_size()), Vector2i(8, 8), "the window's pixels")
	var one := TileReveal.make(Vector2i(2, 2), 0.3)
	var two := TileReveal.make(Vector2i(2, 2), 0.3)
	if one == null:
		one = TileReveal.new()
		two = TileReveal.new()
	add_child(one)
	add_child(two)
	one.before = picture
	two.take_screen(picture)
	one.free()
	assert_true(is_instance_valid(shot) and not shot.is_queued_for_deletion(), "the second cover still shows it")
	two.free()
	assert_true(shot.is_queued_for_deletion(), "let go with the last cover")
	await get_tree().process_frame


func test_a_snapshot_nobody_took_goes() -> void:
	var source := ImageTexture.create_from_image(Image.create_empty(8, 8, false, Image.FORMAT_RGBA8))
	var shot := TileReveal.Snapshot.make(self, source, Vector2i(8, 8))
	shot._unused()
	assert_true(shot.is_queued_for_deletion(), "not taken: gone")
	await get_tree().process_frame
