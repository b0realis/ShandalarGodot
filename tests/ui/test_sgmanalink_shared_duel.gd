extends GameTest
## Parity is structural: the real DuelScreen drives a detached projection.

var referee: SgPracticeMatch
var revision := 1
var commands: Array = []
var refusals: Array = []


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	commands.clear()
	refusals.clear()
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
		refusals.append(error)
		screen.show_notice(error)
	else: revision += 1
	screen.present.call_deferred(_room(seat), true, false)


func _pump() -> void:
	for i in 8: await get_tree().process_frame


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


func test_online_is_the_actual_duel_screen_with_private_projection() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var own := give_hand(1, "Craw Wurm")
	give_hand(0, "Durkwood Boars")
	put_battlefield(0, "Giant Spider")
	var bear := put_battlefield(1, "Grizzly Bears")
	var screen := _screen(1)
	await _pump()
	assert_true(screen is DuelScreen)
	assert_true(screen.game is SgDuelProjection)
	assert_ne(screen.game, g)
	assert_eq(screen.game.players[0].hand[0].data.card_name, own.data.card_name)
	assert_eq(screen.game.players[1].hand[0].data.card_name, "Unknown card")
	assert_eq(screen.game.players[0].battlefield[0], _local(screen, bear))
	assert_ne(_local(screen, own), own)
	assert_eq(_local(screen, own).owner_id, 0)
	assert_eq(screen._field_rows.size(), 2)
	assert_not_null(screen._card_preview)
	assert_not_null(screen._flight)
	assert_not_null(screen._audio)
	assert_eq(screen._ais.size(), 0, "a remote human is never an AI agent")
	for node in screen.find_children("*", "Button", true, false):
		if node is MiniCard:
			assert_ne(node.instance.data.card_name, "Durkwood Boars")
	for card in screen.game.players[1].library: assert_eq(card.data.card_name, "Unknown card")


func test_online_hack_reminders_survive_the_wire_for_either_seat(seat = use_parameters([0, 1])) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var swamp := put_battlefield(0, "Swamp")
	var knight := put_battlefield(1, "Black Knight")
	var plains := put_battlefield(1, "Plains")
	var circle := put_battlefield(0, "Circle of Protection: Red")
	g.change_text(swamp, "land_type", "swamp", "island")
	g.change_text(knight, "color_word", Mtg.ManaColor.W, Mtg.ManaColor.G)
	g.change_text(plains, "mana_color", Mtg.ManaColor.W, Mtg.ManaColor.C)
	circle.memory["shaman_circle_color"] = Mtg.ManaColor.G
	var screen := _screen(seat)
	var wire: Dictionary = JSON.parse_string(JSON.stringify(_room(seat)))
	assert_true(SgViewProtocol.room(wire))
	screen.present(wire, true, false)
	await _pump()
	var ghosts := screen.find_children("TextChangeGhost*", "", true, false)
	assert_eq(ghosts.size(), 4)
	var expectations := {
		"Magical Hack": "Swamp becomes Island",
		"Sleight of Mind": "White becomes Green",
		"Quarum Trench Gnomes": "White becomes Colorless",
		"Balduvian Shaman": "Cumulative upkeep {1}",
	}
	for ghost in ghosts:
		assert_true(expectations.has(ghost.instance.data.card_name))
		assert_string_contains(ghost.tooltip_text, expectations.get(ghost.instance.data.card_name, "MISSING"))
		assert_true(ghost.disabled)
		ghost.mouse_entered.emit()
		assert_eq(screen._card_preview._shown, ghost.instance)
	assert_true(_local(screen, swamp).text_changes.is_empty(), "only presentation metadata, no client rules mutation")
	assert_true(commands.is_empty(), "hovering reminders never sends an action")
	for card in [swamp, knight, plains, circle]: g.return_to_hand(card)
	revision += 1
	screen.present(_room(seat), true, false)
	await _pump()
	assert_true(screen.find_children("TextChangeGhost*", "", true, false).is_empty())


func test_online_protection_badges_map_both_seats_and_clear_live(seat = use_parameters([0, 1])) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(0, "Hill Giant")
	g.players[1].reverse_damage_sources.append(giant.id)
	var screen := _screen(seat)
	await _pump()
	var protected_pid := screen.projection.local_seat(1)
	var badge: PlayerProtectionBadge = screen._protection_badges[protected_pid]
	assert_true(badge.visible)
	assert_false(screen._protection_badges[1 - protected_pid].visible)
	assert_string_contains(badge.tooltip_text, "Hill Giant")
	assert_true(badge.get_parent().get_global_rect().encloses(badge.get_global_rect()), "badge stays within portrait")
	badge.open_details()
	assert_not_null(badge._dialog)
	assert_true(commands.is_empty(), "reading public shields never sends a game command")
	assert_true(screen._modal_open())
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	screen._on_control(enter)
	assert_true(commands.is_empty(), "Return must not advance the duel behind the details")
	screen._on_escape()
	assert_false(badge.details_open())
	badge.open_details()
	var detached := screen.projection.player_damage_effects(protected_pid)
	detached.clear()
	assert_false(screen.projection.player_damage_effects(protected_pid).is_empty())
	g.deal_damage(giant, TargetRef.player(1), 3)
	revision += 1
	screen.present(_room(seat), true, false)
	await _pump()
	assert_false(badge.visible)
	assert_null(badge._dialog)


func test_auto_payment_waits_for_color_and_resumes_once() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bears := give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Fellwar Stone")
	put_battlefield(1, "Mountain")
	put_battlefield(1, "Island")
	var screen := _screen()
	screen._on_card_clicked(_local(screen, bears))
	screen._auto_cast(_local(screen, bears))
	await _pump()
	assert_not_null(g.awaiting_choice)
	assert_eq(commands.size(), 2, "only prepare and autopay before the question")
	assert_eq(refusals, [])
	screen._on_choice_option(0)
	await _pump()
	assert_null(g.awaiting_choice)
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack[0].card, bears)
	assert_eq(commands.filter(func(action: Dictionary) -> bool: return action.op == "submit").size(), 1)
	assert_eq(refusals, [])


func test_auto_x_respects_reserved_sources_and_payment_multipliers() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var fireball := give_hand(0, "Fireball")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var reserved := put_battlefield(0, "Mountain")
	var screen := _screen()
	screen._no_auto_tap[_local(screen, reserved).id] = true
	screen._on_card_clicked(_local(screen, fireball))
	screen._auto_cast(_local(screen, fireball))
	await _pump()
	assert_eq(screen._pending_x, 1)
	assert_false(reserved.tapped)
	assert_eq(g.players[0].mana_pool.total(), 2)
	screen._on_life_clicked(1)
	await _pump()
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack[0].x_value, 1)
	assert_eq(refusals, [])


func test_online_journal_is_private_deduplicated_and_live() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var forest := give_hand(0, "Forest")
	var screen := _screen()
	screen._open_duel_log()
	screen._on_card_clicked(_local(screen, forest))
	await _pump()
	assert_string_contains("\n".join(screen.game.log_lines), "plays Forest")
	var count := screen.game.log_lines.size()
	screen.present(_room(), true, false)
	assert_eq(screen.game.log_lines.size(), count)
	g.reveal_information(0, "Private look", ["Black Lotus"])
	g.log_line("SECRET seed and opponent hand: Ancestral Recall")
	assert_string_contains(JSON.stringify(referee.view(0).journal), "Black Lotus")
	assert_false(JSON.stringify(referee.view(1).journal).contains("Black Lotus"))
	assert_false(JSON.stringify(referee.view(0).journal).contains("Ancestral Recall"))


func test_projection_reuses_anonymous_slots_without_secret_identity() -> void:
	var projection := SgDuelProjection.new()
	projection.ingest(_room())
	var slot: CardInstance = projection.players[1].library[0]
	projection.ingest(_room())
	assert_same(projection.players[1].library[0], slot)
	assert_eq(slot.id, -1)
	assert_false(slot.has_meta("sg_handle"))
	assert_eq(slot.data.card_name, "Unknown card")


func test_nonpayment_refusal_stops_retries_and_allows_new_target() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	var bears := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R)
	var screen := _screen()
	screen._on_card_clicked(_local(screen, bolt))
	await _pump()
	screen._pending_slot = screen._pending_slots.size()
	screen._send({"op":"submit", "targets":[["no-longer-offered", 0]]})
	await _pump()
	var count := commands.size()
	assert_eq(refusals.size(), 1)
	screen.present(_room(), true, false)
	await _pump()
	assert_eq(commands.size(), count, "a refusal never automatically submits again")
	screen._on_card_clicked(_local(screen, bears))
	await _pump()
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack[0].card, bolt)


func test_manual_double_x_dialog_uses_payment_units() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var part_water := give_hand(0, "Part Water")
	for i in 5: put_battlefield(0, "Island")
	var screen := _screen()
	screen._on_card_clicked(_local(screen, part_water))
	assert_not_null(screen._x_dialog)
	screen._x_spin.value = 4
	screen._on_x_confirmed()
	await _pump()
	assert_eq(screen._pending_x, 2, "five mana can pay {X}{X}{U} with X=2")


func test_click_target_then_tap_mana_preserves_the_spell_and_casts_once() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	var mountain := put_battlefield(0, "Mountain")
	var bear := put_battlefield(1, "Grizzly Bears")
	var screen := _screen()
	screen._on_card_clicked(_local(screen, bolt))
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_null(screen._x_dialog)
	screen._on_card_clicked(_local(screen, bear))
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	assert_eq(screen._pending_card, _local(screen, bolt))
	screen._on_card_clicked(_local(screen, mountain))
	await _pump()
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack[0].card, bolt)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_null(screen._pending_card)
	assert_eq(screen.game.stack[0].card, _local(screen, bolt))
	assert_string_contains(screen.game.stack[0].description, "Grizzly Bears")
	assert_true(mountain.tapped)
	assert_eq(commands.filter(func(a: Dictionary) -> bool: return a.op == "submit").size(), 2, "one unpaid attempt, one paid cast")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_double_click_autopays_without_replacing_target_selection() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	var mountain := put_battlefield(0, "Mountain")
	var bear := put_battlefield(1, "Grizzly Bears")
	var screen := _screen()
	var card := _local(screen, bolt)
	screen._on_card_clicked(card)
	screen._auto_cast(card)
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_true(mountain.tapped)
	screen._on_card_clicked(_local(screen, bear))
	await _pump()
	assert_eq(g.stack.size(), 1)
	assert_eq(refusals, [])


func test_shared_combat_window_and_click_damage_assignment() -> void:
	g.rules.free_damage_assignment = true
	var wurm := put_battlefield(0, "Craw Wurm")
	var first := put_battlefield(1, "Grizzly Bears")
	var second := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var screen := _screen()
	screen._on_card_clicked(_local(screen, wurm))
	assert_eq(screen._selected_attackers, [_local(screen, wurm).id])
	assert_not_null(screen._combat_window)
	screen._on_done()
	await _pump()
	for i in 8:
		if g.awaiting_blockers: break
		assert_ok(g.pass_priority(g.priority_player))
	var opponent := _screen(1)
	for bear in [first, second]:
		opponent._on_card_clicked(_local(opponent, bear))
		opponent._on_card_clicked(_local(opponent, wurm))
	assert_eq(opponent._block_map.size(), 2)
	opponent._on_done()
	await _pump()
	for i in 8:
		if g.awaiting_damage_assignment: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_damage_assignment, str(Mtg.Step.keys()[g.current_step()]))
	assert_true(SgViewProtocol.room(_room()), str(_room().game.presentation))
	revision += 1
	screen.present(_room(), true, false)
	assert_eq(screen.mode, DuelScreen.Mode.DAMAGE)
	for i in 3: screen._on_card_clicked(_local(screen, first))
	assert_eq(screen._pending_damage_for(_local(screen, first).id), 3)
	for i in 3: screen._on_card_clicked(_local(screen, second))
	await _pump()
	assert_eq(first.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(refusals, [])


func test_shared_choice_dialog_and_authorized_library_search() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var tutor := give_hand(0, "Demonic Tutor")
	add_mana(0, Mtg.ManaColor.B, 2)
	var screen := _screen()
	screen._on_card_clicked(_local(screen, tutor))
	await _pump()
	assert_eq(g.stack.size(), 1)
	assert_null(screen._search_dialog, "no speculative peek before resolution")
	for i in 4:
		if g.awaiting_choice != null: break
		assert_ok(g.pass_priority(g.priority_player))
	revision += 1
	screen.present(_room(), true, false)
	assert_not_null(screen._choice_overlay)
	assert_eq(screen.game.awaiting_choice.source, "Demonic Tutor")
	screen._on_choice_option(0)
	await _pump()
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].hand.back().data.card_name, "Forest")
	assert_eq(refusals, [])


func test_serendib_djinn_online_auto_pass_keeps_the_land_choice_for_seat_two() -> void:
	var forest := put_battlefield(1, "Forest")
	var island := put_battlefield(1, "Island")
	put_battlefield(1, "Serendib Djinn")
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	var screen := _screen(1)
	screen.stops.clear_all()
	revision += 1
	screen.present(_room(1), true, false)
	for _i in 8:
		await _pump()
		if g.awaiting_choice != null: break
		if g.priority_player == 0:
			assert_ok(g.pass_priority(0))
		revision += 1
		screen.present(_room(1), true, false)
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	revision += 1
	screen.present(_room(1), true, false)
	await _pump()
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)
	assert_eq(g.awaiting_choice.pid, 1)
	assert_not_null(screen._choice_overlay)
	var labels := DuelScreen.choice_options(screen.game.awaiting_choice)
	assert_eq(labels.size(), 2)
	assert_string_contains(labels[0], "Forest")
	assert_string_contains(labels[1], "Island")
	assert_true(referee.view(0).choice.is_empty(), "the opponent cannot answer the land choice")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	screen._on_choice_option(0)
	await _pump()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.unanswered_choices.size(), 0)
	assert_eq(refusals, [])


func test_pending_action_is_not_repeated_by_refresh_or_disconnection() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var land := give_hand(0, "Forest")
	var screen := _screen()
	screen.action_requested.disconnect(_act.bind(screen, 0))
	watch_signals(screen)
	screen._on_card_clicked(_local(screen, land))
	screen._on_card_clicked(_local(screen, land))
	screen._on_done()
	assert_signal_emit_count(screen, "action_requested", 1)
	screen.present(_room(), false, false)
	screen._on_card_clicked(_local(screen, land))
	assert_signal_emit_count(screen, "action_requested", 1)
	assert_true(screen._pass_button.disabled)
	assert_false(g.players[0].battlefield.has(land))


func test_x_modal_and_live_ability_use_shared_controls() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var ball := give_hand(0, "Fireball")
	for i in 5: put_battlefield(0, "Mountain")
	var screen := _screen()
	screen._on_card_clicked(_local(screen, ball))
	assert_not_null(screen._x_dialog)
	assert_gte(screen._x_spin.max_value, 4.0)
	screen._x_spin.value = 3
	screen._on_x_confirmed()
	await _pump()
	screen._auto_tap_for_pending()
	await _pump()
	for i in 3: screen._on_life_clicked(1)
	await _pump()
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack[0].x_value, 3)
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	var salve := give_hand(0, "Healing Salve")
	add_mana(0, Mtg.ManaColor.W)
	revision += 1
	screen.present(_room(), true, false)
	screen._on_card_clicked(_local(screen, salve))
	assert_not_null(screen._mode_overlay)
	screen._on_mode_chosen(0)
	await _pump()
	screen._on_life_clicked(0)
	await _pump()
	resolve_stack()
	assert_eq(g.players[0].life, 23)
	var wisp := put_battlefield(0, "Will-o'-the-Wisp")
	add_mana(0, Mtg.ManaColor.B)
	revision += 1
	screen.present(_room(), true, false)
	screen._on_card_clicked(_local(screen, wisp))
	assert_true(screen._ability_menu.visible)
	screen._on_ability_chosen(0)
	await _pump()
	resolve_stack()
	assert_gt(wisp.regeneration_shields, 0)
	assert_eq(refusals, [])


func test_public_moves_keep_flights_but_hidden_moves_retire_identity() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	var screen := _screen()
	var before := _local(screen, bear)
	screen._on_card_clicked(before)
	await _pump()
	assert_eq(screen.game.stack[0].card, before)
	resolve_stack()
	revision += 1
	screen.present(_room(), true, false)
	assert_eq(_local(screen, bear), before)
	assert_eq(before.zone, Mtg.Zone.BATTLEFIELD)
	var enemy := put_battlefield(1, "Giant Spider")
	revision += 1
	screen.present(_room(), true, false)
	var old_handle := referee._handle(0, enemy)
	var old_id := screen.projection.local_id(old_handle)
	g.return_to_hand(enemy)
	revision += 1
	screen.present(_room(), true, false)
	assert_null(screen.game.find_instance(old_id))
	assert_false(screen.projection.faces.has(old_handle))
	assert_null(referee._card(0, old_handle))


func test_opening_order_and_network_exit_are_explicit() -> void:
	referee = SgPracticeMatch.new(42)
	var winner := referee.toss_winner
	var screen := _screen(winner)
	var intro: SgDuelOpening = screen._intro_overlay
	intro.reconfigure_pressed.emit()
	assert_gt(screen._network_dialog.z_index, intro.z_index)
	assert_true(is_instance_valid(screen._intro_overlay), "leave needs confirmation, not offline navigation")
	watch_signals(screen)
	assert_signal_not_emitted(screen, "exit_requested")
	for button in screen._network_dialog.find_children("*", "Button", true, false):
		if button.text == "Close": button.pressed.emit()
	intro.go_pressed.emit()
	assert_not_null(screen._network_opening)
	assert_eq(screen._network_opening.button_labels(), PackedStringArray(["Play first", "Draw first"]))
	screen._opening_answer(1)
	await _pump()
	assert_eq(referee.first_player, 1 - winner)
	assert_true(referee.order_chosen)
	assert_eq(screen._network_opening.button_labels(), PackedStringArray(["Take mulligan", "Start the duel"]))
	assert_null(screen._intro_overlay)
	screen._request_exit()
	for button in screen._network_dialog.find_children("*", "Button", true, false):
		if button.text == "Confirm close": button.pressed.emit()
	assert_signal_emitted(screen, "exit_requested")


func test_sound_events_are_filtered_and_not_replayed_by_refresh() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var screen := _screen()
	var enemy := put_battlefield(1, "Grizzly Bears")
	referee.view(0)
	g.draw_cards(1, 1)
	assert_true(referee.visual_events[0].is_empty(), "private draw identity stays at its seat")
	g.destroy(enemy)
	revision += 1
	screen.present(_room(), true, false)
	var sounds: Array = screen._audio.recent.duplicate()
	screen.present(_room(), true, false)
	assert_eq(screen._audio.recent, sounds)
	assert_true(SgViewProtocol.game(referee.view(0)))
	var broken := referee.view(0)
	broken.presentation.cues.append({"serial": 999, "cue": "../../private"})
	assert_false(SgViewProtocol.game(broken))


func test_unpayable_spell_cancels_instead_of_trapping_the_payment_prompt() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wurm := give_hand(0, "Craw Wurm")
	var screen := _screen()
	screen._on_card_clicked(_local(screen, wurm))
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_null(screen._pending_card)
	assert_true(referee.actions.draft.is_empty())
	assert_eq(wurm.zone, Mtg.Zone.HAND)


func test_revealed_hand_and_information_before_a_question_remain_visible() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(1, "Lightning Bolt")
	var revelation := put_battlefield(0, "Revelation")
	var screen := _screen()
	assert_false(screen.hidden_hands.has(1))
	g.sacrifice_permanent(revelation)
	revision += 1
	screen.present(_room(), true, false)
	assert_true(screen.hidden_hands.has(1))
	var question := PlayerChoice.new(PlayerChoice.Kind.YES_NO, 0, "Shuffle this library?")
	question.source = "Visions"
	question.information = [{"viewer": 0, "title": "Visions", "cards": ["Forest", "Lightning Bolt"]}]
	g.awaiting_choice = question
	revision += 1
	screen.present(_room(), true, false)
	assert_not_null(screen._choice_overlay)
	var shown := ""
	for label in screen._choice_overlay.find_children("*", "Label", true, false): shown += label.text
	assert_string_contains(shown, "Lightning Bolt")
	assert_true(referee.view(1).choice.is_empty())


func test_mana_burn_life_and_original_cue_reach_both_seats_once() -> void:
	g.rules.mana_burn = true
	advance_to_step(Mtg.Step.MAIN1)
	var screens := [_screen(), _screen(1)]
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.players[0].life, 17)
	revision += 1
	for seat in 2:
		var screen: SgDuelView = screens[seat]
		screen.present(_room(seat), true, false)
		assert_eq(screen.game.players[screen.projection.local_seat(0)].life, 17)
		assert_eq(screen._audio.recent.count("sfx_mana_burn"), 1)
		screen.present(_room(seat), true, false)
		assert_eq(screen._audio.recent.count("sfx_mana_burn"), 1)


func test_animated_lands_and_jaguar_reminders_match_local_card_widgets() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var swamp := put_battlefield(1, "Swamp")
	put_battlefield(0, "Kormus Bell")
	var jaguar := put_battlefield(1, "Aswan Jaguar")
	resolve_stack()
	g.recalculate()
	for seat in 2:
		var screen := _screen(seat)
		var land := _local(screen, swamp)
		assert_true(land.is_creature())
		assert_eq(land.cur_power, 1)
		assert_eq(land.cur_toughness, 1)
		var reminder := screen._chosen_ghost_data(_local(screen, jaguar))
		assert_not_null(reminder)
		assert_eq(reminder.card_name, "No creatures")
		assert_eq(screen.config.decks[1], [], "cosmetic reminders do not copy the opponent's deck")


func test_damage_prevention_markers_and_circle_target_use_host_packets() -> void:
	g.rules.damage_prevention_window = true
	advance_to_step(Mtg.Step.MAIN1)
	var circle := put_battlefield(0, "Circle of Protection: Red")
	var first := put_battlefield(1, "Hill Giant")
	var second := put_battlefield(1, "Gray Ogre")
	add_mana(0, Mtg.ManaColor.W, 2)
	g.deal_damage(first, TargetRef.player(0), 3)
	g.deal_damage(second, TargetRef.player(0), 2)
	for i in 4:
		if g.awaiting_damage_prevention: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_damage_prevention)
	# Entering the next step emptied the earlier floating pool.
	add_mana(0, Mtg.ManaColor.W, 2)
	var screen := _screen()
	assert_eq(screen._damage_markers.markers().size(), 2)
	assert_string_contains(screen._prompt_label.text, "Damage prevention")
	screen._on_card_clicked(_local(screen, circle))
	screen._on_ability_chosen(0)
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	var spec: SgTargetSpec = screen._pending_slots[0].spec
	assert_eq(spec.kind, TargetSpec.Kind.DAMAGE)
	assert_eq(spec.candidates.size(), 2)
	# The same physical marker signal used by the local duel.
	var marker = screen._damage_markers.markers()[0]
	marker.pressed.emit()
	await _pump()
	assert_eq(refusals, [])
	assert_eq(g.stack.size(), 1)
	if not g.stack.is_empty(): assert_true(g.stack[0].targets[0].is_damage)


## THE FAN READS BOTH ENDS of what it draws, and neither end survived the
## wire. An aura's own `attached_to` costs it its slot on the board; what
## draws it again is its HOST's `attachments`, which the projection never
## filled — so an enchanted creature's Aura was on nobody's board at either
## seat. The shield reminder is the definition the engine recorded in
## `prevention_source`, which no card DTO carried at all.
func test_attachments_and_shields_are_fanned_behind_their_host_online() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var healer := put_battlefield(0, "Samite Healer")
	var aura := give_hand(0, "Holy Strength")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, healer, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.recalculate()
	assert_eq(bear.cur_power, 3)
	assert_gt(bear.prevention, 0)
	for seat in 2:
		var screen := _screen(seat)
		await _pump()
		var host := _local(screen, bear)
		var enchantment := _local(screen, aura)
		assert_eq(enchantment.attached_to, host.id, "seat %d links the aura to its host" % seat)
		assert_eq(Array(host.attachments), [enchantment.id], "seat %d host lists its aura" % seat)
		assert_eq(host.cur_power, 3)
		assert_eq(screen._fan_steps(host), 2, "seat %d fans the aura and the shield" % seat)
		var drawn := PackedStringArray()
		for card in screen.find_children("*", "MiniCard", true, false):
			if card.instance != null: drawn.append(card.instance.data.card_name)
		assert_has(drawn, "Holy Strength", "seat %d draws the aura on the board" % seat)
		assert_eq(screen.find_children("ShieldGhost*", "", true, false).size(), 1,
			"seat %d draws the shield reminder" % seat)
		assert_eq(screen._shield_ghost_data(host).card_name, "Samite Healer")
		assert_true(host.memory.is_empty(), "no private host memory crosses the wire")


func test_granted_and_silenced_abilities_badge_the_same_at_both_seats() -> void:
	# The board's cost badge and regeneration mark read the LIVE ability
	# list. Protocol 15 sends it as a cost and a flag per ability, so a
	# Zombie Master's grant and a Titania's Song's silence show online as
	# they do locally (until 2026-09-17 the guest badged the PRINTED list).
	advance_to_step(Mtg.Step.MAIN1)
	var zombie := put_battlefield(0, "Scathe Zombies")
	put_battlefield(0, "Zombie Master")
	var tome := put_battlefield(1, "Jayemdae Tome")
	put_battlefield(1, "Titania's Song")
	g.recalculate()
	assert_eq(zombie.cur_activated_abilities.size(), 1, "the Master's regeneration, granted")
	assert_true(tome.cur_activated_abilities.is_empty(), "the Song silenced the Tome")
	for seat in 2:
		var screen := _screen(seat)
		await _pump()
		var local_zombie := _local(screen, zombie)
		var local_tome := _local(screen, tome)
		assert_eq(local_zombie.cur_activated_abilities.size(), 1, "seat %d sees the granted ability" % seat)
		assert_eq(local_zombie.cur_activated_abilities[0].cost.text, "{B}", "seat %d badges its cost" % seat)
		assert_true(local_tome.cur_activated_abilities.is_empty(), "seat %d sees the Tome silenced" % seat)
		for card in screen.find_children("*", "MiniCard", true, false):
			if card.instance == local_zombie:
				assert_true(card.regenerates_itself(), "seat %d marks the Zombie as regenerating" % seat)
			elif card.instance == local_tome:
				assert_false(card.regenerates_itself())
		assert_true(local_zombie.memory.is_empty(), "no private host memory crosses the wire")


func test_locks_compulsions_and_wards_mark_the_same_at_both_seats() -> void:
	# The board reads LIVE per-instance state for four of its marks: the
	# untap promise (Meekstone's lock), the sickness spiral (Instill
	# Energy lifts the attack gate without HASTE), the mandatory combat
	# highlights (Lure, a Nettling Imp's compulsion) and the
	# protection-from-artifacts badge (Artifact Ward, two desc-named
	# clauses). The flags cross in the presentation rows
	# (SgDuelPresentation.FLAGS, applied over each face); the ward is
	# one bool as of protocol 17 — until then the guest badged nothing.
	advance_to_step(Mtg.Step.MAIN1)
	var wurm := put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Meekstone")
	wurm.tapped = true
	var elves := put_battlefield(0, "Llanowar Elves", true)
	var bait := put_battlefield(0, "Grizzly Bears")
	var warded := put_battlefield(0, "Scryb Sprites")
	var conscript := put_battlefield(1, "Grizzly Bears")
	conscript.must_attack_this_turn = true
	add_mana(0, Mtg.ManaColor.G, 4)
	add_mana(0, Mtg.ManaColor.W)
	for pair in [["Instill Energy", elves], ["Lure", bait], ["Artifact Ward", warded]]:
		var aura := give_hand(0, pair[0])
		assert_ok(g.cast_spell(0, aura, [TargetRef.card(pair[1])]))
		resolve_stack()
	g.recalculate()
	assert_true(wurm.cur_skips_untap, "Meekstone holds the Wurm")
	assert_true(elves.cur_attacks_as_if_hasty and elves.summoning_sick, "Instill Energy on a sick Elf")
	assert_true(bait.cur_must_be_blocked, "Lure")
	assert_false(warded.cur_damage_immunity.is_empty(), "Artifact Ward")
	for seat in 2:
		assert_true(SgViewProtocol.room(_room(seat)), "seat %d's room validates" % seat)
		var screen := _screen(seat)
		await _pump()
		var marks := {}
		for card in screen.find_children("*", "MiniCard", true, false):
			if card.instance != null: marks[card.instance] = card
		var local_wurm := _local(screen, wurm)
		assert_true(local_wurm.tapped and local_wurm.cur_skips_untap, "seat %d sees the Meekstone lock" % seat)
		assert_does_not_have(marks[local_wurm].active_states(), MiniCard.State.WILL_UNTAP,
			"seat %d promises no untap the host will not give" % seat)
		var local_elves := _local(screen, elves)
		assert_true(local_elves.summoning_sick and local_elves.cur_attacks_as_if_hasty, "seat %d sees Instill Energy" % seat)
		assert_does_not_have(marks[local_elves].active_states(), MiniCard.State.SUMMONING_SICK,
			"seat %d draws no spiral on a creature that may attack" % seat)
		assert_true(_local(screen, bait).cur_must_be_blocked, "seat %d sees the Lure" % seat)
		assert_true(_local(screen, conscript).must_attack_this_turn, "seat %d sees the compulsion" % seat)
		var local_warded := _local(screen, warded)
		assert_true(marks[local_warded].warded_from_artifacts(), "seat %d badges protection from artifacts" % seat)
		assert_true(local_warded.memory.is_empty(), "no private host memory crosses the wire")
		assert_true(_local(screen, conscript).cur_damage_immunity.is_empty(), "seat %d wards only the warded" % seat)


func test_a_tokens_printed_pair_and_subtype_reach_both_seats() -> void:
	# The P/T ink and the enlarged card ask the DEFINITION, not the live
	# values (MiniCard.pt_color, CardPreview._power_toughness). A guest
	# reads a named card's print off its own registry — but a TOKEN (a
	# Thallid's saproling, a Rukh Egg's bird) has no entry there, so until
	# protocol 18 every token on either board wore the green "pumped" ink
	# and enlarged as a subtypeless 0/0.
	advance_to_step(Mtg.Step.MAIN1)
	var plain: CardInstance = g.create_token(0,
		CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1).with_subtypes(["saproling"]))[0]
	var grown: CardInstance = g.create_token(0,
		CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1).with_subtypes(["saproling"]))[0]
	g.add_counters(grown, "+1/+1")
	g.recalculate()
	assert_eq(grown.cur_power, 2)
	for seat in 2:
		var screen := _screen(seat)
		await _pump()
		var marks := {}
		for card in screen.find_children("*", "MiniCard", true, false):
			if card.instance != null: marks[card.instance] = card
		var local := _local(screen, plain)
		assert_eq(local.data.power, 1, "seat %d keeps the token's printed power" % seat)
		assert_eq(local.data.toughness, 1, "seat %d keeps the token's printed toughness" % seat)
		assert_eq(marks[local].pt_color(), Color.WHITE,
			"seat %d inks an unmodified token white" % seat)
		assert_ne(marks[_local(screen, grown)].pt_color(), Color.WHITE,
			"seat %d still inks a grown token as pumped" % seat)
		screen._card_preview.show_card(local)
		assert_eq(screen._card_preview._pt_label.text, "1/1",
			"seat %d enlarges the printed pair" % seat)
		assert_string_contains(screen._card_preview._type_label.text, "Saproling")


func test_blaze_of_glory_lets_its_conscript_block_every_attacker_at_both_seats() -> void:
	# *"Target creature defending player controls can block any number of
	# creatures this turn"* is CardInstance.extra_blocks_this_turn = -1,
	# which MtgGame.blocks_allowed reads beside the static permission and
	# the screen subtracts from on every blocking click. Only the static
	# half crossed, so the guest's own UI refused the second block with
	# "Wall of Stone can block only 1 attacker(s)" before the referee ever
	# saw it.
	advance_to_step(Mtg.Step.MAIN1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var blaze := give_hand(1, "Blaze of Glory")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id, giant.id]))
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, blaze, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(g.blocks_allowed(wall), -1, "the print says any number")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	for seat in 2:
		var screen := _screen(seat)
		await _pump()
		var local_wall := _local(screen, wall)
		assert_eq(screen.game.blocks_allowed(local_wall), -1,
			"seat %d sees the permission" % seat)
		if seat != 1: continue
		# ...and the seat the engine is asking pencils both blocks in.
		assert_eq(screen.mode, DuelScreen.Mode.BLOCKERS)
		screen._on_card_clicked(local_wall)
		screen._on_card_clicked(_local(screen, bears))
		screen._on_card_clicked(_local(screen, giant))
		assert_eq((screen._block_map.get(local_wall.id, []) as Array).size(), 2,
			"the conscript is pencilled in against both attackers")


func test_escape_over_a_manalink_window_closes_it_and_nothing_under_it() -> void:
	# The Manalink windows are bare OriginalDialogs exactly as `Give up
	# this duel?` and `Duel Options...` are, so `_dialogs_open()` routes
	# Escape into the cancel ladder. With no rung of their own the press
	# peeled a layer of the DUEL underneath: the graveyard a player had
	# open shut itself while the window they were reading stayed up.
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(put_battlefield(0, "Grizzly Bears"))
	g.destroy(put_battlefield(1, "Craw Wurm"))
	for seat in 2:
		var screen := _screen(seat)
		await _pump()
		screen._open_graveyard(0)
		await _pump()
		screen._show_connection()
		await _pump()
		assert_true(screen._dialogs_open(), "seat %d opened a bare dialog" % seat)
		screen._on_escape()
		await _pump()
		assert_false(is_instance_valid(screen._network_dialog),
			"seat %d closes the window it was reading" % seat)
		assert_true(screen.graveyard_is_open(),
			"seat %d keeps the pile it had open" % seat)
		screen._close_graveyard()


func test_an_attack_lineup_survives_escape_over_the_connection_window() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var screen := _screen(0)
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)
	screen._on_card_clicked(_local(screen, bears))
	assert_eq(Array(screen._selected_attackers).size(), 1)
	screen._show_connection()
	await _pump()
	screen._on_escape()
	await _pump()
	assert_false(is_instance_valid(screen._network_dialog))
	assert_eq(Array(screen._selected_attackers).size(), 1,
		"the attackers lined up behind the window are still lined up")


func test_a_silenced_mana_source_is_not_lit_for_payment_at_either_seat() -> void:
	# `cur_mana_abilities` is the one list the guest keeps PRINTED, and
	# the payment cue read it: a Titania's Song-silenced Sol Ring lit as a
	# source the player could click, where _click_permanent asks the
	# referee's own options for that face and finds none.
	advance_to_step(Mtg.Step.MAIN1)
	var ring := put_battlefield(0, "Sol Ring")
	put_battlefield(1, "Titania's Song")
	g.recalculate()
	assert_true(ring.cur_mana_abilities.is_empty(), "the Song silenced the Ring")
	for seat in 2:
		var screen := _screen(seat)
		await _pump()
		var local := _local(screen, ring)
		assert_false(local.cur_mana_abilities.is_empty(), "the printed list is still there")
		assert_false(screen._has_payment_mana(local),
			"seat %d lights no source the host would refuse" % seat)


func test_the_guests_land_drop_follows_the_seats_own_allowance(fastbond = use_parameters([true, false])) -> void:
	# `players[seat].lands` is only half the land-drop rule: what
	# land_drop_available reads beside the counter is the seat's ALLOWANCE
	# (Fastbond's "any number", a world's extra play), and until protocol
	# 20 no part of it crossed. With a Fastbond out, the guest's own
	# Situation Bar dropped ", play land" after the first land and its
	# hand stopped lighting the second — while the referee went on
	# accepting them.
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(CardRegistry.has_card("Fastbond"))
	if fastbond:
		put_battlefield(0, "Fastbond")
		g.recalculate()
	var first := give_hand(0, "Forest")
	var second := give_hand(0, "Forest")
	var screen := _screen()
	await _pump()
	assert_true(screen.game.land_drop_available(0), "the turn's first land is always offered")
	screen._on_card_clicked(_local(screen, first))
	await _pump()
	assert_eq(g.players[0].lands_played_this_turn, 1, "the referee took the first land")
	assert_eq(screen.game.land_drop_available(0), fastbond,
		"the guest reads the same allowance the host does")
	assert_eq(screen._phase_status_message().ends_with(", play land"), fastbond,
		screen._phase_status_message())
	if not fastbond:
		assert_string_ends_with(screen._phase_status_message(), "cast spells")
		return
	assert_eq(_local(screen, second).id, screen.game.players[0].hand[0].id,
		"the second land is still in the guest's hand")
	screen._on_card_clicked(_local(screen, second))
	await _pump()
	assert_eq(g.players[0].lands_played_this_turn, 2, "the referee took the second land too")
	assert_eq(refusals, [])


func test_the_watching_seat_paints_the_damage_groups_already_assigned() -> void:
	# `damage_request` — the amounts and the per-target lethal hint — goes
	# to the ASSIGNER alone, and the projection used to answer `{}` to
	# every other seat. The groups the assigner had already confirmed were
	# therefore painted on nobody else's board. The public half of the
	# question rides on `presentation.assignment` instead: the source's
	# power and the creatures it is facing are both already on the table.
	g.rules.free_damage_assignment = true
	var wurms: Array = [put_battlefield(0, "Craw Wurm"), put_battlefield(0, "Craw Wurm")]
	var bears: Array = []
	for i in 4: bears.append(put_battlefield(1, "Grizzly Bears"))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurms[0].id, wurms[1].id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bears[0].id: wurms[0].id, bears[1].id: wurms[0].id,
		bears[2].id: wurms[1].id, bears[3].id: wurms[1].id}))
	for i in 8:
		if g.awaiting_damage_assignment: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_damage_assignment, str(Mtg.Step.keys()[g.current_step()]))
	# One wurm's six points answered; the other division is still owed, so
	# the step stays open with the first one's marks on the running total.
	var answered := g.damage_assignment_request()
	var split := {}
	for id: int in answered.targets: split[id] = 3
	assert_ok(g.assign_combat_damage(int(answered.assigner), split))
	assert_true(g.awaiting_damage_assignment, "the second group is still owed")
	var watcher := _screen(1)
	await _pump()
	assert_ne(watcher.mode, DuelScreen.Mode.DAMAGE, "the watching seat is not the assigner")
	var request: Dictionary = watcher.game.damage_assignment_request()
	assert_false(request.is_empty(), "the public half of the division reaches both seats")
	assert_eq(request.assigner, 1, "the assigner is the seat across the table")
	assert_eq(int(request.amount), 6, "the source's power is public")
	assert_eq(request.source.data.card_name, "Craw Wurm")
	assert_eq((request.targets as Array).size(), 2, "both blockers of the open group")
	for id: int in answered.targets:
		assert_eq(watcher._pending_damage_for(_local(watcher, g.find_instance(id)).id), 3,
			"the watching board paints the group already assigned")
	assert_eq(refusals, [])
	# ...and the seat that IS being asked still sees its own question.
	var assigner := _screen(0)
	await _pump()
	assert_eq(assigner.mode, DuelScreen.Mode.DAMAGE)
	assert_eq(int(assigner.game.damage_assignment_request().amount), 6)


func test_the_guest_names_the_creatures_the_regeneration_window_is_about() -> void:
	# `presentation.regeneration` said a window was open and nothing said
	# WHO it was about, so the guest's inherited damage_prevention_request
	# answered with an empty `creatures` list and the board had nobody to
	# offer a shield to. The doomed are public: they are standing on a
	# battlefield holding lethal damage.
	g.rules.damage_prevention_window = true
	var wurm := put_battlefield(0, "Craw Wurm")
	var bones := put_battlefield(1, "Drudge Skeletons")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bones.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_regeneration, "about to go to the graveyard")
	assert_eq(Array(g.regeneration_candidates), [bones.id])
	for seat in 2:
		var screen := _screen(seat)
		await _pump()
		var local := _local(screen, bones)
		assert_eq(Array(screen.game.regeneration_candidates), [local.id],
			"seat %d names the doomed creature" % seat)
		var window: Dictionary = screen.game.damage_prevention_request()
		assert_eq(String(window.kind), "regeneration", "seat %d is in the second window" % seat)
		assert_eq((window.creatures as Array).size(), 1,
			"seat %d has a creature to offer the shield to" % seat)
		assert_eq(window.creatures[0], local)
	# The list belongs to one window: nothing lingers once it has closed.
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_regeneration: assert_ok(g.end_damage_prevention(g.priority_player))
	assert_false(g.awaiting_regeneration)
	revision += 1
	var after := _screen(0)
	await _pump()
	assert_true(after.game.regeneration_candidates.is_empty())
	assert_true(after.game.damage_prevention_request().is_empty())
	assert_eq(refusals, [])
