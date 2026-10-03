extends GameTest
## Pack 8 (the Mirage block), batch B9: the Weatherlight creatures of
## cards/sets/wth/_creatures.gd — each card's distinguishing Oracle clause
## and its edges (illegal targets, the source leaving, X = 0, both seats).

const CLAIMED := ["Benalish Missionary", "Heavy Ballista", "Master of Arms",
	"Soul Shepherd", "Southern Paladin", "Mischievous Poltergeist",
	"Dwarven Thaumaturgist", "Maraxus of Keld", "Orcish Settlers",
	"Fungus Elemental", "Llanowar Behemoth", "Llanowar Druid",
	"Serrated Biskelion", "Steel Golem", "Benalish Knight", "Avizoa"]

func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)

## P0 attacks with [param attacker]; P1 blocks with [param blocker] (or not).
## Leaves the game in the declare-blockers step with P0 holding priority.
func _combat(attacker: CardInstance, blocker: CardInstance = null) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {} if blocker == null else {blocker.id: attacker.id}))
	resolve_stack()

## Hand priority from P0 to P1 in the current step (stack empty).
func _to_p1() -> void:
	assert_eq(g.priority_player, 0)
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


func test_claimed_cards_are_no_longer_pending() -> void:
	for name in CLAIMED:
		var c := CardRegistry.get_card(name)
		assert_not_null(c, name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", name)


# --- Benalish Missionary ----------------------------------------------------

func test_missionary_prevents_combat_damage_dealt_by_a_blocked_creature() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var missionary := put_battlefield(1, "Benalish Missionary")
	_combat(giant, bear)
	_to_p1()
	add_mana(1, Mtg.ManaColor.W, 2)
	assert_ok(g.activate_ability(1, missionary, 0, [TargetRef.card(giant)]))
	assert_true(missionary.tapped)
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the blocked Giant dealt no combat damage")
	assert_eq(giant.damage, 2, "only damage dealt BY the target is prevented")

func test_missionary_refuses_an_unblocked_or_non_attacking_creature() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var idle := put_battlefield(0, "Grizzly Bears")
	var missionary := put_battlefield(1, "Benalish Missionary")
	_combat(giant)
	_to_p1()
	add_mana(1, Mtg.ManaColor.W, 2)
	assert_refused(g.activate_ability(1, missionary, 0, [TargetRef.card(giant)]))
	assert_refused(g.activate_ability(1, missionary, 0, [TargetRef.card(idle)]))
	assert_false(missionary.tapped)


# --- Heavy Ballista ---------------------------------------------------------

func test_ballista_shoots_an_attacker_for_two() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ballista := put_battlefield(1, "Heavy Ballista")
	_combat(bear)
	_to_p1()
	assert_ok(g.activate_ability(1, ballista, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_ballista_can_shoot_a_blocker_but_not_an_idle_creature() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var ballista := put_battlefield(0, "Heavy Ballista")
	var idle := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Wood")
	assert_refused(g.activate_ability(0, ballista, 0, [TargetRef.card(idle)]))
	_combat(giant, wall)
	assert_refused(g.activate_ability(0, ballista, 0, [TargetRef.card(idle)]))
	assert_ok(g.activate_ability(0, ballista, 0, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.damage, 2)


# --- Master of Arms ---------------------------------------------------------

func test_master_of_arms_taps_its_own_blocker_only() -> void:
	var master := put_battlefield(0, "Master of Arms")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Wood")
	var other := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [master.id, bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: master.id, other.id: bear.id}))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W, 4)
	assert_refused(g.activate_ability(0, master, 0, [TargetRef.card(other)]))
	assert_ok(g.activate_ability(0, master, 0, [TargetRef.card(wall)]))
	resolve_stack()
	assert_true(wall.tapped)
	assert_false(other.tapped)
	assert_true(master.has_keyword(Mtg.Keyword.FIRST_STRIKE))


# --- Soul Shepherd ----------------------------------------------------------

func test_soul_shepherd_exiles_a_creature_card_to_gain_one_life() -> void:
	var shepherd := put_battlefield(0, "Soul Shepherd")
	var land := put_battlefield(0, "Forest")
	g.sacrifice_permanent(land)
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, shepherd, 0), "creature card")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.sacrifice_permanent(bear)
	assert_ok(g.activate_ability(0, shepherd, 0))
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	assert_false(shepherd.tapped, "no {T} in the cost")


# --- Southern Paladin -------------------------------------------------------

func test_southern_paladin_destroys_only_red_permanents() -> void:
	var paladin := put_battlefield(0, "Southern Paladin")
	var raider := put_battlefield(1, "Mons's Goblin Raiders")
	var bear := put_battlefield(1, "Grizzly Bears")
	var mountain := put_battlefield(1, "Mountain")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_refused(g.activate_ability(0, paladin, 0, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(0, paladin, 0, [TargetRef.card(mountain)]), "")
	assert_ok(g.activate_ability(0, paladin, 0, [TargetRef.card(raider)]))
	assert_true(paladin.tapped)
	resolve_stack()
	assert_eq(raider.zone, Mtg.Zone.GRAVEYARD)


# --- Mischievous Poltergeist ------------------------------------------------

func test_poltergeist_pays_one_life_to_regenerate() -> void:
	var ghost := put_battlefield(0, "Mischievous Poltergeist")
	assert_true(ghost.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, ghost, 0))
	assert_eq(g.players[0].life, 19, "the life is a cost, paid on activation")
	resolve_stack()
	g.destroy(ghost)
	assert_eq(ghost.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(ghost.tapped)

func test_poltergeist_regenerates_twice_for_two_life() -> void:
	var ghost := put_battlefield(0, "Mischievous Poltergeist")
	assert_ok(g.activate_ability(0, ghost, 0))
	assert_ok(g.activate_ability(0, ghost, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	g.destroy(ghost)
	g.untap_permanent(ghost)
	g.destroy(ghost)
	assert_eq(ghost.zone, Mtg.Zone.BATTLEFIELD, "two shields, two survivals")


# --- Dwarven Thaumaturgist --------------------------------------------------

func test_thaumaturgist_switches_power_and_toughness_until_end_of_turn() -> void:
	var dwarf := put_battlefield(0, "Dwarven Thaumaturgist")
	var minotaur := put_battlefield(1, "Hurloon Minotaur")
	assert_ok(g.activate_ability(0, dwarf, 0, [TargetRef.card(minotaur)]))
	resolve_stack()
	assert_eq(minotaur.cur_power, 3)
	assert_eq(minotaur.cur_toughness, 2)
	advance_to_next_turn()
	assert_eq(minotaur.cur_power, 2)
	assert_eq(minotaur.cur_toughness, 3)

func test_thaumaturgist_kills_a_zero_power_wall() -> void:
	var dwarf := put_battlefield(0, "Dwarven Thaumaturgist")
	var wall := put_battlefield(1, "Wall of Stone")
	assert_ok(g.activate_ability(0, dwarf, 0, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)


# --- Maraxus of Keld --------------------------------------------------------

func test_maraxus_counts_untapped_artifacts_creatures_and_lands_once_each() -> void:
	var maraxus := put_battlefield(0, "Maraxus of Keld")
	var forest := put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Ornithopter")   # an artifact creature counts ONCE
	put_battlefield(0, "Sol Ring")
	put_battlefield(1, "Forest")        # the opponent's do not count
	put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	assert_eq(maraxus.cur_power, 5)
	assert_eq(maraxus.cur_toughness, 5)
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(maraxus.cur_power, 4)
	g.tap_permanent(maraxus)
	assert_eq(maraxus.cur_toughness, 3, "tapping Maraxus itself shrinks it")

func test_maraxus_defines_its_size_in_hand() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var maraxus := give_hand(0, "Maraxus of Keld")
	g.recalculate()
	assert_eq(maraxus.cur_power, 2)
	assert_eq(maraxus.cur_toughness, 2)


# --- Orcish Settlers --------------------------------------------------------

func test_settlers_destroy_x_target_lands_for_double_x() -> void:
	var settlers := put_battlefield(0, "Orcish Settlers")
	var a := put_battlefield(1, "Forest")
	var b := put_battlefield(1, "Island")
	var c := put_battlefield(1, "Swamp")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, settlers, 0, [TargetRef.card(a), TargetRef.card(b)], 2),
		"")   # {2}{2}{R} needs five mana, only four are floating
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, settlers, 0, [TargetRef.card(a), TargetRef.card(b)], 2))
	assert_eq(settlers.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(c.zone, Mtg.Zone.BATTLEFIELD)

func test_settlers_refuse_non_land_targets_and_x_zero_destroys_nothing() -> void:
	var settlers := put_battlefield(0, "Orcish Settlers")
	var bear := put_battlefield(1, "Grizzly Bears")
	var forest := put_battlefield(1, "Forest")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_refused(g.activate_ability(0, settlers, 0, [TargetRef.card(bear)], 1))
	assert_eq(settlers.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.activate_ability(0, settlers, 0, [], 0))
	resolve_stack()
	assert_eq(settlers.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 2, "X = 0 costs only {R}")


# --- Fungus Elemental -------------------------------------------------------

func test_fungus_elemental_grows_only_the_turn_it_entered() -> void:
	var fungus := put_battlefield(0, "Fungus Elemental", true)
	var forest := put_battlefield(0, "Forest")
	var forest2 := put_battlefield(0, "Forest")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, fungus, 0))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "a Forest is sacrificed as the cost")
	resolve_stack()
	assert_eq(int(fungus.counters.get("+2/+2", 0)), 1)
	assert_eq(fungus.cur_power, 5)
	assert_eq(fungus.cur_toughness, 5)
	advance_to_next_turn()
	advance_to_next_turn()
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, fungus, 0), "entered this turn")
	assert_eq(forest2.zone, Mtg.Zone.BATTLEFIELD)

func test_fungus_elemental_needs_a_forest_to_sacrifice() -> void:
	var fungus := put_battlefield(0, "Fungus Elemental", true)
	put_battlefield(0, "Mountain")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, fungus, 0), "Forest")


# --- Llanowar Behemoth ------------------------------------------------------

func test_behemoth_taps_itself_while_summoning_sick_to_grow() -> void:
	var behemoth := put_battlefield(0, "Llanowar Behemoth", true)
	assert_ok(g.activate_ability(0, behemoth, 0))
	assert_true(behemoth.tapped)
	resolve_stack()
	assert_eq(behemoth.cur_power, 5)
	assert_eq(behemoth.cur_toughness, 5)
	assert_refused(g.activate_ability(0, behemoth, 0), "untapped")

func test_behemoth_taps_another_creature_but_never_an_opponents() -> void:
	var behemoth := put_battlefield(0, "Llanowar Behemoth")
	var bear := put_battlefield(0, "Grizzly Bears", true)
	var theirs := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Forest")
	g.tap_permanent(behemoth)
	assert_ok(g.activate_ability(0, behemoth, 0))
	assert_true(bear.tapped, "a sick creature may be tapped for a non-{T} cost (CR 302.6)")
	assert_false(theirs.tapped)
	resolve_stack()
	assert_eq(behemoth.cur_power, 5)
	assert_refused(g.activate_ability(0, behemoth, 0))


# --- Llanowar Druid ---------------------------------------------------------

func test_druid_untaps_every_forest_on_both_sides() -> void:
	var druid := put_battlefield(0, "Llanowar Druid")
	var mine := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Forest")
	var mountain := put_battlefield(0, "Mountain")
	for land in [mine, theirs, mountain]: g.tap_permanent(land)
	assert_ok(g.activate_ability(0, druid, 0))
	assert_eq(druid.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_false(mine.tapped)
	assert_false(theirs.tapped)
	assert_true(mountain.tapped)

func test_druid_is_a_tap_ability_and_respects_summoning_sickness() -> void:
	var druid := put_battlefield(0, "Llanowar Druid", true)
	assert_refused(g.activate_ability(0, druid, 0), "summoning sickness")
	assert_eq(druid.zone, Mtg.Zone.BATTLEFIELD)


# --- Serrated Biskelion -----------------------------------------------------

func test_biskelion_shrinks_itself_and_its_target() -> void:
	var bis := put_battlefield(0, "Serrated Biskelion")
	var minotaur := put_battlefield(1, "Hurloon Minotaur")
	assert_ok(g.activate_ability(0, bis, 0, [TargetRef.card(minotaur)]))
	resolve_stack()
	assert_eq(int(bis.counters.get("-1/-1", 0)), 1)
	assert_eq(int(minotaur.counters.get("-1/-1", 0)), 1)
	assert_eq(bis.cur_power, 1)
	assert_eq(minotaur.cur_toughness, 2)

func test_biskelion_whose_target_is_gone_puts_no_counter_on_itself() -> void:
	var bis := put_battlefield(0, "Serrated Biskelion")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, bis, 0, [TargetRef.card(bear)]))
	g.destroy(bear)
	resolve_stack()
	assert_eq(int(bis.counters.get("-1/-1", 0)), 0, "CR 608.2b: all targets illegal, nothing happens")

func test_biskelion_gone_in_response_still_shrinks_the_target() -> void:
	var bis := put_battlefield(0, "Serrated Biskelion")
	var minotaur := put_battlefield(1, "Hurloon Minotaur")
	assert_ok(g.activate_ability(0, bis, 0, [TargetRef.card(minotaur)]))
	g.return_to_hand(bis)
	resolve_stack()
	assert_eq(int(minotaur.counters.get("-1/-1", 0)), 1)
	assert_eq(int(bis.counters.get("-1/-1", 0)), 0)


# --- Steel Golem ------------------------------------------------------------

func test_steel_golem_stops_only_its_controller_casting_creatures() -> void:
	var golem := put_battlefield(0, "Steel Golem")
	var bear := give_hand(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_refused(g.cast_spell(0, bear))
	assert_ne(g.play_banned(0, bear.data), "")
	assert_eq(g.play_banned(1, bear.data), "", "the opponent may still cast creatures")
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(golem)]))
	resolve_stack()
	assert_eq(g.play_banned(0, growth.data), "")
	g.change_control(golem, 1)
	assert_eq(g.play_banned(0, bear.data), "", "the ban follows the Golem's controller")
	assert_ne(g.play_banned(1, bear.data), "")
	g.destroy(golem)
	assert_eq(g.play_banned(1, bear.data), "")
	assert_ok(g.cast_spell(0, bear))


# --- Benalish Knight ---------------------------------------------------------

func test_benalish_knight_has_flash_and_first_strike() -> void:
	advance_to_next_turn()   # the opponent's main phase
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var bear := give_hand(0, "Grizzly Bears")
	var knight := give_hand(0, "Benalish Knight")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, bear), "")
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, knight))
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_true(knight.has_keyword(Mtg.Keyword.FLASH))


func test_benalish_knight_flashes_in_with_a_spell_on_the_stack() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	var knight := give_hand(0, "Benalish Knight")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, knight))
	assert_eq(g.stack.size(), 2)
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)


# --- Avizoa -----------------------------------------------------------------

func test_avizoa_grows_once_a_turn_and_skips_your_next_untap_step() -> void:
	var avizoa := put_battlefield(0, "Avizoa")
	var forest := put_battlefield(0, "Forest")
	g.tap_permanent(forest)
	assert_ok(g.activate_ability(0, avizoa, 0))
	resolve_stack()
	assert_eq(avizoa.cur_power, 4)
	assert_eq(avizoa.cur_toughness, 4)
	assert_refused(g.activate_ability(0, avizoa, 0), "once")
	g.tap_permanent(avizoa)
	advance_to_next_turn()   # the opponent untaps as usual
	assert_eq(avizoa.cur_power, 2, "until end of turn")
	advance_to_next_turn()   # our untap step is skipped
	assert_true(forest.tapped)
	assert_true(avizoa.tapped)
	advance_to_next_turn()
	advance_to_next_turn()   # the one after that happens
	assert_false(forest.tapped)
	assert_false(avizoa.tapped)


func test_avizoa_activated_on_the_opponents_turn_skips_its_controllers_next_untap() -> void:
	var avizoa := put_battlefield(0, "Avizoa")
	var opposing := put_battlefield(1, "Forest")
	advance_to_next_turn()
	g.tap_permanent(opposing)
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, avizoa, 0))
	resolve_stack()
	assert_eq(avizoa.cur_power, 4)
	var mine := put_battlefield(0, "Forest")
	g.tap_permanent(mine)
	advance_to_next_turn()   # our turn: skipped
	assert_true(mine.tapped)
	advance_to_next_turn()   # the opponent's turn: theirs untaps
	assert_false(opposing.tapped)
