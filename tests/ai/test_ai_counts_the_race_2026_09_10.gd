extends GameTest
## THE DECKING COUNT (2026-09-10, [member AiProfile.counts_the_race];
## `docs/forge/casting.md` P3, `docs/arzakon.strategy` §4 item 4).
##
## [member AiProfile.paces_draws] already reads the two libraries as a race
## and it counts CARDS, which is exactly right while each side loses one a
## turn: a draw step takes one card from each library in turn, so a lead in
## cards IS a lead in turns. A MILL breaks that equality, and every reading
## built on it is then wrong by the ratio.
##
## Reproduced at HEAD before a line was written, a Wizard in seat 0:
##
##     our Millstone, their library 30, three Islands untapped
##       _ability_option(MAIN) = {}      _ability_option(SINK) = {}
##       _try_activate            -> ''  (the Millstone stays untapped)
##     our Millstone, their library 2 — the mill is the game
##       _ability_option(MAIN) = {}      _try_activate -> ''
##     our library 12, theirs 30, our Millstone taking two a turn
##       _library_slack           = 1048576   ("the race is lost already")
##       the truth: their clock 10 turns, ours 12 — the race is OURS
##     their Millstone + their Jayemdae Tome, our library 6, one Disenchant
##       _victim_value(Millstone) = 2.60  _victim_value(Tome) = 4.20
##       _best_victim             -> Jayemdae Tome
##     our library 40, theirs 3 with 20 cards in their graveyard
##       _size_and_aim(Timetwister) = 11.50, cast — their library back at 21
##
## So not one card had ever been milled in this AI's life, and the pace
## called a race it was winning by two turns lost.
##
## THE HORIZON IS THE DECKING CLOCK AND NOTHING ELSE, and that is a ruling
## rather than an omission. A library is MONOTONE — it only ever shrinks,
## its draw step is a rule and not a choice, and a mill on the table mills
## again next turn unless somebody takes it off — so turns counted off it
## are a fact. Every other rate this engine can see is revisable inside a
## turn, which is why [constant AiPlayer.RACE_HORIZON] refuses to read a
## combat clock more than four turns out. The bound here is [constant
## AiPlayer.PACE_HORIZON], the libraries' own, and no new number.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.counts_the_race = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.counts_the_race = false
	return profile


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## Test surgery: the two libraries at exactly these counts, out of the
## harness's thirty filler Forests each — [method _libraries] in
## `test_ai_paces_draws_2026_09_07.gd`, the file this one extends.
func _libraries(mine: int, theirs: int) -> void:
	g.players[0].library.resize(mine)
	g.players[1].library.resize(theirs)


## [param count] cards into [param seat]'s graveyard, for a wheel that
## shuffles them back.
func _graveyard(seat: int, count: int) -> void:
	for _i in count:
		var dead := _make_instance(seat, "Grizzly Bears")
		dead.zone = Mtg.Zone.GRAVEYARD
		g.players[seat].graveyard.append(dead)


func _intent(inst: CardInstance) -> EffectIntent:
	return EffectIntent.read(inst.data.spell_effects, inst.data.card_name)


## What the one Disenchant in hand would destroy.
func _disenchant_pick(ai: AiPlayer) -> String:
	var dis := give_hand(0, "Disenchant")
	var victim := ai._best_victim(g, dis, _intent(dis), 0)
	return "" if victim == null else victim.data.card_name


# ----------------------------------------------------- the printed reading --

func test_the_pool_holds_exactly_one_mill() -> void:
	# The census that says what the reading covers, the way
	# `test_ai_minds_the_vise_2026_09_10.gd` says what the toll covers.
	var found: Array = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		var effects: Array = []
		effects.append_array(data.spell_effects)
		for ability in data.activated_abilities:
			effects.append_array(ability.effects)
		for e in effects:
			if e is MillEffect:
				found.append(card_name)
				break
	found.sort()
	assert_eq(found, ["Millstone"], "the whole of the shape in this pool")


func test_a_mill_is_read_as_a_count_and_not_a_flag() -> void:
	var stone := CardRegistry.get_card("Millstone")
	var intent := EffectIntent.read(stone.activated_abilities[0].effects, "Millstone")
	assert_eq(intent.mills, 2, "{2}, {T}: target player mills two cards")
	assert_eq(intent.target_spec.kind, TargetSpec.Kind.PLAYER)
	# ...and nothing else in this vocabulary carries one.
	var bolt := CardRegistry.get_card("Lightning Bolt")
	assert_eq(EffectIntent.read(bolt.spell_effects, "Lightning Bolt").mills, 0)


func test_the_wheel_that_puts_the_graveyards_back_says_so() -> void:
	var twister := CardRegistry.get_card("Timetwister")
	var wheel := CardRegistry.get_card("Wheel of Fortune")
	var winds := CardRegistry.get_card("Winds of Change")
	var t := EffectIntent.read(twister.spell_effects, "Timetwister")
	var w := EffectIntent.read(wheel.spell_effects, "Wheel of Fortune")
	var c := EffectIntent.read(winds.spell_effects, "Winds of Change")
	assert_eq(t.wheels, 7)
	assert_true(t.wheel_recycles, "hand AND graveyard into the library")
	assert_eq(w.wheels, 7)
	assert_false(w.wheel_recycles, "a discard feeds the graveyard, not the library")
	assert_eq(c.wheels, EffectIntent.WHEEL_REDRAW)
	assert_false(c.wheel_recycles, "a hand shuffled back and no graveyard")


# ------------------------------------------------------------- the clocks --

func test_the_clock_is_the_library_over_the_rate() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		_libraries(12, 30)
		assert_eq(ai._deck_clock(g, 0), 12, "one a turn, no mill anywhere")
		assert_eq(ai._deck_clock(g, 1), 30)
		put_battlefield(0, "Millstone")
		if knob:
			assert_eq(ai._mill_rate(g, 1), 2, "their library loses three a turn")
			assert_eq(ai._deck_clock(g, 1), 10, "30 over 3, rounded up")
			assert_eq(ai._deck_clock(g, 0), 12, "ours still loses one a turn")
		else:
			assert_eq(ai._mill_rate(g, 1), 0, "off: no mill is read at all")
			assert_eq(ai._deck_clock(g, 1), 30)


func test_a_mill_of_ours_is_not_aimed_at_ourselves() -> void:
	var ai := _ai(_on())
	put_battlefield(0, "Millstone")
	assert_eq(ai._mill_rate(g, 0), 0, "nobody mills themselves")
	assert_eq(ai._mill_rate(g, 1), 2)


# --------------------------------------------------------------- the pace --

func test_the_pace_counts_turns_and_not_cards() -> void:
	# Our library 12 against their 30 is a race the CARD count calls lost;
	# with a Millstone of ours on the table their clock is ten turns and
	# ours is twelve, so it is a race we hold by two and may spend down.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		put_battlefield(0, "Millstone")
		_libraries(12, 30)
		if knob:
			assert_eq(ai._library_slack(g), 1,
				"a race held by two turns, one card of it spendable")
		else:
			assert_eq(ai._library_slack(g), 1 << 20,
				"off: 12 minus 30 is negative, so the race reads lost")


func test_the_pace_is_the_expression_it_always_was_with_no_mill() -> void:
	# THE NULL. Every count below is the one `paces_draws` has answered
	# since 2026-09-07, on both arms, because `_mill_rate` is 0.
	for knob in [false, true]:
		for pair in [[20, 12, 7], [10, 10, 1 << 20], [40, 40, 1 << 20],
				[30, 5, 24], [25, 1, 23]]:
			before_each()
			var ai := _ai(_on() if knob else _off())
			_libraries(pair[0], pair[1])
			assert_eq(ai._library_slack(g), pair[2],
				"libraries %d/%d, knob %s" % [pair[0], pair[1], knob])


func test_a_mill_of_theirs_shortens_our_own_pace() -> void:
	# Their Millstone takes our twenty cards to seven turns against their
	# twelve: a race we have already lost, and a lost race is not ours to
	# protect — `paces_draws`' own rule, reached through the rate.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		put_battlefield(1, "Millstone")
		_libraries(20, 12)
		if knob:
			assert_eq(ai._deck_clock(g, 0), 7, "20 over 3")
			assert_eq(ai._library_slack(g), 1 << 20, "seven turns against twelve")
		else:
			assert_eq(ai._library_slack(g), 7, "off: 20 minus 12 minus 1")


# ------------------------------------------------------ the mill activated --

func test_the_millstone_is_bought_at_the_mana_sink() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var stone := put_battlefield(0, "Millstone")
		_lands(0, "Island", 3)
		_libraries(30, 30)
		var main := ai._ability_option(g, stone, 0, AiPlayer.Moment.MAIN)
		var sink := ai._ability_option(g, stone, 0, AiPlayer.Moment.SINK)
		if knob:
			assert_almost_eq(float(main["value"]), 2.70, 0.01,
				"two cards at w_hand, rising with the share they take")
			assert_almost_eq(float(sink["value"]), 3.70, 0.01,
				"plus the point for mana that would otherwise be lost")
			assert_eq(main["targets"][0].player_id, 1)
			# The main phase's bar (3.0) refuses it and the sink's (0.5)
			# takes it: a Millstone is a mana sink, not a play.
			assert_eq(ai._try_activate(g, AiPlayer.Moment.MAIN), "",
				"not worth the mana a spell might want")
			assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK),
				"activated Millstone")
			assert_true(stone.tapped)
		else:
			assert_eq(main, {}, "off: the scorer has no arm for a mill")
			assert_eq(sink, {})
			assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK), "")
			assert_false(stone.tapped)


func test_the_mill_that_decks_them_is_the_game() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var stone := put_battlefield(0, "Millstone")
		_lands(0, "Island", 3)
		_libraries(30, 2)
		advance_to_step(Mtg.Step.MAIN1)
		var option := ai._ability_option(g, stone, 0, AiPlayer.Moment.MAIN)
		if knob:
			assert_almost_eq(float(option["value"]),
				AiPlayer.LETHAL_WORTH - 0.5, 0.01,
				"they draw from nothing at their next draw step, CR 704.5b")
			assert_eq(ai.act(g), "activated Millstone")
			resolve_stack()
			assert_eq(g.players[1].library.size(), 0, "milled out")
		else:
			assert_eq(option, {},
				"off: the mill is the game and the pilot cannot see it")


func test_a_library_beyond_the_horizon_is_not_a_race() -> void:
	# The bound is PACE_HORIZON's own sentence: a game that has not ended
	# in twenty turns of draw steps is not being decided by the libraries.
	# A mill of ONE against a full library is the shape that reaches it.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var synth := CardData.new("Slow Stone", "{2}", Mtg.CardType.ARTIFACT) \
			.activated(ActivatedAbility.new("{2}", true, [MillEffect.new(1)],
				"{2}, {T}: Target player mills a card."))
		var stone := put_synthetic(0, synth)
		_lands(0, "Island", 3)
		_libraries(30, 60)
		if knob:
			assert_eq(ai._deck_clock(g, 1), 30, "60 over 2, beyond the horizon")
		assert_eq(ai._ability_option(g, stone, 0, AiPlayer.Moment.SINK), {},
			"knob %s" % knob)


func test_an_empty_library_has_nothing_left_to_mill() -> void:
	var ai := _ai(_on())
	var stone := put_battlefield(0, "Millstone")
	_lands(0, "Island", 3)
	_libraries(30, 0)
	assert_eq(ai._ability_option(g, stone, 0, AiPlayer.Moment.SINK), {},
		"their draw step has this one")


# --------------------------------------------- the mill on the other side --

func test_the_disenchant_goes_at_the_millstone() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var stone := put_battlefield(1, "Millstone")
		var tome := put_battlefield(1, "Jayemdae Tome")
		_lands(0, "Plains", 2)
		_libraries(6, 30)
		assert_almost_eq(ai._victim_value(g, tome), 4.20, 0.01,
			"the Tome is the same card on both arms")
		if knob:
			assert_almost_eq(ai._victim_value(g, stone), 6.60, 0.01,
				"1.60 printed, 1.00 for the ability, 4.00 for the cards back")
			assert_eq(_disenchant_pick(ai), "Millstone")
		else:
			assert_almost_eq(ai._victim_value(g, stone), 2.60, 0.01)
			assert_eq(_disenchant_pick(ai), "Jayemdae Tome",
				"off: the Vise's malfunction in the other currency")


func test_a_mill_that_decks_us_next_turn_is_worth_the_game() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var stone := put_battlefield(1, "Millstone")
		_libraries(2, 30)
		if knob:
			assert_almost_eq(ai._mill_relief(g, stone), AiPlayer.LETHAL_WORTH,
				0.01, "one more activation and we draw from nothing")
		else:
			assert_eq(ai._mill_relief(g, stone), 0.0)


func test_our_own_millstone_is_not_a_reason_to_destroy_it() -> void:
	var ai := _ai(_on())
	var ours := put_battlefield(0, "Millstone")
	_libraries(6, 30)
	assert_eq(ai._mill_relief(g, ours), 0.0, "the relief is about THEIR board")


func test_a_permanent_that_mills_nobody_is_worth_what_it_was() -> void:
	# THE NULL of the relief: with no mill on the table every price on
	# either side of it is the number it has always been.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var tome := put_battlefield(1, "Jayemdae Tome")
		var ring := put_battlefield(1, "Sol Ring")
		_libraries(6, 30)
		assert_almost_eq(ai._victim_value(g, tome), 4.20, 0.01)
		assert_almost_eq(ai._victim_value(g, ring), 1.00, 0.01)


# ---------------------------------------------- the wheel that hands back --

func test_the_twister_that_hands_a_race_back_is_refused() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		_lands(0, "Island", 6)
		_libraries(40, 3)
		_graveyard(1, 20)
		for _i in 5:
			give_hand(1, "Forest")
		var twist := give_hand(0, "Timetwister")
		var intent := _intent(twist)
		assert_eq(ai._library_after_wheel(g, 1, twist, intent), 21,
			"their 3, plus 5 in hand and 20 in the graveyard, less the 7 dealt")
		var sized := ai._size_and_aim(g, twist, intent, 0, 0)
		if knob:
			assert_eq(sized, {},
				"a win three turns away, handed back for a hand of seven")
		else:
			assert_almost_eq(float(sized["value"]), 11.50, 0.01,
				"off: 4.00 printed and five cards of hand swing")


func test_a_wheel_that_only_deals_cards_out_is_not_refused() -> void:
	# Wheel of Fortune takes the same seven off each library and leaves the
	# race where it found it, so the guard says nothing about it — which is
	# what makes the reading a fact about libraries and not about a name.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		_lands(0, "Mountain", 6)
		_libraries(40, 3)
		_graveyard(1, 20)
		for _i in 5:
			give_hand(1, "Forest")
		var wheel := give_hand(0, "Wheel of Fortune")
		var intent := _intent(wheel)
		assert_eq(ai._library_after_wheel(g, 1, wheel, intent), 0,
			"three cards cannot pay for seven")
		assert_almost_eq(float(ai._size_and_aim(g, wheel, intent, 0, 0)["value"]),
			11.50, 0.01, "knob %s" % knob)


func test_the_twister_is_never_refused_when_we_are_losing_the_race() -> void:
	# The other half of the same fact: a race we are LOSING has nothing to
	# hand back, and the Timetwister is then the card that saves us. The
	# guard is one-directional and this is the direction it must not move.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		_lands(0, "Island", 6)
		_libraries(15, 40)
		_graveyard(0, 20)
		for _i in 5:
			give_hand(1, "Forest")
		var twist := give_hand(0, "Timetwister")
		var intent := _intent(twist)
		assert_false(ai._hands_back_the_race(g, twist, intent))
		assert_almost_eq(float(ai._size_and_aim(g, twist, intent, 0, 0)["value"]),
			11.50, 0.01, "knob %s" % knob)


func test_a_race_beyond_the_horizon_holds_no_wheel() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		_lands(0, "Island", 6)
		_libraries(60, 25)
		_graveyard(1, 20)
		for _i in 5:
			give_hand(1, "Forest")
		var twist := give_hand(0, "Timetwister")
		var intent := _intent(twist)
		assert_false(ai._hands_back_the_race(g, twist, intent),
			"twenty-five turns away: the libraries are deciding nothing")


# ---------------------------------------------------------- the ladder --

func test_the_rung_is_sorcerer_and_wizard() -> void:
	assert_false(AiProfile.apprentice().counts_the_race)
	assert_false(AiProfile.magician().counts_the_race)
	assert_true(AiProfile.sorcerer().counts_the_race)
	assert_true(AiProfile.wizard().counts_the_race)


func test_the_lab_can_name_the_knob() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("counts_the_race=off"), "")
	assert_false(profile.counts_the_race)
	assert_eq(profile.apply_overrides("counts_the_race=on"), "")
	assert_true(profile.counts_the_race)
