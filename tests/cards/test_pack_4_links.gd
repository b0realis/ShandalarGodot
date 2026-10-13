extends GameTest

func before_each() -> void:
	CardPacks.set_enabled("pack-4", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-4", false)

func enchant(name: String, host: CardInstance) -> CardInstance:
	var aura := give_hand(0, name)
	for color in Mtg.WUBRG: add_mana(0, color, 5)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(host)]))
	resolve_stack()
	return aura

func test_funeral_march_bounce_forces_the_departed_hosts_controller_to_sacrifice() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	enchant("Funeral March", a)
	g.return_to_hand(a)
	resolve_stack()
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)

func test_funeral_march_sees_host_leave_in_same_batch_after_aura() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	var aura := enchant("Funeral March", a)
	g.begin_simultaneous()
	g.destroy(aura)
	g.destroy(a)
	g.end_simultaneous()
	resolve_stack()
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)

func test_orcish_mine_last_counter_triggers_and_remembers_land_after_aura_removal() -> void:
	var land := put_battlefield(1, "Forest")
	var aura := enchant("Orcish Mine", land)
	assert_eq(int(aura.counters.get("ore", 0)), 3)
	g.remove_counters(aura, "ore", 3)
	assert_false(g.stack.is_empty())
	g.return_to_hand(aura)
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)

func test_orcish_mine_tap_removes_exactly_one_counter() -> void:
	var land := put_battlefield(1, "Forest")
	var aura := enchant("Orcish Mine", land)
	g.tap_permanent(land)
	resolve_stack()
	assert_eq(int(aura.counters.get("ore", 0)), 2)
	assert_eq(g.players[1].life, 20)

func test_mammoth_harness_removes_flying_and_gives_other_creature_first_strike() -> void:
	var bird := put_battlefield(0, "Mesa Falcon")
	var bear := put_battlefield(1, "Grizzly Bears")
	enchant("Mammoth Harness", bird)
	assert_false(bird.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bird.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: bird.id}))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_false(bird.has_keyword(Mtg.Keyword.FIRST_STRIKE))

func test_an_zerrin_ruins_selects_public_threat_type_and_stops_both_sides() -> void:
	var their_bear := put_battlefield(1, "Grizzly Bears")
	var our_bear := put_battlefield(0, "Grizzly Bears")
	var ruins := put_battlefield(0, "An-Zerrin Ruins")
	assert_eq(String(ruins.memory.get("hml_type", "")), "bear")
	assert_true(their_bear.cur_skips_untap)
	assert_true(our_bear.cur_skips_untap)
	g.destroy(ruins)
	assert_false(their_bear.cur_skips_untap)

func test_marjhan_untap_sacrifice_and_islandhome_remain_distinct() -> void:
	var island := put_battlefield(0, "Island")
	var serpent := put_battlefield(0, "Marjhan")
	assert_true(serpent.cur_skips_untap)
	assert_ne(CombatState.attack_illegality(g, serpent, 1), "")
	put_battlefield(1, "Island")
	assert_eq(CombatState.attack_illegality(g, serpent, 1), "")
	g.destroy(island)
	g.check_state_based_actions()
	# The engine's "when you control no Islands" clause since 2026-10-13: at
	# once by default, the 1997 way, under every preset ...
	assert_true(g.stack.is_empty(), "islandhome is checked at once by default")
	assert_eq(serpent.zone, Mtg.Zone.GRAVEYARD)


func test_marjhan_islandhome_waits_on_the_stack_with_the_rules_option() -> void:
	# ... and the respondable state trigger with
	# RulesOptions.sacrifice_clauses_wait on.
	g.rules.sacrifice_clauses_wait = true
	var island := put_battlefield(0, "Island")
	var serpent := put_battlefield(0, "Marjhan")
	g.destroy(island)
	g.check_state_based_actions()
	assert_false(g.stack.is_empty(), "islandhome uses a respondable state trigger")
	assert_eq(serpent.zone, Mtg.Zone.BATTLEFIELD)
	resolve_stack()
	assert_eq(serpent.zone, Mtg.Zone.GRAVEYARD)

func test_jovens_tools_keeps_walls_legal_and_expires() -> void:
	var tools := put_battlefield(0, "Joven's Tools")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Wood")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, tools, 0, [TargetRef.card(a)]))
	resolve_stack()
	assert_ne(CombatState.block_illegality(g, b, a, 1), "")
	assert_eq(CombatState.block_illegality(g, wall, a, 1), "")
	advance_to_next_turn()
	assert_eq(CombatState.block_illegality(g, b, a, 1), "")
