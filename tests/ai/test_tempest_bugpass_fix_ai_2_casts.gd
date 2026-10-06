extends GameTest
## THE PACK 9 BUG PASS, fix-ai-2 — permanents that may serve the other
## side, read by the fair AI before it casts them (engine/ai/tempest_spells.gd
## `permanent_harm`; [member AiProfile.forecasts_tactics]). The roles are
## declared by the card modules on the trigger or static that carries the
## shape (exo/_choices.gd, sth/_artifacts.gd, tmp/_misc.gd, exo/_spikes.gd):
##  * h6-3 the Oaths (`oath`): never cast while only the opponent qualifies;
##  * h6-4 Jinxed Idol (`donate_self`): never cast with no creature to give
##    it away with;
##  * h6-5 Ensnaring Bridge (`hand_size_attack_cap`): never cast when it
##    keeps more of our power home than of theirs;
##  * h6-6 Furnace of Rath (`damage_doubler`): never cast while their
##    damage is not below ours;
##  * h6-7 Spike Cannibal (`take_all_counters`): never cast to eat our own
##    Spikes.
## Each with its positive control, a null arm and a hidden-information
## permutation.

const TS := preload("res://engine/ai/tempest_spells.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _play_main(ai: AiPlayer) -> Array:
	var lines: Array = []
	var turn := g.turn_number
	for k in 20:
		if g.game_over or g.turn_number != turn or g.current_step() != Mtg.Step.MAIN1: break
		if g.priority_player == 0:
			var did := ai.act(g)
			lines.append(did)
			if did == "" or did == "pass": break
		else:
			g.pass_priority(g.priority_player)
	resolve_stack()
	return lines


## The reading for [param card] in hand, as the planner asks it.
func _reading(ai: AiPlayer, card: CardInstance) -> Variant:
	return TS.permanent_harm(g, ai, card)


# ------------------------------------------------------------------ the roles --

func test_the_card_modules_declare_the_roles() -> void:
	for pair in [["Oath of Druids", &"oath"], ["Oath of Lieges", &"oath"],
			["Oath of Mages", &"oath"], ["Oath of Scholars", &"oath"], ["Oath of Ghouls", &"oath"],
			["Ensnaring Bridge", &"hand_size_attack_cap"], ["Furnace of Rath", &"damage_doubler"],
			["Spike Cannibal", &"take_all_counters"]]:
		assert_not_null(TS._role_ability(CardRegistry.get_card(pair[0]), pair[1]), pair[0])


# --------------------------------------------------------------- h6-3: the Oaths --

func test_no_oath_of_druids_ahead_on_creatures() -> void:
	var ai := _ai()
	for k in 3: put_battlefield(0, "Grizzly Bears")
	for k in 2: put_battlefield(0, "Forest")
	var oath := give_hand(0, "Oath of Druids")
	_play_main(ai)
	assert_eq(oath.zone, Mtg.Zone.HAND, "only the opponent (no creatures) can use this Oath")


func test_no_oath_of_lieges_ahead_on_lands() -> void:
	var ai := _ai()
	for k in 5: put_battlefield(0, "Plains")
	put_battlefield(1, "Plains")
	var oath := give_hand(0, "Oath of Lieges")
	_play_main(ai)
	assert_eq(oath.zone, Mtg.Zone.HAND)


func test_no_oath_of_mages_ahead_on_life() -> void:
	var ai := _ai()
	for k in 3: put_battlefield(0, "Mountain")
	g.players[1].life = 5
	var oath := give_hand(0, "Oath of Mages")
	_play_main(ai)
	assert_eq(oath.zone, Mtg.Zone.HAND)


func test_no_oath_of_scholars_with_the_bigger_hand() -> void:
	var ai := _ai()
	for k in 4: put_battlefield(0, "Island")
	for k in 4: give_hand(0, "Island")
	var oath := give_hand(0, "Oath of Scholars")
	_play_main(ai)
	assert_eq(oath.zone, Mtg.Zone.HAND)


func test_an_oath_we_qualify_for_is_left_to_the_generic_reading() -> void:
	var ai := _ai()
	for k in 2: put_battlefield(0, "Forest")
	for k in 3: put_battlefield(1, "Grizzly Bears")
	var oath := give_hand(0, "Oath of Druids")
	assert_null(_reading(ai, oath), "behind on creatures: the Oath serves us")
	_play_main(ai)
	assert_eq(oath.zone, Mtg.Zone.BATTLEFIELD)


func test_the_null_arm_has_no_oath_reading() -> void:
	var ai := _ai(false)
	for k in 3: put_battlefield(0, "Grizzly Bears")
	var oath := give_hand(0, "Oath of Druids")
	assert_null(TS.spell_choice(g, ai, oath, 0, 0))


func test_the_oath_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		for k in 3: put_battlefield(0, "Grizzly Bears")
		var oath := give_hand(0, "Oath of Druids")
		give_hand(1, "Shivan Dragon" if variant == 0 else "Island")
		if variant == 1: g.players[1].library.reverse()
		answers.append(str(_reading(ai, oath)))
	assert_eq(answers[0], answers[1])


# -------------------------------------------------------------- h6-4: Jinxed Idol --

func test_no_jinxed_idol_with_no_creature_to_give_it_away() -> void:
	var ai := _ai()
	for k in 3: put_battlefield(0, "Mountain")
	var idol := give_hand(0, "Jinxed Idol")
	_play_main(ai)
	assert_eq(idol.zone, Mtg.Zone.HAND, "it would only bite its caster")


func test_jinxed_idol_cast_when_it_can_be_handed_to_a_board_with_no_creature() -> void:
	var ai := _ai()
	for k in 3: put_battlefield(0, "Mountain")
	put_battlefield(0, "Llanowar Elves")
	var idol := give_hand(0, "Jinxed Idol")
	var read: Variant = _reading(ai, idol)
	assert_true(read is Dictionary and not (read as Dictionary).is_empty(),
		"an Elves to give it with and nothing of theirs to send it back: %s" % str(read))


func test_no_jinxed_idol_into_a_board_that_sends_it_back() -> void:
	var ai := _ai()
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Grizzly Bears")
	var idol := give_hand(0, "Jinxed Idol")
	assert_eq(_reading(ai, idol), {}, "one turn of toll is not worth a creature")


# ---------------------------------------------------------- h6-5: Ensnaring Bridge --

func test_no_bridge_over_our_own_attackers() -> void:
	var ai := _ai()
	var dragon := put_battlefield(0, "Shivan Dragon")
	put_battlefield(0, "Craw Wurm")
	for k in 3: put_battlefield(0, "Mountain")
	put_battlefield(1, "Grizzly Bears")
	var bridge := give_hand(0, "Ensnaring Bridge")
	_play_main(ai)
	assert_eq(bridge.zone, Mtg.Zone.HAND, "an empty hand locks our 5/5 flyer and 6/4 out of a 2/2's way")
	assert_false(dragon.cur_cant_attack)


func test_a_bridge_against_their_big_attackers_is_left_to_the_generic_reading() -> void:
	var ai := _ai()
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Craw Wurm")
	var bridge := give_hand(0, "Ensnaring Bridge")
	give_hand(0, "Island")
	assert_null(_reading(ai, bridge), "one card kept: their 6/4 stays home, our 1/1 does not")


# ---------------------------------------------------------- h6-6: Furnace of Rath --

func test_no_furnace_for_their_attacker() -> void:
	var ai := _ai()
	for k in 4: put_battlefield(0, "Mountain")
	put_battlefield(1, "Craw Wurm")
	g.players[0].life = 12
	var furnace := give_hand(0, "Furnace of Rath")
	_play_main(ai)
	assert_eq(furnace.zone, Mtg.Zone.HAND, "only their Wurm's damage would double")


func test_a_furnace_behind_our_own_damage_is_left_to_the_generic_reading() -> void:
	var ai := _ai()
	put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Grizzly Bears")
	var furnace := give_hand(0, "Furnace of Rath")
	give_hand(0, "Lightning Bolt")
	assert_null(_reading(ai, furnace))


func test_the_furnace_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(1, "Craw Wurm")
		var furnace := give_hand(0, "Furnace of Rath")
		give_hand(1, "Lightning Bolt" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		answers.append(str(_reading(ai, furnace)))
	assert_eq(answers[0], answers[1])


# --------------------------------------------------------- h6-7: Spike Cannibal --

func test_no_spike_cannibal_on_our_own_spikes() -> void:
	var ai := _ai()
	var colony := put_battlefield(0, "Spike Colony")
	var feeder := put_battlefield(0, "Spike Feeder")
	for k in 3: put_battlefield(0, "Swamp")
	put_battlefield(1, "Grizzly Bears")
	var cannibal := give_hand(0, "Spike Cannibal")
	_play_main(ai)
	g.check_state_based_actions()
	assert_eq(colony.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(feeder.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(cannibal.zone, Mtg.Zone.HAND, "no counter on their side: it only eats ours")


func test_spike_cannibal_eating_their_spikes_is_worth_more_than_the_card() -> void:
	var ai := _ai()
	put_battlefield(1, "Spike Feeder")
	var cannibal := give_hand(0, "Spike Cannibal")
	var read: Variant = _reading(ai, cannibal)
	assert_true(read is Dictionary and float((read as Dictionary).get("value", 0.0)) \
		> Evaluator.card_value(cannibal.data), "their Feeder dies and its counters are ours: %s" % str(read))


func test_spike_cannibal_with_no_counters_out_is_left_to_the_generic_reading() -> void:
	var ai := _ai()
	put_battlefield(1, "Grizzly Bears")
	assert_null(_reading(ai, give_hand(0, "Spike Cannibal")))


# ------------------------------------------------------------------- null arm --

func test_the_null_arm_reads_none_of_them() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Spike Feeder")
	for card_name in ["Oath of Mages", "Jinxed Idol", "Ensnaring Bridge", "Furnace of Rath", "Spike Cannibal"]:
		assert_null(TS.spell_choice(g, ai, give_hand(0, card_name), 0, 0), card_name)
