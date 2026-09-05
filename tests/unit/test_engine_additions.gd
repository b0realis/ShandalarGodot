extends GameTest
## Engine tests for the mechanics added while graduating the card pool
## (waves 19+). Each section pins one engine class or one MtgGame/
## ContinuousEffects capability directly, independent of the cards that
## motivated it — the card tests live in tests/cards/test_pool_wave*.gd.


# --------------------------------------------------------- MassPumpEffect --

func test_mass_pump_hits_every_creature_by_default() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var land := put_battlefield(0, "Forest")
	var effect := MassPumpEffect.new(1, 1)
	effect.resolve(g, mine, 0, null)
	assert_eq(mine.cur_power, 3)
	assert_eq(theirs.cur_power, 3)
	assert_eq(land.cur_power, 0, "non-creatures are skipped")


func test_mass_pump_yours_only_and_filter_compose() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var flyer := put_battlefield(0, "Serra Angel")
	var theirs := put_battlefield(1, "Serra Angel")
	var effect := MassPumpEffect.new(0, 2, "your fliers").yours_only() \
		.with_filter(_has_flying)
	effect.resolve(g, bear, 0, null)
	assert_eq(bear.cur_toughness, 2, "no flying, no boost")
	assert_eq(flyer.cur_toughness, 6)
	assert_eq(theirs.cur_toughness, 4, "not yours")


static func _has_flying(inst: CardInstance) -> bool:
	return inst.has_keyword(Mtg.Keyword.FLYING)


func test_mass_pump_expires_at_cleanup() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	MassPumpEffect.new(2, 2).resolve(g, bear, 0, null)
	assert_eq(bear.cur_power, 4)
	advance_to_next_turn()
	assert_eq(bear.cur_power, 2)


# ---------------------------------------------- P/T switch (CR 613.4e) --

func test_pt_switch_applies_after_pumps() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_pump(bear.id, 1, 0)   # 3/2
	g.continuous.add_until_eot_pt_switch(bear.id)
	g.recalculate()
	assert_eq(bear.cur_power, 2, "switch reads the already-pumped values")
	assert_eq(bear.cur_toughness, 3)


func test_two_switches_cancel_out() -> void:
	var minotaur := put_battlefield(0, "Hurloon Minotaur")   # 2/3
	g.continuous.add_until_eot_pt_switch(minotaur.id)
	g.continuous.add_until_eot_pt_switch(minotaur.id)
	g.recalculate()
	assert_eq(minotaur.cur_power, 2)
	assert_eq(minotaur.cur_toughness, 3)


func test_pt_switch_expires_at_cleanup() -> void:
	var minotaur := put_battlefield(0, "Hurloon Minotaur")
	g.continuous.add_until_eot_pt_switch(minotaur.id)
	g.recalculate()
	assert_eq(minotaur.cur_power, 3)
	advance_to_next_turn()
	assert_eq(minotaur.cur_power, 2)


# ------------------------------------------------------ "target opponent" --

func test_opponent_spec_rejects_the_source_controller() -> void:
	var spec := TargetSpec.opponent()
	var source := put_battlefield(0, "Grizzly Bears")
	assert_false(spec.is_legal(g, TargetRef.player(0), source), "you are not your own opponent")
	assert_true(spec.is_legal(g, TargetRef.player(1), source))


# ------------------------------------------- the world rule (CR 704.5k) --

func test_world_rule_keeps_only_the_newest() -> void:
	var first := put_battlefield(0, "Concordant Crossroads")
	var second := put_battlefield(0, "Gravity Sphere")
	var third := put_battlefield(1, "Living Plane")
	g.check_state_based_actions()
	assert_eq(first.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "the rule sweeps every older world card")
	assert_eq(third.zone, Mtg.Zone.BATTLEFIELD)


func test_world_rule_ignores_non_world_permanents() -> void:
	var moat := put_battlefield(0, "Moat")            # plain enchantment
	var sphere := put_battlefield(0, "Gravity Sphere")
	g.check_state_based_actions()
	assert_eq(moat.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(sphere.zone, Mtg.Zone.BATTLEFIELD)


func test_world_permanents_go_to_their_owners_graveyard() -> void:
	var mine := put_battlefield(0, "Concordant Crossroads")
	put_battlefield(1, "Gravity Sphere")
	g.check_state_based_actions()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard.has(mine), "owner's graveyard, not the winner's")


# ------------------------------------------------- LoseAbilityEffect --

func test_lose_ability_strips_a_granted_keyword_too() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_pump(bear.id, 0, 0, [Mtg.Keyword.FLYING])
	g.recalculate()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	LoseAbilityEffect.new([Mtg.Keyword.FLYING], "flying").resolve(
		g, bear, 0, TargetRef.card(bear))
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING), "the loss beats the grant")


func test_lose_ability_expires_at_cleanup() -> void:
	var wraith := put_battlefield(0, "Bog Wraith")
	LoseAbilityEffect.new([], "landwalk").and_landwalk().resolve(
		g, wraith, 0, TargetRef.card(wraith))
	assert_eq(wraith.cur_landwalk.size(), 0)
	advance_to_next_turn()
	assert_true(wraith.cur_landwalk.has("swamp"))


# ------------------------------------- mana abilities with other costs --

func test_non_tapping_mana_ability_never_taps_and_repeats() -> void:
	var altar := put_battlefield(0, "Ashnod's Altar")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, altar))
	assert_false(altar.tapped)
	assert_ok(g.tap_for_mana(0, altar))   # usable again — no {T} in the cost
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 4)
	assert_refused(g.tap_for_mana(0, altar), "no creature to sacrifice")


func test_non_tapping_mana_ability_ignores_summoning_sickness() -> void:
	# CR 302.6 gates {T} costs only. The Altar isn't a creature, but the
	# same code path must not consult sickness for a tapless ability.
	var altar := put_battlefield(0, "Ashnod's Altar", true)
	put_battlefield(0, "Grizzly Bears", true)
	assert_ok(g.tap_for_mana(0, altar))


func test_mana_ability_sacrifice_never_eats_its_own_source() -> void:
	# Ashnod's Altar is not a creature, so this pins the general rule with
	# the sacrifice filter that WOULD match the source if it were allowed.
	var altar := put_battlefield(0, "Ashnod's Altar")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, altar), "no creature to sacrifice")
	assert_eq(altar.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------- base P/T sets (CR 613 layer 7b) --

func test_base_pt_set_is_beaten_by_a_later_pump() -> void:
	var angel := put_battlefield(0, "Serra Angel")   # 4/4
	g.continuous.add_until_eot_base_pt(angel.id, 0, -1)
	g.continuous.add_until_eot_pump(angel.id, 3, 3)
	g.recalculate()
	assert_eq(angel.cur_power, 3, "base 0 then +3/+3")
	assert_eq(angel.cur_toughness, 7, "toughness half untouched by the set")


func test_base_pt_set_survives_counters() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.add_counters(bear, "+1/+1", 1)
	g.continuous.add_until_eot_base_pt(bear.id, 0, 2)
	g.recalculate()
	assert_eq(bear.cur_power, 1, "0/2 base plus the counter")
	assert_eq(bear.cur_toughness, 3)


func test_base_pt_set_expires_at_cleanup() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_base_pt(bear.id, 0, 2)
	g.recalculate()
	assert_eq(bear.cur_power, 0)
	advance_to_next_turn()
	assert_eq(bear.cur_power, 2)


# ------------------------------ combat status lasts the whole phase --

func test_attackers_are_still_attacking_in_the_end_of_combat_step() -> void:
	# CR 506.4/511.3: "attacking" ends with the combat PHASE. Desert's
	# end-of-combat ping depends on this.
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_true(g.combat.attackers.has(bear.id))
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(g.combat.attackers.has(bear.id), "cleared when the phase ends")


# ------------------------------- "when you control no <land>, sacrifice" --

func test_no_island_clause_fires_the_moment_the_last_island_goes() -> void:
	var island := put_battlefield(0, "Island")
	var dandan := put_battlefield(0, "Dandân")
	g.check_state_based_actions()
	assert_eq(dandan.zone, Mtg.Zone.BATTLEFIELD)
	g.destroy(island, false)
	g.check_state_based_actions()
	assert_eq(dandan.zone, Mtg.Zone.GRAVEYARD)


func test_no_island_clause_reads_the_controller_not_the_owner() -> void:
	put_battlefield(1, "Island")
	var dandan := put_battlefield(0, "Dandân")
	g.check_state_based_actions()
	assert_eq(dandan.zone, Mtg.Zone.GRAVEYARD, "their Island doesn't help you")


# ------------------------------- ActivatedAbility timing restrictions --

func test_step_restricted_ability_refuses_outside_its_step() -> void:
	var desert := put_battlefield(0, "Desert")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, desert, 0, [TargetRef.card(bear)]),
		"end of combat step")


# ------------------------------------------------------------- TOKENS --

func test_a_token_enters_like_any_permanent() -> void:
	var data := CardData.new("Test Wasp", "", Mtg.CardType.CREATURE) \
		.pt(1, 1).with_keywords([Mtg.Keyword.FLYING]).oracle("")
	var made := g.create_token(0, data, 2)
	assert_eq(made.size(), 2)
	assert_true(made[0].is_token)
	assert_true(made[0].summoning_sick, "tokens are summoning sick like anything else")
	assert_eq(g.players[0].battlefield.size(), 2)


func test_a_token_leaves_no_card_behind() -> void:
	var data := CardData.new("Test Wasp", "", Mtg.CardType.CREATURE).pt(1, 1).oracle("")
	var token := g.create_token(0, data)[0]
	g.destroy(token, false)
	assert_eq(g.players[0].graveyard.size(), 0)
	assert_null(g.find_instance(token.id), "the token is gone from the game")


func test_creating_a_token_counts_as_a_creature_dying() -> void:
	var data := CardData.new("Test Wasp", "", Mtg.CardType.CREATURE).pt(1, 1).oracle("")
	var token := g.create_token(0, data)[0]
	g.destroy(token, false)
	assert_eq(g.creatures_died_this_turn, 1, "its dies-trigger still fired")


# ---------------------------------------------------------- COIN FLIPS --

func test_coin_flips_are_deterministic_for_a_seed() -> void:
	var first: Array[bool] = []
	for i in 8:
		first.append(g.flip_coin(0))
	var other := MtgGame.new()
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	other.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	other.start(0)
	for i in 8:
		assert_eq(other.flip_coin(0), first[i], "same seed, same flips")


# ------------------------------------------------------ CONTROL LEASHES --

func test_a_leash_hands_the_permanent_back_when_its_source_goes() -> void:
	var thief := put_battlefield(0, "Grizzly Bears")
	var prize := put_battlefield(1, "Sol Ring")
	g.gain_control_leashed(prize, thief, false)
	assert_eq(prize.controller_id, 0)
	g.destroy(thief, false)
	g.check_state_based_actions()
	assert_eq(prize.controller_id, 1)
	assert_eq(prize.controlled_via, -1, "the leash is cleared too")


func test_a_tapped_leash_needs_its_source_tapped() -> void:
	var thief := put_battlefield(0, "Grizzly Bears")
	var prize := put_battlefield(1, "Sol Ring")
	g.tap_permanent(thief)
	g.gain_control_leashed(prize, thief, true)
	g.check_state_based_actions()
	assert_eq(prize.controller_id, 0)
	g.untap_permanent(thief)
	g.check_state_based_actions()
	assert_eq(prize.controller_id, 1)


# ------------------------------------------- PreventCombatDamageEffect --

func test_prevent_combat_damage_stops_both_waves() -> void:
	var knight := put_battlefield(0, "White Knight")   # first strike
	var bear := put_battlefield(0, "Grizzly Bears")
	PreventCombatDamageEffect.new().resolve(g, bear, 0, null)
	run_combat([knight.id, bear.id])
	assert_eq(g.players[1].life, 20)


func test_prevent_combat_damage_leaves_burn_alone() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	var bear := put_battlefield(0, "Grizzly Bears")
	PreventCombatDamageEffect.new().resolve(g, bear, 0, null)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)


# ------------------------------- MtgGame.grant_keyword_permanently (wave 60) --

func test_granted_keyword_survives_recalculation() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.grant_keyword_permanently(bear, Mtg.Keyword.FLYING)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	g.recalculate()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "not an until-EOT float")
	advance_to_next_turn()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "and not a per-turn one")


func test_granted_keyword_is_dropped_when_the_card_leaves() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.grant_keyword_permanently(bear, Mtg.Keyword.FLYING)
	g.return_to_hand(bear)
	assert_eq(bear.added_keywords.size(), 0)
	g._put_on_battlefield(bear, 0)
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING),
		"what came back is a new object (CR 400.7)")


func test_granted_keyword_loses_to_a_permanent_removal() -> void:
	var wall := put_battlefield(0, "Wall of Stone")   # defender
	g.grant_keyword_permanently(wall, Mtg.Keyword.DEFENDER)
	g.remove_keyword_permanently(wall, Mtg.Keyword.DEFENDER)
	assert_false(wall.has_keyword(Mtg.Keyword.DEFENDER),
		"losses are applied after grants")


# ------------------------------------------- MtgGame.move_aura (wave 60) --

func test_move_aura_reattaches_without_a_zone_change() -> void:
	var first := put_battlefield(0, "Grizzly Bears")
	var second := put_battlefield(0, "Hill Giant")
	var aura := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(first)]))
	resolve_stack()
	assert_eq(first.cur_power, 3)
	g.move_aura(aura, second)
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "no zone change")
	assert_eq(aura.attached_to, second.id)
	assert_false(first.attachments.has(aura.id))
	assert_true(second.attachments.has(aura.id))
	assert_eq(first.cur_power, 2, "the old host lost the boost")
	assert_eq(second.cur_power, 4, "Hill Giant is a 3/3, now 4/5")
	assert_eq(second.cur_toughness, 5)


func test_move_aura_refuses_a_host_it_could_not_enchant() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(0, "Forest")
	var aura := give_hand(0, "Holy Strength")   # enchant creature
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	g.move_aura(aura, forest)
	assert_eq(aura.attached_to, bear.id, "a land is no legal host (CR 701.3d)")


# -------------------------------------------- exchange_control (CR 701.10) --

func test_exchange_control_swaps_two_permanents() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	assert_true(g.exchange_control(mine, theirs))
	assert_eq(mine.controller_id, 1)
	assert_eq(theirs.controller_id, 0)
	assert_true(g.players[1].battlefield.has(mine), "battlefield lists follow")
	assert_true(g.players[0].battlefield.has(theirs))


func test_exchange_control_is_all_or_nothing() -> void:
	# CR 701.10c: the exchange happens only if both are still there.
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	g.destroy(theirs)
	assert_false(g.exchange_control(mine, theirs))
	assert_eq(mine.controller_id, 0, "no half-trade")


func test_exchange_control_refuses_two_permanents_of_one_seat() -> void:
	var one := put_battlefield(0, "Grizzly Bears")
	var two := put_battlefield(0, "Hill Giant")
	assert_false(g.exchange_control(one, two))
	assert_eq(one.controller_id, 0)
	assert_eq(two.controller_id, 0)


func test_exchange_control_makes_both_summoning_sick() -> void:
	# CR 302.6 — neither has been under its new controller's command since
	# that player's turn began.
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	assert_true(g.exchange_control(mine, theirs))
	assert_true(mine.summoning_sick)
	assert_true(theirs.summoning_sick)


func test_exchange_control_ignores_a_null_or_self_pairing() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	assert_false(g.exchange_control(mine, mine))
	assert_false(g.exchange_control(mine, null))
	assert_false(g.exchange_control(null, null))


# ------------------------------------------------------- current_targets --

func test_current_targets_is_empty_outside_a_resolution() -> void:
	assert_eq(g.current_targets().size(), 0)


func test_current_targets_carries_every_slot_of_the_resolving_object() -> void:
	# Gauntlets of Chaos is the pool's user: slot 2's effect reads slot 1.
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var gauntlets := put_battlefield(0, "Gauntlets of Chaos")
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, gauntlets, 0,
		[TargetRef.card(mine), TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(mine.controller_id, 1, "slot 2 saw slot 1")
	assert_eq(theirs.controller_id, 0)
	assert_eq(g.current_targets().size(), 0, "cleared when the run ends")


# ----------------------------------------------- RandomEffects.sample --

func test_sample_takes_n_different_elements() -> void:
	var items := [1, 2, 3, 4, 5]
	var picked := RandomEffects.sample(g, items, 3)
	assert_eq(picked.size(), 3)
	for i in picked.size():
		for j in range(i + 1, picked.size()):
			assert_ne(picked[i], picked[j], "no element is drawn twice")
	assert_eq(items.size(), 5, "the source list is left alone")


func test_sample_is_capped_by_the_list_and_is_seeded() -> void:
	assert_eq(RandomEffects.sample(g, [1, 2], 9).size(), 2)
	assert_eq(RandomEffects.sample(g, [], 3).size(), 0)
	assert_eq(RandomEffects.sample(g, [1, 2, 3], 0).size(), 0)
	# Deterministic under a seed: the same rng state gives the same draw.
	g.rng.seed = 99
	var first := RandomEffects.sample(g, [1, 2, 3, 4, 5, 6], 4)
	g.rng.seed = 99
	assert_eq(RandomEffects.sample(g, [1, 2, 3, 4, 5, 6], 4), first)


# ------------------------------- DAMAGE REPLACEMENTS on a seat (CR 614) --

func test_a_damage_replacement_catches_the_packet_it_filters_for() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var other := put_battlefield(1, "Hill Giant")
	g.players[0].damage_replacements.append({
		"desc": "test shield",
		"filter": func(_g: MtgGame, packet: DamagePacket) -> bool:
			return packet.source_id() == bear.id,
		"apply": func(_g: MtgGame, packet: DamagePacket) -> int:
			packet.prevent(packet.remaining())
			return 0,
	})
	g.deal_damage(other, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 17, "the other source is untouched")
	g.deal_damage(bear, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 17, "and this one was replaced away")


func test_a_one_shot_damage_replacement_is_consumed() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.players[0].damage_replacements.append({
		"desc": "test shield",
		"filter": func(_g: MtgGame, _p: DamagePacket) -> bool: return true,
		"apply": func(_g: MtgGame, packet: DamagePacket) -> int:
			packet.prevent(packet.remaining())
			return 0,
	})
	g.deal_damage(bear, TargetRef.player(0), 2)
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[0].damage_replacements.size(), 0, "spent")
	g.deal_damage(bear, TargetRef.player(0), 2)
	assert_eq(g.players[0].life, 18, "the second blow lands")


func test_an_all_turn_damage_replacement_stays() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.players[0].damage_replacements.append({
		"desc": "test shield",
		"filter": func(_g: MtgGame, _p: DamagePacket) -> bool: return true,
		"apply": func(_g: MtgGame, packet: DamagePacket) -> int:
			packet.prevent(packet.remaining())
			return 0,
		"all_turn": true,
	})
	g.deal_damage(bear, TargetRef.player(0), 2)
	g.deal_damage(bear, TargetRef.player(0), 2)
	assert_eq(g.players[0].life, 20, "both blows replaced")
	assert_eq(g.players[0].damage_replacements.size(), 1)


func test_a_replacement_that_only_reduces_lets_the_rest_through() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.players[0].damage_replacements.append({
		"desc": "test shield",
		"filter": func(_g: MtgGame, _p: DamagePacket) -> bool: return true,
		"apply": func(_g: MtgGame, packet: DamagePacket) -> int:
			packet.prevent(1)
			return -1,      # carry on with what is left
	})
	g.deal_damage(bear, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 18, "one point prevented, two dealt")


func test_damage_replacements_expire_at_cleanup() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.players[0].damage_replacements.append({
		"desc": "test shield",
		"filter": func(_g: MtgGame, _p: DamagePacket) -> bool: return true,
		"apply": func(_g: MtgGame, packet: DamagePacket) -> int:
			packet.prevent(packet.remaining())
			return 0,
		"all_turn": true,
	})
	advance_to_next_turn()
	assert_eq(g.players[0].damage_replacements.size(), 0)
	g.deal_damage(bear, TargetRef.player(0), 2)
	assert_eq(g.players[0].life, 18)


func test_a_replacement_runs_before_a_prevention_shield() -> void:
	# CR 616: a replacement happens first, so the shield never sees the
	# damage the replacement took away.
	var bear := put_battlefield(1, "Grizzly Bears")
	g.players[0].damage_prevention = 5
	g.players[0].damage_replacements.append({
		"desc": "test shield",
		"filter": func(_g: MtgGame, _p: DamagePacket) -> bool: return true,
		"apply": func(_g: MtgGame, packet: DamagePacket) -> int:
			packet.prevent(packet.remaining())
			return 0,
	})
	g.deal_damage(bear, TargetRef.player(0), 3)
	assert_eq(g.players[0].damage_prevention, 5, "the pool was never touched")
