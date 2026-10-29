extends GameTest
## THE CLONE'S ARRIVAL QUESTION AND A LEGEND ALREADY IN PLAY (the polish
## pass, 2026-10-28; hunt of 2026-10-21: *"A Clone or Doppelganger's
## arrival question may still offer a legend in play, which the ruling then
## buries."*).
##
## AS 1997'S LEGEND RULE PLAYS IT. The rule of the era let a second legend
## of a name come into play and buried the NEWEST at once (the owner's
## ruling of 2026-10-21, [method MtgGame._newest_duplicate_legend]); a
## copy has been that legend for no time at all, so a Clone that enters
## as a copy of a legend already in play is the one buried. The 1997 Clone
## itself chose from every creature in play (`card_clone`, SHANDALAR
## 0x00473c2e: TYPE_CREATURE, no legend test), so the shape stays a LEGAL
## answer — a player may still pick it. What changes is the question:
##  - the shapes the legend rule would bury come LAST, after every shape
##    that lives;
##  - the question says so;
##  - no heuristic answers with one: the default seat takes the first
##    shape that lives, the computer the best of those, and both decline
##    when every shape would be buried.


## Answers every arrival question with [member want] when it is offered,
## and records what was put in front of it.
class Recorder extends DecisionAgent:
	var want := ""
	var asked: Array[String] = []
	var offered: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		var names: Array[String] = []
		for inst in candidates:
			names.append(inst.data.card_name)
		offered.append(names)
		for inst in candidates:
			if inst.data.card_name == want:
				return inst
		return null if candidates.is_empty() else candidates[0]


const LEGEND := "Sir Shandlar of Eberyn"


func _cast(card_name: String) -> CardInstance:
	var clone := give_hand(0, card_name)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, clone, []))
	resolve_stack()
	return clone


# ------------------------------------------------------- the question --

func test_a_legend_in_play_is_offered_last_and_the_question_says_why() -> void:
	var seat := Recorder.new()
	g.set_agent(0, seat)
	put_battlefield(1, LEGEND)            # first in battlefield order
	put_battlefield(1, "Grizzly Bears")
	_cast("Clone")
	assert_eq(seat.offered.size(), 1, "one arrival question")
	if seat.offered.is_empty():
		return
	assert_eq(seat.offered[0], ["Grizzly Bears", LEGEND],
		"the shape that lives first, the legend last")
	assert_true(seat.asked[0].begins_with("Copy any creature on the battlefield?"))
	assert_string_contains(seat.asked[0], "legend")
	assert_string_contains(seat.asked[0], "buried")


func test_no_legend_no_change_in_the_question() -> void:
	var seat := Recorder.new()
	g.set_agent(0, seat)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	_cast("Clone")
	assert_eq(seat.asked, ["Copy any creature on the battlefield?"] as Array[String])
	assert_eq(seat.offered[0], ["Grizzly Bears", "Hill Giant"], "battlefield order kept")


func test_the_player_may_still_choose_the_legend_and_it_is_buried() -> void:
	var seat := Recorder.new()
	seat.want = LEGEND
	g.set_agent(0, seat)
	var legend := put_battlefield(1, LEGEND)
	put_battlefield(1, "Grizzly Bears")
	var clone := _cast("Clone")
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD, "the original stays")
	assert_eq(clone.zone, Mtg.Zone.GRAVEYARD, "the copy is the newer legend")


func test_the_engine_names_the_shapes_the_rule_buries() -> void:
	var legend := put_battlefield(1, LEGEND)
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_true(g.legend_copy_is_buried(legend))
	assert_false(g.legend_copy_is_buried(bears))
	g.turn_face_down(legend)
	assert_false(g.legend_copy_is_buried(legend),
		"a face-down creature's copiable values are a nameless 2/2 (CR 707.2)")


# ------------------------------------------------------ the heuristics --

func test_the_default_seat_copies_the_shape_that_lives() -> void:
	g.set_agent(0, DecisionAgent.new())
	var legend := put_battlefield(1, LEGEND)
	put_battlefield(1, "Grizzly Bears")
	var clone := _cast("Clone")
	assert_eq(clone.zone, Mtg.Zone.BATTLEFIELD, "it did not kill itself")
	assert_eq(clone.data.card_name, "Grizzly Bears")
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD)


func test_the_computer_copies_the_best_shape_that_lives() -> void:
	# Sir Shandlar (4/7) is the most valuable body on the table; the Hill
	# Giant is the best one a copy of survives as.
	g.set_agent(0, AiPlayer.new(0, AiProfile.wizard()))
	put_battlefield(1, "Grizzly Bears")
	var legend := put_battlefield(1, LEGEND)
	put_battlefield(1, "Hill Giant")
	var clone := _cast("Clone")
	assert_eq(clone.zone, Mtg.Zone.BATTLEFIELD, "it did not kill itself")
	assert_eq(clone.data.card_name, "Hill Giant")
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD)


func test_the_computer_declines_when_every_shape_is_buried() -> void:
	g.set_agent(0, AiPlayer.new(0, AiProfile.wizard()))
	var legend := put_battlefield(1, LEGEND)
	var clone := _cast("Clone")
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD)
	assert_ne(clone.data.card_name, LEGEND, "no copy of the legend was made")
	var copied := false
	for line in g.log_lines:
		copied = copied or String(line).contains("becomes a copy of " + LEGEND)
	assert_false(copied, "the computer said no to the shape the rule buries")


func test_the_default_seat_declines_when_every_shape_is_buried() -> void:
	g.set_agent(0, DecisionAgent.new())
	var legend := put_battlefield(1, LEGEND)
	_cast("Clone")
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD)
	var copied := false
	for line in g.log_lines:
		copied = copied or String(line).contains("becomes a copy of " + LEGEND)
	assert_false(copied)


func test_a_doppelganger_arriving_is_asked_the_same_way() -> void:
	g.set_agent(0, AiPlayer.new(0, AiProfile.wizard()))
	var legend := put_battlefield(1, LEGEND)
	put_battlefield(1, "Grizzly Bears")
	var doppel := _cast("Vesuvan Doppelganger")
	assert_eq(doppel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(doppel.data.card_name, "Grizzly Bears")
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD)
