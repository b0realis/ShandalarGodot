extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: room for the vertical
## scrollbar on the Magic Battle and Test hands panels.
##
## WAS: `_fit_panel` sized the panel to its settings' width, but settings
## taller than the window grow a vertical bar, and the bar's width (8 px)
## comes out of the scroller's: the page was 8 px wider than what showed —
## at the shipped 1280x800 window too. No sideways bar appeared for so
## little, but focus still followed: tabbing or pointing the pad at a row
## that spans the page slid the whole page 8 px to the left, its left edge
## cut, with no bar to slide it back. NOW the panel makes room for the bar
## when there will be one; a window truly narrower than the settings still
## scrolls sideways.


func after_each() -> void:
	SetupScreen.forget_choices()
	Settings.clear_value(TestHandsScreen.LAST_KEY)
	Settings.clear_value(TestHandsScreen.SAVED_KEY)


## [param screen] at [param window], laid out.
func _at(screen: Control, window: Vector2) -> ScrollContainer:
	screen.size = window
	screen._fit_panel()
	for i in 3:
		await get_tree().process_frame
	return (screen._panel_content as Control).get_parent() as ScrollContainer


## The focusable control whose right edge is furthest right.
func _rightmost_focusable(root: Node) -> Control:
	var best: Control = null
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var control := node as Control
		if control == null or control.focus_mode != Control.FOCUS_ALL \
				or not control.is_visible_in_tree():
			continue
		if best == null or control.get_global_rect().end.x > best.get_global_rect().end.x:
			best = control
	return best


## The page shows whole, and focusing its rightmost row leaves it there.
func _assert_page_fits(scroll: ScrollContainer, what: String) -> void:
	var content := scroll.get_child(0) as Control
	assert_true(scroll.get_v_scroll_bar().visible, "%s: the settings scroll at 1280x800" % what)
	assert_gte(scroll.get_h_scroll_bar().page, content.size.x,
		"%s: the page is no wider than what shows" % what)
	var right := _rightmost_focusable(content)
	assert_not_null(right)
	if right == null:
		return
	right.grab_focus()
	for i in 3:
		await get_tree().process_frame
	assert_eq(scroll.scroll_horizontal, 0,
		"%s: focusing %s did not slide the page sideways" % [what, right])


func test_magic_battle_at_the_shipped_window() -> void:
	var screen: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var scroll: ScrollContainer = await _at(screen, Vector2(1280, 800))
	await _assert_page_fits(scroll, "Magic Battle")


func test_test_hands_with_a_long_list_at_the_shipped_window() -> void:
	var bench: TestHandsScreen = load("res://game/test_hands_screen.tscn").instantiate()
	bench.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	add_child_autofree(bench)
	await get_tree().process_frame
	for i in 6:
		bench.add_card(0, DuelPosition.TABLE, "Plains")
		bench.add_card(1, DuelPosition.TABLE, "Mountain")
	var scroll: ScrollContainer = await _at(bench, Vector2(1280, 800))
	await _assert_page_fits(scroll, "Test hands")


func test_a_window_narrower_than_the_settings_still_scrolls_sideways() -> void:
	var screen: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var scroll: ScrollContainer = await _at(screen, Vector2(412, 915))
	assert_lte(screen._panel.size.x, 412.0, "the panel stays inside the window")
	assert_true(scroll.get_h_scroll_bar().visible, "and the rest is a sideways scroll away")


func test_a_tall_window_needs_no_room_for_a_bar() -> void:
	var screen: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var scroll: ScrollContainer = await _at(screen, Vector2(1920, 1600))
	assert_false(scroll.get_v_scroll_bar().visible, "everything shows")
	assert_eq(scroll.size.x, (scroll.get_child(0) as Control).size.x,
		"so the panel is the settings' width, nothing added")
