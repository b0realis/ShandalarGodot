extends GutTest
## The hall remains navigable at the smallest supported desktop playtest size.

var _had_folder := false
var _saved_folder: Variant


func before_each() -> void:
	_had_folder = Settings.has_value(GamePaths.KEY_TOURNAMENTS)
	_saved_folder = Settings.get_value(GamePaths.KEY_TOURNAMENTS, null) if _had_folder else null


func after_each() -> void:
	if _had_folder: Settings.set_value(GamePaths.KEY_TOURNAMENTS, _saved_folder)
	else: Settings.clear_value(GamePaths.KEY_TOURNAMENTS)


func test_tournament_setup_is_opt_in_and_uses_three_deck_policies() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	lobby._show_page("tournament")
	for i in 6: await get_tree().process_frame
	assert_eq(lobby._tournament_panel._policy.item_count, 3)
	assert_eq(lobby._tournament_panel._wins.item_count, 3)
	assert_eq(lobby._tournament_panel._limit.item_count, 39)
	assert_eq(lobby._tournament_panel._limit.get_item_text(18), "20 players")
	assert_eq(lobby._tournament_panel._limit.get_item_text(38), "40 players", "forty entrants (owner's word, 2026-10-02)")
	assert_eq(lobby._tournament_panel._limit.selected, 6, "eight players stays the default")
	assert_false(lobby._tournament_panel._deck_area.visible)
	lobby._tournament_panel._policy.select(1)
	lobby._tournament_panel._policy.item_selected.emit(1)
	assert_true(lobby._tournament_panel._deck_area.visible)
	assert_null(lobby.service)
	assert_null(lobby._discovery)
	assert_false(lobby.client._wanted)
	assert_lte(lobby._window.position.x + lobby._window.size.x, 960.0)
	assert_lte(lobby._window.position.y + lobby._window.size.y, 600.0)
	assert_eq(lobby._content_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)


func test_cancelled_tables_do_not_claim_to_be_in_progress() -> void:
	var panel := SgTournamentPanel.new()
	add_child_autofree(panel)
	panel._view = {"phase": "cancelled", "tables": [], "entrants": [{"id": 1, "name": "Azure"}, {"id": 2, "name": "Amber"}],
		"rounds": [[{"id": 9, "players": [1, 2], "wins": [0, 0], "draws": 0, "winner": 0, "game": 1, "status": "playing"}]]}
	panel._build_rounds()
	var labels := PackedStringArray()
	for label in panel.find_children("*", "Label", true, false): labels.append(label.text)
	assert_true(labels.has("Cancelled · no further games"))
	assert_false("\n".join(labels).contains("in progress"))


func test_tournament_setup_exposes_welcome_and_local_save_folder() -> void:
	var panel := _panel()
	panel.present({}, false, false, true)
	assert_not_null(panel.find_child("TournamentName", true, false))
	assert_not_null(panel.find_child("TournamentWelcomeEdit", true, false))
	assert_not_null(panel.find_child("TournamentSaveFolder", true, false))


func test_welcome_is_readable_literal_text_for_new_and_registered_players() -> void:
	var view := _view(_event())
	view.organiser = false
	view.config.welcome = "Welcome, duelists! [b]This is plain text[/b] — good luck."
	var panel := _panel()
	for entrant in [0, 1]:
		view.you = entrant
		panel.present(view, true, false, false)
		for i in 6: await get_tree().process_frame
		var message := panel.find_child("TournamentWelcome", true, false) as Label
		assert_not_null(message)
		assert_eq(message.text, view.config.welcome)
		assert_gt(message.autowrap_mode, TextServer.AUTOWRAP_OFF)
		assert_lte(message.get_global_rect().end.x, 920.0)
		assert_lte(panel.size.x, 920.0)
	view.config.erase("welcome")
	panel.present(view, true, false, false)
	assert_null(panel.find_child("TournamentWelcome", true, false))
	for i in 3: await get_tree().process_frame


func test_folder_selection_is_remembered_refreshes_saved_events_and_stays_local() -> void:
	var folder := "user://tournament-tests/selected folder " + Crypto.new().generate_random_bytes(8).hex_encode()
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Saved welcome cup", "welcome": "Welcome back!", "limit": 8,
		"wins": 1, "policy": "own", "decks": []}, 42), "")
	assert_eq(SgTournamentStore.save(event, folder), OK)
	var panel := _panel()
	panel.present({}, false, false, true)
	var picker := panel._make_folder_picker()
	assert_eq(picker.file_mode, FileDialog.FILE_MODE_OPEN_DIR)
	assert_eq(picker.access, FileDialog.ACCESS_FILESYSTEM)
	var absolute := ProjectSettings.globalize_path(folder)
	picker.dir_selected.emit(absolute)
	assert_eq(GamePaths.tournaments_folder(), absolute)
	assert_eq(panel._folder_edit.text, absolute)
	var resume := panel._saved_events.get_child(0) as Button
	assert_not_null(resume)
	assert_true(resume.text.contains("Saved welcome cup"))
	var events: Array = []
	panel.host_requested.connect(func(options: Dictionary, path: String) -> void: events.append([options, path]))
	resume.pressed.emit()
	assert_eq(events.size(), 1)
	assert_eq(events[0][1], absolute.path_join(event.id + ".json"))
	panel._welcome_edit.text = "Have fun, everyone!"
	panel.find_child("TournamentOpenRegistration", true, false).pressed.emit()
	assert_eq(events.size(), 2)
	assert_eq(events[1][0].welcome, "Have fun, everyone!")
	assert_false(JSON.stringify(events[1][0]).contains(absolute), "host path must not enter shared config")
	panel._folder_edit.text = "relative/saves"
	panel.find_child("TournamentOpenRegistration", true, false).pressed.emit()
	assert_eq(events.size(), 2, "an invalid folder must not open a host")
	assert_eq(GamePaths.tournaments_folder(), absolute)
	var reopened := _panel()
	reopened.present({}, false, false, true)
	assert_eq(reopened._folder_edit.text, absolute)
	for i in 6: await get_tree().process_frame
	assert_lte(panel.size.x, 920.0, "long save paths scroll inside their field")
	assert_lte(panel._folder_edit.get_global_rect().end.x, 920.0)
	DirAccess.remove_absolute(folder.path_join(event.id + ".json"))
	DirAccess.remove_absolute(folder)


func _event() -> SgTournament:
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Twenty Player Cup", "limit": 20, "wins": 1, "policy": "fixed",
		"decks": [{"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]}, 4242), "")
	for i in 20:
		var pid := event.register("Long Player %02d (Guest %d)" % [i + 1, i + 1], str(i).sha256_text())
		event.set_ready(pid, true)
	event.draw_round()
	return event


func _view(event: SgTournament) -> Dictionary:
	var server := SgLocalServer.new()
	add_child_autofree(server)
	var host := SgTournamentHost.new()
	host.event = event
	host.organiser = 99
	server.add_child(host)
	return host.view(99)


func _panel() -> SgTournamentPanel:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(920, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	viewport.add_child(scroll)
	var panel := SgTournamentPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	return panel


func test_twenty_player_graph_is_connected_non_overlapping_and_preserves_exploration() -> void:
	var event := _event()
	for round_index in 5:
		for pair: Dictionary in event.rounds.back():
			if pair.status == "bye": continue
			for pid: int in pair.players: event.set_ready(pid, true)
			event.begin_game(pair.id)
			event.record_game(pair.id, pair.game, 0)
		if event.phase == "complete": break
		event.draw_round()
	var view := _view(event)
	var panel := _panel()
	panel.present(view, true, false, true)
	assert_eq(panel._section, "standings", "a completed tournament opens its final score table")
	var table := panel.find_child("TournamentStandings", true, false) as Tree
	assert_not_null(table)
	var count := 0
	var item := table.get_root().get_first_child()
	while item != null:
		count += 1
		item = item.get_next()
	assert_eq(count, 20)
	panel._choose_section("advancement")
	for i in 6: await get_tree().process_frame
	var graph := panel._graph
	assert_eq(graph._canvas.graph.nodes.size(), 31)
	assert_eq(graph._canvas.graph.links.size(), 30)
	for a: Dictionary in graph._canvas.graph.nodes:
		var box: Rect2 = graph._canvas.boxes[a.id]
		assert_true(Rect2(Vector2.ZERO, graph._canvas.extent).encloses(box))
		for b: Dictionary in graph._canvas.graph.nodes:
			if a.id != b.id: assert_false(box.intersects(graph._canvas.boxes[b.id]), "draw nodes never overlap")
	graph._fit_picker.select(2)
	graph._fit_picker.item_selected.emit(2)
	for i in 3: await get_tree().process_frame
	assert_lte(graph._canvas.custom_minimum_size.x, graph._scroll.size.x)
	assert_lte(graph._canvas.custom_minimum_size.y, graph._scroll.size.y)
	var elided := graph._canvas._elide("An exceptionally long tournament player name", 17, 192)
	assert_true(elided.ends_with("…"))
	assert_lte(graph._canvas.face.get_string_size(elided, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, 192.0)
	graph._zoom_by(0.1)
	graph.follow(17)
	var saved := graph.capture_state()
	var previous_id := graph.get_instance_id()
	view.revision += 1
	panel.present(view, true, false, true)
	assert_eq(panel._graph.get_instance_id(), previous_id, "ACK-only updates do not rebuild the diagram")
	view.entrants[0].connected = true
	panel.present(view, true, false, true)
	for i in 6: await get_tree().process_frame
	assert_eq(panel._graph._canvas.selected, 17)
	assert_almost_eq(panel._graph._canvas.zoom, saved.zoom, 0.001)
	assert_lte(panel.size.x, 920.0)
	panel._choose_section("overview")
	panel._choose_section("advancement")
	for i in 4: await get_tree().process_frame
	assert_eq(panel._graph._canvas.selected, 17, "tab navigation keeps the selected path")


func test_all_tournament_tabs_work_without_network_side_effects() -> void:
	var view := _view(_event())
	var panel := _panel()
	watch_signals(panel)
	panel.present(view, true, false, true)
	for section in ["advancement", "standings", "players", "entry", "overview"]:
		var button := panel.find_child("TournamentTab_" + section, true, false) as Button
		assert_not_null(button)
		button.pressed.emit()
		assert_eq(panel._section, section)
		for i in 3: await get_tree().process_frame
		assert_lte(panel.size.x, 920.0)
	assert_signal_not_emitted(panel, "action_requested")
	assert_signal_not_emitted(panel, "host_requested")

func _wire(view: Dictionary) -> Dictionary:
	# Every real client reads its hall out of decoded JSON, where an entrant
	# identifier and a series score arrive as floats.
	return SgProtocol.decode_payload(SgProtocol.encode(view).to_ascii_buffer())


func _labels(panel: SgTournamentPanel) -> PackedStringArray:
	var result := PackedStringArray()
	for label in panel.find_children("*", "Label", true, false): result.append(label.text)
	return result


func _captions(panel: SgTournamentPanel) -> PackedStringArray:
	var result := PackedStringArray()
	for button: Button in panel.find_children("*", "Button", true, false): result.append(button.text)
	return result


func _small_event(count: int, wins := 1) -> SgTournament:
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Hall Cup", "limit": 8, "wins": wins, "policy": "fixed",
		"decks": [{"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]}, 4242), "")
	for i in count:
		var pid := event.register("Player %d" % (i + 1), str(i).sha256_text())
		event.set_ready(pid, true)
	assert_eq(event.draw_round(), "")
	return event


## One seat's own hall, as it arrives: every entrant holds a live session, so
## readiness and connection read the way a player sees them.
func _seat_view(event: SgTournament, pid: int) -> Dictionary:
	var server := SgLocalServer.new()
	add_child_autofree(server)
	var host := SgTournamentHost.new()
	host.event = event
	host.organiser = 99
	server.add_child(host)
	server._sessions[99] = {"peer": 99, "room": "", "nickname": "Organiser"}
	for player: Dictionary in event.entrants:
		var sid := 500 + int(player.id)
		server._sessions[sid] = {"peer": sid, "room": "", "nickname": String(player.name)}
		host.bindings[int(player.id)] = sid
	return _wire(host.view(99 if pid == 0 else 500 + pid))


func _entry_line(event: SgTournament, pid: int) -> String:
	var panel := _panel()
	panel.present(_seat_view(event, pid), true, false, false)
	panel._choose_section("entry")
	var line := panel.find_child("TournamentEntryStatus", true, false) as Label
	assert_not_null(line, "every entry page states the player's own situation")
	return "" if line == null else line.text


func test_series_scores_never_read_as_decimal_fractions_on_a_real_client() -> void:
	var event := _small_event(2, 2)
	var pair: Dictionary = event.rounds[0][0]
	for pid: int in pair.players: event.set_ready(pid, true)
	assert_eq(event.begin_game(int(pair.id)), "")
	assert_true(event.record_game(int(pair.id), int(pair.game), 0))
	var panel := _panel()
	panel.present(_seat_view(event, int(pair.players[0])), true, false, false)
	panel._choose_section("overview")
	for i in 3: await get_tree().process_frame
	var texts := _labels(panel)
	assert_true(texts.has("1"), "the winning seat shows one game won")
	assert_false(texts.has("1.0"), "a series score is a whole number of games")
	assert_false(texts.has("0.0"), "a series score is a whole number of games")


func test_my_entry_says_what_each_waiting_player_is_waiting_for() -> void:
	var event := _small_event(6)
	var bye := 0
	var playing: Dictionary = {}
	for pair: Dictionary in event.rounds[0]:
		if pair.status == "bye": bye = int(pair.winner)
		elif playing.is_empty(): playing = pair
	assert_ne(bye, 0)
	var table := SgTournament.table_number(int(playing.id))
	var waiting := int(playing.players[0])
	var opponent := int(playing.players[1])
	assert_eq(_entry_line(event, bye),
		"You have a bye in round 1. There is no game to play; wait for the other tables.")
	assert_eq(_entry_line(event, waiting),
		"Round 1, table %d against Player %d. Select Ready for next game." % [table, opponent])
	assert_eq(event.set_ready(waiting, true), "")
	assert_eq(_entry_line(event, waiting), "You are ready. Waiting for Player %d to confirm." % opponent)
	assert_eq(event.set_ready(opponent, true), "")
	assert_eq(event.begin_game(int(playing.id)), "")
	assert_true(event.record_game(int(playing.id), int(playing.game), 0))
	assert_eq(_entry_line(event, waiting),
		"You won your round 1 series. Waiting for the other tables to finish.")
	assert_eq(_entry_line(event, opponent),
		"Player %d won your round 1 series. You are out of the tournament." % waiting)
	for pair: Dictionary in event.rounds[0]:
		if pair.status != "waiting": continue
		for pid: int in pair.players: event.set_ready(pid, true)
		assert_eq(event.begin_game(int(pair.id)), "")
		assert_true(event.record_game(int(pair.id), int(pair.game), 0))
	assert_eq(_entry_line(event, waiting),
		"You won your round 1 series. Waiting for the organiser to draw round 2.")
	assert_eq(event.draw_round(), "")
	assert_eq(_entry_line(event, opponent),
		"You were knocked out. The hall stays open — the rest of the event is in Standings.")
	var quitter := int(event.rounds[1][0].players[0])
	assert_eq(event.withdraw(quitter), "")
	assert_eq(_entry_line(event, quitter),
		"You withdrew. Your seat is closed; the hall stays open to follow the rest.")


func test_a_waiting_pairing_names_the_players_it_is_waiting_for() -> void:
	var event := _small_event(2)
	var pair: Dictionary = event.rounds[0][0]
	var first := "Player %d" % int(pair.players[0])
	var second := "Player %d" % int(pair.players[1])
	var panel := _panel()
	panel.present(_seat_view(event, int(pair.players[0])), true, false, false)
	panel._choose_section("overview")
	for i in 3: await get_tree().process_frame
	assert_true(_labels(panel).has("Waiting for %s and %s" % [first, second]))
	assert_eq(event.set_ready(int(pair.players[0]), true), "")
	panel.present(_seat_view(event, int(pair.players[0])), true, false, false)
	for i in 3: await get_tree().process_frame
	assert_true(_labels(panel).has("Waiting for " + second), "a confirmed player is not still waited for")


func test_return_finished_tables_appears_only_while_a_table_is_finished() -> void:
	# First to two, so the recorded game leaves the pairing waiting for the
	# next one rather than completing the whole event.
	var event := _small_event(2, 2)
	var pair: Dictionary = event.rounds[0][0]
	for pid: int in pair.players: event.set_ready(pid, true)
	assert_eq(event.begin_game(int(pair.id)), "")
	var live := _seat_view(event, 0)
	live.tables = [{"pair": int(pair.id), "life": [20, 20], "turn": 1, "step": "UNTAP"}]
	var panel := _panel()
	panel.present(live, true, false, true)
	for i in 3: await get_tree().process_frame
	assert_true(panel._view.organiser)
	assert_false(_captions(panel).has("Return finished tables to hall"), "a live table has nothing to return")
	assert_true(event.record_game(int(pair.id), int(pair.game), 0))
	var after := _seat_view(event, 0)
	after.tables = live.tables.duplicate(true)
	panel.present(after, true, false, true)
	for i in 3: await get_tree().process_frame
	assert_true(_captions(panel).has("Return finished tables to hall"), "a finished table still holds its players")


func test_a_paused_tournament_tells_a_guest_what_to_expect_not_what_to_press() -> void:
	var event := _small_event(2)
	var pair: Dictionary = event.rounds[0][0]
	var view := _seat_view(event, int(pair.players[0]))
	view.save_error = "Progress could not be saved. Tournament play is paused. Check storage, then Retry save in the Master Panel."
	var panel := _panel()
	panel.present(view, true, false, false)
	for i in 3: await get_tree().process_frame
	var notice := panel.find_child("TournamentPauseNotice", true, false) as Label
	assert_not_null(notice)
	if notice == null: return
	assert_eq(notice.text, "The host could not save progress. Play resumes when the organiser retries the save. Scores already recorded are kept.")
	assert_false(notice.text.contains("Master Panel"), "a guest cannot reach the organiser's controls")
	var master := _seat_view(event, 0)
	master.save_error = view.save_error
	var organiser_panel := _panel()
	organiser_panel.present(master, true, false, true)
	for i in 3: await get_tree().process_frame
	var own := organiser_panel.find_child("TournamentPauseNotice", true, false) as Label
	assert_not_null(own)
	if own == null: return
	assert_eq(own.text, view.save_error, "the organiser keeps the instruction they can act on")


func _standings_cell(panel: SgTournamentPanel, player_name: String, column: int) -> String:
	var table := panel.find_child("TournamentStandings", true, false) as Tree
	assert_not_null(table)
	if table == null: return ""
	var item := table.get_root().get_first_child()
	while item != null:
		if item.get_text(1) == player_name: return item.get_text(column)
		item = item.get_next()
	return ""


func test_the_master_panel_offers_rulings_only_to_the_organiser_and_flags_them() -> void:
	var event := _small_event(2, 2)
	var pair: Dictionary = event.rounds[0][0]
	for pid: int in pair.players: event.set_ready(pid, true)
	assert_eq(event.begin_game(int(pair.id)), "")
	var panel := _panel()
	panel.present(_seat_view(event, 0), true, false, true)
	for i in 3: await get_tree().process_frame
	var captions := _captions(panel)
	assert_true(captions.has("Declare Player 1 winner"), "the organiser can declare a winner over a live table")
	assert_true(captions.has("Declare Player 2 winner"))
	var guest := _panel()
	guest.present(_seat_view(event, int(pair.players[0])), true, false, false)
	for i in 3: await get_tree().process_frame
	for caption in _captions(guest):
		assert_false(caption.begins_with("Declare ") or caption.begins_with("Correct: "), "a guest is offered no ruling: " + caption)
	assert_eq(event.rule(int(pair.id), int(pair.players[1])), "")
	panel.present(_seat_view(event, 0), true, false, true)
	panel._choose_section("overview") # completion had turned the panel to Standings
	for i in 3: await get_tree().process_frame
	captions = _captions(panel)
	assert_true(captions.has("Correct: Player 1 wins"), "the losing seat can be ruled the winner instead")
	assert_false(captions.has("Correct: Player 2 wins"), "the recorded winner is not a correction")
	assert_false(captions.has("Declare Player 1 winner"), "a finished pairing is corrected, not declared")
	assert_true(_labels(panel).has("Organiser's ruling · Player 2"), "the round card flags the ruling")
	panel._choose_section("standings")
	for i in 3: await get_tree().process_frame
	var table := panel.find_child("TournamentStandings", true, false) as Tree
	assert_not_null(table)
	if table == null: return
	assert_eq(table.get_column_title(6), "Ruled W–L", "rulings are their own column, never played series")
	assert_eq(_standings_cell(panel, "Player 2", 6), "1–0")
	assert_eq(_standings_cell(panel, "Player 1", 6), "0–1")
	assert_eq(_standings_cell(panel, "Player 2", 2), "0–0", "a ruled series is not a played series")
	assert_eq(event.rule(int(pair.id), int(pair.players[0])), "")
	panel.present(_seat_view(event, 0), true, false, true)
	panel._choose_section("overview")
	for i in 3: await get_tree().process_frame
	assert_true(_labels(panel).has("Corrected by organiser · Player 1"), "the round card flags the correction")
	assert_true(_captions(panel).has("Correct: Player 2 wins"), "a correction can itself be corrected")


func test_a_manual_pause_reads_differently_for_the_organiser_and_a_guest() -> void:
	var event := _small_event(2)
	var pair: Dictionary = event.rounds[0][0]
	var running := _seat_view(event, 0)
	var panel := _panel()
	panel.present(running, true, false, true)
	for i in 3: await get_tree().process_frame
	assert_true(_captions(panel).has("Pause tournament"), "a running event can be paused by its organiser")
	assert_null(panel.find_child("TournamentPauseNotice", true, false))
	var paused := _seat_view(event, 0)
	paused.paused = true
	panel.present(paused, true, false, true)
	for i in 3: await get_tree().process_frame
	var captions := _captions(panel)
	assert_true(captions.has("Resume tournament"))
	assert_false(captions.has("Pause tournament"))
	var notice := panel.find_child("TournamentPauseNotice", true, false) as Label
	assert_not_null(notice)
	if notice == null: return
	assert_true(notice.text.contains("Resume tournament"), "the organiser is told which control lifts the pause")
	var guest_view := _seat_view(event, int(pair.players[0]))
	guest_view.paused = true
	var guest := _panel()
	guest.present(guest_view, true, false, false)
	for i in 3: await get_tree().process_frame
	var seen := guest.find_child("TournamentPauseNotice", true, false) as Label
	assert_not_null(seen)
	if seen == null: return
	assert_eq(seen.text, "The organiser paused the tournament. Every table stands still; play resumes when the organiser continues the event. Scores already recorded are kept.")
	for caption in _captions(guest):
		assert_false(caption in ["Pause tournament", "Resume tournament"], "a guest has no pause control")
	guest._choose_section("entry")
	for i in 3: await get_tree().process_frame
	var line := guest.find_child("TournamentEntryStatus", true, false) as Label
	assert_not_null(line)
	if line == null: return
	assert_eq(line.text, "The organiser paused the tournament. Your round 1 table against %s waits for play to resume."
		% event.entrant(int(pair.players[1])).name)
