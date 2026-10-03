extends GameTest
## THE MANA PLANNER, and the two engine queries the 1997 auto-cast needed
## (`engine/mana_planner.gd`, `MtgGame.could_afford` / `spell_payment` /
## `ability_payment` / `is_unpaid_refusal`).
##
## The planner is the AI's own, moved out of `AiPlayer` on 2026-09-03 so
## the HUMAN seat's double-click could use it instead of growing a second
## one — the owner's standing instruction with that defect. These tests pin
## the move (the AI still answers the same), the exclusions the original's
## own auto-tapper had (`Don't auto tap this card`, restricted mana), and
## the X rule `Duel.hlp` states for the auto-cast: *"ALL of the mana you
## have available in your pool and from land sources will be put into that
## spell."*


func _lands(pid: int, card_name: String, n: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in n:
		out.append(put_battlefield(pid, card_name))
	return out


# ------------------------------------------------------------- sources --

func test_sources_lists_untapped_lands_and_floating_mana() -> void:
	_lands(0, "Forest", 2)
	add_mana(0, Mtg.ManaColor.G, 1)
	var src := ManaPlanner.sources(g, 0)
	assert_eq(src.size(), 3, "two Forests and one floating green")
	# Floating mana is a null instance — the executors skip it, because it
	# is already in the pool.
	var floating := 0
	for s in src:
		if s[0] == null:
			floating += 1
	assert_eq(floating, 1)


func test_a_tapped_land_is_not_a_source() -> void:
	var forests := _lands(0, "Forest", 2)
	forests[0].tapped = true
	assert_eq(ManaPlanner.sources(g, 0).size(), 1)


func test_dont_auto_tap_takes_a_source_off_the_list() -> void:
	# `@MENU_SMALLCARD` entry 4 (`Program/UIStrings.txt:941`), and
	# `Duel.hlp`, topic Territory: "Don't Auto Tap marks a land to be
	# ignored — not tapped for mana — when you auto-cast any spell or
	# effect. The only way to tap a locked land is manually."
	var forests := _lands(0, "Forest", 2)
	assert_eq(ManaPlanner.sources(g, 0).size(), 2)
	var locked := {forests[0].id: true}
	assert_eq(ManaPlanner.sources(g, 0, locked).size(), 1,
		"the locked land is invisible to the auto-tapper")
	# ...and the plan then cannot cover a cost that needed it.
	var cost := ManaCost.parse("{G}{G}")
	assert_true(ManaPlanner.plan(g, 0, cost, 0).size() == 2)
	assert_true(ManaPlanner.plan(g, 0, cost, 0, [], locked).is_empty())


# ---------------------------------------------------------------- plans --

func test_a_plan_finds_the_colours_first() -> void:
	_lands(0, "Forest", 1)
	_lands(0, "Mountain", 2)
	var tap_plan := ManaPlanner.plan(g, 0, ManaCost.parse("{2}{G}"), 0)
	assert_eq(tap_plan.size(), 3, "one Forest for the {G}, two for the {2}")
	var greens := 0
	for step in tap_plan:
		if step[0] != null and step[0].data.card_name == "Forest":
			greens += 1
	assert_eq(greens, 1)


func test_an_uncoverable_cost_plans_nothing() -> void:
	_lands(0, "Forest", 1)
	assert_true(ManaPlanner.plan(g, 0, ManaCost.parse("{2}{G}"), 0).is_empty())


func test_restricted_mana_is_planned_only_for_what_it_may_pay_for() -> void:
	# Mishra's Workshop: "Spend this mana only to cast artifact spells."
	# Before the 2026-09-02 sweep the planner read it as three generic and
	# every creature it "paid for" bounced off the engine with the lands
	# already tapped; the move must not lose that.
	if CardRegistry.get_card("Mishra's Workshop") == null:
		pass_test("Mishra's Workshop not in the pool")
		return
	put_battlefield(0, "Mishra's Workshop")
	var cost := ManaCost.parse("{3}")
	assert_true(ManaPlanner.plan(g, 0, cost, 0).is_empty(),
		"no usage key: the Workshop's mana may not be planned")
	assert_false(ManaPlanner.plan(g, 0, cost, 0, ["artifact"]).is_empty(),
		"an artifact spell may have it")


func test_run_plan_taps_what_it_planned() -> void:
	var forests := _lands(0, "Forest", 2)
	var tap_plan := ManaPlanner.plan(g, 0, ManaCost.parse("{G}{G}"), 0)
	ManaPlanner.run_plan(g, 0, tap_plan)
	assert_true(forests[0].tapped and forests[1].tapped)
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 2)


# ------------------------------------------------------------------- X --

func test_max_affordable_x_is_every_source_the_seat_has() -> void:
	# `Duel.hlp`, topic Hands: "If you double-click to auto-cast an X
	# spell, ALL of the mana you have available in your pool and from land
	# sources will be put into that spell."
	_lands(0, "Mountain", 4)
	add_mana(0, Mtg.ManaColor.R, 1)
	var fireball := CardRegistry.get_card("Fireball")
	if fireball == null:
		pass_test("Fireball not in the pool")
		return
	# Fireball is {X}{R}: five mana available, one buys the {R}.
	assert_eq(ManaPlanner.max_affordable_x(g, 0, fireball.cost), 4)


# ------------------------------------- the AI still answers the same way --

func test_the_ai_seat_plans_through_the_moved_planner() -> void:
	_lands(1, "Forest", 2)
	var ai := AiPlayer.new(1, AiProfile.wizard())
	assert_eq(ai._mana_sources(g).size(), 2, "its seat, its sources")
	assert_eq(ai._plan_taps(g, ManaCost.parse("{G}{G}"), 0).size(), 2)
	assert_true(ai._plan_and_pay(g, ManaCost.parse("{G}{G}")),
		"and it can still pay for what it plans")
	assert_eq(g.players[1].mana_pool.total_of(Mtg.ManaColor.G), 2)


# ------------------------------------------------ the engine's queries --

func test_could_afford_prices_against_untapped_lands() -> void:
	# The ROADMAP has wanted this query since the Phase Bar's Done order
	# was written; `Duel.hlp`, topic Hands, is what it has to mean: "you
	# must have enough MANA AVAILABLE … a card in your hand is useable,
	# and therefore will be highlighted as such."
	var bears := give_hand(0, "Grizzly Bears")
	_lands(0, "Forest", 2)
	assert_false(g.can_afford(0, bears.data),
		"nothing is floating, so the OLD question says no")
	assert_true(g.could_afford(0, bears.data),
		"...and the new one says yes, because two Forests are untapped")


func test_could_afford_says_no_when_the_lands_cannot_cover_it() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	_lands(0, "Mountain", 2)
	assert_false(g.could_afford(0, bears.data), "no green anywhere")


func test_could_afford_honours_dont_auto_tap() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	var forests := _lands(0, "Forest", 2)
	assert_true(g.could_afford(0, bears.data))
	assert_false(g.could_afford(0, bears.data, {forests[0].id: true}),
		"one land locked, and {1}{G} is out of reach")


func test_spell_payment_is_what_cast_spell_charges() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	var payment := g.spell_payment(0, bears.data)
	assert_eq(int(payment["extra"]), 0, "no surcharge, no X")
	assert_eq(payment["cost"].text, bears.data.cost.text)
	# ...and a plan built from it really does pay for the cast.
	_lands(0, "Forest", 2)
	advance_to_step(Mtg.Step.MAIN1)
	ManaPlanner.run_plan(g, 0, ManaPlanner.plan(g, 0, payment["cost"],
		int(payment["extra"]), payment["usage"]))
	assert_ok(g.cast_spell(0, bears))


func test_an_x_spells_payment_grows_with_x() -> void:
	var fireball := CardRegistry.get_card("Fireball")
	if fireball == null:
		pass_test("Fireball not in the pool")
		return
	var at0 := g.spell_payment(0, fireball, 0)
	var at3 := g.spell_payment(0, fireball, 3)
	assert_eq(int(at3["extra"]) - int(at0["extra"]), 3,
		"three more generic for X=3")


func test_only_the_mana_refusal_is_an_unpaid_one() -> void:
	# The duel screen holds a cast OPEN on this and only this, so a real
	# refusal can never be mistaken for "you have not paid yet".
	assert_true(MtgGame.is_unpaid_refusal(
		"not enough mana for Grizzly Bears ({1}{G})"))
	assert_true(MtgGame.is_unpaid_refusal("not enough mana ({2})"))
	assert_false(MtgGame.is_unpaid_refusal("you don't have priority"))
	assert_false(MtgGame.is_unpaid_refusal("not enough life to pay 3"))
	assert_false(MtgGame.is_unpaid_refusal(""))


# ---------------------------------- two duals, either pip order (2026-10-03) --
# The coloured pass took, for each pip, the FIRST unused source of its
# colour and never went back: an Underground Sea beside a Volcanic Island
# spent the Sea on {U} and then found no {B}, so `{U}{B}` was refused while
# `{B}{U}` — the same two pips — was paid. The pips are a matching
# (Volcanic for U, Sea for B), and every payment question rode on the
# refusal: `can_afford_cost`, `try_pay` (an "unless you pay" or an upkeep
# cost, answered by a sacrifice), the auto-cast and the AI's own casts.

func _covers(pid: int, cost_text: String) -> bool:
	var cost := ManaCost.parse(cost_text)
	var tap_plan := ManaPlanner.plan(g, pid, cost, 0)
	if tap_plan.is_empty():
		return false
	ManaPlanner.run_plan(g, pid, tap_plan)
	var paid := g.players[pid].mana_pool.can_pay(cost, 0)
	g.players[pid].mana_pool.clear()
	for inst in g.players[pid].battlefield:
		inst.tapped = false
	return paid


func test_two_duals_pay_two_colours_in_either_pip_order() -> void:
	put_battlefield(0, "Underground Sea")
	put_battlefield(0, "Volcanic Island")
	assert_true(_covers(0, "{U}{B}"), "Volcanic for the {U}, the Sea for the {B}")
	assert_true(_covers(0, "{B}{U}"), "the same two pips, read the other way round")
	assert_true(g.can_afford_cost(0, ManaCost.parse("{U}{B}")))
	assert_true(g.can_afford_cost(0, ManaCost.parse("{B}{U}")))
	assert_false(g.can_afford_cost(0, ManaCost.parse("{B}{B}")),
		"...and a cost they really cannot cover is still refused")


func test_tundra_and_scrubland_pay_white_blue_either_way() -> void:
	put_battlefield(0, "Tundra")
	put_battlefield(0, "Scrubland")
	assert_true(_covers(0, "{W}{U}"))
	assert_true(_covers(0, "{U}{W}"))
	# try_pay is what an "unless you pay" and an upkeep cost ask.
	assert_true(g.try_pay(0, ManaCost.parse("{W}{U}")), "try_pay pays it")
	assert_eq(g.players[0].mana_pool.total(), 0, "and spends what it tapped")


func test_the_matching_spends_the_basic_and_spares_the_city() -> void:
	# The matching may re-route a dual, never reach past a basic that pays,
	# nor onto a City of Brass a painless re-route spares: {U}{B}{B} over a
	# Swamp, a Sea and a Volcanic Island is the Swamp and the Sea for the
	# {B}s and the Volcanic for the {U}. The greedy pass got it right only
	# when the Volcanic sorted first; with the Sea first it paid the {U}
	# from the Sea and the second {B} from the City. Both battlefield
	# orders, so whichever way the duals tie the answer is the same.
	for sea_first in [true, false]:
		before_each()
		var swamp := put_battlefield(0, "Swamp")
		var city := put_battlefield(0, "City of Brass")
		if sea_first:
			put_battlefield(0, "Underground Sea")
			put_battlefield(0, "Volcanic Island")
		else:
			put_battlefield(0, "Volcanic Island")
			put_battlefield(0, "Underground Sea")
		var tap_plan := ManaPlanner.plan(g, 0, ManaCost.parse("{U}{B}{B}"), 0)
		assert_eq(tap_plan.size(), 3)
		var tapped: Array = []
		for step in tap_plan:
			tapped.append(step[0])
		assert_true(tapped.has(swamp), "the basic pays (sea first: %s)" % sea_first)
		assert_false(tapped.has(city), "the City is not needed (sea first: %s)" % sea_first)
		ManaPlanner.run_plan(g, 0, tap_plan)
		assert_true(g.players[0].mana_pool.can_pay(ManaCost.parse("{U}{B}{B}"), 0))


func test_floating_mana_and_two_duals_pay_four_pips() -> void:
	# Floating mana is a source like any other in the matching: two {G}
	# already in the pool and a Tundra + Scrubland pay {G}{G}{W}{U} only
	# with the duals re-routed.
	add_mana(0, Mtg.ManaColor.G, 2)
	put_battlefield(0, "Tundra")
	put_battlefield(0, "Scrubland")
	assert_true(_covers(0, "{G}{G}{W}{U}"))


# ------------------------------------- a hasty mana creature (2026-10-03) --

func test_a_summoning_sick_mana_creature_with_haste_is_a_source() -> void:
	# CR 302.6: haste lifts summoning sickness for {T} abilities, mana ones
	# included — MtgGame.tap_for_mana always let the hasty Elves tap; the
	# planner skipped them, so the auto-cast and the AI never would.
	put_battlefield(0, "Concordant Crossroads")
	var elves := put_battlefield(0, "Llanowar Elves", true)
	g.recalculate()
	assert_true(elves.summoning_sick and elves.has_keyword(Mtg.Keyword.HASTE))
	var tap_plan := ManaPlanner.plan(g, 0, ManaCost.parse("{G}"), 0)
	assert_eq(tap_plan.size(), 1, "the hasty Elves pay the {G}")
	ManaPlanner.run_plan(g, 0, tap_plan)
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 1)


func test_a_summoning_sick_mana_creature_without_haste_is_not() -> void:
	put_battlefield(0, "Llanowar Elves", true)
	assert_true(ManaPlanner.plan(g, 0, ManaCost.parse("{G}"), 0).is_empty())
