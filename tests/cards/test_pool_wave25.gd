extends GameTest
## Wave-25 tests: Fourth Edition's creature toolbox — mana and ping
## creatures (Apprentice Wizard, Crimson Manticore, Brothers of Fire,
## Psionic Entity), utility bodies (Radjan Spirit, Giant Tortoise,
## Diabolic Machine, Whirling Dervish), the rent-or-die fatties (Ball
## Lightning, Cosmic Horror) and two blue answers (Gaseous Form,
## Hurkyl's Recall).


func test_apprentice_wizard_filters_blue_into_three() -> void:
	var wizard := put_battlefield(0, "Apprentice Wizard")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, wizard), "not enough floating mana")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.tap_for_mana(0, wizard))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 3)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 0)


func test_crimson_manticore_shoots_a_blocker() -> void:
	var manticore := put_battlefield(0, "Crimson Manticore")
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Mons's Goblin Raiders")   # 1/1
	assert_true(manticore.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, manticore, 0, [TargetRef.card(blocker)]),
		"Illegal target")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: bear.id}))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, manticore, 0, [TargetRef.card(blocker)]))
	resolve_stack()
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD)


func test_brothers_of_fire_burn_both_ways() -> void:
	var brothers := put_battlefield(0, "Brothers of Fire")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, brothers, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 19, "and 1 damage to you")


func test_psionic_entity_hurts_itself() -> void:
	var entity := put_battlefield(0, "Psionic Entity")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, entity, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(entity.zone, Mtg.Zone.GRAVEYARD, "3 damage on a 2/2 kills it")


func test_radjan_spirit_grounds_a_flier() -> void:
	var spirit := put_battlefield(0, "Radjan Spirit")
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING), "back next turn")


func test_giant_tortoise_hides_in_its_shell() -> void:
	var tortoise := put_battlefield(0, "Giant Tortoise")
	assert_eq(tortoise.cur_toughness, 4, "untapped: 1/4")
	g.tap_permanent(tortoise)
	assert_eq(tortoise.cur_toughness, 1, "tapped: a bare 1/1")


func test_diabolic_machine_regenerates() -> void:
	var machine := put_battlefield(0, "Diabolic Machine")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, machine, 0, []))
	resolve_stack()
	g.destroy(machine)
	assert_eq(machine.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(machine.tapped)


func test_ball_lightning_dies_at_end_of_turn() -> void:
	var ball := put_battlefield(0, "Ball Lightning", true)   # summoning sick
	assert_true(ball.has_keyword(Mtg.Keyword.HASTE))
	assert_true(ball.has_keyword(Mtg.Keyword.TRAMPLE))
	run_combat([ball.id])
	assert_eq(g.players[1].life, 14, "haste lets it swing immediately")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(ball.zone, Mtg.Zone.GRAVEYARD)


func test_cosmic_horror_devours_its_controller() -> void:
	var horror := put_battlefield(0, "Cosmic Horror")
	assert_true(horror.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_next_turn()
	advance_to_next_turn()   # back to player 0's upkeep, no mana available
	assert_eq(horror.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 13, "7 damage on the way out")


func test_whirling_dervish_grows_after_connecting() -> void:
	var dervish := put_battlefield(0, "Whirling Dervish")
	run_combat([dervish.id])
	assert_eq(g.players[1].life, 19)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(dervish.cur_power, 2)
	assert_eq(dervish.cur_toughness, 2)


func test_whirling_dervish_ignores_black_removal() -> void:
	var dervish := put_battlefield(0, "Whirling Dervish")
	var terror := give_hand(1, "Terror")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.pass_priority(0))
	assert_refused(g.cast_spell(1, terror, [TargetRef.card(dervish)]), "Illegal target")


func test_gaseous_form_blanks_combat_both_ways() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Hurloon Minotaur")   # 2/3
	var form := give_hand(0, "Gaseous Form")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, form, [TargetRef.card(bear)]))
	resolve_stack()
	run_combat([bear.id], {blocker.id: bear.id})
	assert_eq(blocker.damage, 0, "it deals no combat damage")
	assert_eq(bear.damage, 0, "and takes none")


func test_gaseous_form_still_lets_burn_through() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var form := give_hand(0, "Gaseous Form")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, form, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "only COMBAT damage is prevented")


func test_hurkyls_recall_bounces_all_their_artifacts() -> void:
	var theirs := put_battlefield(1, "Icy Manipulator")
	var golem := put_battlefield(1, "Obsianus Golem")
	var mine := put_battlefield(0, "Sol Ring")
	var recall := give_hand(0, "Hurkyl's Recall")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, recall, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.HAND)
	assert_eq(golem.zone, Mtg.Zone.HAND)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "only the target player's")
