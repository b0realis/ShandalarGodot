extends GutTest
## THE DECK AREA SCROLLS SMOOTHLY, AND SAYS WHEN THERE IS MORE — the owner,
## 2026-11-10:
##
##   *"Deck builder smooth scrolling of cards and purple arrows at the
##    right indicating that the deck is larger than window !!!! (Smooth
##    scrolling i mean you can scroll continuously and show half a card in
##    bottom row) - now some players miss bottom rows in large decks in
##    deck builder."*
##
## At 1280x800 the deck area held exactly four rows, and it stepped by whole
## rows, so a 70-card deck looked like a 24-card one with a thin bar beside
## it. Pinned here: the side-barred surface stands at a PIXEL offset (the
## wheel glides half a row, the bar and the keys move by the pixel, a cut
## row shows at the edge), the paging still builds only the rows the view
## touches and rotates widgets rather than rebuilding them, the quilt and
## the keyboard ring ride the fraction with their cards, and the purple
## arrows stand at the two ends of the right edge exactly while there are
## cards that way. The Inventory, on its bottom bar, still steps.

var screen: DeckBuilderScreen


func before_each() -> void:
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	# Deferred: set straight after add_child, Godot warns that a full-rect
	# node's size is overridden after _ready() (one warning per test).
	screen.set_deferred("size", Vector2(1280, 800))
	await get_tree().process_frame


func after_each() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null:
		owner.release_focus()


## The deck area holding [param n] DIFFERENT cards — one copy each of the
## Inventory's first [param n], put in through the model and listed once.
func _deck_of(n: int) -> CardArea:
	var added := 0
	for entry in screen._inventory._visible_entries():
		if added >= n:
			break
		if screen.deck.add(entry[0].card_name) == "":
			added += 1
	screen.refresh()
	return screen._deck_area


func _big() -> CardArea:
	return _deck_of(70)


func _wheel(down := true, factor := 1.0, at := Vector2(40, 40)) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.factor = factor
	event.position = at
	return event


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _name_at(area: CardArea, index: int) -> String:
	return area._visible_entries()[index][0].card_name


func _ring_on(area: CardArea, cell: Control) -> bool:
	return area._cursor_ring.visible and area._cursor_ring.position \
		== cell.position - Vector2(CardArea.RING_OUT, CardArea.RING_OUT)


# ================================================== 1. THE WHEEL GLIDES ==

func test_the_deck_area_scrolls_smoothly_and_the_inventory_does_not() -> void:
	assert_true(screen._deck_area.smooth(), "the side-barred deck area")
	assert_false(screen._inventory.smooth(), "the Inventory still steps")
	assert_false(screen._sideboard_area.smooth(), "and so does the sideboard strip")


func test_a_wheel_notch_glides_half_a_row_not_a_whole_one() -> void:
	var area := _big()
	assert_eq(area.scroll_px(), 0.0)
	area._gui_input(_wheel())
	assert_true(area.is_processing(), "it glides over frames")
	assert_eq(area.scroll_px(), 0.0, "rather than jumping on the notch")
	area.settle_scroll()
	assert_almost_eq(area.scroll_px(), area.row_pitch() * CardArea.WHEEL_ROWS, 0.001,
		"half a row on")
	assert_eq(area.offset(), 0, "the first row is still partly in view")
	assert_false(area.is_processing(), "and nothing ticks once it has landed")


func test_the_glide_is_seen_moving_between_frames_and_lands_exactly() -> void:
	var area := _big()
	var target := area.row_pitch() * CardArea.WHEEL_ROWS
	area._gui_input(_wheel())
	area._process(1.0 / 60.0)
	var first := area.scroll_px()
	assert_gt(first, 0.0, "one frame in, it has moved")
	assert_lt(first, target, "but not all the way")
	area._process(1.0 / 60.0)
	assert_gt(area.scroll_px(), first, "the next frame moves it on")
	for _i in 60:
		area._process(1.0 / 60.0)
	assert_eq(area.scroll_px(), target, "and it lands on the notch exactly")
	assert_false(area.is_processing())


func test_quick_notches_add_up_instead_of_restarting() -> void:
	var area := _big()
	for _i in 3:
		area._gui_input(_wheel())
	area.settle_scroll()
	assert_almost_eq(area.scroll_px(), area.row_pitch() * CardArea.WHEEL_ROWS * 3.0, 0.001)
	area._gui_input(_wheel(false))
	area.settle_scroll()
	assert_almost_eq(area.scroll_px(), area.row_pitch() * CardArea.WHEEL_ROWS * 2.0, 0.001,
		"and the wheel back up takes one off")


func test_a_precise_touchpad_moves_its_fraction_of_a_notch() -> void:
	var area := _big()
	area._gui_input(_wheel(true, 0.25))
	area.settle_scroll()
	assert_almost_eq(area.scroll_px(), area.row_pitch() * CardArea.WHEEL_ROWS * 0.25, 0.001)


func test_a_touchpad_pan_follows_the_fingers_at_once() -> void:
	var area := _big()
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(0, 1.5)
	area._gui_input(pan)
	assert_almost_eq(area.scroll_px(), area.row_pitch() * CardArea.WHEEL_ROWS * 1.5, 0.001,
		"no glide: the fingers are the glide")


func test_the_wheel_over_a_card_glides_the_same() -> void:
	var area := _big()
	area._on_cell_input(_wheel(), area.cell_nodes()[2])
	area.settle_scroll()
	assert_almost_eq(area.scroll_px(), area.row_pitch() * CardArea.WHEEL_ROWS, 0.001)


func test_a_deck_that_fits_does_not_scroll_at_all() -> void:
	var area := _deck_of(10)
	assert_eq(area.max_scroll_px(), 0.0, "two rows fit in four")
	assert_false(area._bar.visible, "no bar")
	area._gui_input(_wheel())
	area.settle_scroll()
	assert_eq(area.scroll_px(), 0.0)
	assert_false(area.is_processing(), "and the notch started nothing")


# =========================================== 2. HALF A CARD AT THE EDGE ==

func test_a_scrolled_deck_shows_a_cut_row_at_the_bottom() -> void:
	var area := _big()
	area.scroll_px_to(area.row_pitch() * 0.5)
	var cut := 0
	for cell in area.cell_nodes():
		var top := cell.position.y
		var bottom := top + MiniCard.SIZE.y
		assert_lt(top, area.size.y, "%s: no card is laid wholly below the view" % cell.card_name)
		assert_gt(bottom, 0.0, "%s: nor wholly above it" % cell.card_name)
		if bottom > area.size.y:
			cut += 1
	assert_eq(cut, area.columns(), "a whole row is cut by the bottom edge — the 'there is more'")


func test_every_card_stands_at_its_row_less_the_fraction_bound_to_its_own_entry() -> void:
	var area := _big()
	var pitch := area.row_pitch()
	var cols := area.columns()
	var lead := CardArea.GAP / 2.0
	for px in [0.0, 1.0, 37.5, pitch - 1.0, pitch, pitch * 2.25, area.max_scroll_px()]:
		area.scroll_px_to(px)
		var first := int(floorf(area.scroll_px() / pitch))
		var frac := area.scroll_px() - first * pitch
		assert_eq(area.offset(), first * cols, "offset at %.1f" % px)
		var cells := area.cell_nodes()
		assert_gt(cells.size(), 0)
		for i in cells.size():
			var want := Vector2(lead.x + (i % cols) * (MiniCard.SIZE.x + CardArea.GAP.x),
				lead.y + (i / cols) * pitch - frac)
			assert_almost_eq(cells[i].position.x, want.x, 0.001, "slot %d x at %.1f" % [i, px])
			assert_almost_eq(cells[i].position.y, want.y, 0.001, "slot %d y at %.1f" % [i, px])
			assert_eq(cells[i].card_name, _name_at(area, area.offset() + i),
				"slot %d is entry offset+%d at %.1f" % [i, i, px])


func test_the_page_is_the_rows_in_view_plus_one_at_most() -> void:
	# The paging rule of the class header: never the whole deck's worth of
	# widgets — the rows the view touches, one more at the most.
	var area := _big()
	var cols := area.columns()
	var most := (int(ceilf(area.size.y / area.row_pitch())) + 1) * cols
	var px := 0.0
	while px <= area.max_scroll_px():
		area.scroll_px_to(px)
		assert_lte(area._cells.size(), most, "widgets built at %.0f" % px)
		assert_lte(area.cell_nodes().size(), most)
		px += 13.0
	assert_lt(area._cells.size(), area.entry_count(), "far fewer widgets than cards")


func test_crossing_into_a_new_row_rotates_the_widgets_instead_of_rebuilding() -> void:
	var area := _big()
	var cols := area.columns()
	var second_row: CardArea.Cell = area.cell_nodes()[cols]
	var name := second_row.card_name
	area.scroll_px_to(area.row_pitch() + 10.0)
	assert_eq(area.offset(), cols, "the second row is the first one now")
	assert_same(area.cell_nodes()[0], second_row, "the same widget, moved up")
	assert_eq(area.cell_nodes()[0].card_name, name, "still holding its card")


func test_a_slide_inside_one_row_redraws_no_card() -> void:
	var area := _big()
	area.scroll_px_to(10.0)
	var faces := {}
	for cell in area.cell_nodes():
		faces[cell] = cell.face.instance
	area.scroll_px_to(40.0)
	for cell in area.cell_nodes():
		if faces.has(cell):
			assert_same(cell.face.instance, faces[cell],
				"%s kept its face: a pixel redraws nothing" % cell.card_name)


func test_the_end_puts_the_last_card_whole_on_the_bottom_edge() -> void:
	var area := _big()
	area.scroll_to_end()
	assert_almost_eq(area.scroll_px(), area.content_height() - area.size.y, 0.001,
		"the true end, not the row before it")
	var cells := area.cell_nodes()
	var last: CardArea.Cell = cells[-1]
	assert_eq(last.card_name, _name_at(area, area.entry_count() - 1), "the list's last card")
	assert_almost_eq(last.position.y + MiniCard.SIZE.y, area.size.y - CardArea.GAP.y / 2.0, 0.001,
		"whole, half a gap above the edge — its carving's own margin")
	area.home()
	assert_eq(area.scroll_px(), 0.0, "and Home really goes home")


# ===================================================== 3. THE QUILT RIDES ==

## The carving under the card at [param cell], from the quilt's own layout.
func _carving_under(area: CardArea, cell: Control) -> Array:
	var centre := area._grid.position + cell.position + MiniCard.SIZE / 2.0
	for laid: Array in area._quilt():
		if (laid[0] as Rect2).has_point(centre):
			return laid
	return []


func test_each_card_keeps_its_own_carving_as_it_glides() -> void:
	var area := _big()
	var cols := area.columns()
	for px in [0.0, 40.0, area.row_pitch() + 70.0, area.max_scroll_px()]:
		area.scroll_px_to(px)
		var cells := area.cell_nodes()
		for i in cells.size():
			var k := area.offset() + i
			var laid := _carving_under(area, cells[i])
			assert_false(laid.is_empty(), "card %d has a carving under it at %.0f" % [k, px])
			if laid.is_empty():
				continue
			assert_eq(int(laid[1]), ((k / cols) * cols + k % cols) % CardArea.PLAQUE_COLUMNS,
				"card %d wears the carving of its place in the LIST at %.0f" % [k, px])
			var frame := area._grid.position + cells[i].position - CardArea.GAP / 2.0
			assert_almost_eq((laid[0] as Rect2).position.x, frame.x, 0.001,
				"and sits half a gap inside it at %.0f" % px)
			assert_almost_eq((laid[0] as Rect2).position.y, frame.y, 0.001,
				"and sits half a gap inside it at %.0f" % px)


func test_the_quilt_still_covers_the_whole_area_while_cut() -> void:
	var area := _big()
	area.scroll_px_to(area.row_pitch() * 1.4)
	var top := INF
	var bottom := -INF
	for laid: Array in area._quilt():
		var rect: Rect2 = laid[0]
		top = minf(top, rect.position.y)
		bottom = maxf(bottom, rect.end.y)
	assert_lte(top, 0.0, "from the top edge")
	assert_gte(bottom, area.size.y, "to the bottom edge, no bare weave")


# ======================================================== 4. THE BAR ==

func test_the_side_bar_counts_pixels() -> void:
	var area := _big()
	area.scroll_px_to(123.0)
	var bar: ScrollBar = area._bar
	assert_true(bar.visible)
	assert_almost_eq(bar.max_value, area.content_height(), 0.001, "the whole list")
	assert_almost_eq(bar.page, area.size.y, 0.001, "the view")
	assert_almost_eq(bar.value, 123.0, 0.001, "where it stands")


func test_dragging_the_bar_moves_the_cards_by_the_pixel() -> void:
	var area := _big()
	area._bar.value = 137.0
	assert_almost_eq(area.scroll_px(), 137.0, 0.001, "not rounded to a row")
	assert_eq(area.offset(), area.columns(), "the second row is the first in view")


# ===================================================== 5. THE KEYBOARD ==

func test_down_into_a_cut_row_scrolls_just_enough_to_show_it_whole() -> void:
	var area := _big()
	var cols := area.columns()
	area.grab_focus()
	area.set_cursor(3 * cols + 2)
	assert_eq(area.scroll_px(), 0.0, "the fourth row is whole already")
	area.handle_key(_key(KEY_DOWN))
	assert_eq(area.cursor_index(), 4 * cols + 2, "a row down")
	assert_almost_eq(area.scroll_px(), 5.0 * area.row_pitch() - area.size.y, 0.001,
		"just far enough for the fifth row's carving to meet the bottom edge")
	var cell: CardArea.Cell = area.cell_nodes()[area.cursor_index() - area.offset()]
	assert_lte(cell.position.y + MiniCard.SIZE.y, area.size.y, "the card is whole")
	assert_true(_ring_on(area, cell), "and ringed where it now stands")


func test_up_into_a_cut_row_scrolls_it_down_whole() -> void:
	var area := _big()
	var cols := area.columns()
	var pitch := area.row_pitch()
	area.scroll_px_to(pitch * 2.0 + 40.0)
	area.grab_focus()
	area.set_cursor(3 * cols)
	assert_almost_eq(area.scroll_px(), pitch * 2.0 + 40.0, 0.001, "row four is in view")
	area.handle_key(_key(KEY_UP))
	assert_eq(area.cursor_index(), 2 * cols)
	assert_almost_eq(area.scroll_px(), pitch * 2.0, 0.001, "row three's carving on the top edge")


func test_an_arrow_with_no_cursor_lands_on_the_first_whole_row() -> void:
	var area := _big()
	var cols := area.columns()
	area.scroll_px_to(area.row_pitch() * 0.7)
	area.grab_focus()
	area.handle_key(_key(KEY_RIGHT))
	assert_eq(area.cursor_index(), cols, "not the sliver of row one at the top")
	assert_almost_eq(area.scroll_px(), area.row_pitch() * 0.7, 0.001, "and nothing moved")


func test_the_ring_rides_the_fraction_with_its_card() -> void:
	var area := _big()
	var cols := area.columns()
	area.scroll_px_to(44.8)
	area.grab_focus()
	area.set_cursor(cols + 1)
	var cell: CardArea.Cell = area.cell_nodes()[cols + 1]
	assert_true(_ring_on(area, cell), "on its card at a fractional offset")
	area.scroll_px_to(60.0)
	cell = area.cell_nodes()[area.cursor_index() - area.offset()]
	assert_true(_ring_on(area, cell), "and still on it after a slide")
	area.scroll_px_to(area.row_pitch() + 5.0)
	cell = area.cell_nodes()[area.cursor_index() - area.offset()]
	assert_true(_ring_on(area, cell), "and after a row has gone round")


func test_page_down_moves_whole_rows_and_carries_the_cursor() -> void:
	var area := _big()
	var cols := area.columns()
	area.scroll_px_to(30.0)
	area.grab_focus()
	area.set_cursor(cols + 1)
	area.handle_key(_key(KEY_PAGEDOWN))
	assert_almost_eq(area.scroll_px(), 30.0 + area.rows() * area.row_pitch(), 0.001,
		"a page of whole rows, the fraction kept")
	assert_eq(area.cursor_index(), cols + 1 + area.rows() * cols, "the cursor in its slot")


func test_home_and_end_reach_the_true_ends() -> void:
	var area := _big()
	area.grab_focus()
	area.set_cursor(0)
	area.handle_key(_key(KEY_END))
	assert_eq(area.cursor_index(), area.entry_count() - 1)
	assert_almost_eq(area.scroll_px(), area.max_scroll_px(), 0.001, "the last card whole")
	area.handle_key(_key(KEY_HOME))
	assert_eq(area.scroll_px(), 0.0)


# =============================================== 6. THE POINTER ==

func test_a_click_on_a_cut_card_leaves_the_view_where_it_is() -> void:
	var area := _big()
	var cols := area.columns()
	area.scroll_px_to(area.row_pitch() * 0.5)
	var cell: CardArea.Cell = area.cell_nodes()[4 * cols]
	assert_gt(cell.position.y + MiniCard.SIZE.y, area.size.y, "a card cut by the bottom edge")
	var name := cell.card_name
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	click.position = Vector2(20, 20)
	area._on_cell_input(click, cell)
	assert_almost_eq(area.scroll_px(), area.row_pitch() * 0.5, 0.001,
		"the card did not scroll itself under the pointer")
	assert_eq(screen.deck.count_of(name), 0, "and the click took it out, as it always has")


func test_the_card_under_a_still_pointer_is_lit_after_a_glide() -> void:
	var area := _big()
	var start: CardArea.Cell = area.cell_nodes()[1]
	var inside := Vector2(60, 60)
	var at := start.position + inside
	var motion := InputEventMouseMotion.new()
	motion.position = inside
	start.mouse_entered.emit()
	area._on_cell_input(motion, start)
	var seen: Array[String] = []
	area.card_hovered.connect(func(data: CardData) -> void: seen.append(data.card_name))
	area._on_cell_input(_wheel(true, 1.0, inside), start)
	area.settle_scroll()
	var under: CardArea.Cell = null
	for cell in area.cell_nodes():
		if Rect2(cell.position, MiniCard.SIZE).has_point(at):
			under = cell
	assert_not_null(under, "half a row on, a card is under the pointer")
	assert_ne(under.card_name, _name_at(area, 1), "and it is not the one it started on")
	assert_eq(seen.back() if not seen.is_empty() else "", under.card_name,
		"the Showcase shows the card now under the pointer")
	for cell in area.cell_nodes():
		assert_eq(cell.face.hovered, cell == under, "%s lit only if under it" % cell.card_name)


func test_a_pointer_that_has_left_lights_nothing() -> void:
	var area := _big()
	var start: CardArea.Cell = area.cell_nodes()[1]
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(60, 60)
	start.mouse_entered.emit()
	area._on_cell_input(motion, start)
	start.mouse_exited.emit()
	area.notification(Control.NOTIFICATION_MOUSE_EXIT)
	var seen: Array[String] = []
	area.card_hovered.connect(func(data: CardData) -> void: seen.append(data.card_name))
	area.scroll_px_to(area.row_pitch() * 0.5)
	assert_eq(seen, [] as Array[String], "the Showcase is not told of a card nobody points at")
	for cell in area.cell_nodes():
		assert_false(cell.face.hovered, "%s is not lit" % cell.card_name)


func test_a_resize_that_changes_the_columns_keeps_the_top_left_card() -> void:
	var area := _big()
	var pitch := area.row_pitch()
	var cols := area.columns()
	area.scroll_px_to(pitch * 3.0 + 20.0)
	var top_left := _name_at(area, 3 * cols)
	screen.size = Vector2(1700, 800)
	await get_tree().process_frame
	assert_ne(area.columns(), cols, "the wider window takes more columns")
	var row: Array[String] = []
	for i in area.columns():
		row.append(_name_at(area, area.offset() + i))
	assert_has(row, top_left, "the card at the top-left is still on the top row")
	assert_almost_eq(fposmod(area.scroll_px(), pitch), 20.0, 0.001, "at the same fraction")


# ================================================ 7. THE PURPLE ARROWS ==

func test_the_deck_area_wears_them_and_the_card_strips_do_not() -> void:
	assert_true(screen._deck_area.more_arrows)
	assert_not_null(screen._deck_area._up_arrow)
	assert_not_null(screen._deck_area._down_arrow)
	assert_false(screen._inventory.more_arrows, "the Inventory has its own pair")
	assert_false(screen._sideboard_area.more_arrows)


func test_a_deck_that_fits_shows_neither() -> void:
	var area := _deck_of(10)
	assert_false(area._up_arrow.visible)
	assert_false(area._down_arrow.visible)


func test_each_one_shows_while_there_are_cards_its_way() -> void:
	var area := _big()
	assert_false(area._up_arrow.visible, "at the top: nothing above")
	assert_true(area._down_arrow.visible, "the rest of the deck below")
	area.scroll_px_to(area.row_pitch() * 2.5)
	assert_true(area._up_arrow.visible, "in the middle: both")
	assert_true(area._down_arrow.visible)
	area.scroll_to_end()
	assert_true(area._up_arrow.visible, "at the end: only up")
	assert_false(area._down_arrow.visible)


func test_they_stand_at_the_two_ends_of_the_right_edge_with_the_bar_between() -> void:
	var area := _big()
	var up: Button = area._up_arrow
	var down: Button = area._down_arrow
	var bar: ScrollBar = area._bar
	assert_eq(up.position, Vector2(area.size.x - CardArea.MORE_W, 0.0), "top right")
	assert_eq(up.size, Vector2(CardArea.MORE_W, CardArea.MORE_H))
	assert_eq(down.position, Vector2(area.size.x - CardArea.MORE_W,
		area.size.y - CardArea.MORE_H), "bottom right")
	assert_eq(down.size, Vector2(CardArea.MORE_W, CardArea.MORE_H))
	assert_gte(bar.position.y, up.position.y + up.size.y, "the bar starts below the up arrow")
	assert_lte(bar.position.y + bar.size.y, down.position.y, "and ends above the down one")
	assert_almost_eq(bar.position.x + bar.size.x / 2.0, area.size.x - CardArea.MORE_W / 2.0,
		0.001, "down the middle of their column")


func test_no_card_is_drawn_under_them() -> void:
	var area := _big()
	for cell in area.cell_nodes():
		assert_lte(area._grid.position.x + cell.position.x + MiniCard.SIZE.x,
			area.size.x - CardArea.MORE_W, "%s clears the arrows' column" % cell.card_name)


func test_their_column_costs_the_deck_no_column_at_1280() -> void:
	assert_eq(screen._deck_area.columns(), 6, "six across, as before the arrows")
	assert_eq(screen._deck_area.rows(), 4, "four rows whole")


func test_they_are_purple() -> void:
	var area := _big()
	for button: Button in [area._up_arrow, area._down_arrow]:
		var box := button.get_theme_stylebox("normal")
		var face: Color
		if box is StyleBoxTexture:
			face = (box as StyleBoxTexture).modulate_color
			assert_eq(face, CardArea.MORE_TINT, "the 1997 stone, tinted")
		else:
			face = (box as StyleBoxFlat).bg_color
			assert_eq(face, CardArea.MORE_FLAT, "a flat face with no skin")
		assert_gt(face.b, face.r, "blue over red...")
		assert_gt(face.r, face.g, "...over green: purple")
		var hover := button.get_theme_stylebox("hover")
		var pressed := button.get_theme_stylebox("pressed")
		assert_ne(hover, box, "hover is its own state")
		assert_ne(pressed, box, "and so is a press")
		var glyph: CardArea.Arrow = button.get_child(0)
		assert_true(glyph.vertical, "an up/down arrow")
		assert_eq(button.focus_mode, Control.FOCUS_NONE, "it never takes the keys")
	assert_eq((area._up_arrow.get_child(0) as CardArea.Arrow).facing, -1, "up")
	assert_eq((area._down_arrow.get_child(0) as CardArea.Arrow).facing, 1, "down")


func test_a_click_glides_one_row_onto_a_row_boundary() -> void:
	var area := _big()
	var pitch := area.row_pitch()
	area.press_arrow(1)
	area.release_arrow()
	area.settle_scroll()
	assert_almost_eq(area.scroll_px(), pitch, 0.001, "one row down")
	area.scroll_px_to(pitch * 2.0 + 30.0)
	area.press_arrow(-1)
	area.release_arrow()
	area.settle_scroll()
	assert_almost_eq(area.scroll_px(), pitch * 2.0, 0.001,
		"up from a fraction: that row's carving on the top edge")
	area.press_arrow(1)
	area.release_arrow()
	area.settle_scroll()
	assert_almost_eq(area.scroll_px(), pitch * 3.0, 0.001, "and down to the next boundary")


func test_holding_one_keeps_scrolling_and_letting_go_stops_it() -> void:
	var area := _big()
	var pitch := area.row_pitch()
	area.press_arrow(1)
	area._process(CardArea.ARROW_DELAY * 0.5)
	assert_almost_eq(area._glide_to, pitch, 0.001, "one row, mid-delay")
	for _i in 4:
		area._process(CardArea.ARROW_DELAY)
	assert_gte(area._glide_to, pitch * 4.0, "and then it runs")
	area.release_arrow()
	area.settle_scroll()
	var settled := area.scroll_px()
	assert_almost_eq(fposmod(settled, pitch), 0.0, 0.001, "on a row boundary")
	assert_false(area.is_processing(), "the frame handler is off again")
	for _i in 5:
		area._process(CardArea.ARROW_DELAY)
	assert_eq(area.scroll_px(), settled, "and nothing moved after the release")


func test_a_held_arrow_stops_at_the_end_of_the_deck() -> void:
	var area := _big()
	area.scroll_px_to(area.max_scroll_px() - area.row_pitch() * 2.5)
	area.press_arrow(1)
	for _i in 30:
		area._process(CardArea.ARROW_DELAY)
	assert_almost_eq(area.scroll_px(), area.max_scroll_px(), 0.001, "the last card whole")
	assert_false(area._down_arrow.visible, "the arrow has gone with the cards below")
	assert_false(area.is_processing(), "and the repeat gave up the frame handler")
	area.release_arrow()


func test_the_wheel_over_an_arrow_still_scrolls() -> void:
	var area := _big()
	area._down_arrow.gui_input.emit(_wheel())
	area.settle_scroll()
	assert_almost_eq(area.scroll_px(), area.row_pitch() * CardArea.WHEEL_ROWS, 0.001,
		"the arrows stand on the bar's edge, and the bar scrolled under the wheel")


# ======================================== 8. THE INVENTORY STILL STEPS ==

func test_the_inventory_still_steps_whole_columns() -> void:
	var row := screen._inventory
	row._gui_input(_wheel())
	assert_eq(row.offset(), row.scroll_step(), "one whole column, at once")
	assert_false(row.is_processing(), "no glide")
	for cell in row.cell_nodes():
		assert_almost_eq(fposmod(cell.position.x - row._inset,
			MiniCard.SIZE.x + CardArea.GAP.x), 0.0, 0.001, "%s on its column" % cell.card_name)
