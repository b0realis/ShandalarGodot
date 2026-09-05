extends GameTest
## Behavior tests for the wave-2 graduated cards and their new mechanics:
## damage-prevention shields (CoPs), tap effects, extra turns, Fog, mana
## triggers, enters-tapped, graveyard targeting, dynamic stats, and the
## hand-reset sorceries.


# ------------------------------------------------- Circles of Protection --

func test_cop_red_eats_a_bolt() -> void:
	# In RESPONSE to the Bolt: the Circle names "a red source of your
	# choice" as it resolves, and the Bolt on the stack is the one it
	# names (lifted 2026-09-02; tests/cards/test_fidelity_2026_09_02_sources.gd).
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "shield ate the whole bolt")
	assert_eq(g.players[0].prevention_shield_filters.size(), 0, "one-shot")


func test_cop_wrong_color_does_nothing() -> void:
	var cop := put_battlefield(0, "Circle of Protection: Blue")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "blue shield ignores red damage")


func test_cop_shields_expire_at_cleanup() -> void:
	var cop := put_battlefield(0, "Circle of Protection: Red")
	put_battlefield(1, "Hill Giant")   # a red source for the Circle to name
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	assert_eq(g.players[0].prevention_shield_filters.size(), 1)
	advance_to_next_turn()
	assert_eq(g.players[0].prevention_shield_filters.size(), 0, "this-turn only")


# ------------------------------------------------------- Icy Manipulator --

func test_icy_taps_a_blocker() -> void:
	var icy := put_battlefield(0, "Icy Manipulator")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(wall)]))
	resolve_stack()
	assert_true(wall.tapped, "tapped by Icy — can't block this combat")
	assert_true(icy.tapped)


# ------------------------------------------------------------- Time Walk --

func test_time_walk_grants_an_extra_turn() -> void:
	var walk := give_hand(0, "Time Walk")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, walk, []))
	resolve_stack()
	var this_turn := g.turn_number
	advance_to_next_turn()
	assert_eq(g.turn_number, this_turn + 1)
	assert_eq(g.active_player, 0, "P0 goes again")
	advance_to_next_turn()
	assert_eq(g.active_player, 1, "then the turn passes normally")


# ------------------------------------------------------------------- Fog --

func test_fog_blanks_an_alpha_strike() -> void:
	var serra := put_battlefield(0, "Serra Angel")
	var mammoth := put_battlefield(0, "War Mammoth")
	var fog := give_hand(1, "Fog")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [serra.id, mammoth.id]))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, fog, []))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "seven power, zero damage")
	advance_to_next_turn()
	assert_false(g.combat_damage_prevented, "Fog lifts at cleanup")


# ---------------------------------------------- Mana Flare & Wild Growth --

func test_mana_flare_doubles_land_taps_for_both_players() -> void:
	put_battlefield(0, "Mana Flare")
	var my_mountain := put_battlefield(0, "Mountain")
	var their_swamp := put_battlefield(1, "Swamp")
	assert_ok(g.tap_for_mana(0, my_mountain))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 2, "1 + Flare bonus")
	assert_ok(g.tap_for_mana(1, their_swamp))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.B), 2, "symmetric, as printed")


func test_wild_growth_only_boosts_its_host() -> void:
	var forest1 := put_battlefield(0, "Forest")
	var forest2 := put_battlefield(0, "Forest")
	var growth := give_hand(0, "Wild Growth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(forest1)]))
	resolve_stack()
	g.players[0].mana_pool.clear()
	assert_ok(g.tap_for_mana(0, forest1))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 2, "host: 1 + bonus {G}")
	assert_ok(g.tap_for_mana(0, forest2))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 3, "other forest: no bonus")


# -------------------------------------------------- Disk & Howling Mine --

func test_disk_enters_tapped_then_wipes_everything() -> void:
	var disk := give_hand(0, "Nevinyrral's Disk")
	var serra := put_battlefield(1, "Serra Angel")
	var moon := put_battlefield(1, "Bad Moon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, disk, []))
	resolve_stack()
	assert_true(disk.tapped, "enters tapped")
	assert_refused(g.activate_ability(0, disk, 0, []), "already tapped")
	advance_to_next_turn()
	advance_to_next_turn()   # back to P0; disk untapped in P0's untap step
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, disk, 0, []))
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(moon.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD, "dies in its own blast")


func test_howling_mine_feeds_both_players() -> void:
	put_battlefield(0, "Howling Mine")
	var lib1_before := g.players[1].library.size()
	advance_to_next_turn()   # P1's turn: draw step draws 1 + Mine's 1
	resolve_stack()
	assert_eq(g.players[1].library.size(), lib1_before - 2, "normal draw + Mine draw")


# ----------------------------------------- graveyard reach & hand resets --

func test_raise_dead_recovers_a_dead_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear, false)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	var raise := give_hand(0, "Raise Dead")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, raise, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)


func test_raise_dead_cannot_reach_the_opponents_graveyard() -> void:
	var their_bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(their_bear, false)
	var raise := give_hand(0, "Raise Dead")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.cast_spell(0, raise, [TargetRef.card(their_bear)]), "Illegal target")


func test_wheel_resets_both_hands() -> void:
	give_hand(0, "Forest")
	give_hand(1, "Forest")
	give_hand(1, "Forest")
	var wheel := give_hand(0, "Wheel of Fortune")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, wheel, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 7)
	assert_eq(g.players[1].hand.size(), 7)
	assert_gte(g.players[1].graveyard.size(), 2, "old hand went to the graveyard")


func test_timetwister_shuffles_graveyards_away() -> void:
	var dead_bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(dead_bear, false)
	var twister := give_hand(0, "Timetwister")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, twister, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 7)
	assert_eq(g.players[1].hand.size(), 7)
	assert_eq(g.players[0].graveyard.size(), 1,
		"only Timetwister itself — it was on the stack while resolving (CR 608.2m)")
	assert_eq(g.players[0].graveyard[0].data.card_name, "Timetwister")


# --------------------------------------------------- assorted wave-2 kit --

func test_royal_assassin_executes_a_tapped_attacker() -> void:
	var assassin := put_battlefield(1, "Royal Assassin")
	var serra := put_battlefield(0, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))   # bear taps; Serra stays home
	assert_ok(g.pass_priority(0))                  # P1 receives priority
	assert_refused(g.activate_ability(1, assassin, 0, [TargetRef.card(serra)]),
		"Illegal target")   # Serra is untapped — not a legal execution
	assert_ok(g.activate_ability(1, assassin, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "tapped attacker executed pre-damage")


func test_nightmare_grows_with_swamps() -> void:
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Underground Sea")   # swamp subtype counts
	var nightmare := put_battlefield(0, "Nightmare")
	assert_eq(nightmare.cur_power, 3)
	assert_eq(nightmare.cur_toughness, 3)
	put_battlefield(0, "Swamp")
	assert_eq(nightmare.cur_power, 4, "recalculates as swamps arrive")


func test_pestilence_melts_a_board_then_sacrifices_itself() -> void:
	var pest := put_battlefield(0, "Pestilence")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, pest, 0, []))
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD, "1 damage kills the 2/1")
	assert_eq(g.players[0].life, 19, "hits both players")
	assert_eq(g.players[1].life, 19)
	advance_to_step(Mtg.Step.END)
	resolve_stack()   # no creatures anywhere -> sacrifice trigger
	assert_eq(pest.zone, Mtg.Zone.GRAVEYARD, "sacrificed with no creatures around")


func test_drain_life_damages_and_heals() -> void:
	g.players[0].life = 10
	var drain := give_hand(0, "Drain Life")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 4)   # {B} + X=3 in black (lifted 2026-09-02)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].life, 13, "gained the drained 3")


func test_drain_life_gain_capped_by_creature_toughness() -> void:
	g.players[0].life = 10
	var lions := put_battlefield(1, "Savannah Lions")   # 2/1
	var drain := give_hand(0, "Drain Life")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 4)   # {B} + X=3 in black (lifted 2026-09-02)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, drain, [TargetRef.card(lions)], 3))
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 11, "gain capped at toughness 1, not X=3")


func test_flight_lets_a_bear_block_a_djinn() -> void:
	var djinn := put_battlefield(0, "Mahamoti Djinn")
	var bear := put_battlefield(1, "Grizzly Bears")
	var flight := give_hand(1, "Flight")
	advance_to_next_turn()   # P1's turn to enchant
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, flight, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()   # P0's turn: djinn attacks
	run_combat([djinn.id], {bear.id: djinn.id})
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "block was legal thanks to Flight")


func test_castle_bonus_only_while_untapped() -> void:
	put_battlefield(0, "Castle")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(bear.cur_toughness, 4, "2 + Castle's +0/+2")
	run_combat([bear.id])
	assert_eq(bear.cur_toughness, 2, "tapped attacker loses the Castle bonus")


func test_armageddon_scorches_all_lands() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Tundra")
	var geddon := give_hand(0, "Armageddon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, geddon, []))
	resolve_stack()
	for pl in g.players:
		for inst in pl.battlefield:
			assert_false(inst.data.is_land(), "no land survives")


func test_disenchant_answers_an_aura() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(1, "Holy Strength")
	var disenchant := give_hand(0, "Disenchant")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, aura, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.pass_priority(1))
	assert_ok(g.cast_spell(0, disenchant, [TargetRef.card(aura)]))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.cur_power, 2, "back to printed stats")
