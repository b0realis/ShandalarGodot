extends GutTest
## A LONG HELP PAGE IS BUILT OVER A FEW FRAMES (campaign 2026-11-26,
## smoothness 6): the press that turns to it builds the top, the rest
## follows a slice a frame, and the page ends up exactly the page a
## whole build makes.

var screen: Control


func before_each() -> void:
	screen = load("res://game/help/help_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _longest_page() -> int:
	var pages: Array = HelpPages.pages()
	var best := 0
	var most := 0
	for i in pages.size():
		var letters := 0
		for block: Dictionary in pages[i].get("blocks", []):
			letters += String(block.get("text", "")).length()
		if letters > most:
			most = letters
			best = i
	return best


func _reading(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var line: Array = [child.get_class()]
		if child is Label or child is Button:
			line.append(child.get("text"))
		if child is TextureRect:
			line.append((child as TextureRect).texture)
		out.append(line)
		_reading(child, out)


func _page_reading() -> Array:
	var out: Array = []
	_reading(screen._body, out)
	return out


func test_without_slices_a_page_is_whole_at_once() -> void:
	assert_false(screen.slices, "control: the suite has no display, and builds whole pages")
	screen.go_to(_longest_page())
	assert_true(screen.page_built())
	assert_false(screen.is_processing(), "nothing is left for a later frame")


func test_a_long_page_comes_in_slices_and_ends_the_same() -> void:
	var page := _longest_page()
	screen.go_to(page)
	var whole := _page_reading()
	screen.go_to(0)
	screen.slices = true
	var started := Time.get_ticks_usec()
	screen.go_to(page)
	var first_ms := float(Time.get_ticks_usec() - started) / 1000.0
	assert_gt(screen._body.get_child_count(), 0, "the top of the page is there in the press")
	assert_false(screen.page_built(), "the rest is still to come")
	assert_true(screen.is_processing())
	assert_lt(_page_reading().size(), whole.size())
	# A slice stops at the first part past its time: twice the slice and the
	# longest paragraph is a generous bound on any machine that runs the suite.
	assert_lt(first_ms, 60.0, "the press itself stayed short (%.1f ms)" % first_ms)
	var frames := 0
	while not screen.page_built() and frames < 200:
		await get_tree().process_frame
		frames += 1
	assert_true(screen.page_built(), "the page is finished a few frames on")
	assert_gt(frames, 0)
	await get_tree().process_frame
	assert_false(screen.is_processing(), "and the screen rests again")
	assert_eq(_page_reading(), whole, "the same page, part for part")


func test_turning_away_drops_what_was_still_to_come() -> void:
	screen.slices = true
	var page := _longest_page()
	screen.go_to(page)
	assert_false(screen.page_built())
	screen.go_to(1)
	screen.slices = false
	screen.go_to(1)
	var whole := _page_reading()
	screen.slices = true
	screen.go_to(page)
	screen.go_to(1)
	while not screen.page_built():
		await get_tree().process_frame
	assert_eq(_page_reading(), whole, "nothing of the page left behind is on this one")


func test_the_contents_first_topic_is_built_in_the_press() -> void:
	screen.slices = true
	screen.go_to(1)
	screen.go_to(0)
	assert_not_null(screen._body.find_child("HelpTopic*", true, false), "the ring has its topic to start on")
	while not screen.page_built():
		await get_tree().process_frame


func test_icon_rows_and_card_examples_are_parts_of_their_own() -> void:
	var pages: Array = HelpPages.pages()
	for i in pages.size():
		var rows := 0
		var blocks := 0
		for block: Dictionary in pages[i].get("blocks", []):
			match String(block.get("kind", "")):
				HelpPages.ICONS: rows += maxi(1, (block.get("entries", []) as Array).size())
				HelpPages.CARDS: rows += maxi(1, (block.get("examples", []) as Array).size())
				_: blocks += 1
		assert_eq(screen._units_of(pages[i]).size(), rows + blocks, "page %d" % i)
