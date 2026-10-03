extends GameTest
## Pack 8, batch B3 — Mirage's black and red creatures with rules text
## (cards/sets/mir/_creatures.gd): every clause through the real API, with
## the edges each one prints (timing riders, caps, last known information,
## who chooses, the source leaving, both players).

func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


class Seat extends DecisionAgent:
	var option := 0
	var card_name := ""
	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			_options: Array[String], _hint: int) -> int:
		return option
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for c in candidates:
			if c.data.card_name == card_name: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_discard(_game: MtgGame, _pid: int, _count: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for c in _game.players[_pid].hand:
			if c.data.card_name == card_name: out.append(c)
		if out.is_empty(): out.append(_game.players[_pid].hand[0])
		return out


func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst


func _on_top(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.put_from_hand_on_top_of_library(inst)
	return inst


## P0 attacks with [param attackers], P1 blocks with [param blocks]
## (blocker id -> attacker id); P0 holds priority in declare blockers.
func _fight(attackers: Array, blocks: Dictionary) -> void:
	var ids: Array = []
	for inst in attackers: ids.append(inst.id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))
	resolve_stack()
	assert_eq(g.priority_player, 0)


func test_abyssal_hunter_taps_and_hits_for_its_live_power() -> void:
	var hunter := put_battlefield(0, "Abyssal Hunter")
	var giant := put_battlefield(1, "Hill Giant")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(hunter)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, hunter, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "4 damage from a Giant-Grown Hunter")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.untap_permanent(hunter)
	advance_to_next_turn()
	advance_to_next_turn()
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, hunter, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.tapped)
	assert_eq(bear.damage, 1, "back to its printed 1 power")


func test_abyssal_hunter_uses_last_known_power_after_leaving() -> void:
	var hunter := put_battlefield(0, "Abyssal Hunter")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, hunter, 0, [TargetRef.card(bear)]))
	g.destroy(hunter)
	resolve_stack()
	assert_true(bear.tapped)
	assert_eq(bear.damage, 1, "CR 608.2h: the power it had as it left")


func test_barbed_back_wurm_shrinks_only_a_green_creature_blocking_it() -> void:
	var wurm := put_battlefield(0, "Barbed-Back Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var idle := put_battlefield(1, "Grizzly Bears")
	_fight([wurm], {bear.id: wurm.id, giant.id: wurm.id})
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.activate_ability(0, wurm, 0, [TargetRef.card(giant)]), "")
	assert_refused(g.activate_ability(0, wurm, 0, [TargetRef.card(idle)]), "")
	assert_ok(g.activate_ability(0, wurm, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 1])


func test_blighted_shaman_eats_a_swamp_or_a_creature() -> void:
	var shaman := put_battlefield(0, "Blighted Shaman")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, shaman, 0, [TargetRef.card(bear)]), "Swamp")
	var swamp := put_battlefield(0, "Swamp")
	assert_ok(g.activate_ability(0, shaman, 0, [TargetRef.card(bear)]))
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.cur_power, 3)
	g.untap_permanent(shaman)
	var seat := Seat.new()
	seat.card_name = "Blighted Shaman"
	g.set_agent(0, seat)
	assert_ok(g.activate_ability(0, shaman, 1, [TargetRef.card(bear)]))
	assert_eq(shaman.zone, Mtg.Zone.GRAVEYARD, "\"Sacrifice a creature\" may eat the Shaman itself")
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [5, 5])


func test_self_pumping_black_bodies() -> void:
	var stealer := put_battlefield(0, "Breathstealer")
	var wraith := put_battlefield(0, "Dirtwater Wraith")
	var horror := put_battlefield(0, "Fetid Horror")
	assert_true(wraith.cur_landwalk.has("swamp"), "swampwalk")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.activate_ability(0, stealer, 0))
	assert_ok(g.activate_ability(0, wraith, 0))
	assert_ok(g.activate_ability(0, horror, 0))
	resolve_stack()
	assert_eq([stealer.cur_power, stealer.cur_toughness], [3, 1])
	assert_eq([wraith.cur_power, wraith.cur_toughness], [2, 3])
	assert_eq([horror.cur_power, horror.cur_toughness], [2, 3])
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, stealer, 0))
	resolve_stack()
	assert_eq(stealer.zone, Mtg.Zone.GRAVEYARD, "+1/-1 twice is a 0-toughness Breathstealer")


func test_mire_shade_grows_only_as_a_sorcery() -> void:
	var shade := put_battlefield(0, "Mire Shade")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, shade, 0))
	assert_refused(g.activate_ability(0, shade, 0), "sorcery")
	resolve_stack()
	assert_eq(int(shade.counters.get("+1/+1", 0)), 1)
	assert_eq([shade.cur_power, shade.cur_toughness], [2, 2])
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, shade, 0), "sorcery")


func test_restless_dead_regenerates() -> void:
	var dead := put_battlefield(0, "Restless Dead")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, dead, 0))
	resolve_stack()
	g.destroy(dead)
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(dead.tapped)


func test_sewer_rats_pay_life_three_times_a_turn() -> void:
	var rats := put_battlefield(0, "Sewer Rats")
	add_mana(0, Mtg.ManaColor.B, 4)
	for n in 3: assert_ok(g.activate_ability(0, rats, 0))
	assert_refused(g.activate_ability(0, rats, 0), "3 times")
	assert_eq(g.players[0].life, 17)
	resolve_stack()
	assert_eq(rats.cur_power, 4)
	advance_to_next_turn()
	advance_to_next_turn()
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, rats, 0))
	resolve_stack()


func test_shadow_guildmage_returns_a_stolen_creature_to_its_owners_library() -> void:
	var mage := put_battlefield(0, "Shadow Guildmage")
	var stolen := put_battlefield(1, "Grizzly Bears")
	g.change_control(stolen, 0)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, mage, 0, [TargetRef.card(stolen)]))
	resolve_stack()
	assert_eq(g.players[1].library.back(), stolen, "its OWNER's library")


func test_shadow_guildmage_pings_a_target_and_its_controller() -> void:
	var mage := put_battlefield(0, "Shadow Guildmage")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, mage, 1, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(g.players[0].life, 19)


func test_spirit_of_the_night_has_first_strike_only_while_attacking() -> void:
	var spirit := put_battlefield(0, "Spirit of the Night")
	assert_false(spirit.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_true(spirit.has_keyword(Mtg.Keyword.HASTE))
	assert_eq(spirit.cur_protection & Mtg.ManaColor.B, Mtg.ManaColor.B)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [spirit.id]))
	assert_true(spirit.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(spirit.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_tainted_specter_discard_burns_everyone() -> void:
	var specter := put_battlefield(0, "Tainted Specter")
	var bear := put_battlefield(1, "Grizzly Bears")
	var seat := Seat.new()
	seat.option = 1
	seat.card_name = "Hill Giant"
	g.set_agent(1, seat)
	give_hand(1, "Lightning Bolt")
	var giant := give_hand(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, specter, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the target player chose the discard")
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[1].life, 19)
	assert_eq(bear.damage, 1)
	assert_eq(specter.damage, 1, "each creature, its own source included")


func test_tainted_specter_top_of_library_spares_everyone() -> void:
	var specter := put_battlefield(0, "Tainted Specter")
	var seat := Seat.new()
	seat.option = 0
	seat.card_name = "Hill Giant"
	g.set_agent(1, seat)
	var giant := give_hand(1, "Hill Giant")
	give_hand(1, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, specter, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].library.back(), giant)
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(g.players[0].life, 20)
	assert_eq(specter.damage, 0)


func test_tainted_specter_empty_hand_and_sorcery_timing() -> void:
	var specter := put_battlefield(0, "Tainted Specter")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, specter, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "no card to discard, no damage")
	g.untap_permanent(specter)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, specter, 0, [TargetRef.player(1)]), "sorcery")


func test_urborg_panther_kills_a_creature_blocking_it() -> void:
	var panther := put_battlefield(0, "Urborg Panther")
	var bear := put_battlefield(1, "Grizzly Bears")
	var idle := put_battlefield(1, "Grizzly Bears")
	_fight([panther], {bear.id: panther.id})
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.activate_ability(0, panther, 0, [TargetRef.card(idle)]), "")
	assert_ok(g.activate_ability(0, panther, 0, [TargetRef.card(bear)]))
	assert_eq(panther.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the block outlives the sacrificed Panther")


func test_urborg_panther_assembles_spirit_of_the_night() -> void:
	var panther := put_battlefield(0, "Urborg Panther")
	var stealer := put_battlefield(0, "Breathstealer")
	var spirit := _on_top(0, "Spirit of the Night")
	assert_refused(g.activate_ability(0, panther, 1), "")
	var shadow := put_battlefield(0, "Feral Shadow")
	assert_ok(g.activate_ability(0, panther, 1))
	assert_eq(panther.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(stealer.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(shadow.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(spirit.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(spirit.controller_id, 0)


func test_wall_of_corpses_kills_what_it_blocks() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Corpses")
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	_fight([giant, bear], {wall.id: giant.id})
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_refused(g.activate_ability(1, wall, 0, [TargetRef.card(bear)]), "")
	assert_ok(g.activate_ability(1, wall, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)


func test_armorer_guildmage_pumps_either_way() -> void:
	var mage := put_battlefield(0, "Armorer Guildmage")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, mage, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.untap_permanent(mage)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, mage, 1, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])


func test_burning_palm_efreet_burns_and_grounds_a_flyer() -> void:
	var efreet := put_battlefield(0, "Burning Palm Efreet")
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, efreet, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, efreet, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.damage, 2)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING), "until end of turn")


func test_crimson_hellkite_spends_only_red_on_x() -> void:
	var kite := put_battlefield(0, "Crimson Hellkite")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_refused(g.activate_ability(0, kite, 0, [TargetRef.card(giant)], 3), "mana")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, kite, 0, [TargetRef.card(giant)], 3))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 3, "the green was never spent")


func test_dwarven_miner_destroys_only_nonbasic_lands() -> void:
	var miner := put_battlefield(0, "Dwarven Miner")
	var forest := put_battlefield(1, "Forest")
	var bayou := put_battlefield(1, "Bayou")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_refused(g.activate_ability(0, miner, 0, [TargetRef.card(forest)]))
	assert_ok(g.activate_ability(0, miner, 0, [TargetRef.card(bayou)]))
	resolve_stack()
	assert_eq(bayou.zone, Mtg.Zone.GRAVEYARD)


func test_dwarven_nomad_sneaks_a_small_creature_past_blockers() -> void:
	var nomad := put_battlefield(0, "Dwarven Nomad")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Corpses")
	assert_refused(g.activate_ability(0, nomad, 0, [TargetRef.card(giant)]))
	assert_ok(g.activate_ability(0, nomad, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: bear.id}))


func test_flame_elemental_burns_for_the_power_it_died_with() -> void:
	var elemental := put_battlefield(0, "Flame Elemental")
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(elemental)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, elemental, 0, [TargetRef.card(djinn)]))
	assert_eq(elemental.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(djinn.zone, Mtg.Zone.GRAVEYARD, "6 damage: 3 printed + 3 from Giant Growth")


func test_goblin_soothsayer_pumps_red_creatures_for_a_goblin() -> void:
	var sayer := put_battlefield(0, "Goblin Soothsayer")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, sayer, 0))
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD, "another Goblin is eaten before the source")
	resolve_stack()
	assert_eq(giant.cur_power, 4, "every red creature")
	assert_eq(sayer.cur_power, 2)
	assert_eq(bear.cur_power, 2)


func test_goblin_tinkerer_takes_the_artifacts_mana_value_in_damage() -> void:
	var tinkerer := put_battlefield(0, "Goblin Tinkerer")
	var ring := put_battlefield(1, "Sol Ring")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, tinkerer, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(tinkerer.damage, 1)
	var gnomes := put_battlefield(1, "Ersatz Gnomes")
	g.untap_permanent(tinkerer)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, tinkerer, 0, [TargetRef.card(gnomes)]))
	resolve_stack()
	assert_eq(gnomes.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(tinkerer.zone, Mtg.Zone.GRAVEYARD, "three more damage")


func test_hivis_holds_a_dragon_while_tapped() -> void:
	var hivis := put_battlefield(0, "Hivis of the Scale")
	var dragon := put_battlefield(1, "Shivan Dragon")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_true(hivis.data.may_skip_untap)
	assert_refused(g.activate_ability(0, hivis, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, hivis, 0, [TargetRef.card(dragon)]))
	resolve_stack()
	assert_eq(dragon.controller_id, 0)
	g.untap_permanent(hivis)
	assert_eq(dragon.controller_id, 1, "Hivis untapped: the Dragon goes back")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_ok(g.activate_ability(0, hivis, 0, [TargetRef.card(dragon)]))
	resolve_stack()
	assert_eq(dragon.controller_id, 0)
	g.change_control(hivis, 1)
	assert_eq(dragon.controller_id, 1, "you no longer control Hivis: the Dragon goes back")


func test_pyric_salamander_breathes_and_dies_at_end_of_turn() -> void:
	var salamander := put_battlefield(0, "Pyric Salamander")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, salamander, 0))
	assert_ok(g.activate_ability(0, salamander, 0))
	resolve_stack()
	assert_eq(salamander.cur_power, 3)
	salamander.regeneration_shields = 1
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(salamander.zone, Mtg.Zone.BATTLEFIELD, "not before the end step")
	advance_to_next_turn()
	assert_eq(salamander.zone, Mtg.Zone.GRAVEYARD, "sacrificed: regeneration is no help")


func test_raging_spirit_turns_colorless_until_end_of_turn() -> void:
	var spirit := put_battlefield(0, "Raging Spirit")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, spirit, 0))
	resolve_stack()
	assert_eq(spirit.cur_colors, 0)
	advance_to_next_turn()
	assert_eq(spirit.cur_colors, Mtg.ManaColor.R)


func test_reckless_embermage_hurts_itself_too() -> void:
	var mage := put_battlefield(0, "Reckless Embermage")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, mage, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(mage.damage, 1)
	assert_ok(g.activate_ability(0, mage, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(mage.zone, Mtg.Zone.GRAVEYARD)


func test_reckless_embermage_at_itself_takes_two() -> void:
	var mage := put_battlefield(0, "Reckless Embermage")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, mage, 0, [TargetRef.card(mage)]))
	resolve_stack()
	assert_eq(mage.zone, Mtg.Zone.GRAVEYARD)


func test_subterranean_spirit_quakes_ground_creatures_but_not_itself() -> void:
	var spirit := put_battlefield(0, "Subterranean Spirit")
	var bear := put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")
	assert_ok(g.activate_ability(0, spirit, 0))
	resolve_stack()
	assert_eq(bear.damage, 1)
	assert_eq(angel.damage, 0)
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(spirit.damage, 0, "protection from red stops its own damage")


func test_wildfire_emissary_firebreathes() -> void:
	var emissary := put_battlefield(0, "Wildfire Emissary")
	assert_eq(emissary.cur_protection & Mtg.ManaColor.W, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, emissary, 0))
	resolve_stack()
	assert_eq(emissary.cur_power, 3)


func test_zirilan_fetches_a_hasty_dragon_and_exiles_it_at_end_step() -> void:
	var zirilan := put_battlefield(0, "Zirilan of the Claw")
	var dragon := _on_top(0, "Shivan Dragon")
	_on_top(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, zirilan, 0))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(dragon.has_keyword(Mtg.Keyword.HASTE))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [dragon.id]))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.EXILE)


func test_zirilan_exile_spares_a_dragon_that_left_and_returned() -> void:
	var zirilan := put_battlefield(0, "Zirilan of the Claw")
	var dragon := _on_top(0, "Shivan Dragon")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, zirilan, 0))
	resolve_stack()
	g.return_to_hand(dragon)
	g.put_from_hand_into_play(dragon, 0)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "a new object (CR 400.7)")


# ------------------------------------------------- Gravebane Zombie (E7) --
# "If this creature would die, put it on top of its owner's library
# instead." A replacement (CR 614.1): it never dies (CR 700.4), so no DIES
# event — Soul Net, which hears every death, stays silent.

func test_gravebane_zombie_goes_to_the_top_of_its_library_instead_of_dying() -> void:
	put_battlefield(1, "Soul Net")
	var zombie := put_battlefield(0, "Gravebane Zombie")
	g.destroy(zombie)
	assert_eq(zombie.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), zombie, "on top")
	assert_false(g.players[0].graveyard.has(zombie))
	assert_true(g.stack.is_empty(), "it did not die: no dies trigger")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear)
	assert_false(g.stack.is_empty(), "the control: a real death does trigger Soul Net")


func test_gravebane_zombie_every_way_of_dying_is_replaced() -> void:
	var sacrificed := put_battlefield(0, "Gravebane Zombie")
	g.sacrifice_permanent(sacrificed)
	assert_eq(g.players[0].library.back(), sacrificed, "sacrifice")
	var burned := put_battlefield(0, "Gravebane Zombie")
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(burned)]))
	resolve_stack()
	assert_eq(g.players[0].library.back(), burned, "lethal damage (state-based action)")
	assert_eq(burned.damage, 0, "a new object in the library")
	var exiled := put_battlefield(0, "Gravebane Zombie")
	g.exile_permanent(exiled)
	assert_eq(exiled.zone, Mtg.Zone.EXILE, "exile is not dying")
	var bounced := put_battlefield(0, "Gravebane Zombie")
	g.return_to_hand(bounced)
	assert_eq(bounced.zone, Mtg.Zone.HAND, "nor is a bounce")


func test_gravebane_zombie_stolen_goes_to_its_owners_library() -> void:
	var zombie := put_battlefield(1, "Gravebane Zombie")
	g.change_control(zombie, 0)
	var mine := g.players[0].library.size()
	g.destroy(zombie)
	assert_eq(g.players[1].library.back(), zombie, "its OWNER's library")
	assert_eq(g.players[0].library.size(), mine)


func test_gravebane_zombie_token_copy_simply_dies() -> void:
	var made := g.create_token(0, CardRegistry.get_card("Gravebane Zombie"))
	assert_eq(made.size(), 1)
	if made.is_empty(): return
	var size := g.players[0].library.size()
	g.destroy(made[0])
	assert_eq(g.players[0].library.size(), size, "a token is not a card: no replacement")
	assert_false(g.players[0].battlefield.has(made[0]))
