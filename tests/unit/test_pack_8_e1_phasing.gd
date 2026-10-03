extends GameTest
## Pack 8 engine package E1 — PHASING as the real keyword (CR 702.26) and
## the batch/event/ban vocabulary the Mirage block's 32 phasing cards are
## built from: `N_phasing`, `N_phase_batch`, `N_phase_events`,
## `N_cant_phase_out`.
##
## Every card here is SYNTHETIC (three lines, built in the test) so each
## test pins one rule of the mechanism, not a printed card:
## - the untap-step turn-based action (CR 502.1 / 702.26a): phased-in
##   permanents with phasing phase out and the ones that phased out under
##   the active player's control phase in, simultaneously, before anything
##   untaps;
## - a one-shot "phases out" comes back at its controller's next untap
##   step; an "until" hold (Oubliette, CR 610.4a) does not;
## - Auras ride along indirectly and come back attached (702.26g-i);
## - a phased-out permanent is treated as though it doesn't exist (702.26b):
##   nothing affects it, it leaves combat, "for as long as" effects that
##   track it end (702.26f), a resolved effect does not include it
##   (702.26e), but it never changes zones or control (702.26d) — tokens,
##   counters, timestamp and summoning-sickness clock all survive;
## - the PHASED_OUT / PHASED_IN events, the "can't phase out" ban, and the
##   simultaneous batch (Time and Tide, Taniwha, Teferi's Realm, Equipoise).

var heard: Array = []


func before_each() -> void:
	super.before_each()
	heard = []


# ------------------------------------------------------------- the cards --

static func _ids(list: Array) -> Array:
	return list.map(func(inst: CardInstance) -> int: return inst.id)


func _creature(card_name := "Test Bear", power := 2, toughness := 2,
		keywords: Array = []) -> CardData:
	var c := CardData.new(card_name, "{1}{U}", Mtg.CardType.CREATURE).pt(power, toughness)
	if not keywords.is_empty():
		c.with_keywords(keywords)
	return c


func _bear(pid: int, card_name := "Test Bear") -> CardInstance:
	return put_synthetic(pid, _creature(card_name))


func _phaser(pid: int, card_name := "Test Drake") -> CardInstance:
	return put_synthetic(pid, _creature(card_name, 2, 2, [Mtg.Keyword.PHASING]))


## An Aura on [param host], controlled by [param pid] (the host's
## controller by default), carrying [param statics].
func _aura_on(host: CardInstance, pid := -1, statics: Array = []) -> CardInstance:
	var c := CardData.new("Test Aura", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature())
	for s in statics:
		c.static_ability(s)
	var seat := pid if pid >= 0 else host.controller_id
	var aura := CardInstance.new(c, g._next_instance_id, seat)
	g._next_instance_id += 1
	g._instances[aura.id] = aura
	g._put_on_battlefield(aura, seat, host)
	return aura


static func _grant_phasing(game: MtgGame, source: CardInstance) -> void:
	var host := game.find_instance(source.attached_to)
	if game.is_present(host) and not host.cur_keywords.has(Mtg.Keyword.PHASING):
		host.cur_keywords.append(Mtg.Keyword.PHASING)


## A plain enchantment — the holder of an "until" (Oubliette's shape).
func _holder(pid: int) -> CardInstance:
	return put_synthetic(pid, CardData.new("Test Holder", "{1}{B}", Mtg.CardType.ENCHANTMENT))


## A creature that records its own phase events as they resolve.
func _listener(pid: int, keywords: Array = []) -> CardInstance:
	var c := _creature("Test Imp", 1, 1, keywords)
	for type in [Mtg.EventType.PHASED_OUT, Mtg.EventType.PHASED_IN]:
		c.triggered(TriggeredAbility.new(type,
			func(_game: MtgGame, source: CardInstance, event: GameEvent) -> void:
				heard.append([event.type, source.id, bool(event.data.get("indirect", false)),
					int(event.data.get("controller", -1))]),
			"Whenever this phases out or in, note it.",
			func(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
				return event.data.get("instance") == source))
	return put_synthetic(pid, c)


# ------------------------------------------------- the untap-step action --

func test_phasing_phases_out_before_its_controller_untaps_and_back_in_the_next() -> void:
	var drake := _phaser(0)
	g.tap_permanent(drake)
	advance_to_next_turn()   # turn 2, P1: not P0's untap step
	assert_false(drake.phased_out, "the opponent's untap step leaves it alone")
	advance_to_next_turn()   # turn 3, P0
	assert_true(drake.phased_out, "phases out before P0 untaps (CR 502.1)")
	assert_false(g.players[0].battlefield.has(drake), "off the battlefield arrays")
	assert_true(g.players[0].phased_out.has(drake), "parked on its controller")
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD, "phasing is not a zone change (702.26d)")
	assert_true(drake.tapped, "it phased out BEFORE the untap, so it stayed tapped")
	advance_to_next_turn()   # turn 4, P1
	assert_true(drake.phased_out, "nothing brings it back on the opponent's step")
	advance_to_next_turn()   # turn 5, P0
	assert_false(drake.phased_out, "back in on P0's next untap step")
	assert_true(g.players[0].battlefield.has(drake))
	assert_false(drake.tapped,
		"it phased in BEFORE the untap, so it untapped with the rest (502.3)")


func test_a_permanent_that_phases_in_is_not_phased_straight_back_out() -> void:
	# The untap step's phasing is ONE simultaneous event: a phasing
	# permanent that comes back in it has already phased this step.
	var drake := _phaser(0)
	assert_true(g.phase_out(drake), "a one-shot phase-out during P0's turn")
	advance_to_next_turn()   # P1
	assert_true(drake.phased_out)
	advance_to_next_turn()   # P0: it phases in — and stays in, with phasing
	assert_false(drake.phased_out, "phased in, not in-and-out again")
	advance_to_next_turn()   # P1
	advance_to_next_turn()   # P0: now it is a phased-in permanent with phasing
	assert_true(drake.phased_out)


func test_a_one_shot_phase_out_returns_at_its_controllers_next_untap_step() -> void:
	var theirs := _bear(1)
	var mine := _bear(0, "My Bear")
	assert_true(g.phase_out(theirs), "Reality Ripple's shape")
	assert_true(g.phase_out(mine))
	assert_false(g.phase_out(theirs), "already phased out: nothing to do")
	advance_to_next_turn()   # turn 2, P1
	assert_false(theirs.phased_out, "P1's untap step brings P1's back")
	assert_true(mine.phased_out, "P0's waits for P0's untap step")
	advance_to_next_turn()   # turn 3, P0
	assert_false(mine.phased_out)


func test_a_stolen_permanent_comes_back_on_the_thiefs_step_and_then_goes_home() -> void:
	# CR 502.1: it phases in during the untap step of the player who
	# controlled it as it phased out; the until-end-of-turn control effect
	# expired while it was gone (702.26f), so it is the owner's again.
	var bear := _bear(1)
	g.gain_control_until_eot(bear, 0)
	assert_eq(bear.controller_id, 0)
	assert_true(g.phase_out(bear))
	assert_true(g.players[0].phased_out.has(bear), "phased out under the thief")
	advance_to_next_turn()   # P1's untap step: not the thief's
	assert_true(bear.phased_out)
	advance_to_next_turn()   # P0's untap step
	assert_false(bear.phased_out)
	assert_eq(bear.controller_id, 1, "the borrow ended while it was gone")
	assert_true(g.players[1].battlefield.has(bear))


# ----------------------------------------- it never changed zones (702.26d) --

func test_tokens_counters_timestamp_and_order_survive_phasing() -> void:
	var first := _bear(0, "First Bear")
	var token: CardInstance = g.create_token(0, _creature("Test Token", 1, 1))[0]
	var last := _bear(0, "Last Bear")
	g.add_counters(first, "+1/+1", 2)
	var stamp := first.layer_timestamp
	assert_true(g.phase_out(first))
	assert_true(g.phase_out(token))
	assert_true(g._instances.has(token.id), "a phased-out token still exists (702.26d)")
	assert_eq(int(first.counters.get("+1/+1", 0)), 2, "counters stay on it")
	assert_true(g.phase_in(first))
	assert_true(g.phase_in(token))
	assert_eq(first.layer_timestamp, stamp, "same object, same timestamp")
	assert_eq(first.cur_power, 4)
	assert_eq(_ids(g.all_battlefield()), [first.id, token.id, last.id],
		"back in its own place in timestamp order, not at the end")
	assert_eq(g.players[0].battlefield.find(first), 0)


func test_phasing_is_no_zone_change_so_nothing_enters_or_leaves() -> void:
	var c := CardData.new("Test Watcher", "{1}", Mtg.CardType.ARTIFACT)
	for type in [Mtg.EventType.ENTERS_BATTLEFIELD, Mtg.EventType.LEAVES_BATTLEFIELD]:
		c.triggered(TriggeredAbility.new(type,
			func(_game: MtgGame, _s: CardInstance, _e: GameEvent) -> void: pass,
			"Whenever anything enters or leaves, note it."))
	put_synthetic(0, c)
	resolve_stack()
	var bear := _bear(1)
	resolve_stack()
	assert_true(g.phase_out(bear))
	assert_true(g.phase_in(bear))
	assert_eq(g.stack.size(), 0, "no enters/leaves trigger (702.26d)")


func test_a_creature_that_phased_in_keeps_its_summoning_sickness_clock() -> void:
	# P0's creature with phasing, still sick on turn 1, phases out at P0's
	# untap step on turn 3 BEFORE the sweep. Brought back mid-turn (Time
	# and Tide) it has been under P0's control since the turn began
	# (702.26d), so it may attack.
	var drake := _phaser(0)
	drake.summoning_sick = true
	advance_to_next_turn()
	advance_to_next_turn()   # turn 3, P0: it phased out
	assert_true(drake.phased_out)
	g.phase_simultaneously([], [drake])
	assert_false(drake.summoning_sick, "under P0's control since the turn began")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [drake.id]))


# ------------------------------------------------- Auras ride indirectly --

func test_an_aura_phases_out_indirectly_and_comes_back_attached() -> void:
	var host := _bear(0)
	var aura := _aura_on(host)
	assert_true(g.phase_out(host))
	assert_true(aura.phased_out, "attached Auras phase out with it (702.26g)")
	assert_true(aura.phased_indirectly)
	assert_false(host.phased_indirectly, "the host phased out directly")
	assert_false(g.phase_in(aura), "an indirect rider never phases in alone")
	advance_to_next_turn()
	assert_true(aura.phased_out, "nor at its controller's untap step")
	advance_to_next_turn()   # P0's untap step: host and rider together
	assert_false(host.phased_out)
	assert_false(aura.phased_out)
	assert_false(aura.phased_indirectly)
	assert_eq(aura.attached_to, host.id, "back attached (702.26i)")
	assert_true(host.attachments.has(aura.id))


func test_an_opponents_aura_rides_with_my_creature() -> void:
	var host := _bear(0)
	var aura := _aura_on(host, 1)
	assert_true(g.phase_out(host))
	assert_true(aura.phased_out)
	advance_to_next_turn()   # P1's untap step: the aura is P1's, but indirect
	assert_true(aura.phased_out, "an indirect rider waits for its host")
	advance_to_next_turn()   # P0's untap step brings the host and the rider
	assert_false(aura.phased_out)
	assert_true(g.players[1].battlefield.has(aura))


func test_granted_phasing_takes_the_aura_along_and_back() -> void:
	# Teferi's Curse / Cloak of Invisibility: "enchanted creature has
	# phasing" is a layer-6 grant; the host phases out at its controller's
	# untap step with the Aura riding, and both come back together.
	var host := _bear(0)
	var curse := _aura_on(host, 0, [StaticAbility.new(_grant_phasing,
		"Enchanted creature has phasing.").changing_abilities()])
	assert_true(host.has_keyword(Mtg.Keyword.PHASING), "granted")
	advance_to_next_turn()
	advance_to_next_turn()   # P0's untap step
	assert_true(host.phased_out)
	assert_true(curse.phased_out and curse.phased_indirectly)
	advance_to_next_turn()
	advance_to_next_turn()   # P0's next
	assert_false(host.phased_out)
	assert_false(curse.phased_out)
	assert_true(host.has_keyword(Mtg.Keyword.PHASING), "and still has it")


# --------------------------------------------------- an "until" hold (610.4a) --

func test_a_held_permanent_stays_out_until_its_holder_releases_it() -> void:
	var holder := _holder(0)
	var bear := _bear(1)
	assert_true(g.phase_out(bear, holder), "Oubliette's 'until this leaves'")
	assert_eq(bear.phase_hold, holder.id)
	advance_to_next_turn()   # P1's untap step
	assert_true(bear.phased_out, "a held permanent ignores the untap step")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(bear.phased_out)
	assert_false(g.release_phase_hold(bear, _holder(0)), "another holder: not its hold")
	assert_true(g.release_phase_hold(bear, holder, true))
	assert_false(bear.phased_out)
	assert_true(bear.tapped, "Oubliette's 'tap that creature as it phases in'")
	assert_eq(bear.phase_hold, -1)


func test_a_hold_broken_by_another_effect_is_not_released_again() -> void:
	# CR 610.4a: once it phased in by another effect (Time and Tide), the
	# holder's release does nothing — even if it has phased out since.
	var holder := _holder(0)
	var bear := _bear(1)
	assert_true(g.phase_out(bear, holder))
	g.phase_simultaneously([], [bear])
	assert_false(bear.phased_out, "Time and Tide may phase a held permanent in")
	assert_true(g.phase_out(bear))
	assert_false(g.release_phase_hold(bear, holder), "the hold is gone")
	assert_true(bear.phased_out, "it waits for its own untap step instead")


func test_the_oubliette_still_holds_and_releases() -> void:
	var victim := put_battlefield(1, "Serra Angel")
	var oubliette := put_battlefield(0, "Oubliette")
	resolve_stack()
	assert_true(victim.phased_out)
	advance_to_next_turn()   # P1's untap step: held
	assert_true(victim.phased_out, "the Oubliette's prisoner is exempt (610.4a)")
	g.destroy(oubliette)
	assert_false(victim.phased_out, "released the instant it leaves")
	assert_true(victim.tapped)


# --------------------------------------------------------- "can't phase out" --

func test_a_permanent_that_cant_phase_out_stays_through_the_untap_step() -> void:
	var drake := _phaser(0)
	g.forbid_phasing_out(drake, 0)   # Ertai's Familiar: until your next upkeep
	assert_true(drake.cur_cant_phase_out)
	assert_false(g.phase_out(drake), "a one-shot is refused too")
	assert_false(drake.phased_out)
	advance_to_next_turn()
	advance_to_next_turn()   # P0's untap step comes BEFORE P0's upkeep
	assert_false(drake.phased_out, "the ban covers this untap step")
	assert_false(drake.cur_cant_phase_out, "and ended as P0's upkeep began")
	assert_true(g.phase_out(drake), "it can phase out again")


func test_the_ban_outlives_its_source_but_not_the_permanent() -> void:
	var binding := _holder(1)
	var bear := _bear(0)
	g.forbid_phasing_out(bear, 1, binding)   # Spatial Binding's controller: P1
	g.destroy(binding)
	assert_true(bear.cur_cant_phase_out, "a resolved effect, not a static of the source")
	g.return_to_hand(bear)
	assert_false(bear.cur_cant_phase_out, "a new object (CR 400.7)")


func test_an_aura_that_cant_phase_out_is_left_behind_and_falls_off() -> void:
	var host := _bear(0)
	var aura := _aura_on(host)
	g.forbid_phasing_out(aura, 0)
	assert_true(g.phase_out(host))
	assert_false(aura.phased_out, "it can't ride out")
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD,
		"attached to something that doesn't exist: CR 704.5m")
	assert_false(host.attachments.has(aura.id))


# ------------------------------------------------------------------ events --

func test_the_phasing_permanent_hears_its_own_phase_out_and_phase_in() -> void:
	var imp := _listener(0, [Mtg.Keyword.PHASING])
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)   # P0's untap step: it phased out
	assert_true(imp.phased_out)
	# CR 502.4: raised in the untap step, the trigger waited for the
	# upkeep's priority — and it was heard although its source is gone.
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(heard, [[Mtg.EventType.PHASED_OUT, imp.id, false, 0]])
	advance_to_next_turn()
	advance_to_next_turn()   # P0's next untap step: it phases in
	resolve_stack()
	assert_eq(heard.back(), [Mtg.EventType.PHASED_IN, imp.id, false, 0])


func test_an_indirect_rider_reports_indirect() -> void:
	var host := _bear(0)
	var c := CardData.new("Test Listening Aura", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature())
	c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_OUT,
		func(_game: MtgGame, source: CardInstance, event: GameEvent) -> void:
			heard.append([source.id, bool(event.data.get("indirect", false))]),
		"Whenever this phases out, note it.",
		func(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
			return event.data.get("instance") == source))
	var aura := CardInstance.new(c, g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[aura.id] = aura
	g._put_on_battlefield(aura, 0, host)
	assert_true(g.phase_out(host))
	resolve_stack()
	assert_eq(heard, [[aura.id, true]])


func test_events_fire_on_the_finished_board() -> void:
	# The batch is ONE event (CR 702.26a): a phase-in trigger already sees
	# the permanents that phased out beside it gone.
	var counted: Array = []
	var c := _creature("Test Counter")
	c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_IN,
		func(_game: MtgGame, _s: CardInstance, _e: GameEvent) -> void: pass,
		"Whenever this phases in, count.",
		func(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
			if event.data.get("instance") != source:
				return false
			counted.append(game.players[0].battlefield.size())
			return true))
	var counter := put_synthetic(0, c)
	var leaving := _phaser(0)
	assert_true(g.phase_out(counter))
	var done := g.phase_simultaneously([leaving], [counter])
	assert_eq(_ids(done["out"]), [leaving.id])
	assert_eq(_ids(done["in"]), [counter.id])
	assert_eq(counted, [1], "only the counter itself: the Drake is already gone")


# ----------------------------------------------------- the batch (Time and Tide) --

func test_time_and_tide_shape_swaps_in_and_out_at_once() -> void:
	var gone := _bear(1)
	assert_true(g.phase_out(gone))
	var phasers := [_phaser(0), _phaser(1, "Their Drake")]
	var outs: Array = []
	for inst in g.all_battlefield():
		if inst.is_creature() and inst.has_keyword(Mtg.Keyword.PHASING):
			outs.append(inst)
	var ins: Array = []
	for inst in g.phased_out_permanents():
		if inst.is_creature():
			ins.append(inst)
	var done := g.phase_simultaneously(outs, ins)
	assert_false(gone.phased_out, "every phased-out creature phased in")
	for drake in phasers:
		assert_true(drake.phased_out, "and every creature with phasing out")
	assert_eq(done["out"].size(), 2)
	assert_eq(done["in"].size(), 1)


func test_the_batch_filters_what_cannot_phase() -> void:
	var drake := _phaser(0)
	var stuck := _bear(0, "Stuck Bear")
	g.forbid_phasing_out(stuck, 0)
	var host := _bear(0, "Host Bear")
	var aura := _aura_on(host)
	# The Aura named directly AND riding with its host goes indirectly
	# (702.26h); a phased-in permanent named as an IN is ignored.
	var done := g.phase_simultaneously([drake, stuck, host, aura, null], [drake])
	assert_true(drake.phased_out)
	assert_false(stuck.phased_out, "can't phase out")
	assert_true(aura.phased_out and aura.phased_indirectly, "702.26h: indirectly")
	assert_eq(done["out"].size(), 3)
	assert_eq(done["in"].size(), 0)


func test_taniwha_shape_all_lands_phase_out_together() -> void:
	var lands: Array = []
	for i in 3:
		lands.append(put_battlefield(0, "Island"))
	var done := g.phase_simultaneously(lands, [])
	assert_eq(done["out"].size(), 3)
	for land in lands:
		assert_true(land.phased_out)
	advance_to_next_turn()
	advance_to_next_turn()
	for land in lands:
		assert_false(land.phased_out, "back before P0 untaps")


# --------------------------------------- treated as though it doesn't exist --

func test_nothing_affects_a_phased_out_permanent() -> void:
	var bear := _bear(1)
	assert_true(g.phase_out(bear))
	g.destroy(bear)
	g.sacrifice_permanent(bear)
	g.return_to_hand(bear)
	g.exile_permanent(bear)
	g.tap_permanent(bear)
	g.add_counters(bear, "+1/+1", 1)
	g.change_control(bear, 0)
	g.gain_control_until_eot(bear, 0)
	g.grant_keyword_permanently(bear, Mtg.Keyword.FLYING)
	var bolt := _bear(0, "Pinger")
	g.deal_damage(bolt, TargetRef.card(bear), 1)
	assert_true(bear.phased_out, "still phased out")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.players[1].phased_out.has(bear), "and still parked, uncorrupted")
	assert_false(g.players[0].battlefield.has(bear))
	assert_false(bear.tapped)
	assert_eq(bear.damage, 0)
	assert_true(bear.counters.is_empty())
	assert_eq(bear.controller_id, 1)
	assert_true(bear.added_keywords.is_empty())
	assert_true(g.players[1].graveyard.is_empty())
	assert_true(g.players[1].hand.is_empty())
	assert_true(g.phase_in(bear))
	assert_eq(bear.controller_id, 1,
		"a control change made while it was gone never included it (702.26e)")
	assert_true(g.players[1].battlefield.has(bear))


func test_a_doomed_creature_that_phased_out_survives_the_doom() -> void:
	var bear := _bear(0)
	g.doom_at_next_end_step(bear)
	assert_true(g.phase_out(bear))
	advance_to_next_turn()
	assert_true(bear.phased_out, "it did not exist at the end step")
	assert_true(g.players[0].graveyard.is_empty())
	advance_to_next_turn()
	assert_false(bear.phased_out)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_a_resolved_pump_does_not_include_a_phased_out_creature() -> void:
	# CR 702.26e: the ability resolves while its creature is phased out, so
	# its effect has nothing to affect — and still nothing once it's back.
	var c := _creature("Test Breather")
	c.activated(ActivatedAbility.new("{0}", false, [PumpEffect.new(3, 3).self_buff()],
		"{0}: This creature gets +3/+3 until end of turn."))
	var breather := put_synthetic(0, c)
	assert_ok(g.activate_ability(0, breather, 0))
	assert_true(g.phase_out(breather))
	resolve_stack()
	assert_true(g.phase_in(breather))
	assert_eq(breather.cur_power, 2)


func test_a_pump_from_before_still_applies_after_phasing_back_in() -> void:
	# The other half of 702.26e/f: an effect that already included the
	# creature keeps applying until it expires (the same object came back).
	var bear := _bear(0)
	g.continuous.add_until_eot_pump(bear.id, 3, 3, [])
	g.recalculate()
	assert_true(g.phase_out(bear))
	assert_true(g.phase_in(bear))
	assert_eq(bear.cur_power, 5)


func test_a_leash_ends_when_its_source_phases_out() -> void:
	# CR 702.26f: "for as long as" effects that track the permanent end
	# when it phases out — and do not come back with it.
	var leash := _bear(0, "Leash")
	var victim := _bear(1, "Victim")
	g.gain_control_leashed(victim, leash)
	assert_eq(victim.controller_id, 0)
	assert_true(g.phase_out(leash))
	assert_eq(victim.controller_id, 1, "the leash can no longer see its source")
	assert_true(g.phase_in(leash))
	assert_eq(victim.controller_id, 1, "a broken duration never revives")


func test_a_phased_out_attacker_is_removed_from_combat() -> void:
	var bear := _bear(0)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_true(g.phase_out(bear))
	assert_false(g.combat.attackers.has(bear.id), "removed from combat (702.26b)")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "it dealt no damage")


func test_a_blocked_attacker_whose_blocker_phases_out_stays_blocked() -> void:
	var attacker := _bear(0, "Attacker")
	var blocker := _bear(1, "Blocker")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: attacker.id}))
	assert_true(g.phase_out(blocker))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "blocked, no trample: no damage (CR 509.1h)")
	assert_eq(attacker.damage, 0, "and nothing hit it back")


func test_damage_wears_off_a_phased_out_creature_at_cleanup() -> void:
	# CR 514.2: "all damage marked on permanents (including phased-out
	# permanents) is removed".
	var bear := _bear(0)
	g.deal_damage(_bear(1, "Pinger"), TargetRef.card(bear), 1)
	assert_eq(bear.damage, 1)
	assert_true(g.phase_out(bear))
	advance_to_next_turn()   # turn 1's cleanup ran while it was out
	assert_true(bear.phased_out)
	assert_eq(bear.damage, 0)


func test_counts_leave_a_phased_out_permanent_out() -> void:
	# 702.26b's own example: "Draw a card for each creature you control" —
	# a phased-out creature is not counted.
	var bear := _bear(0)
	_bear(0, "Other")
	assert_true(g.phase_out(bear))
	var creatures := 0
	for inst in g.players[0].battlefield:
		if inst.is_creature():
			creatures += 1
	assert_eq(creatures, 1)
	assert_false(g.is_present(bear))
	assert_true(g.is_present(g.players[0].battlefield[0]))
	assert_false(g.is_present(null))


# ------------------------------------------------- undo and both rulesets --

func test_the_phasing_batch_round_trips_under_the_journal() -> void:
	var drake := _phaser(0)
	var gone := _bear(1)
	var host := _bear(0, "Host")
	var aura := _aura_on(host)
	assert_true(g.phase_out(gone))
	var mark := g.make_mark()
	g.phase_simultaneously([drake, host], [gone])
	assert_true(drake.phased_out and aura.phased_out and not gone.phased_out)
	g.unmake_to(mark)
	g.end_search()
	assert_false(drake.phased_out)
	assert_false(aura.phased_out)
	assert_false(aura.phased_indirectly)
	assert_true(gone.phased_out)
	assert_true(g.players[0].battlefield.has(drake))
	assert_true(g.players[1].phased_out.has(gone))
	assert_true(g.all_battlefield().has(host))


func test_the_untap_step_phasing_round_trips_under_the_journal() -> void:
	var drake := _phaser(0)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.END)
	var mark := g.make_mark()
	advance_to_next_turn()   # P0's untap step phases it out
	assert_true(drake.phased_out)
	g.unmake_to(mark)
	g.end_search()
	assert_false(drake.phased_out)
	assert_true(g.all_battlefield().has(drake))


func test_untap_step_phasing_under_the_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	var drake := _phaser(0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(drake.phased_out)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(drake.phased_out)


# ------------------------------------------------------------- the AI seats --

## Every phased-out permanent parked exactly once, off every battlefield list.
func _parking_problems() -> Array[String]:
	var out: Array[String] = []
	for p in g.players:
		for inst in p.battlefield:
			if inst.phased_out:
				out.append("%s is on a battlefield list while phased out" % inst)
		for inst in p.phased_out:
			if not inst.phased_out or inst.zone != Mtg.Zone.BATTLEFIELD:
				out.append("%s is parked but not phased out" % inst)
			if g.all_battlefield().has(inst) or g.players[0].battlefield.has(inst) \
					or g.players[1].battlefield.has(inst):
				out.append("%s is parked AND on the battlefield" % inst)
	return out


func test_two_ai_seats_play_a_phasing_board_without_tripping() -> void:
	# The pilot reads only the battlefield lists, so phasing must never
	# leave it holding a permanent that is not there — or crash it.
	var a := AiPlayer.new(0, AiProfile.wizard())
	var b := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(0, a)
	g.set_agent(1, b)
	_phaser(0)
	_phaser(1, "Their Drake")
	var host := _bear(0)
	_aura_on(host, 0, [StaticAbility.new(_grant_phasing,
		"Enchanted creature has phasing.").changing_abilities()])
	assert_true(g.phase_out(_bear(1, "Gone Bear")))
	var problems: Array[String] = []
	var guard := 0
	while g.turn_number < 10 and not g.game_over and guard < 4000:
		if a.act(g) == "" and b.act(g) == "":
			break
		guard += 1
		if problems.is_empty():
			problems = _parking_problems()
	assert_true(g.turn_number >= 10 or g.game_over,
		"the duel moved on (turn %d, %d actions)" % [g.turn_number, guard])
	assert_eq(problems, [] as Array[String])


func test_a_phased_out_permanents_abilities_cannot_be_activated() -> void:
	var c := _creature("Test Breather")
	c.activated(ActivatedAbility.new("{0}", false, [PumpEffect.new(1, 1).self_buff()],
		"{0}: This creature gets +1/+1 until end of turn."))
	var breather := put_synthetic(0, c)
	var land := put_battlefield(0, "Island")
	assert_true(g.phase_out(breather))
	assert_true(g.phase_out(land))
	assert_refused(g.activate_ability(0, breather, 0), "phased out")
	assert_refused(g.tap_for_mana(0, land), "phased out")
	assert_false(land.tapped)
	assert_eq(g.stack.size(), 0)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [breather.id]), "not a permanent you control")
