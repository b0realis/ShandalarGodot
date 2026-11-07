extends GutTest
## THE SEAT'S DICE (the owner, 2026-11-07): "add a small randomize button in
## the magic battle screen that randomizes player name/deck/logo/mat
## (respecting color) and the same for opponent … at the top where most
## common changes are (the button should have the dice icon)" and "the
## player and opponent should have separate randomize buttons".
## [method SetupScreen.randomize_seat].

var screen: SetupScreen


func before_each() -> void:
	SetupScreen.forget_choices()
	screen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	SetupScreen.forget_choices()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _deck_of(pid: int) -> String:
	return str(screen._deck_options[pid].get_selected_metadata())


func test_each_seat_has_its_own_dice_beside_its_heading() -> void:
	assert_eq(screen._dice_buttons.size(), 2, "one die for the player, one for the opponent")
	for pid in 2:
		var dice: Button = screen._dice_buttons[pid]
		assert_true(dice.get_child(0) is DiceIcon, "a die's face on the button")
		var heading := dice.get_parent()
		assert_eq(heading.get_parent(), screen._deck_options[pid].get_parent(),
			"at the top of the seat's own column")
		assert_eq(heading.get_index(), 0, "first in the column, above the deck")


func test_the_dice_draw_a_playable_deck_and_a_name() -> void:
	screen.randomize_seat(0, _rng(7))
	var path := _deck_of(0)
	assert_true(screen._format_playable().has(path),
		"a concrete deck the format allows, never a <random …> row: %s" % path)
	var name_text: String = screen._name_edits[0].text
	var parts := name_text.split(" ")
	assert_true(AdventureSetup.FIRST_NAMES.has(parts[0]), "a magical first name: %s" % name_text)


func test_the_players_dice_roll_the_mat_to_follow_the_deck() -> void:
	DuelOptions.set_territory_color(DuelOptions.TERRITORY_COLORS[1])
	screen.randomize_seat(0, _rng(11))
	assert_eq(DuelOptions.territory_color(), DuelOptions.DECK_COLOR,
		"the mat respects the deck's colour")
	var labels: Array = []
	for entry in DuelOptions.TERRITORY_TYPES:
		labels.append(String(entry["label"]))
	assert_true(labels.has(DuelOptions.territory_type()), "one of the colour's arts")


func test_the_opponents_dice_leave_the_player_alone() -> void:
	screen.randomize_seat(0, _rng(3))
	var mine := _deck_of(0)
	var my_name: String = screen._name_edits[0].text
	var my_mat := DuelOptions.territory_type()
	for roll in 5:
		screen.randomize_seat(1, _rng(100 + roll))
	assert_eq(_deck_of(0), mine, "seat 1's deck untouched")
	assert_eq(screen._name_edits[0].text, my_name, "seat 1's name untouched")
	assert_eq(DuelOptions.territory_type(), my_mat, "your mat untouched")
	assert_true(screen._format_playable().has(_deck_of(1)))


func test_the_dice_are_silent() -> void:
	var before: String = screen._format_note.text
	screen.randomize_seat(1, _rng(5))
	assert_eq(screen._format_note.text, before,
		"no report of what was drawn (the owner's ruling, 2026-11-05)")
