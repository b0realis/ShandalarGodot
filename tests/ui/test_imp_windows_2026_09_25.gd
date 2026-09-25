extends GutTest
## THE PRINTED RIDERS AT THE SCREEN (2026-09-25). The owner: Nettling Imp
## *"plays like instant on the opponent turns only"* — and it did at the
## engine, which refused the click in every other moment; but the duel
## screen's three "has a fast effect" predicates priced an untapped Imp's
## free {T} as a response in EVERY window of BOTH turns, so the automatic
## pass stopped for it on its own turn and after their attackers were
## declared, and the actionable cue lit a card that could not be used.
## Now [method DuelScreen._ability_open] asks the engine's own reading of
## the riders ([method MtgGame.ability_timing_refusal]) before pricing
## the cost, and these pin the three answers: its own turn (nothing),
## their turn before attackers (a response), their turn after (nothing).
## The fixture is `test_instant_windows_2026_09_08.gd`'s.

var screen: DuelScreen
var _saved_stops: Variant = null
var _next_id := 90700


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
	screen.game.players[0].hand.clear()
	screen.game.players[1].hand.clear()


func after_each() -> void:
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


func _window(active: int, step: int) -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._passes = 0 if active == 0 else 1
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	return g


func _on_to(step: int) -> void:
	var g: MtgGame = screen.game
	g._probing = true
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._probing = false


func _summon(card_name: String, seat: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), _next_id, seat)
	_next_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, seat)
	inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


func _attack_with_an_ogre(seat: int) -> CardInstance:
	var ogre := _summon("Gray Ogre", seat)
	screen.game.combat.attackers[ogre.id] = true
	ogre.tapped = true
	return ogre


## The Imp and something for it to conscript: seat 1's Hill Giant.
func _imp_and_a_giant() -> CardInstance:
	_summon("Hill Giant", 1)
	return _summon("Nettling Imp", 0)


func test_an_untapped_imp_holds_nothing_on_its_own_turn() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var imp := _imp_and_a_giant()
	assert_false(imp.tapped)
	assert_false(screen._has_affordable_fast_effect(0), "not a fast effect of yours")
	assert_false(screen._could_respond(0), "not a response of yours")
	assert_false(screen._can_act_on(imp), "no cue on it")
	assert_true(screen._auto_pass_applies(), "your own main goes")
	_on_to(Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(0)
	assert_false(screen._could_respond(0), "nor in your own attack window")
	assert_true(screen._auto_pass_applies())
	_on_to(Mtg.Step.END)
	g.priority_player = 0
	assert_false(screen._could_respond(0))
	assert_true(screen._auto_pass_applies())


func test_the_imp_is_a_response_on_their_turn_before_attackers() -> void:
	var g := _window(1, Mtg.Step.UPKEEP)
	var imp := _imp_and_a_giant()
	assert_true(screen._could_respond(0), "their upkeep: the Imp is handy")
	assert_true(screen._has_affordable_fast_effect(0), "...and costs nothing")
	assert_true(screen._can_act_on(imp), "the cue lights")
	_on_to(Mtg.Step.COMBAT_BEGIN)
	g.priority_player = 0
	assert_true(screen._could_respond(0), "the beginning of their combat: still")
	assert_false(screen._auto_pass_applies(), "...so the automatic pass waits")
	assert_eq(g.ability_timing_refusal(0, imp, imp.cur_activated_abilities[0]), "")
	imp.tapped = true
	assert_false(screen._could_respond(0), "a tapped Imp is not handy")
	assert_true(screen._auto_pass_applies())


func test_the_imp_is_no_response_once_their_attackers_are_declared() -> void:
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(1)
	var imp := _imp_and_a_giant()
	g.priority_player = 0
	assert_false(screen._could_respond(0), "their attack is declared: too late")
	assert_false(screen._has_affordable_fast_effect(0))
	assert_false(screen._can_act_on(imp))
	assert_true(screen._auto_pass_applies(), "the attack window is not held for it")
	_on_to(Mtg.Step.DECLARE_BLOCKERS)
	assert_false(screen._could_respond(0))
	assert_true(screen._auto_pass_applies())
	_on_to(Mtg.Step.END)
	assert_false(screen._could_respond(0), "nor is the end of their turn")
	assert_true(screen._auto_pass_applies())


func test_a_bolt_still_holds_the_windows_the_imp_no_longer_does() -> void:
	# The riders narrow the Imp alone: an instant in hand is a response
	# in the same windows it always was.
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(1)
	_imp_and_a_giant()
	_summon("Mountain", 0)
	var bolt := CardInstance.new(CardRegistry.get_card("Lightning Bolt"), _next_id, 0)
	_next_id += 1
	bolt.zone = Mtg.Zone.HAND
	g._instances[bolt.id] = bolt
	g.players[0].hand.append(bolt)
	g.priority_player = 0
	assert_true(screen._could_respond(0))
	assert_false(screen._auto_pass_applies(), "the Bolt holds it")
