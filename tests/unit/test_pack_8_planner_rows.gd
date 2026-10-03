extends GameTest
## THE PLANNER TRIES EVERY ROW OF A PERMANENT (Pack 8, 2026-10-03).
##
## A source with several mana abilities is listed once per ability
## (ManaPlanner.sources), but the plan only ever tried an instance's FIRST
## row in sorted order and then marked the instance used — so Crystal
## Vein's "{T}, Sacrifice: Add {C}{C}", sorted after its plain "{T}: Add
## {C}" (sacrifices last), was never considered: the Vein could not pay
## {2}, Vein + Forest could not pay {3}, and the auto-tap missed it the same
## way. The fix lets a taken permanent trade its row for a richer one once
## every cheaper row is spent (ManaPlanner._upgrade_row) — paying {1} still
## taps the plain row and keeps the land.


func _vein() -> CardData:
	return CardData.new("Test Vein", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C)) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 2).with_sacrifice())


func _grove() -> CardData:
	return CardData.new("Test Grove", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.mana(ManaAbility.new(Mtg.ManaColor.G, 2).with_sacrifice())


func _rows(tap_plan: Array) -> Array:
	var out: Array = []
	for step in tap_plan:
		out.append([step[0], int(step[1])])
	return out


func test_one_generic_taps_the_plain_row_and_keeps_the_land() -> void:
	var vein := put_synthetic(0, _vein())
	assert_eq(_rows(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)), [[vein, 0]])
	assert_true(g.try_pay(0, ManaCost.parse("{1}")))
	assert_eq(vein.zone, Mtg.Zone.BATTLEFIELD, "no sacrifice for {1}")


func test_two_generic_plans_the_sacrifice_row() -> void:
	var vein := put_synthetic(0, _vein())
	assert_eq(_rows(ManaPlanner.plan(g, 0, ManaCost.parse("{2}"), 0)), [[vein, 1]])
	assert_true(g.can_afford_cost(0, ManaCost.parse("{2}")))
	assert_true(g.try_pay(0, ManaCost.parse("{2}")))
	assert_eq(vein.zone, Mtg.Zone.GRAVEYARD, "it paid with {T}, Sacrifice")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_three_generic_with_a_forest_uses_the_forest_and_the_sacrifice() -> void:
	var vein := put_synthetic(0, _vein())
	var forest := put_battlefield(0, "Forest")
	var tap_plan := _rows(ManaPlanner.plan(g, 0, ManaCost.parse("{3}"), 0))
	assert_eq(tap_plan.size(), 2)
	assert_true(tap_plan.has([forest, 0]))
	assert_true(tap_plan.has([vein, 1]))
	var auto := _rows(ManaPlanner.plan_from(ManaPlanner.auto_tap_sources(g, 0),
		ManaCost.parse("{3}"), 0))
	assert_eq(auto.size(), 2, "the player's auto-tap finds it too")
	assert_true(auto.has([vein, 1]))


func test_two_generic_with_a_forest_keeps_the_vein() -> void:
	var vein := put_synthetic(0, _vein())
	var forest := put_battlefield(0, "Forest")
	var tap_plan := _rows(ManaPlanner.plan(g, 0, ManaCost.parse("{2}"), 0))
	assert_true(tap_plan.has([forest, 0]))
	assert_true(tap_plan.has([vein, 0]), "cheaper rows first: nothing is sacrificed")


func test_x_counts_the_richer_row() -> void:
	put_synthetic(0, _vein())
	put_battlefield(0, "Forest")
	assert_eq(ManaPlanner.max_affordable_x(g, 0, ManaCost.parse("{X}")), 3)


func test_a_colored_multi_row_source_pays_two_pips_or_a_pip_and_a_generic() -> void:
	var grove := put_synthetic(0, _grove())
	assert_eq(_rows(ManaPlanner.plan(g, 0, ManaCost.parse("{G}"), 0)), [[grove, 0]])
	assert_eq(_rows(ManaPlanner.plan(g, 0, ManaCost.parse("{G}{G}"), 0)), [[grove, 1]])
	assert_eq(_rows(ManaPlanner.plan(g, 0, ManaCost.parse("{1}{G}"), 0)), [[grove, 1]])
	assert_true(ManaPlanner.plan(g, 0, ManaCost.parse("{G}{G}{G}"), 0).is_empty())


func test_a_colored_row_is_not_traded_away_from_its_pip() -> void:
	# {R}{1} with a Mountain and a Grove: the Mountain pays the pip and the
	# Grove's plain row the generic — never a colour swap.
	var mountain := put_battlefield(0, "Mountain")
	var grove := put_synthetic(0, _grove())
	var tap_plan := _rows(ManaPlanner.plan(g, 0, ManaCost.parse("{1}{R}"), 0))
	assert_true(tap_plan.has([mountain, 0]))
	assert_true(tap_plan.has([grove, 0]))
	assert_eq(_rows(ManaPlanner.plan(g, 0, ManaCost.parse("{2}{R}"), 0)).has([grove, 1]), true)
