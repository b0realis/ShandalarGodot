extends GutTest
## Smoke tests for the duel screen: the scene must boot a real game, drive
## the engine through its public API, refresh without errors, and survive
## fast-forwarded turns. Deep interaction testing stays in the engine
## suites — this guards the UI wiring (mode machine, rebuilds, popups).


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func test_scene_boots_a_real_game() -> void:
	assert_not_null(screen.game)
	assert_eq(screen.game.players[0].hand.size(), 7, "opening hand dealt")
	assert_eq(screen.game.players[0].library.size(), 33, "40-card deck minus hand")
	assert_false(screen.game.game_over)


func test_starter_decks_are_fully_implemented() -> void:
	# Every deck name must resolve — a stub name here would error at setup.
	for deck in [StarterDecks.WHITE_KNIGHTS, StarterDecks.BLACK_RED_RAIDERS]:
		assert_eq(deck.size(), 40)
		for card_name in deck:
			assert_not_null(CardRegistry.get_card(card_name), card_name)


func test_pass_and_fast_forward_advance_the_game() -> void:
	var turn := screen.game.turn_number
	var step := Mtg.STEP_ORDER.find(screen.game.current_step())
	screen._on_pass()
	screen._on_pass_turn()
	# Done runs on until the first thing 1997 says it must stop for. Since
	# 2026-09-03 a fresh profile HAS such a thing on your own turn — the
	# three default Stops (PhaseStops.DEFAULT_SLOTS) — so this no longer
	# reaches the attacker declaration in one press, and asserting that it
	# does was asserting the absence of the feature. What must always hold
	# is that the duel MOVED and the UI refreshed without error.
	assert_true(screen.game.turn_number > turn
			or Mtg.STEP_ORDER.find(screen.game.current_step()) > step
			or screen.game.awaiting_attackers or screen.game.awaiting_blockers,
		"the duel went forward under Done")


func test_combat_mode_engages_automatically() -> void:
	# This is about the MODE following the engine, not about where Done
	# comes to rest — so it clears the three default Stops (2026-09-03,
	# PhaseStops.DEFAULT_SLOTS) and presses on until combat. It used to be
	# written as `if awaiting_attackers:` around the whole body, which
	# asserted NOTHING the moment Done stopped anywhere else.
	screen.stops.clear_all()
	for _i in 12:
		if screen.game.awaiting_attackers:
			break
		screen._on_pass_turn()   # runs to the next stop
	assert_true(screen.game.awaiting_attackers,
		"Done reached the attacker declaration")
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS,
		"UI entered attacker declaration with the engine")
	screen._on_confirm()   # declare no attackers
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_full_fast_forwarded_turns_do_not_crash() -> void:
	for _i in 6:
		if screen.game.game_over:
			break
		if screen.game.awaiting_attackers or screen.game.awaiting_blockers:
			screen._on_confirm()
		else:
			screen._on_pass_turn()
	assert_gte(screen.game.turn_number, 2, "several turns elapsed under UI control")


# ------------------------------------------------------- the coin toss --
#
# THE PRESENTATION MOVED to `game/duel/coin_toss.gd` on 2026-09-02 (the
# fiftieth pass), with its three modes, and is tested in
# `tests/ui/test_coin_toss.gd`. What stays here is the duel screen's own
# half of the contract: the toss must not block a headless run, and the
# leader must come off `game.rng` so a seeded duel replays.

func test_headless_skips_the_toss_animation() -> void:
	# Tests and CI must not wait on tweens: the duel starts immediately
	# and nothing is left blocking the AI scheduler.
	assert_false(screen._toss_active, "the toss does not block headless runs")
	assert_null(screen._toss_overlay, "no overlay is left behind")


func test_the_toss_is_seeded_so_a_duel_replays() -> void:
	# The leader is rolled on game.rng, so the same seed reproduces the
	# same opening — it would drift if it used the global RNG.
	var leaders: Array[int] = []
	for _run in 2:
		var g := MtgGame.new()
		g.setup(StarterDecks.WHITE_KNIGHTS, StarterDecks.BLACK_RED_RAIDERS,
			"A", "B", 20, 20, 4242)
		leaders.append(g.rng.randi() % 2)
	assert_eq(leaders[0], leaders[1], "seed 4242 always leads with the same seat")


func test_the_card_slot_holds_a_card_back_until_something_is_examined() -> void:
	# The sidebar slot is never an empty black hole: it starts face down
	# and the first examined card replaces the back.
	var preview: CardPreview = screen._card_preview
	assert_true(preview.visible, "the docked slot is occupied at duel start")
	assert_true(preview._back.visible, "by a card back")

	var inst: CardInstance = screen.game.players[0].hand[0]
	preview.show_card(inst)
	assert_false(preview._back.visible, "examining a card turns it face up")
	assert_true(preview.visible)

	preview.show_back()
	assert_true(preview._back.visible, "and it can be turned back over")


# ------------------------------------------------------ sidebar geometry --

func test_the_players_life_numeral_sits_flush_with_the_bottom_edge() -> void:
	# The owner's layout: each life numeral hugs its own corner of the
	# screen, with no dead strip under the player's block.
	await get_tree().process_frame
	var view := screen.get_viewport_rect().size
	var mine: Button = screen._life_buttons[0]
	assert_almost_eq(mine.global_position.y + mine.size.y, view.y, 2.0,
		"the player's life finishes on the bottom edge")
	var theirs: Button = screen._life_buttons[1]
	assert_almost_eq(theirs.global_position.y, 0.0, 2.0,
		"the opponent's starts on the top edge")


func test_the_big_card_rides_high_over_the_qol_reserve() -> void:
	# The examined card sits directly under the opponent's block; ALL the
	# column's slack collects below it, reserved for future QoL controls.
	await get_tree().process_frame
	var dock := screen._preview_dock
	var reserve := screen._qol_reserve
	assert_gt(reserve.global_position.y, dock.global_position.y,
		"the reserve lies below the card, not above it")
	assert_gt(reserve.size.y, 0.0, "and it has room to hold something")
	var theirs: Button = screen._life_buttons[1]
	assert_lt(dock.global_position.y - (theirs.global_position.y + theirs.size.y),
		200.0, "the card rides close under the opponent's block")


# ------------------------------------------------- 2026-09 audit findings --

func test_an_ability_with_x_in_its_cost_asks_for_x() -> void:
	# Voodoo Doll's "{X}{X}, {T}:" used to submit X=0 silently, firing it
	# for free; the Candelabra's "Untap X target lands" offered no slots.
	var doll := CardRegistry.get_card("Voodoo Doll")
	assert_not_null(doll)
	var ability: ActivatedAbility = doll.activated_abilities[0]
	assert_true(ability.cost.has_x, "the ability really carries X")
	assert_eq(ability.cost.x_count, 2, "and charges twice per point of X")


func test_the_x_bound_charges_x_count_per_point() -> void:
	# {X}{X} costs charge x_count mana per point of X, so an X dialog
	# bounded on a single X would offer double what the pool can pay.
	var pool := ManaPool.new()
	pool.add(Mtg.ManaColor.C, 4)
	var doubled := ManaCost.parse("{X}{X}")
	var per_x: int = maxi(doubled.x_count, 1)
	var max_x := 0
	while pool.can_pay(doubled, (max_x + 1) * per_x):
		max_x += 1
	assert_eq(max_x, 2, "four mana pays X=2 on a doubled cost, not X=4")


func test_the_ability_menu_lists_live_abilities() -> void:
	# The engine indexes cur_*; a menu built from the printed lists both
	# lies about a retyped permanent and shifts the indices.
	var source := FileAccess.get_file_as_string(
		"res://game/duel/duel_screen.gd")
	assert_true(source.contains("for ability in inst.cur_mana_abilities"),
		"the menu enumerates LIVE mana abilities")
	assert_true(source.contains("for ability in inst.cur_activated_abilities"),
		"and LIVE activated abilities")


func test_every_duel_runs_on_a_logged_seed() -> void:
	# A duel must be replayable from a bug report.
	assert_ne(screen.game.rng.seed, 0, "the game got a real seed")
	var logged := false
	for line in screen.game.log_lines:
		if line.begins_with("Duel seed: "):
			logged = true
	assert_true(logged, "and the seed is on the log for the report")


func test_a_configured_seed_reproduces_the_opening_hand() -> void:
	var hands: Array[String] = []
	for _run in 2:
		var config := DuelConfig.hotseat_default()
		config.rng_seed = 90210
		var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
		duel.config = config
		add_child_autofree(duel)
		await get_tree().process_frame
		var names: Array[String] = []
		for card in duel.game.players[0].hand:
			names.append(card.data.card_name)
		hands.append(", ".join(names))
	assert_eq(hands[0], hands[1], "seed 90210 always deals the same hand")


func test_poison_counters_show_a_clock_on_the_life_panel() -> void:
	# Ten poison counters lose the game; the duel used to show no sign of
	# them at all, so a loss to Marsh Viper came out of nowhere.
	await get_tree().process_frame
	assert_false(screen._poison_labels[0].visible, "hidden while clean")
	screen.game.add_poison(0, 3)
	screen._refresh()
	assert_true(screen._poison_labels[0].visible, "shown once poisoned")
	assert_eq(screen._poison_labels[0].text, "3/10", "counting toward the loss")


func test_restricted_mana_shows_in_the_pool_readout() -> void:
	# Mishra's Workshop floats restricted mana; amount_of() hid it and the
	# panel read all zeroes while three mana was in the pool.
	var pool := ManaPool.new()
	pool.add_restricted(Mtg.ManaColor.C, 3, "artifact")
	assert_eq(pool.amount_of(Mtg.ManaColor.C), 0, "none of it is unrestricted")
	assert_eq(pool.total_of(Mtg.ManaColor.C), 3, "but the readout sees it")
	pool.add(Mtg.ManaColor.C, 2)
	assert_eq(pool.total_of(Mtg.ManaColor.C), 5, "and sums both kinds")


func test_the_castable_hint_honours_cost_modifiers() -> void:
	# Gloom taxes white spells {3}; a hint that reads only the printed
	# cost turns the name yellow for a spell the engine will refuse.
	var g := MtgGame.new()
	g.setup([StarterDecks.WHITE_KNIGHTS[0]], [StarterDecks.WHITE_KNIGHTS[0]],
		"A", "B", 20, 20, 77)
	g.start(1, 0)
	var white := CardRegistry.get_card("Savannah Lions")   # {W}
	g.players[0].mana_pool.add(Mtg.ManaColor.W, 1)
	assert_true(g.can_afford(0, white), "one Plains casts a one-drop")

	var gloom := CardRegistry.get_card("Gloom")
	if gloom != null:
		var inst := CardInstance.new(gloom, 91000, 1)
		g._instances[inst.id] = inst
		g._put_on_battlefield(inst, 1)
		assert_false(g.can_afford(0, white),
			"under Gloom that same Plains no longer covers it")


func test_restricted_mana_makes_an_artifact_castable() -> void:
	# Mishra's Workshop's mana only casts artifacts — the hint must see
	# it, which a plain can_pay on the unrestricted pool cannot.
	var g := MtgGame.new()
	g.setup([StarterDecks.WHITE_KNIGHTS[0]], [StarterDecks.WHITE_KNIGHTS[0]],
		"A", "B", 20, 20, 78)
	g.start(1, 0)
	var vise := CardRegistry.get_card("Black Vise")        # {1}, artifact
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 3, "artifact")
	assert_true(g.can_afford(0, vise), "workshop mana casts the artifact")
	var lions := CardRegistry.get_card("Savannah Lions")
	assert_false(g.can_afford(0, lions), "but not a creature")


# ------------------------------- the hand window floats, and that is all --
#
# It used to reserve a band: each half gave up the horizontal strip the
# window covered so the piles squeezed instead of being painted over, and
# the reservation was recomputed from the window's LIVE rect as it was
# dragged. The owner overruled it on 2026-09-04 — *"Yes, the hand stack
# can be present anywhere — only cast mini-cards are bound to the
# playfield"* — after the report that gave the reason: *"When I move my
# hand stack, also other cards move on the table."* A board that yields to
# a draggable window RE-LAYS ITSELF OUT on every drag, and measured under
# Xvfb a single 480px drag slid all four of a row's lands 385px sideways.
# The window is chrome the player parks where they like; the board does
# not notice it. See `tests/ui/test_card_placement.gd` for the placement
# half of the same rule.

func _stack_window() -> StackHand:
	if screen._hand_rows.size() > 1 and screen._hand_rows[1] is StackHand:
		return screen._hand_rows[1]
	return null


func test_each_half_keeps_its_full_width_wherever_the_window_sits() -> void:
	var stack := _stack_window()
	if stack == null:
		pass_test("fan hand layout: nothing floats over the board")
		return
	await get_tree().process_frame
	for corner in [Vector2(60.0, 60.0), Vector2(400.0, 420.0),
			Vector2(screen.size.x - stack.size.x, 420.0)]:
		stack.position = corner
		await get_tree().process_frame
		await get_tree().process_frame
		for pid in 2:
			var rows: Control = screen._half_rows[pid]
			assert_eq(rows.offset_right, -DuelScreen.BOARD_INSET,
				"half %d keeps its own inset with the window at %s"
					% [pid, corner])


func test_the_window_is_not_wired_into_the_board_at_all() -> void:
	# The invariant behind it, so a refactor cannot quietly reconnect the
	# two: dragging the window emits `item_rect_changed`, and NOTHING on
	# the duel screen may be listening.
	var stack := _stack_window()
	if stack == null:
		pass_test("fan hand layout")
		return
	for con in stack.item_rect_changed.get_connections():
		var cb: Callable = con["callable"]
		assert_ne(cb.get_object(), screen,
			"the board does not listen to the hand window (got %s)"
				% cb.get_method())


func test_dragging_the_window_across_the_board_moves_no_card() -> void:
	# The owner's report, end to end at the layout level: every card the
	# rows draw is exactly where it was after the window has crossed them.
	var stack := _stack_window()
	if stack == null:
		pass_test("fan hand layout")
		return
	# Something to disturb: a right-hugging land pile (the row the reserve
	# used to squeeze) and a creature.
	var g: MtgGame = screen.game
	for i in 4:
		var land := CardInstance.new(CardRegistry.get_card("Forest"),
			96100 + i, 0)
		g._instances[land.id] = land
		g._put_on_battlefield(land, 0)
	var bear := CardInstance.new(
		CardRegistry.get_card("Grizzly Bears"), 96200, 0)
	g._instances[bear.id] = bear
	g._put_on_battlefield(bear, 0)
	screen._refresh()
	stack.position = Vector2(screen.size.x - stack.size.x, 420.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var before := _board_cards()
	assert_gt(before.size(), 0, "there are cards on the board to disturb")
	for x in [900.0, 600.0, 300.0, 40.0]:
		stack.position = Vector2(x, stack.position.y)
		await get_tree().process_frame
		await get_tree().process_frame
	var after := _board_cards()
	for id in before:
		assert_eq(after.get(id), before[id],
			"card %d did not move when the window crossed it" % id)


## Every MiniCard the BOARD draws, by instance id, in screen coordinates.
func _board_cards() -> Dictionary:
	var out := {}
	for pid in 2:
		for row in screen._field_rows[pid]:
			_collect_cards(screen._field_rows[pid][row], out)
	return out


func _collect_cards(n: Node, out: Dictionary) -> void:
	if n is MiniCard and (n as MiniCard).instance != null:
		out[(n as MiniCard).instance.id] = (n as MiniCard).global_position
	for c in n.get_children():
		_collect_cards(c, out)


func test_the_seat_colour_is_the_decks_dominant_colour() -> void:
	# The owner's rule: a seat's colour — and so its hand-window border,
	# life panel, terrain and graveyard plate — is the colour the MOST
	# cards in that deck are.
	var config := DuelConfig.hotseat_default()
	assert_eq(config.panel_colors[0],
		DuelConfig.dominant_color(config.decks[0]),
		"seat 0 wears its own deck's colour")
	assert_eq(config.panel_colors[1],
		DuelConfig.dominant_color(config.decks[1]),
		"and so does seat 1")

	# Swapping the decks swaps the colours: nothing is hardcoded.
	var swapped := DuelConfig.new()
	swapped.decks = [config.decks[1], config.decks[0]]
	swapped.apply_deck_colors()
	assert_eq(swapped.panel_colors[0], config.panel_colors[1])
	assert_eq(swapped.panel_colors[1], config.panel_colors[0])
	assert_ne(swapped.panel_colors[0], swapped.panel_colors[1],
		"the two starter decks really are different colours")


# ------------------------------------- the 1997 popups & the Situation Bar --
# The bar's wording comes from shandalar-src/Program/UIStrings.txt (see
# docs/glossary-1997.md); these pin the strings that were ours, not the
# original's, so a later pass cannot quietly reinvent them.

func test_the_situation_bar_speaks_the_originals_own_lines() -> void:
	# @PROMPT_MAIN (UIStrings.txt:1063). Ours used to read "Main phase:
	# play a land or cast spells. Done to go to combat." — an instruction
	# the 1997 game never gives.
	screen.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	screen.game.active_player = 0
	screen.game.priority_player = 0
	screen.game.players[0].lands_played_this_turn = 0
	assert_eq(screen._status_message(),
		"Main phase (before combat): cast spells, play land")
	screen.game.players[0].lands_played_this_turn = 1
	assert_eq(screen._status_message(),
		"Main phase (before combat): cast spells",
		"the land clause drops once the drop is spent")


func test_fast_effects_names_the_phase_the_way_1997_does() -> void:
	# @PROMPT_FASTEFFECTS "Fast Effects?...%s" filled from
	# @PROMPT_CHECKFEPHASE. Both halves are quoted, ellipsis included.
	assert_eq(DuelScreen._fe_phase_name(Mtg.Step.DECLARE_ATTACKERS),
		"Assign Attackers")
	assert_eq(DuelScreen._fe_phase_name(Mtg.Step.DECLARE_BLOCKERS),
		"Assign Blockers")
	assert_eq(DuelScreen._fe_phase_name(Mtg.Step.CLEANUP), "Discard Phase",
		"the original's Discard phase is where our CLEANUP runs")
	assert_eq(DuelScreen._fe_phase_name(Mtg.Step.UPKEEP), "Upkeep Phase")


func test_the_bar_never_asks_a_question_the_original_does_not() -> void:
	# "Attackers?...", "Blockers?..." and "GAME OVER —" were ours. The
	# "?..." form belongs to @PROMPT_FASTEFFECTS alone.
	var source := FileAccess.get_file_as_string(
		"res://game/duel/duel_screen.gd")
	for invented in ["Attackers?...Declare", "Blockers?...Declare",
			"GAME OVER"]:
		assert_false(source.contains(invented), invented)
	assert_true(source.contains("Fast Effects?...%s"),
		"the one question the original does ask")


func test_the_duels_verdict_is_the_1997_wording() -> void:
	# @DIALOG_SHANDALARENDDUEL (UIStrings.txt:514) is three lines: "%s
	# won", "You won!", "The duel is a draw".
	screen.game.game_over = true
	screen.game.winner = 0
	assert_eq(screen._status_message(), "You won!")
	screen.game.winner = -1
	assert_eq(screen._status_message(), "The duel is a draw")
	# The third line is for a seat you are NOT sitting in; the default
	# hotseat config makes both seats human, so it is pinned in source.
	var source := FileAccess.get_file_as_string(
		"res://game/duel/duel_screen.gd")
	assert_true(source.contains('"%s won" % game.players[game.winner].player_name'),
		"the opponent's win reads \"%s won\"")


func test_the_targeting_cursor_does_not_outlive_the_screen() -> void:
	# `Input.set_custom_mouse_cursor` is process-global; a screen freed
	# mid-targeting (Concede → Yes) used to leave the crosshair on every
	# screen after it (2026-09-02).
	screen._set_target_cursor(true)
	assert_true(screen._target_cursor_active)
	remove_child(screen)
	assert_false(screen._target_cursor_active,
		"leaving the tree puts the system cursor back")
	screen._set_target_cursor(false)
	assert_false(screen._target_cursor_active)


func test_a_drawn_duel_plays_neither_sting_and_belongs_to_no_seat() -> void:
	# The original has Shell_WinDuel.wav and Shell_LoseDuel.wav and no
	# third sting (`windows.c:1229-1230`). `-1` is the engine's "no
	# winner", and `_is_human(-1)` used to be TRUE — every seat that is not
	# an AI — so a draw greeted the player with the win sting (2026-09-02).
	assert_false(screen._is_human(-1), "no seat is not the human seat")
	screen._audio.recent.clear()
	screen._on_game_over(-1)
	assert_eq(screen._audio.recent, [] as Array[String],
		"a draw ends in silence")
	assert_eq(screen._prompt_label.text, "The duel is a draw")
	screen._audio.recent.clear()
	screen._on_game_over(0)
	assert_true(screen._audio.recent.has("sfx_win"),
		"the human seat's win still has its sting")


func test_a_duel_between_two_ais_plays_neither_sting() -> void:
	# Both stings are addressed to the player ("you won" / "you lost"), so
	# the title screen's demo — no human seat — used to end on the LOSE
	# sting whoever won (2026-09-06).
	var demo: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	demo.config = DuelConfig.demo_default()
	demo.config.pace = 0.0
	add_child_autofree(demo)
	await get_tree().process_frame
	assert_false(demo._is_human(0))
	assert_false(demo._is_human(1))
	for winner in [0, 1]:
		demo._audio.recent.clear()
		demo._on_game_over(winner)
		assert_eq(demo._audio.recent, [] as Array[String],
			"nobody at the table to hear a sting")
		assert_eq(demo._prompt_label.text,
			"%s won" % demo.game.players[winner].player_name)


func test_every_centre_popup_wears_the_shared_chrome() -> void:
	# The whole point of OriginalDialog: one component, so the look cannot
	# drift popup by popup. No duel popup may be an OS Window again.
	var source := FileAccess.get_file_as_string(
		"res://game/duel/duel_screen.gd")
	for os_window in ["AcceptDialog.new()", "ConfirmationDialog.new()"]:
		assert_false(source.contains(os_window), os_window)
	assert_true(source.contains("OriginalDialog.bar_style"),
		"the Situation Bar is ruled by the shared component")


func test_the_x_question_opens_as_an_original_dialog() -> void:
	var fireball := CardRegistry.get_card("Fireball")
	if fireball == null:
		pass_test("Fireball not in the pool")
		return
	var inst := CardInstance.new(fireball, 4242, 0)
	screen.game._instances[inst.id] = inst
	screen._pending_card = inst
	screen._pending_pid = 0
	screen._pending_ability_index = -1
	screen._open_x_dialog()
	assert_not_null(screen._x_dialog)
	assert_true(screen._x_dialog is OriginalDialog)
	# @DIALOG_FIREBALL (UIStrings.txt:657) — the original's own question.
	var found := false
	for node in screen._x_dialog.body().get_children():
		if node is Label and node.text.begins_with("Generic mana"):
			found = true
	assert_true(found, "the 1997 question is on the dialog")
	screen._x_dialog.queue_free()
	screen._x_dialog = null
	screen._pending_card = null


func test_the_library_picker_opens_as_an_original_dialog() -> void:
	var tutor := CardRegistry.get_card("Demonic Tutor")
	if tutor == null:
		pass_test("Demonic Tutor not in the pool")
		return
	var inst := CardInstance.new(tutor, 4243, 0)
	screen.game._instances[inst.id] = inst
	screen._pending_card = inst
	screen._pending_pid = 0
	screen._open_search_dialog(SearchLibraryEffect.new())
	assert_true(screen._search_dialog is OriginalDialog)
	assert_gt(screen._search_list.item_count, 0, "the library is listed")
	screen._search_dialog.queue_free()
	screen._search_dialog = null
	screen._pending_card = null


func test_attackers_can_be_taken_back_by_default() -> void:
	# The owner's call (2026-08-31): ours stays revocable; 1997's "final"
	# is available in Options as a labelled divergence.
	assert_true(screen.game.rules.attackers_revocable)
	var lion := CardRegistry.get_card("Savannah Lions")
	var inst := CardInstance.new(lion, 95001, screen.game.active_player)
	screen.game._instances[inst.id] = inst
	screen.game._put_on_battlefield(inst, screen.game.active_player)
	inst.summoning_sick = false
	# In the declare-attackers step, or _refresh drops the declaration as
	# stale the moment _toggle_attacker calls it (§3.5).
	screen.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	screen.mode = DuelScreen.Mode.ATTACKERS

	screen._toggle_attacker(inst)
	assert_true(screen._selected_attackers.has(inst.id), "declared")
	screen._toggle_attacker(inst)
	assert_false(screen._selected_attackers.has(inst.id), "and taken back")

	# With the 1997 fork on, the second click is refused instead.
	screen.game.rules.attackers_revocable = false
	screen._toggle_attacker(inst)
	assert_true(screen._selected_attackers.has(inst.id))
	screen._toggle_attacker(inst)
	assert_true(screen._selected_attackers.has(inst.id),
		"under 1997 rules an attacker is committed")
	assert_string_contains(screen._prompt_label.text, "final")


# ------------------------------- the small card's border state machine --
# docs/duel-todo.md §2.10. The COLOUR CODE is the manual's (p.128:
# "Mandatory effects are highlighted in orange, while optional effects are
# in yellow") and the COVERAGE is s30's nine border states.

func _summon_for_highlight(card_name: String, pid: int) -> CardInstance:
	var g := screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func test_an_activatable_permanent_is_highlighted() -> void:
	# The NORMAL-mode cue we lacked entirely (s30 duel.go block 2b): a
	# permanent with something you can do on it.
	var g := screen.game
	var pid: int = g.priority_player
	var skeletons := _summon_for_highlight("Drudge Skeletons", pid)
	assert_eq(screen._highlight_for(skeletons), MiniCard.Highlight.NONE,
		"with an empty pool there is nothing to activate")
	g.players[pid].mana_pool.add(Mtg.ManaColor.B, 1)
	assert_eq(screen._highlight_for(skeletons), MiniCard.Highlight.OPTIONAL,
		"{B}: Regenerate is payable now — yellow, the manual's 'you may'")


func test_a_permanent_you_cannot_pay_for_is_not_highlighted() -> void:
	var g := screen.game
	var pid: int = g.priority_player
	var skeletons := _summon_for_highlight("Drudge Skeletons", pid)
	g.players[pid].mana_pool.add(Mtg.ManaColor.W, 5)
	assert_eq(screen._highlight_for(skeletons), MiniCard.Highlight.NONE,
		"white mana does not pay {B}")


func test_a_plain_creature_on_the_board_is_not_highlighted() -> void:
	# Mana abilities are deliberately excluded from the cue — every
	# untapped land has one, and lighting the mana base up would turn the
	# cue into wallpaper.
	var g := screen.game
	var pid: int = g.priority_player
	var lion := _summon_for_highlight("Savannah Lions", pid)
	var plains := _summon_for_highlight("Plains", pid)
	assert_eq(screen._highlight_for(lion), MiniCard.Highlight.NONE)
	assert_eq(screen._highlight_for(plains), MiniCard.Highlight.NONE,
		"a land is not 'actionable' for this cue")


func test_a_pending_attacker_is_committed_not_optional() -> void:
	var g := screen.game
	var lion := _summon_for_highlight("Savannah Lions", g.active_player)
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	screen.mode = DuelScreen.Mode.ATTACKERS
	assert_eq(screen._highlight_for(lion), MiniCard.Highlight.OPTIONAL,
		"eligible but not declared — yellow")
	screen._selected_attackers.append(lion.id)
	assert_eq(screen._highlight_for(lion), MiniCard.Highlight.COMMITTED,
		"declared — green, locked in")
	screen._selected_attackers.clear()


func test_a_creature_that_must_attack_is_orange() -> void:
	# Manual p.128: forced attackers are "highlighted, and you must add
	# them to the Combat window". Orange is the manual's word for MUST.
	var g := screen.game
	var lion := _summon_for_highlight("Savannah Lions", g.active_player)
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	screen.mode = DuelScreen.Mode.ATTACKERS
	assert_eq(screen._highlight_for(lion), MiniCard.Highlight.OPTIONAL)
	lion.must_attack_this_turn = true
	assert_eq(screen._highlight_for(lion), MiniCard.Highlight.MANDATORY)
	lion.must_attack_this_turn = false


func test_an_attacker_that_must_be_blocked_is_orange() -> void:
	# The defender's mandatory case: Lure's cur_must_be_blocked.
	var g := screen.game
	var attacker := _summon_for_highlight("Savannah Lions", g.active_player)
	g.combat.attackers[attacker.id] = true
	screen.mode = DuelScreen.Mode.BLOCKERS
	assert_eq(screen._highlight_for(attacker), MiniCard.Highlight.TARGET_LEGAL)
	attacker.cur_must_be_blocked = true
	assert_eq(screen._highlight_for(attacker), MiniCard.Highlight.MANDATORY)
	g.combat.attackers.clear()
	screen.mode = DuelScreen.Mode.NORMAL


func test_a_refused_target_is_stamped_cant_target_this() -> void:
	# `@CUECARD_SMALLCARD`: "Can't target this". Only the screen can answer
	# it — the refusal belongs to the prompt in progress.
	var lion := _summon_for_highlight("Savannah Lions", 0)
	var plains := _summon_for_highlight("Plains", 0)
	screen.mode = DuelScreen.Mode.TARGETING
	screen._pending_card = lion
	screen._pending_slots = [{"spec": TargetSpec.creature(),
		"min": 1, "max": 1, "divided": false}]
	screen._pending_groups = [[]]
	screen._pending_slot = 0
	assert_eq(screen._target_state_for(lion), -1, "a legal target is quiet")
	assert_eq(screen._target_state_for(plains), MiniCard.State.CANT_TARGET,
		"'target creature' refuses a land")
	screen._pending_groups = [[TargetRef.card(lion)]]
	assert_eq(screen._target_state_for(lion), MiniCard.State.TARGET_AGAIN,
		"already picked — 'Is a target, can't target again'")
	screen._clear_pending()


func test_the_small_card_is_handed_the_game_so_it_can_read_the_stack() -> void:
	var lion := _summon_for_highlight("Savannah Lions", 0)
	var widget := screen._make_widget(lion)
	add_child_autofree(widget)
	var card: MiniCard = widget if widget is MiniCard else widget.get_child(0)
	assert_eq(card.game, screen.game,
		"'Is a target' is a question about the stack, not the card")


# ------------------------------- the damage-prevention window (§6.8) --

func test_the_status_line_names_the_damage_prevention_step() -> void:
	# `Damage prevention` and `Use Regeneration Effects` are entries 0 and
	# 11 of `@PROMPT_CHECKFEPHASE` (UIStrings.txt:1026, :1037) — the same
	# table the phase names come from, so they fill the fast-effects blank
	# the same way.
	screen.game.priority_player = screen._human_seat()
	screen.game.awaiting_damage_prevention = true
	assert_eq(screen._status_message(), "Fast Effects?...Damage prevention")
	screen.game.awaiting_damage_prevention = false
	screen.game.awaiting_regeneration = true
	assert_eq(screen._status_message(),
		"Fast Effects?...Use Regeneration Effects")
	# The other seat's window is named, but not offered.
	screen.game.priority_player = screen.game.opponent_of(screen._human_seat())
	assert_eq(screen._status_message(), "Use Regeneration Effects")


func test_a_run_stops_at_the_damage_prevention_step() -> void:
	# A run that blew through the window would make a Circle of Protection
	# unusable: it is the only moment the card can be played at all.
	assert_eq(screen._advance_stop_reason(), "",
		"nothing is holding the duel yet")
	screen.game.awaiting_damage_prevention = true
	assert_eq(screen._advance_stop_reason(), "damage prevention is waiting")
	screen.game.awaiting_damage_prevention = false
	screen.game.awaiting_regeneration = true
	assert_eq(screen._advance_stop_reason(), "damage prevention is waiting")


func test_the_human_seat_asks_for_the_window_but_the_fork_decides() -> void:
	assert_true(HumanAgent.new().wants_damage_prevention_window(),
		"the player is the reason the step exists")
	assert_false(screen.game.rules.damage_prevention_window,
		"but a duel is modern until the Options screen says otherwise")


# ------------------------------------- the result and the owner (2026-09-02) --

func test_the_owner_hears_of_the_result_while_the_last_word_is_still_pending() -> void:
	# MatchScreen reads result_dialog_open() the moment duel_finished
	# lands, and waits on it before opening its own window. The End of
	# Duel window is built only AFTER the death countdown, so at that
	# moment there was nothing to wait on: the match's window opened over
	# a verdict that had not appeared, and its OK freed this screen while
	# _on_game_over still sat on the countdown timer.
	var seen: Array = []
	screen.duel_finished.connect(func(_winner: int) -> void:
		seen.append(screen.result_dialog_open()))
	screen._on_game_over(0)
	assert_eq(seen, [true], "pending from the moment the signal lands")
	assert_false(screen.result_dialog_open(),
		"headless has no window, and says so on the way out")


# ------------------------------------------- the tutor's pick (2026-09-02) --

func test_a_tutors_pick_survives_its_cast() -> void:
	# Demonic Tutor: the picker's answer is parked on the HumanAgent for
	# the SEARCH, which happens when the spell resolves — priority rounds
	# after the cast. _clear_pending dropped the parked name the moment
	# the cast went through, so the resolution asked all over again.
	var g: MtgGame = screen.game
	g.active_player = 0
	g.priority_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	var tutor := CardInstance.new(CardRegistry.get_card("Demonic Tutor"),
		g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[tutor.id] = tutor
	tutor.zone = Mtg.Zone.HAND
	g.players[0].hand.append(tutor)
	g.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	g.players[0].mana_pool.add(Mtg.ManaColor.C, 1)
	screen._click_hand_card(tutor)
	assert_not_null(screen._search_dialog, "the picker opened before the cast")
	var wanted := screen._search_list.get_item_text(0)
	screen._search_list.select(0)
	screen._on_search_confirmed()
	assert_eq(tutor.zone, Mtg.Zone.STACK, "the cast went through")
	assert_true(screen._humans[0].has_preselection(),
		"and the pick is still parked for the resolution")
	var in_hand := g.players[0].hand.size()
	var copies := _count_in_hand(g, 0, wanted)
	assert_eq(g.pass_priority(0), "")
	assert_eq(g.pass_priority(1), "", "both pass: the Tutor resolves")
	assert_null(g.awaiting_choice, "the resolution did not ask again")
	assert_eq(tutor.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), in_hand + 1, "one card fetched")
	assert_eq(_count_in_hand(g, 0, wanted), copies + 1,
		"the one the picker named")
	assert_false(screen._humans[0].has_preselection(), "and the pick is spent")


func _count_in_hand(g: MtgGame, pid: int, card_name: String) -> int:
	var n := 0
	for inst in g.players[pid].hand:
		if inst.data.card_name == card_name:
			n += 1
	return n


# ================================ what the table shows about a card (§5) ==
#
# Two defects out of `docs/card-states.md`'s catalogue of the small card,
# both of them the same shape: a fact the widget can draw that nothing was
# handing it.


func _hand_card_for_highlight(card_name: String, pid: int) -> CardInstance:
	# The hand-side twin of `_summon_for_highlight` above.
	var g := screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


## The [MiniCard] anywhere under [param node] that draws [param inst] — the
## board wraps a tapped card in a turn holder, an enchanted one in an aura
## wrap and a piled one in a holder `Button`, so the walk is recursive.
func _mini_for(node: Node, inst: CardInstance) -> MiniCard:
	if node is MiniCard and (node as MiniCard).instance == inst:
		return node
	for child in node.get_children():
		var found := _mini_for(child, inst)
		if found != null:
			return found
	return null


func test_a_face_down_permanent_is_drawn_face_down(): # §5.1
	# `MtgGame.put_from_hand_face_down` (Illusionary Mask) sets
	# `CardInstance.face_down`, and nothing carried it onto the widget — so
	# a masked creature was drawn with its NAME, its ART, its oracle
	# tooltip and its printed mana stripes on show: the whole of what the
	# card exists to hide.
	var lion := _summon_for_highlight("Savannah Lions", 0)
	screen.game.turn_face_down(lion)
	var widget := screen._make_widget(lion)
	add_child_autofree(widget)
	var card := _mini_for(widget, lion)
	assert_true(card.face_down, "the widget wears the engine's own flag")
	assert_false(card._name_label.visible, "no name")
	assert_false(card._art.visible, "no art")
	assert_false(card._stripes.visible, "no mana stripes")
	assert_false(card._pt_label.visible, "no live power and toughness")
	assert_eq(card.tooltip_text, "", "and no oracle text one hover away")


func test_a_face_down_permanent_is_face_down_to_EVERY_seat(): # §5.1
	# `engine/` has no per-seat visibility model — no `may_look_at`, and
	# `CardInstance.face_down` blanks the card's characteristics for
	# everybody (CR 708.2) — so the table takes the only reading that
	# cannot leak: a card back to its controller as well as to its
	# opponent. The day the engine can answer, CR 708.2 lets the
	# controller's own be relaxed.
	for pid in 2:
		var lion := _summon_for_highlight("Savannah Lions", pid)
		screen.game.turn_face_down(lion)
		var widget := screen._make_widget(lion)
		add_child_autofree(widget)
		assert_true(_mini_for(widget, lion).face_down,
			"seat %d's masked creature is a card back to the viewer" % pid)


func test_a_face_down_permanent_is_face_down_in_a_pile_too(): # §5.1
	# Lands and artifacts group into a `CardPile` the moment there are two
	# of them, and a pile builds its own faces.
	var one := _summon_for_highlight("Ornithopter", 0)
	var two := _summon_for_highlight("Ornithopter", 0)
	screen.game.turn_face_down(two)
	var pile := CardPile.new()
	add_child_autofree(pile)
	pile.populate([one, two], false, screen._on_card_clicked,
		screen._highlight_for)
	assert_false(_mini_for(pile, one).face_down, "the open one is open")
	assert_true(_mini_for(pile, two).face_down, "and the masked one is shut")


func test_the_castable_name_yellows_in_the_fan_as_well_as_the_pile(): # §5.5
	# `MiniCard.castable` was assigned in exactly ONE place in the whole
	# codebase — `card_pile.gd` — so a hand drawn as a FAN never yellowed a
	# card however castable it was. Which hand style the player picked in
	# Options silently changed what the game told them, and since the
	# double-click auto-cast landed the same yellow is also the promise
	# that double-clicking will work.
	var g := screen.game
	g.priority_player = 0
	_summon_for_highlight("Plains", 0)
	_summon_for_highlight("Plains", 0)
	var lion := _hand_card_for_highlight("Savannah Lions", 0)
	assert_eq(screen._highlight_for(lion), MiniCard.Highlight.CASTABLE,
		"two untapped Plains pay for it, so the game says you may cast it")
	var fan := FanHand.new()
	add_child_autofree(fan)
	screen._rebuild_hand(0, fan)
	var stack := StackHand.new()
	add_child_autofree(stack)
	screen._rebuild_hand(0, stack)
	var fanned := _mini_for(fan, lion)
	var piled := _mini_for(stack, lion)
	assert_true(piled.castable, "the stacked hand has always said so...")
	assert_true(fanned.castable, "...and the fan says it too now")
	assert_eq(fanned.name_color(), piled.name_color(),
		"one hand, two styles, the same yellow name")


func test_an_uncastable_card_stays_white_in_the_fan(): # §5.5
	var g := screen.game
	g.priority_player = 0
	var wurm := _hand_card_for_highlight("Craw Wurm", 0)
	assert_eq(screen._highlight_for(wurm), MiniCard.Highlight.NONE,
		"nothing on the table pays {4}{G}{G}")
	var fan := FanHand.new()
	add_child_autofree(fan)
	screen._rebuild_hand(0, fan)
	var card := _mini_for(fan, wurm)
	assert_false(card.castable, "so the fan leaves its name white")
	assert_eq(card.name_color(), Color(0.95, 0.95, 0.92))
