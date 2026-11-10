extends GameTest
const T := preload("res://engine/ai/homelands_tactics.gd")

func before_each() -> void:
	CardPacks.set_enabled("pack-4", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-4", false)

func pilot() -> AiPlayer:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.profile.develops_late = false
	g.set_agent(0, ai)
	return ai

func test_ai_locks_a_tapped_enemy_and_null_keeps_old_policy() -> void:
	var oyster := put_battlefield(0, "Giant Oyster")
	var enemy := put_battlefield(1, "Serra Angel")
	g.tap_permanent(enemy)
	var ai := pilot()
	ai.profile.forecasts_tactics = false
	assert_eq(ai._try_activate(g), "")
	ai.profile.forecasts_tactics = true
	assert_eq(ai._try_activate(g), "activated Giant Oyster")
	assert_eq(g.stack.back().targets[0].instance_id, enemy.id)
	resolve_stack()
	assert_true(enemy.cur_skips_untap)
	assert_true(oyster.tapped)

func test_ai_recharges_clockwork_only_up_to_missing_counters() -> void:
	var clockwork := put_battlefield(0, "Clockwork Steed")
	g.remove_counters(clockwork, "+1/+0", 3)
	# A 1/3 does not attack into a 3/3, so the {T} costs no attack (gap
	# review 2026-11-10: it is wound up only when it stays home).
	put_battlefield(1, "Hill Giant")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.C, 5)
	var ai := pilot()
	assert_true(ai._ability_available(g, clockwork, 0, true))
	assert_eq(ai._try_activate(g, AiPlayer.Moment.UPKEEP), "activated Clockwork Steed")
	if g.stack.is_empty(): return
	assert_eq(g.stack.back().x_value, 3)
	resolve_stack()
	assert_eq(int(clockwork.counters.get("+1/+0", 0)), 4)

func test_ai_cheats_a_minotaur_through_a_creature_ban() -> void:
	put_battlefield(0, "Didgeridoo")
	put_battlefield(1, "Aether Storm")
	var minotaur := give_hand(0, "Anaba Spirit Crafter")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_eq(pilot()._try_activate(g), "activated Didgeridoo")
	resolve_stack()
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD)

func test_ai_spends_arrow_to_kill_enemy_not_own_creature() -> void:
	var arrows := put_battlefield(0, "Serrated Arrows")
	var enemy := put_battlefield(1, "Llanowar Elves")
	put_battlefield(0, "Llanowar Elves")
	assert_eq(pilot()._try_activate(g), "activated Serrated Arrows")
	assert_eq(g.stack.back().targets[0].instance_id, enemy.id)
	resolve_stack()
	assert_eq(enemy.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(int(arrows.counters.get("arrowhead", 0)), 2)

func test_ai_redirects_minimum_damage_and_forecast_restores_everything() -> void:
	var abbot := put_battlefield(0, "Hazduhr the Abbot")
	var knight := put_battlefield(0, "White Knight")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(knight)]))
	assert_ok(g.pass_priority(1))
	var ai := pilot()
	var rng := g.rng.state
	var choice: Dictionary = T.option(g, ai, abbot, 0, "RESPONSE")
	assert_false(choice.is_empty())
	if choice.is_empty(): return
	assert_eq(choice.x, 2)
	assert_eq(choice.targets[0].instance_id, knight.id)
	assert_eq(g.rng.state, rng)
	assert_true(knight.creature_damage_redirects.is_empty())
	assert_eq(knight.damage, 0)
	assert_null(g.undo_log)
	assert_true(ai._ability_available(g, abbot, 0, true))
	assert_eq(ai._try_activate(g, AiPlayer.Moment.RESPONSE), "activated Hazduhr the Abbot")
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(knight.damage, 1)
	assert_eq(abbot.damage, 2)

func test_ai_budget_keeps_an_affordable_attacker_instead_of_refusing_army() -> void:
	put_battlefield(1, "Koskun Falls")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	add_mana(0, Mtg.ManaColor.C, 2)
	var ai := pilot()
	assert_eq(T.affordable_attackers(g, ai, [bear.id, giant.id]), [giant.id])
	assert_eq(g.players[0].mana_pool.total(), 2, "budget check does not pay")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_eq(ai._declare_attacks(g), "declared 1 attacker(s)")
	assert_eq(g.combat.attackers.keys(), [giant.id])

func test_ai_sacrifices_two_distinct_enemy_targets_with_retribution() -> void:
	var a := put_battlefield(1, "Serra Angel")
	var b := put_battlefield(1, "Hill Giant")
	put_battlefield(0, "Shivan Dragon")
	var spell := give_hand(0, "Retribution")
	var choice: Dictionary = T.spell_choice(g, pilot(), spell)
	assert_eq(choice.targets.size(), 2)
	assert_ne(choice.targets[0].instance_id, choice.targets[1].instance_id)
	assert_true([a.id, b.id].has(choice.targets[0].instance_id))
	assert_true([a.id, b.id].has(choice.targets[1].instance_id))

func test_custom_policy_ignores_hidden_cards_and_future_rng() -> void:
	var oyster := put_battlefield(0, "Giant Oyster")
	var enemy := put_battlefield(1, "Hill Giant")
	g.tap_permanent(enemy)
	var ai := pilot()
	var first: Dictionary = T.option(g, ai, oyster, 0, "MAIN")
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Wrath of God")
	g.players[0].library.reverse()
	g.players[1].library.reverse()
	var rng := g.rng.state
	var second: Dictionary = T.option(g, ai, oyster, 0, "MAIN")
	assert_eq(first.value, second.value)
	assert_eq(first.targets[0].instance_id, second.targets[0].instance_id)
	assert_eq(g.rng.state, rng)

func test_harmful_homelands_auras_point_at_the_opponent() -> void:
	put_battlefield(0, "Grizzly Bears")
	var enemy := put_battlefield(1, "Hill Giant")
	var roots := give_hand(0, "Roots")
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_eq(pilot()._try_cast_best(g), "cast Roots")
	assert_eq(g.stack.back().targets[0].instance_id, enemy.id)
	resolve_stack()
	assert_eq(roots.attached_to, enemy.id)

func test_ai_buys_walls_only_evasion_before_blocks_and_not_after() -> void:
	var tools := put_battlefield(0, "Joven's Tools")
	var attacker := put_battlefield(0, "Shivan Dragon")
	put_battlefield(1, "Serra Angel")
	var ai := pilot()
	var choice: Dictionary = T.option(g, ai, tools, 0, "MAIN")
	assert_false(choice.is_empty())
	assert_eq(choice.targets[0].instance_id, attacker.id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(T.option(g, ai, tools, 0, "COMBAT").is_empty())

func test_ai_can_escape_foreign_aether_storm_with_own_creature_in_hand() -> void:
	var storm := put_battlefield(1, "Aether Storm")
	give_hand(0, "Shivan Dragon")
	add_mana(0, Mtg.ManaColor.R, 6)
	assert_eq(pilot()._try_activate(g), "activated Aether Storm")
	resolve_stack()
	assert_eq(storm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 16)

func test_ai_redirection_also_answers_a_classic_damage_packet() -> void:
	var abbot := put_battlefield(0, "Hazduhr the Abbot")
	var knight := put_battlefield(0, "White Knight")
	var red := put_battlefield(1, "Anaba Shaman")
	var ai := pilot()
	g.set_agent(1, AiPlayer.new(1, AiProfile.wizard()))
	g.rules.damage_prevention_window = true
	add_mana(0, Mtg.ManaColor.C, 2)
	g.deal_damage(red, TargetRef.card(knight), 3)
	g._open_priority()
	assert_true(g.awaiting_damage_prevention)
	assert_eq(ai._prevention_action(g), "activated Hazduhr the Abbot")
	assert_eq(g.stack.back().x_value, 2)
	resolve_stack()
	var guard := 0
	while g.awaiting_damage_prevention and guard < 12:
		guard += 1
		assert_ok(g.pass_priority(g.priority_player))
	assert_lt(guard, 12)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(abbot.damage, 2)

func test_ai_badger_does_not_exchange_a_lethal_attack_for_two_life() -> void:
	var badger := put_battlefield(0, "Rysorian Badger")
	g.players[0].life = 3
	g.players[1].life = 2
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [badger.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_false(pilot().answer_yes_no(g, 0, "Exile the targeted creature cards and gain life instead of assigning combat damage?", true))
