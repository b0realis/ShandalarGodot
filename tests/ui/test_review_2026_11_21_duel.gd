extends GutTest
## THE DUEL'S SMOOTHNESS AND ITS SELECTION WINDOWS (review 2026-11-21).
##
## Smoothness: an unchanged card keeps its widget over a redraw (and a kept
## table shows what a rebuilt one would), the engine's verdicts are asked
## once a redraw, the computer's thinking is part of its dwell and a slow
## decision's redraw is the next frame's, a duel's card art is named for
## the warmer, and the large card is not laid out again for the face it
## already shows.
##
## Selection windows: the arrows and the digits do not reach a held
## question under another window, a press of the mouse ends the arrows'
## walk, the tutor picker confirms once, and its selected row can be let
## go again.

var screen: DuelScreen


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)   # Vampiric Tutor, the picker's card
	CardRegistry.ensure_loaded()
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	screen.config.pace = 1000.0   # no dwell fires inside a test
	add_child_autofree(screen)
	await get_tree().process_frame
	get_viewport().gui_release_focus()
	var g: MtgGame = screen.game
	g.active_player = 0
	g.priority_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	screen.mode = DuelScreen.Mode.NORMAL


func after_each() -> void:
	if screen != null and is_instance_valid(screen) and screen.game != null:
		screen.game.awaiting_choice = null
	get_viewport().gui_release_focus()
	CardPacks.set_enabled("pack-8", false)


func _card(pid: int, card_name: String, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.HAND: g.players[pid].hand.append(inst)
		Mtg.Zone.LIBRARY: g.players[pid].library.push_front(inst)
		Mtg.Zone.BATTLEFIELD:
			g._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	return inst


func _press(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	get_viewport().push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)
	await get_tree().process_frame


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


## The table card drawing [param inst], wherever it stands.
func _widget_of(inst: CardInstance) -> MiniCard:
	for found: MiniCard in screen.find_children("*", "MiniCard", true, false):
		if found.instance == inst and not found.is_queued_for_deletion():
			return found
	return null


## What a player could read off the table's rows: every control's kind,
## words, tint, turn and place.
func _reading(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion() or not (child is Control):
			continue
		var c := child as Control
		var line: Array = [c.get_class(), c.visible, c.tooltip_text, c.modulate,
			snappedf(c.rotation_degrees, 0.01), c.position.round(), c.size.round()]
		if c is Label or c is Button:
			line.append(c.get("text"))
		if c is BaseButton:
			line.append((c as BaseButton).disabled)
		if c is TextureRect:
			line.append((c as TextureRect).texture)
		out.append(line)
		_reading(c, out)


func _table_reading() -> Array:
	var out: Array = []
	for pid in 2:
		for row in screen._field_rows[pid]:
			_reading(screen._field_rows[pid][row], out)
		_reading(screen._free_layers[pid], out)
	for hand in screen._hand_rows:
		_reading(hand, out)
	return out


# ------------------------------------------- 1. the table kept over a redraw --

func _busy_table() -> Dictionary:
	var out := {}
	out["lands"] = []
	for i in 6:
		out["lands"].append(_card(0, "Forest", Mtg.Zone.BATTLEFIELD))
	out["bear"] = _card(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	out["angel"] = _card(0, "Serra Angel", Mtg.Zone.BATTLEFIELD)
	out["lion"] = _card(1, "Savannah Lions", Mtg.Zone.BATTLEFIELD)
	out["theirs"] = _card(1, "Plains", Mtg.Zone.BATTLEFIELD)
	out["held"] = _card(0, "Giant Growth", Mtg.Zone.HAND)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	return out


func test_an_unchanged_card_keeps_its_widget_over_a_redraw() -> void:
	var table := await _busy_table()
	var bear := _widget_of(table["bear"])
	var lion := _widget_of(table["lion"])
	var held := _widget_of(table["held"])
	assert_not_null(bear, "control: the bear is drawn")
	assert_not_null(held, "control: the hand's card is drawn")
	var built := screen.slots_built
	(table["lands"][0] as CardInstance).tapped = true
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	assert_eq(_widget_of(table["bear"]), bear, "the bear's own widget stands")
	assert_eq(_widget_of(table["lion"]), lion, "the other side's card too")
	assert_eq(_widget_of(table["held"]), held, "and the card in hand: its hover and tooltip stay")
	assert_gt(screen.slots_kept, 0, "control: slots were kept")
	assert_lte(screen.slots_built - built, 1, "only the pile whose land turned was built again")


func test_a_kept_table_reads_as_a_rebuilt_one_after_each_change() -> void:
	var table := await _busy_table()
	var g: MtgGame = screen.game
	var bear: CardInstance = table["bear"]
	var angel: CardInstance = table["angel"]
	var changes: Array[Callable] = [
		func() -> void: (table["lands"][1] as CardInstance).tapped = true,
		func() -> void: bear.damage = 1,
		func() -> void: angel.tapped = true,
		func() -> void: bear.counters["+1/+1"] = 2,
		func() -> void: angel.tapped = false,
		func() -> void: (table["lion"] as CardInstance).summoning_sick = true,
		func() -> void: _card(0, "Llanowar Elves", Mtg.Zone.BATTLEFIELD),
		func() -> void: g.players[0].mana_pool.add(Mtg.ManaColor.G, 1),
		func() -> void:
			g.players[0].hand.erase(table["held"])
			(table["held"] as CardInstance).zone = Mtg.Zone.GRAVEYARD
			g.players[0].graveyard.append(table["held"]),
	]
	for at in changes.size():
		changes[at].call()
		g.recalculate()
		screen.keep_table_widgets = true
		screen._refresh()
		await get_tree().process_frame
		var kept := _table_reading()
		screen.keep_table_widgets = false
		screen._refresh()
		await get_tree().process_frame
		var rebuilt := _table_reading()
		assert_eq(kept.size(), rebuilt.size(), "change %d: as many controls kept as rebuilt" % at)
		if kept.size() == rebuilt.size():
			for i in kept.size():
				if kept[i] != rebuilt[i]:
					assert_eq(str(kept[i]), str(rebuilt[i]), "change %d, control %d" % [at, i])
					break
		assert_eq(kept.hash(), rebuilt.hash(), "change %d: the kept table reads as the rebuilt one" % at)
	screen.keep_table_widgets = true


func test_a_kept_card_does_not_hold_the_keys() -> void:
	var table := await _busy_table()
	var bear := _widget_of(table["bear"])
	bear.grab_focus()   # what a click does to a button
	assert_eq(_focused(), bear, "control: the clicked card holds the keys")
	screen._refresh()
	assert_null(_focused(), "the redraw lets them go, as it did when it freed the card")
	assert_eq(_widget_of(table["bear"]), bear, "control: and the card was kept")


func test_a_pile_keeps_its_rows_until_its_shape_moves() -> void:
	var cards: Array = []
	for i in 3:
		cards.append(_card(0, "Forest", Mtg.Zone.BATTLEFIELD))
	var pile := CardPile.new()
	add_child_autofree(pile)
	var click := func(_inst: CardInstance) -> void: pass
	var light := func(_inst: CardInstance) -> int: return MiniCard.Highlight.NONE
	pile.keeps_rows = true
	pile.populate(cards, false, click, light)
	var row := pile.get_child(0)
	pile.populate(cards, false, click, light)
	assert_eq(pile.get_child(0), row, "asked for the same pile again, the rows stand")
	assert_eq(pile.kept_count, 1)
	(cards[1] as CardInstance).tapped = true
	assert_false(pile.redress(), "a land turned: the pile's shape moved")
	pile.populate(cards, false, click, light)
	assert_eq(pile.built_count, 2, "and it is built again")
	assert_true(pile.redress(), "which then stands")
	var plain := CardPile.new()
	add_child_autofree(plain)
	plain.populate(cards, false, click, light)
	plain.populate(cards, false, click, light)
	assert_eq(plain.built_count, 2, "a pile nobody asked to keep its rows rebuilds, as before")


# ------------------------------------------------- 2. the computer's dwell --

class SlowSeat:
	extends RefCounted
	var acted := 0
	var thinks_msec := 0
	func act(game: MtgGame) -> String:
		acted += 1
		if thinks_msec > 0:
			OS.delay_msec(thinks_msec)
		game.state_changed.emit()
		return "thought"


func test_the_thinking_comes_off_the_dwell() -> void:
	assert_almost_eq(DuelScreen.dwell_after_thinking(0.35, 0.1), 0.25, 0.0001)
	assert_eq(DuelScreen.dwell_after_thinking(0.35, 2.0), 0.0, "never less than nothing")
	assert_eq(DuelScreen.dwell_after_thinking(0.35, 0.0), 0.35, "a quick decision changes nothing")
	assert_false(DuelScreen.redraws_next_frame(0.005), "a quick decision is drawn at once")
	assert_true(DuelScreen.redraws_next_frame(0.05), "a slow one leaves its redraw to the next frame")


func _computers_turn(seat: SlowSeat) -> void:
	var g: MtgGame = screen.game
	screen._ais[1] = seat
	g.active_player = 1
	g.priority_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	screen._ai_pending = false


func test_a_slow_decision_is_drawn_on_the_next_frame_and_once() -> void:
	var seat := SlowSeat.new()
	seat.thinks_msec = 50
	_computers_turn(seat)
	screen.split_slow_decisions = true
	var before := screen.refresh_count
	screen._ai_step()
	assert_eq(seat.acted, 1, "control: the computer acted")
	assert_eq(screen.refresh_count, before, "its redraw is not in the frame the thinking froze")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(screen.refresh_count, before + 1, "the next frame draws it, once")
	assert_gte(screen._ai_thought_seconds + 1.0, 1.0, "control: the time is a number")


func test_a_quick_decision_is_drawn_at_once() -> void:
	var seat := SlowSeat.new()
	_computers_turn(seat)
	screen.split_slow_decisions = true
	var before := screen.refresh_count
	screen._ai_step()
	assert_eq(screen.refresh_count, before + 1, "drawn in the step itself, as before")


# ------------------------------------------- 3. one verdict a card a redraw --

func test_the_verdicts_are_kept_for_one_redraw_only() -> void:
	var elves := _card(0, "Llanowar Elves", Mtg.Zone.BATTLEFIELD)
	var growth := _card(0, "Giant Growth", Mtg.Zone.HAND)
	_card(0, "Forest", Mtg.Zone.BATTLEFIELD)
	screen.game.recalculate()
	screen._refresh()
	assert_false(screen._verdicts_live, "no verdict outlives the redraw")
	assert_true(screen._verdicts.is_empty())
	var hits := screen.verdict_hits
	assert_eq(screen._payable_now(0, growth), screen._payable_now_fresh(0, growth))
	assert_eq(screen.verdict_hits, hits, "a question outside a redraw is asked of the engine")
	# Inside one, the second asking is the kept answer — and it is the fresh one.
	screen._begin_verdicts()
	var first := screen._payable_now(0, growth)
	var again := screen._payable_now(0, growth)
	assert_eq(screen.verdict_hits, hits + 1, "the second asking is served from the first")
	assert_eq(again, first)
	assert_eq(first, screen._payable_now_fresh(0, growth), "and equals the engine's own")
	assert_eq(screen._activation_refusal_now(0, elves, 0), screen.game.activation_refusal(0, elves, 0))
	# The engine moves: every kept verdict goes.
	for land in screen.game.players[0].battlefield:
		land.tapped = true
	screen.game.recalculate()
	assert_true(screen._verdicts.is_empty(), "an announced change drops them all")
	assert_eq(screen._payable_now(0, growth), screen._payable_now_fresh(0, growth),
		"so the answer after the change is the engine's")
	assert_false(screen._payable_now(0, growth), "control: nothing left to pay with")
	screen._end_verdicts()


func test_a_redraw_asks_each_verdict_once() -> void:
	_card(0, "Prodigal Sorcerer", Mtg.Zone.BATTLEFIELD)
	_card(0, "Island", Mtg.Zone.BATTLEFIELD)
	_card(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var g: MtgGame = screen.game
	g.recalculate()
	# The opponent's spell on the chain: the automatic pass asks what the
	# player could answer with, after the table asked the same.
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	var hits := screen.verdict_hits
	screen._begin_verdicts()
	var could := screen._could_respond(0)
	assert_eq(screen._could_respond(0), could)
	screen._end_verdicts()
	assert_gt(screen.verdict_hits, hits, "the second asking read the kept verdicts")
	assert_eq(screen._could_respond(0), could, "and the fresh answer is the same")


# ------------------------------------------------- 4. the duel's art, named --

func test_the_duels_card_names_for_the_warmer() -> void:
	var g: MtgGame = screen.game
	var names := DuelScreen.table_art_names(g, 0)
	assert_lte(names.size(), CardArtWarmer.MOST, "never more than the warmer takes")
	var seen := {}
	for card_name in names:
		assert_false(seen.has(card_name), "%s is named once" % card_name)
		seen[card_name] = true
	for inst in g.players[0].hand:
		assert_true(seen.has(MiniCard.art_name(inst)), "the hand's %s is named" % inst.data.card_name)
	if not g.players[0].hand.is_empty():
		assert_eq(names[0], MiniCard.art_name(g.players[0].hand[0]), "the viewer's hand comes first")
	for pid in 2:
		for inst in g.players[pid].library:
			if names.size() < CardArtWarmer.MOST:
				assert_true(seen.has(MiniCard.art_name(inst)), "seat %d's library is named" % pid)


# ----------------------------------------------------- 6. the large card --

func test_the_large_card_is_not_laid_out_again_for_the_face_it_shows() -> void:
	var bear := _card(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var angel := _card(0, "Serra Angel", Mtg.Zone.BATTLEFIELD)
	var face := CardPreview.new()
	face.docked = true
	add_child_autofree(face)
	face.show_card(bear)
	assert_eq(face.same_face_hits, 0)
	face.show_card(bear)
	assert_eq(face.same_face_hits, 1, "the same card again: the face stands")
	face.show_card(angel)
	assert_eq(face.same_face_hits, 1, "another card is laid out")
	assert_eq(face._name_label.text, "Serra Angel")
	face.show_card(bear)
	assert_eq(face._name_label.text, "Grizzly Bears", "and back")
	face.show_back()
	face.show_card(bear)
	assert_eq(face.same_face_hits, 1, "after the back, the face is laid out again")
	face.set_text_expanded(not face.text_is_expanded())
	assert_eq(face.same_face_hits, 1, "and after the text box changed")
	face.visible = false
	face.show_card(bear)
	assert_true(face.visible, "a hidden card is shown again")


func test_a_kept_fit_equals_the_measured_one() -> void:
	CardPreview.forget_measures()
	var font := ThemeDB.fallback_font
	var sizes := [17, 15, 13, 11, 9]
	for text in ["Grizzly Bears", "Asmoranomardicadaistinaculdacar the Long-Named", "Ow"]:
		for width in [60.0, 120.0, 240.0]:
			var fresh := CardPreview._fit_one_line_fresh(font, text, width, sizes)
			assert_eq(CardPreview._fit_one_line(font, text, width, sizes), fresh, "first asked")
			assert_eq(CardPreview._fit_one_line(font, text, width, sizes), fresh, "and kept")
	var rules := "Flying, vigilance\nWhenever this attacks, it stays where it is."
	var measured := ManaText.measure(rules, font, 13, 180.0, 2)
	assert_eq(CardPreview._wrapped_height(font, rules, 180.0, 13, 2), measured)
	assert_eq(CardPreview._wrapped_height(font, rules, 180.0, 13, 2), measured, "kept")
	assert_ne(CardPreview._wrapped_height(font, rules, 90.0, 13, 2), measured,
		"another width is another measure")


# ------------------------------------------ a-c. the held question's keys --

func _discard_question() -> void:
	var g: MtgGame = screen.game
	var bears := _card(0, "Grizzly Bears", Mtg.Zone.HAND)
	var bolt := _card(0, "Lightning Bolt", Mtg.Zone.HAND)
	var choice := PlayerChoice.new(PlayerChoice.Kind.DISCARD, 0, "")
	choice.count = 2
	choice.source = "Bazaar of Baghdad"
	choice.candidates = [bears, bolt] as Array[CardInstance]
	g.awaiting_choice = choice
	screen._choice_picks = PackedInt32Array()
	screen._choice_walking = false
	screen._choice_focus = -1
	screen._build_choice_overlay(choice)


func _line(text: String) -> Button:
	for button: Button in screen._choice_overlay.find_children("*", "Button", true, false):
		if button.text.begins_with(text):
			return button
	return null


func test_the_arrows_and_digits_stay_out_of_a_question_under_another_window() -> void:
	_discard_question()
	screen._ask_to_concede()
	assert_true(screen._window_above_selection(), "control: the concede question is above")
	await _press(KEY_DOWN)
	var held := _focused()
	assert_false(held != null and screen._choice_overlay.is_ancestor_of(held),
		"Down gives no line of the question under it the keys")
	assert_false(screen._choice_walking, "and starts no walk there")
	await _press(KEY_1)
	assert_true(screen._choice_picks.is_empty(), "a digit answers nothing through the window above")
	screen._cancel_concede()
	await get_tree().process_frame
	assert_false(screen._window_above_selection(), "control: the window is gone")
	await _press(KEY_1)
	assert_eq(Array(screen._choice_picks), [0], "and the digit is the question's again")


func test_a_mouse_press_ends_the_arrows_walk() -> void:
	_discard_question()
	await _press(KEY_DOWN)
	assert_true(screen._choice_walking, "control: the arrows walk the lines")
	var line := _line("2. Lightning Bolt")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	line.gui_input.emit(press)
	assert_false(screen._choice_walking, "a press of the mouse ends the walk")
	line.grab_focus()   # what the click does to the button
	line.pressed.emit()
	assert_eq(Array(screen._choice_picks), [1], "control: the click ticked its line")
	await get_tree().process_frame
	assert_null(_focused(), "the redraw gives the clicked line no keys")
	await _press(KEY_SPACE)
	assert_eq(Array(screen._choice_picks), [1], "so a later Space unticks nothing")


# --------------------------------------------------- d-e. the tutor picker --

func _open_vampiric_tutor() -> CardInstance:
	_card(0, "Serra Angel", Mtg.Zone.LIBRARY)
	_card(0, "Ancestral Recall", Mtg.Zone.LIBRARY)
	var tutor := _card(0, "Vampiric Tutor", Mtg.Zone.HAND)
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	screen._click_hand_card(tutor)
	return tutor


func test_the_picker_confirms_once() -> void:
	var tutor := _open_vampiric_tutor()
	assert_not_null(screen._search_dialog, "control: the picker is up")
	screen._search_list.select(0)
	var wanted := screen._search_list.get_item_text(0)
	screen._on_search_confirmed()
	assert_null(screen._search_dialog, "control: the first OK closed it")
	assert_eq(tutor.zone, Mtg.Zone.STACK, "control: the cast went on")
	var lines := screen.game.log_lines.size()
	screen._on_search_confirmed()   # a second OK in the same frame
	assert_eq(screen.game.log_lines.size(), lines, "the second does nothing")
	assert_eq(screen.game.stack.size(), 1, "one cast")
	assert_eq(screen._humans[0]._preselected_name, wanted, "with the row the first OK took")


func test_the_pickers_selected_row_can_be_let_go() -> void:
	var tutor := _open_vampiric_tutor()
	await _press(KEY_DOWN)
	assert_eq(Array(screen._search_list.get_selected_items()), [0], "control: the first arrow selects a row")
	await _press(KEY_SPACE)
	assert_true(screen._search_list.get_selected_items().is_empty(),
		"the select key on the selected row lets it go")
	assert_not_null(screen._search_dialog, "and is not the OK")
	assert_eq(screen._search_face._shown, tutor, "the large card is the tutor's again")
	screen._on_search_confirmed()
	assert_eq(tutor.zone, Mtg.Zone.STACK, "OK with nothing chosen casts")
	assert_eq(screen._humans[0]._preselected_name, HumanAgent.DECLINED_PICK,
		"and parks the decline: the search may fail to find")


func test_which_presses_let_the_pickers_row_go() -> void:
	var list := ItemList.new()
	add_child_autofree(list)
	list.size = Vector2(200, 200)
	list.add_item("Ancestral Recall")
	list.add_item("Serra Angel")
	await get_tree().process_frame
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = list.get_item_rect(0).get_center()
	assert_false(DuelScreen.search_list_deselects(list, click), "nothing selected: a click selects")
	list.select(0)
	assert_true(DuelScreen.search_list_deselects(list, click), "a click on the selected row lets it go")
	click.position = list.get_item_rect(1).get_center()
	assert_false(DuelScreen.search_list_deselects(list, click), "a click on another row selects that one")
	click.position = list.get_item_rect(0).get_center()
	click.double_click = true
	assert_false(DuelScreen.search_list_deselects(list, click), "a double click is still the OK")
	var motion := InputEventMouseMotion.new()
	assert_false(DuelScreen.search_list_deselects(list, motion), "the pointer moving lets nothing go")
