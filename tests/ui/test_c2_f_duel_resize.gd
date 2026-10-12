extends GutTest
## THE DUEL'S WINDOWS FOLLOW A RESIZED WINDOW (campaign 2026-10-12, finding
## r2-8). A desktop window dragged smaller, a Steam Deck docked or undocked,
## a Quest panel resized: the graveyard view kept its Done button where the
## old size had put it (below the new bottom edge), the duel log kept its
## title bar thousands of pixels off to the right, and the hand window hung
## off the bottom until something redrew it. Each now re-fits the moment
## the view changes size.

var view: SubViewport
var screen: DuelScreen


func before_each() -> void:
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	add_child_autofree(view)
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	view.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame


func _shrink(to: Vector2i) -> void:
	view.size = to
	for _i in 3:
		await get_tree().process_frame


func test_the_graveyard_views_done_stays_on_screen() -> void:
	var g: MtgGame = screen.game
	var dead := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[dead.id] = dead
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(dead)
	screen._open_graveyard(0)
	await get_tree().process_frame
	assert_true(screen.graveyard_is_open(), "control: the view is up")
	var done: Control = screen._grave_view._done
	assert_true(Rect2(Vector2.ZERO, Vector2(1280, 800)).encloses(done.get_global_rect()),
		"control: Done is on screen at 1280x800 (%s)" % done.get_global_rect())
	await _shrink(Vector2i(800, 600))
	assert_true(Rect2(Vector2.ZERO, Vector2(800, 600)).encloses(done.get_global_rect()),
		"Done is on screen after the window shrank (%s)" % done.get_global_rect())


func test_the_duel_log_stays_on_screen() -> void:
	screen._open_duel_log()
	var log_window: DuelLog = screen._duel_log
	assert_not_null(log_window, "control: the log is up")
	assert_gt(log_window.position.x, 700.0, "control: it opens at the right of a wide table")
	await _shrink(Vector2i(640, 480))
	assert_lt(log_window.position.x, 640.0 - 40.0,
		"its title bar is still reachable after the window shrank (x = %.0f)" % log_window.position.x)
	assert_lt(log_window.position.y, 480.0 - 20.0)


func test_the_hand_window_stays_on_screen() -> void:
	var hand: StackHand = null
	for row in screen._hand_rows:
		if row is StackHand and not (row as StackHand).pinned and (row as Control).visible:
			hand = row
			break
	assert_not_null(hand, "control: a floating hand window")
	if hand == null:
		return
	hand.position = Vector2(1280 - hand.size.x, 800 - StackHand.TITLE_HEIGHT - 4)
	await _shrink(Vector2i(800, 600))
	assert_lte(hand.position.x, 800.0 - hand.size.x + 0.5,
		"the hand window moved in from the right edge (x = %.0f)" % hand.position.x)
	assert_lte(hand.position.y, 600.0 - StackHand.TITLE_HEIGHT + 0.5,
		"its title bar is above the bottom edge (y = %.0f)" % hand.position.y)
