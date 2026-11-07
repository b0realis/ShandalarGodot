extends GutTest
## A LIST OF NAMES SHOWS ITS CARDS (the owner, 2026-11-07): "Bazaar of
## Baghdad card. When a gui window pops up to select cards to discard - a
## large card should show cards you hover over in the list of the gui
## window. All similar selection windows should behave the same as
## sometimes you don't remember a card by name."
##
## The duel's question window (DuelScreen._build_choice_overlay: a discard,
## a search, a pick, a named card), the Sideboard window between duels and
## Test hands' card picker. (The adventure's trade window and the Deck
## Builder's sealed packs already showed the card on hover.)

var screen: DuelScreen


func _duel() -> DuelScreen:
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	duel.config = DuelConfig.hotseat_default()
	duel.config.rng_seed = 92100
	add_child_autofree(duel)
	await get_tree().process_frame
	return duel


func _card(g: MtgGame, pid: int, card_name: String, zone: int) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = zone
	if zone == Mtg.Zone.HAND:
		g.players[pid].hand.append(inst)
	elif zone == Mtg.Zone.BATTLEFIELD:
		g._put_on_battlefield(inst, pid)
	return inst


func _face(duel: DuelScreen) -> CardPreview:
	var found := duel._choice_overlay.find_children("*", "CardPreview", true, false)
	return found[0] if not found.is_empty() else null


func _line(duel: DuelScreen, text: String) -> Button:
	for button: Button in duel._choice_overlay.find_children("*", "Button", true, false):
		if button.text.begins_with(text):
			return button
	return null


func test_bazaars_discard_shows_the_hovered_card_and_then_bazaar_again() -> void:
	screen = await _duel()
	var g := screen.game
	var bazaar := _card(g, 0, "Bazaar of Baghdad", Mtg.Zone.BATTLEFIELD)
	var bears := _card(g, 0, "Grizzly Bears", Mtg.Zone.HAND)
	var bolt := _card(g, 0, "Lightning Bolt", Mtg.Zone.HAND)
	var choice := PlayerChoice.new(PlayerChoice.Kind.DISCARD, 0, "")
	choice.count = 2
	choice.source = "Bazaar of Baghdad"
	choice.candidates = [bears, bolt] as Array[CardInstance]
	screen._build_choice_overlay(choice)
	var face := _face(screen)
	assert_not_null(face, "the window's large card")
	assert_eq(face._shown, bazaar, "the question's own card first")
	var line := _line(screen, "2. Lightning Bolt")
	assert_not_null(line)
	var at := face.position
	line.mouse_entered.emit()
	assert_eq(face._shown, bolt, "the hovered name, big")
	assert_eq(face.position, at, "in its place on the window's left, not over the lines")
	line.mouse_exited.emit()
	assert_eq(face._shown, bazaar, "and the question's card again when the pointer leaves")
	_line(screen, "1. Grizzly Bears").focus_entered.emit()
	assert_eq(face._shown, bears, "the pad's focus shows it too")


func test_a_search_line_shows_the_card_it_names() -> void:
	screen = await _duel()
	var g := screen.game
	var found := _card(g, 0, "Serra Angel", Mtg.Zone.LIBRARY)
	var choice := PlayerChoice.new(PlayerChoice.Kind.CARD, 0, "Search your library for a card.")
	choice.optional = true
	choice.candidates = [found] as Array[CardInstance]
	screen._build_choice_overlay(choice)
	var face := _face(screen)
	assert_not_null(face, "a large card even with no card asking")
	assert_false(face.visible, "nothing to show until a line is hovered")
	_line(screen, "1. Serra Angel").mouse_entered.emit()
	assert_true(face.visible)
	assert_eq(face._shown, found)


func test_a_named_card_option_is_shown_and_a_number_is_not() -> void:
	var named := PlayerChoice.new(PlayerChoice.Kind.OPTION, 0, "Name a card.")
	named.options = ["Shivan Dragon", "7"] as Array[String]
	var dragon := DuelScreen.choice_line_card(named, 0)
	assert_not_null(dragon)
	assert_eq(dragon.data.card_name, "Shivan Dragon")
	assert_null(DuelScreen.choice_line_card(named, 1), "a number is no card")
	var yes_no := PlayerChoice.new(PlayerChoice.Kind.YES_NO, 0, "Pay?")
	assert_false(DuelScreen.choice_lists_cards(yes_no), "a yes/no window lists no cards")


func test_the_sideboard_window_shows_the_hovered_card() -> void:
	var config := DuelConfig.hotseat_default()
	config.best_of = 3
	config.sideboard_between_duels = true
	var deck := DeckList.load_file("res://decks/white_knights.deck", true)
	config.decks[0] = deck.cards.duplicate()
	config.sideboards[0] = deck.sideboard.duplicate()
	config.sideboards[1] = deck.sideboard.duplicate()
	var runner: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	runner.config = config
	add_child_autofree(runner)
	await get_tree().process_frame
	runner._open_sideboard(0)
	assert_not_null(runner._sb_preview)
	var line: Button = null
	for button: Button in runner._sb_dialog.find_children("*", "Button", true, false):
		if button.text.ends_with("Serra Angel"):
			line = button
	assert_not_null(line, "the deck's Serra Angel line")
	line.mouse_entered.emit()
	assert_true(runner._sb_preview.visible)
	assert_eq(runner._sb_preview._shown.data.card_name, "Serra Angel")
	runner._close_sideboard()


func test_test_hands_picker_shows_the_row_under_the_pointer() -> void:
	var config := DuelConfig.hotseat_default()
	var deck := DeckList.load_file("res://decks/white_knights.deck", true)
	config.decks[0] = deck.cards.duplicate()
	config.decks[1] = deck.cards.duplicate()
	var bench: TestHandsScreen = load("res://game/test_hands_screen.tscn").instantiate()
	bench.config = config
	add_child_autofree(bench)
	await get_tree().process_frame
	bench.open_picker(0, DuelPosition.HAND)
	bench._fill_picker()
	for _i in 3:
		await get_tree().process_frame
	assert_gt(bench._picker_list.item_count, 1)
	var motion := InputEventMouseMotion.new()
	motion.position = bench._picker_list.get_item_rect(1).get_center()
	bench._hover_picked(motion)
	assert_eq(bench._picker_preview._shown.data.card_name,
		String(bench._picker_list.get_item_metadata(1)), "the hovered row, big")
	bench.close_picker()
