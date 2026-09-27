extends GutTest
## THE OPPONENT CHOOSER, SEEN FROM THE DUEL SCREEN (2026-09-27).
##
## The playtest of a Black Vise: *"Black Vise card does not work"*, and the
## ruling once the engine had shown it working — *"opponent chooser should
## fire and then effects upon upkeep."* The engine half is pinned in
## tests/cards/test_choose_an_opponent_2026_09_27.gd; this is the half the
## owner sees. A human who casts the Vise against the AI is held on the
## choice overlay (docs/duel-todo.md §1.3) with the AI's name as the one
## line, picks it, and the Vise enters naming that seat; the AI's own Vise
## never pauses the duel. The overlay itself is not built headless, so the
## assertions read what it would show: the held question and its lines.


var screen: DuelScreen


func before_each() -> void:
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame


func _make(pid: int, card_name: String, zone: int) -> CardInstance:
	var game: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, game._next_instance_id, pid)
	game._next_instance_id += 1
	game._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.HAND:
			game.players[pid].hand.append(inst)
		Mtg.Zone.BATTLEFIELD:
			game._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	return inst


## Cast [param inst] for its controller from a main phase of their own turn
## and pass until the stack is empty or a question is held.
func _cast_and_resolve(pid: int, inst: CardInstance) -> void:
	var game: MtgGame = screen.game
	game.active_player = pid
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	game.players[pid].mana_pool.add(Mtg.ManaColor.C, 1)
	assert_eq(game.cast_spell(pid, inst), "", "the Vise is cast")
	var guard := 0
	while not game.stack.is_empty() and game.awaiting_choice == null and guard < 20:
		game.pass_priority(game.priority_player)
		guard += 1


func test_the_players_vise_holds_the_chooser_with_the_ai_named() -> void:
	var game: MtgGame = screen.game
	assert_true(game.interactive_choices, "a duel with a human in it pre-flights")
	var vise := _make(0, "Black Vise", Mtg.Zone.HAND)
	var asked := game.choice_log.size()
	_cast_and_resolve(0, vise)
	assert_not_null(game.awaiting_choice, "the resolution is held for the player")
	assert_eq(vise.zone, Mtg.Zone.STACK, "and the Vise has not entered yet")
	var choice: PlayerChoice = game.awaiting_choice
	assert_eq(choice.kind, PlayerChoice.Kind.OPTION)
	assert_eq(choice.pid, 0, "the player's own question")
	assert_eq(choice.source, "Black Vise", "the overlay's title line")
	assert_eq(DuelScreen.choice_question(choice), "Choose an opponent for Black Vise")
	assert_eq(DuelScreen.choice_options(choice), [game.players[1].player_name],
		"one line: the AI seat, by the name the table shows for it")
	assert_eq(DuelScreen.choice_options(choice), ["AI Wizard"])
	# Answer it the way the overlay does — line 1.
	screen._on_choice_option(0)
	assert_null(game.awaiting_choice)
	assert_eq(vise.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(vise.memory["victim"]), 1, "the Vise names the seat behind that line")
	assert_eq(game.choice_log.size(), asked + 1, "asked once, filed once")
	assert_true(game.choice_log[asked].answered_by_player)
	assert_eq(game.unanswered_choices.size(), 0, "nothing decided on the player's behalf")


func test_then_the_ai_is_squeezed_at_its_upkeep() -> void:
	var game: MtgGame = screen.game
	var vise := _make(0, "Black Vise", Mtg.Zone.HAND)
	_cast_and_resolve(0, vise)
	screen._on_choice_option(0)
	assert_eq(int(vise.memory["victim"]), 1)
	# Seven cards in the AI's hand at its upkeep: 7 − 4 = 3.
	while game.players[1].hand.size() < 7:
		_make(1, "Forest", Mtg.Zone.HAND)
	while game.players[1].hand.size() > 7:
		game.players[1].hand.pop_back()
	var life: int = game.players[1].life
	game.active_player = 1
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	var guard := 0
	while not game.stack.is_empty() and guard < 20:
		game.pass_priority(game.priority_player)
		guard += 1
	assert_eq(game.players[1].life, life - 3, "the squeeze follows the chooser")


func test_the_ais_own_vise_never_pauses_the_duel() -> void:
	var game: MtgGame = screen.game
	var vise := _make(1, "Black Vise", Mtg.Zone.HAND)
	var asked := game.choice_log.size()
	_cast_and_resolve(1, vise)
	assert_null(game.awaiting_choice, "the AI seat takes the hint")
	assert_eq(vise.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(vise.memory["victim"]), 0, "and names the player")
	assert_eq(game.choice_log.size(), asked + 1, "still filed, like every ask")
	assert_eq(game.choice_log[asked].pid, 1)
	assert_eq(game.choice_log[asked].options, ["White Wizard"] as Array[String],
		"the player's seat, by name")
	assert_eq(game.unanswered_choices.size(), 0, "the AI never wanted to be asked")
