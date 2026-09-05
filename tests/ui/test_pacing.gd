extends GutTest
## PER-EVENT DWELL — `docs/duel-todo.md` §2.6, s30 `duel.go:497-514`,
## `555-574` and the diff detectors at `:576-611`.
##
## s30 gives every game message a minimum time on screen: 100ms normally,
## 300ms when the active player is not you, 600ms when either life total
## moved or any permanent's marked damage did. We have no message queue,
## so the thing that waits is the AI's own pacing timer — and
## [member DuelConfig.pace] keeps meaning exactly what it always meant,
## the ordinary gap between AI actions, which is s30's MIDDLE tier.
##
## The invariant the whole item hangs on is the last test here: a headless
## run must not gain a single wait it did not have, because the test suite
## and the Deck Lab both live on that.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


# ------------------------------------------------------------ the tiers --

func test_the_three_tiers_are_s30s_own_ratios() -> void:
	# 100 / 300 / 600 milliseconds, expressed against the middle one.
	assert_almost_eq(DuelScreen.DWELL_QUIET, 1.0 / 3.0, 0.0001)
	assert_eq(DuelScreen.DWELL_ENEMY, 1.0)
	assert_eq(DuelScreen.DWELL_EVENT, 2.0)


func test_your_own_turn_runs_at_the_quiet_tier() -> void:
	# The AI is only passing priority inside your turn; s30 gives that
	# 100ms, not 300.
	assert_eq(DuelScreen.dwell_multiplier(true, false), DuelScreen.DWELL_QUIET)


func test_the_opponents_turn_runs_at_the_pace_the_config_names() -> void:
	assert_eq(DuelScreen.dwell_multiplier(false, false), DuelScreen.DWELL_ENEMY)


func test_life_or_damage_lingers_whichever_turn_it_is() -> void:
	# "600ms when either life changed, any permanent's marked damage
	# changed, or a new log line matches ' deals ' + ' damage to '."
	assert_eq(DuelScreen.dwell_multiplier(true, true), DuelScreen.DWELL_EVENT)
	assert_eq(DuelScreen.dwell_multiplier(false, true), DuelScreen.DWELL_EVENT)


# ------------------------------------------------------- what "stirred" is --

func test_a_quiet_board_does_not_stir() -> void:
	screen._reset_pacing()
	assert_false(screen._board_stirred(), "nothing moved")
	assert_false(screen._board_stirred(), "and still nothing")


func test_a_life_total_stirs_the_board_once() -> void:
	screen._reset_pacing()
	screen._board_stirred()
	screen.game.players[1].life -= 3
	assert_true(screen._board_stirred(), "the blow lingers")
	assert_false(screen._board_stirred(), "the next gap is ordinary again")


func test_marked_damage_stirs_the_board() -> void:
	var g: MtgGame = screen.game
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"),
		g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[bear.id] = bear
	g._put_on_battlefield(bear, 1)
	screen._reset_pacing()
	screen._board_stirred()
	bear.damage = 1
	assert_true(screen._board_stirred())


func test_two_creatures_moving_opposite_ways_still_stir() -> void:
	# The reason the record is per PERMANENT and not a total: a sum would
	# cancel a heal against a wound and report a quiet board.
	var g: MtgGame = screen.game
	var made: Array[CardInstance] = []
	for i in 2:
		var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"),
			g._next_instance_id, 1)
		g._next_instance_id += 1
		g._instances[bear.id] = bear
		g._put_on_battlefield(bear, 1)
		made.append(bear)
	made[0].damage = 1
	screen._reset_pacing()
	screen._board_stirred()
	made[0].damage = 0
	made[1].damage = 1
	assert_true(screen._board_stirred())


func test_a_permanent_leaving_is_not_a_damage_change() -> void:
	# s30's map only compares ids present in BOTH states; a dead creature
	# had its own moment when it died.
	var g: MtgGame = screen.game
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"),
		g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[bear.id] = bear
	g._put_on_battlefield(bear, 1)
	bear.damage = 1
	screen._reset_pacing()
	screen._board_stirred()
	g.players[1].battlefield.erase(bear)
	assert_false(screen._board_stirred())


# ---------------------------------------------- what pace still means --

func test_the_demo_still_means_08_seconds_between_actions() -> void:
	# `DuelConfig.demo_default` is 0.8, "human-followable". A demo has no
	# "you", so every turn is somebody else's and every ordinary gap is
	# the enemy tier — i.e. still exactly 0.8.
	var config := DuelConfig.demo_default()
	assert_eq(config.pace, 0.8)
	assert_eq(config.pace * DuelScreen.dwell_multiplier(false, false), 0.8)


func test_vs_ai_still_means_the_setting() -> void:
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	assert_eq(config.pace, Settings.ai_pace())
	assert_eq(config.pace * DuelScreen.dwell_multiplier(false, false),
		Settings.ai_pace())


# ----------------------------------------------- the headless invariant --

func test_the_dwell_adds_no_wait_of_its_own() -> void:
	# THE ITEM'S ONE HARD CONSTRAINT. Everything above is arithmetic over
	# state the screen already reads; the only timer in the duel screen is
	# still the AI's, and it is still created in exactly one place. If a
	# second `create_timer` ever appears in `_maybe_schedule_ai`'s
	# neighbourhood, this is what says so.
	var source := FileAccess.get_file_as_string(
		"res://game/duel/duel_screen.gd")
	var sched := source.substr(source.find("func _maybe_schedule_ai"))
	sched = sched.substr(0, sched.find("func _ai_step"))
	assert_eq(sched.count("create_timer"), 1,
		"one wait, the one that was always there")
	assert_false(sched.contains("await"), "and nothing that yields")
