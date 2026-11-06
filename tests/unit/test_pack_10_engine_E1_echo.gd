extends GameTest
## Pack 10 E1 — ECHO (CR 702.30a): "At the beginning of your upkeep, if
## this permanent came under your control since the beginning of your last
## upkeep, sacrifice it unless you pay [cost]." Pinned on SYNTHETIC
## permanents (engine/abilities/echo.gd), so nothing here depends on how a
## Pack 10 card file is written; the cards themselves are B10's
## (tests/cards/test_pack_10_B10_*.gd).
##
## The clock: MtgPlayer.upkeeps_begun (counted just before UPKEEP_START)
## against CardInstance.control_upkeep_mark (written by _put_on_battlefield
## and _set_controller) — MtgGame.came_under_control_since_last_upkeep.


## Records every echo question it is asked, and answers with [member pay]
## (and the hint: an unaffordable echo is never asked anyway).
class EchoSeat extends DecisionAgent:
	var pay := true
	var asked: Array[String] = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		if prompt.begins_with("Pay echo"):
			asked.append(prompt)
			return pay and hint
		return hint


var seats: Array[EchoSeat] = []


func before_each() -> void:
	super()
	seats = [EchoSeat.new(), EchoSeat.new()]
	g.set_agent(0, seats[0])
	g.set_agent(1, seats[1])
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	seats = []
	CardPacks.set_enabled("pack-9", false)


static func _echo_beast(cost := "{1}{G}", card_name := "Test Echo Beast") -> CardData:
	var c := CardData.new(card_name, cost, Mtg.CardType.CREATURE)
	c.pt(3, 3)
	return EchoAbility.attach(c, cost)


static func _echo_relic(cost := "{3}") -> CardData:
	var c := CardData.new("Test Echo Relic", cost, Mtg.CardType.ARTIFACT)
	return EchoAbility.attach(c, cost)


func _forests(pid: int, count: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for _i in count:
		out.append(put_battlefield(pid, "Forest"))
	return out


## Pass until [param turn]'s upkeep has begun (its triggers on the stack,
## none resolved).
func _to_upkeep_of_turn(turn: int) -> void:
	var guard := 0
	while not (g.turn_number == turn and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "did not reach turn %d's upkeep" % turn)


## Did the stack hold an echo trigger of [param inst]?
func _echo_on_stack(inst: CardInstance) -> bool:
	for item in g.stack:
		if item.card == inst and item.trigger is EchoAbility.EchoTrigger:
			return true
	return false


# ============================================ 1. due once, at the first upkeep --

func test_the_clock_counts_upkeeps_as_they_begin() -> void:
	assert_eq(g.players[0].upkeeps_begun, 1, "turn 1's upkeep began")
	assert_eq(g.players[1].upkeeps_begun, 0, "the second seat has had none")
	advance_to_next_turn()
	assert_eq(g.players[1].upkeeps_begun, 1)
	advance_to_next_turn()
	assert_eq(g.players[0].upkeeps_begun, 2)


func test_due_at_the_first_upkeep_after_it_arrives_and_never_again(preset = use_parameters(
		["modern", "modern_mana_burn", "fifth"])) -> void:
	g.rules.set_preset(preset)
	var lands := _forests(0, 2)
	var beast := put_synthetic(0, _echo_beast())
	assert_true(g.came_under_control_since_last_upkeep(beast), "it arrived this turn")
	assert_true(EchoAbility.due_next_upkeep(g, beast), "the public reader agrees")
	advance_to_next_turn()   # the opponent's turn: not their echo
	assert_eq(seats[1].asked.size(), 0, "the opponent owes nothing")
	_to_upkeep_of_turn(3)
	assert_true(_echo_on_stack(beast), "the echo trigger is on the stack")
	resolve_stack()
	assert_eq(seats[0].asked.size(), 1, "asked once")
	assert_string_contains(seats[0].asked[0], "{1}{G}")
	assert_string_contains(seats[0].asked[0], "Test Echo Beast")
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD, "paid, so it stays")
	assert_true(lands[0].tapped and lands[1].tapped, "the echo was paid from the lands")
	assert_false(EchoAbility.due_next_upkeep(g, beast), "nothing more is owed")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.turn_number, 5)
	assert_eq(seats[0].asked.size(), 1, "the second upkeep asks nothing")
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)


func test_arrived_during_your_upkeep_is_due_at_the_next_one() -> void:
	_forests(0, 2)
	_to_upkeep_of_turn(3)
	var beast := put_synthetic(0, _echo_beast())
	resolve_stack()
	assert_false(_echo_on_stack(beast), "this upkeep's triggers were already put")
	advance_to_step(Mtg.Step.MAIN1)   # turn 3's main
	assert_eq(seats[0].asked.size(), 0, "not asked in the upkeep it arrived in")
	assert_true(EchoAbility.due_next_upkeep(g, beast))
	advance_to_next_turn()
	advance_to_next_turn()   # turn 5
	assert_eq(g.turn_number, 5)
	assert_eq(seats[0].asked.size(), 1, "asked at the next one")
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)


func test_flashed_in_on_the_opponents_turn_is_due_at_your_next_upkeep() -> void:
	_forests(1, 2)
	var beast := put_synthetic(1, _echo_beast())   # P1's, during P0's turn 1
	advance_to_next_turn()   # P1's turn 2
	assert_eq(seats[1].asked.size(), 1, "due at P1's first upkeep since")
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)


# ============================================= 2. declined or unaffordable --

func test_declined_echo_sacrifices_it_and_regeneration_does_not_save_it() -> void:
	_forests(0, 2)
	seats[0].pay = false
	var beast := put_synthetic(0, _echo_beast())
	beast.regeneration_shields = 1
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 1, "the seat was asked")
	assert_eq(beast.zone, Mtg.Zone.GRAVEYARD, "sacrificed, not destroyed (CR 701.17a)")


func test_an_unaffordable_echo_is_not_asked_and_the_permanent_is_sacrificed() -> void:
	var beast := put_synthetic(0, _echo_beast("{4}{G}{G}"))
	_forests(0, 2)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 0, "a seat that cannot pay is not asked")
	assert_eq(beast.zone, Mtg.Zone.GRAVEYARD)


func test_floating_mana_pays_first() -> void:
	var lands := _forests(0, 2)
	var beast := put_synthetic(0, _echo_beast())
	_to_upkeep_of_turn(3)
	add_mana(0, Mtg.ManaColor.G, 2)
	resolve_stack()
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(lands[0].tapped or lands[1].tapped, "the pool paid; no land was tapped")
	assert_eq(g.players[0].mana_pool.total(), 0)


# ======================================================== 3. control changes --

func test_a_stolen_echo_permanent_is_owed_by_the_new_controller_only() -> void:
	_forests(0, 2)
	_forests(1, 2)
	var beast := put_synthetic(0, _echo_beast())
	beast.control_upkeep_mark = -1   # long since paid
	g.change_control(beast, 1)       # Control Magic's engine half
	assert_eq(beast.controller_id, 1)
	advance_to_next_turn()           # P1's upkeep
	assert_eq(seats[1].asked.size(), 1, "the thief owes it")
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 0, "the old controller owes nothing")


func test_an_exchange_makes_both_new_controllers_owe() -> void:
	_forests(0, 4)
	_forests(1, 4)
	var mine := put_synthetic(0, _echo_beast("{1}{G}", "Test Echo Mine"))
	var theirs := put_synthetic(1, _echo_beast("{1}{G}", "Test Echo Theirs"))
	mine.control_upkeep_mark = -1
	theirs.control_upkeep_mark = -1
	assert_true(g.exchange_control(mine, theirs))
	advance_to_next_turn()
	assert_eq(seats[1].asked.size(), 1, "P1 owes echo for what it gained")
	assert_string_contains(seats[1].asked[0], "Test Echo Mine")
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 1)
	assert_string_contains(seats[0].asked[0], "Test Echo Theirs")


func test_a_borrowed_permanent_that_comes_home_is_owed_again_by_its_owner() -> void:
	_forests(0, 2)
	_forests(1, 2)
	var beast := put_synthetic(0, _echo_beast())
	beast.control_upkeep_mark = -1
	advance_to_next_turn()   # P1's turn 2
	g.gain_control_until_eot(beast, 1)
	assert_eq(beast.controller_id, 1)
	advance_to_next_turn()   # back to P0 at cleanup; P0's turn 3
	assert_eq(beast.controller_id, 0, "home again")
	assert_eq(seats[0].asked.size(), 1, "it came back under P0's control since P0's last upkeep")
	advance_to_next_turn()   # P1's turn 4
	assert_eq(seats[1].asked.size(), 0, "the borrower owes nothing")


func test_stolen_in_response_the_trigger_asks_nobody() -> void:
	_forests(0, 2)
	_forests(1, 2)
	var beast := put_synthetic(0, _echo_beast())
	_to_upkeep_of_turn(3)
	assert_true(_echo_on_stack(beast))
	g.change_control(beast, 1)
	resolve_stack()
	assert_eq(seats[0].asked.size(), 0, "the trigger's controller no longer controls it")
	assert_eq(seats[1].asked.size(), 0)
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD, "nobody could sacrifice it")
	advance_to_next_turn()   # P1's turn 4
	assert_eq(g.turn_number, 4)
	assert_eq(seats[1].asked.size(), 1, "the thief owes it at their next upkeep")


# ======================================= 4. new objects, phasing, copies --

func test_leaving_and_returning_owes_echo_again() -> void:
	_forests(0, 2)
	var beast := put_synthetic(0, _echo_beast())
	beast.control_upkeep_mark = -1
	g.exile_permanent(beast)
	assert_eq(beast.control_upkeep_mark, -1, "off the battlefield it has no mark")
	g.return_from_exile_to_play(beast, 0)
	assert_true(g.came_under_control_since_last_upkeep(beast), "a new object (CR 400.7)")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 1)


func test_bounced_in_response_the_trigger_does_nothing() -> void:
	_forests(0, 2)
	var beast := put_synthetic(0, _echo_beast())
	_to_upkeep_of_turn(3)
	assert_true(_echo_on_stack(beast))
	g.return_to_hand(beast)
	resolve_stack()
	assert_eq(seats[0].asked.size(), 0, "the object that triggered is gone (CR 603.4)")
	assert_eq(beast.zone, Mtg.Zone.HAND)


func test_phasing_out_and_in_is_not_coming_under_control() -> void:
	_forests(0, 2)
	var beast := put_synthetic(0, _echo_beast())
	beast.control_upkeep_mark = -1
	assert_true(g.phase_out(beast))
	advance_to_next_turn()
	advance_to_next_turn()   # P0's untap step phased it in
	assert_false(beast.phased_out)
	assert_eq(seats[0].asked.size(), 0, "phasing in is not coming under control (CR 702.26d)")


func test_a_fresh_permanent_that_phases_out_still_owes_its_echo() -> void:
	_forests(0, 2)
	var beast := put_synthetic(0, _echo_beast())
	assert_true(g.phase_out(beast))
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 1, "the mark survived the phasing")


func test_a_clone_of_an_echo_creature_owes_the_copied_echo() -> void:
	_forests(0, 4)
	var beast := put_synthetic(1, _echo_beast())
	beast.control_upkeep_mark = -1
	var clone := put_battlefield(0, "Clone")
	assert_eq(clone.data.card_name, "Test Echo Beast", "the Clone copied the beast")
	assert_eq(EchoAbility.echo_cost(clone), "{1}{G}", "and has its echo (CR 707.2)")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 1, "the Clone owes the copied echo")
	assert_eq(clone.zone, Mtg.Zone.BATTLEFIELD)


func test_becoming_a_copy_is_not_coming_under_control() -> void:
	_forests(0, 4)
	var beast := put_synthetic(1, _echo_beast())
	var shifter := put_synthetic(0, CardData.new("Test Shifter", "{3}{U}{U}",
		Mtg.CardType.CREATURE).pt(1, 1))
	shifter.control_upkeep_mark = -1
	beast.control_upkeep_mark = -1
	g.become_copy(shifter, g.copiable_data(beast))   # Vesuvan Doppelganger's shift
	assert_eq(EchoAbility.echo_cost(shifter), "{1}{G}")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 0, "it has been under P0's control all along")


# ================================================= 5. Humility's silence --

func test_humility_silences_echo_for_as_long_as_it_lasts() -> void:
	CardPacks.set_enabled("pack-9", true)
	_forests(0, 2)
	put_battlefield(1, "Humility")
	var beast := put_synthetic(0, _echo_beast())
	assert_eq(EchoAbility.echo_cost(beast), "", "a creature under Humility has no echo")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 0, "no ability, no trigger")
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)


func test_humility_gone_before_the_upkeep_the_echo_is_asked_then() -> void:
	CardPacks.set_enabled("pack-9", true)
	_forests(0, 2)
	var humility := put_battlefield(1, "Humility")
	var beast := put_synthetic(0, _echo_beast())
	g.destroy(humility)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(seats[0].asked.size(), 1, "inside the window, so asked")


# ============================================ 6. a noncreature artifact --

func test_a_tapped_artifact_still_owes_echo_under_the_1997_rules() -> void:
	g.rules.set_preset("fifth")
	_forests(0, 3)
	var relic := put_synthetic(0, _echo_relic())
	relic.tapped = true
	relic.skip_next_untap = true
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(relic.tapped, "still tapped")
	assert_eq(seats[0].asked.size(), 1, "echo is a trigger, not a continuous effect")
	assert_eq(relic.zone, Mtg.Zone.BATTLEFIELD)


# =================================================== 7. a human is asked --

func test_a_human_seat_is_held_on_the_echo_question() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	_forests(0, 2)
	var beast := put_synthetic(0, _echo_beast())
	_to_upkeep_of_turn(3)
	assert_true(_echo_on_stack(beast))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice, "the resolution is held open")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_eq(g.awaiting_choice.pid, 0)
	assert_string_contains(g.awaiting_choice.prompt, "Pay echo {1}{G}")
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD, "nothing has happened yet")
	assert_ok(g.answer_choice(false))
	assert_null(g.awaiting_choice)
	assert_eq(beast.zone, Mtg.Zone.GRAVEYARD, "declined: sacrificed")


func test_a_human_who_says_yes_pays() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var lands := _forests(0, 2)
	var beast := put_synthetic(0, _echo_beast())
	_to_upkeep_of_turn(3)
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_ok(g.answer_choice(true))
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(lands[0].tapped and lands[1].tapped, "paid")


# ======================================== 8. the default seats' answer --

func test_the_plain_agent_pays_an_affordable_echo() -> void:
	var plain := DecisionAgent.new()
	assert_true(plain.echo_hint(g, 0, null, ManaCost.parse("{1}{G}")))
	g.set_agent(0, plain)
	_forests(0, 2)
	var beast := put_synthetic(0, _echo_beast())
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)


# ======================================== 9. Test hands, and the journal --

func test_a_test_position_permanent_owes_no_echo_by_default() -> void:
	var game := MtgGame.new()
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	game.setup(filler, filler, "P0", "P1", 20, 20, 7)
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Forest")
	assert_false(bool(position.table_entry(0, 0)["echo_due"]), "off by default")
	position.set_echo_due(0, 0, true)
	var back := DuelPosition.from_dict(position.to_dict())
	assert_true(bool(back.table_entry(0, 0)["echo_due"]), "the flag round-trips")
	assert_eq(game.begin_from_position(DuelPosition.new()), "")
	var placed := CardInstance.new(_echo_beast(), 999, 0)
	game._place_from_position(placed, 0, false, false)
	assert_eq(placed.control_upkeep_mark, -1, "placed, not arrived")
	assert_false(game.came_under_control_since_last_upkeep(placed))


func test_the_search_journal_takes_the_clock_and_the_sacrifice_back() -> void:
	_forests(0, 2)
	seats[0].pay = false
	var beast := put_synthetic(0, _echo_beast())
	var mark_before := beast.control_upkeep_mark
	var counts := [g.players[0].upkeeps_begun, g.players[1].upkeeps_begun]
	var m := g.make_mark()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(beast.zone, Mtg.Zone.GRAVEYARD, "declined under the search")
	assert_eq(g.players[0].upkeeps_begun, counts[0] + 1)
	g.unmake_to(m)
	g.end_search()
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD, "the sacrifice was taken back")
	assert_eq(beast.control_upkeep_mark, mark_before, "and its mark")
	assert_eq([g.players[0].upkeeps_begun, g.players[1].upkeeps_begun], counts,
		"and both seats' clocks")
	assert_true(g.came_under_control_since_last_upkeep(beast), "still owed")
