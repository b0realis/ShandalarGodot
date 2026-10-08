extends GutTest
## THE TITLE MENU'S BULLET ([MenuBullet], 2026-10-08) — the 1997 menu's
## Celtic-knot square with its pink gem at the left of each title-menu
## button: at rest, hovered (the pointer, the focus, and the press — the
## owner's three states: the 1997 press frame is a smaller 22x22 bullet,
## which read as the icon shrinking), and dimmed for the two placeholders,
## Shandalar and Save / Load, which stay clickable. The art is the
## imported skin's `begin_menu` sheet; a stand-in sheet is put in the skin's cache here, one colour per 24px
## row, so a cell is known by its colour and no player's art is needed.

const ROW_COLOURS := 18


func _sheet() -> ImageTexture:
	var image := Image.create(265, 24 * ROW_COLOURS, false, Image.FORMAT_RGBA8)
	for row in ROW_COLOURS:
		image.fill_rect(Rect2i(0, row * 24, 265, 24), Color8(row * 10, 255 - row * 10, 128))
	return ImageTexture.create_from_image(image)


func before_each() -> void:
	GameSkin._texture_cache[MenuBullet.SHEET] = _sheet()


func after_each() -> void:
	GameSkin._texture_cache.erase(MenuBullet.SHEET)


func _row_of(bullet: MenuBullet) -> int:
	var cell := bullet.texture as AtlasTexture
	return int(cell.region.position.y) / MenuBullet.CELL_HEIGHT


func test_the_state_table() -> void:
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_NORMAL, false, false), MenuBullet.AT_REST)
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_HOVER, false, false), MenuBullet.HOVERED)
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_NORMAL, true, false), MenuBullet.HOVERED,
		"the keyboard and pad focus lights it the way the pointer does")
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_PRESSED, false, false), MenuBullet.HOVERED,
		"the click shows the hover cell, never the 22x22 sunken one")
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_HOVER_PRESSED, true, false), MenuBullet.HOVERED)
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_DISABLED, false, false), MenuBullet.DIMMED)
	assert_eq(MenuBullet.state_for(BaseButton.DRAW_HOVER, true, true), MenuBullet.DIMMED,
		"a placeholder stays dimmed whatever the pointer does")


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
	assert_eq(_row_of(bullet), MenuBullet.HOVERED)


func test_without_the_imported_sheet_the_button_is_unchanged() -> void:
	GameSkin._texture_cache[MenuBullet.SHEET] = null
	var button := Button.new()
	add_child_autofree(button)
	assert_null(MenuBullet.attach(button))
	assert_eq(button.get_child_count(), 0)


func test_the_title_menu_wears_eight_bullets_two_dimmed() -> void:
	var title: Node = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	var rows := {}
	for bullet in title.find_children("MenuBullet", "", true, false):
		rows[(bullet.get_parent() as Button).text] = (bullet as MenuBullet).frame
	assert_eq(rows.size(), 8, str(rows))
	assert_eq(rows.get("Shandalar"), MenuBullet.DIMMED)
	assert_eq(rows.get("Save / Load"), MenuBullet.DIMMED)
	assert_eq(rows.get("Magic Battle"), MenuBullet.HOVERED, "it holds the focus the shell opens on")
	for label in ["Gauntlet", "Deck Builder", "Options", "Help", "Exit"]:
		assert_eq(rows.get(label), MenuBullet.AT_REST, label)
