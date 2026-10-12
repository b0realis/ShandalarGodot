extends GutTest
## A NUMBER QUESTION READS AS ITS NUMBERS (campaign 2026-10-12, finding
## b6-1). "Choose a number" questions (DecisionAgent.choose_number: Land
## Tax's "up to 3", Power Leak, Mind Bomb, Shapeshifter, Tetravus...) are
## one OPTION question whose answers are the numbers themselves. The
## overlay numbered every line "%d. %s" and the digit keys answered the
## LINE — so the lines read "1. 0", "2. 1", "3. 2", "4. 3", and the 3 key
## on Land Tax fetched two lands. A question whose every answer is a
## whole number (or a whole number and its noun, the trigger's "2
## targets") now shows each line as its number, and digit k answers k.

var screen: DuelScreen


func before_each() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
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
		Mtg.Zone.LIBRARY:
			game.players[pid].library.append(inst)
		Mtg.Zone.BATTLEFIELD:
			game._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	return inst


func _digit(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	screen._unhandled_key_input(ev)


func _lines() -> Array:
	var texts: Array = []
	var stack: Array = [screen._choice_overlay]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button:
			texts.append((node as Button).text)
		stack.append_array(node.get_children())
	return texts


func _option(prompt: String, options: Array[String]) -> PlayerChoice:
	var choice := PlayerChoice.new(PlayerChoice.Kind.OPTION, 0, prompt, 0)
	choice.options = options
	return choice


func test_the_3_key_on_land_tax_fetches_three_lands() -> void:
	var game: MtgGame = screen.game
	game._probing = true
	for p in game.players:
		p.hand.clear()
		p.battlefield.clear()
	game._probing = false
	_make(0, "Land Tax", Mtg.Zone.BATTLEFIELD)
	_make(1, "Island", Mtg.Zone.BATTLEFIELD)
	_make(1, "Island", Mtg.Zone.BATTLEFIELD)
	for i in 5:
		_make(0, "Plains", Mtg.Zone.LIBRARY)
	game.recalculate()
	game.active_player = 0
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	var guard := 0
	while game.awaiting_choice == null and not game.stack.is_empty() and guard < 20:
		game.pass_priority(game.priority_player)
		guard += 1
	var number: PlayerChoice = game.awaiting_choice
	assert_not_null(number, "control: Land Tax holds its resolution on the count")
	if number == null:
		return
	assert_eq(Array(number.options), ["0", "1", "2", "3"], "control: a number question")
	screen._build_choice_overlay(number)   # headless: _open_choice_overlay stays shut
	_digit(KEY_3)
	guard = 0
	while game.awaiting_choice != null and guard < 10:
		screen._close_choice_overlay()
		screen._on_choice_option(0)       # each search: the first Plains
		guard += 1
	var plains := 0
	for inst in game.players[0].hand:
		if inst.data.card_name == "Plains":
			plains += 1
	assert_eq(plains, 3, "pressing 3 on 'Pick up to 3 basic lands.' fetched %d" % plains)


func test_a_number_questions_lines_read_as_their_numbers() -> void:
	var choice := _option("Pick up to 3 basic lands.", ["0", "1", "2", "3"])
	screen.game.awaiting_choice = choice
	screen._build_choice_overlay(choice)
	var texts := _lines()
	for n in ["0", "1", "2", "3"]:
		assert_has(texts, n, "the line for %s reads %s" % [n, n])
	assert_false(texts.has("4. 3"), "no line reads '4. 3': %s" % [texts])
	screen._close_choice_overlay()
	screen.game.awaiting_choice = null


func test_digit_k_answers_the_line_that_says_k() -> void:
	var choice := _option("Pick up to 3 basic lands.", ["0", "1", "2", "3"])
	for digit in range(1, 4):
		assert_eq(DuelScreen.choice_line_for_digit(choice, digit), digit,
			"the %d key answers the line '%d'" % [digit, digit])
	assert_eq(DuelScreen.choice_line_for_digit(choice, 4), -1, "no line says 4")
	var from_two := _option("Choose a number.", ["2", "3", "4", "5", "6"])
	assert_eq(DuelScreen.choice_line_for_digit(from_two, 2), 0, "a list starting at 2: the 2 key is its first line")
	assert_eq(DuelScreen.choice_line_for_digit(from_two, 1), -1, "and 1 answers nothing")


## The trigger's "How many targets?" lines carry their noun: "1 target",
## "2 targets". Each still reads as its number, and the 2 key is "2 targets".
func test_a_count_with_its_noun_is_a_number_question_too() -> void:
	var count := _option("How many targets?", ["0 targets", "1 target", "2 targets"])
	assert_eq(DuelScreen.choice_line_for_digit(count, 2), 2, "2 answers '2 targets'")
	assert_eq(DuelScreen.choice_line_for_digit(count, 1), 1, "1 answers '1 target'")
	screen.game.awaiting_choice = count
	screen._build_choice_overlay(count)
	var texts := _lines()
	assert_has(texts, "2 targets", "the line reads '2 targets' (lines: %s)" % [texts])
	assert_false(texts.has("3. 2 targets"))
	screen._close_choice_overlay()
	screen.game.awaiting_choice = null


## Anything else keeps its line numbers: words, and labels that only
## happen to start with a number they share.
func test_other_questions_keep_their_numbered_lines() -> void:
	var words := _option("Choose one.", ["Destroy target artifact", "Draw a card"])
	assert_eq(DuelScreen.choice_line_for_digit(words, 2), 1, "the 2 key is the second line")
	screen.game.awaiting_choice = words
	screen._build_choice_overlay(words)
	assert_has(_lines(), "2. Draw a card")
	screen._close_choice_overlay()
	screen.game.awaiting_choice = null
	var shared := _option("Choose one.", ["1 Plains", "1 Island"])
	assert_eq(DuelScreen.choice_line_for_digit(shared, 2), 1,
		"two lines that both start with 1 are not numbers: the 2 key is the second line")
	var yes_no := PlayerChoice.new(PlayerChoice.Kind.YES_NO, 0, "Pay {B}{B}?", true)
	assert_eq(DuelScreen.choice_line_for_digit(yes_no, 1), 0, "a yes/no question is untouched")
