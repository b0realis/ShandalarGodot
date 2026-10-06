extends GameTest
## Pack 9 bug pass (fix-licid; finding h5-1) — Heartstone: "Activated
## abilities of creatures cost {1} less to activate." "Creature" alone
## means a creature PERMANENT (CR 109.2): a creature CARD in a graveyard is
## no creature, so Carrionette's {2}{B}{B} and Necrosavant's {3}{B}{B}
## (both activated only from the graveyard) keep their full price. Both
## rules presets.


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ability_cost(pid: int, inst: CardInstance, index: int) -> int:
	var pay := g.ability_payment(pid, inst, index)
	return (pay["cost"] as ManaCost).mana_value() + int(pay["extra"])


func _dead(pid: int, card_name: String) -> CardInstance:
	var inst := put_battlefield(pid, card_name)
	g.sacrifice_permanent(inst)
	assert_eq(inst.zone, Mtg.Zone.GRAVEYARD)
	return inst


func test_heartstone_leaves_carrionette_in_the_graveyard_at_four() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		g.rules.set_edition(preset)
		var puppet := _dead(0, "Carrionette")
		var giant := put_battlefield(1, "Hill Giant")
		assert_eq(_ability_cost(0, puppet, 0), 4, "%s: precondition, {2}{B}{B}" % preset)
		put_battlefield(1, "Heartstone")
		assert_eq(_ability_cost(0, puppet, 0), 4,
			"%s: a creature card in a graveyard is no creature" % preset)
		add_mana(0, Mtg.ManaColor.B, 2)
		add_mana(0, Mtg.ManaColor.C, 1)
		g.priority_player = 0
		assert_refused(g.activate_ability(0, puppet, 0, [TargetRef.card(giant)]))
		assert_eq(puppet.zone, Mtg.Zone.GRAVEYARD, "%s: three mana paid nothing" % preset)
		assert_eq(g.players[0].mana_pool.total(), 3, "%s: nothing spent" % preset)


func test_heartstone_leaves_necrosavant_in_the_graveyard_at_five() -> void:
	var dead := _dead(0, "Necrosavant")
	assert_eq(_ability_cost(0, dead, 0), 5, "precondition: {3}{B}{B}")
	put_battlefield(0, "Heartstone")
	assert_eq(_ability_cost(0, dead, 0), 5, "a creature card in a graveyard is no creature")


func test_heartstone_still_discounts_a_creature_on_the_battlefield() -> void:
	var feeder := put_battlefield(0, "Spike Feeder")
	put_battlefield(1, "Heartstone")
	assert_eq(_ability_cost(0, feeder, 0), 1, "{2} becomes {1}")
