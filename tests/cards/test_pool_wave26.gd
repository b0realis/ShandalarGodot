extends GameTest
## Wave-26 tests: The Dark's utility shell — tribal and graveyard hosers
## (Tivadar's Crusade, Tormod's Crypt), aura removal on a stick (Miracle
## Worker, Savaen Elves), painful mana (Elves of Deep Shadow), board
## control (Riptide, Niall Silvain, Hurr Jackal), land-count bodies
## (Water Wurm, People of the Woods), enchantment recursion (Skull of Orm)
## and the promo Giant Badger.


func test_tivadars_crusade_only_kills_goblins() -> void:
	var king := put_battlefield(1, "Goblin King")
	var raiders := put_battlefield(1, "Mons's Goblin Raiders")
	var bear := put_battlefield(1, "Grizzly Bears")
	var crusade := give_hand(0, "Tivadar's Crusade")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, crusade, []))
	resolve_stack()
	assert_eq(king.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_riptide_taps_every_blue_creature() -> void:
	var wizard := put_battlefield(1, "Prodigal Sorcerer")
	var bear := put_battlefield(1, "Grizzly Bears")
	var mine := put_battlefield(0, "Prodigal Sorcerer")
	var riptide := give_hand(0, "Riptide")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, riptide, []))
	resolve_stack()
	assert_true(wizard.tapped)
	assert_true(mine.tapped, "symmetric — yours too")
	assert_false(bear.tapped)


func test_tormods_crypt_exiles_a_graveyard() -> void:
	var crypt := put_battlefield(0, "Tormod's Crypt")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear, false)
	assert_eq(g.players[1].graveyard.size(), 1)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, crypt, 0, [TargetRef.player(1)]))
	assert_eq(crypt.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	resolve_stack()
	assert_eq(g.players[1].graveyard.size(), 0)
	assert_eq(bear.zone, Mtg.Zone.EXILE)


func test_miracle_worker_strips_your_own_aura() -> void:
	var worker := put_battlefield(0, "Miracle Worker")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var mine_aura := give_hand(0, "Holy Strength")
	var their_aura := give_hand(1, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, mine_aura, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()   # auras are sorcery-speed: player 1's own turn
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, their_aura, [TargetRef.card(theirs)]))
	resolve_stack()
	advance_to_next_turn()
	assert_refused(g.activate_ability(0, worker, 0, [TargetRef.card(their_aura)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, worker, 0, [TargetRef.card(mine_aura)]))
	resolve_stack()
	assert_eq(mine_aura.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(their_aura.zone, Mtg.Zone.BATTLEFIELD)


func test_savaen_elves_shatter_a_land_aura() -> void:
	var elves := put_battlefield(0, "Savaen Elves")
	var land := put_battlefield(1, "Forest")
	var venom := give_hand(1, "Psychic Venom")
	advance_to_next_turn()   # player 1's turn — enchantments are sorcery-speed
	add_mana(1, Mtg.ManaColor.U)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, venom, [TargetRef.card(land)]))
	resolve_stack()
	assert_eq(venom.attached_to, land.id)
	advance_to_next_turn()
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, elves, 0, [TargetRef.card(venom)]))
	resolve_stack()
	assert_eq(venom.zone, Mtg.Zone.GRAVEYARD)


func test_niall_silvain_regenerates_anything() -> void:
	var niall := put_battlefield(0, "Niall Silvain")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_ok(g.activate_ability(0, niall, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_hurr_jackal_blanks_a_regeneration_shield() -> void:
	var jackal := put_battlefield(0, "Hurr Jackal")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, skeletons, 0, []))
	resolve_stack()
	assert_eq(skeletons.regeneration_shields, 1)
	assert_ok(g.activate_ability(0, jackal, 0, [TargetRef.card(skeletons)]))
	resolve_stack()
	g.destroy(skeletons)
	assert_eq(skeletons.zone, Mtg.Zone.GRAVEYARD, "the shield was banned")


func test_hurr_jackal_ban_wears_off() -> void:
	var jackal := put_battlefield(0, "Hurr Jackal")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, jackal, 0, [TargetRef.card(skeletons)]))
	resolve_stack()
	assert_true(skeletons.regeneration_banned_this_turn)
	advance_to_next_turn()
	assert_false(skeletons.regeneration_banned_this_turn)


func test_elves_of_deep_shadow_hurt_to_use() -> void:
	var elves := put_battlefield(0, "Elves of Deep Shadow")
	assert_ok(g.tap_for_mana(0, elves))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_eq(g.players[0].life, 19)


func test_water_wurm_swells_against_islands() -> void:
	var wurm := put_battlefield(0, "Water Wurm")
	assert_eq(wurm.cur_toughness, 1)
	put_battlefield(0, "Island")
	g.recalculate()
	assert_eq(wurm.cur_toughness, 1, "your own Islands don't count")
	put_battlefield(1, "Island")
	g.recalculate()
	assert_eq(wurm.cur_toughness, 2)


func test_people_of_the_woods_count_your_forests() -> void:
	var people := put_battlefield(0, "People of the Woods")
	assert_eq(people.cur_power, 1)
	assert_eq(people.cur_toughness, 0, "no Forests — it dies")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	g.recalculate()
	assert_eq(people.cur_toughness, 3)


func test_skull_of_orm_rebuys_an_enchantment() -> void:
	var skull := put_battlefield(0, "Skull of Orm")
	var crusade := put_battlefield(0, "Crusade")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(crusade, false)
	g.destroy(bear, false)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_refused(g.activate_ability(0, skull, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, skull, 0, [TargetRef.card(crusade)]))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.HAND)


func test_giant_badger_bulks_up_when_blocking() -> void:
	var badger := put_battlefield(1, "Giant Badger")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {badger.id: bear.id}))
	resolve_stack()
	assert_eq(badger.cur_power, 4)
	assert_eq(badger.cur_toughness, 4)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(badger.zone, Mtg.Zone.BATTLEFIELD)
