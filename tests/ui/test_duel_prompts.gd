extends GutTest
## The two moments the engine now HOLDS OPEN for the player, driven through
## the duel screen: the DISCARD PHASE (docs/duel-todo.md §1.1) and the
## COMBAT DAMAGE DIVISION (§1.4). The rules are pinned in the engine suites
## — this pins that the screen enters the mode, uses the original's words,
## and hands the answer back.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
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
		Mtg.Zone.BATTLEFIELD:
			game._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	return inst


# ------------------------------------------------- §1.1 the discard phase --

func test_the_screen_stops_at_the_discard_phase_and_uses_its_words() -> void:
	var game: MtgGame = screen.game
	game.active_player = 0
	var spare: Array[CardInstance] = []
	while game.players[0].hand.size() < 9:
		spare.append(_make(0, "Grizzly Bears", Mtg.Zone.HAND))
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.CLEANUP))
	assert_true(game.awaiting_discard, "the engine stopped")
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.DISCARD, "and so did the screen")
	# `@PROMPT_DISCARDACARD` entry 1, Program/UIStrings.txt:1106.
	assert_string_contains(screen._prompt_label.text, "Select card to discard.")
	screen._on_card_clicked(spare[0])
	screen._on_card_clicked(spare[1])
	assert_eq(game.players[0].hand.size(), 9, "nothing has gone yet")
	screen._on_done()
	assert_eq(game.players[0].hand.size(), 7)
	assert_eq(spare[0].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(spare[1].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_a_misclick_can_be_taken_back() -> void:
	var game: MtgGame = screen.game
	game.active_player = 0
	var spare: Array[CardInstance] = []
	while game.players[0].hand.size() < 8:
		spare.append(_make(0, "Grizzly Bears", Mtg.Zone.HAND))
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.CLEANUP))
	screen._refresh()
	screen._on_card_clicked(spare[0])
	screen._on_card_clicked(spare[0])          # clicked again: deselected
	screen._on_done()
	assert_true(game.awaiting_discard, "Done with nothing picked is refused")
	assert_string_contains(screen._prompt_label.text, "select 1 card")


# ------------------------------------------ §1.4 the combat damage division --

func _gang_block() -> Array:
	var game: MtgGame = screen.game
	var giant := _make(0, "Hill Giant", Mtg.Zone.BATTLEFIELD)
	var first := _make(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var second := _make(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	game.active_player = 0
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	assert_eq(game.declare_attackers(0, [giant.id]), "")
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS))
	game.awaiting_blockers = true
	assert_eq(game.declare_blockers(1,
		{first.id: giant.id, second.id: giant.id}), "")
	return [giant, first, second]


func test_the_screen_runs_the_1997_points_left_loop() -> void:
	var game: MtgGame = screen.game
	var cast := _gang_block()
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_DAMAGE))
	assert_true(game.awaiting_damage_assignment, "the engine stopped")
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.DAMAGE)
	# `@PROMPT_RESOLVECOMBAT` entry 1, Program/UIStrings.txt:999 — verbatim.
	assert_eq(screen._prompt_label.text,
		"Hill Giant: Assign damage to blockers, 3 points left")
	# One click is one point, and the counter counts down.
	screen._on_card_clicked(cast[1])
	assert_string_contains(screen._prompt_label.text, "2 points left")
	screen._on_card_clicked(cast[1])
	assert_string_contains(screen._prompt_label.text, "1 points left")
	# The last point spends itself and the division submits.
	screen._on_card_clicked(cast[2])
	assert_false(game.awaiting_damage_assignment)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_eq(cast[1].zone, Mtg.Zone.GRAVEYARD, "the first blocker took lethal")
	assert_eq(cast[2].damage, 1, "the second took the remainder")


func test_the_order_gates_the_clicks_under_modern_rules() -> void:
	var game: MtgGame = screen.game
	var cast := _gang_block()
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_DAMAGE))
	screen._refresh()
	# CR 510.1c: nothing may be assigned to the second blocker until the
	# first has lethal, so the screen refuses the click instead of letting
	# the engine refuse the whole division later.
	screen._on_card_clicked(cast[2])
	assert_string_contains(screen._prompt_label.text, "Illegal target")
	assert_true(game.awaiting_damage_assignment)


# --------------------------------- §1.3 the choice overlay, every question --

func test_the_very_first_ask_reaches_the_player() -> void:
	var game: MtgGame = screen.game
	assert_true(game.interactive_choices, "a duel with a human in it pre-flights")
	var efreet := _make(0, "Junún Efreet", Mtg.Zone.BATTLEFIELD)
	_make(0, "Swamp", Mtg.Zone.BATTLEFIELD)
	_make(0, "Swamp", Mtg.Zone.BATTLEFIELD)
	game.active_player = 0
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	# The FIRST time the card asks — the half that used to fall through.
	var guard := 0
	while not game.stack.is_empty() and game.awaiting_choice == null and guard < 20:
		game.pass_priority(game.priority_player)
		guard += 1
	assert_not_null(game.awaiting_choice, "the resolution is held for the player")
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD, "and nothing has happened yet")
	assert_eq(game.unanswered_choices.size(), 0, "nobody was overruled")
	var choice: PlayerChoice = game.awaiting_choice
	assert_eq(DuelScreen.choice_options(choice),
		["Pay Upkeep costs.", "Don't pay Upkeep."], "in the original's words")
	# Answer it the way the overlay does — option 2, "Don't pay Upkeep."
	screen._on_choice_option(1)
	assert_null(game.awaiting_choice)
	assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD, "the player declined to pay")
	assert_eq(game.unanswered_choices.size(), 0,
		"and it is the player's decision, not the referee's")


func test_a_colour_question_offers_the_five_colours() -> void:
	var choice := PlayerChoice.new(PlayerChoice.Kind.COLOR, 0, "Choose a color", 0)
	# `@ALCHORS_TOMB` (promptsX2.txt:11) titles it; the colour words are the
	# original's own (UIStrings.txt:610-614).
	assert_eq(DuelScreen.choice_question(choice), "Select a color.")
	assert_eq(DuelScreen.choice_options(choice),
		["White", "Blue", "Black", "Red", "Green"])


func test_a_card_question_lists_the_candidates_and_a_way_out() -> void:
	var game: MtgGame = screen.game
	var choice := PlayerChoice.new(PlayerChoice.Kind.CARD, 0, "Select target card.")
	choice.candidates = [
		_make(0, "Grizzly Bears", Mtg.Zone.HAND),
		_make(0, "Grizzly Bears", Mtg.Zone.HAND),
		_make(0, "Lightning Bolt", Mtg.Zone.HAND),
	]
	# A tutor lists a NAME once, however many copies the library holds.
	assert_eq(DuelScreen.choice_options(choice),
		["Grizzly Bears", "Lightning Bolt"])
	choice.optional = true
	assert_eq(DuelScreen.choice_options(choice),
		["Grizzly Bears", "Lightning Bolt", "Cancel."],
		"a search may fail to find (CR 701.19b), and says so in 1997's word")


func test_a_discard_question_lists_the_hand_and_takes_several_clicks() -> void:
	var choice := PlayerChoice.new(PlayerChoice.Kind.DISCARD, 0,
		"Select card to discard.")
	choice.count = 2
	choice.candidates = [
		_make(0, "Grizzly Bears", Mtg.Zone.HAND),
		_make(0, "Lightning Bolt", Mtg.Zone.HAND),
	]
	assert_eq(DuelScreen.choice_options(choice),
		["Grizzly Bears", "Lightning Bolt"], "every card, duplicates included")
	assert_true(DuelScreen.choice_is_multi(choice), "two clicks, not one")


func test_a_discard_question_takes_one_click_per_card_and_takes_them_back() -> void:
	var game: MtgGame = screen.game
	var human := HumanAgent.new()
	game.set_agent(0, human)
	var bears := _make(0, "Grizzly Bears", Mtg.Zone.HAND)
	var twin := _make(0, "Grizzly Bears", Mtg.Zone.HAND)
	var bolt := _make(0, "Lightning Bolt", Mtg.Zone.HAND)
	var choice := PlayerChoice.new(PlayerChoice.Kind.DISCARD, 0,
		"Select card to discard.")
	choice.count = 2
	choice.candidates = [bears, twin, bolt]
	game.awaiting_choice = choice
	# Two copies of one card are two LINES: clicking line 1 twice must not
	# read as picking two cards, so the second click takes the first back.
	screen._on_choice_option(0)
	screen._on_choice_option(0)
	assert_not_null(game.awaiting_choice, "nothing answered yet")
	screen._on_choice_option(0)
	screen._on_choice_option(1)
	assert_null(game.awaiting_choice, "two picks, one answer")
	assert_true(human.has_parked(), "and it is parked for the resolution")


func test_the_overlay_cannot_be_escaped_only_answered() -> void:
	var game: MtgGame = screen.game
	game.awaiting_choice = PlayerChoice.new(PlayerChoice.Kind.YES_NO, 0, "Pay?", true)
	screen._choice_overlay = Control.new()
	screen.add_child(screen._choice_overlay)
	assert_true(screen._modal_open(), "it owns the keyboard")
	assert_false(screen._can_cancel(),
		"@PROMPT_PAYUPKEEP has two entries and neither is Cancel")
	screen._on_escape()
	assert_not_null(game.awaiting_choice, "Escape does not answer it")
	screen._choice_overlay.queue_free()
	screen._choice_overlay = null
	game.awaiting_choice = null


func test_the_1997_fork_opens_every_blocker_at_once() -> void:
	var game: MtgGame = screen.game
	game.rules.free_damage_assignment = true
	var cast := _gang_block()
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_DAMAGE))
	screen._refresh()
	# Fifth Edition had no damage assignment order: the click loop lets the
	# attacker put the points wherever they like.
	screen._on_card_clicked(cast[2])
	screen._on_card_clicked(cast[2])
	screen._on_card_clicked(cast[1])
	assert_false(game.awaiting_damage_assignment)
	assert_eq(cast[2].zone, Mtg.Zone.GRAVEYARD, "the second blocker took lethal")
	assert_eq(cast[1].damage, 1)


func test_an_upkeep_cost_gets_the_originals_own_buttons() -> void:
	# @PROMPT_PAYUPKEEP (Program/UIStrings.txt:1129) — naming the action
	# beats a bare Yes on the question the player meets every turn.
	assert_eq(DuelScreen.yes_no_labels("Pay {2} for Erg Raiders' upkeep?"),
		["Pay Upkeep costs.", "Don't pay Upkeep."])


func test_other_questions_keep_yes_and_no() -> void:
	# The original's general two-way pair stays for everything else.
	assert_eq(DuelScreen.yes_no_labels("Draw a card?"), ["Yes", "No"])
	assert_eq(DuelScreen.yes_no_labels("Sacrifice a creature?"), ["Yes", "No"])
	# "Pay for attacker" / "Pay for blocker" have their OWN strings and are
	# deliberately not swallowed by the upkeep case.
	assert_eq(DuelScreen.yes_no_labels("Pay for attacker?"), ["Yes", "No"])


# ------------------------------------------------- the fifth kind: OPTION --
#
# docs/duel-todo.md §1.3. `PlayerChoice.Kind.OPTION` — "choose one of these
# labelled things", answered by INDEX — arrived after the overlay shipped,
# and until the overlay had a case for it `DecisionAgent.can_answer` kept it
# away (a kind with no labels would raise a dialog with no buttons and no
# Cancel and stop the duel dead). The overlay has the case now, so these
# pin BOTH halves: the labels, and the gate that lets the question through.

func test_an_option_question_lists_its_own_labels() -> void:
	var choice := PlayerChoice.new(PlayerChoice.Kind.OPTION, 0,
		"Choose Shapeshifter's power", 3)
	choice.options = ["0", "1", "2", "3"]
	assert_eq(DuelScreen.choice_options(choice), ["0", "1", "2", "3"],
		"the caller wrote the labels; the overlay just shows them")


func test_the_human_seat_can_be_asked_an_option_question() -> void:
	# The gate itself. Widening it is what makes the hold legal, and the
	# base agent must stay narrow so a front end without the case is safe.
	var choice := PlayerChoice.new(PlayerChoice.Kind.OPTION, 0, "Pick", 0)
	choice.options = ["a", "b"]
	assert_true(HumanAgent.new().can_answer(choice),
		"the duel overlay has an OPTION case")
	assert_false(DecisionAgent.new().can_answer(choice),
		"and the default stays at the four kinds every front end has")


func test_shapeshifter_asks_the_player_for_its_own_split() -> void:
	# End to end, and it is a BRANCHING hold: the upkeep trigger asks a
	# YES_NO ("you may choose a number") and only then the OPTION. Two holds,
	# one resolution, the second one found by re-probing with the first
	# answer parked.
	var game: MtgGame = screen.game
	var shifter := _make(0, "Shapeshifter", Mtg.Zone.BATTLEFIELD)
	shifter.memory["shape"] = 1
	game.recalculate()
	game.active_player = 0
	# The as-it-enters split is asked by the test's own setup, outside any
	# resolution — one of the fall-through sites (§1.3). Only the UPKEEP
	# re-split is under test, so count from here.
	var already := game.unanswered_choices.size()
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	var guard := 0
	while not game.stack.is_empty() and game.awaiting_choice == null and guard < 20:
		game.pass_priority(game.priority_player)
		guard += 1
	assert_not_null(game.awaiting_choice, "the upkeep trigger is held open")
	assert_eq((game.awaiting_choice as PlayerChoice).kind, PlayerChoice.Kind.YES_NO,
		"the 'you may' comes first")
	screen._on_choice_option(0)   # yes, re-split
	assert_not_null(game.awaiting_choice, "and now the number itself")
	var number: PlayerChoice = game.awaiting_choice
	assert_eq(number.kind, PlayerChoice.Kind.OPTION)
	assert_eq(number.source, "Shapeshifter")
	assert_eq(DuelScreen.choice_options(number).size(), 8, "0 through 7")
	screen._on_choice_option(5)   # a 5/2, which no heuristic would pick here
	assert_null(game.awaiting_choice, "the resolution finished")
	assert_eq(shifter.cur_power, 5, "the player's number, not the referee's")
	assert_eq(shifter.cur_toughness, 2)
	assert_eq(game.unanswered_choices.size(), already,
		"and nothing new was decided on the player's behalf")


# ------------------------------ §1.3 the COST questions, through the screen --
#
# docs/duel-todo.md §1.3's last four rows. A cost is assembled and paid
# BEFORE the spell reaches the stack (CR 601.2h), and a mana ability never
# touches the stack at all (CR 605.3a), so the pre-flight has nothing to
# probe. The engine holds the whole ACTION open instead and re-issues it once
# the answer is parked — from the screen's side that is the same overlay,
# raised by the same _refresh, answered by the same _on_choice_option.

func test_a_casts_additional_cost_reaches_the_overlay() -> void:
	var game: MtgGame = screen.game
	game.active_player = 0
	game.priority_player = 0
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	var bears := _make(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var wall := _make(0, "Wall of Stone", Mtg.Zone.BATTLEFIELD)
	var meta := _make(0, "Metamorphosis", Mtg.Zone.HAND)
	game.players[0].mana_pool.add(Mtg.ManaColor.G, 1)
	assert_eq(game.cast_spell(0, meta, []), "", "the cast is accepted")
	assert_not_null(game.awaiting_choice, "and held open on the question")
	var choice: PlayerChoice = game.awaiting_choice
	assert_true(choice.is_cost, "filed as a COST question, not a resolution's")
	# `@SACRIFICE_CREATURE`, Program/Text.res:2649-2651 — and no `Cancel.`,
	# because a cost's sacrifice is not optional.
	assert_eq(DuelScreen.choice_question(choice),
		"Select creature to sacrifice.")
	assert_eq(DuelScreen.choice_options(choice),
		["Grizzly Bears", "Wall of Stone"])
	screen._refresh()   # headless builds no overlay node, but must not crash
	assert_eq(screen._choice_source_card(choice), meta,
		"showing the spell's own face, found in HAND — it is not cast yet")
	screen._on_choice_option(1)
	assert_null(game.awaiting_choice, "answered")
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "the body the player picked")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "and not the heuristic's")
	assert_eq(meta.zone, Mtg.Zone.STACK, "the cast went through on the replay")
	assert_eq(game.unanswered_choices.size(), 0, "nobody was overruled")


func test_a_mana_abilitys_colour_reaches_the_overlay() -> void:
	# Fellwar Stone. `@FELLWAR_STONE` (Program/prompts.txt:372-374) —
	# `Fellwar Stone: What kind of mana?`, which is `@MULTIMANA`'s
	# `%s: What kind of mana?` (Text.res:2057-2059) with the source's name.
	var game: MtgGame = screen.game
	var stone := _make(0, "Fellwar Stone", Mtg.Zone.BATTLEFIELD)
	_make(1, "Island", Mtg.Zone.BATTLEFIELD)
	_make(1, "Mountain", Mtg.Zone.BATTLEFIELD)
	assert_eq(game.tap_for_mana(0, stone), "")
	assert_not_null(game.awaiting_choice, "the tap is held open")
	var choice: PlayerChoice = game.awaiting_choice
	assert_eq(choice.kind, PlayerChoice.Kind.COLOR)
	assert_eq(DuelScreen.choice_question(choice),
		"Fellwar Stone: What kind of mana?",
		"the source's own line, not the generic `Select a color.`")
	assert_eq(DuelScreen.choice_options(choice), ["Blue", "Red"],
		"and only what the opponent's lands could actually make")
	screen._refresh()
	assert_eq(screen._choice_source_card(choice), stone,
		"showing the source's face")
	screen._on_choice_option(1)
	assert_null(game.awaiting_choice)
	assert_eq(game.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1,
		"the player's colour")
	assert_eq(game.players[0].mana_pool.total(), 1, "and one mana, asked once")


# ------------------------------ §6.10 the refusal names WHAT IS WRONG --

func test_a_misaimed_click_prints_the_1997_reason() -> void:
	# `@PROMPT_ILLEGALTARGET` (UIStrings.txt:1145) is `Illegal target (%s).`
	# and the brackets carry one of `@PROMPT_ILLEGALTARGETWHY`'s 29 words
	# ([constant TargetSpec.WHY]) — the REASON, not the requirement. The
	# requirement is what the prompt above already says.
	var game: MtgGame = screen.game
	var forest := _make(1, "Forest", Mtg.Zone.BATTLEFIELD)
	var terror := _make(0, "Terror", Mtg.Zone.HAND)
	game.active_player = 0
	game.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	game.players[0].mana_pool.add(Mtg.ManaColor.C, 1)
	screen._click_hand_card(terror)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_string_contains(screen._prompt_label.text, "Select ")
	screen._on_card_clicked(forest)
	assert_eq(screen._prompt_label.text, "Illegal target (type).")
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "still aiming")


func test_the_reason_is_never_a_concatenation() -> void:
	# The item said the reasons accumulate into `(type,color,tapped)`.
	# Manalink's own `validate_target_impl` ends every failure in
	# `goto epilog`, so exactly one word is ever printed.
	var game: MtgGame = screen.game
	var knight := _make(1, "Black Knight", Mtg.Zone.HAND)  # pro white, and
	                                                       # in the wrong zone
	var swords := _make(0, "Swords to Plowshares", Mtg.Zone.HAND)
	game.active_player = 0
	game.players[0].mana_pool.add(Mtg.ManaColor.W, 1)
	screen._click_hand_card(swords)
	screen._on_card_clicked(knight)
	assert_eq(screen._prompt_label.text, "Illegal target (where).")
	assert_false(screen._prompt_label.text.contains(","))


# ---------------------- two namesakes on the battlefield (2026-09-02) --

func test_two_namesakes_on_the_battlefield_are_told_apart() -> void:
	# Ashnod's Altar with two Grizzly Bears: the list named "Grizzly
	# Bears" once, and the answer went back by NAME, so the FIRST Bears
	# always died — the tapped one, the pumped one, whichever the player
	# meant. A permanent is listed per object, numbered by the ID tag the
	# card itself can show (Ctrl+T), and answered by instance id; a
	# tutor's library list stays one line per name (the test above).
	var game: MtgGame = screen.game
	var altar := _make(0, "Ashnod's Altar", Mtg.Zone.BATTLEFIELD)
	var first := _make(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var second := _make(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	assert_eq(game.tap_for_mana(0, altar), "")
	var choice: PlayerChoice = game.awaiting_choice
	assert_not_null(choice, "held on the sacrifice")
	assert_eq(DuelScreen.choice_options(choice),
		["Grizzly Bears #%d" % first.id, "Grizzly Bears #%d" % second.id])
	screen._on_choice_option(1)
	assert_null(game.awaiting_choice, "answered")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "the Bears the player pointed at")
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD, "and not its namesake")
	assert_eq(game.players[0].mana_pool.total(), 2, "the Altar's two")
