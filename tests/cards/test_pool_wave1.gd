extends GameTest
## Behavior tests for the wave-1 graduated cards (see each card file's doc
## header for what is being pinned). Mechanics themselves are covered in
## tests/unit/test_mechanics.gd; these tests are about each CARD doing what
## its oracle text says.


# -------------------------------------------------------- Hypnotic Specter --

func test_hyppie_combat_damage_forces_random_discard() -> void:
	var hyppie := put_battlefield(0, "Hypnotic Specter")
	give_hand(1, "Forest")
	give_hand(1, "Forest")
	give_hand(1, "Forest")
	run_combat([hyppie.id])
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[1].hand.size(), 2, "one card discarded at random")
	assert_eq(g.players[1].graveyard.size(), 1)


func test_hyppie_noncombat_damage_also_triggers() -> void:
	# "Deals damage", not "deals combat damage" — e.g. if it ever pings via
	# another effect. Simulate by direct engine damage from the specter.
	var hyppie := put_battlefield(0, "Hypnotic Specter")
	give_hand(1, "Forest")
	g.deal_damage(hyppie, TargetRef.player(1), 1)
	resolve_stack()   # the trigger
	assert_eq(g.players[1].hand.size(), 0)


# ------------------------------------------------------------- Erg Raiders --

func test_erg_raiders_punish_a_lazy_turn() -> void:
	var raiders := put_battlefield(0, "Erg Raiders")   # not sick (helper default)
	advance_to_step(Mtg.Step.END)
	resolve_stack()   # end-step trigger
	assert_eq(g.players[0].life, 18, "didn't attack: 2 damage to controller")


func test_erg_raiders_quiet_when_they_attacked() -> void:
	var raiders := put_battlefield(0, "Erg Raiders")
	run_combat([raiders.id])
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "attacked — no punishment")
	assert_eq(g.players[1].life, 18)


func test_erg_raiders_grace_turn_when_summoned() -> void:
	var raiders := put_battlefield(0, "Erg Raiders", true)   # sick = just arrived
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "came under control this turn — no punishment")


# ------------------------------------------------- Crusade & Bad Moon --

func test_crusade_boosts_all_white_creatures_symmetrically() -> void:
	put_battlefield(0, "Crusade")
	var my_lions := put_battlefield(0, "Savannah Lions")
	var their_lions := put_battlefield(1, "Savannah Lions")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(my_lions.cur_power, 3)
	assert_eq(their_lions.cur_power, 3, "symmetric, as printed")
	assert_eq(bear.cur_power, 2, "green bear unaffected")


func test_bad_moon_stacks_with_itself() -> void:
	put_battlefield(0, "Bad Moon")
	put_battlefield(0, "Bad Moon")
	var zombies := put_battlefield(0, "Scathe Zombies")
	assert_eq(zombies.cur_power, 4, "two Bad Moons: 2/2 -> 4/4")
	assert_eq(zombies.cur_toughness, 4)


# ------------------------------------- self-pumps (Shade, Shivan, Gargoyle) --

func test_frozen_shade_pumps_per_activation() -> void:
	var shade := put_battlefield(0, "Frozen Shade")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, shade, 0, []))
	assert_ok(g.activate_ability(0, shade, 0, []))
	resolve_stack()
	assert_eq(shade.cur_power, 2, "0/1 + two activations = 2/3")
	assert_eq(shade.cur_toughness, 3)
	advance_to_next_turn()
	assert_eq(shade.cur_power, 0, "pumps expire at cleanup")


func test_granite_gargoyle_toughness_pump_beats_bolt() -> void:
	var gargoyle := put_battlefield(0, "Granite Gargoyle")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(gargoyle)]))
	# Respond with two +0/+1 activations: 2/2 -> 2/4 before the bolt lands.
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, gargoyle, 0, []))
	assert_ok(g.activate_ability(0, gargoyle, 0, []))
	resolve_stack()
	assert_eq(gargoyle.zone, Mtg.Zone.BATTLEFIELD, "3 damage vs 4 toughness")
	assert_eq(gargoyle.damage, 3)


func test_shivan_firebreathing_stacks() -> void:
	var shivan := put_battlefield(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	for _i in 3:
		assert_ok(g.activate_ability(0, shivan, 0, []))
	resolve_stack()
	assert_eq(shivan.cur_power, 8, "5/5 + three breaths = 8/5")


# ----------------------------------------------- removal & mass effects --

func test_swords_exiles_and_feeds_current_power() -> void:
	# Enchanted bear (3/4 via Holy Strength): Swords exiles it, its
	# controller gains its CURRENT power — 3, not printed 2.
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(1, "Holy Strength")
	var swords := give_hand(0, "Swords to Plowshares")
	advance_to_next_turn()   # P1's turn to cast their aura
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, aura, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.pass_priority(1))
	assert_ok(g.cast_spell(0, swords, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "exiled, not destroyed")
	assert_eq(g.players[1].life, 23, "gained current power (3)")
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "orphaned aura fell off")


func test_wrath_kills_protected_and_shielded_alike() -> void:
	var knight := put_battlefield(1, "White Knight")     # pro-black
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	skeletons.regeneration_shields = 3
	var mine := put_battlefield(0, "Serra Angel")
	var wrath := give_hand(0, "Wrath of God")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, wrath, []))
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD, "no targeting, no damage — protection useless")
	assert_eq(skeletons.zone, Mtg.Zone.GRAVEYARD, "can't be regenerated")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "Wrath spares no one, including its caster's")


func test_earthquake_spares_flyers_hits_players() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	var quake := give_hand(0, "Earthquake")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, quake, [], 2))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "X=2 kills the grounded 2/2")
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD, "flyer spared")
	assert_eq(g.players[0].life, 18, "symmetric: caster too")
	assert_eq(g.players[1].life, 18)


func test_weakness_shrinks_lions_to_death() -> void:
	var lions := put_battlefield(1, "Savannah Lions")
	var weakness := give_hand(0, "Weakness")
	advance_to_step(Mtg.Step.MAIN1)   # enchantments are sorcery-speed
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, weakness, [TargetRef.card(lions)]))
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD, "2/1 - 2/1 = 0/0 dies to SBA")


func test_unsummon_bounces_and_strands_the_aura() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	var unsummon := give_hand(1, "Unsummon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, unsummon, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND, "bounced to owner's hand")
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "aura stranded — card advantage")


# ------------------------------------------------- rituals, geysers, mana --

func test_dark_ritual_fuels_a_turn_one_specter() -> void:
	var swamp := put_battlefield(0, "Swamp")
	var ritual := give_hand(0, "Dark Ritual")
	var hyppie := give_hand(0, "Hypnotic Specter")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, swamp))
	assert_ok(g.cast_spell(0, ritual, []))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 3)
	assert_ok(g.cast_spell(0, hyppie, []))
	resolve_stack()
	assert_eq(hyppie.zone, Mtg.Zone.BATTLEFIELD, "the classic curve, engine-legal")


func test_braingeyser_draws_x_for_target_player() -> void:
	var geyser := give_hand(0, "Braingeyser")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, geyser, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 3, "aimed at the opponent, X=3")


func test_stream_of_life_gains_x() -> void:
	var stream := give_hand(0, "Stream of Life")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, stream, [TargetRef.player(0)], 5))
	resolve_stack()
	assert_eq(g.players[0].life, 25)


func test_llanowar_elves_are_summoning_sick() -> void:
	var elves := put_battlefield(0, "Llanowar Elves", true)   # just arrived
	assert_refused(g.tap_for_mana(0, elves), "summoning sickness")


func test_birds_pick_any_color() -> void:
	var birds := put_battlefield(0, "Birds of Paradise")
	assert_ok(g.tap_for_mana(0, birds, 3))   # index 3 = red
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1)


func test_mox_taps_the_turn_it_arrives() -> void:
	var mox := give_hand(0, "Mox Ruby")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.cast_spell(0, mox, []))   # {0}
	resolve_stack()
	assert_ok(g.tap_for_mana(0, mox))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1)
