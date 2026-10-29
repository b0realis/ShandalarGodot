extends GutTest
## THE POISON COUNTER, DRAWN AS OUR OWN (the polish pass, 2026-10-28).
##
## The ledger: *"Poison art: Manalink's `Poison.pic` vs the 1997-files-only
## rule."* The 1997 sprite is the player's own copy (with a dead mask in
## every conversion we hold) and Manalink's rescale is a third party's, so
## the counter is our own drawing in `game/art/` ([PoisonCounters]'s class
## doc), laid out on the life register as the 1997 life window laid out its
## own: one per counter on a grid a quarter wide and a third tall, the
## number drawn over them.


func test_the_picture_is_ours_and_ships() -> void:
	var sprite := GameSkin.our_art(PoisonCounters.ART)
	assert_not_null(sprite, "game/art/poison_counter.png loads through GameSkin.our_art")
	if sprite == null:
		return
	assert_eq(sprite.get_size(), Vector2(42, 52), "twice the 1997 counter's 21x26 cell")
	var image := sprite.get_image()
	assert_eq(image.get_pixel(0, 0).a, 0.0, "a sprite, not a tile: the corners are clear")
	assert_gt(image.get_pixel(21, 32).a, 0.9, "the body is solid")
	var readme := FileAccess.get_file_as_string("res://game/art/README.md")
	assert_string_contains(readme, "`poison_counter.png`", "a README row with its hash")
	var generator := FileAccess.get_file_as_string("res://tools/draw_our_art.gd")
	assert_string_contains(generator, "\"poison_counter.png\"", "drawn by the generator")


func test_the_1997_grid_a_quarter_wide_and_a_third_tall() -> void:
	var cells := PoisonCounters.cells(Vector2(96, 76), 10)
	assert_eq(cells.size(), 10)
	if cells.size() < 10:
		return
	assert_eq(cells[0], Rect2(0, 0, 24, 25))
	assert_eq(cells[3], Rect2(72, 0, 24, 25), "four to a row")
	assert_eq(cells[4], Rect2(0, 25, 24, 25), "then the next row")
	assert_eq(cells[9], Rect2(24, 50, 24, 25), "ten counters: two rows and a half")


func test_the_cells_are_whole_pixels_and_wrap_on_the_right_edge() -> void:
	# `client.right / 4` is an integer division, and the wrap is "the next
	# cell would pass the right edge" — on a register one pixel short of a
	# fourth whole cell the row still holds four.
	var cells := PoisonCounters.cells(Vector2(99, 61), 5)
	assert_eq(cells[0].size, Vector2(24, 20))
	assert_eq(cells[3].position, Vector2(72, 0))
	assert_eq(cells[4].position, Vector2(0, 20))


func test_the_spider_keeps_its_shape_in_a_wide_cell() -> void:
	# A register twice as wide as tall makes wide cells; the sprite is
	# fitted, centred, never flattened.
	var shown := PoisonCounters.fit(Rect2(0, 0, 47, 26), Vector2(42, 52))
	assert_eq(shown.size.y, 26.0, "as tall as the cell")
	assert_almost_eq(shown.size.x / shown.size.y, 42.0 / 52.0, 0.05, "its own shape")
	assert_eq(shown.position, Vector2(floorf((47.0 - shown.size.x) * 0.5), 0), "centred")


func test_no_counters_no_cells() -> void:
	assert_true(PoisonCounters.cells(Vector2(96, 76), 0).is_empty())
	assert_true(PoisonCounters.cells(Vector2.ZERO, 3).is_empty(), "no room, nothing drawn")


func test_the_count_is_never_negative_and_lets_every_click_through() -> void:
	var counters := PoisonCounters.new()
	add_child_autofree(counters)
	counters.count = -3
	assert_eq(counters.count, 0)
	counters.count = 4
	assert_eq(counters.count, 4)
	assert_eq(counters.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the register's own clicks and menus still reach the button")


func test_the_number_is_drawn_in_the_buttons_own_colour() -> void:
	var button := Button.new()
	button.add_theme_color_override("font_color", Color(0.95, 0.85, 0.20))
	add_child_autofree(button)
	assert_eq(PoisonCounters._number_color(button), Color(0.95, 0.85, 0.20))
	button.disabled = true
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	assert_eq(PoisonCounters._number_color(button), Color(0.5, 0.5, 0.5))
