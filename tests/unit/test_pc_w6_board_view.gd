extends GutTest
## THE BOARD DRAWN AND HEARD (part C, stage C2, W6): [DungeonView]'s 1997
## rules — the cell order, the back and front sprites (dE:1240–1286), the
## rock tops (with 1997's cull slip fixed), what stands in a cell, the
## figures' facing (dE:1333–1341), the walk's frames (dE:1463–1511), the
## plaque — the white castle's floor marks [ours, the owner's ruling], and
## [DungeonSound]'s ambience (dE:416–447) on its own dice, never the board's
## or the adventure's.

var player: AdventurePlayer


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	DungeonView.frame_seconds = 0.0


func after_each() -> void:
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS


## A hand-made board: [param open] cells open, [param events] `{cell:
## event}`, the hero at [param hero] and looking round.
func _hand_board(open: Array, events := {}, hero := DungeonBoard.START) -> DungeonBoard:
	var board := DungeonBoard.new()
	board.cells.resize(DungeonBoard.CELLS)
	board.cells.fill(0)
	board.depth.resize(DungeonBoard.CELLS)
	board.depth.fill(0)
	board.looks.resize(DungeonBoard.CELLS)
	board.looks.fill(0)
	for at in open:
		board.cells[at.x * DungeonBoard.HEIGHT + at.y] = DungeonBoard.OPEN
	for at in events:
		board.cells[at.x * DungeonBoard.HEIGHT + at.y] = DungeonBoard.OPEN | (int(events[at]) << DungeonBoard.EVENT_SHIFT)
	board.dice = MsvcRandom.new(1)
	board.monsters = [1, 2, 3, 4, 5] as Array[int]
	board.sheet = "dungeon_tiles_1"
	board.hero = hero
	board.reveal(board.hero)
	return board


func _view(board: DungeonBoard) -> DungeonView:
	var view := DungeonView.new()
	view.board = board
	add_child_autofree(view)
	return view


# ------------------------------------------------------------ the rules --

func test_the_cells_are_drawn_back_to_front() -> void:
	var order := DungeonView.draw_order()
	assert_eq(order.size(), DungeonBoard.CELLS)
	assert_eq(order[0], Vector2i(14, 0), "x from 14 down")
	assert_eq(order[1], Vector2i(14, 1), "y from 0 up")
	assert_eq(order[12], Vector2i(14, 12))
	assert_eq(order[13], Vector2i(13, 0))
	assert_eq(order[order.size() - 1], Vector2i(0, 12))


func test_the_back_and_front_sprites() -> void:
	assert_eq(DungeonView.back_frame(false, false, 0), 0, "a floor, look 0")
	assert_eq(DungeonView.back_frame(true, false, 0), 1, "a wall up-right")
	assert_eq(DungeonView.back_frame(false, true, 0), 2, "a wall up-left")
	assert_eq(DungeonView.back_frame(true, true, 1), 7, "both, look 1 (+4)")
	assert_eq(DungeonView.back_frame(true, false, 2), 25, "look 2 (+24)")
	assert_eq(DungeonView.back_frame(false, true, 3), 30, "look 3 (+28)")
	assert_eq(DungeonView.front_frame(false, false, 2), 12, "an even row's plain floor")
	assert_eq(DungeonView.front_frame(true, false, 2), 13, "a wall down-right")
	assert_eq(DungeonView.front_frame(false, true, 2), 14, "a wall down-left")
	assert_eq(DungeonView.front_frame(true, true, 3), 19, "both, an odd row (+4)")


func test_a_seen_cell_reads_its_walls_and_the_grid_s_edge() -> void:
	# A corridor along row 11 from (5, 11) to (9, 11); the hero at (7, 11).
	var open := [Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11), Vector2i(8, 11), Vector2i(9, 11),
		DungeonBoard.ENTRANCE]
	var board := _hand_board(open)
	var view := _view(board)
	var middle := view.cell_look(Vector2i(7, 11))
	# x + 1 open, y − 1 solid: back 2; y + 1 the entrance (open), x − 1 open:
	# front 12, odd row +4.
	assert_eq(int(middle["back"]), 2)
	assert_eq(int(middle["front"]), 16)
	var end := view.cell_look(Vector2i(9, 11))
	assert_eq(int(end["back"]), 3, "the corridor's end: walls up-right and up-left")
	assert_eq(int(end["front"]), 17, "a wall down-right, odd row")
	var door := view.cell_look(DungeonBoard.ENTRANCE)
	assert_true(bool(door["exit"]), "the entrance says Exit")
	assert_eq(int(door["front"]) & 1, 1, "the last row's down-right edge is a wall (off the grid)")


func test_rock_tops_need_two_seen_neighbours_and_the_cull_slip_is_gone() -> void:
	var open := [Vector2i(11, 9), Vector2i(11, 10), Vector2i(11, 11), Vector2i(12, 11), Vector2i(13, 11),
		Vector2i(13, 10), Vector2i(13, 9), Vector2i(12, 9)]
	var board := _hand_board(open, {}, Vector2i(11, 11))
	# Look round from every corner of the ring, so all of it is seen.
	for at in open:
		board.reveal(at)
	var view := _view(board)
	assert_true(view.shows_rock(Vector2i(12, 10)), "(12, 10): four seen neighbours — drawn [ours: 1997's cull hid it]")
	assert_true(view.cell_look(Vector2i(12, 10)).has("rock"))
	assert_false(view.shows_rock(Vector2i(10, 11)), "one seen neighbour: nothing")
	assert_false(view.shows_rock(Vector2i(11, 10)), "an open cell has no rock top")


func test_what_stands_in_a_seen_cell() -> void:
	var open := [Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11), Vector2i(8, 11), Vector2i(9, 11)]
	var events := {Vector2i(5, 11): DungeonBoard.DICE, Vector2i(6, 11): DungeonBoard.SCROLL,
		Vector2i(8, 11): DungeonBoard.TREASURE, Vector2i(9, 11): 4}
	var board := _hand_board(open, events)
	var view := _view(board)
	assert_eq(String(view.cell_look(Vector2i(6, 11))["stands"]), "scroll")
	assert_eq(String(view.cell_look(Vector2i(8, 11))["stands"]), "chest")
	var room := view.cell_look(Vector2i(9, 11))
	assert_eq(String(room["stands"]), "creature", "event 4: room slot 1")
	assert_eq(int(room["row"]), 2, "its creature")
	assert_eq(String(view.cell_look(Vector2i(5, 11))["stands"]), "dice",
		"the dice behind the scroll: in a straight open line, seen (dE:1420–1460)")
	assert_eq(view.cell_look(Vector2i(7, 9)), {}, "a cell never seen draws nothing")
	board.cells[6 * DungeonBoard.HEIGHT + 11] = DungeonBoard.PASSED
	assert_eq(String(view.cell_look(Vector2i(6, 11))["stands"]), "", "a cell passed shows nothing")


func test_a_creature_faces_the_way_in() -> void:
	var depth := {Vector2i(5, 5): 9, Vector2i(5, 6): 8, Vector2i(6, 5): 10, Vector2i(5, 4): 0}
	var depth_of := func(at: Vector2i) -> int: return int(depth.get(at, 0))
	assert_eq(DungeonView.facing(depth_of, Vector2i(5, 5)), 5, "towards +y, where the entrance is nearer")
	depth[Vector2i(4, 5)] = 7
	assert_eq(DungeonView.facing(depth_of, Vector2i(5, 5)), 7, "the last nearer of 1, 3, 5, 7 wins")
	assert_eq(DungeonView.facing(func(_at: Vector2i) -> int: return 0, Vector2i(2, 2)), 5, "none nearer: 5")
	assert_eq(WorldArt.creature_frame(1, 0), 15, "−y: row 3")
	assert_eq(WorldArt.creature_frame(7, 0), 5, "−x: row 1")


func test_the_walk_s_frames() -> void:
	var whole := DungeonView.walk_frames(3)
	assert_eq(whole.size(), 8)
	var steps := []
	for frame in whole:
		steps.append(int(frame["step"]))
	assert_eq(steps, [2, 3, 4, 1, 2, 3, 4, 0], "1997's walking steps")
	assert_eq(Vector2(whole[7]["offset"]), Vector2(32, -16), "+x: ends on the next cell's anchor, not 4 short")
	assert_eq(Vector2(DungeonView.walk_frames(1)[0]["offset"]), Vector2(-4, -2))
	assert_eq(Vector2(DungeonView.walk_frames(5)[0]["offset"]), Vector2(4, 2))
	assert_eq(Vector2(DungeonView.walk_frames(7)[0]["offset"]), Vector2(-4, 2))
	var half := DungeonView.walk_frames(5, true)
	assert_eq(half.size(), 4, "half way into an event")
	assert_eq(int(half[3]["step"]), 1, "ends on step 1")
	assert_eq(Vector2(DungeonBoard.cell_to_page(Vector2i(7, 12)) - DungeonBoard.cell_to_page(Vector2i(7, 11))),
		Vector2(32, 16), "a cell is 8 frames of (4, 2)")


func test_a_walk_ends_on_the_cell_and_a_half_walk_waits_half_way() -> void:
	var open := [Vector2i(6, 11), Vector2i(7, 11), Vector2i(8, 11), DungeonBoard.ENTRANCE]
	var board := _hand_board(open, {Vector2i(8, 11): DungeonBoard.DICE})
	var view := _view(board)
	var calls := []
	view.walk(Vector2i(7, 11), 7, 0, 8, func() -> void: calls.append("whole"))
	assert_eq(calls, ["whole"], "no frame time: at once")
	assert_eq(view.hero_point(), Vector2(DungeonBoard.cell_to_page(board.hero)), "standing on the hero's cell")
	view.walk(Vector2i(7, 11), 3, 0, 4, func() -> void: calls.append("half"))
	assert_eq(view.hero_point(), Vector2(DungeonBoard.cell_to_page(Vector2i(7, 11))) + Vector2(16, -8),
		"half way into the dice's cell, waiting")
	assert_eq(view.hero_step(), 1)
	view.stand()
	assert_eq(view.hero_step(), 0)


func test_the_walk_takes_1997_s_time() -> void:
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS
	var board := _hand_board([Vector2i(7, 11), Vector2i(8, 11)])
	var view := _view(board)
	var done := []
	view.walk(Vector2i(7, 11), 3, 0, 8, func() -> void: done.append(true))
	assert_true(view.walking())
	view._process(0.066 * 7.5)
	assert_true(view.walking(), "seven frames in: still walking")
	view._process(0.066)
	assert_false(view.walking(), "eight frames of 66 ms: one cell")
	assert_eq(done, [true])


func test_the_plaque_grows_with_the_name() -> void:
	assert_eq(DungeonView.plaque_middles(20.0), 0)
	assert_eq(DungeonView.plaque_middles(29.0), 0, "29 + 24n at least the width")
	assert_eq(DungeonView.plaque_middles(30.0), 1)
	assert_eq(DungeonView.plaque_middles(150.0), 6)
	assert_eq(DungeonView.plaque_left(6), 208.0, "320 − 12n − 40")


func test_a_click_on_a_figure_is_a_click_on_its_room() -> void:
	var open := [Vector2i(7, 9), Vector2i(7, 10), Vector2i(7, 11), DungeonBoard.ENTRANCE]
	var board := _hand_board(open, {Vector2i(7, 9): 3})
	var view := _view(board)
	var figure := view.figure_rect(Vector2i(7, 9))
	assert_true(figure.has_area(), "the creature's figure (its sheet's, or the plain disc)")
	assert_lt(figure.get_center().y, float(DungeonBoard.cell_to_page(Vector2i(7, 9)).y), "above its floor")
	assert_eq(view.cell_at(figure.get_center()), Vector2i(7, 9), "a click on the body is a click on its room")
	assert_eq(view.cell_at(Vector2(DungeonBoard.cell_to_page(Vector2i(7, 11)))), Vector2i(7, 11), "a floor")


func test_the_board_s_first_look_is_drawn_from_the_board_entered() -> void:
	var setup := DungeonDoors.enter(player, 7)
	var board := DungeonBoard.enter(player, setup, 4242)
	var view := _view(board)
	var start := view.cell_look(DungeonBoard.START)
	assert_true(start.has("back"), "the start seen")
	assert_true(bool(view.cell_look(DungeonBoard.ENTRANCE)["exit"]))
	for at in DungeonView.draw_order():
		var look := view.cell_look(at)
		if look.has("back"):
			assert_true(board.seen(at) and board.is_open(at), "%s drawn only when seen and open" % at)


# --------------------------------------------- the white castle's floor --

func test_the_white_castle_s_floor_is_as_1997_showed_it() -> void:
	# The owner's ruling of 2026-10-28: frame 16's mark on the odd rows only;
	# the looks' marks the front sprite paints over stay hidden — the white
	# castle drawn as every sheet is.
	var open := [Vector2i(7, 11), Vector2i(7, 10), Vector2i(6, 11), Vector2i(6, 10), DungeonBoard.ENTRANCE]
	var board := _hand_board(open)
	board.reveal(Vector2i(7, 10))
	board.sheet = DungeonView.WHITE
	board.castle = true
	board.color = 5
	var view := _view(board)
	assert_eq(int(view.cell_look(Vector2i(7, 10))["front"]), 12, "an even row: the plain floor repainted")
	assert_eq(int(view.cell_look(Vector2i(7, 11))["front"]), 16, "an odd row: frame 16, its mark")
	assert_false(view.has_method("white_mark"), "no mark drawn apart from the sheet's own frames")
	var sheet := view.art.texture(DungeonView.WHITE)
	if sheet == null:
		pass_test("no 1997 skin: the white castle is drawn plain")
		return
	# Measured on the sheet's 1997 pixels: 12 is the plain floor, 16 the floor
	# with its mark, and the looks' marks (frames 4, 28) lie under them.
	var one := GameSkin.original(sheet)
	var plain := _floor_differences(one, view.art.frame_rect(DungeonView.WHITE, 0),
		view.art.frame_rect(DungeonView.WHITE, 12))
	var marked := _floor_differences(one, view.art.frame_rect(DungeonView.WHITE, 0),
		view.art.frame_rect(DungeonView.WHITE, 16))
	var look := _floor_differences(one, view.art.frame_rect(DungeonView.WHITE, 0),
		view.art.frame_rect(DungeonView.WHITE, 4))
	assert_eq(plain, 0, "frame 12 repaints the plain floor: a back mark under it is hidden")
	assert_between(marked, 60, 160, "frame 16 carries its own mark (109 pixels): the one 1997 showed")
	assert_gt(look, 60, "look 1's mark exists in the sheet — and is painted over")


## How many of [param a]'s opaque floor pixels differ in frame [param b] of
## image [param img].
func _floor_differences(img: Image, a: Rect2, b: Rect2) -> int:
	var out := 0
	for y in int(a.size.y):
		for x in int(a.size.x):
			var floor := img.get_pixel(int(a.position.x) + x, int(a.position.y) + y)
			if floor.a < 0.5:
				continue
			if not floor.is_equal_approx(img.get_pixel(int(b.position.x) + x, int(b.position.y) + y)):
				out += 1
	return out


# ------------------------------------------------------------ the sound --

func test_the_ambience_never_repeats_and_bursts_the_drip() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 1997
	var state := {"last": 1, "repeats": 0}
	var bursts := 0
	for i in 400:
		var before := state
		state = DungeonSound.next(dice, state)
		var sound := int(state["play"])
		assert_between(int(state["volume"]), 80, 99)
		assert_between(int(state["pan"]), -50, 49)
		if int(before["last"]) == DungeonSound.BURSTING and int(before["repeats"]) > 0:
			assert_eq(sound, DungeonSound.BURSTING, "a burst's repeat")
			assert_eq(int(state["repeats"]), int(before["repeats"]) - 1)
			assert_between(int(state["wait"]), 30, 89)
			continue
		assert_ne(sound, int(before["last"]), "never the one just played")
		if i == 0:
			assert_ne(sound, 1, "the first is never Damb1")
		if sound == DungeonSound.BURSTING:
			bursts += 1
			assert_between(int(state["repeats"]), 2, 4, "a burst of 2–4 more")
			assert_between(int(state["wait"]), 60, 89)
		else:
			assert_eq(int(state["repeats"]), 0)
			assert_between(int(state["wait"]), 120, 209)
	assert_gt(bursts, 10, "the drip comes in bursts")


func test_the_ambience_waits_and_counts_through_a_duel() -> void:
	var sound := DungeonSound.new()
	add_child_autofree(sound)
	sound.rng.seed = 5
	sound.start()
	var first := int(sound.state["wait"])
	assert_between(first, 90, 179, "the first wait: 3.0–5.9 s")
	sound._process(DungeonSound.TICK * (first - 1))
	assert_eq(sound.played.size(), 0, "not yet")
	sound.pause_for_duel()
	sound._process(DungeonSound.TICK * 400)
	assert_eq(sound.played.size(), 0, "nothing while a duel holds the board")
	sound.resume()
	sound._process(0.0)
	assert_eq(sound.played.size(), 1, "overdue: at once after the duel, as 1997's")
	sound.stop()
	sound._process(DungeonSound.TICK * 400)
	assert_eq(sound.played.size(), 1, "the board left: quiet")


func test_listening_never_moves_the_board_s_or_the_adventure_s_dice() -> void:
	var setup := DungeonDoors.enter(player, 7)
	var board := DungeonBoard.enter(player, setup, 4242)
	var board_dice := board.dice.state
	var adventure_dice := player.dice
	var sound := DungeonSound.new()
	add_child_autofree(sound)
	sound.start()
	for i in 60:
		sound._process(1.0)
	assert_gt(sound.played.size(), 5, "a minute of ambience")
	assert_eq(board.dice.state, board_dice, "the board's dice untouched")
	assert_eq(player.dice, adventure_dice, "the adventure's dice untouched")


func test_the_bed_is_a_seamless_loop() -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(2000)
	wav.data = data
	var loop := DungeonSound.looped(wav) as AudioStreamWAV
	assert_eq(loop.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(loop.loop_begin, 0)
	assert_eq(loop.loop_end, 1000, "the whole sample: 2000 bytes of 16-bit mono")
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "the skin's own stream untouched")


func test_the_rooms_left_words() -> void:
	assert_eq(DungeonPane.rooms_words({"creatures": 4, "treasures": 1, "dice": 2, "scrolls": 0}),
		"Rooms left: 4 creatures · 1 treasure · 2 dice")
	assert_eq(DungeonPane.rooms_words({"creatures": 1, "treasures": 0, "dice": 0, "scrolls": 1}),
		"Rooms left: 1 creature · 1 scroll")
	assert_eq(DungeonPane.rooms_words({}), DungeonPane.ALL_CLEARED)


func test_what_a_step_newly_sees_shows_as_the_walk_ends_and_fades_in() -> void:
	TileReveal.forced = 1
	var open := [Vector2i(7, 11), Vector2i(7, 10), Vector2i(6, 10), Vector2i(5, 10), DungeonBoard.ENTRANCE]
	var board := _hand_board(open)
	var view := _view(board)
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS
	var before := board.cells.duplicate()
	var went := board.step(DungeonBoard.UP_LEFT)
	assert_eq(String(went["kind"]), "moved")
	view.hold_cells(before)
	view.walk(DungeonBoard.START, DungeonBoard.UP_LEFT, 0, 8)
	assert_true(board.seen(Vector2i(6, 10)), "control: the board saw the corridor at once")
	assert_eq(view.cell_look(Vector2i(6, 10)), {}, "drawn only as the walk ends (1997's redraw after it)")
	view._process(0.066 * 8.5)
	assert_false(view.walking())
	assert_true(view.cell_look(Vector2i(6, 10)).has("back"), "shown now")
	assert_lt(view._alpha(Vector2i(6, 10)), 1.0, "fading in [QoL]")
	assert_eq(view._alpha(Vector2i(7, 11)), 1.0, "what was seen stays as it was")
	view._process(DungeonView.FRESH_SECONDS + 0.01)
	assert_eq(view._alpha(Vector2i(6, 10)), 1.0, "whole after a fifth of a second")
	TileReveal.forced = -1
