extends GutTest
## Robustness campaign 2026-10-12 — the battle-setup screen.
##
##   * b2-1: `<random deck>` and `<random from …>` draw only decks the chosen
##     format accepts; the pooled rows are re-dealt when the format changes;
##     an empty bag is said under the picker and on `Go!`.
##   * b2-10: an emptied Name field never reaches the duel blank, and the
##     field is capped.
##   * b2-11: a deck whose pack is not installed is not sent to Options to
##     enable it.
##   * r2-9: Escape (the Quest's back gesture, a handheld's Start) is `Back`,
##     a popup that is up closing first.

var screen: SetupScreen
var _was: Node = null


func before_each() -> void:
	SetupScreen.forget_choices()
	screen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	SetupScreen.forget_choices()


func _choose_format(format: String) -> void:
	var index := DeckFormat.ORDER.find(format)
	screen._format_option.select(index)
	screen._format_option.item_selected.emit(index)


func _pooled_rows(option: OptionButton) -> Array[String]:
	var out: Array[String] = []
	for i in option.item_count:
		var meta := str(option.get_item_metadata(i))
		if not option.is_item_separator(i) and meta.begins_with(SetupScreen.GROUP_RANDOM):
			out.append(meta.substr(SetupScreen.GROUP_RANDOM.length()))
	return out


# ------------------------------------------------------------- b2-1 --

func test_random_deck_draws_only_decks_the_chosen_format_accepts() -> void:
	for format in DeckFormat.ORDER:
		_choose_format(format)
		for pid in 2:
			screen._deck_options[pid].select(0)          # <random deck>
		var refused: Array[String] = []
		for seed_value in range(1, 31):
			var picker := RandomNumberGenerator.new()
			picker.seed = seed_value
			for pid in 2:
				var path := screen._deck_path_for(pid, picker)
				assert_ne(path, "", "%s: seed %d drew a deck" % [format, seed_value])
				var deck := DeckList.load_file(path, true)
				var refusal := DeckFormat.legal(deck.cards, format, deck.sideboard)
				if refusal != "":
					refused.append("%s seed %d: %s" % [format, seed_value, refusal])
		assert_eq(refused, [] as Array[String], "%s: no drawn deck is refused" % format)


func test_go_starts_a_random_duel_under_every_format() -> void:
	for format in DeckFormat.ORDER:
		_choose_format(format)
		for pid in 2:
			screen._deck_options[pid].select(0)
		for seed_value in [3, 17, 4242]:
			screen._seed_edit.text = str(seed_value)
			assert_not_null(screen._build_config(), "%s, seed %d" % [format, seed_value])
	for child in screen.get_children():
		assert_false(child is Control and (child as Control).z_index == 300,
			"no refusal popup went up")


func test_the_pooled_rows_are_redealt_for_the_format() -> void:
	var option: OptionButton = screen._deck_options[0]
	var unrestricted := _pooled_rows(option)
	assert_true(unrestricted.has(DeckGroups.ORIGINALS), "the 1997 pool is offered")
	_choose_format(DeckFormat.HIGHLANDER)
	var highlander := _pooled_rows(option)
	for group in highlander:
		var legal: Array = screen._grouped_format_playable().get(group, [])
		assert_gte(legal.size(), 2, "%s offered under Highlander with %d decks" % [group, legal.size()])
	assert_false(highlander.has(DeckGroups.ORIGINALS),
		"no two 1997 originals are Highlander decks, so the row goes")
	# The seat that sat on the vanished row falls back to `<random deck>`.
	assert_eq(str(option.get_selected_metadata()), "", "back on <random deck>")
	_choose_format(DeckFormat.UNRESTRICTED)
	assert_eq(_pooled_rows(option), unrestricted, "and the rows come back")


func test_a_pooled_row_draws_only_its_decks_that_the_format_accepts() -> void:
	_choose_format(DeckFormat.TOURNAMENT_T15)
	var option: OptionButton = screen._deck_options[0]
	var rows := _pooled_rows(option)
	assert_false(rows.is_empty(), "some pool survives Tournament (Type 1.5)")
	for group in rows:
		option.select(SetupScreen._row_of_group(option, group))
		var bag: Array = screen._grouped_format_playable()[group]
		assert_true(option.get_item_tooltip(option.selected).contains(
			"%d decks under %s" % [bag.size(), group]), "the tooltip counts the format's bag")
		for seed_value in range(1, 21):
			var picker := RandomNumberGenerator.new()
			picker.seed = seed_value
			var path := screen._deck_path_for(0, picker)
			assert_true(bag.has(path), "%s seed %d stays in its bag" % [group, seed_value])
			assert_eq(DeckGroups.of(path), group)
			var deck := DeckList.load_file(path, true)
			assert_eq(DeckFormat.legal(deck.cards, DeckFormat.TOURNAMENT_T15, deck.sideboard), "",
				"%s seed %d: %s meets the format" % [group, seed_value, path.get_file()])


func test_unrestricted_draws_exactly_as_before() -> void:
	# The seed replays the same duel: under Unrestricted the bag is the
	# whole playable list, in the same order, as it always was.
	for seed_value in range(1, 25):
		var a := RandomNumberGenerator.new()
		a.seed = seed_value
		var b := RandomNumberGenerator.new()
		b.seed = seed_value
		screen._deck_options[0].select(0)
		assert_eq(screen._deck_path_for(0, a),
			SetupScreen.random_deck_path(screen._playable_paths, b))


func test_an_empty_bag_is_said_under_the_picker_and_on_go() -> void:
	_choose_format(DeckFormat.HIGHLANDER)
	screen._deck_options[0].select(0)
	# Every deck the format accepted, taken away: nothing left to draw.
	screen._legal_by_format[DeckFormat.HIGHLANDER] = {
		"paths": [] as Array[String], "grouped": {}}
	screen._refresh_format_note()
	assert_string_contains(screen._format_note.text,
		"Seat 1 — No deck in the list meets Highlander.")
	screen._seed_edit.text = "9"
	assert_null(screen._build_config(), "Go! refuses")
	var said := ""
	for node in screen.find_children("*", "Label", true, false):
		said += (node as Label).text + "\n"
	assert_string_contains(said, "No deck in the list meets Highlander.")


func test_a_remembered_format_brings_its_own_rows() -> void:
	_choose_format(DeckFormat.HIGHLANDER)
	screen._remember_choices()
	var fresh: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(fresh)
	assert_eq(fresh.deck_format(), DeckFormat.HIGHLANDER)
	assert_false(_pooled_rows(fresh._deck_options[0]).has(DeckGroups.ORIGINALS),
		"the reopened screen carries Highlander's rows")


# ------------------------------------------------------------ b2-10 --

func test_a_blank_name_takes_the_seat_default() -> void:
	screen._apply_mode(SetupScreen.BattleMode.HOTSEAT)
	screen._name_edits[0].text = "   "
	screen._name_edits[1].text = ""
	screen._seed_edit.text = "7"
	var config := screen._build_config()
	assert_not_null(config)
	if config != null:
		assert_eq(config.player_names[0], "Player 1")
		assert_eq(config.player_names[1], "Player 2")
	screen._apply_mode(SetupScreen.BattleMode.VS_AI)
	screen._name_edits[1].text = " "
	config = screen._build_config()
	if config != null:
		assert_eq(config.player_names[1], "HAL 9000")


func test_a_name_is_trimmed_and_capped() -> void:
	assert_eq(screen._name_edits[0].max_length, SetupScreen.SEAT_NAME_MAX)
	screen._name_edits[0].text = "  Merlin  "
	screen._seed_edit.text = "7"
	var config := screen._build_config()
	if config != null:
		assert_eq(config.player_names[0], "Merlin")


# ------------------------------------------------------------ b2-11 --

const PACK_DECK := "user://decks/_c2_f_deck_needs_pack_9.deck"


func test_a_pack_that_is_not_installed_is_not_called_disabled() -> void:
	var packs := get_node("/root/CardPacks")
	if not packs.has_pack("pack-9"):
		pending("needs the Pack 9 test zip")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(PACK_DECK, FileAccess.WRITE)
	file.store_string("# requires-pack: pack-9\nname: Synced Tempest\n36 Swamp\n4 Dauthi Slayer\n")
	file.close()
	var saved: Dictionary = packs._available["pack-9"]
	packs._available.erase("pack-9")          # the zip is not on this device
	var fresh: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(fresh)
	var said := fresh._pack_refusal(PACK_DECK)
	packs._available["pack-9"] = saved
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PACK_DECK))
	assert_true(fresh._pack_paths.has(PACK_DECK), "listed as needing its pack")
	assert_false(said.contains("disabled"), "not 'disabled': " + said)
	assert_false(said.contains("Enable the pack"), said)
	assert_string_contains(said, "This deck requires Pack 9.")
	assert_string_contains(said, "The exact %s file is not available" % packs.file_name_for("pack-9"))
	assert_string_contains(said, "Card Packs folder and Rescan from Options.")


func test_a_pack_that_is_only_off_keeps_its_sentence() -> void:
	var packs := get_node("/root/CardPacks")
	if not packs.has_pack("pack-9"):
		pending("needs the Pack 9 test zip")
		return
	screen._pack_paths["user://decks/x.deck"] = ["pack-9"]
	assert_eq(screen._pack_refusal("user://decks/x.deck"),
		"This deck requires Pack 9, which is disabled. Enable the pack under Options, Card packs, and come back.")


# ------------------------------------------------------------- r2-9 --

func _escape() -> InputEventKey:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	return esc


func test_escape_closes_a_popup_before_it_leaves() -> void:
	screen._explain_formats()
	var popup := screen._open_popup
	assert_not_null(popup)
	screen._unhandled_input(_escape())
	assert_true(popup.is_queued_for_deletion(), "the popup closed")
	assert_false(screen._leaving, "and the screen stayed")


func test_escape_is_back_to_the_title() -> void:
	_was = get_tree().current_scene
	var own: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	get_tree().root.add_child(own)
	get_tree().current_scene = own
	await get_tree().process_frame
	own._unhandled_input(_escape())
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	assert_not_null(scene)
	if scene != null:
		assert_eq(scene.scene_file_path, "res://game/main.tscn", "Escape went back to the title")
		if scene.scene_file_path == "res://game/main.tscn":
			scene.queue_free()
	get_tree().current_scene = _was if is_instance_valid(_was) else null
	await get_tree().process_frame
