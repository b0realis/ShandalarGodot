extends GutTest
## THE ZONE COLUMN — the library / graveyard / exile row in each seat's
## sidebar panel, its three counts, and the seat portrait beside them.
##
## THE BUG THESE PIN. The owner photographed the column on 2026-09-03 and
## asked *"What is this small number right of the exile stack?"* It was the
## GRAVEYARD's count: `_grave_labels` was a bare Label appended to the row
## AFTER the exile plate — a leftover from when one label read "Deck N /
## Grave N" for both piles — so it floated in the black gap in the default
## theme's white while the other two counts sat on their own art in yellow.
## Every count now rides the pile it counts, in one voice, and the gap it
## vacated carries the seat's chosen portrait and name.
##
## THE 1997 POSITION, for the record: `Duel.hlp`, topic **Library**, says
## the pile *"is represented — inexactly, as in real life. If you must
## know, you can right-click on a library to find out the exact number"* —
## the original printed NO counts. Printing them is a [QoL] divergence this
## screen already carried; these tests pin the refined form of it, not the
## divergence itself, which `docs/ROADMAP.md` records.
##
## Everything that needs the pile PLATES needs the original skin
## (`assets/original/`); without it the table draws no plates and those
## checks skip, the same contract `GameSkin` gives every caller.


var screen: DuelScreen


func before_each() -> void:
	screen = _screen()
	await get_tree().process_frame


func _screen(names := ["Player 1", "Player 2"], portraits := ["", ""]) -> DuelScreen:
	var made: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = 909
	config.player_names[0] = names[0]
	config.player_names[1] = names[1]
	config.portraits[0] = portraits[0]
	config.portraits[1] = portraits[1]
	made.config = config
	add_child_autofree(made)
	return made


func _skin_present() -> bool:
	return GameSkin.texture("grave_panel_red") != null


func _piles_row(pid: int) -> Control:
	return screen._seat_portraits[pid].get_parent().get_parent()


# ------------------------------------- every count rides its own pile --

func test_every_count_is_a_child_of_the_pile_it_counts() -> void:
	# The exact regression: a count parented to the ROW instead of to a
	# pile is a number standing in empty space, belonging to nothing.
	if not _skin_present():
		return
	for pid in 2:
		assert_eq(screen._grave_labels[pid].get_parent(), screen._grave_icons[pid],
			"seat %d: the graveyard count rides the graveyard plate" % pid)
		assert_eq(screen._exile_labels[pid].get_parent(), screen._exile_icons[pid],
			"seat %d: the exile count rides the exile plate" % pid)
		assert_eq(screen._lib_labels[pid].get_parent(), screen._deck_stacks[pid],
			"seat %d: the library count rides the deck stack" % pid)
		assert_eq(screen._deck_stacks[pid], _piles_row(pid).get_child(0),
			"seat %d: and that stack is the row's first column" % pid)


func test_no_count_floats_loose_in_the_row() -> void:
	# What the owner saw: a Label as a direct child of the piles row, in
	# the black gap right of the exile plate. Nothing may sit there but
	# the piles themselves and the portrait block.
	if not _skin_present():
		return
	for pid in 2:
		for child in _piles_row(pid).get_children():
			assert_false(child is Label,
				"seat %d: no bare count in the row (%s)" % [pid, child.name])


func test_every_count_sits_in_its_pile_s_bottom_right_corner() -> void:
	if not _skin_present():
		return
	for pid in 2:
		for label in [screen._grave_labels[pid], screen._exile_labels[pid],
				screen._lib_labels[pid]]:
			assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
			assert_eq(label.vertical_alignment, VERTICAL_ALIGNMENT_BOTTOM)
			var host: Control = label.get_parent()
			var corner: Vector2 = host.get_global_rect().end
			var mine: Vector2 = label.get_global_rect().end
			assert_lt(corner.distance_to(mine), 6.0,
				"seat %d: the count ends within a few px of its pile's corner"
					% pid)


func test_every_count_wears_the_life_numeral_s_yellow_over_black() -> void:
	# The owner's *"colour it some contrasting colour so it can be read"*.
	# The yellow is the one the life numeral and the library count already
	# used; the OUTLINE is what was missing, and it is what makes one
	# colour work over a card scan, a card back and five painted plates.
	if not _skin_present():
		return
	for pid in 2:
		for label in [screen._grave_labels[pid], screen._exile_labels[pid],
				screen._lib_labels[pid]]:
			assert_eq(label.get_theme_color("font_color"),
				DuelScreen.PILE_COUNT_INK)
			assert_eq(label.get_theme_color("font_outline_color"),
				DuelScreen.PILE_COUNT_OUTLINE)
			assert_gte(label.get_theme_constant("outline_size"), 3,
				"a hard outline, not a 1px shadow that a pale scan swallows")
	assert_eq(screen._life_buttons[0].get_theme_color("font_color"),
		DuelScreen.PILE_COUNT_INK, "the same yellow as the life numeral")


func test_each_count_reads_its_own_zone() -> void:
	if not _skin_present():
		return
	var seat := screen.game.players[0]
	for i in 3:
		var dead: CardInstance = seat.hand[0]
		seat.hand.erase(dead)
		dead.zone = Mtg.Zone.GRAVEYARD
		seat.graveyard.append(dead)
	var gone: CardInstance = seat.hand[0]
	seat.hand.erase(gone)
	gone.zone = Mtg.Zone.EXILE
	seat.exile.append(gone)
	screen._refresh()
	assert_eq(screen._grave_labels[0].text, "3", "the graveyard count is the graveyard's")
	assert_eq(screen._exile_labels[0].text, "1", "the exile count is the exile's")
	assert_eq(screen._lib_labels[0].text, str(seat.library.size()))


func test_an_empty_pile_says_nothing() -> void:
	# Both plates start empty, and a "0" written across the red skull is
	# noise the empty plate already says better.
	if not _skin_present():
		return
	assert_eq(screen._grave_labels[0].text, "")
	assert_eq(screen._exile_labels[0].text, "")


func test_the_graveyard_names_ride_the_plate_that_can_show_them() -> void:
	# The list used to hang on the count Label, and a Label is
	# MOUSE_FILTER_IGNORE, so no tooltip could ever be reached.
	if not _skin_present():
		return
	var seat := screen.game.players[0]
	var dead: CardInstance = seat.hand[0]
	seat.hand.erase(dead)
	dead.zone = Mtg.Zone.GRAVEYARD
	seat.graveyard.append(dead)
	screen._refresh()
	assert_string_contains(screen._grave_icons[0].tooltip_text, dead.data.card_name)
	assert_eq(screen._grave_labels[0].mouse_filter, Control.MOUSE_FILTER_IGNORE)


# ------------------------------------- four columns, three even gaps --

func test_the_row_is_four_columns_and_three_even_gaps_inside_185() -> void:
	# The owner's *"align all four columns"*. The sidebar is fixed at
	# CardPreview.SIZE.x; the mana panel and the panel row's own gap take
	# 109 + 6 of it, so this row has exactly 185 and must not want more.
	if not _skin_present():
		return
	for pid in 2:
		var row := _piles_row(pid)
		var widths: Array[float] = []
		for child in row.get_children():
			widths.append((child as Control).size.x)
		assert_eq(widths.size(), 4, "seat %d: deck, grave, exile, face" % pid)
		assert_eq(widths[0], DuelScreen.DECK_STACK.x, "the deck is the wide one")
		for i in range(1, 4):
			assert_eq(widths[i], 40.0,
				"seat %d: column %d is the 1997 plate's own width" % [pid, i])
		assert_eq(row.get_theme_constant("separation"),
			DuelScreen.PILES_SEPARATION, "one gap, used three times")
		var spent := DuelScreen.DECK_STACK.x + 40.0 * 3.0 \
			+ DuelScreen.PILES_SEPARATION * 3.0
		assert_eq(spent, 185.0, "and the four columns spend the row exactly")
		assert_lte(row.get_combined_minimum_size().x, 185.0)


func test_the_four_columns_stand_the_same_height_within_a_few_pixels() -> void:
	if not _skin_present():
		return
	for pid in 2:
		var tallest := maxf(DuelScreen.DECK_STACK.y, DuelScreen.SEAT_PORTRAIT.y)
		for child in _piles_row(pid).get_children():
			assert_lt(absf((child as Control).size.y - tallest), 15.0,
				"seat %d: %s is the same size as the row" % [pid, child.name])


# ------------------------------------------------ the library's depth --
#
# `Duel.hlp`, **Library**: *"The number of cards left in your library is
# represented — inexactly, as in real life."* The thickness IS the 1997
# readout, so the rule behind it is pinned step by step: it is exactly the
# kind of number that drifts.

func test_the_deck_stack_box_holds_one_card_back_and_every_edge() -> void:
	assert_eq(DuelScreen.DECK_STACK, DuelScreen.DECK_SHEET
		+ DuelScreen.DECK_STEP * (DuelScreen.LIBRARY_STEPS.size() - 1),
		"the box is a card back plus one edge per step past the first")


func test_the_thickness_rule_is_one_sheet_per_step_reached() -> void:
	assert_eq(DuelScreen.LIBRARY_STEPS, [1, 4, 10, 20, 32, 45] as Array[int])
	var cases := {
		0: 0, 1: 1, 3: 1, 4: 2, 9: 2, 10: 3, 19: 3, 20: 4,
		31: 4, 32: 5, 44: 5, 45: 6, 60: 6, 300: 6,
	}
	for cards in cases:
		assert_eq(DuelScreen.library_thickness(cards), cases[cards],
			"a library of %d draws %d card backs" % [cards, cases[cards]])


func test_a_forty_card_duel_opens_at_five_sheets_and_thins_as_it_is_drawn() -> void:
	# 40 cards minus the opening seven = 33, which is the fifth step.
	assert_eq(screen.game.players[0].library.size(), 33)
	assert_eq(screen._deck_sheets[0], 5, "the opening pile is nearly full")
	assert_eq(_deck_backs(0), 5, "and five card backs are actually drawn")
	while screen.game.players[0].library.size() > 20:
		screen.game.players[0].library.pop_back()
	screen._refresh()
	assert_eq(screen._deck_sheets[0], 4, "it thins as the library is drawn")
	assert_eq(_deck_backs(0), 4)


func test_an_empty_library_draws_no_pile_at_all() -> void:
	# `Duel.hlp`: *"When there are no cards in a library, that player
	# cannot draw and will likely lose during his or her next draw
	# phase"* — the empty space is the warning, and the 0 says it exactly.
	screen.game.players[0].library.clear()
	screen._refresh()
	assert_eq(_deck_backs(0), 0)
	assert_eq(screen._lib_labels[0].text, "0")


func test_the_top_card_back_never_moves_however_thin_the_pile_gets() -> void:
	# Which is what lets the count ride the box's own corner: the stack
	# grows and shrinks BEHIND its top card, up and to the left.
	var front := DuelScreen.DECK_STEP * (DuelScreen.LIBRARY_STEPS.size() - 1)
	for keep in [45, 33, 21, 11, 5, 2]:
		while screen.game.players[0].library.size() > keep:
			screen.game.players[0].library.pop_back()
		screen._refresh()
		var backs := _deck_sheet_positions(0)
		assert_false(backs.is_empty(), "a library of %d draws something" % keep)
		assert_eq(backs[backs.size() - 1], front,
			"at %d cards the top card back is still in its slot" % keep)


func test_the_count_stays_on_top_of_the_stack_it_counts() -> void:
	# The sheets are rebuilt on every step, so the label has to be moved
	# back to the front or the pile is redrawn straight over the number.
	screen.game.players[0].library.resize(3)
	screen._refresh()
	var stack: Control = screen._deck_stacks[0]
	assert_eq(stack.get_child(stack.get_child_count() - 1), screen._lib_labels[0],
		"the count is the last thing drawn in the box")


func _deck_backs(pid: int) -> int:
	var drawn := 0
	for child in screen._deck_stacks[pid].get_children():
		if child is TextureRect:
			drawn += 1
	return drawn


func _deck_sheet_positions(pid: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for child in screen._deck_stacks[pid].get_children():
		if child is TextureRect:
			spots.append((child as Control).position)
	return spots


# ------------------------------------------- the seat's face and name --

func test_the_portrait_stands_right_of_the_exile_plate() -> void:
	# The owner's *"There is space right of the exile stack!"* — the very
	# gap the stray graveyard count used to stand in.
	if not _skin_present():
		return
	for pid in 2:
		var row := _piles_row(pid)
		assert_eq(screen._exile_icons[pid].get_parent(), row)
		assert_gt(screen._seat_portraits[pid].get_parent().get_index(),
			screen._exile_icons[pid].get_index(),
			"seat %d: the portrait block is the row's last column" % pid)
		assert_gt(screen._seat_portraits[pid].global_position.x,
			screen._exile_icons[pid].get_global_rect().end.x - 1.0,
			"seat %d: and it starts where the exile plate ends" % pid)


func test_the_player_s_name_is_above_his_face_and_the_opponent_s_below() -> void:
	# The owner's symmetry: both names hug their own edge of the screen.
	# Seat 0 is the bottom panel (life numeral last), seat 1 the top.
	assert_lt(screen._seat_name_labels[0].global_position.y,
		screen._seat_portraits[0].global_position.y,
		"the player's name sits ABOVE his portrait")
	assert_gt(screen._seat_name_labels[1].global_position.y,
		screen._seat_portraits[1].global_position.y,
		"the opponent's name sits BELOW his portrait")


func test_the_name_wears_the_same_ink_as_the_counts() -> void:
	for pid in 2:
		var label := screen._seat_name_labels[pid]
		assert_eq(label.get_theme_color("font_color"), DuelScreen.PILE_COUNT_INK)
		assert_eq(label.get_theme_color("font_outline_color"),
			DuelScreen.PILE_COUNT_OUTLINE)
		assert_gte(label.get_theme_constant("outline_size"), 3)


func test_a_long_name_is_trimmed_and_never_widens_the_column() -> void:
	# A Label's minimum width is its WHOLE string, so an untrimmed name
	# here would push the mana panel off the 300px sidebar. This is the
	# owner's *"if the name is much larger, shorten it with three dots"*.
	var long_name := "Wolfgang Amadeus Mozart of the Endless Marches"
	var big := _screen([long_name, "HAL"])
	await get_tree().process_frame
	var label := big._seat_name_labels[0]
	assert_eq(label.text, long_name, "the full name is still what it holds")
	assert_lte(label.get_combined_minimum_size().x, DuelScreen.SEAT_PORTRAIT.x,
		"but it asks for no more width than the portrait")
	assert_eq(label.size.x, DuelScreen.SEAT_PORTRAIT.x,
		"and it is laid out at exactly the portrait's width")
	# ..._FORCE, not the plain ellipsis behaviour: measured under Xvfb at
	# this size, the plain one trims to "Wolfgan" and drops the dots, so
	# a cut name reads as a short name. Only FORCE renders "Wolfg…".
	assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS_FORCE,
		"trimmed WITH the three dots the owner asked for")
	assert_eq(label.tooltip_text, long_name, "the whole name is still readable")
	# The column as a whole is what must not grow.
	var row: Control = big._seat_portraits[0].get_parent().get_parent()
	assert_lte(row.get_combined_minimum_size().x, 185.0,
		"the piles row still fits beside the mana panel")


func test_a_short_name_is_left_alone() -> void:
	var small := _screen(["HAL", "HAL"])
	await get_tree().process_frame
	assert_eq(small._seat_name_labels[0].text, "HAL")


func test_the_seat_wears_the_portrait_it_chose() -> void:
	var faces := PortraitLibrary.all()
	if faces.is_empty():
		return          # no portraits installed: nothing to choose
	var chosen := String(faces[0]["id"])
	var picked := _screen(["Player 1", "Player 2"], [chosen, ""])
	await get_tree().process_frame
	assert_eq(picked._seat_portraits[0].texture, PortraitLibrary.texture(chosen),
		"the face the battle-setup screen chose is the face the duel shows")


func test_a_seat_that_chose_nothing_falls_back_to_its_duelist_face() -> void:
	# Through DuelIntro.portrait_for, so the duel and the pre-duel splash
	# can never disagree about whose face a seat wears.
	assert_eq(screen._seat_portraits[0].texture,
		DuelIntro.portrait_for(screen.config, 0))
	assert_eq(screen._seat_portraits[1].texture,
		DuelIntro.portrait_for(screen.config, 1))


func test_the_portrait_block_neither_blocks_clicks_nor_distorts_the_face() -> void:
	for pid in 2:
		assert_eq(screen._seat_portraits[pid].mouse_filter,
			Control.MOUSE_FILTER_IGNORE, "the face is decoration, not a target")
		assert_eq(screen._seat_portraits[pid].stretch_mode,
			TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"it fills its box at its own aspect rather than letterboxing")
		assert_eq(screen._seat_portraits[pid].size, DuelScreen.SEAT_PORTRAIT)
