extends GutTest
## Removal must remain visible before an unanswered opponent spell resolves.

class PassingSeat:
	extends RefCounted
	var acted := 0
	func act(game: MtgGame) -> String:
		acted += 1
		return game.pass_priority(1)

var screen: DuelScreen
var pilot: PassingSeat
var bear: CardInstance
var swords: CardInstance
var _saved_stops: Variant

func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	screen.config.pace = 1000.0 # keep setup's old timer out of the fixture
	add_child_autofree(screen)
	await get_tree().process_frame
	pilot = PassingSeat.new()
	screen._ais[1] = pilot
	screen._ai_pending = true
	screen.config.pace = 0.35
	screen.stops.clear_all()
	var game := screen.game
	game._probing = true
	game.active_player = 1
	game._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	game.priority_player = 1
	game.stack.clear()
	for player in game.players:
		player.hand.clear()
		player.battlefield.clear()
		player.mana_pool.clear()
	bear = _card("Grizzly Bears", 0)
	game._put_on_battlefield(bear, 0)
	swords = _card("Swords to Plowshares", 1)
	swords.zone = Mtg.Zone.HAND
	game.players[1].hand.append(swords)
	game.players[1].mana_pool.add(Mtg.ManaColor.W, 1)
	game.recalculate()
	game._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	screen._reset_pacing()

func after_each() -> void:
	if _saved_stops == null: Settings.clear_value(PhaseStops.SETTING_KEY)
	else: Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)

func _card(card_name: String, seat: int) -> CardInstance:
	var game := screen.game
	var card := CardInstance.new(CardRegistry.get_card(card_name), game._next_instance_id, seat)
	game._next_instance_id += 1
	game._instances[card.id] = card
	return card

func _cast_swords() -> void:
	assert_eq(screen.game.cast_spell(1, swords, [TargetRef.card(bear)]), "")
	screen._refresh()
	assert_false(screen._could_respond(0), "the reported case: the human has no response")

func test_unanswered_removal_is_visible_before_an_old_dwell_can_resolve_it() -> void:
	_cast_swords()
	# A previously armed short timer must not hurry the newly shown spell.
	screen._ai_step()
	assert_eq(pilot.acted, 0, "the opponent's next pass waits for the reading pause")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the target is still on the table to see")
	assert_eq(swords.zone, Mtg.Zone.STACK, "the spell remains on the chain")
	assert_gt(screen._arrows.link_count(), 0, "its target arrow stays visible")

func test_waiting_message_names_the_opponents_spell_and_target() -> void:
	_cast_swords()
	var message := screen._phase_status_message()
	assert_string_contains(message, "Swords to Plowshares")
	assert_string_contains(message, "Grizzly Bears")

func test_quiet_opponent_actions_keep_the_normal_pace() -> void:
	screen._ai_step()
	assert_eq(pilot.acted, 1, "an empty chain adds no reading pause")

func test_reading_pause_expires_and_swords_resolves_with_the_correct_life_gain() -> void:
	_cast_swords()
	assert_eq(screen._opponent_action_wait(1000), DuelScreen.OPPONENT_ACTION_SECONDS)
	assert_eq(screen._opponent_action_wait(1500), 1.5, "redraws do not restart the pause")
	assert_eq(screen._opponent_action_wait(3000), 0.0)
	var life := screen.game.players[0].life
	screen._pace_action_until = 0
	screen._ai_step()
	assert_eq(pilot.acted, 1)
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_eq(swords.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(screen.game.players[0].life, life + 2)

func test_removal_during_the_humans_turn_gets_the_same_reading_pause() -> void:
	screen.game.active_player = 0
	_cast_swords()
	screen._ai_step()
	assert_eq(pilot.acted, 0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_a_real_response_still_waits_for_the_human_after_the_reading_pause() -> void:
	_cast_swords()
	var growth := _card("Giant Growth", 0)
	growth.zone = Mtg.Zone.HAND
	screen.game.players[0].hand.append(growth)
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.G, 1)
	screen._opponent_action_wait()
	screen._pace_action_until = 0
	screen._ai_step()
	assert_eq(screen.game.priority_player, 0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(swords.zone, Mtg.Zone.STACK)
	assert_false(screen._auto_pass_applies())
	screen._on_pass()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "Done explicitly declines the response")

func test_zero_pace_tools_and_demo_play_keep_their_existing_speed() -> void:
	_cast_swords()
	screen.config.pace = 0.0
	assert_eq(screen._opponent_action_wait(1000), 0.0)
	screen.config.pace = 0.8
	screen._humans.clear()
	assert_eq(screen._opponent_action_wait(1000), 0.0)

func test_each_activation_of_the_same_card_has_its_own_pause() -> void:
	var first := StackItem.new()
	first.card = bear
	first.kind = Mtg.StackKind.ABILITY
	first.controller = 1
	screen.game.stack.append(first)
	assert_eq(screen._opponent_action_wait(1000), 2.0)
	assert_eq(screen._opponent_action_wait(3000), 0.0)
	var second := StackItem.new()
	second.card = bear
	second.kind = Mtg.StackKind.ABILITY
	second.controller = 1
	screen.game.stack.append(second)
	assert_eq(screen._opponent_action_wait(4000), 2.0)
	screen.game.stack.erase(second)
	assert_eq(screen._opponent_action_wait(4500), 1.5, "an older item returning to the top is not new")
	screen.game.stack.clear()
	assert_eq(screen._opponent_action_wait(4500), 0.0)
	assert_true(screen._pace_chain_ids.is_empty())

func test_private_target_names_are_not_revealed_in_the_notice() -> void:
	bear.face_down = true
	_cast_swords()
	var message := screen._phase_status_message()
	assert_string_contains(message, "a face-down creature")
	assert_false(message.contains("Grizzly Bears"))

func test_the_docked_showcase_explains_the_new_opponent_spell() -> void:
	screen._card_preview.docked = true
	_cast_swords()
	screen._opponent_action_wait()
	assert_eq(screen._card_preview._name_label.text, "Swords to Plowshares")

func test_an_own_spell_does_not_delay_the_computers_response() -> void:
	var own := StackItem.new()
	own.card = bear
	own.kind = Mtg.StackKind.SPELL
	own.controller = 0
	screen.game.stack.append(own)
	assert_eq(screen._opponent_action_wait(1000), 0.0)

func test_pause_menu_still_holds_the_duel_after_reading_time_has_elapsed() -> void:
	_cast_swords()
	screen._opponent_action_wait()
	screen._open_pause()
	screen._pace_action_until = 0
	screen._ai_step()
	assert_eq(pilot.acted, 0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	screen._close_pause()
	screen._ai_step()
	assert_eq(bear.zone, Mtg.Zone.EXILE)

func test_a_standing_done_order_cannot_skip_the_reading_pause() -> void:
	_cast_swords()
	screen._order_done_advance()
	screen._ai_step()
	assert_eq(pilot.acted, 0)
	assert_eq(swords.zone, Mtg.Zone.STACK)
	screen._pace_action_until = 0
	screen._ai_step()
	assert_eq(bear.zone, Mtg.Zone.EXILE)

func test_new_duel_clears_reading_state() -> void:
	_cast_swords()
	screen._opponent_action_wait()
	assert_false(screen._pace_chain_ids.is_empty())
	screen._reset_pacing()
	assert_true(screen._pace_chain_ids.is_empty())
	assert_eq(screen._pace_action_until, 0)
