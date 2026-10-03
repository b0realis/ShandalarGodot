extends GutTest
## "IN ANY ORDER", ONE CLICK INSTEAD OF ONE PER CARD (Pack 8 — Teferi's
## Puzzle Box: "At the beginning of each player's draw step, that player
## puts the cards in their hand on the bottom of their library in any
## order, then draws that many cards").
##
## The card asks once per card, each going beneath the last — with a full
## hand, seven questions every draw step. Any order is legal and the
## library's bottom is hidden, so a pick of such a sequence
## (`DecisionAgent.choose_card_in_order`, `PlayerChoice.in_order`) wears a
## last line, `Done — keep this order.`: this card and the rest go in the
## order listed, and no further question is put for that resolution
## (`HumanAgent.keep_order_for`). The player may still place any cards by
## hand first. A question that is NOT part of such a sequence never offers
## the line.
##
## The box here is a synthetic instant running the card's own loop through
## the new call, so the pin holds whatever state the card file is in.

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	screen.game.players[0].hand.clear()
	screen.game.players[1].hand.clear()


func after_each() -> void:
	CardPacks.set_enabled("pack-8", false)
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


class BoxEffect extends EffectBase:
	var asks_in_order := true
	func resolve(g: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x := 0) -> void:
		var left: Array[CardInstance] = g.players[controller].hand.duplicate()
		var n := left.size()
		while not left.is_empty():
			var pick: CardInstance = left[0]
			if left.size() > 1:
				var answer: CardInstance
				if asks_in_order:
					answer = g.agents[controller].choose_card_in_order(g, controller, left,
						"Test Box: put a card on the bottom of your library (each goes beneath the last)")
				else:
					answer = g.agents[controller].choose_card(g, controller, left,
						"Test Box: put a card on the bottom of your library", false, false, true)
				if answer != null and left.has(answer):
					pick = answer
			left.erase(pick)
			g.put_on_bottom_of_library(pick)
		g.draw_cards(controller, n)
	func describe() -> String:
		return "put your hand on the bottom of your library in any order, then draw that many"


func _box(in_order := true) -> CardData:
	var effect := BoxEffect.new()
	effect.asks_in_order = in_order
	return CardData.new("Test Box", "{0}", Mtg.CardType.INSTANT).spell(effect)


func _make(pid: int, data: CardData) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


## Main phase of the human's turn, a Stop on it, five named cards in hand
## and the box cast: the resolution is held on its first pick.
func _hand_of_five_and_the_box(in_order := true) -> Array:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g._probing = false
	var here: Array = screen._phase_key()
	screen.stops.set_marked(here[0], here[1], here[2], true)
	var box := _make(0, _box(in_order))
	var cards: Array[CardInstance] = []
	for i in 5:
		cards.append(_make(0, CardData.new("Card %s" % "ABCDE"[i], "{1}",
			Mtg.CardType.ARTIFACT)))
	assert_eq(g.cast_spell(0, box), "")
	for _i in 10:
		if g.awaiting_choice != null or g.stack.is_empty():
			break
		var acting := screen._ai_seat_to_act()
		if acting != -1:
			screen._ais[acting].act(g)
		else:
			screen._on_pass()
	return cards


func test_a_pick_or_two_then_keep_this_order_finishes_in_one_click() -> void:
	var g: MtgGame = screen.game
	var cards := _hand_of_five_and_the_box()
	var first: PlayerChoice = g.awaiting_choice
	assert_not_null(first, "the first pick is put to the player")
	if first == null:
		return
	assert_true(first.in_order)
	var labels := DuelScreen.choice_options(first)
	assert_eq(labels.size(), 6, "five cards and the one-click line")
	assert_eq(labels.back(), DuelScreen.KEEP_ORDER_LINE)
	# Place Card C by hand first.
	screen._on_choice_option(labels.find("Card C"))
	var second: PlayerChoice = g.awaiting_choice
	assert_not_null(second, "the next pick")
	if second == null:
		return
	assert_eq(DuelScreen.choice_options(second),
		["Card A", "Card B", "Card D", "Card E", DuelScreen.KEEP_ORDER_LINE])
	var asked := g.choice_log.size()
	screen._on_choice_option(4)   # Done — keep this order.
	assert_null(g.awaiting_choice, "no further question")
	assert_true(g.stack.is_empty(), "the box resolved")
	# C first, then A, B, D, E — each beneath the last.
	var lib: Array = g.players[0].library
	var at := func(c: CardInstance) -> int: return lib.find(c)
	assert_true(lib.has(cards[2]), "C went to the library")
	var order := [cards[2], cards[0], cards[1], cards[3], cards[4]]
	var placed := order.filter(func(c: CardInstance) -> bool: return lib.has(c))
	for i in range(1, placed.size()):
		assert_lt(at.call(placed[i]), at.call(placed[i - 1]),
			"%s lies beneath %s" % [placed[i].data.card_name, placed[i - 1].data.card_name])
	assert_eq(g.players[0].hand.size(), 5, "then drew that many")
	for entry in g.choice_log.slice(asked):
		assert_true((entry as PlayerChoice).answered_by_player,
			"every pick counted as the player's own")
	assert_eq(g.unanswered_choices.size(), 0, "nothing decided on the player's behalf")


func test_keep_this_order_on_the_first_pick_answers_everything() -> void:
	var g: MtgGame = screen.game
	var cards := _hand_of_five_and_the_box()
	var first: PlayerChoice = g.awaiting_choice
	if first == null:
		fail_test("the first pick was not held")
		return
	screen._on_choice_option(DuelScreen.choice_options(first).size() - 1)
	assert_null(g.awaiting_choice)
	assert_true(g.stack.is_empty())
	var lib: Array = g.players[0].library
	for i in range(1, cards.size()):
		if lib.has(cards[i]) and lib.has(cards[i - 1]):
			assert_lt(lib.find(cards[i]), lib.find(cards[i - 1]), "the listed order")
	assert_eq(g.unanswered_choices.size(), 0)


func test_the_next_box_asks_again() -> void:
	# The one-click answer belongs to the resolution it was given in.
	var g: MtgGame = screen.game
	_hand_of_five_and_the_box()
	if g.awaiting_choice == null:
		fail_test("the first pick was not held")
		return
	screen._on_choice_option(DuelScreen.choice_options(g.awaiting_choice).size() - 1)
	assert_true(g.stack.is_empty())
	var again := _make(0, _box())
	assert_eq(g.cast_spell(0, again), "")
	for _i in 10:
		if g.awaiting_choice != null or g.stack.is_empty():
			break
		var acting := screen._ai_seat_to_act()
		if acting != -1:
			screen._ais[acting].act(g)
		else:
			screen._on_pass()
	assert_not_null(g.awaiting_choice, "a fresh box asks its first pick again")


func test_an_ordinary_ordered_pick_never_offers_the_line() -> void:
	var g: MtgGame = screen.game
	_hand_of_five_and_the_box(false)
	var first: PlayerChoice = g.awaiting_choice
	assert_not_null(first)
	if first == null:
		return
	assert_false(first.in_order)
	assert_true(first.ordered)
	assert_false(DuelScreen.choice_options(first).has(DuelScreen.KEEP_ORDER_LINE))
	assert_false(DuelScreen.offers_keep_order(first))


# ============================================ the real card, Pack 8 on --

func test_the_real_puzzle_box_offers_keep_this_order_at_your_draw_step() -> void:
	CardPacks.set_enabled("pack-8", true)
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card("Teferi's Puzzle Box")
	assert_not_null(data, "Pack 8 is on")
	if data == null:
		CardPacks.set_enabled("pack-8", false)
		return
	var box := CardInstance.new(data, g._next_instance_id, 0)
	g._next_instance_id += 1
	g._probing = true
	g._instances[box.id] = box
	g._put_on_battlefield(box, 0)
	g.recalculate()
	g._probing = false
	var hand: Array[CardInstance] = []
	for i in 3:
		hand.append(_make(0, CardData.new("Card %s" % "XYZ"[i], "{1}", Mtg.CardType.ARTIFACT)))
	# A Stop on my draw step, so the screen leaves the window to me; then
	# the step begins: the draw, then the box's trigger (CR 504.1-504.2).
	g._probing = true
	g.turn_number = maxi(g.turn_number, 3)   # no first-turn draw skip
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	g.priority_player = 0
	g._probing = false
	var draw_key := [PhaseStops.half_for_seat(0, screen._human_seat()),
		PhaseStops.Bar.PHASE, DuelScreen._phase_icon_slot(Mtg.Step.DRAW)]
	screen.stops.set_marked(draw_key[0], draw_key[1], draw_key[2], true)
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DRAW))
	var in_hand := g.players[0].hand.size()
	assert_eq(in_hand, 4, "three, and the step's own draw")
	for _i in 20:
		if g.awaiting_choice != null or (g.stack.is_empty() and g.current_step() != Mtg.Step.DRAW):
			break
		var acting := screen._ai_seat_to_act()
		if acting != -1:
			screen._ais[acting].act(g)
		elif g.priority_player == 0 and g.awaiting_choice == null:
			screen._on_pass()
		else:
			screen._refresh()
	var held: PlayerChoice = g.awaiting_choice
	assert_not_null(held, "the box puts the first pick to the player")
	if held == null:
		CardPacks.set_enabled("pack-8", false)
		return
	assert_eq(held.source, "Teferi's Puzzle Box")
	assert_true(held.in_order, "the card asks through choose_card_in_order")
	assert_true(DuelScreen.offers_keep_order(held))
	var labels := DuelScreen.choice_options(held)
	assert_eq(labels.back(), DuelScreen.KEEP_ORDER_LINE)
	screen._on_choice_option(labels.size() - 1)
	assert_null(g.awaiting_choice, "one click answered the whole hand")
	assert_eq(g.players[0].hand.size(), in_hand, "then drew that many")
	for card in hand:
		assert_eq(card.zone, Mtg.Zone.LIBRARY, "%s went to the bottom" % card.data.card_name)
	assert_eq(g.unanswered_choices.size(), 0)
	CardPacks.set_enabled("pack-8", false)
