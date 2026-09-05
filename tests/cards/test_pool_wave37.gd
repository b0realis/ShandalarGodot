extends GameTest
## Wave-37 tests: Legends' protection and evasion shelf — targeting bans
## (Anti-Magic Aura, Spectral Cloak), combat neutering (Demonic Torment,
## Enchanted Being, Kry Shield, Telekinesis), blanket prevention
## (Indestructible Aura), evasion (Teleport), life manipulation (Life
## Chisel, Mirror Universe), an attack drawback (Giant Turtle) and a
## colour-fixing flier (Fire Sprites).


func test_anti_magic_aura_blanks_targeting() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Anti-Magic Aura")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_cant_be_spell_target)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(bear)]), "Illegal target")


func test_anti_magic_aura_blocks_other_auras() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Anti-Magic Aura")
	var strength := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, strength, [TargetRef.card(bear)]), "Illegal target")


func test_spectral_cloak_shrouds_while_untapped() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var cloak := give_hand(0, "Spectral Cloak")
	var tim := put_battlefield(1, "Prodigal Sorcerer")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, cloak, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_shroud)
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, tim, 0, [TargetRef.card(bear)]),
		"Illegal target")
	g.tap_permanent(bear)
	assert_false(bear.cur_shroud, "a tapped creature is exposed")
	assert_ok(g.activate_ability(1, tim, 0, [TargetRef.card(bear)]))


func test_demonic_torment_grounds_and_silences() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var torment := give_hand(0, "Demonic Torment")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, torment, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_cant_attack)
	assert_true(bear.cur_prevent_combat_damage_dealt)


func test_enchanted_being_ignores_auras() -> void:
	var being := put_battlefield(0, "Enchanted Being")   # 2/2
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(1, "Unholy Strength")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(1, aura, [TargetRef.card(bear)]))
	resolve_stack()
	run_combat([bear.id], {being.id: bear.id})
	assert_eq(being.damage, 0, "enchanted creatures can't hurt it")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "it hits back for 2 on a 4/3")


func test_enchanted_being_is_only_proof_against_combat_damage() -> void:
	var being := put_battlefield(0, "Enchanted Being")   # 2/2
	var tim := put_battlefield(1, "Prodigal Sorcerer")
	var aura := give_hand(1, "Unholy Strength")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(1, aura, [TargetRef.card(tim)]))
	resolve_stack()
	assert_false(tim.attachments.is_empty())
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(1, tim, 0, [TargetRef.card(being)]))
	resolve_stack()
	assert_eq(being.damage, 1, "an enchanted PINGER still hurts it — only combat damage is prevented")


func test_indestructible_aura_shrugs_off_everything() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var shield := give_hand(0, "Indestructible Aura")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, shield, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_kry_shield_silences_and_thickens_your_own() -> void:
	var angel := put_battlefield(0, "Serra Angel")   # mana value 5
	var shield := put_battlefield(0, "Kry Shield")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, shield, 0, [TargetRef.card(theirs)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, shield, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.cur_toughness, 9)
	assert_true(angel.cur_prevent_all_damage_dealt)


func test_telekinesis_locks_a_creature_down_for_two_turns() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var telekinesis := give_hand(0, "Telekinesis")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, telekinesis, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.tapped)
	assert_eq(bear.skip_untaps, 2)
	advance_to_next_turn()
	assert_true(bear.tapped, "their first untap step is skipped")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(bear.tapped, "and the second")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(bear.tapped, "free at last")


func test_teleport_makes_an_attacker_unblockable() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Wall of Wood")
	var teleport := give_hand(0, "Teleport")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, teleport, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blocker.id: bear.id}), "can't be blocked")


func test_life_chisel_cashes_creatures_at_upkeep() -> void:
	var chisel := put_battlefield(0, "Life Chisel")
	var wall := put_battlefield(0, "Wall of Wood")   # 0/3
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, chisel, 0, []), "upkeep")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, chisel, 0, []))
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 23)


func test_mirror_universe_swaps_life_totals() -> void:
	var mirror := put_battlefield(0, "Mirror Universe")
	g.adjust_life(0, -17)   # you: 3
	g.adjust_life(1, -2)    # them: 18
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, mirror, 0, [TargetRef.player(1)]))
	assert_eq(mirror.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[1].life, 3)


func test_giant_turtle_needs_a_turn_off() -> void:
	var turtle := put_battlefield(0, "Giant Turtle")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [turtle.id]))
	advance_to_next_turn()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [turtle.id]), "can't attack")
	advance_to_next_turn()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [turtle.id]), )


func test_fire_sprites_filter_green_into_red() -> void:
	var sprites := put_battlefield(0, "Fire Sprites")
	assert_true(sprites.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, sprites), "not enough floating mana")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.tap_for_mana(0, sprites))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 0)
