extends GameTest
## THE PLANNER'S TIE-BREAK — 2026-09-11, `engine/mana_planner.gd`.
##
## Among sources that pay a cost equally the planner took them in
## BATTLEFIELD ORDER, so a Mishra's Factory, a Library of Alexandria or a
## Strip Mine played before the basics paid the generic pip and the option
## it was holding went with it. The reproduction is three refusals, each
## of them the engine's own words, all of them on a board with a Forest
## standing untapped beside the land that got spent:
##
##   plan for {1}: Mishra's Factory
##   Mishra's Factory can't attack: tapped creatures can't attack
##   plan for {1}: Library of Alexandria
##   Library of Alexandria is already tapped
##   plan for {1}: Strip Mine
##   Strip Mine is already tapped
##
## It is an ENGINE change and not a knob: every rung plans through this
## file, and so does the human seat's double-click auto-cast
## (`DuelScreen._auto_tap_for_pending`). So the rule is read as a SHAPE
## and never as a card name — [method ManaPlanner.holds_untapped], the
## {T} another ability has already spoken for (CR 107.5) and the body an
## animation would buy (CR 508.1a, CR 509.1a).


func _cards_of(plan: Array) -> Array:
	var out: Array = []
	for step in plan:
		out.append("(floating)" if step[0] == null else String(step[0].data.card_name))
	return out


# ------------------------------------------------- the reading, as a shape --

func test_a_plain_land_holds_nothing_back() -> void:
	var forest := put_battlefield(0, "Forest")
	assert_eq(ManaPlanner.holds_untapped(forest), 0)
	# ...and so does a mana rock whose only line is the mana.
	if CardRegistry.get_card("Sol Ring") != null:
		assert_eq(ManaPlanner.holds_untapped(put_battlefield(0, "Sol Ring")), 0)


func test_the_tap_another_ability_has_spoken_for() -> void:
	# One tap to spend (CR 107.5): the draw and the mana want the same one.
	assert_eq(ManaPlanner.holds_untapped(put_battlefield(0, "Library of Alexandria")), 1)
	assert_eq(ManaPlanner.holds_untapped(put_battlefield(0, "Strip Mine")), 1)
	# A Desert's shot at an attacker is the same shape on a common land.
	assert_eq(ManaPlanner.holds_untapped(put_battlefield(0, "Desert")), 1)


func test_the_body_an_animation_would_buy() -> void:
	# Mishra's Factory prints BOTH shapes: "{T}: target Assembly-Worker
	# gets +1/+1" is the tap, "{1}: becomes a 2/2" is the body — and the
	# animation carries no tap at all, which is why the {T} reading alone
	# would have priced the Factory for the wrong ability.
	assert_eq(ManaPlanner.holds_untapped(put_battlefield(0, "Mishra's Factory")), 2)


func test_a_mana_creature_is_not_read_here() -> void:
	# A Llanowar Elves is worth something untapped too, and that is the
	# AI's combat reading (`AiPlayer._attackers_excluded`,
	# `_main2_mana_held`) rather than the planner's sort.
	assert_eq(ManaPlanner.holds_untapped(put_battlefield(0, "Llanowar Elves")), 0)


# ------------------------------------------------- what the plan does now --

func test_the_forest_pays_before_the_factory() -> void:
	# THE REPRODUCTION, in battlefield order: the Factory is played first.
	var factory := put_battlefield(0, "Mishra's Factory")
	var forest := put_battlefield(0, "Forest")
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)
	assert_eq(_cards_of(plan), ["Forest"], "the basic pays the generic pip")
	ManaPlanner.run_plan(g, 0, plan)
	assert_false(factory.tapped, "the Factory is still a body to animate")
	assert_true(forest.tapped)


func test_the_forest_pays_before_the_library() -> void:
	var lib := put_battlefield(0, "Library of Alexandria")
	put_battlefield(0, "Forest")
	for i in 7:
		give_hand(0, "Forest")
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)
	assert_eq(_cards_of(plan), ["Forest"])
	ManaPlanner.run_plan(g, 0, plan)
	# The draw the old order refused with "already tapped" is available.
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, lib, 0, []))


func test_the_forest_pays_before_the_strip_mine() -> void:
	var mine := put_battlefield(0, "Strip Mine")
	put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Forest")
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)
	assert_eq(_cards_of(plan), ["Forest"])
	ManaPlanner.run_plan(g, 0, plan)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, mine, 0, [TargetRef.card(theirs)]))


func test_the_utility_land_is_still_reached_when_the_cost_needs_it() -> void:
	# A tie-break ORDERS the sources; it never removes one. Two pips with
	# one Forest on the table still plans the Strip Mine in — second.
	put_battlefield(0, "Strip Mine")
	put_battlefield(0, "Forest")
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{2}"), 0)
	assert_eq(_cards_of(plan), ["Forest", "Strip Mine"])


func test_the_coloured_pip_still_comes_from_the_colour_that_has_it() -> void:
	# The colour loop runs first and is untouched: the Forest buys the {G}
	# and the generic falls to the second basic, not to the Factory.
	put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var plan := _cards_of(ManaPlanner.plan(g, 0, ManaCost.parse("{1}{G}"), 0))
	assert_eq(plan.size(), 2)
	assert_false(plan.has("Mishra's Factory"), "two Forests cover it: %s" % [plan])


# ----------------------------------------- the keys above it do not move --

func test_the_basic_still_comes_before_the_dual() -> void:
	# `source_options` is still the key above the tie-break, so a Library
	# beside a lone Tundra is STILL spent first — the dual's flexibility
	# wins, which is the case this pass left open on purpose.
	if CardRegistry.get_card("Tundra") == null:
		pass_test("Tundra not in the pool")
		return
	put_battlefield(0, "Tundra")
	var lib := put_battlefield(0, "Library of Alexandria")
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)
	assert_eq(_cards_of(plan), ["Library of Alexandria"])
	assert_false(lib.tapped, "planned, not yet run")


func test_the_painful_source_is_still_last() -> void:
	# A City of Brass has no other ability, so the tie-break says nothing
	# about it and the pain key still does: the Library goes first.
	if CardRegistry.get_card("City of Brass") == null:
		pass_test("City of Brass not in the pool")
		return
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "Library of Alexandria")
	assert_eq(_cards_of(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)),
		["Library of Alexandria"])


func test_a_sacrifice_source_is_still_last_of_all() -> void:
	# Two utility lands against a source that eats itself: the sacrifice
	# key outranks everything the tie-break says.
	if CardRegistry.get_card("Black Lotus") == null:
		pass_test("Black Lotus not in the pool")
		return
	put_battlefield(0, "Black Lotus")
	put_battlefield(0, "Strip Mine")
	assert_eq(_cards_of(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)),
		["Strip Mine"])


# ------------------------------------------------------ the seats, both --

func test_every_rung_leaves_the_factory_up() -> void:
	# The reproduction ran at all four: Apprentice to Wizard, the pilot
	# cast its Grizzly Bears with the Factory paying the {1}. This is an
	# engine change, so the fix is at all four too.
	for profile in [AiProfile.apprentice(), AiProfile.magician(),
			AiProfile.sorcerer(), AiProfile.wizard()]:
		before_each()
		var factory := put_battlefield(0, "Mishra's Factory")
		put_battlefield(0, "Forest")
		put_battlefield(0, "Forest")
		give_hand(0, "Grizzly Bears")
		put_battlefield(1, "Grizzly Bears")
		advance_to_step(Mtg.Step.MAIN1)
		var ai := AiPlayer.new(0, profile)
		var guard := 0
		while guard < 8 and not factory.tapped:
			if ai.act(g) == "":
				break
			guard += 1
		assert_eq(g.players[0].hand.size(), 0,
			"%s cast the Bears at all" % profile.profile_name)
		assert_false(factory.tapped,
			"%s spent the Factory on the Bears" % profile.profile_name)


func test_the_human_double_click_taps_the_basic() -> void:
	# The human seat's auto-cast plans through the same file
	# (`DuelScreen._auto_tap_for_pending` -> `ManaPlanner.plan`), so a
	# player double-clicking a spell keeps their Library of Alexandria.
	# Asked here the way the screen asks it: the engine's own payment.
	var lib := put_battlefield(0, "Library of Alexandria")
	var forest := put_battlefield(0, "Forest")
	var second := put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var payment := g.spell_payment(0, bears.data, 0, 1)
	var plan := ManaPlanner.plan(g, 0, payment["cost"], int(payment["extra"]),
		payment["usage"])
	ManaPlanner.run_plan(g, 0, plan)
	assert_true(forest.tapped and second.tapped, "the two Forests paid {1}{G}")
	assert_false(lib.tapped, "...and the Library is still the player's to use")
