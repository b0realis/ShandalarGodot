extends GutTest
## THE EXTRAS WINDOW REMEMBERS (2026-09-17 playtest — *"Deckbuilder extras
## (extra card set) selections should be persistent across open close or
## game restart. If user selects only 1997, then in next opening of the
## deck builder - only 1997 should be selected."*).
##
## The switches live on `DeckBuilderScreen.filter`; the screen writes
## them to `Settings` under [constant DeckBuilderScreen.EXTRAS_SETTING]
## when a refresh finds them moved, and reads them back in `_ready`
## before the Inventory is first drawn. Pack 1 and Pack 2 are enabled
## here so there are three switches to move and three counts to read:
## 897 originals, 999 with Fallen Empires, 1003 with Pack 1 as well.


func before_each() -> void:
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, false)
	CardPacks.set_enabled(CardPacks.ID, true)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)


func after_each() -> void:
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, false)
	CardPacks.set_current_deck_names([])
	Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)
	ShellMusic.stop()


func _open() -> DeckBuilderScreen:
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


## Close the screen the way leaving it does — the node goes, the setting stays.
func _close(screen: DeckBuilderScreen) -> void:
	screen.queue_free()
	await get_tree().process_frame


func _press(screen: DeckBuilderScreen, button_name: String) -> void:
	var button := screen.find_child(button_name, true, false) as Button
	assert_not_null(button, button_name)
	if button != null:
		button.pressed.emit()


func _pressed(screen: DeckBuilderScreen, button_name: String) -> bool:
	var button := screen.find_child(button_name, true, false) as Button
	return button != null and button.button_pressed


func test_only_1997_in_extras_is_what_the_next_opening_shows() -> void:
	var first := await _open()
	assert_eq(first._inventory.entry_count(), 1003, "everything on, nothing remembered yet")
	first._open_extra_sets()
	_press(first, "ExtraPack1Off")
	_press(first, "ExtraPack2Off")
	assert_eq(first._inventory.entry_count(), 897, "only 1997")
	assert_eq(Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, {}),
		{"original": true, "pack1": false, "sets": {"fem": false}},
		"written the moment the switch moved")
	await _close(first)
	var second := await _open()
	assert_true(second.filter.original_cards_on)
	assert_false(second.filter.completion_pack_on, "Pack 1 stays off")
	assert_false(second.filter.set_on("fem"), "Fallen Empires stays off")
	assert_eq(second._inventory.entry_count(), 897, "only 1997, as left")
	for code in CardRegistry.SET_ORDER:
		assert_true(second.filter.set_on(code), "the 1997 set strip is untouched: " + code)
	second._open_extra_sets()
	assert_true(_pressed(second, "ExtraOriginalOn"))
	assert_true(_pressed(second, "ExtraPack1Off"))
	assert_true(_pressed(second, "ExtraPack2Off"))
	# And back on: the next opening follows the latest word, not the first.
	_press(second, "ExtraPack2On")
	assert_eq(second._inventory.entry_count(), 999)
	await _close(second)
	var third := await _open()
	assert_true(third.filter.set_on("fem"))
	assert_false(third.filter.completion_pack_on)
	assert_eq(third._inventory.entry_count(), 999)


func test_select_all_is_remembered_too_and_a_keystroke_writes_nothing() -> void:
	var screen := await _open()
	var writes: int = Settings.write_count
	screen._filter_bar.search_field.text = "bear"
	screen._filter_bar.search_field.text_changed.emit("bear")
	assert_eq(Settings.write_count, writes, "a type-ahead keystroke costs no write")
	screen._open_extra_sets()
	_press(screen, "ExtraOriginalOff")
	assert_eq(Settings.write_count, writes + 1, "a moved switch costs one")
	_press(screen, "ExtraOriginalOff")
	assert_eq(Settings.write_count, writes + 1, "an already-off switch costs none")
	# `Select All` on the strip turns every source on again — and that is
	# what the next opening should show, not the Extras window's last word.
	screen.filter.select_all()
	screen._refresh_inventory()
	assert_eq(Settings.write_count, writes + 2)
	assert_eq(Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, {}),
		{"original": true, "pack1": true, "sets": {"fem": true}})
	await _close(screen)
	var next := await _open()
	assert_true(next.filter.original_cards_on)
	assert_eq(next._inventory.entry_count(), 1003)


func test_nothing_saved_or_nonsense_saved_opens_with_everything_on() -> void:
	Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING, "not a dictionary")
	var screen := await _open()
	assert_true(screen.filter.original_cards_on)
	assert_true(screen.filter.completion_pack_on)
	assert_true(screen.filter.set_on("fem"))
	assert_eq(screen._inventory.entry_count(), 1003)
	# `null` reads the stored value as it is: a `{}` default now coerces a
	# wrong-typed value to the default (campaign 2026-10-12, Settings).
	assert_eq(Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, null), "not a dictionary",
		"and opening writes nothing")
	await _close(screen)
	Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING, {"original": false, "sets": 7})
	var partial := await _open()
	assert_false(partial.filter.original_cards_on, "the one switch that was saved is honoured")
	assert_true(partial.filter.completion_pack_on)
	assert_true(partial.filter.set_on("fem"))
	var shown: int = partial._inventory.entry_count()
	assert_lt(shown, 1003, "the original printings are hidden")
	assert_gt(shown, 102, "Pack 1's names and Fallen Empires still show")
	partial.filter.original_cards_on = true
	partial._refresh_inventory()
	assert_eq(partial._inventory.entry_count(), 1003)


## A pack that is off in Options has no switch to remember. Turned on
## again later, its cards come back on — what `_on_card_packs_changed`
## has always promised — whatever the window last said about them.
func test_a_pack_enabled_later_comes_back_on_whatever_was_remembered() -> void:
	var screen := await _open()
	screen._open_extra_sets()
	_press(screen, "ExtraPack2Off")
	assert_false(screen.filter.set_on("fem"))
	await _close(screen)
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var without := await _open()
	assert_eq(without._inventory.entry_count(), 901, "Pack 1 alone")
	assert_false(without._extras_state().sets.has("fem"), "no Fallen Empires switch to remember")
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	assert_true(without.filter.set_on("fem"), "enabled again, its cards show")
	assert_eq(without._inventory.entry_count(), 1003)
	assert_eq(Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, {}).sets, {"fem": true})
