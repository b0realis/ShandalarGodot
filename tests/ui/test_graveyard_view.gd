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


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
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
