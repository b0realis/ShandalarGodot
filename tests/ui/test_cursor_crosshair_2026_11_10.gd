extends GutTest
## Needs the imported 1997 skin (the crosshair is its Target.pic).
## THE TARGETING CROSSHAIR AT ITS NORMAL SIZE (the owner, 2026-11-10: "the
## target icon in duel … is too large (2x approx)", "remove high res switch,
## use normal size … Colourchange should ignore duel crosshair"): 1997's own
## 61-pixel frame in its own colors, whatever Cursor color says.

var _had: Variant = null


func before_each() -> void:
	_had = Settings.get_value(Settings.CURSOR_COLOR, null) \
		if Settings.has_value(Settings.CURSOR_COLOR) else null


func after_each() -> void:
	if _had == null:
		Settings.clear_value(Settings.CURSOR_COLOR)
	else:
		Settings.set_value(Settings.CURSOR_COLOR, _had)


func test_the_duel_crosshair_is_normal_size_and_keeps_its_colors() -> void:
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
