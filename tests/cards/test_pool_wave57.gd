extends GameTest
## Wave-57 tests: damage REDIRECTION (Jade Monolith, Veteran Bodyguard),
## damage BOOKKEEPING (Simulacrum, Reverse Damage), CONSCRIPTION (Nettling
## Imp's "attacks this turn if able"), a graveyard-listening trigger (Nether
## Shadow) and the shapeshifters.


func test_registry_loaded_wave57() -> void:
	for name in ["Sacrifice", "Simulacrum", "Veteran Bodyguard",
			"Reverse Damage", "Jade Monolith", "Demonic Hordes",
			"Nether Shadow", "Nettling Imp", "Natural Selection",
			"Clockwork Avian", "Urza's Avenger", "Primal Clay"]:
		assert_not_null(CardRegistry.get_card(name), name)


# --------------------------------------------------------------- Sacrifice --

func test_sacrifice_turns_a_body_into_black_mana() -> void:
	put_battlefield(0, "Hill Giant")     # mana value 4
	var spell := give_hand(0, "Sacrifice")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 4)


# -------------------------------------------------------------- Simulacrum --

func test_simulacrum_moves_your_damage_onto_a_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	var spell := give_hand(0, "Simulacrum")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the 3 came back as life")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "and 3 went into our own bear")


# ---------------------------------------------------------- Reverse Damage --

func test_reverse_damage_turns_a_bolt_into_life() -> void:
	# In RESPONSE to the Bolt: "a source of your choice" is named as the
	# spell resolves, and the Bolt on the stack is the one it names
	# (lifted 2026-09-02; tests/cards/test_fidelity_2026_09_02_sources.gd).
	var spell := give_hand(0, "Reverse Damage")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(g.players[0].life, 23, "prevented, and paid back as life")


# ------------------------------------------------------------ Jade Monolith --

func test_jade_monolith_takes_the_blow_for_a_creature() -> void:
	# In RESPONSE to the Bolt: "a source of your choice" is named as the
	# ability resolves, and the Bolt on the stack is the one it names
	# (lifted 2026-09-02; tests/cards/test_fidelity_2026_09_02_sources.gd).
	var monolith := put_battlefield(0, "Jade Monolith")
	var bear := put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, monolith, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the bear is untouched")
	assert_eq(bear.damage, 0)
	assert_eq(g.players[0].life, 17, "we took it instead")


# ------------------------------------------------------- Veteran Bodyguard --

func test_veteran_bodyguard_eats_the_unblocked_damage() -> void:
	var guard := put_battlefield(1, "Veteran Bodyguard")   # 2/5
	var attacker := put_battlefield(0, "Hill Giant")       # 3/3
	guard.tapped = false
	run_combat([attacker.id])
	assert_eq(g.players[1].life, 20, "the Bodyguard soaked it")
	assert_eq(guard.damage, 3)


func test_a_tapped_bodyguard_stands_aside() -> void:
	var guard := put_battlefield(1, "Veteran Bodyguard")
	var attacker := put_battlefield(0, "Hill Giant")
	g.tap_permanent(guard)
	run_combat([attacker.id])
	assert_eq(g.players[1].life, 17)


# ----------------------------------------------------------- Demonic Hordes --

func test_demonic_hordes_destroys_a_land() -> void:
	var hordes := put_battlefield(0, "Demonic Hordes")
	var land := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, hordes, 0, [TargetRef.card(land)]))
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)


func test_demonic_hordes_eats_your_land_when_unpaid() -> void:
	var hordes := put_battlefield(0, "Demonic Hordes")
	var mine := put_battlefield(0, "Forest")     # green: can't pay {B}{B}{B}
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep
	resolve_stack()
	assert_true(hordes.tapped)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------ Nether Shadow --

func test_nether_shadow_crawls_out_of_a_deep_graveyard() -> void:
	var shadow := give_hand(0, "Nether Shadow")
	g.players[0].hand.erase(shadow)
	shadow.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(shadow)
	for _i in 3:                       # three creature cards ABOVE it
		var corpse := give_hand(0, "Grizzly Bears")
		g.players[0].hand.erase(corpse)
		corpse.zone = Mtg.Zone.GRAVEYARD
		g.players[0].graveyard.append(corpse)
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep
	resolve_stack()
	assert_eq(shadow.zone, Mtg.Zone.BATTLEFIELD)


func test_nether_shadow_stays_buried_when_shallow() -> void:
	var shadow := give_hand(0, "Nether Shadow")
	g.players[0].hand.erase(shadow)
	shadow.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(shadow)
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	assert_eq(shadow.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------- Nettling Imp --

func test_nettling_imp_conscripts_a_creature() -> void:
	var imp := put_battlefield(0, "Nettling Imp")
	var victim := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()      # their turn
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, imp, 0, [TargetRef.card(victim)]))
	resolve_stack()
	assert_true(victim.must_attack_this_turn)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, []), "must attack")
	assert_ok(g.declare_attackers(1, [victim.id]))


# ------------------------------------------------------- Natural Selection --

func test_natural_selection_restacks_a_library() -> void:
	var spell := give_hand(0, "Natural Selection")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	var before: int = g.players[1].library.size()
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].library.size(), before, "nothing left the library")


# ---------------------------------------------------------- Clockwork Avian --

func test_clockwork_avian_winds_down_and_back_up() -> void:
	var avian := put_battlefield(0, "Clockwork Avian")
	assert_eq(int(avian.counters.get("+1/+0", 0)), 4)
	assert_eq(avian.cur_power, 4)
	run_combat([avian.id])
	resolve_stack()
	assert_eq(int(avian.counters.get("+1/+0", 0)), 3, "a counter came off")
	# Walk to OUR next upkeep (advance_to_next_turn sails past it).
	var guard := 0
	var want := g.turn_number + 2
	while (g.turn_number < want or g.current_step() != Mtg.Step.UPKEEP) \
			and guard < 300:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, 0)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, avian, 0, [], 2))
	resolve_stack()
	assert_eq(int(avian.counters.get("+1/+0", 0)), 4, "never more than four")


# ----------------------------------------------------------- Urza's Avenger --

func test_urzas_avenger_trades_size_for_keywords() -> void:
	var avenger := put_battlefield(0, "Urza's Avenger")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, avenger, 1, []))   # flying
	resolve_stack()
	assert_eq(avenger.cur_power, 3)
	assert_eq(avenger.cur_toughness, 3)
	assert_true(avenger.has_keyword(Mtg.Keyword.FLYING))


# --------------------------------------------------------------- Primal Clay --

func test_primal_clay_picks_a_body_on_arrival() -> void:
	var clay := put_battlefield(0, "Primal Clay")
	resolve_stack()
	assert_true(clay.cur_power > 0)
	assert_true(clay.cur_toughness > 0)
	assert_true(clay.memory.has("shape"))


func test_primal_clay_walls_up_against_a_big_board() -> void:
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Hill Giant")
	var clay := put_battlefield(0, "Primal Clay")
	resolve_stack()
	assert_eq(String(clay.memory.get("shape", "")), "wall")
	assert_eq(clay.cur_toughness, 6)
	assert_true(clay.has_keyword(Mtg.Keyword.DEFENDER))
