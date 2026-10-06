extends GameTest
## Pack 9 (the Tempest block), batch B8: the Tempest combat cards in
## cards/sets/tmp/_combat.gd — Apes of Rath, Elite Javelineer, Elven
## Warhounds, Flailing Drake, Flowstone Salamander, Gerrard's Battle Cry,
## Knight of Dusk, Maddening Imp, Magnetic Web, Mogg Conscripts, Mounted
## Archers, No Quarter, Propaganda, Renegade Warlord, Safeguard, Sea
## Monster, Storm Front, Trumpeting Armodon and Watchdog.

const CLAIMED := ["Apes of Rath", "Elite Javelineer", "Elven Warhounds", "Flailing Drake",
	"Flowstone Salamander", "Gerrard's Battle Cry", "Knight of Dusk", "Maddening Imp",
	"Magnetic Web", "Mogg Conscripts", "Mounted Archers", "No Quarter", "Propaganda",
	"Renegade Warlord", "Safeguard", "Sea Monster", "Storm Front", "Trumpeting Armodon",
	"Watchdog"]

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

## A card ask answered with the candidate named [member pick] when there is
## one, else the default.
class Seat extends DecisionAgent:
	var pick := ""
	var asked: Array[String] = []
	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		for c in candidates:
			if c.data.card_name == pick: return c
		return super(game, pid, candidates, prompt)

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

## Hand priority to [param pid] in the current step (the other seat passes).
func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

## The active player attacks with [param attackers]; attack triggers resolve.
func _attack(attackers: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(g.active_player, attackers))
	resolve_stack()

## The defending player declares [param blocks]; block triggers resolve.
func _block(blocks: Dictionary) -> void:
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(g.opponent_of(g.active_player), blocks))
	resolve_stack()


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


func test_the_ai_reads_a_declared_role_for_each_card_local_effect() -> void:
	var roles := {"Maddening Imp": &"forces_attacks", "Magnetic Web": &"magnet_counter",
		"Mounted Archers": &"extra_block", "Trumpeting Armodon": &"lure_target"}
	for card_name in roles:
		var c := CardRegistry.get_card(card_name)
		assert_eq(c.activated_abilities[0].effects[0].ai_role, roles[card_name], card_name)


# ------------------------------------------------------------ Apes of Rath --

func test_apes_of_rath_skips_its_next_untap_step_after_attacking() -> void:
	var apes := put_battlefield(0, "Apes of Rath")
	_attack([apes.id])
	advance_to_next_turn()   # the opponent's turn
	advance_to_next_turn()   # ours: the untap step left it tapped
	assert_true(apes.tapped, "it doesn't untap during its controller's next untap step")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(apes.tapped, "only the NEXT untap step")

func test_apes_of_rath_that_did_not_attack_untaps_normally() -> void:
	var apes := put_battlefield(0, "Apes of Rath")
	g.tap_permanent(apes)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(apes.tapped)


# -------------------------------------------------------- Elite Javelineer --

func test_elite_javelineer_blocking_deals_1_damage_to_target_attacking_creature() -> void:
	var seat := _seat(1)
	seat.pick = "Grizzly Bears"
	var javelineer := put_battlefield(1, "Elite Javelineer")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([giant.id, bear.id])
	_block({javelineer.id: giant.id})
	assert_eq(bear.damage, 1, "any attacking creature, not only the one it blocks")
	assert_eq(giant.damage, 0)

func test_elite_javelineer_hint_picks_the_attacker_the_point_kills() -> void:
	var javelineer := put_battlefield(1, "Elite Javelineer")
	var giant := put_battlefield(0, "Hill Giant")
	var elves := put_battlefield(0, "Llanowar Elves")
	_attack([giant.id, elves.id])
	_block({javelineer.id: giant.id})
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)

func test_elite_javelineer_only_attacking_creatures_are_targets_and_no_block_no_trigger() -> void:
	var javelineer := put_battlefield(1, "Elite Javelineer")
	var trigger: TriggeredAbility = javelineer.data.triggered_abilities[0]
	var giant := put_battlefield(0, "Hill Giant")
	var home := put_battlefield(0, "Grizzly Bears")
	_attack([giant.id])
	var legal := trigger.target_spec.legal_targets(g, javelineer)
	assert_eq(legal.size(), 1)
	assert_eq(legal[0].instance_id, giant.id, "a creature that stayed home is no target")
	_block({})
	assert_eq(giant.damage, 0, "it triggers only when it blocks")
	assert_eq(home.damage, 0)


# --------------------------------------------------------- Elven Warhounds --

func test_elven_warhounds_puts_each_blocker_on_top_of_its_owners_library() -> void:
	var hounds := put_battlefield(0, "Elven Warhounds")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_attack([hounds.id])
	_block({bear.id: hounds.id, giant.id: hounds.id})
	assert_eq(bear.zone, Mtg.Zone.LIBRARY)
	assert_eq(giant.zone, Mtg.Zone.LIBRARY)
	var library := g.players[1].library
	assert_true(library.slice(library.size() - 2).has(bear), "on top")
	assert_true(library.slice(library.size() - 2).has(giant), "on top")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "it stays blocked (CR 509.1h)")

func test_elven_warhounds_unblocked_or_blocking_does_nothing() -> void:
	var hounds := put_battlefield(0, "Elven Warhounds")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack([hounds.id])
	_block({})
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()   # the opponent attacks INTO a Warhounds
	var guard := put_battlefield(0, "Elven Warhounds")
	var giant := put_battlefield(1, "Hill Giant")
	_attack([giant.id])
	_block({guard.id: giant.id})
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "blocking is not becoming blocked")


# ---------------------------------------------------------- Flailing Drake --

func test_flailing_drake_pumps_the_creature_it_blocks() -> void:
	var drake := put_battlefield(1, "Flailing Drake")
	var giant := put_battlefield(0, "Hill Giant")
	_attack([giant.id])
	_block({drake.id: giant.id})
	assert_eq(_pt(giant), [4, 4])
	assert_eq(_pt(drake), [2, 3], "not the Drake itself")

func test_flailing_drake_pumps_the_creature_blocking_it_until_end_of_turn() -> void:
	var drake := put_battlefield(0, "Flailing Drake")
	var angel := put_battlefield(1, "Serra Angel")
	_attack([drake.id])
	_block({angel.id: drake.id})
	assert_eq(_pt(angel), [5, 5])
	advance_to_next_turn()
	assert_eq(_pt(angel), [4, 4])

func test_flailing_drake_unblocked_pumps_nobody() -> void:
	var drake := put_battlefield(0, "Flailing Drake")
	var angel := put_battlefield(1, "Serra Angel")
	_attack([drake.id])
	_block({})
	assert_eq(_pt(angel), [4, 4])


# ----------------------------------------------------- Flowstone Salamander --

func test_flowstone_salamander_pings_only_a_creature_blocking_it() -> void:
	var salamander := put_battlefield(0, "Flowstone Salamander")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, R)
	assert_refused(g.activate_ability(0, salamander, 0, [TargetRef.card(bear)]))
	_attack([salamander.id])
	_block({bear.id: salamander.id})
	_priority(0)
	add_mana(0, R, 2)
	assert_refused(g.activate_ability(0, salamander, 0, [TargetRef.card(giant)]),
		"")
	assert_ok(g.activate_ability(0, salamander, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 1)
	assert_ok(g.activate_ability(0, salamander, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------ Gerrard's Battle Cry --

func test_gerrards_battle_cry_pumps_only_its_controllers_creatures() -> void:
	var cry := put_battlefield(0, "Gerrard's Battle Cry")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, cry, 0))
	add_mana(0, W)
	add_mana(0, G, 2)
	assert_ok(g.activate_ability(0, cry, 0))
	resolve_stack()
	assert_eq(_pt(mine), [3, 3])
	assert_eq(_pt(theirs), [2, 2])
	var late := put_battlefield(0, "Hill Giant")
	assert_eq(_pt(late), [3, 3], "the creatures as it resolved (CR 611.2c)")
	advance_to_next_turn()
	assert_eq(_pt(mine), [2, 2])


# ---------------------------------------------------------- Knight of Dusk --

func test_knight_of_dusk_destroys_a_creature_blocking_it() -> void:
	var knight := put_battlefield(0, "Knight of Dusk")
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack([knight.id])
	_block({giant.id: knight.id})
	_priority(0)
	add_mana(0, B, 2)
	assert_refused(g.activate_ability(0, knight, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, knight, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- Maddening Imp --

func test_maddening_imp_drafts_every_non_wall_and_dooms_the_ones_that_stay_home() -> void:
	var imp := put_battlefield(1, "Maddening Imp")
	var bear := put_battlefield(0, "Grizzly Bears")
	var sick := put_battlefield(0, "Hill Giant", true)
	var wall := put_battlefield(0, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	_priority(1)
	assert_ok(g.activate_ability(1, imp, 0))
	resolve_stack()
	assert_true(imp.tapped)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, []), "must attack")
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_next_turn()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "it attacked")
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "Walls are not drafted")
	assert_eq(sick.zone, Mtg.Zone.GRAVEYARD,
		"it could not attack, so it didn't — destroyed (no 'continuously' clause)")

func test_maddening_imp_only_on_an_opponents_turn_before_combat() -> void:
	var mine := put_battlefield(0, "Maddening Imp")
	var theirs := put_battlefield(1, "Maddening Imp")
	put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, mine, 0), "opponent's turn")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	_priority(1)
	assert_refused(g.activate_ability(1, theirs, 0), "before combat")
	advance_to_step(Mtg.Step.MAIN2)
	_priority(1)
	assert_refused(g.activate_ability(1, theirs, 0), "before combat")


# ------------------------------------------------------------ Magnetic Web --

func test_magnetic_web_puts_a_magnet_counter_on_target_creature() -> void:
	var web := put_battlefield(0, "Magnetic Web")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, G, 2)
	assert_ok(g.activate_ability(0, web, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(int(bear.counters.get("magnet", 0)), 1)
	assert_refused(g.activate_ability(0, web, 0, [TargetRef.card(bear)]), "")

func test_a_magnet_attacker_drags_every_able_magnet_creature_along() -> void:
	put_battlefield(1, "Magnetic Web")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var elves := put_battlefield(0, "Llanowar Elves")
	g.add_counters(bear, "magnet")
	g.add_counters(giant, "magnet")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]), "magnet")
	assert_refused(g.declare_attackers(0, [giant.id, elves.id]), "magnet")
	assert_ok(g.declare_attackers(0, [bear.id, giant.id]))

func test_without_a_magnet_attacker_nothing_is_required() -> void:
	put_battlefield(0, "Magnetic Web")
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(0, "Llanowar Elves")
	g.add_counters(bear, "magnet")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [elves.id]))

func test_magnet_creatures_must_block_the_magnet_attacker() -> void:
	put_battlefield(1, "Magnetic Web")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var spare := put_battlefield(1, "Grizzly Bears")
	g.add_counters(bear, "magnet")
	g.add_counters(wall, "magnet")
	_attack([bear.id, giant.id])
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}))
	assert_refused(g.declare_blockers(1, {wall.id: giant.id}))
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	assert_eq(spare.zone, Mtg.Zone.BATTLEFIELD, "no counter, no requirement")

func test_a_tapped_magnetic_web_still_binds_under_modern_rules() -> void:
	var web := put_battlefield(0, "Magnetic Web")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	g.add_counters(bear, "magnet")
	g.add_counters(giant, "magnet")
	g.tap_permanent(web)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]), "magnet")

func test_a_tapped_magnetic_web_imposes_nothing_under_the_1997_rules() -> void:
	g.rules.set_edition("fifth")
	var web := put_battlefield(0, "Magnetic Web")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	g.add_counters(bear, "magnet")
	g.add_counters(giant, "magnet")
	g.tap_permanent(web)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))

func test_a_non_magnet_attack_asks_no_magnet_blocks() -> void:
	put_battlefield(1, "Magnetic Web")
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	g.add_counters(wall, "magnet")
	_attack([giant.id])
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))


# --------------------------------------------------------- Mogg Conscripts --

func test_mogg_conscripts_attacks_only_after_its_controller_cast_a_creature_spell() -> void:
	var mogg := put_battlefield(0, "Mogg Conscripts")
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_string_contains(CombatState.attack_illegality(g, mogg, 1), "can't attack")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bear))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mogg.id]))

func test_mogg_conscripts_cannot_attack_on_a_turn_without_one() -> void:
	var mogg := put_battlefield(0, "Mogg Conscripts")
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bear))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [mogg.id]), "can't attack")


# --------------------------------------------------------- Mounted Archers --

func test_mounted_archers_blocks_a_flier_and_one_creature_without_paying() -> void:
	var archers := put_battlefield(1, "Mounted Archers")
	var angel := put_battlefield(0, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([angel.id, bear.id])
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {archers.id: [angel.id, bear.id]}))
	assert_ok(g.declare_blockers(1, {archers.id: angel.id}))

func test_mounted_archers_pays_w_to_block_an_additional_creature_this_turn() -> void:
	var archers := put_battlefield(1, "Mounted Archers")
	var angel := put_battlefield(0, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([angel.id, bear.id])
	_priority(1)
	add_mana(1, W)
	assert_ok(g.activate_ability(1, archers, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {archers.id: [angel.id, bear.id]}))
	advance_to_next_turn()
	assert_eq(archers.extra_blocks_this_turn, 0, "this turn only")


# --------------------------------------------------------------- No Quarter --

func test_no_quarter_destroys_a_blocker_with_lesser_power() -> void:
	put_battlefield(1, "No Quarter")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack([giant.id])
	_block({bear.id: giant.id})
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)

func test_no_quarter_destroys_an_attacker_with_lesser_power() -> void:
	put_battlefield(0, "No Quarter")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_attack([bear.id])
	_block({giant.id: bear.id})
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)

func test_no_quarter_leaves_equal_powers_alone() -> void:
	put_battlefield(0, "No Quarter")
	var bear := put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(1, "Grizzly Bears")
	_attack([bear.id])
	_block({other.id: bear.id})
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(other.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------------- Propaganda --

func test_propaganda_charges_two_for_each_creature_attacking_its_controller() -> void:
	put_battlefield(1, "Propaganda")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]))
	add_mana(0, G, 2)
	assert_refused(g.declare_attackers(0, [bear.id, giant.id]), "{4}")
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_eq(g.players[0].mana_pool.total(), 0, "the {2} was paid")

func test_propaganda_does_not_tax_its_own_controllers_attack() -> void:
	put_battlefield(0, "Propaganda")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))


# --------------------------------------------------------- Renegade Warlord --

func test_renegade_warlord_pumps_each_other_attacker() -> void:
	var warlord := put_battlefield(0, "Renegade Warlord")
	var bear := put_battlefield(0, "Grizzly Bears")
	var home := put_battlefield(0, "Llanowar Elves")
	assert_true(warlord.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	_attack([warlord.id, bear.id])
	assert_eq(_pt(bear), [3, 2])
	assert_eq(_pt(warlord), [3, 3], "each OTHER attacking creature")
	assert_eq(_pt(home), [1, 1])

func test_renegade_warlord_staying_home_pumps_nobody() -> void:
	put_battlefield(0, "Renegade Warlord")
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([bear.id])
	assert_eq(_pt(bear), [2, 2])


# ---------------------------------------------------------------- Safeguard --

func test_safeguard_prevents_the_combat_damage_target_creature_would_deal() -> void:
	var guard := put_battlefield(1, "Safeguard")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack([giant.id])
	_block({bear.id: giant.id})
	_priority(1)
	add_mana(1, W)
	assert_refused(g.activate_ability(1, guard, 0, [TargetRef.card(giant)]))
	add_mana(1, G, 2)
	assert_ok(g.activate_ability(1, guard, 0, [TargetRef.card(giant)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the Giant's damage is prevented")
	assert_eq(bear.damage, 0)
	assert_eq(giant.damage, 2, "only damage dealt BY it")


## A seat that asks for the 1997 damage-prevention window.
class WindowSeat extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true

func test_safeguard_works_in_the_1997_damage_prevention_window() -> void:
	g.rules.set_edition("fifth")
	g.rules.damage_prevention_window = true
	g.set_agent(1, WindowSeat.new())
	var guard := put_battlefield(1, "Safeguard")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack([giant.id])
	_block({bear.id: giant.id})
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the 1997 damage prevention step is open")
	_priority(1)
	add_mana(1, W)
	add_mana(1, G, 2)
	assert_ok(g.activate_ability(1, guard, 0, [TargetRef.card(giant)]))
	var guard_loop := 0
	while (g.awaiting_damage_prevention or g.awaiting_regeneration or not g.stack.is_empty()) \
			and guard_loop < 20:
		if g.stack.is_empty():
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard_loop += 1
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the waiting damage from the Giant is prevented")
	assert_eq(giant.damage, 2)


# --------------------------------------------------------------- Sea Monster --

func test_sea_monster_attacks_only_into_an_island() -> void:
	var monster := put_battlefield(0, "Sea Monster")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [monster.id]), "Island")
	put_battlefield(1, "Island")
	assert_ok(g.declare_attackers(0, [monster.id]))


# --------------------------------------------------------------- Storm Front --

func test_storm_front_taps_target_creature_with_flying() -> void:
	var front := put_battlefield(0, "Storm Front")
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, G, 2)
	assert_refused(g.activate_ability(0, front, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, front, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_true(angel.tapped)
	assert_false(front.tapped, "no {T} in the cost")


# -------------------------------------------------------- Trumpeting Armodon --

func test_trumpeting_armodon_makes_target_creature_block_it() -> void:
	var armodon := put_battlefield(0, "Trumpeting Armodon")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var spare := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, G, 2)
	assert_ok(g.activate_ability(0, armodon, 0, [TargetRef.card(bear)]))
	resolve_stack()
	_attack([armodon.id, giant.id])
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}))
	assert_refused(g.declare_blockers(1, {bear.id: giant.id}))
	# Only the target is asked; the other creature blocks freely.
	assert_ok(g.declare_blockers(1, {bear.id: armodon.id, spare.id: giant.id}))

func test_trumpeting_armodon_requirement_ends_with_the_turn() -> void:
	var armodon := put_battlefield(0, "Trumpeting Armodon")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, G, 2)
	assert_ok(g.activate_ability(0, armodon, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(armodon.cur_must_be_blocked)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(armodon.cur_must_be_blocked)
	_attack([armodon.id])
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))


# ---------------------------------------------------------------- Watchdog --

func test_watchdog_blocks_each_combat_and_shrinks_attackers_while_untapped() -> void:
	var dog := put_battlefield(1, "Watchdog")
	var giant := put_battlefield(0, "Hill Giant")
	_attack([giant.id])
	assert_eq(giant.cur_power, 2, "-1/-0 while it attacks the Watchdog's controller")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}), "blocks each combat")
	assert_ok(g.declare_blockers(1, {dog.id: giant.id}))
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(giant.cur_power, 3, "no longer attacking")

func test_a_tapped_watchdog_neither_blocks_nor_shrinks() -> void:
	var dog := put_battlefield(1, "Watchdog")
	g.tap_permanent(dog)
	var giant := put_battlefield(0, "Hill Giant")
	_attack([giant.id])
	assert_eq(giant.cur_power, 3)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))

func test_watchdog_does_not_shrink_its_own_controllers_attackers() -> void:
	put_battlefield(0, "Watchdog")
	var giant := put_battlefield(0, "Hill Giant")
	_attack([giant.id])
	assert_eq(giant.cur_power, 3)


# ------------------------------------------------------------ both presets --

func test_the_1997_rules_keep_the_combat_cards() -> void:
	g.rules.set_edition("fifth")
	put_battlefield(1, "No Quarter")
	var dog := put_battlefield(1, "Watchdog")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack([giant.id])
	assert_eq(giant.cur_power, 2)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: giant.id}), "blocks each combat")
	assert_ok(g.declare_blockers(1, {dog.id: giant.id, bear.id: giant.id}))
	resolve_stack()
	assert_eq(dog.zone, Mtg.Zone.GRAVEYARD, "1 < 2: the blocker with lesser power")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "2 is not less than 2")
