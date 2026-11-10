extends GameTest
## [method ManaPlanner.payment_pick] (GitHub issue #7): the colour a
## payment click on a source with several mana abilities means, or `[]`
## for the menu. The screens' own tests are tests/ui/test_issue_7_*.gd.


## The pick for [param inst] against [param cost_text] from seat 0's
## sources, the clicked source's rows in menu order.
func _pick(inst: CardInstance, cost_text: String) -> Array:
	var options: Array = []
	var others: Array = []
	for row in ManaPlanner.sources(g, 0):
		if row[0] == inst: options.append(row)
		else: others.append(row)
	options.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[1]) < int(b[1]) if int(a[1]) != int(b[1]) \
			else Mtg.WUBRG.find(int(a[2])) < Mtg.WUBRG.find(int(b[2])))
	var abilities: Array = []
	for row in options:
		abilities.append(g.mana_ability_for(0, inst, int(row[1])))
	return ManaPlanner.payment_pick(options, others, ManaCost.parse(cost_text), 0, [], abilities)


func _color(pick: Array) -> int:
	return int(pick[2]) if not pick.is_empty() else -1


func test_the_pip_still_owed_names_the_colour() -> void:
	var savannah := put_battlefield(0, "Savannah")
	add_mana(0, Mtg.ManaColor.G)
	assert_eq(_color(_pick(savannah, "{G}{G}")), Mtg.ManaColor.G)
	assert_eq(_color(_pick(savannah, "{W}")), Mtg.ManaColor.W)


func test_floating_mana_pays_its_own_pip_first() -> void:
	# {W}{G} with a white floating: only the green is owed.
	var savannah := put_battlefield(0, "Savannah")
	add_mana(0, Mtg.ManaColor.W)
	assert_eq(_color(_pick(savannah, "{W}{G}")), Mtg.ManaColor.G)


func test_the_rest_of_the_bill_breaks_a_tie() -> void:
	var savannah := put_battlefield(0, "Savannah")
	put_battlefield(0, "Plains")
	assert_eq(_color(_pick(savannah, "{G}{W}")), Mtg.ManaColor.G,
		"white would leave the {G} to a Plains")


func test_a_real_choice_is_left_to_the_player() -> void:
	var savannah := put_battlefield(0, "Savannah")
	put_battlefield(0, "Savannah")
	assert_eq(_pick(savannah, "{G}{W}"), [])


func test_generic_takes_the_first_and_surplus_asks() -> void:
	var savannah := put_battlefield(0, "Savannah")
	assert_eq(_color(_pick(savannah, "{1}")), Mtg.ManaColor.G)
	var lotus := put_battlefield(0, "Black Lotus")
	assert_eq(_pick(lotus, "{1}"), [], "two would float in a colour nobody named")
	assert_eq(_color(_pick(lotus, "{G}{G}")), Mtg.ManaColor.G)


func test_a_colour_that_pays_nothing_owed_is_never_picked() -> void:
	var tundra := put_battlefield(0, "Tundra")
	assert_eq(_pick(tundra, "{G}"), [], "neither white nor blue pays a {G}")


func test_a_colour_choice_ability_keeps_its_question() -> void:
	var stone := put_battlefield(0, "Fellwar Stone")
	put_battlefield(1, "Plains")
	put_battlefield(1, "Island")
	assert_eq(_pick(stone, "{W}"), [], "the owner's rule of 2026-09-17: the Stone asks")


func test_options_that_differ_pick_only_the_one_that_pays() -> void:
	var data := CardData.new("Test Painland", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C)) \
		.mana(ManaAbility.new(Mtg.ManaColor.W).hurting(1))
	var land := put_synthetic(0, data)
	put_battlefield(0, "Plains")
	assert_eq(_color(_pick(land, "{W}")), Mtg.ManaColor.W)
	assert_eq(_pick(land, "{1}{W}"), [], "painless {C} or painful {W}: the player says")
	assert_eq(_pick(land, "{1}"), [], "a different cost each way: the player says")
