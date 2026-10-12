extends GameTest
## THE UPKEEP THAT BURNS (robustness campaign 2026-10-12, b5-7;
## [member AiProfile.forecasts_tactics]).
##
## [method AiPlayer.cumulative_upkeep_hint] priced a cumulative upkeep by
## its mana, life and lands and never by the mana its payment leaves
## floating: seven green for an Uktabi Efreet out of Karoos, each tapping
## for {C}{G}, burns a point for every Karoo under the mana-burn rules
## (the Karoo deck took 26 of the 30 AI mana burns in 432 Pack 8 duels). The
## burn is now priced ([method AiPlayer._upkeep_burn]) and a burn that is
## our last life is never paid, at any rung. Gate off: the old price.


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(profile: AiProfile = null, on := true) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## [param count] Jungle Basins ({T}: Add {C}{G}), untapped, and nothing else.
func _basins(count: int) -> void:
	for i in count:
		var forest := put_battlefield(0, "Forest")
		var basin := put_battlefield(0, "Jungle Basin")
		resolve_stack()   # the Basin returns the Forest
		if forest.zone == Mtg.Zone.HAND:
			g.discard_cards(0, [forest])
		basin.tapped = false


func test_the_burn_of_an_upkeep_payment_is_read() -> void:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai()
	_basins(3)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._upkeep_burn(g, ManaCost.parse("{G}{G}{G}")), 3,
		"three Basins for {G}{G}{G}: three {C} float")
	g.rules.set_preset("modern")
	assert_eq(ai._upkeep_burn(g, ManaCost.parse("{G}{G}{G}")), 0, "no mana burn: nothing to price")


func test_forests_leave_nothing_to_burn() -> void:
	g.rules.set_preset("fifth")
	var ai := _ai()
	for i in 3: put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._upkeep_burn(g, ManaCost.parse("{G}{G}{G}")), 0)


func test_an_upkeep_whose_burn_is_our_last_life_is_not_paid() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		for profile in [AiProfile.wizard(), AiProfile.magician(), AiProfile.apprentice()]:
			before_each()
			g.rules.set_preset(preset)
			var ai := _ai(profile)
			_basins(3)
			var efreet := put_battlefield(0, "Uktabi Efreet")
			advance_to_step(Mtg.Step.MAIN1)
			g.players[0].life = 3
			assert_false(ai.cumulative_upkeep_hint(g, 0, efreet, ManaCost.parse("{G}{G}{G}"), 0, 0),
				"%s %s: three to burn at three life" % [preset, profile.profile_name])
	before_each()
	g.rules.set_preset("modern_mana_burn")
	var off := _ai(null, false)
	_basins(3)
	var efreet := put_battlefield(0, "Uktabi Efreet")
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].life = 3
	assert_true(off.cumulative_upkeep_hint(g, 0, efreet, ManaCost.parse("{G}{G}{G}"), 0, 0),
		"gate off: the old price pays it")


func test_the_burn_is_part_of_the_wizards_price() -> void:
	# Six Basins for {G}x6 at 20 life: six to burn. The same price at the
	# same life with Forests is paid; the burn tips it.
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai()
	_basins(6)
	var efreet := put_battlefield(0, "Uktabi Efreet")
	advance_to_step(Mtg.Step.MAIN1)
	var cost := ManaCost.parse("{G}{G}{G}{G}{G}{G}")
	var worth := ai._own_value(g, efreet)
	var plain := cost.mana_value() * 0.75
	var burned := plain + 6.0 * minf(ai._life_price(20), Evaluator.W_LIFE)
	gut.p("Efreet worth %.2f, price %.2f, with the burn %.2f" % [worth, plain, burned])
	assert_eq(ai.cumulative_upkeep_hint(g, 0, efreet, cost, 0, 0), worth >= burned)
