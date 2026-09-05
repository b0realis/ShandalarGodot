extends GutTest
## THE TERRITORY MENU — `@MENU_TERRITORY` (`UIStrings.txt:908`),
## `docs/duel-todo.md` §6.3.
##
## The item's remaining half is the `Go to:` LIST: the same fourteen stops
## **Run to** already reaches from the bars, named in a menu, plus
## `Go to: next phase`, which is the one 1997 verb we had no equivalent
## for. These tests pin the table (verbatim strings, in the table's order),
## the destination each entry resolves to, and the two verbs' behaviour.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


# ------------------------------------------------------------- the table --

func test_the_go_to_list_is_the_1997_table_verbatim() -> void:
	var labels: Array = []
	for entry in TerritoryMenu.GO_TO:
		labels.append(entry["label"])
	assert_eq(labels, [
		"Go to: Upkeep phase",
		"Go to: Draw phase",
		"Go to: Main phase (precombat)",
		"Go to: Main phase (combat)",
		"Go to: Attack Fast Effects phase",
		"Go to: Choose Defenders phase",
		"Go to: Block Fast Effects phase",
		"Go to: Resolve first strike damage",
		"Go to: Resolve combat",
		"Go to: Main phase (postcombat)",
		"Go to: Discard phase",
		"Go to: Cleanup phase",
		"Go to: Start of next turn",
		"Go to: next phase",
	], "UIStrings.txt:910-923, in the table's own order and capitalisation")


func test_the_rest_of_the_table_is_present_and_mostly_greyed() -> void:
	# §6.1's precedent: "Showing them greyed says the menu is complete and
	# the help is missing; dropping them would say the original's menu had
	# two items."
	var labels: Array = []
	for entry in TerritoryMenu.REST:
		labels.append(TerritoryMenu.rest_label(entry))
	assert_eq(labels, [
		"Arrange your cards", "Arrange opponent's cards",
		"Duel Options...", "Show ID tags", "Show invisible effects",
		"Show all cards' summoning sickness", "Minimize", "Help...",
		"Concede",
	])
	assert_eq(TerritoryMenu.CONCEDE_CONFIRM, "Yes, I'm sure")


func test_only_two_entries_are_still_greyed() -> void:
	# What is left: `Show invisible effects` (we have no effect cards to
	# show) and `Help...` (§6.20l). Everything else in the table is live.
	var dark: Array = []
	for entry in TerritoryMenu.REST:
		if not TerritoryMenu.rest_is_live(entry):
			dark.append(TerritoryMenu.rest_label(entry))
	assert_eq(dark, ["Show invisible effects", "Help..."])


func test_save_game_is_deliberately_absent() -> void:
	# Manual p.112: Save Game "appears ONLY if you are playing in the Duel
	# (a separate program described later)". The string is in the table
	# because one binary served both products; Shandalar has no mid-duel
	# save and we must not invent one.
	for entry in TerritoryMenu.REST:
		assert_false(TerritoryMenu.rest_label(entry).begins_with("Save game"),
			"no mid-duel save in the adventure")


func test_every_go_to_names_a_real_icon() -> void:
	# A destination the run driver can never arrive at is a hang, not a
	# feature: every entry must land inside its bar's slot count.
	for entry in TerritoryMenu.GO_TO:
		var bar: int = entry["bar"]
		assert_lt(int(entry["slot"]), PhaseStops.SLOT_COUNT[bar],
			"%s is in range" % entry["label"])


func test_start_of_next_turn_crosses_to_the_other_half() -> void:
	# Manual p.116: the top half of the bar is the opponent's turn, the
	# lower half yours — so "next turn" is always the other one.
	var entry: Dictionary = TerritoryMenu.GO_TO[12]
	assert_eq(TerritoryMenu.half_for(entry, PhaseStops.Half.YOURS),
		PhaseStops.Half.OPPONENTS)
	assert_eq(TerritoryMenu.half_for(entry, PhaseStops.Half.OPPONENTS),
		PhaseStops.Half.YOURS)


func test_every_other_go_to_stays_in_the_turn_in_progress() -> void:
	for i in TerritoryMenu.GO_TO.size():
		if i == 12:
			continue
		assert_eq(TerritoryMenu.half_for(TerritoryMenu.GO_TO[i],
			PhaseStops.Half.YOURS), PhaseStops.Half.YOURS)


# -------------------------------------------------------------- the menu --

func test_a_right_click_on_a_territory_opens_the_menu() -> void:
	# Duel.hlp, Territory: "When you right-click on EITHER territory, a
	# mini-menu pops open."
	for pid in 2:
		screen._open_territory_menu(pid, Vector2(200, 200))
		assert_true(screen._territory_menu.visible, "seat %d" % pid)
		assert_eq(screen._territory_menu_pid, pid)
		screen._territory_menu.hide()


func test_the_half_itself_is_wired_to_the_right_click() -> void:
	# End to end: the board half's own VBox is the control that spans a
	# territory, so it is the one that has to carry the gesture. The row
	# containers PASS so the empty air between piles falls through to it.
	for pid in 2:
		var rows: Control = screen._half_rows[pid]
		assert_not_null(rows, "seat %d has a row column" % pid)
		assert_true(rows.gui_input.get_connections().size() > 0,
			"seat %d's territory listens for the mini-menu" % pid)
		for row in screen._field_rows[pid]:
			assert_eq(screen._field_rows[pid][row].mouse_filter,
				Control.MOUSE_FILTER_PASS,
				"row %d of seat %d lets the click through" % [row, pid])
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ev.global_position = Vector2(500, 600)
	screen._on_territory_input(ev, 0)
	assert_true(screen._territory_menu.visible, "a right-click opened it")
	screen._territory_menu.hide()


func test_the_menu_carries_the_whole_table() -> void:
	screen._open_territory_menu(0, Vector2.ZERO)
	var menu := screen._territory_menu
	var seen: Array = []
	for i in menu.item_count:
		if not menu.is_item_separator(i):
			seen.append(menu.get_item_text(i))
	assert_eq(seen.size(),
		TerritoryMenu.GO_TO.size() + TerritoryMenu.REST.size())
	assert_eq(seen[0], "Go to: Upkeep phase")
	assert_eq(seen[-1], "Concede")
	screen._territory_menu.hide()


func test_the_unbuilt_entries_are_shown_disabled() -> void:
	# The live set grew as the sections landed: the fourteen `Go to:`
	# destinations and the two `Arrange` commands (§6.1, §2.3),
	# `Duel Options...` (§6.4), and now Concede, Minimize and two of the
	# three display toggles. Two entries are still greyed and both have a
	# reason.
	screen._open_territory_menu(0, Vector2.ZERO)
	var menu := screen._territory_menu
	for i in menu.item_count:
		if menu.is_item_separator(i):
			continue
		var text := menu.get_item_text(i)
		var dark := text == "Show invisible effects" or text == "Help..."
		assert_eq(menu.is_item_disabled(i), dark, text)
	screen._territory_menu.hide()


func test_duel_options_is_live_and_opens_the_1997_panel() -> void:
	# `@MENU_TERRITORY` entry 17 (§6.4). The panel is where every one of
	# `@DIALOG_DUELOPTIONS`'s nineteen strings lives.
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 2)
	assert_not_null(screen._options_dialog, "the panel opened")
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 2)
	assert_not_null(screen._options_dialog, "and a second click is not a second panel")
	screen._options_dialog.dismiss()
	assert_null(screen._options_dialog, "closing it lets the table redress")


func test_the_arrange_entries_arrange_one_territory_each() -> void:
	# The 1997 command is per-territory: it "straightens up the cards in
	# play in the territory where you right-clicked".
	var mine := screen._human_seat()
	var theirs := 1 - mine
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 0)
	assert_true(screen._arranged[mine], "your cards")
	assert_false(screen._arranged[theirs], "and only yours")
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 1)
	assert_true(screen._arranged[theirs], "their cards too")
	# The sidebar toggle only reads pressed once BOTH halves are arranged.
	assert_true(screen._arrange_button.button_pressed)
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 0)
	assert_false(screen._arranged[mine], "the tick is how it comes off")
	assert_false(screen._arrange_button.button_pressed)


# --------------------------------------------------------- the two verbs --

func test_a_go_to_entry_orders_a_run_to_that_icon() -> void:
	# Thirteen of the fourteen are the SAME destinations Run to reaches, so
	# they must go through the same driver rather than a second mechanism.
	screen._order_go_to(11)      # Go to: Cleanup phase
	var entry: Dictionary = TerritoryMenu.GO_TO[11]
	# The run may have arrived already (and cleared itself); either way it
	# must never have been left aimed somewhere else.
	if screen._advance_mode == DuelScreen.Advance.RUN_TO:
		assert_eq(screen._run_to[1], int(entry["bar"]))
		assert_eq(screen._run_to[2], int(entry["slot"]))
	else:
		assert_eq(screen._advance_mode, DuelScreen.Advance.NONE,
			"arrived, and forgot its destination")


func test_go_to_next_phase_leaves_the_phase_it_was_given_in() -> void:
	# Duel.hlp, Territory: "Go to ends the current phase and moves you on
	# to the next one." The coarser of the original's two fast-forward
	# verbs, and the one control we had no equivalent for.
	var before := screen._phase_key()
	screen._order_go_to(13)
	assert_ne(screen._phase_key(), before,
		"the duel left the phase (or stopped for something it must not pass)")


func test_go_to_next_phase_stops_at_the_very_next_phase() -> void:
	# It must not keep running: one phase, then rest. Run it twice and the
	# duel must move twice, not sprint to the end of the turn.
	var first := screen._phase_key()
	screen._order_go_to(13)
	var second := screen._phase_key()
	assert_ne(second, first)
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE,
		"the order is spent as soon as the phase changed")
