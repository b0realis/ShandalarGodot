extends GutTest
## STOPS and RUN TO — the Phase Bar's two 1997 behaviours
## (manual pp.116-117, `Duel.hlp` topic **Stop**; docs/duel-todo.md §6.1,
## §6.3, §6.20a). Files under test: game/duel/phase_stops.gd,
## game/duel/phase_bar.gd, and the driver in game/duel/duel_screen.gd.
##
## The one thing here that is a CORRECTION rather than an addition: the red
## dot now marks Stops, not the current phase. The manual gives the current
## phase the HIGHLIGHT and nothing else — *"First and foremost, the current
## phase is always highlighted"* — and `Duel.hlp` is the only source that
## describes a marker at all: *"put a Stop **marker** on that phase."*
## `test_the_red_dot_marks_stops_and_not_the_current_phase` pins that.


var screen: DuelScreen
## The player's own persisted Stops (null when their file has none),
## put back after every test.
var _saved_stops: Variant = null


func before_each() -> void:
	# The Stops PERSIST (they are "a lasting instruction"), so a test must
	# never inherit the player's own file — nor take theirs away: the
	# value is remembered before the screen reads it and restored after
	# (test_game_audio.gd's remember-and-restore).
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()


func after_each() -> void:
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


## Stand the duel in one step, with the human seat (0) as active player, so
## a run's start point is known.
func _stand_in(step: int) -> void:
	screen.game.active_player = 0
	screen.game._enter_step(Mtg.STEP_ORDER.find(step))
	screen.mode = DuelScreen.Mode.NORMAL
	screen._refresh()


# ============================================================ the model --

func test_a_stop_is_per_half_per_bar_per_slot() -> void:
	# The original's own shape: `option_PhaseStoppers[2][38]`, indexed
	# [whose turn][which phase] (shandalar-src/src/manalink.h:120,
	# src/functions/windows.c:543). Marking your Main phase must not mark
	# the opponent's, and the two bars must not share a slot number.
	var stops := PhaseStops.new()
	stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 3, true)
	assert_true(stops.is_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 3))
	assert_false(stops.is_marked(PhaseStops.Half.OPPONENTS,
		PhaseStops.Bar.PHASE, 3), "the other half is untouched")
	assert_false(stops.is_marked(PhaseStops.Half.YOURS,
		PhaseStops.Bar.COMBAT, 3), "the other bar is untouched")
	assert_false(stops.is_marked(PhaseStops.Half.YOURS,
		PhaseStops.Bar.PHASE, 4), "the other slot is untouched")


func test_stops_go_on_the_opponents_half_too() -> void:
	# `Duel.hlp`, topic Stop: "A Stop on your opponent's Main Pre-Combat
	# sub-phase is always a good idea." The upper half is the opponent's
	# turn (manual p.116), and it takes marks like the lower one.
	var stops := PhaseStops.new()
	stops.set_marked(PhaseStops.Half.OPPONENTS, PhaseStops.Bar.PHASE, 3, true)
	assert_eq(stops.marked_slots(PhaseStops.Half.OPPONENTS,
		PhaseStops.Bar.PHASE), [3] as Array[int])
	assert_true(stops.any_marked())


func test_mark_toggles_because_1997_ships_no_unmark_string() -> void:
	# @MENU_PHASEBAR has exactly four entries and none of them un-marks, so
	# the single "Mark this phase to always stop" has to serve both ways.
	var stops := PhaseStops.new()
	assert_true(stops.toggle(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 1))
	assert_false(stops.toggle(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 1))
	assert_false(stops.any_marked())


func test_the_combat_bar_takes_stops_too() -> void:
	# `Duel.hlp`, topic Combat Bar: "It functions in exactly the same way as
	# the larger bar; you can even use Stops." The original's array is 38
	# wide — one past PHASE_DAMAGE_PREVENTION (0x25) — so it spans the
	# combat sub-phases as well (src/defs.h:685-707).
	var stops := PhaseStops.new()
	for slot in PhaseStops.SLOT_COUNT[PhaseStops.Bar.COMBAT]:
		stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.COMBAT,
			slot, true)
	assert_eq(stops.marked_slots(PhaseStops.Half.YOURS,
		PhaseStops.Bar.COMBAT).size(), 7, "all seven sub-phases can stop")
	assert_eq(PhaseStops.SLOT_COUNT, [8, 7] as Array[int],
		"eight Phase Bar icons, seven Combat Bar ones")


func test_a_stop_is_a_lasting_instruction_and_survives_the_duel() -> void:
	# Manual p.117: "This is a lasting instruction". The original persisted
	# it as `PhaseStoppers` under the DuelOptions registry key, beside the
	# rest of the Duel Options — and p.114: "your option settings are
	# retained for future duels".
	var stops := PhaseStops.new()
	stops.set_marked(PhaseStops.Half.OPPONENTS, PhaseStops.Bar.PHASE, 3, true)
	stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.COMBAT, 5, true)
	stops.save()
	var reloaded := PhaseStops.load_saved()
	assert_true(reloaded.is_marked(PhaseStops.Half.OPPONENTS,
		PhaseStops.Bar.PHASE, 3))
	assert_true(reloaded.is_marked(PhaseStops.Half.YOURS,
		PhaseStops.Bar.COMBAT, 5))
	# ...and putting them back to the DEFAULT set takes the key out again
	# rather than writing a copy of the defaults into the player's file.
	var back := PhaseStops.defaults()
	back.save()
	assert_false(Settings.has_value(PhaseStops.SETTING_KEY),
		"an untouched profile leaves no row behind")


# ================================================ the three default Stops --

func test_a_fresh_profile_starts_with_the_three_main_stops() -> void:
	# The owner's playtest, 2026-09-03: "My main phase precombat, combat and
	# main phase post-combat should be selected to stop (red dot) by
	# default." The original shipped three of its own, and they are not
	# quite these three — see the test below and docs/ROADMAP.md, "THE
	# THREE DEFAULT STOPS".
	Settings.clear_value(PhaseStops.SETTING_KEY)
	var fresh := PhaseStops.load_saved()
	assert_eq(fresh.marked_slots(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE),
		[3, 4, 5] as Array[int],
		"your Main pre-combat, combat and Main post-combat")
	assert_eq(fresh.marked_slots(PhaseStops.Half.OPPONENTS,
		PhaseStops.Bar.PHASE), [] as Array[int],
		"the opponent's half starts bare — `Duel.hlp` ADVISES a Stop there, "
		+ "which is advice nobody gives about a mark already set")
	assert_eq(fresh.marked_slots(PhaseStops.Half.YOURS,
		PhaseStops.Bar.COMBAT), [] as Array[int], "and so does the Combat Bar")
	assert_eq(PhaseStops.DEFAULT_SLOTS, [3, 4, 5] as Array[int])


func test_the_1997_default_set_is_recorded_beside_ours() -> void:
	# WHAT THE ORIGINAL ACTUALLY SHIPPED, read out of `Magic.exe`'s
	# duel-options loader (2026-09-03): the array at 0x62c374 is zeroed and
	# then three cells are set — `[0][0x14]` PHASE_MAIN1 and `[0][0x1E]`
	# PHASE_MAIN2 on the HUMAN's row (defs.h:2362, `HUMAN = 0`), and
	# `[1][0x1F]` PHASE_DISCARD on the AI's. So: your slots 3 and 5, plus
	# the OPPONENT's slot 6. A stored value still gets `[0][0x14]` forced
	# back on at 0x45deea, so that one was mandatory.
	assert_eq(PhaseStops.ORIGINAL_1997_YOURS, [3, 5] as Array[int])
	assert_eq(PhaseStops.ORIGINAL_1997_OPPONENTS, [6] as Array[int])
	# ...and this is the whole of our divergence, in one assert. `[QoL]`,
	# on the owner's instruction: we ADD your combat icon and we do NOT
	# ship the opponent's Discard stop.
	Settings.clear_value(PhaseStops.SETTING_KEY)
	var fresh := PhaseStops.load_saved()
	var ours := fresh.marked_slots(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE)
	assert_true(ours.has(3) and ours.has(5),
		"the two the original set on your half, we set too")
	assert_true(ours.has(4), "[QoL] ours adds the combat icon")
	assert_false(fresh.is_marked(PhaseStops.Half.OPPONENTS,
		PhaseStops.Bar.PHASE, 6),
		"[QoL] and ours leaves the opponent's Discard phase bare")


func test_the_three_are_the_slots_the_cue_cards_name() -> void:
	# The dots have to sit on the phases the owner named, and
	# @CUECARD_PHASEBAR is what each icon IS.
	for slot in PhaseStops.DEFAULT_SLOTS:
		assert_true(PhaseBar.CUE_YOURS[slot].begins_with("Your Main phase"),
			"slot %d is a Main-phase icon: %s" % [slot, PhaseBar.CUE_YOURS[slot]])
	assert_eq(PhaseBar.CUE_YOURS[3], "Your Main phase (precombat)")
	assert_eq(PhaseBar.CUE_YOURS[4], "Your Main phase (declare combat)")
	assert_eq(PhaseBar.CUE_YOURS[5], "Your Main phase (postcombat)")


func test_the_middle_default_is_a_dot_the_combat_bar_answers_for() -> void:
	# WHAT SLOT 4 REALLY IS, pinned because the owner asked for "combat" to
	# stop and this is the one of their three that a Stop cannot do on its
	# own. Every step from COMBAT_BEGIN to COMBAT_END is keyed to the
	# COMBAT bar ([method CombatBar.covers_step], and
	# `DuelScreen._phase_key` follows it), so no phase key is ever
	# `[half, Bar.PHASE, 4]` and the dot on the Phase Bar's combat crescent
	# marks a phase nothing consults. It is not idle: what actually holds
	# the duel at combat is the DECLARATION — `_required_action_reason`'s
	# "attackers must be declared" — which stops it whether the dot is
	# there or not, which is why the owner's combat pause works anyway.
	# docs/ROADMAP.md, "THE COMBAT DOT".
	for step in [Mtg.Step.COMBAT_BEGIN, Mtg.Step.DECLARE_ATTACKERS,
			Mtg.Step.COMBAT_DAMAGE, Mtg.Step.COMBAT_END]:
		_stand_in(step)
		var key: Array = screen._phase_key()
		assert_eq(key[1], PhaseStops.Bar.COMBAT,
			"%s is keyed to the Combat Bar" % Mtg.step_name(step))
	assert_eq(DuelScreen._phase_icon_slot(Mtg.Step.COMBAT_BEGIN), 4,
		"...while the PHASE bar still lights slot 4 for it, which is the "
		+ "dot the player sees")
	_stand_in(Mtg.Step.DECLARE_ATTACKERS)
	screen.game.awaiting_attackers = true
	assert_eq(screen._required_action_reason(), "attackers must be declared",
		"and this is what really pauses combat, dot or no dot")
	screen.game.awaiting_attackers = false


func test_the_defaults_are_an_absent_value_and_never_a_stored_copy() -> void:
	# THE SETTINGS CONTRACT. Writing the defaults into the player's file is
	# a bug this project has shipped once (the "fan" hand style), so
	# "default" must mean the ABSENCE of a row.
	Settings.clear_value(PhaseStops.SETTING_KEY)
	PhaseStops.defaults().save()
	assert_false(Settings.has_value(PhaseStops.SETTING_KEY),
		"saving exactly the defaults writes nothing")
	# A hand-edited or truncated value is not a decision either.
	Settings.set_value(PhaseStops.SETTING_KEY, PackedInt32Array([0, 0]))
	assert_eq(PhaseStops.load_saved().marked_slots(PhaseStops.Half.YOURS,
		PhaseStops.Bar.PHASE), [3, 4, 5] as Array[int],
		"an unreadable row falls back to the defaults, not to an empty bar")


func test_a_player_who_clears_every_stop_keeps_them_cleared() -> void:
	# The other half of the contract, and the one that matters most: four
	# zeroes IS a decision and is written down, so the next duel does not
	# silently hand the three dots back.
	Settings.clear_value(PhaseStops.SETTING_KEY)
	var mine := PhaseStops.load_saved()
	mine.clear_all()
	mine.save()
	assert_true(Settings.has_value(PhaseStops.SETTING_KEY),
		"a deliberate clear is stored, not erased")
	var next_duel := PhaseStops.load_saved()
	assert_false(next_duel.any_marked(),
		"the player who cleared them starts the next duel with none")


func test_one_removed_default_leaves_the_other_two() -> void:
	Settings.clear_value(PhaseStops.SETTING_KEY)
	var mine := PhaseStops.load_saved()
	assert_false(mine.toggle(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 4),
		"the Mark entry un-marks a default exactly as it un-marks any Stop")
	mine.save()
	assert_eq(PhaseStops.load_saved().marked_slots(PhaseStops.Half.YOURS,
		PhaseStops.Bar.PHASE), [3, 5] as Array[int])


# ======================= the row the owner's own profile actually held --
#
# THE DEFECT THE TESTS ABOVE COULD NOT SEE, reported twice and "fixed"
# once (2026-09-04). Every test above either clears the key first or
# builds a PhaseStops by hand, so all of them measure a profile that has
# never been played. The owner's had: `phase_stoppers=PackedInt32Array(0,
# 0, 8, 0)` — the single Stop they set on their own Main pre-combat back
# when the game shipped no defaults at all — and `load_saved` honoured it
# to the letter, so the three new defaults never reached the one profile
# they were written for. The suite was green the whole time.
#
# The two below are the pin. The first is the owner's file, verbatim; the
# second asks the BAR what it draws rather than asking the model what it
# holds, because a red dot is a thing on a screen.

## The exact row read out of the owner's
## `~/.local/share/godot/app_userdata/Shandalar/settings.cfg` on
## 2026-09-04, before any of this was changed. A method, not a `const`,
## for the same reason [method PhaseStops.default_masks] is one: GDScript
## will not fold a PackedInt32Array literal into a constant expression.
func _owners_stored_row() -> PackedInt32Array:
	return PackedInt32Array([0, 0, 8, 0])


## Which dot indices a [PhaseBar] actually shows for [param stops] —
## `i / 8` is the half, `i % 8` the slot, so 8..15 are YOUR half. Built
## standalone so the answer is the widget's own and does not depend on a
## skin being installed.
func _dots_drawn(stops: PhaseStops) -> Array[int]:
	var bar: PhaseBar = autofree(PhaseBar.new())
	bar.stops = stops
	bar.refresh_stops()
	var lit: Array[int] = []
	for i in bar._dots.size():
		if bar._dots[i].visible:
			lit.append(i)
	return lit


func test_a_row_written_before_the_defaults_existed_does_not_veto_them() -> void:
	# The owner's own file, and the whole of the bug: four ints cannot say
	# whether they are a decision or a leftover, so a row from a build that
	# offered no defaults outranked the defaults that came later.
	Settings.set_value(PhaseStops.SETTING_KEY, _owners_stored_row())
	var loaded := PhaseStops.load_saved()
	assert_eq(loaded.marked_slots(PhaseStops.Half.YOURS,
		PhaseStops.Bar.PHASE), [3, 4, 5] as Array[int],
		"an unstamped row is not an opt-out from an offer nobody made")
	assert_eq(_dots_drawn(loaded), [8 + 3, 8 + 4, 8 + 5] as Array[int],
		"and the BAR draws all three dots on your half — which is the "
		+ "thing the owner reported twice, in the owner's own words")


func test_a_fresh_profile_draws_three_dots_on_the_lower_half() -> void:
	# The same assertion for the profile that HAS no row: what the widget
	# shows, not what the model holds. Nothing on the opponent's half.
	Settings.clear_value(PhaseStops.SETTING_KEY)
	assert_eq(_dots_drawn(PhaseStops.load_saved()),
		[8 + 3, 8 + 4, 8 + 5] as Array[int],
		"your Main pre-combat, combat and Main post-combat, and no more")


func test_a_stored_row_is_stamped_with_the_generation_it_answered() -> void:
	# What makes the two distinguishable at all: a row the player CHOSE
	# carries the generation of the defaults it was chosen against.
	Settings.clear_value(PhaseStops.SETTING_KEY)
	var mine := PhaseStops.load_saved()
	mine.toggle(PhaseStops.Half.OPPONENTS, PhaseStops.Bar.PHASE, 3)
	mine.save()
	var row: PackedInt32Array = Settings.get_value(PhaseStops.SETTING_KEY,
		PackedInt32Array())
	assert_eq(row.size(), 5, "four masks and the generation stamp")
	assert_eq(row[4], PhaseStops.DEFAULTS_GENERATION)
	assert_eq(PhaseStops.load_saved().to_masks(), mine.to_masks(),
		"...and a stamped row is honoured to the letter")


func test_the_stamp_does_not_take_away_a_deliberate_clear() -> void:
	# The contract this must not break: four zeroes IS a decision. With
	# the stamp on it, it stays one.
	Settings.clear_value(PhaseStops.SETTING_KEY)
	var mine := PhaseStops.load_saved()
	mine.clear_all()
	mine.save()
	assert_false(PhaseStops.load_saved().any_marked(),
		"the player who cleared every Stop keeps them cleared")
	assert_eq(_dots_drawn(PhaseStops.load_saved()), [] as Array[int],
		"and the bar draws nothing")


func test_your_turn_is_the_lower_half_of_the_bar() -> void:
	# Manual p.116: "The top half of the bar represents the phases in your
	# opponent's turn, while the lower half represents your turn."
	assert_eq(PhaseStops.half_for_seat(0, 0), PhaseStops.Half.YOURS)
	assert_eq(PhaseStops.half_for_seat(1, 0), PhaseStops.Half.OPPONENTS)
	assert_eq(PhaseBar.HALF_Y[PhaseStops.Half.OPPONENTS], 2.0,
		"the opponent's strip runs from the top of the sheet")
	assert_eq(PhaseBar.HALF_Y[PhaseStops.Half.YOURS], 431.0,
		"yours from the middle band down")


# ========================================================== the mini-menu --

func test_the_mini_menu_is_the_1997_four_entries_verbatim() -> void:
	# @MENU_PHASEBAR, shandalar-src/Program/UIStrings.txt:947 (the same four
	# at Program/Text.res:1903).
	assert_eq(PhaseStops.MENU_ENTRIES, [
		"Run to this phase",
		"Mark this phase to always stop",
		"Help for this phase...",
		"Help...",
	] as Array[String])


func test_the_menu_offers_all_four_with_help_disabled() -> void:
	if screen._phase_menu == null:
		pass_test("no menu built")
		return
	screen._open_phase_menu(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 3,
		Vector2(100, 100))
	var menu := screen._phase_menu
	assert_eq(menu.item_count, 4, "all four entries, none silently dropped")
	for i in 4:
		assert_eq(menu.get_item_text(i), PhaseStops.MENU_ENTRIES[i])
	# There is no Dueling Help yet (§6.20l): the entries are shown GREYED
	# rather than invented or removed.
	assert_false(menu.is_item_disabled(
		menu.get_item_index(DuelScreen.PhaseMenu.RUN_TO)))
	assert_false(menu.is_item_disabled(
		menu.get_item_index(DuelScreen.PhaseMenu.MARK)))
	assert_true(menu.is_item_disabled(
		menu.get_item_index(DuelScreen.PhaseMenu.HELP_PHASE)))
	assert_true(menu.is_item_disabled(
		menu.get_item_index(DuelScreen.PhaseMenu.HELP)))
	menu.hide()


func test_the_mark_entry_is_ticked_when_that_phase_is_stopped() -> void:
	if screen._phase_menu == null:
		pass_test("no menu built")
		return
	var menu := screen._phase_menu
	screen._open_phase_menu(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 3,
		Vector2.ZERO)
	var mark := menu.get_item_index(DuelScreen.PhaseMenu.MARK)
	assert_false(menu.is_item_checked(mark), "no Stop yet")
	screen._on_phase_menu_chosen(DuelScreen.PhaseMenu.MARK)
	assert_true(screen.stops.is_marked(PhaseStops.Half.YOURS,
		PhaseStops.Bar.PHASE, 3), "Mark set the Stop")
	screen._open_phase_menu(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 3,
		Vector2.ZERO)
	assert_true(menu.is_item_checked(
		menu.get_item_index(DuelScreen.PhaseMenu.MARK)),
		"and re-opening shows the tick — the only un-mark affordance the "
		+ "1997 string table leaves room for")
	menu.hide()


# ============================================================= the bar --

func test_the_phase_bar_has_sixteen_icons_with_their_1997_cue_cards() -> void:
	# @CUECARD_PHASEBAR, UIStrings.txt:706 — its first sixteen entries,
	# eight per seat. §6.1's other half, live at last.
	assert_eq(PhaseBar.CUE_OPPONENT.size(), 8)
	assert_eq(PhaseBar.CUE_YOURS.size(), 8)
	assert_eq(PhaseBar.cue_card(PhaseStops.Half.YOURS, 4, "Ivory"),
		"Your Main phase (declare combat)",
		"your own combat slot is the one entry that differs in wording")
	assert_eq(PhaseBar.cue_card(PhaseStops.Half.OPPONENTS, 4, "Ivory"),
		"Ivory Main phase (combat)", "the opponent's takes their name")
	if screen._phase_bar == null:
		pass_test("no original skin imported — no strip is built")
		return
	var seen: Array[String] = []
	for zone in screen._phase_bar._zones:
		seen.append(zone.tooltip_text)
	assert_eq(seen.size(), 16, "sixteen hover zones, one per icon")
	assert_eq(seen[0], PhaseBar.CUE_OPPONENT[0] % screen._phase_bar.opponent_name)
	assert_eq(seen[8], "Your Untap phase")


func test_the_red_dot_marks_stops_and_not_the_current_phase() -> void:
	# THE CORRECTION. The dot used to ride beside the current phase, which
	# the manual marks with the HIGHLIGHT and nothing else (p.116); the only
	# marker any 1997 source describes is the Stop's (`Duel.hlp`). And the
	# owner's own words for the feature: "set a stop point (red dot) there".
	if screen._phase_bar == null:
		pass_test("no original skin imported")
		return
	_stand_in(Mtg.Step.UPKEEP)
	var bar := screen._phase_bar
	for dot in bar._dots:
		assert_false(dot.visible,
			"no Stops marked, so not one red dot anywhere — including "
			+ "beside the phase the duel is actually in")
	screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 5, true)
	screen.stops.set_marked(PhaseStops.Half.OPPONENTS, PhaseStops.Bar.PHASE,
		3, true)
	bar.refresh_stops()
	var lit: Array[int] = []
	for i in bar._dots.size():
		if bar._dots[i].visible:
			lit.append(i)
	assert_eq(lit, [3, 8 + 5] as Array[int],
		"several dots at once — the opponent's Main pre-combat and your "
		+ "own post-combat main")


func test_the_current_phase_is_marked_by_the_highlight() -> void:
	# "First and foremost, the current phase is always highlighted."
	if screen._phase_bar == null:
		pass_test("no original skin imported")
		return
	_stand_in(Mtg.Step.DRAW)
	assert_eq(screen._phase_bar.state(), [PhaseStops.Half.YOURS, 2],
		"your Draw phase is slot 2 of the lower half")
	# The highlighted cell is the sheet's SECOND column (x=44), which is the
	# whole reason the art ships two columns.
	assert_eq(PhaseBar.active_region(PhaseStops.Half.YOURS, 2),
		Rect2(44, 431 + 41 * 2, 35, 40))
	screen.game.active_player = 1
	screen._refresh()
	assert_eq(screen._phase_bar.state()[0], PhaseStops.Half.OPPONENTS,
		"the opponent's turn lights the upper half")


func test_a_stop_on_the_combat_bar_draws_its_own_dot() -> void:
	if screen._combat_bar == null:
		pass_test("no original skin imported")
		return
	screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.COMBAT,
		CombatBar.Slot.BLOCKER_FAST_EFFECTS, true)
	screen._combat_bar.set_state(true, CombatBar.Slot.DECLARE_ATTACKERS,
		PhaseStops.Half.YOURS)
	var lit: Array[int] = []
	for i in screen._combat_bar._dots.size():
		if screen._combat_bar._dots[i].visible:
			lit.append(i)
	assert_eq(lit, [CombatBar.Slot.BLOCKER_FAST_EFFECTS] as Array[int])


# ============================================================== run to --

func test_clicking_a_phase_icon_runs_the_duel_to_it() -> void:
	# "You can move forward ('run') to any phase by clicking on the icon for
	# that phase… The duel blithely skips through all the intervening
	# phases, then stops."
	_stand_in(Mtg.Step.UPKEEP)
	screen._on_phase_bar_slot(PhaseStops.Half.YOURS, 3)   # your Main phase
	assert_eq(screen.game.current_step(), Mtg.Step.MAIN1,
		"it skipped the Draw phase and stopped in Main")
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE,
		"and the order is spent")


func test_a_run_pauses_at_a_marked_phase_and_forgets_where_it_was_going() -> void:
	# "If you have placed a Stop on a phase, progress pauses at that phase"
	# — and "your original 'destination' phase is forgotten."
	screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 2,
		true)                                     # a Stop on your Draw phase
	_stand_in(Mtg.Step.UPKEEP)
	screen._on_phase_bar_slot(PhaseStops.Half.YOURS, 3)   # aim past it
	assert_eq(screen.game.current_step(), Mtg.Step.DRAW,
		"the Stop caught it one phase short of the destination")
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE,
		"the destination is forgotten, not resumed")
	assert_eq(screen._run_to, [], "nothing left to run to")


func test_a_stop_on_the_phase_you_are_standing_in_does_not_trap_the_order() -> void:
	# "that phase does not end until you tell it to manually" — ordering a
	# run IS telling it manually, so the Stop you are sitting on releases.
	screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 1,
		true)                                    # a Stop on your Upkeep
	_stand_in(Mtg.Step.UPKEEP)
	screen._on_phase_bar_slot(PhaseStops.Half.YOURS, 3)
	assert_eq(screen.game.current_step(), Mtg.Step.MAIN1,
		"the run left the stopped phase it started in")


func test_a_run_stops_when_a_decision_is_required() -> void:
	# "If there are any required actions to perform during a specific phase…
	# movement through the phases will stop at that phase until you do what
	# is necessary."
	_stand_in(Mtg.Step.UPKEEP)
	screen.game.awaiting_discard = true
	screen._on_phase_bar_slot(PhaseStops.Half.YOURS, 5)
	assert_eq(screen.game.current_step(), Mtg.Step.UPKEEP,
		"the run never started: the duel is holding for a decision")
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE)
	screen.game.awaiting_discard = false


func test_a_run_is_refused_while_an_action_is_in_progress() -> void:
	_stand_in(Mtg.Step.UPKEEP)
	screen.mode = DuelScreen.Mode.TARGETING
	screen._on_phase_bar_slot(PhaseStops.Half.YOURS, 3)
	assert_eq(screen.game.current_step(), Mtg.Step.UPKEEP)
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE)
	screen.mode = DuelScreen.Mode.NORMAL


func test_a_run_can_cross_into_the_other_seats_turn() -> void:
	# "Whenever you want to, you can click on any phase on either side of
	# the bar."
	_stand_in(Mtg.Step.MAIN2)
	var turn: int = screen.game.turn_number
	screen._on_phase_bar_slot(PhaseStops.Half.OPPONENTS, 1)  # their Upkeep
	assert_gt(screen.game.turn_number, turn, "the run changed the turn over")
	assert_eq(screen.game.current_step(), Mtg.Step.UPKEEP)
	assert_eq(screen.game.active_player, 1)


func test_a_halted_run_says_the_1997_word_for_it() -> void:
	# @PROMPT_STOPANYWAY, UIStrings.txt:1078 — nine entries, and the whole
	# vocabulary the original has for a run coming to rest. Entry 6,
	# "Paused: Discard phase", is the one §1.1's discard already uses.
	assert_eq(DuelScreen.paused_message(Mtg.Step.UPKEEP),
		"Paused: Upkeep phase")
	assert_eq(DuelScreen.paused_message(Mtg.Step.MAIN2), "Paused: Main phase",
		"the table has ONE Main phase entry for both of ours")
	assert_eq(DuelScreen.paused_message(Mtg.Step.CLEANUP),
		"Paused: Discard phase")
	assert_eq(DuelScreen.paused_message(Mtg.Step.COMBAT_DAMAGE),
		"Paused: Combat damage resolution")
	assert_eq(DuelScreen.paused_message(Mtg.Step.DECLARE_ATTACKERS), "Paused",
		"the table's bare first entry covers what it does not name")
	# ...and the run actually says it.
	screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 2,
		true)
	_stand_in(Mtg.Step.UPKEEP)
	screen._on_phase_bar_slot(PhaseStops.Half.YOURS, 3)
	assert_eq(screen._prompt_label.text, "Paused: Draw phase",
		"the Stop announced itself in the Situation Bar")


func test_the_combat_bar_click_still_ends_a_declaration() -> void:
	# Manual p.126 — unchanged by run-to being added beside it.
	if screen._combat_bar == null:
		pass_test("no original skin imported")
		return
	var g: MtgGame = screen.game
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	screen.mode = DuelScreen.Mode.ATTACKERS
	screen._selected_attackers = []
	screen._on_combat_bar_slot(CombatBar.Slot.ATTACKER_FAST_EFFECTS)
	assert_false(g.awaiting_attackers, "the click submitted the lineup")


# ================================================== Done, the standing order --

func test_done_runs_on_until_a_stop() -> void:
	# Manual p.112: Done "tells the 'referee' that you do not intend any
	# action until (1) you reach a phase that has a Stop on it…"
	screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 3,
		true)                                       # your Main pre-combat
	_stand_in(Mtg.Step.UPKEEP)
	screen._on_pass_turn()
	assert_eq(screen.game.current_step(), Mtg.Step.MAIN1,
		"Done ran to the Stop and no further")
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE)


func test_done_stops_when_a_fast_effect_is_affordable() -> void:
	# "…or (3) you are able to use a fast effect. (Note that 'able to' means
	# that you have a fast effect handy AND you have the mana available to
	# use that effect.)"
	var bolt := CardRegistry.get_card("Lightning Bolt")
	if bolt == null:
		pass_test("Lightning Bolt not in the pool")
		return
	_stand_in(Mtg.Step.UPKEEP)
	var g: MtgGame = screen.game
	g.players[0].hand.clear()
	var inst := CardInstance.new(bolt, 90210, 0)
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)
	assert_false(screen._has_affordable_fast_effect(0),
		"an instant with no mana floated is not yet usable")
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_true(screen._has_affordable_fast_effect(0),
		"handy AND payable — the manual's two halves")
	var step: int = g.current_step()
	screen._on_pass_turn()
	assert_eq(g.current_step(), step,
		"Done refuses to burn the window it can actually use")


func test_done_still_takes_a_quiet_duel_forward() -> void:
	# The everyday case: nothing marked, nothing affordable, no decision —
	# Done runs, which is the "if the red dot is removed it moves
	# automatically" half of the feature.
	_stand_in(Mtg.Step.UPKEEP)
	screen.game.players[0].hand.clear()
	screen.game.players[1].hand.clear()
	var before: int = Mtg.STEP_ORDER.find(screen.game.current_step())
	screen._on_pass_turn()
	assert_true(screen.game.turn_number > 1
			or Mtg.STEP_ORDER.find(screen.game.current_step()) > before,
		"the duel moved on its own")
