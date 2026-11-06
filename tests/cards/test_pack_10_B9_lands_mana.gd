extends GameTest
## Pack 10 (the Urza block), batch B9: the mana producers and lands of
## cards/sets/usg/_lands_mana.gd and uds/_lands_mana.gd — Blood Vassal,
## Skirge Familiar, Witch Engine, Carpet of Flowers, Priest of Titania,
## Vernal Bloom, Worn Powerstone, Gaea's Cradle, Phyrexian Tower, Serra's
## Sanctum, Shivan Gorge, Thran Quarry, Tolarian Academy, Heart Warden,
## Rofellos, Thran Dynamo and Yavimaya Hollow (Citanul Hierophants has its
## own script). Mana is read off the pool after a real tap; what the one
## mana planner counts is read off ManaPlanner.sources.

const CLAIMED := ["Blood Vassal", "Skirge Familiar", "Witch Engine", "Carpet of Flowers",
	"Priest of Titania", "Vernal Bloom", "Worn Powerstone", "Gaea's Cradle", "Phyrexian Tower",
	"Serra's Sanctum", "Shivan Gorge", "Thran Quarry", "Tolarian Academy", "Heart Warden",
	"Rofellos, Llanowar Emissary", "Thran Dynamo", "Yavimaya Hollow"]


## Scripted yes/no and colour answers; records every question.
class Scripted extends DecisionAgent:
	var yes: Array = []
	var colors: Array = []
	var asked: Array[String] = []

	func answer_yes_no(_g: MtgGame, _p: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return bool(yes.pop_front()) if not yes.is_empty() else hint

	func answer_color(_g: MtgGame, _p: int, prompt: String, hint: int) -> int:
		asked.append(prompt)
		return int(colors.pop_front()) if not colors.is_empty() else hint


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a

func pool(pid: int, color: int) -> int:
	return g.players[pid].mana_pool.amount_of(color)

## The amount the planner reads for [param inst]'s ability rows (0 = none).
func planned(inst: CardInstance) -> int:
	var most := 0
	for s in ManaPlanner.sources(g, inst.controller_id):
		if s[0] == inst: most = maxi(most, int(s[3]))
	return most


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Blood Vassal, Skirge Familiar, Heart Warden -----------------------------

func test_blood_vassal_sacrifices_for_two_black_even_when_sick() -> void:
	var vassal := put_battlefield(0, "Blood Vassal", true)
	assert_ok(g.tap_for_mana(0, vassal))
	assert_eq(pool(0, Mtg.ManaColor.B), 2)
	assert_eq(vassal.zone, Mtg.Zone.GRAVEYARD, "sacrifice, no {T}")

func test_skirge_familiar_discards_for_black_and_is_never_auto_planned() -> void:
	var familiar := put_battlefield(0, "Skirge Familiar", true)
	assert_true(familiar.has_keyword(Mtg.Keyword.FLYING))
	assert_refused(g.tap_for_mana(0, familiar))
	var card := give_hand(0, "Grizzly Bears")
	assert_eq(planned(familiar), 0, "a discard is a choice, never an auto-tap")
	assert_ok(g.tap_for_mana(0, familiar))
	assert_eq(pool(0, Mtg.ManaColor.B), 1)
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	assert_false(familiar.tapped, "no {T}: again and again while cards last")

func test_skirge_familiar_holds_a_human_seat_on_the_discard() -> void:
	var familiar := put_battlefield(0, "Skirge Familiar")
	give_hand(0, "Grizzly Bears")
	var giant := give_hand(0, "Hill Giant")
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.tap_for_mana(0, familiar))
	assert_not_null(g.awaiting_choice, "the card to discard is the player's")
	assert_true(g.awaiting_choice.is_cost)
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing paid while the question is open")
	assert_ok(g.answer_choice(giant.id))
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(pool(0, Mtg.ManaColor.B), 1)
	assert_eq(g.players[0].hand.size(), 1)

func test_heart_warden_taps_for_green_and_cashes_in_for_a_card() -> void:
	var warden := put_battlefield(0, "Heart Warden")
	assert_ok(g.tap_for_mana(0, warden))
	assert_eq(pool(0, Mtg.ManaColor.G), 1)
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, warden, 0))
	assert_eq(warden.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_refused(g.tap_for_mana(0, put_battlefield(0, "Heart Warden", true)), "summoning sickness")


# --- Witch Engine -------------------------------------------------------------

func test_witch_engine_makes_four_black_and_changes_hands() -> void:
	var engine := put_battlefield(0, "Witch Engine")
	assert_true(engine.cur_landwalk.has("swamp"))
	assert_true(engine.cur_mana_abilities.is_empty(), "it targets, so it is no mana ability (CR 605.1a)")
	assert_ok(g.activate_ability(0, engine, 0, [TargetRef.player(1)]))
	assert_eq(g.stack.size(), 1, "it uses the stack")
	assert_eq(pool(0, Mtg.ManaColor.B), 0)
	resolve_stack()
	assert_eq(pool(0, Mtg.ManaColor.B), 4)
	assert_eq(engine.controller_id, 1, "target opponent gains control of it")

func test_witch_engine_targets_only_an_opponent_and_needs_to_be_unsick() -> void:
	var engine := put_battlefield(0, "Witch Engine", true)
	assert_refused(g.activate_ability(0, engine, 0, [TargetRef.player(1)]), "summoning sickness")
	engine.summoning_sick = false
	assert_refused(g.activate_ability(0, engine, 0, [TargetRef.player(0)]))


# --- Carpet of Flowers --------------------------------------------------------

func test_carpet_of_flowers_adds_one_color_per_opponents_island() -> void:
	var p0 := seat(0)
	p0.yes = [true]
	p0.colors = [Mtg.ManaColor.R]
	put_battlefield(0, "Carpet of Flowers")
	for i in 3: put_battlefield(1, "Island")
	put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN2)   # each of your main phases
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(pool(0, Mtg.ManaColor.R), 3, "three Islands, one colour of my choice")

func test_carpet_of_flowers_declined_in_the_first_main_may_be_used_in_the_second() -> void:
	var p0 := seat(0)
	p0.yes = [false, true]
	advance_to_next_turn()   # P1's turn
	put_battlefield(0, "Carpet of Flowers")
	for i in 2: put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(g.stack.is_empty(), "not \"your\" main phase")
	advance_to_next_turn()   # P0's first main phase
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total(), 0, "declined")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.stack.size(), 1, "not added yet this turn: it triggers again")
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total(), 2)

func test_carpet_of_flowers_adds_only_once_a_turn() -> void:
	var p0 := seat(0)
	p0.yes = [true, true]
	advance_to_next_turn()   # P1's turn
	put_battlefield(0, "Carpet of Flowers")
	put_battlefield(1, "Island")
	advance_to_next_turn()   # P0's first main phase
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total(), 1)
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(g.stack.is_empty(), "already added this turn (CR 603.4)")

func test_carpet_of_flowers_with_no_opponent_islands_asks_nothing() -> void:
	var p0 := seat(0)
	put_battlefield(0, "Carpet of Flowers")
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_true(p0.asked.is_empty())


# --- Priest of Titania, Rofellos ----------------------------------------------

func test_priest_of_titania_counts_every_elf_on_the_battlefield() -> void:
	var priest := put_battlefield(0, "Priest of Titania")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Llanowar Elves")
	put_battlefield(1, "Grizzly Bears")
	assert_eq(planned(priest), 3)
	assert_ok(g.tap_for_mana(0, priest))
	assert_eq(pool(0, Mtg.ManaColor.G), 3, "itself, ours and theirs")

func test_rofellos_counts_the_forests_its_controller_controls() -> void:
	var rofellos := put_battlefield(0, "Rofellos, Llanowar Emissary")
	for i in 3: put_battlefield(0, "Forest")
	put_battlefield(1, "Forest")
	put_battlefield(0, "Island")
	assert_ok(g.tap_for_mana(0, rofellos))
	assert_eq(pool(0, Mtg.ManaColor.G), 3)
	assert_true((rofellos.cur_supertypes & Mtg.Supertype.LEGENDARY) != 0)

func test_rofellos_with_no_forest_is_no_source() -> void:
	var rofellos := put_battlefield(0, "Rofellos, Llanowar Emissary")
	assert_eq(planned(rofellos), 0)


# --- Vernal Bloom -------------------------------------------------------------

func test_vernal_bloom_doubles_every_forest_for_its_controller() -> void:
	put_battlefield(0, "Vernal Bloom")
	var mine := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Forest")
	var island := put_battlefield(0, "Island")
	assert_eq(planned(mine), 2, "the planner reads the bonus")
	assert_ok(g.tap_for_mana(0, mine))
	assert_eq(pool(0, Mtg.ManaColor.G), 2)
	assert_ok(g.tap_for_mana(1, theirs))
	assert_eq(pool(1, Mtg.ManaColor.G), 2, "symmetric: its controller adds the extra")
	assert_ok(g.tap_for_mana(0, island))
	assert_eq(pool(0, Mtg.ManaColor.U), 1)


# --- the artifacts ------------------------------------------------------------

func test_worn_powerstone_enters_tapped_and_taps_for_two() -> void:
	var stone := give_hand(0, "Worn Powerstone")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, stone))
	resolve_stack()
	assert_true(stone.tapped)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_ok(g.tap_for_mana(0, stone))
	assert_eq(pool(0, Mtg.ManaColor.C), 2)

func test_thran_dynamo_taps_for_three() -> void:
	var dynamo := put_battlefield(0, "Thran Dynamo")
	assert_eq(planned(dynamo), 3)
	assert_ok(g.tap_for_mana(0, dynamo))
	assert_eq(pool(0, Mtg.ManaColor.C), 3)


# --- the legendary lands ------------------------------------------------------

func test_gaeas_cradle_counts_creatures_you_control() -> void:
	var cradle := put_battlefield(0, "Gaea's Cradle")
	assert_eq(planned(cradle), 0, "no creature, no mana — the planner must not count it")
	for i in 3: put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	assert_eq(planned(cradle), 3)
	assert_ok(g.tap_for_mana(0, cradle))
	assert_eq(pool(0, Mtg.ManaColor.G), 3)

func test_gaeas_cradle_counts_an_animated_land() -> void:
	var cradle := put_battlefield(0, "Gaea's Cradle")
	var factory := put_battlefield(0, "Mishra's Factory")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, factory, 0))
	resolve_stack()
	assert_ok(g.tap_for_mana(0, cradle))
	assert_eq(pool(0, Mtg.ManaColor.G), 1, "live types (CONTRIBUTING rule 5)")

func test_a_second_legendary_land_of_a_name_is_buried() -> void:
	var first := put_battlefield(0, "Gaea's Cradle")
	var second := put_battlefield(0, "Gaea's Cradle")
	g.check_state_based_actions()
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "the 1997 legend rule: the newest goes")

func test_serras_sanctum_counts_enchantments_you_control() -> void:
	var sanctum := put_battlefield(0, "Serra's Sanctum")
	put_battlefield(0, "Vernal Bloom")
	put_battlefield(0, "Back to Basics")
	put_battlefield(1, "Carpet of Flowers")
	assert_ok(g.tap_for_mana(0, sanctum))
	assert_eq(pool(0, Mtg.ManaColor.W), 2)

func test_tolarian_academy_counts_artifacts_you_control() -> void:
	var academy := put_battlefield(0, "Tolarian Academy")
	put_battlefield(0, "Voltaic Key")
	put_battlefield(0, "Phyrexian Colossus")   # an artifact creature counts
	put_battlefield(1, "Sol Ring")
	assert_eq(planned(academy), 2)
	assert_ok(g.tap_for_mana(0, academy))
	assert_eq(pool(0, Mtg.ManaColor.U), 2)

func test_phyrexian_tower_taps_for_colorless_or_sacrifices_for_two_black() -> void:
	var tower := put_battlefield(0, "Phyrexian Tower")
	assert_refused(g.tap_for_mana(0, tower, 1), "creature")
	var bears := put_battlefield(0, "Grizzly Bears", true)
	assert_eq(planned(tower), 1, "the sacrifice is never auto-planned")
	assert_ok(g.tap_for_mana(0, tower, 1))
	assert_eq(pool(0, Mtg.ManaColor.B), 2)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_true(tower.tapped)
	g.untap_permanent(tower)
	assert_ok(g.tap_for_mana(0, tower, 0))
	assert_eq(pool(0, Mtg.ManaColor.C), 1)

func test_shivan_gorge_pings_the_opponent() -> void:
	var gorge := put_battlefield(0, "Shivan Gorge")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, gorge, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 20)
	assert_true(gorge.tapped)
	assert_refused(g.tap_for_mana(0, gorge), "tapped")

func test_yavimaya_hollow_regenerates_target_creature() -> void:
	var hollow := put_battlefield(0, "Yavimaya Hollow")
	var giant := put_battlefield(0, "Hill Giant")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, hollow, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.regeneration_shields, 1)
	g.destroy(giant)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(giant.tapped)
	g.untap_permanent(hollow)
	assert_ok(g.tap_for_mana(0, hollow))
	assert_eq(pool(0, Mtg.ManaColor.C), 1)


# --- Thran Quarry ---------------------------------------------------------------

func test_thran_quarry_makes_any_color() -> void:
	var quarry := put_battlefield(0, "Thran Quarry")
	put_battlefield(0, "Grizzly Bears")
	assert_ok(g.tap_for_mana(0, quarry, 3))
	assert_eq(g.players[0].mana_pool.total(), 1)
	assert_eq(quarry.cur_mana_abilities.size(), 5, "one per colour")

func test_thran_quarry_is_sacrificed_at_any_end_step_without_a_creature() -> void:
	var quarry := put_battlefield(0, "Thran Quarry")
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_next_turn()
	assert_eq(quarry.zone, Mtg.Zone.BATTLEFIELD, "a creature: kept")
	g.destroy(bears)
	advance_to_step(Mtg.Step.END)   # the opponent's end step counts too
	resolve_stack()
	assert_eq(quarry.zone, Mtg.Zone.GRAVEYARD)

func test_thran_quarry_survives_a_creature_arriving_before_its_trigger_resolves() -> void:
	var quarry := put_battlefield(0, "Thran Quarry")
	advance_to_step(Mtg.Step.END)
	assert_eq(g.stack.size(), 1)
	put_battlefield(0, "Grizzly Bears")
	resolve_stack()
	assert_eq(quarry.zone, Mtg.Zone.BATTLEFIELD, "the intervening if is checked again (CR 603.4)")
