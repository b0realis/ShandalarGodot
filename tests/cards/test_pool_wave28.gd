extends GameTest
## Wave-28 tests: Legends' two signature combat mechanics — RAMPAGE
## (Craw Giant, Frost Giant, Wolverine Pack, Marhault Elsdragon, Hunding
## Gjornersen, Aerathi Berserker) and the landwalk NULLIFIERS (Gosta
## Dirk, Ur-Drago, Lord Magnus, Crevasse, Deadfall, Great Wall, Quagmire,
## Undertow).


func test_rampage_does_nothing_against_one_blocker() -> void:
	var pack := put_battlefield(0, "Wolverine Pack")   # 2/4 rampage 2
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [pack.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: pack.id}))
	assert_eq(pack.cur_power, 2, "one blocker is not 'beyond the first'")


func test_rampage_scales_with_extra_blockers() -> void:
	var pack := put_battlefield(0, "Wolverine Pack")   # 2/4 rampage 2
	var b1 := put_battlefield(1, "Grizzly Bears")
	var b2 := put_battlefield(1, "Grizzly Bears")
	var b3 := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [pack.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {b1.id: pack.id, b2.id: pack.id, b3.id: pack.id}))
	assert_eq(pack.cur_power, 6, "2/4 plus rampage 2 twice")
	assert_eq(pack.cur_toughness, 8)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(pack.zone, Mtg.Zone.BATTLEFIELD, "8 toughness survives 6 damage")


func test_aerathi_berserker_rampage_three() -> void:
	var berserker := put_battlefield(0, "Aerathi Berserker")   # 2/4 rampage 3
	var b1 := put_battlefield(1, "Wall of Wood")
	var b2 := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [berserker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {b1.id: berserker.id, b2.id: berserker.id}))
	assert_eq(berserker.cur_power, 5)
	assert_eq(berserker.cur_toughness, 7)


func test_craw_giant_tramples_over_a_gang_block() -> void:
	var giant := put_battlefield(0, "Craw Giant")   # 6/4 trample rampage 2
	assert_true(giant.has_keyword(Mtg.Keyword.TRAMPLE))
	var b1 := put_battlefield(1, "Wall of Wood")   # 0/3
	var b2 := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {b1.id: giant.id, b2.id: giant.id}))
	assert_eq(giant.cur_power, 8)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18, "8 power, 6 soaked by two walls, 2 trample over")


func test_frost_giant_and_friends_carry_their_rampage() -> void:
	assert_eq(CardRegistry.get_card("Frost Giant").rampage, 2)
	assert_eq(CardRegistry.get_card("Marhault Elsdragon").rampage, 1)
	assert_eq(CardRegistry.get_card("Hunding Gjornersen").rampage, 1)
	assert_eq(CardRegistry.get_card("Craw Giant").rampage, 2)
	assert_eq(CardRegistry.get_card("Aerathi Berserker").rampage, 3)
	assert_eq(CardRegistry.get_card("Wolverine Pack").rampage, 2)


func test_undertow_lets_you_block_islandwalkers() -> void:
	put_battlefield(1, "Island")
	var walker := put_battlefield(0, "Merfolk of the Pearl Trident")
	var oil := give_hand(0, "Fishliver Oil")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, oil, [TargetRef.card(walker)]))
	resolve_stack()
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [walker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blocker.id: walker.id}), "islandwalk")
	put_battlefield(1, "Undertow")
	g.recalculate()
	assert_ok(g.declare_blockers(1, {blocker.id: walker.id}))


func test_quagmire_cancels_swampwalk() -> void:
	put_battlefield(1, "Swamp")
	var wraith := put_battlefield(0, "Bog Wraith")
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wraith.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blocker.id: wraith.id}), "swampwalk")
	put_battlefield(0, "Quagmire")
	assert_true(g.nullified_landwalk.has("swamp"), "the swamp path is closed")
	assert_true(wraith.cur_landwalk.has("swamp"), "it still HAS swampwalk")
	assert_ok(g.declare_blockers(1, {blocker.id: wraith.id}))


func test_crevasse_cancels_mountainwalk() -> void:
	put_battlefield(0, "Goblin King")
	var goblin := put_battlefield(0, "Mons's Goblin Raiders")
	assert_true(goblin.cur_landwalk.has("mountain"))
	put_battlefield(1, "Crevasse")
	g.recalculate()
	assert_true(g.nullified_landwalk.has("mountain"))


func test_deadfall_and_great_wall_close_their_paths() -> void:
	put_battlefield(1, "Deadfall")
	g.recalculate()
	assert_true(g.nullified_landwalk.has("forest"))
	put_battlefield(1, "Great Wall")
	g.recalculate()
	assert_true(g.nullified_landwalk.has("plains"))


func test_gosta_dirk_closes_the_islands_himself() -> void:
	var gosta := put_battlefield(1, "Gosta Dirk")
	assert_true(gosta.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	put_battlefield(1, "Island")
	var walker := put_battlefield(0, "Merfolk of the Pearl Trident")
	var oil := give_hand(0, "Fishliver Oil")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, oil, [TargetRef.card(walker)]))
	resolve_stack()
	assert_true(g.nullified_landwalk.has("island"), "Gosta Dirk shuts islandwalk off")
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [walker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: walker.id}))


func test_ur_drago_closes_the_swamps() -> void:
	put_battlefield(1, "Ur-Drago")
	put_battlefield(0, "Bog Wraith")
	g.recalculate()
	assert_true(g.nullified_landwalk.has("swamp"))


func test_lord_magnus_closes_two_paths() -> void:
	var magnus := put_battlefield(1, "Lord Magnus")
	assert_true(magnus.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	g.recalculate()
	assert_true(g.nullified_landwalk.has("forest"))
	assert_true(g.nullified_landwalk.has("plains"))
	assert_false(g.nullified_landwalk.has("island"), "only the two he names")
