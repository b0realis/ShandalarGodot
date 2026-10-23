class_name WorldScreen
extends Control
## THE WORLD OF SHANDALAR, on the whole screen — a new adventure's world
## ([WorldGenerator]) drawn as the 1997 game drew it ([WorldView]), without
## the frame the original looked at it through (the owner, 2026-10-22:
## *"we will omit the original border around the world screen and try to
## render it full screen"*).
##
## WHAT IT DOES TODAY: it shows the adventure ([AdventurePlayer]) from where
## the hero stands, and the hero WALKS: a click on the map is where to go,
## the way there is found and walked at the 1997 pace ([HeroWalk]), the
## world's clock ticking every 60 ms as the original's did, the land the
## hero passes explored. The pointer is a small walking man, an open door
## over a site. The arrows or a drag look around, the wheel zooms, Space
## comes back to the hero, M is the map of the land seen, Escape leaves.
## The floating panel ([WorldHud]) shows what the hero carries, and its
## options save, load (over the world) and exit the game.
## The towns, the encounters and the rest come next
## (`docs/adventure-implementation-notes.md`).

const LOOK_SPEED := 600.0   # screen pixels a second, at zoom 1
const ZOOM_STEP := 1.25
## A press that moves no further than this is a click, not a drag.
const CLICK_SLOP := 6.0
## At most this many ticks in one frame, after a long one.
const MOST_TICKS := 20

## The adventure: the hero and their world. Set before the screen enters
## the tree; when it is not, one is begun from [member record] and
## [member world] (without a save).
var player: AdventurePlayer
## The record a new adventure began from ([method AdventureSetup.resolve]),
## and its world.
var record: Dictionary = {}
var world: ShandalarWorld
## The hero's walk ([HeroWalk]).
var walk: HeroWalk

## A few lines greeting the hero on arrival ([method EmbarkScreen.summary]),
## shown for [constant ARRIVAL_SECONDS].
var arrival := ""
const ARRIVAL_SECONDS := 8.0

var view: WorldView
var _map: WorldMap
## The floating icons ([WorldHud]): the purse, the amulets, the World
## Magics and the round buttons.
var hud: WorldHud
var _arrival: Label
var _dragging := false
var _pressed_at := Vector2.ZERO
var _dragged := false
var _leaving := false
var _tick_left := 0.0
var _pointer := -1
## The saved adventures, open over the world from the options.
var _load_screen: LoadAdventureScreen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if world == null and not record.is_empty():
		world = AdventureSetup.make_world(record)
	view = WorldView.new()
	view.name = "View"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	_map = WorldMap.new()
	_map.name = "Map"
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.visible = false
	add_child(_map)
	hud = WorldHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.map_pressed.connect(toggle_map)
	hud.hero_pressed.connect(hud.toggle_hero)
	hud.deck_pressed.connect(show_deck)
	hud.save_pressed.connect(save_now)
	hud.load_pressed.connect(open_load)
	hud.exit_pressed.connect(exit_game)
	hud.hovered.connect(func() -> void: _wear(-1))
	_arrival = Label.new()
	_arrival.name = "Arrival"
	_arrival.text = arrival
	_arrival.visible = arrival != ""
	_arrival.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrival.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_arrival.position.y = 200
	_arrival.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_arrival.add_theme_font_size_override("font_size", 18)
	_arrival.add_theme_color_override("font_color", Color8(232, 190, 110))
	_arrival.add_theme_color_override("font_outline_color", Color8(30, 8, 6))
	_arrival.add_theme_constant_override("outline_size", 4)
	_arrival.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrival)
	if arrival != "" and is_inside_tree():
		var fade := create_tween()
		fade.tween_interval(ARRIVAL_SECONDS)
		fade.tween_property(_arrival, "modulate:a", 0.0, 1.5)
	if player == null and world != null:
		player = AdventurePlayer.begin(record, world)
	if player != null:
		show_player(player)


## Show [param adventure]: its world, the hero where they stand.
func show_player(adventure: AdventurePlayer) -> void:
	player = adventure
	world = player.world
	walk = HeroWalk.new(player)
	view.world = world
	view.hero_walker = player.walker
	view.hero_sheet = HeroColors.dressed(view.art, player.walker, player.figure_colors)
	world.explore_around(player.tile())
	_map.world = world
	hud.show_player(player)
	_show_hero()
	view.camera = view.hero
	view.queue_redraw()


## The world's own adventure, begun from [param shown] (the screen's
## [member record]); for a world shown without a save.
func show_world(shown: ShandalarWorld) -> void:
	show_player(AdventurePlayer.begin(record, shown))


func _show_hero() -> void:
	view.hero = Vector2(player.position)
	view.hero_facing = player.facing
	view.hero_step = player.step
	_map.hero_tile = player.tile()
	hud.refresh()


## SAVE (the HUD's book, Ctrl+S): the adventure as it now stands, beside
## its autosave; the path written, or "".
func save_now() -> String:
	if player == null:
		return ""
	var path := player.save(player.save_path("save"))
	hud.say("Saved." if path != "" else "The adventure could not be saved.")
	return path


## LOAD (the options): the saved adventures over the world, which waits
## under them; Back comes back to it, Continue takes the one chosen up
## instead.
func open_load() -> LoadAdventureScreen:
	if loading():
		return _load_screen
	_wear(-1)
	_dragging = false
	_load_screen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child(_load_screen)
	return _load_screen


func loading() -> bool:
	return _load_screen != null and is_instance_valid(_load_screen) and not _load_screen.is_queued_for_deletion()


## EXIT GAME (the options): the adventure saved as it stands, then the
## game ends — as `Exit game` ends it from a duel.
func exit_game() -> void:
	save_now()
	_end_process()


## Ends the process; a seam so a test can count the exit instead.
func _end_process() -> void:
	get_tree().quit()


## THE DECK (the frame's spellbook, F1): there is none to open yet.
func show_deck() -> void:
	if player.cards.is_empty():
		hud.say("No cards yet: the starting deck comes with the 1997 card rarities.")
	else:
		hud.say("%d cards; the deck builder comes to the world later." % player.cards.size())


## Walk to [param tile] (the way is found); true when there is a way.
func walk_to_tile(tile: Vector2i) -> bool:
	if walk == null:
		return false
	var going := walk.walk_to(tile)
	if going:
		view.camera = view.hero
	return going


## The world's clock run for [param seconds]: a tick every
## [constant HeroWalk.TICK], the hero walking, the land they pass explored.
func advance(seconds: float) -> void:
	if walk == null:
		return
	_tick_left += seconds
	var ticks := 0
	while _tick_left >= HeroWalk.TICK and ticks < MOST_TICKS:
		_tick_left -= HeroWalk.TICK
		ticks += 1
		var walking := walk.is_walking()
		if walk.tick():
			world.explore_around(player.tile())
		if walking:
			view.camera = Vector2(player.position)
	if ticks == MOST_TICKS:
		_tick_left = 0.0
	if ticks > 0:
		_show_hero()
		view.queue_redraw()
		if _map.visible:
			_map.queue_redraw()


## The tile under [param point] on the view.
func tile_at(point: Vector2) -> Vector2i:
	var at := view.unproject(point)
	return Vector2i(floori(at.x / 32.0), floori(at.y / 32.0))


## The pointer over [param tile]: an open door on a site the hero can
## see, the walking man elsewhere.
func pointer_for(tile: Vector2i) -> WorldCursors.Kind:
	if world != null and world.is_explored(tile.x, tile.y) \
			and world.tile_flags(tile.x, tile.y) & ShandalarWorld.SITE != 0:
		return WorldCursors.Kind.DOOR
	return WorldCursors.Kind.WALK


func _wear(kind: int) -> void:
	if kind == _pointer:
		return
	_pointer = kind
	if kind < 0:
		WorldCursors.take_off()
	else:
		WorldCursors.wear(kind)


func _exit_tree() -> void:
	_wear(-1)


## Look by [param pixels] on the screen.
func look(pixels: Vector2) -> void:
	var p := pixels / view.zoom
	view.camera += Vector2(p.x / 4.0 - p.y / 2.0, p.x / 4.0 + p.y / 2.0)
	var limit := float(ShandalarWorld.TILES * 32)
	view.camera = view.camera.clamp(Vector2(-256, -256), Vector2(limit + 256, limit + 256))
	view.queue_redraw()


func set_zoom(value: float) -> void:
	view.zoom = clampf(value, WorldView.ZOOM_MIN, WorldView.ZOOM_MAX)
	view.queue_redraw()


func back_to_hero() -> void:
	view.camera = view.hero
	view.queue_redraw()


func toggle_map() -> void:
	_map.visible = not _map.visible
	_arrival.visible = not _map.visible and arrival != ""
	if _map.visible:
		_wear(-1)
	_map.queue_redraw()


func _process(delta: float) -> void:
	if world == null or _map.visible or loading():
		return
	advance(delta)
	# Ctrl+S saves; it never looks down too.
	if Input.is_key_pressed(KEY_CTRL):
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		direction.y += 1
	if direction != Vector2.ZERO:
		look(direction.normalized() * LOOK_SPEED * delta)


func _gui_input(event: InputEvent) -> void:
	if _map.visible:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = true
				_dragged = false
				_pressed_at = button.position
			else:
				_dragging = false
				# A press let go where it was made is a click: walk there —
				# unless it closes the options, as a click outside a menu does.
				if not _dragged and not hud.close_options():
					walk_to_tile(tile_at(button.position))
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(view.zoom * ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(view.zoom / ZOOM_STEP)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			if not _dragged and motion.position.distance_to(_pressed_at) > CLICK_SLOP:
				_dragged = true
			if _dragged:
				look(-motion.relative)
		_wear(pointer_for(tile_at(motion.position)))


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or loading():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _map.visible:
			toggle_map()
		elif hud.close_panels():
			pass
		else:
			leave()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_M, KEY_F2:
				toggle_map()
			KEY_F1:
				show_deck()
			KEY_F5:
				hud.toggle_hero()
			KEY_H:
				hud.toggle_help()
			KEY_S:
				if (event as InputEventKey).ctrl_pressed:
					save_now()
				else:
					return
			KEY_SPACE, KEY_HOME:
				back_to_hero()
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
				set_zoom(view.zoom * ZOOM_STEP)
			KEY_MINUS, KEY_KP_SUBTRACT:
				set_zoom(view.zoom / ZOOM_STEP)
			_:
				return
		get_viewport().set_input_as_handled()


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://game/main.tscn")
