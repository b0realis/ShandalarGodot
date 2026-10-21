extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: "the color or colors of
## your choice" (Dream Coat, Prismatic Lace, Shyft).
##
## WAS: the choice overlay answers every colour question with ONE colour —
## a click on a line is the answer — so a player could make a creature
## white, or blue, but never white and blue, which the three cards allow
## and `MtgGame.set_color` already takes (a colour MASK, which
## `HumanAgent.answer_color` passes through as it is). NOW a colour question
## that allows several (`PlayerChoice.count` above 1) is answered the
## discard window's way: each line ticks or unticks a colour, and a last
## line, `Done.`, answers with every colour ticked. A question for one
## colour is answered by its click, as before.
##
## These tests set the count on the held question themselves, which is
## all the screen reads; the engine half — the three cards asking with
## `count` set (`DecisionAgent.choose_color(several)`) — landed with the
## hunt's handovers and is pinned in
## `test_hunt_2026_10_21_handover_colours.gd`.

var screen: DuelScreen
var bear: CardInstance
var coat: CardInstance


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)     # Prismatic Lace (Mirage)
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	var g: MtgGame = screen.game
	g._probing = true
	for p in g.players:
		p.hand.clear()
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g._probing = false
	bear = _put("Grizzly Bears")
	coat = CardInstance.new(CardRegistry.get_card("Dream Coat"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[coat.id] = coat
	g.attach_aura_from_anywhere(coat, bear, 0)


func after_each() -> void:
	CardPacks.set_enabled("pack-8", false)
	await get_tree().process_frame
	await get_tree().process_frame


func _put(card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, 0)
	inst.summoning_sick = false
	return inst


## Dream Coat activated and resolving: the colour question, held for the
## player and on the screen.
func _ask(colors_allowed: int) -> PlayerChoice:
	var g: MtgGame = screen.game
	assert_eq(g.activate_ability(0, coat, 0, []), "")
	g.pass_priority(0)
	g.pass_priority(1)
	var choice: PlayerChoice = g.awaiting_choice
	assert_not_null(choice, "control: the colour question is held")
	if choice == null:
		return null
	assert_eq(choice.kind, PlayerChoice.Kind.COLOR)
	choice.count = colors_allowed      # the engine half (see the class doc)
	screen._build_choice_overlay(choice)
	return choice


func test_two_colours_ticked_then_done() -> void:
	var choice := _ask(5)
	if choice == null:
		return
	var labels := DuelScreen.choice_options(choice)
	assert_eq(labels, ["White", "Blue", "Black", "Red", "Green", DuelScreen.COLORS_DONE],
		"five colours to tick and the line that answers")
	screen._on_choice_option(0)
	assert_not_null(screen.game.awaiting_choice, "a tick is not an answer")
	screen._on_choice_option(1)
	screen._on_choice_option(labels.size() - 1)
	assert_null(screen.game.awaiting_choice, "Done answered it")
	assert_eq(bear.cur_colors, Mtg.ManaColor.W | Mtg.ManaColor.U, "white AND blue")


func test_a_second_click_unticks() -> void:
	var choice := _ask(5)
	if choice == null:
		return
	screen._on_choice_option(0)
	screen._on_choice_option(2)
	screen._on_choice_option(0)     # White again: taken back
	screen._on_choice_option(DuelScreen.choice_options(choice).size() - 1)
	assert_eq(bear.cur_colors, Mtg.ManaColor.B, "black alone")


func test_done_with_nothing_ticked_answers_nothing() -> void:
	var choice := _ask(5)
	if choice == null:
		return
	screen._on_choice_option(DuelScreen.choice_options(choice).size() - 1)
	assert_not_null(screen.game.awaiting_choice, "a colour must be chosen first")
	screen._on_choice_option(4)
	screen._on_choice_option(DuelScreen.choice_options(choice).size() - 1)
	assert_eq(bear.cur_colors, Mtg.ManaColor.G)


func test_the_ticks_are_shown() -> void:
	var choice := _ask(5)
	if choice == null:
		return
	screen._on_choice_option(3)
	var ticked := false
	for line in screen._choice_overlay.find_children("*", "BaseButton", true, false):
		if (line as BaseButton).get("text") != null and String((line as BaseButton).get("text")).begins_with("4. Red") \
				and String((line as BaseButton).get("text")).ends_with("*"):
			ticked = true
	assert_true(ticked, "the Red line wears its tick")


func test_a_one_colour_question_is_answered_by_its_click() -> void:
	var choice := _ask(0)
	if choice == null:
		return
	assert_eq(DuelScreen.choice_options(choice).size(), 5, "no Done line")
	screen._on_choice_option(1)
	assert_null(screen.game.awaiting_choice)
	assert_eq(bear.cur_colors, Mtg.ManaColor.U)


func test_prismatic_lace_makes_a_permanent_two_colours() -> void:
	var g: MtgGame = screen.game
	var lace := CardInstance.new(CardRegistry.get_card("Prismatic Lace"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[lace.id] = lace
	lace.zone = Mtg.Zone.HAND
	g.players[0].hand.append(lace)
	g.players[0].mana_pool.add(Mtg.ManaColor.U, 1)
	assert_eq(g.cast_spell(0, lace, [TargetRef.card(bear)]), "", "control: the Lace at the Bears")
	g.pass_priority(0)
	g.pass_priority(1)
	var choice: PlayerChoice = g.awaiting_choice
	assert_not_null(choice, "control: the colour question is held")
	if choice == null:
		return
	choice.count = 5      # the engine half (see the class doc)
	screen._build_choice_overlay(choice)
	screen._on_choice_option(0)
	screen._on_choice_option(4)
	screen._on_choice_option(DuelScreen.choice_options(choice).size() - 1)
	assert_null(g.awaiting_choice, "Done answered it")
	assert_eq(bear.cur_colors, Mtg.ManaColor.W | Mtg.ManaColor.G, "white AND green")
