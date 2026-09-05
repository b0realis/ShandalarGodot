extends GameTest
## Wave-30 tests: land-type changers (Evil Presence, Phantasmal Terrain,
## Blood Moon, Conversion) now that mana abilities are LIVE per instance,
## plus a run of auras (Web, Aspect of Wolf, Creature Bond, Blight,
## Spirit Shackle, The Brute) and two creatures (Goblin Balloon Brigade,
## Zombie Master).


func test_evil_presence_turns_a_land_into_a_swamp() -> void:
	var forest := put_battlefield(1, "Forest")
	var presence := give_hand(0, "Evil Presence")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, presence, [TargetRef.card(forest)]))
	resolve_stack()
	assert_true(forest.has_subtype("swamp"))
	assert_false(forest.has_subtype("forest"), "it IS a Swamp now, not also a Forest")
	assert_ok(g.tap_for_mana(1, forest))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.G), 0)


func test_phantasmal_terrain_picks_the_scarcest_type() -> void:
	var island := put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var terrain := give_hand(0, "Phantasmal Terrain")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, terrain, [TargetRef.card(island)]))
	resolve_stack()
	assert_false(island.has_subtype("island"), "it stopped being an Island")
	assert_ok(g.tap_for_mana(1, island))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.U), 0)


func test_blood_moon_burns_the_nonbasics() -> void:
	var basic := put_battlefield(1, "Forest")
	var dual := put_battlefield(1, "Tundra")
	put_battlefield(0, "Blood Moon")
	g.recalculate()
	assert_true(basic.has_subtype("forest"), "basics are untouched")
	assert_true(dual.has_subtype("mountain"))
	assert_ok(g.tap_for_mana(1, dual))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.R), 1)
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.W), 0)


func test_conversion_turns_mountains_into_plains() -> void:
	var mountain := put_battlefield(1, "Mountain")
	put_battlefield(0, "Conversion")
	g.recalculate()
	assert_true(mountain.has_subtype("plains"))
	assert_ok(g.tap_for_mana(1, mountain))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.W), 1)


func test_conversion_falls_off_when_the_rent_goes_unpaid() -> void:
	var conversion := put_battlefield(0, "Conversion")
	advance_to_next_turn()
	advance_to_next_turn()   # player 0's upkeep, no mana available
	assert_eq(conversion.zone, Mtg.Zone.GRAVEYARD)


func test_web_grants_reach_and_toughness() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var web := give_hand(0, "Web")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, web, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_toughness, 4)
	assert_true(bear.has_keyword(Mtg.Keyword.REACH))
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [angel.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {bear.id: angel.id}))   # reach blocks a flier


func test_aspect_of_wolf_scales_with_forests() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aspect := give_hand(0, "Aspect of Wolf")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, aspect, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3, "3 Forests: +1 power (rounded down)")
	assert_eq(bear.cur_toughness, 4, "+2 toughness (rounded up)")


func test_creature_bond_backfires_on_the_host() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bond := give_hand(0, "Creature Bond")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bond, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(bear, false)
	resolve_stack()
	assert_eq(g.players[1].life, 18, "2 damage — the bear's toughness")


func test_blight_destroys_the_land_it_taps() -> void:
	var forest := put_battlefield(1, "Forest")
	var blight := give_hand(0, "Blight")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, blight, [TargetRef.card(forest)]))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.tap_for_mana(1, forest))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)


func test_spirit_shackle_wears_a_creature_down() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var shackle := give_hand(0, "Spirit Shackle")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, shackle, [TargetRef.card(bear)]))
	resolve_stack()
	g.tap_permanent(bear)
	resolve_stack()
	# -0/-2 on a 2/2 is lethal: the counter lands and state-based actions
	# bury it the moment the trigger finishes resolving.
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(shackle.zone, Mtg.Zone.GRAVEYARD, "the orphaned aura follows")


func test_spirit_shackle_stacks_on_a_bigger_body() -> void:
	var angel := put_battlefield(1, "Serra Angel")   # 4/4
	var shackle := give_hand(0, "Spirit Shackle")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, shackle, [TargetRef.card(angel)]))
	resolve_stack()
	g.tap_permanent(angel)
	resolve_stack()
	assert_eq(angel.cur_toughness, 2, "-0/-2 counter")
	g.untap_permanent(angel)
	g.tap_permanent(angel)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD, "two counters is lethal")


func test_the_brute_pumps_and_regenerates() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var brute := give_hand(0, "The Brute")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, brute, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, brute, 0, []))
	resolve_stack()
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the aura regenerated its host")


func test_goblin_balloon_brigade_takes_off() -> void:
	var goblins := put_battlefield(0, "Goblin Balloon Brigade")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, goblins, 0, []))
	resolve_stack()
	assert_true(goblins.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_false(goblins.has_keyword(Mtg.Keyword.FLYING))


func test_zombie_master_arms_the_horde() -> void:
	var master := put_battlefield(0, "Zombie Master")
	var zombie := put_battlefield(0, "Scathe Zombies")
	assert_true(zombie.cur_landwalk.has("swamp"))
	assert_false(master.cur_landwalk.has("swamp"), "'other' Zombies")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, zombie, 0, []))
	resolve_stack()
	g.destroy(zombie)
	assert_eq(zombie.zone, Mtg.Zone.BATTLEFIELD, "the granted regeneration works")
