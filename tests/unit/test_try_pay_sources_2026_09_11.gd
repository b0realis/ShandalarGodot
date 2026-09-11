extends GameTest
## TRIGGERED PAYMENTS REACH EVERY MANA SOURCE — 2026-09-11,
## `MtgGame._payment_plan` / `try_pay` / `can_afford_cost`.
##
## **CR 605.3a**: a player may activate a mana ability whenever they have
## priority, whenever a rule or effect asks them to pay a mana cost, and
## whenever a spell or ability's cost is being paid. An "unless you pay
## {N}" trigger is a rule asking for a payment, so every mana source on
## the table is available to it — not only the lands.
##
## `_payment_plan` scanned `inst.is_land()` and nothing else until today,
## and the reproduction is the prison land of the era killing a creature
## with two mana standing beside it:
##
##   board ["Sol Ring"]:  can_afford_cost({1}) = false  try_pay({1}) = false
##   board ["Mox Emerald", "Mox Ruby"]:  can_afford_cost({1}) = false
##   The Tabernacle at Pendrell Vale, a Sol Ring untapped:
##     Bears zone=3, Sol Ring tapped=false  >> the Bears are DEAD
##
## The plan is now [ManaPlanner]'s — the ONE planner the AI seat and the
## human's own double-click auto-cast already share — so a triggered
## payment cannot tap a different set of sources than a cast of the same
## cost would, and the QUERY (`can_afford_cost`, which hints every "do you
## want to pay?" offer and lights the duel screen's activatable abilities)
## cannot drift from the PAYMENT, because both are the same plan.


## Our next upkeep, passed: their turn, then ours.
func _through_my_next_upkeep() -> void:
	advance_to_next_turn()
	advance_to_next_turn()


func _plan_names(plan: Array) -> Array:
	var out: Array = []
	for step in plan:
		out.append("(floating)" if step[0] == null else String(step[0].data.card_name))
	return out


# ----------------------------------------------- an upkeep off artifacts --

func test_the_tabernacle_tax_is_paid_by_a_sol_ring() -> void:
	# THE REPRODUCTION. The Tabernacle prints no mana ability of its own,
	# so the {1} has exactly one place to come from.
	put_battlefield(0, "The Tabernacle at Pendrell Vale")
	var ring := put_battlefield(0, "Sol Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	_through_my_next_upkeep()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the Bears paid their rent")
	assert_true(ring.tapped, "...and the Sol Ring is what paid it")


func test_the_moxen_pay_a_paralyze() -> void:
	# Four Moxen, four pips, no land on the table at all.
	var host := put_battlefield(0, "Grizzly Bears")
	var moxen: Array[CardInstance] = []
	for name in ["Mox Emerald", "Mox Ruby", "Mox Jet", "Mox Pearl"]:
		moxen.append(put_battlefield(0, name))
	var aura := give_hand(1, "Paralyze")
	g.attach_aura_from_anywhere(aura, host, 1)
	g.tap_permanent(host)
	g.recalculate()
	assert_true(host.tapped)
	_through_my_next_upkeep()
	assert_false(host.tapped, "the {4} bought the untap back")
	for mox in moxen:
		assert_true(mox.tapped, "%s paid its pip" % mox.data.card_name)


func test_a_mana_creature_pays_too() -> void:
	# CR 605.3a names the ABILITY, not the card type: four Llanowar Elves
	# are four mana abilities like any other.
	var host := put_battlefield(0, "Grizzly Bears")
	for _i in 4:
		put_battlefield(0, "Llanowar Elves")
	var aura := give_hand(1, "Paralyze")
	g.attach_aura_from_anywhere(aura, host, 1)
	g.tap_permanent(host)
	g.recalculate()
	_through_my_next_upkeep()
	assert_false(host.tapped, "the Elves paid the {4}")


# ------------------------------------------------------------- the mix --

func test_an_upkeep_paid_off_a_mix_of_lands_and_artifacts() -> void:
	# Two Forests and a Sol Ring are four mana; two Forests alone are two,
	# which is what this board could reach until today.
	var host := put_battlefield(0, "Grizzly Bears")
	var first := put_battlefield(0, "Forest")
	var second := put_battlefield(0, "Forest")
	var ring := put_battlefield(0, "Sol Ring")
	var aura := give_hand(1, "Paralyze")
	g.attach_aura_from_anywhere(aura, host, 1)
	g.tap_permanent(host)
	g.recalculate()
	_through_my_next_upkeep()
	assert_false(host.tapped, "{4} off two lands and a Ring")
	assert_true(first.tapped and second.tapped and ring.tapped,
		"all three were spent")


func test_floating_mana_is_still_the_first_seed() -> void:
	# `ManaPlanner.sources` counts each floating unit as a zero-cost source
	# with a null instance, exactly the way this method's own simulation
	# used to seed itself — and `try_pay` skips those steps rather than
	# trying to tap them.
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_true(g.can_afford_cost(0, ManaCost.parse("{2}")))
	assert_eq(_plan_names(g._payment_plan(0, ManaCost.parse("{2}"))),
		["(floating)", "(floating)"])
	assert_true(g.try_pay(0, ManaCost.parse("{2}")))
	assert_eq(g.players[0].mana_pool.total(), 0, "spent, not doubled")


func test_floating_mana_first_and_the_source_for_the_rest() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	add_mana(0, Mtg.ManaColor.G)
	assert_true(g.can_afford_cost(0, ManaCost.parse("{3}")))
	assert_true(g.try_pay(0, ManaCost.parse("{3}")))
	assert_true(ring.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_coloured_pip_still_comes_from_the_colour_that_has_it() -> void:
	# The Mox makes {U}; the Ring's two colourless cover the generic.
	var mox := put_battlefield(0, "Mox Sapphire")
	var ring := put_battlefield(0, "Sol Ring")
	assert_true(g.can_afford_cost(0, ManaCost.parse("{2}{U}")))
	assert_true(g.try_pay(0, ManaCost.parse("{2}{U}")))
	assert_true(mox.tapped and ring.tapped)


# ------------------------------------------------------- the refusals --

func test_the_payment_is_refused_when_the_mana_is_not_there() -> void:
	# A Rod of Ruin is an artifact with no mana ability: the Tabernacle
	# collects, and this is the answer that must NOT have changed.
	put_battlefield(0, "The Tabernacle at Pendrell Vale")
	put_battlefield(0, "Rod of Ruin")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_false(g.can_afford_cost(0, ManaCost.parse("{1}")))
	assert_false(g.try_pay(0, ManaCost.parse("{1}")))
	_through_my_next_upkeep()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "nothing could pay the {1}")


func test_a_tapped_source_is_not_a_source() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	g.tap_permanent(ring)
	assert_false(g.can_afford_cost(0, ManaCost.parse("{1}")))


func test_a_summoning_sick_mana_creature_is_not_a_source() -> void:
	# CR 302.6 gates the {T}, and the plan must not spend what the engine
	# will refuse (`tap_for_mana`) once the pips are half paid.
	put_battlefield(0, "Llanowar Elves", true)
	assert_false(g.can_afford_cost(0, ManaCost.parse("{G}")))


func test_restricted_mana_still_cannot_pay_an_upkeep() -> void:
	# CR 106.6: "Spend this mana only to cast artifact spells". An upkeep
	# tax is not a spell, so the Workshop's three are not available to it.
	if CardRegistry.get_card("Mishra's Workshop") == null:
		pass_test("Mishra's Workshop not in the pool")
		return
	put_battlefield(0, "Mishra's Workshop")
	assert_false(g.can_afford_cost(0, ManaCost.parse("{1}")))
	assert_false(g.try_pay(0, ManaCost.parse("{1}")))
	assert_eq(g.players[0].mana_pool.total(), 0, "and nothing was tapped for it")


# ---------------------------------------- the two shapes that would ASK --

func test_a_source_that_would_ask_is_left_out_of_the_plan() -> void:
	# A mid-trigger payment has no way to hold a duel open for a question:
	# the COST hold re-issues the mana ability ALONE and the resolution it
	# was nested in would be lost. Proven at the site — `tap_for_mana` on a
	# Fellwar Stone returns "" with `awaiting_choice` set and NO mana made:
	#
	#   tap_for_mana -> ''
	#   awaiting_choice = Fellwar Stone: What kind of mana?
	#   stone tapped = false ; pool = []
	#
	# So `_payment_plan` drops it, and the cost is under-reported rather
	# than half-paid.
	if CardRegistry.get_card("Fellwar Stone") == null:
		pass_test("Fellwar Stone not in the pool")
		return
	put_battlefield(0, "Fellwar Stone")
	put_battlefield(1, "Forest")          # a colour for it to offer
	assert_false(g.can_afford_cost(0, ManaCost.parse("{1}")),
		"the colour choice keeps it out of a triggered payment")
	# ...and it is THIS method's rule, not the planner's: the shared
	# planner still reaches the Stone for a cast.
	assert_eq(_plan_names(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)),
		["Fellwar Stone"])


func test_a_charged_battery_is_left_out_and_an_empty_one_is_not() -> void:
	# "Remove any number of charge counters" is announced with the
	# activation (CR 601.2b), so a CHARGED battery asks "how many" and a
	# bare one asks nothing at all.
	if CardRegistry.get_card("Blue Mana Battery") == null:
		pass_test("Blue Mana Battery not in the pool")
		return
	var battery := put_battlefield(0, "Blue Mana Battery")
	assert_true(g.can_afford_cost(0, ManaCost.parse("{1}")),
		"no counters, no question")
	battery.counters["charge"] = 2
	assert_false(g.can_afford_cost(0, ManaCost.parse("{1}")),
		"a charged battery would ask how many to spend")


# ------------------------------------------------- the order, and a cost --

func test_the_sacrifice_source_is_still_last() -> void:
	# `ManaPlanner.cheapest_source_first` sorts a source that eats itself
	# below everything else, so a Forest beside a Black Lotus pays the pip
	# and the Lotus is still on the table.
	if CardRegistry.get_card("Black Lotus") == null:
		pass_test("Black Lotus not in the pool")
		return
	var lotus := put_battlefield(0, "Black Lotus")
	var forest := put_battlefield(0, "Forest")
	assert_true(g.try_pay(0, ManaCost.parse("{1}")))
	assert_true(forest.tapped)
	assert_eq(lotus.zone, Mtg.Zone.BATTLEFIELD, "the Lotus was not cracked")


func test_the_sacrifice_source_is_reached_when_nothing_else_is() -> void:
	# ...and it IS reached, which is a behaviour change worth stating: the
	# Lotus is artifact mana too (CR 605.3a), the payer said yes to the
	# offer, and the planner had nowhere else to go.
	if CardRegistry.get_card("Black Lotus") == null:
		pass_test("Black Lotus not in the pool")
		return
	put_battlefield(0, "The Tabernacle at Pendrell Vale")
	var lotus := put_battlefield(0, "Black Lotus")
	var bear := put_battlefield(0, "Grizzly Bears")
	_through_my_next_upkeep()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the Bears live")
	assert_eq(lotus.zone, Mtg.Zone.GRAVEYARD, "...and the Lotus paid for it")


func test_a_painful_source_is_planned_after_a_painless_one() -> void:
	if CardRegistry.get_card("City of Brass") == null:
		pass_test("City of Brass not in the pool")
		return
	var city := put_battlefield(0, "City of Brass")
	var ring := put_battlefield(0, "Sol Ring")
	assert_true(g.try_pay(0, ManaCost.parse("{1}")))
	assert_true(ring.tapped, "the Ring costs nothing to tap")
	assert_false(city.tapped)


# -------------------------------------- the query and the payment agree --

func test_the_query_and_the_payment_never_disagree() -> void:
	# `can_afford_cost` is the QUERY behind every "do you want to pay?"
	# hint and the duel screen's activatable-ability highlight; `try_pay`
	# is the EXECUTION. They are the same plan, and a board that says yes
	# must be a board that pays.
	var boards: Array = [
		["Sol Ring"], ["Mox Emerald", "Mox Ruby"], ["Forest", "Sol Ring"],
		["Rod of Ruin"], ["Basalt Monolith"], ["Mana Crypt"], [],
	]
	for cost_text in ["{1}", "{2}", "{3}", "{G}"]:
		for board in boards:
			before_each()
			for name in board:
				put_battlefield(0, name)
			var cost := ManaCost.parse(cost_text)
			var said := g.can_afford_cost(0, cost)
			assert_eq(g.try_pay(0, cost), said,
				"%s for %s" % [board, cost_text])
