extends GameTest
## The Mirage bug pass (Pack 8, 0.50.11), engine batch A — eleven findings:
##
## (a) CUMULATIVE UPKEEP'S INTERVENING IF (H6-F1, CR 702.24a, 603.4,
##     702.26b). "At the beginning of your upkeep, IF THIS PERMANENT IS ON
##     THE BATTLEFIELD, ..." — a permanent that phased out with its upkeep
##     trigger on the stack is treated as though it doesn't exist: no age
##     counter, no payment (Psychic Vortex drew its cards), no "wasn't
##     paid" event (Heart of Bogardan blasted the opponent).
## (b) AN AURA'S CONTROL KEEPS ITS PLACE ACROSS PHASING (H6-F3, CR 702.26d,
##     613.7). Control Magic phasing out with its host was dropped from the
##     control layer and came back as the NEWEST control effect, beating a
##     later one.
## (c) PEACE TALKS' "NEXT TURN" (H4-F1 = H6-F5): the next turn that
##     actually begins — the caster's own when the opponent's is skipped
##     (CR 614.10), an extra turn taken next (CR 500.7) — not "the
##     opponent's next turn" (`MtgGame.queue_next_turn_static` with -1).
## (d) "SACRIFICE IT" IS THE CASTER'S (H2-04, CR 603.7d, 701.17a): Tidal
##     Wave's Wall and Soulshriek's creature, stolen before the end step,
##     are not sacrificed by their new controller. "ITS CONTROLLER
##     sacrifices it" (the engine default, Celestial Sword) still is. The
##     Wall token says "Defender" (H1-F2).
## (e) FINAL FORTUNE'S LOSS IS FINAL FORTUNE'S (H2-09): the log named Last
##     Chance for both.
## (f) A FACE-DOWN OR SILENCED CREATURE HAS NO "IF THIS WOULD DIE"
##     REPLACEMENT (H6-F4, CR 708.2): Gravebane Zombie, Firestorm Phoenix.
## (g) A PHASED-OUT TRIGGER SOURCE IS NOT THERE (H3-F7, CR 702.26b, 603.4):
##     `F._same_trigger_source` (fem/_rules.gd, ~116 users) now asks
##     `MtgGame.is_present` — Tombstone Stairwell makes no Tombspawn, Soul
##     Echo asks nobody. Its LAST-KNOWN-INFORMATION readers moved to
##     `F._same_trigger_object`: a phased-out Wave of Terror still counts
##     its own age counters, not stale `last_counters`.
## (h) END-OF-COMBAT DELAYED TRIGGERS USE THE STACK (H5-F6, CR 603.7,
##     603.3b): Teferi's Veil's "it phases out at end of combat" is the
##     attacking player's trigger, so the defender's end-of-combat triggers
##     (Heat Stroke, Sawtooth Ogre) resolve first; Glyph of Doom's doom is
##     the caster's trigger, on the stack where players can answer it.
## (j) "SACRIFICE IT" FROM AN ACTIVATED ABILITY IS THE ACTIVATOR'S (CR
##     603.7d, 701.17a): Pyric Salamander, Dragon Whelp, Nalathni Dragon and
##     Krovikan Elementalist, stolen after the activation, stay. "ITS
##     CONTROLLER sacrifices it" (Celestial Sword, Goblin Ski Patrol) is
##     still whoever controls it then.
## (k) MORE END-OF-COMBAT DELAYED TRIGGERS ON THE STACK (CR 603.7, 603.3b):
##     Time Elemental's "at end of combat, sacrifice it and it deals 5
##     damage to you" (the attack/block trigger's controller; a stolen one
##     isn't sacrificed but still burns them) and Infinite Authority's
##     "destroy the other creature at end of combat".
## (i) PAYING OFF A DELAYED TRIGGER (found by the UI fixer):
##     `MtgGame.settle_delayed_trigger` took the entry off the queue by an
##     index read BEFORE paying, and the payment announces the state — a
##     synchronous listener that moved the game on (the duel screen's
##     automatic pass) let Sabertooth Cobra's upkeep trigger fire and leave
##     the queue, and the stale index then pointed past it. The entry now
##     leaves the queue first and comes back if the payment fails.

const F := preload("res://cards/sets/fem/_rules.gd")


class Seat extends DecisionAgent:
	var answer := true
	var asked: Array[String] = []

	func answer_yes_no(_g: MtgGame, _p: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return answer


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)
	CardPacks.set_enabled("pack-6", false)
	CardPacks.set_enabled("pack-3", false)


## Pass until [param step] of [param pid]'s turn — a later turn than this
## one when [param pid] is active now and the step is behind us.
func _to_step_of(pid: int, step: int) -> void:
	var guard := 0
	while not (g.active_player == pid and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached %s of P%d" % [Mtg.step_name(step), pid])


## P0's NEXT upkeep, with its triggers waiting on the stack.
func _to_my_next_upkeep() -> void:
	advance_to_next_turn()   # P1's turn
	_to_step_of(0, Mtg.Step.UPKEEP)
	assert_false(g.stack.is_empty(), "the upkeep trigger is on the stack")


func _cast(pid: int, name: String, targets: Array = []) -> CardInstance:
	var card := give_hand(pid, name)
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card


func _tokens(pid: int, name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[pid].battlefield:
		if inst.is_token and inst.data.card_name == name:
			out.append(inst)
	return out


# ============================================ (a) cumulative upkeep, phased

func test_a_phased_out_psychic_vortex_upkeep_does_nothing() -> void:
	var vortex := put_battlefield(0, "Psychic Vortex")
	vortex.counters["age"] = 2
	_to_my_next_upkeep()
	var hand := g.players[0].hand.size()
	assert_true(g.phase_out(vortex), "it phases out with its upkeep trigger on the stack")
	resolve_stack()
	assert_eq(int(vortex.counters.get("age", 0)), 2, "no age counter")
	assert_eq(g.players[0].hand.size(), hand,
		"CR 702.24a's intervening if fails: no 'draw a card' payment")
	assert_true(vortex.phased_out, "and nothing sacrificed it")


func test_a_phased_out_heart_of_bogardan_does_not_blast() -> void:
	var heart := put_battlefield(0, "Heart of Bogardan")
	heart.counters["age"] = 3
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_my_next_upkeep()
	assert_true(g.phase_out(heart))
	var life := g.players[1].life
	resolve_stack()
	assert_eq(g.players[1].life, life,
		"no CUMULATIVE_UPKEEP_UNPAID event: Heart of Bogardan's blast never triggers")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(heart.counters.get("age", 0)), 3)
	assert_true(heart.phased_out)


func test_a_phased_in_cumulative_upkeep_still_asks() -> void:
	var vortex := put_battlefield(0, "Psychic Vortex")
	vortex.counters["age"] = 1
	_to_my_next_upkeep()
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(int(vortex.counters.get("age", 0)), 2, "the control: an age counter")
	assert_eq(g.players[0].hand.size(), hand + 2, "and the payment drawn")


func test_a_phased_out_permanent_cannot_take_a_self_counter_payment() -> void:
	var aboroth := put_battlefield(0, "Aboroth")
	var payment := CumulativeUpkeep.self_counter_payment("-1/-1")
	assert_true(CumulativeUpkeep.payment_possible(g, aboroth, 0, 1, payment))
	assert_true(g.phase_out(aboroth))
	assert_false(CumulativeUpkeep.payment_possible(g, aboroth, 0, 1, payment),
		"no counters on a phased-out permanent (CR 702.26b)")


# ============================================= (b) aura control and phasing

func _control_magic(pid: int, host: CardInstance) -> CardInstance:
	var aura := _make_instance(pid, "Control Magic")
	g._put_on_battlefield(aura, pid, host)
	g.recalculate()
	return aura


func test_a_later_control_change_still_wins_after_the_aura_phases_with_its_host() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _control_magic(1, bear)
	assert_eq(bear.controller_id, 1)
	advance_to_step(Mtg.Step.MAIN1)
	g.change_control(bear, 0)   # a later, permanent control change
	assert_eq(bear.controller_id, 0, "the later effect wins (CR 613.7)")
	assert_true(g.phase_out(bear))
	assert_true(aura.phased_out and aura.phased_indirectly, "the Aura rides along (702.26g)")
	assert_true(g.phase_in(bear))
	assert_false(aura.phased_out)
	assert_eq(bear.controller_id, 0,
		"phasing keeps timestamps (CR 702.26d): the Aura's control is not re-dated as the newest")


func test_control_magic_alone_survives_its_host_phasing() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_control_magic(1, bear)
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(g.phase_out(bear))
	assert_true(g.phase_in(bear))
	assert_eq(bear.controller_id, 1, "Control Magic still controls it")


func test_an_aura_phased_out_on_its_own_pauses_its_control_and_keeps_its_place() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _control_magic(1, bear)
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(g.phase_out(aura), "the Aura alone phases out")
	assert_false(bear.phased_out)
	assert_eq(bear.controller_id, 0, "a phased-out Aura controls nothing (CR 702.26b)")
	assert_true(g.phase_in(aura))
	assert_eq(bear.controller_id, 1, "back in: its control applies again")
	g.change_control(bear, 0)
	assert_true(g.phase_out(aura))
	assert_true(g.phase_in(aura))
	assert_eq(bear.controller_id, 0, "…in its old place, under the later effect")


# =========================================================== (c) Peace Talks

func test_peace_talks_covers_my_next_turn_when_the_opponents_is_skipped() -> void:
	var bear0 := put_battlefield(0, "Grizzly Bears")
	var bear1 := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.skip_next_turn(1)   # Chronatog's "you skip your next turn"
	_cast(0, "Peace Talks")
	assert_true(bear0.cur_cant_attack, "this turn")
	advance_to_next_turn()
	assert_eq(g.active_player, 0, "P1's turn was skipped")
	assert_true(bear0.cur_cant_attack,
		"Peace Talks' next turn is the next turn that happens (CR 614.10)")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear0.id]))
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_false(bear1.cur_cant_attack, "two turns later it is over")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear1.id]))


func test_peace_talks_covers_an_extra_turn_created_after_it() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Peace Talks")
	_cast(0, "Time Walk")
	advance_to_next_turn()
	assert_eq(g.active_player, 0, "the extra turn is the next turn (CR 500.7)")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]))
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))


func test_a_per_seat_next_turn_static_still_waits_for_that_seat() -> void:
	# The other form (False Peace, Taunt): THAT player's next turn.
	var seen: Array = []
	var marker := StaticAbility.new(func(game: MtgGame, _s: CardInstance) -> void:
		seen.append(game.active_player), "Test marker.")
	var src := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.queue_next_turn_static(1, src, marker)
	g.skip_next_turn(1)
	advance_to_next_turn()
	assert_eq(g.active_player, 0, "P1's turn was skipped")
	assert_true(seen.is_empty(), "not P0's turn: it is P1's next turn the static waits for")
	assert_eq(g.next_turn_statics.size(), 1, "still queued")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_true(seen.has(1), "P1's next turn that happens")
	assert_true(g.next_turn_statics.is_empty())


# ============================================== (d) "sacrifice it" — whose

func test_tidal_waves_wall_stolen_is_not_sacrificed_by_its_new_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Tidal Wave")
	var walls := _tokens(0, "Wall")
	assert_eq(walls.size(), 1)
	var wall := walls[0]
	g.change_control(wall, 1)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD,
		"P0's delayed 'sacrifice it' can't make P1 sacrifice it (CR 603.7d, 701.17a)")


func test_tidal_waves_wall_is_sacrificed_by_its_caster() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Tidal Wave")
	var wall := _tokens(0, "Wall")[0]
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	assert_string_contains(wall.data.oracle_text, "Defender",
		"the token's text says what it has (H1-F2)")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_ne(wall.zone, Mtg.Zone.BATTLEFIELD, "sacrificed at the end step")


func test_soulshriek_target_stolen_is_not_sacrificed_but_one_returned_is() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var lion := put_battlefield(0, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Soulshriek", [TargetRef.card(bear)])
	_cast(0, "Soulshriek", [TargetRef.card(lion)])
	g.change_control(bear, 1)
	g.change_control(lion, 1)
	g.change_control(lion, 0)   # back under the caster before the end step
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "stolen: P0 can't sacrifice it")
	assert_eq(lion.zone, Mtg.Zone.GRAVEYARD, "P0 controls it again: sacrificed")


func test_its_controller_sacrifices_it_is_still_whoever_controls_it() -> void:
	# The engine default (sacrificer -1): "ITS CONTROLLER sacrifices it"
	# (Celestial Sword) — the new controller does.
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.doom_at_next_end_step(bear, false, false, true)
	g.change_control(bear, 1)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ======================================================= (e) Final Fortune

func _loss_line() -> String:
	var hit := ""
	for line in g.log_lines:
		if line.contains("loses:"):
			hit = line
	return hit


func test_final_fortunes_loss_is_logged_under_its_own_name() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Final Fortune")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_true(g.players[0].has_lost)
	assert_string_contains(_loss_line(), "Final Fortune")
	assert_false(_loss_line().contains("Last Chance"), _loss_line())


func test_last_chances_loss_is_still_last_chance() -> void:
	CardPacks.set_enabled("pack-6", true)
	CardRegistry.ensure_loaded()
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Last Chance")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_true(g.players[0].has_lost)
	assert_string_contains(_loss_line(), "Last Chance")


# =================================== (f) a face-down creature has no ability

func test_a_face_down_gravebane_zombie_dies() -> void:
	var zombie := put_battlefield(0, "Gravebane Zombie")
	g.turn_face_down(zombie)
	g.destroy(zombie)
	assert_eq(zombie.zone, Mtg.Zone.GRAVEYARD,
		"a face-down 2/2 has no abilities (CR 708.2): no dies-to-library replacement")


func test_a_face_down_firestorm_phoenix_dies() -> void:
	var phoenix := put_battlefield(0, "Firestorm Phoenix")
	g.turn_face_down(phoenix)
	g.destroy(phoenix)
	assert_eq(phoenix.zone, Mtg.Zone.GRAVEYARD, "no return-to-hand replacement")


func _silence_creatures(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_abilities_silenced = true


func test_a_gravebane_zombie_that_lost_all_abilities_dies() -> void:
	var zombie := put_battlefield(0, "Gravebane Zombie")
	put_synthetic(1, CardData.new("Test Silence", "{2}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_silence_creatures,
			"Creatures lose all abilities.").silencing_abilities()))
	g.recalculate()
	assert_true(zombie.cur_abilities_silenced)
	g.destroy(zombie)
	assert_eq(zombie.zone, Mtg.Zone.GRAVEYARD)


func test_a_face_up_gravebane_zombie_still_goes_to_the_library() -> void:
	var zombie := put_battlefield(0, "Gravebane Zombie")
	g.destroy(zombie)
	assert_eq(zombie.zone, Mtg.Zone.LIBRARY)


# ======================================= (g) a phased-out trigger source

func test_a_phased_out_tombstone_stairwell_makes_no_tombspawn() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var stairwell := put_battlefield(1, "Tombstone Stairwell")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear)
	g.set_agent(1, Seat.new())
	_to_step_of(1, Mtg.Step.UPKEEP)
	assert_false(g.stack.is_empty())
	assert_true(g.phase_out(stairwell))
	resolve_stack()
	var made := 0
	for p in g.players:
		made += _tokens(p.id, "Tombspawn").size()
	assert_eq(made, 0, "CR 603.4: 'if this enchantment is on the battlefield' fails")
	assert_true(stairwell.phased_out, "still there, phased out")


func test_a_phased_out_soul_echo_asks_nobody() -> void:
	var echo := put_battlefield(0, "Soul Echo")
	echo.counters["echo"] = 3
	var them := Seat.new()
	g.set_agent(1, them)
	_to_my_next_upkeep()
	assert_true(g.phase_out(echo))
	resolve_stack()
	assert_true(them.asked.is_empty(), "no Soul Echo choice from a phased-out Echo: %s" % [them.asked])
	assert_eq(int(echo.counters.get("echo", 0)), 3)


func test_a_phased_out_wave_of_terror_still_counts_its_own_age_counters() -> void:
	# Its draw-step trigger is no intervening if: it resolves, reading the
	# age counters on the Wave as it last existed (CR 608.2h) — the live
	# ones, since a phased-out permanent keeps its counters (702.26d) and
	# `last_counters` is only written when it leaves the battlefield.
	var bear := put_battlefield(1, "Grizzly Bears")          # mana value 2
	var spirit := g.create_token(1, CardData.new("Spirit", "", Mtg.CardType.CREATURE) \
		.pt(1, 1).with_colors(Mtg.ManaColor.W))[0]               # mana value 0
	advance_to_next_turn()
	_to_step_of(0, Mtg.Step.UPKEEP)
	resolve_stack()
	var wave := put_battlefield(0, "Wave of Terror")   # after the upkeep: no age bill
	wave.counters["age"] = 2
	_to_step_of(0, Mtg.Step.DRAW)
	assert_false(g.stack.is_empty(), "the draw-step trigger waits")
	assert_true(g.phase_out(wave))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "two age counters: mana value 2 dies")
	assert_eq(spirit.zone, Mtg.Zone.BATTLEFIELD, "not the stale 'no counters' (mana value 0)")


func test_the_two_trigger_source_helpers() -> void:
	var s := put_battlefield(0, "Grizzly Bears")
	assert_true(F._same_trigger_source(g, s))
	assert_true(F._same_trigger_object(g, s))
	assert_true(g.phase_out(s))
	assert_false(F._same_trigger_source(g, s), "phased out: not here to act")
	assert_true(F._same_trigger_object(g, s), "but the same object, for last known information")


# ========================================== (h) end-of-combat delayed triggers

func test_heat_stroke_of_the_defender_resolves_before_teferis_veil() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Teferi's Veil")
	put_battlefield(1, "Heat Stroke")
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	run_combat([giant.id], {wall.id: giant.id})
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD,
		"Heat Stroke (NAP) resolves before the Veil's phase-out (AP, CR 603.3b)")


func test_sawtooth_ogres_bite_lands_before_teferis_veil() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Teferi's Veil")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_pump(bears.id, 0, 3, [])
	g.recalculate()
	var ogre := put_battlefield(1, "Sawtooth Ogre")
	run_combat([bears.id], {ogre.id: bears.id})
	resolve_stack()
	assert_true(bears.phased_out, "it still phases out afterwards")
	assert_eq(bears.damage, 4, "3 combat damage, then the Ogre's bite, then the fade")


func test_teferis_veil_fade_waits_on_the_stack() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Teferi's Veil")
	var bear := put_battlefield(0, "Grizzly Bears")
	run_combat([bear.id])
	assert_eq(g.current_step(), Mtg.Step.COMBAT_END)
	assert_false(bear.phased_out, "a trigger, not yet resolved")
	assert_false(g.stack.is_empty())
	assert_eq(g.stack.back().controller, 0, "the attacking player's (CR 603.7d)")
	resolve_stack()
	assert_true(bear.phased_out)


func test_glyph_of_doom_is_a_trigger_players_can_answer() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: attacker.id}))
	assert_ok(g.pass_priority(0))
	_cast(1, "Glyph of Doom", [TargetRef.card(wall)])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(attacker.zone, Mtg.Zone.BATTLEFIELD, "on the stack, not yet")
	assert_false(g.stack.is_empty())
	assert_eq(g.stack.back().controller, 1, "the caster's delayed trigger (CR 603.7d)")
	resolve_stack()
	assert_eq(attacker.zone, Mtg.Zone.GRAVEYARD)


# ================== (i) paying off a delayed trigger while the game moves

var _moved_on := false

## A synchronous state_changed listener that moves the game on — the
## local duel screen's automatic pass does — once, into P1's upkeep.
func _move_on_to_their_upkeep() -> void:
	if _moved_on:
		return
	_moved_on = true
	_to_step_of(1, Mtg.Step.UPKEEP)


func test_settling_survives_a_listener_that_moves_the_game_on_mid_payment() -> void:
	var cobra := put_battlefield(0, "Sabertooth Cobra")
	run_combat([cobra.id])
	resolve_stack()
	assert_eq(g.players[1].poison, 1, "bitten")
	var due := g.settleable_delayed_triggers(1)
	assert_eq(due.size(), 1, "the ransom P1 may pay")
	if due.is_empty():
		return
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	add_mana(1, Mtg.ManaColor.C, 2)
	g.state_changed.connect(_move_on_to_their_upkeep)
	var result := g.settle_delayed_trigger(1, int(due[0]["id"]))
	g.state_changed.disconnect(_move_on_to_their_upkeep)
	assert_eq(result, "", "paid")
	assert_true(_moved_on, "the listener moved the game on during the payment")
	assert_eq(g.active_player, 1)
	resolve_stack()
	assert_eq(g.players[1].poison, 1,
		"settled before it could trigger: no second poison counter at that upkeep")
	assert_true(g.settleable_delayed_triggers(1).is_empty())


func test_a_settlement_that_cannot_be_paid_keeps_the_entry() -> void:
	var cobra := put_battlefield(0, "Sabertooth Cobra")
	run_combat([cobra.id])
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(0))
	var due := g.settleable_delayed_triggers(1)
	assert_eq(due.size(), 1)
	if due.is_empty():
		return
	assert_refused(g.settle_delayed_trigger(1, int(due[0]["id"])), "not enough mana")
	assert_eq(g.settleable_delayed_triggers(1).size(), 1, "still owed")
	advance_to_next_turn()
	assert_eq(g.players[1].poison, 2, "unpaid: the upkeep poison counter")


# ===================== (j) an activated "sacrifice it" is the activator's

## Activate [param inst]'s ability [param index] for P0 with [param mana]
## (colour -> amount) and let it resolve.
func _activate(inst: CardInstance, index: int, mana: Dictionary, targets: Array = []) -> void:
	for c in mana:
		add_mana(0, c, int(mana[c]))
	assert_ok(g.activate_ability(0, inst, index, targets))
	resolve_stack()


func _to_end_step_and_resolve() -> void:
	advance_to_step(Mtg.Step.END)
	resolve_stack()


func test_pyric_salamander_stolen_after_its_breath_stays() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var stolen := put_battlefield(0, "Pyric Salamander")
	var kept := put_battlefield(0, "Pyric Salamander")
	_activate(stolen, 0, {Mtg.ManaColor.R: 1})
	_activate(kept, 0, {Mtg.ManaColor.R: 1})
	g.change_control(stolen, 1)
	_to_end_step_and_resolve()
	assert_eq(stolen.zone, Mtg.Zone.BATTLEFIELD, "P0 can't sacrifice what P1 controls (CR 701.17a)")
	assert_eq(kept.zone, Mtg.Zone.GRAVEYARD, "the activator sacrifices their own")


func _breathe_four_times(dragon: CardInstance) -> void:
	for i in 4:
		_activate(dragon, 0, {Mtg.ManaColor.R: 1})


func test_dragon_whelp_stolen_after_its_fourth_breath_stays() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var stolen := put_battlefield(0, "Dragon Whelp")
	var kept := put_battlefield(0, "Dragon Whelp")
	_breathe_four_times(stolen)
	_breathe_four_times(kept)
	g.change_control(stolen, 1)
	_to_end_step_and_resolve()
	assert_eq(stolen.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(kept.zone, Mtg.Zone.GRAVEYARD)


func test_nalathni_dragon_stolen_after_its_fourth_breath_stays() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var stolen := put_battlefield(0, "Nalathni Dragon")
	var kept := put_battlefield(0, "Nalathni Dragon")
	_breathe_four_times(stolen)
	_breathe_four_times(kept)
	g.change_control(stolen, 1)
	_to_end_step_and_resolve()
	assert_eq(stolen.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(kept.zone, Mtg.Zone.GRAVEYARD)


func test_krovikan_elementalists_flier_stolen_stays() -> void:
	CardPacks.set_enabled("pack-3", true)
	CardRegistry.ensure_loaded()
	advance_to_step(Mtg.Step.MAIN1)
	var elementalist := put_battlefield(0, "Krovikan Elementalist")
	var stolen := put_battlefield(0, "Grizzly Bears")
	var kept := put_battlefield(0, "Savannah Lions")
	_activate(elementalist, 1, {Mtg.ManaColor.U: 2}, [TargetRef.card(stolen)])
	_activate(elementalist, 1, {Mtg.ManaColor.U: 2}, [TargetRef.card(kept)])
	assert_true(stolen.has_keyword(Mtg.Keyword.FLYING))
	g.change_control(stolen, 1)
	_to_end_step_and_resolve()
	assert_eq(stolen.zone, Mtg.Zone.BATTLEFIELD, "'Sacrifice it' — the activator can't")
	assert_eq(kept.zone, Mtg.Zone.GRAVEYARD)


func test_celestial_swords_creature_is_sacrificed_by_its_controller() -> void:
	CardPacks.set_enabled("pack-3", true)
	CardRegistry.ensure_loaded()
	advance_to_step(Mtg.Step.MAIN1)
	var sword := put_battlefield(0, "Celestial Sword")
	var bear := put_battlefield(0, "Grizzly Bears")
	_activate(sword, 0, {Mtg.ManaColor.C: 3}, [TargetRef.card(bear)])
	assert_eq(bear.cur_power, 5)
	g.change_control(bear, 1)
	_to_end_step_and_resolve()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD,
		"'ITS CONTROLLER sacrifices it' — the new controller does")


func test_goblin_ski_patrol_is_sacrificed_by_its_controller() -> void:
	CardPacks.set_enabled("pack-3", true)
	CardRegistry.ensure_loaded()
	advance_to_step(Mtg.Step.MAIN1)
	var ski := put_battlefield(0, "Goblin Ski Patrol")
	put_battlefield(0, "Snow-Covered Mountain")
	_activate(ski, 0, {Mtg.ManaColor.R: 1, Mtg.ManaColor.C: 1})
	g.change_control(ski, 1)
	_to_end_step_and_resolve()
	assert_eq(ski.zone, Mtg.Zone.GRAVEYARD, "'Its controller sacrifices it' — printed so")


# ======================= (k) Time Elemental, Infinite Authority on the stack

func test_time_elementals_immolation_waits_on_the_stack() -> void:
	var elemental := put_battlefield(0, "Time Elemental")
	run_combat([elemental.id])
	assert_eq(g.current_step(), Mtg.Step.COMBAT_END)
	assert_eq(elemental.zone, Mtg.Zone.BATTLEFIELD, "a delayed trigger, not yet resolved")
	assert_false(g.stack.is_empty())
	if g.stack.is_empty():
		return
	assert_eq(g.stack.back().controller, 0, "the attack trigger's controller's (CR 603.7d)")
	resolve_stack()
	assert_eq(elemental.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 15)


func test_a_time_elemental_stolen_before_end_of_combat_still_burns_who_attacked() -> void:
	var elemental := put_battlefield(0, "Time Elemental")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [elemental.id]))
	resolve_stack()   # the attack trigger creates the delayed one
	g.change_control(elemental, 1)
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(elemental.zone, Mtg.Zone.BATTLEFIELD,
		"'sacrifice it': P0 can't sacrifice what P1 controls (CR 701.17a)")
	assert_eq(g.players[0].life, 15, "'it deals 5 damage to you' — still P0")
	assert_eq(g.players[1].life, 20)


func test_infinite_authoritys_destruction_waits_on_the_stack() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Wood")   # 0/3
	var aura := give_hand(0, "Infinite Authority")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "on the stack, not yet")
	assert_false(g.stack.is_empty())
	if g.stack.is_empty():
		return
	assert_eq(g.stack.back().controller, 0, "the Aura's controller's delayed trigger")
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1)
