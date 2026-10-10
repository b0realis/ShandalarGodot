extends GutTest
## THE READER'S `Text` TOGGLE ([FullscreenCard], 2026-10-10) — the owner:
## *"as when players click on large card to show it fullscreen they
## sometimes want to examine the art! So they should be able to toggle off
## and on the large text rectangle. The default should be small on the
## full screen card."* The reader used to grow the text box over the art
## for every long card with no way back. Pinned here: it opens on the 1997
## box; the button at the card's bottom right (and Enter) switches it and
## the choice is kept; the click on it does not close the reader; the
## sidebar's own Expand is never touched; and the button stands beside the
## card where there is room and in the hint's row where there is not.

var viewport: SubViewport
var source: CardPreview
var viewer: FullscreenCard
var _saved_cards: Variant
var _saved_text: Variant
var _saved_expand: Variant


func _keep(key: String) -> Variant:
	return Settings.get_value(key, null) if Settings.has_value(key) else null


func _put_back(key: String, value: Variant) -> void:
	if value == null:
		Settings.clear_value(key)
	else:
		Settings.set_value(key, value)


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_saved_cards = _keep("fullscreen_cards")
	_saved_text = _keep(FullscreenCard.FULL_TEXT_SETTING)
	_saved_expand = _keep(CardPreview.EXPAND_SETTING)
	Settings.set_value("fullscreen_cards", true, false)
	Settings.clear_value(FullscreenCard.FULL_TEXT_SETTING)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	source = CardPreview.new()
	source.docked = true
	source.position = Vector2(40, 40)
	viewport.add_child(source)
	source.show_card(CardInstance.new(CardRegistry.get_card(_longest_card()), 1, 0))
	viewer = FullscreenCard.new()
	viewport.add_child(viewer)
	viewer.watch(source, func() -> bool: return true)
	await get_tree().process_frame


func after_each() -> void:
	viewer.dismiss()
	_put_back("fullscreen_cards", _saved_cards)
	_put_back(FullscreenCard.FULL_TEXT_SETTING, _saved_text)
	_put_back(CardPreview.EXPAND_SETTING, _saved_expand)
	await get_tree().process_frame


## The card whose text most needs the large box — the one the toggle is for.
func _longest_card() -> String:
	var longest := ""
	var length := -1
	for card_name in CardRegistry.all_names():
		var text := CardRegistry.get_card(card_name).oracle_text
		if text.length() > length:
			longest = card_name
			length = text.length()
	return longest


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	viewport.push_input(move)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		viewport.push_input(event)


func _enter() -> void:
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = down
		viewport.push_input(key)


func _text_top() -> float:
	return viewer._card._oracle.anchor_top


func test_the_reader_opens_on_the_1997_box() -> void:
	assert_false(FullscreenCard.full_text_wanted(), "small until the player says otherwise")
	assert_true(viewer.open_card())
	assert_false(viewer._card.text_is_expanded())
	assert_almost_eq(_text_top(), float(CardPreview.TEXT_TOP + 0.019), 0.001,
		"the longest card in the pool, in the printed box: the art is clear")
	assert_eq(viewer._text_toggle.text, "Text: 1997")
	assert_false(viewer._text_toggle.button_pressed)
	assert_true(viewer._text_toggle.is_visible_in_tree())


func test_a_click_on_the_toggle_grows_the_box_and_keeps_the_reader_open() -> void:
	assert_true(viewer.open_card())
	_click(viewer._text_toggle.get_global_rect().get_center())
	assert_true(viewer.is_open(), "the toggle's click is the toggle's, not a close")
	assert_true(viewer._card.text_is_expanded())
	assert_lt(_text_top(), float(CardPreview.TEXT_TOP + 0.019) - 0.01,
		"the long card's box has grown up over the art")
	assert_eq(viewer._text_toggle.text, "Text: full")
	assert_true(viewer._text_toggle.button_pressed)
	assert_true(FullscreenCard.full_text_wanted(), "and the choice is kept")
	_click(viewer._text_toggle.get_global_rect().get_center())
	assert_true(viewer.is_open())
	assert_false(viewer._card.text_is_expanded(), "and back")
	assert_eq(viewer._text_toggle.text, "Text: 1997")
	assert_false(FullscreenCard.full_text_wanted())


func test_the_choice_is_there_next_time() -> void:
	assert_true(viewer.open_card())
	viewer.toggle_text()
	viewer.dismiss()
	assert_true(viewer.open_card())
	assert_true(viewer._card.text_is_expanded(), "reopened on the large box the player chose")
	assert_eq(viewer._text_toggle.text, "Text: full")


func test_enter_switches_it_and_a_click_elsewhere_still_closes() -> void:
	assert_true(viewer.open_card())
	_enter()
	assert_true(viewer.is_open())
	assert_true(viewer._card.text_is_expanded(), "Enter — a pad's A, the R36's X — switches it")
	assert_string_contains(viewer._hint.text, "Enter: text")
	_click(viewer._card.get_global_rect().get_center())
	assert_false(viewer.is_open(), "a click on the card still closes the reader")


func test_the_sidebars_expand_is_its_own() -> void:
	CardPreview.set_expand(true)
	source.set_text_expanded(true)
	assert_true(viewer.open_card())
	assert_false(viewer._card.text_is_expanded(),
		"the sidebar's Expand does not decide the reader's box")
	viewer.toggle_text()
	viewer.toggle_text()
	assert_true(CardPreview.expand_wanted(), "and the reader's toggle never writes the sidebar's")
	assert_true(source.text_is_expanded())


func test_the_toggle_stands_at_the_cards_bottom_right() -> void:
	assert_true(viewer.open_card())
	# What the game's window gives it: never narrower than 1280 (the
	# stretch's `expand` aspect), so the card is fitted to the height and
	# there is room beside it.
	for dimensions in [Vector2i(1280, 800), Vector2i(1280, 960), Vector2i(1422, 800)]:
		viewport.size = dimensions
		await get_tree().process_frame
		var card := viewer._card.get_global_rect()
		var toggle := viewer._text_toggle.get_global_rect()
		assert_gte(toggle.position.x, card.end.x, "%s: beside the card, not over it" % dimensions)
		assert_almost_eq(toggle.end.y, card.end.y, 0.5, "%s: level with its bottom" % dimensions)
		assert_lte(toggle.end.x, float(dimensions.x), "%s: on the screen" % dimensions)
	# A portrait phone, or a square: no room beside the card, so the toggle
	# takes the right of the hint's row and the hint gives it the room.
	for dimensions in [Vector2i(360, 640), Vector2i(720, 720)]:
		viewport.size = dimensions
		await get_tree().process_frame
		var card := viewer._card.get_global_rect()
		var toggle := viewer._text_toggle.get_global_rect()
		var hint := viewer._hint.get_global_rect()
		assert_gte(toggle.position.y, card.end.y, "%s: below the card" % dimensions)
		assert_lte(toggle.end.x, float(dimensions.x), "%s: on the screen" % dimensions)
		assert_lte(toggle.end.y, float(dimensions.y), "%s: on the screen" % dimensions)
		assert_lte(hint.end.x, toggle.position.x, "%s: the hint stops short of it" % dimensions)
