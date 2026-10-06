extends GameTest
## Pack 9 bug pass (fix-licid; finding h5-4) — Pandemonium: "Whenever a
## creature enters, that creature's controller may have it deal damage
## equal to its power to any target of their choice." The TARGET is named
## by the creature's controller as the trigger goes on the stack (CR
## 603.3d); the "may" is part of the resolution (CR 608.2) and belongs to
## the creature's controller AS IT RESOLVES — a creature that changed hands
## in response is its new controller's to fire or hold. A creature that has
## left answers through its last controller we know of: the one it entered
## under (CR 608.2h).


class Seat extends DecisionAgent:
	var answers: Array = []
	var asked: Array[String] = []

	func answer_yes_no(_g: MtgGame, _p: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_option(_g: MtgGame, _p: int, prompt: String, _labels: Array[String], hint: int) -> int:
		asked.append(prompt)
		return hint


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _seat(pid: int) -> Seat:
	var a := Seat.new()
	g.set_agent(pid, a)
	return a


func _may_prompts(seat: Seat) -> int:
	var n := 0
	for p in seat.asked:
		if p.begins_with("Pandemonium: have "): n += 1
	return n


func test_the_creatures_new_controller_answers_the_may() -> void:
	var mine := _seat(0)
	var theirs := _seat(1)
	mine.answers = [false]   # P0 would never hit itself
	put_battlefield(0, "Pandemonium")
	var giant := put_battlefield(1, "Hill Giant")
	assert_eq(g.stack.size(), 1, "the trigger is on the stack")
	var ref: TargetRef = g.stack.back().targets[0]
	assert_true(ref.is_player and ref.player_id == 0, "P1 aimed it at P0")
	g.gain_control_until_eot(giant, 0)   # P0 takes the Giant in response
	assert_eq(giant.controller_id, 0)
	resolve_stack()
	assert_eq(_may_prompts(mine), 1, "P0, the creature's controller now, is asked")
	assert_eq(_may_prompts(theirs), 0, "P1 no longer controls it")
	assert_eq(g.players[0].life, 20, "and P0 declines")


func test_the_entering_controller_still_answers_without_a_control_change() -> void:
	var mine := _seat(0)
	var theirs := _seat(1)
	theirs.answers = [true]
	put_battlefield(0, "Pandemonium")
	put_battlefield(1, "Hill Giant")
	resolve_stack()
	assert_eq(_may_prompts(theirs), 1)
	assert_eq(_may_prompts(mine), 0)
	assert_eq(g.players[0].life, 17)


func test_a_creature_that_left_is_answered_for_by_its_entering_controller() -> void:
	var mine := _seat(0)
	var theirs := _seat(1)
	theirs.answers = [true]
	put_battlefield(0, "Pandemonium")
	var giant := put_battlefield(1, "Hill Giant")
	g.destroy(giant)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(_may_prompts(theirs), 1, "last known: it was P1's")
	assert_eq(_may_prompts(mine), 0)
	assert_eq(g.players[0].life, 17, "its last known power")
