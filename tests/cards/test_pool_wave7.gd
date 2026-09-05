extends GameTest
## Wave-7 tests: the five mechanics of the type-change/cost/prevention
## engine pass — cost modifiers (Gloom), land animation (Mishra's Factory),
## amount-based damage prevention (Healing Salve, Samite Healer), the
## 1997-era legend rule, and modal spells (Blasts, Remove Soul) — plus the
## AI's grasp of the new choices.


# ---------------------------------------------------------------- Gloom --

func test_gloom_taxes_white_spells() -> void:
	put_battlefield(1, "Gloom")
	var salve := give_hand(0, "Healing Salve")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	# {W} alone no longer cuts it: Gloom demands {3} more.
	assert_refused(g.cast_spell(0, salve, [TargetRef.player(0)], 0, 0), "plus {3} more")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, salve, [TargetRef.player(0)], 0, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 23, "gained 3 once the tax was paid")


func test_gloom_ignores_nonwhite_spells() -> void:
	put_battlefield(1, "Gloom")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))


func test_gloom_taxes_white_enchantment_abilities() -> void:
	put_battlefield(1, "Gloom")
	var cop := put_battlefield(0, "Circle of Protection: Red")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, cop, 0, []), "plus {3} more")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, cop, 0, []))


func test_gloom_leaves_nonwhite_and_noncreature_abilities_alone() -> void:
	put_battlefield(1, "Gloom")
	# Icy Manipulator is an artifact — not a white enchantment.
	var icy := put_battlefield(0, "Icy Manipulator")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(bear)]))


# --------------------------------------------------- Mishra's Factory --

func test_factory_animates_and_reverts_at_cleanup() -> void:
	var factory := put_battlefield(0, "Mishra's Factory")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(factory.is_creature(), "printed: just a land")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, factory, 0, []))
	resolve_stack()
	assert_true(factory.is_creature(), "animated")
	assert_true(factory.is_land(), "it's still a land")
	assert_true(factory.is_type(Mtg.CardType.ARTIFACT))
	assert_true(factory.has_subtype("assembly-worker"))
	assert_eq(factory.cur_power, 2)
	assert_eq(factory.cur_toughness, 2)
	advance_to_next_turn()
	assert_false(factory.is_creature(), "animation expired at cleanup")


func test_factory_played_this_turn_cannot_attack() -> void:
	# The famous judge call: the Factory animates fine on the turn it's
	# played, but summoning sickness (which every permanent carries on
	# arrival) bars the attack.
	var factory := put_battlefield(0, "Mishra's Factory", true)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, factory, 0, []))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [factory.id]), "sickness")


func test_factory_attacks_and_pumps_itself_needs_another_worker() -> void:
	# A Factory controlled since last turn attacks as a 2/2; its own tap
	# ability can pump ANOTHER Assembly-Worker (not itself while tapped —
	# but a second factory can boost the attacker).
	var attacker := put_battlefield(0, "Mishra's Factory")
	var booster := put_battlefield(0, "Mishra's Factory")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, attacker, 0, []))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	# Booster taps: target Assembly-Worker gets +1/+1.
	assert_ok(g.activate_ability(0, booster, 1, [TargetRef.card(attacker)]))
	resolve_stack()
	assert_eq(attacker.cur_power, 3, "2/2 worker pumped to 3/3")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "3 combat damage from the animated land")


func test_factory_dies_like_a_creature_when_animated() -> void:
	# An ANIMATED Factory is a legal burn target and dies like any 2/2.
	# (Unanimated it isn't even targetable — pinned by the fizzle test below.)
	var factory := put_battlefield(1, "Mishra's Factory")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, factory, 0, []))
	resolve_stack()
	assert_true(factory.is_creature(), "animated and exposed")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(factory)]))
	resolve_stack()
	assert_eq(factory.zone, Mtg.Zone.GRAVEYARD, "3 damage kills the 2/2 land")


func test_bolt_fizzles_on_unanimated_factory() -> void:
	# Without animation a land is an illegal target for creature burn.
	var factory := put_battlefield(1, "Mishra's Factory")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(factory)]), "Illegal target")


# ---------------------------------------------------- damage prevention --

func test_healing_salve_mode_gain_life() -> void:
	var salve := give_hand(0, "Healing Salve")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, salve, [TargetRef.player(0)], 0, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 23)


func test_healing_salve_mode_prevent_creature_damage() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var salve := give_hand(0, "Healing Salve")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, salve, [TargetRef.card(bear)], 0, 1))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the 3 bolt damage was prevented")
	assert_eq(bear.damage, 0)
	assert_eq(bear.prevention, 0, "pool fully consumed")


func test_healing_salve_prevention_is_partial_and_expires() -> void:
	var salve := give_hand(0, "Healing Salve")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, salve, [TargetRef.player(0)], 0, 1))
	resolve_stack()
	assert_eq(g.players[0].damage_prevention, 3)
	# A 5-damage hit: 3 prevented, 2 land.
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.player(0), 5)
	assert_eq(g.players[0].life, 18, "5 - 3 prevented = 2")
	assert_eq(g.players[0].damage_prevention, 0)
	advance_to_next_turn()
	assert_eq(g.players[0].damage_prevention, 0, "cleanup keeps it cleared")


func test_samite_healer_prevents_one() -> void:
	var healer := put_battlefield(0, "Samite Healer")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, healer, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(healer.tapped)
	assert_eq(bear.prevention, 1)
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.card(bear), 2)
	assert_eq(bear.damage, 1, "one of the two prevented")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "1 < 2 toughness — survives")


func test_death_ward_regenerates_target() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := give_hand(0, "Death Ward")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regeneration replaced destruction")
	assert_true(bear.tapped, "regenerating taps")
	assert_eq(bear.damage, 0)


func test_uthden_troll_regenerates() -> void:
	var troll := put_battlefield(0, "Uthden Troll")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, troll, 0, []))
	resolve_stack()
	assert_eq(troll.regeneration_shields, 1)
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(troll)]))
	resolve_stack()
	assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD, "the troll shrugs it off")


# -------------------------------------------------------- the legend rule --

func test_second_legend_is_buried() -> void:
	# put_battlefield is direct surgery — SBAs run explicitly (real casts
	# hit them on resolution automatically).
	var first := put_battlefield(0, "Jedit Ojanen")
	var second := put_battlefield(0, "Jedit Ojanen")
	g.check_state_based_actions()
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD, "the elder legend stands")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD,
		"the newcomer is buried (1997 first-in-time rule)")


func test_opposing_same_name_legends_also_collide() -> void:
	# The era's rule cares about NAME, not controller: your Jedit bars mine.
	var yours := put_battlefield(1, "Jedit Ojanen")
	var mine := put_battlefield(0, "Jedit Ojanen")
	g.check_state_based_actions()
	assert_eq(yours.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)


func test_different_legends_coexist() -> void:
	var jedit := put_battlefield(0, "Jedit Ojanen")
	var torsten := put_battlefield(0, "Torsten Von Ursus")
	g.check_state_based_actions()
	assert_eq(jedit.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(torsten.zone, Mtg.Zone.BATTLEFIELD)


func test_nonlegendary_same_names_coexist() -> void:
	put_battlefield(0, "Grizzly Bears")
	var twin := put_battlefield(0, "Grizzly Bears")
	g.check_state_based_actions()
	assert_eq(twin.zone, Mtg.Zone.BATTLEFIELD, "no legend rule for commons")


# ----------------------------------------------------------- modal spells --

func test_blue_elemental_blast_counters_red_spell() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	var beb := give_hand(0, "Blue Elemental Blast")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, beb, [TargetRef.card(bolt)], 0, 0))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(g.players[0].life, 20, "no bolt damage")


func test_blue_elemental_blast_refuses_nonred_spell() -> void:
	var growth := give_hand(1, "Giant Growth")
	var bear := put_battlefield(1, "Grizzly Bears")
	var beb := give_hand(0, "Blue Elemental Blast")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, growth, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, beb, [TargetRef.card(growth)], 0, 0),
		"Illegal target")


func test_red_elemental_blast_destroys_blue_permanent() -> void:
	var drake := put_battlefield(1, "Azure Drake")
	var reb := give_hand(0, "Red Elemental Blast")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, reb, [TargetRef.card(drake)], 0, 1))
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD, "mode 2: destroy blue permanent")


func test_modal_mode_out_of_range_is_refused() -> void:
	var beb := give_hand(0, "Blue Elemental Blast")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, beb, [], 0, 5), "no mode")


func test_remove_soul_counters_only_creature_spells() -> void:
	# The ACTIVE player casts the creature; the defender counters it.
	var bears := give_hand(0, "Grizzly Bears")
	var soul := give_hand(1, "Remove Soul")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, soul, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "creature spell countered")


func test_remove_soul_refuses_noncreature_spell() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	var soul := give_hand(0, "Remove Soul")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, soul, [TargetRef.card(bolt)]), "Illegal target")


# ------------------------------------------------------------------- AI --

func test_ai_counters_bolt_with_blue_elemental_blast() -> void:
	# The wizard AI holds BEB (reactive: it has a counter mode) and fires
	# its counter mode at a threatening red spell.
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	give_hand(1, "Blue Elemental Blast")
	put_battlefield(1, "Island")
	var serra := put_battlefield(1, "Serra Angel")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	# Bolt aimed at the AI's Serra Angel — well over the counter threshold.
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(serra)]))
	assert_ok(g.pass_priority(0))
	var did := ai.act(g)
	assert_string_contains(did, "Blue Elemental Blast")
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "the AI countered the bolt")
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD)


func test_ai_plans_gloom_tax_into_casts() -> void:
	# With Gloom out and only {W}+{1} available, the AI must NOT attempt
	# the white spell (it would bounce); it simply develops elsewhere.
	put_battlefield(1, "Gloom")
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	give_hand(0, "Healing Salve")
	put_battlefield(0, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	var log_before := g.log_lines.size()
	ai.act(g)
	for i in range(log_before, g.log_lines.size()):
		assert_false(g.log_lines[i].contains("refused"),
			"AI cast bounced off the engine: %s" % g.log_lines[i])
