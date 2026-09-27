extends GameTest
## THE OPPONENT CHOOSER FIRES AS THE VISE ENTERS (2026-09-27).
##
## The playtest: *"Black Vise card does not work"* — and the Vise worked:
## it squeezed hand−4 at every upkeep of the seat it named, cast from the
## hand, cast by the AI, under the 1997 rules. What it did NOT do was say a
## word on the way in. *"As Black Vise enters, choose an opponent"* is a
## choice the printed card makes the caster make, and at a two-seat table
## the card used to make it silently ([method MtgGame.opponent_of]), so a
## Vise that arrived without a prompt read as a Vise that did nothing. The
## ruling: *"opponent chooser should fire and then effects upon upkeep."*
##
## [method MtgGame.choose_opponent] now puts the question to the caster's
## seat — the other seats' names as its lines — through the same
## [method DecisionAgent.choose_option] every other resolution ask goes
## through, so it is FILED (choice_log), HELD for a seat that answers for
## itself (docs/duel-todo.md §1.3) and taken on the hint by a seat that does
## not want to be asked. Black Vise, The Rack and Cursed Rack all name their
## opponent this way; the upkeep effects are unchanged and pinned last.


func _last_choice() -> PlayerChoice:
	assert_false(g.choice_log.is_empty(), "something was asked")
	return g.choice_log[g.choice_log.size() - 1]


## Cast [param card_name] from [param pid]'s hand in a main phase of their
## own turn (a GameTest starts at turn 1's upkeep, P0 active).
func _cast_artifact(pid: int, card_name: String) -> CardInstance:
	if g.active_player != pid:
		advance_to_next_turn()
	advance_to_step(Mtg.Step.MAIN1)
	var inst := give_hand(pid, card_name)
	add_mana(pid, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(pid, inst))
	resolve_stack()
	assert_eq(inst.zone, Mtg.Zone.BATTLEFIELD, "%s resolved" % card_name)
	return inst


# ------------------------------------------------------ the question is put --

func test_the_vise_asks_its_caster_to_name_an_opponent() -> void:
	var asked := g.choice_log.size()
	var vise := _cast_artifact(0, "Black Vise")
	assert_eq(g.choice_log.size(), asked + 1, "one question, asked once")
	var choice := _last_choice()
	assert_eq(choice.kind, PlayerChoice.Kind.OPTION)
	assert_eq(choice.pid, 0, "put to the caster")
	assert_eq(choice.prompt, "Choose an opponent for Black Vise")
	assert_eq(choice.options, ["P1"] as Array[String],
		"the other seat's name is the one line — never the caster's own")
	assert_eq(choice.source, "Black Vise", "asked inside the Vise's resolution")
	assert_eq(int(choice.answer), 0)
	assert_eq(int(vise.memory["victim"]), 1, "and the seat behind that line is the victim")


func test_the_rack_and_the_cursed_rack_ask_the_same_way() -> void:
	var rack := _cast_artifact(1, "The Rack")   # on P1's turn, by P1
	var choice := _last_choice()
	assert_eq(choice.prompt, "Choose an opponent for The Rack")
	assert_eq(choice.pid, 1)
	assert_eq(choice.options, ["P0"] as Array[String])
	assert_eq(int(rack.memory["victim"]), 0)
	var cursed := _cast_artifact(0, "Cursed Rack")   # and back to P0
	choice = _last_choice()
	assert_eq(choice.prompt, "Choose an opponent for Cursed Rack")
	assert_eq(choice.pid, 0)
	assert_eq(choice.options, ["P1"] as Array[String])
	assert_eq(int(cursed.memory["victim"]), 1)


func test_a_seat_that_does_not_want_to_be_asked_is_not_held() -> void:
	# The base agent (and the AI, which overrides answer_option only for
	# Time Vault and Deflection) takes the hint: nothing pauses, nothing is
	# "decided for" anyone, because the seat never wanted the question.
	var vise := _cast_artifact(0, "Black Vise")
	assert_null(g.awaiting_choice, "no hold for a seat that answers by hint")
	assert_eq(g.unanswered_choices.size(), 0)
	assert_eq(int(vise.memory["victim"]), 1)


# ------------------------------------------------- a human seat is held open --

func test_a_human_seat_is_held_open_on_the_chooser() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	advance_to_step(Mtg.Step.MAIN1)
	var vise := give_hand(0, "Black Vise")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(0, vise))
	assert_null(g.awaiting_choice, "the question is asked at resolution, not at the cast")
	var guard := 0
	while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_not_null(g.awaiting_choice, "the resolution is held for the player")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_eq(g.awaiting_choice.source, "Black Vise")
	assert_eq(g.awaiting_choice.prompt, "Choose an opponent for Black Vise")
	assert_eq(g.awaiting_choice.options, ["P1"] as Array[String])
	assert_eq(vise.zone, Mtg.Zone.STACK, "nothing has entered while the question is open")
	assert_false(vise.memory.has("victim"))
	assert_ok(g.answer_choice(0))
	assert_null(g.awaiting_choice)
	assert_eq(vise.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(vise.memory["victim"]), 1)
	assert_eq(g.unanswered_choices.size(), 0, "the player answered it themselves")
	assert_true(_last_choice().answered_by_player)


# --------------------------------------------------- then effects upon upkeep --

func test_the_named_seat_is_squeezed_at_its_upkeep_as_before() -> void:
	_cast_artifact(0, "Black Vise")
	for _i in 7:
		give_hand(1, "Forest")
	advance_to_next_turn()   # P1's upkeep: 7 − 4
	resolve_stack()
	assert_eq(g.players[1].life, 17, "the chooser changed nothing about the squeeze")
	assert_eq(g.players[0].life, 20, "and the caster is never the victim")


func test_the_rack_still_racks_the_named_seat() -> void:
	_cast_artifact(0, "The Rack")
	advance_to_next_turn()   # P1's upkeep with an empty hand: 3 − 0
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].life, 20)
