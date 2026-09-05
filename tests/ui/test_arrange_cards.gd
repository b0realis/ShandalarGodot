extends GutTest
## ARRANGE CARDS on the duel table — `docs/duel-todo.md` §2.3.
##
## The order itself is pinned in `tests/unit/test_board_order.gd`; this
## file pins the CONTROL: where it lives, that it is a toggle, that
## untoggling restores the play order exactly (including for a card that
## arrived while the table was arranged), and that a click on an arranged
## card still operates that card and not the one that used to sit there.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


## Every LIVE MiniCard under [param node], in tree order.
##
## The queued-for-deletion skip is not optional: `CardPile.populate` frees
## its children without removing them first (the immediate-mode CAVEAT in
## `docs/duel-screen-design.md`, twenty-sixth pass), so the previous
## rebuild's widgets are still in the tree for the rest of the frame.
## `TargetArrows._collect` carries the same guard for the same reason.
func _mini_cards(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is MiniCard:
			out.append(child)
		out.append_array(_mini_cards(child))
	return out


func _names(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append(c.instance.data.card_name if c is MiniCard
			else c.data.card_name)
	return out


## Replace seat 0's hand with exactly these cards, in this order.
func _set_hand(card_names: Array) -> void:
	var g: MtgGame = screen.game
	g.players[0].hand.clear()
	for card_name in card_names:
		var data := CardRegistry.get_card(card_name)
		var inst := CardInstance.new(data, g._next_instance_id, 0)
		g._next_instance_id += 1
		g._instances[inst.id] = inst
		inst.zone = Mtg.Zone.HAND
		g.players[0].hand.append(inst)


func _put(card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, 0)
	return inst


# ------------------------------------------------------------ the control --

func test_the_toggle_lives_in_the_qol_reserve() -> void:
	# The strip under the docked Showcase, built and named for exactly
	# this: "the black space under the large preview card will be used by
	# new QoL buttons and features when they land".
	assert_not_null(screen._arrange_button)
	assert_eq(screen._arrange_button.get_parent(), screen._qol_reserve)
	assert_true(screen._arrange_button.toggle_mode, "click on, click off")


func test_the_toggle_is_right_aligned_in_the_strip() -> void:
	await get_tree().process_frame
	var btn := screen._arrange_button
	var strip := screen._qol_reserve
	assert_almost_eq(btn.position.x + btn.size.x, strip.size.x - 4.0, 1.0,
		"hugs the column's inner edge — the owner's 'on the right'")
	assert_lt(btn.position.y, 16.0, "and rides up under the big card")


func test_the_control_carries_the_1997_command_name() -> void:
	# `@MENU_TERRITORY` entry 15, UIStrings.txt:908 — `Arrange your
	# cards\tDblClk`, minus the accelerator, which is not our gesture.
	assert_eq(screen._arrange_button.tooltip_text, "Arrange your cards")


func test_the_icon_changes_with_the_state() -> void:
	# Three cards askew, three cards squared up — the picture Duel.hlp
	# draws in words ("straightens up the cards in play").
	assert_ne(ArrangeButton.glyph(false), ArrangeButton.glyph(true))
	assert_eq(screen._arrange_button.icon, ArrangeButton.glyph(false))
	screen._arrange_button.button_pressed = true
	assert_eq(screen._arrange_button.icon, ArrangeButton.glyph(true))


# --------------------------------------------------------------- the hand --

func test_the_hand_renders_in_play_order_until_it_is_arranged() -> void:
	_set_hand(["Sol Ring", "Lightning Bolt", "Forest", "Healing Salve"])
	screen._refresh()
	assert_eq(screen._hand_order(0).map(func(c: CardInstance) -> String:
		return c.data.card_name),
		["Sol Ring", "Lightning Bolt", "Forest", "Healing Salve"])


func test_arranging_puts_the_hand_in_display_order() -> void:
	_set_hand(["Sol Ring", "Lightning Bolt", "Forest", "Healing Salve"])
	screen._on_arrange_toggled(true)
	assert_eq(_names(screen._hand_order(0)),
		["Forest", "Healing Salve", "Lightning Bolt", "Sol Ring"],
		"land, then W, then R, then colourless")
	# ...and the widgets follow, not just the model.
	var hand: Control = screen._hand_rows[1]
	assert_eq(_names(_mini_cards(hand)),
		["Forest", "Healing Salve", "Lightning Bolt", "Sol Ring"])


func test_unarranging_restores_the_exact_previous_order() -> void:
	# The owner's requirement in one assertion: "unclick would return to
	# previous state it was before sorting."
	var before := ["Sol Ring", "Lightning Bolt", "Forest", "Healing Salve"]
	_set_hand(before)
	screen._on_arrange_toggled(true)
	screen._on_arrange_toggled(false)
	assert_eq(_names(screen._hand_order(0)), before)
	assert_eq(_names(_mini_cards(screen._hand_rows[1])), before)


func test_a_card_that_arrives_while_arranged_lands_where_the_engine_put_it() -> void:
	# The one question the toggle has to answer. Arranged, the newcomer
	# takes its sorted place at once; unarranged, it shows up where the
	# ENGINE holds it, which for a card just added to the hand is the end.
	# Nothing is snapshotted, so nothing can go stale.
	_set_hand(["Sol Ring", "Forest"])
	screen._on_arrange_toggled(true)
	_set_hand(["Sol Ring", "Forest", "Healing Salve"])
	assert_eq(_names(screen._hand_order(0)),
		["Forest", "Healing Salve", "Sol Ring"])
	screen._on_arrange_toggled(false)
	assert_eq(_names(screen._hand_order(0)),
		["Sol Ring", "Forest", "Healing Salve"])


func test_clicking_an_arranged_card_operates_that_card() -> void:
	# THE ANTI-DRIFT PIN. Two spells in reverse display order: arranged,
	# the FIRST widget is the one that was SECOND in the hand, and clicking
	# it must begin casting THAT card. Every MiniCard binds its own
	# CardInstance (`w.pressed.connect(_on_card_clicked.bind(inst))`), so
	# there is no index to drift — this test is what keeps it that way.
	_set_hand(["Lightning Bolt", "Healing Salve"])
	screen._on_arrange_toggled(true)
	var widgets := _mini_cards(screen._hand_rows[1])
	assert_eq(_names(widgets), ["Healing Salve", "Lightning Bolt"],
		"White before red, so the hand reads back to front")
	var first: MiniCard = widgets[0]
	screen._on_card_clicked(first.instance)
	assert_eq(screen._pending_card, first.instance,
		"the card under the pointer is the card being cast")


# ---------------------------------------------------------- the territory --

func test_arranging_orders_the_creature_and_land_rows() -> void:
	for card_name in ["Grizzly Bears", "Shivan Dragon", "Wall of Stone"]:
		_put(card_name)
	for card_name in ["Mountain", "Forest"]:
		_put(card_name)
	screen.game.recalculate()
	screen._on_arrange_toggled(true)
	var creatures: Control = screen._field_rows[0][DuelScreen.Row.CREATURES]
	assert_eq(_names(_mini_cards(creatures)),
		["Shivan Dragon", "Grizzly Bears", "Wall of Stone"],
		"power descending, then toughness, then name")
	var lands: Control = screen._field_rows[0][DuelScreen.Row.LANDS]
	var land_names := _names(_mini_cards(lands))
	assert_eq(land_names.slice(land_names.size() - 2), ["Forest", "Mountain"],
		"lands by name")


func test_other_permanents_keep_their_play_order() -> void:
	# The reference sorts three groups and leaves this one alone: it is the
	# row where the player's own grouping carries meaning.
	var order: Array = []
	for card_name in ["Sol Ring", "Black Vise", "Howling Mine"]:
		order.append(_put(card_name))
	screen.game.recalculate()
	screen._on_arrange_toggled(true)
	var others: Control = screen._field_rows[0][DuelScreen.Row.OTHER]
	assert_eq(_names(_mini_cards(others)), _names(order))


func test_the_arrange_never_reorders_the_engines_own_arrays() -> void:
	# "This has no effect on the duel, it just makes things neater."
	# The battlefield array is the engine's; a view may read it, never
	# rewrite it.
	for card_name in ["Shivan Dragon", "Grizzly Bears", "Mountain", "Forest"]:
		_put(card_name)
	_set_hand(["Sol Ring", "Forest"])
	var field_before := _names(screen.game.players[0].battlefield)
	var hand_before := _names(screen.game.players[0].hand)
	screen._on_arrange_toggled(true)
	assert_eq(_names(screen.game.players[0].battlefield), field_before)
	assert_eq(_names(screen.game.players[0].hand), hand_before)
