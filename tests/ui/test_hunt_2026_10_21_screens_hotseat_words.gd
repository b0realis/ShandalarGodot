extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: "Your" at a screen two
## players share.
##
## WAS: the End of Duel window's next draws said "Your next draw:" for
## every human seat, so a hotseat duel ended on "Your next draw:" twice,
## over two different cards; and at a private hotseat the library's count
## (`@MENU_LIBRARY`) said "Your library" for seat 0 whoever held the
## screen — Player 2 was told Player 1's library was theirs. NOW two
## humans at one screen are named (their seat at a private hotseat, as the
## verdict names it), and the private hotseat's library is named as its
## graveyard plate already was.

var screen: DuelScreen
var _saved: Variant = null


func before_each() -> void:
	_saved = Settings.get_value("SeeNextDrawsAtEndOfDuel", null) \
		if Settings.has_value("SeeNextDrawsAtEndOfDuel") else null
	DuelOptions.set_toggle("SeeNextDrawsAtEndOfDuel", true)


func after_each() -> void:
	if _saved == null:
		Settings.clear_value("SeeNextDrawsAtEndOfDuel")
	else:
		Settings.set_value("SeeNextDrawsAtEndOfDuel", _saved)
	await get_tree().process_frame


func _screen(config: DuelConfig) -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	config.rng_seed = 92000
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame


func _captions() -> Array[String]:
	var out: Array[String] = []
	for line in screen.next_draw_lines():
		out.append(line.get_slice("\n", 0))
	return out


func test_an_open_hotseats_next_draws_are_named() -> void:
	await _screen(DuelConfig.hotseat_default())
	assert_eq(_captions(), ["%s next draw:" % screen.game.players[0].player_name,
		"%s next draw:" % screen.game.players[1].player_name] as Array[String])


func test_a_private_hotseats_next_draws_are_named_by_seat() -> void:
	var config := DuelConfig.hotseat_default()
	config.hotseat_privacy = true
	await _screen(config)
	assert_eq(_captions(), ["%s next draw:" % DuelConfig.seat_label(0),
		"%s next draw:" % DuelConfig.seat_label(1)] as Array[String])


func test_against_the_computer_yours_is_still_yours() -> void:
	await _screen(DuelConfig.vs_ai_default(AiProfile.wizard()))
	var captions := _captions()
	assert_eq(captions[0], "Your next draw:")
	assert_eq(captions[1], "%s next draw:" % screen.game.players[1].player_name)


func test_a_private_hotseats_library_is_named_by_seat() -> void:
	var config := DuelConfig.hotseat_default()
	config.hotseat_privacy = true
	await _screen(config)
	var g: MtgGame = screen.game
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1
	screen._refresh()
	for pid in 2:
		screen._library_menu.set_meta("pid", pid)
		screen._on_library_menu_chosen(0)
		assert_false(screen._prompt_label.text.contains("Your library"), screen._prompt_label.text)
		assert_string_contains(screen._prompt_label.text, "%s library: %d cards"
			% [DuelConfig.seat_label(pid), g.players[pid].library.size()])


func test_against_the_computer_the_library_is_still_yours() -> void:
	await _screen(DuelConfig.vs_ai_default(AiProfile.wizard()))
	screen._library_menu.set_meta("pid", 0)
	screen._on_library_menu_chosen(0)
	assert_string_contains(screen._prompt_label.text, "Your library: ")
