extends GameTest
## Pack 9 (the Tempest block), the fair AI's SPELL READERS (stage 4,
## casting; engine/ai/tempest_spells.gd, [member AiProfile.forecasts_tactics]).
##
## The card-local effects the intent reader could not price, each read by
## the shape its card declares ([member EffectBase.ai_role]) off the public
## board:
##  * damage counted as it resolves — Sudden Impact's hand size, Repentance's
##    and Deadshot's power, Mob Justice's creatures, Flame Wave's player and
##    board; before this they were zero-damage burn and named nothing;
##  * Meditate's skipped turn, priced as a turn and never skipped into
##    their lethal board (it was cast at their end step as a plain draw);
##  * Extinction's one creature type, not a Wrath of God;
##  * Mox Diamond's land card: never cast with none to spare (it went to the
##    graveyard);
##  * Stun's "can't block" before our attack, Corpse Dance's hasty attacker,
##    Verdant Touch on a land of ours we can spare.
## With the gate off every card plays as it did before Pack 9. The
## opponent's hidden hand never moves a decision (its size is public).


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------- damage counted as it resolves --

func test_sudden_impact_burns_a_full_hand() -> void:
	var lives: Array = []
	for hand in [["Forest", "Forest", "Forest", "Forest"],
			["Lightning Bolt", "Counterspell", "Shivan Dragon", "Swords to Plowshares"]]:
		g = null
		before_each()
		var ai := _ai()
		_lands(0, "Mountain", 4)
		give_hand(0, "Sudden Impact")
		for card_name in hand: give_hand(1, card_name)
		advance_to_step(Mtg.Step.MAIN1)
		assert_string_contains(ai.act(g), "Sudden Impact")
		resolve_stack()
		lives.append(g.players[1].life)
	assert_eq(lives, [16, 16], "four cards, four damage — whatever the four are")


func test_sudden_impact_waits_for_a_hand() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	var impact := give_hand(0, "Sudden Impact")
	give_hand(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(impact.zone, Mtg.Zone.HAND, "one point is not a card's worth")


func test_repentance_turns_their_wurm_on_itself() -> void:
	var ai := _ai()
	_lands(0, "Plains", 3)
	var wurm := put_battlefield(1, "Craw Wurm")
	put_battlefield(1, "Wall of Stone")
	give_hand(0, "Repentance")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Repentance")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "6 power into 4 toughness")


func test_repentance_is_kept_from_a_wall() -> void:
	var ai := _ai()
	_lands(0, "Plains", 3)
	put_battlefield(1, "Wall of Stone")
	var repentance := give_hand(0, "Repentance")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(repentance.zone, Mtg.Zone.HAND, "0 power kills nothing")


func test_deadshot_has_their_giant_shoot_their_bears() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	var giant := put_battlefield(1, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Deadshot")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Deadshot")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_true(giant.tapped, "the shooter is theirs, and tapped")


func test_mob_justice_counts_our_creatures() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Wall of Stone")
	give_hand(0, "Mob Justice")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Mob Justice")
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_flame_wave_takes_their_board_and_four_life() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 7)
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	give_hand(0, "Flame Wave")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Flame Wave")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 16)


func test_the_null_arm_throws_repentance_at_a_wall() -> void:
	var ai := _ai(false)
	_lands(0, "Plains", 3)
	put_battlefield(1, "Wall of Stone")
	var repentance := give_hand(0, "Repentance")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_ne(repentance.zone, Mtg.Zone.HAND, "gate off: the old reading names their best creature, power or not")


# ---------------------------------------------------------------- the skipped turn --

func test_meditate_is_never_skipped_into_their_board() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	for _i in 2: put_battlefield(1, "Craw Wurm")
	var meditate := give_hand(0, "Meditate")
	_their_turn_at(Mtg.Step.END)
	ai.act(g)
	assert_eq(meditate.zone, Mtg.Zone.HAND, "twelve power, twice, is our twenty life")


func test_meditate_draws_four_on_a_quiet_board() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var meditate := give_hand(0, "Meditate")
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Meditate")
	resolve_stack()
	assert_eq(meditate.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------------- Extinction --

func test_extinction_takes_their_type_and_leaves_ours() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 5)
	var theirs: Array = []
	for _i in 2: theirs.append(put_battlefield(1, "Grizzly Bears"))
	var elves := put_battlefield(0, "Llanowar Elves")
	give_hand(0, "Extinction")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Extinction")
	resolve_stack()
	for bear in theirs:
		assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD)


func test_extinction_is_not_a_wrath() -> void:
	# Their two creatures share no type worth a sweep: a Bears of theirs is
	# a Bears of ours too, and the Elf alone is not worth the card.
	var ai := _ai()
	_lands(0, "Swamp", 5)
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Llanowar Elves")
	var extinction := give_hand(0, "Extinction")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(extinction.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------------ Mox Diamond --

func test_mox_diamond_waits_for_a_spare_land() -> void:
	var ai := _ai()
	var mox := give_hand(0, "Mox Diamond")
	give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 3:
		ai.act(g)
		resolve_stack()
	assert_eq(mox.zone, Mtg.Zone.HAND, "the one land was the land drop")


func test_mox_diamond_eats_the_second_land() -> void:
	var ai := _ai()
	var mox := give_hand(0, "Mox Diamond")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 3:
		ai.act(g)
		resolve_stack()
	assert_eq(mox.zone, Mtg.Zone.BATTLEFIELD)


func test_the_null_arm_throws_the_mox_away() -> void:
	var ai := _ai(false)
	var mox := give_hand(0, "Mox Diamond")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_eq(mox.zone, Mtg.Zone.GRAVEYARD, "gate off: no land, no Mox (as before Pack 9)")


# ---------------------------------------------------------------- the attack --

func test_stun_clears_their_blocker_before_our_attack() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Stun")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Stun")
	resolve_stack()
	assert_true(bears.cur_cant_block_filter.is_valid(), "the Bears cannot block this turn")


func test_stun_without_an_attack_waits() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	put_battlefield(1, "Grizzly Bears")
	var stun := give_hand(0, "Stun")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(stun.zone, Mtg.Zone.HAND)


func test_corpse_dance_raises_the_wurm_to_attack() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 3)
	var wurm := _in_graveyard(0, "Craw Wurm")
	give_hand(0, "Corpse Dance")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Corpse Dance")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.controller_id, 0)


func test_verdant_touch_animates_our_own_spare_land() -> void:
	var ai := _ai()
	_lands(0, "Forest", 5)
	var their_land := put_battlefield(1, "Forest")
	give_hand(0, "Verdant Touch")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Verdant Touch")
	resolve_stack()
	assert_false(their_land.is_creature(), "never their land")
	var animated := 0
	for land in g.players[0].battlefield:
		if land.is_land() and land.is_creature(): animated += 1
	assert_eq(animated, 1)


func test_verdant_touch_keeps_a_thin_mana_base() -> void:
	var ai := _ai()
	_lands(0, "Forest", 3)
	var touch := give_hand(0, "Verdant Touch")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(touch.zone, Mtg.Zone.HAND)


# -------------------------------------------------------------- bodies sized on entry --

func test_minion_of_the_wastes_is_kept_at_low_life() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 6)
	g.players[0].life = 6
	var minion := give_hand(0, "Minion of the Wastes")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(minion.zone, Mtg.Zone.HAND, "the hint pays 1 life: a 1/1 for six mana")


func test_minion_of_the_wastes_at_healthy_life() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 6)
	var minion := give_hand(0, "Minion of the Wastes")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Minion of the Wastes")
	resolve_stack()
	assert_eq(minion.zone, Mtg.Zone.BATTLEFIELD)
	assert_gt(minion.cur_toughness, 0)


func test_dracoplasm_needs_a_meal() -> void:
	var ai := _ai()
	put_battlefield(0, "Island")
	put_battlefield(0, "Mountain")
	var draco := give_hand(0, "Dracoplasm")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(draco.zone, Mtg.Zone.HAND, "no creature to eat: a 0/0")


# ------------------------------------------------------------------ X bodies --

func test_shifting_wall_is_cast_as_big_as_the_mana() -> void:
	var ai := _ai()
	_lands(0, "Island", 4)
	var wall := give_hand(0, "Shifting Wall")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Shifting Wall")
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wall.cur_toughness, 4)


func test_endless_scream_pumps_our_creature() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	var bears := put_battlefield(0, "Grizzly Bears")
	var scream := give_hand(0, "Endless Scream")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Endless Scream")
	resolve_stack()
	assert_eq(g.find_instance(scream.attached_to), bears)
	assert_gt(bears.cur_power, 2)


# ------------------------------------------------------------- Legacy's Allure --

func test_legacys_allure_takes_what_its_counters_reach() -> void:
	var ai := _ai()
	var allure := put_battlefield(0, "Legacy's Allure")
	allure.counters["treasure"] = 3
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Legacy's Allure")
	resolve_stack()
	assert_eq(giant.controller_id, 0)
