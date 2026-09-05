extends GameTest
## 2026-09-02 fidelity pass — COST-shaped lifts (CR 601.2h): a variable
## "any number of" sacrifice cost, asked one body at a time, and the engine
## fix it needed — a held cost action with SEVERAL questions of the same
## kind serves each answer to the question it belongs to.


## Picks named cards, in order, and declines once the list is spent.
class ListSeat extends DecisionAgent:
	var picks: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if picks.is_empty():
			return null
		var wanted := String(picks.pop_front())
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


# ---------------------------------------------------------- Sword of the Ages --

func test_sword_of_the_ages_lets_you_hold_creatures_back() -> void:
	# "Sacrifice this artifact and ANY NUMBER of creatures you control" —
	# the seat is asked one body at a time and may stop.
	var sword := put_battlefield(0, "Sword of the Ages")
	sword.tapped = false
	var giant := put_battlefield(0, "Hill Giant")        # 3 power
	var bears := put_battlefield(0, "Grizzly Bears")     # 2 power
	var seat := ListSeat.new()
	seat.picks = ["Grizzly Bears"]
	g.agents[0] = seat
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.player(1)]))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a COST, on activation")
	assert_eq(sword.zone, Mtg.Zone.GRAVEYARD, "so is the Sword")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "the Giant was held back")
	resolve_stack()
	assert_eq(g.players[1].life, 18, "X is the power of what was sacrificed")
	assert_eq(bears.zone, Mtg.Zone.EXILE, "then the card is exiled")
	assert_eq(sword.zone, Mtg.Zone.EXILE)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


func test_sword_of_the_ages_may_eat_nothing_at_all() -> void:
	# Zero is a legal number: with no creatures the Sword still activates
	# (and deals 0), rather than being refused for want of a body.
	var sword := put_battlefield(0, "Sword of the Ages")
	sword.tapped = false
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(sword.zone, Mtg.Zone.EXILE)


func test_sword_of_the_ages_default_seat_still_swings_with_everything() -> void:
	var sword := put_battlefield(0, "Sword of the Ages")
	sword.tapped = false
	put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 15, "the heuristic seat holds nothing back")


func test_sword_of_the_ages_holds_a_human_on_every_body() -> void:
	# THE ENGINE FIX. Two cost questions of the same kind, from the same
	# card: the first answer must go to the first question and the second
	# to the second. Before answers were parked just in time, the replay's
	# re-ask of question 1 swallowed answer 2 ("" = done) and nothing was
	# ever sacrificed.
	var sword := put_battlefield(0, "Sword of the Ages")
	sword.tapped = false
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	_human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.player(1)]))
	assert_not_null(g.awaiting_choice, "held on the first body")
	assert_true(g.awaiting_choice.is_cost)
	assert_true(g.awaiting_choice.optional, "and it may be declined")
	assert_eq(g.awaiting_choice.candidates.size(), 2)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "nothing paid while held")
	assert_ok(g.answer_choice("Grizzly Bears"))
	assert_not_null(g.awaiting_choice, "held again on the second body")
	assert_eq(g.awaiting_choice.candidates.size(), 1, "one creature left to offer")
	assert_eq(g.awaiting_choice.candidates[0], giant)
	assert_ok(g.answer_choice(""))          # done
	assert_null(g.awaiting_choice, "the cost is fully answered")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the FIRST answer ate the Bears")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "the SECOND answer kept the Giant")
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(bears.zone, Mtg.Zone.EXILE)


func test_sword_of_the_ages_human_can_take_everything_one_by_one() -> void:
	var sword := put_battlefield(0, "Sword of the Ages")
	sword.tapped = false
	put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Grizzly Bears")
	_human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.player(1)]))
	assert_ok(g.answer_choice("Hill Giant"))
	assert_ok(g.answer_choice("Grizzly Bears"))
	assert_null(g.awaiting_choice, "no bodies left, so no third ask")
	resolve_stack()
	assert_eq(g.players[1].life, 15)
