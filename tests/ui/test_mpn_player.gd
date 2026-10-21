extends GameTest
## Graphical public-history playback uses duel widgets, never rules actions.

func _document(name := "finished-game") -> Dictionary:
	return MpnCodec.parse(FileAccess.get_file_as_string("res://docs/mpn-examples/" + name + ".mpn"))

func _player() -> MpnPlayer:
	var player := MpnPlayer.new()
	add_child_autofree(player)
	player.open_document(_document())
	return player

func _row(handle: String, title: String, owner := 0, zone := "battlefield") -> Dictionary:
	return {"id": handle, "name": title, "owner": owner, "controller": owner,
		"zone": zone, "face_down": false, "tapped": false, "creature": true,
		"power": 2, "toughness": 2, "damage": 0, "counters": {}, "types": ["creature"]}

func test_projection_uses_recorded_stats_and_text_without_executable_definitions() -> void:
	var state := MpnCodec.state_at(_document().records, 0)
	state.objects.o2 = _row("o2", "Grizzly Bears")
	state.objects.o2.power = 9
	state.objects.o2.rules_text = "Recorded text, not the current catalogue."
	state.objects.o2.counters = {"+1/+1": 7}
	var projection := MpnProjection.new()
	projection.ingest(state, _document().headers)
	var bear := projection.find_instance(projection.local_id("o2"))
	assert_eq(bear.cur_power, 9)
	assert_eq(bear.data.oracle_text, state.objects.o2.rules_text)
	assert_eq(bear.counters, {"+1/+1": 7})
	assert_eq(bear.data.spell_effects.size(), 0)
	assert_eq(bear.data.static_abilities.size(), 0)
	assert_eq(bear.cur_activated_abilities.size(), 0)
	assert_false(bear.summoning_sick, "unknown status does not acquire a guessed badge")
	assert_eq(projection.priority_player, -1, "turn owner is not inferred priority")

func test_counts_do_not_materialize_hidden_cards_and_masked_faces_have_no_lookup() -> void:
	var state := MpnCodec.state_at(_document().records, 0)
	state.players[0].library = 1000000
	state.players[0].hand = 1000000
	var masked := _row("o2", "Face-down card", 1, "exile")
	masked.face_down = true
	masked.erase("types")
	state.objects.o2 = masked
	var projection := MpnProjection.new()
	projection.ingest(state, _document().headers)
	assert_eq(projection.players[0].library.size(), 0)
	assert_eq(projection.players[0].hand.size(), 0)
	assert_eq(int(projection.observation.players[0].library), 1000000)
	assert_eq(projection.players[1].exile[0].data.card_name, "Face-down card")
	assert_true(projection.players[1].exile[0].face_down)
	assert_eq(projection.players[1].exile[0].data.set_code, "")

func test_unknown_cards_optional_fields_and_cyclic_attachments_are_safe() -> void:
	var state := MpnCodec.state_at(_document().records, 0)
	state.objects.o2 = _row("o2", "Uncatalogued token")
	state.objects.o3 = _row("o3", "Another token")
	state.objects.o2.attached_to = "o3"
	state.objects.o3.attached_to = "o2"
	state.objects.o2.rules_text = ["wrong type"]
	state.objects.o2.keywords = [false, "unknown"]
	state.objects.o2.counters = {"bad": [1]}
	var projection := MpnProjection.new()
	projection.ingest(state, _document().headers)
	var token := projection.find_instance(projection.local_id("o2"))
	assert_eq(token.data.card_name, "Uncatalogued token")
	assert_eq(token.attached_to, -1)
	assert_eq(token.counters, {})
	assert_eq(token.data.oracle_text, "Rules text not recorded.")
	assert_eq(token.cur_keywords.size(), 0)

func test_recorded_attackers_blocks_targets_and_damage_are_display_values_only() -> void:
	var state := MpnCodec.state_at(_document().records, 4)
	state.objects.o3 = _row("o3", "Grizzly Bears", 0)
	state.objects.o4 = _row("o4", "Gray Ogre", 1)
	state.objects.o3.damage = 1
	state.combat = {"attackers": ["o3"], "blocks": [["o4", "o3"]]}
	var projection := MpnProjection.new()
	projection.ingest(state, _document().headers)
	assert_true(projection.combat.attackers.has(projection.local_id("o3")))
	assert_eq(projection.combat.blocks[projection.local_id("o4")], projection.local_id("o3"))
	assert_eq(projection.find_instance(projection.local_id("o3")).damage, 1)
	assert_eq(projection.stack.size(), 1)
	assert_true(projection.stack[0].targets[0].is_player)
	assert_eq(projection.stack[0].targets[0].player_id, 1)
	assert_eq(projection.damage_pending.size(), 0, "pending packets are not reconstructed from dealt damage")

func test_graphical_player_steps_and_rewinds_without_double_applying_damage() -> void:
	var player := _player()
	var game_rng := g.rng.state
	player.seek(7)
	assert_eq(player._table.game.players[1].life, 17)
	assert_eq(int(player._state.players[1].life), 17)
	assert_true(player._table.is_visible_in_tree())
	player.seek(10)
	assert_eq(player._table.game.players[0].graveyard.size(), 1)
	player.seek(0)
	assert_eq(player._table.game.players[1].life, 20)
	assert_eq(player._table.game.players[0].graveyard.size(), 0)
	assert_eq(g.rng.state, game_rng)
	assert_true(player._timer.is_stopped())
	assert_null(player._table._public_archive)
	await get_tree().process_frame

func test_duel_action_controls_are_disconnected_and_inputs_cannot_play() -> void:
	var player := _player()
	var table := player._table
	var original := table.projection.observation.duplicate(true)
	var rng := table.game.rng.state
	table._pass_button.pressed.emit()
	table._skip_button.pressed.emit()
	table._on_done()
	table._on_pass()
	table._drive_advance()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	table._on_control(key)
	table._territory_menu.id_pressed.emit(DuelScreen.REST_BASE + 8) # Concede
	assert_eq(table.projection.observation, original)
	assert_eq(table.game.rng.state, rng)
	assert_false(table.game.game_over)
	assert_eq(player.cursor, 0)
	assert_true(table._ais.is_empty())
	assert_false(table._situation_bar.visible)
	await get_tree().process_frame

func test_inspection_is_cleared_when_rewinding_or_a_public_card_disappears() -> void:
	var player := _player()
	player.seek(4)
	var bolt := player._table.game.stack[0].card
	player._table._on_card_clicked(bolt)
	assert_not_null(player._table._card_preview._shown)
	player.seek(0)
	assert_null(player._table._card_preview._shown)
	assert_eq(player._table.game.stack.size(), 0)
	assert_false(player._table.inspection_open())
	await get_tree().process_frame

func test_history_watch_button_and_return_preserve_the_observation() -> void:
	var history := PastGamesScreen.new()
	add_child_autofree(history)
	assert_true(history.open_record("res://docs/mpn-examples/finished-game.mpn"))
	history.seek(4)
	assert_false(history._watch.disabled)
	history._watch.pressed.emit()
	assert_not_null(history._player)
	assert_false(history.visible)
	assert_eq(history._player.cursor, 4)
	history._player.seek(7)
	history._player.close_player()
	assert_true(history.visible)
	assert_eq(history.cursor, 7)
	await get_tree().process_frame

func test_turn_navigation_and_stopped_recordings_do_not_invent_results() -> void:
	var doc := _document("stopped-game")
	doc.records.insert(3, {"kind": "state", "data": {"turn": 1, "step": "main1"}})
	doc.records.insert(4, {"kind": "state", "data": {"turn": 2, "active": 1}})
	var player := MpnPlayer.new()
	add_child_autofree(player)
	player.open_document(doc)
	player.jump_turn(1)
	assert_eq(player.cursor, 3)
	player.jump_turn(1)
	assert_eq(player.cursor, 4)
	player.jump_turn(-1)
	assert_eq(player.cursor, 3)
	player.step_to(doc.records.size() - 1)
	assert_true(player._caption.text.contains("no final result"))
	assert_false(player._table.game.game_over)
	assert_true(player._timer.is_stopped())
	await get_tree().process_frame

func test_oversized_graphical_observation_is_refused_without_silent_truncation() -> void:
	var state := MpnCodec.state_at(_document().records, 0)
	for i in MpnProjection.MAX_VISIBLE:
		var id := "o%d" % (i + 2)
		state.objects[id] = _row(id, "Token")
	assert_ne(MpnProjection.refusal(state), "")

func test_closing_after_a_result_does_not_claim_the_game_was_unfinished() -> void:
	var doc := _document()
	doc.records.append({"kind": "close", "data": {"reason": "recording-stopped"}})
	var player := _player()
	player.open_document(doc, "", doc.records.size() - 1)
	assert_true(player._caption.text.contains("final result recorded"))
	assert_false(player._caption.text.contains("no final result"))
	assert_false(player._table.game.game_over, "the display adapter still never ends a simulated game")
	await get_tree().process_frame

func test_partial_history_does_not_guess_untap_or_dying_cues() -> void:
	var player := _player()
	var state := MpnCodec.state_at(_document().records, 0)
	state.objects.o2 = _row("o2", "Grizzly Bears")
	state.objects.o2.tapped = true
	state.objects.o2.damage = 3
	player._table.present(state, _document().headers)
	var bear := player._table.projection.find_instance(player._table.projection.local_id("o2"))
	var card := player._table._make_card(bear)
	add_child_autofree(card)
	assert_false(card._state_active(MiniCard.State.WILL_UNTAP))
	assert_false(card._state_active(MiniCard.State.DYING))
	assert_true(card._state_active(MiniCard.State.DAMAGE))
	assert_eq(card._damage_count.text, "3")
	var live_card := MiniCard.new(bear)
	add_child_autofree(live_card)
	assert_true(live_card._state_active(MiniCard.State.WILL_UNTAP), "live duel cues are unchanged")
	assert_true(live_card._state_active(MiniCard.State.DYING))
	await get_tree().process_frame

func test_table_and_hand_labels_fit_above_toolbar_and_piles_are_read_only() -> void:
	var player := _player()
	player.seek(10)
	await get_tree().process_frame
	await get_tree().process_frame
	var table := player._table
	assert_lte(table.get_global_rect().end.y, player._caption.global_position.y)
	var board := table._board_area()
	assert_true(board.encloses(table._hand_badges[0].get_global_rect()))
	assert_true(board.encloses(table._hand_badges[1].get_global_rect()))
	assert_gte(table._hand_badges[0].global_position.y, board.position.y + board.size.y * 0.5)
	table._on_grave_pile_clicked(0)
	assert_true(table.inspection_open())
	assert_eq(table._grave_view.get_global_transform().get_scale(), Vector2.ONE)
	assert_eq(table._grave_view._human, -1, "public observation has no private seat")
	table.dismiss_inspection()
	assert_false(table.inspection_open())
