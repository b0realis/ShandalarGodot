extends GameTest
## THE COUNTER RESERVE, PAYABLE AND UNDER PRESSURE (robustness campaign
## 2026-10-12, b5-1 and b5-2; [member AiProfile.forecasts_tactics]).
##
## [method AiPlayer._held_reserve] booked [member AiProfile.counter_threshold]
## for any counterspell in hand, and the main-phase gate of [method
## AiPlayer._try_cast_best] held a cheap creature whenever a counter was in
## hand and the plan left fewer than two blue sources. Neither asked whether
## the counter could be PAID tonight: Blue Skies held Merfolk of the Pearl
## Trident behind a Counterspell on one Island for three turns, the Humility
## deck a Wall of Tears behind Dismiss on two lands. And neither looked at
## the board: a deck at 6 life in front of two Hill Giants kept {U}{U} open
## for a spell that might never come instead of casting the blocker.
##
## Now a counter books mana only when the lasting sources (not mana floating
## in the pool, which empties before their turn) can pay it, the gate asks
## whether the CHEAPEST payable counter can still be paid after the plan,
## and the reserve is dropped while their board puts us on the panic line
## ([method AiPlayer._board_pressure]). Gate off: the old reading. The opponent's
## hidden hand never moves the answer.


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## Our first main phase, the AI at seat 0 acting until it passes.
func _play_main(ai: AiPlayer) -> Array:
	var lines: Array = []
	var turn := g.turn_number
	for k in 12:
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


## Our whole turn: the AI at seat 0, a passive seat 1 (no blocks, passes).
func _play_turn(ai: AiPlayer) -> Array:
	var lines: Array = []
	var turn := g.turn_number
	for k in 200:
		if g.game_over or g.turn_number != turn:
			break
		if g.awaiting_attackers and g.active_player == 0:
			lines.append(ai.act(g))
		elif g.awaiting_blockers:
			if g.block_chooser() == 0: lines.append(ai.act(g))
			else: g.declare_blockers(1, {})
		elif g.priority_player == 0:
			var did := ai.act(g)
			if did != "pass": lines.append(did)
		else:
			g.pass_priority(g.priority_player)
	return lines


func _hand(seat: int, names: Array) -> Array:
	var out: Array = []
	for n in names:
		out.append(give_hand(seat, n))
	return out


# ------------------------------------------------------------- b5-1 --


## Island, Mountain, Mountain: Counterspell's {U}{U} cannot be paid, so it
## keeps nothing open, and the Gray Ogre is cast.
func _ogre_board(on: bool, preset: String, their_hand: Array = []) -> Dictionary:
	before_each()
	g.rules.set_preset(preset)
	var ai := _ai(on)
	put_battlefield(0, "Island")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var counter := give_hand(0, "Counterspell")
	var ogre := give_hand(0, "Gray Ogre")
	_hand(1, their_hand)
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(g.could_afford(0, counter.data, {}, counter),
		"precondition: {U}{U} is not payable from one Island")
	var reserve := ai._held_reserve(g)
	var lines := _play_main(ai)
	return {"lines": lines, "cast": ogre.zone == Mtg.Zone.BATTLEFIELD, "reserve": reserve}


func test_an_unpayable_counterspell_does_not_hold_back_the_creature() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		var on := _ogre_board(true, preset)
		assert_true(on["cast"], "%s: the Ogre is cast: %s" % [preset, on["lines"]])
		assert_true(Dictionary(on["reserve"]).is_empty(),
			"%s: an unpayable counter books nothing" % preset)
		var off := _ogre_board(false, preset)
		assert_false(off["cast"], "%s, gate off: the old hold (%s)" % [preset, off["lines"]])
		assert_false(Dictionary(off["reserve"]).is_empty(), "%s, gate off: the old booking" % preset)


func test_their_hidden_hand_does_not_move_the_answer() -> void:
	var seen: Array = []
	for their_hand in [[], ["Counterspell", "Shivan Dragon"], ["Lightning Bolt", "Lightning Bolt", "Fireball"]]:
		seen.append(_ogre_board(true, "modern_mana_burn", their_hand)["lines"])
	assert_eq(seen[1], seen[0], "a hidden Counterspell and Dragon changed the play")
	assert_eq(seen[2], seen[0], "a hidden burn hand changed the play")


func test_one_island_casts_the_merfolk() -> void:
	# The Blue Skies opening: one Island, Merfolk of the Pearl Trident and
	# Counterspell in hand. The Merfolk used to wait turns 1, 3 and 5.
	var ai := _ai()
	put_battlefield(0, "Island")
	var merfolk := give_hand(0, "Merfolk of the Pearl Trident")
	give_hand(0, "Counterspell")
	advance_to_step(Mtg.Step.MAIN1)
	var lines := _play_main(ai)
	assert_eq(merfolk.zone, Mtg.Zone.BATTLEFIELD, "{U}{U} cannot be paid from one Island: %s" % [lines])


func test_two_lands_cast_the_wall_behind_dismiss() -> void:
	# Tempest: Dismiss is {2}{U}{U}; two Islands cannot pay it.
	var ai := _ai()
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var dismiss := give_hand(0, "Dismiss")
	var wall := give_hand(0, "Wall of Tears")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(g.could_afford(0, dismiss.data, {}, dismiss), "precondition")
	var lines := _play_main(ai)
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "Dismiss cannot be paid tonight: %s" % [lines])


func test_a_payable_counter_is_still_held_for_a_marginal_creature() -> void:
	# The design the fix keeps: with {U}{U} open, a Gray Ogre that would
	# tap the counter out waits (the 1.5x rule).
	var ai := _ai()
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(0, "Mountain")
	give_hand(0, "Counterspell")
	var ogre := give_hand(0, "Gray Ogre")
	advance_to_step(Mtg.Step.MAIN1)
	var reserve := ai._held_reserve(g)
	assert_false(reserve.is_empty(), "a payable Counterspell books its mana")
	var lines := _play_main(ai)
	assert_eq(ogre.zone, Mtg.Zone.HAND, "the counter mana stays open: %s" % [lines])


func test_the_spare_island_reading_stays() -> void:
	# Four Forests and two Islands: Bears paid with Forests leaves {U}{U}.
	var ai := _ai()
	for i in 4: put_battlefield(0, "Forest")
	for i in 2: put_battlefield(0, "Island")
	give_hand(0, "Counterspell")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var lines := _play_main(ai)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the Bears leave the Counterspell payable: %s" % [lines])


func test_the_gate_reads_the_cheapest_payable_counter_not_two_blue() -> void:
	# Island and four Mountains, Remove Soul ({1}{U}) and a Gray Ogre: the
	# Ogre taps three Mountains, the Island and a Mountain still pay the
	# Soul. The old gate wanted two BLUE sources left and held the Ogre.
	var cast: Array = []
	for on in [true, false]:
		before_each()
		var ai := _ai(on)
		put_battlefield(0, "Island")
		for i in 4: put_battlefield(0, "Mountain")
		var soul := give_hand(0, "Remove Soul")
		var ogre := give_hand(0, "Gray Ogre")
		advance_to_step(Mtg.Step.MAIN1)
		var lines := _play_main(ai)
		gut.p("on=%s: %s" % [on, lines])
		cast.append(ogre.zone == Mtg.Zone.BATTLEFIELD)
		if on:
			assert_true(g.could_afford(0, soul.data, {}, soul),
				"the Ogre was paid around the Island: Remove Soul stays payable")
	assert_true(cast[0], "Remove Soul is still payable after the Ogre")
	assert_false(cast[1], "gate off: the old two-blue hold")


func test_floating_mana_is_not_a_reserve() -> void:
	# {U}{U} floating with one Island on the table: the pool empties at the
	# end of the step, so it cannot keep a Counterspell for their turn.
	var ai := _ai()
	put_battlefield(0, "Island")
	give_hand(0, "Counterspell")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_true(ai._held_reserve(g).is_empty(), "floating mana books no counter")


# ------------------------------------------------------------- b5-2 --


## 6 life, two Hill Giants across the table, Island Island Forest: the
## board is lethal next turn whatever is cast; the counter answers a spell
## that may never come.
func _giants_board(on: bool, life: int, preset := "modern_mana_burn",
		their_hand: Array = []) -> Dictionary:
	before_each()
	g.rules.set_preset(preset)
	var ai := _ai(on)
	g.players[0].life = life
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(0, "Forest")
	give_hand(0, "Counterspell")
	var bears := give_hand(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Hill Giant")
	_hand(1, their_hand)
	advance_to_step(Mtg.Step.MAIN1)
	var lines := _play_main(ai)
	return {"lines": lines, "cast": bears.zone == Mtg.Zone.BATTLEFIELD}


func test_a_lethal_board_drops_the_counter_reserve() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		var on := _giants_board(true, 6, preset)
		assert_true(on["cast"], "%s: 6 life v 6 power, the blocker is cast: %s" % [preset, on["lines"]])
		var off := _giants_board(false, 6, preset)
		assert_false(off["cast"], "%s, gate off: the old hold (%s)" % [preset, off["lines"]])


func test_no_pressure_keeps_the_counter_reserve() -> void:
	var calm := _giants_board(true, 20)
	assert_false(calm["cast"], "20 life v two Hill Giants: the counter mana stays open (%s)" % [calm["lines"]])


func test_low_life_with_no_creature_across_keeps_the_counter() -> void:
	# The panic line is asked of their CREATURES: at 4 life facing only
	# open Mountains, the Counterspell is the answer to the burn spell that
	# would end the game, and its mana stays open.
	var ai := _ai()
	g.players[0].life = 4
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(0, "Forest")
	give_hand(0, "Counterspell")
	var bears := give_hand(0, "Grizzly Bears")
	for i in 3: put_battlefield(1, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(ai._board_pressure(g), "no creature across the table")
	var lines := _play_main(ai)
	assert_eq(bears.zone, Mtg.Zone.HAND, "the counter mana stays open (%s)" % [lines])


func test_pressure_reading_ignores_their_hidden_hand() -> void:
	var seen: Array = []
	for their_hand in [[], ["Giant Growth", "Lightning Bolt"], ["Counterspell"]]:
		seen.append(_giants_board(true, 6, "modern_mana_burn", their_hand)["lines"])
	assert_eq(seen[1], seen[0], "hidden tricks changed the play")
	assert_eq(seen[2], seen[0], "a hidden counter changed the play")


func test_the_jamuraa_position_casts_a_creature() -> void:
	# The Lab position (p8_flash v p8_jamuraa, seed 81150, turn 14): 11
	# life, 4 Forests + 2 Islands, Warping Wurm, Striped Bears, Ophidian
	# and Dissipate in hand; two Stalking Tigers swinging each turn. It cast
	# nothing on turns 14 and 16 and died on turn 18.
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.forecasts_tactics = true
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	g.players[0].life = 11
	for i in 4: put_battlefield(0, "Forest")
	for i in 2: put_battlefield(0, "Island")
	var hand := _hand(0, ["Warping Wurm", "Striped Bears", "Ophidian", "Dissipate"])
	put_battlefield(1, "Stalking Tiger")
	put_battlefield(1, "Stalking Tiger")
	put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	var lines := _play_turn(ai)
	var cast := 0
	for c in hand:
		if c.zone == Mtg.Zone.BATTLEFIELD: cast += 1
	assert_gt(cast, 0, "11 life v 7 power with 6 mana: some creature is cast (%s)" % [lines])
