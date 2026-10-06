extends GameTest
## The Tempest block bug pass (2026-10-06), the lead's two follow-ups to
## fix-engine's CR 614.12 reading (`MtgGame._enters_without_abilities`): a
## permanent that would have no abilities as it would exist on the
## battlefield applies none of its OWN entry replacements, so
## - a land drop is not HELD on an entry payment the entry no longer uses
##   (Lotus Vale under Blood Moon is a Mountain: it asks nothing), and
## - its own entry veto (`entry_condition`) does not refuse the arrival (no
##   pool card has one today; the shape is pinned for the next).


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)
	CardPacks.set_enabled("pack-9", false)


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func test_a_lotus_vale_under_blood_moon_asks_no_entry_question() -> void:
	put_battlefield(1, "Blood Moon")
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	_human_seat(0)
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	assert_null(g.awaiting_choice, "a Mountain has no entry payment to ask about (CR 614.12)")
	assert_eq(vale.zone, Mtg.Zone.BATTLEFIELD, "the land entered")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "no land was sacrificed")
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].lands_played_this_turn, 1)


func test_a_lotus_vale_without_blood_moon_still_asks() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Plains")
	_human_seat(0)
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	assert_not_null(g.awaiting_choice, "the control: its own entry payment is asked")
	assert_eq(vale.zone, Mtg.Zone.HAND)


func test_an_own_entry_veto_does_not_refuse_a_permanent_entering_without_abilities() -> void:
	var veto := CardData.new("Test Vetoed Creature", "{G}", Mtg.CardType.CREATURE).pt(2, 2)
	veto.entry_condition = func(_g: MtgGame, _i: CardInstance, _pid: int) -> String:
		return "it refuses to enter"
	put_battlefield(1, "Humility")
	var inst := give_synthetic(0, veto)
	assert_eq(g.entry_refused(inst, 0), "", "under Humility it has no entry veto (CR 614.12)")


func test_an_own_entry_veto_still_refuses_without_a_silencer() -> void:
	var veto := CardData.new("Test Vetoed Creature", "{G}", Mtg.CardType.CREATURE).pt(2, 2)
	veto.entry_condition = func(_g: MtgGame, _i: CardInstance, _pid: int) -> String:
		return "it refuses to enter"
	var inst := give_synthetic(0, veto)
	assert_eq(g.entry_refused(inst, 0), "it refuses to enter", "the control")
