extends GameTest
## STASIS SKIPS THE UNTAP STEP, AND ISLAND SANCTUARY STILL ENDS (bug hunt
## 2026-10-21, cardsA).
##
## Stasis says "players skip their untap steps". It used to freeze every
## permanent instead (`cur_skips_untap`) and let each untap step run on —
## which spent the one-shot "doesn't untap during its controller's next
## untap step" locks (Barl's Cage, Telekinesis) on steps that untapped
## nothing, ended "until your next untap step" effects and phased
## permanents in and out. It now raises the engine's real skip
## (`MtgPlayer.skips_untap_step`, Sands of Time's), keeping the freeze
## flags for what reads them.
##
## That made a latent fault of Island Sanctuary's reachable from the base
## set: its "until your next turn" ended at its controller's next UNTAP
## STEP, so a skipped one (Sands of Time, an Avizoa — now a Stasis) kept
## the shield up for good. It ends as that player's next upkeep begins
## instead — the same moment for every attack, since nobody attacks in an
## untap step.


## Says yes to Island Sanctuary's first offer only; every other question is
## answered with its hint.
class SanctuaryOnce extends DecisionAgent:
	var used := false

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		if prompt == "Select draw potential.":
			if used:
				return false
			used = true
			return true
		return hint


func test_stasis_skips_the_untap_step_so_a_cage_lock_waits() -> void:
	var stasis := put_battlefield(0, "Stasis")
	var cage := put_battlefield(0, "Barl's Cage")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.tap_permanent(bear)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, cage, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()   # P1's turn 2: its untap step is skipped
	assert_true(bear.tapped)
	assert_true(bear.skip_next_untap, "a skipped untap step spends no lock")
	g.destroy(stasis)
	advance_to_next_turn()   # P0's turn 3
	advance_to_next_turn()   # P1's turn 4: the first real untap step
	assert_true(bear.tapped, "the Cage's lock holds it for that step")
	assert_false(bear.skip_next_untap, "and is spent there")


func test_stasis_still_lets_the_turn_begin() -> void:
	put_battlefield(0, "Stasis")
	var bear := put_battlefield(1, "Grizzly Bears", true)
	advance_to_next_turn()
	assert_false(bear.summoning_sick, "a skipped untap step is not a skipped turn")
	assert_true(g.players[1].skips_untap_step)


func _sanctuary_board() -> CardInstance:
	put_battlefield(0, "Island Sanctuary")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()   # P1's turn 2
	g.agents[0] = SanctuaryOnce.new()
	advance_to_next_turn()   # P0's turn 3: the draw is skipped, the gates shut
	assert_eq(g.active_player, 0)
	return bear


func _p1_attacks(bear: CardInstance) -> String:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.active_player, 1)
	var answer := g.declare_attackers(1, [bear.id])
	if answer != "":
		assert_ok(g.declare_attackers(1, []))
	return answer


func test_island_sanctuary_ends_at_your_next_turn_after_a_skipped_untap_step() -> void:
	var bear := _sanctuary_board()
	g.skip_next_untap_step(0)   # P0's turn-5 untap step will not happen
	advance_to_next_turn()      # P1's turn 4
	assert_refused(_p1_attacks(bear))
	advance_to_next_turn()      # P0's turn 5, untap step skipped
	advance_to_next_turn()      # P1's turn 6
	assert_ok(_p1_attacks(bear))


func test_island_sanctuary_ends_under_stasis_too() -> void:
	var bear := _sanctuary_board()
	put_battlefield(0, "Stasis")
	advance_to_next_turn()      # P1's turn 4
	assert_refused(_p1_attacks(bear))
	advance_to_step(Mtg.Step.UPKEEP)   # P0's turn 5: keep the Stasis
	add_mana(0, Mtg.ManaColor.U)
	resolve_stack()
	advance_to_next_turn()      # P1's turn 6
	assert_ok(_p1_attacks(bear))


func test_island_sanctuary_shield_holds_through_their_turn() -> void:
	var bear := _sanctuary_board()
	advance_to_next_turn()      # P1's turn 4
	assert_refused(_p1_attacks(bear))
	advance_to_next_turn()      # P0's turn 5
	advance_to_next_turn()      # P1's turn 6
	assert_ok(_p1_attacks(bear))
