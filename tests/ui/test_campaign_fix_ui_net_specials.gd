extends GameTest
## THE SPECIAL ACTIONS AT AN SGMANALINK TABLE (whole-game campaign, fix-ui:
## w7-3, the duel screen's part).
##
## Sabertooth Cobra's "unless they pay {2} before that step" ransom: the
## local screen offers it on the territory menu and the Cobra's own menu
## and names it on the Situation Bar (Mirage bug pass H1-F1). At a
## networked table `DuelScreen._special_actions` kept only the Pack 9
## kinds (a licid's end, a curse's ignore) of the referee's list, so the
## ransom — and a point of paid prevention, and Channel — was on neither
## menu nor on the bar. Every row the referee lists is now offered, and
## taking one is a `special` message by its index, never an act on the
## projection. (Whether the networked seat's automatic pass HOLDS for it is
## the referee's `respond` flag — the network fixer's half.)

var referee: SgPracticeMatch


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	referee = null
	CardPacks.set_enabled("pack-8", false)


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": 1,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(sent: Array) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([0, 0, 0, 0]))
	# A Stop on their end step keeps the window ours to look at: whether the
	# automatic pass holds there by itself is the referee's `respond` flag,
	# which this file does not test.
	screen.stops.set_marked(PhaseStops.Half.OPPONENTS, PhaseStops.Bar.PHASE,
		DuelScreen._phase_icon_slot(Mtg.Step.END), true)
	viewport.add_child(screen)
	screen.action_requested.connect(func(action: Dictionary) -> void: sent.append(action.duplicate()))
	screen.present(_room(0), true, false)
	return screen


## Seat 1's Cobra bites seat 0; play walks on to seat 1's END step with
## seat 0 holding priority and two untapped Islands to pay with.
func _bitten_at_the_end_step() -> CardInstance:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var cobra := put_battlefield(1, "Sabertooth Cobra")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	run_combat([cobra.id])
	assert_eq(g.settleable_delayed_triggers(0).size(), 1, "control: the ransom is owed")
	for i in 30:
		if g.current_step() == Mtg.Step.END and g.priority_player == 0 and g.stack.is_empty(): break
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.current_step(), Mtg.Step.END)
	assert_eq(g.priority_player, 0)
	return cobra


func _settle_rows(rows: Array) -> Array:
	return rows.filter(func(row: Dictionary) -> bool: return String(row.get("kind", "")) == "settle")


func test_the_territory_menu_lists_the_ransom() -> void:
	_bitten_at_the_end_step()
	var sent: Array = []
	var screen := _screen(sent)
	await get_tree().process_frame
	var rows := _settle_rows(screen._special_actions(0))
	assert_eq(rows.size(), 1, "the referee's ransom row is on the territory menu")
	assert_string_contains(String(rows[0].get("label", "")), "Pay {2}")
	assert_eq(screen._special_action_refusal(0, rows[0]), "", "and it may be taken now")


func test_the_cobras_menu_offers_the_ransom() -> void:
	var cobra := _bitten_at_the_end_step()
	var screen := _screen([])
	await get_tree().process_frame
	var local := screen.game.find_instance(screen.projection.local_id(referee._handle(0, cobra)))
	assert_not_null(local, "the Cobra is on the projected table")
	assert_eq(_settle_rows(screen._special_actions_on(local)).size(), 1,
		"right-click the Cobra: Pay {2}")


func test_the_situation_bar_names_what_is_owed_once() -> void:
	_bitten_at_the_end_step()
	var screen := _screen([])
	await get_tree().process_frame
	var note := screen._special_action_note()
	assert_string_contains(note, "Sabertooth Cobra", "the bar names the ransom")
	assert_false(note.contains("Pay {2}: Sabertooth"), "what is owed, not the menu line again: %s" % note)


func test_taking_the_ransom_is_a_special_message_by_its_index() -> void:
	_bitten_at_the_end_step()
	var sent: Array = []
	var screen := _screen(sent)
	await get_tree().process_frame
	sent.clear()
	var row: Dictionary = _settle_rows(screen._special_actions(0))[0]
	screen._take_special_action(0, row)
	var specials := sent.filter(func(a: Dictionary) -> bool: return String(a.get("op", "")) == "special")
	assert_eq(specials.size(), 1, "one `special` message (sent: %s)" % str(sent))
	if specials.size() == 1:
		assert_eq(int(specials[0].get("index", -1)), int(row["id"]), "by the referee's index")
	assert_eq(g.settleable_delayed_triggers(0).size(), 1,
		"nothing was paid on the projection: the referee does it")
