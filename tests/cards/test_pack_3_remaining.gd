extends GameTest

func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()
	advance_to_step(Mtg.Step.MAIN1)
func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)

func boon(body: CardInstance) -> void:
	var card := give_hand(0, "Sacred Boon")
	add_mana(0, Mtg.ManaColor.W, 2)
	g.priority_player = 0
	assert_ok(g.cast_spell(0, card, [TargetRef.card(body)]))
	resolve_stack()

func test_balduvian_shaman_only_rewrites_eligible_circles_and_grants_real_upkeep() -> void:
	var shaman := put_battlefield(0, "Balduvian Shaman")
	var circle := put_battlefield(0, "Circle of Protection: White")
	var other := put_battlefield(0, "Crusade")
	assert_refused(g.activate_ability(0, shaman, 0, [TargetRef.card(other)]))
	assert_ok(g.activate_ability(0, shaman, 0, [TargetRef.card(circle)]))
	resolve_stack()
	assert_ne(load("res://cards/sets/ice/_remaining.gd").circle_color(circle), Mtg.ManaColor.W)
	g.untap_permanent(shaman)
	assert_refused(g.activate_ability(0, shaman, 0, [TargetRef.card(circle)]), "Illegal target")
	add_mana(0, Mtg.ManaColor.C)
	g.dispatch_event(Mtg.EventType.UPKEEP_START, {"player": 0})
	resolve_stack()
	assert_eq(int(circle.counters.get("age", 0)), 1)
	assert_eq(g.players[0].mana_pool.total(), 0)

func test_boon_counts_only_damage_actually_prevented_by_its_own_shield() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	boon(bear)
	g.deal_damage(giant, TargetRef.card(bear), 2)
	assert_eq(bear.damage, 0)
	g.dispatch_event(Mtg.EventType.END_STEP_START, {"player": 0})
	resolve_stack()
	assert_eq(int(bear.counters.get("+0/+1", 0)), 2)
	assert_eq(bear.cur_toughness, 4)

func test_boon_awards_nothing_when_protection_prevents_the_damage() -> void:
	var knight := put_battlefield(0, "White Knight")
	var black := put_battlefield(1, "Black Knight")
	boon(knight)
	g.deal_damage(black, TargetRef.card(knight), 2)
	g.dispatch_event(Mtg.EventType.END_STEP_START, {"player": 0})
	resolve_stack()
	assert_eq(int(knight.counters.get("+0/+1", 0)), 0)

func test_two_boons_do_not_each_claim_the_same_prevented_damage() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	boon(bear)
	boon(bear)
	g.deal_damage(giant, TargetRef.card(bear), 4)
	g.dispatch_event(Mtg.EventType.END_STEP_START, {"player": 0})
	resolve_stack()
	assert_eq(bear.damage, 0)
	assert_eq(int(bear.counters.get("+0/+1", 0)), 4)

func test_boon_does_not_reward_a_new_battlefield_incarnation() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	boon(bear)
	g.deal_damage(giant, TargetRef.card(bear), 2)
	g.return_to_hand(bear)
	g.put_from_hand_into_play(bear, 0)
	g.dispatch_event(Mtg.EventType.END_STEP_START, {"player": 0})
	resolve_stack()
	assert_eq(int(bear.counters.get("+0/+1", 0)), 0)

func test_control_and_prevention_ledgers_rewind_with_ai_search() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var before := bear.controller_id
	var mark := g.make_mark()
	g.gain_control_until_eot(bear, 0)
	g.book_tracked_prevention(bear, 3, "Probe")
	g.unmake_to(mark)
	assert_eq(bear.controller_id, before)
	assert_true(bear.tracked_prevention.is_empty())
	assert_true(g._control_layers.is_empty())

func test_soul_burn_uses_mixed_black_red_x_and_only_black_x_gains_life() -> void:
	var spell := give_hand(0, "Soul Burn")
	add_mana(0, Mtg.ManaColor.B, 3)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)], 4))
	assert_eq(g.players[0].mana_pool.total(), 0)
	resolve_stack()
	assert_eq(g.players[1].life, 16)
	assert_eq(g.players[0].life, 22)

func test_soul_burn_red_x_does_not_count_the_black_in_base_cost() -> void:
	var spell := give_hand(0, "Soul Burn")
	add_mana(0, Mtg.ManaColor.B, 1)
	add_mana(0, Mtg.ManaColor.R, 3)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 17)

func test_soul_burn_rejects_green_x_even_with_north_star() -> void:
	var spell := give_hand(0, "Soul Burn")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.G, 5)
	g.players[0].any_color_spells = 1
	assert_refused(g.cast_spell(0, spell, [TargetRef.player(1)], 3))
	assert_eq(g.players[0].mana_pool.total(), 6)
	assert_eq(g.players[0].any_color_spells, 1)

func test_soul_burn_life_is_capped_by_toughness_and_actual_damage() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Soul Burn")
	add_mana(0, Mtg.ManaColor.B, 7)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)], 4))
	resolve_stack()
	assert_eq(g.players[0].life, 22)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_soul_burn_planner_finds_mixed_mana_and_preferred_black() -> void:
	for _n in 3: put_battlefield(0, "Swamp")
	for _n in 2: put_battlefield(0, "Mountain")
	put_battlefield(0, "Sol Ring")
	var spell := give_hand(0, "Soul Burn")
	var payment := g.spell_payment(0, spell.data, 4, 1, spell)
	assert_true(ManaPlanner.plan_and_pay(g, 0, payment.cost, payment.extra, payment.usage))
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)], 4))
	resolve_stack()
	assert_eq(g.players[0].life, 22)

func test_soul_burn_discount_reduces_generic_x_but_not_its_damage() -> void:
	for _n in 4: put_battlefield(0, "Stone Calendar")
	for _n in 2: put_battlefield(0, "Swamp")
	var spell := give_hand(0, "Soul Burn")
	var payment := g.spell_payment(0, spell.data, 3, 1, spell)
	assert_eq(payment.extra, -4)
	assert_true(ManaPlanner.plan_and_pay(g, 0, payment.cost, payment.extra, payment.usage))
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].life, 21, "only one black mana was actually spent on X")

func test_soul_burn_discount_cannot_erase_printed_pip_through_north_star() -> void:
	var cost := CardRegistry.get_card("Soul Burn").cost_for(3)
	var pool := ManaPool.new()
	assert_false(pool.can_pay(cost, -5, [], [], true))
	pool.add(Mtg.ManaColor.G, 1)
	assert_true(pool.can_pay(cost, -5, [], [], true))
	pool.pay(cost, -5, [], [], true)
	assert_eq(pool.total(), 0)

func test_spoils_requires_exact_graveyard_x_before_paying() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var enemy := put_battlefield(1, "Grizzly Bears")
	g.destroy(enemy, false)
	var spell := give_hand(0, "Spoils of War")
	var target := TargetRef.card(bear)
	target.amount = 1
	add_mana(0, Mtg.ManaColor.B, 4)
	assert_refused(g.cast_spell(0, spell, [target], 2))
	assert_eq(g.players[0].mana_pool.total(), 4)
	assert_ok(g.cast_spell(0, spell, [target], 1))
	g.reanimate(enemy, 1)
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1, "X stays fixed after casting")

func test_winter_chill_checks_snow_land_limit_and_preserves_regeneration() -> void:
	var enemy := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Snow-Covered Island")
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	g.combat.attackers[enemy.id] = true
	var spell := give_hand(0, "Winter's Chill")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(enemy)], 2))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(enemy)], 1))
	resolve_stack()
	assert_eq(enemy.zone, Mtg.Zone.BATTLEFIELD)
	enemy.regeneration_shields = 1
	g.dispatch_event(Mtg.EventType.END_OF_COMBAT, {"player": 1})
	resolve_stack()
	assert_eq(enemy.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(enemy.regeneration_shields, 0)

func test_dance_of_the_dead_enters_attached_to_graveyard_card_then_triggers() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear, false)
	var aura := give_hand(0, "Dance of the Dead")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	g._resolve_top()
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "The ETB trigger can be answered")
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 0)
	assert_true(bear.tapped)
	assert_true(bear.cur_skips_untap)
	assert_eq(bear.cur_power, 3)
	g.return_to_hand(aura)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "Sacrifice waits for a trigger")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

## Through Eureka (CR 303.4f): Dance of the Dead enters attached to a
## creature card in a graveyard and its own enters trigger raises it — the
## same as the cast path above (bug pass 2026-10-03).
func test_eureka_puts_dance_of_the_dead_onto_a_graveyard_creature() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear, false)
	var aura := give_hand(0, "Dance of the Dead")
	var eureka := give_hand(0, "Eureka")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, eureka, []))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "its enters trigger raised the Bears")
	assert_eq(bear.controller_id, 0)
	assert_true(bear.tapped)
	assert_eq(bear.cur_power, 3)

func test_dance_cannot_raise_after_aura_leaves_in_response() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear, false)
	var aura := give_hand(0, "Dance of the Dead")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	g._resolve_top()
	g.return_to_hand(aura)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_true(bear.attachments.is_empty())

func test_dance_upkeep_can_pay_to_untap_without_a_new_control_change() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear, false)
	var aura := give_hand(0, "Dance of the Dead")
	add_mana(0, Mtg.ManaColor.B, 4)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	g.dispatch_event(Mtg.EventType.UPKEEP_START, {"player": 0})
	resolve_stack()
	assert_false(bear.tapped)
	assert_eq(bear.controller_id, 0)

func test_dreams_exiles_on_bounce_not_only_on_death() -> void:
	var bear := put_battlefield(0, "Black Knight")
	g.destroy(bear, false)
	var dreams := put_battlefield(0, "Dreams of the Dead")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.activate_ability(0, dreams, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_exile_on_leaving)
	g.return_to_hand(dreams)
	g.return_to_hand(bear)
	assert_eq(bear.zone, Mtg.Zone.EXILE)

func test_dreams_grants_cumulative_upkeep_and_exiles_unpaid_creature() -> void:
	var bear := put_battlefield(0, "Black Knight")
	g.destroy(bear, false)
	var dreams := put_battlefield(0, "Dreams of the Dead")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.activate_ability(0, dreams, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.dispatch_event(Mtg.EventType.UPKEEP_START, {"player": 0})
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
