extends GameTest
## Untamed Wilds at the human seat (playtest, 2026-09-06): the library
## picker opens BEFORE the cast, the pick is parked on the HumanAgent, and
## the found land must arrive on the battlefield when the spell resolves
## — asked once, answered once.


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func test_the_found_land_arrives_and_the_pick_is_asked_once() -> void:
	var human := _human_seat(0)
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var mountain := _make_instance(0, "Mountain")
	mountain.zone = Mtg.Zone.LIBRARY
	g.players[0].library.push_front(mountain)
	var wilds := give_hand(0, "Untamed Wilds")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 3)
	human.preselect("Mountain")
	assert_ok(g.cast_spell(0, wilds))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	var lands := 0
	for perm in g.players[0].battlefield:
		if perm.is_land():
			lands += 1
	assert_eq(lands, 4, "the Mountain is on the battlefield")
	assert_null(g.awaiting_choice, "nothing held open")
