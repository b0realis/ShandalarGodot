extends GameTest
## The two 1997 timing rules that were listed as RULES FORKS but may not
## be forks at all — manual p.105 ("ending a phase can be responded to")
## and p.189/p.95/p.132 ("costs are not actions"). If our priority loop
## already behaves the 1997 way, there is nothing to switch, and shipping
## a switch that does nothing would be a lie. These tests decide it.


func test_a_response_cancels_the_end_of_the_step() -> void:
	# Manual p.105: "the other player can use fast effects in response to
	# this announcement. Any such response CANCELS the end of the phase,
	# thus giving the active player additional opportunities to take
	# actions during that phase."
	advance_to_step(Mtg.Step.MAIN1)
	var attacker := g.active_player
	var responder := g.opponent_of(attacker)
	var bolt := give_hand(responder, "Lightning Bolt")
	add_mana(responder, Mtg.ManaColor.R, 1)
	var step_before := g.current_step()

	# The active player announces the end (passes); priority moves across.
	assert_ok(g.pass_priority(attacker))
	assert_eq(g.priority_player, responder, "the other player may respond")

	# They respond instead of passing.
	assert_ok(g.cast_spell(responder, bolt, [TargetRef.player(attacker)]))
	resolve_stack()

	assert_eq(g.current_step(), step_before,
		"the phase did not end — the response cancelled it")
	assert_eq(g.priority_player, attacker,
		"and the active player has the phase back")


func test_playing_a_land_offers_no_response_window() -> void:
	# Manual p.189: "Putting a land into play (like tapping a land for
	# mana) is not an action, and thus presents no opportunity for fast
	# effects."
	advance_to_step(Mtg.Step.MAIN1)
	var pid := g.active_player
	var forest := give_hand(pid, "Forest")
	assert_ok(g.play_land(pid, forest))
	assert_eq(g.priority_player, pid,
		"priority never left the player who played it")
	assert_true(g.stack.is_empty(), "and nothing went on the stack")


func test_tapping_for_mana_offers_no_response_window() -> void:
	# Manual p.95: "Drawing mana from a mana source is neither a spell nor
	# an effect. You cannot respond to or interrupt the use of a mana
	# source."
	advance_to_step(Mtg.Step.MAIN1)
	var pid := g.active_player
	var forest := put_battlefield(pid, "Forest")
	assert_ok(g.tap_for_mana(pid, forest))
	assert_eq(g.priority_player, pid, "priority did not move")
	assert_true(g.stack.is_empty(), "a mana ability does not use the stack")
	assert_eq(g.players[pid].mana_pool.total(), 1)
