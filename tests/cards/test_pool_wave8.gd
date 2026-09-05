extends GameTest
## Wave-8 tests: the prevention/modal dividend — cards unblocked by the
## wave-7 mechanics. X prevention (Guardian Angel, Alabaster Potion),
## untargeted "to you" pools (Conservator), prevention tap-artifacts and
## specialists (Amulet of Kroog, Argivian Blacksmith, Kei Takahashi),
## color-hoser modals with bounce modes (Active Volcano, Flash Flood),
## combat-only animation (Jade Statue), and plain bounce (Boomerang).


# ------------------------------------------------- prevention artillery --

func test_conservator_shields_its_controller() -> void:
	var conservator := put_battlefield(0, "Conservator")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, conservator, 0, []))
	resolve_stack()
	assert_true(conservator.tapped)
	assert_eq(g.players[0].damage_prevention, 2)
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 19, "3 - 2 prevented = 1")


func test_amulet_of_kroog_prevents_one_anywhere() -> void:
	var amulet := put_battlefield(0, "Amulet of Kroog")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, amulet, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.prevention, 1)


func test_guardian_angel_prevents_x() -> void:
	var angel := give_hand(0, "Guardian Angel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, angel, [TargetRef.player(0)], 4))
	resolve_stack()
	assert_eq(g.players[0].damage_prevention, 4, "X=4 into the pool")


func test_alabaster_potion_both_modes_scale_with_x() -> void:
	# Mode 0: gain X.
	var potion := give_hand(0, "Alabaster Potion")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, potion, [TargetRef.player(0)], 5, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 25, "gained X=5")
	# Mode 1: prevent X on a creature.
	var bear := put_battlefield(0, "Grizzly Bears")
	var second := give_hand(0, "Alabaster Potion")
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, second, [TargetRef.card(bear)], 2, 1))
	resolve_stack()
	assert_eq(bear.prevention, 2)


func test_kei_takahashi_is_a_legend_and_prevents_two() -> void:
	var kei := put_battlefield(0, "Kei Takahashi")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, kei, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.prevention, 2)
	# And the legend rule applies to him.
	var twin := put_battlefield(0, "Kei Takahashi")
	g.check_state_based_actions()
	assert_eq(twin.zone, Mtg.Zone.GRAVEYARD, "second Kei is buried")


func test_argivian_blacksmith_only_shields_artifact_creatures() -> void:
	var smith := put_battlefield(0, "Argivian Blacksmith")
	var golem := put_battlefield(0, "Obsianus Golem")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, smith, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, smith, 0, [TargetRef.card(golem)]))
	resolve_stack()
	assert_eq(golem.prevention, 2)


# ------------------------------------------------------- color hosers --

func test_active_volcano_destroys_blue_permanent() -> void:
	var drake := put_battlefield(1, "Azure Drake")
	var volcano := give_hand(0, "Active Volcano")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, volcano, [TargetRef.card(drake)], 0, 0))
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD)


func test_active_volcano_bounces_an_island() -> void:
	var island := put_battlefield(1, "Island")
	var volcano := give_hand(0, "Active Volcano")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, volcano, [TargetRef.card(island)], 0, 1))
	resolve_stack()
	assert_eq(island.zone, Mtg.Zone.HAND, "the Island goes home")
	assert_true(g.players[1].hand.has(island))


func test_active_volcano_bounce_mode_refuses_a_mountain() -> void:
	var mountain := put_battlefield(1, "Mountain")
	var volcano := give_hand(0, "Active Volcano")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, volcano, [TargetRef.card(mountain)], 0, 1),
		"Illegal target")


func test_flash_flood_mirrors_the_volcano() -> void:
	var mountain := put_battlefield(1, "Mountain")
	var flood := give_hand(0, "Flash Flood")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, flood, [TargetRef.card(mountain)], 0, 1))
	resolve_stack()
	assert_eq(mountain.zone, Mtg.Zone.HAND)


# --------------------------------------------------------- Jade Statue --

func test_jade_statue_animates_only_during_combat() -> void:
	var statue := put_battlefield(0, "Jade Statue")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, statue, 0, []), "only during combat")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, statue, 0, []))
	resolve_stack()
	assert_true(statue.is_creature())
	assert_true(statue.has_subtype("golem"))
	assert_eq(statue.cur_power, 3)
	assert_eq(statue.cur_toughness, 6)
	# "Until end of COMBAT": through the end-of-combat step it's a golem;
	# the moment the combat phase ends it's a plain artifact again —
	# post-combat Terror finds no creature to hit (CR 700.5).
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_true(statue.is_creature(), "still a golem during end of combat")
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(statue.is_creature(), "a plain artifact again in main 2")
	assert_false(statue.has_subtype("golem"))


func test_jade_statue_blocks_a_juggernaut_and_survives() -> void:
	# The Statue's classic job: a surprise 3/6 wall. Activate at declare-
	# attackers (in response to the attack), then block.
	var statue := put_battlefield(1, "Jade Statue")
	var juggernaut := put_battlefield(0, "Juggernaut")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [juggernaut.id]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(1, statue, 0, []))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {statue.id: juggernaut.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(statue.zone, Mtg.Zone.BATTLEFIELD, "5 damage vs 6 toughness")
	assert_eq(g.players[1].life, 20, "nothing got through")


# ----------------------------------------------------------- Boomerang --

func test_boomerang_returns_any_permanent() -> void:
	var serra := put_battlefield(1, "Serra Angel")
	var boomerang := give_hand(0, "Boomerang")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, boomerang, [TargetRef.card(serra)]))
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.HAND)
	# A land is a permanent too — the tempo play of the era.
	var swamp := put_battlefield(1, "Swamp")
	var second := give_hand(0, "Boomerang")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, second, [TargetRef.card(swamp)]))
	resolve_stack()
	assert_eq(swamp.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------------- AI --

func test_ai_uses_active_volcano_on_the_best_blue_permanent() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	give_hand(0, "Active Volcano")
	put_battlefield(0, "Mountain")
	var drake := put_battlefield(1, "Azure Drake")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ""
	for _i in 8:
		did = ai.act(g)
		if did.contains("Active Volcano"):
			break
	assert_string_contains(did, "Active Volcano")
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD, "the AI torched the Drake")
