extends GutTest
## THE SPELL CHAIN FITS THE SCREEN (the bug campaign c12, h4-2).
##
## The chain was a plain VBox at a fixed (362, 150), and a VBox only grows:
## six objects (X spells and Bolts in turn) ended at 310, 442, 608, 740,
## 906 and 1038 on a screen 800 tall, the fifth showing its caption and the
## sixth nothing; and the Situation Bar at the seam sat over the second
## one's card. Now the column runs from y 150 to the screen's foot, slides
## its entries under one another once they do not fit (the top of the
## chain always whole), and keeps every entry off the Situation Bar.

var screen: DuelScreen
var _next_id := 93300

## What of an entry that slid under the next must still show — its
## caption's first line ([constant DuelScreen.ChainColumn.MIN_SHOWN]).
const MIN_SHOWN := 18.0
## The game's own screen, in logical pixels.
const SCREEN := Vector2(1280, 800)


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	# The runner's window is 1280x1280; the game's is 1280x800 (and stays
	# 800 logical rows tall at 1920x1080, `canvas_items` stretch).
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = SCREEN
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _push(card_name: String, controller := 0, x := 0) -> StackItem:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, _next_id, controller)
	_next_id += 1
	screen.game._instances[inst.id] = inst
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.controller = controller
	item.card = inst
	item.x_value = x
	item.description = "%s (test)" % card_name
	screen.game.stack.append(item)
	return item


## [param count] chain objects, X spells and Bolts in turn — the finding's
## own chain.
func _chain(count: int) -> Array[Control]:
	for i in count:
		if i % 2 == 0:
			_push("Fireball", 0, 3)
		else:
			_push("Lightning Bolt", 1)
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var entries: Array[Control] = []
	for child in screen._chain_box.get_children():
		entries.append(child as Control)
	return entries


func _screen_foot() -> float:
	return SCREEN.y


func test_six_objects_stay_on_the_screen() -> void:
	var entries := await _chain(6)
	assert_eq(entries.size(), 6, "control: one entry per chain object")
	var foot := _screen_foot()
	for i in entries.size():
		var rect := entries[i].get_global_rect()
		assert_gte(rect.position.y, 150.0 - 0.5, "entry %d starts below y 150" % i)
		assert_lte(rect.end.y, foot + 0.5,
			"entry %d ends on the screen (%.0f of %.0f)" % [i, rect.end.y, foot])


func test_the_top_of_the_chain_shows_whole_and_the_others_keep_their_captions() -> void:
	var entries := await _chain(6)
	for i in entries.size() - 1:
		var shown := entries[i + 1].position.y - entries[i].position.y
		if entries[i + 1].position.y > entries[i].position.y + entries[i].size.y:
			continue   # the next one stands apart (past the Situation Bar)
		assert_gte(shown, MIN_SHOWN - 0.5,
			"entry %d keeps its caption in sight under entry %d" % [i, i + 1])
	# The last child draws last, over all the others, and nothing comes
	# after it: whole by construction — and on the screen.
	var last := entries[-1].get_global_rect()
	assert_lte(last.end.y, _screen_foot() + 0.5, "the top of the chain is whole")


func test_no_entry_lies_under_the_situation_bar() -> void:
	var bar: Rect2 = screen._situation_bar.get_global_rect()
	assert_gt(bar.size.y, 0.0, "control: the bar is laid out")
	for count in [2, 3, 6]:
		screen.game.stack.clear()
		var entries := await _chain(count)
		for i in entries.size():
			assert_false(entries[i].get_global_rect().intersects(bar),
				"%d on the chain: entry %d is clear of the Situation Bar" % [count, i])


func test_a_short_chain_stands_as_it_did() -> void:
	var entries := await _chain(1)
	assert_eq(entries.size(), 1)
	assert_almost_eq(entries[0].get_global_rect().position.y, 150.0, 0.5,
		"one object: at the top of the column, as the VBox put it")
	assert_almost_eq(entries[0].size.x, float(MiniCard.SIZE.x), 0.5,
		"one card wide")


func test_the_empty_column_takes_no_click_from_the_board() -> void:
	await _chain(1)
	assert_eq(screen._chain_box.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the column runs the screen's height: its empty part is the board's")


## The arithmetic on its own: while they fit nothing slides; once they do
## not, the bottom comes up to the foot, and an entry that would cross
## the band starts below it.
func test_the_column_places_entries_round_the_band() -> void:
	var column: Variant = screen._chain_box
	if not column.has_method("place"):
		fail_test("the chain is no column that places its entries")
		return
	var heights: Array[float] = [160.0, 132.0, 160.0]
	var tops: Array[float] = []
	var band := Vector2(220.0, 270.0)
	var bottom: float = column.place(heights, band, 0.0, tops)
	assert_eq(tops[0], 0.0)
	assert_eq(tops[1], 270.0, "the second would cross the band: it starts below it")
	assert_eq(tops[2], 270.0 + 132.0 + 6.0, "the gap while they fit")
	assert_eq(bottom, tops[2] + 160.0)
