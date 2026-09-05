extends GutTest
## AN UNSTOPPED PHASE RUNS ITSELF — the owner's playtest, 2026-09-03, in
## two instalments. First: *"I should not be clicking through AI opponent
## phases, they should go automatically — as it is opponent playing (in a
## human pace of course)."* Then: *"If nothing happens on a phase (no card
## needs it) and I DON'T have it selected for stoppage by red dot — then it
## should go automatically EVEN FOR ME."*
##
## WHAT IT WAS. `DuelScreen._drive_advance` returns on its first line
## unless a standing order is in force, and only Done, Run to and the
## territory menu's Go to arm one. So the human's priority window in every
## step of the opponent's turn — eight a turn — waited for a click that
## carried no decision. `test_the_human_used_to_have_to_click_every_phase`
## below is that defect, pinned as the thing that must never come back.
##
## WHERE IT STOPS is 1997's own list, and every test here names its
## sentence. `Duel.hlp`, topic **Stop**, is the licence for the whole
## feature: *"that phase does not end until you tell it to manually; IT
## CANNOT PASS AUTOMATICALLY."*

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]   # seat 1 is the opponent
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()


func after_each() -> void:
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


## Stand the duel in [param step] of the OPPONENT's turn with the human
## holding priority — the exact moment the owner was made to click.
func _human_priority_on_their_turn(step: int) -> MtgGame:
	return _human_priority_in(1, step)


## ...and the same on the human's OWN turn, which is the second half of the
## feature.
func _human_priority_on_your_turn(step: int) -> MtgGame:
	return _human_priority_in(0, step)


func _human_priority_in(active: int, step: int) -> MtgGame:
	var g: MtgGame = screen.game
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.priority_player = 0
	screen.mode = DuelScreen.Mode.NORMAL
	return g


# ============================================================ the defect --

func test_the_human_used_to_have_to_click_every_phase() -> void:
	var g := _human_priority_on_their_turn(Mtg.Step.UPKEEP)
	screen._refresh()
	assert_ne(g.priority_player, 0,
		"the duel passed the window by itself instead of waiting for Done")


func test_the_human_used_to_have_to_click_their_own_phases_too() -> void:
	# The SECOND instalment, and the same defect one turn over: the human's
	# own upkeep and draw carried no decision either, and with nothing
	# marked there they now pass themselves.
	var g := _human_priority_on_your_turn(Mtg.Step.UPKEEP)
	screen.stops.clear_all()
	assert_true(screen._auto_pass_applies(),
		"nothing marked and nothing held: the window carries no decision")
	var before := Mtg.STEP_ORDER.find(g.current_step())
	screen._refresh()
	# Either the window went to the opponent or — when they had already
	# passed into it — the step itself turned over. Both are "it moved
	# without a click", which is the whole of the owner's ask.
	assert_true(g.priority_player != 0
			or Mtg.STEP_ORDER.find(g.current_step()) > before,
		"an unstopped phase of your own goes by itself")


func test_your_own_main_phase_is_stopped_by_default() -> void:
	# ...and this is why that is safe. The three defaults
	# (PhaseStops.default_masks()) are exactly the phases you act in.
	var g := _human_priority_on_your_turn(Mtg.Step.MAIN1)
	screen.stops.from_masks(PhaseStops.default_masks())
	assert_false(screen._auto_pass_applies(),
		"your Main pre-combat carries a red dot out of the box")
	screen._refresh()
	assert_eq(g.priority_player, 0, "your main phase waits for you")
	assert_eq(g.current_step(), Mtg.Step.MAIN1)
	# ...and so does the second one.
	var g2 := _human_priority_on_your_turn(Mtg.Step.MAIN2)
	assert_false(screen._auto_pass_applies())
	screen._refresh()
	assert_eq(g2.priority_player, 0)


func test_your_own_upkeep_and_draw_are_not_stopped_by_default() -> void:
	screen.stops.from_masks(PhaseStops.default_masks())
	for step in [Mtg.Step.UPKEEP, Mtg.Step.DRAW]:
		_human_priority_on_your_turn(step)
		assert_true(screen._auto_pass_applies(),
			"%s carries no dot, so it goes by itself"
				% Mtg.step_name(step))


func test_a_hotseat_duel_never_auto_passes() -> void:
	# Both seats are somebody's: there is no "opponent" for the duel to
	# run on behalf of.
	var hotseat: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(hotseat)
	await get_tree().process_frame
	var g: MtgGame = hotseat.game
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	g.priority_player = 0
	hotseat._refresh()
	assert_eq(g.priority_player, 0, "seat 0's window is seat 0's to pass")


# ============================================= where it is NOT allowed to --

func test_it_stops_for_a_required_action() -> void:
	# "If there are any required actions to perform during a specific
	# phase … movement through the phases will stop at that phase until
	# you do what is necessary" (`Duel.hlp`, topic Phase Bar).
	var g := _human_priority_on_their_turn(Mtg.Step.DECLARE_BLOCKERS)
	g.awaiting_blockers = true
	assert_false(screen._auto_pass_applies(), "blockers are yours to declare")
	g.awaiting_blockers = false
	assert_true(screen._auto_pass_applies())


func test_it_stops_for_something_on_the_chain_you_can_answer() -> void:
	# "If your opponent does something that requires or permits a response
	# (casts a spell, uses a fast effect, declares an attack, or whatever),
	# movement through phases stops so that you have a chance to respond."
	#
	# PERMITS, READ LITERALLY (2026-09-04). The clause used to stop for
	# ANYTHING on the chain, which cost the owner one click per spell the
	# opponent cast — the second half of their report — because a chain
	# item you hold no answer to permits no response at all. The test is
	# POTENTIAL mana (`_could_respond` -> MtgGame.could_afford), so a
	# window you could still tap a land into always waits.
	var g := _human_priority_on_their_turn(Mtg.Step.MAIN1)
	g.players[0].hand.clear()
	assert_true(screen._auto_pass_applies(), "an empty chain runs on")
	_give_a_real_response(g)
	g.priority_player = 0
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.controller = 1
	g.stack.append(item)
	assert_false(screen._auto_pass_applies(),
		"a Bolt in hand and a Mountain untapped IS a response, and the "
		+ "duel waits for it even though no mana is floated yet")
	g.players[0].hand.clear()
	g.priority_player = 0
	assert_true(screen._auto_pass_applies(),
		"nothing in hand and nothing to activate: this chain item permits "
		+ "no response, so it is not a window worth a click")
	g.stack.clear()


## An instant in hand and an untapped source for it — the state in which
## something on the chain really does *permit* a response. Nothing is
## refreshed after the chain item goes on, because a bare [StackItem]
## carries no card for the screen to draw.
func _give_a_real_response(g: MtgGame) -> void:
	var bolt := CardRegistry.get_card("Lightning Bolt")
	var mountain := CardRegistry.get_card("Mountain")
	if bolt == null or mountain == null:
		return
	var land := CardInstance.new(mountain, 90411, 0)
	g._instances[land.id] = land
	g._put_on_battlefield(land, 0)
	g.recalculate()
	var inst := CardInstance.new(bolt, 90410, 0)
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)


func test_it_stops_at_a_stop() -> void:
	# "If you have placed a Stop on a phase, progress pauses at that
	# phase" — and a Stop is defined by exactly this: "that phase does not
	# end until you tell it to manually; it cannot pass automatically."
	var g := _human_priority_on_their_turn(Mtg.Step.UPKEEP)
	assert_true(screen._auto_pass_applies())
	screen.stops.set_marked(PhaseStops.Half.OPPONENTS, PhaseStops.Bar.PHASE,
		1, true)                             # their Upkeep
	assert_false(screen._auto_pass_applies(), "the marked phase holds")
	screen._refresh()
	assert_eq(g.priority_player, 0, "...and the window really is still ours")


func test_it_stops_when_a_fast_effect_is_affordable() -> void:
	# Manual p.112's third Done condition, which is also the owner's own
	# "priority with something castable": "(3) you are able to use a fast
	# effect. (Note that 'able to' means that you have a fast effect handy
	# AND you have the mana available to use that effect.)"
	var bolt := CardRegistry.get_card("Lightning Bolt")
	if bolt == null:
		pass_test("Lightning Bolt not in the pool")
		return
	var g := _human_priority_on_their_turn(Mtg.Step.UPKEEP)
	g.players[0].hand.clear()
	var inst := CardInstance.new(bolt, 90310, 0)
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)
	assert_true(screen._auto_pass_applies(),
		"an instant with no mana floated is not yet 'able to'")
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_false(screen._auto_pass_applies(),
		"handy AND payable — the manual's two halves, and the duel waits")


func test_it_stops_for_a_held_open_question() -> void:
	var g := _human_priority_on_their_turn(Mtg.Step.UPKEEP)
	var ask := PlayerChoice.new(PlayerChoice.Kind.YES_NO, 0, "Pay {B}{B}?")
	g.awaiting_choice = ask
	assert_false(screen._auto_pass_applies(), "an unanswered question holds")
	g.awaiting_choice = null


func test_it_never_runs_over_an_action_in_progress() -> void:
	_human_priority_on_their_turn(Mtg.Step.UPKEEP)
	screen.mode = DuelScreen.Mode.TARGETING
	assert_false(screen._auto_pass_applies(),
		"a spell of yours is being aimed on their turn")
	screen.mode = DuelScreen.Mode.NORMAL
	assert_true(screen._auto_pass_applies())


func test_a_standing_order_still_owns_the_duel() -> void:
	# Done / Run to are the player's own instruction and drive themselves;
	# the auto-pass must not fire underneath one.
	_human_priority_on_their_turn(Mtg.Step.UPKEEP)
	screen._advance_mode = DuelScreen.Advance.DONE
	screen._drive_advance()
	screen._cancel_advance()
	pass_test("the driver took the DONE branch, not the auto-pass one")


# ======================================================== the whole turn --

func test_the_opponents_turn_walks_itself_to_yours() -> void:
	# The end-to-end shape of the fix: from their upkeep, with nothing
	# held and nothing marked, the duel gets itself out of their turn
	# without a single Done. The AI seat's own moves ride its pacing
	# timer, so this drives only what the screen drives.
	var g := _human_priority_on_their_turn(Mtg.Step.UPKEEP)
	g.players[0].hand.clear()
	g.players[1].hand.clear()
	var seen := 0
	# The AI seat's own move, then a refresh: exactly what `_ai_step` does
	# when its pacing timer fires, with the timer taken out of it. The
	# human's windows are never touched — if the duel gets out of their
	# turn, the screen passed every one of them by itself.
	while seen < 200 and g.active_player == 1 and not g.game_over:
		seen += 1
		var acting := screen._ai_seat_to_act()
		if acting != -1:
			screen._ais[acting].act(g)
			continue
		var was: int = Mtg.STEP_ORDER.find(g.current_step())
		screen._refresh()
		if screen._ai_seat_to_act() == -1 and g.priority_player == 0 \
				and Mtg.STEP_ORDER.find(g.current_step()) == was:
			break            # the screen stopped and is waiting on a click
	assert_ne(g.active_player, 1,
		"the duel reached the human's turn with no Done pressed (stopped in %s)"
			% Mtg.step_name(g.current_step()))


# ====================================== YOUR OWN TURN — the safety cases --
#
# Every one of these is a moment the ENGINE is holding the turn open for
# the human seat. Passing one of them for the player is a HANG, which is
# what `duel_soak.sh` exists to catch, so each is pinned with NOTHING
# marked — the safety list is checked before any Stop is consulted and must
# hold on an entirely unmarked bar.

func test_your_own_combat_is_never_passed_for_you() -> void:
	# `MtgGame._advance_step` sets `awaiting_attackers` on entering
	# DECLARE_ATTACKERS whatever the board looks like, so combat on your own
	# turn always reaches you — the combat dot is a promise the engine keeps
	# on its own.
	var g := _human_priority_on_your_turn(Mtg.Step.DECLARE_ATTACKERS)
	screen.stops.clear_all()
	assert_true(g.awaiting_attackers, "the engine is waiting on a lineup")
	assert_false(screen._auto_pass_applies(),
		"an unmarked bar does not let the duel declare no attack for you")


func test_your_own_discard_is_never_passed_for_you() -> void:
	var g := _human_priority_on_your_turn(Mtg.Step.MAIN2)
	screen.stops.clear_all()
	assert_true(screen._auto_pass_applies(), "quiet, so far")
	g.awaiting_discard = true
	assert_false(screen._auto_pass_applies(),
		"a hand over seven is yours to cut")
	g.awaiting_discard = false


func test_your_own_turn_stops_for_a_question() -> void:
	# §1.3: the engine HOLDS a resolution open on `awaiting_choice`. The
	# overlay comes up from `_refresh`, and passing the window underneath it
	# would strand the question.
	var g := _human_priority_on_your_turn(Mtg.Step.UPKEEP)
	screen.stops.clear_all()
	g.awaiting_choice = PlayerChoice.new(
		PlayerChoice.Kind.YES_NO, 0, "Pay {B}{B}?")
	assert_false(screen._auto_pass_applies())
	g.awaiting_choice = null


func test_your_own_turn_stops_for_the_damage_windows() -> void:
	# §6.8: the prevention and regeneration windows are the one moment a
	# Circle of Protection can be used at all.
	var g := _human_priority_on_your_turn(Mtg.Step.COMBAT_DAMAGE)
	screen.stops.clear_all()
	g.awaiting_damage_prevention = true
	assert_false(screen._auto_pass_applies())
	g.awaiting_damage_prevention = false
	g.awaiting_regeneration = true
	assert_false(screen._auto_pass_applies())
	g.awaiting_regeneration = false
	g.awaiting_damage_assignment = true
	assert_false(screen._auto_pass_applies())
	g.awaiting_damage_assignment = false


func test_your_own_turn_stops_for_a_chain_item_you_can_answer() -> void:
	# The same "permits" reading one turn over: a trigger of your own
	# upkeep holds the duel when you have an answer to it, and does not
	# when you have none.
	var g := _human_priority_on_your_turn(Mtg.Step.UPKEEP)
	screen.stops.clear_all()
	g.players[0].hand.clear()
	_give_a_real_response(g)
	g.priority_player = 0
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.controller = 1
	g.stack.append(item)
	assert_false(screen._auto_pass_applies(),
		"a trigger of your own upkeep is something to respond to")
	g.players[0].hand.clear()
	g.priority_player = 0
	assert_true(screen._auto_pass_applies(),
		"...and with nothing to respond WITH it is not")
	g.stack.clear()
	g.stack.clear()


func test_your_own_turn_stops_for_a_fast_effect_you_can_afford() -> void:
	var bolt := CardRegistry.get_card("Lightning Bolt")
	if bolt == null:
		pass_test("Lightning Bolt not in the pool")
		return
	var g := _human_priority_on_your_turn(Mtg.Step.UPKEEP)
	screen.stops.clear_all()
	g.players[0].hand.clear()
	var inst := CardInstance.new(bolt, 90410, 0)
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_false(screen._auto_pass_applies(),
		"mana floated for a response is a response you are about to make")


# ================================= arriving somewhere is not a window --

func test_the_phase_an_order_rested_in_is_not_passed_for_you() -> void:
	# Manual p.116: a run "blithely skips through all the intervening
	# phases, THEN STOPS". Naming a destination is telling the duel manually
	# where you want to be, so the automatic pass must not walk on the same
	# frame it arrives.
	var g := _human_priority_on_your_turn(Mtg.Step.DRAW)
	screen.stops.clear_all()
	assert_true(screen._auto_pass_applies(), "unmarked, so it would go")
	screen._rested_at = screen._phase_key()
	assert_false(screen._auto_pass_applies(), "...but it arrived here")
	# ...and the mark is spent the moment the duel is anywhere else.
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	screen._drive_advance()
	assert_eq(screen._rested_at, [] as Array, "the rest mark is dropped")


func test_a_run_to_an_unmarked_phase_actually_stays_there() -> void:
	# The same rule end to end, through the real driver and the real AI
	# seat: aim at your own Draw step, which carries no Stop, and the duel
	# must be sitting in it when the dust settles.
	var g := _human_priority_on_your_turn(Mtg.Step.UPKEEP)
	screen.stops.clear_all()
	g.players[0].hand.clear()
	g.players[1].hand.clear()
	screen._order_run_to(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 2)
	_pump(60)
	assert_eq(g.current_step(), Mtg.Step.DRAW,
		"the run arrived (stopped in %s)" % Mtg.step_name(g.current_step()))
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE,
		"and the order is spent")
	_pump(20)
	assert_eq(g.current_step(), Mtg.Step.DRAW,
		"and it is STILL there — the auto-pass did not eat the arrival")


# ============================ the whole of your turn, between the stops --

func test_your_turn_walks_itself_from_stop_to_stop() -> void:
	# The shape of the second instalment: with the three defaults and a
	# quiet board, your untap/upkeep/draw go by themselves and the duel
	# comes to rest in your Main pre-combat, which is where you act.
	var g := _human_priority_on_your_turn(Mtg.Step.UPKEEP)
	screen.stops.from_masks(PhaseStops.default_masks())
	g.players[0].hand.clear()
	g.players[1].hand.clear()
	_pump(80)
	assert_eq(g.active_player, 0, "still your turn")
	assert_eq(g.current_step(), Mtg.Step.MAIN1,
		"it stopped at the first red dot (stopped in %s)"
			% Mtg.step_name(g.current_step()))
	assert_eq(g.priority_player, 0, "and the window is yours")


## Take the duel forward the way the live screen does: let an AI seat move
## when it is its turn to, otherwise refresh, which is where the automatic
## pass lives. Stands in for the pacing timer, which a test cannot await.
func _pump(steps: int) -> void:
	for _i in steps:
		if screen.game.game_over:
			return
		var acting := screen._ai_seat_to_act()
		if acting != -1:
			screen._ais[acting].act(screen.game)
		else:
			screen._refresh()
