extends GutTest
## THE TRANSITIONS (the quick world package, 2026-10-27, H7 — the owner:
## *"Add, with a switch"*): [TileReveal], 1997's picture effects as one
## node — the zoom-in (`AnimateVisitBackdropZoomIn`), the staggered tiles
## (`BlitRectByStaggeredRandomTileOrder`), the random tiles
## (`BlitRectByRandomTileOrderInPlace`) — and [RevealDissolve] on it. Each
## is short, takes no input, ends at any press and frees itself; the
## Options' switch turns them off; headless they never play, so no test
## waits on one.


func after_each() -> void:
	TileReveal.forced = -1
	Settings.clear_value(TileReveal.SETTING)


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	return key


## A cover of [param tiles] in [param order], [param length] seconds,
## seeded, in the tree.
func _cover(tiles: Vector2i, order: TileReveal.Order, length := 0.5) -> TileReveal:
	TileReveal.forced = 1
	var host := Control.new()
	add_child_autofree(host)
	var made := TileReveal.make(tiles, length, order)
	made.seed_value = 7
	made.size = Vector2(512, 280)
	host.add_child(made)
	return made


func _strip_done(cover: TileReveal, strip: int) -> float:
	var shown := 0
	var count := 0
	for y in cover.grid.y:
		for x in range(strip * cover.strip, mini((strip + 1) * cover.strip, cover.grid.x)):
			count += 1
			if cover.revealed(Vector2i(x, y)):
				shown += 1
	return float(shown) / count


# ----------------------------------------------------------- the switch --

func test_on_by_default_off_headless_and_by_the_switch() -> void:
	assert_true(Settings.transitions(), "on by default (the owner's H7)")
	assert_false(Settings.has_value(TileReveal.SETTING), "reading writes nothing")
	assert_false(TileReveal.wanted(), "headless: never — a test never waits on a picture")
	assert_null(TileReveal.make(TileReveal.LAIR_GRID, 0.4), "nothing made")
	var picture := Control.new()
	assert_null(TileReveal.zoom_in(picture), "nothing zoomed")
	picture.free()
	TileReveal.forced = 1
	assert_true(TileReveal.wanted())
	var made := TileReveal.make(TileReveal.LAIR_GRID, 0.4)
	assert_not_null(made)
	made.free()
	TileReveal.forced = 0
	assert_false(TileReveal.wanted())
	Settings.set_value(TileReveal.SETTING, false)
	assert_false(Settings.transitions(), "the Options' switch, off")


# ------------------------------------------------------------- the order --

func test_random_tiles_each_come_once_in_their_moment() -> void:
	var moments := TileReveal.moments(TileReveal.LAIR_GRID, TileReveal.Order.RANDOM, 4, 3, 11)
	assert_eq(moments.size(), 103 * 56, "every 5 × 5 tile of the 512 × 280 picture")
	var lowest := 255
	var highest := 0
	for value in moments:
		lowest = mini(lowest, value)
		highest = maxi(highest, value)
	assert_eq([lowest, highest], [1, 255], "from the first moment to the last")
	assert_ne(moments, TileReveal.moments(TileReveal.LAIR_GRID, TileReveal.Order.RANDOM, 4, 3, 12),
		"another roll, another order")
	var cover := _cover(TileReveal.LAIR_GRID, TileReveal.Order.RANDOM)
	cover.seek(0.25)
	var shown := 0
	for y in 56:
		for x in 103:
			if cover.revealed(Vector2i(x, y)):
				shown += 1
	assert_almost_eq(float(shown) / (103 * 56), 0.5, 0.01, "half the tiles at half the time")


func test_staggered_strips_sweep_from_left_to_right() -> void:
	# 1997's castle: 16 strips of 4 × 35 tiles, three at once — the leading
	# a tile a round, the next two, the trailing three: a strip is a sixth,
	# a half and the whole done after its first, second and third phase of
	# 16 + 3 − 1 = 18.
	var cover := _cover(TileReveal.CASTLE_GRID, TileReveal.Order.STAGGERED, 1.8)
	assert_eq(cover.grid, Vector2i(64, 35))
	cover.seek(0.9)
	assert_eq(_strip_done(cover, 0), 1.0, "at half time the first strip is whole")
	assert_eq(_strip_done(cover, 15), 0.0, "and the last has not begun")
	# A moment is a 255th of the whole (7 ms here, a 14th of a phase):
	# looked at just before and just after each phase's end, within that.
	cover.seek(0.09)
	assert_almost_eq(_strip_done(cover, 0), 0.9 / 6.0, 0.04, "near a phase: near a sixth of the first")
	assert_eq(_strip_done(cover, 1), 0.0, "the next not begun")
	cover.seek(0.19)
	assert_almost_eq(_strip_done(cover, 0), 1.0 / 6.0 + 0.9 * 2.0 / 6.0, 0.04, "near two: near half")
	assert_almost_eq(_strip_done(cover, 1), 0.9 / 6.0, 0.04, "the second drawing a tile a round")
	assert_eq(_strip_done(cover, 2), 0.0, "the third not begun")
	cover.seek(0.31)
	assert_eq(_strip_done(cover, 0), 1.0, "three phases: the first strip done")
	assert_almost_eq(_strip_done(cover, 1), 0.5 + 0.1 * 3.0 / 6.0, 0.04, "the second past half")
	assert_almost_eq(_strip_done(cover, 2), 1.0 / 6.0 + 0.1 * 2.0 / 6.0, 0.04, "the third past a sixth")


func test_a_delay_holds_every_tile_back() -> void:
	var cover := _cover(TileReveal.FACE_GRID, TileReveal.Order.RANDOM, 0.3)
	cover.delay = 0.2
	cover.seek(0.15)
	assert_eq(cover.progress(), 0.0, "the face waits for the zoom")
	assert_false(cover.revealed(Vector2i(0, 0)))
	cover.seek(0.35)
	assert_almost_eq(cover.progress(), 0.5, 0.001)


# ------------------------------------------------------------ the node --

func test_it_frees_itself_after_its_seconds_and_says_so_once() -> void:
	var cover := _cover(TileReveal.LAIR_GRID, TileReveal.Order.RANDOM, 0.4)
	var told := [0]
	cover.done.connect(func() -> void: told[0] += 1)
	assert_eq(cover.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it takes no input")
	assert_not_null(cover.material, "drawn through its shader")
	cover._process(0.3)
	assert_false(cover.is_over())
	cover._process(0.15)
	assert_true(cover.is_over(), "over after its 0.4 s")
	cover.finish()
	assert_eq(told[0], 1, "done once")
	await _frames(1)
	assert_false(is_instance_valid(cover), "and gone")


func test_a_slow_frame_before_it_does_not_eat_it() -> void:
	var cover := _cover(TileReveal.LAIR_GRID, TileReveal.Order.RANDOM, 0.4)
	cover.set_process(false)
	await get_tree().process_frame
	# The first frame after it was made, half a second long (the pane's
	# build): a thirtieth counted.
	cover._process(0.5)
	assert_false(cover.is_over(), "a half-second first frame counts a thirtieth")
	assert_lt(cover.progress(), 0.2)
	cover.finish()


func test_a_click_or_a_key_ends_it_and_goes_on() -> void:
	# The cover lies over a button: the click both ends the cover and
	# presses the button — nothing under a transition ever waits.
	TileReveal.forced = 1
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 400)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	var room := Control.new()
	room.size = Vector2(640, 400)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(room)
	var button := Button.new()
	button.text = "Leave"
	button.position = Vector2(100, 100)
	button.size = Vector2(120, 40)
	room.add_child(button)
	var pressed := [0]
	button.pressed.connect(func() -> void: pressed[0] += 1)
	var cover := TileReveal.cover(room, Rect2(0, 0, 640, 400), TileReveal.LAIR_GRID, 0.4)
	assert_not_null(cover)
	await _frames(1)
	var at := button.get_global_rect().get_center()
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	assert_true(cover.is_over(), "the click ended it")
	assert_eq(pressed[0], 1, "and pressed the button under it")
	var again := TileReveal.cover(button, Rect2(0, 0, 120, 40), TileReveal.FACE_GRID, 0.3)
	await _frames(1)
	var echo := _key(KEY_Y)
	echo.echo = true
	again._input(echo)
	assert_false(again.is_over(), "a key held down is not a new press")
	again._input(_key(KEY_Y))
	assert_true(again.is_over(), "a key ends it")


func test_the_zoom_grows_the_picture_about_its_middle() -> void:
	TileReveal.forced = 1
	var picture := Control.new()
	picture.size = Vector2(512, 280)
	add_child_autofree(picture)
	var zoom := TileReveal.zoom_in(picture)
	assert_not_null(zoom)
	assert_eq(picture.scale, Vector2(TileReveal.ZOOM_FROM, TileReveal.ZOOM_FROM), "1997's first blit: 2/8")
	assert_eq(picture.pivot_offset, Vector2(256, 140), "about its middle")
	assert_lt(picture.modulate.a, 1.0, "fading up from the frame's ground")
	zoom.seek(TileReveal.ZOOM_SECONDS / 2.0)
	assert_between(picture.scale.x, TileReveal.ZOOM_FROM, 1.0)
	assert_gt(picture.scale.x, 0.25 + 0.75 / 2.0, "eased out: more than halfway at half time")
	zoom._input(_key(KEY_SPACE))
	assert_eq(picture.scale, Vector2.ONE, "a key: the picture whole at once")
	assert_eq(picture.modulate.a, 1.0)
	assert_true(zoom.is_over())


func test_the_shader_cover_draws_what_it_hides() -> void:
	var cover := _cover(TileReveal.FACE_GRID, TileReveal.Order.RANDOM)
	assert_eq(cover._source_now(), Rect2(), "no picture: the ground")
	cover.before = ImageTexture.create_from_image(Image.create(1024, 560, false, Image.FORMAT_RGB8))
	assert_eq(cover._source_now(), Rect2(0, 0, 1024, 560), "the whole picture")
	cover.source = Rect2(392, 36, 240, 240)
	assert_eq(cover._source_now(), Rect2(392, 36, 240, 240), "its region")
	# The screen as it stood: the cover's place on it, in the window's
	# pixels.
	var screen := ImageTexture.create_from_image(Image.create(1920, 1080, false, Image.FORMAT_RGB8))
	cover.take_screen(screen)
	var canvas := cover.get_viewport_rect().size
	var placed := cover.get_global_rect()
	var pixels := Vector2(1920, 1080) / canvas
	assert_eq(cover.source, Rect2(placed.position * pixels, placed.size * pixels))
	assert_true(TileReveal.SHADER.contains("discard"), "a tile come is dropped")


# ------------------------------------------------- the world's dissolve --

func test_the_world_s_dissolve_is_one_of_them() -> void:
	var host := Control.new()
	add_child_autofree(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var quiet := RevealDissolve.over(host, null)
	assert_not_null(quiet, "headless the world screen still gets its overlay to place")
	await _frames(1)
	assert_false(is_instance_valid(quiet), "gone at once: the new view is simply there")
	TileReveal.forced = 1
	var cover := RevealDissolve.over(host, null)
	assert_true(cover is TileReveal)
	var area := cover.get_viewport_rect().size
	assert_eq(cover.grid, Vector2i(ceili(area.x / RevealDissolve.BLOCK), ceili(area.y / RevealDissolve.BLOCK)),
		"16-pixel squares over the screen")
	assert_eq(cover.seconds, RevealDissolve.SECONDS)
	assert_eq(cover.ground, Color.BLACK, "a new adventure's world comes out of black")
	cover._input(_key(KEY_ESCAPE))
	assert_true(cover.is_over(), "a key ends it")
