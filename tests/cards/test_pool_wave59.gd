extends GameTest
## Wave-59 tests: upkeep engines that charge rent (Cyclone, Primordial
## Ooze, Psychic Allergy, Rohgahh of Kher Keep), the untargeted sweeper
## (Drop of Honey), the damage battery (Living Artifact), the colour tax
## (Invoke Prejudice), and the two combat-step cards (Spitting Slug,
## Lesser Werewolf) plus Siren's Call's conscription.


func test_registry_loaded_wave59() -> void:
	for name in ["Siren's Call", "Cyclone", "Drop of Honey", "Living Artifact",
			"Primordial Ooze", "Invoke Prejudice", "Psychic Allergy",
			"Rohgahh of Kher Keep", "Spitting Slug", "Lesser Werewolf"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------ Siren's Call --

func test_sirens_call_refuses_your_own_turn() -> void:
	var call := give_hand(0, "Siren's Call")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, call, []), "opponent's turn")


func test_sirens_call_refuses_after_attackers() -> void:
	var call := give_hand(0, "Siren's Call")
	advance_to_next_turn()      # player 1's turn
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, call, []), "before attackers")


func test_sirens_call_forces_the_attack() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	var call := give_hand(0, "Siren's Call")
	advance_to_next_turn()      # player 1's turn, main phase
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, call, []))
	resolve_stack()
	assert_true(bear.must_attack_this_turn)
	assert_false(wall.must_attack_this_turn, "Walls are ignored by the effect")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, []), "must attack")
	assert_ok(g.declare_attackers(1, [bear.id]))


func test_sirens_call_spares_a_creature_that_arrived_this_turn() -> void:
	var call := give_hand(0, "Siren's Call")
	advance_to_next_turn()
	var newcomer := put_battlefield(1, "Grizzly Bears", true)   # summoning sick
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, call, []))
	resolve_stack()
	assert_false(newcomer.must_attack_this_turn)
	advance_to_next_turn()
	assert_eq(newcomer.zone, Mtg.Zone.BATTLEFIELD, "not controlled since the turn began")


func test_sirens_call_kills_the_creature_that_stayed_home() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var call := give_hand(0, "Siren's Call")
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, call, []))
	resolve_stack()
	# Tapped after the conscription: it CANNOT attack, so the requirement
	# excuses it (CR 508.1d) — and it dies at the end step all the same.
	g.tap_permanent(bear)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_sirens_call_spares_the_creature_that_did_attack() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var call := give_hand(0, "Siren's Call")
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, call, []))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ----------------------------------------------------------------- Cyclone --

func test_cyclone_sweeps_for_one_on_its_first_upkeep() -> void:
	put_battlefield(0, "Forest")
	var cyclone := put_battlefield(0, "Cyclone")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")   # 1/1
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(int(cyclone.counters.get("wind", 0)), 1)
	assert_eq(cyclone.zone, Mtg.Zone.BATTLEFIELD, "the {G} was paid")
	assert_eq(g.players[0].life, 19, "the storm hits its own controller too")
	assert_eq(g.players[1].life, 19)
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD)


func test_cyclone_blows_itself_out_when_unpaid() -> void:
	var cyclone := put_battlefield(0, "Cyclone")   # no lands at all
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(cyclone.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20, "an unpaid Cyclone deals nothing")


# ----------------------------------------------------------- Drop of Honey --

func test_drop_of_honey_eats_the_smallest_creature() -> void:
	put_battlefield(0, "Drop of Honey")
	put_battlefield(0, "Grizzly Bears")            # 2/2
	var raiders := put_battlefield(1, "Mons's Goblin Raiders")   # 1/1
	put_battlefield(1, "Hill Giant")               # 3/3
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD)


func test_drop_of_honey_breaks_a_tie_against_the_enemy() -> void:
	put_battlefield(0, "Drop of Honey")
	var mine := put_battlefield(0, "Mons's Goblin Raiders")
	var theirs := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


func test_drop_of_honey_ignores_regeneration() -> void:
	put_battlefield(0, "Drop of Honey")
	var bones := put_battlefield(1, "Drudge Skeletons")   # 1/1, {B}: regenerate
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep; the trigger is on the stack
	assert_eq(bones.zone, Mtg.Zone.GRAVEYARD, "it can't be regenerated")


func test_drop_of_honey_buries_itself_on_an_empty_board() -> void:
	var drop := put_battlefield(0, "Drop of Honey")
	g.check_state_based_actions()
	assert_eq(drop.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Living Artifact --

func test_living_artifact_banks_damage_and_pays_it_back() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	var aura := give_hand(0, "Living Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(ring)]))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	assert_eq(int(aura.counters.get("vitality", 0)), 3)
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep: one counter becomes one life
	assert_eq(int(aura.counters.get("vitality", 0)), 2)
	assert_eq(g.players[0].life, 18)


func test_living_artifact_ignores_damage_to_your_creatures() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Living Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(ring)]))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(int(aura.counters.get("vitality", 0)), 0)


# -------------------------------------------------------- Primordial Ooze --

func test_primordial_ooze_grows_and_charges_rent() -> void:
	put_battlefield(0, "Mountain")
	var ooze := put_battlefield(0, "Primordial Ooze", true)
	assert_true(ooze.has_keyword(Mtg.Keyword.MUST_ATTACK))
	advance_to_next_turn()               # the opponent's turn
	advance_to_step(Mtg.Step.UPKEEP)     # ours, before it has to charge
	resolve_stack()
	assert_eq(int(ooze.counters.get("+1/+1", 0)), 1)
	assert_eq(ooze.cur_power, 2)
	assert_false(ooze.tapped, "the {1} was paid")
	assert_eq(g.players[0].life, 20)


func test_primordial_ooze_taps_and_bites_when_it_cannot_pay() -> void:
	var ooze := put_battlefield(0, "Primordial Ooze", true)   # no lands
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	resolve_stack()
	assert_true(ooze.tapped)
	assert_eq(g.players[0].life, 19)
	assert_eq(ooze.cur_power, 2, "it grew anyway")


# ------------------------------------------------------- Invoke Prejudice --

func test_invoke_prejudice_counters_an_unshared_colour() -> void:
	put_battlefield(0, "Invoke Prejudice")
	var bear := give_hand(1, "Grizzly Bears")
	advance_to_next_turn()      # player 1's main phase
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, bear, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "no mana left to pay the toll")


func test_invoke_prejudice_can_be_paid_off() -> void:
	put_battlefield(0, "Invoke Prejudice")
	var bear := give_hand(1, "Grizzly Bears")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(1, bear, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_invoke_prejudice_spares_a_shared_colour() -> void:
	put_battlefield(0, "Invoke Prejudice")
	put_battlefield(0, "Grizzly Bears")     # a green creature of our own
	var bear := give_hand(1, "Grizzly Bears")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, bear, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "green meets green")


func test_invoke_prejudice_leaves_your_own_spells_alone() -> void:
	put_battlefield(0, "Invoke Prejudice")
	var bear := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bear, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- Psychic Allergy --

func test_psychic_allergy_burns_for_each_matching_permanent() -> void:
	for _i in 3:
		put_battlefield(1, "Merfolk of the Pearl Trident")   # blue 1/1
	for _i in 2:
		put_battlefield(0, "Island")
	var allergy := give_hand(0, "Psychic Allergy")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, allergy, []))
	resolve_stack()
	assert_eq(int(allergy.memory.get("color", 0)), Mtg.ManaColor.U,
		"blue is what the enemy board shows most of")
	advance_to_next_turn()      # their upkeep
	assert_eq(g.players[1].life, 17, "three blue permanents")


func test_psychic_allergy_dies_without_two_islands() -> void:
	put_battlefield(1, "Merfolk of the Pearl Trident")
	put_battlefield(0, "Island")
	var allergy := give_hand(0, "Psychic Allergy")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, allergy, []))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep: one Island is not two
	assert_eq(allergy.zone, Mtg.Zone.GRAVEYARD)


func test_psychic_allergy_eats_two_islands_to_survive() -> void:
	put_battlefield(1, "Merfolk of the Pearl Trident")
	for _i in 2:
		put_battlefield(0, "Island")
	var allergy := give_hand(0, "Psychic Allergy")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, allergy, []))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(allergy.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].battlefield.filter(
		func(i: CardInstance) -> bool: return i.is_land()).size(), 0)


# --------------------------------------------------- Rohgahh of Kher Keep --

func test_rohgahh_musters_only_his_own_kobolds() -> void:
	put_battlefield(0, "Rohgahh of Kher Keep")
	var mine := put_battlefield(0, "Kobolds of Kher Keep")
	var crookshank := put_battlefield(0, "Crookshank Kobolds")
	var theirs := put_battlefield(1, "Kobolds of Kher Keep")
	assert_eq(mine.cur_power, 2)
	assert_eq(mine.cur_toughness, 3)
	assert_eq(theirs.cur_power, 0, "only creatures YOU control")
	assert_eq(crookshank.cur_power, 0, "the name, not the Kobold subtype")
	assert_eq(crookshank.cur_toughness, 1)


func test_rohgahh_defects_with_his_kobolds_when_unpaid() -> void:
	var rohgahh := put_battlefield(0, "Rohgahh of Kher Keep")
	var kobold := put_battlefield(0, "Kobolds of Kher Keep")
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep, no red mana anywhere
	assert_eq(rohgahh.controller_id, 1)
	assert_eq(kobold.controller_id, 1)
	assert_true(rohgahh.tapped)
	assert_true(kobold.tapped)


func test_rohgahh_stays_when_the_rent_is_paid() -> void:
	for _i in 3:
		put_battlefield(0, "Mountain")
	var rohgahh := put_battlefield(0, "Rohgahh of Kher Keep")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(rohgahh.controller_id, 0)
	assert_false(rohgahh.tapped)


# ------------------------------------------------------------ Spitting Slug --

func test_spitting_slug_buys_first_strike_for_itself() -> void:
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	var slug := put_battlefield(1, "Spitting Slug")     # 2/4
	var giant := put_battlefield(0, "Hill Giant")       # 3/3
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {slug.id: giant.id}))
	resolve_stack()
	assert_true(slug.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_false(giant.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_spitting_slug_arms_the_enemy_when_it_cannot_pay() -> void:
	var slug := put_battlefield(1, "Spitting Slug")     # no lands
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {slug.id: giant.id}))
	resolve_stack()
	assert_false(slug.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_true(giant.has_keyword(Mtg.Keyword.FIRST_STRIKE))


# ---------------------------------------------------------- Lesser Werewolf --

func test_lesser_werewolf_shrinks_its_dance_partner() -> void:
	var wolf := put_battlefield(1, "Lesser Werewolf")   # 2/4
	var giant := put_battlefield(0, "Hill Giant")       # 3/3
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wolf.id: giant.id}))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(1, wolf, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(wolf.cur_power, 1)
	assert_eq(giant.cur_toughness, 2)
	assert_eq(int(giant.counters.get("-0/-1", 0)), 1)


func test_lesser_werewolf_runs_out_of_power() -> void:
	var wolf := put_battlefield(1, "Lesser Werewolf")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wolf.id: giant.id}))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 3)
	assert_ok(g.activate_ability(1, wolf, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, wolf, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_eq(wolf.cur_power, 0)
	assert_refused(g.activate_ability(1, wolf, 0, [TargetRef.card(giant)]),
		"no power left")


func test_lesser_werewolf_only_bites_during_declare_blockers() -> void:
	var wolf := put_battlefield(0, "Lesser Werewolf")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, wolf, 0, [TargetRef.card(bear)]))
