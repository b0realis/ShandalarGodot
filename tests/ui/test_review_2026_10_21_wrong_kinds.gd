extends GutTest
## A WRONG KIND INSIDE A STORED LIST OR TABLE (review 2026-10-21, ui-2,
## ui-3, ui-4).
##
## `docs/player-files.md` promises that a value of the wrong kind in a
## hand-edited settings.cfg "reads as meant where it can … and as the
## default where it cannot". [method Settings.get_value] keeps that for a
## key's own value, but four readers took the ENTRIES of a stored list or
## table on trust, and `String(8)` and `bool("yes")` are script errors in
## this engine, which abort the reader:
##
##   - ui-2. `enabled_card_packs=["pack-9", 8]` read as no pack at all, so
##     the valid Pack 9 was off for the session and every deck that needs
##     it was refused, with a script error at every start.
##   - ui-3. A `test_hands_saved` table with a number for a name left the
##     Test hands screen's Saved tests list short — every test sorted after
##     the bad name could not be reached.
##   - ui-4. A `deck_builder_extras` switch written `"yes"` stopped the
##     Deck Builder's restore before it remembered what it read, and the
##     next refresh wrote the all-on state over the player's edit; a number
##     in `sealed_sets` stopped the Sealed Deck window reading its sets.
##
## Each reader now takes text as text, a number where a name is wanted as
## its digits (ui-3) or skips it (an id or set code, which a number never
## is), and a switch through [method Settings.coerce].

const KEYS := ["enabled_card_packs", "test_hands_saved", "test_hands_last",
	"deck_builder_extras", "sealed_sets"]

var _kept := {}


func before_each() -> void:
	for key in KEYS:
		_kept[key] = Settings.get_value(key, null)


func after_each() -> void:
	for key in KEYS:
		if _kept[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _kept[key])
	await get_tree().process_frame


# ============================================================ ui-2 ==

func test_a_number_among_the_card_packs_is_skipped_and_the_rest_stay_on() -> void:
	Settings.set_value("enabled_card_packs", ["pack-9", 8, &"pack-8", [7], "pack-9"])
	assert_eq(Settings.enabled_card_packs(), ["pack-9", "pack-8"] as Array[String],
		"the two real ids, once each, in order; the number and the list are not ids")


func test_a_list_of_nothing_but_numbers_reads_as_no_pack_without_an_error() -> void:
	Settings.set_value("enabled_card_packs", [2, 3.5, true])
	assert_eq(Settings.enabled_card_packs(), [] as Array[String])


# ============================================================ ui-3 ==

func _bench() -> TestHandsScreen:
	var screen: TestHandsScreen = load("res://game/test_hands_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	add_child_autofree(screen)
	return screen


func _saved_names(screen: TestHandsScreen) -> Array[String]:
	var out: Array[String] = []
	for i in screen._saved_option.item_count:
		out.append(screen._saved_option.get_item_text(i))
	return out


func test_a_saved_test_named_by_a_number_is_listed_beside_the_others() -> void:
	var position := DuelPosition.new()
	position.add(0, DuelPosition.HAND, "Serra Angel")
	var saved := {"position": position.to_dict(), "open_hands": true}
	Settings.clear_value(TestHandsScreen.LAST_KEY)
	Settings.set_value(TestHandsScreen.SAVED_KEY,
		{1: saved, "Aluren": {}, "Zoo": {}, Vector2(1, 2): {}})
	var screen := _bench()
	await get_tree().process_frame
	assert_eq(_saved_names(screen), ["1", "Aluren", "Zoo"] as Array[String],
		"every saved test listed, the number by its digits; a name that is neither text nor a number is left out")
	assert_false(screen._saved_option.disabled)
	screen._select_saved("1")
	screen._load_saved()
	assert_eq(screen.test_position.names_in(0, DuelPosition.HAND),
		["Serra Angel"] as Array[String], "and the one named by a number loads")


func test_saved_tests_reads_a_number_key_as_its_digits() -> void:
	Settings.set_value(TestHandsScreen.SAVED_KEY, {7: {}, &"Name": {}, "7": {"kept": true}})
	var saved := TestHandsScreen.saved_tests()
	assert_eq(saved.keys().size(), 2)
	assert_true(saved.has("Name"))
	assert_eq(saved.get("7"), {"kept": true}, "a text key wins over a number that reads the same")


# ============================================================ ui-4 ==

func _builder() -> Control:
	var screen: Control = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	return screen


func test_the_extras_switches_read_yes_and_no_as_meant() -> void:
	var edited := {"original": "no", "pack1": "yes", "sets": {}}
	Settings.set_value("deck_builder_extras", edited)
	var screen := _builder()
	await get_tree().process_frame
	assert_false(screen.filter.original_cards_on, "\"no\" reads as off")
	assert_true(screen.filter.completion_pack_on, "\"yes\" reads as on")
	await get_tree().process_frame
	assert_eq(Settings.get_value("deck_builder_extras", null), edited,
		"and the player's file is not written over with a state they did not choose")


func test_an_unreadable_extras_switch_is_the_default_and_on() -> void:
	Settings.set_value("deck_builder_extras", {"original": "maybe", "pack1": [1], "sets": {}})
	var screen := _builder()
	await get_tree().process_frame
	assert_true(screen.filter.original_cards_on)
	assert_true(screen.filter.completion_pack_on)


func test_a_set_switch_of_the_wrong_kind_reads_as_meant() -> void:
	# Pack 2 (the runner's metadata-only build) puts Fallen Empires in play,
	# so the Extras window has a set switch to read.
	var was_on := CardPacks.is_enabled(FallenEmpiresPack.ID)
	assert_true(CardPacks.set_enabled(FallenEmpiresPack.ID, true), "Pack 2 switched on")
	var codes := CardRegistry.extra_set_order()
	assert_false(codes.is_empty(), "an expansion set is in play")
	if not codes.is_empty():
		Settings.set_value("deck_builder_extras",
			{"original": true, "pack1": true, "sets": {codes[0]: "off"}})
		var screen := _builder()
		await get_tree().process_frame
		assert_false(screen.filter.set_on(codes[0]), "\"off\" reads as off")
	CardPacks.set_enabled(FallenEmpiresPack.ID, was_on)


func test_a_number_among_the_sealed_sets_is_skipped() -> void:
	var active := CardRegistry.active_set_order()
	var real := String(active[0])
	Settings.set_value("sealed_sets", [4, real, &"zzz", real])
	var screen := _builder()
	await get_tree().process_frame
	assert_eq(screen._sealed_sets(), [real] as Array[String],
		"the set in play, once; the number and the unknown code are not")
