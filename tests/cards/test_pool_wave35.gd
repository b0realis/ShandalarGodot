extends GameTest
## Wave-35 tests: the Legends banding lands (Adventurers' Guildhouse,
## Cathedral of Serra, Mountain Stronghold, Seafarer's Quay, Unholy
## Citadel), banding removal (Shelkin Brownie, Tolaria), legendary
## landwalk (Livonya Silone), combat caps (Caverns of Despair), the
## universal upkeep tax (The Tabernacle at Pendrell Vale) and two
## mana-value pump tricks (Great Defender, Subdue).


# Amended 2026-09-02 with the "bands with other" lift (docs/simplified-
# cards.md, "Banding lands and bands-with cycles"): the lands grant
# CardInstance.cur_bands_with, not the banding keyword — CR 702.22c's
# second form. tests/cards/test_fidelity_2026_09_02_bands_with_other.gd
# pins the band rules themselves.
func test_guildhouse_bands_your_green_legends() -> void:
	put_battlefield(0, "Adventurers' Guildhouse")
	var legend := put_battlefield(0, "Jedit Ojanen")       # legendary, but white/blue
	var green := put_battlefield(0, "Marhault Elsdragon")  # legendary, red-green
	g.recalculate()
	assert_eq(legend.cur_bands_with.size(), 0, "not green")
	assert_eq(green.cur_bands_with.size(), 1)
	assert_eq(String(green.cur_bands_with[0]["desc"]), "legendary creatures")
	assert_false(green.has_keyword(Mtg.Keyword.BANDING),
		"'bands with other' is not banding (CR 702.22c)")


func test_the_other_four_banding_lands_pick_their_colour() -> void:
	put_battlefield(0, "Cathedral of Serra")
	put_battlefield(0, "Mountain Stronghold")
	put_battlefield(0, "Seafarer's Quay")
	put_battlefield(0, "Unholy Citadel")
	var white_legend := put_battlefield(0, "Jedit Ojanen")   # {4}{W}{W}{U}
	var plain := put_battlefield(0, "Grizzly Bears")         # not legendary
	g.recalculate()
	assert_eq(white_legend.cur_bands_with.size(), 1, "two lands, one grant")
	assert_eq(plain.cur_bands_with.size(), 0)


func test_shelkin_brownie_strips_banding() -> void:
	var brownie := put_battlefield(0, "Shelkin Brownie")
	var bander := put_battlefield(1, "Benalish Hero")
	assert_true(bander.has_keyword(Mtg.Keyword.BANDING))
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, brownie, 0, [TargetRef.card(bander)]))
	resolve_stack()
	assert_false(bander.has_keyword(Mtg.Keyword.BANDING))


func test_tolaria_only_works_in_an_upkeep() -> void:
	var tolaria := put_battlefield(0, "Tolaria")
	var bander := put_battlefield(1, "Benalish Hero")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, tolaria, 0, [TargetRef.card(bander)]),
		"upkeep step")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, tolaria, 0, [TargetRef.card(bander)]))
	resolve_stack()
	assert_false(bander.has_keyword(Mtg.Keyword.BANDING))


func test_tolaria_taps_for_blue() -> void:
	var tolaria := put_battlefield(0, "Tolaria")
	assert_ok(g.tap_for_mana(0, tolaria))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)


func test_livonya_silone_walks_past_legendary_lands() -> void:
	var livonya := put_battlefield(0, "Livonya Silone")
	assert_true(livonya.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [livonya.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	# no legendary land on their side, so the evasion is off
	assert_ok(g.declare_blockers(1, {blocker.id: livonya.id}))


func test_livonya_silone_is_unblockable_over_a_legendary_land() -> void:
	var livonya := put_battlefield(0, "Livonya Silone")
	put_battlefield(1, "Karakas")   # a legendary land
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [livonya.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blocker.id: livonya.id}), "legendarywalk")


func test_caverns_of_despair_caps_the_combat() -> void:
	put_battlefield(0, "Caverns of Despair")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var c := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [a.id, b.id, c.id]),
		"no more than 2 creatures can attack")
	assert_ok(g.declare_attackers(0, [a.id, b.id]))


func test_caverns_of_despair_caps_blockers_too() -> void:
	put_battlefield(0, "Caverns of Despair")
	var attacker := put_battlefield(0, "Craw Giant")
	var x := put_battlefield(1, "Wall of Wood")
	var y := put_battlefield(1, "Wall of Wood")
	var z := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1,
		{x.id: attacker.id, y.id: attacker.id, z.id: attacker.id}),
		"no more than 2 creatures can block")
	assert_ok(g.declare_blockers(1, {x.id: attacker.id, y.id: attacker.id}))


func test_tabernacle_charges_rent_for_every_creature() -> void:
	put_battlefield(0, "The Tabernacle at Pendrell Vale")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()   # player 1's upkeep, no mana available
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "only the active player pays")
	advance_to_next_turn()   # player 0's upkeep
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "symmetric, as printed")


func test_great_defender_scales_with_mana_value() -> void:
	var angel := put_battlefield(0, "Serra Angel")   # mana value 5
	var defender := give_hand(0, "Great Defender")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, defender, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.cur_toughness, 9)
	assert_eq(angel.cur_power, 4, "power untouched")


func test_subdue_silences_and_thickens() -> void:
	var giant := put_battlefield(1, "Craw Giant")   # mana value 7
	var subdue := give_hand(0, "Subdue")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, subdue, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.cur_toughness, 11)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "its combat damage was prevented")
