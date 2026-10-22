class_name WorldScreen
extends Control
## THE WORLD OF SHANDALAR, on the whole screen — a new adventure's world
## ([WorldGenerator]) drawn as the 1997 game drew it ([WorldView]), without
## the frame the original looked at it through (the owner, 2026-10-22:
## *"we will omit the original border around the world screen and try to
## render it full screen"*).
##
## WHAT IT DOES TODAY: it shows the world the hero set out into, from where
## they stand, and lets the player look around it — the arrows or a drag
## to look, the wheel to zoom, Space to come back to the hero, M for the
## map of the world, Escape to leave. Walking, the towns, the encounters
## and the rest come next (`docs/adventure-implementation-notes.md`).

const LOOK_SPEED := 600.0   # screen pixels a second, at zoom 1
const ZOOM_STEP := 1.25

## The adventure's record ([method AdventureSetup.resolve]) and its world.
var record: Dictionary = {}
var world: ShandalarWorld

## A few lines greeting the hero on arrival ([method EmbarkScreen.summary]),
## shown for [constant ARRIVAL_SECONDS].
var arrival := ""
const ARRIVAL_SECONDS := 8.0

var view: WorldView
var _map: WorldMap
var _hud: Label
var _hint: Label
var _arrival: Label
var _dragging := false
var _leaving := false


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
	_hud = Label.new()
	_hud.name = "Hud"
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color8(236, 222, 196))
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hud.add_theme_constant_override("shadow_offset_x", 1)
	_hud.add_theme_constant_override("shadow_offset_y", 1)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_hint = _hud.duplicate()
	_hint.name = "Hint"
	_hint.text = "Arrows or drag: look around · Wheel: zoom · Space: back to the hero · M: the map · Esc: leave"
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_hint)
	_arrival = Label.new()
	_arrival.name = "Arrival"
	_arrival.text = arrival
	_arrival.visible = arrival != ""
	_arrival.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrival.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_arrival.position.y = 64
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
	if world != null:
		show_world(world)


func show_world(shown: ShandalarWorld) -> void:
	world = shown
	view.world = world
	view.hero = Vector2(world.start)
	view.camera = Vector2(world.start)
	var hero: Dictionary = record.get("hero", {})
	view.hero_walker = String(hero.get("walker", "male"))
	world.explore_around(world.start_tile())
	_map.world = world
	_map.hero_tile = world.start_tile()
	_hud.text = _hud_text()
	view.queue_redraw()


func _hud_text() -> String:
	var hero: Dictionary = record.get("hero", {})
	var name := String(hero.get("name", ""))
	var lines: Array[String] = []
	if name != "":
		lines.append("%s · %s" % [name, AdventureSetup.DIFFICULTIES[int(record.get("difficulty", 0))]])
	lines.append("World seed %s" % String(record.get("seed_text", str(world.seed))))
	return "\n".join(lines)


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
	_hint.visible = not _map.visible
	_map.queue_redraw()


func _process(delta: float) -> void:
	if world == null or _map.visible:
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
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(view.zoom * ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(view.zoom / ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		look(-(event as InputEventMouseMotion).relative)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _map.visible:
			toggle_map()
		else:
			leave()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_M:
				toggle_map()
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
