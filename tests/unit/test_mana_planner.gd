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
