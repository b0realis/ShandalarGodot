extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: the Showcase over an
## open graveyard or exile pile.
##
## WAS: opening a pile lifts the docked big card (the Showcase) over the
## view's dim so the pile's cards can fill it — but Godot finds a click by
## tree order, not by z, and the view is the later sibling: it took every
## click on the Showcase it was drawn under. A left click on the Showcase
## closed the pile ("anywhere outside a card"), and a right click never
## reached `@MENU_FULLCARD`. NOW the view is not there to be clicked where
## the Showcase is drawn over it (`GraveyardView._has_point`).

var screen: DuelScreen
## On its own layer above the runner's panel, as test_graveyard_view.gd
## stages its real clicks.
var _stage: CanvasLayer
var _xform: Transform2D


func before_each() -> void:
	_stage = CanvasLayer.new()
	_stage.layer = 200
	add_child_autofree(_stage)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	_stage.add_child(screen)
	await get_tree().process_frame
	_xform = get_tree().root.get_final_transform()
	var game: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), game._next_instance_id, 0)
	game._next_instance_id += 1
	game._instances[inst.id] = inst
	inst.zone = Mtg.Zone.GRAVEYARD
	game.players[0].graveyard.append(inst)


func after_each() -> void:
	if screen._full_card_menu != null:
		screen._full_card_menu.hide()
	await get_tree().process_frame


func _button(button: int, pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = _xform * at
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(button: int, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _xform * at
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await get_tree().process_frame
	_button(button, true, at)
	await get_tree().process_frame
	_button(button, false, at)
	await get_tree().process_frame
	await get_tree().process_frame


## Wall-clock, which the view's settle reads.
func _settle() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 <= GraveyardView.SETTLE_MS + 30:
		await get_tree().process_frame


func _open() -> Vector2:
	screen._open_graveyard(0)
	await _settle()
	assert_true(screen.graveyard_is_open(), "control: the pile is open")
	assert_gt(screen._card_preview.z_index, screen._grave_view.z_index,
		"control: the Showcase is drawn over the dim")
	return screen._card_preview.get_global_rect().get_center()


func test_a_click_on_the_showcase_leaves_the_pile_open() -> void:
	var at: Vector2 = await _open()
	await _click(MOUSE_BUTTON_LEFT, at)
	assert_true(screen.graveyard_is_open(), "the Showcase's click is the Showcase's")


func test_a_right_click_on_the_showcase_opens_its_menu() -> void:
	var at: Vector2 = await _open()
	await _click(MOUSE_BUTTON_RIGHT, at)
	assert_true(screen._full_card_menu.visible, "@MENU_FULLCARD over the open pile")


func test_a_click_on_the_dim_still_closes_the_pile() -> void:
	await _open()
	var board := screen._board_area()
	await _click(MOUSE_BUTTON_LEFT, Vector2(board.end.x - 8, board.position.y + 8))
	assert_false(screen.graveyard_is_open(), "s30's click anywhere outside")
