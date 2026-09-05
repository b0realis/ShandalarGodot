extends GutTest
## THE PAUSE WINDOW — `Q` / `Esc` during a duel ([DuelPause], and the block
## comment in `game/duel/duel_screen.gd`).
##
## The owner's playtest, 2026-09-03: *"When a player types Q or ESC keys
## during a duel, a menu should pop up with buttons: concede the duel (you
## lost), exit duel (return to duel config), return to main menu, exit
## game"*; then *"And another button: return to game. Pressing Q or ESC
## again would close the menu. The menu should be named Pause on top!"*;
## and *"This Q or ESC button menu should reuse the brown portraits window
## with buttons on the bottom."*
##
## THE TWO THINGS MOST LIKELY TO ROT are pinned hardest here: the Esc
## PRECEDENCE (Esc was given a job on 2026-09-02 and must keep it — see
## `tests/ui/test_cancel_contract.gd`), and the promise the word "Pause"
## makes about time. A player who opens this, walks away, and comes back to
## find the AI has taken three turns would have been given the opposite of
## what the word means.

var screen: DuelScreen


func before_each() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]   # seat 1 is the opponent
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame


func _send_key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	screen._unhandled_key_input(ev)


func _give(card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[0].hand.append(inst)
	return inst


# ================================================== the window itself --

func test_it_is_titled_pause_and_carries_the_owners_five_entries() -> void:
	assert_eq(DuelPause.TITLE, "Pause", "the owner's own word, on top")
	assert_eq(DuelPause.ENTRIES, [
		"Return to game",
		"Concede duel",
		"Exit duel",
		"Return to main menu",
		"Exit game",
	] as Array[String])
	assert_eq(DuelPause.ENTRIES.size(), DuelPause.BUTTON_RECTS.size(),
		"one rect per entry")
	assert_eq(int(DuelPause.Action.RESUME), 0,
		"the safe one is first, so the reflex press is the harmless one")


func test_every_button_fits_inside_the_marble() -> void:
	# The board is the ART's 500x400 and the buttons are laid out in its
	# own coordinates — a rect that runs off it would be a button the
	# player cannot press.
	for rect in DuelPause.BUTTON_RECTS:
		assert_true(rect.position.x >= 0 and rect.end.x <= VersusPanel.SPLASH.x,
			"%s is inside the board horizontally" % str(rect))
		assert_true(rect.end.y <= VersusPanel.SPLASH.y,
			"%s ends above the bottom edge" % str(rect))
		# ...and below the seat names, which run to the wells' end + 34.
		assert_true(rect.position.y >= VersusPanel.WELLS[0].end.y + 34,
			"%s clears the seat lettering" % str(rect))


func test_it_wears_the_intro_marble_and_not_a_second_copy() -> void:
	# The owner asked for "the brown portraits window" — the same one, not
	# a clone of its layout. One base class, one set of measurements.
	var pause := DuelPause.new()
	var intro := DuelIntro.new()
	assert_true(pause is VersusPanel)
	assert_true(intro is VersusPanel)
	pause.free()
	intro.free()
	assert_eq(VersusPanel.SPLASH, Vector2(500, 400))
	assert_eq(VersusPanel.WELLS.size(), 2)


func test_it_carries_no_timer_of_its_own() -> void:
	# [DuelIntro] auto-advances after five seconds. A window called Pause
	# must not: one that dismisses itself while you are reading it is worse
	# than no window.
	var menu := DuelPause.new()
	add_child_autofree(menu)
	menu.build(screen.config)
	assert_false(menu.is_processing(),
		"nothing is counting down behind the Pause window")
	assert_false(menu.has_method("seconds_left"),
		"and it has no clock to read")


func test_the_buttons_are_really_built() -> void:
	var menu := DuelPause.new()
	add_child_autofree(menu)
	menu.build(screen.config)
	var seen: Array[String] = []
	for node in menu.find_children("*", "Button", true, false):
		seen.append((node as Button).text)
	for entry in DuelPause.ENTRIES:
		assert_true(seen.has(entry), "the window really shows %s" % entry)


# ========================================================== the two keys --

func test_q_opens_it() -> void:
	assert_false(screen.is_paused())
	_send_key(KEY_Q)
	assert_true(screen.is_paused(), "Q opens the Pause window")
	assert_not_null(screen._pause_menu)


func test_q_closes_it_again() -> void:
	_send_key(KEY_Q)
	assert_true(screen.is_paused())
	_send_key(KEY_Q)
	assert_false(screen.is_paused(), "the same key toggles it shut")


func test_escape_opens_it_when_there_is_nothing_to_cancel() -> void:
	assert_false(screen._can_cancel(), "nothing pending")
	_send_key(KEY_ESCAPE)
	assert_true(screen.is_paused())


func test_escape_closes_the_open_window() -> void:
	_send_key(KEY_Q)
	assert_true(screen.is_paused())
	_send_key(KEY_ESCAPE)
	assert_false(screen.is_paused(), "Esc closes what Q opened")


func test_escape_cancels_first_and_never_opens_the_window() -> void:
	# THE PRECEDENCE, and the reason it matters: a player mid-cast pressing
	# Esc wants their cast back, not a quit dialog. The 2026-09-02 cancel
	# ladder (`tests/ui/test_cancel_contract.gd`) is unchanged by the Pause
	# window existing.
	if CardRegistry.get_card("Fireball") == null:
		pass_test("Fireball not in the pool")
		return
	screen._click_hand_card(_give("Fireball"))
	assert_not_null(screen._x_dialog, "the X question is up")
	assert_true(screen._can_cancel(), "so there is something to cancel")
	_send_key(KEY_ESCAPE)
	assert_false(screen.is_paused(),
		"Esc spent itself on the cast, not on the menu")
	assert_null(screen._x_dialog, "and the question came down")
	# ...and only NOW does the same key reach the window.
	_send_key(KEY_ESCAPE)
	assert_true(screen.is_paused())


func test_q_opens_it_even_mid_cast_because_q_has_no_1997_duty() -> void:
	if CardRegistry.get_card("Fireball") == null:
		pass_test("Fireball not in the pool")
		return
	screen._click_hand_card(_give("Fireball"))
	_send_key(KEY_Q)
	assert_true(screen.is_paused(), "Q is unconditional")


func test_no_key_reaches_the_table_while_it_is_up() -> void:
	_send_key(KEY_Q)
	var g: MtgGame = screen.game
	var turn := g.turn_number
	var step := g.current_step()
	for code in [KEY_ENTER, KEY_SPACE, KEY_H, KEY_M]:
		_send_key(code)
	assert_true(screen.is_paused(), "still open")
	assert_eq(g.turn_number, turn, "Return did not arm a Done order")
	assert_eq(g.current_step(), step, "and Space passed nothing")


# ============================================ pause means the duel STOPS --

func test_the_table_is_deaf_and_the_auto_pass_is_off() -> void:
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	g.priority_player = 0
	screen.mode = DuelScreen.Mode.NORMAL
	screen.stops.clear_all()
	assert_true(screen._auto_pass_applies(),
		"unstopped and quiet: it would go by itself")
	_send_key(KEY_Q)
	assert_true(screen._modal_open(),
		"the window is modal against the table")
	assert_false(screen._auto_pass_applies(),
		"...so an unstopped phase does NOT sail past while you read it")


func test_the_ai_clock_stops_and_starts_again() -> void:
	var g: MtgGame = screen.game
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1
	screen.mode = DuelScreen.Mode.NORMAL
	_send_key(KEY_Q)
	screen._ai_pending = false     # forget whatever the setup armed
	screen._maybe_schedule_ai()
	assert_false(screen._ai_pending, "no dwell is armed while paused")
	# ...and a dwell armed BEFORE the window opened is dropped rather than
	# played out: this is the timer callback firing under the window.
	var turn := g.turn_number
	var step := g.current_step()
	var life: Array[int] = [g.players[0].life, g.players[1].life]
	for _i in 30:
		screen._ai_step()
		screen._refresh()
	assert_eq(g.turn_number, turn, "the opponent took no turn")
	assert_eq(g.current_step(), step, "the duel did not move one step")
	assert_eq([g.players[0].life, g.players[1].life], life, "nor one point")
	# Closing it starts the clock again.
	_send_key(KEY_Q)
	assert_false(screen.is_paused())
	screen._ai_pending = false
	screen._maybe_schedule_ai()
	assert_true(screen._ai_pending, "the AI's dwell is armed again")


# ================================================== what the entries do --

func test_return_to_game_just_closes_it() -> void:
	_send_key(KEY_Q)
	screen._pause_menu.press("Return to game")
	assert_false(screen.is_paused())


func test_concede_asks_before_it_takes_the_duel() -> void:
	# Losing a duel to a mis-key is the worst thing this window can do, so
	# it opens the ORIGINAL's own confirmation — `@MENU_TERRITORY` entry 25
	# — rather than conceding outright, and rather than a second copy of
	# the question the territory menu already asks.
	var g: MtgGame = screen.game
	_send_key(KEY_Q)
	screen._pause_menu.press("Concede duel")
	assert_false(g.game_over, "nothing has been given up yet")
	assert_not_null(screen._concede_dialog, "the confirmation is up")
	assert_eq(TerritoryMenu.CONCEDE_CONFIRM, "Yes, I'm sure")
	screen._confirm_concede()
	assert_true(g.game_over, "and now it is a loss")
	assert_eq(g.winner, 1, "recorded as the HUMAN's loss")


func test_the_leaving_entries_are_the_screens_to_act_on() -> void:
	# The window itself only reports the choice — which is what lets a test
	# read `Exit game` without killing the process.
	var menu := DuelPause.new()
	add_child_autofree(menu)
	menu.build(screen.config)
	var seen: Array[int] = []
	menu.chosen.connect(func(action: int) -> void: seen.append(action))
	assert_true(menu.press("Exit duel"))
	assert_true(menu.press("Return to main menu"))
	assert_true(menu.press("Exit game"))
	assert_eq(seen, [
		int(DuelPause.Action.EXIT_DUEL),
		int(DuelPause.Action.MAIN_MENU),
		int(DuelPause.Action.QUIT),
	] as Array[int])
	assert_false(menu.press("Nothing of the sort"),
		"a label the window does not have is a miss, not a silent no-op")
