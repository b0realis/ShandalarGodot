extends GutTest
## Demo-mode seat wiring: the lower battlefield, blue phase/combat strip
## and lower sidebar all belong to seat 0; the upper counterparts to seat 1.
## No human is present, so choosing a viewing seat must not grant control.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.demo_default()
	screen.config.rng_seed = 92000
	screen.config.player_names = ["Bottom pilot", "Top pilot"]
	screen.config.deck_names = ["Bottom deck", "Top deck"]
	screen.config.lives = [17, 26]
	screen.config.decks = [[], []]
	for i in 40:
		screen.config.decks[0].append("Forest")
	for i in 45:
		screen.config.decks[1].append("Swamp")
	screen.config.apply_deck_colors()
	# Freeze scheduling without removing either AI: their presence is what
	# exposed the reversed perspective. Tests drive the real engine directly.
	screen._ai_pending = true
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame


func _stand_in(pid: int, step: int) -> void:
	screen.game.active_player = pid
	screen.game._enter_step(Mtg.STEP_ORDER.find(step))
	screen._refresh()


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_demo_uses_the_bottom_view_without_creating_a_human() -> void:
	assert_eq(screen._human_seat(), 0, "demo view must stay on the bottom seat")
	assert_false(screen._is_human(0))
	assert_false(screen._is_human(1))
	assert_true(screen._humans.is_empty())
	assert_true(screen.hidden_hands.is_empty(), "spectators see both hand stacks throughout the duel")
	var land: CardInstance = screen.game.players[0].hand[0]
	screen._on_card_clicked(land)
	assert_eq(land.zone, Mtg.Zone.HAND, "viewing seat 0 does not let us play its cards")


func test_demo_gives_both_players_matching_hand_stacks() -> void:
	for pid in 2:
		assert_true(screen._hand_rows[1 - pid] is StackHand,
			"demo hands are stacks, never open cards spread across the battlefield")
	for pid in 2:
		_stand_in(pid, Mtg.Step.MAIN1)
		var hand := screen._hand_rows[1 - pid] as HotseatHand
		var other := screen._hand_rows[pid] as HotseatHand
		assert_true(hand.revealed)
		assert_eq(hand._pile.get_child_count(), screen.game.players[pid].hand.size())
		assert_true(other.revealed, "the other computer's hand stays open too")
		assert_eq(other._pile.get_child_count(), screen.game.players[1 - pid].hand.size())
		assert_eq(other._backs.get_child_count(), 0)
		assert_false(hand.toggle_button.visible, "a spectator never needs Show hand")
		assert_false(hand.opponent_button.visible, "a spectator cannot interject")
		assert_eq(screen.game.pass_priority(pid), "")
		assert_true(other.revealed, "responding never changes hand visibility")
		assert_true(hand.revealed, "passing priority must not fold the other stack")
		assert_eq(screen.game.active_player, pid)
		var corners := [hand.position, other.position]
		var heights := [hand.size.y, other.size.y]
		assert_eq(screen.game.pass_priority(1 - pid), "")
		assert_true(hand.revealed and other.revealed, "both remain open across phases")
		assert_eq([hand.position, other.position], corners)
		assert_eq([hand.size.y, other.size.y], heights, "no folding or jumping as priority changes")


func _assert_both_stacks_open() -> void:
	assert_true(screen.hidden_hands.is_empty())
	for pid in 2:
		var hand := screen._hand_rows[1 - pid] as HotseatHand
		assert_true(hand.revealed and hand._pile.visible)
		assert_eq(hand._pile.get_child_count(), screen.game.players[pid].hand.size())
		assert_eq(hand._backs.get_child_count(), 0)
		assert_false(hand.toggle_button.visible)
		assert_false(hand.opponent_button.visible)


func test_demo_both_hands_update_without_concealment_on_draw_play_and_new_turn() -> void:
	for pid in 2:
		_stand_in(pid, Mtg.Step.MAIN1)
		_assert_both_stacks_open()
		screen.game.draw_cards(1 - pid, 1)
		# An engine change is drawn at the end of the frame (one redraw per
		# frame since the 2026-10-12 campaign, r1-1).
		await get_tree().process_frame
		_assert_both_stacks_open()
		var card: CardInstance = screen.game.players[pid].hand[0]
		screen._on_card_clicked(card)
		assert_eq(card.zone, Mtg.Zone.HAND, "both open hands remain read-only for spectators")
		assert_eq(screen.game.play_land(pid, card), "")
		await get_tree().process_frame
		_assert_both_stacks_open()
		# A new turn must never conceal either hand, even though hotseat does.
		screen.game.turn_number += 1
		_stand_in(1 - pid, Mtg.Step.UPKEEP)
		_assert_both_stacks_open()


func test_demo_phase_strip_follows_the_same_side_as_the_battlefield(
		pid = use_parameters([0, 1])) -> void:
	_stand_in(pid, Mtg.Step.MAIN1)
	var half := PhaseStops.Half.YOURS if pid == 0 else PhaseStops.Half.OPPONENTS
	assert_eq(screen._phase_key(), [half, PhaseStops.Bar.PHASE, 3],
		"phase controls use the battlefield's seat, not the opposite one")
	if screen._phase_bar != null:
		assert_eq(screen._phase_bar.state(), [half, 3],
			"seat 0 lights the lower blue strip; seat 1 the upper gold strip")
		assert_eq(screen._phase_bar.opponent_name, "Top pilot")
	# Passing priority must not move the turn highlight to the other seat.
	assert_eq(screen.game.pass_priority(pid), "")
	assert_eq(screen.game.active_player, pid)
	assert_eq(screen._phase_key()[0], half)


func test_demo_combat_stays_on_the_attackers_physical_side(
		pid = use_parameters([0, 1])) -> void:
	var tokens: Array[CardInstance] = []
	for seat in 2:
		tokens.append(screen.game.create_token(seat,
			CardRegistry.get_card("Grizzly Bears"))[0])
	_stand_in(pid, Mtg.Step.UNTAP) # a real untap clears the attacker's sickness
	_stand_in(pid, Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(screen.game.declare_attackers(pid, [tokens[pid].id]), "")
	for i in 8:
		if screen.game.awaiting_blockers:
			break
		assert_eq(screen.game.pass_priority(screen.game.priority_player), "")
	assert_true(screen.game.awaiting_blockers)
	_assert_both_stacks_open()
	var defender := 1 - int(pid)
	assert_eq(screen.game.declare_blockers(defender,
		{tokens[defender].id: tokens[pid].id}), "")
	screen._refresh()
	_assert_both_stacks_open()
	assert_not_null(screen._combat_window)
	assert_eq(screen._combat_window.lane_ids(), [[tokens[1].id], [tokens[0].id]],
		"combat lanes must match the top and bottom battlefields")
	if screen._combat_bar != null:
		assert_true(screen._combat_bar.visible)
		assert_eq(screen._combat_bar._is_player_seat, pid == 0,
			"bottom attacks in blue; top attacks in gold")
		assert_eq(screen._combat_bar._half,
			PhaseStops.Half.YOURS if pid == 0 else PhaseStops.Half.OPPONENTS)


func test_demo_sidebar_and_zone_controls_stay_with_their_own_seat() -> void:
	for pid in 2:
		var player := screen.game.players[pid]
		screen.game.put_from_hand_into_play(player.hand[0], pid)
		screen.game.adjust_life(pid, -pid - 1)
		screen.game.draw_cards(pid, pid + 1)
		for i in pid + 1:
			screen.game.put_into_graveyard(player.hand[0])
			screen.game.exile_top_of_library(pid)
		player.mana_pool.add(Mtg.ManaColor.C, pid + 2)
		screen._refresh()
		assert_eq(screen._seat_name_labels[pid].text, screen.config.player_names[pid])
		assert_eq(screen._deck_name_labels[pid].text, screen.config.deck_names[pid])
		assert_eq(screen._seat_portraits[pid].texture, DuelIntro.portrait_for(screen.config, pid))
		assert_eq(screen._life_buttons[pid].text, str(player.life))
		assert_eq(screen._lib_labels[pid].text, str(player.library.size()))
		assert_eq(screen._grave_labels[pid].text, str(player.graveyard.size()))
		assert_eq(screen._mana_labels[pid][Mtg.ManaColor.C].text, str(pid + 2))
		if screen._exile_labels.size() == 2:
			assert_eq(screen._exile_labels[pid].text, str(player.exile.size()))
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_RIGHT
		screen._deck_stacks[pid].gui_input.emit(click)
		assert_eq(screen._library_menu.get_meta("pid"), pid,
			"right-clicking a deck addresses its own library")
		screen._library_menu.hide()
		screen._life_buttons[pid].gui_input.emit(click)
		assert_eq(screen._life_menu_pid, pid, "the face menu belongs to the clicked seat")
		screen._life_menu.hide()
	await get_tree().process_frame
	for pair in [[screen._half_rows[0], screen._half_rows[1]],
			[screen._life_buttons[0], screen._life_buttons[1]],
			[screen._seat_portraits[0], screen._seat_portraits[1]],
			[screen._deck_stacks[0], screen._deck_stacks[1]]]:
		assert_gt(pair[0].global_position.y, pair[1].global_position.y,
			"seat 0's field and controls stay below seat 1's")
