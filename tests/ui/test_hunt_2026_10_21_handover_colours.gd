extends GameTest
## THE SECOND BUG HUNT (2026-10-21), the handover: "the color or colors of
## your choice" (Dream Coat, Prismatic Lace, Shyft), the engine's half and
## the network table's — the duel screen's half landed earlier today
## (tests/ui/test_hunt_2026_10_21_screens_colors_of_your_choice.gd).
##
## WAS: the three cards asked an ordinary one-colour question, so the duel
## screen offered five lines and the first click was the answer — a player
## could make a creature white, or blue, never white and blue. Shyft asked
## instead with a list of all 32 combinations. At an SGManalink table every
## colour question took exactly one line.
## NOW `DecisionAgent.choose_color(..., several := true)` asks with
## `PlayerChoice.count` 5: the screen ticks colours and `Done.` answers with
## all of them, as one colour mask; Shyft asks whether, then which. A seat
## that answers for itself (the computer, the default agent) still answers
## with its one hint colour — one colour is a legal answer. The network
## table carries the same question as the five colours plus a `Done.` line
## (`SgDuelActions.choice_view`; `count` is how many may be ticked), and
## the host takes any one to five of them.
## AND (item 12): a finished duel at a network table opens no question
## (`SgDuelView._open_choice_overlay`), as the local screen already did.


## Answers every colour question with [member colors] (or its hint) and
## every yes/no with [member yes], keeping the questions it was asked.
class Asked extends DecisionAgent:
	var asked: Array = []
	var colors := 0
	var yes := true

	func answer_color(_game: MtgGame, _pid: int, _prompt: String, hint: int) -> int:
		asked.append(current_choice())
		return colors if colors != 0 else hint

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return yes


var asked: Asked


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	CardRegistry.ensure_loaded()


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func before_each() -> void:
	super.before_each()
	asked = Asked.new()


func _coated(pid: int) -> Array:
	var bear := put_battlefield(pid, "Grizzly Bears")
	var coat := give_hand(pid, "Dream Coat")
	g.attach_aura_from_anywhere(coat, bear, pid)
	return [bear, coat]


# ------------------------------------------------------------ the engine --

func test_dream_coat_asks_for_the_color_or_colors() -> void:
	g.set_agent(0, asked)
	asked.colors = Mtg.ManaColor.W | Mtg.ManaColor.U
	var pair := _coated(0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, pair[1], 0))
	resolve_stack()
	assert_eq(asked.asked.size(), 1)
	var choice: PlayerChoice = asked.asked[0]
	assert_eq(choice.count, 5, "any of the five colours, several at once")
	assert_string_contains(choice.prompt, "color or colors")
	assert_eq((pair[0] as CardInstance).cur_colors, Mtg.ManaColor.W | Mtg.ManaColor.U)


func test_prismatic_lace_asks_for_the_color_or_colors() -> void:
	g.set_agent(0, asked)
	asked.colors = Mtg.ManaColor.R | Mtg.ManaColor.G
	var bear := put_battlefield(0, "Grizzly Bears")
	var lace := give_hand(0, "Prismatic Lace")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq((asked.asked[0] as PlayerChoice).count, 5)
	assert_eq(bear.cur_colors, Mtg.ManaColor.R | Mtg.ManaColor.G)


func test_shyft_asks_whether_then_the_color_or_colors() -> void:
	g.set_agent(0, asked)
	asked.colors = Mtg.ManaColor.W | Mtg.ManaColor.B
	advance_to_step(Mtg.Step.MAIN1)
	var shyft := put_battlefield(0, "Shyft")
	advance_to_next_turn()
	advance_to_next_turn()   # its controller's next upkeep
	assert_eq(asked.asked.size(), 1, "one colour question")
	if asked.asked.is_empty():
		return
	assert_eq((asked.asked[0] as PlayerChoice).count, 5)
	assert_eq(shyft.cur_colors, Mtg.ManaColor.W | Mtg.ManaColor.B, "white and black, indefinitely")
	advance_to_next_turn()
	assert_eq(shyft.cur_colors, Mtg.ManaColor.W | Mtg.ManaColor.B, "the change lasts")


func test_shyft_may_keep_its_colours() -> void:
	g.set_agent(0, asked)
	asked.yes = false
	advance_to_step(Mtg.Step.MAIN1)
	var shyft := put_battlefield(0, "Shyft")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(asked.asked.is_empty(), "declined: no colour is asked")
	assert_eq(shyft.cur_colors, Mtg.ManaColor.U)


func test_a_one_colour_question_stays_one() -> void:
	# Control: Alchor's Tomb's "the color of your choice".
	g.set_agent(0, asked)
	var tomb := put_battlefield(0, "Alchor's Tomb")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tomb, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_lte((asked.asked[0] as PlayerChoice).count, 1, "one colour")


func test_a_seat_answering_for_itself_names_one_colour() -> void:
	# The default agent (and the computer, which keeps it) answers with its
	# hint: one colour, a legal answer to "the color or colors".
	var pair := _coated(0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, pair[1], 0))
	resolve_stack()
	var colors: int = (pair[0] as CardInstance).cur_colors
	assert_true(colors in Mtg.WUBRG, "exactly one colour (it is %d)" % colors)


# -------------------------------------------------------- the duel screen --

func test_the_duel_screen_makes_a_dream_coat_creature_two_colours() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	var game: MtgGame = screen.game
	game._probing = true
	for p in game.players:
		p.hand.clear()
	game.active_player = 0
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	game.priority_player = 0
	game._probing = false
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), game._next_instance_id, 0)
	game._next_instance_id += 1
	game._instances[bear.id] = bear
	game._put_on_battlefield(bear, 0)
	var coat := CardInstance.new(CardRegistry.get_card("Dream Coat"), game._next_instance_id, 0)
	game._next_instance_id += 1
	game._instances[coat.id] = coat
	game.attach_aura_from_anywhere(coat, bear, 0)
	assert_eq(game.activate_ability(0, coat, 0, []), "")
	game.pass_priority(0)
	game.pass_priority(1)
	var choice: PlayerChoice = game.awaiting_choice
	assert_not_null(choice, "control: the colour question is held for the player")
	if choice == null:
		return
	screen._build_choice_overlay(choice)
	var labels := DuelScreen.choice_options(choice)
	assert_eq(labels.back(), DuelScreen.COLORS_DONE, "the engine asked for several")
	screen._on_choice_option(0)          # White
	screen._on_choice_option(1)          # Blue
	screen._on_choice_option(labels.size() - 1)
	assert_null(game.awaiting_choice)
	assert_eq(bear.cur_colors, Mtg.ManaColor.W | Mtg.ManaColor.U)
	await get_tree().process_frame
	await get_tree().process_frame


# ------------------------------------------------------ the network table --

var referee: SgPracticeMatch
var revision := 1


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _act(action: Dictionary, screen: SgDuelView, seat: int) -> void:
	var error := referee.act(seat, action)
	if error.is_empty(): revision += 1
	else: screen.show_notice(error)
	screen.present.call_deferred(_room(seat), true, false)


func _pump() -> void:
	for i in 8: await get_tree().process_frame


## A Dream Coat question held at a network table for seat 0.
func _table_question() -> CardInstance:
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	var pair := _coated(0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, pair[1], 0))
	for i in 4:
		if g.awaiting_choice != null: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice, "control: the question is held")
	return pair[0]


func _table_screen() -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.action_requested.connect(_act.bind(screen, 0))
	screen.present(_room(0), true, false)
	return screen


func test_the_table_offers_the_colours_and_done() -> void:
	_table_question()
	var choice: Dictionary = referee.view(0).choice
	assert_eq(choice.options, ["White", "Blue", "Black", "Red", "Green", DuelScreen.COLORS_DONE])
	assert_eq(int(choice.count), 5, "up to five may be ticked")
	assert_true(SgViewProtocol.choice(choice), "the protocol's own check passes it")


func test_the_table_host_takes_one_to_five_colours() -> void:
	var bear := _table_question()
	assert_ne(referee.act(0, {"op": "choice", "picks": []}), "", "nothing ticked")
	assert_ne(referee.act(0, {"op": "choice", "picks": [5]}), "", "Done. is no colour")
	assert_ne(referee.act(0, {"op": "choice", "picks": [0, 0]}), "", "a repeated colour")
	assert_not_null(g.awaiting_choice, "every refusal left the question open")
	assert_eq(referee.act(0, {"op": "choice", "picks": [0, 3]}), "")
	assert_null(g.awaiting_choice)
	assert_eq(bear.cur_colors, Mtg.ManaColor.W | Mtg.ManaColor.R)


func test_the_table_screen_ticks_colours_then_done() -> void:
	var bear := _table_question()
	var screen := _table_screen()
	await _pump()
	screen._on_choice_option(1)          # Blue: a tick, not an answer
	await _pump()
	assert_not_null(g.awaiting_choice)
	screen._on_choice_option(4)          # Green
	screen._on_choice_option(5)          # Done.
	await _pump()
	assert_null(g.awaiting_choice, "Done. answered it")
	assert_eq(bear.cur_colors, Mtg.ManaColor.U | Mtg.ManaColor.G)


func test_a_one_colour_question_at_the_table_is_one_click() -> void:
	# Control: Alchor's Tomb.
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	var tomb := put_battlefield(0, "Alchor's Tomb")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tomb, 0, [TargetRef.card(bear)]))
	for i in 4:
		if g.awaiting_choice != null: break
		assert_ok(g.pass_priority(g.priority_player))
	var choice: Dictionary = referee.view(0).choice
	assert_eq(choice.options.size(), 5, "no Done. line")
	assert_eq(int(choice.count), 1)
	assert_eq(referee.act(0, {"op": "choice", "picks": [2]}), "")
	assert_eq(bear.cur_colors, Mtg.ManaColor.B)


func test_a_finished_table_opens_no_question() -> void:
	_table_question()
	var screen := _table_screen()
	await _pump()
	screen._close_choice_overlay()
	screen.game.game_over = true
	screen._open_choice_overlay()
	assert_null(screen._choice_overlay, "no question over a finished duel")
