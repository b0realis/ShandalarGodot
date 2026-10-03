extends GameTest
## THE LOCKS AND BANS, VALUED (Pack 8, 2026-10-03; engine package E4;
## [member AiProfile.forecasts_tactics]).
##
##  * AN ACTIVATION BAN (Null Rod, Cursed Totem, City of Solitude) is cast
##    when it stops more of THEIR abilities than ours — a nonland mana
##    ability weighing most, a turn-relative ban half, and each instant in
##    our own hand a lock on playing would strand counted against it
##    (mirage_tactics.gd `ban_swing`).
##  * PEACE TALKS is cast after our attack when their clock is lethal or
##    clearly the faster (`truce_value`), and held on an even board.
##  * A FLOATING BAN (Solfatara, Abeyance) is cast at their upkeep, at
##    them (`upkeep_ban`).
## Public board and own hand only.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai() -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func test_null_rod_is_cast_against_their_artifacts() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	put_battlefield(1, "Mox Emerald")
	put_battlefield(1, "Sol Ring")
	put_battlefield(1, "Rod of Ruin")
	var rod := give_hand(0, "Null Rod")
	advance_to_step(Mtg.Step.MAIN1)
	assert_gt(M.ban_swing(g, ai, rod), 1.5)
	assert_string_contains(ai.act(g), "Null Rod")


func test_null_rod_is_held_against_our_own_artifacts() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Mox Pearl")
	put_battlefield(0, "Sol Ring")
	var rod := give_hand(0, "Null Rod")
	advance_to_step(Mtg.Step.MAIN1)
	assert_lt(M.ban_swing(g, ai, rod), 0.0)
	ai.act(g)
	assert_eq(rod.zone, Mtg.Zone.HAND, "it would lock our own mana")


func test_city_of_solitude_counts_the_instants_it_strands() -> void:
	var ai := _ai()
	var city := give_hand(0, "City of Solitude")
	var before := M.ban_swing(g, ai, city)
	give_hand(0, "Lightning Bolt")
	give_hand(0, "Counterspell")
	assert_eq(M.ban_swing(g, ai, city), before - 2.0)


func test_peace_talks_waits_on_an_even_board() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var talks := give_hand(0, "Peace Talks")
	advance_to_step(Mtg.Step.MAIN2)
	ai.act(g)
	assert_eq(talks.zone, Mtg.Zone.HAND)


func test_peace_talks_buys_two_turns_against_a_lethal_clock() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	put_battlefield(1, "Craw Wurm")
	put_battlefield(1, "Hill Giant")
	g.players[0].life = 8
	var talks := give_hand(0, "Peace Talks")
	advance_to_step(Mtg.Step.MAIN2)
	assert_string_contains(ai.act(g), "Peace Talks")
	resolve_stack()
	assert_eq(talks.zone, Mtg.Zone.GRAVEYARD)


func test_solfatara_is_cast_at_their_upkeep() -> void:
	var ai := _ai()
	for _i in 3: put_battlefield(0, "Mountain")
	var solfatara := give_hand(0, "Solfatara")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.UPKEEP) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))
	assert_string_contains(ai.act(g), "Solfatara")
	assert_eq(g.stack.back().targets[0].player_id, 1, "at them")
	resolve_stack()
	assert_eq(solfatara.zone, Mtg.Zone.GRAVEYARD)
	assert_ne(g.play_banned(1, CardRegistry.get_card("Forest")), "", "no land drop for them this turn")
