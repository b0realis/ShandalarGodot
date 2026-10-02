extends GutTest
## [QoL] Real screens keep their controls, privacy and local AI safe while reading.

var _saved: Variant
var _touch_active: bool
var stage: CanvasLayer


func before_each() -> void:
	_saved = Settings.get_value("fullscreen_cards", false) if Settings.has_value("fullscreen_cards") else null
	Settings.set_value("fullscreen_cards", true, false)
	_touch_active = TouchControls.is_active()
	stage = CanvasLayer.new()
	stage.layer = 10
	add_child_autofree(stage)


func after_each() -> void:
	if _saved == null: Settings.clear_value("fullscreen_cards")
	else: Settings.set_value("fullscreen_cards", _saved)
	TouchControls.set_active(_touch_active)
	for i in 3: await get_tree().process_frame


func _builder() -> DeckBuilderScreen:
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	stage.add_child(screen)
	return screen


func _duel() -> DuelScreen:
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.hotseat_default()
	screen.config.rng_seed = 42
	screen.config.pace = 0.0
	stage.add_child(screen)
	return screen


func _press(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		get_viewport().push_input(event)


func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		get_viewport().push_input(event)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	get_viewport().push_input(move, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)


func test_builder_click_enlarges_without_adding_or_removing_cards() -> void:
	var screen := _builder()
	await get_tree().process_frame
	_press(KEY_RIGHT)
	_press(KEY_ENTER)
	var count := screen.deck.total()
	var cursor := screen._inventory.cursor_index()
	var rect := screen._showcase.get_global_rect()
	assert_gt(count, 0)
	_click(rect.get_center())
	assert_true(screen._fullscreen_card.is_open())
	for code in [KEY_ENTER, KEY_BACKSPACE, KEY_RIGHT, KEY_Q]: _press(code)
	assert_eq(screen.deck.total(), count)
	assert_eq(screen._inventory.cursor_index(), cursor)
	assert_false(screen.is_menu_open())
	assert_eq(screen._showcase.get_global_rect(), rect)
	_press(KEY_ESCAPE)
	assert_false(screen._fullscreen_card.is_open())
	assert_false(screen.is_menu_open(), "Escape only dismisses the reader")
	_press(KEY_ENTER)
	assert_eq(screen.deck.total(), count + 1, "normal card keys work after closing")


func test_builder_dialogs_prevent_opening() -> void:
	var screen := _builder()
	await get_tree().process_frame
	screen._show_in_showcase(CardRegistry.get_card("Forest"))
	screen._open_deck_menu()
	assert_false(screen._fullscreen_card.open_card())


func test_leaving_a_screen_with_reader_open_is_clean(duel = use_parameters([true, false])) -> void:
	var screen: Control = _duel() if duel else _builder()
	await get_tree().process_frame
	var preview: CardPreview = screen._card_preview if duel else screen._showcase
	preview.show_card(CardInstance.new(CardRegistry.get_card("Forest"), -1, 0))
	assert_true(screen._fullscreen_card.open_card())
	screen.queue_free()
	for i in 3: await get_tree().process_frame
	assert_false(is_instance_valid(screen), "closing a scene cannot restore focus into it")


func test_duel_click_blocks_phase_keys_and_preserves_right_click_menu() -> void:
	var screen := _duel()
	await get_tree().process_frame
	screen._card_preview.show_card(screen.game.players[0].hand[0])
	_click(screen._card_preview.get_global_rect().get_center())
	assert_true(screen._fullscreen_card.is_open())
	var before := screen.game.log_lines.size()
	for code in [KEY_SPACE, KEY_ENTER, KEY_Q]: _press(code)
	assert_true(screen._fullscreen_card.is_open())
	assert_eq(screen.game.log_lines.size(), before)
	assert_false(screen.is_paused())
	_press(KEY_ESCAPE)
	assert_false(screen._fullscreen_card.is_open())
	assert_false(screen.is_paused())
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.global_position = Vector2(150, 400)
	screen._on_showcase_input(right)
	assert_true(screen._full_card_menu.visible)
	assert_false(screen._fullscreen_card.is_open())
	screen._full_card_menu.hide()


func test_local_ai_and_auto_passing_wait_then_resume_after_reading() -> void:
	var screen := _duel()
	await get_tree().process_frame
	# Install a live AI at the current priority seat only after setup, so
	# the fixture cannot race its zero-delay timer before the reader opens.
	var pid := screen.game.priority_player
	screen.config.pilots[pid] = AiProfile.wizard()
	screen._ais[pid] = AiPlayer.new(pid, AiProfile.wizard())
	screen._humans.erase(pid)
	screen._card_preview.show_card(screen.game.players[0].hand[0])
	assert_true(screen._fullscreen_card.open_card())
	var before := screen.game.log_lines.size()
	screen._ai_step()
	screen._maybe_schedule_ai()
	assert_false(screen._ai_pending, "no new timer while reading")
	assert_false(screen._auto_pass_applies())
	assert_eq(screen.game.log_lines.size(), before, "an already-armed timer cannot act")
	screen._fullscreen_card.dismiss()
	for i in 10: await get_tree().process_frame
	assert_gt(screen.game.log_lines.size(), before, "closing resumes local play")


func test_hotseat_concealment_clears_enlarged_card_immediately() -> void:
	var screen := _duel()
	await get_tree().process_frame
	screen.config.hotseat_privacy = true
	screen._sync_hotseat()
	screen._toggle_hotseat_hand(screen._hotseat_seat)
	screen._card_preview.show_card(screen.game.players[screen._hotseat_seat].hand[0])
	assert_true(screen._fullscreen_card.open_card())
	screen._toggle_hotseat_hand(screen._hotseat_seat)
	assert_false(screen._fullscreen_card.is_open())
	assert_null(screen._fullscreen_card._card._shown)


func test_touch_tap_opens_and_next_tap_closes_without_reopening(translator = use_parameters([true, false])) -> void:
	TouchControls.set_active(translator)
	var screen := _builder()
	await get_tree().process_frame
	screen._show_in_showcase(CardRegistry.get_card("Forest"))
	var at := screen._showcase.get_global_rect().get_center()
	for expected in [true, false, true, false]:
		for down in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.pressed = down
			touch.position = get_tree().root.get_final_transform() * at
			Input.parse_input_event(touch)
			for i in 3: await get_tree().process_frame
		assert_eq(screen._fullscreen_card.is_open(), expected)
	assert_eq(screen.deck.total(), 0)


func test_touch_close_does_not_press_underlying_button(translator = use_parameters([true, false])) -> void:
	TouchControls.set_active(translator)
	var screen := _builder()
	await get_tree().process_frame
	screen._show_in_showcase(CardRegistry.get_card("Forest"))
	assert_true(screen._fullscreen_card.open_card())
	var hits := []
	var button := Button.new()
	button.position = Vector2(900, 500)
	button.size = Vector2(150, 60)
	button.z_index = 300
	button.pressed.connect(func() -> void: hits.append(true))
	stage.add_child(button)
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = get_tree().root.get_final_transform() * Vector2(960, 530)
		Input.parse_input_event(touch)
		for i in 3: await get_tree().process_frame
	assert_false(screen._fullscreen_card.is_open())
	assert_true(hits.is_empty())


# ================================================ the key reads the card ==
## The R36 Ultra tester, 2026-10-02: *"an easy way to bring a card up
## full-size when you need to read it"*. The `duel_read` keystroke — R,
## R3 on a pad, R2 through the ArkOS mapping — opens the reader on the
## sidebar's card on both screens, whether or not click-to-enlarge is
## on, and the same keystroke closes it. Behind the screen's own gate:
## nothing opens under the pause menu or the Deck Builder's menu.

func test_the_read_key_opens_and_closes_the_reader_in_the_duel(switch = use_parameters([true, false])) -> void:
	Settings.set_value("fullscreen_cards", switch, false)
	var screen := _duel()
	await get_tree().process_frame
	screen._card_preview.show_card(screen.game.players[0].hand[0])
	var before := screen.game.log_lines.size()
	_press(KEY_R)
	assert_true(screen._fullscreen_card.is_open(), "R opens the reader (switch %s)" % switch)
	assert_true(screen._fullscreen_card._hint.text.contains("R or R3"), "the hint names the key")
	for code in [KEY_SPACE, KEY_ENTER]: _press(code)
	assert_true(screen._fullscreen_card.is_open(), "the duel's keys wait under it")
	_press(KEY_R)
	assert_false(screen._fullscreen_card.is_open(), "R again closes it")
	assert_eq(screen.game.log_lines.size(), before, "nothing else happened")
	assert_false(screen.is_paused())


func test_the_pad_button_reads_the_card_in_the_duel() -> void:
	var screen := _duel()
	await get_tree().process_frame
	screen._card_preview.show_card(screen.game.players[0].hand[0])
	_pad(JOY_BUTTON_RIGHT_STICK)
	assert_true(screen._fullscreen_card.is_open(), "R3 opens the reader")
	_pad(JOY_BUTTON_RIGHT_STICK)
	assert_false(screen._fullscreen_card.is_open(), "R3 again closes it")


func test_the_read_key_waits_under_the_pause_menu() -> void:
	var screen := _duel()
	await get_tree().process_frame
	screen._card_preview.show_card(screen.game.players[0].hand[0])
	screen._open_pause()
	_press(KEY_R)
	assert_false(screen._fullscreen_card.is_open())
	assert_true(screen.is_paused(), "and the pause menu stands")
	screen._close_pause()


func test_the_read_key_opens_and_closes_the_reader_in_the_builder(switch = use_parameters([true, false])) -> void:
	Settings.set_value("fullscreen_cards", switch, false)
	var screen := _builder()
	await get_tree().process_frame
	_press(KEY_RIGHT)
	var count := screen.deck.total()
	var cursor := screen._inventory.cursor_index()
	screen._show_in_showcase(CardRegistry.get_card("Forest"))
	_press(KEY_R)
	assert_true(screen._fullscreen_card.is_open(), "R opens the reader (switch %s)" % switch)
	for code in [KEY_ENTER, KEY_BACKSPACE, KEY_RIGHT]: _press(code)
	assert_eq(screen.deck.total(), count, "the card keys wait under it")
	assert_eq(screen._inventory.cursor_index(), cursor)
	_press(KEY_R)
	assert_false(screen._fullscreen_card.is_open(), "R again closes it")
	assert_false(screen.is_menu_open())
	assert_eq(screen.deck.total(), count)


func test_the_pad_button_reads_the_card_in_the_builder() -> void:
	var screen := _builder()
	await get_tree().process_frame
	screen._show_in_showcase(CardRegistry.get_card("Forest"))
	_pad(JOY_BUTTON_RIGHT_STICK)
	assert_true(screen._fullscreen_card.is_open(), "R3 opens the reader")
	_pad(JOY_BUTTON_RIGHT_STICK)
	assert_false(screen._fullscreen_card.is_open(), "R3 again closes it")
	assert_eq(screen.deck.total(), 0)


func test_the_read_key_waits_under_the_builder_menu() -> void:
	var screen := _builder()
	await get_tree().process_frame
	screen._show_in_showcase(CardRegistry.get_card("Forest"))
	screen._open_deck_menu()
	_press(KEY_R)
	assert_false(screen._fullscreen_card.is_open())
	assert_true(screen.is_menu_open(), "and the menu stands")
