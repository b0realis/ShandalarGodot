extends GutTest
## THE OWNER'S CURSOR RULING (2026-11-10): "Something wrong with target icon
## in duel!!! - it is too large (2x approx)", then "remove high res switch,
## use normal size, the color applies to the pointers the game already
## draws … Colourchange should ignore duel crosshair". And the Booster
## Draft's building time "color it gold so it is not missed".

var _had: Variant = null


func before_each() -> void:
	_had = Settings.get_value(Settings.CURSOR_COLOR, null) \
		if Settings.has_value(Settings.CURSOR_COLOR) else null


func after_each() -> void:
	if _had == null:
		Settings.clear_value(Settings.CURSOR_COLOR)
	else:
		Settings.set_value(Settings.CURSOR_COLOR, _had)


func test_the_walker_wears_the_chosen_color_inside_its_ink() -> void:
	for color_name in ["Gold", "Electric blue", "Red"]:
		Settings.set_value(Settings.CURSOR_COLOR, color_name)
		var drawing := WorldCursors.drawing(WorldCursors.Kind.WALK)
		var head := drawing.get_pixel(70, 24)
		assert_true(head.is_equal_approx(Settings.CURSOR_COLORS[color_name]),
			"%s: the walker's head is %s (got %s)" % [color_name, color_name, head])
		assert_true(drawing.get_pixel(70, 8).is_equal_approx(WorldCursors.INK),
			"%s: outlined in ink" % color_name)
		assert_eq(WorldCursors.image(WorldCursors.Kind.WALK).get_size(), Vector2i(32, 32),
			"one, normal size")


func test_black_is_outlined_light_so_it_shows_on_the_map() -> void:
	Settings.set_value(Settings.CURSOR_COLOR, "Black")
	var drawing := WorldCursors.drawing(WorldCursors.Kind.ARROW)
	assert_true(drawing.get_pixel(20, 40).is_equal_approx(Settings.CURSOR_COLORS["Black"]),
		"the arrow's body is black")
	var outline := WorldCursors._ink()
	assert_gt(outline.get_luminance(), 0.6, "and its outline light, not ink")
	assert_true(drawing.get_pixel(7, 40).is_equal_approx(outline),
		"left of the arrow's edge, the light outline")


func test_an_unknown_stored_color_is_gold() -> void:
	Settings.set_value(Settings.CURSOR_COLOR, "Mauve")
	assert_eq(Settings.cursor_color_name(), "Gold")
	Settings.set_value(Settings.CURSOR_COLOR, 7)
	assert_eq(Settings.cursor_color_name(), "Gold")


func test_the_duel_crosshair_is_normal_size_and_keeps_its_colors() -> void:
	if GameSkin.texture("target_cursor") == null:
		pending("the crosshair is the imported 1997 skin's Target.pic")
		return
	Settings.set_value(Settings.CURSOR_COLOR, "Electric blue")
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	duel.config = DuelConfig.hotseat_default()
	add_child_autofree(duel)
	await get_tree().process_frame
	duel._set_target_cursor(true)
	var frame: Image = duel._target_cursor.get_image()
	assert_eq(frame.get_size(), Vector2i(61, 61), "1997's 61 pixels, not twice them")
	var sheet := GameSkin.texture("target_cursor")
	var cell := Rect2i(0, 0, sheet.get_height(), sheet.get_height())
	var original := GameSkin.original(sheet).get_region(cell)
	assert_eq(frame.get_data(), original.get_data(), "the 1997 frame's own colors")
	duel._set_target_cursor(false)


func test_the_draft_time_is_gold() -> void:
	var setup: DraftSetup = DraftSetup.new()
	add_child_autofree(setup)
	await get_tree().process_frame
	var spin: SpinBox = setup.fields["minutes"]
	assert_eq(spin.get_line_edit().get_theme_color("font_color"), UiChrome.CHOSEN, "the number in gold")
	var well := spin.get_line_edit().get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(well.border_color, UiChrome.CHOSEN, "its well rimmed in gold")
	var row := spin.get_parent()
	var words := row.get_child(0) as VBoxContainer
	assert_eq((words.get_child(0) as Label).get_theme_color("font_color"), UiChrome.CHOSEN,
		"\"Building time (minutes)\" in gold")
	var boosters: SpinBox = setup.fields["boosters"]
	assert_ne(boosters.get_line_edit().get_theme_color("font_color"), UiChrome.CHOSEN,
		"the other rows as they were")
