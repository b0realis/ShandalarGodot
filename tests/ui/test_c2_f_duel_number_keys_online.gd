extends GameTest
## A NUMBER QUESTION AT AN SGMANALINK TABLE (campaign 2026-10-12, finding
## b6-1, the online half). The network view's questions arrive as labels
## only, and the shared overlay drew Land Tax's "Pick up to 3 basic
## lands." as "1. 0" … "4. 3" there too, with the 3 key answering the
## third line (two lands). The labels are read the same way online: each
## line is its number, and the 3 key sends the answer 3.

var referee: SgPracticeMatch
var revision := 1
var commands: Array = []


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	commands.clear()
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.action_requested.connect(_act.bind(screen, seat))
	screen.present(_room(seat), true, false)
	return screen


func _act(action: Dictionary, screen: SgDuelView, seat: int) -> void:
	commands.append(action.duplicate(true))
	var error := referee.act(seat, action)
	if not error.is_empty():
		screen.show_notice(error)
	else:
		revision += 1
	screen.present.call_deferred(_room(seat), true, false)


func _pump() -> void:
	for i in 8:
		await get_tree().process_frame


func _lines(screen: SgDuelView) -> Array:
	var texts: Array = []
	var stack: Array = [screen._choice_overlay]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button:
			texts.append((node as Button).text)
		stack.append_array(node.get_children())
	return texts


func test_the_3_key_answers_3_at_a_network_table() -> void:
	put_battlefield(0, "Land Tax")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	for i in 20:
		if g.awaiting_choice != null or g.stack.is_empty():
			break
		g.pass_priority(g.priority_player)
	assert_not_null(g.awaiting_choice, "control: Land Tax holds its resolution on the count")
	if g.awaiting_choice == null:
		return
	assert_eq(Array(g.awaiting_choice.options), ["0", "1", "2", "3"], "control: a number question")
	var screen := _screen()
	await _pump()
	assert_not_null(screen._choice_overlay, "control: the online overlay is up")
	if screen._choice_overlay == null:
		return
	var texts := _lines(screen)
	assert_has(texts, "3", "the line for 3 reads 3 (lines: %s)" % [texts])
	assert_false(texts.has("4. 3"), "no line reads '4. 3'")
	var key := InputEventKey.new()
	key.keycode = KEY_3
	key.pressed = true
	screen._unhandled_key_input(key)
	await _pump()
	var sent: Array = []
	for action in commands:
		if String(action.get("op", "")) == "choice":
			sent.append(Array(action["picks"]))
	assert_false(sent.is_empty(), "the key sent an answer")
	if not sent.is_empty():
		assert_eq(sent[0], [3], "the 3 key answered 3, not the third line")
