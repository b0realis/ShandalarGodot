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
## A pinch zooms and a touchpad's two-finger slide looks, and a finger
## does what the mouse does ([TouchControls]).
## The floating panel ([WorldHud]) shows what the hero carries; its World
## Magics are cast with a click or 1–5 ([WorldMagic]); its options save,
## load (over the world), return to the title and exit the game. A small
## map, the quest pane and the clues float in panes the player may move;
## guide arrows point to the places that call the hero ([WorldGuides]).
## The towns, the encounters and the rest come next
## (`docs/adventure-implementation-notes.md`).

const LOOK_SPEED := 600.0   # screen pixels a second, at zoom 1
const ZOOM_STEP := 1.25
## A press that moves no further than this is a click, not a drag.
const CLICK_SLOP := 6.0
## Screen pixels a touchpad's two-finger slide looks for each unit of it.
const PAN_STEP := 24.0
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
## The arrows to the places that call the hero ([WorldGuides]).
var guides: WorldGuides
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
## The deck builder, open over the world ([AdventureBuilder]).
var _builder: AdventureBuilder
## The place visited, its pane over the world ([VisitPane]).
var _visit: VisitPane


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if world == null and not record.is_empty():
		world = AdventureSetup.make_world(record)
	view = WorldView.new()
	view.name = "View"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	guides = WorldGuides.new()
	guides.name = "Guides"
	guides.view = view
	guides.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(guides)
	_map = WorldMap.new()
	_map.name = "Map"
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.visible = false
	add_child(_map)
	_make_hud()
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


## The floating panel ([WorldHud]) and what its parts do.
func _make_hud() -> void:
	hud = WorldHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.map_pressed.connect(toggle_map)
	hud.hero_pressed.connect(hud.toggle_hero)
	hud.deck_pressed.connect(show_deck)
	hud.save_pressed.connect(save_now)
	hud.load_pressed.connect(open_load)
	hud.exit_pressed.connect(exit_game)
	hud.menu_pressed.connect(return_to_menu)
	hud.clues_pressed.connect(show_clues)
	hud.cast_pressed.connect(func(key: int) -> void: cast(key))
	hud.walk_requested.connect(func(tile: Vector2i) -> void: walk_to_tile(tile))
	hud.hovered.connect(func() -> void:
		_wear(WorldCursors.Kind.ARROW)
		hud.hide_place())
	hud.big_switched.connect(rebuild_hud, CONNECT_DEFERRED)


## THE PANEL MADE AGAIN, at the size the options now ask (big buttons),
## where the old one stood among the screen's layers.
func rebuild_hud() -> void:
	var at := hud.get_index()
	var old := hud
	old.name = "OldHud"
	_make_hud()
	move_child(hud, at)
	old.queue_free()
	if player != null:
		hud.show_player(player)
		_show_hero()


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
	var calling := WorldStatus.targets(player)
	hud.minimap.world = world
	hud.minimap.hero = Vector2(player.position)
	hud.minimap.marks = calling
	var guided: Array[Dictionary] = []
	if WorldHud.guides_wanted():
		guided = calling
	guides.targets = guided
	guides.bar_at_bottom = hud.bar_at_bottom
	var covered: Array[Rect2] = []
	for pane in [hud.minimap, hud.find_child("QuestPane", false, false)]:
		if pane != null and (pane as Control).visible:
			covered.append((pane as Control).get_global_rect())
	guides.avoid = covered
	guides.visible = not guides.targets.is_empty()
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
	_cover_world(true)
	_load_screen.tree_exited.connect(func() -> void:
		if is_inside_tree():
			_cover_world(false))
	return _load_screen


## A screen over the whole world (the deck builder, the saves): the panel,
## its panes and the arrows rest under it, drawing nothing.
func _cover_world(covered: bool) -> void:
	hud.visible = not covered
	guides.visible = not covered and not guides.targets.is_empty()
	view.visible = not covered


func loading() -> bool:
	return _load_screen != null and is_instance_valid(_load_screen) and not _load_screen.is_queued_for_deletion()


## EXIT GAME (the options): the adventure saved as it stands, then the
## game ends — as `Exit game` ends it from a duel.
func exit_game() -> void:
	save_now()
	_end_process()


## RETURN TO MAIN MENU (the options): the adventure saved as it stands,
## then the title screen.
func return_to_menu() -> void:
	leave()


## Ends the process; a seam so a test can count the exit instead.
func _end_process() -> void:
	get_tree().quit()


## A PLACE VISITED: the pane of what stands at [param tile] — a town, a
## castle, a lair, a dungeon whose clues are known — over the world, which
## waits under it ([VisitPane]); null when nothing there is visited.
func visit(tile: Vector2i) -> VisitPane:
	if visiting():
		return _visit
	var place := VisitPane.describe(player, tile)
	if place.is_empty():
		return null
	_wear(WorldCursors.Kind.ARROW)
	_dragging = false
	hud.close_panels()
	hud.hide_place()
	_visit = VisitPane.new()
	_visit.player = player
	_visit.place = place
	_visit.k = WorldHud.BIG if hud.big else 1.0
	add_child(_visit)
	_visit.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_visit.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_visit.grow_vertical = Control.GROW_DIRECTION_BOTH
	_visit.left.connect(_left_place, CONNECT_DEFERRED)
	if String(place["kind"]) in VisitPane.KINDS:
		player.log_event("visit", "Visited %s" % String(place["name"]))
	return _visit


func visiting() -> bool:
	return _visit != null and is_instance_valid(_visit) and not _visit.is_queued_for_deletion()


func _left_place(then: String) -> void:
	if visiting():
		_visit.queue_free()
	_visit = null
	_show_hero()
	if then == "deck":
		show_deck()


## THE CLUES (the frame's gate, F4): what the hero has learned of the
## castles and the dungeons ([WorldClues]).
func show_clues() -> void:
	hud.toggle_clues()


## CAST the World Magic of key [param key] (1–5, or a click on its icon)
## ([WorldMagic]): the hero set down elsewhere when it moves them, its
## words beside the panel. What [method WorldMagic.cast] answered.
func cast(key: int) -> Dictionary:
	if player == null:
		return {}
	var result := WorldMagic.cast(player, key)
	if result["moved"]:
		walk.stop()
		world.explore_around(player.tile())
		view.camera = Vector2(player.position)
	_show_hero()
	view.queue_redraw()
	if result["deck"]:
		var builder := show_deck()
		if builder != null:
			builder._say(String(result["said"]))
	elif String(result["said"]) != "":
		hud.say(result["said"])
	return result


## THE DECK (the frame's spellbook, F1, and Conjurer's Will): the
## adventure's deck builder over the world, which waits under it
## ([AdventureBuilder]); Done writes the decks back to the hero.
func show_deck() -> AdventureBuilder:
	if building():
		return _builder
	if player.cards.is_empty():
		hud.say("No cards yet.")
		return null
	_wear(-1)
	_dragging = false
	hud.close_panels()
	_cover_world(true)
	_builder = AdventureBuilder.new()
	_builder.name = "DeckBuilder"
	_builder.player = player
	_builder.closed.connect(_deck_closed)
	_builder.exit_requested.connect(exit_game)
	add_child(_builder)
	return _builder


func building() -> bool:
	return _builder != null and is_instance_valid(_builder) and not _builder.is_queued_for_deletion()


## The builder is done: the world again, its music, the deck's count.
func _deck_closed() -> void:
	if building():
		_builder.queue_free()
	_builder = null
	_cover_world(false)
	var music := get_node_or_null(^"/root/ShellMusic")
	if music != null:
		music.call(&"play")
	_show_hero()
	hud.say("Deck %d: %d cards" % [player.current_deck + 1, hud.cards_in_deck()])


## Walk to [param tile] (the way is found); true when there is a way. The
## place the hero stands on is visited again.
func walk_to_tile(tile: Vector2i) -> bool:
	if walk == null:
		return false
	if tile == player.tile() and not walk.is_walking():
		return visit(tile) != null
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
			# THE WALK ENDS AT A PLACE: it is visited [QoL: only the place
			# walked to — 1997 entered every town stepped on, and a way
			# found for the hero would wander into towns not chosen].
			if not walk.is_walking() and player.tile() == walk.destination \
					and visit(player.tile()) != null:
				break
	if ticks == MOST_TICKS:
		_tick_left = 0.0
	if ticks > 0:
		var lost := WorldStatus.check_quest(player)
		if lost != "":
			hud.say(lost)
		_show_hero()
		view.queue_redraw()
		if _map.visible:
			_map.queue_redraw()


## The tile under [param point] on the view.
func tile_at(point: Vector2) -> Vector2i:
	var at := view.unproject(point)
	return Vector2i(floori(at.x / 32.0), floori(at.y / 32.0))


## The place the hero can see and visit at [param tile] ([method
## VisitPane.describe]), or `{}`.
func place_at(tile: Vector2i) -> Dictionary:
	if player == null or world == null or not world.is_explored(tile.x, tile.y):
		return {}
	return VisitPane.describe(player, tile)


## The pointer over [param tile]: the place there ([constant
## WorldCursors.FOR_PLACE]), the walking man elsewhere.
func pointer_for(tile: Vector2i) -> WorldCursors.Kind:
	var place := place_at(tile)
	if place.is_empty():
		return WorldCursors.Kind.WALK
	return WorldCursors.FOR_PLACE.get(String(place["kind"]), WorldCursors.Kind.WALK)


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


## The window's close button on the world: the adventure is saved before
## the game ends (the deck builder, open, answers it itself).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player != null and not _leaving and not building():
		player.save(player.save_path("save"))


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
	_dragging = false
	hud.hide_place()
	guides.visible = not _map.visible and not guides.targets.is_empty()
	_arrival.visible = not _map.visible and arrival != ""
	if _map.visible:
		_wear(-1)
	_map.queue_redraw()


func _process(delta: float) -> void:
	if world == null or _map.visible or loading() or building() or visiting():
		return
	advance(delta * WorldHud.pace())
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
	if _map.visible or building() or visiting():
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
	elif event is InputEventMagnifyGesture:
		# A pinch on a touchpad or a touchscreen zooms.
		set_zoom(view.zoom * (event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		# Two fingers sliding on a touchpad look around.
		look((event as InputEventPanGesture).delta * PAN_STEP)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging and motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			_dragging = false
		if _dragging:
			if not _dragged and motion.position.distance_to(_pressed_at) > CLICK_SLOP:
				_dragged = true
			if _dragged:
				look(-motion.relative)
		# The place under the pointer: its pointer, and its kind and name
		# floating by it.
		var place := place_at(tile_at(motion.position))
		_wear(WorldCursors.FOR_PLACE.get(String(place.get("kind", "")), WorldCursors.Kind.WALK))
		if place.is_empty() or _dragged:
			hud.hide_place()
		else:
			hud.show_place(String(place["name"]), String(place["subtitle"]), motion.position)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or loading() or building() or visiting():
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
			KEY_F4:
				show_clues()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				cast((event as InputEventKey).keycode - KEY_0)
			KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5:
				cast((event as InputEventKey).keycode - KEY_KP_0)
			KEY_N:
				hud.show_minimap(not hud.minimap_shown())
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


## LEAVE THE WORLD for the title (Escape, Return to main menu): saved
## first, as Exit game does.
func leave() -> void:
	if _leaving:
		return
	save_now()
	_leaving = true
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://game/main.tscn")
