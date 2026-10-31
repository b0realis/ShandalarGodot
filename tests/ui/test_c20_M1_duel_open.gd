extends GutTest
## THE DUEL OPENS WITHOUT A FREEZE (the smoothness pass, 0.50.66, M1; the
## owner, 2026-10-29: *"I really want our adventure to play silky butter
## smooth"*). Measured on the desk's RTX: a duel's screen took 400 ms of
## one frame to open with the 1997 skin, 1 s with the 2x skin, every time.
## What it spent that on, and what this pins:
##  - THE DERIVED STONES ([method OriginalDialog.stone_job]): the bar's
##    button, the ruled grounds and the Classic frames were walked pixel by
##    pixel on every duel. Now made once per picture — the same texture
##    handed out again, so the same pixels; made afresh for a skin that
##    arrives; the same pixels as before the pass (the old routines are
##    kept below as the reference); and the same pixels when a warm-up
##    makes them on a worker thread.
##  - THE STOP DOTS ([method PhaseBar.show_stop_dot]): `●` asked the system
##    for a font on every dot built; a dot is lettered when first shown.
##  - THE DUEL'S TUNES ([method MusicPlayer.play_key]): the window of eight
##    decoded before the first note; now on a worker — the same list, in
##    the same order, every place filled before the opening tune can end,
##    and headless the whole list at once as before.
##  - THE WARM-UP ([DuelWarmup]): nothing headless; the stones it makes are
##    the ones a duel wears; a duel opened before it is through opens as
##    before.
## The skin here is a scratch folder of small fixture pictures, so the file
## runs with or without the imported 1997 skin.

const SCRATCH := "user://test_c20_m1"
const SKIN := SCRATCH + "/skin"
const MUSIC_PLAYER_DIR := SCRATCH + "/music_player"
const MUSIC_SKIN_DIR := SCRATCH + "/music_skin"
const KEYS: Array[String] = [GamePaths.KEY_SKIN_FOLDER, GamePaths.KEY_USE_SKIN_FOLDER,
	DuelOptions.BAR_FRAME_KEY, DuelOptions.COIN_FLIP_KEY, MusicLibrary.SETTING]
const PALETTE: Array[Color] = [Color.BLACK, Color.WHITE, Color(0.18, 0.18, 0.18),
	Color(0.62, 0.20, 0.18), Color(0.20, 0.35, 0.70), Color(0.30, 0.62, 0.28),
	Color(0.80, 0.70, 0.30), Color(0.49, 0.35, 0.36)]

var _saved: Dictionary = {}
var _was_worn := false


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SKIN)
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SKIN)
	_was_worn = GameSkin.zip_worn
	GameSkin.zip_worn = false
	GameSkin.clear_caches()
	MusicPlayer.threaded = -1
	DuelWarmup.forced = -1
	SkinWarmer.forced = -1


func after_each() -> void:
	MusicPlayer.threaded = -1
	DuelWarmup.forced = -1
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
	MusicPlayer.reset_order()
	_wipe(SCRATCH)
	GameSkin.clear_caches()


static func _wipe(folder: String) -> void:
	for sub in DirAccess.get_directories_at(folder):
		_wipe(folder.path_join(sub))
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


static func _blocks(size: Vector2i, salt := 0) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var h := ((x / 3) * 73856093) ^ ((y / 3) * 19349663) ^ (salt * 83492791)
			img.set_pixel(x, y, PALETTE[absi(h) % PALETTE.size()])
	return img


## The two stones' pictures in the scratch skin, small: [param scale] 2
## writes the bar's at twice its 1997 slot's size, as the 2x skin wears it
## (the field stays small — a 1776x632 fixture walked pixel by pixel in a
## test costs seconds and proves nothing the bar does not).
func _skin_pictures(scale := 1, salt := 0) -> void:
	var bar: Vector2i = GameSkin.SIZES["message_panel"]
	var bar_size := bar * 2 if scale == 2 else Vector2i(96, bar.y)
	_blocks(bar_size, salt).save_png(ProjectSettings.globalize_path(SKIN.path_join("message_panel.png")))
	_blocks(Vector2i(90, 40), salt + 1).save_png(
		ProjectSettings.globalize_path(SKIN.path_join("attack_panel.png")))
	_blocks(Vector2i(130, 110), salt + 2).save_png(
		ProjectSettings.globalize_path(SKIN.path_join("panel_dark_stone.png")))
	GameSkin.clear_caches()


# ------------------------------------------- the old routines, the reference --

## `OriginalDialog._rule` as it was before the pass (0.50.65), verbatim.
static func _old_rule(img: Image, raised: bool, scale := 1) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var top := OriginalDialog.HIGHLIGHT if raised else OriginalDialog.SHADOW
	var bottom := OriginalDialog.SHADOW if raised else OriginalDialog.HIGHLIGHT
	for y in h:
		for x in w:
			var near_tl: int = mini(y, x)
			var near_br: int = mini(h - 1 - y, w - 1 - x)
			if near_br < OriginalDialog.RULE_WIDTH * scale and near_br <= near_tl:
				img.set_pixel(x, y, bottom)
			elif near_tl < OriginalDialog.RULE_WIDTH * scale:
				img.set_pixel(x, y, top)
	return img


## `OriginalDialog.bar_button_texture`'s pixels as they were.
static func _old_button(art: Texture2D, pressed: bool, gain: float) -> Image:
	var img := art.get_image().duplicate()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(minf(c.r * gain, 1.0),
				minf(c.g * gain, 1.0), minf(c.b * gain, 1.0), c.a))
	return _old_rule(img, not pressed, GameSkin.scale_of(art))


## `OriginalDialog.ruled_texture`'s pixels as they were.
static func _old_ruled(art: Texture2D, raised: bool) -> Image:
	var img := art.get_image().duplicate()
	img.convert(Image.FORMAT_RGBA8)
	return _old_rule(img, raised, GameSkin.scale_of(art))


## `OriginalDialog.ridged_texture`'s pixels as they were.
static func _old_ridged(art: Texture2D, frame: String) -> Image:
	var img: Image = art.get_image().duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var pale := OriginalDialog.HIGHLIGHT
	var dark := OriginalDialog.INK
	if frame != DuelOptions.BAR_FRAME_CLASSIC:
		var mean := OriginalDialog._mean_colour(img)
		pale = Color(minf(mean.r * OriginalDialog.RIDGE_LIGHT, 1.0),
			minf(mean.g * OriginalDialog.RIDGE_LIGHT, 1.0), minf(mean.b * OriginalDialog.RIDGE_LIGHT, 1.0))
		dark = Color(mean.r * OriginalDialog.RIDGE_DARK, mean.g * OriginalDialog.RIDGE_DARK,
			mean.b * OriginalDialog.RIDGE_DARK)
	var line := OriginalDialog.ridge_width(frame)
	var scale := GameSkin.scale_of(art)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var band: int = line * scale
	for y in h:
		for x in w:
			var near_tl: int = mini(y, x)
			var near_br: int = mini(h - 1 - y, w - 1 - x)
			var near: int = mini(near_tl, near_br)
			if near >= 2 * band:
				continue
			var outer := near < band
			if near_br <= near_tl:
				img.set_pixel(x, y, dark if outer else pale)
			else:
				img.set_pixel(x, y, pale if outer else dark)
	return img


func _same_pixels(tex: Texture2D, want: Image, what: String) -> void:
	assert_not_null(tex, what)
	if tex == null:
		return
	var got := tex.get_image()
	got.convert(Image.FORMAT_RGBA8)
	assert_eq(got.get_size(), want.get_size(), what + ": the size")
	assert_true(got.get_data() == want.get_data(), what + ": pixel for pixel")


# ------------------------------------------------------- the derived stones --

func test_a_stone_is_made_once_and_handed_out_again() -> void:
	_skin_pictures()
	var button := OriginalDialog.bar_button_texture(false)
	assert_not_null(button, "the fixture skin has the bar's stone")
	assert_same(OriginalDialog.bar_button_texture(false), button, "the bar's button: once")
	assert_same(OriginalDialog.bar_button_texture(true), OriginalDialog.bar_button_texture(true),
		"its pressed face: once")
	assert_ne(OriginalDialog.bar_button_texture(false, 1.18), button, "another gain is another stone")
	var field := OriginalDialog.ruled_texture("attack_panel")
	assert_same(OriginalDialog.ruled_texture("attack_panel"), field, "the Combat window's field: once")
	var ridge := OriginalDialog.ridged_texture("message_panel", DuelOptions.BAR_FRAME_CLASSIC)
	assert_same(OriginalDialog.ridged_texture("message_panel", DuelOptions.BAR_FRAME_CLASSIC), ridge,
		"a Classic frame: once")
	# And so a duel's whole chrome: two buttons dressed alike share their faces.
	var one := OriginalDialog.bar_button("a")
	var two := OriginalDialog.bar_button("b")
	assert_same((two.get_theme_stylebox("normal") as StyleBoxTexture).texture,
		(one.get_theme_stylebox("normal") as StyleBoxTexture).texture, "the same face on both")
	one.free()
	two.free()


func test_the_stones_are_the_pixels_they_were() -> void:
	for scale in [1, 2]:
		_skin_pictures(scale)
		var bar := GameSkin.texture("message_panel")
		var field := GameSkin.texture("attack_panel")
		assert_eq(GameSkin.scale_of(bar), scale, "the bar's fixture at %dx" % scale)
		for pressed in [false, true]:
			for gain in [1.55, 1.18, 1.78]:
				_same_pixels(OriginalDialog.bar_button_texture(pressed, gain),
					_old_button(bar, pressed, gain), "button %s %.2f at %dx" % [pressed, gain, scale])
		for raised in [true, false]:
			_same_pixels(OriginalDialog.ruled_texture("message_panel", raised),
				_old_ruled(bar, raised), "the bar ruled %s at %dx" % [raised, scale])
			_same_pixels(OriginalDialog.ruled_texture("attack_panel", raised),
				_old_ruled(field, raised), "the field ruled %s at %dx" % [raised, scale])
		for frame in [DuelOptions.BAR_FRAME_CLASSIC, DuelOptions.BAR_FRAME_CLASSIC_THIN,
				DuelOptions.BAR_FRAME_CLASSIC_PALE]:
			_same_pixels(OriginalDialog.ridged_texture("message_panel", frame),
				_old_ridged(bar, frame), "%s at %dx" % [frame, scale])


func test_a_seamless_ground_is_the_tile_it_was_whichever_thread_made_it() -> void:
	_skin_pictures()
	var art := GameSkin.texture("panel_dark_stone")
	var spec: Dictionary = OriginalDialog.PANELS["panel_dark_stone"]
	var want := OriginalDialog.seamless(art.get_image(), 1, spec.get("period", Vector2i.ZERO),
		spec.get("flatten", true))
	assert_ne(want.get_size(), art.get_image().get_size(), "the fixture is big enough to be tiled")
	var job := OriginalDialog.stone_job(OriginalDialog.STONE_GROUND, "panel_dark_stone")
	var task := WorkerThreadPool.add_task(func() -> void: OriginalDialog.make_stone(job))
	WorkerThreadPool.wait_for_task_completion(task)
	var kept := OriginalDialog.keep_stone(job)
	assert_same(OriginalDialog.ground("panel_dark_stone"), kept, "the dialogs wear the one made off the thread")
	_same_pixels(kept, want, "the seamless tile")


func test_a_skin_that_arrives_makes_the_stones_afresh() -> void:
	_skin_pictures(1, 0)
	var before := OriginalDialog.bar_button_texture(false)
	_skin_pictures(1, 5)
	var after := OriginalDialog.bar_button_texture(false)
	assert_ne(after, before, "a new picture, a new stone")
	_same_pixels(after, _old_button(GameSkin.texture("message_panel"), false, 1.55),
		"made of the picture worn now")


func test_a_stone_made_off_the_thread_is_the_same_stone() -> void:
	_skin_pictures(2)
	var jobs: Array[Dictionary] = [
		# A button's face is raised when it is not pressed.
		OriginalDialog.stone_job(OriginalDialog.STONE_BUTTON, "message_panel", true, 1.55),
		OriginalDialog.stone_job(OriginalDialog.STONE_RULED, "attack_panel", true),
		OriginalDialog.stone_job(OriginalDialog.STONE_RIDGED, "message_panel", true, 1.55,
			DuelOptions.BAR_FRAME_CLASSIC_PALE)]
	var task := WorkerThreadPool.add_task(func() -> void:
		for job in jobs:
			OriginalDialog.make_stone(job))
	WorkerThreadPool.wait_for_task_completion(task)
	var kept: Array = []
	for job in jobs:
		kept.append(OriginalDialog.keep_stone(job))
	assert_same(OriginalDialog.bar_button_texture(true, 1.55), OriginalDialog.bar_button_texture(true, 1.55))
	assert_same(OriginalDialog.bar_button_texture(false), kept[0], "the duel wears the one made off the thread")
	assert_same(OriginalDialog.ruled_texture("attack_panel"), kept[1])
	assert_same(OriginalDialog.ridged_texture("message_panel", DuelOptions.BAR_FRAME_CLASSIC_PALE), kept[2])
	_same_pixels(kept[0], _old_button(GameSkin.texture("message_panel"), false, 1.55), "the button, 2x")
	_same_pixels(kept[1], _old_ruled(GameSkin.texture("attack_panel"), true), "the field")
	assert_true(OriginalDialog.stone_job(OriginalDialog.STONE_RULED, "attack_panel").is_empty(),
		"a stone kept is no job")


func test_a_stone_of_a_picture_no_longer_worn_is_not_kept() -> void:
	_skin_pictures(1, 0)
	var job := OriginalDialog.stone_job(OriginalDialog.STONE_RULED, "attack_panel")
	OriginalDialog.make_stone(job)
	_skin_pictures(1, 3)
	assert_null(OriginalDialog.keep_stone(job), "the skin changed meanwhile: dropped")
	_same_pixels(OriginalDialog.ruled_texture("attack_panel"),
		_old_ruled(GameSkin.texture("attack_panel"), true), "made of the picture worn now")


func test_a_combat_bar_column_keyed_off_the_thread_is_the_same_column() -> void:
	var sheet := _blocks(GameSkin.SIZES["combat_bar"], 2)
	for y in range(0, sheet.get_height(), 7):
		for x in sheet.get_width():
			sheet.set_pixel(x, y, Color.WHITE)       # white to key out
	sheet.save_png(ProjectSettings.globalize_path(SKIN.path_join("combat_bar.png")))
	GameSkin.clear_caches()
	CombatBar._keyed.clear()
	var region := CombatBar.column_region(true)
	var at_once := CombatBar.keyed_texture(region, CombatBar.Fill.BLACK).get_image()
	CombatBar._keyed.clear()
	var job := CombatBar.keyed_job(region, CombatBar.Fill.BLACK)
	var task := WorkerThreadPool.add_task(func() -> void: CombatBar.make_keyed(job))
	WorkerThreadPool.wait_for_task_completion(task)
	var kept := CombatBar.keep_keyed(job)
	assert_same(CombatBar.keyed_texture(region, CombatBar.Fill.BLACK), kept, "the duel wears it")
	assert_true(kept.get_image().get_data() == at_once.get_data(), "pixel for pixel")
	assert_true(CombatBar.keyed_job(region, CombatBar.Fill.BLACK).is_empty(), "kept: no job")
	CombatBar._keyed.clear()


# --------------------------------------------------------------- the dots --

func test_a_stop_dot_is_lettered_when_first_shown() -> void:
	var bar: PhaseBar = autofree(PhaseBar.new())
	for dot in bar._dots:
		assert_eq(dot.text, "", "a hidden dot asks no font for its letter")
	var stops := PhaseStops.new()
	stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 5, true)
	bar.stops = stops
	bar.refresh_stops()
	var shown: Label = bar._dots[PhaseBar.SLOTS + 5]
	assert_true(shown.visible)
	assert_eq(shown.text, PhaseBar.STOP_DOT, "the shown dot is the red dot it always was")
	stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 5, false)
	bar.refresh_stops()
	assert_false(shown.visible, "hidden again")
	var combat: CombatBar = autofree(CombatBar.new())
	for dot in combat._dots:
		assert_eq(dot.text, "", "the Combat Bar's too")


# ------------------------------------------------------------ the tunes --

## A real, minimal PCM wav of [param frames] frames (the fixture of
## `tests/ui/test_deck_sound.gd`), each tune its own [param tone] so two
## tunes' data differ.
func _wav(frames: int, tone: int) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)
	for i in frames:
		pcm.encode_s16(i * 2, ((i * (tone + 3)) % 2000) - 1000)
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


## Ten of the original's tunes in the scratch library.
func _library() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MUSIC_SKIN_DIR))
	MusicLibrary.dirs = [MUSIC_PLAYER_DIR]
	MusicLibrary.skin_dirs = [MUSIC_SKIN_DIR]
	var count := 0
	for row in MusicLibrary.ORIGINAL_TRACKS:
		if count >= 10:
			break
		var file := FileAccess.open(MUSIC_SKIN_DIR.path_join(String(row[0]) + ".wav"), FileAccess.WRITE)
		file.store_buffer(_wav(400 + count * 37, count))
		file.close()
		count += 1
	MusicLibrary.refresh()


func _player() -> MusicPlayer:
	var player: MusicPlayer = autofree(MusicPlayer.new())
	add_child(player)
	player.silent = false
	return player


## What a list plays, in order: each place's sound, an empty place none.
static func _heard(list: AudioStream) -> Array:
	var out: Array = []
	var playlist := list as AudioStreamPlaylist
	if playlist == null:
		return out
	for i in playlist.stream_count:
		var one := playlist.get_list_stream(i) as AudioStreamWAV
		if one != null and one.data.size() > 0:
			out.append(one.data)
	return out


func _the_list(threaded: int, choice: String) -> Array:
	MusicLibrary._forget_kept()
	Settings.set_value(MusicLibrary.SETTING, choice)
	MusicPlayer.reset_order()
	seed(6606)
	MusicPlayer.threaded = threaded
	var player := _player()
	player.play_key("music_duel")
	if threaded == 1:
		assert_true(player.window_pending(), "a window on its way")
		player.settle_window()
		assert_false(player.window_pending())
	return [player.tracks.duplicate(), _heard(player.stream), player.key]


func test_the_window_plays_the_same_tunes_in_the_same_order() -> void:
	_library()
	for choice in [MusicLibrary.CHOICE_SHUFFLE, MusicLibrary.CHOICE_ORIGINAL]:
		var at_once := _the_list(0, choice)
		var off_thread := _the_list(1, choice)
		assert_eq(off_thread[0], at_once[0], choice + ": the same tracks")
		assert_eq(off_thread[2], at_once[2], choice + ": the same key")
		assert_eq((off_thread[1] as Array).size(), (at_once[1] as Array).size(), choice + ": as many heard")
		assert_true(off_thread[1] == at_once[1], choice + ": the same sounds in the same order")
		assert_gt((at_once[1] as Array).size(), 1, choice + ": a list to compare")


func test_every_place_is_filled_before_the_opening_tune_can_end() -> void:
	_library()
	Settings.set_value(MusicLibrary.SETTING, MusicLibrary.CHOICE_SHUFFLE)
	MusicLibrary._forget_kept()
	MusicPlayer.threaded = 1
	var player := _player()
	player.play_key("music_duel")
	# The fixture tunes are milliseconds long: the deadline is now, so the
	# frame the list starts in is the last before every place is filled.
	for i in 30:
		if not player.window_pending():
			break
		await get_tree().process_frame
	assert_false(player.window_pending(), "settled")
	var playlist := player.stream as AudioStreamPlaylist
	assert_not_null(playlist, "playing")
	for i in playlist.stream_count:
		var one := playlist.get_list_stream(i) as AudioStreamWAV
		assert_true(one != null and one.data.size() > 0, "place %d filled: none skipped" % i)
	assert_eq(MusicPlayer.due(10.0), 10.0 - MusicPlayer.FADE - MusicPlayer.DEADLINE,
		"the deadline: before the opening tune's crossfade")
	assert_eq(MusicPlayer.due(1.0), 0.0, "a short opening: at once")


func test_headless_the_whole_list_is_built_at_once() -> void:
	_library()
	Settings.set_value(MusicLibrary.SETTING, MusicLibrary.CHOICE_SHUFFLE)
	MusicLibrary._forget_kept()
	assert_false(MusicPlayer.decodes_off_thread(), "no worker for a headless run")
	var player := _player()
	player.play_key("music_duel")
	assert_false(player.window_pending(), "nothing on its way")
	assert_eq(_heard(player.stream).size(), player.tracks.size(), "every tune in its place now")


func test_a_new_tune_lets_the_window_go() -> void:
	_library()
	Settings.set_value(MusicLibrary.SETTING, MusicLibrary.CHOICE_SHUFFLE)
	MusicLibrary._forget_kept()
	MusicPlayer.threaded = 1
	var player := _player()
	player.play_key("music_duel")
	player.stop_music()
	assert_false(player.window_pending(), "stopped: the worker waited for and let go")
	assert_null(player.stream)
	for i in 3:
		await get_tree().process_frame
	assert_null(player.stream, "nothing starts after a stop")


# ----------------------------------------------------------- the warm-up --

func test_headless_nothing_is_warmed() -> void:
	var host: Node = autofree(Node.new())
	add_child(host)
	var before := get_tree().root.get_child_count()
	assert_null(DuelWarmup.warm(host, ["green", "white"] as Array[String]),
		"no worker headless: the duel makes everything as it opens, as before")
	await get_tree().process_frame
	assert_eq(get_tree().root.get_child_count(), before, "nothing joined the tree")


func test_the_warm_up_asks_for_the_seats_pictures() -> void:
	var keys := DuelWarmup.pictures_for(["white", "green"] as Array[String])
	for key in ["message_panel", "attack_panel", "phase_bar",
			"life_panel_white", "life_panel_green", "hand_panel_green", "card_frame_land_white"]:
		assert_has(keys, key)
	assert_does_not_have(keys, "coin_toss_heads", "the coin's sheets are the warm-up's to add")
	var ground := DuelOptions.ground_for(1, 0, "green", {})
	assert_has(keys, DuelOptions.ground_key(String(ground["color"]), String(ground["type"])),
		"the ground the opponent's half will lay")
	assert_lt(keys.find("attack_panel"), keys.find("life_panel_white"),
		"the stones' pictures first")
	var unknown := DuelWarmup.pictures_for(["white", ""] as Array[String])
	for color in AdventurePlayer.COLORS:
		assert_has(unknown, "life_panel_" + color, "a seat not known yet: every colour's small panels")
	assert_does_not_have(unknown, "card_frame_red", "but never the five frames")
	assert_does_not_have(unknown, DuelOptions.ground_key("red", ""), "nor the five grounds")


func test_the_coin_is_warmed_only_when_a_duel_is_at_hand() -> void:
	DuelWarmup.forced = 1
	var host: Node = autofree(Node.new())
	add_child(host)
	var near := DuelWarmup.warm(host, ["green"] as Array[String])
	assert_has(near._pictures, "coin_toss_heads", "a meeting, a setup: the coin too")
	assert_has(near._sounds, "sfx_toss")
	var far := DuelWarmup.warm(host, ["green"] as Array[String], {}, [] as Array[String], false)
	assert_does_not_have(far._pictures, "coin_toss_heads", "on arrival: 39 MB the walk does not need")
	assert_does_not_have(far._sounds, "sfx_toss")
	near.finish_now()
	far.finish_now()
	await get_tree().process_frame
	assert_false(is_instance_valid(near), "done before it joined the tree: it frees itself")


func test_the_warm_up_makes_the_stones_a_duel_wears() -> void:
	_skin_pictures()
	DuelWarmup.forced = 1
	var host: Node = autofree(Node.new())
	add_child(host)
	var warmup := DuelWarmup.warm(host, ["green"] as Array[String])
	assert_not_null(warmup)
	warmup.finish_now()
	assert_true(warmup.finished())
	for spec in DuelWarmup._stone_specs():
		var kind := String(spec[0])
		var job := OriginalDialog.stone_job(kind, String(spec[1]), bool(spec[2]), float(spec[3]),
			String(spec[4]) if spec.size() > 4 else "")
		assert_true(job.is_empty(), "%s %s: kept" % [kind, spec])
	_same_pixels(OriginalDialog.bar_button_texture(false),
		_old_button(GameSkin.texture("message_panel"), false, 1.55), "the pixels a duel made")


func test_a_duel_opened_before_the_warm_up_is_through_opens_as_before() -> void:
	_skin_pictures()
	DuelWarmup.forced = 1
	var host: Node = autofree(Node.new())
	add_child(host)
	var warmup := DuelWarmup.warm(host, ["green"] as Array[String])
	assert_not_null(warmup)
	# The Duel button clicked at once: the screen makes what it needs.
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(duel)
	await get_tree().process_frame
	assert_not_null(duel.game, "the duel is dealt")
	# The two `▼` gadgets ask the system for no font until they are shown.
	assert_eq(duel._chain_gadget.text, "", "no chain yet: the band's gadget unlettered")
	assert_eq(duel._combat_window._minimize.text, "", "no attack yet: the window's gadget unlettered")
	duel._combat_window.present(duel.game, [], [], 0, 0)
	assert_eq(duel._combat_window._minimize.text, "▼", "presented: lettered as it always was")
	var bar := duel._situation_bar.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(bar, "the bar wears its stone")
	warmup.finish_now()
	assert_same(bar.texture, OriginalDialog.ruled_texture("message_panel"),
		"the warm-up keeps the stone the duel made: one stone, not two")
	assert_same(OriginalDialog.bar_button_texture(false),
		(duel._arrange_button.get_theme_stylebox("normal") as StyleBoxTexture).texture,
		"and the buttons' faces")
