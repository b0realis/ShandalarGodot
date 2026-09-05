extends GutTest
## THE INVENTORY'S TWO SCROLL ARROWS, AND THE COUNT IN ITS CORNER — the
## owner's playtest, 2026-09-04:
##
##   *"Add arrows to the left and right of cards to help scroll, beside the
##    scrollbar at the bottom."*
##   *"Lower right number of cards — make much bigger, as it is not seen
##    now."*
##
## WHAT ROTS, and is therefore pinned here rather than trusted: an arrow
## that scrolls once per click instead of while it is held; an arrow that
## goes on being pressable at the end of the list and simply does nothing;
## an arrow column drawn OVER the cards it flanks; and a font size that
## goes back to being a number somebody liked instead of a fraction of the
## card it stands on.

var screen: DeckBuilderScreen


func before_each() -> void:
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame


func _row() -> CardArea:
	return screen._inventory


# ============================================== 1. THE TWO ARROWS EXIST ==

func test_the_card_row_is_flanked_by_an_arrow_at_each_end() -> void:
	var row := _row()
	assert_true(row.scroll_arrows, "the Inventory asks for them")
	assert_not_null(row._left_arrow)
	assert_not_null(row._right_arrow)
	# LEFT of the cards and RIGHT of them, in the area's own coordinates.
	assert_almost_eq(row._left_arrow.position.x, 0.0, 0.5, "hard left")
	assert_almost_eq(row._right_arrow.position.x + row._right_arrow.size.x,
		row.size.x, 0.5, "hard right")
	# ...and BESIDE THE SCROLL BAR: they run the full height of the area,
	# so the bar row at the bottom is between them too.
	for arrow in [row._left_arrow, row._right_arrow]:
		assert_almost_eq(arrow.size.y, row.size.y, 0.5,
			"full height, so it flanks the bar as well as the cards")
		assert_eq(arrow.size.x, CardArea.ARROW_W)


func test_the_bar_runs_between_them_and_never_under_them() -> void:
	var row := _row()
	var bar: ScrollBar = row._bar
	assert_gte(bar.position.x, row._left_arrow.size.x,
		"the bar starts inside the left arrow")
	assert_lte(bar.position.x + bar.size.x, row.size.x - CardArea.ARROW_W,
		"and stops before the right one")


func test_no_card_is_drawn_underneath_an_arrow() -> void:
	var row := _row()
	assert_almost_eq(row._grid.position.x, CardArea.ARROW_W, 0.5,
		"the cards start inside the left arrow")
	assert_almost_eq(row._inner_size().x, row.size.x - 2 * CardArea.ARROW_W,
		0.5, "and the row gave up a column at each end for them")
	for cell in row.cell_nodes():
		var left := row._grid.position.x + cell.position.x
		assert_gte(left, CardArea.ARROW_W - 0.5, "%s clears the left arrow"
			% cell.card_name)
		assert_lte(left + cell.size.x, row.size.x - CardArea.ARROW_W + 0.5,
			"%s clears the right one" % cell.card_name)


func test_the_triangle_cannot_swallow_its_own_buttons_click() -> void:
	# A bare Control defaults to MOUSE_FILTER_STOP, and one inside a button
	# eats the press that button exists for. Four defects in this project
	# came from that one default.
	for arrow in [_row()._left_arrow, _row()._right_arrow]:
		assert_gt(arrow.get_child_count(), 0, "the glyph is there")
		var glyph: Control = arrow.get_child(0)
		assert_eq(glyph.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"the triangle does not take the click")
	# ...and the arrows do not take the KEYBOARD either: the surface itself
	# answers the arrow keys and PageUp/PageDown.
	for arrow in [_row()._left_arrow, _row()._right_arrow]:
		assert_eq(arrow.focus_mode, Control.FOCUS_NONE)


# ================================================ 2. WHAT THEY ACTUALLY DO ==

func test_the_right_arrow_moves_the_row_on_by_one_step() -> void:
	var row := _row()
	assert_eq(row.offset(), 0)
	row._right_arrow.button_down.emit()
	row._right_arrow.button_up.emit()
	assert_eq(row.offset(), row.scroll_step(),
		"one press is exactly one step of cards")


func test_the_left_arrow_brings_it_back() -> void:
	var row := _row()
	row.scroll_by(4)
	var was := row.offset()
	row._left_arrow.button_down.emit()
	row._left_arrow.button_up.emit()
	assert_eq(row.offset(), was - row.scroll_step())


func test_holding_it_down_keeps_scrolling() -> void:
	# *"Held-down should keep scrolling, not one nudge per click."*
	var row := _row()
	row.press_arrow(1)
	var after_the_press := row.offset()
	assert_eq(after_the_press, row.scroll_step(),
		"the first step happens on the press itself")
	# Nothing more until the delay is up — a deliberate single click must
	# not turn into two.
	row._process(CardArea.ARROW_DELAY * 0.5)
	assert_eq(row.offset(), after_the_press, "still one step, mid-delay")
	for _i in 6:
		row._process(CardArea.ARROW_DELAY)
	assert_gt(row.offset(), after_the_press + 3 * row.scroll_step(),
		"and then it runs")
	row.release_arrow()


func test_letting_go_stops_it() -> void:
	var row := _row()
	row.press_arrow(1)
	for _i in 3:
		row._process(CardArea.ARROW_DELAY)
	row.release_arrow()
	var settled := row.offset()
	assert_false(row.is_processing(), "the frame handler is off again")
	for _i in 5:
		row._process(CardArea.ARROW_DELAY)
	assert_eq(row.offset(), settled, "and nothing moved after the release")


func test_a_held_arrow_never_runs_off_the_end_of_the_list() -> void:
	var row := _row()
	# Start five steps out, so the run is short and the END is what is
	# under test rather than the length of the pool.
	row.scroll_to(row.max_offset() - 5 * row.scroll_step())
	row.press_arrow(1)
	for _i in 30:
		row._process(CardArea.ARROW_DELAY)
	assert_eq(row.offset(), row.max_offset(), "it stopped at the last page")
	assert_false(row.is_processing(),
		"and gave up the frame handler rather than spinning on the end")
	row.release_arrow()


# ================================================== 3. THE DEAD ENDS SHOW ==

func test_the_left_arrow_is_dead_at_the_start_of_the_list() -> void:
	# *"Disable an arrow at its end of the list rather than letting it do
	# nothing silently."*
	var row := _row()
	assert_eq(row.offset(), 0)
	assert_true(row._left_arrow.disabled, "nowhere left to go")
	assert_false(row._right_arrow.disabled, "but 897 cards to the right")


func test_the_right_arrow_is_dead_at_the_end_of_it() -> void:
	var row := _row()
	row.scroll_to_end()
	assert_true(row._right_arrow.disabled)
	assert_false(row._left_arrow.disabled)


func test_both_are_dead_when_the_whole_list_fits_on_one_page() -> void:
	var row := _row()
	screen.filter.text = "black lotus"
	screen._refresh_inventory()
	assert_eq(row.entry_count(), 1, "one card, one page")
	assert_true(row._left_arrow.disabled)
	assert_true(row._right_arrow.disabled)


func test_a_dead_arrows_triangle_is_greyed_with_it() -> void:
	# Godot greys the STONE on its own (`disabled` stylebox); the triangle
	# is a child that draws itself and would otherwise stay full-strength
	# ink on a dead button, which reads as alive.
	var row := _row()
	var dead: Control = row._left_arrow.get_child(0)
	var live: Control = row._right_arrow.get_child(0)
	assert_true(row._left_arrow.disabled)
	assert_lt(dead.modulate.a, 0.5, "the dead one is faint")
	assert_almost_eq(live.modulate.a, 1.0, 0.01, "the live one is not")


func test_the_state_follows_the_wheel_and_the_keyboard_too() -> void:
	# The arrows describe the surface, so they must follow every way of
	# moving it — not only their own press.
	var row := _row()
	row.scroll_by(1)
	assert_false(row._left_arrow.disabled, "the wheel moved it")
	row.home()
	assert_true(row._left_arrow.disabled, "and Home brought it back")


# ============================== 4. THE COUNT IN THE BOTTOM-RIGHT CORNER ==

func test_the_count_is_sized_by_a_ratio_of_the_card_it_sits_on() -> void:
	# *"Lower right number of cards — make much bigger, as it is not seen
	# now."* — and sized the way the duel screen's own numbers are, by a
	# fraction of the thing under them, never by feel.
	assert_eq(CardArea.tally_font_size(),
		int(MiniCard.SIZE.y * CardArea.TALLY_FONT_RATIO),
		"a fraction of the one card size this game has")
	assert_gte(CardArea.tally_font_size(), 24,
		"which is much bigger than the 14 it shipped at")


func test_the_label_really_wears_that_size() -> void:
	var label: Label = _row()._tally_label
	assert_eq(label.get_theme_font_size("font_size"),
		CardArea.tally_font_size(), "the constant is not decoration")
	# ...and it is the biggest lettering on the bar row, which is the point.
	var title: Label = screen._sideboard_area._title_label
	assert_gt(label.get_theme_font_size("font_size"),
		title.get_theme_font_size("font_size"),
		"bigger than the heading it shares a row with")


func test_it_keeps_its_outline_over_the_busy_art() -> void:
	# The corner is the busiest ground the screen has — Dekbar1's dithered
	# teal, the scroll bar's stone, and the bottom edge of whatever card
	# art the last column holds. A number over that needs a FLOOR.
	var label: Label = _row()._tally_label
	assert_gte(label.get_theme_constant("outline_size"), 4,
		"the floor grew with the letters")
	assert_eq(label.get_theme_color("font_outline_color"), OriginalDialog.INK,
		"…and it is still the hard dark outline, not a new hue")


func test_the_biggest_number_still_fits_the_room_it_is_given() -> void:
	# A font that outgrows [constant CardArea.TALLY_W] would either run
	# over the scroll bar or be clipped by the area's own `clip_contents`.
	var label: Label = _row()._tally_label
	var font := label.get_theme_font("font")
	var text := "%d cards" % CardRegistry.size()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		CardArea.tally_font_size()).x
	assert_lte(width, CardArea.TALLY_W - 6.0,
		"'%s' fits the corner at %dpx" % [text, CardArea.tally_font_size()])


func test_it_still_counts_the_whole_filtered_list() -> void:
	# The size changed; what it counts did not.
	assert_eq(_row()._tally_label.text,
		"%d cards" % _row().entry_count())
	screen.filter.text = "el"
	screen._refresh_inventory()
	assert_eq(_row()._tally_label.text,
		"%d cards" % _row().entry_count(), "and it followed the filter")
