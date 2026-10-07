extends GameTest
## THE SHARED MANA PLANNER PAYS EVERY BILL WITH THE LEAST LEFT OVER
## (whole-game campaign, 2026-10-07 — `engine/mana_planner.gd`,
## `MtgGame.try_pay`). The planner is the AI's, the human's double-click
## auto-cast's and the engine's own "you may pay" payer at once, so every
## test here is a test of all three.
##
## w6-1: the size of a source was no key of the planner's order. A Sol Ring
## paid a one-drop beside an untapped Mountain and a Mana Vault paid an
## Icy Manipulator's {1} beside an Island — and under mana burn (the
## shipped default preset, and 1997's) the rest burned: 392 life in 300
## tournament-deck duels.
##
## w1-1: the bonus of a mana trigger (Mana Flare, Wild Growth, Gauntlet of
## Might) was unknown to every plan, so a Hill Giant tapped four Mountains
## under a Flare, made eight red and burned four. The run now stops once
## the pool covers the bill, and a trigger that DESCRIBES its bonus — for
## any land, or for its own enchanted land, in the colour the land made —
## is counted by the plan itself.
##
## w1-2: a land under a "whenever enchanted land becomes tapped" Aura
## (Psychic Venom, Blight, Kudzu) was tapped first while plain lands stood
## untapped.

const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G
const U := Mtg.ManaColor.U


func _names(tap_plan: Array) -> Array:
	var out: Array = []
	for step in tap_plan:
		out.append("(floating)" if step[0] == null else (step[0] as CardInstance).data.card_name)
	out.sort()
	return out


func _tapped(pid: int, card_name: String) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == card_name and inst.tapped:
			n += 1
	return n


func _made(tap_plan: Array, src: Array) -> int:
	var made := 0
	for step in tap_plan:
		for s in src:
			if s[0] == step[0] and int(s[1]) == int(step[1]):
				made += int(s[3])
				break
	return made


## "Whenever a player taps a land for mana, that player adds one mana of
## any type that land produced" — DESCRIBED: any land, the land's colour.
static func _flare() -> CardData:
	var trigger := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _flare_mana,
		"Whenever a player taps a land for mana, that player adds one mana of any type that land produced.") \
		.as_mana_trigger()
	trigger.mana_bonus_subtype = ManaPlanner.BONUS_ANY_LAND
	trigger.mana_bonus_color = 0
	trigger.mana_bonus_amount = 1
	return CardData.new("Test Flare", "{2}{R}", Mtg.CardType.ENCHANTMENT).triggered(trigger)


static func _flare_mana(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	game.players[int(event.data["player"])].mana_pool.add(int(event.data["color"]), 1)


## "Enchant land. Whenever enchanted land is tapped for mana, its
## controller adds an additional {G}" — DESCRIBED: the enchanted land, {G}.
static func _growth() -> CardData:
	var trigger := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _growth_mana,
		"Whenever enchanted land is tapped for mana, its controller adds an additional {G}.",
		_host_tapped).as_mana_trigger()
	trigger.mana_bonus_subtype = ManaPlanner.BONUS_ENCHANTED_LAND
	trigger.mana_bonus_color = G
	trigger.mana_bonus_amount = 1
	return CardData.new("Test Growth", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
			func(inst: CardInstance) -> bool: return inst.is_land())) \
		.triggered(trigger)


static func _host_tapped(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return source.attached_to != -1 and event.data["instance"].id == source.attached_to


static func _growth_mana(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	game.players[int(event.data["controller"])].mana_pool.add(G, 1)


func _enchant(host: CardInstance, data: CardData, controller: int) -> CardInstance:
	var aura := CardInstance.new(data, g._next_instance_id, controller)
	g._next_instance_id += 1
	g._instances[aura.id] = aura
	g.attach_aura_from_anywhere(aura, host, controller)
	g.recalculate()
	return aura


func _enchant_with(host: CardInstance, card_name: String, controller: int) -> CardInstance:
	var aura := _make_instance(controller, card_name)
	g.attach_aura_from_anywhere(aura, host, controller)
	g.recalculate()
	return aura


# ============================== w6-1: the least surplus ==============================

func test_a_one_drop_is_paid_with_the_mountain_not_the_sol_ring() -> void:
	# Both battlefield orders: the Ring first was the order that burned.
	for ring_first in [true, false]:
		before_each()
		if ring_first:
			put_battlefield(0, "Sol Ring")
		put_battlefield(0, "Mountain")
		if not ring_first:
			put_battlefield(0, "Sol Ring")
		assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)), ["Mountain"],
			"ring first: %s" % ring_first)


func test_a_two_drop_takes_the_sol_ring_alone_not_a_mountain_and_the_ring() -> void:
	for ring_first in [true, false]:
		before_each()
		if ring_first:
			put_battlefield(0, "Sol Ring")
		put_battlefield(0, "Mountain")
		if not ring_first:
			put_battlefield(0, "Sol Ring")
		assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{2}"), 0)), ["Sol Ring"],
			"two exactly, from one tap (ring first: %s)" % ring_first)


func test_the_mana_vault_waits_while_an_island_covers_the_cost() -> void:
	var vault := put_battlefield(0, "Mana Vault")
	put_battlefield(0, "Island")
	g.recalculate()
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)), ["Island"])
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{U}"), 0)), ["Island"])
	# {3}: the Vault alone is three exactly — the Island would only float.
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{3}"), 0)), ["Mana Vault"])
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{4}"), 0)), ["Island", "Mana Vault"])
	assert_true(vault.cur_skips_untap, "the Vault is the source that stays tapped")


func test_a_source_that_does_not_untap_sorts_after_a_painful_one() -> void:
	# A City of Brass costs a life; a Mana Vault costs its untap, {4} and a
	# life every draw step it stays tapped.
	put_battlefield(0, "Basalt Monolith")
	put_battlefield(0, "City of Brass")
	g.recalculate()
	var src := ManaPlanner.sources(g, 0)
	assert_eq((src.back()[0] as CardInstance).data.card_name, "Basalt Monolith")
	assert_eq(ManaPlanner.source_rank(src.back()), ManaPlanner.RANK_STAYS_TAPPED)
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)), ["City of Brass"])


func test_the_least_surplus_cover_mixes_the_sizes() -> void:
	# Four from a Mountain, a Sol Ring and a Mana Vault: the Mountain and
	# the Vault are four exactly; the Ring and the Vault would float one.
	put_battlefield(0, "Mana Vault")
	put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Mountain")
	g.recalculate()
	var src := ManaPlanner.sources(g, 0)
	var tap_plan := ManaPlanner.plan_from(src, ManaCost.parse("{4}"), 0)
	assert_eq(_made(tap_plan, src), 4, "nothing left over: %s" % [_names(tap_plan)])
	# {3} without the Vault's help: the Ring and the Mountain.
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{3}"), 0)), ["Mountain", "Sol Ring"])


func test_mishras_workshop_pays_three_and_leaves_a_one_drop_to_the_mountain() -> void:
	put_battlefield(0, "Mishra's Workshop")
	put_battlefield(0, "Mountain")
	var artifact := ["artifact"]
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0, artifact)), ["Mountain"])
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{3}"), 0, artifact)),
		["Mishra's Workshop"])


func test_the_urza_lands_pay_what_they_make_and_no_more() -> void:
	put_battlefield(0, "Urza's Tower")
	put_battlefield(0, "Urza's Mine")
	put_battlefield(0, "Urza's Power Plant")
	put_battlefield(0, "Island")
	var src := ManaPlanner.sources(g, 0)
	for cost_text in ["{1}", "{2}", "{3}", "{4}", "{5}"]:
		var tap_plan := ManaPlanner.plan_from(src, ManaCost.parse(cost_text), 0)
		assert_eq(_made(tap_plan, src), ManaCost.parse(cost_text).mana_value(),
			"%s paid exactly: %s" % [cost_text, _names(tap_plan)])


func test_the_lotus_is_still_last_and_still_reached() -> void:
	put_battlefield(0, "Black Lotus")
	put_battlefield(0, "Island")
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{U}"), 0)), ["Island"])
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{3}"), 0)), ["Black Lotus"],
		"three from the Lotus alone, the Island's one would float")
	# A Stasis' {1}{U} with nothing but the Lotus for the {1}: the Lotus is
	# cracked either way, so it makes BLUE and pays the whole cost — one
	# left over instead of two, and the Island still untapped.
	var lotus: CardInstance = g.players[0].battlefield[0]
	assert_eq(ManaPlanner.plan(g, 0, ManaCost.parse("{1}{U}"), 0), [[lotus, 1]])


func test_floating_mana_is_spent_before_any_tap() -> void:
	put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Mountain")
	add_mana(0, G, 1)
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{2}"), 0)), ["(floating)", "Mountain"])
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{3}"), 0)), ["(floating)", "Sol Ring"])


func test_the_query_and_the_payment_still_agree() -> void:
	var boards: Array = [
		["Sol Ring", "Mountain"], ["Mana Vault", "Island"], ["Black Lotus", "Forest"],
		["Mishra's Workshop", "Sol Ring"], ["Basalt Monolith", "City of Brass"],
	]
	for cost_text in ["{1}", "{2}", "{3}", "{G}", "{1}{U}", "{5}"]:
		for board in boards:
			before_each()
			for card_name in board:
				put_battlefield(0, card_name)
			var cost := ManaCost.parse(cost_text)
			var said := g.can_afford_cost(0, cost)
			assert_eq(g.try_pay(0, cost), said, "%s for %s" % [board, cost_text])


func test_try_pay_burns_nothing_for_a_one_with_a_mountain_beside_the_ring() -> void:
	g.rules.set_preset("modern_mana_burn")
	var ring := put_battlefield(0, "Sol Ring")
	var mountain := put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(g.try_pay(0, ManaCost.parse("{1}")))
	assert_true(mountain.tapped)
	assert_false(ring.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)


# ============================ the coloured half of w6-1 ============================

func test_a_plain_forest_pays_g_before_a_forest_that_makes_two() -> void:
	var plain := put_battlefield(0, "Forest")
	var grown := put_battlefield(0, "Forest")
	_enchant(grown, _growth(), 0)
	# Both battlefield orders.
	for first in [grown, plain]:
		g.players[0].battlefield.erase(first)
		g.players[0].battlefield.push_front(first)
		assert_eq(ManaPlanner.plan(g, 0, ManaCost.parse("{G}"), 0), [[plain, 0]],
			"{G}: the plain Forest")
		assert_eq(ManaPlanner.plan(g, 0, ManaCost.parse("{1}{G}"), 0), [[grown, 0]],
			"{1}{G}: the grown Forest alone makes {G}{G}")


func test_two_colours_take_the_source_that_fits_first() -> void:
	# The matching (two colours or more) keeps the same rule.
	put_battlefield(0, "Island")
	var grown := put_battlefield(0, "Forest")
	var plain := put_battlefield(0, "Forest")
	_enchant(grown, _growth(), 0)
	g.players[0].battlefield.erase(grown)
	g.players[0].battlefield.push_front(grown)
	var tap_plan := ManaPlanner.plan(g, 0, ManaCost.parse("{G}{U}"), 0)
	assert_eq(tap_plan.size(), 2)
	assert_true(tap_plan.has([plain, 0]) and not tap_plan.has([grown, 0]),
		"the plain Forest pays the {G}")


# ============================== w1-1: bonus mana ==============================

func test_a_described_any_land_bonus_doubles_every_land_in_its_own_colour() -> void:
	put_synthetic(1, _flare())
	var mountain := put_battlefield(0, "Mountain")
	var taiga := put_battlefield(0, "Taiga")
	for s in ManaPlanner.sources(g, 0):
		assert_eq(int(s[3]), 2, "%s for %s" % [(s[0] as CardInstance).data.card_name,
			Mtg.COLOR_NAMES[int(s[2])]])
	assert_ok(g.tap_for_mana(0, mountain))
	assert_eq(g.players[0].mana_pool.amount_of(R), 2, "and the tap makes what the plan priced")
	assert_ok(g.tap_for_mana(0, taiga, 1))
	assert_eq(g.players[0].mana_pool.amount_of(G), 2)


func test_hill_giant_under_a_described_flare_plans_two_mountains() -> void:
	put_synthetic(0, _flare())
	for _i in 4:
		put_battlefield(0, "Mountain")
	var hill_giant := CardRegistry.get_card("Hill Giant")
	assert_eq(ManaPlanner.plan(g, 0, hill_giant.cost, 0).size(), 2)
	# ...and Fireball counts the bonus: eight red, one for the {R}.
	assert_eq(ManaPlanner.max_affordable_x(g, 0, CardRegistry.get_card("Fireball").cost), 7)
	# Force of Nature's {2}{G}{G}{G}{G} from three Forests is castable now.
	before_each()
	put_synthetic(0, _flare())
	for _i in 3:
		put_battlefield(0, "Forest")
	assert_false(ManaPlanner.plan(g, 0, CardRegistry.get_card("Force of Nature").cost, 0).is_empty())


func test_an_enchanted_land_bonus_is_its_hosts_only() -> void:
	var host := put_battlefield(0, "Forest")
	var other := put_battlefield(0, "Forest")
	var aura := _enchant(host, _growth(), 1)   # the other seat's Aura still feeds the host's controller
	for s in ManaPlanner.sources(g, 0):
		assert_eq(int(s[3]), 2 if s[0] == host else 1)
	assert_eq(ManaPlanner.max_affordable_x(g, 0, ManaCost.parse("{X}")), 3)
	# A land of another colour under it makes two colours at once: the row
	# carries both, as the tap does.
	g.move_aura(aura, put_battlefield(0, "Island"))
	g.recalculate()
	assert_eq(ManaPlanner.max_affordable_x(g, 0, ManaCost.parse("{X}")), 4)
	assert_false(ManaPlanner.plan(g, 0, ManaCost.parse("{G}{G}{G}"), 0).is_empty(),
		"two Forests and the Island's green")
	for s in ManaPlanner.sources(g, 0):
		if s[0] == other:
			assert_eq(int(s[3]), 1, "the Forest it left makes one again")


func test_run_plan_stops_once_the_pool_covers_the_bill() -> void:
	# The REAL Mana Flare, described or not: a plan for four Mountains is
	# run against the bill and stops at two.
	put_battlefield(0, "Mana Flare")
	var mountains: Array = []
	for _i in 4:
		mountains.append(put_battlefield(0, "Mountain"))
	var tap_plan: Array = []
	for m in mountains:
		tap_plan.append([m, 0])
	var bill := CardRegistry.get_card("Hill Giant").cost
	assert_true(ManaPlanner.run_plan(g, 0, tap_plan, bill))
	assert_eq(_tapped(0, "Mountain"), 2)
	assert_eq(g.players[0].mana_pool.amount_of(R), 4)
	# Without a bill every step runs, as before.
	before_each()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	assert_true(ManaPlanner.run_plan(g, 0, ManaPlanner.plan(g, 0, ManaCost.parse("{G}{G}"), 0)))
	assert_eq(_tapped(0, "Forest"), 2)


func test_plan_and_pay_under_mana_flare_floats_nothing_extra() -> void:
	put_battlefield(1, "Mana Flare")
	for _i in 4:
		put_battlefield(0, "Mountain")
	var bill := CardRegistry.get_card("Hill Giant").cost
	assert_true(ManaPlanner.plan_and_pay(g, 0, bill))
	assert_eq(_tapped(0, "Mountain"), 2)
	assert_eq(g.players[0].mana_pool.total(), 4, "exactly the bill")


func test_try_pay_under_mana_flare_taps_only_what_the_cost_needs() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		put_battlefield(1, "Mana Flare")
		for _i in 4:
			put_battlefield(0, "Mountain")
		advance_to_step(Mtg.Step.MAIN1)
		assert_true(g.try_pay(0, ManaCost.parse("{4}")))
		assert_eq(_tapped(0, "Mountain"), 2, preset)
		assert_eq(g.players[0].mana_pool.total(), 0, preset)
		advance_to_step(Mtg.Step.COMBAT_BEGIN)
		assert_eq(g.players[0].life, 20, "%s: nothing burned" % preset)


# ============================== w1-2: tap tolls ==============================

func test_a_land_under_a_hostile_tap_aura_is_tapped_last() -> void:
	for aura_name in ["Psychic Venom", "Blight", "Kudzu"]:
		before_each()
		var cursed := put_battlefield(0, "Forest")
		put_battlefield(0, "Forest")
		put_battlefield(0, "Forest")
		_enchant_with(cursed, aura_name, 1)
		var src := ManaPlanner.sources(g, 0)
		assert_eq(src.back()[0], cursed, aura_name)
		assert_eq(ManaPlanner.source_rank(src.back()), ManaPlanner.RANK_TAP_TOLL, aura_name)
		var tap_plan := ManaPlanner.plan_from(src, ManaCost.parse("{1}{G}"), 0)
		assert_eq(tap_plan.size(), 2, aura_name)
		assert_false(tap_plan.has([cursed, 0]), "%s: two plain Forests pay {1}{G}" % aura_name)
		# ...and it is still a source when the cost needs it.
		assert_eq(ManaPlanner.plan_from(src, ManaCost.parse("{G}{G}{G}"), 0).size(), 3, aura_name)


func test_the_tolled_land_goes_after_a_city_of_brass_and_a_mana_vault() -> void:
	var cursed := put_battlefield(0, "Forest")
	_enchant_with(cursed, "Psychic Venom", 1)
	put_battlefield(0, "City of Brass")
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)), ["City of Brass"])
	before_each()
	cursed = put_battlefield(0, "Forest")
	_enchant_with(cursed, "Blight", 1)
	put_battlefield(0, "Mana Vault")
	g.recalculate()
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{1}"), 0)), ["Mana Vault"],
		"a Vault's untap is worth less than the Blighted land")


func test_try_pay_spares_the_venomed_land() -> void:
	var cursed := put_battlefield(0, "Forest")
	var plain := put_battlefield(0, "Forest")
	_enchant_with(cursed, "Psychic Venom", 1)
	assert_true(g.try_pay(0, ManaCost.parse("{1}")))
	assert_true(plain.tapped)
	assert_false(cursed.tapped)
	resolve_stack()
	assert_eq(g.players[0].life, 20)


func test_an_artifact_under_relic_bind_is_tolled_too() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	_enchant_with(ring, "Relic Bind", 1)
	assert_eq(_names(ManaPlanner.plan(g, 0, ManaCost.parse("{2}"), 0)), ["Mountain", "Mountain"])


func test_a_friendly_mana_aura_is_no_toll() -> void:
	var host := put_battlefield(0, "Forest")
	_enchant_with(host, "Wild Growth", 0)
	for s in ManaPlanner.sources(g, 0):
		assert_eq(ManaPlanner.source_rank(s), 0)
