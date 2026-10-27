extends GameTest
## Pass-and-play privacy: empty opening battlefields, explicit seat names,
## concealed hands, deliberate reveal/hide and private control handoffs.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.hotseat_default()
	screen.config.hotseat_privacy = true
	screen.config.rng_seed = 92000
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	g = screen.game


func test_hotseat_starts_with_empty_battlefields_and_concealed_hands() -> void:
	for pid in 2:
		assert_true(screen.game.players[pid].battlefield.is_empty(),
			"opening cards are in hand, never already on the battlefield")
		assert_true(screen.hidden_hands.has(pid), "neither opening hand starts exposed")
		assert_true(screen._hand_rows[1 - pid] is StackHand,
			"both players have a real hand stack, not cards spread over the board")
	assert_true(screen._card_preview._back.visible, "no private draw in the Showcase")


func test_hotseat_coin_badge_names_the_player_and_side() -> void:
	for pid in 2:
		var badge := CoinToss.result_badge(screen.config, pid, 0)
		add_child_autofree(badge)
		assert_eq((badge.get_child(badge.get_child_count() - 1) as Label).text,
			DuelConfig.seat_label(pid), "no ambiguous Your seat in hotseat")
		assert_eq(CoinToss.verdict_for(screen.config, pid, true),
			"%s won the coin toss." % DuelConfig.seat_label(pid))


func _stand(pid: int) -> void:
	screen.game.active_player = pid
	screen.game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	screen._refresh()


func test_match_keeps_private_hotseat_for_every_duel() -> void:
	var match_screen := MatchScreen.new()
	match_screen.config = screen.config
	# The match's state, as `_ready` makes it: a duel's config reads its
	# record number off it since the MPN history (0.50.44), and without one
	# this test stopped on a script error (found by the hunt of 2026-10-21).
	match_screen.state = MatchState.new()
	for i in 3:
		assert_true(match_screen._config_for_this_duel().private_hotseat())
	match_screen.free()


func test_hidden_hands_keep_named_phase_and_response_prompts(pid = use_parameters([0, 1])) -> void:
	_stand(pid)
	var phase := "%s — Main phase (before combat): cast spells, play land" % DuelConfig.seat_label(pid)
	assert_eq(screen._status_message(), phase)
	for i in 3:
		screen._refresh()
		assert_eq(screen._prompt_label.text, phase)
	_hand(pid).toggle_button.pressed.emit()
	_hand(pid).toggle_button.pressed.emit()
	assert_eq(screen._prompt_label.text, phase, "hiding does not replace the phase")
	_hand(pid).opponent_button.pressed.emit()
	var response := "%s — Fast Effects?...Main Phase" % DuelConfig.seat_label(1 - int(pid))
	assert_eq(screen._status_message(), response)
	assert_eq(screen._prompt_label.text, response)
	assert_false(screen._hotseat_revealed)


func test_concealed_blockers_keep_their_instruction_across_refreshes(pid = use_parameters([0, 1])) -> void:
	var defender := 1 - int(pid)
	var attacker := put_battlefield(pid, "Grizzly Bears")
	var blocker := put_battlefield(defender, "Grizzly Bears")
	_stand(pid)
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	screen._refresh()
	assert_eq(screen._prompt_label.text,
		"%s — Combat phase: Choose attackers." % DuelConfig.seat_label(pid))
	assert_ok(g.declare_attackers(pid, [attacker.id]))
	screen.mode = DuelScreen.Mode.NORMAL
	screen._refresh()
	screen._on_done()
	assert_true(g.awaiting_blockers)
	assert_false(screen._hotseat_revealed)
	var prompt := "%s — Combat phase: Choose blockers." % DuelConfig.seat_label(defender)
	for i in 3:
		screen._refresh()
		assert_eq(screen._prompt_label.text, prompt, "refresh cannot bury the blocker instruction")
		assert_eq(screen._status_message(), prompt)
	_hand(defender).toggle_button.pressed.emit()
	_hand(defender).toggle_button.pressed.emit()
	assert_eq(screen._prompt_label.text, prompt, "Show/Hide never replaces the instruction")
	# Battlefield choices are public: declaring blockers does not require
	# exposing a hand. Preserve the more specific second-click instruction.
	screen._on_card_clicked(blocker)
	screen._refresh()
	assert_eq(screen._prompt_label.text,
		"%s — Block which attacker?" % DuelConfig.seat_label(defender))
	screen._on_card_clicked(attacker)
	assert_eq(screen._prompt_label.text, prompt)
	screen._on_done()
	assert_false(g.awaiting_blockers)


func test_hidden_choice_asks_the_right_player_without_naming_private_cards() -> void:
	_stand(0)
	var choice := PlayerChoice.new(PlayerChoice.Kind.DISCARD, 1, "Choose a card.")
	choice.count = 1
	choice.source = "Private source"
	choice.candidates.assign(g.players[1].hand)
	g.awaiting_choice = choice
	screen._refresh()
	assert_eq(screen._prompt_label.text, "Player 2 (above) — Make your choice.")
	assert_null(screen._choice_overlay)
	assert_false(screen._hotseat_revealed)
	_hand(1).toggle_button.pressed.emit()
	assert_eq(screen._prompt_label.text, "Player 2 (above) — Process Private source")
	_hand(1).toggle_button.pressed.emit()
	assert_eq(screen._prompt_label.text, "Player 2 (above) — Make your choice.")


func test_hidden_damage_assignment_names_the_assigner(pid = use_parameters([0, 1])) -> void:
	var defender := 1 - int(pid)
	var giant := put_battlefield(pid, "Hill Giant")
	var first := put_battlefield(defender, "Grizzly Bears")
	var second := put_battlefield(defender, "Grizzly Bears")
	_stand(pid)
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	assert_ok(g.declare_attackers(pid, [giant.id]))
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS))
	assert_ok(g.declare_blockers(defender, {first.id: giant.id, second.id: giant.id}))
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_DAMAGE))
	screen._refresh()
	assert_true(g.awaiting_damage_assignment)
	assert_false(screen._hotseat_revealed)
	var prefix := DuelConfig.seat_label(pid) + " — Hill Giant: Assign damage to blockers, "
	assert_eq(screen._prompt_label.text, prefix + "3 points left")
	screen._refresh()
	assert_eq(screen._prompt_label.text, prefix + "3 points left")
	screen._on_card_clicked(first)
	assert_eq(screen._prompt_label.text, prefix + "2 points left")


func test_hidden_discard_keeps_the_instruction_and_count(pid = use_parameters([0, 1])) -> void:
	_stand(pid)
	while g.players[pid].hand.size() <= 7:
		give_hand(pid, "Forest")
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.CLEANUP))
	screen._refresh()
	assert_true(g.awaiting_discard)
	assert_false(screen._hotseat_revealed)
	var prompt := "%s — Select card to discard. (0 of %d)" % [DuelConfig.seat_label(pid), g.discard_count]
	screen._refresh()
	assert_eq(screen._prompt_label.text, prompt)
	_hand(pid).toggle_button.pressed.emit()
	assert_eq(screen._prompt_label.text, prompt)
	_hand(pid).toggle_button.pressed.emit()
	assert_eq(screen._prompt_label.text, prompt)


func test_hidden_refresh_preserves_a_refusal_until_it_expires() -> void:
	_stand(0)
	screen._report("Illegal target.")
	screen._refresh()
	assert_string_contains(screen._prompt_label.text, "Illegal target.")
	assert_eq(screen._prompt_label.get_theme_color("font_color"), DuelScreen.WARNING)
	screen._on_flash_expired()
	assert_eq(screen._prompt_label.text, screen._status_message())
	assert_false(screen._prompt_label.text.contains("looks away"))


func after_each() -> void:
	# Refresh removes old card widgets immediately and frees them at frame end.
	await get_tree().process_frame
	await get_tree().process_frame


func _hand(pid: int) -> HotseatHand:
	return screen._hand_rows[1 - pid] as HotseatHand


func _exile(pid: int, card_name: String, viewer: int) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		screen.game._next_instance_id, pid)
	screen.game._next_instance_id += 1
	screen.game._instances[inst.id] = inst
	inst.zone = Mtg.Zone.EXILE
	inst.face_down = true
	inst.exile_visible_to = viewer
	screen.game.players[pid].exile.append(inst)
	return inst


## A card exiled face down belongs to the one seat a rule let look at it
## (Gustha's Scepter). The pile read its viewer off `_human_seat()`, which
## is always seat 0 in a hotseat, so the OTHER player — sitting at the very
## same screen on their own turn — read the name off the pile's tooltip.
func test_a_face_down_exile_is_hidden_from_the_seat_it_is_not_shown_to() -> void:
	_exile(0, "Lightning Bolt", 0)
	_stand(1)
	assert_false(screen._exile_tooltip(0).contains("Lightning Bolt"),
		"the seat the card was not shown to reads only (face down)")
	assert_string_contains(screen._exile_tooltip(0), "(face down)")
	_stand(0)
	# ...once its player has pressed Show hand: until then nobody at the
	# screen is known to be that seat (the bug campaign c12, h4-6).
	assert_false(screen._exile_tooltip(0).contains("Lightning Bolt"),
		"not before Show hand")
	screen._toggle_hotseat_hand(0)
	assert_string_contains(screen._exile_tooltip(0), "Lightning Bolt",
		"the seat a rule did show it to still reads it")


## The graveyard view is opened by whichever seat is deciding, so the card
## it hands back is theirs. Reading the owner off `_human_seat()` meant the
## top seat could look at Ashen Ghoul's ability and never activate it.
func test_the_deciding_seat_can_open_a_graveyard_ability() -> void:
	var data := CardData.new("Probe Revenant", "{B}", Mtg.CardType.CREATURE) \
		.activated(ActivatedAbility.new("{B}", false, [],
			"return this card from your graveyard to the battlefield") \
			.from_graveyard())
	var inst := CardInstance.new(data, screen.game._next_instance_id, 1)
	screen.game._next_instance_id += 1
	screen.game._instances[inst.id] = inst
	inst.zone = Mtg.Zone.GRAVEYARD
	screen.game.players[1].graveyard.append(inst)
	_stand(1)
	screen._ability_menu.clear()
	screen._on_graveyard_card(inst)
	assert_gt(screen._ability_menu.item_count, 0,
		"the seat whose turn it is must reach its own graveyard ability")
	assert_eq(int(screen._ability_menu.get_meta("instance_id", -1)), inst.id)
	screen._ability_menu.hide()


func test_hotseat_show_hide_is_private_for_either_seat(pid = use_parameters([0, 1])) -> void:
	_stand(pid)
	var hand := _hand(pid)
	var other := _hand(1 - int(pid))
	assert_true(hand.active)
	assert_false(other.active)
	assert_true(hand.toggle_button.visible)
	assert_false(other.toggle_button.visible)
	assert_eq(hand.toggle_button.text, "Show hand")
	assert_eq(hand.toggle_button.focus_mode, Control.FOCUS_NONE,
		"clicking Show/Hide must not steal Enter or Space from the duel")
	assert_eq(hand._backs.get_child_count(), screen.game.players[pid].hand.size())
	assert_eq(hand._pile.get_child_count(), 0, "hidden hands construct no named card widgets")
	assert_eq(other._backs.get_child_count(), 0, "the inactive seat has only a count")
	for back in hand._backs.get_children():
		assert_true(back is Panel, "anonymous card-back artwork has no card identity")
		assert_eq(back.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(back.tooltip_text, "")
	var inst := screen.game.players[pid].hand[0]
	screen._on_card_clicked(inst)
	assert_eq(inst.zone, Mtg.Zone.HAND, "concealed cards cannot be played")
	hand.toggle_button.pressed.emit()
	assert_true(screen._may_see_hand(pid))
	assert_false(screen._may_see_hand(1 - int(pid)))
	assert_eq(hand.toggle_button.text, "Hide hand")
	assert_gt(hand._pile.get_child_count(), 0)
	var face := CardPile._face_in(hand._pile.get_child(0))
	hand._pile._on_card_hover(face.instance, face)
	assert_false(screen._card_preview._back.visible)
	hand.toggle_button.pressed.emit()
	assert_false(screen._may_see_hand(pid))
	assert_eq(hand.toggle_button.text, "Show hand")
	assert_true(screen._card_preview._back.visible, "hiding clears the enlarged private card")
	hand._pile._on_card_hover(inst, face)
	assert_true(screen._card_preview._back.visible, "a queued old hover cannot reveal it again")
	assert_gt(hand.toggle_button.position.x, hand._frame.size.x,
		"Show/Hide sits to the right of the card stack")


func test_hotseat_priority_handoff_conceals_both_hands_without_flipping_the_board() -> void:
	_stand(0)
	_hand(0).toggle_button.pressed.emit()
	_hand(0).opponent_button.pressed.emit()
	assert_eq(screen.game.priority_player, 1)
	assert_eq(screen._hotseat_seat, 1)
	assert_false(screen._hotseat_revealed)
	assert_eq(screen.hidden_hands, [0, 1] as Array[int])
	assert_true(_hand(1).active)
	assert_false(_hand(0).active)
	assert_eq(screen._phase_key()[0], PhaseStops.Half.YOURS,
		"a top-player response is still the bottom player's turn")
	_hand(1).toggle_button.pressed.emit()
	assert_true(screen._may_see_hand(1))
	assert_false(screen._may_see_hand(0))
	_stand(1)
	assert_false(screen._hotseat_revealed, "a new turn conceals even for the same viewer")
	assert_eq(screen._phase_key()[0], PhaseStops.Half.OPPONENTS)


func test_hotseat_names_include_the_physical_side_without_changing_saved_names() -> void:
	for pid in 2:
		var expected := "%s (%s)" % [screen.config.player_names[pid], "below" if pid == 0 else "above"]
		assert_eq(screen.game.players[pid].player_name, expected)
		assert_eq(screen._seat_name_labels[pid].text, expected)
		assert_eq(screen.config.seat_name(pid), expected)
		assert_eq(screen._seat_name_labels[pid].get_parent().get_node("SeatSide").text,
			"(below)" if pid == 0 else "(above)", "side remains visible even when a long name is trimmed")
	assert_eq(screen.config.player_names, ["White Wizard", "Black Wizard"] as Array[String])
	assert_eq(DuelConfig.demo_default().seat_name(0), "AI White")
	assert_eq(DuelConfig.hotseat_default().seat_name(0), "White Wizard")


func test_hotseat_hidden_draws_never_fill_the_showcase() -> void:
	_stand(0)
	screen.game.draw_cards(0, 1)
	assert_true(screen._card_preview._back.visible)
	_hand(0).toggle_button.pressed.emit()
	screen.game.draw_cards(1, 1)
	assert_true(screen._card_preview._back.visible, "the other player's draw stays private")
	screen.game.draw_cards(0, 1)
	assert_false(screen._card_preview._back.visible, "a deliberately revealed hand may preview its draw")
	_hand(0).toggle_button.pressed.emit()
	assert_true(screen._card_preview._back.visible)


func test_routine_pass_keeps_the_current_players_hand_open(pid = use_parameters([0, 1])) -> void:
	_stand(pid)
	_hand(pid).toggle_button.pressed.emit()
	screen._on_done()
	assert_eq(screen._hotseat_seat, pid, "routine priority must not hand the screen to the opponent")
	assert_true(screen._may_see_hand(pid), "the current player need not reveal again every phase")
	assert_eq(screen.game.current_step(), Mtg.Step.COMBAT_BEGIN,
		"Done includes the silent opponent's pass and advances one window")


func test_opponent_can_counter_before_a_spell_resolves(pid = use_parameters([0, 1])) -> void:
	_stand(pid)
	var other := 1 - int(pid)
	_hand(pid).toggle_button.pressed.emit()
	var bear := give_hand(pid, "Grizzly Bears")
	var counter := give_hand(other, "Counterspell")
	add_mana(pid, Mtg.ManaColor.G, 2)
	add_mana(other, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(pid, bear))
	assert_eq(g.stack.size(), 1)
	assert_eq(screen._hotseat_seat, pid, "casting keeps control until a response is requested")
	_hand(pid).opponent_button.pressed.emit()
	assert_eq(g.stack.size(), 1, "interjection grants priority BEFORE resolving the spell")
	assert_eq(g.priority_player, other)
	assert_false(screen._hotseat_revealed)
	_hand(other).toggle_button.pressed.emit()
	assert_ok(g.cast_spell(other, counter, [TargetRef.card(bear)]))
	assert_true(screen._may_see_hand(other), "respondent retains priority after casting")
	screen._on_pass_turn() # Enter is Done for the respondent, not a whole-turn run.
	assert_eq(g.priority_player, pid)
	assert_eq(screen._hotseat_seat, pid)
	assert_false(screen._hotseat_revealed)
	assert_eq(g.stack.size(), 2, "the turn player can respond to the counterspell")
	_hand(pid).toggle_button.pressed.emit()
	screen._on_done()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(counter.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.stack.is_empty())
	assert_eq(g.current_step(), Mtg.Step.MAIN1, "resolving the top never also skips a phase")
	assert_true(screen._may_see_hand(pid))


func test_declining_an_interjection_returns_control_and_ends_only_one_window() -> void:
	_stand(0)
	_hand(0).toggle_button.pressed.emit()
	_hand(0).opponent_button.pressed.emit()
	_hand(1).toggle_button.pressed.emit()
	_hand(1).opponent_button.pressed.emit()
	assert_eq(g.current_step(), Mtg.Step.COMBAT_BEGIN)
	assert_eq(screen._hotseat_seat, 0)
	assert_false(screen._hotseat_revealed)


func test_declining_a_response_does_not_pass_inside_a_draw_spells_resolution() -> void:
	_stand(0)
	_hand(0).toggle_button.pressed.emit()
	var recall := give_hand(0, "Ancestral Recall")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, recall, [TargetRef.player(0)]))
	_hand(0).opponent_button.pressed.emit()
	_hand(1).toggle_button.pressed.emit()
	var passes_during_resolution: Array = []
	g.state_changed.connect(func():
		if g.current_resolution_controller() >= 0:
			passes_during_resolution.append(g._passes))
	var before := g.players[0].hand.size()
	screen._on_done()
	assert_eq(g.players[0].hand.size(), before + 3)
	assert_false(passes_during_resolution.is_empty(), "draw emits state during resolution")
	for count in passes_during_resolution:
		assert_eq(count, 0, "the shortcut cannot pass priority inside a resolving effect")
	assert_eq(g.current_step(), Mtg.Step.MAIN1)
	assert_eq(g.priority_player, 0)
	assert_false(screen._hotseat_revealed)


func test_required_blocking_hands_over_but_does_not_choose_for_the_defender() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Grizzly Bears")
	_stand(0)
	_hand(0).toggle_button.pressed.emit()
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	screen._refresh()
	assert_true(_hand(0).opponent_button.disabled)
	_hand(0).opponent_button.pressed.emit()
	assert_eq(screen._hotseat_seat, 0, "cannot transfer a required attacker choice")
	assert_ok(g.declare_attackers(0, [bear.id]))
	screen.mode = DuelScreen.Mode.NORMAL
	screen._refresh()
	screen._on_done()
	assert_true(g.awaiting_blockers)
	assert_eq(screen._hotseat_seat, 1)
	assert_false(screen._hotseat_revealed)
	assert_true(_hand(1).opponent_button.disabled)
	_hand(1).toggle_button.pressed.emit()
	assert_ok(g.declare_blockers(1, {blocker.id: bear.id}))
	screen._refresh()
	assert_false(g.awaiting_blockers)
	assert_eq(screen._hotseat_seat, 0)
	assert_false(screen._hotseat_revealed)


func test_pending_cast_and_private_choice_cannot_be_interrupted() -> void:
	_stand(0)
	_hand(0).toggle_button.pressed.emit()
	var spell := give_hand(0, "Lightning Bolt")
	screen._on_card_clicked(spell)
	assert_not_null(screen._pending_card)
	assert_false(screen._hotseat_can_interject())
	_hand(0).opponent_button.pressed.emit()
	assert_eq(screen._hotseat_seat, 0)
	assert_eq(screen._pending_card, spell)
	screen._on_cancel()
	var choice := PlayerChoice.new(PlayerChoice.Kind.DISCARD, 1, "Choose a card.")
	choice.count = 1
	choice.candidates.assign(g.players[1].hand)
	g.awaiting_choice = choice
	screen._refresh()
	assert_eq(screen._hotseat_seat, 1)
	assert_false(screen._hotseat_revealed)
	assert_true(_hand(1).opponent_button.disabled)
	_hand(1).opponent_button.pressed.emit()
	assert_eq(g.awaiting_choice, choice, "the shortcut never answers a forced choice")
	assert_eq(screen._hotseat_seat, 1)


func test_new_turn_conceals_and_cancels_a_run_even_when_the_same_player_gets_it() -> void:
	_stand(0)
	_hand(0).toggle_button.pressed.emit()
	g.turn_number += 1 # extra turn: same seat, new private session
	screen._refresh()
	assert_false(screen._hotseat_revealed)
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE)
	assert_eq(screen._hotseat_seat, 0)


func test_a_standing_order_stops_privately_at_the_next_players_turn() -> void:
	_stand(0)
	while g.players[0].hand.size() > 7:
		g.put_into_graveyard(g.players[0].hand[0])
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.END))
	screen._refresh()
	_hand(0).toggle_button.pressed.emit()
	var turn := g.turn_number
	screen._order_next_phase()
	assert_eq(g.turn_number, turn + 1)
	assert_eq(g.active_player, 1)
	assert_eq(screen._hotseat_seat, 1)
	assert_false(screen._hotseat_revealed)
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE)
	await get_tree().process_frame
	assert_eq(g.turn_number, turn + 1, "a queued refresh cannot resume the old order")
	assert_false(screen._hotseat_revealed)


func test_opponent_interjection_allows_fifth_edition_regeneration() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var wisp := put_battlefield(1, "Will-o'-the-Wisp")
	_stand(0)
	g.rules.damage_prevention_window = true
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	screen._refresh()
	_hand(0).toggle_button.pressed.emit()
	screen._selected_attackers = [attacker.id]
	screen._on_done()
	screen._on_done()
	assert_true(g.awaiting_blockers)
	_hand(1).toggle_button.pressed.emit()
	screen._block_map = {wisp.id: [attacker.id]}
	screen._on_done()
	_hand(0).toggle_button.pressed.emit()
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_DAMAGE))
	screen._refresh()
	for i in 8:
		if g.awaiting_regeneration:
			break
		screen._on_done()
	assert_true(g.awaiting_regeneration)
	if not g.awaiting_regeneration:
		return
	assert_true(screen._hotseat_can_interject())
	_hand(0).opponent_button.pressed.emit()
	assert_eq(g.priority_player, 1)
	assert_false(screen._hotseat_revealed)
	_hand(1).toggle_button.pressed.emit()
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(1, wisp, 0))
	screen._on_done()
	assert_eq(screen._hotseat_seat, 0)
	_hand(0).toggle_button.pressed.emit()
	for i in 8:
		if not g.awaiting_regeneration:
			break
		screen._on_done()
	assert_false(g.awaiting_regeneration)
	assert_eq(wisp.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(wisp.tapped)
	assert_eq(wisp.damage, 0)


func test_hiding_a_private_choice_keeps_the_engine_question_unanswered() -> void:
	_stand(1)
	var choice := PlayerChoice.new(PlayerChoice.Kind.DISCARD, 1, "Choose a card.")
	choice.count = 1
	choice.candidates.assign(screen.game.players[1].hand)
	screen.game.awaiting_choice = choice
	screen._refresh()
	assert_null(screen._choice_overlay)
	_hand(1).toggle_button.pressed.emit()
	# Headless skips dialog opening; construct the exact same native overlay.
	screen._build_choice_overlay(choice)
	var overlay := screen._choice_overlay
	var hide_button := overlay.get_node("HidePrivateHand") as Button
	assert_eq(hide_button.global_position, _hand(1).toggle_button.global_position)
	hide_button.pressed.emit()
	assert_null(screen._choice_overlay)
	assert_false(overlay.visible, "no frame or closing fade discloses private options")
	assert_eq(screen.game.awaiting_choice, choice)
	assert_false(_hand(1).revealed)


func test_each_stack_drags_with_its_button_and_keeps_its_own_position(pid = use_parameters([0, 1])) -> void:
	_stand(pid)
	var hand := _hand(pid)
	var other := _hand(1 - int(pid))
	assert_false(hand.pinned)
	assert_eq(hand.get_parent(), screen, "hand floats, no container can reset its position")
	var before := hand.position
	var other_before := other.position
	var button_offset := hand.toggle_button.global_position - hand.global_position
	var opponent_offset := hand.opponent_button.global_position - hand.global_position
	assert_gt(hand.opponent_button.position.y, hand.toggle_button.position.y + hand.toggle_button.size.y)
	assert_eq(hand.opponent_button.focus_mode, Control.FOCUS_NONE)
	var saved := Settings.hand_stack_pos()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(StackHand.WIDTH / 2.0, StackHand.BAR_HEIGHT / 2.0)
	press.global_position = hand._title_bg.global_position + press.position
	hand._on_title_input(press)
	var move := InputEventMouseMotion.new()
	move.global_position = press.global_position + Vector2(-180, 32)
	hand._on_title_input(move)
	press.pressed = false
	press.global_position = move.global_position
	hand._on_title_input(press)
	assert_eq(hand.position, before + Vector2(-180, 32))
	assert_eq(hand.toggle_button.global_position - hand.global_position, button_offset)
	assert_eq(hand.opponent_button.global_position - hand.global_position, opponent_offset)
	assert_eq(other.position, other_before)
	var dragged := hand.position
	hand.toggle_button.pressed.emit()
	hand.toggle_button.pressed.emit()
	screen._refresh()
	await get_tree().process_frame
	assert_eq(hand.position, dragged, "reveal/hide and refresh never reset the dragged corner")
	assert_eq(Settings.hand_stack_pos(), saved, "neither seat overwrites the solo hand preference")
	hand.position = screen.get_viewport_rect().size
	hand._clamp_on_screen()
	assert_true(screen.get_viewport_rect().encloses(hand.toggle_button.get_global_rect()),
		"even an edge drag keeps the entire button on screen")
	assert_true(screen.get_viewport_rect().encloses(hand.opponent_button.get_global_rect()),
		"the second button stays on screen too")


func test_hotseat_opening_hand_reconceals_for_the_next_player() -> void:
	var window := OpeningWindow.new()
	add_child_autofree(window)
	window.show_hand(screen.game, 0, "white", true)
	var hand := window.hand_window() as HotseatHand
	assert_false(hand.revealed)
	hand.toggle_button.pressed.emit()
	assert_true(hand.revealed)
	window.show_hand(screen.game, 1, "black", true)
	assert_false(hand.revealed)
	assert_eq(hand.seat, 1)
	assert_eq(hand.toggle_button.text, "Show hand")
	hand.toggle_button.pressed.emit()
	assert_true(hand.revealed)
	hand.toggle_button.pressed.emit()
	assert_false(hand.revealed)
	assert_false(window._examine.visible)
	await get_tree().process_frame
	assert_true(Rect2(Vector2.ZERO, OpeningWindow.SIZE).encloses(window.hand_rect()),
		"the hand and its toggle fit within the opening window")


func _press(window: OpeningWindow, label: String) -> void:
	assert_true(window.press(label), "opening has a %s button" % label)
	await get_tree().process_frame
	await get_tree().process_frame


func test_private_opening_sequence_for_either_toss_winner(winner = use_parameters([0, 1])) -> void:
	var opening := OpeningHand.new()
	add_child_autofree(opening)
	# A separate dealt game, before either seat's mulligan has been settled.
	var dealt := MtgGame.new()
	dealt.setup(screen.config.decks[0], screen.config.decks[1], "A", "B", 20, 20, 92000)
	dealt.deal_opening_hands(7)
	opening.run(dealt, winner, func(_pid: int): return true, ["white", "black"], true)
	await get_tree().process_frame
	var window := opening.window()
	assert_string_contains(window.lead_text(), DuelConfig.seat_label(winner))
	var hand := window.hand_window() as HotseatHand
	assert_eq(hand.seat, winner)
	assert_false(hand.revealed)
	await _press(window, "Draw first")
	assert_string_contains(window.lead_text(), DuelConfig.seat_label(1 - int(winner)))
	hand.toggle_button.pressed.emit()
	assert_true(hand.revealed)
	await _press(window, "Take mulligan")
	assert_eq(dealt.players[winner].hand.size(), 6)
	assert_true(hand.revealed, "the same player may inspect their redraw")
	await _press(window, "Start the duel")
	assert_eq(hand.seat, 1 - int(winner))
	assert_false(hand.revealed, "the next player explicitly reveals their own cards")
	hand.toggle_button.pressed.emit()
	assert_true(hand.revealed)
	await _press(window, "Start the duel")
	assert_eq(dealt.turn_number, 1)
	assert_eq(dealt.active_player, 1 - int(winner))
	assert_false(hand.revealed, "the opening hand is concealed before its closing fade")
	await get_tree().create_timer(0.5).timeout
