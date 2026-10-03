extends GameTest

func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)

func mana(pid := 0) -> void:
	for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G]: add_mana(pid, color, 10)

func test_fire_covenant_life_is_paid_before_resolution_without_x_mana() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Fire Covenant")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	var ta := TargetRef.card(a)
	var tb := TargetRef.card(b)
	ta.amount = 2
	tb.amount = 2
	assert_ok(g.cast_spell(0, spell, [ta, tb], 4))
	assert_eq(g.players[0].life, 16)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD)
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)

func test_fire_covenant_refuses_unpayable_life_without_consuming_mana() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Fire Covenant")
	mana()
	var pool := g.players[0].mana_pool.total()
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(a)], 21), "life")
	assert_eq(g.players[0].mana_pool.total(), pool)
	assert_eq(spell.zone, Mtg.Zone.HAND)

func test_fumarole_pays_life_even_if_countered() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Forest")
	var spell := give_hand(0, "Fumarole")
	mana()
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(a), TargetRef.card(b)]))
	assert_eq(g.players[0].life, 17)
	g.counter_spell(spell)
	assert_eq(g.players[0].life, 17)
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD)

func test_meteor_zero_x_still_deals_one_for_red() -> void:
	var spell := give_hand(0, "Meteor Shower")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)], 0))
	resolve_stack()
	assert_eq(g.players[1].life, 19)

func test_meteor_pays_x_twice_and_deals_x_plus_one() -> void:
	var spell := give_hand(0, "Meteor Shower")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)], 2))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].mana_pool.total(), 0)

func test_sextant_mana_is_immediate_and_draw_is_delayed_after_sacrifice() -> void:
	var sextant := put_battlefield(0, "Barbed Sextant")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.tap_for_mana(0, sextant, 1))
	assert_eq(sextant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].mana_pool.total(), 1)
	assert_true(g.stack.is_empty())
	assert_eq(g.delayed_triggers.size(), 1)
	assert_true(g.players[0].hand.is_empty())

func test_lumberjack_supports_mixed_mana_and_sacrifices_forest_as_cost() -> void:
	var jack := put_battlefield(0, "Orcish Lumberjack")
	var forest := put_battlefield(0, "Forest")
	assert_ok(g.tap_for_mana(0, jack, 1))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].mana_pool.total(), 3)
	assert_true(g.players[0].mana_pool.can_pay(ManaCost.parse("{R}{G}{G}")))

func test_ski_once_is_paid_on_activation_even_before_resolution() -> void:
	var ski := put_battlefield(0, "Goblin Ski Patrol")
	put_battlefield(0, "Snow-Covered Mountain")
	mana()
	assert_ok(g.activate_ability(0, ski, 0))
	assert_refused(g.activate_ability(0, ski, 0), "once")
	resolve_stack()
	assert_eq(ski.cur_power, 3)
	assert_true(ski.has_keyword(Mtg.Keyword.FLYING))
	g.continuous.expire_until_eot()
	g.recalculate()
	assert_eq(ski.cur_power, 3)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(ski.zone, Mtg.Zone.GRAVEYARD)

func test_guard_link_cannot_sacrifice_a_guard_you_no_longer_control() -> void:
	var guard := put_battlefield(0, "Kjeldoran Elite Guard")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_ok(g.activate_ability(0, guard, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	g.change_control(guard, 1)
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(guard.zone, Mtg.Zone.BATTLEFIELD)

func test_touch_vitae_untap_ability_is_single_use_and_expires() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var spell := give_hand(0, "Touch of Vitae")
	mana()
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.HASTE))
	g.tap_permanent(bear)
	assert_ok(g.activate_ability(0, bear, 0))
	resolve_stack()
	assert_false(bear.tapped)
	assert_refused(g.activate_ability(0, bear, 0))
	g.continuous.expire_until_eot()
	g.recalculate()
	assert_eq(bear.cur_activated_abilities.size(), 0)

func test_wiitigo_remembers_block_across_cleanup_not_just_this_turn() -> void:
	var w := put_battlefield(0, "Wiitigo")
	var a := put_battlefield(1, "Grizzly Bears")
	g.dispatch_event(Mtg.EventType.BLOCKED, {"attacker": a, "blocker": w})
	w.blocked_this_turn = false
	g.dispatch_event(Mtg.EventType.UPKEEP_START, {"player": 0})
	resolve_stack()
	assert_eq(int(w.counters.get("+1/+1", 0)), 7)
	g.dispatch_event(Mtg.EventType.UPKEEP_START, {"player": 0})
	resolve_stack()
	assert_eq(int(w.counters.get("+1/+1", 0)), 6)

func test_pox_rounds_up_separately_and_keeps_choosing_players_own_permanents() -> void:
	for who in 2:
		g.players[who].life = 10
		for _i in 4:
			put_battlefield(who, "Grizzly Bears")
			put_battlefield(who, "Forest")
			give_hand(who, "Island")
	var spell := give_hand(0, "Pox")
	mana()
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()
	for who in 2:
		assert_eq(g.players[who].life, 6)
		assert_eq(g.players[who].hand.size(), 2)
		assert_eq(g.players[who].battlefield.size(), 4)

# CR 601.2c, per instance of the word "target" (2026-10-03): the opponent may
# take part of the divided 5 AND be the "target opponent" who gains 5 life.
# The whole-spell duplicate check refused it ("can't choose the same target
# twice").
func test_fiery_justice_may_hit_the_opponent_who_gains_the_life() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Fiery Justice")
	mana()
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear, 3), TargetRef.player(1, 2), TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 23, "20 - 2 + 5")
