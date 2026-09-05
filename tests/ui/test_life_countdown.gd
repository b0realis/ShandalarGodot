extends GutTest
## THE DYING LIFE TOTAL FALLS — `docs/duel-todo.md` §2.7.
##
## s30 interpolates the losing player's numeral from its previous value to
## the final one over 900ms, holds it 500ms, and REFUSES TO LEAVE THE DUEL
## until the count has finished (`duel.go:613-682` and `1227-1229`). Ours
## jumped straight to the final number and put the End of Duel window over
## it in the same frame, so the blow that ended the duel was never shown.
##
## The count is deliberately restricted to a DEATH, as s30 restricts it:
## `startLossAnimationFromMessage` starts a counter only for a seat whose
## life is at or below zero. Ordinary damage still snaps — a duel in which
## every Lightning Bolt took a second to land would be unplayable.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func test_the_numeral_reads_the_engine_until_a_death_is_counted() -> void:
	assert_eq(screen._shown_life(0), screen.game.players[0].life)
	screen.game.players[0].life = 7
	assert_eq(screen._shown_life(0), 7, "ordinary damage snaps")


func test_the_refresh_remembers_the_life_it_painted() -> void:
	# The invariant the whole animation rests on: MtgGame deals the lethal
	# damage, emits game_ended, and only then emits state_changed — so at
	# game-over time this array is still one repaint behind and holds the
	# life the player had before the blow (s30's `prev.State`).
	screen._refresh()
	assert_eq(screen._last_life[0], screen.game.players[0].life)
	screen.game.players[0].life = -3
	assert_eq(screen._last_life[0], 20,
		"still the pre-damage number until the next repaint")


func test_the_count_walks_the_numeral_down_to_the_final_number() -> void:
	screen._refresh()                       # _last_life[0] == 20
	screen.game.players[0].life = -2
	screen._run_death_countdown()           # not awaited: sample it mid-fall
	await get_tree().process_frame
	assert_true(screen._life_countdown.has(0), "seat 0 is counting")
	assert_lte(screen._shown_life(0), 20)
	assert_gte(screen._shown_life(0), -2)
	# Let the tween and the hold finish.
	await get_tree().create_timer(
		DuelScreen.LOSS_COUNT_SECONDS + DuelScreen.LOSS_HOLD_SECONDS + 0.2).timeout
	assert_false(screen._life_countdown.has(0), "the count is over")
	assert_eq(screen._shown_life(0), -2, "and it landed on the real total")


func test_a_seat_that_did_not_die_of_damage_is_not_counted() -> void:
	# Decking (CR 104.3c) and poison end a duel without the life total
	# moving; s30 gates on `life <= 0` for the same reason.
	screen._refresh()
	assert_eq(screen.game.players[0].life, 20)
	await screen._run_death_countdown()
	assert_true(screen._life_countdown.is_empty(),
		"nothing fell, so nothing is counted")


func test_the_count_is_idempotent() -> void:
	# s30's `start` returns immediately when `a.started`; game_ended can
	# arrive while an earlier repaint is still in flight.
	screen._refresh()
	screen.game.players[0].life = -1
	screen._run_death_countdown()
	await get_tree().process_frame
	var mid: float = screen._life_countdown[0]
	screen._run_death_countdown()           # a second start must not restart
	assert_eq(screen._life_countdown[0], mid, "the fall was not rewound")
	await get_tree().create_timer(
		DuelScreen.LOSS_COUNT_SECONDS + DuelScreen.LOSS_HOLD_SECONDS + 0.2).timeout


func test_the_durations_are_s30s_own() -> void:
	assert_almost_eq(DuelScreen.LOSS_COUNT_SECONDS, 0.9, 0.001)
	assert_almost_eq(DuelScreen.LOSS_HOLD_SECONDS, 0.5, 0.001)
