extends GutTest
## THE DECK BUILDER'S KEYBOARD CURSOR — the owner, 2026-09-08:
##
##   *"In the deck builder, left and right arrow should select cards in
##    the below strip and scroll to new cards left and right. Enter
##    button should add a card to the deck. (We had this enter to add but
##    it is not working now?)"*
##
## Two halves. [CardArea.handle_key] is the cursor itself — a ring the
## arrows walk along the cards, a page that turns to keep it in view,
## Enter as a click on the ringed card — pinned by calling it directly.
## [DeckBuilderScreen._input] is WHO GETS THE KEYS, and that is the half
## that was broken: Enter added a card only while the type-ahead held the
## keyboard, and any click on a card or a stone took it away. So the
## routing is driven through `Viewport.push_input`, the engine's own path
## — focus owner, the focus hop between buttons, `ui_accept` on a stone —
## because a test that called the handler by hand would have passed
## before the fix too.

var screen: DeckBuilderScreen


func before_each() -> void:
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	_let_go()


func after_each() -> void:
	_let_go()


## Nothing holds the keyboard — the state a freshly opened screen is in.
func _let_go() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


func _strip() -> CardArea:
	return screen._inventory


func _key(code: Key, shift := false, ctrl := false, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.echo = echo
	return event


## Straight to the surface, as Godot delivers a key to the focus owner.
func _tap(area: CardArea, code: Key, shift := false) -> void:
	area.handle_key(_key(code, shift))


## Through the engine — the focus owner, the focus hop, `_input` and all.
func _press(code: Key, shift := false) -> void:
	get_viewport().push_input(_key(code, shift))
	var up := _key(code, shift)
	up.pressed = false
	get_viewport().push_input(up)


func _card_at(area: CardArea, index: int) -> String:
	return area._visible_entries()[index][0].card_name


# ================================================= 1. THE CURSOR ITSELF ==

func test_the_first_arrow_stands_the_cursor_on_the_pages_first_card() -> void:
	var strip := _strip()
	strip.grab_focus()
	assert_eq(strip.cursor_index(), -1, "nothing selected to begin with")
	_tap(strip, KEY_RIGHT)
	assert_eq(strip.cursor_index(), 0, "the first arrow selects, it does not skip")
	assert_eq(strip.offset(), 0, "and the page did not move")


func test_right_and_left_walk_it_one_card_at_a_time() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_RIGHT)
	_tap(strip, KEY_RIGHT)
	_tap(strip, KEY_RIGHT)
	assert_eq(strip.cursor_index(), 2)
	assert_eq(strip.cursor_entry().card_name, _card_at(strip, 2))
	_tap(strip, KEY_LEFT)
	assert_eq(strip.cursor_index(), 1)
	_tap(strip, KEY_LEFT)
	_tap(strip, KEY_LEFT)
	assert_eq(strip.cursor_index(), 0, "Left stops at the first card")


func test_up_and_down_are_the_same_walk_on_a_one_row_strip() -> void:
	var strip := _strip()
	strip.grab_focus()
	assert_eq(strip.rows(), 1, "the Inventory is one row")
	_tap(strip, KEY_DOWN)
	_tap(strip, KEY_DOWN)
	assert_eq(strip.cursor_index(), 1)
	_tap(strip, KEY_UP)
	assert_eq(strip.cursor_index(), 0)


func test_the_ring_sits_on_the_cursors_card() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_RIGHT)
	_tap(strip, KEY_RIGHT)
	var ring: Panel = strip._cursor_ring
	assert_true(ring.visible, "the ring shows")
	var cell: Control = strip.cell_nodes()[1]
	assert_eq(ring.position, cell.position - Vector2(CardArea.RING_OUT, CardArea.RING_OUT),
		"half a gap outside the second card")
	assert_eq(ring.size, MiniCard.SIZE + Vector2(CardArea.RING_OUT, CardArea.RING_OUT) * 2.0)
	assert_eq(ring.z_index, CardArea.RING_Z, "over the pile marker's plate")
	assert_eq(ring.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and it takes no click")
	var box: StyleBoxFlat = ring.get_theme_stylebox("panel")
	assert_eq(box.border_color, MiniCard.HIGHLIGHT_COLORS[MiniCard.Highlight.OPTIONAL],
		"the duel's own 'you may' ink")
	assert_eq(box.border_width_left, CardArea.RING_WIDTH)
	assert_false(box.draw_center, "a ring, not a plate")


func test_the_ring_is_only_shown_while_the_surface_has_the_keyboard() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_RIGHT)
	assert_true(strip._cursor_ring.visible)
	strip.release_focus()
	assert_false(strip._cursor_ring.visible, "the keyboard left, the promise with it")
	assert_eq(strip.cursor_index(), 0, "but the cursor remembers where it stood")
	strip.grab_focus()
	assert_true(strip._cursor_ring.visible, "and comes back with it")


func test_walking_off_the_right_edge_turns_the_page() -> void:
	var strip := _strip()
	strip.grab_focus()
	var page := strip.page_size()
	assert_gt(strip.entry_count(), page * 2, "a list longer than a page")
	for _i in page:
		_tap(strip, KEY_RIGHT)
	assert_eq(strip.cursor_index(), page - 1, "the last card of the first page")
	assert_eq(strip.offset(), 0, "still the first page")
	_tap(strip, KEY_RIGHT)
	assert_eq(strip.cursor_index(), page, "one more")
	assert_eq(strip.offset(), strip.scroll_step(), "and the page turned by one step to show it")
	assert_true(strip._cursor_ring.visible, "the ring is still on screen")
	assert_eq(strip._cursor_ring.position + Vector2(CardArea.RING_OUT, CardArea.RING_OUT),
		strip.cell_nodes()[page - 1].position, "on the last slot")


func test_walking_back_off_the_left_edge_turns_it_back() -> void:
	var strip := _strip()
	strip.grab_focus()
	var page := strip.page_size()
	strip.set_cursor(page + 2)
	var turned := strip.offset()
	assert_eq(turned, 3, "set_cursor turned the page just far enough to show it")
	var steps := 0
	while strip.cursor_index() > turned and steps < page:
		_tap(strip, KEY_LEFT)
		steps += 1
	assert_eq(strip.offset(), turned, "walking within the page moves nothing")
	assert_eq(strip.cursor_index(), turned, "down to the page's first card")
	_tap(strip, KEY_LEFT)
	assert_eq(strip.cursor_index(), turned - 1)
	assert_eq(strip.offset(), turned - 1, "one more turns the page back a step")


func test_an_arrow_with_the_cursor_off_the_page_lands_on_the_page_not_the_cursor() -> void:
	# The type-ahead relists and rewinds; a cursor kept by name may be
	# pages away. The keys act on what is in view.
	var strip := _strip()
	strip.grab_focus()
	strip.set_cursor(30)
	strip.reset_scroll()
	assert_eq(strip.cursor_index(), 30, "kept")
	assert_false(strip._cursor_ring.visible, "but off the page, so unringed")
	_tap(strip, KEY_RIGHT)
	assert_eq(strip.cursor_index(), 0, "the arrow started again from what is in view")
	assert_eq(strip.offset(), 0, "and did not drag the page to card 30")


func test_end_and_home_go_to_the_ends_of_the_list() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_RIGHT)
	_tap(strip, KEY_END)
	assert_eq(strip.cursor_index(), strip.entry_count() - 1)
	assert_eq(strip.offset(), strip.max_offset(), "the last page")
	assert_true(strip._cursor_ring.visible)
	_tap(strip, KEY_HOME)
	assert_eq(strip.cursor_index(), 0)
	assert_eq(strip.offset(), 0)


func test_page_down_carries_the_cursor_in_its_slot() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_RIGHT)
	_tap(strip, KEY_RIGHT)
	_tap(strip, KEY_RIGHT)
	assert_eq(strip.cursor_index(), 2)
	_tap(strip, KEY_PAGEDOWN)
	var turned := strip.offset()
	assert_gt(turned, 0, "the page turned")
	assert_eq(strip.cursor_index(), turned + 2, "the cursor kept its slot on the new page")
	_tap(strip, KEY_PAGEUP)
	assert_eq(strip.offset(), 0)
	assert_eq(strip.cursor_index(), 2)


func test_without_a_cursor_the_paging_keys_scroll_as_they_always_did() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_PAGEDOWN)
	assert_gt(strip.offset(), 0)
	assert_eq(strip.cursor_index(), -1, "a page turn selects nothing")
	_tap(strip, KEY_END)
	assert_eq(strip.offset(), strip.max_offset())
	assert_eq(strip.cursor_index(), -1)
	_tap(strip, KEY_HOME)
	assert_eq(strip.offset(), 0)


func test_the_showcase_follows_the_cursor() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_RIGHT)
	_tap(strip, KEY_RIGHT)
	assert_eq(screen._showcase._name_label.text, _card_at(strip, 1),
		"the big card is the ringed one")


func test_a_click_stands_the_cursor_on_the_card_it_hit() -> void:
	var strip := _strip()
	var cell: CardArea.Cell = strip.cell_nodes()[3]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	strip._on_cell_input(click, cell)
	assert_eq(strip.cursor_index(), 3)
	assert_true(strip.has_focus())
	assert_eq(screen.deck.count_of(cell.card_name), 1, "the click still adds")
	_tap(strip, KEY_RIGHT)
	assert_eq(strip.cursor_index(), 4, "and the arrows carry on from there")


# ================================================================ 2. ENTER ==

func test_enter_adds_the_ringed_card() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_RIGHT)
	_tap(strip, KEY_RIGHT)
	var name := strip.cursor_entry().card_name
	_tap(strip, KEY_ENTER)
	assert_eq(screen.deck.count_of(name), 1, "one copy in")
	_tap(strip, KEY_KP_ENTER)
	assert_eq(screen.deck.count_of(name), 2, "the keypad's Enter is Enter")
	assert_eq(strip.cursor_index(), 1, "the cursor stayed where it was")


func test_a_held_enter_adds_once() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_RIGHT)
	var name := strip.cursor_entry().card_name
	_tap(strip, KEY_ENTER)
	strip.handle_key(_key(KEY_ENTER, false, false, true))
	strip.handle_key(_key(KEY_ENTER, false, false, true))
	assert_eq(screen.deck.count_of(name), 1, "the repeats poured nothing in")


func test_enter_with_no_cursor_takes_the_pages_first_card() -> void:
	var strip := _strip()
	strip.grab_focus()
	var first := _card_at(strip, 0)
	_tap(strip, KEY_ENTER)
	assert_eq(screen.deck.count_of(first), 1, "what you see first is what you get")
	assert_eq(strip.cursor_index(), 0, "and it is ringed now, so the next Enter is legible")


func test_shift_enter_sends_it_to_the_sideboard() -> void:
	var strip := _strip()
	strip.grab_focus()
	_tap(strip, KEY_RIGHT)
	var name := strip.cursor_entry().card_name
	_tap(strip, KEY_ENTER, true)
	assert_eq(screen.deck.count_of(name), 0, "not the deck")
	assert_eq(screen.deck.sideboard.get(name, 0), 1, "the sideboard, as Shift-click does")


func test_enter_on_an_empty_list_does_nothing_and_says_so_nowhere_new() -> void:
	screen.filter.set_text("zzzz nothing")
	screen._refresh_inventory()
	await get_tree().process_frame
	var strip := _strip()
	strip.grab_focus()
	var before := screen.deck.total()
	assert_true(strip.handle_key(_key(KEY_ENTER)), "the key is still the surface's")
	assert_eq(screen.deck.total(), before)
	assert_eq(strip.cursor_index(), -1)


func test_enter_on_the_deck_surface_removes_a_copy_and_the_cursor_keeps_its_card() -> void:
	screen._add_one("Lightning Bolt")
	screen._add_one("Lightning Bolt")
	screen._add_one("Serra Angel")
	await get_tree().process_frame
	var area: CardArea = screen._deck_area
	area.grab_focus()
	_tap(area, KEY_RIGHT)
	assert_eq(area.cursor_entry().card_name, _card_at(area, 0))
	var name := area.cursor_entry().card_name
	var had := screen.deck.count_of(name)
	_tap(area, KEY_ENTER)
	assert_eq(screen.deck.count_of(name), had - 1, "one copy out")
	if had > 1:
		assert_eq(area.cursor_entry().card_name, name,
			"the relist kept the cursor on its card")
	else:
		assert_eq(area.cursor_index(), -1, "the card is gone, and the cursor with it")


func test_the_cursor_follows_its_card_through_a_relist() -> void:
	screen._add_one("Serra Angel")
	screen._add_one("Wrath of God")
	await get_tree().process_frame
	var area: CardArea = screen._deck_area
	area.grab_focus()
	area.set_cursor(1)
	var name := area.cursor_entry().card_name
	screen._add_one("Air Elemental")
	await get_tree().process_frame
	assert_eq(area.cursor_entry().card_name, name, "same card")
	var where := -1
	for i in area.entry_count():
		if _card_at(area, i) == name:
			where = i
	assert_eq(area.cursor_index(), where, "wherever the relist put it")


func test_up_and_down_walk_the_deck_by_a_row() -> void:
	var names := ["Air Elemental", "Serra Angel", "Wrath of God", "Lightning Bolt",
		"Llanowar Elves", "Giant Growth", "Dark Ritual", "Hypnotic Specter",
		"Counterspell", "Disenchant", "Swords to Plowshares", "Shivan Dragon"]
	for name in names:
		screen._add_one(name)
	await get_tree().process_frame
	var area: CardArea = screen._deck_area
	var cols := area.columns()
	assert_gt(cols, 1)
	assert_gt(area.entry_count(), cols)
	area.grab_focus()
	_tap(area, KEY_RIGHT)
	_tap(area, KEY_DOWN)
	assert_eq(area.cursor_index(), mini(cols, area.entry_count() - 1), "a row down")
	_tap(area, KEY_UP)
	assert_eq(area.cursor_index(), 0, "and back")
	_tap(area, KEY_RIGHT)
	assert_eq(area.cursor_index(), 1, "Right is one card on a row-major surface")


func test_owns_key_names_the_keys_and_refuses_the_chords() -> void:
	assert_true(CardArea.owns_key(_key(KEY_RIGHT)))
	assert_true(CardArea.owns_key(_key(KEY_ENTER, true)), "Shift+Enter is one of them")
	assert_false(CardArea.owns_key(_key(KEY_S, false, true)), "Ctrl+S is the screen's")
	assert_false(CardArea.owns_key(_key(KEY_RIGHT, false, true)), "Ctrl+Right is nobody's")
	assert_false(CardArea.owns_key(_key(KEY_Q)))
	var wheel := InputEventMouseButton.new()
	assert_false(CardArea.owns_key(wheel))


# ==================================================== 3. WHO GETS THE KEYS ==

func test_with_nothing_focused_the_arrow_goes_to_the_strip() -> void:
	assert_null(get_viewport().gui_get_focus_owner(), "a fresh screen holds nothing")
	_press(KEY_RIGHT)
	assert_true(_strip().has_focus(), "the strip took the keyboard")
	assert_eq(_strip().cursor_index(), 0, "and the arrow landed")
	_press(KEY_RIGHT)
	assert_eq(_strip().cursor_index(), 1, "from then on it is the strip's own")


func test_with_nothing_focused_enter_adds_a_card() -> void:
	# The owner's own case: open the builder, press Enter.
	var first := _card_at(_strip(), 0)
	_press(KEY_ENTER)
	assert_eq(screen.deck.count_of(first), 1)


func test_from_a_focused_stone_the_arrow_goes_to_the_strip_not_the_next_stone() -> void:
	var stone: Button = screen._filter_bar._buttons[0]
	stone.grab_focus()
	assert_true(stone.has_focus())
	_press(KEY_RIGHT)
	assert_true(_strip().has_focus(), "the strip, not a neighbouring button")
	assert_eq(_strip().cursor_index(), 0)


func test_from_a_focused_stone_enter_adds_a_card_and_leaves_the_stone_alone() -> void:
	var stone: Button = screen._filter_bar._buttons[0]
	stone.grab_focus()
	var lit := stone.button_pressed
	var first := _card_at(_strip(), 0)
	_press(KEY_ENTER)
	assert_eq(stone.button_pressed, lit, "the stone did not flip")
	assert_eq(screen.deck.count_of(first), 1, "the card went in")


func test_the_type_ahead_keeps_its_own_keys() -> void:
	var box := screen._filter_bar.search_field
	box.text = "lightning bol"
	screen.filter.set_text("lightning bol")
	screen._refresh_inventory()
	await get_tree().process_frame
	box.grab_focus()
	_press(KEY_LEFT)
	assert_true(box.has_focus(), "an arrow in the box moves the caret, nothing else")
	assert_eq(_strip().cursor_index(), -1)
	_press(KEY_ENTER)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1,
		"Enter in the box still adds the first match")
	assert_true(box.has_focus(), "and keeps the keyboard, so four Enters are four Bolts")


func test_a_click_on_a_card_then_enter_adds_another() -> void:
	# The sequence the owner hit: click a card, press Enter, nothing.
	var strip := _strip()
	var cell: CardArea.Cell = strip.cell_nodes()[2]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	strip._on_cell_input(click, cell)
	assert_eq(screen.deck.count_of(cell.card_name), 1)
	_press(KEY_ENTER)
	assert_eq(screen.deck.count_of(cell.card_name), 2, "Enter added the clicked card again")
	_press(KEY_RIGHT)
	_press(KEY_ENTER)
	assert_eq(screen.deck.count_of(strip.cell_nodes()[3].card_name), 1, "the next one")


func test_an_open_dialog_keeps_the_keyboard() -> void:
	screen._open_stats()
	await get_tree().process_frame
	assert_true(screen._dialog_busy())
	var before := screen.deck.total()
	_press(KEY_RIGHT)
	_press(KEY_ENTER)
	assert_false(_strip().has_focus(), "the strip did not take the keyboard from a dialog")
	assert_eq(_strip().cursor_index(), -1)
	assert_eq(screen.deck.total(), before, "and Enter added nothing")
	screen.open_dialogs()[-1].dismiss()


func test_the_q_menu_keeps_its_arrows() -> void:
	screen._toggle_deck_menu()
	await get_tree().process_frame
	assert_true(screen.is_menu_open())
	_press(KEY_DOWN)
	assert_true(screen.is_menu_open(), "still up")
	assert_eq(_strip().cursor_index(), -1, "the arrow was the menu's")
	screen._close_deck_menu()
