extends GutTest
## THE WORLD'S INPUT (the 0.50.66 bug campaign, h2-2, h2-3, h2-4), through
## the screen's own viewport with real events, the world's frames run by
## hand:
##  - a walking key pressed anew in the half second after a pane closed
##    (the shield, [constant WorldScreen.AFTER_PANE_MS]) was swallowed, and
##    held it walked no one: now it walks; a key held through the close
##    (its repeats) still walks no one, and the shield's other keys stay
##    shielded;
##  - a click's walk stopped on its first tile left its path arrows at full
##    strength: given up, the hover preview looked for anew;
##  - with a pad or a finger the place under the pointer was looked for at
##    the hidden system mouse whenever the view moved: now where the
##    pointer's last event put it.

const SAVES := "user://adventure_tests_c21_x1_input"
const HELD := [KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN,
	KEY_SPACE, KEY_Q]
const LAIRS := [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, -3),
	Vector2i(-3, 3)]

var viewport: SubViewport
var screen: WorldScreen
## GUT's own panel over the window, put away while a test points in it.
var _gut_layer: CanvasLayer


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	Settings.clear_value(WorldHud.PACE_SETTING)
	viewport = null
	screen = null
	_gut_layer = null


func after_each() -> void:
	if _gut_layer != null:
		_gut_layer.visible = true
	for code in HELD:
		var up := InputEventKey.new()
		up.keycode = code
		up.physical_keycode = code
		up.pressed = false
		Input.parse_input_event(up)
	Input.flush_buffered_events()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## The world screen, in a viewport of its own — or, with [param in_root],
## in the window's own (the system mouse is only the window's to read: a
## viewport of its own reads its last event's).
func _open(in_root := false) -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	if in_root:
		add_child_autofree(screen)
	else:
		viewport = SubViewport.new()
		viewport.size = Vector2i(1280, 800)
		viewport.gui_disable_input = false
		add_child_autofree(viewport)
		viewport.add_child(screen)
		# The pointer is in the viewport, as in a window: its motions reach
		# the world (a bare viewport hears only its buttons).
		viewport.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	await wait_process_frames(3)
	screen.set_process(false)
	screen.player.food = 50
	screen.player.sieges = AdventurePlayer.SIEGES_NONE
	screen._tick_left = 0.0
	_quiet_slots()


func _quiet_slots() -> void:
	var player := screen.player
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		var tile: Vector2i = player.tile() + LAIRS[slot]
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000


func _run(ticks: int) -> void:
	for i in ticks:
		_quiet_slots()
		screen._process(HeroWalk.TICK)


## A key held down or let go: the Input's state, and the event through the
## screen's viewport; [param echo]: the system's repeat of a key held.
func _hold(code: Key, down: bool, echo := false) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = down
	key.echo = echo
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	viewport.push_input(key.duplicate(), true)


func _mouse(at: Vector2, button := MOUSE_BUTTON_NONE, down := false) -> void:
	if button == MOUSE_BUTTON_NONE:
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		viewport.push_input(mm, true)
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	viewport.push_input(ev, true)


func _middle(tile: Vector2i) -> Vector2i:
	return tile * 32 + Vector2i(16, 16)


## A tile with [param length] plain land tiles after it way [param way] (no
## place on any) — and with [param sea_beside], the sea one step from it
## some other way —, the hero set down on its middle and the line explored.
func _line(way: int, length: int, sea_beside := false) -> Vector2i:
	var player := screen.player
	var step := Vector2i(ShandalarWorld.DX[way], ShandalarWorld.DY[way])
	var home := player.tile()
	for radius in range(0, 25):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var start := home + Vector2i(dx, dy)
				var ok := true
				for k in length + 1:
					var tile := start + step * k
					if not screen.world.is_land(tile.x, tile.y) or not screen.place_at(tile).is_empty() \
							or not VisitPane.describe(player, tile).is_empty() \
							or screen.world.terrain(tile.x, tile.y) in [2, 3, 4, 5]:
						ok = false
						break
				if ok and sea_beside and _sea_way(start) < 0:
					ok = false
				if ok:
					player.position = _middle(start)
					for k in length + 1:
						screen.world.explore_around(start + step * k)
					screen._show_hero()
					screen.view.camera = screen.view.hero
					_quiet_slots()
					return start
	return Vector2i(-1, -1)


## A way (1-8, not the line's 4) from [param tile] into the sea, -1 for none.
func _sea_way(tile: Vector2i) -> int:
	for way in [2, 6, 8, 1, 3, 5, 7]:
		var next := tile + Vector2i(ShandalarWorld.DX[way], ShandalarWorld.DY[way])
		if not screen.world.is_land(next.x, next.y):
			return way
	return -1


## A town never visited with land on either side Right's way (+1, +1); the
## hero set down beside it, on the land before it.
func _town_beside() -> Dictionary:
	var player := screen.player
	for slot in screen.world.sites.size():
		var site: Dictionary = screen.world.sites[slot]
		if int(site["type"]) != ShandalarWorld.TOWN or TownStatus.ruled(screen.world, slot):
			continue
		var tile := Vector2i(int(site["x"]), int(site["y"]))
		var from := tile - Vector2i(1, 1)
		if screen.world.is_land(from.x, from.y) and VisitPane.describe(player, from).is_empty() \
				and screen.world.is_land(tile.x + 1, tile.y + 1) \
				and VisitPane.describe(player, tile + Vector2i(1, 1)).is_empty():
			player.position = _middle(from)
			_quiet_slots()
			return {"slot": slot, "tile": tile}
	return {}


## Into the town (a click's walk): its tile, (-1, -1) when none is found.
func _visit() -> Vector2i:
	var town := _town_beside()
	assert_false(town.is_empty(), "control: a town with land beside it")
	if town.is_empty():
		return Vector2i(-1, -1)
	var tile: Vector2i = town["tile"]
	screen.walk_to_tile(tile)
	for i in 200:
		if screen.visiting():
			break
		_run(1)
	assert_true(screen.visiting(), "control: in the town")
	return tile


## Out of the town again: its pane left, the seller after it too; the
## shield up as the world screen raises it.
func _leave() -> void:
	screen._visit.choose("leave")
	await wait_process_frames(3)
	var seller := screen.find_child("WorldMagicPane", true, false) as WorldMagicPane
	if seller != null and not seller.is_queued_for_deletion():
		seller.done.emit()
		await wait_process_frames(3)
	assert_false(screen.modal(), "control: the town left")
	screen._sync_rest()


# ------------------------------------------------------- h2-2: the shield --

func test_a_walking_key_pressed_just_after_a_pane_walks() -> void:
	await _open()
	var tile := _visit()
	if tile.x < 0:
		return
	await _leave()
	var player := screen.player
	assert_eq(player.position, _middle(tile), "control: on the town's middle")
	assert_lt(Time.get_ticks_msec(), screen._shield_until, "control: the shield is up (the pane just closed)")
	_hold(KEY_RIGHT, true)
	assert_eq(screen._walk_keys, [KEY_RIGHT] as Array[int], "Right pressed anew under the shield: heard")
	_run(30)
	assert_ne(player.position, _middle(tile), "and held: the hero walks")
	_hold(KEY_RIGHT, false)


func test_a_key_held_through_the_close_still_walks_no_one() -> void:
	await _open()
	var tile := _visit()
	if tile.x < 0:
		return
	# Right pressed under the town's pane and held as it closes.
	_hold(KEY_RIGHT, true)
	_run(3)
	await _leave()
	var player := screen.player
	assert_lt(Time.get_ticks_msec(), screen._shield_until, "control: the shield is up")
	for i in 3:
		# The system's repeats of the key held: echoes.
		_hold(KEY_RIGHT, true, true)
		_run(10)
	assert_eq(player.position, _middle(tile), "its repeats walk no one (W1's rule stands)")
	screen._shield_until = 0
	_hold(KEY_RIGHT, true, true)
	_run(10)
	assert_eq(player.position, _middle(tile), "nor after the shield")
	_hold(KEY_RIGHT, false)
	_hold(KEY_RIGHT, true)
	_run(10)
	assert_ne(player.position, _middle(tile), "control: pressed again, it walks")
	_hold(KEY_RIGHT, false)


func test_the_shield_still_holds_the_other_keys() -> void:
	await _open()
	var tile := _visit()
	if tile.x < 0:
		return
	await _leave()
	assert_lt(Time.get_ticks_msec(), screen._shield_until, "control: the shield is up")
	_hold(KEY_Q, true)
	_hold(KEY_Q, false)
	assert_false(screen.modal(), "Q under the shield asks nothing")
	screen._shield_until = 0
	screen._sync_rest()
	_hold(KEY_Q, true)
	_hold(KEY_Q, false)
	assert_true(screen.modal(), "control: Q once it lifted asks \"Ready to Quit?\"")


# ----------------------------------------------- h2-3: the stale arrows --

func test_a_click_s_walk_stopped_on_its_first_tile_leaves_no_arrows() -> void:
	await _open()
	var start := _line(4, 8)
	assert_gt(start.x, -1, "control: a line of land")
	if start.x < 0:
		return
	screen.set_zoom(1.0)
	screen._process(0.001)
	var target := start + Vector2i(ShandalarWorld.DX[4], ShandalarWorld.DY[4]) * 3
	var at := screen.view.drawn_at(Vector2(_middle(target)))
	assert_eq(screen.tile_at(at), target, "control: the pointer's tile")
	_mouse(at)
	await get_tree().create_timer(0.25).timeout
	screen._process(0.001)
	assert_true(screen.paths.previewing(), "control: resting, the preview")
	_mouse(at, MOUSE_BUTTON_LEFT, true)
	_mouse(at, MOUSE_BUTTON_LEFT, false)
	screen._process(HeroWalk.TICK)
	assert_true(screen.walk.is_walking(), "control: the click walks")
	assert_true(screen.paths.shown() and not screen.paths.previewing(), "control: its way at full strength")
	assert_eq(screen.player.tile(), start, "control: still on the first tile")
	_hold(KEY_SPACE, true)
	_hold(KEY_SPACE, false)
	for i in 5:
		screen._process(0.001)
	assert_false(screen.walk.is_walking(), "control: Space stopped the walk")
	assert_false(screen.paths.shown() and not screen.paths.previewing(),
		"no arrows at full strength left with the hero standing")
	assert_true(screen.paths.previewing(), "the pointer still resting there: its preview, faint")
	assert_eq(screen.paths.marked()[screen.paths.marked().size() - 1], target, "to the tile under the pointer")


func test_an_arrow_into_the_sea_leaves_no_click_arrows() -> void:
	await _open()
	var start := _line(4, 6, true)
	assert_gt(start.x, -1, "control: a line of land with the sea beside its first tile")
	if start.x < 0:
		return
	var sea := _sea_way(start)
	var key: Key = {2: KEY_UP, 3: KEY_PAGEUP, 5: KEY_PAGEDOWN, 6: KEY_DOWN, 7: KEY_END, 8: KEY_LEFT,
		1: KEY_HOME}[sea]
	screen.set_zoom(1.0)
	screen._process(0.001)
	var target := start + Vector2i(ShandalarWorld.DX[4], ShandalarWorld.DY[4]) * 3
	var at := screen.view.drawn_at(Vector2(_middle(target)))
	_mouse(at)
	await get_tree().create_timer(0.25).timeout
	screen._process(0.001)
	_mouse(at, MOUSE_BUTTON_LEFT, true)
	_mouse(at, MOUSE_BUTTON_LEFT, false)
	screen._process(HeroWalk.TICK)
	assert_true(screen.paths.shown() and not screen.paths.previewing(), "control: the click's way")
	_hold(key, true)
	_hold(key, false)
	for i in 40:
		screen._process(HeroWalk.TICK)
	assert_false(screen.walk.is_walking(), "control: the arrow into the sea, the hero stands")
	assert_false(screen.paths.shown() and not screen.paths.previewing(),
		"no arrows at full strength left with the hero standing")


# --------------------------------------- h2-4: the pointer of a pad or a finger --

func test_the_place_under_the_pointer_is_where_its_events_put_it() -> void:
	_gut_layer = get_tree().root.find_child("GutLayer", true, false) as CanvasLayer
	if _gut_layer != null:
		_gut_layer.visible = false
	await _open(true)
	var start := _line(4, 6)
	assert_gt(start.x, -1, "control: a line of land")
	if start.x < 0:
		return
	screen.set_zoom(1.0)
	screen._process(0.001)
	# The system's mouse left on a far place (a pad hides it where it was).
	var os_at := screen.view.feet() + Vector2(-260, -130)
	var mouse := InputEventMouseMotion.new()
	mouse.position = os_at
	mouse.global_position = os_at
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	await wait_process_frames(1)
	# The pad's pointer: events pushed into the window, as PadControls and
	# TouchControls push them.
	var pad_at := screen.view.drawn_at(Vector2(_middle(start + Vector2i(ShandalarWorld.DX[4],
		ShandalarWorld.DY[4]) * 2)))
	var pad := InputEventMouseMotion.new()
	pad.position = pad_at
	pad.global_position = pad_at
	get_tree().root.push_input(pad, true)
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_hovered_control(), screen.view, "control: the pointer rests on the world")
	assert_ne(screen.tile_at(screen.get_local_mouse_position()), screen.tile_at(pad_at),
		"control: the system's mouse is elsewhere")
	# The land moves under the still pointer: a look, as a walk's view does.
	screen.look(Vector2(96, 64))
	screen._point_again()
	assert_eq(screen.paths._hover, screen.tile_at(pad_at), "the place under the pad's pointer, not the mouse's")
