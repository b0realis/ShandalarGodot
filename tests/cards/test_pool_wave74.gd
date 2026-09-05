extends GameTest
## Wave-74: Nalathni Dragon — the one card the POOL DEFINITION missed.
##
## It is not a HarperPrism book promo (our `phpr` set, which is complete at
## five) but the DragonCon 1994 promo, so fetching whole Scryfall sets could
## never produce it. `Duel.hlp` — the 1997 game's own shipped help — carries
## a full card entry for it, which is what establishes that it belongs;
## tools/fetch_cards.py's EXTRA_PRINTINGS now fetches it by name.


func test_registry_loaded_nalathni_dragon() -> void:
	var data := CardRegistry.get_card("Nalathni Dragon")
	assert_not_null(data)
	assert_eq(data.cost.text, "{2}{R}{R}")
	assert_eq(data.power, 1)
	assert_eq(data.toughness, 1)


func test_nalathni_dragon_flies_and_bands() -> void:
	var dragon := put_battlefield(0, "Nalathni Dragon")
	assert_true(dragon.has_keyword(Mtg.Keyword.FLYING))
	assert_true(dragon.has_keyword(Mtg.Keyword.BANDING))


func test_nalathni_dragon_breathes_fire() -> void:
	var dragon := put_battlefield(0, "Nalathni Dragon")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, dragon, 0))
	resolve_stack()
	assert_eq(dragon.cur_power, 2)
	assert_ok(g.activate_ability(0, dragon, 0))
	resolve_stack()
	assert_eq(dragon.cur_power, 3)
	assert_eq(dragon.cur_toughness, 1, "toughness is untouched")


func test_the_fourth_breath_is_fatal() -> void:
	var dragon := put_battlefield(0, "Nalathni Dragon")
	add_mana(0, Mtg.ManaColor.R, 4)
	for _i in 4:
		assert_ok(g.activate_ability(0, dragon, 0))
		resolve_stack()
	assert_eq(dragon.cur_power, 5)
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "it burns out at END step")
	advance_to_step(Mtg.Step.END)
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD)


func test_three_breaths_a_turn_are_survivable_forever() -> void:
	var dragon := put_battlefield(0, "Nalathni Dragon")
	for _turn in 3:
		add_mana(0, Mtg.ManaColor.R, 3)
		for _i in 3:
			assert_ok(g.activate_ability(0, dragon, 0))
			resolve_stack()
		advance_to_next_turn()
		advance_to_next_turn()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD,
		"'four or more times THIS TURN' — the count resets")
	assert_eq(dragon.cur_power, 1, "and the pumps expired with each turn")


func test_the_burnout_is_a_sacrifice() -> void:
	# CR 701.17: a sacrifice ignores regeneration.
	var dragon := put_battlefield(0, "Nalathni Dragon")
	dragon.regeneration_shields = 1
	add_mana(0, Mtg.ManaColor.R, 4)
	for _i in 4:
		assert_ok(g.activate_ability(0, dragon, 0))
		resolve_stack()
	advance_to_step(Mtg.Step.END)
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD, "a shield does not save it")
