extends GutTest
## THE SCREEN HAS THE LAST WORD — OriginalDialog.keep_on_screen
## (game/duel/original_dialog.gd). The 2026-09-28 Steam Deck playtest:
## *"Some windows overflow the screen like AutoDeck window in the deck
## builder is too large."* A window is made for the 1280x800 the game
## lays out on, and the Deck's screen lands on exactly 800 logical rows:
## a window 800 tall fills it edge to edge and one that grew for its
## lines (fit_height) hangs off it. Since then every window keeps
## SCREEN_MARGIN from the screen's edges — cut to fit, recentred — and a
## window cut short puts its body behind a scroll so the foot buttons
## stay on the stone and the wheel reaches every line.
##
## The test runner's own viewport is 1280x1280, so these windows open in
## a SubViewport of the Deck's 1280x800.

const SCREEN := Vector2i(1280, 800)
const ROOM := 800 - 2 * OriginalDialog.SCREEN_MARGIN

var _view: SubViewport


func before_each() -> void:
	_view = SubViewport.new()
	_view.size = SCREEN
	add_child_autofree(_view)


func _open(size: Vector2, lines := 0) -> OriginalDialog:
	var dialog := OriginalDialog.create("A window", size)
	for i in lines:
		var line := OriginalDialog.label("Line %d" % (i + 1))
		line.name = "Line%d" % (i + 1)
		dialog.body().add_child(line)
	dialog.add_button("OK")
	_view.add_child(dialog)
	return dialog


func _scroll_of(dialog: OriginalDialog) -> ScrollContainer:
	return dialog.find_child("BodyScroll", true, false) as ScrollContainer


func test_a_window_that_fits_is_left_as_it_was_made() -> void:
	var dialog := _open(Vector2(680, 720), 3)
	assert_eq(dialog.size, Vector2(680, 720))
	assert_null(_scroll_of(dialog), "no scroll for a window that fits")
	assert_eq(dialog.body().get_parent().get_parent(), dialog,
		"the body sits in the column, as before")


func test_a_tall_window_is_cut_to_the_screen_and_its_body_scrolls() -> void:
	var dialog := _open(Vector2(680, 900), 40)
	assert_eq(dialog.size, Vector2(680, ROOM), "cut by SCREEN_MARGIN on both sides")
	assert_almost_eq(dialog.position.y, float(OriginalDialog.SCREEN_MARGIN), 0.5, "recentred")
	var scroll := _scroll_of(dialog)
	assert_not_null(scroll, "the body went behind a scroll")
	if scroll == null:
		return
	assert_eq(dialog.body().get_parent(), scroll)
	assert_true(scroll.follow_focus, "a hop to a line brings it into view")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	await get_tree().process_frame
	await get_tree().process_frame
	# The foot stays on the stone: the OK button's bottom is inside the window.
	var ok := dialog.find_child("OK", true, false) as Control
	if ok == null:
		for child in dialog.find_children("*", "Button", true, false):
			if (child as Button).text == "OK":
				ok = child
	assert_not_null(ok)
	if ok != null:
		var foot := ok.get_global_rect()
		assert_lte(foot.end.y, dialog.get_global_rect().end.y, "the button is on the stone")
	# The last line is off the stone until the wheel brings it up.
	var last := dialog.find_child("Line40", true, false) as Control
	assert_not_null(last)
	if last == null:
		return
	assert_gt(last.get_global_rect().position.y, dialog.get_global_rect().end.y,
		"line 40 waits below the window's edge")
	scroll.scroll_vertical = 100000
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lt(last.get_global_rect().end.y, dialog.get_global_rect().end.y,
		"scrolled, line 40 is on the stone")


func test_a_wide_window_is_cut_too() -> void:
	var dialog := _open(Vector2(1400, 400), 2)
	assert_eq(dialog.size, Vector2(1280 - 2 * OriginalDialog.SCREEN_MARGIN, 400))
	assert_almost_eq(dialog.position.x, float(OriginalDialog.SCREEN_MARGIN), 0.5, "recentred")
	assert_null(_scroll_of(dialog), "a cut in width alone needs no scroll")


func test_fit_height_grows_a_window_only_as_far_as_the_screen() -> void:
	var dialog := _open(Vector2(600, 300), 40)
	assert_eq(dialog.size, Vector2(600, 300), "made small, fits the screen as made")
	await get_tree().process_frame
	dialog.fit_height()
	assert_eq(dialog.size, Vector2(600, ROOM), "grew for its forty lines, to the screen")
	assert_not_null(_scroll_of(dialog), "and the lines past the screen scroll")
	assert_almost_eq(dialog.position.y, float(OriginalDialog.SCREEN_MARGIN), 0.5, "recentred")
	# Asked again the window neither grows nor shrinks.
	dialog.fit_height()
	assert_eq(dialog.size, Vector2(600, ROOM))


func test_a_window_on_the_runners_own_viewport_is_not_touched() -> void:
	# The runner's 1280x1280 viewport has room for 900 rows.
	var dialog := OriginalDialog.create("A window", Vector2(680, 900))
	dialog.add_button("OK")
	add_child_autofree(dialog)
	assert_eq(dialog.size, Vector2(680, 900))
	assert_null(_scroll_of(dialog))
