extends GameTest
## THE MINI HELP AND WHAT ARRIVES UNDER IT (repository check 2026-10-13,
## finding c1-1).
##
## At an SGManalink table the duel does not wait under the mini help: the
## other seat plays on, and a question for this seat, a revealed card or the
## End of Duel window can be added to the screen while the panel is up.
## Godot finds a click by TREE ORDER, whatever the z, so a window added
## after the panel took the clicks the panel was drawn over: Close could not
## be clicked, and a click on Close could answer the question underneath.
##
## Now:
## - a question for THIS seat closes the panel, so the question is in front
##   at once, and for a moment ([constant DuelScreen.QUESTION_SETTLE_MS]) it
##   ignores the pointer, so a click already on its way to Close answers
##   nothing;
## - any other window added under the open panel goes under it in the tree
##   too, so the panel keeps the clicks it is drawn over;
## - a window drawn OVER the panel (the Pause window) closes it, as the
##   pause key does.
##
## The question is the 0.50.21 damage-order question (modern rules): a
## Forethought Amulet and a Furnace of Rath both apply to one Lightning Bolt.

var referee: SgPracticeMatch
var revision := 1


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	g.rules.set_preset("modern_mana_burn")
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	referee = null
	CardPacks.set_enabled("pack-9", false)


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.present(_room(seat), true, false)
	return [viewport, screen]


func _pump(frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame


## A real left click at [param at] through the viewport's GUI picking.
func _click_at(viewport: SubViewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		viewport.push_input(ev, true)


## This seat's Bolt at itself; this seat's Amulet and the other seat's
## Furnace both apply, so the damaged player — this seat — is asked.
func _bolt_myself() -> void:
	put_battlefield(0, "Forethought Amulet")
	put_battlefield(1, "Furnace of Rath")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(0))   # the other seat now holds priority


func _open_help(screen: SgDuelView, subject: String, at: Vector2) -> DuelMiniHelp:
	screen._open_mini_help(subject, at)
	assert_true(screen.mini_help_open(), "control: the help is up")
	var help := screen._mini_help
	help._opened_ms -= DuelMiniHelp.SETTLE_MS + 1
	return help


func _is_last(screen: Control, node: Node) -> bool:
	return screen.get_child(screen.get_child_count() - 1) == node


## CONTROL: with nothing arriving, Close clicked through the viewport closes
## the panel.
func test_control_close_is_clickable_through_the_viewport() -> void:
	_bolt_myself()
	var parts := _screen()
	var viewport: SubViewport = parts[0]
	var screen: SgDuelView = parts[1]
	await _pump()
	var help := _open_help(screen, HelpPages.MINI_SPELL_CHAIN, Vector2(400, 260))
	await _pump()
	_click_at(viewport, help._close.get_global_rect().get_center())
	await _pump()
	assert_false(screen.mini_help_open(), "control: Close clicked through the viewport closes it")


func test_a_question_for_this_seat_closes_the_help_and_is_in_front() -> void:
	_bolt_myself()
	var parts := _screen()
	var screen: SgDuelView = parts[1]
	await _pump()
	_open_help(screen, HelpPages.MINI_SPELL_CHAIN, Vector2(400, 260))
	# The other seat passes: the Bolt resolves and the referee holds it on
	# this seat's damage-order question.
	assert_ok(g.pass_priority(1))
	assert_not_null(g.awaiting_choice, "control: a question is held")
	if g.awaiting_choice == null:
		return
	assert_eq(g.awaiting_choice.pid, 0, "control: for this seat")
	assert_string_contains(g.awaiting_choice.prompt, "Which applies first")
	revision += 1
	screen.present(_room(), true, false)
	assert_false(screen.mini_help_open(), "the question closed the help at once")
	assert_not_null(screen._choice_overlay, "and the question is shown")
	await _pump()
	assert_true(_is_last(screen, screen._choice_overlay), "the question is the screen's last window")


func test_the_other_seats_question_leaves_the_help_up() -> void:
	# Mirror image: this seat bolts the other, whose Amulet applies — the
	# other seat is asked, and nothing is shown here.
	put_battlefield(1, "Forethought Amulet")
	put_battlefield(0, "Furnace of Rath")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	var parts := _screen()
	var screen: SgDuelView = parts[1]
	await _pump()
	_open_help(screen, HelpPages.MINI_SPELL_CHAIN, Vector2(400, 260))
	assert_ok(g.pass_priority(1))
	assert_not_null(g.awaiting_choice, "control: a question is held")
	if g.awaiting_choice == null:
		return
	assert_eq(g.awaiting_choice.pid, 1, "control: for the other seat")
	revision += 1
	screen.present(_room(), true, false)
	await _pump()
	assert_null(screen._choice_overlay, "control: nothing to answer here")
	assert_true(screen.mini_help_open(), "the other seat's question leaves the help up")


## The worst case of the finding: the panel stands over the question's
## second line, and the player clicks its Close just as the question
## arrives. The panel has gone; the click must not answer the question.
## Once the question has settled, a click on the same line answers it.
func test_a_click_on_its_way_to_close_answers_nothing() -> void:
	_bolt_myself()
	var parts := _screen()
	var viewport: SubViewport = parts[0]
	var screen: SgDuelView = parts[1]
	var sent: Array = []
	screen.action_requested.connect(func(action: Dictionary) -> void:
		sent.append(action.duplicate(true))
		referee.act(0, action))
	await _pump()
	assert_ok(g.pass_priority(1))
	assert_not_null(g.awaiting_choice, "control: a question is held for this seat")
	if g.awaiting_choice == null:
		return
	revision += 1
	screen.present(_room(), true, false)
	await _pump()
	assert_not_null(screen._choice_overlay, "control: the question is shown")
	# Where the second answer line is drawn.
	var answers: Array = []
	for b in screen._choice_overlay.find_children("*", "BaseButton", true, false):
		if (b as BaseButton).text.begins_with("1. ") or (b as BaseButton).text.begins_with("2. "):
			answers.append(b)
	assert_eq(answers.size(), 2, "control: two answer lines")
	if answers.size() < 2:
		return
	var target: Rect2 = (answers[1] as Control).get_global_rect()
	# Learn where Close sits inside the panel, then open it with its Close
	# over that line.
	var help := _open_help(screen, HelpPages.MINI_LIFE, Vector2(100, 100))
	await _pump()
	var close_off := help._close.get_global_rect().get_center() - help.panel_rect().position
	help.dismiss()
	await _pump()
	screen._close_choice_overlay()
	help = _open_help(screen, HelpPages.MINI_LIFE,
		target.get_center() - close_off - Vector2(DuelMiniHelp.GAP, 0))
	await _pump(2)
	var close_at := help._close.get_global_rect().get_center()
	assert_true(target.has_point(close_at), "control: Close is drawn over answer line 2 (%s in %s)" % [close_at, target])
	# The question comes back the way a new table from the host brings it.
	revision += 1
	screen.present(_room(), true, false)
	assert_false(screen.mini_help_open(), "the question closed the help")
	assert_not_null(screen._choice_overlay, "control: the question is shown again")
	await _pump(2)
	_click_at(viewport, close_at)
	await _pump(2)
	assert_eq(sent, [], "a click on its way to Close sent nothing: %s" % [sent])
	assert_not_null(g.awaiting_choice, "and the question is still open")
	# Settled: the same click is an answer now.
	await get_tree().create_timer(DuelScreen.QUESTION_SETTLE_MS / 1000.0 + 0.1).timeout
	await _pump(2)
	_click_at(viewport, close_at)
	await _pump()
	assert_eq(sent.size(), 1, "after the settle a click on the line answers it")
	if sent.size() == 1:
		assert_eq(String(sent[0].get("op", "")), "choice")


## A window that arrives under the open panel — revealed cards, the End of
## Duel window, anything else added to the screen — goes under it, and
## Close is still the panel's.
func test_a_window_added_while_it_is_open_goes_under_it() -> void:
	var parts := _screen()
	var viewport: SubViewport = parts[0]
	var screen: SgDuelView = parts[1]
	await _pump()
	var help := _open_help(screen, HelpPages.MINI_GRAVEYARD, Vector2(400, 260))
	screen._show_reveal(-1, "Revealed information", ["Forest"])
	assert_true(screen.reveal_window_open(), "control: a reveal window is up")
	assert_true(_is_last(screen, help), "the help stays over the reveal window")
	screen._show_result_window("Amber Owl won")
	assert_true(_is_last(screen, help), "the help stays over the End of Duel window")
	var stray := Control.new()
	stray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(stray)
	assert_true(_is_last(screen, help), "and over anything else added under it")
	assert_true(screen.mini_help_open(), "still open")
	await _pump()
	_click_at(viewport, help._close.get_global_rect().get_center())
	await _pump()
	assert_false(screen.mini_help_open(), "Close clicked through the viewport closes it")
	assert_true(screen.reveal_window_open(), "and the click reached nothing under it")


## A window drawn over the panel — the Pause window, opened here by
## [method SgDuelView.toggle_menu] rather than by the pause key — closes it,
## as the pause key does, so what is drawn on top is what takes the click.
func test_the_pause_window_closes_it() -> void:
	var parts := _screen()
	var screen: SgDuelView = parts[1]
	await _pump()
	_open_help(screen, HelpPages.MINI_HAND, Vector2(400, 260))
	screen.toggle_menu()
	assert_true(screen.is_paused(), "control: the Pause window is up")
	assert_false(screen.mini_help_open(), "the Pause window closed the help")
	await _pump()
	assert_true(_is_last(screen, screen._pause_menu), "and it is the screen's last window")
