extends GameTest
## WHO SHIELDED THIS CREATURE — [member CardInstance.prevention_source],
## the card whose effect last filled a creature's this-turn prevention
## pool (2026-09-07, `[QoL]`). The engine already kept the pool
## ([member CardInstance.prevention]); the table needed to know which
## card to draw behind the creature — the owner's *"Cast Healing Salve on
## a creature should be like an aura (mini card behind a creature) just
## last only one turn"* — and an instant is in the graveyard by the time
## anybody looks. Pinned: every writer of the pool names itself; the name
## survives the pool draining and goes with the pool at cleanup; a probe
## leaves neither behind.


func _salve_on(inst: CardInstance) -> void:
	var salve := give_hand(0, "Healing Salve")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, salve, [TargetRef.card(inst)], 0, 1))
	resolve_stack()


func test_healing_salve_names_itself_on_the_creature_it_shields() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_salve_on(bear)
	assert_eq(bear.prevention, 3)
	assert_not_null(bear.prevention_source)
	assert_eq(bear.prevention_source.card_name, "Healing Salve")
	assert_eq(g.players[0].graveyard.size(), 1,
		"the Salve itself is in the graveyard, as it should be — the table "
		+ "draws the definition, not the instance")


func test_the_name_stays_while_the_pool_drains_and_goes_with_it_at_cleanup() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_salve_on(bear)
	g.deal_damage(giant, TargetRef.card(bear), 3)
	assert_eq(bear.prevention, 0, "three of the Giant's three soaked")
	assert_eq(bear.damage, 0)
	assert_eq(bear.prevention_source.card_name, "Healing Salve",
		"the name is not cleared by the draining — the table hides it at 0")
	advance_to_next_turn()
	assert_eq(bear.prevention, 0)
	assert_null(bear.prevention_source, "cleanup takes the name with the pool")


func test_a_second_shield_takes_the_name() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var healer := put_battlefield(0, "Samite Healer")
	advance_to_step(Mtg.Step.MAIN1)
	_salve_on(bear)
	assert_ok(g.activate_ability(0, healer, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.prevention, 4)
	assert_eq(bear.prevention_source.card_name, "Samite Healer",
		"the latest shield is the one the table shows")


func test_a_creature_shielding_itself_names_itself() -> void:
	var hydra := put_battlefield(0, "Rock Hydra")
	g.add_counters(hydra, "+1/+1", 2)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, hydra, 0))
	resolve_stack()
	assert_eq(hydra.prevention, 1)
	assert_eq(hydra.prevention_source, hydra.data,
		"its own definition — which is how the table knows not to draw "
		+ "a Hydra behind the Hydra")


func test_guardian_angels_paid_point_names_the_angel() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var angel := give_hand(0, "Guardian Angel")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, angel, [TargetRef.card(bear)], 0))
	resolve_stack()
	assert_eq(bear.prevention, 0, "X was 0")
	assert_null(bear.prevention_source, "nothing shields the Bears yet")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.pay_for_prevention(0, TargetRef.card(bear)))
	assert_eq(bear.prevention, 1)
	assert_eq(bear.prevention_source.card_name, "Guardian Angel",
		"the point bought later still knows whose rider it was")


func test_indestructible_aura_names_itself() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var aura := give_hand(0, "Indestructible Aura")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.prevention, 9999)
	assert_eq(bear.prevention_source.card_name, "Indestructible Aura")


func test_a_probe_leaves_neither_the_pool_nor_the_name() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var salve := give_hand(0, "Healing Salve")
	add_mana(0, Mtg.ManaColor.W)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, salve, [TargetRef.card(bear)], 0, 1))
	resolve_stack()
	assert_eq(bear.prevention, 3)
	assert_eq(bear.prevention_source.card_name, "Healing Salve")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.prevention, 0)
	assert_null(bear.prevention_source)


func test_a_paid_point_under_a_probe_is_unmade_too() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var angel := give_hand(0, "Guardian Angel")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, angel, [TargetRef.card(bear)], 0))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.G)
	var mark := g.make_mark()
	assert_ok(g.pay_for_prevention(0, TargetRef.card(bear)))
	assert_eq(bear.prevention_source.card_name, "Guardian Angel")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.prevention, 0)
	assert_null(bear.prevention_source,
		"pay_for_prevention journals the name beside the pool")
