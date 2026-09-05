extends GameTest
## Wave-22 tests: Legends' static abilities — the world enchantments
## (Concordant Crossroads, Gravity Sphere, Living Plane) and the world
## rule that polices them, the lords (Jacques le Vert, the three Kobold
## chiefs, Angelic Voices), the conditional pumps (Ivory Guardians,
## Beasts of Bogardan) and the attack-prisons (Akron Legionnaire, Evil
## Eye of Orms-by-Gore).


func test_concordant_crossroads_hastes_everyone() -> void:
	put_battlefield(0, "Concordant Crossroads")
	var mine := put_battlefield(0, "Grizzly Bears", true)   # summoning sick
	var theirs := put_battlefield(1, "Savannah Lions", true)
	assert_true(mine.has_keyword(Mtg.Keyword.HASTE))
	assert_true(theirs.has_keyword(Mtg.Keyword.HASTE), "symmetric, as printed")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mine.id]))


func test_gravity_sphere_grounds_the_fliers() -> void:
	put_battlefield(0, "Gravity Sphere")
	var angel := put_battlefield(1, "Serra Angel")
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_next_turn()
	run_combat([angel.id], {bear.id: angel.id})
	assert_eq(angel.damage, 2, "a ground bear can block it now")


func test_living_plane_animates_every_land() -> void:
	put_battlefield(0, "Living Plane")
	var forest := put_battlefield(0, "Forest")
	var island := put_battlefield(1, "Island")
	assert_true(forest.is_creature())
	assert_eq(forest.cur_power, 1)
	assert_eq(forest.cur_toughness, 1)
	assert_true(island.is_creature(), "both sides")
	assert_true(forest.is_land(), "still lands")


func test_world_rule_buries_the_older_world_enchantment() -> void:
	var crossroads := put_battlefield(0, "Concordant Crossroads")
	var sphere := put_battlefield(1, "Gravity Sphere")
	g.check_state_based_actions()
	assert_eq(crossroads.zone, Mtg.Zone.GRAVEYARD, "the older world permanent goes")
	assert_eq(sphere.zone, Mtg.Zone.BATTLEFIELD, "the newest survives")


func test_jacques_le_vert_thickens_green() -> void:
	var jacques := put_battlefield(0, "Jacques le Vert")
	var bear := put_battlefield(0, "Grizzly Bears")
	var lions := put_battlefield(0, "Savannah Lions")
	var theirs := put_battlefield(1, "Grizzly Bears")
	assert_eq(bear.cur_toughness, 4)
	assert_eq(lions.cur_toughness, 1, "white isn't green")
	assert_eq(theirs.cur_toughness, 2, "only creatures you control")
	assert_eq(jacques.cur_toughness, 4,
		"his own {G} makes him green, so he pumps himself (CR 105.2b)")


func test_kobold_taskmaster_arms_the_others_only() -> void:
	var master := put_battlefield(0, "Kobold Taskmaster")
	var kobold := put_battlefield(0, "Kobolds of Kher Keep")
	assert_eq(kobold.cur_power, 1, "0/1 + 1/+0")
	assert_eq(master.cur_power, 1, "not boosted by itself")


func test_kobold_overlord_spreads_first_strike() -> void:
	var overlord := put_battlefield(0, "Kobold Overlord")
	var kobold := put_battlefield(0, "Kobolds of Kher Keep")
	var theirs := put_battlefield(1, "Kobolds of Kher Keep")
	assert_true(overlord.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_true(kobold.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_false(theirs.has_keyword(Mtg.Keyword.FIRST_STRIKE), "yours only")


func test_kobold_drill_sergeant_toughens_and_tramples() -> void:
	put_battlefield(0, "Kobold Drill Sergeant")
	var kobold := put_battlefield(0, "Kobolds of Kher Keep")
	assert_eq(kobold.cur_toughness, 2)
	assert_true(kobold.has_keyword(Mtg.Keyword.TRAMPLE))


func test_angelic_voices_only_sings_for_a_pure_board() -> void:
	put_battlefield(0, "Angelic Voices")
	var lions := put_battlefield(0, "Savannah Lions")
	assert_eq(lions.cur_power, 3, "white-only board gets the boost")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	assert_eq(lions.cur_power, 2, "a green creature silences the choir")
	assert_eq(bear.cur_power, 2)


func test_ivory_guardians_swell_against_red() -> void:
	var guardians := put_battlefield(0, "Ivory Guardians")
	assert_eq(guardians.cur_power, 3, "no red permanent yet")
	put_battlefield(1, "Mons's Goblin Raiders")
	g.recalculate()
	assert_eq(guardians.cur_power, 4)
	assert_eq(guardians.cur_toughness, 4)


func test_ivory_guardians_shrug_off_red_burn() -> void:
	var guardians := put_battlefield(0, "Ivory Guardians")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(guardians)]), "Illegal target")


func test_beasts_of_bogardan_swell_against_white() -> void:
	var beasts := put_battlefield(0, "Beasts of Bogardan")
	assert_eq(beasts.cur_power, 3)
	put_battlefield(1, "Savannah Lions")
	g.recalculate()
	assert_eq(beasts.cur_power, 4)
	assert_eq(beasts.cur_toughness, 4)


func test_akron_legionnaire_grounds_your_army() -> void:
	var akron := put_battlefield(0, "Akron Legionnaire")
	var bear := put_battlefield(0, "Grizzly Bears")
	var golem := put_battlefield(0, "Obsianus Golem")   # artifact creature
	var theirs := put_battlefield(1, "Grizzly Bears")
	assert_true(bear.cur_cant_attack)
	assert_false(akron.cur_cant_attack, "the Legionnaire itself may attack")
	assert_false(golem.cur_cant_attack, "artifact creatures are exempt")
	assert_false(theirs.cur_cant_attack, "only creatures you control")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]), "can't attack")
	assert_ok(g.declare_attackers(0, [akron.id]))


func test_evil_eye_grounds_non_eyes_and_dodges_non_walls() -> void:
	var eye := put_battlefield(0, "Evil Eye of Orms-by-Gore")
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Wood")
	assert_true(bear.cur_cant_attack)
	assert_false(eye.cur_cant_attack)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [eye.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blocker.id: eye.id}), "Walls")
	assert_ok(g.declare_blockers(1, {wall.id: eye.id}))
