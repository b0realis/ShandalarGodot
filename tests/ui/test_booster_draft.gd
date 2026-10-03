extends GutTest
## The in-game draft: pool configuration, bounded deals, countdown and safe saves.

var saved: Dictionary = {}
var files: Array[String] = []
const FOLDER := "user://test_booster_draft"

class ResumeBuilder extends DeckBuilderScreen:
	var music_applied := 0
	func _apply_music_switch() -> void:
		music_applied += 1


## A session whose window close is COUNTED rather than obeyed: the real
## [method DraftSession._quit_game] ends the process, the test runner with it.
class QuitSpySession extends DraftSession:
	var quits := 0
	func _quit_game() -> void:
		quits += 1


func before_each() -> void:
	CardRegistry.ensure_loaded()
	for key in [DraftPoolConfig.SETTING, DraftPoolConfig.OPTIONS, GamePaths.KEY_DRAFTS]:
		saved[key] = Settings.get_value(key, 0) if Settings.has_value(key) else null
		Settings.clear_value(key)


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for key in saved:
		if saved[key] == null: Settings.clear_value(key)
		else: Settings.set_value(key, saved[key], false)
	for path in files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	files.clear()


func _store(pool: SealedPool) -> DraftStore:
	var store := DraftStore.new()
	assert_eq(store.prepare(FOLDER, pool, DraftPoolConfig.defaults()), "")
	files.append_array([store.deck_path, store.pool_path, store.deck_path + ".pending", store.pool_path + ".pending"])
	return store


func _small_pool() -> SealedPool:
	var pool := SealedPool.new()
	pool.counts = {"Lightning Bolt": 2, "Mountain": 20, "Forest": 1}
	var cards: Array[String] = []
	for card_name in pool.counts:
		for _i in pool.counts[card_name]: cards.append(card_name)
	pool.packs = [{"title": "Test pack", "cards": cards}]
	return pool


func _session() -> DraftSession:
	var session := DraftSession.new()
	session.pool = _small_pool()
	session.store = _store(session.pool)
	session.seconds = 60
	add_child_autofree(session)
	session.start_building()
	return session


func test_default_pool_is_available_without_writing_settings() -> void:
	assert_gt(DraftPoolConfig.selected().size(), 800)
	assert_false(Settings.has_value(DraftPoolConfig.SETTING))
	assert_eq(GamePaths.drafts_folder(), GamePaths.DEFAULT_DRAFTS)
	assert_false(Settings.has_value(GamePaths.KEY_DRAFTS))


func test_selected_pool_deduplicates_and_rejects_unimplemented_cards() -> void:
	Settings.set_value(DraftPoolConfig.SETTING, ["Mountain", "Mountain", "Imaginary Card", 12], false)
	assert_eq(DraftPoolConfig.selected(), ["Mountain"] as Array[String])


func test_default_deal_has_exact_pack_composition() -> void:
	var pool := DraftPoolConfig.deal(DraftPoolConfig.defaults(), DraftPoolConfig.selected())
	assert_not_null(pool)
	assert_eq(pool.total(), 105)
	assert_eq(pool.packs.size(), 4)
	for pack: Dictionary in pool.packs:
		var slots := {"rare": 0, "uncommon": 0, "common": 0, "land": 0}
		var seen: Dictionary = {}
		for card_name: String in pack.cards:
			var slot := SealedPool.slot_of(card_name)
			slots[slot] += 1
			if slot != "land": assert_false(seen.has(card_name), "No duplicate nonbasic within one pack")
			seen[card_name] = true
		assert_eq(slots, SealedPool.STARTER if pack.title.begins_with("Starter") else SealedPool.BOOSTER)


func test_legendary_marker_does_not_override_printed_pack_rarity() -> void:
	assert_eq(DeckStats.rarity_of("Tobias Andrion"), "uncommon")
	assert_eq(DeckStats.rarity_tier(CardRegistry.get_card("Tobias Andrion")), "legendary")
	assert_eq(SealedPool.slot_of("Tobias Andrion"), "uncommon")
	var sheets := SealedPool.sheets(DraftPoolConfig.library(DraftPoolConfig.selected()))
	assert_has(sheets.uncommon, "Tobias Andrion")
	assert_false(sheets.rare.has("Tobias Andrion"))
	assert_has(sheets.rare, "Tetsuo Umezawa")


func test_pack_rarities_across_seeds_and_maximum_size_use_printed_data() -> void:
	var library := DraftPoolConfig.library(DraftPoolConfig.selected())
	for seed_value in range(64):
		var pool := SealedPool.new()
		pool.boosters = 12 if seed_value == 63 else seed_value % 5
		pool.starters = 12 if seed_value == 63 else 1 + seed_value % 3
		pool.free_lands = 30 if seed_value == 63 else 2
		pool.extras = 60 if seed_value == 63 else 7
		pool.deal(library, seed_value)
		assert_eq(pool.total(), pool.card_total())
		var counted: Dictionary = {}
		for pack in pool.packs:
			var rarity := {"rare": 0, "uncommon": 0, "common": 0, "land": 0}
			var distinct: Dictionary = {}
			for card_name: String in pack.cards:
				counted[card_name] = int(counted.get(card_name, 0)) + 1
				# Independent of slot_of/sheets so a wrong dealer classification cannot pass.
				var slot := "land" if SealedPool.LAND_NAMES.has(card_name) else DeckStats.rarity_of(card_name)
				rarity[slot] += 1
				if slot != "land" and pack.title != "Random Cards": assert_false(distinct.has(card_name))
				distinct[card_name] = true
			if pack.title.begins_with("Booster"): assert_eq(rarity, SealedPool.BOOSTER)
			elif pack.title.begins_with("Starter"): assert_eq(rarity, SealedPool.STARTER)
			elif pack.title == "Free Lands":
				for land in SealedPool.LAND_NAMES: assert_eq(pack.cards.count(land), pool.free_lands)
			else: assert_eq(distinct.size(), pool.extras)
		assert_eq(counted, pool.counts)
		if seed_value == 63: assert_eq(pool.total(), DraftAudit.MAX_CARDS)


func test_each_short_rarity_sheet_refuses_launch() -> void:
	var all_names := DraftPoolConfig.selected()
	for starters in [0, 1]:
		var config := DraftPoolConfig.defaults()
		config.starters = starters
		config.boosters = 1
		var shape: Dictionary = SealedPool.STARTER if starters else SealedPool.BOOSTER
		for short_slot in SealedPool.SLOT_ORDER:
			var names: Array[String] = []
			var kept := 0
			var required := 1 if short_slot == "land" else int(shape[short_slot])
			for card_name in all_names:
				if SealedPool.slot_of(card_name) != short_slot: names.append(card_name)
				elif kept < required - 1:
					names.append(card_name)
					kept += 1
			assert_string_contains(DraftPoolConfig.validate(config, names), short_slot)
			assert_null(DraftPoolConfig.deal(config, names))


func test_receipt_exists_before_building_and_audit_is_read_only() -> void:
	var store := _store(_small_pool())
	assert_true(FileAccess.file_exists(store.pool_path))
	assert_false(FileAccess.file_exists(store.deck_path))
	var before := FileAccess.get_file_as_string(store.pool_path)
	var receipt: Dictionary = JSON.parse_string(before)
	assert_eq(DraftAudit.pool_refusal(receipt), "")
	assert_eq(receipt.collation, "printed-rarity-v1")
	var deck := DeckModel.new()
	deck.add("Lightning Bolt")
	deck.add_side("Lightning Bolt")
	assert_eq(store.checkpoint(deck), "")
	var result := DraftAudit.check_files(store.pool_path, store.deck_path)
	assert_true(result.ok)
	assert_string_contains(result.message, "1 main-deck cards and 1 sideboard cards")
	assert_eq(FileAccess.get_file_as_string(store.pool_path), before)
	assert_eq(FileAccess.get_file_as_string(store.deck_path), deck.to_text())
	assert_string_contains(DraftAudit.TRUST_NOTE, "organiser")
	assert_string_contains(DraftAudit.TRUST_NOTE, "not deck-format legality")


func test_audit_combines_duplicate_lines_and_sideboard_and_rejects_outside_cards() -> void:
	var store := _store(_small_pool())
	for text in ["1 Black Lotus", "1 Lightning Bolt\n1x Lightning Bolt\nSB: 1 Lightning Bolt"]:
		var result := DraftAudit.check(store.receipt, text)
		assert_false(result.ok)
		assert_string_contains(result.message, "Outside the saved pool")
	assert_true(DraftAudit.check(store.receipt, "// NAME: Draft\n2x Lightning Bolt\nSB: 20 Mountain").ok)
	assert_true(DraftAudit.check(store.receipt, "# unfinished\nname: Empty").ok, "Membership is not format legality")


func test_audit_refuses_corrupt_receipts_and_bounded_malformed_decks() -> void:
	var store := _store(_small_pool())
	for bad in [null, [], {}, {"schema": 200}, {"schema": 1, "counts": [], "packs": []}]:
		assert_false(DraftAudit.check(bad, "1 Mountain").ok)
	for value in [0, -1, 1.5, "2", true, INF, NAN, 999999]:
		var bad: Dictionary = store.receipt.duplicate(true)
		bad.counts["Lightning Bolt"] = value
		assert_false(DraftAudit.check(bad, "1 Mountain").ok)
	var altered := store.receipt.duplicate(true)
	altered.counts["Lightning Bolt"] = 3
	assert_string_contains(DraftAudit.check(altered, "1 Mountain").message, "do not match")
	for text in ["0 Mountain", "-1 Mountain", "1.5 Mountain", "999999999999999999999 Mountain", "1 Imaginary Card", "800 Mountain\nSB: 800 Mountain", "#".repeat(DraftAudit.DECK_BYTES + 1)]:
		assert_false(DraftAudit.check(store.receipt, text).ok)
	assert_false(DraftAudit.check_files("", "").ok)
	assert_false(DraftAudit.check_files(store.pool_path + ".missing", store.deck_path).ok)


func test_audit_refuses_oversized_files_and_invalid_json() -> void:
	var store := _store(_small_pool())
	assert_eq(DraftStore._write(store.deck_path, "#".repeat(DraftAudit.DECK_BYTES + 1)), "")
	assert_string_contains(DraftAudit.check_files(store.pool_path, store.deck_path).message, "too large")
	assert_eq(DraftStore._write(store.deck_path, "1 Mountain"), "")
	assert_eq(DraftStore._write(store.pool_path, "not json"), "")
	assert_false(DraftAudit.check_files(store.pool_path, store.deck_path).ok)
	assert_eq(DraftStore._write(store.pool_path, " ".repeat(DraftAudit.POOL_BYTES + 1)), "")
	assert_string_contains(DraftAudit.check_files(store.pool_path, store.deck_path).message, "too large")


func test_verifier_opens_from_setup_and_reports_the_selected_files() -> void:
	var setup := DraftSetup.new()
	add_child_autofree(setup)
	setup.find_child("VerifyDraftDeck", true, false).pressed.emit()
	var verifier: DraftVerifier
	for child in setup.get_children():
		if child is DraftVerifier: verifier = child
	assert_not_null(verifier)
	verifier.verify()
	assert_string_contains(verifier.report.text, "Choose both")
	var store := _store(_small_pool())
	var deck := DeckModel.new()
	deck.add("Mountain")
	assert_eq(store.checkpoint(deck), "")
	verifier.select_file("pool", store.pool_path)
	verifier.select_file("deck", store.deck_path)
	verifier.verify()
	assert_string_contains(verifier.report.text, "Pool membership matches")
	assert_eq(verifier.paths.pool.text, store.pool_path.get_file())
	assert_eq(DraftStore._write(store.deck_path, "1 Black Lotus"), "")
	verifier.verify()
	assert_string_contains(verifier.report.text, "Outside the saved pool")


func test_extras_and_lands_are_exact_and_selected() -> void:
	var names := DraftPoolConfig.selected()
	var config := DraftPoolConfig.defaults()
	config.free_lands = 3
	config.extras = 12
	var pool := DraftPoolConfig.deal(config, names)
	assert_eq(pool.total(), 132)
	for card_name in pool.names(): assert_has(names, card_name)
	assert_eq(pool.packs[-1].cards.size(), 12)
	var unique: Dictionary = {}
	for card_name in pool.packs[-1].cards: unique[card_name] = true
	assert_eq(unique.size(), 12)


func test_pool_validation_refuses_short_sheets_instead_of_under_dealing() -> void:
	assert_string_contains(DraftPoolConfig.validate(DraftPoolConfig.defaults(), ["Mountain"]), "needs at least")
	var config := DraftPoolConfig.defaults()
	config.boosters = 0
	config.starters = 0
	config.extras = 2
	assert_string_contains(DraftPoolConfig.validate(config, ["Mountain"]), "without duplicates")
	config.extras = 0
	assert_string_contains(DraftPoolConfig.validate(config, ["Mountain"]), "Add a booster")
	config.free_lands = 1
	assert_string_contains(DraftPoolConfig.validate(config, ["Mountain"]), "all five basic lands")


func test_count_and_time_limits_reject_invalid_values() -> void:
	for invalid in [-1, 1.5, 100000, "3", null, INF, NAN]:
		var config := DraftPoolConfig.defaults()
		config.boosters = invalid
		assert_ne(DraftPoolConfig.validate(config, DraftPoolConfig.selected()), "")
	var config := DraftPoolConfig.defaults()
	config.minutes = 0
	assert_ne(DraftPoolConfig.validate(config, DraftPoolConfig.selected()), "")


func test_pool_editor_changes_only_on_save_and_includes_set_groups() -> void:
	var chooser := DraftPoolDialog.new()
	add_child_autofree(chooser)
	assert_gt(chooser.groups.size(), 1)
	chooser.choose(["Mountain", "Lightning Bolt"])
	assert_false(Settings.has_value(DraftPoolConfig.SETTING))
	chooser._save()
	assert_eq(DraftPoolConfig.selected(), ["Lightning Bolt", "Mountain"] as Array[String])


func test_pool_editor_refuses_empty_save_and_searches_cards() -> void:
	var chooser := DraftPoolDialog.new()
	add_child_autofree(chooser)
	chooser.choose([])
	chooser._save()
	assert_false(Settings.has_value(DraftPoolConfig.SETTING))
	assert_string_contains(chooser.summary.text, "at least one")
	chooser._search("Lightning Bolt")
	assert_true(chooser.rows["Lightning Bolt"].visible)
	assert_false(chooser.rows["Mountain"].visible)


func test_bad_output_folder_is_refused_without_writing_settings() -> void:
	for path in ["relative/folder", "res://decks", "https://example.org/", "user://bad\nfolder"]:
		assert_ne(GamePaths.set_drafts_folder(path), "")
	assert_false(Settings.has_value(GamePaths.KEY_DRAFTS))
	assert_eq(GamePaths.set_drafts_folder(FOLDER), "")
	assert_eq(GamePaths.drafts_folder(), FOLDER)


func test_store_saves_exact_deck_and_pool_and_replaces_checkpoint() -> void:
	var pool := _small_pool()
	var store := _store(pool)
	var model := DeckModel.new()
	model.deck_name = "My Draft"
	model.add("Lightning Bolt")
	model.add_side("Forest")
	assert_eq(store.checkpoint(model), "")
	assert_eq(FileAccess.get_file_as_string(store.deck_path), model.to_text())
	model.add("Mountain")
	assert_eq(store.checkpoint(model, "done"), "")
	assert_eq(FileAccess.get_file_as_string(store.deck_path), model.to_text())
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.pool_path))
	assert_eq(receipt.state, "done")
	for card_name in pool.counts: assert_eq(int(receipt.counts[card_name]), int(pool.counts[card_name]))
	assert_false(FileAccess.file_exists(store.deck_path + ".pending"))


func test_store_rejects_outside_cards_and_over_quantity_including_sideboard() -> void:
	var store := _store(_small_pool())
	var model := DeckModel.new()
	model.add("Black Lotus")
	assert_ne(store.checkpoint(model), "")
	assert_false(FileAccess.file_exists(store.deck_path))
	model = DeckModel.new()
	model.add("Lightning Bolt")
	model.add("Lightning Bolt")
	model.add_side("Lightning Bolt")
	assert_ne(store.checkpoint(model), "")


func test_each_draft_has_a_unique_output_and_preserves_previous_deck() -> void:
	var first := _store(_small_pool())
	assert_eq(first.checkpoint(DeckModel.new()), "")
	var second := _store(_small_pool())
	assert_ne(first.deck_path, second.deck_path)
	assert_true(FileAccess.file_exists(first.deck_path))


func test_timed_builder_enforces_pool_and_blocks_escape_commands() -> void:
	var session := _session()
	var builder := session.builder
	builder._add_basic_land("Mountain", 30)
	assert_eq(builder.deck.count_of("Mountain"), 20)
	builder._add_one("Black Lotus")
	assert_eq(builder.deck.count_of("Black Lotus"), 0)
	builder._add_one("Lightning Bolt")
	builder._add_one_side("Lightning Bolt")
	builder._add_one("Lightning Bolt")
	assert_eq(builder.deck.copies_of("Lightning Bolt"), 2)
	for command in ["Load deck", "Import deck", "New deck", "Add proxy card", "Copy deck to", "Booster Draft"]:
		builder._run_command(command)
	assert_eq(builder.deck.total(), 21)
	assert_eq(builder.open_dialogs().size(), 0)
	builder._switch_slot(1)
	builder._leave_sealed()
	assert_eq(builder._slot, 0)
	assert_not_null(builder.sealed)
	assert_true(builder._dice_button.disabled)
	assert_true(builder._pool_button.disabled, "AutoDeck's pool medallion is locked too")


func test_done_finishes_once_and_saves_partial_deck() -> void:
	var session := _session()
	watch_signals(session)
	session.builder._add_one("Lightning Bolt")
	session.builder._run_command("Exit deck builder")
	session.finish("done")
	assert_true(session.finished)
	assert_signal_emit_count(session, "completed", 1)
	assert_eq(session.reason, "done")
	assert_string_contains(FileAccess.get_file_as_string(session.store.deck_path), "1 Lightning Bolt")
	assert_false(session.builder.visible)
	assert_eq(session.builder.process_mode, Node.PROCESS_MODE_DISABLED)


func test_timeout_runs_with_stats_dialog_open_and_handles_final_input() -> void:
	var session := _session()
	session.builder._add_one("Mountain")
	session.builder._open_stats()
	assert_gt(session.builder.open_dialogs().size(), 0)
	session.deadline_ms = Time.get_ticks_msec() - 1
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	session._input(key)
	assert_eq(session.reason, "time up")
	assert_eq(session.remaining_seconds(), 0)
	assert_string_contains(FileAccess.get_file_as_string(session.store.deck_path), "1 Mountain")


func test_deadline_uses_elapsed_real_time_not_frame_delta() -> void:
	var session := _session()
	var original := session.deadline_ms
	session._process(3600)
	assert_eq(session.deadline_ms, original)
	assert_false(session.finished)
	session.deadline_ms = Time.get_ticks_msec() - 1000
	session._process(0)
	assert_true(session.finished)


func test_close_during_opening_still_saves_a_partial_deck() -> void:
	var session := QuitSpySession.new()
	session.pool = _small_pool()
	session.store = _store(session.pool)
	add_child_autofree(session)
	assert_null(session.builder)
	session._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_true(session.finished)
	assert_true(FileAccess.file_exists(session.store.deck_path))


func test_setup_defaults_and_pool_summary_are_visible() -> void:
	var setup := DraftSetup.new()
	add_child_autofree(setup)
	assert_eq(setup.options(), DraftPoolConfig.defaults())
	assert_string_contains(setup.pool_summary.text, "eligible cards")
	assert_string_contains(setup.status.text, "105 cards")
	assert_false(Settings.has_value(DraftPoolConfig.OPTIONS))


## `Load deck` reads the two deck folders and nothing else, so a draft sent
## anywhere else is a real file the pickers never list. Say so before the
## draft starts rather than let "Saved to:" imply otherwise.
func test_a_save_folder_the_deck_pickers_do_not_read_says_so_before_launching() -> void:
	var setup := DraftSetup.new()
	add_child_autofree(setup)
	assert_eq(setup.folder.text, GamePaths.DEFAULT_DRAFTS)
	assert_false(setup.status.text.contains("Import deck"), "the default folder is the one Load deck reads")
	setup.folder.text = FOLDER
	setup.folder.text_changed.emit(setup.folder.text)
	assert_string_contains(setup.status.text, "Import deck")
	assert_string_contains(setup.status.text, GamePaths.DEFAULT_DRAFTS)
	setup.folder.text = GamePaths.DEFAULT_DRAFTS
	setup.folder.text_changed.emit(setup.folder.text)
	assert_false(setup.status.text.contains("Import deck"))
	assert_string_contains(setup.status.text, "105 cards")


func test_live_builder_fills_viewport_and_reserves_space_for_clock() -> void:
	var session := _session()
	await get_tree().process_frame
	assert_eq(session.builder.size, session.size)
	assert_gt(session.builder._inventory.size.x, 600.0)
	assert_gt(session.builder._inventory.size.y, 60.0)
	assert_gt(session.builder._deck_area.size.y, 100.0)
	assert_gt(session.builder._deck_area.position.y, 60.0)
	assert_gt(session.builder._inventory.position.y, 400.0)


func test_save_failure_freezes_builder_and_keeps_last_good_deck() -> void:
	var session := _session()
	session.builder._add_one("Mountain")
	assert_eq(session.store.checkpoint(session.builder.deck), "")
	var kept := FileAccess.get_file_as_string(session.store.deck_path)
	session.builder._add_one("Mountain")
	assert_eq(DirAccess.make_dir_absolute(session.store.deck_path + ".pending"), OK)
	session.finish("done")
	assert_true(session.finished)
	assert_ne(session._save_warning, "")
	var words := ""
	for child in session._result.body().get_children():
		if child is Label: words += child.text
	assert_false(words.contains("Saved as an unfinished deck"))
	assert_string_contains(words, "held in memory")
	assert_eq(FileAccess.get_file_as_string(session.store.deck_path), kept)
	assert_eq(DirAccess.remove_absolute(session.store.deck_path + ".pending"), OK)
	assert_eq(session.store.checkpoint(session.builder.deck, "done"), "")


func test_final_save_restores_a_missing_checkpoint_file() -> void:
	var store := _store(_small_pool())
	var model := DeckModel.new()
	assert_eq(store.checkpoint(model), "")
	assert_eq(DirAccess.remove_absolute(store.deck_path), OK)
	assert_eq(store.checkpoint(model, "done"), "")
	assert_true(FileAccess.file_exists(store.deck_path))


func test_actual_key_dispatch_cannot_add_a_card_after_deadline() -> void:
	var session := _session()
	await get_tree().process_frame
	session.builder._inventory.set_cursor(0)
	session.builder._inventory.grab_focus()
	session.deadline_ms = Time.get_ticks_msec() - 1
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	get_viewport().push_input(key)
	key.pressed = false
	get_viewport().push_input(key)
	assert_eq(session.builder.deck.total(), 0)
	assert_true(session.finished)


func test_opening_setup_preserves_the_original_unsaved_builder() -> void:
	var previous: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(previous)
	previous._add_one("Lightning Bolt")
	var setup := DraftSetup.open_on(previous)
	assert_false(previous.visible)
	assert_eq(previous.process_mode, Node.PROCESS_MODE_DISABLED)
	setup.queue_free()
	await get_tree().process_frame
	assert_true(previous.visible)
	assert_ne(previous.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(previous.deck.count_of("Lightning Bolt"), 1)


func test_returning_to_a_builder_restores_its_own_music_switch() -> void:
	var previous := ResumeBuilder.new()
	add_child_autofree(previous)
	var before := previous.music_applied
	var setup := DraftSetup.open_on(previous)
	setup.close_setup()
	await get_tree().process_frame
	assert_eq(previous.music_applied, before + 1)


func test_options_contains_a_draft_launch_entry() -> void:
	var options_screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(options_screen)
	var button := options_screen.find_child("LaunchDraftSetup", true, false) as Button
	assert_not_null(button)
	assert_string_contains(button.text, "Launch draft")


func test_setup_launches_an_actual_session_and_locks_its_configuration() -> void:
	var setup := DraftSetup.new()
	add_child_autofree(setup)
	setup.folder.text = FOLDER
	setup._launch()
	assert_true(setup.launching)
	assert_false(setup.window.visible)
	var sessions: Array[DraftSession] = []
	for child in setup.get_children():
		if child is DraftSession: sessions.append(child)
	assert_eq(sessions.size(), 1)
	var session := sessions[0]
	files.append_array([session.store.deck_path, session.store.pool_path])
	setup._launch()
	var actual_sessions := 0
	for child in setup.get_children():
		if child is DraftSession: actual_sessions += 1
	assert_eq(actual_sessions, 1)
	assert_eq(session.pool.total(), 105)
	session.start_building()
	session.finish("done")
	session.queue_free()
	await get_tree().process_frame
	assert_false(setup.launching)
	assert_true(setup.window.visible)


func test_clear_restore_and_undo_never_restore_a_foreign_deck() -> void:
	var session := _session()
	var builder := session.builder
	builder._add_one("Lightning Bolt")
	builder._clear_deck()
	assert_eq(builder.deck.total(), 0)
	builder._restore_deck()
	assert_eq(builder.deck.count_of("Lightning Bolt"), 1)
	assert_eq(session.store.checkpoint(builder.deck), "")
	builder._undo_last()
	assert_eq(session.store.checkpoint(builder.deck), "")


func test_finish_restores_window_close_policy_when_session_leaves() -> void:
	var before := get_tree().auto_accept_quit
	var session := _session()
	assert_false(get_tree().auto_accept_quit)
	session.finish("done")
	session.queue_free()
	await get_tree().process_frame
	assert_eq(get_tree().auto_accept_quit, before)


func test_scene_cleanup_is_not_treated_as_a_return_to_draft_setup() -> void:
	var session := _session()
	session.finish("done")
	assert_false(session.returning_to_setup)
	session.return_to_setup()
	assert_true(session.returning_to_setup)


# =============================================== BUG PASS 2026-10-03 ==

func _spy_session() -> QuitSpySession:
	var session := QuitSpySession.new()
	session.pool = _small_pool()
	session.store = _store(session.pool)
	session.seconds = 60
	add_child_autofree(session)
	session.start_building()
	return session


## The session turns `auto_accept_quit` off so a close saves first — and
## then never closed at all: the first request finished the draft and the
## window stayed, every later request returned at `finished`. A saved
## draft now lets the window go, and so does any request once finished.
func test_the_window_closes_once_the_draft_is_saved() -> void:
	var session := _spy_session()
	session.builder._add_one("Mountain")
	session._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_true(session.finished)
	assert_eq(session._save_warning, "")
	assert_eq(session.quits, 1, "the save is on disk, so the window closes")
	assert_string_contains(FileAccess.get_file_as_string(session.store.deck_path), "1 Mountain")


func test_a_close_after_the_draft_finished_closes_the_window() -> void:
	var session := _spy_session()
	session.finish("done")
	assert_eq(session.quits, 0, "Done shows the result; it does not quit")
	session._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(session.quits, 1, "the close button works on the result window")


## A save that FAILED keeps the window for its `Retry save` — the deck is
## only in memory — and a second request is the player insisting.
func test_a_failed_save_keeps_the_window_once_for_the_retry() -> void:
	var session := _spy_session()
	assert_eq(DirAccess.make_dir_absolute(session.store.deck_path + ".pending"), OK)
	session.builder._add_one("Mountain")
	session._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_true(session.finished)
	assert_ne(session._save_warning, "")
	assert_eq(session.quits, 0, "the unsaved deck is still on screen")
	session._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(session.quits, 1, "and a second close is obeyed")
	assert_eq(DirAccess.remove_absolute(session.store.deck_path + ".pending"), OK)
