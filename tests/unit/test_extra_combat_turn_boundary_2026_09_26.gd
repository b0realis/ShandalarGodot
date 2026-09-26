extends GameTest
## THE TURN AFTER AN EXTRA COMBAT (2026-09-26). Round 2 of the deck
## funnel printed `Out of bounds get index '19' (on base: 'Array[int]')`
## from `MtgGame.current_step` in every game where Goblin Fire's
## Relentless Assault resolved. The assault makes the turn twenty steps
## long; `_next_turn` put the standard thirteen back while `_step_index`
## still said 19, and the "== Turn N ==" line asked `current_step()`
## before `_enter_step(0)` corrected the index. The suite never saw it:
## the one test that crossed that boundary did so inside a search, where
## log lines are not written. Now `_next_turn` points the index at the
## new order's cleanup before it writes the line — the step a plain
## turn's line has always carried.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, false)


## The log meta of the line that opens [param turn].
func _turn_line_meta(turn: int) -> Dictionary:
	for i in g.log_lines.size():
		if String(g.log_lines[i]).begins_with("== Turn %d " % turn):
			return g.log_meta[i]
	return {}


## Seat 0 resolves a Relentless Assault (Portal Second Age, pack 6).
func _extra_combat() -> void:
	CardPacks.set_enabled("pack-6", true)
	var spell := give_hand(0, "Relentless Assault")
	for color in Mtg.WUBRG:
		add_mana(0, color, 3)
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()
	g.players[0].mana_pool.clear()


func test_a_plain_turn_line_carries_the_cleanup_step() -> void:
	advance_to_next_turn()
	assert_eq(g.turn_number, 2)
	assert_eq(g.active_player, 1)
	assert_eq(_turn_line_meta(2).get("step"), Mtg.Step.CLEANUP)


func test_the_turn_after_an_extra_combat_opens_without_an_engine_error() -> void:
	_extra_combat()
	assert_true(g.step_is_ahead(Mtg.Step.COMBAT_BEGIN), "the extra combat lies ahead")
	# Crossing the boundary OUTSIDE a search: an out-of-bounds read here
	# is an engine error, which the runner counts as a failure.
	advance_to_next_turn()
	assert_eq(g.turn_number, 2)
	assert_eq(g.active_player, 1)
	assert_eq(g.current_step(), Mtg.Step.MAIN1)
	assert_eq(_turn_line_meta(2).get("step"), Mtg.Step.CLEANUP,
		"the turn line is logged from the new order's cleanup")


func test_two_assaults_then_the_boundary_read_the_same() -> void:
	_extra_combat()
	_extra_combat()
	advance_to_next_turn()
	assert_eq(g.turn_number, 2)
	assert_eq(g.current_step(), Mtg.Step.MAIN1)
	assert_eq(_turn_line_meta(2).get("step"), Mtg.Step.CLEANUP)
	# And the turn after that is a plain one again.
	advance_to_next_turn()
	assert_eq(g.turn_number, 3)
	assert_eq(g.active_player, 0)
	assert_eq(_turn_line_meta(3).get("step"), Mtg.Step.CLEANUP)
