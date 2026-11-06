extends GameTest
## Pack 10 (the Urza block), batch B9: Citanul Hierophants — "Creatures you
## control have '{T}: Add {G}.'" — the first card in the pool to grant a
## MANA ability to other permanents (cards/sets/usg/_lands_mana.gd). The
## granted ability lives in each creature's live list, so tap_for_mana and
## the one mana planner (the AI's plans and the human auto-pay) both see it,
## and both keep summoning sickness (CR 302.6, 605.1a: a {T} mana ability of
## a creature is gated like any other {T} ability; haste lifts it).

func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func pool(pid: int, color: int) -> int:
	return g.players[pid].mana_pool.amount_of(color)

## The planner's rows for [param inst] (green ones), as [index, amount].
func green_rows(inst: CardInstance) -> Array:
	var out: Array = []
	for s in ManaPlanner.sources(g, inst.controller_id):
		if s[0] == inst and int(s[2]) == Mtg.ManaColor.G: out.append([int(s[1]), int(s[3])])
	return out

## The index of [param inst]'s granted {G} ability.
func granted_index(inst: CardInstance) -> int:
	for i in inst.cur_mana_abilities.size():
		var a: ManaAbility = inst.cur_mana_abilities[i]
		if a.taps_source and int(a.produces[0][0]) == Mtg.ManaColor.G and a.cost == null:
			return i
	return -1


func test_hierophants_is_no_longer_pending() -> void:
	var c := CardRegistry.get_card("Citanul Hierophants")
	assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending")


func test_creatures_you_control_tap_for_green() -> void:
	var hiero := put_battlefield(0, "Citanul Hierophants")
	var bears := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	assert_true(theirs.cur_mana_abilities.is_empty(), "only creatures YOU control")
	assert_ok(g.tap_for_mana(0, bears, granted_index(bears)))
	assert_ok(g.tap_for_mana(0, hiero, granted_index(hiero)))
	assert_eq(pool(0, Mtg.ManaColor.G), 2, "the Hierophants itself is a creature you control")
	assert_true(bears.tapped)
	assert_refused(g.tap_for_mana(0, bears, granted_index(bears)), "tapped")

func test_a_summoning_sick_creature_cannot_use_it_and_the_planner_knows() -> void:
	put_battlefield(0, "Citanul Hierophants", true)
	var fresh := put_battlefield(0, "Grizzly Bears", true)
	var old := put_battlefield(0, "Hill Giant")
	assert_ne(granted_index(fresh), -1, "it has the ability")
	assert_refused(g.tap_for_mana(0, fresh, granted_index(fresh)), "summoning sickness")
	assert_true(green_rows(fresh).is_empty(), "the planner never counts a sick creature")
	assert_eq(green_rows(old), [[granted_index(old), 1]])
	assert_true(g.can_afford_cost(0, ManaCost.parse("{G}")))
	assert_false(g.can_afford_cost(0, ManaCost.parse("{G}{G}")), "two sick creatures, one ready")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(g.can_afford_cost(0, ManaCost.parse("{G}{G}{G}")), "a turn later all three may tap")

func test_haste_lifts_the_sickness() -> void:
	put_battlefield(0, "Citanul Hierophants")
	var skirge := put_battlefield(0, "Crazed Skirge", true)
	assert_true(skirge.has_keyword(Mtg.Keyword.HASTE))
	assert_eq(green_rows(skirge).size(), 1)
	assert_ok(g.tap_for_mana(0, skirge, granted_index(skirge)))
	assert_eq(pool(0, Mtg.ManaColor.G), 1)

func test_the_auto_pay_taps_creatures_for_a_cost() -> void:
	put_battlefield(0, "Citanul Hierophants")
	put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Hill Giant", true)   # sick: never part of the plan
	assert_true(g.try_pay(0, ManaCost.parse("{1}{G}")), "{1}{G} paid by tapping creatures")
	var tapped := 0
	for i in g.players[0].battlefield:
		if i.tapped:
			tapped += 1
			assert_false(i.summoning_sick, i.data.card_name)
	assert_eq(tapped, 2)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_false(g.try_pay(0, ManaCost.parse("{G}")), "the sick one is all that is left")

func test_the_grant_follows_the_hierophants_and_control() -> void:
	var hiero := put_battlefield(0, "Citanul Hierophants")
	var bears := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	g.change_control(theirs, 0)
	g.recalculate()
	assert_ne(granted_index(theirs), -1, "a creature you came to control has it")
	g.return_to_hand(hiero)
	g.recalculate()
	assert_eq(granted_index(bears), -1, "gone with the Hierophants")
	assert_true(bears.cur_mana_abilities.is_empty())

func test_a_creature_with_its_own_mana_ability_keeps_it_first() -> void:
	put_battlefield(0, "Citanul Hierophants")
	var elves := put_battlefield(0, "Llanowar Elves")
	assert_eq(elves.cur_mana_abilities.size(), 2, "its own {G} and the granted one")
	assert_ok(g.tap_for_mana(0, elves, 0))
	assert_eq(pool(0, Mtg.ManaColor.G), 1)

func test_an_animated_land_is_a_creature_you_control() -> void:
	put_battlefield(0, "Citanul Hierophants")
	var factory := put_battlefield(0, "Mishra's Factory")
	assert_eq(granted_index(factory), -1, "not a creature yet")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, factory, 0))
	resolve_stack()
	assert_ne(granted_index(factory), -1)
	assert_ok(g.tap_for_mana(0, factory, granted_index(factory)))
	assert_eq(pool(0, Mtg.ManaColor.G), 1)

func test_two_hierophants_grant_it_twice_and_one_leaving_keeps_the_other() -> void:
	var first := put_battlefield(0, "Citanul Hierophants")
	put_battlefield(0, "Citanul Hierophants")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_eq(bears.cur_mana_abilities.size(), 2)
	g.return_to_hand(first)
	g.recalculate()
	assert_eq(bears.cur_mana_abilities.size(), 1)

func test_humility_takes_the_grant_away_in_either_order() -> void:
	for humility_first in [false, true]:
		CardPacks.set_enabled("pack-9", true)
		before_each()
		if humility_first: put_battlefield(1, "Humility")
		put_battlefield(0, "Citanul Hierophants")
		var bears := put_battlefield(0, "Grizzly Bears")
		if not humility_first: put_battlefield(1, "Humility")
		g.recalculate()
		assert_eq(granted_index(bears), -1,
			"the Hierophants lost its ability (Humility %s)" % ("first" if humility_first else "last"))
		assert_refused(g.tap_for_mana(0, bears))
