extends GutTest
## Cosmetic preferences never create extra rules identities or reveal a hand.

func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-6", true)

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_current_deck_names([])
	Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)
	ShellMusic.stop()
	# Pack toggles notify the still-mounted builder; let its deferred UI
	# refreshes retire before GUT measures orphaned nodes.
	for i in 3: await get_tree().process_frame

func test_deck_and_community_round_trip_keep_art_without_changing_counts() -> void:
	var model := DeckModel.new()
	model.add("Forest")
	model.add("Forest")
	model.add_side("Island")
	model.printings = {"Forest": "por:215", "Island": "por:203", "Plains": "por:199"}
	var copy := model.duplicate_model()
	copy.printings.Forest = "por:214"
	assert_eq(model.printings.Forest, "por:215")
	for text in [model.to_text(), model.to_dec_text()]:
		var deck := DeckList.new()
		deck.parse(text)
		assert_eq(deck.errors, [])
		assert_eq(deck.cards, ["Forest", "Forest"])
		assert_eq(deck.sideboard, ["Island"])
		assert_eq(deck.printings, {"Forest": "por:215", "Island": "por:203"})
		assert_eq(DeckModel.from_deck_list(deck).printings, deck.printings)
		var report: Array = []
		var imported := DeckStore.import_text(text, "Imported", report)
		assert_not_null(imported)
		if imported != null: assert_eq(imported.printings, deck.printings, "Load/import must not discard comments")
		assert_true(deck.required_packs.is_empty(), "art is not a rules dependency")
	model.clear()
	assert_true(model.printings.is_empty())

func test_optional_comments_are_bounded_and_unavailable_ids_survive() -> void:
	var deck := DeckList.new()
	deck.parse('# printing: ["Forest","por:999"]\n# printing: ["Island","../../x"]\n# printing: broken\n2 Forest\n1 Island')
	assert_eq(deck.errors, [])
	assert_eq(deck.printings, {"Forest": "por:999"})
	assert_true(CardPrintings.resolve("Forest", "por:999").is_empty())
	assert_string_contains(DeckModel.from_deck_list(deck).to_text(), "por:999")
	for bad in [null, 1, [], {}, "", "res://x", "por:../215", "POR:215", "por:215:x"]:
		assert_false(DeckPrintings.valid_id(bad), str(bad))
	assert_false(DeckPrintings.valid_map({"Island": "por:203"}, ["Forest"]))

func test_portal_has_twenty_lands_and_reprints_share_identity() -> void:
	var total := 0
	for land in ["Plains", "Island", "Swamp", "Mountain", "Forest"]:
		var rows := CardPrintings.choices(land).filter(func(row: Dictionary) -> bool: return row.set == "por")
		assert_eq(rows.size(), 4, land)
		total += rows.size()
		assert_eq(rows.map(func(row: Dictionary) -> String: return row.id).size(), 4)
	assert_eq(total, 20)
	assert_eq(CardPrintings.resolve("Forest", "por:215").number, "215")
	assert_true(CardPrintings.resolve("Island", "por:215").is_empty())
	assert_true(CardPacks.art_path("Island", "por", false, "215").is_empty())
	assert_eq(CardPrintings.resolve("Forest", "por:215").id, "por:215")
	assert_gt(CardPrintings.choices("Forest").size(), 4, "original and Portal coexist")
	CardPacks.set_enabled("pack-6", false)
	assert_true(CardPrintings.resolve("Forest", "por:215").is_empty(), "cache follows toggles")
	assert_false(CardPrintings.choices("Forest").is_empty(), "native fallback remains")

func test_builder_selector_and_undo_keep_one_preference_per_name() -> void:
	var screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.filter.original_cards_on = false
	screen.filter.completion_pack_on = false
	screen._refresh_inventory()
	assert_eq(screen._inventory.entry_count(), 318, "both Portal sets deduplicate shared names")
	assert_eq(screen._printing_count, 380)
	screen.filter.sets["p02"] = false
	screen.filter.revision += 1
	screen._refresh_inventory()
	assert_eq(screen._inventory.entry_count(), 200)
	assert_eq(screen._printing_count, 215)
	assert_eq(screen._count_label.text, "200 cards / 215 printings")
	assert_eq(screen._count_label.max_lines_visible, 1)
	screen._add_one("Forest")
	screen._show_in_showcase(CardRegistry.get_card("Forest"))
	assert_false(screen._variant_button.disabled)
	screen._choose_printing("Forest", "por:215")
	assert_eq(screen.deck.total(), 1)
	assert_eq(screen._showcase._shown_printing_set, "por:215")
	assert_eq(screen._deck_area.art_set_for.call(CardRegistry.get_card("Forest")), "por:215")
	assert_eq(screen._sideboard_area.art_set_for.call(CardRegistry.get_card("Forest")), "por:215")
	assert_true(screen._undo.printings.is_empty())
	screen._undo_last()
	assert_false(screen.deck.printings.has("Forest"))
	screen._undo_last()
	assert_eq(screen.deck.printings.Forest, "por:215")
	var chosen := []
	var dialog := CardVariantDialog.create("Forest", "por:215", func(id: String) -> void: chosen.append(id))
	add_child_autofree(dialog)
	await get_tree().process_frame
	assert_true(dialog.get_global_rect().encloses(dialog._buttons.get_global_rect()))
	dialog._buttons.get_child(0).pressed.emit()
	assert_eq(chosen, ["por:215"])
	screen._choose_printing("Forest", "")
	assert_false(screen.deck.printings.has("Forest"))
	await get_tree().process_frame
	await get_tree().process_frame

func test_reprints_from_several_enabled_sets_share_the_same_card() -> void:
	CardPacks.set_enabled("pack-1", true)
	CardPacks.set_enabled("pack-3", true)
	var rows := CardPrintings.choices("Plains")
	var sets := rows.map(func(row: Dictionary) -> String: return row.set)
	assert_true(sets.has("2ed"))
	assert_true(sets.has("4ed"))
	assert_true(sets.has("ice"))
	assert_true(sets.has("por"))
	assert_false(CardPrintings.resolve("Plains", "4ed").is_empty())
	assert_false(CardPrintings.resolve("Plains", "por:199").is_empty())

func test_variant_medallion_floats_over_information_without_changing_layout() -> void:
	var screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen._add_one("Forest")
	screen._show_in_showcase(CardRegistry.get_card("Forest"))
	screen._choose_printing("Forest", "por:215")
	var button: Button = screen._variant_button
	assert_eq(button.text, "", "compact icon, not a full-width text button")
	assert_eq(button.focus_mode, Control.FOCUS_ALL)
	assert_string_contains(button.tooltip_text, "Card variant")
	assert_string_contains(button.tooltip_text, "#215")
	assert_eq(button.get_theme_stylebox("normal").texture, GameSkin.our_art("card_variant_on"))
	assert_eq(button.get_theme_stylebox("disabled").texture, GameSkin.our_art("card_variant_off"))
	for big in [true, false]:
		for viewport_size in [Vector2(1280, 800), Vector2(960, 720)]:
			for sideboard in [0, 15]:
				screen._big_cards = big
				screen.size = viewport_size
				screen.deck.sideboard = {} if sideboard == 0 else {"Island": sideboard}
				screen.refresh()
				screen._layout()
				for i in 4: await get_tree().process_frame
				var card: Rect2 = screen._showcase.get_global_rect()
				var medallion := button.get_global_rect()
				assert_eq(button.size, Vector2(32, 32))
				assert_almost_eq(medallion.end.x, card.end.x, 0.01)
				assert_almost_eq(medallion.position.y, card.end.y + 6, 0.01)
				assert_false(medallion.intersects(card), "never cover the card's text or P/T")
				assert_true(medallion.intersects(screen._left_scroll.get_global_rect()),
					"floats over information, without reserving any space")
				assert_eq(screen._deck_area.position.x, 330.0 if big else 270.0,
					"original deck position, no added gutter")
				assert_eq(screen._sideboard_area.position.x, screen._deck_area.position.x)
				assert_eq(screen._left_scroll.position.y, card.end.y + 6)
				var expected_width: float = screen._left_width()
				if big: expected_width -= screen._left_scroll.get_v_scroll_bar().get_combined_minimum_size().x
				assert_eq(screen._stats_label.custom_minimum_size.x, expected_width,
					"the medallion takes no text width")
				assert_eq(screen._left_scroll.size.x, screen._left_width())
				screen._left_scroll.scroll_vertical = 999
				await get_tree().process_frame
				assert_eq(button.get_global_rect(), medallion, "information scroll cannot move the button")
	button.grab_focus()
	assert_true(button.has_focus())
	assert_gt(button.get_index(), screen._left_scroll.get_index(), "receives pointer input over the scroll area")
	assert_gt(button.z_index, screen._left_scroll.z_index)
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	get_viewport().push_input(motion, true)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = motion.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		get_viewport().push_input(click, true)
	await get_tree().process_frame
	assert_eq(screen.open_dialogs().size(), 1, "real pointer click reaches the floating icon")
	for dialog in screen.open_dialogs(): dialog.dismiss()
	for i in 3: await get_tree().process_frame
	screen._show_in_showcase(ProxyCard.data_for("Unknown illustration"))
	assert_false(button.visible, "proxies have no printings to choose")
	screen._show_in_showcase(CardRegistry.get_card("Forest"))
	assert_true(button.visible)


func test_match_configuration_and_tournament_checkpoint_keep_preferences() -> void:
	var match_screen := MatchScreen.new()
	match_screen.config = DuelConfig.hotseat_default()
	match_screen.config.printings[0] = {"Forest": "por:215"}
	var config := match_screen._config_for_this_duel()
	assert_eq(config.printings[0], {"Forest": "por:215"})
	config.printings[0].Forest = "por:214"
	assert_eq(match_screen.config.printings[0].Forest, "por:215", "independent configuration copy")
	match_screen.free()
	var names: Array = []
	for i in 40: names.append("Forest")
	var deck := {"name": "Forest", "cards": names, "sideboard": [], "printings": {"Forest": "por:215"}}
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Artwork", "limit": 2, "wins": 1, "policy": "own", "decks": []}, 7), "")
	var pid := event.register("One", "a".repeat(64))
	assert_eq(event.select_deck(pid, deck), "")
	var restored := SgTournament.new()
	assert_eq(restored.restore(event.checkpoint()), "")
	assert_eq(restored.entrant(pid).deck.printings, deck.printings)

func test_local_duel_stamps_instances_without_changing_registry() -> void:
	var game := MtgGame.new()
	game.setup(["Forest", "Island"], ["Forest"], "One", "Two", 20, 20, 7)
	CardPrintings.apply_game(game, [{"Forest": "por:215"}, {"Forest": "por:213"}])
	for pid in 2:
		for card in game.players[pid].library:
			if card.data.card_name == "Forest":
				assert_eq(CardPrintings.of(card), "por:215" if pid == 0 else "por:213")
				card.controller_id = 1 - pid
				assert_eq(CardPrintings.of(card), "por:215" if pid == 0 else "por:213")
				card.face_down = true
				assert_eq(CardPrintings.of(card), "")
			else: assert_eq(CardPrintings.of(card), "")
	assert_ne(CardRegistry.get_card("Forest").set_code, "por")

func test_lan_decks_and_visible_cards_retain_cosmetics_but_masks_do_not() -> void:
	var names: Array = []
	for i in 40: names.append("Forest")
	var deck := {"name": "Forest", "cards": names, "sideboard": [], "printings": {"Forest": "por:215"}}
	assert_eq(SgDeckCatalog.payload(deck), deck)
	assert_true(SgViewProtocol.deck(deck))
	var message := {"v": SgProtocol.VERSION, "type": "command", "seq": 1, "room": "", "revision": 0,
		"action": deck.merged({"op": "deck"})}
	assert_true(SgProtocol.valid(message))
	var duel := SgPracticeMatch.new(42, [deck, {}])
	var view := duel.view(0)
	assert_true(SgViewProtocol.cards(view.hand))
	assert_eq(view.hand[0].printing, "por:215")
	assert_false(JSON.stringify(duel.view(1)).contains("por:215"), "opponent gets no hand/deck artwork map")
	var instance := SgCardPresentation.make(view.hand[0], 0, Mtg.Zone.HAND)
	assert_eq(CardPrintings.of(instance), "por:215")
	var card: CardInstance = duel.game.players[0].hand[0]
	card.face_down = true
	var masked := duel._cards(0, [card])
	assert_eq(masked[0].printing, "")
	assert_true(SgViewProtocol.cards(masked))
	SgCardPresentation.make(masked[0], 0, Mtg.Zone.HAND, instance)
	assert_eq(CardPrintings.of(instance), "")
	masked[0].printing = "por:215"
	assert_false(SgViewProtocol.cards(masked), "masked art would leak identity")
	message.action.printings = {"Forest": "../../file"}
	assert_false(SgProtocol.valid(message))
