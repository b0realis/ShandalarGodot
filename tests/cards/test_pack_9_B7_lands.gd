extends GameTest
## Pack 9 (the Tempest block), batch B7: the Tempest lands and mana sources
## in cards/sets/tmp/_lands_mana.gd — Ancient Tomb, Blood Pet, the five
## painlands (Caldera Lake, Pine Barrens, Salt Flats, Scabland, Skyshroud
## Forest), the five slow duals (Cinder Marsh, Mogg Hollows, Rootwater
## Depths, Thalakos Lowlands, Vec Townships), Eladamri's Vineyard, Ghost
## Town, Lotus Petal, Manakin, Reflecting Pool, Skyshroud Elf, Stalking
## Stones and Wasteland. Each card: it is not pending, its main effect, a
## refused case, and what its text implies — and every mana source on what
## the one mana planner does with it.

const CLAIMED := ["Ancient Tomb", "Blood Pet", "Caldera Lake", "Cinder Marsh",
	"Eladamri's Vineyard", "Ghost Town", "Lotus Petal", "Manakin", "Mogg Hollows",
	"Pine Barrens", "Reflecting Pool", "Rootwater Depths", "Salt Flats", "Scabland",
	"Skyshroud Elf", "Skyshroud Forest", "Stalking Stones", "Thalakos Lowlands",
	"Vec Townships", "Wasteland"]

const PAIN := {
	"Caldera Lake": [Mtg.ManaColor.U, Mtg.ManaColor.R],
	"Pine Barrens": [Mtg.ManaColor.B, Mtg.ManaColor.G],
	"Salt Flats": [Mtg.ManaColor.W, Mtg.ManaColor.B],
	"Scabland": [Mtg.ManaColor.R, Mtg.ManaColor.W],
	"Skyshroud Forest": [Mtg.ManaColor.G, Mtg.ManaColor.U],
}

const SLOW := {
	"Cinder Marsh": [Mtg.ManaColor.B, Mtg.ManaColor.R],
	"Mogg Hollows": [Mtg.ManaColor.R, Mtg.ManaColor.G],
	"Rootwater Depths": [Mtg.ManaColor.U, Mtg.ManaColor.B],
	"Thalakos Lowlands": [Mtg.ManaColor.W, Mtg.ManaColor.U],
	"Vec Townships": [Mtg.ManaColor.G, Mtg.ManaColor.W],
}

## A seat that answers colour questions the way a test says.
class Pick extends DecisionAgent:
	var color := 0
	var asked := 0
	func answer_color(_g: MtgGame, _pid: int, _prompt: String, hint: int) -> int:
		asked += 1
		return color if color != 0 else hint


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _pool(color: int, pid := 0) -> int:
	return g.players[pid].mana_pool.amount_of(color)

func _ai_plan(text: String) -> Array:
	return ManaPlanner.plan(g, 0, ManaCost.parse(text), 0)

func _human_plan(text: String) -> Array:
	return ManaPlanner.plan_from(ManaPlanner.auto_tap_sources(g, 0), ManaCost.parse(text), 0)

func _mana_index(inst: CardInstance, color: int) -> int:
	for i in inst.cur_mana_abilities.size():
		if int(inst.cur_mana_abilities[i].produces[0][0]) == color:
			return i
	return -1

func _to_next_turn_of(pid: int) -> void:
	advance_to_next_turn()
	if g.active_player != pid: advance_to_next_turn()
	assert_eq(g.active_player, pid)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_eq(c.set_code, "tmp", card_name)


# --------------------------------------------------------------- painlands --

func test_the_painlands_enter_tapped_and_hurt_only_for_colour() -> void:
	for card_name in PAIN:
		g.players[0].mana_pool.clear()
		g.players[0].life = 20
		var land := give_hand(0, card_name)
		g.players[0].lands_played_this_turn = 0
		assert_ok(g.play_land(0, land))
		assert_true(land.tapped, "%s enters tapped" % card_name)
		assert_refused(g.tap_for_mana(0, land, 0))
		g.untap_permanent(land)
		assert_eq(land.cur_mana_abilities.size(), 3, card_name)
		assert_ok(g.tap_for_mana(0, land, 0))
		assert_eq(_pool(Mtg.ManaColor.C), 1, card_name)
		assert_eq(g.players[0].life, 20, "%s: colourless is free" % card_name)
		for color in PAIN[card_name]:
			g.untap_permanent(land)
			var before := _pool(color)
			assert_ok(g.tap_for_mana(0, land, _mana_index(land, color)))
			assert_eq(_pool(color), before + 1, card_name)
			assert_eq(land.cur_mana_abilities[_mana_index(land, color)].pain, 1, "the planner knows the price")
		assert_eq(g.players[0].life, 18, "%s: 1 damage per coloured tap" % card_name)

func test_a_painland_put_onto_the_battlefield_by_an_effect_still_enters_tapped() -> void:
	var lake := put_battlefield(0, "Caldera Lake")
	assert_true(lake.tapped)


func test_the_planner_taps_a_painland_for_colour_only_when_it_must() -> void:
	var flats := put_battlefield(0, "Salt Flats")
	g.untap_permanent(flats)
	var plains := put_battlefield(0, "Plains")
	assert_false(_ai_plan("{W}").is_empty())
	assert_true(ManaPlanner.plan_and_pay(g, 0, ManaCost.parse("{W}")))
	assert_true(plains.tapped, "the painless Plains first")
	assert_false(flats.tapped)
	assert_eq(g.players[0].life, 20)
	assert_false(_human_plan("{B}").is_empty(), "the Flats can still make {B}")


# --------------------------------------------------------------- slow duals --

func test_the_slow_duals_skip_the_next_untap_only_after_a_coloured_tap() -> void:
	var lands := {}
	for card_name in SLOW:
		var land := put_battlefield(0, card_name)
		assert_false(land.tapped, "%s enters untapped" % card_name)
		lands[card_name] = land
	var colourless := put_battlefield(0, "Cinder Marsh")
	for card_name in SLOW:
		var land: CardInstance = lands[card_name]
		var color: int = SLOW[card_name][1]   # R, G, B, U, W: one of each
		assert_ok(g.tap_for_mana(0, land, _mana_index(land, color)))
		assert_eq(_pool(color), 1, card_name)
	assert_ok(g.tap_for_mana(0, colourless, 0))
	assert_eq(g.players[0].life, 20, "no damage")
	_to_next_turn_of(0)
	for card_name in SLOW:
		assert_true((lands[card_name] as CardInstance).tapped, "%s skipped this untap step" % card_name)
	assert_false(colourless.tapped, "{C} has no rider")
	_to_next_turn_of(0)
	for card_name in SLOW:
		assert_false((lands[card_name] as CardInstance).tapped, "%s untaps the step after" % card_name)

func test_a_slow_dual_makes_both_its_colours() -> void:
	for card_name in SLOW:
		g.players[0].mana_pool.clear()
		var land := put_battlefield(0, card_name)
		for color in SLOW[card_name]:
			g.untap_permanent(land)
			assert_ok(g.tap_for_mana(0, land, _mana_index(land, color)))
			assert_eq(_pool(color), 1, card_name)
			assert_refused(g.tap_for_mana(0, land, 0), "tapped")


# -------------------------------------------------------------- Ancient Tomb --

func test_ancient_tomb_makes_two_colourless_and_deals_two() -> void:
	var tomb := put_battlefield(0, "Ancient Tomb")
	assert_eq(tomb.cur_mana_abilities[0].pain, 2)
	assert_ok(g.tap_for_mana(0, tomb, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 2)
	assert_eq(g.players[0].life, 18)
	assert_refused(g.tap_for_mana(0, tomb, 0), "tapped")
	_to_next_turn_of(0)
	assert_false(tomb.tapped, "it untaps normally")

func test_ancient_tomb_hurts_under_the_1997_rules_too() -> void:
	g.rules.set_preset("fifth")
	var tomb := put_battlefield(0, "Ancient Tomb")
	assert_ok(g.tap_for_mana(0, tomb, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 2)
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(g.players[0].life, 16, "the 2 damage, and the unspent {C}{C} burned")

func test_ancient_tomb_pays_a_two_in_one_tap() -> void:
	var tomb := put_battlefield(0, "Ancient Tomb")
	assert_false(_ai_plan("{2}").is_empty())
	assert_true(_ai_plan("{3}").is_empty())
	assert_true(_ai_plan("{G}").is_empty(), "colourless only")
	assert_true(ManaPlanner.plan_and_pay(g, 0, ManaCost.parse("{2}")))
	assert_true(tomb.tapped)


# ----------------------------------------------------------------- Blood Pet --

func test_blood_pet_sacrifices_for_black_even_the_turn_it_arrives() -> void:
	var pet := put_battlefield(0, "Blood Pet", true)
	assert_ok(g.tap_for_mana(0, pet, 0))
	assert_eq(_pool(Mtg.ManaColor.B), 1)
	assert_eq(pet.zone, Mtg.Zone.GRAVEYARD)
	assert_refused(g.tap_for_mana(0, pet, 0))

func test_blood_pet_is_planned_last() -> void:
	var pet := put_battlefield(0, "Blood Pet")
	var swamp := put_battlefield(0, "Swamp")
	assert_true(ManaPlanner.plan_and_pay(g, 0, ManaCost.parse("{B}")))
	assert_true(swamp.tapped)
	assert_eq(pet.zone, Mtg.Zone.BATTLEFIELD, "the sacrifice is the last resort")


# ------------------------------------------------------ Eladamri's Vineyard --

func _vineyard_game(preset: String) -> CardInstance:
	g = MtgGame.new()
	var filler: Array = []
	for i in 30: filler.append("Forest")
	g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	g.rules.set_preset(preset)
	g.start(0)
	return put_battlefield(0, "Eladamri's Vineyard")

func test_eladamris_vineyard_gives_each_player_gg_in_their_first_main_phase() -> void:
	_vineyard_game("modern")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(_pool(Mtg.ManaColor.G), 0, "a trigger, on the stack")
	resolve_stack()
	assert_eq(_pool(Mtg.ManaColor.G), 2)
	assert_eq(_pool(Mtg.ManaColor.G, 1), 0)
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(g.stack.is_empty(), "not the second main phase")
	assert_eq(_pool(Mtg.ManaColor.G), 0)
	advance_to_next_turn()   # the opponent's first main phase
	assert_eq(g.active_player, 1)
	resolve_stack()
	assert_eq(_pool(Mtg.ManaColor.G, 1), 2, "that player adds {G}{G}")
	assert_eq(_pool(Mtg.ManaColor.G, 0), 0)

func test_eladamris_vineyard_mana_burns_under_the_mana_burn_presets() -> void:
	for preset in ["modern", "modern_mana_burn", "fifth"]:
		_vineyard_game(preset)
		advance_to_step(Mtg.Step.MAIN1)
		resolve_stack()
		assert_eq(_pool(Mtg.ManaColor.G), 2, preset)
		advance_to_step(Mtg.Step.COMBAT_BEGIN)
		advance_to_step(Mtg.Step.MAIN2)
		assert_eq(g.players[0].life, 20 if preset == "modern" else 18, "%s: the unused {G}{G}" % preset)

func test_eladamris_vineyard_mana_pays_for_a_spell() -> void:
	_vineyard_game("modern_mana_burn")
	advance_to_step(Mtg.Step.MAIN1)
	resolve_stack()
	var bears := give_hand(0, "Grizzly Bears")
	assert_ok(g.cast_spell(0, bears))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[0].life, 20, "spent: nothing burns")


# ----------------------------------------------------------------- Ghost Town --

func test_ghost_town_returns_to_hand_only_on_another_players_turn() -> void:
	var town := put_battlefield(0, "Ghost Town")
	assert_refused(g.activate_ability(0, town, 0))
	assert_eq(town.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, town, 0))
	resolve_stack()
	assert_eq(town.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(town))

func test_ghost_town_taps_for_colourless_and_can_bounce_while_tapped() -> void:
	var town := put_battlefield(0, "Ghost Town")
	assert_ok(g.tap_for_mana(0, town, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1)
	advance_to_next_turn()
	g.tap_permanent(town)
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, town, 0))
	resolve_stack()
	assert_eq(town.zone, Mtg.Zone.HAND, "{0} has no {T}")

func test_ghost_town_dodges_a_wasteland() -> void:
	var town := put_battlefield(0, "Ghost Town")
	advance_to_next_turn()
	var waste := put_battlefield(1, "Wasteland")
	assert_ok(g.activate_ability(1, waste, 0, [TargetRef.card(town)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, town, 0))
	resolve_stack()
	assert_eq(town.zone, Mtg.Zone.HAND, "bounced in response")
	assert_eq(waste.zone, Mtg.Zone.GRAVEYARD, "the Wasteland's cost was paid all the same")

func test_ghost_town_carries_the_self_bounce_role() -> void:
	var town := put_battlefield(0, "Ghost Town")
	assert_eq(town.cur_activated_abilities[0].effects[0].ai_role, &"self_bounce")


# ----------------------------------------------------------------- Lotus Petal --

func test_lotus_petal_one_mana_of_any_colour_then_gone() -> void:
	for color in Mtg.WUBRG:
		g.players[0].mana_pool.clear()
		var petal := put_battlefield(0, "Lotus Petal", true)
		assert_eq(petal.cur_mana_abilities.size(), 5)
		assert_ok(g.tap_for_mana(0, petal, _mana_index(petal, color)))
		assert_eq(_pool(color), 1)
		assert_eq(g.players[0].mana_pool.total(), 1, "one mana only")
		assert_eq(petal.zone, Mtg.Zone.GRAVEYARD)
		assert_refused(g.tap_for_mana(0, petal, 0))

func test_lotus_petal_costs_nothing_and_is_spent_last() -> void:
	var petal := give_hand(0, "Lotus Petal")
	assert_ok(g.cast_spell(0, petal))
	resolve_stack()
	assert_eq(petal.zone, Mtg.Zone.BATTLEFIELD)
	var forest := put_battlefield(0, "Forest")
	assert_true(ManaPlanner.plan_and_pay(g, 0, ManaCost.parse("{G}")))
	assert_true(forest.tapped)
	assert_eq(petal.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(_ai_plan("{R}").is_empty(), "the Petal can still pay a {R}")


# -------------------------------------------------------------------- Manakin --

func test_manakin_taps_for_colourless_but_not_while_summoning_sick() -> void:
	var sick := put_battlefield(0, "Manakin", true)
	assert_refused(g.tap_for_mana(0, sick, 0), "summoning sickness")
	var ready := put_battlefield(0, "Manakin")
	assert_ok(g.tap_for_mana(0, ready, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1)
	assert_true(ready.is_creature() and ready.is_type(Mtg.CardType.ARTIFACT))


# ------------------------------------------------------------ Reflecting Pool --

func test_reflecting_pool_makes_any_type_its_other_lands_could() -> void:
	var pick := Pick.new()
	g.set_agent(0, pick)
	var pool := put_battlefield(0, "Reflecting Pool")
	put_battlefield(0, "Forest")
	var island := put_battlefield(0, "Island")
	g.tap_permanent(island)   # a tapped land still "could produce" (its ruling)
	pick.color = Mtg.ManaColor.U
	assert_ok(g.tap_for_mana(0, pool, 0))
	assert_eq(pick.asked, 1, "two types on offer: the player is asked")
	assert_eq(_pool(Mtg.ManaColor.U), 1)
	g.untap_permanent(pool)
	assert_ok(g.tap_for_mana(0, pool, 0, Mtg.ManaColor.G))
	assert_eq(_pool(Mtg.ManaColor.G), 1)

func test_reflecting_pool_counts_colourless_and_ignores_the_opponents_lands() -> void:
	var pool := put_battlefield(0, "Reflecting Pool")
	put_battlefield(0, "Ancient Tomb")
	put_battlefield(1, "Mountain")
	assert_ok(g.tap_for_mana(0, pool, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1, "colourless is a type of mana (CR 106.1b)")
	assert_eq(_pool(Mtg.ManaColor.R), 0)
	assert_eq(g.players[0].life, 20, "the Tomb's rider is not borrowed")

func test_reflecting_pool_alone_or_with_only_pools_makes_nothing() -> void:
	var pool := put_battlefield(0, "Reflecting Pool")
	g.tap_for_mana(0, pool, 0)
	assert_eq(g.players[0].mana_pool.total(), 0, "no other land: no mana")
	var other := put_battlefield(0, "Reflecting Pool")
	g.untap_permanent(pool)
	g.tap_for_mana(0, pool, 0)
	g.tap_for_mana(0, other, 0)
	assert_eq(g.players[0].mana_pool.total(), 0, "two Pools do not feed each other")
	assert_true(_ai_plan("{1}").is_empty())

func test_reflecting_pool_with_another_pool_and_a_land_offers_only_that_land() -> void:
	var pool := put_battlefield(0, "Reflecting Pool")
	put_battlefield(0, "Reflecting Pool")
	put_battlefield(0, "Plains")
	assert_ok(g.tap_for_mana(0, pool, 0))
	assert_eq(_pool(Mtg.ManaColor.W), 1)

func test_reflecting_pool_follows_a_painland_and_the_planner_reads_it() -> void:
	var pool := put_battlefield(0, "Reflecting Pool")
	var barrens := put_battlefield(0, "Pine Barrens")   # enters tapped: still counts
	assert_true(barrens.tapped)
	assert_false(_ai_plan("{B}").is_empty())
	assert_true(_ai_plan("{U}").is_empty())
	# The owner's rule for colour-choice sources (Fellwar Stone, 2026-09-17):
	# several types on offer, the player's auto-tap spends it only on
	# generic mana and the tap asks; one type on offer, it is known.
	assert_true(_human_plan("{G}").is_empty())
	assert_false(_human_plan("{1}").is_empty())
	assert_true(ManaPlanner.plan_and_pay(g, 0, ManaCost.parse("{G}")))
	assert_true(pool.tapped)
	assert_eq(_pool(Mtg.ManaColor.G), 1)
	assert_eq(g.players[0].life, 20, "the Pool deals no damage")

func test_reflecting_pool_with_one_type_on_offer_auto_taps_for_it() -> void:
	put_battlefield(0, "Reflecting Pool")
	var swamp := put_battlefield(0, "Swamp")
	g.tap_permanent(swamp)
	assert_false(_human_plan("{B}").is_empty())
	assert_true(_human_plan("{G}").is_empty())


# -------------------------------------------------------------- Skyshroud Elf --

func test_skyshroud_elf_taps_for_green_or_turns_one_into_red_or_white() -> void:
	var elf := put_battlefield(0, "Skyshroud Elf")
	assert_eq(elf.cur_mana_abilities.size(), 3)
	assert_refused(g.tap_for_mana(0, elf, _mana_index(elf, Mtg.ManaColor.R)))
	assert_ok(g.tap_for_mana(0, elf, 0))
	assert_eq(_pool(Mtg.ManaColor.G), 1)
	assert_ok(g.tap_for_mana(0, elf, _mana_index(elf, Mtg.ManaColor.R)))
	assert_eq(_pool(Mtg.ManaColor.G), 0, "the {1} was paid from the floating green")
	assert_eq(_pool(Mtg.ManaColor.R), 1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.tap_for_mana(0, elf, _mana_index(elf, Mtg.ManaColor.W)))
	assert_eq(_pool(Mtg.ManaColor.W), 1, "no {T}: again while tapped")

func test_skyshroud_elf_converts_while_summoning_sick_and_the_planner_uses_it() -> void:
	var elf := put_battlefield(0, "Skyshroud Elf", true)
	assert_refused(g.tap_for_mana(0, elf, 0), "summoning sickness")
	put_battlefield(0, "Forest")
	assert_false(_ai_plan("{R}").is_empty(), "a Forest's {G} through the Elf")
	assert_true(_ai_plan("{R}{G}").is_empty(), "one Forest pays one")
	assert_true(ManaPlanner.plan_and_pay(g, 0, ManaCost.parse("{W}")))
	assert_eq(_pool(Mtg.ManaColor.W), 1)


# ------------------------------------------------------------- Stalking Stones --

func test_stalking_stones_becomes_a_3_3_for_good() -> void:
	var stones := put_battlefield(0, "Stalking Stones")
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_refused(g.activate_ability(0, stones, 0))
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, stones, 0))
	resolve_stack()
	assert_true(stones.is_creature())
	assert_true(stones.is_land(), "still a land")
	assert_true(stones.is_type(Mtg.CardType.ARTIFACT))
	assert_true(stones.has_subtype("elemental"))
	assert_eq([stones.cur_power, stones.cur_toughness], [3, 3])
	_to_next_turn_of(0)
	assert_true(stones.is_creature(), "the effect lasts indefinitely")
	assert_ok(g.tap_for_mana(0, stones, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1, "and it still taps for mana")

func test_stalking_stones_animated_can_attack_and_forgets_on_leaving() -> void:
	var stones := put_battlefield(0, "Stalking Stones")
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.activate_ability(0, stones, 0))
	resolve_stack()
	run_combat([stones.id])
	assert_eq(g.players[1].life, 17)
	g.return_to_hand(stones)
	var again := g.players[0].hand.has(stones)
	assert_true(again)
	g.players[0].lands_played_this_turn = 0
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.play_land(0, stones))
	assert_false(stones.is_creature(), "a new object (CR 400.7)")


# ------------------------------------------------------------------ Wasteland --

func test_wasteland_destroys_a_nonbasic_land_only() -> void:
	var waste := put_battlefield(0, "Wasteland")
	var forest := put_battlefield(1, "Forest")
	var tomb := put_battlefield(1, "Ancient Tomb")
	assert_refused(g.activate_ability(0, waste, 0, [TargetRef.card(forest)]))
	assert_eq(waste.zone, Mtg.Zone.BATTLEFIELD, "a refused activation pays nothing")
	assert_ok(g.activate_ability(0, waste, 0, [TargetRef.card(tomb)]))
	assert_eq(waste.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(tomb.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)

func test_wasteland_taps_for_colourless_and_then_cannot_also_destroy() -> void:
	var waste := put_battlefield(0, "Wasteland")
	var lake := put_battlefield(1, "Caldera Lake")
	assert_ok(g.tap_for_mana(0, waste, 0))
	assert_eq(_pool(Mtg.ManaColor.C), 1)
	assert_refused(g.activate_ability(0, waste, 0, [TargetRef.card(lake)]))
	assert_eq(lake.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(waste.cur_activated_abilities[0].effects[0] is DestroyEffect, "the AI reads typed removal")
