extends GameTest
## Pack 10 (the Urza block), batch B9: the untap cards that are not "up to
## N lands" — Back to Basics, Horseshoe Crab, Morphling, Somnophore,
## Turnabout, Mana Leech, Argothian Elder, Phyrexian Colossus, Voltaic Key
## (cards/sets/usg/_untap.gd); Burst of Energy, Hope and Glory, Vigilant
## Drake, Grim Monolith (ulg/_untap.gd); Blizzard Elemental (uds/_untap.gd).
## Each is driven through the public API with its refused or edge case.

const CLAIMED := ["Back to Basics", "Horseshoe Crab", "Morphling", "Somnophore",
	"Turnabout", "Mana Leech", "Argothian Elder", "Phyrexian Colossus", "Voltaic Key",
	"Burst of Energy", "Hope and Glory", "Vigilant Drake", "Grim Monolith",
	"Blizzard Elemental"]


## FIFO answers and a record of every question; an empty queue answers
## with the caller's hint.
class Scripted extends DecisionAgent:
	var options: Array = []
	var asked: Array[String] = []

	func answer_option(_g: MtgGame, _p: int, prompt: String, _labels: Array[String], hint: int) -> int:
		asked.append(prompt)
		return int(options.pop_front()) if not options.is_empty() else hint


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


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Back to Basics ---------------------------------------------------------

func test_back_to_basics_locks_nonbasic_lands_of_both_players() -> void:
	put_battlefield(0, "Back to Basics")
	var tundra := put_battlefield(0, "Tundra")
	var island := put_battlefield(0, "Island")
	var their_factory := put_battlefield(1, "Mishra's Factory")
	var their_forest := put_battlefield(1, "Forest")
	for land in [tundra, island, their_factory, their_forest]: land.tapped = true
	g.recalculate()
	advance_to_next_turn()   # P1's untap step
	assert_true(their_factory.tapped, "a nonbasic land stays tapped")
	assert_false(their_forest.tapped, "a basic land untaps")
	advance_to_next_turn()   # P0's untap step
	assert_true(tundra.tapped, "an Island that is not basic is still locked (live supertype)")
	assert_false(island.tapped)

func test_back_to_basics_does_not_stop_an_effect_untapping_a_land() -> void:
	put_battlefield(0, "Back to Basics")
	var tundra := put_battlefield(0, "Tundra")
	tundra.tapped = true
	var burst := give_hand(0, "Burst of Energy")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, burst, [TargetRef.card(tundra)]))
	resolve_stack()
	assert_false(tundra.tapped, "the lock is the untap step's, not every untap")

func test_back_to_basics_gone_releases_the_lands() -> void:
	var basics := put_battlefield(0, "Back to Basics")
	var factory := put_battlefield(1, "Mishra's Factory")
	factory.tapped = true
	g.destroy(basics)
	advance_to_next_turn()
	assert_false(factory.tapped)


# --- Horseshoe Crab, Vigilant Drake, Blizzard Elemental ---------------------

func test_self_untappers_untap_for_their_printed_costs() -> void:
	for row in [["Horseshoe Crab", {Mtg.ManaColor.U: 1}], ["Vigilant Drake", {Mtg.ManaColor.U: 1, Mtg.ManaColor.C: 2}],
			["Blizzard Elemental", {Mtg.ManaColor.U: 1, Mtg.ManaColor.C: 3}]]:
		var body := put_battlefield(0, String(row[0]), true)   # sick: no {T} in the cost
		body.tapped = true
		assert_refused(g.activate_ability(0, body, 0))
		var cost: Dictionary = row[1]
		for color in cost: add_mana(0, int(color), int(cost[color]))
		assert_ok(g.activate_ability(0, body, 0))
		resolve_stack()
		assert_false(body.tapped, row[0])
		assert_eq(g.players[0].mana_pool.total(), 0, row[0])

func test_vigilant_drake_and_blizzard_elemental_fly() -> void:
	assert_true(put_battlefield(0, "Vigilant Drake").has_keyword(Mtg.Keyword.FLYING))
	assert_true(put_battlefield(0, "Blizzard Elemental").has_keyword(Mtg.Keyword.FLYING))

func test_horseshoe_crab_untaps_after_it_attacks() -> void:
	var crab := put_battlefield(0, "Horseshoe Crab")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [crab.id]))
	assert_true(crab.tapped)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, crab, 0))
	resolve_stack()
	assert_false(crab.tapped, "untapped, still attacking")
	assert_true(g.combat.attackers.has(crab.id))


# --- Morphling --------------------------------------------------------------

func test_morphling_untaps_flies_and_shifts_its_shape() -> void:
	var morph := put_battlefield(0, "Morphling")
	morph.tapped = true
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.activate_ability(0, morph, 0))
	resolve_stack()
	assert_false(morph.tapped)
	assert_ok(g.activate_ability(0, morph, 1))
	resolve_stack()
	assert_true(morph.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, morph, 3))
	assert_ok(g.activate_ability(0, morph, 3))
	resolve_stack()
	assert_eq([morph.cur_power, morph.cur_toughness], [5, 1])
	assert_ok(g.activate_ability(0, morph, 4))
	resolve_stack()
	assert_eq([morph.cur_power, morph.cur_toughness], [4, 2])
	advance_to_next_turn()
	assert_eq([morph.cur_power, morph.cur_toughness], [3, 3], "until end of turn")
	assert_false(morph.has_keyword(Mtg.Keyword.FLYING))

func test_morphling_shroud_answers_a_bolt() -> void:
	var morph := put_battlefield(0, "Morphling")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, morph, 2))
	resolve_stack()
	assert_true(morph.cur_shroud)
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(morph)]))
	var ability: ActivatedAbility = CardRegistry.get_card("Morphling").activated_abilities[2]
	assert_eq(ability.effects[0].ai_role, &"self_bounce")

func test_morphling_toughness_shift_kills_it_at_zero() -> void:
	var morph := put_battlefield(0, "Morphling")
	add_mana(0, Mtg.ManaColor.C, 3)
	for i in 3:
		assert_ok(g.activate_ability(0, morph, 3))
	resolve_stack()
	assert_eq(morph.zone, Mtg.Zone.GRAVEYARD, "6/0")


# --- Somnophore -------------------------------------------------------------

func test_somnophore_taps_and_holds_a_creature_of_the_player_it_hit() -> void:
	var somnophore := put_battlefield(0, "Somnophore")
	var giant := put_battlefield(1, "Hill Giant")
	run_combat([somnophore.id])
	assert_eq(g.players[1].life, 18)
	assert_true(giant.tapped, "tap target creature that player controls")
	advance_to_next_turn()   # P1's untap step
	assert_true(giant.tapped, "it doesn't untap while Somnophore remains")
	advance_to_next_turn()   # P0: Somnophore untaps
	advance_to_next_turn()   # P1
	assert_false(somnophore.tapped)
	assert_true(giant.tapped, "not tied to Somnophore being tapped")
	g.return_to_hand(somnophore)
	advance_to_next_turn()   # P0
	advance_to_next_turn()   # P1's untap step again
	assert_false(giant.tapped, "Somnophore left: the lock ended")

func test_somnophore_hitting_its_controller_targets_their_own_creature() -> void:
	var somnophore := put_battlefield(0, "Somnophore")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	g.deal_damage(somnophore, TargetRef.player(0), 2)
	resolve_stack()
	assert_true(mine.tapped, "\"that player\" is the damaged player")
	assert_false(theirs.tapped)
	assert_false(somnophore.tapped, "the heuristic does not lock Somnophore itself")

func test_somnophore_without_a_creature_to_target_does_nothing() -> void:
	var somnophore := put_battlefield(0, "Somnophore")
	run_combat([somnophore.id])
	assert_eq(g.players[1].life, 18)
	assert_true(g.stack.is_empty())

func test_somnophore_lock_is_not_carried_by_a_new_object() -> void:
	var somnophore := put_battlefield(0, "Somnophore")
	var giant := put_battlefield(1, "Hill Giant")
	run_combat([somnophore.id])
	assert_true(giant.tapped)
	g.return_to_hand(giant)
	g.put_from_hand_into_play(giant, 1)
	giant.tapped = true
	advance_to_next_turn()
	assert_false(giant.tapped, "the creature that returned is a new object (CR 400.7)")


# --- Turnabout --------------------------------------------------------------

func test_turnabout_taps_all_untapped_lands_of_target_player() -> void:
	var p0 := seat(0)
	p0.options = [2, 0]   # land, tap
	var forests: Array[CardInstance] = []
	for i in 3: forests.append(put_battlefield(1, "Forest"))
	var their_bears := put_battlefield(1, "Grizzly Bears")
	var my_island := put_battlefield(0, "Island")
	var turnabout := give_hand(0, "Turnabout")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, turnabout, [TargetRef.player(1)]))
	resolve_stack()
	for f in forests: assert_true(f.tapped)
	assert_false(their_bears.tapped, "only the chosen type")
	assert_false(my_island.tapped, "only that player's")
	assert_eq(p0.asked.size(), 2, "the type, then tap or untap — on resolution")

func test_turnabout_untaps_all_tapped_creatures_of_its_caster() -> void:
	var p0 := seat(0)
	p0.options = [1, 1]   # creature, untap
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var island := put_battlefield(0, "Island")
	for i in [bears, giant, island]: i.tapped = true
	var turnabout := give_hand(0, "Turnabout")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, turnabout, [TargetRef.player(0)]))
	resolve_stack()
	assert_false(bears.tapped)
	assert_false(giant.tapped)
	assert_true(island.tapped, "lands were not the chosen type")

func test_turnabout_heuristic_taps_an_opponent_and_untaps_its_caster() -> void:
	var forests: Array[CardInstance] = []
	for i in 3: forests.append(put_battlefield(1, "Forest"))
	var turnabout := give_hand(0, "Turnabout")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, turnabout, [TargetRef.player(1)]))
	resolve_stack()
	for f in forests: assert_true(f.tapped, "aimed at an opponent: tap their lands")
	var mine: Array[CardInstance] = []
	for i in 4:
		var island := put_battlefield(0, "Island")
		assert_ok(g.tap_for_mana(0, island))
		mine.append(island)
	var again := give_hand(0, "Turnabout")
	assert_ok(g.cast_spell(0, again, [TargetRef.player(0)]))
	resolve_stack()
	for island in mine: assert_false(island.tapped, "aimed at yourself: untap your lands")

func test_turnabout_artifacts_count_artifact_creatures() -> void:
	var p0 := seat(0)
	p0.options = [0, 0]   # artifact, tap
	var colossus := put_battlefield(1, "Phyrexian Colossus")
	var ring := put_battlefield(1, "Sol Ring")
	var bears := put_battlefield(1, "Grizzly Bears")
	var turnabout := give_hand(0, "Turnabout")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, turnabout, [TargetRef.player(1)]))
	resolve_stack()
	assert_true(colossus.tapped)
	assert_true(ring.tapped)
	assert_false(bears.tapped)


# --- Mana Leech -------------------------------------------------------------

func test_mana_leech_holds_a_land_while_it_stays_tapped() -> void:
	var leech := put_battlefield(0, "Mana Leech")
	var their_land := put_battlefield(1, "Mountain")
	assert_ok(g.activate_ability(0, leech, 0, [TargetRef.card(their_land)]))
	resolve_stack()
	assert_true(their_land.tapped)
	assert_true(leech.tapped)
	advance_to_next_turn()   # P1
	assert_true(their_land.tapped, "held")
	advance_to_next_turn()   # P0: the heuristic keeps the Leech tapped
	assert_true(leech.tapped, "you may choose not to untap it — and it is holding something")
	advance_to_next_turn()   # P1
	assert_true(their_land.tapped)
	g.untap_permanent(leech)
	advance_to_next_turn()   # P0
	advance_to_next_turn()   # P1
	assert_false(their_land.tapped, "the Leech untapped: the duration ended")

func test_mana_leech_targets_only_a_land_and_is_sick_on_arrival() -> void:
	var leech := put_battlefield(0, "Mana Leech", true)
	var land := put_battlefield(1, "Mountain")
	assert_refused(g.activate_ability(0, leech, 0, [TargetRef.card(land)]), "summoning sickness")
	leech.summoning_sick = false
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, leech, 0, [TargetRef.card(bears)]))
	assert_true(CardRegistry.get_card("Mana Leech").may_skip_untap)


# --- Argothian Elder --------------------------------------------------------

func test_argothian_elder_untaps_two_target_lands() -> void:
	var elder := put_battlefield(0, "Argothian Elder")
	var a := put_battlefield(0, "Forest")
	var b := put_battlefield(0, "Forest")
	a.tapped = true
	b.tapped = true
	assert_ok(g.activate_ability(0, elder, 0, [TargetRef.card(a), TargetRef.card(b)]))
	resolve_stack()
	assert_false(a.tapped)
	assert_false(b.tapped)
	assert_true(elder.tapped)

func test_argothian_elder_needs_two_different_lands() -> void:
	var elder := put_battlefield(0, "Argothian Elder")
	var a := put_battlefield(0, "Forest")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, elder, 0, [TargetRef.card(a), TargetRef.card(a)]))
	assert_refused(g.activate_ability(0, elder, 0, [TargetRef.card(a), TargetRef.card(bears)]))
	var sick := put_battlefield(0, "Argothian Elder", true)
	var b := put_battlefield(1, "Forest")
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.card(a), TargetRef.card(b)]), "summoning sickness")


# --- Phyrexian Colossus -----------------------------------------------------

func test_phyrexian_colossus_stays_tapped_and_pays_eight_life_to_untap() -> void:
	var colossus := put_battlefield(0, "Phyrexian Colossus")
	colossus.tapped = true
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(colossus.tapped, "doesn't untap during your untap step")
	assert_ok(g.activate_ability(0, colossus, 0))
	assert_eq(g.players[0].life, 12, "8 life is the cost")
	resolve_stack()
	assert_false(colossus.tapped)

func test_phyrexian_colossus_cannot_pay_more_life_than_it_has() -> void:
	var colossus := put_battlefield(0, "Phyrexian Colossus")
	colossus.tapped = true
	g.adjust_life(0, -13)
	assert_refused(g.activate_ability(0, colossus, 0))
	assert_true(colossus.tapped)

func test_phyrexian_colossus_needs_three_blockers() -> void:
	var colossus := put_battlefield(0, "Phyrexian Colossus")
	var blockers: Array[CardInstance] = []
	for i in 3: blockers.append(put_battlefield(1, "Grizzly Bears"))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [colossus.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blockers[0].id: colossus.id, blockers[1].id: colossus.id}))
	assert_ok(g.declare_blockers(1, {blockers[0].id: colossus.id, blockers[1].id: colossus.id, blockers[2].id: colossus.id}))


# --- Voltaic Key ------------------------------------------------------------

func test_voltaic_key_untaps_target_artifact() -> void:
	var key := put_battlefield(0, "Voltaic Key")
	var ring := put_battlefield(0, "Sol Ring")
	assert_ok(g.tap_for_mana(0, ring))
	assert_ok(g.activate_ability(0, key, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_false(ring.tapped)
	assert_true(key.tapped)
	assert_eq(g.players[0].mana_pool.total(), 1, "two from the Ring, one paid for the Key")

func test_voltaic_key_refuses_a_nonartifact() -> void:
	var key := put_battlefield(0, "Voltaic Key")
	var bears := put_battlefield(0, "Grizzly Bears")
	bears.tapped = true
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, key, 0, [TargetRef.card(bears)]))

func test_voltaic_key_untaps_an_artifact_creature_too() -> void:
	var key := put_battlefield(0, "Voltaic Key")
	var colossus := put_battlefield(0, "Phyrexian Colossus")
	colossus.tapped = true
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, key, 0, [TargetRef.card(colossus)]))
	resolve_stack()
	assert_false(colossus.tapped, "eight life saved")


# --- Burst of Energy, Hope and Glory ----------------------------------------

func test_burst_of_energy_untaps_any_permanent() -> void:
	var theirs := put_battlefield(1, "Hill Giant")
	theirs.tapped = true
	var burst := give_hand(0, "Burst of Energy")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, burst, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_false(theirs.tapped)

func test_hope_and_glory_untaps_and_pumps_two_creatures() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	bears.tapped = true
	giant.tapped = true
	var hope := give_hand(0, "Hope and Glory")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, hope, [TargetRef.card(bears), TargetRef.card(giant)]))
	resolve_stack()
	assert_false(bears.tapped)
	assert_false(giant.tapped)
	assert_eq([bears.cur_power, bears.cur_toughness], [3, 3])
	assert_eq([giant.cur_power, giant.cur_toughness], [4, 4])
	advance_to_next_turn()
	assert_eq([bears.cur_power, bears.cur_toughness], [2, 2])

func test_hope_and_glory_needs_two_creatures_and_survives_losing_one() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var hope := give_hand(0, "Hope and Glory")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_refused(g.cast_spell(0, hope, [TargetRef.card(bears)]))
	assert_refused(g.cast_spell(0, hope, [TargetRef.card(bears), TargetRef.card(bears)]))
	var giant := put_battlefield(1, "Hill Giant")
	giant.tapped = true
	assert_ok(g.cast_spell(0, hope, [TargetRef.card(bears), TargetRef.card(giant)]))
	g.destroy(bears)
	resolve_stack()
	assert_false(giant.tapped, "the legal target still gets it (CR 608.2b)")
	assert_eq(giant.cur_power, 4)


# --- Grim Monolith ------------------------------------------------------------

func test_grim_monolith_taps_for_three_and_untaps_for_four() -> void:
	var monolith := put_battlefield(0, "Grim Monolith")
	assert_ok(g.tap_for_mana(0, monolith))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 3)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, monolith, 0))
	resolve_stack()
	assert_false(monolith.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0, "net -1 each cycle without help")

func test_grim_monolith_does_not_untap_in_the_untap_step_under_either_rules() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		if preset == "fifth": g.rules.set_edition("fifth")
		else: g.rules.set_preset("modern")
		var monolith := put_battlefield(0, "Grim Monolith")
		assert_ok(g.tap_for_mana(0, monolith))
		advance_to_next_turn()
		advance_to_next_turn()
		assert_true(monolith.tapped, preset)
