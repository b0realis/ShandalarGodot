extends GameTest
## Pack 8, batch B1: the Mirage phasing cards (cards/sets/mir/_phasing.gd),
## driven through the real cast / activate / turn APIs on engine package E1
## (CR 702.26). The untap-step cycle is walked over two full turns of the
## controller: out before they untap, out through the opponent's turn, back
## in — untapped — on their next untap step; Auras ride along indirectly;
## phase triggers wait for the upkeep; a phased-out permanent is neither
## counted, targeted nor in combat.


class Scripted extends DecisionAgent:
	## FIFO answers; an empty queue falls back to the caller's hint.
	var options: Array = []   # int index or String label (case-insensitive)
	var answers: Array = []   # bool
	var picks: Array = []     # CardInstance, card name, or null (decline)
	var asked: Array[String] = []   # every prompt, in order

	func answer_option(_g: MtgGame, _p: int, prompt: String,
			labels: Array[String], hint: int) -> int:
		asked.append(prompt)
		if options.is_empty():
			return hint
		var want: Variant = options.pop_front()
		if want is String:
			for i in labels.size():
				if labels[i].to_lower().contains(String(want).to_lower()):
					return i
			return hint
		return int(want)

	func answer_yes_no(_g: MtgGame, _p: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		if want == null:
			return null
		for c in candidates:
			if want is CardInstance and c == want:
				return c
			if want is String and c.data.card_name == want:
				return c
		return null if candidates.is_empty() else candidates[0]


var p0: Scripted
var p1: Scripted


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	p0 = seat(0)
	p1 = seat(1)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a


## Exactly the mana [param card]'s cost asks for.
func fund(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)


func cast(name: String, targets: Array = [], mode := 0, pid := 0) -> CardInstance:
	var card := give_hand(pid, name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets, 0, mode))
	resolve_stack()
	return card


func activate(inst: CardInstance, index: int, targets: Array = [], pid := 0) -> void:
	assert_ok(g.activate_ability(pid, inst, index, targets))
	resolve_stack()


## The untap-step cycle of a permanent [param pid] controls, from the
## first main phase of turn 1 (P0's): out on [param pid]'s next untap step,
## still out through the other seat's turn, back in — untapped — on the
## one after.
func assert_phasing_cycle(inst: CardInstance, pid: int, label: String) -> void:
	g.tap_permanent(inst)
	if pid == 1:
		advance_to_next_turn()   # turn 2: P1's untap step
	else:
		advance_to_next_turn()   # turn 2: P1's — nothing of P0's phases
		assert_false(inst.phased_out, "%s: the opponent's untap step leaves it alone" % label)
		advance_to_next_turn()   # turn 3: P0's untap step
	assert_true(inst.phased_out, "%s: phased out before its controller untapped (CR 502.1)" % label)
	assert_false(g.players[pid].battlefield.has(inst), "%s: treated as though it doesn't exist" % label)
	assert_true(inst.tapped, "%s: it phased out before the untap, so it stayed tapped" % label)
	advance_to_next_turn()
	assert_true(inst.phased_out, "%s: still out through the other seat's turn" % label)
	advance_to_next_turn()
	assert_false(inst.phased_out, "%s: back in on its controller's next untap step" % label)
	assert_false(inst.tapped, "%s: phased in before the untap, so it untapped too (502.3)" % label)
	assert_true(g.players[pid].battlefield.has(inst), label)


# ------------------------------------------------------- printed phasing --

func test_printed_phasing_bodies_carry_the_keyword_and_cycle() -> void:
	var raiders := put_battlefield(0, "Merfolk Raiders")
	assert_true(raiders.has_keyword(Mtg.Keyword.PHASING))
	assert_true(raiders.cur_landwalk.has("island"), "islandwalk kept")
	assert_phasing_cycle(raiders, 0, "Merfolk Raiders")


func test_sandbar_crocodile_cycles_and_is_not_attackable_while_out() -> void:
	var croc := put_battlefield(0, "Sandbar Crocodile")
	assert_true(croc.has_keyword(Mtg.Keyword.PHASING))
	assert_eq([croc.cur_power, croc.cur_toughness], [6, 5])
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: out
	assert_true(croc.phased_out)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [croc.id]))


func test_teferis_drake_flies_and_cycles() -> void:
	var drake := put_battlefield(0, "Teferi's Drake")
	assert_true(drake.has_keyword(Mtg.Keyword.FLYING))
	assert_phasing_cycle(drake, 0, "Teferi's Drake")


func test_teferis_drake_and_a_one_shot_under_the_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	var drake := put_battlefield(0, "Teferi's Drake")
	assert_phasing_cycle(drake, 0, "Teferi's Drake (Fifth Edition rules)")
	var giant := put_battlefield(1, "Hill Giant")
	cast("Reality Ripple", [TargetRef.card(giant)])
	assert_true(giant.phased_out)


func test_a_phased_out_drake_cannot_be_targeted() -> void:
	var drake := put_battlefield(1, "Teferi's Drake")
	advance_to_next_turn()   # turn 2: P1's untap step — it phases out
	assert_true(drake.phased_out)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(drake)]))


# --------------------------------------------------------- Teferi's Isle --

func test_teferis_isle_enters_tapped_taps_for_two_blue_and_phases() -> void:
	var isle := give_hand(0, "Teferi's Isle")
	assert_ok(g.play_land(0, isle))
	assert_true(isle.tapped, "enters tapped")
	assert_true(isle.has_keyword(Mtg.Keyword.PHASING))
	g.untap_permanent(isle)
	assert_ok(g.tap_for_mana(0, isle))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2, "{T}: Add {U}{U}")
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: P0's untap step
	assert_true(isle.phased_out, "a land with phasing phases out like anything else")
	assert_refused(g.tap_for_mana(0, isle))
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(isle.phased_out)
	assert_false(isle.tapped)


# --------------------------------------------- Cloak of Invisibility --

func test_cloak_grants_phasing_and_rides_its_host_out_and_back() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var cloak := cast("Cloak of Invisibility", [TargetRef.card(bear)])
	assert_eq(cloak.attached_to, bear.id)
	assert_true(bear.has_keyword(Mtg.Keyword.PHASING), "enchanted creature has phasing")
	advance_to_next_turn()
	assert_false(bear.phased_out)
	advance_to_next_turn()   # turn 3: P0's untap step
	assert_true(bear.phased_out)
	assert_true(cloak.phased_out and cloak.phased_indirectly, "the Aura rides along (702.26g)")
	advance_to_next_turn()
	assert_true(bear.phased_out and cloak.phased_out)
	advance_to_next_turn()   # turn 5: back together
	assert_false(bear.phased_out)
	assert_false(cloak.phased_out)
	assert_eq(cloak.attached_to, bear.id, "and still attached (702.26i)")
	assert_true(bear.has_keyword(Mtg.Keyword.PHASING))


func test_cloaked_creature_can_be_blocked_only_by_walls() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Cloak of Invisibility", [TargetRef.card(bear)])
	var giant := put_battlefield(1, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {giant.id: bear.id}))
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))


# ------------------------------------------------------- Teferi's Curse --

func test_teferis_curse_phases_an_opponents_artifact_and_rides_it() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var forest := put_battlefield(1, "Forest")
	var curse := give_hand(0, "Teferi's Curse")
	fund(0, curse)
	assert_refused(g.cast_spell(0, curse, [TargetRef.card(forest)]), "")
	assert_ok(g.cast_spell(0, curse, [TargetRef.card(ring)]))
	resolve_stack()
	assert_true(ring.has_keyword(Mtg.Keyword.PHASING), "enchanted permanent has phasing")
	advance_to_next_turn()   # turn 2: P1's untap step
	assert_true(ring.phased_out)
	assert_true(curse.phased_out and curse.phased_indirectly)
	advance_to_next_turn()
	assert_true(ring.phased_out, "out through P0's turn")
	advance_to_next_turn()   # turn 4: P1's
	assert_false(ring.phased_out)
	assert_false(curse.phased_out)
	assert_eq(curse.attached_to, ring.id)


# ---------------------------------------------------------------- Shimmer --

func test_shimmer_gives_the_chosen_land_type_phasing_on_both_sides() -> void:
	var my_island := put_battlefield(0, "Island")
	var my_forest := put_battlefield(0, "Forest")
	var their_island := put_battlefield(1, "Island")
	p0.options = ["Island"]
	var shimmer := cast("Shimmer")
	assert_eq(String(shimmer.memory.get("land_type", "")), "island")
	assert_true(my_island.has_keyword(Mtg.Keyword.PHASING))
	assert_true(their_island.has_keyword(Mtg.Keyword.PHASING))
	assert_false(my_forest.has_keyword(Mtg.Keyword.PHASING))
	advance_to_next_turn()   # P1's untap step
	assert_true(their_island.phased_out)
	assert_false(my_island.phased_out)
	advance_to_next_turn()   # P0's
	assert_true(my_island.phased_out)
	assert_false(my_forest.phased_out)
	assert_true(their_island.phased_out, "P1's comes back on P1's next untap step")
	advance_to_next_turn()   # turn 4: P1's
	assert_false(their_island.phased_out)


# ----------------------------------------------------------- Dream Fighter --

func test_dream_fighter_becomes_blocked_and_both_phase_out() -> void:
	var fighter := put_battlefield(0, "Dream Fighter")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [fighter.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: fighter.id}))
	resolve_stack()
	assert_true(fighter.phased_out, "this creature phases out")
	assert_true(bear.phased_out, "and that creature")
	assert_false(g.combat.attackers.has(fighter.id), "removed from combat (702.26b)")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(fighter.damage, 0)
	assert_eq(g.players[1].life, 20)
	advance_to_next_turn()   # turn 2: P1's untap
	assert_false(bear.phased_out, "the blocker comes back on its controller's step")
	assert_true(fighter.phased_out)
	advance_to_next_turn()
	assert_false(fighter.phased_out)


func test_dream_fighter_blocks_and_both_phase_out() -> void:
	var fighter := put_battlefield(0, "Dream Fighter")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()   # P1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {fighter.id: giant.id}))
	resolve_stack()
	assert_true(fighter.phased_out and giant.phased_out)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "the attacker was removed from combat")
	assert_eq(fighter.zone, Mtg.Zone.BATTLEFIELD, "nothing died")


# ------------------------------------------------------------- Mist Dragon --

func test_mist_dragon_gains_and_loses_flying_in_timestamp_order() -> void:
	var dragon := put_battlefield(0, "Mist Dragon")
	assert_false(dragon.has_keyword(Mtg.Keyword.FLYING))
	activate(dragon, 0)
	assert_true(dragon.has_keyword(Mtg.Keyword.FLYING), "{0}: gains flying")
	activate(dragon, 1)
	assert_false(dragon.has_keyword(Mtg.Keyword.FLYING), "{0}: loses flying")
	activate(dragon, 0)
	assert_true(dragon.has_keyword(Mtg.Keyword.FLYING), "the later effect wins (CR 613.7)")
	advance_to_next_turn()
	assert_true(dragon.has_keyword(Mtg.Keyword.FLYING), "lasts indefinitely")


func test_mist_dragon_loses_flying_granted_earlier_by_another_effect() -> void:
	var dragon := put_battlefield(0, "Mist Dragon")
	cast("Sapphire Charm", [TargetRef.card(dragon)], 1)
	assert_true(dragon.has_keyword(Mtg.Keyword.FLYING))
	activate(dragon, 1)
	assert_false(dragon.has_keyword(Mtg.Keyword.FLYING), "the loss is later than the charm")


func test_mist_dragon_phases_out_for_five_mana() -> void:
	var dragon := put_battlefield(0, "Mist Dragon")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	activate(dragon, 2)
	assert_true(dragon.phased_out)
	advance_to_next_turn()
	assert_true(dragon.phased_out, "out through the opponent's turn")
	advance_to_next_turn()
	assert_false(dragon.phased_out, "back before P0 untaps")


# ---------------------------------------------------------- Reality Ripple --

func test_reality_ripple_phases_an_artifact_creature_or_land() -> void:
	var forest := put_battlefield(1, "Forest")
	cast("Reality Ripple", [TargetRef.card(forest)])
	assert_true(forest.phased_out)
	advance_to_next_turn()   # P1's untap step brings it back
	assert_false(forest.phased_out)


func test_reality_ripple_refuses_an_enchantment_and_a_phased_out_permanent() -> void:
	var curse_host := put_battlefield(1, "Sol Ring")
	var aura := cast("Teferi's Curse", [TargetRef.card(curse_host)])
	var ripple := give_hand(0, "Reality Ripple")
	fund(0, ripple)
	assert_refused(g.cast_spell(0, ripple, [TargetRef.card(aura)]), "")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_true(g.phase_out(bear))
	assert_refused(g.cast_spell(0, ripple, [TargetRef.card(bear)]), "")


func test_reality_ripple_removes_an_attacker_from_combat() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()   # P1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	resolve_stack()
	var ripple := give_hand(0, "Reality Ripple")
	fund(0, ripple)
	assert_ok(g.pass_priority(1))   # P1 passes: P0 may respond in the step
	assert_ok(g.cast_spell(0, ripple, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(giant.phased_out)
	assert_false(g.combat.attackers.has(giant.id))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)


# ---------------------------------------------------------- Sapphire Charm --

func test_sapphire_charm_draws_at_the_next_turns_upkeep() -> void:
	cast("Sapphire Charm", [TargetRef.player(1)], 0)
	assert_eq(g.players[1].hand.size(), 0, "not yet")
	advance_to_step(Mtg.Step.END)
	assert_eq(g.players[1].hand.size(), 0, "not this turn")
	advance_to_next_turn()
	assert_eq(g.players[1].hand.size(), 2, "the upkeep draw plus the draw step")


func test_sapphire_charm_on_yourself_draws_in_the_opponents_upkeep() -> void:
	var before := g.players[0].hand.size()
	cast("Sapphire Charm", [TargetRef.player(0)], 0)
	advance_to_step(Mtg.Step.END)
	advance_to_next_turn()   # turn 2 is P1's: "the next turn's upkeep"
	assert_eq(g.players[0].hand.size(), before + 1)


func test_sapphire_charm_flying_until_end_of_turn() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Sapphire Charm", [TargetRef.card(bear)], 1)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING))


func test_sapphire_charm_phases_out_only_an_opponents_creature() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var charm := give_hand(0, "Sapphire Charm")
	fund(0, charm)
	assert_refused(g.cast_spell(0, charm, [TargetRef.card(mine)], 0, 2), "")
	assert_ok(g.cast_spell(0, charm, [TargetRef.card(theirs)], 0, 2))
	resolve_stack()
	assert_true(theirs.phased_out)
	assert_false(mine.phased_out)


# ----------------------------------------------------------------- Taniwha --

func test_taniwha_phases_its_controllers_lands_out_each_upkeep_it_is_in() -> void:
	var taniwha := put_battlefield(0, "Taniwha")
	assert_true(taniwha.has_keyword(Mtg.Keyword.TRAMPLE) and taniwha.has_keyword(Mtg.Keyword.PHASING))
	var lands: Array[CardInstance] = []
	for i in 3: lands.append(put_battlefield(0, "Island"))
	var theirs := put_battlefield(1, "Forest")
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: Taniwha phases out — no upkeep trigger
	assert_true(taniwha.phased_out)
	for land in lands: assert_false(land.phased_out, "it didn't exist at the upkeep")
	advance_to_next_turn()
	advance_to_next_turn()   # turn 5: Taniwha in; its upkeep trigger takes the lands
	assert_false(taniwha.phased_out)
	for land in lands: assert_true(land.phased_out, "all lands you control phase out")
	assert_false(theirs.phased_out, "not the opponent's")
	advance_to_next_turn()
	advance_to_next_turn()   # turn 7: Taniwha out, the lands back
	assert_true(taniwha.phased_out)
	for land in lands:
		assert_false(land.phased_out)
		assert_false(land.tapped)


# ------------------------------------------------------------ Teferi's Imp --

func test_teferis_imp_discards_as_it_phases_out_and_draws_as_it_phases_in() -> void:
	var imp := put_battlefield(0, "Teferi's Imp")
	var kept := give_hand(0, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: out at the untap step, discard at the upkeep
	assert_true(imp.phased_out)
	assert_eq(kept.zone, Mtg.Zone.GRAVEYARD, "whenever it phases out, discard a card")
	advance_to_next_turn()
	var before := g.players[0].hand.size()
	advance_to_next_turn()   # turn 5: in at the untap step, draw at the upkeep
	assert_false(imp.phased_out)
	assert_eq(g.players[0].hand.size(), before + 2, "the Imp's card and the draw step's")


func test_teferis_imp_phasing_out_with_an_empty_hand_is_harmless() -> void:
	var imp := put_battlefield(0, "Teferi's Imp")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(imp.phased_out)
	assert_eq(g.players[0].graveyard.size(), 0)


# ---------------------------------------------------------- Vaporous Djinn --

func test_vaporous_djinn_phases_out_when_its_upkeep_goes_unpaid() -> void:
	var djinn := put_battlefield(0, "Vaporous Djinn")
	assert_true(djinn.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: no Islands, nothing to pay with
	assert_true(djinn.phased_out)
	advance_to_next_turn()
	advance_to_next_turn()   # turn 5: back before the untap — and out again
	assert_true(djinn.phased_out, "phased in at the untap step, out at the upkeep")


func test_vaporous_djinn_stays_when_its_controller_pays() -> void:
	var djinn := put_battlefield(0, "Vaporous Djinn")
	var islands := [put_battlefield(0, "Island"), put_battlefield(0, "Island")]
	advance_to_next_turn()
	p0.answers = [true]
	advance_to_next_turn()
	assert_false(djinn.phased_out, "paid {U}{U}")
	for island in islands: assert_true(island.tapped)


func test_vaporous_djinn_declined_payment_phases_out() -> void:
	var djinn := put_battlefield(0, "Vaporous Djinn")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	advance_to_next_turn()
	p0.answers = [false]
	advance_to_next_turn()
	assert_true(djinn.phased_out)


# ------------------------------------------------------------ Warping Wurm --

func test_warping_wurm_grows_each_time_it_phases_in() -> void:
	var wurm := put_battlefield(0, "Warping Wurm")
	assert_true(wurm.has_keyword(Mtg.Keyword.PHASING))
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: phasing takes it out; no upkeep trigger
	assert_true(wurm.phased_out)
	assert_eq(int(wurm.counters.get("+1/+1", 0)), 0)
	advance_to_next_turn()
	# Turn 5: in at the untap step; its phase-in trigger and its upkeep
	# trigger go on together and its controller puts the counter first
	# (CR 503.1a, 603.3b).
	p0.options = ["+1/+1 counter"]
	advance_to_next_turn()   # turn 5: in (+1/+1 counter), unpaid upkeep: out
	assert_true(p0.asked.has(MtgGame.TRIGGER_ORDER_PROMPT), "the controller was asked")
	assert_eq(int(wurm.counters.get("+1/+1", 0)), 1, "whenever it phases in")
	assert_true(wurm.phased_out, "phases out unless you pay {2}{G}{U}")
	advance_to_next_turn()
	advance_to_next_turn()   # turn 7: the one-shot return phases it in again
	assert_eq(int(wurm.counters.get("+1/+1", 0)), 2)


func test_warping_wurm_paid_upkeep_keeps_it_in() -> void:
	var wurm := put_battlefield(0, "Warping Wurm")
	for name in ["Island", "Forest", "Forest", "Forest"]: put_battlefield(0, name)
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3: out (phasing)
	advance_to_next_turn()
	p0.answers = [true]
	advance_to_next_turn()   # turn 5
	assert_false(wurm.phased_out)
	assert_eq([wurm.cur_power, wurm.cur_toughness], [2, 2])


# --------------------------------------------------------- Frenetic Efreet --

func test_frenetic_efreet_phases_out_on_a_win_and_is_sacrificed_on_a_loss() -> void:
	var outcomes := {"won": 0, "lost": 0}
	for n in 24:
		var efreet := put_battlefield(0, "Frenetic Efreet")
		assert_true(efreet.has_keyword(Mtg.Keyword.FLYING))
		activate(efreet, 0)
		if efreet.phased_out:
			assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD)
			outcomes["won"] += 1
		else:
			assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD, "a lost flip sacrifices it")
			outcomes["lost"] += 1
	assert_gt(int(outcomes["won"]), 0, "some flips are won")
	assert_gt(int(outcomes["lost"]), 0, "some flips are lost")


# --------------------------------------------------------- Spatial Binding --

func test_spatial_binding_holds_a_phaser_in_until_its_controllers_next_upkeep() -> void:
	var binding := put_battlefield(0, "Spatial Binding")
	var drake := put_battlefield(1, "Teferi's Drake")
	activate(binding, 0, [TargetRef.card(drake)])
	assert_eq(g.players[0].life, 19, "Pay 1 life")
	assert_true(drake.cur_cant_phase_out)
	advance_to_next_turn()   # turn 2: P1's untap step — the ban holds it in
	assert_false(drake.phased_out)
	advance_to_next_turn()   # turn 3: P0's upkeep ends the ban
	assert_false(drake.cur_cant_phase_out)
	advance_to_next_turn()   # turn 4: P1's untap step
	assert_true(drake.phased_out)


func test_spatial_binding_stops_a_one_shot_phase_out_too() -> void:
	var binding := put_battlefield(0, "Spatial Binding")
	var giant := put_battlefield(1, "Hill Giant")
	activate(binding, 0, [TargetRef.card(giant)])
	cast("Reality Ripple", [TargetRef.card(giant)])
	assert_false(giant.phased_out, "can't phase out")


# ----------------------------------------------------------- Crystal Golem --

func test_crystal_golem_phases_out_at_its_controllers_end_step() -> void:
	var golem := put_battlefield(0, "Crystal Golem")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_true(golem.phased_out, "at the beginning of your end step")
	advance_to_next_turn()   # turn 2: P1's turn — no blocker there
	assert_true(golem.phased_out)
	assert_false(g.players[0].creatures().has(golem), "not counted among P0's creatures")
	advance_to_next_turn()   # turn 3
	assert_false(golem.phased_out)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_true(golem.phased_out, "and again")
