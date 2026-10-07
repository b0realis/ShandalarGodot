extends GameTest
## THE WHOLE-GAME CAMPAIGN, fix-ai-c — casting policy (engine/ai/ai_player.gd;
## [member AiProfile.forecasts_tactics]):
##  * w6-5 the library race already lost is no licence to draw the library
##    down to its last card (Braingeyser for 7 of the last 8);
##  * w6-9 the sweeper goes first: no creature cast into our own Wrath of
##    God in the same main phase;
##  * w6-10 Dark Ritual is cast only for a card its mana makes castable AND
##    useful (a Terror with nothing to kill is not one);
##  * w1-5 no second freezer while the freeze is already in force (Stasis);
##  * w1-6 Animate Artifact is never hung on an artifact it animates into a
##    dead 0/0 (our own Mox);
##  * w6-13 Drop of Honey is never cast while a creature of ours is its first
##    meal (the least power on the table);
##  * w2-5 a creature that is sacrificed on arrival unless we discard a card
##    (Balduvian Horde, Thundering Wurm) is never cast with nothing to discard.
## Each with a positive control, a null arm (the gate off) and a
## hidden-information permutation.

var _packs: Array = []


func after_each() -> void:
	g = null
	for id in _packs:
		CardPacks.set_enabled(id, false)
	_packs = []


## Enable [param ids] and rebuild the game under them.
func _with_packs(ids: Array) -> void:
	for id in ids:
		CardPacks.set_enabled(id, true)
		_packs.append(id)
	before_each()


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
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


func _burn_counter(seat: int) -> Array:
	var burned := [0]
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.MANA_BURN and int(e.data.get("player", -1)) == seat:
			burned[0] += int(e.data.get("amount", 0)))
	return burned


## Leave the main phase (so floating mana empties and burns, if it does).
func _leave_main() -> void:
	var guard := 0
	while g.current_step() == Mtg.Step.MAIN1 and not g.game_over and guard < 20:
		_advance_once()
		guard += 1


# ------------------------------------------------- w6-5: the lost race --

func _geyser_board() -> CardInstance:
	while g.players[0].library.size() > 8:
		g.players[0].library.pop_back()
	for i in 9:
		put_battlefield(0, "Island")
	var geyser := give_hand(0, "Braingeyser")
	advance_to_step(Mtg.Step.MAIN1)
	return geyser


func test_a_lost_race_still_keeps_the_library_it_needs() -> void:
	var ai := _ai()
	_geyser_board()
	_play_main(ai)
	gut.p("library %d" % g.players[0].library.size())
	assert_gte(g.players[0].library.size(), 4,
		"no clock of ours on the table: four turns of library are kept (RACE_HORIZON)")


func test_a_race_we_hold_still_draws_for_value() -> void:
	# Control: their library is the short one — the Braingeyser draws.
	var ai := _ai()
	while g.players[1].library.size() > 8:
		g.players[1].library.pop_back()
	for i in 9:
		put_battlefield(0, "Island")
	give_hand(0, "Braingeyser")
	advance_to_step(Mtg.Step.MAIN1)
	var before := g.players[0].library.size()
	_play_main(ai)
	assert_lte(g.players[0].library.size(), before - 5, "the race is ours: the X is the mana's")


func test_null_arm_draws_the_lost_race_to_its_last_card() -> void:
	var ai := _ai(false)
	_geyser_board()
	_play_main(ai)
	assert_eq(g.players[0].library.size(), 1, "gate off: the old unbounded slack")


func test_the_lost_race_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_geyser_board()
		give_hand(1, "Counterspell" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		answers.append([str(_play_main(ai)), g.players[0].library.size()])
	assert_eq(answers[0], answers[1])


# --------------------------------------------- w6-9: the sweeper first --

func _wrath_board(with_wrath := true) -> Array:
	for i in 6:
		put_battlefield(0, "Plains")
	put_battlefield(0, "Erhnam Djinn")
	put_battlefield(1, "Mahamoti Djinn")
	put_battlefield(1, "Phantom Monster")
	put_battlefield(1, "Serra Angel")
	var wrath: CardInstance = give_hand(0, "Wrath of God") if with_wrath else null
	var knight := give_hand(0, "White Knight")
	advance_to_step(Mtg.Step.MAIN1)
	return [wrath, knight]


func test_the_sweeper_goes_before_the_creature_it_would_kill() -> void:
	var ai := _ai()
	var cards := _wrath_board()
	var did := _play_main(ai)
	gut.p(str(did))
	assert_eq(cards[0].zone, Mtg.Zone.GRAVEYARD, "the Wrath is cast")
	assert_eq(cards[1].zone, Mtg.Zone.BATTLEFIELD, "and the Knight after it, alive: %s" % str(did))


func test_with_no_sweeper_the_creature_is_cast() -> void:
	var ai := _ai()
	var cards := _wrath_board(false)
	_play_main(ai)
	assert_eq(cards[1].zone, Mtg.Zone.BATTLEFIELD)


func test_a_sweeper_not_worth_casting_does_not_hold_the_creature() -> void:
	# Only our own Djinn would die: the Wrath is not worth casting, so the
	# Knight is not held for it.
	var ai := _ai()
	for i in 6:
		put_battlefield(0, "Plains")
	put_battlefield(0, "Erhnam Djinn")
	var wrath := give_hand(0, "Wrath of God")
	var knight := give_hand(0, "White Knight")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wrath.zone, Mtg.Zone.HAND)


func test_null_arm_casts_the_creature_into_its_own_wrath() -> void:
	var ai := _ai(false)
	var cards := _wrath_board()
	_play_main(ai)
	assert_eq(cards[0].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD, "gate off: the old order")


func test_the_sweeper_order_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_wrath_board()
		give_hand(1, "Counterspell" if variant == 0 else "Giant Growth")
		if variant == 1: g.players[1].library.reverse()
		answers.append(str(_play_main(ai)))
	assert_eq(answers[0], answers[1])


# ------------------------------------------------ w6-10: the Ritual's use --

func test_no_ritual_for_a_terror_with_nothing_to_kill() -> void:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai()
	put_battlefield(0, "Swamp")
	var ritual := give_hand(0, "Dark Ritual")
	give_hand(0, "Terror")
	var burned := _burn_counter(0)
	advance_to_step(Mtg.Step.MAIN1)
	var did := _play_main(ai)
	_leave_main()
	assert_eq(ritual.zone, Mtg.Zone.HAND, "nothing for the BBB to do: %s" % str(did))
	assert_eq(burned[0], 0)


func test_the_ritual_still_casts_what_it_enables() -> void:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai()
	put_battlefield(0, "Swamp")
	var ritual := give_hand(0, "Dark Ritual")
	var specter := give_hand(0, "Hypnotic Specter")
	var burned := _burn_counter(0)
	advance_to_step(Mtg.Step.MAIN1)
	var did := _play_main(ai)
	_leave_main()
	assert_eq(ritual.zone, Mtg.Zone.GRAVEYARD, str(did))
	assert_eq(specter.zone, Mtg.Zone.BATTLEFIELD, str(did))
	assert_eq(burned[0], 0)


func test_null_arm_rituals_into_the_burn() -> void:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai(false)
	put_battlefield(0, "Swamp")
	var ritual := give_hand(0, "Dark Ritual")
	give_hand(0, "Terror")
	var burned := _burn_counter(0)
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	_leave_main()
	assert_eq(ritual.zone, Mtg.Zone.GRAVEYARD, "gate off: the old arithmetic")
	assert_eq(burned[0], 3)


## The hunter's duel board (w6-10, b2 seed 2156): Mishra's Factory
## animated, then the Ritual "for" a Contagion with no creature to hit.
func test_the_duel_board_burns_nothing() -> void:
	_with_packs(["pack-3", "pack-4", "pack-5"])
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai()
	g.players[0].life = 11
	g.players[1].life = 18
	for n in ["Swamp", "Swamp", "Lava Tubes", "Strip Mine", "Mishra's Factory", "Nevinyrral's Disk"]:
		put_battlefield(0, n)
	for n in ["Mountain", "Mountain", "Plains", "Mishra's Factory"]:
		put_battlefield(1, n)
	for n in ["Dark Ritual", "Contagion", "Drain Life", "Ihsan's Shade", "Fireball"]:
		give_hand(0, n)
	var burned := _burn_counter(0)
	advance_to_step(Mtg.Step.MAIN1)
	var guard := 0
	while g.turn_number == 1 and not g.game_over and guard < 60:
		if g.awaiting_attackers or g.awaiting_blockers or g.priority_player == 0:
			var a := ai.act(g)
			if a == "" and not (g.awaiting_attackers or g.awaiting_blockers):
				g.pass_priority(g.priority_player)
		else:
			g.pass_priority(g.priority_player)
		guard += 1
	assert_eq(burned[0], 0)


func test_the_ritual_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Swamp")
		give_hand(0, "Dark Ritual")
		give_hand(0, "Terror")
		give_hand(1, "Grizzly Bears" if variant == 0 else "Counterspell")
		if variant == 1: g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(str(_play_main(ai)))
	assert_eq(answers[0], answers[1])


# ------------------------------------------------ w1-5: the second freeze --

func _stasis_board() -> void:
	for i in 6:
		put_battlefield(0, "Island")
	for i in 4:
		put_battlefield(1, "Plains").tapped = true
	put_battlefield(1, "Grizzly Bears").tapped = true


func _stasis_count() -> int:
	var n := 0
	for seat in 2:
		for inst in g.players[seat].battlefield:
			if inst.data.card_name == "Stasis":
				n += 1
	return n


func test_no_second_stasis_beside_our_own() -> void:
	var ai := _ai()
	_stasis_board()
	put_battlefield(0, "Stasis")
	var second := give_hand(0, "Stasis")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai._arrival_refused(g, second))
	var did := _play_main(ai)
	assert_eq(second.zone, Mtg.Zone.HAND, "the second only doubles the rent: %s" % str(did))
	assert_eq(_stasis_count(), 1)


func test_the_first_stasis_is_not_refused_by_the_freeze_reading() -> void:
	var ai := _ai()
	_stasis_board()
	var first := give_hand(0, "Stasis")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(ai._freeze_in_force(g, first.data))
	assert_false(ai._arrival_refused(g, first))


func test_no_stasis_while_theirs_already_freezes_the_table() -> void:
	var ai := _ai()
	_stasis_board()
	put_battlefield(1, "Stasis")
	var mine := give_hand(0, "Stasis")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai._freeze_in_force(g, mine.data))
	_play_main(ai)
	assert_eq(mine.zone, Mtg.Zone.HAND, "their Stasis already freezes every untap step")


func test_null_arm_casts_the_second_stasis() -> void:
	var ai := _ai(false)
	_stasis_board()
	put_battlefield(0, "Stasis")
	give_hand(0, "Stasis")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_eq(_stasis_count(), 2, "gate off: the old double rent")


func test_the_freeze_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_stasis_board()
		put_battlefield(0, "Stasis")
		give_hand(0, "Stasis")
		give_hand(1, "Disenchant" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(str(_play_main(ai)))
	assert_eq(answers[0], answers[1])


# ------------------------------------------ w1-6: the 0/0 Animate Artifact --

func test_animate_artifact_is_not_hung_on_our_own_mox() -> void:
	var ai := _ai()
	for i in 4:
		put_battlefield(0, "Island")
	var mox := put_battlefield(0, "Mox Sapphire")
	give_hand(0, "Animate Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	g.check_state_based_actions()
	assert_eq(mox.zone, Mtg.Zone.BATTLEFIELD, "a mana value 0 artifact animates into a dead 0/0")


func test_animate_artifact_still_animates_a_real_body() -> void:
	var ai := _ai()
	for i in 4:
		put_battlefield(0, "Island")
	var mox := put_battlefield(0, "Mox Sapphire")
	var icy := put_battlefield(0, "Icy Manipulator")
	var aura := give_hand(0, "Animate Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	g.check_state_based_actions()
	assert_eq(mox.zone, Mtg.Zone.BATTLEFIELD)
	if aura.zone == Mtg.Zone.BATTLEFIELD:
		assert_eq(aura.attached_to, icy.id, "the Icy is the 4/4 worth making")


func test_null_arm_animates_the_mox_to_death() -> void:
	var ai := _ai(false)
	for i in 4:
		put_battlefield(0, "Island")
	var mox := put_battlefield(0, "Mox Sapphire")
	give_hand(0, "Animate Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	g.check_state_based_actions()
	assert_eq(mox.zone, Mtg.Zone.GRAVEYARD, "gate off: the old pick")


func test_the_animate_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		for i in 4:
			put_battlefield(0, "Island")
		put_battlefield(0, "Mox Sapphire")
		give_hand(0, "Animate Artifact")
		give_hand(1, "Shatter" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(str(_play_main(ai)))
	assert_eq(answers[0], answers[1])


# ----------------------------------------------- w6-13: the Drop of Honey --

func test_drop_of_honey_is_not_cast_while_ours_is_the_least_power() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Grizzly Bears")
	var drop := give_hand(0, "Drop of Honey")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_eq(drop.zone, Mtg.Zone.HAND, "its first upkeep would eat our own Elves")


func test_drop_of_honey_is_cast_when_theirs_is_the_least_power() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Llanowar Elves")
	var drop := give_hand(0, "Drop of Honey")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_eq(drop.zone, Mtg.Zone.BATTLEFIELD, "their Elves are the first meal")


func test_drop_of_honey_on_a_tie_eats_theirs() -> void:
	# Tied for least power, the choice is the Drop's controller's (ours).
	var ai := _ai()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Llanowar Elves")
	var drop := give_hand(0, "Drop of Honey")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_eq(drop.zone, Mtg.Zone.BATTLEFIELD)


func test_their_drop_of_honey_is_read_as_an_upkeep_meal() -> void:
	# The appetite reader: their Drop eats the least power on the table at
	# their upkeep — their Elves, not our Bears.
	var ai := _ai()
	put_battlefield(1, "Drop of Honey")
	var elves := put_battlefield(1, "Llanowar Elves")
	put_battlefield(0, "Grizzly Bears")
	var board: Array[CardInstance] = []
	for inst in g.all_battlefield():
		board.append(inst)
	var eaten: Array = ai._upkeep_meals(g, 1, board)
	assert_true(eaten.has(elves), str(eaten))


func test_null_arm_casts_the_drop_into_our_own_board() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Grizzly Bears")
	var drop := give_hand(0, "Drop of Honey")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_eq(drop.zone, Mtg.Zone.BATTLEFIELD, "gate off: the old cast")


func test_the_drop_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Forest")
		put_battlefield(0, "Forest")
		put_battlefield(0, "Llanowar Elves")
		put_battlefield(1, "Grizzly Bears")
		give_hand(0, "Drop of Honey")
		give_hand(1, "Llanowar Elves" if variant == 0 else "Giant Growth")
		if variant == 1: g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(str(_play_main(ai)))
	assert_eq(answers[0], answers[1])


# ----------------------------------------- w2-5: the discard-or-sacrifice --

func test_no_horde_into_an_empty_hand() -> void:
	_with_packs(["pack-5"])
	var ai := _ai()
	for n in 4: put_battlefield(0, "Mountain")
	var horde := give_hand(0, "Balduvian Horde")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_eq(horde.zone, Mtg.Zone.HAND, "it would be sacrificed with nothing to discard")


func test_the_horde_is_cast_with_a_card_to_discard() -> void:
	_with_packs(["pack-5"])
	var ai := _ai()
	for n in 4: put_battlefield(0, "Mountain")
	var horde := give_hand(0, "Balduvian Horde")
	give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_eq(horde.zone, Mtg.Zone.BATTLEFIELD)


func test_no_thundering_wurm_without_a_land_card_to_discard() -> void:
	_with_packs(["pack-6"])
	var ai := _ai()
	for n in 3: put_battlefield(0, "Forest")
	var wurm := give_hand(0, "Thundering Wurm")
	give_hand(0, "Grizzly Bears")   # a card, but not a land card
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_ne(wurm.zone, Mtg.Zone.GRAVEYARD, "a land card is what keeps it")


func test_null_arm_casts_the_horde_into_an_empty_hand() -> void:
	_with_packs(["pack-5"])
	var ai := _ai(false)
	for n in 4: put_battlefield(0, "Mountain")
	var horde := give_hand(0, "Balduvian Horde")
	advance_to_step(Mtg.Step.MAIN1)
	_play_main(ai)
	assert_eq(horde.zone, Mtg.Zone.GRAVEYARD, "gate off: cast and sacrificed")


func test_the_horde_answer_ignores_their_hidden_cards() -> void:
	_with_packs(["pack-5"])
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		for n in 4: put_battlefield(0, "Mountain")
		give_hand(0, "Balduvian Horde")
		give_hand(1, "Lightning Bolt" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(str(_play_main(ai)))
	assert_eq(answers[0], answers[1])

