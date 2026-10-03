extends GameTest
## Pack 8, batch B3 — Mirage's white and blue creatures with rules text
## (cards/sets/mir/_creatures.gd). Each test drives the clause that makes
## the card what it is through the real activation/cast API, with the
## edges it prints: illegal targets, timing windows, once-per-turn caps,
## the source leaving, both players.

func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst


## Attack with [param attackers] (P0) and hand priority to P1 in the
## declare-attackers step.
func _attack(attackers: Array) -> void:
	var ids: Array = []
	for inst in attackers: ids.append(inst.id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


## Our own upkeep, two turns on, with priority.
func _own_upkeep() -> void:
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 0)
	assert_eq(g.priority_player, 0)


func test_civic_guildmage_toughens_any_creature_and_stacks_only_your_own() -> void:
	var mage := put_battlefield(0, "Civic Guildmage")
	var bear := put_battlefield(0, "Grizzly Bears")
	var foe := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, mage, 0, [TargetRef.card(foe)]))
	resolve_stack()
	assert_eq([foe.cur_power, foe.cur_toughness], [2, 3], "+0/+1 on any creature")
	g.untap_permanent(mage)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.activate_ability(0, mage, 1, [TargetRef.card(foe)]))
	assert_ok(g.activate_ability(0, mage, 1, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), bear, "on top of its owner's library")
	advance_to_next_turn()
	assert_eq(foe.cur_toughness, 2, "the +0/+1 lasted the turn only")


func test_ethereal_champion_buys_prevention_one_life_at_a_time() -> void:
	var champ := put_battlefield(0, "Ethereal Champion")
	assert_ok(g.activate_ability(0, champ, 0))
	assert_ok(g.activate_ability(0, champ, 0))
	assert_eq(g.players[0].life, 18, "each activation costs 1 life up front")
	resolve_stack()
	g.deal_damage(give_hand(1, "Lightning Bolt"), TargetRef.card(champ), 3)
	assert_eq(champ.damage, 1, "two of the three points prevented")
	assert_eq(champ.zone, Mtg.Zone.BATTLEFIELD)


func test_ethereal_champion_shield_does_not_follow_a_new_object() -> void:
	var champ := put_battlefield(0, "Ethereal Champion")
	assert_ok(g.activate_ability(0, champ, 0))
	g.return_to_hand(champ)
	g.put_from_hand_into_play(champ, 0)
	resolve_stack()
	assert_eq(champ.prevention, 0, "CR 400.7: the returned Champion is a new object")


func test_femeref_healer_shields_any_target_and_needs_to_tap() -> void:
	var sick := put_battlefield(0, "Femeref Healer", true)
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.player(0)]), "summoning")
	var healer := put_battlefield(0, "Femeref Healer")
	assert_ok(g.activate_ability(0, healer, 0, [TargetRef.player(0)]))
	resolve_stack()
	g.deal_damage(give_hand(1, "Lightning Bolt"), TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 18, "one point prevented")
	assert_true(healer.tapped)


func test_mtenda_griffin_trades_itself_for_a_griffin_card_in_your_upkeep() -> void:
	var griffin := put_battlefield(0, "Mtenda Griffin")
	var fallen := _grave(0, "Teremko Griffin")
	var bear := _grave(0, "Grizzly Bears")
	var theirs := _grave(1, "Ekundu Griffin")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, griffin, 0, [TargetRef.card(fallen)]), "upkeep")
	_own_upkeep()
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, griffin, 0, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(0, griffin, 0, [TargetRef.card(theirs)]))
	assert_ok(g.activate_ability(0, griffin, 0, [TargetRef.card(fallen)]))
	resolve_stack()
	assert_eq(griffin.zone, Mtg.Zone.HAND)
	assert_eq(fallen.zone, Mtg.Zone.HAND)


func test_mtenda_griffin_fizzles_whole_when_the_griffin_card_is_gone() -> void:
	var griffin := put_battlefield(0, "Mtenda Griffin")
	var fallen := _grave(0, "Teremko Griffin")
	_own_upkeep()
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, griffin, 0, [TargetRef.card(fallen)]))
	g.exile_from_graveyard(fallen)
	resolve_stack()
	assert_eq(griffin.zone, Mtg.Zone.BATTLEFIELD, "its only target is illegal: nothing happens")


func test_mtenda_griffin_cannot_be_used_in_the_opponents_upkeep() -> void:
	var theirs := put_battlefield(1, "Mtenda Griffin")
	var fallen := _grave(1, "Ekundu Griffin")
	_own_upkeep()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(1, theirs, 0, [TargetRef.card(fallen)]), "your turn")
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(fallen.zone, Mtg.Zone.GRAVEYARD)


func test_pearl_dragon_firebreathes_toughness() -> void:
	var dragon := put_battlefield(0, "Pearl Dragon")
	assert_true(dragon.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, dragon, 0))
	assert_ok(g.activate_ability(0, dragon, 0))
	resolve_stack()
	assert_eq([dragon.cur_power, dragon.cur_toughness], [4, 6])


func test_rashida_slays_an_attacking_dragon_through_regeneration_and_gains_its_power() -> void:
	var rashida := put_battlefield(1, "Rashida Scalebane")
	var dragon := put_battlefield(0, "Shivan Dragon")
	var bear := put_battlefield(0, "Grizzly Bears")
	var idle := put_battlefield(0, "Shivan Dragon")
	g.change_control(idle, 1)   # a Dragon not in combat
	_attack([dragon, bear])
	assert_refused(g.activate_ability(1, rashida, 0, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(1, rashida, 0, [TargetRef.card(idle)]))
	dragon.regeneration_shields = 1
	assert_ok(g.activate_ability(1, rashida, 0, [TargetRef.card(dragon)]))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD, "it can't be regenerated")
	assert_eq(g.players[1].life, 25, "life equal to its power")


func test_spectral_guardian_shrouds_noncreature_artifacts_only_while_untapped() -> void:
	var guardian := put_battlefield(1, "Spectral Guardian")
	var ring := put_battlefield(1, "Sol Ring")
	var gnomes := put_battlefield(1, "Ersatz Gnomes")
	var mine := put_battlefield(0, "Sol Ring")
	var shatter := give_hand(0, "Shatter")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, shatter, [TargetRef.card(ring)]))
	assert_refused(g.cast_spell(0, shatter, [TargetRef.card(mine)]), "abilities")   # anyone's noncreature artifacts
	assert_ok(g.cast_spell(0, shatter, [TargetRef.card(gnomes)]))
	resolve_stack()
	assert_eq(gnomes.zone, Mtg.Zone.GRAVEYARD, "an artifact creature is not covered")
	g.tap_permanent(guardian)
	var again := give_hand(0, "Shatter")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, again, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)


func test_unyaro_griffin_counters_only_red_instants_and_sorceries() -> void:
	var griffin := put_battlefield(1, "Unyaro Griffin")
	var bear := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, griffin, 0, [TargetRef.card(growth)]))
	resolve_stack()
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, griffin, 0, [TargetRef.card(bolt)]))
	assert_eq(griffin.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "the Bolt was countered")


func test_vigilant_martyr_regenerates_a_creature_by_dying() -> void:
	var martyr := put_battlefield(0, "Vigilant Martyr")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, martyr, 0, [TargetRef.card(bear)]))
	assert_eq(martyr.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(bear.tapped)


func test_vigilant_martyr_counters_only_a_spell_that_targets_an_enchantment() -> void:
	var martyr := put_battlefield(1, "Vigilant Martyr")
	var crusade := put_battlefield(1, "Crusade")
	var ring := put_battlefield(1, "Sol Ring")
	var at_ring := give_hand(0, "Disenchant")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, at_ring, [TargetRef.card(ring)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W, 2)
	assert_refused(g.activate_ability(1, martyr, 1, [TargetRef.card(at_ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	var at_crusade := give_hand(0, "Disenchant")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, at_crusade, [TargetRef.card(crusade)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W, 2)
	assert_ok(g.activate_ability(1, martyr, 1, [TargetRef.card(at_crusade)]))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD, "the Disenchant was countered")
	assert_eq(martyr.zone, Mtg.Zone.GRAVEYARD)


func test_zuberi_pumps_every_other_griffin() -> void:
	var zuberi := put_battlefield(0, "Zuberi, Golden Feather")
	var ours := put_battlefield(0, "Teremko Griffin")
	var theirs := put_battlefield(1, "Ekundu Griffin")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq([zuberi.cur_power, zuberi.cur_toughness], [3, 3], "not itself")
	assert_eq([ours.cur_power, ours.cur_toughness], [3, 3])
	assert_eq([theirs.cur_power, theirs.cur_toughness], [3, 3], "every Griffin, either side")
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2])
	g.destroy(zuberi)
	assert_eq(ours.cur_power, 2)


func test_azimaet_drake_pumps_once_each_turn() -> void:
	var drake := put_battlefield(0, "Azimaet Drake")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.activate_ability(0, drake, 0))
	assert_refused(g.activate_ability(0, drake, 0), "once")
	resolve_stack()
	assert_eq(drake.cur_power, 2)
	advance_to_next_turn()
	assert_eq(drake.cur_power, 1)


func test_daring_apprentice_counters_any_spell_by_dying() -> void:
	var apprentice := put_battlefield(1, "Daring Apprentice")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, apprentice, 0, [TargetRef.card(bear)]))
	assert_eq(apprentice.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_hakim_raises_an_aura_onto_himself_in_your_upkeep_while_unenchanted() -> void:
	var hakim := put_battlefield(0, "Hakim, Loreweaver")
	var strength := _grave(0, "Holy Strength")
	var other := _grave(0, "Holy Strength")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.activate_ability(0, hakim, 0, [TargetRef.card(strength)]), "upkeep")
	_own_upkeep()
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.activate_ability(0, hakim, 0, [TargetRef.card(strength)]))
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(strength.attached_to, hakim.id)
	assert_eq([hakim.cur_power, hakim.cur_toughness], [3, 6])
	assert_refused(g.activate_ability(0, hakim, 0, [TargetRef.card(other)]), "enchanted")


func test_hakim_leaves_an_aura_that_cannot_enchant_him_in_the_graveyard() -> void:
	var hakim := put_battlefield(0, "Hakim, Loreweaver")
	var growth := _grave(0, "Wild Growth")
	_own_upkeep()
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.activate_ability(0, hakim, 0, [TargetRef.card(growth)]))
	resolve_stack()
	assert_eq(growth.zone, Mtg.Zone.GRAVEYARD, "an Enchant land Aura can't be attached to Hakim")
	assert_eq(hakim.attachments.size(), 0)


func test_hakim_destroys_every_aura_attached_to_him() -> void:
	var hakim := put_battlefield(0, "Hakim, Loreweaver")
	var bear := put_battlefield(1, "Grizzly Bears")
	var mine := give_hand(0, "Holy Strength")
	var theirs := give_hand(1, "Unholy Strength")
	var elsewhere := give_hand(1, "Unholy Strength")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, mine, [TargetRef.card(hakim)]))
	resolve_stack()
	g.players[1].hand.erase(theirs)
	g.attach_aura_from_anywhere(theirs, hakim, 1)
	g.players[1].hand.erase(elsewhere)
	g.attach_aura_from_anywhere(elsewhere, bear, 1)
	assert_eq(hakim.cur_power, 5)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.activate_ability(0, hakim, 1))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(elsewhere.zone, Mtg.Zone.BATTLEFIELD, "only the Auras on Hakim")
	assert_eq([hakim.cur_power, hakim.cur_toughness], [2, 4])
	assert_true(hakim.tapped)


func test_harmattan_efreet_lends_flying_until_end_of_turn() -> void:
	var efreet := put_battlefield(0, "Harmattan Efreet")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, efreet, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING))


func test_kukemssa_serpent_needs_an_island_across_the_table_to_attack() -> void:
	var serpent := put_battlefield(0, "Kukemssa Serpent")
	put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [serpent.id]))
	put_battlefield(1, "Island")
	assert_ok(g.declare_attackers(0, [serpent.id]))


func test_kukemssa_serpent_islands_an_enemy_land_and_dies_without_islands() -> void:
	var serpent := put_battlefield(0, "Kukemssa Serpent")
	var island := put_battlefield(0, "Island")
	var forest := put_battlefield(1, "Forest")
	var own_forest := put_battlefield(0, "Forest")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.activate_ability(0, serpent, 0, [TargetRef.card(own_forest)]), "")
	assert_ok(g.activate_ability(0, serpent, 0, [TargetRef.card(forest)]))
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD, "an Island is sacrificed as the cost")
	resolve_stack()
	assert_eq(serpent.zone, Mtg.Zone.GRAVEYARD, "no Islands left: sacrificed")
	assert_true(forest.has_subtype("island"), "the ability still resolves")
	assert_false(forest.has_subtype("forest"), "it loses its other land types (CR 305.7)")
	advance_to_next_turn()
	assert_true(forest.has_subtype("forest"), "until end of turn only")


func test_shaper_guildmage_grants_first_strike_or_power() -> void:
	var mage := put_battlefield(0, "Shaper Guildmage")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, mage, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	g.untap_permanent(mage)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, mage, 1, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3)


func test_suq_ata_firewalker_turns_away_red_and_pings() -> void:
	var walker := put_battlefield(1, "Suq'Ata Firewalker")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(walker)]), "abilities")   # a red spell
	var artillery := put_battlefield(0, "Orcish Artillery")
	assert_refused(g.activate_ability(0, artillery, 0, [TargetRef.card(walker)]), "abilities")   # a red source
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(walker)]))   # a blue source may
	resolve_stack()
	assert_eq(walker.zone, Mtg.Zone.GRAVEYARD)
	var second := put_battlefield(1, "Suq'Ata Firewalker")
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, second, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 19)


func test_suq_ata_firewalker_ban_follows_the_sources_live_colour() -> void:
	var walker := put_battlefield(1, "Suq'Ata Firewalker")
	var artillery := put_battlefield(0, "Orcish Artillery")
	var gnomes := put_battlefield(0, "Ersatz Gnomes")
	assert_ok(g.activate_ability(0, gnomes, 1, [TargetRef.card(artillery)]))
	resolve_stack()
	assert_eq(artillery.cur_colors, 0)
	assert_ok(g.activate_ability(0, artillery, 0, [TargetRef.card(walker)]))   # colourless now
	resolve_stack()
	assert_eq(walker.zone, Mtg.Zone.GRAVEYARD)


func test_wave_elemental_taps_up_to_three_creatures_without_flying() -> void:
	var wave := put_battlefield(0, "Wave Elemental")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	var c := put_battlefield(1, "Hill Giant")
	var d := put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.activate_ability(0, wave, 0, [TargetRef.card(angel)]))
	assert_refused(g.activate_ability(0, wave, 0, [TargetRef.card(a), TargetRef.card(b), TargetRef.card(c), TargetRef.card(d)]))
	assert_ok(g.activate_ability(0, wave, 0, [TargetRef.card(a), TargetRef.card(b), TargetRef.card(c)]))
	assert_eq(wave.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_true(a.tapped and b.tapped and c.tapped)
	assert_false(d.tapped)
	assert_false(angel.tapped)


func test_wave_elemental_may_choose_no_targets() -> void:
	var wave := put_battlefield(0, "Wave Elemental")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, wave, 0, []))
	resolve_stack()
	assert_eq(wave.zone, Mtg.Zone.GRAVEYARD)


## A seat that asks for the 1997 damage windows (RulesOptions fork,
## docs/duel-todo.md §6.8).
class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func test_femeref_healer_answers_damage_in_the_1997_prevention_window() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(1, Duelist.new())
	var healer := put_battlefield(1, "Femeref Healer")
	var shaper := put_battlefield(1, "Shaper Guildmage")
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the Healer is a reason to open it")
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(1, shaper, 1, [TargetRef.card(healer)]))
	assert_ok(g.activate_ability(1, healer, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention: assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(g.players[1].life, 15, "one of the Wurm's six points prevented after it was dealt")
