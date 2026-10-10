extends GutTest
## [QoL] The shared full-screen reader: no gameplay or hidden-card access.

var viewport: SubViewport
var source: CardPreview
var viewer: FullscreenCard
var _saved: Variant
var _saved_text: Variant
var _touch_active: bool
var presses := 0


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_saved = Settings.get_value("fullscreen_cards", false) if Settings.has_value("fullscreen_cards") else null
	_saved_text = Settings.get_value(FullscreenCard.FULL_TEXT_SETTING, false) \
		if Settings.has_value(FullscreenCard.FULL_TEXT_SETTING) else null
	Settings.clear_value(FullscreenCard.FULL_TEXT_SETTING)
	_touch_active = TouchControls.is_active()
	Settings.set_value("fullscreen_cards", true, false)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var button := Button.new()
	button.position = Vector2(900, 500)
	button.size = Vector2(150, 60)
	button.pressed.connect(func() -> void: presses += 1)
	viewport.add_child(button)
	presses = 0
	source = CardPreview.new()
	source.docked = true
	source.position = Vector2(40, 40)
	viewport.add_child(source)
	source.show_card(CardInstance.new(CardRegistry.get_card("Grizzly Bears"), 1, 0))
	viewer = FullscreenCard.new()
	viewport.add_child(viewer)
	viewer.watch(source, func() -> bool: return true)
	await get_tree().process_frame


func after_each() -> void:
	viewer.dismiss()
	if _saved == null: Settings.clear_value("fullscreen_cards")
	else: Settings.set_value("fullscreen_cards", _saved)
	if _saved_text == null: Settings.clear_value(FullscreenCard.FULL_TEXT_SETTING)
	else: Settings.set_value(FullscreenCard.FULL_TEXT_SETTING, _saved_text)
	TouchControls.set_active(_touch_active)
	await get_tree().process_frame


func _click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	viewport.push_input(move)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = down
		event.position = at
		event.global_position = at
		viewport.push_input(event)


func test_click_opens_and_second_click_closes_without_changing_layout() -> void:
	var rect := source.get_global_rect()
	_click(rect.get_center())
	assert_true(viewer.is_open(), "opening release must not dismiss the card")
	assert_eq(viewer._card._shown, source._shown)
	assert_eq(source.get_global_rect(), rect, "the sidebar never moves or resizes")
	_click(viewer._card.get_global_rect().get_center())
	assert_false(viewer.is_open())
	assert_null(viewer._card._shown, "no retained hidden face")
	assert_eq(source.get_global_rect(), rect)


func test_option_off_preserves_normal_clicks_and_right_click_is_not_zoom() -> void:
	Settings.set_value("fullscreen_cards", false, false)
	_click(source.get_global_rect().get_center())
	assert_false(viewer.is_open())
	Settings.set_value("fullscreen_cards", true, false)
	_click(source.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	assert_false(viewer.is_open())


func test_card_back_and_hidden_source_cannot_be_enlarged() -> void:
	source.show_back()
	assert_false(viewer.open_card())
	source.show_card(CardInstance.new(CardRegistry.get_card("Swamp"), 2, 0))
	source.hide()
	assert_false(viewer.open_card())


func test_hiding_or_replacing_source_immediately_closes_the_view() -> void:
	assert_true(viewer.open_card())
	source.show_back()
	assert_false(viewer.is_open())
	assert_null(viewer._card._shown)
	source.show_card(CardInstance.new(CardRegistry.get_card("Swamp"), 2, 0))
	assert_true(viewer.open_card())
	source.hide()
	assert_false(viewer.is_open())
	source.show()
	assert_true(viewer.open_card())
	source.show_card(CardInstance.new(CardRegistry.get_card("Forest"), 3, 0))
	assert_false(viewer.is_open())


func test_same_card_refresh_keeps_reader_open_and_preserves_printing() -> void:
	var printing := String(CardPrintings.choices("Grizzly Bears")[-1].id)
	source.show_card(source._shown, printing)
	assert_true(viewer.open_card())
	assert_eq(viewer._card._shown_printing_set, printing)
	assert_eq(viewer._card._artist_label.text, source._artist_label.text)
	source.show_card(source._shown, printing)
	assert_true(viewer.is_open())
	assert_false(viewer._card.text_is_expanded(), "the reader opens on the 1997 box (2026-10-10)")
	assert_false(source.text_is_expanded(), "reading does not change the sidebar")


func test_modal_guard_can_refuse_the_view() -> void:
	viewer._may_open = func() -> bool: return false
	assert_false(viewer.open_card())


func test_click_to_close_does_not_press_button_beneath() -> void:
	assert_true(viewer.open_card())
	_click(Vector2(960, 530))
	assert_false(viewer.is_open())
	assert_eq(presses, 0)
	_click(Vector2(960, 530))
	assert_eq(presses, 1, "the next deliberate click works normally")


func test_escape_and_controller_cancel_close_without_passing_through() -> void:
	assert_true(viewer.open_card())
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	viewport.push_input(key)
	assert_false(viewer.is_open())
	assert_true(viewer.open_card())
	var cancel := InputEventAction.new()
	cancel.action = "duel_cancel"
	cancel.pressed = true
	viewport.push_input(cancel)
	assert_false(viewer.is_open())


func test_keyboard_and_focus_are_contained_and_restored() -> void:
	var button := viewport.get_child(0) as Button
	button.grab_focus()
	assert_true(viewer.open_card())
	for code in [KEY_ENTER, KEY_SPACE, KEY_RIGHT, KEY_BACKSPACE, KEY_Q]:
		for down in [true, false]:
			var key := InputEventKey.new()
			key.keycode = code
			key.pressed = down
			viewport.push_input(key)
	assert_true(viewer.is_open())
	assert_eq(presses, 0)
	assert_eq(viewport.gui_get_focus_owner(), viewer._shade)
	viewer.dismiss()
	assert_eq(viewport.gui_get_focus_owner(), button)


func test_resize_fits_square_wide_and_portrait_screens_without_distortion() -> void:
	assert_true(viewer.open_card())
	for dimensions in [Vector2i(720, 720), Vector2i(1280, 800), Vector2i(360, 640)]:
		viewport.size = dimensions
		await get_tree().process_frame
		var rect := viewer._card.get_global_rect()
		assert_almost_eq(viewer._card.scale.x, viewer._card.scale.y, 0.001)
		assert_gte(rect.position.x, 0.0)
		assert_gte(rect.position.y, 0.0)
		assert_lte(rect.end.x, float(dimensions.x))
		assert_lte(rect.end.y, viewer._hint.position.y)
		assert_almost_eq(rect.get_center().x, dimensions.x * 0.5, 0.01)
		assert_eq(viewer._shade.size, Vector2(dimensions))
		assert_lte(viewer._hint.get_global_rect().end.y, float(dimensions.y),
			"the close hint must not acquire an offscreen wrapped minimum height")


## "Some say the text is a bit blurred" (2026-09-30): the reader is the
## 300-px preview under a node scale, which automatic font oversampling
## does not follow. While it is open the viewport oversamples by the
## reader's factor; the moment it closes, the automatic value is back.
func test_open_reader_sharpens_the_fonts_and_closing_restores_automatic() -> void:
	assert_eq(viewport.oversampling_override, 0.0, "automatic before")
	assert_true(viewer.open_card())
	var factor := viewer._card.scale.x
	assert_gt(factor, 1.5, "a reader on 1280x800 is well over the sidebar's size")
	assert_almost_eq(viewport.oversampling_override, factor, 0.001,
		"the automatic value (1 on an unstretched viewport) times the reader's factor")
	viewport.size = Vector2i(720, 720)
	await get_tree().process_frame
	assert_almost_eq(viewport.oversampling_override, viewer._card.scale.x, 0.001,
		"a resize while open refits the sharpening with the card")
	viewer.dismiss()
	assert_eq(viewport.oversampling_override, 0.0, "automatic again")
	viewport.size = Vector2i(1280, 800)
	await get_tree().process_frame
	assert_eq(viewport.oversampling_override, 0.0, "a resize while closed sets nothing")


func test_touch_emulation_is_not_double_consumed() -> void:
	TouchControls.set_active(true)
	assert_true(viewer.open_card())
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.device = InputEvent.DEVICE_ID_EMULATION
	viewer._input(event)
	assert_true(viewer.is_open(), "TouchControls swallows the emulation")
	event.device = TouchControls.SYNTH_DEVICE
	viewer._input(event)
	assert_false(viewer.is_open(), "only its translated click dismisses")


func test_emulated_mouse_works_when_touch_layer_is_off() -> void:
	TouchControls.set_active(false)
	assert_true(viewer.open_card())
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.device = InputEvent.DEVICE_ID_EMULATION
	viewer._input(event)
	assert_false(viewer.is_open())
