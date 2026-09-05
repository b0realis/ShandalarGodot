extends GameTest
## Wave-6 tests: control change (Control Magic), reanimation (Animate
## Dead), X pumps, spell-cast triggers, and the AI's grasp of all of it.


# --------------------------------------------------------- Control Magic --

func test_control_magic_steals_and_disenchant_returns() -> void:
	var serra := put_battlefield(1, "Serra Angel")
	var theft := give_hand(0, "Control Magic")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, theft, [TargetRef.card(serra)]))
	resolve_stack()
	assert_eq(serra.controller_id, 0, "stolen")
	assert_true(g.players[0].battlefield.has(serra))
	assert_true(serra.summoning_sick, "a stolen creature can't attack yet")
	# The classic answer: Disenchant the Control Magic.
	var answer := give_hand(1, "Disenchant")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, answer, [TargetRef.card(theft)]))
	resolve_stack()
	assert_eq(serra.controller_id, 1, "home again")
	assert_true(g.players[1].battlefield.has(serra))


func test_stolen_creature_survives_if_aura_host_dies_naturally() -> void:
	# Kill the STOLEN creature: the orphaned Control Magic sweeps to the
	# graveyard with nothing to return.
	var bear := put_battlefield(1, "Grizzly Bears")
	var theft := give_hand(0, "Control Magic")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, theft, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(bear, false)
	g.check_state_based_actions()   # direct engine surgery: run SBAs by hand
	assert_eq(theft.zone, Mtg.Zone.GRAVEYARD, "orphaned aura swept")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------- Animate Dead --

func test_animate_dead_raises_the_enemys_dragon() -> void:
	var shivan := put_battlefield(1, "Shivan Dragon")
	g.destroy(shivan, false)
	assert_eq(shivan.zone, Mtg.Zone.GRAVEYARD)
	var animate := give_hand(0, "Animate Dead")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, animate, [TargetRef.card(shivan)]))
	resolve_stack()
	assert_eq(shivan.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(shivan.controller_id, 0, "raised under OUR control")
	assert_eq(shivan.cur_power, 4, "5/5 with the -1/-0 rider")
	# Kill the aura: the creature dies again (modern oracle).
	g.destroy(animate, false)
	assert_eq(shivan.zone, Mtg.Zone.GRAVEYARD, "back to the grave")


# --------------------------------------------------------- assorted cards --

func test_howl_from_beyond_scales_with_x() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var howl := give_hand(0, "Howl from Beyond")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, howl, [TargetRef.card(bear)], 5))
	resolve_stack()
	assert_eq(bear.cur_power, 7, "2 + X=5")
	assert_eq(bear.cur_toughness, 2)


func test_keldon_warlord_counts_the_troops() -> void:
	var warlord := put_battlefield(0, "Keldon Warlord")
	assert_eq(warlord.cur_power, 1, "counts itself")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Wall of Stone")
	assert_eq(warlord.cur_power, 2, "walls don't march")


func test_enchantress_draws_on_enchantments_only() -> void:
	put_battlefield(0, "Verduran Enchantress")
	var aura := give_hand(0, "Holy Strength")
	var bear := put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 2, "bolt + the enchantress draw")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "no draw for an instant")


func test_unstable_mutation_loan_comes_due() -> void:
	var merfolk := put_battlefield(0, "Merfolk of the Pearl Trident")   # 1/1
	var mutation := give_hand(0, "Unstable Mutation")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, mutation, [TargetRef.card(merfolk)]))
	resolve_stack()
	assert_eq(merfolk.cur_power, 4, "1 + 3 on the spot")
	for _i in 4:
		advance_to_next_turn()
	# After two of OUR upkeeps: two -1/-1 counters against the +3/+3.
	assert_eq(merfolk.counters.get("-1/-1", 0), 2)
	assert_eq(merfolk.cur_power, 2, "1 + 3 - 2")


func test_sol_kanar_relishes_every_black_spell() -> void:
	put_battlefield(1, "Sol'kanar the Swamp King")
	var ritual := give_hand(0, "Dark Ritual")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, ritual, []))
	resolve_stack()
	assert_eq(g.players[1].life, 21, "even OUR ritual feeds their demon")


func test_scavenger_folk_trade_themselves_for_a_disk() -> void:
	var folk := put_battlefield(0, "Scavenger Folk")
	var disk := put_battlefield(1, "Nevinyrral's Disk")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, folk, 0, [TargetRef.card(disk)]))
	assert_eq(folk.zone, Mtg.Zone.GRAVEYARD, "sacrificed up front")
	resolve_stack()
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------ AI plays it --

func test_ai_steals_the_best_enemy_creature() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	give_hand(0, "Control Magic")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(1, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Control Magic")
	resolve_stack()
	assert_eq(serra.controller_id, 0, "it took the angel, not the bear")


func test_ai_reanimates_from_either_graveyard() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	give_hand(0, "Animate Dead")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var my_bear := put_battlefield(0, "Grizzly Bears")
	var their_shivan := put_battlefield(1, "Shivan Dragon")
	g.destroy(my_bear, false)
	g.destroy(their_shivan, false)
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Animate Dead")
	resolve_stack()
	assert_eq(their_shivan.zone, Mtg.Zone.BATTLEFIELD,
		"the enemy's dragon, not our bear")
	assert_eq(their_shivan.controller_id, 0)


func test_ai_royal_assassin_executes_mid_combat() -> void:
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	put_battlefield(1, "Royal Assassin")
	var serra := put_battlefield(0, "Serra Angel")
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))   # wurm taps; Serra home
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "executed Craw Wurm")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "tapped attacker executed")


func test_ai_greed_converts_life_to_cards() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	put_battlefield(0, "Greed")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "activated Greed")
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[0].hand.size(), 1)


func test_wave6_soak_still_completes() -> void:
	var game := MtgGame.new()
	game.setup(StarterDecks.WHITE_KNIGHTS, StarterDecks.BLACK_RED_RAIDERS,
		"A", "B", 20, 20, 606)
	var ai0 := AiPlayer.new(0, AiProfile.wizard())
	var ai1 := AiPlayer.new(1, AiProfile.wizard())
	game.set_agent(0, ai0)
	game.set_agent(1, ai1)
	game.start()
	assert_true(AiPlayer.play_out(game, ai0, ai1))
