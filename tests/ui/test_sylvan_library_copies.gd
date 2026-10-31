extends GameTest
## Sylvan Library's identical draws stay separate through the real held
## resolution, local choice rows and the private LAN question.

var old_forest: CardInstance


func _open_library_choice() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	old_forest = give_hand(0, "Forest")
	put_battlefield(0, "Sylvan Library")
	advance_to_next_turn()
	g.set_agent(0, HumanAgent.new())
	g.interactive_choices = true
	advance_to_step(Mtg.Step.DRAW)
	for i in 8:
		if g.awaiting_choice != null:
			break
		assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice)
	assert_ok(g.answer_choice(true))
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.awaiting_choice.candidates.size(), 3, "normal draw and two extra Forests")
	assert_does_not_have(g.awaiting_choice.candidates, old_forest, "not drawn this turn")


func test_each_drawn_forest_has_its_own_local_row_and_answer() -> void:
	_open_library_choice()
	var choices := g.awaiting_choice.candidates.duplicate()
	var rows := DuelScreen.choice_card_lines(g.awaiting_choice)
	assert_eq(rows.size(), 3, "three Forests, three selectable rows")
	if rows.size() != 3:
		return
	assert_eq(DuelScreen.choice_options(g.awaiting_choice),
		["Forest (copy 1 of 3)", "Forest (copy 2 of 3)", "Forest (copy 3 of 3)"])
	assert_eq(rows[2].answer, choices[2].id, "select the actual third copy")
	assert_ok(g.answer_choice(rows[2].answer))
	assert_ok(g.answer_choice(false))
	rows = DuelScreen.choice_card_lines(g.awaiting_choice)
	assert_eq(rows.size(), 2, "only the first chosen copy has gone")
	assert_ok(g.answer_choice(rows[0].answer))
	assert_ok(g.answer_choice(false))
	assert_null(g.awaiting_choice)
	assert_true(g.stack.is_empty())
	assert_eq(g.players[0].library[-1], choices[0], "the second returned card is on top")
	assert_eq(g.players[0].library[-2], choices[2], "the first returned card is underneath")
	assert_has(g.players[0].hand, choices[1])
	assert_has(g.players[0].hand, old_forest)
	assert_eq(g.players[0].hand.size(), 2)
	assert_eq(g.players[0].life, 20)
	assert_true(g.unanswered_choices.is_empty(), "no heuristic answered for the player")


func test_paying_for_one_forest_does_not_select_it_again() -> void:
	_open_library_choice()
	var choices := g.awaiting_choice.candidates.duplicate()
	var rows := DuelScreen.choice_card_lines(g.awaiting_choice)
	assert_eq(rows.size(), 3)
	if rows.size() != 3:
		return
	assert_ok(g.answer_choice(rows[1].answer))
	assert_ok(g.answer_choice(true))
	rows = DuelScreen.choice_card_lines(g.awaiting_choice)
	assert_eq(rows.size(), 2, "the paid-for copy is settled")
	for row in rows:
		assert_ne(row.answer, choices[1].id)
	assert_ok(g.answer_choice(rows[1].answer))
	assert_ok(g.answer_choice(false))
	assert_null(g.awaiting_choice)
	assert_has(g.players[0].hand, choices[1], "the exact paid-for copy stays")
	assert_eq(g.players[0].library[-1], choices[2])
	assert_eq(g.players[0].life, 16, "only one four-life payment")
	assert_eq(g.players[0].hand.size(), 3)


func test_lan_shows_every_copy_without_hidden_card_handles() -> void:
	_open_library_choice()
	var choices := g.awaiting_choice.candidates.duplicate()
	var actions := SgDuelActions.new(g)
	var handles_requested: Array[int] = []
	var handle := func(card: CardInstance) -> String:
		handles_requested.append(card.id)
		return "private-card"
	var view := actions.choice_view(0, handle)
	assert_eq(view.options.size(), 3, "LAN also shows all three Forests")
	assert_eq(actions.choice_view(1, handle), {}, "only the choosing player sees the cards")
	assert_true(handles_requested.is_empty(), "no persistent handles for hidden cards")
	if view.options.size() != 3:
		return
	assert_ne(view.options[0], view.options[1], "identical copies have distinct labels")
	assert_eq(view.cards, ["", "", ""])
	assert_ok(actions.answer(0, [2]))
	assert_ok(actions.answer(0, [1])) # No: put it back.
	view = actions.choice_view(0, handle)
	assert_eq(view.options.size(), 2)
	assert_true(handles_requested.is_empty(), "the next question also stays private")
	assert_ok(actions.answer(0, [0]))
	assert_ok(actions.answer(0, [1]))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].library[-1], choices[0])
	assert_eq(g.players[0].library[-2], choices[2])
	assert_has(g.players[0].hand, old_forest)
	assert_eq(g.players[0].life, 20)
