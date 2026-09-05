extends GameTest
## Wave-13 tests: 4th Edition workhorses — pump auras (Divine
## Transformation, Giant Strength, Immolation, Eternal Warrior), self-pump
## creatures (Killer Bees, Carrion Ants, Dragon Engine), pingers and
## shrink effects (Grapeshot Catapult, Pradesh Gypsies), combat sweep
## (Sandstorm), catch-all removal (Desert Twister) and a value body
## (Onulet).


func test_desert_twister_hits_any_permanent() -> void:
	var crusade := put_battlefield(1, "Crusade")
	var twister := give_hand(0, "Desert Twister")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, twister, [TargetRef.card(crusade)]))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD)


func test_divine_transformation_plus_three() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Divine Transformation")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 5)
	assert_eq(bear.cur_toughness, 5)


func test_giant_strength_plus_two() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Giant Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	assert_eq(bear.cur_toughness, 4)


func test_immolation_can_burn_out_small_hosts() -> void:
	# On a 3/3 the host survives at 5/1; a 2/2 host drops to 4/0 and dies.
	var mammoth := put_battlefield(0, "War Mammoth")
	var immo := give_hand(0, "Immolation")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, immo, [TargetRef.card(mammoth)]))
	resolve_stack()
	assert_eq(mammoth.cur_power, 5)
	assert_eq(mammoth.cur_toughness, 1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var immo2 := give_hand(0, "Immolation")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, immo2, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "4/0 — toughness SBA")
	assert_eq(immo2.zone, Mtg.Zone.GRAVEYARD, "the aura follows its host")


func test_eternal_warrior_grants_vigilance() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Eternal Warrior")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_false(bear.tapped, "vigilance — attacked untapped")


func test_killer_bees_swell() -> void:
	var bees := put_battlefield(0, "Killer Bees")
	assert_true(bees.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, bees, 0, []))
	assert_ok(g.activate_ability(0, bees, 0, []))
	resolve_stack()
	assert_eq(bees.cur_power, 2, "0/1 + two pumps")
	assert_eq(bees.cur_toughness, 3)


func test_carrion_ants_and_dragon_engine_pump() -> void:
	var ants := put_battlefield(0, "Carrion Ants")
	var engine := put_battlefield(0, "Dragon Engine")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, ants, 0, []))
	assert_ok(g.activate_ability(0, engine, 0, []))
	resolve_stack()
	assert_eq(ants.cur_power, 1)
	assert_eq(ants.cur_toughness, 2)
	assert_eq(engine.cur_power, 2, "1/3 +1/+0")
	assert_eq(engine.cur_toughness, 3)


func test_grapeshot_catapult_only_hits_flyers() -> void:
	var catapult := put_battlefield(0, "Grapeshot Catapult")
	var flyer := put_battlefield(1, "Phantom Monster")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, catapult, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, catapult, 0, [TargetRef.card(flyer)]))
	resolve_stack()
	assert_eq(flyer.damage, 1)
	assert_true(catapult.tapped)


func test_pradesh_gypsies_shrink() -> void:
	var gypsies := put_battlefield(0, "Pradesh Gypsies")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, gypsies, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 0, "2/2 shrunk to 0/2")
	assert_eq(bear.cur_toughness, 2)


func test_sandstorm_pelts_every_attacker() -> void:
	var lions := put_battlefield(0, "Savannah Lions")
	var mammoth := put_battlefield(0, "War Mammoth")
	var home := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lions.id, mammoth.id]))
	var storm := give_hand(1, "Sandstorm")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, storm, []))
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD, "the 2/1 died to the grit")
	assert_eq(mammoth.damage, 1)
	assert_eq(home.damage, 0, "non-attackers untouched")


func test_onulet_pays_out_on_death() -> void:
	var onulet := put_battlefield(0, "Onulet")
	g.destroy(onulet, false)
	resolve_stack()
	assert_eq(g.players[0].life, 22, "died — its controller gains 2")
