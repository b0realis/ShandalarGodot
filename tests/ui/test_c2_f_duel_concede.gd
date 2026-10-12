extends GutTest
## CONCEDE GIVES UP THE DUEL OF THE PLAYER WHO ASKED (campaign 2026-10-12,
## findings b6-8 and r2-6). At a PRIVATE hotseat the territory menu opens
## on either half, and its Concede used to concede the half that was
## right-clicked: Player 2, deciding at the screen, right-clicked the lower
## half (Player 1's), answered "Yes, I'm sure" — and Player 1 lost. The
## Pause window's Concede was already the seat at the screen's; now the
## territory menu's is too. At an open hotseat (both hands shown) the
## clicked half still decides, as it always has. And a second press of the
## question's Cancel in the same frame is harmless.

var screen: DuelScreen


func _private_hotseat() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.hotseat_default()
	screen.config.hotseat_privacy = true
	screen.config.rng_seed = 92000
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame


## Player [param seat] to decide in its own first main phase.
func _seat_to_decide(seat: int) -> void:
	var g: MtgGame = screen.game
	g.active_player = seat
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = seat
	screen._refresh()


func _concede_from_half(half: int) -> void:
	screen._open_territory_menu(half, Vector2(200, 600))
	screen._territory_menu.hide()
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 8)   # Concede
	assert_not_null(screen._concede_dialog, "control: Yes, I'm sure? is asked")
	screen._confirm_concede()


func test_player_two_conceding_from_player_ones_half_concedes_player_two() -> void:
	await _private_hotseat()
	_seat_to_decide(1)
	assert_true(screen.config.private_hotseat(), "control: a private hotseat")
	assert_eq(screen._viewing_seat(), 1, "control: the screen serves Player 2")
	_concede_from_half(0)
	var g: MtgGame = screen.game
	assert_true(g.game_over, "the duel ended")
	assert_eq(g.winner, 0, "Player 2 conceded, so Player 1 won (winner: Player %d)" % (g.winner + 1))


func test_player_one_conceding_from_player_twos_half_concedes_player_one() -> void:
	await _private_hotseat()
	_seat_to_decide(0)
	assert_eq(screen._viewing_seat(), 0, "control: the screen serves Player 1")
	_concede_from_half(1)
	var g: MtgGame = screen.game
	assert_true(g.game_over, "the duel ended")
	assert_eq(g.winner, 1, "Player 1 conceded, so Player 2 won (winner: Player %d)" % (g.winner + 1))


## The private hotseat keeps the clicked half for Arrange: "my cards" is
## still the half that was right-clicked.
func test_arrange_still_belongs_to_the_clicked_half() -> void:
	await _private_hotseat()
	_seat_to_decide(1)
	screen._open_territory_menu(0, Vector2(200, 600))
	screen._territory_menu.hide()
	assert_eq(screen._menu_seat(), 0, "the menu speaks for the half it was opened on")


## An OPEN hotseat (both hands on the table) is unchanged: the half that
## was right-clicked concedes, which is how two players at one screen
## say which of them is giving up.
func test_an_open_hotseat_concedes_the_clicked_half() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.hotseat_default()
	screen.config.hotseat_privacy = false
	screen.config.rng_seed = 92000
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_false(screen.config.private_hotseat(), "control: an open hotseat")
	_seat_to_decide(0)
	_concede_from_half(1)
	var g: MtgGame = screen.game
	assert_true(g.game_over)
	assert_eq(g.winner, 0, "the lower half's player won: the upper half conceded")


func test_a_doubled_cancel_on_the_concede_question_is_harmless() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var g: MtgGame = screen.game
	screen._ask_to_concede()
	var dialog: Node = screen._concede_dialog
	assert_not_null(dialog)
	var cancel: Button = null
	for b in dialog.find_children("*", "Button", true, false):
		if (b as Button).text == "Cancel":
			cancel = b
	assert_not_null(cancel, "control: the question has a Cancel")
	cancel.pressed.emit()
	assert_true(is_instance_valid(cancel) and cancel.is_inside_tree(),
		"control: the button is still pressable in the same frame")
	cancel.pressed.emit()
	await get_tree().process_frame
	assert_null(screen._concede_dialog, "the question is gone")
	assert_false(g.game_over, "nothing was conceded")
