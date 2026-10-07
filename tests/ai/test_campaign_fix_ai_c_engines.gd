extends GameTest
## THE WHOLE-GAME CAMPAIGN, fix-ai-c — engines that cost more than they
## give (engine/ai/ai_player.gd; [member AiProfile.forecasts_tactics]):
##  * Pestilence (w3, seen in soak seed 1074): no second copy beside the
##    first, and no activation that empties the battlefield — the end step
##    then sacrifices every Pestilence ([method AiPlayer._empty_board_toll]);
##  * Varchild's War-Riders (w3, audit seed 31000): the cumulative upkeep
##    paid in Survivors for the opponent is paid only while the Riders'
##    power is more than the bodies handed over;
##  * w6-1 the mana a cast's taps leave floating is priced, not only the
##    burn that is our last life ([method AiPlayer._burn_price]);
##  * w6-15 a wheel that moves no card (Timetwister between equal hands)
##    is never cast — the Black Lotus/Timetwister loop ran 190 casts in one
##    main phase.
## Each with a positive control, a null arm (the gate off) and a
## hidden-information permutation.

var _packs: Array = []


func after_each() -> void:
	g = null
	for id in _packs:
		CardPacks.set_enabled(id, false)
	_packs = []


func _with_packs(ids: Array) -> void:
	for id in ids:
		CardPacks.set_enabled(id, true)
		_packs.append(id)
	before_each()


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _play_main(ai: AiPlayer, rounds := 12) -> Array:
	var lines: Array = []
	var turn := g.turn_number
	for k in rounds:
		if g.game_over or g.turn_number != turn or g.current_step() != Mtg.Step.MAIN1:
			break
		if g.priority_player == 0:
			var did := ai.act(g)
			lines.append(did)
			if did == "" or did == "pass":
				break
		else:
			g.pass_priority(g.priority_player)
		resolve_stack()
	return lines


func _count(seat: int, card_name: String) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.data.card_name == card_name:
			n += 1
	return n


# ------------------------------------------------------ Pestilence: copies --

func test_no_second_pestilence_beside_the_first() -> void:
	var ai := _ai()
	for k in 4: put_battlefield(0, "Swamp")
	put_battlefield(0, "Pestilence")
	put_battlefield(1, "Grizzly Bears")
	var second := give_hand(0, "Pestilence")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai._arrival_refused(g, second))
	_play_main(ai)
	assert_eq(second.zone, Mtg.Zone.HAND, "one Pestilence already repeats every activation")


func test_the_first_pestilence_is_not_refused() -> void:
	var ai := _ai()
	for k in 4: put_battlefield(0, "Swamp")
	put_battlefield(1, "Grizzly Bears")
	var first := give_hand(0, "Pestilence")
	assert_false(ai._arrival_refused(g, first))


func test_a_tapping_engine_copy_is_not_refused() -> void:
	# A {T} ability is once a turn per copy: a second one is a second
	# activation, not a repeat (Prodigal-style engines, Icy Manipulator).
	var ai := _ai()
	put_battlefield(0, "Icy Manipulator")
	var second := give_hand(0, "Icy Manipulator")
	assert_false(ai._arrival_refused(g, second))


func test_null_arm_does_not_refuse_the_second_pestilence() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Pestilence")
	var second := give_hand(0, "Pestilence")
	assert_false(ai._arrival_refused(g, second))


# ------------------------------------------------ Pestilence: the empty board --

func _pestilence_effect() -> EffectBase:
	return CardRegistry.get_card("Pestilence").activated_abilities[0].effects[0]


func test_a_sweep_that_empties_the_board_pays_for_every_pestilence() -> void:
	var on := _ai()
	for k in 3: put_battlefield(0, "Pestilence")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Llanowar Elves")
	var effect := _pestilence_effect()
	var with_toll: float = on._sweep_value(g, effect, 0)
	var off := _ai(false)
	var without: float = off._sweep_value(g, effect, 0)
	assert_lt(with_toll, without - 3.0, "three Pestilences are sacrificed at the end step")


func test_a_sweep_that_leaves_a_creature_pays_nothing() -> void:
	var on := _ai()
	for k in 3: put_battlefield(0, "Pestilence")
	put_battlefield(0, "Grizzly Bears")   # survives one point
	put_battlefield(1, "Llanowar Elves")
	var effect := _pestilence_effect()
	var off := _ai(false)
	var without: float = off._sweep_value(g, effect, 0)
	g.set_agent(0, on)
	assert_eq(on._sweep_value(g, effect, 0), without)


## The soak's shape (seed 1074): their attack, our creature that cannot
## block, three Pestilences and the mana for two activations. The second
## would take their last creature and ours — and all three Pestilences.
func _their_attack_into_pestilence(ai: AiPlayer) -> Array:
	for k in 3: put_battlefield(0, "Pestilence")
	for k in 4: put_battlefield(0, "Swamp")
	var ours := put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 9
	var bears := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	ours.tapped = true   # it attacked last turn: no block
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bears.id, elves.id]))
	# Through their turn and ours: a board emptied in their end step costs
	# the Pestilences at OUR end step.
	var guard := 0
	while g.turn_number <= 3 and not g.game_over and guard < 300:
		if g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		elif g.awaiting_attackers:
			if g.active_player == 0:
				ai.act(g)
			else:
				assert_ok(g.declare_attackers(1, []))
		elif g.priority_player == 0:
			var did := ai.act(g)
			if did == "":
				g.pass_priority(0)
			elif did != "pass":
				gut.p("act: %s" % did)
		else:
			g.pass_priority(g.priority_player)
		guard += 1
	return [ours]


func test_no_pestilence_activation_that_empties_the_board() -> void:
	var ai := _ai()
	var r := _their_attack_into_pestilence(ai)
	assert_eq(r[0].zone, Mtg.Zone.BATTLEFIELD, "our Bears are not swept with their last creature")
	assert_eq(_count(0, "Pestilence"), 3, "and the Pestilences outlive the end step")


func test_null_arm_empties_the_board() -> void:
	var ai := _ai(false)
	_their_attack_into_pestilence(ai)
	assert_eq(_count(0, "Pestilence"), 0, "gate off: the old activation, all three sacrificed")


func test_the_pestilence_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		give_hand(1, "Giant Growth" if variant == 0 else "Counterspell")
		if variant == 1: g.players[1].library.reverse()
		var r := _their_attack_into_pestilence(ai)
		answers.append([r[0].zone, _count(0, "Pestilence")])
	assert_eq(answers[0], answers[1])


# -------------------------------------------- Varchild's War-Riders: upkeep --

## Our War-Riders, aged [param age] already, at our next upkeep.
func _riders_upkeep(ai: AiPlayer, age: int) -> CardInstance:
	advance_to_step(Mtg.Step.MAIN1)   # past our first upkeep
	var riders := put_battlefield(0, "Varchild's War-Riders")
	if age > 0:
		riders.counters["age"] = age
	advance_to_next_turn()
	advance_to_next_turn()   # our next turn: the upkeep has been paid or not
	assert_eq(g.active_player, 0)
	return riders


func test_the_riders_upkeep_is_not_paid_in_three_survivors() -> void:
	_with_packs(["pack-5"])
	var ai := _ai()
	var riders := _riders_upkeep(ai, 2)
	assert_eq(riders.zone, Mtg.Zone.GRAVEYARD, "three Survivors for a 3-power body")
	assert_eq(_count(1, "Survivor"), 0)


func test_the_riders_first_upkeep_is_paid() -> void:
	_with_packs(["pack-5"])
	var ai := _ai()
	var riders := _riders_upkeep(ai, 0)
	assert_eq(riders.zone, Mtg.Zone.BATTLEFIELD, "one Survivor for a 3/4 trampler")
	assert_eq(_count(1, "Survivor"), 1)


func test_null_arm_pays_three_survivors() -> void:
	_with_packs(["pack-5"])
	var ai := _ai(false)
	var riders := _riders_upkeep(ai, 2)
	assert_eq(riders.zone, Mtg.Zone.BATTLEFIELD, "gate off: the hint's three")
	assert_eq(_count(1, "Survivor"), 3)


func test_the_riders_answer_ignores_their_hidden_cards() -> void:
	_with_packs(["pack-5"])
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		give_hand(1, "Lightning Bolt" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		var riders := _riders_upkeep(ai, 1)
		answers.append([riders.zone, _count(1, "Survivor")])
	assert_eq(answers[0], answers[1])


# ------------------------------------------------ w6-1: the burn, priced --

func test_the_burn_a_plan_leaves_is_priced() -> void:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai()
	var ring := put_battlefield(0, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	var sources: Array = ai._mana_sources(g)
	var plan: Array = ai._plan_taps_from(sources, ManaCost.parse("{1}"), 0)
	assert_false(plan.is_empty())
	assert_eq(ai._burn_price(g, sources, plan, 1), 1.0 * ai._life_price(20),
		"a Sol Ring for a {1}: one floats and burns")
	var two: Array = ai._plan_taps_from(sources, ManaCost.parse("{2}"), 0)
	assert_eq(ai._burn_price(g, sources, two, 2), 0.0, "for a {2}: nothing floats")
	g.rules.set_preset("modern")
	assert_eq(ai._burn_price(g, sources, plan, 1), 0.0, "no mana burn: nothing to price")


func test_null_arm_prices_no_burn() -> void:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai(false)
	put_battlefield(0, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	var sources: Array = ai._mana_sources(g)
	var plan: Array = ai._plan_taps_from(sources, ManaCost.parse("{1}"), 0)
	assert_eq(ai._burn_price(g, sources, plan, 1), 0.0)


func test_at_low_life_the_one_drop_off_a_sol_ring_waits_for_the_two_drop() -> void:
	# A Sol Ring and two artifacts: the {2} spends both, the {1} burns one.
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai()
	g.players[0].life = 3
	put_battlefield(0, "Sol Ring")
	var mine := give_hand(0, "Millstone")    # {2}
	give_hand(0, "Black Vise")               # {1}
	var burned := [0]
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.MANA_BURN and int(e.data.get("player", -1)) == 0:
			burned[0] += int(e.data.get("amount", 0)))
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	while g.current_step() == Mtg.Step.MAIN1 and not g.game_over:
		_advance_once()
	assert_eq(burned[0], 0, "no life burned at three")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


func test_the_burn_price_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		g.rules.set_preset("modern_mana_burn")
		var ai := _ai()
		g.players[0].life = 3
		put_battlefield(0, "Sol Ring")
		give_hand(0, "Millstone")
		give_hand(0, "Black Vise")
		give_hand(1, "Lightning Bolt" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(str(_play_main(ai)))
	assert_eq(answers[0], answers[1])


# ------------------------------------- the tap toll (fix-mana handover) --

## Two Forests, one wearing THEIR Psychic Venom: a Grizzly Bears needs both,
## and the Venomed tap deals us 2.
func _venomed_bears(life: int, on := true) -> CardInstance:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai(on)
	g.players[0].life = life
	var cursed := put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	g.attach_aura_from_anywhere(_make_instance(1, "Psychic Venom"), cursed, 1)
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	return bears


func test_a_tolled_tap_that_is_our_last_life_is_never_paid() -> void:
	var bears := _venomed_bears(2)
	assert_eq(bears.zone, Mtg.Zone.HAND, "the Venom's two is the game")
	assert_false(g.game_over)


func test_a_tolled_tap_we_can_afford_is_a_price() -> void:
	var bears := _venomed_bears(20)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "two life at twenty for the Bears")
	assert_eq(g.players[0].life, 18)


func test_the_toll_is_read_off_the_aura() -> void:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai()
	g.players[0].life = 10
	var cursed := put_battlefield(0, "Forest")
	g.attach_aura_from_anywhere(_make_instance(1, "Psychic Venom"), cursed, 1)
	advance_to_step(Mtg.Step.MAIN1)
	var sources: Array = ai._mana_sources(g)
	var plan: Array = ai._plan_taps_from(sources, ManaCost.parse("{G}"), 0)
	assert_eq(ai._tap_toll_price(g, sources, plan), 2.0 * ai._life_price(10))
	ai.profile.forecasts_tactics = false
	assert_eq(ai._tap_toll_price(g, sources, plan), 0.0, "null arm: unpriced")


func test_null_arm_pays_the_venom_with_our_last_life() -> void:
	_venomed_bears(2, false)
	assert_true(g.game_over, "gate off: the Bears, and the Venom's two at two life")


func test_the_toll_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		give_hand(1, "Lightning Bolt" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		answers.append(_venomed_bears(2).zone)
	assert_eq(answers[0], answers[1])


# ------------------------------------------------ w6-15: the empty wheel --

func _wheel_board(theirs: int, ours: int) -> CardInstance:
	for k in 3: put_battlefield(0, "Island")
	var twister := give_hand(0, "Timetwister")
	for k in ours: give_hand(0, "Grizzly Bears")
	for k in theirs: give_hand(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	return twister


func test_no_timetwister_between_equal_hands() -> void:
	var ai := _ai()
	var twister := _wheel_board(6, 6)
	_play_main(ai)
	assert_eq(twister.zone, Mtg.Zone.HAND, "seven for seven: nothing moves but the card")


func test_the_timetwister_that_refills_our_hand_is_cast() -> void:
	var ai := _ai()
	var twister := _wheel_board(7, 1)
	_play_main(ai)
	assert_ne(twister.zone, Mtg.Zone.HAND, "six cards our way")


func test_one_wheel_a_turn() -> void:
	# The harness's loop (seed 3000, deck 259): Black Lotus into Timetwister,
	# the Lotus shuffled back and redrawn — each re-deal read as a swing of
	# the cards just spent. After one wheel this turn, no second.
	var ai := _ai()
	var twister := _wheel_board(7, 1)
	_play_main(ai, 1)
	assert_ne(twister.zone, Mtg.Zone.HAND)
	assert_eq(ai._wheel_turn, AiPlayer._turn_key(g), "the cast is remembered for the turn")
	before_each()
	ai = _ai()
	var again := _wheel_board(7, 1)
	ai._wheel_turn = AiPlayer._turn_key(g)
	_play_main(ai)
	assert_eq(again.zone, Mtg.Zone.HAND, "a second wheel this turn only re-deals the first's hands")


func test_null_arm_casts_the_empty_wheel() -> void:
	var ai := _ai(false)
	var twister := _wheel_board(6, 6)
	_play_main(ai)
	assert_ne(twister.zone, Mtg.Zone.HAND, "gate off: the old zero-swing cast")


func test_the_wheel_answer_reads_hand_sizes_not_hand_contents() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		var twister := _wheel_board(6, 6)
		if variant == 1:
			for card in g.players[1].hand:
				card.data = CardRegistry.get_card("Counterspell")
			g.players[1].library.reverse()
		_play_main(ai)
		answers.append(twister.zone)
	assert_eq(answers[0], answers[1])
