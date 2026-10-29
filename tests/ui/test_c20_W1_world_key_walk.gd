extends GutTest
## THE KEYS WALK THE HERO ON THE WORLD MAP (0.50.66, the owner's ruling of
## 2026-10-29: *"The arrow keys (and the keypad's 8 directions, two arrows
## for a diagonal) would walk the hero step by step while held, no
## pathfinding; clicks keep walking with pathfinding. Scrolling the view
## would move to W A S D only, plus the mouse drag."*). 1997's keys set the
## hero's heading (adventure_input.c 328–353: Up 2, PgUp 3, Right 4, PgDn 5,
## Down 6, End 7, Left 8, Home 1). Every key here is a real key event
## through the screen's viewport, the Input's own state held beside it; the
## world's frames are run by hand, a tick at a time.

const SAVES := "user://adventure_tests_c20_w1_key_walk"
## Every key a test may hold, let go after each.
const HELD := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN,
	KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
	KEY_W, KEY_A, KEY_S, KEY_D, KEY_CTRL, KEY_F3, KEY_SPACE, KEY_3]
## Where the roaming slots' lairs stand from the hero ([method _quiet_slots]).
const LAIRS := [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, -3),
	Vector2i(-3, 3)]


var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	Settings.clear_value(WorldHud.PACE_SETTING)
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.food = 50
	# No siege news to stop a walk; the clock still steps.
	screen.player.sieges = AdventurePlayer.SIEGES_NONE
	# One tick a frame from here ([method _run]).
	screen._tick_left = 0.0
	_quiet_slots()


func after_each() -> void:
	for code in HELD:
		var up := InputEventKey.new()
		up.keycode = code
		up.physical_keycode = code
		up.pressed = false
		Input.parse_input_event(up)
	Input.flush_buffered_events()
	Settings.clear_value(WorldHud.PACE_SETTING)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## Every roaming slot held by a lair three tiles from the hero — inside the
## ring, so nothing refills it, and beyond its reach, so none is met; set
## again before every tick ([method _run]), so the lairs keep their
## distance as the hero walks.
func _quiet_slots() -> void:
	var player := screen.player
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		var tile: Vector2i = player.tile() + LAIRS[slot]
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## [param ticks] of the world's frames, a tick each.
func _run(ticks: int) -> void:
	for i in ticks:
		_quiet_slots()
		screen._process(HeroWalk.TICK)


## A key held down or let go: the Input's state, and the event through the
## screen's viewport, where the world hears it.
func _hold(code: Key, down: bool, ctrl := false) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = down
	key.ctrl_pressed = ctrl
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	viewport.push_input(key.duplicate(), true)


## A key tapped: down and up before the world's next frame.
func _tap(code: Key) -> void:
	_hold(code, true)
	_hold(code, false)


func _middle(tile: Vector2i) -> Vector2i:
	return tile * 32 + Vector2i(16, 16)


## A STRAIGHT LINE OF LAND for a walk [param way] (1–8): a tile with
## [param length] land tiles after it that way, none of them a place, and
## (with [param plain]) the way a click finds there the line itself; the
## hero set down on its middle. Its first tile.
func _line(way: int, length: int, plain := false) -> Vector2i:
	var player := screen.player
	var step := Vector2i(ShandalarWorld.DX[way], ShandalarWorld.DY[way])
	var home := player.tile()
	for radius in range(0, 20):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var start := home + Vector2i(dx, dy)
				var ok := true
				for k in length + 1:
					var tile := start + step * k
					if not screen.world.is_land(tile.x, tile.y) or not screen.place_at(tile).is_empty() \
							or not VisitPane.describe(player, tile).is_empty():
						ok = false
						break
				# Land beyond the line too: a walk let go at its end stops
				# there, not at the sea.
				var beyond := start + step * (length + 1)
				if ok and not screen.world.is_land(beyond.x, beyond.y):
					ok = false
				if ok and plain:
					player.position = _middle(start)
					var way_found := screen.walk.plan(start + step * length)
					var straight: Array[Vector2i] = []
					for k in length + 1:
						straight.append(start + step * k)
					ok = way_found == straight
				if ok:
					player.position = _middle(start)
					screen.view.hero = Vector2(player.position)
					screen.view.camera = screen.view.hero
					_quiet_slots()
					return start
	return Vector2i(-1, -1)


## The ticks run until the hero stands, at most [param most].
func _until_standing(most := 400) -> int:
	for i in most:
		if not screen.walk.is_walking():
			return i
		_run(1)
	return most


## Held [param code] until the walk's next tile is [param last], then let
## go; the hero walks on to its middle and stands.
func _hold_to(code: Key, last: Vector2i) -> void:
	_hold(code, true)
	_run_until_bound_for(last)
	_hold(code, false)
	_until_standing()


## The ticks run until the walk's next tile is [param last].
func _run_until_bound_for(last: Vector2i) -> void:
	for i in 600:
		if screen.walk.destination == last:
			return
		_run(1)


# ----------------------------------------------------------- the walk --

func test_a_held_right_walks_tile_by_tile_and_stops_on_release() -> void:
	var player := screen.player
	# Right on the screen is the world's way 4 (1997: VK_RIGHT, 0x4d00 → 4).
	var start := _line(4, 4)
	assert_gt(start.x, -1, "control: a line of land to walk")
	_hold(KEY_RIGHT, true)
	assert_true(screen.walk.is_walking(), "Right: the hero walks at once")
	assert_true(screen.walk.by_keys, "the keys' walk, no way found")
	var middles: Array[Vector2i] = []
	for i in 600:
		_run(1)
		if screen.walk.at_middle:
			middles.append(player.tile())
		if middles.size() == 3:
			break
	assert_eq(middles, [start + Vector2i(1, 1), start + Vector2i(2, 2), start + Vector2i(3, 3)] as Array[Vector2i],
		"held: one tile after another, the way Right points")
	assert_true(screen.walk.is_walking(), "still held: walking on, no stop at a tile's middle")
	assert_ne(player.step, 0, "the walking figure, not the standing one, at the middle")
	_hold(KEY_RIGHT, false)
	_until_standing()
	assert_eq(player.tile(), start + Vector2i(4, 4), "let go: the tile under way walked to its end")
	assert_eq(player.position, _middle(start + Vector2i(4, 4)), "and stood on its middle")
	assert_eq(player.facing, 4, "facing the way walked")
	var at := player.position
	_run(40)
	assert_eq(player.position, at, "let go, the hero stands")


func test_a_tap_walks_one_tile() -> void:
	var start := _line(8, 2)
	assert_gt(start.x, -1, "control: land to the left")
	_tap(KEY_LEFT)
	_until_standing()
	assert_eq(screen.player.position, _middle(start + Vector2i(-1, -1)), "Left tapped: one tile, the way Left points")


func test_up_and_right_held_walk_the_diagonal_between() -> void:
	var player := screen.player
	# Up is way 2, Right way 4: together way 3, as 1997's PgUp.
	var start := _line(3, 3)
	assert_gt(start.x, -1, "control: a line of land up and right")
	_hold(KEY_UP, true)
	_run(1)
	_hold(KEY_RIGHT, true)
	assert_eq(screen.walk.keyed, 3, "two arrows: the way between them")
	_run_until_bound_for(start + Vector2i(2, 0))
	_hold(KEY_UP, false)
	_hold(KEY_RIGHT, false)
	_until_standing()
	assert_eq(player.position, _middle(start + Vector2i(2, 0)), "Up and Right: up-right on the screen from the first step")
	assert_eq(player.facing, 3)


func test_the_keypad_and_1997_s_diagonal_keys_walk() -> void:
	var player := screen.player
	for pair in [[KEY_KP_9, 3], [KEY_PAGEUP, 3], [KEY_HOME, 1], [KEY_KP_7, 1], [KEY_END, 7], [KEY_KP_1, 7],
			[KEY_PAGEDOWN, 5], [KEY_KP_3, 5], [KEY_KP_8, 2], [KEY_KP_6, 4], [KEY_KP_2, 6], [KEY_KP_4, 8]]:
		var way: int = pair[1]
		var start := _line(way, 2)
		assert_gt(start.x, -1, "control: land for way %d" % way)
		_tap(pair[0])
		_until_standing()
		var step := Vector2i(ShandalarWorld.DX[way], ShandalarWorld.DY[way])
		assert_eq(player.position, _middle(start + step), "%s walks way %d" % [OS.get_keycode_string(pair[0]), way])


func test_the_sea_stops_the_keys() -> void:
	var player := screen.player
	# A land tile with the sea beside it, Right's way.
	var start := Vector2i(-1, -1)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			if screen.world.is_land(x, y) and not screen.world.is_land(x + 1, y + 1) \
					and VisitPane.describe(player, Vector2i(x, y)).is_empty():
				start = Vector2i(x, y)
				break
		if start.x >= 0:
			break
	assert_gt(start.x, -1, "control: a shore")
	player.position = _middle(start)
	_quiet_slots()
	_hold(KEY_RIGHT, true)
	_run(80)
	assert_eq(player.position, _middle(start), "the sea ahead: the hero stands on the last land")
	assert_false(screen.walk.is_walking())
	_hold(KEY_RIGHT, false)


func test_an_arrow_gives_up_a_click_s_walk() -> void:
	var player := screen.player
	var start := _line(4, 6)
	assert_gt(start.x, -1, "control: land to walk")
	assert_true(screen.walk_to_tile(start + Vector2i(6, 6)), "control: a click's walk")
	_run(5)
	assert_true(screen.walk.is_walking() and not screen.walk.by_keys, "control: walking the click's way")
	# Down is way 6 (−1, +1): one tile that way from the start's middle the
	# hero had hardly left, or from the middle the step under way reaches
	# (itself, when the sea lies that way).
	var ahead: Vector2i = screen.walk.path[0]
	var ends := [_middle(start + Vector2i(-1, 1)), _middle(ahead + Vector2i(-1, 1)), _middle(ahead)]
	_tap(KEY_DOWN)
	assert_true(screen.walk.by_keys, "an arrow: the keys' walk, the click's way given up")
	_until_standing()
	assert_true(player.position in ends, "one tile the way Down points, not the click's place: %s" % player.position)
	assert_ne(player.tile(), start + Vector2i(6, 6))


func test_a_click_still_walks_with_the_way_found() -> void:
	var start := _line(4, 3)
	assert_gt(start.x, -1)
	assert_true(screen.walk_to_tile(start + Vector2i(3, 3)))
	assert_false(screen.walk.by_keys, "a click: the way found")
	_until_standing()
	assert_eq(screen.player.tile(), start + Vector2i(3, 3))


func test_food_and_the_clocks_step_as_for_a_click_s_walk() -> void:
	var player := screen.player
	var start := _line(4, 5, true)
	assert_gt(start.x, -1, "control: a straight line the way-finder walks too")
	var target := start + Vector2i(5, 5)
	player.monster_timer = 1
	player.food = 9
	player.quest_timer = 0
	player.siege_timer = 0
	_hold_to(KEY_RIGHT, target)
	assert_eq(player.position, _middle(target), "control: the keys walked there")
	var keyed := [player.food, player.quest_timer, player.siege_timer, player.monster_timer, player.facing]
	assert_gt(player.quest_timer, 0, "control: the quest clock stepped")
	assert_gt(player.siege_timer, 0, "control: the siege clock stepped")
	assert_lt(player.food, 9, "control: food eaten")
	# The same walk by a click, from the same moment.
	player.position = _middle(start)
	player.monster_timer = 1
	player.food = 9
	player.quest_timer = 0
	player.siege_timer = 0
	screen._tick_left = 0.0
	_quiet_slots()
	assert_true(screen.walk_to_tile(target))
	_until_standing()
	assert_eq(player.position, _middle(target))
	assert_eq([player.food, player.quest_timer, player.siege_timer, player.monster_timer, player.facing], keyed,
		"the same food, quest and siege clocks, ticks and facing as a click's walk")


func test_walking_onto_a_town_arrives_there_and_stops() -> void:
	var player := screen.player
	# A town with land beside it, Right's way (−1, −1) from it.
	var town := -1
	var beside := Vector2i(-1, -1)
	for slot in screen.world.sites.size():
		var site: Dictionary = screen.world.sites[slot]
		if int(site["type"]) != ShandalarWorld.TOWN or TownStatus.ruled(screen.world, slot):
			continue
		var tile := Vector2i(int(site["x"]), int(site["y"]))
		var from := tile - Vector2i(1, 1)
		if screen.world.is_land(from.x, from.y) and VisitPane.describe(player, from).is_empty() \
				and screen.world.is_land(tile.x + 1, tile.y + 1):
			town = slot
			beside = from
			break
	assert_gt(town, -1, "control: a town with land beside it")
	player.position = _middle(beside)
	_quiet_slots()
	assert_false(TownStatus.visited(screen.world, town), "control: never visited")
	_hold(KEY_RIGHT, true)
	for i in 200:
		if screen.visiting():
			break
		_run(1)
	assert_true(screen.visiting(), "walked onto the town: its pane, as a click's walk opens it")
	assert_eq(int(screen._visit.place["slot"]), town)
	assert_eq(player.position, _middle(beside + Vector2i(1, 1)), "on the town's middle")
	assert_true(TownStatus.visited(screen.world, town), "arrived: visited")
	assert_false(screen.walk.is_walking(), "the walk stops there (1997 dropped the heading)")
	# Right still held as the pane is left: the hero stays.
	screen._visit.choose("leave")
	await _frames(3)
	var seller := screen.find_child("WorldMagicPane", true, false) as WorldMagicPane
	if seller != null and not seller.is_queued_for_deletion():
		seller.done.emit()
		await _frames(3)
	assert_false(screen.modal(), "control: the town left")
	_run(60)
	assert_eq(player.position, _middle(beside + Vector2i(1, 1)), "the key held through the pane walks no one")
	_hold(KEY_RIGHT, false)


# ------------------------------------------------------- panes and keys --

func test_nothing_walks_under_a_pane_nor_after_it_while_held() -> void:
	var player := screen.player
	var start := _line(4, 4)
	assert_gt(start.x, -1)
	assert_not_null(screen.show_city_list(), "control: a pane holds the world")
	_hold(KEY_RIGHT, true)
	_run(60)
	assert_eq(player.position, _middle(start), "under the pane: no step")
	screen._close_pane(screen._city_list)
	await _frames(2)
	screen._shield_until = 0
	assert_false(screen.modal(), "control: closed")
	_run(60)
	assert_eq(player.position, _middle(start), "held on as it closed: no step until pressed again")
	_hold(KEY_RIGHT, false)
	_hold(KEY_RIGHT, true)
	_run(5)
	assert_ne(player.position, _middle(start), "pressed again: walking")
	_hold(KEY_RIGHT, false)


func test_a_pane_opened_while_walking_stops_the_held_walk() -> void:
	var player := screen.player
	var start := _line(4, 5)
	assert_gt(start.x, -1)
	_hold(KEY_RIGHT, true)
	_run(10)
	assert_true(screen.walk.is_walking(), "control: walking")
	_hold(KEY_F3, true)
	_hold(KEY_F3, false)
	assert_true(screen.city_list_shown(), "control: F3, the city list over the world")
	var at := player.position
	_run(30)
	assert_eq(player.position, at, "the world waits under it")
	screen._close_pane(screen._city_list)
	await _frames(2)
	screen._shield_until = 0
	_run(120)
	assert_eq(player.position, _middle(start + Vector2i(1, 1)),
		"closed, Right still held: the tile under way ended, no more")
	_hold(KEY_RIGHT, false)


func test_the_map_and_the_options_hold_the_keys() -> void:
	var player := screen.player
	var start := _line(4, 2)
	assert_gt(start.x, -1)
	screen.toggle_map()
	_tap(KEY_RIGHT)
	_run(40)
	assert_eq(player.position, _middle(start), "the map up: no walk")
	screen.toggle_map()
	screen._shield_until = 0
	screen.hud.toggle_options_at(Vector2(600, 300))
	assert_true(screen.hud.options_shown(), "control: the options")
	_tap(KEY_RIGHT)
	assert_false(screen.hud.options_shown(), "an arrow closes them, as a click on the land does")
	_run(40)
	assert_eq(player.position, _middle(start), "and walks no one")
	_hold(KEY_RIGHT, true, true)
	_run(40)
	assert_eq(player.position, _middle(start), "Ctrl held (Ctrl+S saves): no walk")
	_hold(KEY_RIGHT, false)


func test_space_stops_the_keys_walk() -> void:
	var player := screen.player
	var start := _line(4, 4)
	assert_gt(start.x, -1)
	_hold(KEY_RIGHT, true)
	_run(8)
	_hold(KEY_SPACE, true)
	_hold(KEY_SPACE, false)
	var at := player.position
	_run(60)
	assert_eq(player.position, at, "Space: the hero stands, the arrow still held")
	_hold(KEY_RIGHT, false)


# --------------------------------------------------- looking and casting --

func test_the_arrows_look_no_more_and_w_a_s_d_still_do() -> void:
	var camera := screen.view.camera
	for code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_PAGEDOWN]:
		Input.parse_input_event(_key_event(code, true))
		Input.flush_buffered_events()
		screen._look_with_keys(0.5)
		Input.parse_input_event(_key_event(code, false))
		Input.flush_buffered_events()
		assert_eq(screen.view.camera, camera, "%s walks; it looks no more" % OS.get_keycode_string(code))
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		camera = screen.view.camera
		Input.parse_input_event(_key_event(code, true))
		Input.flush_buffered_events()
		screen._look_with_keys(0.5)
		Input.parse_input_event(_key_event(code, false))
		Input.flush_buffered_events()
		assert_ne(screen.view.camera, camera, "%s looks around" % OS.get_keycode_string(code))


func test_the_top_row_casts_and_the_keypad_walks() -> void:
	var player := screen.player
	player.world_magics.append("Quickening")
	player.amulets["green"] = 3
	var start := _line(5, 2)
	assert_gt(start.x, -1, "control: land the way the keypad's 3 points")
	_tap(KEY_KP_3)
	assert_eq(player.quickening, 0, "the keypad's 3: no World Magic (1997's keypad never cast)")
	_until_standing()
	assert_eq(player.position, _middle(start + Vector2i(0, 1)), "it walks, as 1997's PgDn")
	_tap(KEY_3)
	assert_gt(player.quickening, 0, "the top row's 3: Quickening")


func test_the_help_says_the_arrows_walk() -> void:
	var keys := "\n".join(screen.hud.key_lines())
	assert_string_contains(keys, "Arrows: walk your hero while held")
	assert_string_contains(keys, "Drag or W A S D: look around")
	assert_false(keys.contains("Drag or arrows"), "the arrows look no more")


func _key_event(code: Key, down: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = down
	return key
