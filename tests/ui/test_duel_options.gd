extends GutTest
## THE DUEL OPTIONS PANEL — `docs/duel-todo.md` §6.4.
##
## `@DIALOG_DUELOPTIONS` (`shandalar-src/Program/UIStrings.txt:598`) is
## nineteen strings; `Duel.hlp`, topic **Dueling Options**, says what each
## one does and that *"These settings are retained for future duels."*
## Every string is pinned here verbatim, because the whole value of the
## panel is that it is the ORIGINAL's list and not a list of ours.


var _saved: Dictionary = {}


func before_each() -> void:
	# The panel writes straight to user://settings.cfg, so anything a test
	# touches is remembered BEFORE the write and put back afterwards: the
	# player's own value when they had one, and nothing at all when they
	# did not — writing a default back would MATERIALISE it into their
	# file, which is the bug `Settings.clear_value` exists for.
	_saved = {}


func after_each() -> void:
	for key in _saved:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])


## Call BEFORE writing [param key]: snapshots the player's own value.
func _touch(key: String) -> void:
	if _saved.has(key):
		return
	_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null


## Call before READING a shipped default: snapshots the player's value the
## same way and then takes it out of the file, so what the test reads is
## the default and not whatever this machine happens to hold.
##
## It is not hypothetical. `./duel_soak.sh` drives a FUZZED human seat
## through the live duel screen, which includes this panel, and one soak
## on 2026-09-03 left `PlayerTerritoryColor="Red"` in the settings file —
## after which "the original ships on Deck color" failed on that machine
## and nowhere else. A test that asserts a default has to own the absence
## of a value, not assume it.
func _unset(key: String) -> void:
	_touch(key)
	Settings.clear_value(key)


# ------------------------------------------------------- the 19 strings --

func test_the_table_is_the_originals_nineteen_entries() -> void:
	var entries: Array[String] = [DuelOptions.TITLE,
		DuelOptions.LAYOUT_LABEL, DuelOptions.LAYOUT_STANDARD,
		DuelOptions.LAYOUT_ADVANCED]
	for row in DuelOptions.TOGGLES:
		entries.append(String(row["label"]))
	entries.append(DuelOptions.TERRITORY_LABEL)
	entries.append_array(DuelOptions.TERRITORY_COLORS)
	for row in DuelOptions.TERRITORY_TYPES:
		entries.append(String(row["label"]))
	assert_eq(entries, [
		"Duel Options",
		"Layout", "Standard", "Advanced",
		"Show coin flip animations",
		"Show cue cards",
		"Show abilities on small cards",
		"Show power/toughness on small cards",
		"See next draws at end of duel",
		"Your territory background",
		"White", "Blue", "Black", "Red", "Green", "Deck color",
		"Line drawing", "Pattern", "Mana symbols",
	], "UIStrings.txt:598-618, ampersands dropped, order kept")
	assert_eq(entries.size(), 19)


func test_the_keys_are_the_originals_registry_names() -> void:
	# `Software\\MicroProse\\Magic: The Gathering\\DuelOptions`. Keeping the
	# original's spelling makes a 1997 registry export readable straight
	# into user://settings.cfg.
	var keys: Array[String] = []
	for row in DuelOptions.TOGGLES:
		keys.append(String(row["key"]))
	assert_eq(keys, ["ShowCoinFlips", "ShowCueCards", "ShowAbilitiesOnCards",
		"ShowPowerToughnessOnCards", "SeeNextDrawsAtEndOfDuel"])


func test_every_switch_starts_ON_as_the_original_ships() -> void:
	for row in DuelOptions.TOGGLES:
		_unset(String(row["key"]))
	_unset("Layout")
	_unset("PlayerTerritoryColor")
	for row in DuelOptions.TOGGLES:
		assert_true(DuelOptions.toggle(String(row["key"])),
			"%s defaults on" % row["key"])
	assert_eq(DuelOptions.layout(), "Standard")
	assert_eq(DuelOptions.territory_color(), "Deck color")


func test_a_switch_is_retained_for_future_duels() -> void:
	# "These settings are retained for future duels" — so they persist,
	# rather than living on the screen.
	_touch("ShowCueCards")
	DuelOptions.set_toggle("ShowCueCards", false)
	assert_false(DuelOptions.toggle("ShowCueCards"))
	assert_false(bool(Settings.get_value("ShowCueCards", true)),
		"and it went to the settings file, not to a member")


# ---------------------------------------------------- the territory box --

func test_the_opponents_ground_never_follows_your_choice() -> void:
	# "You cannot do anything to change the background in your opponent's
	# territory; it matches the predominant color in her deck."
	_touch("PlayerTerritoryColor")
	DuelOptions.set_territory_color("Red")
	assert_eq(DuelOptions.ground_color_for(0, 0, "green"), "red",
		"your own half takes the choice")
	assert_eq(DuelOptions.ground_color_for(1, 0, "blue"), "blue",
		"theirs stays their deck's colour")


func test_deck_color_is_the_behaviour_we_had_before_the_panel() -> void:
	_unset("PlayerTerritoryColor")
	assert_eq(DuelOptions.ground_color_for(0, 0, "green"), "green")


func test_the_style_list_carries_the_originals_own_file_suffixes() -> void:
	# `Terr_<Colour><Type>.bmp` in Program/DuelArt/ — Pict is the line
	# drawing, Patt the pattern, Mana the symbols. That naming is what
	# settles which label means which art.
	var suffixes: Array[String] = []
	for row in DuelOptions.TERRITORY_TYPES:
		suffixes.append(String(row["suffix"]))
	assert_eq(suffixes, ["pict", "patt", "mana"])


func test_every_one_of_the_nine_choices_has_its_own_skin_key() -> void:
	# All fifteen `Terr_<Colour><Type>` files are imported (2026-09-02),
	# so no style stands in for another any more: choosing `Line drawing`
	# and being shown the pattern would be the panel lying about itself.
	var keys: Array[String] = []
	for color in ["white", "blue", "black", "red", "green"]:
		for row in DuelOptions.TERRITORY_TYPES:
			keys.append(DuelOptions.ground_key(color, String(row["label"])))
	assert_eq(keys.size(), 15)
	assert_eq(keys, [
		"duel_picture_white", "duel_pattern_white", "duel_mana_white",
		"duel_picture_blue", "duel_pattern_blue", "duel_mana_blue",
		"duel_picture_black", "duel_pattern_black", "duel_mana_black",
		"duel_picture_red", "duel_pattern_red", "duel_mana_red",
		"duel_picture_green", "duel_pattern_green", "duel_mana_green",
	])
	# ...and every one of the fifteen is a DIFFERENT key.
	var seen: Dictionary = {}
	for key in keys:
		seen[key] = true
	assert_eq(seen.size(), 15, "no two choices share a key")


func test_ground_key_is_pure_and_does_not_consult_the_skin() -> void:
	# It answers the same on a machine with the 1997 art and one without,
	# which is what lets the nine choices be pinned headlessly. Whether
	# the art is PRESENT is TerritoryGround's question.
	assert_eq(DuelOptions.ground_key("magenta", "Pattern"),
		"duel_pattern_magenta")
	assert_eq(DuelOptions.ground_key("green", "no such style"),
		"duel_pattern_green", "an unreadable type falls back to Pattern")


# --------------------------------------------------------- the wiring --

func test_the_panel_builds_with_every_control() -> void:
	var dialog := DuelOptions.window()
	add_child_autofree(dialog)
	var found: Array[String] = []
	var stack: Array = [dialog]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is CheckBox:
				found.append(child.text)
			stack.append(child)
	assert_true(found.has("Standard") and found.has("Advanced"),
		"the Layout pair")
	for row in DuelOptions.TOGGLES:
		assert_true(found.has(String(row["label"])), String(row["label"]))


func test_advanced_layout_is_listed_and_greyed() -> void:
	# SIMPLIFIED: Advanced removes the permanent Showcase and re-flows the
	# table around the space — a layout milestone, not a switch. The
	# original greys what it cannot offer rather than shortening its menu
	# (`Duel.hlp`, **Territory**), which is the call §6.1 already made.
	var dialog := DuelOptions.window()
	add_child_autofree(dialog)
	var stack: Array = [dialog]
	var advanced: CheckBox = null
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is CheckBox and child.text == "Advanced":
				advanced = child
			stack.append(child)
	assert_not_null(advanced)
	assert_true(advanced.disabled)


# ------------------------------------ what the switches actually govern --

func test_show_power_toughness_gates_the_small_cards_numbers() -> void:
	_touch("ShowPowerToughnessOnCards")
	var data := CardRegistry.get_card("Grizzly Bears")
	var inst := CardInstance.new(data, 1, 0)
	inst.zone = Mtg.Zone.BATTLEFIELD
	var card := MiniCard.new(inst, null)
	add_child_autofree(card)
	assert_eq(card._pt_label.text, "2/2")
	DuelOptions.set_toggle("ShowPowerToughnessOnCards", false)
	card.refresh()
	assert_eq(card._pt_label.text, "", "the numbers came off the card")


func test_show_cue_cards_gates_the_tooltip_hints_but_not_the_card() -> void:
	# "…controls the appearance of the tiny hints that pop up when you
	# position the mouse cursor over an active location." The card's own
	# name and rules text are not a cue card.
	_touch("ShowCueCards")
	var data := CardRegistry.get_card("Grizzly Bears")
	var inst := CardInstance.new(data, 2, 0)
	inst.zone = Mtg.Zone.BATTLEFIELD
	inst.tapped = true
	var card := MiniCard.new(inst, null)
	add_child_autofree(card)
	var with_cues := card.tooltip_text
	assert_true(with_cues.contains("Grizzly Bears"))
	DuelOptions.set_toggle("ShowCueCards", false)
	card.refresh()
	assert_true(card.tooltip_text.contains("Grizzly Bears"),
		"the card still names itself")
	assert_lt(card.tooltip_text.length(), with_cues.length(),
		"but the hints are gone")


func test_show_abilities_gates_the_badges() -> void:
	_touch("ShowAbilitiesOnCards")
	var data := CardRegistry.get_card("Serra Angel")
	var inst := CardInstance.new(data, 3, 0)
	inst.zone = Mtg.Zone.BATTLEFIELD
	inst.cur_keywords = data.keywords.duplicate()
	var card := MiniCard.new(inst, null)
	add_child_autofree(card)
	assert_gt(card._badges.get_child_count(), 0, "flying and vigilance")
	DuelOptions.set_toggle("ShowAbilitiesOnCards", false)
	card.refresh()
	assert_eq(card._badges.get_child_count(), 0)


func test_see_next_draws_shows_both_seats_next_card() -> void:
	# `@DIALOG_ENDDUEL` (UIStrings.txt:527) is two strings and no more:
	# `%s next draw:` and `Your next draw:`.
	_touch("SeeNextDrawsAtEndOfDuel")
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var lines := screen.next_draw_lines()
	assert_eq(lines.size(), 2, "one per seat")
	for line in lines:
		assert_true(line.contains("next draw:"), line)
	assert_true(lines[0].contains(
		screen.game.players[0].library[-1].data.card_name),
		"and it names the card actually on top")
	DuelOptions.set_toggle("SeeNextDrawsAtEndOfDuel", false)
	assert_eq(screen.next_draw_lines().size(), 0,
		"toggled off, the End of Duel window says nothing about draws")


func test_an_empty_library_has_no_next_draw_to_show() -> void:
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.game.players[0].library.clear()
	var lines := screen.next_draw_lines()
	assert_eq(lines.size(), 1, "the seat that drew itself to death is silent")
