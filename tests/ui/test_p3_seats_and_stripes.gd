extends GutTest
## THE POLISH PASS (2026-10-28), P3 item 5 — two reads of the table that
## served the wrong thing.
##
##  * The STATUS LINE at an open two-human table (a Test hands duel with two
##    humans — [method DuelConfig.for_test] never makes a private hotseat)
##    still read seat 0: [method DuelScreen._phase_status_message] took its
##    "you" as `0 if _is_human(0) else 1`, so on seat 1's own main phase,
##    with seat 1 holding priority, the bar said the bare step name instead
##    of seat 1's `Main phase (before combat): cast spells, play land`.
##    The bug campaign c12 (h4-4) moved every other read to
##    [method DuelScreen._viewing_seat]; this one was left (ledger duel-090).
##  * The SMALL CARD'S MANA STRIPES read the PRINTED ability: Gem Bazaar
##    wore a white stripe whatever colour it had chosen (white is the
##    stand-in its dynamic colour reads before anything is chosen), Fellwar
##    Stone a colourless one though it makes the colours of the opponent's
##    lands, and Reflecting Pool a colourless one though it makes what its
##    controller's other lands make. On the table the stripes are now the
##    colours each mana ability would make NOW ([method
##    MiniCard.live_mana_colors] — the census Fellwar Stone already takes,
##    CR 106.7).

var screen: DuelScreen


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)


func after_each() -> void:
	CardPacks.set_enabled("pack-9", false)
	await get_tree().process_frame


func _two_humans(active: int, step: int) -> MtgGame:
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Forest")
	position.add(1, DuelPosition.TABLE, "Mountain")
	position.add(1, DuelPosition.HAND, "Grizzly Bears")
	position.active_player = active
	position.step = step
	var config := DuelConfig.hotseat_default().for_test(position, 31337)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_false(config.private_hotseat(), "control: an open table")
	return screen.game


# ===================================================== the status line --

func test_the_status_line_serves_seat_one_on_its_own_main_phase() -> void:
	var g := await _two_humans(1, Mtg.Step.MAIN1)
	assert_eq(g.active_player, 1, "control: seat 1's turn")
	assert_eq(g.priority_player, 1, "control: seat 1 holds priority")
	assert_eq(screen._viewing_seat(), 1, "control: the screen serves seat 1")
	assert_eq(screen._phase_status_message(),
		"Main phase (before combat): cast spells, play land",
		"seat 1's own main phase reads as seat 1's, not as seat 0's opponent's")


func test_and_seat_zero_on_seat_zeros() -> void:
	var g := await _two_humans(0, Mtg.Step.MAIN1)
	assert_eq(g.priority_player, 0)
	assert_eq(screen._phase_status_message(),
		"Main phase (before combat): cast spells, play land")


func test_seat_one_answering_on_seat_zeros_turn_reads_the_fast_effects_line() -> void:
	var g := await _two_humans(0, Mtg.Step.MAIN1)
	g.priority_player = 1
	assert_eq(screen._viewing_seat(), 1, "control: seat 1 decides")
	assert_true(screen._phase_status_message().begins_with("Fast Effects?..."),
		"seat 1 holding priority on seat 0's turn is asked the 1997 question: %s"
			% screen._phase_status_message())


func test_against_the_computer_nothing_moves() -> void:
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	g.active_player = 1
	g.priority_player = 1
	assert_eq(screen._phase_status_message(), "Still thinking...",
		"the computer's priority is still the referee working")


# ================================================== the mana stripes --

func _game() -> MtgGame:
	var g := MtgGame.new()
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	g.start(0)
	return g


func _put(g: MtgGame, pid: int, card_name: String) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "%s is in the pool" % card_name)
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	return inst


## The stripe slots a widget drew, by position — the same reading for the
## 1997 sheet and for none.
func _slots(w: MiniCard) -> Array:
	var out := []
	for child in w._stripes.get_children():
		for slot in MiniCard.STRIPE_SLOT_COUNT:
			if is_equal_approx((child as Control).position.x, MiniCard._stripe_x(slot)):
				out.append(slot)
	out.sort()
	return out


func _widget(inst: CardInstance, g: MtgGame) -> MiniCard:
	var w := MiniCard.new(inst, g)
	add_child_autofree(w)
	return w


func test_gem_bazaar_wears_the_colour_it_chose() -> void:
	var g := _game()
	var bazaar := _put(g, 0, "Gem Bazaar")
	bazaar.memory["color"] = Mtg.ManaColor.R
	assert_eq(_slots(_widget(bazaar, g)), [MiniCard.STRIPE_SLOT[Mtg.ManaColor.R]],
		"red chosen: the red stripe, not the white stand-in")


func test_gem_bazaar_before_any_choice_makes_nothing_and_wears_nothing() -> void:
	var g := _game()
	var bazaar := _put(g, 0, "Gem Bazaar")
	bazaar.memory.erase("color")
	assert_eq(_slots(_widget(bazaar, g)), [],
		"no colour chosen yet: tapping adds nothing (its dynamic amount is 0)")


func test_fellwar_stone_wears_the_opponents_lands_colours() -> void:
	var g := _game()
	var stone := _put(g, 0, "Fellwar Stone")
	_put(g, 1, "Island")
	_put(g, 1, "Mountain")
	assert_eq(_slots(_widget(stone, g)), [MiniCard.STRIPE_SLOT[Mtg.ManaColor.U],
		MiniCard.STRIPE_SLOT[Mtg.ManaColor.R]], "blue and red: what the Stone could make")


func test_fellwar_stone_with_no_coloured_land_opposite_wears_nothing() -> void:
	var g := _game()
	var stone := _put(g, 0, "Fellwar Stone")
	assert_eq(_slots(_widget(stone, g)), [], "it would make no mana at all")


func test_reflecting_pool_wears_its_controllers_lands_types() -> void:
	var g := _game()
	var pool := _put(g, 0, "Reflecting Pool")
	_put(g, 0, "Forest")
	_put(g, 0, "Island")
	_put(g, 1, "Mountain")
	assert_eq(_slots(_widget(pool, g)), [MiniCard.STRIPE_SLOT[Mtg.ManaColor.U],
		MiniCard.STRIPE_SLOT[Mtg.ManaColor.G]], "its own lands' types, not the opponent's")


func test_a_plain_land_is_unchanged() -> void:
	var g := _game()
	var forest := _put(g, 0, "Forest")
	assert_eq(_slots(_widget(forest, g)), [MiniCard.STRIPE_SLOT[Mtg.ManaColor.G]])
	var brass := _put(g, 0, "City of Brass")
	assert_eq(_slots(_widget(brass, g)).size(), 5, "City of Brass wears all five")


func test_off_the_table_a_census_card_wears_nothing_it_cannot_promise() -> void:
	var g := _game()
	var stone := CardInstance.new(CardRegistry.get_card("Fellwar Stone"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[stone.id] = stone
	stone.zone = Mtg.Zone.HAND
	_put(g, 1, "Island")
	assert_eq(_slots(_widget(stone, g)), [],
		"in a hand the Stone makes nothing yet: no colourless stripe that is not true")
