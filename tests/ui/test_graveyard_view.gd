extends GutTest
## §1.2 of docs/duel-todo.md — CARDS IN A GRAVEYARD CAN BE TARGETED.
##
## The engine has had `CREATURE_IN_YOUR_GRAVEYARD`,
## `CARD_IN_YOUR_GRAVEYARD`, `CREATURE_IN_ANY_GRAVEYARD` and
## `CARD_IN_ANY_GRAVEYARD` (engine/core/target.gd) and five cards that use
## them for a long time. They were uncastable, because the duel screen drew
## a graveyard as a `TextureRect` with a tooltip: casting Raise Dead put
## the screen into TARGETING with nothing clickable and Cancel as the only
## move. This pins the whole path — the pile opens, a legal card is
## outlined, clicking it submits the cast, and the spell resolves.


var screen: DuelScreen
## The screen sits on its own layer ABOVE THE RUNNER'S PANEL: GUT's GutLayer
## is CanvasLayer 128 and its output box covers the top of the window, so
## a real click there (see the real clicks below) reached the runner's
## text box, never the card. test_pad_controls.gd stages the same way.
var _stage: CanvasLayer


func before_each() -> void:
	_stage = CanvasLayer.new()
	_stage.layer = 200
	add_child_autofree(_stage)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	_stage.add_child(screen)
	await get_tree().process_frame


func _bury(pid: int, card_name: String) -> CardInstance:
	var game: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, game._next_instance_id, pid)
	game._next_instance_id += 1
	game._instances[inst.id] = inst
	inst.zone = Mtg.Zone.GRAVEYARD
	game.players[pid].graveyard.append(inst)
	return inst


func _hand(pid: int, card_name: String) -> CardInstance:
	var game: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	var inst := CardInstance.new(data, game._next_instance_id, pid)
	game._next_instance_id += 1
	game._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	game.players[pid].hand.append(inst)
	return inst


func test_an_empty_pile_does_not_open() -> void:
	screen.game.players[0].graveyard.clear()
	screen._on_grave_pile_clicked(0)
	assert_false(screen.graveyard_is_open())


func test_a_pile_opens_and_the_same_pile_closes_it() -> void:
	_bury(0, "Grizzly Bears")
	screen._on_grave_pile_clicked(0)
	assert_true(screen.graveyard_is_open(), "clicking a full pile opens it")
	screen._on_grave_pile_clicked(0)
	assert_false(screen.graveyard_is_open(), "the same pile again closes it")


func test_escape_peels_the_view_before_the_pending_cast() -> void:
	_bury(0, "Grizzly Bears")
	screen._on_grave_pile_clicked(0)
	screen._unhandled_key_input(_escape())
	assert_false(screen.graveyard_is_open())


func _escape() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event


func test_the_sections_use_the_originals_own_words() -> void:
	var game: MtgGame = screen.game
	assert_eq(GraveyardView.section_title(game, 0, 0, Mtg.Zone.GRAVEYARD, 3),
		"Your graveyard (3)")
	assert_eq(GraveyardView.section_title(game, 1, 0, Mtg.Zone.GRAVEYARD, 2),
		"%s graveyard (2)" % game.players[1].player_name)
	# `@MENU_GRAVEYARD`'s other two views.
	assert_eq(GraveyardView.section_title(game, 0, 0, Mtg.Zone.EXILE, 1),
		"Your exiled cards (1)")
	assert_eq(GraveyardView.section_title(game, 0, 0, Mtg.Zone.ANTE, 1),
		"Your ante (1)")


func test_raise_dead_is_castable_through_the_ui() -> void:
	var game: MtgGame = screen.game
	# Set the stage: our own turn, a creature in our graveyard, the mana.
	var bear := _bury(0, "Grizzly Bears")
	var raise := _hand(0, "Raise Dead")
	# Sorcery timing: our own main phase, empty chain, the mana floating.
	game.active_player = 0
	game.priority_player = 0
	game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	game.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	screen._click_hand_card(raise)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING,
		"the cast is waiting for a target")
	assert_true(screen._pile_holds_a_target(0),
		"and the pile is ringed, because the answer is inside it")
	screen._on_grave_pile_clicked(0)
	assert_true(screen.graveyard_is_open())
	screen._on_graveyard_card(bear)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "the cast went through")
	assert_false(screen.graveyard_is_open(), "and the view got out of the way")
	assert_eq(game.stack.size(), 1,
		"Raise Dead is on the chain: %s" % screen._prompt_label.text)
	while not game.stack.is_empty():
		game.pass_priority(game.priority_player)
	assert_eq(bear.zone, Mtg.Zone.HAND, "and the bear came back")


func test_an_illegal_pile_card_is_refused_not_ignored() -> void:
	var game: MtgGame = screen.game
	var mountain := _bury(0, "Mountain")     # not a creature card
	var raise := _hand(0, "Raise Dead")
	# Sorcery timing: our own main phase, empty chain, the mana floating.
	game.active_player = 0
	game.priority_player = 0
	game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	game.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	screen._click_hand_card(raise)
	screen._on_grave_pile_clicked(0)
	screen._on_graveyard_card(mountain)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "still waiting")
	assert_string_contains(screen._prompt_label.text, "Illegal target")


# ------------------------------------------- [QoL] the shelf of five --
#
# The owner's divergence (docs/duel-todo.md §1.2, docs/duel-screen-design.md
# thirty-third pass): the pile is OUR mini cards at THEIR OWN SIZE, five in
# a row, arrows either side, and the position of the CENTRE card of the
# five printed on it. A card in a graveyard is the same object as the same
# card on the battlefield — never a squashed one.

const LONG_PILE := ["Grizzly Bears", "Hill Giant", "Lightning Bolt",
	"Mountain", "Forest"]


func _bury_many(pid: int, count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append(_bury(pid, LONG_PILE[i % LONG_PILE.size()]))
	return out


func _open_pile(count: int) -> GraveyardView:
	screen.game.players[0].graveyard.clear()
	_bury_many(0, count)
	screen._on_grave_pile_clicked(0)
	return screen._grave_view


func test_the_shelf_costs_exactly_what_full_size_cards_cost() -> void:
	# n * 132 + the gaps + both arrow buttons. The card never shrinks, so
	# this sum is what decides the COUNT.
	assert_almost_eq(GraveyardView.shelf_width(5), 784.0, 0.01)
	assert_almost_eq(GraveyardView.shelf_width(3), 504.0, 0.01)
	assert_eq(GraveyardView.cards_across(890.0), 5,
		"the board region of the 1280 canvas holds five")
	assert_eq(GraveyardView.cards_across(700.0), 3,
		"too narrow for five — show THREE, never a smaller card")


func test_a_long_pile_shows_one_page_of_true_size_mini_cards() -> void:
	var view := _open_pile(30)
	assert_eq(view.page_size(), 5, "five across on our canvas")
	assert_eq(view.shown(Mtg.Zone.GRAVEYARD, 0).size(), 5)
	var cards := view.widgets(Mtg.Zone.GRAVEYARD, 0)
	assert_eq(cards.size(), 5)
	await get_tree().process_frame
	for card in cards:
		assert_eq(card.scale, Vector2.ONE, "a graveyard card is NEVER scaled")
		assert_eq(card.custom_minimum_size, MiniCard.SIZE)
		assert_eq(card.size, MiniCard.SIZE,
			"%s renders at the battlefield's own card size" %
			card.instance.data.card_name)


func test_the_centre_card_of_the_five_carries_its_position() -> void:
	var view := _open_pile(30)
	assert_eq(view.counter_text(Mtg.Zone.GRAVEYARD, 0), "3 / 30",
		"the third card of thirty is the middle of the first five")


func test_the_arrows_page_a_whole_shelf_at_a_time() -> void:
	var view := _open_pile(30)
	var pile: Array = screen.game.players[0].graveyard
	assert_false(view.can_page(Mtg.Zone.GRAVEYARD, 0, -1), "nothing behind us")
	assert_true(view.can_page(Mtg.Zone.GRAVEYARD, 0, 1))
	view.step(Mtg.Zone.GRAVEYARD, 0, 1)
	assert_eq(view.page_start(Mtg.Zone.GRAVEYARD, 0), 5)
	assert_eq(view.counter_text(Mtg.Zone.GRAVEYARD, 0), "8 / 30")
	assert_eq(view.shown(Mtg.Zone.GRAVEYARD, 0)[0], pile[5])
	view.step(Mtg.Zone.GRAVEYARD, 0, -1)
	assert_eq(view.page_start(Mtg.Zone.GRAVEYARD, 0), 0, "and back again")


func test_paging_clamps_at_both_ends() -> void:
	var view := _open_pile(30)
	view.step(Mtg.Zone.GRAVEYARD, 0, -1)
	assert_eq(view.page_start(Mtg.Zone.GRAVEYARD, 0), 0, "cannot page off the front")
	for _i in 10:
		view.step(Mtg.Zone.GRAVEYARD, 0, 1)
	assert_eq(view.page_start(Mtg.Zone.GRAVEYARD, 0), 25,
		"the last page is a FULL five, not a half-empty shelf")
	assert_eq(view.counter_text(Mtg.Zone.GRAVEYARD, 0), "28 / 30")
	assert_false(view.can_page(Mtg.Zone.GRAVEYARD, 0, 1))
	assert_eq(view.shown(Mtg.Zone.GRAVEYARD, 0).size(), 5)


func test_a_short_pile_has_nowhere_to_page() -> void:
	var view := _open_pile(3)
	assert_eq(view.shown(Mtg.Zone.GRAVEYARD, 0).size(), 3)
	assert_eq(view.counter_text(Mtg.Zone.GRAVEYARD, 0), "2 / 3")
	assert_false(view.can_page(Mtg.Zone.GRAVEYARD, 0, -1))
	assert_false(view.can_page(Mtg.Zone.GRAVEYARD, 0, 1))


func test_the_view_opens_on_the_page_holding_the_first_legal_target() -> void:
	var game: MtgGame = screen.game
	game.players[0].graveyard.clear()
	for _i in 12:
		_bury(0, "Mountain")
	var bear := _bury(0, "Grizzly Bears")     # index 12, deep in the pile
	for _i in 10:
		_bury(0, "Mountain")
	var raise := _hand(0, "Raise Dead")
	game.active_player = 0
	game.priority_player = 0
	game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	game.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	screen._click_hand_card(raise)
	screen._on_grave_pile_clicked(0)
	var view := screen._grave_view
	assert_eq(view.page_start(Mtg.Zone.GRAVEYARD, 0), 10,
		"the only legal card lands in the CENTRE slot")
	assert_eq(view.counter_text(Mtg.Zone.GRAVEYARD, 0), "13 / 23")
	assert_true(view.shown(Mtg.Zone.GRAVEYARD, 0).has(bear),
		"the player never has to hunt for the answer")
	var centre: MiniCard = view.widgets(Mtg.Zone.GRAVEYARD, 0)[2]
	assert_eq(centre.instance, bear)
	# s30 outlines a legal target and leaves an illegal one plain; ours
	# reuses the board's own TARGET tint so the two reads match.
	assert_eq(centre._highlight, MiniCard.Highlight.TARGET,
		"the one card Raise Dead can take is ringed")
	assert_eq(view.widgets(Mtg.Zone.GRAVEYARD, 0)[1]._highlight,
		MiniCard.Highlight.NONE, "and a Mountain beside it is not")


func test_the_pile_fills_the_duels_own_big_preview() -> void:
	_open_pile(6)
	assert_eq(screen._grave_view.preview, screen._card_preview,
		"hovering a corpse fills the SAME docked card the hand does")


func test_a_reopened_pile_starts_at_the_front() -> void:
	var view := _open_pile(30)
	view.step(Mtg.Zone.GRAVEYARD, 0, 1)
	assert_eq(view.page_start(Mtg.Zone.GRAVEYARD, 0), 5)
	screen._on_grave_pile_clicked(0)          # closes
	screen._on_grave_pile_clicked(0)          # and opens afresh
	assert_eq(view.page_start(Mtg.Zone.GRAVEYARD, 0), 0)


# ================================ the second Steam Deck playtest, 2026-09-28 ==

## *"7. Ok when i click on the graveyard it just flashes and i cannot see
## it!"* / *"10. I ment graveyard and exile stacks both!"* — Steam Input
## can hand a game two copies of one press (the first playtest's layout
## sent Escape beside pad B): one copy opened the pile, the other landed
## on the dim and closed it. A press on the dim within SETTLE_MS of the
## view opening closes nothing; after it, the click-anywhere rule holds.
## Wall-clock ms, which is what the view reads — the runner's own timers
## run on a scaled clock.
func _wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 <= ms:
		await get_tree().process_frame


func _dim_click(pressed: bool, double := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double
	screen._grave_view._gui_input(event)


func test_a_press_on_the_dim_right_after_opening_closes_nothing() -> void:
	_open_pile(3)
	assert_true(screen.graveyard_is_open())
	_dim_click(true)
	_dim_click(false)
	assert_true(screen.graveyard_is_open(), "the copy of the opening press: still open")
	await _wait_ms(GraveyardView.SETTLE_MS + 20)
	_dim_click(true)
	assert_true(screen.graveyard_is_open(), "a press alone decides nothing")
	_dim_click(false)
	assert_false(screen.graveyard_is_open(), "its release, after the settle, closes it")
	# And the exile plate opens the same view, settled the same way.
	screen._on_grave_pile_clicked(0)
	assert_true(screen.graveyard_is_open())
	_dim_click(true)
	_dim_click(false)
	assert_true(screen.graveyard_is_open(), "reopened: settled again")


## THE THIRD PLAYTEST (2026-09-28). The plate is double-clicked — the
## desktop's habit, a trackpad tap beside a click — and the second press,
## flagged `double_click`, lands on the dim past the settle: it is the
## opening click arriving again and closes nothing. A release with no
## armed press behind it closes nothing either.
func test_a_double_clicks_second_press_and_a_lone_release_close_nothing() -> void:
	_open_pile(3)
	await _wait_ms(GraveyardView.SETTLE_MS + 20)
	_dim_click(true, true)
	_dim_click(false)
	assert_true(screen.graveyard_is_open(), "the second half of a double click")
	_dim_click(false)
	assert_true(screen.graveyard_is_open(), "a release nobody pressed for")
	_dim_click(true)
	_dim_click(false)
	assert_false(screen.graveyard_is_open(), "a whole click after the settle: closed")


## `@BUTTONLABELS` is "Cancel / Done": the view carries a Done of its own,
## fixed bottom-centre under the shelves and outside the scroll, so the
## pad and the touchscreen have a way out that is not empty dim.
func test_the_done_button_closes_the_view() -> void:
	var view := _open_pile(12)
	var done := view.done_button()
	assert_not_null(done)
	assert_true(done.is_visible_in_tree())
	assert_eq(done.text, "Done")
	assert_eq(done.focus_mode, Control.FOCUS_NONE, "the pad hops to it; nothing tabs to it")
	var scroll: ScrollContainer = view._scroll
	assert_gte(done.global_position.y, scroll.global_position.y + scroll.size.y,
		"under the shelves, never over them")
	var content: Rect2 = view._content_rect()
	assert_almost_eq(done.global_position.x + done.size.x / 2.0,
		content.position.x + content.size.x / 2.0, 1.0, "centred on the board")
	assert_almost_eq(done.global_position.y + done.size.y, content.end.y, 1.0,
		"on the board's bottom edge")
	done.pressed.emit()
	await get_tree().process_frame
	assert_false(screen.graveyard_is_open(), "Done closes it")


## *"Really check this graveyard window so it is visible and stays on top,
## but below main message window."* Drawn over every window of the duel
## and under the Situation Bar; and since a click goes to the LAST sibling
## under the pointer whatever its z, the tree agrees with the z: the view
## after everything, the bar after the view.
func test_the_view_sits_over_the_windows_and_under_the_bar() -> void:
	# The log window is made on demand, after the bar: the case the tree
	# order is settled for.
	screen._open_duel_log()
	var view := _open_pile(3)
	assert_eq(view.z_index, GraveyardView.Z)
	assert_lt(view.z_index, screen._situation_bar.z_index, "under the Situation Bar")
	assert_lt(view.z_index, 200, "under the dialogs")
	for window in [screen._combat_window, screen._hand_rows[1], screen._flight,
			screen._chain_box, screen._duel_log]:
		if window == null:
			continue
		assert_gt(view.z_index, window.z_index, "over %s" % window.name)
		assert_lt(window.get_index(), view.get_index(), "%s before the view" % window.name)
	assert_eq(screen._situation_bar.get_index(), screen.get_child_count() - 1,
		"the bar is the last sibling: picked first")
	assert_eq(view.get_index(), screen.get_child_count() - 2, "the view right before it")
	assert_gt(screen._card_preview.z_index, view.z_index, "the big card over the dim")
	assert_lt(screen._card_preview.z_index, screen._situation_bar.z_index,
		"and still under the bar")


## *"8. Big card is on top of windows, for example battle window in the
## duel. It should be behind active windows!"* — the docked big card
## rested at the examine popup's 200, over the combat window (30), the
## hand window (60) and a card in flight (70). Docked, it is a panel of
## its screen at 0; undocked it stays the popup. While a pile is open the
## duel lifts it over the view's dim — the dim would darken the very
## card the pile fills — and rests it again when the view goes.
func test_the_docked_big_card_rests_under_the_windows() -> void:
	var big: CardPreview = screen._card_preview
	assert_true(big.docked)
	assert_eq(big.z_index, 0, "a panel of the screen")
	assert_lt(big.z_index, screen._combat_window.z_index, "under the combat window")
	assert_lt(big.z_index, screen._hand_rows[1].z_index, "under the hand window")
	_open_pile(3)
	assert_gt(big.z_index, screen._grave_view.z_index, "over the dim while the pile is open")
	screen._on_grave_pile_clicked(0)
	assert_eq(big.z_index, 0, "and resting again when it closes")
	var popup := CardPreview.new()
	assert_eq(popup.z_index, CardPreview.POPUP_Z, "undocked: the examine popup, over everything")
	popup.docked = true
	assert_eq(popup.z_index, 0)
	popup.docked = false
	assert_eq(popup.z_index, CardPreview.POPUP_Z)
	popup.free()


# --------------------------------------- the real clicks of the playtest --
#
# *"if you use cards that target graveyard cards ("Raise dead") you should
# be able to click with a target cursor graveyard, the graveyard should
# open and you should be able to target a card in graveyard."* Everything
# above drives the screen's methods; these drive the SCREEN, with the same
# mouse events the engine makes from a real click — the plate, the mini
# card in the open view, the Situation Bar's Cancel over the dim, and the
# double click that used to shut the view on the Deck. The plates are
# skin art, so without the skin there is nothing to click and the tests
# pass as read.

var _xform: Transform2D


func _real(button: int, pressed: bool, at: Vector2, double := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.double_click = double
	event.position = _xform * at
	event.global_position = event.position
	Input.parse_input_event(event)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _xform * at
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2, double := false) -> void:
	_move(at)
	await get_tree().process_frame
	_real(MOUSE_BUTTON_LEFT, true, at, double)
	await get_tree().process_frame
	_real(MOUSE_BUTTON_LEFT, false, at)
	await get_tree().process_frame
	await get_tree().process_frame


func _plate_centre(pid: int) -> Vector2:
	return screen._grave_icons[pid].get_global_rect().get_center()


func _has_plates() -> bool:
	_xform = get_tree().root.get_final_transform()
	return screen._grave_icons.size() == 2 and screen._grave_icons[0] != null


func _stage_raise_dead() -> Array:
	var game: MtgGame = screen.game
	var bear := _bury(0, "Grizzly Bears")
	var raise := _hand(0, "Raise Dead")
	game.active_player = 0
	game.priority_player = 0
	game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	game.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	screen._refresh()
	return [bear, raise]


func test_raise_dead_is_cast_with_real_clicks_on_the_plate_and_the_card() -> void:
	if not _has_plates():
		pass_test("no skin imported — there is no plate to click")
		return
	var staged := _stage_raise_dead()
	var bear: CardInstance = staged[0]
	screen._click_hand_card(staged[1])
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_true(screen._grave_rings[0].visible, "the plate wears the target ring")
	await _click(_plate_centre(0))
	assert_true(screen.graveyard_is_open(), "a real click on the plate opens the pile")
	var widgets: Array = screen._grave_view.widgets(Mtg.Zone.GRAVEYARD, 0)
	assert_eq(widgets.size(), 1)
	var card: MiniCard = widgets[0]
	assert_eq(card._highlight, MiniCard.Highlight.TARGET, "the bear is ringed")
	await _wait_ms(GraveyardView.SETTLE_MS + 20)
	await _click(card.get_global_rect().get_center())
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "a real click on the card took the target")
	assert_false(screen.graveyard_is_open(), "and the view got out of the way")
	assert_eq(screen.game.stack.size(), 1, "Raise Dead is on the chain")
	while not screen.game.stack.is_empty():
		screen.game.pass_priority(screen.game.priority_player)
	assert_eq(bear.zone, Mtg.Zone.HAND, "and the bear came back")


func test_a_real_double_click_on_the_plate_leaves_the_view_open() -> void:
	if not _has_plates():
		pass_test("no skin imported — there is no plate to click")
		return
	_bury(0, "Grizzly Bears")
	screen._refresh()
	var at := _plate_centre(0)
	await _click(at)
	assert_true(screen.graveyard_is_open())
	await _wait_ms(GraveyardView.SETTLE_MS + 70)
	await _click(at, true)
	assert_true(screen.graveyard_is_open(), "the double click's second half: still open")
	await _wait_ms(GraveyardView.SETTLE_MS + 20)
	await _click(at)
	assert_false(screen.graveyard_is_open(), "a plain click on the dim, later: closed")


func test_the_bars_cancel_is_clicked_over_the_open_view() -> void:
	if not _has_plates():
		pass_test("no skin imported — there is no plate to click")
		return
	var staged := _stage_raise_dead()
	screen._click_hand_card(staged[1])
	await _click(_plate_centre(0))
	assert_true(screen.graveyard_is_open())
	var cancel: Button = screen._cancel_button
	assert_true(cancel.is_visible_in_tree(), "Cancel is up while a cast waits")
	await _wait_ms(GraveyardView.SETTLE_MS + 20)
	await _click(cancel.get_global_rect().get_center())
	assert_false(screen.graveyard_is_open(), "the bar's Cancel, over the dim, peels the view")
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the cast still waits — Escape's own ladder")
