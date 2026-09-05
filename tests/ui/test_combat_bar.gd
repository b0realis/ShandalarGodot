extends GutTest
## THE COMBAT BAR — the strip that replaces the Phase Bar during an attack
## (manual p.117/p.125, `Duel.hlp` topic "Combat Bar"; game/duel/combat_bar.gd).
##
## These pin the three things a later pass could silently break: the SEVEN
## icons and their 1997 tooltips, the sheet geometry measured off
## `Winbk_Phasecombat.pic`, and the step→icon mapping.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


# ------------------------------------------------------- the seven icons --

func test_the_bar_has_seven_icons_not_five() -> void:
	# `Duel.hlp`, topic "Combat Bar": "This bar has seven icons, representing
	# the sub-phases of combat" — and it lists them. The printed manual
	# (p.117) says five and is outnumbered by the help file, the string
	# table and the art.
	assert_eq(CombatBar.SLOT_Y.size(), 7, "seven icon rows in the sheet")
	assert_eq(CombatBar.TOOLTIPS.size(), 7, "one cue card per icon")
	assert_eq(CombatBar.Slot.END_OF_COMBAT, 6, "the exit is the seventh")


func test_the_tooltips_are_the_1997_cue_cards_verbatim() -> void:
	# @CUECARD_PHASEBAR, shandalar-src/Program/UIStrings.txt:706 — the last
	# seven of its 23 entries, in the table's own order.
	assert_eq(CombatBar.TOOLTIPS, [
		"Choose attackers phase",
		"Attacker fast effects phase",
		"Assign defenders phase",
		"Blocker fast effects phase",
		"Resolve 1st strike damage",
		"Resolve normal damage",
		"Main phase (postcombat)",
	] as Array[String])


func test_every_icon_carries_its_cue_card_on_screen() -> void:
	var bar := CombatBar.new()
	add_child_autofree(bar)
	var seen: Array[String] = []
	for child in bar.get_children():
		if child is Control and (child as Control).tooltip_text != "":
			seen.append((child as Control).tooltip_text)
	assert_eq(seen, CombatBar.TOOLTIPS,
		"the hover zones carry the seven cue cards in order")


# ----------------------------------------------------- the sheet geometry --

func test_the_bar_wears_blue_for_you_and_gold_for_the_opponent() -> void:
	# Winbk_Phasecombat.pic (164x760) carries FOUR columns: a gold
	# [normal | active] pair at x 0..81 and a blue one at x 82..163.
	# THE OWNER SETTLED THIS (2026-08-31): "make it blue when im attacking
	# and gold when an enemy is attacking." An earlier pass had inferred
	# from one 1997 screenshot of "Your attack" that the bar was always
	# blue and left the gold half unused; the sheet lays both halves out
	# identically because both are used, and this is the Phase Bar's own
	# convention (opponent gold on top, player blue below).
	assert_eq(CombatBar.SHEET_SIZE, Vector2(164.0, 760.0))
	assert_eq(CombatBar.column_region(false), Rect2(0, 0, 41, 760),
		"the opponent's attack wears the GOLD half")
	assert_eq(CombatBar.column_region(true), Rect2(82, 0, 41, 760),
		"your own attack wears the BLUE half")
	assert_eq(CombatBar.SEAT_PITCH * 2.0, CombatBar.SHEET_SIZE.x,
		"two 82px halves fill the sheet exactly")


func test_the_highlighted_cell_sits_at_44_inside_its_half() -> void:
	# The same 35x40 cell at x=44 the Phase Bar uses (s30 phasePOS), inside
	# whichever half the attacking seat owns. This cell is drawn UNKEYED —
	# white behind the icon — while the rest of the column is keyed to
	# black, so the white box IS the current-sub-phase cue.
	assert_eq(CombatBar.active_region(false, CombatBar.Slot.DECLARE_ATTACKERS),
		Rect2(44, 2, 35, 40), "gold half: 0 + 44")
	assert_eq(CombatBar.active_region(true, CombatBar.Slot.DECLARE_ATTACKERS),
		Rect2(126, 2, 35, 40), "blue half: 82 + 44")


func test_the_unlit_column_is_keyed_to_black_and_the_lit_cell_is_not() -> void:
	# The owner's "classic MicroProse manner": "icons use black behind
	# (recolor white to black and when individual phase is active use the
	# white behind icon)" — which is exactly what Winbk_Phase already does
	# in its own art, black cells with one white one.
	var sheet := GameSkin.texture("combat_bar")
	if sheet == null:
		pass_test("no original skin imported — nothing to measure")
		return
	var ground := CombatBar.keyed_texture(
		CombatBar.column_region(true), CombatBar.Fill.BLACK)
	assert_not_null(ground)
	var img := ground.get_image()
	# A pixel inside the first icon cell that is white in the sheet must be
	# black in the keyed ground. The cell interior's top-left corner is
	# background in every one of the seven icons.
	var probe := Vector2i(int(CombatBar.CELL_X) + 3, int(CombatBar.SLOT_Y[0]) + 3)
	var raw: Color = sheet.get_image().get_pixel(
		int(CombatBar.SEAT_PITCH) + probe.x, probe.y)
	assert_gte(raw.r, CombatBar.WHITE_KEY, "the sheet draws that pixel white")
	assert_eq(img.get_pixel(probe.x, probe.y), Color.BLACK,
		"and the keyed ground draws it black")


func test_the_rows_run_at_the_phase_bars_own_41px_pitch() -> void:
	for i in 6:
		assert_eq(CombatBar.SLOT_Y[i], 2.0 + 41.0 * i,
			"icon %d rides the 41px pitch" % i)
	# The exit crescent skips row 6 — the bare stone gap the original
	# leaves between the six in-combat icons and the way out.
	assert_eq(CombatBar.SLOT_Y[6], 2.0 + 41.0 * 7)


func test_the_icons_are_really_there_in_the_imported_sheet() -> void:
	var sheet := GameSkin.texture("combat_bar")
	if sheet == null:
		pass_test("no original skin imported — nothing to measure")
		return
	assert_eq(Vector2(sheet.get_width(), sheet.get_height()),
		CombatBar.SHEET_SIZE, "Winbk_Phasecombat is 164x760")
	var img := sheet.get_image()
	# Row 6 is BARE STONE: no icon card, which is what makes the gap.
	var gap_y := int(2.0 + 41.0 * 6) + 20
	var icon_y := int(CombatBar.SLOT_Y[5]) + 20
	assert_lt(img.get_pixel(20, gap_y).v, img.get_pixel(20, icon_y).v,
		"the empty row is dark stone where the icon row is a bright card")


# ------------------------------------------------------- step -> the icon --

func test_each_combat_step_lights_its_own_icon() -> void:
	assert_eq(CombatBar.slot_for_step(Mtg.Step.COMBAT_BEGIN, false, false),
		CombatBar.Slot.DECLARE_ATTACKERS,
		"announcing the attack points at declaring it")
	assert_eq(CombatBar.slot_for_step(Mtg.Step.DECLARE_ATTACKERS, true, false),
		CombatBar.Slot.DECLARE_ATTACKERS)
	assert_eq(CombatBar.slot_for_step(Mtg.Step.DECLARE_ATTACKERS, false, false),
		CombatBar.Slot.ATTACKER_FAST_EFFECTS,
		"once the lineup is in, the same step IS the fast-effects round")
	assert_eq(CombatBar.slot_for_step(Mtg.Step.DECLARE_BLOCKERS, false, true),
		CombatBar.Slot.DECLARE_BLOCKERS)
	assert_eq(CombatBar.slot_for_step(Mtg.Step.DECLARE_BLOCKERS, false, false),
		CombatBar.Slot.BLOCKER_FAST_EFFECTS)
	assert_eq(CombatBar.slot_for_step(Mtg.Step.FIRST_STRIKE_DAMAGE, false, false),
		CombatBar.Slot.FIRST_STRIKE_DAMAGE)
	assert_eq(CombatBar.slot_for_step(Mtg.Step.COMBAT_DAMAGE, false, false),
		CombatBar.Slot.NORMAL_DAMAGE)
	assert_eq(CombatBar.slot_for_step(Mtg.Step.COMBAT_END, false, false),
		CombatBar.Slot.END_OF_COMBAT)


func test_the_bar_covers_exactly_the_combat_phase() -> void:
	for step in [Mtg.Step.COMBAT_BEGIN, Mtg.Step.DECLARE_ATTACKERS,
			Mtg.Step.DECLARE_BLOCKERS, Mtg.Step.FIRST_STRIKE_DAMAGE,
			Mtg.Step.COMBAT_DAMAGE, Mtg.Step.COMBAT_END]:
		assert_true(CombatBar.covers_step(step),
			"%s is a combat sub-phase" % Mtg.step_name(step))
	for step in [Mtg.Step.UNTAP, Mtg.Step.UPKEEP, Mtg.Step.DRAW,
			Mtg.Step.MAIN1, Mtg.Step.MAIN2, Mtg.Step.END, Mtg.Step.CLEANUP]:
		assert_false(CombatBar.covers_step(step),
			"%s belongs to the Phase Bar" % Mtg.step_name(step))


# ----------------------------------------------------------- the swap --

func test_the_combat_bar_replaces_the_phase_bar_and_gives_it_back() -> void:
	if screen._combat_bar == null:
		pass_test("no original skin imported — neither bar is built")
		return
	var g: MtgGame = screen.game
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	screen._refresh()
	assert_false(screen._combat_bar.visible, "no attack, no Combat Bar")
	assert_true(screen._phase_bar.visible, "the Phase Bar holds the column")
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true              # the attack is being declared
	screen._refresh()
	assert_true(screen._combat_bar.visible,
		"the Combat Bar takes the place of the Phase Bar")
	assert_false(screen._phase_bar.visible,
		"only one bar in the column — and the Phase Bar's own icons, "
		+ "highlight and Stop dots are all inside it, so they go with it")
	g.awaiting_attackers = false
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN2)
	screen._refresh()
	assert_true(screen._phase_bar.visible, "combat over, the Phase Bar returns")
	assert_false(screen._combat_bar.visible)


func test_no_attackers_means_no_combat_bar_at_all() -> void:
	# THE OWNER'S PLAYTEST, 2026-09-03: "If no attackers are declared the
	# combat subphases should not show." `Duel.hlp`, topic **Combat Bar**:
	# the bar "appears during an ATTACK" — and topic **Combat**: "as soon
	# as you add the first creature to the attack, the Combat window
	# opens". Declare none and there is no attack, so the strip that marks
	# an attack's sub-phases has nothing to mark.
	#
	# The ENGINE was already right (CR 506.4 / 508.1 — `MtgGame`'s own
	# "Skip blockers/damage when no attackers were declared"); it was the
	# screen that paraded them.
	assert_true(CombatBar.shows_attack(Mtg.Step.COMBAT_BEGIN, false, 0),
		"combat begins: 'your next step is declaring your attack'")
	assert_true(CombatBar.shows_attack(Mtg.Step.DECLARE_ATTACKERS, true, 0),
		"...and while it is being declared")
	assert_false(CombatBar.shows_attack(Mtg.Step.DECLARE_ATTACKERS, false, 0),
		"declared, and nobody attacked: no attack, no bar")
	assert_true(CombatBar.shows_attack(Mtg.Step.DECLARE_ATTACKERS, false, 1),
		"one attacker is an attack")
	for step in [Mtg.Step.DECLARE_BLOCKERS, Mtg.Step.FIRST_STRIKE_DAMAGE,
			Mtg.Step.COMBAT_DAMAGE, Mtg.Step.COMBAT_END]:
		assert_false(CombatBar.shows_attack(step, false, 0),
			"%s is ceremony with no attackers" % Mtg.step_name(step))
		assert_true(CombatBar.shows_attack(step, false, 2),
			"%s is real with attackers" % Mtg.step_name(step))
	assert_false(CombatBar.shows_attack(Mtg.Step.MAIN1, false, 3),
		"and never outside the combat phase")


func test_the_screen_puts_the_phase_bar_back_when_nobody_attacks() -> void:
	if screen._combat_bar == null:
		pass_test("no original skin imported — neither bar is built")
		return
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	screen._refresh()
	assert_true(screen._combat_bar.visible, "the attack is being declared")
	assert_eq(g.declare_attackers(0, []), "", "...and nobody attacks")
	screen._refresh()
	assert_false(screen._combat_bar.visible,
		"the sub-phases stop showing the moment there is no attack")
	assert_true(screen._phase_bar.visible,
		"the Phase Bar's own combat icon carries the phase instead")


func test_the_bar_wears_the_attacking_seats_colour() -> void:
	if screen._combat_bar == null:
		pass_test("no original skin imported")
		return
	var g: MtgGame = screen.game
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true              # an attack is being declared
	g.active_player = 0                      # the human attacks
	screen._refresh()
	assert_eq(screen._combat_bar._is_player_seat, true,
		"the player's own attack shows the sheet's BLUE half")
	g.active_player = 1
	screen._refresh()
	assert_eq(screen._combat_bar._is_player_seat, false,
		"the opponent's attack shows the GOLD half")


func test_clicking_a_sub_phase_is_the_third_way_to_say_done() -> void:
	# Manual p.126: "Use the Done option on the mini-menu, the Done button
	# on the Situation Bar, or click a sub-phase on the Combat Bar."
	if screen._combat_bar == null:
		pass_test("no original skin imported")
		return
	var g: MtgGame = screen.game
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	screen.mode = DuelScreen.Mode.ATTACKERS
	screen._selected_attackers = []
	screen._on_combat_bar_slot(CombatBar.Slot.ATTACKER_FAST_EFFECTS)
	assert_false(g.awaiting_attackers,
		"the click submitted the (empty) lineup, exactly as Done would")
