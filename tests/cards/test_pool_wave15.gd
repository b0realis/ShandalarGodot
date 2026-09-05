extends GameTest
## Wave-15 tests: mass land animation (Kormus Bell, Living Lands), wall
## liberation (Animate Wall), color-hoser counters (Deathgrip, Lifeforce),
## damage-payoff triggers (El-Hajjâj, Spirit Link, Backfire, Dingus Egg),
## and power-based block restrictions (Ironclaw Orcs, Amrou Kithkin) plus
## the blocking-only pump (Righteousness).


# ------------------------------------------------------- mass land animation --

func test_kormus_bell_wakes_the_swamps() -> void:
	put_battlefield(0, "Kormus Bell")
	var swamp := put_battlefield(0, "Swamp")
	var forest := put_battlefield(0, "Forest")
	assert_true(swamp.is_creature(), "swamps are 1/1 creatures")
	assert_true(swamp.is_land(), "…that are still lands")
	assert_eq(swamp.cur_power, 1)
	assert_eq(swamp.cur_toughness, 1)
	assert_false(forest.is_creature(), "forests unaffected")
	# They tap for mana AND can die to Earthquake-style sweeps.
	assert_ok(g.tap_for_mana(0, swamp))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)


func test_kormus_bell_swamps_get_summoning_sickness_rules() -> void:
	put_battlefield(0, "Kormus Bell")
	var swamp := put_battlefield(0, "Swamp", true)   # played this turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [swamp.id]), "summoning sickness")


func test_living_lands_wakes_the_forests() -> void:
	put_battlefield(0, "Living Lands")
	var forest := put_battlefield(0, "Forest")
	var swamp := put_battlefield(0, "Swamp")
	assert_true(forest.is_creature())
	assert_eq(forest.cur_power, 1)
	assert_false(swamp.is_creature())


func test_bell_and_bolt_kill_a_swamp() -> void:
	put_battlefield(0, "Kormus Bell")
	var swamp := put_battlefield(1, "Swamp")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(swamp)]))
	resolve_stack()
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD, "1/1 land dies to a Bolt")


# ------------------------------------------------------------- Animate Wall --

func test_animate_wall_lets_the_wall_swing() -> void:
	var wall := put_battlefield(0, "Wall of Stone")
	var aura := give_hand(0, "Animate Wall")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wall.id]))


func test_animate_wall_refuses_non_walls() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Animate Wall")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, aura, [TargetRef.card(bear)]), "Illegal target")


# ------------------------------------------------------ color-hoser counters --

func test_deathgrip_counters_green_only() -> void:
	put_battlefield(1, "Deathgrip")
	var growth := give_hand(0, "Giant Growth")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	var grip := g.find_on_battlefield(1, "Deathgrip")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(1, grip, 0, [TargetRef.card(growth)]))
	resolve_stack()
	assert_eq(growth.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(bear.cur_power, 2, "no pump happened")


func test_lifeforce_refuses_nonblack_spells() -> void:
	var force := put_battlefield(1, "Lifeforce")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_refused(g.activate_ability(1, force, 0, [TargetRef.card(bolt)]),
		"Illegal target")


# ----------------------------------------------------- damage-payoff triggers --

func test_el_hajjaj_drinks_what_he_deals() -> void:
	var hajjaj := put_battlefield(0, "El-Hajjâj")
	run_combat([hajjaj.id], {})
	assert_eq(g.players[1].life, 19, "1 combat damage")
	assert_eq(g.players[0].life, 21, "…and 1 life gained")


func test_spirit_link_pays_the_aura_controller() -> void:
	# Linking the OPPONENT's attacker: its damage feeds US.
	var mammoth := put_battlefield(1, "War Mammoth")
	var link := give_hand(0, "Spirit Link")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, link, [TargetRef.card(mammoth)]))
	resolve_stack()
	advance_to_next_turn()   # the opponent's turn
	run_combat([mammoth.id], {})
	assert_eq(g.players[0].life, 20 - 3 + 3, "took 3, gained 3")


func test_backfire_reflects_combat_pain() -> void:
	var mammoth := put_battlefield(1, "War Mammoth")
	var backfire := give_hand(0, "Backfire")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, backfire, [TargetRef.card(mammoth)]))
	resolve_stack()
	advance_to_next_turn()
	run_combat([mammoth.id], {})
	assert_eq(g.players[0].life, 17, "the mammoth still hits us for 3")
	assert_eq(g.players[1].life, 17, "…but its controller takes 3 back")


func test_dingus_egg_punishes_land_death() -> void:
	put_battlefield(0, "Dingus Egg")
	var swamp := put_battlefield(1, "Swamp")
	var sinkhole := give_hand(0, "Sinkhole")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, sinkhole, [TargetRef.card(swamp)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "their land died — 2 damage to them")


# -------------------------------------------------- power-based block rules --

func test_ironclaw_orcs_fear_the_strong() -> void:
	# "Can't block creatures with power 2 or greater" — even a 2/1 is
	# off-limits; only sub-2-power attackers may be blocked.
	var orcs := put_battlefield(1, "Ironclaw Orcs")
	var lions := put_battlefield(0, "Savannah Lions")
	var tim := put_battlefield(0, "Prodigal Sorcerer")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lions.id, tim.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {orcs.id: lions.id}), "power 2 or greater")
	assert_ok(g.declare_blockers(1, {orcs.id: tim.id}))


func test_amrou_kithkin_slips_past_the_big_ones() -> void:
	var kithkin := put_battlefield(0, "Amrou Kithkin")
	var mammoth := put_battlefield(1, "War Mammoth")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [kithkin.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {mammoth.id: kithkin.id}), "power 3 or greater")
	assert_ok(g.declare_blockers(1, {lions.id: kithkin.id}))


# ------------------------------------------------------------ Righteousness --

func test_righteousness_only_blesses_blockers() -> void:
	var mammoth := put_battlefield(0, "War Mammoth")
	var blocker := put_battlefield(1, "Savannah Lions")
	var bystander := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mammoth.id]))
	var right := give_hand(1, "Righteousness")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: mammoth.id}))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(1, right, [TargetRef.card(bystander)]),
		"Illegal target")
	assert_ok(g.cast_spell(1, right, [TargetRef.card(blocker)]))
	resolve_stack()
	assert_eq(blocker.cur_power, 9, "2 + 7")
	assert_eq(blocker.cur_toughness, 8, "1 + 7")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(mammoth.zone, Mtg.Zone.GRAVEYARD, "the mammoth was smitten")
