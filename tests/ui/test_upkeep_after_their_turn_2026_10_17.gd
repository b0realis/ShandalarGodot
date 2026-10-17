extends GutTest
## YOUR UPKEEP, STRAIGHT AFTER THEIR TURN (2026-10-17). The owner's
## playtest on 0.50.31: *"why does my gameplay stop at my upkeep phase at
## the beginning even if I dont have the red dot on that phase? Please
## check and fix!"*
##
## WHAT IT WAS. The opponent's turn ends on an automatic pass: the
## computer passes in its end step, the human holds nothing for the
## window, and [method DuelScreen._auto_pass_priority] passes it for them.
## That pass carries the duel through the cleanup and the untap into the
## human's OWN upkeep — where the human, the active player, holds priority
## again. The redraw the pass makes runs under `_advancing`, so the
## [method DuelScreen._drive_advance] at its end returned on its first
## line; and nothing else was coming, because the next window was the
## human's and the computer had nothing to do. The duel sat in an
## unmarked upkeep waiting for a click — at the start of every turn whose
## end step the computer had closed. Reproduced in a real duel against the
## computer with the three default Stops (the human waited in the upkeep
## of turns 3, 5 and 7, every check of the automatic pass saying "pass").
##
## Every other window is followed by a move of the computer's, whose
## pacing timer redraws and resumes the drive; this one is the turn's door,
## two of the human's windows back to back.

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]   # seat 1 is the computer
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	# Let the new duel come to rest first — at the human's first Stop, the
	# computer's beats spent. A stale beat of the computer's landing
	# mid-test redraws the table, and that redraw is exactly the one the
	# real duel did NOT get.
	var quiet := 0
	for _i in 300:
		await get_tree().process_frame
		quiet = quiet + 1 if not screen._ai_pending else 0
		if quiet >= 3:
			break
	# The three Stops a fresh profile starts with: none of them on the upkeep.
	screen.stops.from_masks(PhaseStops.default_masks())


func after_each() -> void:
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


## The computer's end step with the computer holding priority, nothing on
## the table or in either hand: its pass, then the human's, ends the turn.
## Driven through the computer's own beat ([method DuelScreen._ai_step]),
## the way a real duel gets there — the engine's announcements from the
## computer's move have already asked for the end-of-frame redraw, which
## the automatic pass's own redraw then finds nothing left to draw for.
func _their_end_step() -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.END))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 1
	g._passes = 0
	g.stack.clear()
	for p in g.players:
		p.battlefield.clear()
		p.hand.clear()
		p.mana_pool.clear()
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	screen._ai_pending = false
	return g


func test_your_unmarked_upkeep_after_their_turn_passes_itself() -> void:
	var g := _their_end_step()
	screen._ai_step()
	assert_eq(g.active_player, 0, "their pass and your automatic one ended their turn")
	assert_false(screen.stops.is_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 1),
		"no Stop on your upkeep")
	screen._ai_pending = true    # whatever the computer does next waits
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(g.current_step() == Mtg.Step.UPKEEP and g.priority_player == 0,
		"your unmarked upkeep is not left waiting for a click")


func test_a_stop_on_your_upkeep_still_holds_it() -> void:
	var g := _their_end_step()
	screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 1, true)
	screen._ai_step()
	screen._ai_pending = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(g.current_step(), Mtg.Step.UPKEEP, "the marked upkeep holds")
	assert_eq(g.priority_player, 0, "and waits for you")
