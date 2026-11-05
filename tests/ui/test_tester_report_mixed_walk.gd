extends GutTest
## CLICKS AND ARROWS TOGETHER (a play-tester's report, 2026-11-05: *"the
## walking was either mouse click like in Heroes of Might and Magic or use
## arrows to move … if you try to use both at the same time it gets a little
## messy"*). The last input wins: an arrow against the step under way turns
## the hero on the spot ([method HeroWalk.key_toward]); a click mid-step
## walks on, never back to the middle just left ([method HeroWalk.walk_to]);
## a key held through a click or Space walks no one until pressed again
## ([method WorldScreen.walk_to_tile], [method WorldScreen.stop_and_back]);
## the hover preview waits for the pointer to move after the keys walked
## ([member WorldPath.quiet]); and a mouse press let go after an arrow
## clicks no tile ([member WorldScreen._press_spent]).

const SAVES := "user://adventure_tests_mixed_walk"
const HELD := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE]
const LAIRS := [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, -3),
	Vector2i(-3, 3)]
## The world's ways along the screen's right and left (ShandalarWorld.DX/DY).
const RIGHT_WAY := 4
const LEFT_WAY := 8

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
	viewport.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.food = 50
	screen.player.sieges = AdventurePlayer.SIEGES_NONE
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
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## No creature on the way: every lair slot far off, none respawning.
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


func _run(ticks: int) -> void:
	for i in ticks:
		_quiet_slots()
		screen._process(HeroWalk.TICK)


## A key held down ([param down]) or let go, for Input and the world.
func _hold(code: Key, down: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = down
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	viewport.push_input(key.duplicate(), true)


func _mouse(at: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.position = at
	click.global_position = at
	viewport.push_input(click, true)


func _motion(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	await _frames(1)


func _middle(tile: Vector2i) -> Vector2i:
	return tile * 32 + Vector2i(16, 16)


## A straight run of [param length] plain land tiles the way [param way],
## with nothing to visit on it and the way found along it; the hero set on
## its first tile's middle. (-1, -1) when the world has none near.
func _line(way: int, length: int) -> Vector2i:
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
				for k in range(-1, length + 1):
					var tile := start + step * k
					if not screen.world.is_land(tile.x, tile.y) or not screen.place_at(tile).is_empty() \
							or not VisitPane.describe(player, tile).is_empty():
						ok = false
						break
				if ok:
					player.position = _middle(start)
					var straight: Array[Vector2i] = []
					for k in length + 1:
						straight.append(start + step * k)
					ok = screen.walk.plan(start + step * length) == straight
				if ok:
					player.position = _middle(start)
					screen.view.hero = Vector2(player.position)
					screen.view.camera = screen.view.hero
					_quiet_slots()
					return start
	return Vector2i(-1, -1)


func _until_standing(most := 400) -> void:
	for i in most:
		if not screen.walk.is_walking():
			return
		_run(1)


func test_an_arrow_against_the_click_turns_the_hero_on_the_spot() -> void:
	var start := _line(RIGHT_WAY, 6)
	assert_gt(start.x, -1, "a straight run of land")
	if start.x < 0:
		return
	assert_true(screen.walk_to_tile(start + Vector2i(6, 6)))
	_run(6)
	assert_eq(screen.walk.heading, RIGHT_WAY, "the click's walk under way")
	_hold(KEY_LEFT, true)
	_run(1)
	assert_eq(screen.walk.heading, LEFT_WAY, "turned at once, not on to the tile ahead first")
	_hold(KEY_LEFT, false)
	_until_standing()
	assert_eq(screen.player.position, _middle(start), "back on the tile just left")


func test_a_click_during_the_keys_walk_never_steps_back() -> void:
	var start := _line(RIGHT_WAY, 6)
	assert_gt(start.x, -1, "a straight run of land")
	if start.x < 0:
		return
	_hold(KEY_RIGHT, true)
	_run(8)
	assert_eq(screen.walk.heading, RIGHT_WAY, "the keys' walk under way")
	assert_true(screen.walk_to_tile(start + Vector2i(5, 5)))
	var back := 0
	for i in 40:
		_run(1)
		if screen.walk.heading == LEFT_WAY:
			back += 1
	assert_eq(back, 0, "the click walks on through the tile ahead")
	_hold(KEY_RIGHT, false)


func test_a_key_held_through_a_click_is_no_half_of_the_next_diagonal() -> void:
	var start := _line(RIGHT_WAY, 6)
	assert_gt(start.x, -1, "a straight run of land")
	if start.x < 0:
		return
	_hold(KEY_UP, true)
	_run(3)
	assert_true(screen.walk_to_tile(start + Vector2i(4, 4)))
	_run(3)
	assert_false(screen.walk.by_keys, "the click's walk")
	_hold(KEY_RIGHT, true)
	_run(1)
	assert_eq(screen.walk.keyed, RIGHT_WAY, "Right alone, not Up and Right")
	_hold(KEY_RIGHT, false)
	_hold(KEY_UP, false)


func test_a_key_held_through_space_is_no_half_of_the_next_diagonal() -> void:
	var start := _line(RIGHT_WAY, 6)
	assert_gt(start.x, -1, "a straight run of land")
	if start.x < 0:
		return
	_hold(KEY_UP, true)
	_run(3)
	_hold(KEY_SPACE, true)
	_hold(KEY_SPACE, false)
	_run(2)
	_hold(KEY_RIGHT, true)
	_run(1)
	assert_eq(screen.walk.keyed, RIGHT_WAY, "Right alone, not Up and Right")
	_hold(KEY_RIGHT, false)
	_hold(KEY_UP, false)


func test_no_preview_after_the_keys_walk_until_the_pointer_moves() -> void:
	var start := _line(RIGHT_WAY, 3)
	assert_gt(start.x, -1, "a straight run of land")
	if start.x < 0:
		return
	var target := start + Vector2i(-3, 2)
	if not screen.world.is_land(target.x, target.y):
		target = start + Vector2i(2, -1)
	await _motion(screen.view.drawn_at(Vector2(_middle(target))))
	_hold(KEY_RIGHT, true)
	_run(3)
	_hold(KEY_RIGHT, false)
	_until_standing()
	# The pointer rested long since: only the keys' quiet holds the preview.
	screen.paths._hover_since -= WorldPath.REST_MS * 10
	_run(2)
	assert_false(screen.paths.shown(), "nothing pops up where the mouse happens to lie")
	await _motion(screen.view.drawn_at(Vector2(_middle(target))) + Vector2(3, 0))
	screen.paths._hover_since -= WorldPath.REST_MS * 10
	_run(2)
	assert_false(screen.paths.quiet, "the pointer moved")


func test_a_press_let_go_after_an_arrow_clicks_no_tile() -> void:
	var start := _line(RIGHT_WAY, 6)
	assert_gt(start.x, -1, "a straight run of land")
	if start.x < 0:
		return
	var aim := screen.view.drawn_at(Vector2(_middle(start + Vector2i(-2, 1))))
	# The control: the same press let go is a click that walks.
	_mouse(aim, true)
	await _frames(1)
	_mouse(aim, false)
	await _frames(1)
	assert_true(screen.walk.is_walking() and not screen.walk.by_keys, "a plain click walks")
	screen.stop_and_back()
	_until_standing()
	aim = screen.view.drawn_at(Vector2(_middle(screen.player.tile() + Vector2i(-2, 1))))
	_mouse(aim, true)
	await _frames(1)
	_hold(KEY_RIGHT, true)
	_run(2)
	_mouse(aim, false)
	await _frames(1)
	assert_true(screen.walk.by_keys, "the keys' walk goes on: the view moved under the press")
	_hold(KEY_RIGHT, false)


## A cleric the hero sees in slot 0, standing on [param tile]'s middle; the
## other slots lairs far off.
func _cleric_at(tile: Vector2i) -> Dictionary:
	var player := screen.player
	_quiet_slots()
	var cleric := {"slot": 0, "kind": "creature", "creature": 8, "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
		"color": 5, "heading": 0, "frame": 0}
	player.monsters[0] = cleric
	screen.view.creatures = WorldCreatures.seen(player)
	return cleric


## Where the cleric's body is drawn: a little above its feet.
func _on(cleric: Dictionary) -> Vector2:
	return screen.view.drawn_at(Vector2(int(cleric["x"]), int(cleric["y"]))) - Vector2(0, 10) * screen.view.zoom


func test_over_a_creature_the_sword_and_a_click_goes_for_it() -> void:
	var start := _line(RIGHT_WAY, 6)
	assert_gt(start.x, -1, "a straight run of land")
	if start.x < 0:
		return
	var cleric := _cleric_at(start + Vector2i(1, 1))
	assert_eq(screen.view.creatures.size(), 1, "the hero sees it")
	await _motion(_on(cleric))
	assert_eq(screen._pointer, WorldCursors.Kind.CREATURE, "the sword over it")
	await _motion(screen.view.drawn_at(Vector2(_middle(start + Vector2i(-2, 2)))))
	assert_ne(screen._pointer, WorldCursors.Kind.CREATURE, "and not off it")
	_mouse(_on(cleric), true)
	await _frames(1)
	_mouse(_on(cleric), false)
	await _frames(1)
	assert_eq(screen._chase, 0, "the click goes for it")
	assert_eq(screen.walk.destination, start + Vector2i(1, 1), "to where it stands")
	# It moves on a tile: the way is found again to where it is now.
	cleric["x"] = int(cleric["x"]) + 32
	screen._follow_chase()
	assert_eq(screen.walk.destination, start + Vector2i(2, 1), "the chase follows it")
	# Another walk chosen gives the chase up.
	screen.walk_to_tile(start + Vector2i(3, 3))
	assert_eq(screen._chase, -1, "a click elsewhere")
	assert_true(screen.engage(0))
	_hold(KEY_RIGHT, true)
	assert_eq(screen._chase, -1, "an arrow key")
	_hold(KEY_RIGHT, false)
