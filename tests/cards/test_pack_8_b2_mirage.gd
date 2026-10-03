extends GameTest
## Pack 8, batch B2 — Mirage's combat cards without flanking
## (cards/sets/mir/_combat.gd): combat tricks, block and attack
## restrictions, "blocks or becomes blocked" triggers (one per blocking
## creature, a band's blockers counting for every member — CR 702.22h),
## "attacks and isn't blocked" triggers, and whose choice every "may" is.

class Seat extends DecisionAgent:
	var yes := -1
	var option := -1
	var prefer: Array = []
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			_options: Array[String], hint: int) -> int:
		asked.append(prompt)
		return hint if option < 0 else option

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _attack(ids: Array, bands: Array = []) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids, bands))


func _attack_and_block(ids: Array, blocks: Dictionary, bands: Array = []) -> void:
	_attack(ids, bands)
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))


func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst


## Player 1's creatures attack player 0: from player 0's MAIN1 to player
## 1's declare-attackers step.
func _their_attack(ids: Array) -> void:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)


func _tokens(pid: int, name: String) -> Array:
	return g.players[pid].battlefield.filter(func(i: CardInstance) -> bool:
		return i.is_token and i.data.card_name == name)


# ================================================================== white

func test_alarum_untaps_a_nonattacking_creature_and_pumps_it() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.tap_permanent(bear)
	var alarum := give_hand(0, "Alarum")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, alarum, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.tapped)
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 5])


func test_alarum_can_t_target_an_attacking_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	_attack([bear.id])
	resolve_stack()
	var alarum := give_hand(0, "Alarum")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, alarum, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, alarum, [TargetRef.card(giant)]))


func test_dazzling_beauty_only_in_the_declare_blockers_step() -> void:
	var beauty := give_hand(0, "Dazzling Beauty")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, beauty, []), "declare blockers")


func test_dazzling_beauty_blocks_an_unblockable_attacker_and_draws_next_upkeep() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.UNBLOCKABLE])
	g.recalculate()
	_attack_and_block([bear.id], {})
	assert_ok(g.pass_priority(0))
	var beauty := give_hand(1, "Dazzling Beauty")
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, beauty, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(g.combat.was_blocked([bear.id]), "works on a creature that can't be blocked")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "a blocked creature with no blocker deals nothing")
	assert_eq(g.players[1].hand.size(), 0)
	advance_to_next_turn()
	assert_eq(g.players[1].hand.size(), 2, "the delayed draw at upkeep plus the draw step")


func test_divine_retribution_counts_the_attackers() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var elves := put_battlefield(0, "Llanowar Elves")
	var home := put_battlefield(1, "Grizzly Bears")
	_attack([bear.id, giant.id, elves.id])
	resolve_stack()
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Divine Retribution")
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(1, spell, [TargetRef.card(home)]))
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "3 attackers: 3 damage")


func test_sunweb_can_t_block_power_two_or_less() -> void:
	var web := put_battlefield(1, "Sunweb")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	_attack([bear.id, giant.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {web.id: bear.id}))
	assert_ok(g.declare_blockers(1, {web.id: giant.id}))


func test_yare_needs_a_defending_player() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var yare := give_hand(0, "Yare")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, yare, [TargetRef.card(bear)]))


func test_yare_pumps_a_defender_that_then_blocks_three() -> void:
	var wall := put_battlefield(1, "Wall of Stone")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var elves := put_battlefield(0, "Llanowar Elves")
	_attack([bear.id, giant.id, elves.id])
	resolve_stack()
	assert_ok(g.pass_priority(0))
	var yare := give_hand(1, "Yare")
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(1, yare, [TargetRef.card(bear)]), "")
	assert_ok(g.cast_spell(1, yare, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.cur_power, 3)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: [bear.id, giant.id, elves.id]}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "one Wall blocked all three")


# =================================================================== blue

func test_coral_fighters_may_bury_the_defender_s_top_card() -> void:
	var fighters := put_battlefield(0, "Coral Fighters")
	var top := _on_library_top(1, "Lightning Bolt")
	me.yes = 1
	_attack_and_block([fighters.id], {})
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(g.players[1].library[0], top, "on the bottom")
	assert_eq(top.zone, Mtg.Zone.LIBRARY)


func test_coral_fighters_may_leave_it() -> void:
	var fighters := put_battlefield(0, "Coral Fighters")
	var top := _on_library_top(1, "Lightning Bolt")
	me.yes = 0
	_attack_and_block([fighters.id], {})
	resolve_stack()
	assert_eq(g.players[1].library.back(), top, "still on top")


func test_kukemssa_pirates_steals_an_artifact_instead_of_damage() -> void:
	var pirates := put_battlefield(0, "Kukemssa Pirates")
	var ring := put_battlefield(1, "Sol Ring")
	_attack_and_block([pirates.id], {})
	resolve_stack()
	assert_eq(ring.controller_id, 0)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "it assigned no combat damage")


func test_kukemssa_pirates_declining_deals_damage() -> void:
	var pirates := put_battlefield(0, "Kukemssa Pirates")
	var ring := put_battlefield(1, "Sol Ring")
	me.yes = 0
	_attack_and_block([pirates.id], {})
	resolve_stack()
	assert_eq(ring.controller_id, 1)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)


func test_kukemssa_pirates_without_an_artifact_has_no_trigger() -> void:
	var pirates := put_battlefield(0, "Kukemssa Pirates")
	put_battlefield(0, "Sol Ring")
	_attack_and_block([pirates.id], {})
	assert_eq(g.stack.size(), 0, "only the defending player's artifacts")


# ================================================================== black

func test_cadaverous_knight_is_a_flanker() -> void:
	assert_eq(Flanking.instances(put_battlefield(0, "Cadaverous Knight")), 1)


func test_catacomb_dragon_halves_a_blocker_s_power() -> void:
	var dragon := put_battlefield(0, "Catacomb Dragon")
	var angel := put_battlefield(1, "Serra Angel")
	_attack_and_block([dragon.id], {angel.id: dragon.id})
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq([angel.cur_power, angel.cur_toughness], [2, 4])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(dragon.damage, 2)


func test_catacomb_dragon_spares_artifact_and_dragon_blockers() -> void:
	var dragon := put_battlefield(0, "Catacomb Dragon")
	var thopter := put_battlefield(1, "Ornithopter")
	var shivan := put_battlefield(1, "Shivan Dragon")
	_attack_and_block([dragon.id], {thopter.id: dragon.id, shivan.id: dragon.id})
	assert_eq(g.stack.size(), 0)


func test_crypt_cobra_poisons_when_unblocked() -> void:
	var cobra := put_battlefield(0, "Crypt Cobra")
	_attack_and_block([cobra.id], {})
	resolve_stack()
	assert_eq(g.players[1].poison, 1)


func test_crypt_cobra_blocked_does_nothing() -> void:
	var cobra := put_battlefield(0, "Crypt Cobra")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([cobra.id], {bear.id: cobra.id})
	resolve_stack()
	assert_eq(g.players[1].poison, 0)


func test_dread_specter_destroys_a_nonblack_blocker_at_end_of_combat() -> void:
	var specter := put_battlefield(0, "Dread Specter")
	var wall := put_battlefield(1, "Wall of Stone")
	_attack_and_block([specter.id], {wall.id: specter.id})
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)


func test_dread_specter_spares_a_black_blocker() -> void:
	var specter := put_battlefield(0, "Dread Specter")
	var zombies := put_battlefield(1, "Scathe Zombies")
	_attack_and_block([specter.id], {zombies.id: specter.id})
	assert_eq(g.stack.size(), 0, "a black blocker triggers nothing")


func test_dread_specter_destroys_the_creature_it_blocks() -> void:
	var specter := put_battlefield(0, "Dread Specter")
	var giant := put_battlefield(1, "Hill Giant")
	_their_attack([giant.id])
	assert_ok(g.declare_blockers(0, {specter.id: giant.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


# ==================================================================== red

func test_aleatory_only_after_blockers_are_declared() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var spell := give_hand(0, "Aleatory")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]), "after blockers")
	_attack([bear.id])
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]), "after blockers")


func test_aleatory_flips_for_the_pump_and_draws_next_upkeep() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var spell := give_hand(0, "Aleatory")
	_attack_and_block([bear.id], {})
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	# The flip is the game's own RNG; read what it will say, then put it back.
	var state := g.rng.state
	var won := (g.rng.randi() % 2) == 0
	g.rng.state = state
	resolve_stack()
	assert_eq(bear.cur_power, 3 if won else 2)
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before + 2,
		"the draw at the NEXT turn's upkeep (the opponent's), then our own draw step")


func test_barreling_attack_tramples_and_grows_per_blocker() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	var spell := give_hand(0, "Barreling Attack")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(giant.has_keyword(Mtg.Keyword.TRAMPLE))
	_attack_and_block([giant.id], {bear.id: giant.id, elves.id: giant.id})
	resolve_stack()
	assert_eq([giant.cur_power, giant.cur_toughness], [5, 5], "+1/+1 for each of two blockers")


func test_barreling_attack_unblocked_gets_nothing_more() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var spell := give_hand(0, "Barreling Attack")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(giant)]))
	resolve_stack()
	_attack_and_block([giant.id], {})
	resolve_stack()
	assert_eq([giant.cur_power, giant.cur_toughness], [3, 3])


func test_blind_fury_doubles_creature_to_creature_combat_damage_only() -> void:
	var mammoth := put_battlefield(0, "War Mammoth")   # 3/3 trample
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")    # 0/8
	_attack_and_block([mammoth.id, bear.id], {wall.id: mammoth.id})
	assert_ok(g.pass_priority(0))
	var fury := give_hand(1, "Blind Fury")
	add_mana(1, Mtg.ManaColor.R, 2)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, fury, []))
	resolve_stack()
	assert_false(mammoth.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(wall.damage, 6, "3 to a creature becomes 6")
	assert_eq(g.players[1].life, 18, "the bear's 2 to a player is not doubled")


func test_crimson_roc_strikes_first_against_a_ground_attacker() -> void:
	var roc := put_battlefield(1, "Crimson Roc")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack_and_block([bear.id], {roc.id: bear.id})
	resolve_stack()
	assert_eq(roc.cur_power, 3)
	assert_true(roc.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(roc.damage, 0)


func test_crimson_roc_against_a_flyer_has_no_trigger() -> void:
	var roc := put_battlefield(1, "Crimson Roc")
	var pegasus := put_battlefield(0, "Mesa Pegasus")
	_attack_and_block([pegasus.id], {roc.id: pegasus.id})
	assert_eq(g.stack.size(), 0)


func test_ekundu_cyclops_attacks_when_another_creature_does() -> void:
	var cyclops := put_battlefield(0, "Ekundu Cyclops")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]), "Ekundu Cyclops")
	assert_ok(g.declare_attackers(0, [bear.id, cyclops.id]))


func test_ekundu_cyclops_may_stay_home_alone() -> void:
	put_battlefield(0, "Ekundu Cyclops")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))


func test_goblin_elite_infantry_shrinks_when_blocked() -> void:
	var goblin := put_battlefield(0, "Goblin Elite Infantry")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([goblin.id], {bear.id: goblin.id})
	resolve_stack()
	assert_eq([goblin.cur_power, goblin.cur_toughness], [1, 1])


func test_goblin_elite_infantry_shrinks_when_it_blocks() -> void:
	var goblin := put_battlefield(0, "Goblin Elite Infantry")
	var bear := put_battlefield(1, "Grizzly Bears")
	_their_attack([bear.id])
	assert_ok(g.declare_blockers(0, {goblin.id: bear.id}))
	resolve_stack()
	assert_eq([goblin.cur_power, goblin.cur_toughness], [1, 1])


func test_goblin_elite_infantry_unblocked_stays_whole() -> void:
	var goblin := put_battlefield(0, "Goblin Elite Infantry")
	_attack_and_block([goblin.id], {})
	resolve_stack()
	assert_eq([goblin.cur_power, goblin.cur_toughness], [2, 2])


func test_searing_spear_askari_is_a_flanker() -> void:
	assert_eq(Flanking.instances(put_battlefield(0, "Searing Spear Askari")), 1)


# ================================================================== green

func test_brushwagg_turns_defensive_when_blocked() -> void:
	var wagg := put_battlefield(0, "Brushwagg")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([wagg.id], {bear.id: wagg.id})
	resolve_stack()
	assert_eq([wagg.cur_power, wagg.cur_toughness], [1, 4])


func test_gibbering_hyenas_can_t_block_black_creatures() -> void:
	var hyenas := put_battlefield(1, "Gibbering Hyenas")
	var zombies := put_battlefield(0, "Scathe Zombies")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([zombies.id, bear.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {hyenas.id: zombies.id}))
	assert_ok(g.declare_blockers(1, {hyenas.id: bear.id}))


func test_jungle_wurm_shrinks_for_each_blocker_beyond_the_first() -> void:
	var wurm := put_battlefield(0, "Jungle Wurm")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	var c := put_battlefield(1, "Hill Giant")
	_attack_and_block([wurm.id], {a.id: wurm.id, b.id: wurm.id, c.id: wurm.id})
	resolve_stack()
	assert_eq([wurm.cur_power, wurm.cur_toughness], [3, 3])


func test_jungle_wurm_with_one_blocker_is_whole() -> void:
	var wurm := put_battlefield(0, "Jungle Wurm")
	var a := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([wurm.id], {a.id: wurm.id})
	resolve_stack()
	assert_eq([wurm.cur_power, wurm.cur_toughness], [5, 5])


func test_mindbender_spores_keep_the_blocked_creature_down() -> void:
	var spores := put_battlefield(1, "Mindbender Spores")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack_and_block([bear.id], {spores.id: bear.id})
	resolve_stack()
	assert_eq(int(bear.counters.get("fungus", 0)), 4)
	advance_to_next_turn()   # player 1's turn
	advance_to_next_turn()   # player 0's: the untap step skips it; upkeep removes one
	assert_true(bear.tapped, "doesn't untap while it has a fungus counter")
	assert_eq(int(bear.counters.get("fungus", 0)), 3)


func test_mindbender_spores_grant_outlives_the_spores_until_the_counters_run_out() -> void:
	var spores := put_battlefield(1, "Mindbender Spores")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack_and_block([bear.id], {spores.id: bear.id})
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(spores.zone, Mtg.Zone.GRAVEYARD, "the 0/1 died to the bear")
	for n in 4:   # four of the bear's upkeeps: 4 -> 0 counters, never untapping
		advance_to_next_turn()
		advance_to_next_turn()
		assert_true(bear.tapped, "upkeep %d" % (n + 1))
		assert_eq(int(bear.counters.get("fungus", 0)), 3 - n)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(bear.tapped, "no fungus counter left: it untaps")


func test_mtenda_lion_s_damage_is_prevented_if_the_defender_pays_u() -> void:
	var lion := put_battlefield(0, "Mtenda Lion")
	var island := put_battlefield(1, "Island")
	_attack([lion.id])
	resolve_stack()
	assert_true(island.tapped, "paid {U}")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)


func test_mtenda_lion_unpaid_deals_damage() -> void:
	var lion := put_battlefield(0, "Mtenda Lion")
	put_battlefield(1, "Island")
	foe.yes = 0
	_attack([lion.id])
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)


func test_sabertooth_cobra_poisons_now_and_again_next_upkeep() -> void:
	var cobra := put_battlefield(0, "Sabertooth Cobra")
	_attack_and_block([cobra.id], {})
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].poison, 1)
	assert_eq(g.settleable_delayed_triggers(1).size(), 1, "the bitten player may pay it off")
	advance_to_next_turn()
	assert_eq(g.players[1].poison, 2, "another at their upkeep")


func test_sabertooth_cobra_paid_off_before_the_upkeep() -> void:
	var cobra := put_battlefield(0, "Sabertooth Cobra")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	_attack_and_block([cobra.id], {})
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].poison, 1)
	assert_ok(g.pass_priority(0))
	var entries := g.settleable_delayed_triggers(1)
	assert_eq(entries.size(), 1)
	assert_ok(g.settle_delayed_trigger(1, int(entries[0]["id"])))
	advance_to_next_turn()
	assert_eq(g.players[1].poison, 1, "paid: no second counter")


# =================================================================== gold

func test_delirium_only_on_an_opponent_s_turn() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Delirium")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)]), "opponent's turn")


func test_delirium_turns_an_attacker_on_its_controller() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	var own := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([angel.id], {})
	assert_ok(g.pass_priority(0))
	var spell := give_hand(1, "Delirium")
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(1, spell, [TargetRef.card(own)]), "")
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(angel)]))
	resolve_stack()
	assert_true(angel.tapped)
	assert_eq(g.players[0].life, 16, "its power, to its controller")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "its combat damage is prevented")


func test_harbor_guardian_offers_the_defender_a_card() -> void:
	var guardian := put_battlefield(0, "Harbor Guardian")
	foe.yes = 1
	_attack([guardian.id])
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)


func test_harbor_guardian_the_defender_may_decline() -> void:
	var guardian := put_battlefield(0, "Harbor Guardian")
	foe.yes = 0
	_attack([guardian.id])
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)
	assert_true(foe.asked.size() > 0, "the DEFENDING player was asked")


func test_rock_basilisk_destroys_a_non_wall_blocker_at_end_of_combat() -> void:
	var basilisk := put_battlefield(0, "Rock Basilisk")
	var golem := put_battlefield(1, "Obsianus Golem")   # 4/6: survives the damage
	_attack_and_block([basilisk.id], {golem.id: basilisk.id})
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD, "destroyed at end of combat")


func test_rock_basilisk_spares_a_wall() -> void:
	var basilisk := put_battlefield(0, "Rock Basilisk")
	var wall := put_battlefield(1, "Wall of Stone")
	_attack_and_block([basilisk.id], {wall.id: basilisk.id})
	assert_eq(g.stack.size(), 0)
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)


# ============================================================== artifacts

func test_basalt_golem_can_t_be_blocked_by_artifact_creatures() -> void:
	var golem := put_battlefield(0, "Basalt Golem")
	var thopter := put_battlefield(1, "Ornithopter")
	_attack([golem.id])
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {thopter.id: golem.id}))


func test_basalt_golem_turns_its_blocker_into_a_wall() -> void:
	var golem := put_battlefield(0, "Basalt Golem")
	var wall := put_battlefield(1, "Wall of Stone")
	_attack_and_block([golem.id], {wall.id: golem.id})
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "sacrificed at end of combat")
	var tokens := _tokens(1, "Wall")
	assert_eq(tokens.size(), 1)
	var token: CardInstance = tokens[0]
	assert_eq([token.cur_power, token.cur_toughness], [0, 2])
	assert_true(token.is_type(Mtg.CardType.ARTIFACT))
	assert_true(token.has_keyword(Mtg.Keyword.DEFENDER))
	assert_eq(token.cur_colors, 0, "colorless")


func test_basalt_golem_a_blocker_that_died_is_no_wall() -> void:
	var golem := put_battlefield(0, "Basalt Golem")
	var elves := put_battlefield(1, "Llanowar Elves")
	_attack_and_block([golem.id], {elves.id: golem.id})
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(_tokens(1, "Wall").size(), 0, "nothing was sacrificed")


func test_lead_golem_skips_its_next_untap() -> void:
	var golem := put_battlefield(0, "Lead Golem")
	_attack([golem.id])
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(golem.tapped, "it didn't untap")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(golem.tapped, "only the next untap step")


# ======================================================== bands and LKI

func test_rock_basilisk_in_a_band_gazes_at_the_band_s_blocker() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var basilisk := put_battlefield(0, "Rock Basilisk")
	var golem := put_battlefield(1, "Obsianus Golem")
	_attack_and_block([hero.id, basilisk.id], {golem.id: hero.id}, [[hero.id, basilisk.id]])
	assert_eq(g.stack.size(), 1, "blocking the Hero blocks the Basilisk too (CR 702.22h)")
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD)


func test_dread_specter_killed_in_response_still_dooms_its_blocker() -> void:
	var specter := put_battlefield(0, "Dread Specter")
	var wall := put_battlefield(1, "Wall of Stone")
	_attack_and_block([specter.id], {wall.id: specter.id})
	assert_eq(g.stack.size(), 1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(specter)]))
	resolve_stack()
	assert_eq(specter.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "the trigger is independent of its source (CR 113.7a)")


func test_catacomb_dragon_reads_the_blocker_s_power_as_it_resolves() -> void:
	var dragon := put_battlefield(0, "Catacomb Dragon")
	var angel := put_battlefield(1, "Serra Angel")
	_attack_and_block([dragon.id], {angel.id: dragon.id})
	assert_ok(g.pass_priority(0))
	var growth := give_hand(1, "Giant Growth")
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, growth, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq([angel.cur_power, angel.cur_toughness], [4, 7], "7 power halved, rounded down: -3/-0")


func test_mindbender_spores_on_a_creature_that_left_does_nothing() -> void:
	var spores := put_battlefield(1, "Mindbender Spores")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack_and_block([bear.id], {spores.id: bear.id})
	g.return_to_hand(bear)
	resolve_stack()
	g._put_on_battlefield(bear, 0)
	assert_eq(int(bear.counters.get("fungus", 0)), 0, "a new object (CR 400.7)")
