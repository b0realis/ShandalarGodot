extends GutTest
## THE TITLE MENU'S BULLET ([MenuBullet], 2026-10-08) — the 1997 menu's
## Celtic-knot square with its pink gem at the left of each title-menu
## button: at rest, hovered (the pointer, the focus, and the press — the
## owner's three states: the 1997 press frame is a smaller 22x22 bullet,
## which read as the icon shrinking), and dimmed for the two placeholders,
## Shandalar and Save / Load, which stay clickable. The art is the
## imported skin's `begin_menu` sheet; a stand-in sheet is put in the skin's cache here, one colour per 24px
## row, so a cell is known by its colour and no player's art is needed.
##
## AND IT LIGHTS FOR WHAT THE PLAYER IS USING (2026-10-10 playtest: *"the
## icon on Magic Battle button in main menu is sometimes highlighted even
## if you do not hover over the button"*): the pointer's button, or the
## focused one after an arrow, Tab or Enter — never the focus a mouse
## player never asked for, never both.

const ROW_COLOURS := 18

var _was_by_pointer := true


func _sheet() -> ImageTexture:
	var image := Image.create(265, 24 * ROW_COLOURS, false, Image.FORMAT_RGBA8)
	for row in ROW_COLOURS:
		image.fill_rect(Rect2i(0, row * 24, 265, 24), Color8(row * 10, 255 - row * 10, 128))
	return ImageTexture.create_from_image(image)


func before_each() -> void:
	GameSkin._texture_cache[MenuBullet.SHEET] = _sheet()
	_was_by_pointer = MenuBullet.by_pointer
	MenuBullet.by_pointer = true


func after_each() -> void:
	GameSkin._texture_cache.erase(MenuBullet.SHEET)
	MenuBullet.by_pointer = _was_by_pointer


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	return key


func _motion(at: Vector2) -> InputEventMouseMotion:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	return move


func _row_of(bullet: MenuBullet) -> int:
	var cell := bullet.texture as AtlasTexture
	return int(cell.region.position.y) / MenuBullet.CELL_HEIGHT


func test_the_state_table() -> void:
	# On the pointer: the button under it, and nothing else.
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_NORMAL, false, false), MenuBullet.AT_REST)
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_HOVER, false, false), MenuBullet.HOVERED)
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_NORMAL, true, false), MenuBullet.AT_REST,
		"the focus the title gives Magic Battle does not light it for a mouse player")
	# On the keys: the focused button, and nothing else.
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_NORMAL, true, false, false), MenuBullet.HOVERED,
		"the keyboard and pad focus lights it")
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_HOVER, false, false, false), MenuBullet.AT_REST,
		"a resting pointer's hover is not where the keys are")
	# Held down, whatever moved it.
	for pointer in [true, false]:
		assert_eq(MenuBullet.state_for(BaseButton.DRAW_PRESSED, false, false, pointer), MenuBullet.HOVERED,
			"the click shows the hover cell, never the 22x22 sunken one")
		assert_eq(MenuBullet.state_for(BaseButton.DRAW_HOVER_PRESSED, true, false, pointer), MenuBullet.HOVERED)
		assert_eq(MenuBullet.state_for(BaseButton.DRAW_DISABLED, false, false, pointer), MenuBullet.DIMMED)
		assert_eq(MenuBullet.state_for(BaseButton.DRAW_HOVER, true, true, pointer), MenuBullet.DIMMED,
			"a placeholder stays dimmed whatever the pointer does")


func test_what_says_pointer_and_what_says_keys() -> void:
	assert_eq(MenuBullet.input_kind(_motion(Vector2(5, 5))), MenuBullet.Kind.POINTER)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_eq(MenuBullet.input_kind(click), MenuBullet.Kind.POINTER)
	assert_eq(MenuBullet.input_kind(InputEventScreenTouch.new()), MenuBullet.Kind.POINTER)
	for code in [KEY_UP, KEY_DOWN, KEY_TAB, KEY_ENTER]:
		assert_eq(MenuBullet.input_kind(_key(code)), MenuBullet.Kind.KEYS, OS.get_keycode_string(code))
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_DOWN
	dpad.pressed = true
	assert_eq(MenuBullet.input_kind(dpad), MenuBullet.Kind.KEYS)
	for code in [KEY_PRINT, KEY_SHIFT, KEY_F12, KEY_M]:
		assert_eq(MenuBullet.input_kind(_key(code)), MenuBullet.Kind.NONE,
			"%s moves no focus, so it cannot light the focus behind a mouse player's back"
			% OS.get_keycode_string(code))
	var released := _key(KEY_DOWN)
	released.pressed = false
	assert_eq(MenuBullet.input_kind(released), MenuBullet.Kind.NONE)


func test_the_cells_are_the_sheets_last_four_rows() -> void:
	assert_eq([MenuBullet.AT_REST, MenuBullet.HOVERED, MenuBullet.PRESSED, MenuBullet.DIMMED], [14, 15, 16, 17])
	for state in [14, 15, 17]:
		var cell := MenuBullet.frame_texture(state) as AtlasTexture
		assert_eq(cell.region, Rect2(0, state * 24, 24, 24))


func test_a_button_wears_it_at_its_left_and_it_follows_the_button() -> void:
	var button := Button.new()
	button.text = "Magic Battle"
	button.custom_minimum_size = Vector2(228, 36)
	add_child_autofree(button)
	var bullet := MenuBullet.attach(button)
	assert_not_null(bullet)
	await get_tree().process_frame
	assert_eq(_row_of(bullet), MenuBullet.AT_REST)
	assert_eq(bullet.position, Vector2(MenuBullet.INSET, 6), "left inset, centred on 36px")
	assert_eq(bullet.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the click is the button's")
	button.disabled = true
	button.queue_redraw()
	await get_tree().process_frame
	assert_eq(_row_of(bullet), MenuBullet.DIMMED)
	button.disabled = false
	button.grab_focus()
	button.queue_redraw()
	await get_tree().process_frame
	assert_eq(_row_of(bullet), MenuBullet.AT_REST, "focused, but the player is on the pointer")
	bullet._input(_key(KEY_DOWN))
	assert_false(MenuBullet.by_pointer)
	assert_eq(_row_of(bullet), MenuBullet.HOVERED, "an arrow key: the focus is where the player is")
	bullet._input(_motion(Vector2(1000, 1000)))
	assert_true(MenuBullet.by_pointer)
	assert_eq(_row_of(bullet), MenuBullet.AT_REST, "the pointer moved, and not onto it")


func test_without_the_imported_sheet_the_button_is_unchanged() -> void:
	GameSkin._texture_cache[MenuBullet.SHEET] = null
	var button := Button.new()
	add_child_autofree(button)
	assert_null(MenuBullet.attach(button))
	assert_eq(button.get_child_count(), 0)


func _rows(title: Node) -> Dictionary:
	var rows := {}
	for bullet in title.find_children("MenuBullet", "", true, false):
		rows[(bullet.get_parent() as Button).text] = (bullet as MenuBullet).frame
	return rows


func test_the_title_menu_wears_eight_bullets_two_dimmed() -> void:
	var title: Node = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	var rows := _rows(title)
	assert_eq(rows.size(), 8, str(rows))
	assert_eq(rows.get("Shandalar"), MenuBullet.DIMMED)
	assert_eq(rows.get("Save / Load"), MenuBullet.DIMMED)
	for label in ["Magic Battle", "Gauntlet", "Deck Builder", "Options", "Help", "Exit"]:
		assert_eq(rows.get(label), MenuBullet.AT_REST, label)


## The playtest's report: Magic Battle holds the focus the title opens on,
## and its gem stayed lit for a player who never touched the keys. Lit
## for the keys once they are used, and dark again for the pointer.
func test_magic_battle_is_lit_only_for_the_keys() -> void:
	var title: Node = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	var battle := (title.find_children("MenuBullet", "", true, false)[0] as MenuBullet).get_parent() as Button
	assert_eq(battle.text, "Magic Battle")
	assert_true(battle.has_focus(), "the title still opens with the focus on it, for the pad")
	assert_eq(_rows(title).get("Magic Battle"), MenuBullet.AT_REST, "and its gem is dark")
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	var rows := _rows(title)
	assert_eq(rows.get("Gauntlet"), MenuBullet.HOVERED, "the arrow moved the focus and the gem with it")
	assert_eq(rows.get("Magic Battle"), MenuBullet.AT_REST, str(rows))
	get_viewport().push_input(_motion(Vector2(2, 2)), true)
	await get_tree().process_frame
	rows = _rows(title)
	for label in ["Magic Battle", "Gauntlet", "Deck Builder", "Options", "Help", "Exit"]:
		assert_eq(rows.get(label), MenuBullet.AT_REST, "the mouse moved, over no button: " + label)
