extends GameTest
## THE OLD LOOPS (2026-09-10, [member AiProfile.runs_loops];
## `docs/forge/casting.md` P5, `docs/arzakon.strategy` §3C and §4 item 6).
##
## Three things reproduced at HEAD before a line was written, all three at
## the same seam — a card whose worth is a fact about the BOARD or about
## the two HANDS was priced by [method Evaluator.card_value], which reads
## the printed card and nothing else:
##
##     Wheel of Fortune, our hand 7 and theirs 0 (a gift of six cards)
##       _cast_value = 4.00
##     Wheel of Fortune, our hand 1 and theirs 7 (a gain of six cards)
##       _cast_value = 4.00        <- the same number
##     Time Walk behind three Serra Angels, their board empty
##       _cast_value = 3.00        <- the flat 3.0 arzakon.strategy §5 names
##     Regrowth over [Time Walk, Serra Angel] in our own graveyard
##       _choose_targets -> Serra Angel, every time (10.00 against 3.00)
##
## The third is why `docs/arzakon.strategy` §3C's loop could never start:
## the Regrowth would not pick the Walk up.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.runs_loops = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.runs_loops = false
	return profile


func _yard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


## What [method AiPlayer._size_and_aim] answers for a card in hand.
func _sized(ai: AiPlayer, inst: CardInstance) -> Dictionary:
	var intent := EffectIntent.read(inst.data.spell_effects, inst.data.card_name)
	return ai._size_and_aim(g, inst, intent, 0, 0)


func _worth(ai: AiPlayer, inst: CardInstance) -> float:
	var sized := _sized(ai, inst)
	return -1.0 if sized.is_empty() else float(sized["value"])


# ------------------------------------------------------- the extra turn --

func test_the_extra_turn_is_priced_by_the_board() -> void:
	var ai := _ai(_on())
	for i in 4:
		put_battlefield(0, "Island")
	for i in 3:
		put_battlefield(0, "Serra Angel")
	var walk := give_hand(0, "Time Walk")
	# a draw step (w_hand 1.5) plus twelve unblocked damage at twenty life,
	# priced by _face_damage_value: 12 * (1 + 12/20) = 19.2.
	assert_almost_eq(_worth(ai, walk), 20.7, 0.001)


func test_off_the_extra_turn_is_a_three_mana_spell() -> void:
	var ai := _ai(_off())
	for i in 4:
		put_battlefield(0, "Island")
	for i in 3:
		put_battlefield(0, "Serra Angel")
	var walk := give_hand(0, "Time Walk")
	assert_almost_eq(_worth(ai, walk), 3.0, 0.001,
		"the flat 3.0, whatever is standing on the table")


func test_an_extra_turn_with_no_board_buys_a_draw_and_nothing_else() -> void:
	var ai := _ai(_on())
	for i in 4:
		put_battlefield(0, "Island")
	var walk := give_hand(0, "Time Walk")
	assert_almost_eq(_worth(ai, walk), 3.0, 0.001,
		"1.5 for the draw step is below the printed 3.00, so the printed card stands")


func test_the_land_drop_is_only_counted_when_a_land_is_held() -> void:
	var ai := _ai(_on())
	for i in 4:
		put_battlefield(0, "Island")
	var walk := give_hand(0, "Time Walk")
	assert_almost_eq(ai._extra_turn_value(g, 1), 1.5, 0.001, "no land in hand")
	give_hand(0, "Island")
	assert_almost_eq(ai._extra_turn_value(g, 1), 2.5, 0.001, "a drop with something to drop")
	assert_eq(walk.zone, Mtg.Zone.HAND)


func test_the_pace_still_refuses_the_walk_our_library_cannot_spare() -> void:
	# THE ORDER OF THE GUARDS: paces_draws runs first and is untouched.
	var ai := _ai(_on())
	for i in 4:
		put_battlefield(0, "Island")
	for i in 3:
		put_battlefield(0, "Serra Angel")
	var walk := give_hand(0, "Time Walk")
	# A lead of exactly nothing, inside the pace's own horizon: our draw
	# step is next, so 11 against 10 is level.
	g.players[0].library.resize(11)
	g.players[1].library.resize(10)
	assert_eq(ai._library_slack(g), 0, "the race is held by nothing at all")
	assert_true(_sized(ai, walk).is_empty(),
		"an extra turn is a draw step the race cannot spare")


# ------------------------------------------------------------- the wheel --

func test_a_wheel_that_gives_cards_away_is_refused() -> void:
	var ai := _ai(_on())
	for i in 5:
		put_battlefield(0, "Mountain")
	var wheel := give_hand(0, "Wheel of Fortune")
	for i in 6:
		give_hand(0, "Forest")
	assert_true(_sized(ai, wheel).is_empty(),
		"six of our cards for none of theirs")


func test_off_the_wheel_is_cast_into_our_own_full_hand() -> void:
	var ai := _ai(_off())
	for i in 5:
		put_battlefield(0, "Mountain")
	var wheel := give_hand(0, "Wheel of Fortune")
	for i in 6:
		give_hand(0, "Forest")
	assert_almost_eq(_worth(ai, wheel), 4.0, 0.001, "the printed card, either way round")


func test_a_wheel_that_takes_cards_is_priced_by_the_swing() -> void:
	var ai := _ai(_on())
	for i in 5:
		put_battlefield(0, "Mountain")
	var wheel := give_hand(0, "Wheel of Fortune")
	for i in 7:
		give_hand(1, "Forest")
	# the wheel is on the stack while it resolves (CR 608.2m), so our hand
	# is 0 against their 7: seven cards moved, at w_hand 1.5 each.
	assert_eq(ai._wheel_swing(g, wheel,
		EffectIntent.read(wheel.data.spell_effects, wheel.data.card_name)), 7)
	assert_almost_eq(_worth(ai, wheel), 14.5, 0.001)


func test_off_the_same_wheel_is_the_same_four() -> void:
	var ai := _ai(_off())
	for i in 5:
		put_battlefield(0, "Mountain")
	var wheel := give_hand(0, "Wheel of Fortune")
	for i in 7:
		give_hand(1, "Forest")
	assert_almost_eq(_worth(ai, wheel), 4.0, 0.001)


func test_a_reroll_keeps_its_printed_worth() -> void:
	# Winds of Change gives each player back exactly what it took
	# (EffectIntent.WHEEL_REDRAW), so the swing cancels whatever the hands
	# hold and there is nothing here to price.
	var ai := _ai(_on())
	for i in 3:
		put_battlefield(0, "Mountain")
	var winds := give_hand(0, "Winds of Change")
	for i in 7:
		give_hand(1, "Forest")
	assert_eq(EffectIntent.read(winds.data.spell_effects, winds.data.card_name).wheels,
		EffectIntent.WHEEL_REDRAW)
	assert_almost_eq(_worth(ai, winds), 2.5, 0.001)


func test_a_wheel_our_library_cannot_pay_for_is_refused() -> void:
	var ai := _ai(_on())
	for i in 5:
		put_battlefield(0, "Mountain")
	var wheel := give_hand(0, "Wheel of Fortune")
	for i in 7:
		give_hand(1, "Forest")
	g.players[0].library.resize(5)
	assert_true(_sized(ai, wheel).is_empty(),
		"seven cards off a library of five is the draw from nothing (CR 704.5b)")


# -------------------------------------------------------------- the loop --

func test_the_regrowth_takes_the_time_walk_off_a_board_that_attacks() -> void:
	var ai := _ai(_on())
	for i in 7:
		put_battlefield(0, "Island")
	for i in 3:
		put_battlefield(0, "Serra Angel")
	_yard(0, "Time Walk")
	_yard(0, "Serra Angel")
	var regrowth := give_hand(0, "Regrowth")
	var targets = ai._choose_targets(g, regrowth, 0, 0)
	assert_not_null(targets)
	assert_eq(g.find_instance(targets[0].instance_id).data.card_name, "Time Walk")


func test_off_the_regrowth_takes_the_angel() -> void:
	var ai := _ai(_off())
	for i in 7:
		put_battlefield(0, "Island")
	for i in 3:
		put_battlefield(0, "Serra Angel")
	_yard(0, "Time Walk")
	_yard(0, "Serra Angel")
	var regrowth := give_hand(0, "Regrowth")
	var targets = ai._choose_targets(g, regrowth, 0, 0)
	assert_not_null(targets)
	assert_eq(g.find_instance(targets[0].instance_id).data.card_name, "Serra Angel",
		"10.00 against 3.00, and the pick is Evaluator.card_value alone")


func test_the_regrowth_still_takes_the_angel_off_an_empty_board() -> void:
	# The knob does not prefer the Walk; it prices it. With nothing to
	# attack with, an extra turn IS worth less than a Serra Angel.
	var ai := _ai(_on())
	for i in 7:
		put_battlefield(0, "Island")
	_yard(0, "Time Walk")
	_yard(0, "Serra Angel")
	var regrowth := give_hand(0, "Regrowth")
	var targets = ai._choose_targets(g, regrowth, 0, 0)
	assert_eq(g.find_instance(targets[0].instance_id).data.card_name, "Serra Angel")


func test_the_walk_is_cast_before_the_regrowth_beside_it() -> void:
	# The ORDER, and it is a value and not a fourth rule: a turn taken
	# with a returner in hand is a card that comes back.
	var ai := _ai(_on())
	for i in 4:
		put_battlefield(0, "Island")
	var walk := give_hand(0, "Time Walk")
	var regrowth := give_hand(0, "Regrowth")
	_yard(0, "Serra Angel")
	assert_almost_eq(_worth(ai, walk), 4.5, 0.001, "3.00, and 1.5 for the card that comes back")
	assert_gt(_worth(ai, walk), ai._cast_value(g, regrowth,
		ai._choose_targets(g, regrowth, 0, 0), 0))


func test_off_the_walk_and_the_regrowth_are_the_same_three() -> void:
	var ai := _ai(_off())
	for i in 4:
		put_battlefield(0, "Island")
	var walk := give_hand(0, "Time Walk")
	var regrowth := give_hand(0, "Regrowth")
	_yard(0, "Serra Angel")
	assert_almost_eq(_worth(ai, walk), 3.0, 0.001)
	assert_almost_eq(ai._cast_value(g, regrowth,
		ai._choose_targets(g, regrowth, 0, 0), 0), 3.0, 0.001)


func test_raise_dead_is_not_a_returner_for_a_time_walk() -> void:
	# The shape and not the name: a Raise Dead's spec admits creatures
	# only, and cannot take a Time Walk back.
	var ai := _ai(_on())
	for i in 4:
		put_battlefield(0, "Island")
	var walk := give_hand(0, "Time Walk")
	give_hand(0, "Raise Dead")
	assert_false(ai._returner_in_hand(g, walk))
	assert_almost_eq(_worth(ai, walk), 3.0, 0.001, "no premium, so the printed card stands")


func test_a_wheel_in_the_graveyard_is_offered_at_what_it_would_move() -> void:
	var ai := _ai(_on())
	for i in 6:
		put_battlefield(0, "Island")
	var twister := _yard(0, "Timetwister")
	_yard(0, "Grizzly Bears")
	for i in 7:
		give_hand(1, "Forest")
	assert_gt(ai._graveyard_worth(g, twister),
		ai._graveyard_worth(g, g.players[0].graveyard[1]),
		"seven of their cards for none of ours outprices a 2/2")


func test_off_the_graveyard_pick_is_the_printed_card() -> void:
	var ai := _ai(_off())
	for i in 6:
		put_battlefield(0, "Island")
	var twister := _yard(0, "Timetwister")
	for i in 7:
		give_hand(1, "Forest")
	assert_almost_eq(ai._graveyard_worth(g, twister),
		Evaluator.card_value(twister.data), 0.001)
