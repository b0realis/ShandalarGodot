extends GutTest
## THE PATH ARROWS ON THE WORLD (0.50.66; the owner, 2026-10-29: *"visual
## pathfinding arrows as in the supplied reference photo from HOMM 3 (range
## coloured) - with visual pathfinding on/off setting!"*, and the look
## picked from the mock-ups) — [WorldPath] through the real world screen: a
## click's way marked tile by tile, orange while the food lasts and red
## beyond, the tile the hero stands on unmarked; nothing for the keys' walk;
## the options' Path arrows, on by default, switch them; the hover preview
## waits for the pointer to rest and a click still walks at once; nothing
## while the world waits; drawn again only when something changed.

const SAVES := "user://adventure_tests_c20_v1_path_arrows"
## Where the roaming slots' lairs stand from the hero ([method _quiet_slots]).
const LAIRS := [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, -3),
	Vector2i(-3, 3)]

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	Settings.clear_value(WorldHud.PATHS_SETTING)
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
	# The pointer is in this viewport, as a container would say: without it
	# a motion pushed here reaches no control (test_c3_f1_modal_world's).
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
	for code in [KEY_RIGHT]:
		var up := InputEventKey.new()
		up.keycode = code
		up.physical_keycode = code
		up.pressed = false
		Input.parse_input_event(up)
	Input.flush_buffered_events()
	Settings.clear_value(WorldHud.PATHS_SETTING)
	Settings.clear_value(WorldHud.PACE_SETTING)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## Every roaming slot held by a lair three tiles from the hero: nothing
## refills, nothing comes (test_c20_W1_world_key_walk's).
func _quiet_slots() -> void:
	var player := screen.player
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		var tile: Vector2i = player.tile() + LAIRS[slot]
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000
	player.siege_active = false


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## [param ticks] of the world's frames, a tick each.
func _run(ticks: int) -> void:
	for i in ticks:
		_quiet_slots()
		screen._process(HeroWalk.TICK)


static func _middle(tile: Vector2i) -> Vector2i:
	return tile * 32 + Vector2i(16, 16)


## A land tile no place stands on, whose way from the hero is [param least]
## to [param most] tiles long and — with [param on_screen] — whose middle is
## drawn well inside the screen. (-1, -1) for none.
func _target(least: int, most: int, on_screen := false) -> Vector2i:
	var player := screen.player
	player.position = _middle(player.tile())
	var home := player.tile()
	for radius in range(2, 20):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile := home + Vector2i(dx, dy)
				if not screen.world.is_land(tile.x, tile.y) or not screen.place_at(tile).is_empty() \
						or not VisitPane.describe(player, tile).is_empty():
					continue
				if on_screen and not Rect2(200, 200, 880, 450).has_point(screen.view.drawn_at(Vector2(_middle(tile)))):
					continue
				var way := screen.walk.plan(tile)
				if way.size() - 1 >= least and way.size() - 1 <= most and way.back() == tile:
					return tile
	return Vector2i(-1, -1)


## The least food that walks part of [param tiles] fed and the rest hungry.
func _splitting_food(tiles: Array[Vector2i]) -> int:
	for food in range(1, 30):
		screen.player.food = food
		var fed := screen.walk.forecast(tiles)
		if fed.count(1) >= 2 and fed.has(0):
			return food
	return 1


func _bools(fed: PackedByteArray) -> Array[bool]:
	var out: Array[bool] = []
	for one in fed:
		out.append(one == 1)
	return out


func _marks() -> Node2D:
	return screen.paths.find_child("Marks", true, false) as Node2D


## The pointer moved to [param at], through the viewport; a frame for the
## world to hear it (its own clock does not run: no tick passes).
func _motion(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	await _frames(1)


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames(1)


func _hold(code: Key, down: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = down
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	viewport.push_input(key.duplicate(), true)


# ------------------------------------------------------------ the walk --

func test_a_click_s_way_is_marked_orange_then_red_and_follows_the_hero() -> void:
	assert_true(WorldHud.path_arrows_wanted(), "the path arrows are on by default")
	var paths := screen.paths
	var target := _target(9, 16)
	assert_gt(target.x, -1, "control: a far tile to walk to")
	var tiles := screen.walk.plan(target)
	tiles.remove_at(0)
	var food := _splitting_food(tiles)
	screen.player.food = food
	assert_true(screen.walk_to_tile(target), "the click walks")
	screen.player.monster_timer = 1
	_run(1)
	assert_true(paths.shown(), "a click's way is marked")
	assert_false(paths.previewing(), "at full strength, not the preview's")
	assert_eq(paths.marked(), tiles, "every tile still to walk to, the hero's own not")
	var fed := paths.fed()
	assert_eq(fed, _bools(screen.walk.forecast(screen.walk.path)), "coloured by the food foreseen")
	assert_true(fed.has(true) and fed.has(false), "control: orange, then red: %s at food %d" % [fed, food])
	assert_eq(fed.find(false), fed.rfind(true) + 1, "orange first, then red")
	var marks := _marks()
	assert_eq(marks.position, screen.view.drawn_at(Vector2(_middle(tiles[0]))), "laid where the view draws")
	assert_eq(marks.scale, Vector2(screen.view.zoom, screen.view.zoom), "at the view's zoom")
	# Within a tile, no meal: moved with the view, not drawn again.
	var drawn := paths.redraws
	_run(3)
	assert_eq(paths.redraws, drawn, "nothing changed: not drawn again")
	assert_eq(marks.position, screen.view.drawn_at(Vector2(_middle(tiles[0]))), "still laid on the land")
	# Into the next tile: its mark is gone, the rest stay.
	for i in 200:
		if screen.player.tile() == tiles[0]:
			break
		_run(1)
	assert_eq(screen.player.tile(), tiles[0], "control: the hero entered the first tile")
	assert_eq(paths.marked(), tiles.slice(1), "the tile entered is no longer marked")
	assert_gt(paths.redraws, drawn, "drawn again for it")
	screen.set_zoom(1.0)
	_run(1)
	assert_eq(_marks().scale, Vector2(1.0, 1.0), "a zoom scales the marks with the land")


func test_the_walk_s_end_takes_the_marks_away() -> void:
	var target := _target(3, 5)
	screen.walk_to_tile(target)
	for i in 600:
		if not screen.walk.is_walking():
			break
		_run(1)
	_run(1)
	assert_false(screen.walk.is_walking(), "control: arrived")
	assert_false(screen.paths.shown(), "arrived: nothing marked")


func test_the_keys_walk_is_not_marked() -> void:
	var player := screen.player
	# A tile with land to the right of it (the world's way 4).
	var home := player.tile()
	var start := Vector2i(-1, -1)
	for radius in range(0, 12):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var tile := home + Vector2i(dx, dy)
				if start.x < 0 and screen.world.is_land(tile.x, tile.y) and screen.world.is_land(tile.x + 1, tile.y + 1) \
						and screen.world.is_land(tile.x + 2, tile.y + 2) and screen.place_at(tile + Vector2i(1, 1)).is_empty():
					start = tile
	assert_gt(start.x, -1, "control: land to walk right onto")
	player.position = _middle(start)
	screen.view.hero = Vector2(player.position)
	screen.view.camera = screen.view.hero
	_hold(KEY_RIGHT, true)
	_run(2)
	assert_true(screen.walk.is_walking() and screen.walk.by_keys, "control: the keys walk the hero")
	assert_false(screen.paths.shown(), "the keys' walk finds no way: nothing marked")
	_hold(KEY_RIGHT, false)


func test_the_options_switch_the_arrows() -> void:
	var hud := screen.hud
	hud.toggle_options()
	var option := hud.find_child("Option_Paths", true, false) as Button
	assert_not_null(option, "the options hold Path arrows")
	assert_eq(option.text, "Path arrows: on")
	option.pressed.emit()
	assert_true(hud.options_shown(), "a switch leaves the options open")
	assert_eq(option.text, "Path arrows: off")
	assert_false(WorldHud.path_arrows_wanted(), "off, remembered")
	assert_false(bool(Settings.get_value(WorldHud.PATHS_SETTING, true)), "under world_path_arrows")
	hud.close_options()
	screen.walk_to_tile(_target(6, 12))
	_run(1)
	assert_true(screen.walk.is_walking(), "control: walking")
	assert_false(screen.paths.shown(), "switched off: nothing marked")
	hud.toggle_options()
	option.pressed.emit()
	assert_eq(option.text, "Path arrows: on")
	_run(1)
	assert_true(screen.paths.shown(), "switched on: marked at once")


# ----------------------------------------------------- the hover preview --

func test_the_hover_preview_waits_for_the_pointer_to_rest() -> void:
	var paths := screen.paths
	var target := _target(3, 6, true)
	assert_gt(target.x, -1, "control: a tile on the screen to point at")
	var at := screen.view.drawn_at(Vector2(_middle(target)))
	await _motion(at)
	_run(1)
	assert_false(paths.shown(), "not before the pointer rests")
	await get_tree().create_timer(WorldPath.REST_MS / 1000.0 + 0.05).timeout
	_run(1)
	assert_true(paths.previewing(), "rested: the way there, previewed")
	var tiles := screen.walk.plan(target)
	tiles.remove_at(0)
	assert_eq(paths.marked(), tiles, "the way a click would walk")
	var group := paths.find_child("Preview", true, false) as CanvasGroup
	assert_true(group.visible and group.is_ancestor_of(_marks()), "drawn as one, through the group")
	assert_almost_eq(group.self_modulate.a, 0.5, 0.001, "at half strength")
	assert_false(screen.walk.is_walking(), "resting walks no one")
	var drawn := paths.redraws
	_run(3)
	assert_eq(paths.redraws, drawn, "a still pointer: not drawn again")
	# Another tile: its rest begins again.
	var other := target + Vector2i(1, 0) if screen.world.is_land(target.x + 1, target.y) else target - Vector2i(1, 0)
	await _motion(screen.view.drawn_at(Vector2(_middle(other))))
	_run(1)
	assert_false(paths.shown(), "moved on: the old preview gone, the new one not yet")
	# The pointer over the panel: none.
	screen.hud.hovered.emit()
	await get_tree().create_timer(WorldPath.REST_MS / 1000.0 + 0.05).timeout
	_run(1)
	assert_false(paths.shown(), "over the panel: no preview")


func test_a_click_still_walks_at_once() -> void:
	var paths := screen.paths
	var target := _target(3, 6, true)
	var at := screen.view.drawn_at(Vector2(_middle(target)))
	await _motion(at)
	await get_tree().create_timer(WorldPath.REST_MS / 1000.0 + 0.05).timeout
	_run(1)
	assert_true(paths.previewing(), "control: previewed")
	var ticked := screen.player.monster_timer
	await _click(at)
	assert_true(screen.walk.is_walking(), "the click walks at once")
	assert_eq(screen.player.monster_timer, ticked, "no tick waited for")
	assert_eq(screen.walk.destination, target, "to the tile clicked")
	_run(1)
	assert_true(paths.shown() and not paths.previewing(), "the walk's own marks, at full strength")
	var group := paths.find_child("Preview", true, false) as CanvasGroup
	assert_false(group.is_ancestor_of(_marks()), "no longer through the preview's group")


# ----------------------------------------------------- the world waiting --

func test_nothing_is_marked_while_the_world_waits() -> void:
	var paths := screen.paths
	screen.walk_to_tile(_target(9, 16))
	_run(1)
	assert_true(paths.shown(), "control: marked")
	screen.toggle_map()
	_run(1)
	assert_false(paths.shown(), "under the map: none")
	screen.toggle_map()
	_run(1)
	assert_true(paths.shown(), "the map closed: marked again")
	var load_screen := screen.open_load()
	assert_not_null(load_screen, "control: the saved adventures")
	_run(1)
	assert_false(paths.shown(), "under a pane: none")
	load_screen.free()
	_run(1)
	assert_true(paths.shown(), "the pane closed: marked again")
	# A news flash stops the walk; a preview waits under it too — the
	# shield's moment after the pane waited out first.
	screen.walk.stop()
	var target := _target(3, 6, true)
	await get_tree().create_timer(WorldScreen.AFTER_PANE_MS / 1000.0 + 0.1).timeout
	_run(1)
	await _motion(screen.view.drawn_at(Vector2(_middle(target))))
	await get_tree().create_timer(WorldPath.REST_MS / 1000.0 + 0.05).timeout
	_run(1)
	assert_true(paths.previewing(), "control: previewed")
	var town := -1
	for i in screen.world.sites.size():
		if int(screen.world.sites[i].get("type", 0)) == ShandalarWorld.TOWN:
			town = i
			break
	var news := screen.show_news([{"kind": "siege", "lines": ["The Red Wizardess sends a Dragon."],
		"town": town}])
	assert_not_null(news, "control: a news flash")
	_run(1)
	assert_false(paths.shown(), "under a news flash: none")
