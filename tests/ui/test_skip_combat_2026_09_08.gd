extends GutTest
## THE SKIP — the owner's playtest of v0.19.0-dev, 2026-09-08: *"before
## phases of combat even start you might want to skip it entirely - so
## when we arrive at the icon of combat phase the announcement should
## say: Begin Combat or skip? And you should have two buttons: begin
## (takes you into declare attackers and combat stages), if you click
## "skip", you just go into main phase 2 post-combat without even seeing
## the combat phases icons.. If you dont have red dot on combat (it just
## skips if no creatures are on your board). Otherwise red dot is always
## on here by default."*
##
## `DuelScreen.SKIP_OFFER` and the block above it carry the design: a
## standing order (`Advance.SKIP_COMBAT`) that is a Run to the second
## main phase, declaring no attackers on the way, taking the AI seat's
## replies at once so the walk is one call, and ignoring the Stops of the
## phase it leaves out; the Stop-off case arms the same order by itself
## when nothing of yours could attack. [QoL] — the original's combat
## opened on the attackers' choice, and no `UIStrings.txt` prompt offers
## to skip it.

var screen: DuelScreen
var _saved_stops: Variant = null
var _next_id := 91500


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


# ---------------------------------------------------------------- fixture --
#
# The same fixture as tests/ui/test_instant_windows_2026_09_08.gd: every
# change is made with the engine's `_probing` flag up so no refresh runs
# the automatic pass — or now the automatic skip — over a half-built
# position. What the screen does is then asked for directly.

## Stand the duel at the beginning of [param active]'s combat with the
## human holding priority, the chain empty, the table in NORMAL mode.
func _begin_combat(active := 0) -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_BEGIN))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._passes = 0 if active == 0 else 1
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	return g


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


func _hold(card_name: String, seat := 0) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), _next_id, seat)
	_next_id += 1
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[seat].hand.append(inst)
	return inst


## A foreign spell standing on the chain — the opponent's Bolt, cast.
func _their_bolt_on_the_chain() -> StackItem:
	var bolt := _hold("Lightning Bolt", 1)
	bolt.zone = Mtg.Zone.STACK
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.card = bolt
	item.controller = 1
	item.description = "Lightning Bolt"   # filled at creation in play
	screen.game.stack.append(item)
	return item


## The combat Stop on your own half: slot 4 of the Phase Bar, the one
## PhaseStops.default_masks() marks and before_each cleared.
func _mark_combat_stop(on: bool) -> void:
	screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 4, on)


func _main2_key() -> Array:
	return [PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 5]


func _pump(steps: int) -> void:
	for _i in steps:
		if screen.game.game_over:
			return
		var acting := screen._ai_seat_to_act()
		if acting != -1:
			screen._ais[acting].act(screen.game)
		else:
			screen._refresh()


func _log_has(text: String) -> bool:
	for line in screen.game.log_lines:
		if String(line).contains(text):
			return true
	return false


# =============================================================== the offer --

func test_the_bar_asks_the_owners_question_at_your_own_beginning_of_combat() -> void:
	_mark_combat_stop(true)
	_summon("Gray Ogre", 0)
	_begin_combat(0)
	assert_true(screen._skip_offer_applies())
	assert_eq(screen._status_message(), "Begin Combat or skip?",
		"the owner's words, verbatim")
	screen._refresh()
	assert_eq(screen.game.current_step(), Mtg.Step.COMBAT_BEGIN,
		"the Stop holds the duel there")
	assert_eq(screen._pass_button.text, "Begin", "Done wears the first answer")
	assert_true(screen._skip_button.visible, "...and Skip stands beside it")
	assert_false(screen._cancel_button.visible, "nothing to cancel")


func test_elsewhere_done_is_done_and_there_is_no_skip() -> void:
	var g: MtgGame = screen.game
	g._probing = true
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g._probing = false
	assert_false(screen._skip_offer_applies())
	screen._refresh()
	assert_eq(screen._pass_button.text, "Done")
	assert_false(screen._skip_button.visible)


func test_not_offered_on_their_turn_nor_over_a_chain_nor_without_priority() -> void:
	_mark_combat_stop(true)
	_begin_combat(1)
	assert_false(screen._skip_offer_applies(), "their combat is theirs")
	assert_eq(screen._status_message(), "Fast Effects?...Begin Combat",
		"the 2026-09-08 line on their turn, untouched")
	var g := _begin_combat(0)
	_their_bolt_on_the_chain()
	assert_false(screen._skip_offer_applies(), "something on the chain first")
	assert_eq(screen._status_message(), "Fast Effects?...Cast Lightning Bolt")
	g.stack.clear()
	g.priority_player = 1
	assert_false(screen._skip_offer_applies(), "not while the opponent holds priority")
	g.priority_player = 0
	assert_true(screen._skip_offer_applies(), "...and again once it is yours")


# ================================================================ the skip --

func test_skip_walks_to_the_second_main_phase_in_one_call() -> void:
	# The Stop is on (the default), a creature of yours could attack, and
	# you would rather not: the whole of combat goes by inside the one
	# call, no lineup asked for, no icon drawn.
	_mark_combat_stop(true)
	var ogre := _summon("Gray Ogre", 0)
	var g := _begin_combat(0)
	screen._order_skip_combat()
	assert_eq(g.current_step(), Mtg.Step.MAIN2, "the second main phase, at once")
	assert_eq(g.active_player, 0, "still your turn")
	assert_eq(g.priority_player, 0, "and your priority in it")
	assert_true(g.combat.attackers.is_empty(), "no attack was made")
	assert_false(ogre.tapped, "the Ogre never moved")
	assert_true(_log_has("declares no attackers"), "the engine's own record of it")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "the lineup mode was entered and left")
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE, "the order is spent")
	assert_eq(screen._rested_at, _main2_key(),
		"...and rests where it arrived, so the automatic pass leaves Main 2 alone")
	assert_eq(screen._status_message(), "Main phase (after combat): cast spells, play land")
	assert_eq(screen._pass_button.text, "Done")
	assert_false(screen._skip_button.visible)


func test_begin_is_the_plain_pass_into_the_lineup() -> void:
	# The first button: what Done did before — one pass, the AI's reply,
	# and the declaration is asked for as it was.
	_mark_combat_stop(true)
	_summon("Gray Ogre", 0)
	var g := _begin_combat(0)
	screen._on_done()
	assert_eq(g.current_step(), Mtg.Step.COMBAT_BEGIN, "one pass: the AI's turn to speak")
	assert_eq(g.priority_player, 1)
	_pump(2)
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)
	assert_true(g.awaiting_attackers)
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)
	assert_eq(screen._status_message(), "Combat phase: Choose attackers.")


func test_skip_ignores_the_stops_inside_the_phase_it_leaves_out() -> void:
	# A Stop on every Combat Bar icon and on the combat icon itself: a
	# Run to would halt at the first of them; the Skip was told to leave
	# the phase out, Stops and all.
	_mark_combat_stop(true)
	for slot in PhaseStops.SLOT_COUNT[PhaseStops.Bar.COMBAT]:
		screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.COMBAT, slot, true)
	_summon("Gray Ogre", 0)
	var g := _begin_combat(0)
	screen._order_skip_combat()
	assert_eq(g.current_step(), Mtg.Step.MAIN2)
	# ...and the reason itself, read directly: the same position with the
	# same marks answers "Stop" to a Run to and nothing to a Skip.
	_begin_combat(0)
	screen._advance_mode = DuelScreen.Advance.RUN_TO
	screen._advance_moved = true
	assert_eq(screen._advance_stop_reason(), "Stop")
	screen._advance_mode = DuelScreen.Advance.SKIP_COMBAT
	assert_eq(screen._advance_stop_reason(), "")
	screen._cancel_advance()


func test_skip_halts_for_something_the_opponent_puts_on_the_chain() -> void:
	# Manual p.116's "requires or permits a response", read as a Run to
	# reads it: whatever the opponent did, you see it. A foreign spell
	# the order did not see when it was given is the reason.
	_summon("Gray Ogre", 0)
	_begin_combat(0)
	screen._advance_mode = DuelScreen.Advance.SKIP_COMBAT
	screen._advance_moved = true
	screen._advance_seen = []
	_their_bolt_on_the_chain()
	assert_eq(screen._advance_stop_reason(), "Lightning Bolt is on the chain")
	screen.game.stack.clear()
	screen._cancel_advance()


func test_a_creature_that_must_attack_refuses_the_skip_at_the_lineup() -> void:
	# Nettling Imp's compulsion: "none" is not a lineup the engine takes,
	# and the order halts there with the engine's own words, the
	# declaration yours to make.
	_mark_combat_stop(true)
	var ogre := _summon("Gray Ogre", 0)
	ogre.must_attack_this_turn = true
	var g := _begin_combat(0)
	screen._order_skip_combat()
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)
	assert_true(g.awaiting_attackers)
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE)
	assert_string_contains(screen._prompt_label.text, "must attack this turn if able")


# ============================================================ the stop off --

func test_with_the_stop_off_and_nothing_to_send_the_combat_goes_by_itself() -> void:
	# *"If you dont have red dot on combat (it just skips if no creatures
	# are on your board)."* — read as "no creature that could attack": a
	# Wall is on the board and it has nothing to send.
	_summon("Wall of Swords", 0)
	_summon("Mountain", 0)
	var g := _begin_combat(0)
	assert_true(screen._auto_pass_applies(), "the unmarked phase would pass itself")
	assert_false(screen._has_a_legal_attacker(0), "a Wall cannot attack")
	assert_true(screen._auto_skip_applies())
	screen._refresh()
	assert_eq(g.current_step(), Mtg.Step.MAIN2, "one refresh: Main 2")
	assert_true(_log_has("declares no attackers"))
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE)


func test_with_the_stop_off_and_an_attacker_the_lineup_is_still_asked_for() -> void:
	# ...and with a creature able to attack an unstopped combat runs as
	# it did: the beginning passes itself, the declaration waits for you.
	_summon("Gray Ogre", 0)
	var g := _begin_combat(0)
	assert_true(screen._auto_pass_applies())
	assert_true(screen._has_a_legal_attacker(0))
	assert_false(screen._auto_skip_applies())
	screen._refresh()
	assert_eq(g.current_step(), Mtg.Step.COMBAT_BEGIN, "passed once, to the AI")
	_pump(2)
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)
	assert_true(g.awaiting_attackers)
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)


func test_nothing_to_send_is_the_engines_own_reading() -> void:
	# Tapped, summoning-sick, a Wall, a Festival: none could attack. An
	# untapped Ogre could.
	var ogre := _summon("Gray Ogre", 0)
	_begin_combat(0)
	assert_true(screen._has_a_legal_attacker(0))
	ogre.tapped = true
	assert_false(screen._has_a_legal_attacker(0), "tapped")
	ogre.tapped = false
	ogre.summoning_sick = true
	assert_false(screen._has_a_legal_attacker(0), "summoning sick")
	ogre.summoning_sick = false
	screen.game.no_attacks_this_turn = true
	assert_false(screen._has_a_legal_attacker(0), "under a Festival")
	screen.game.no_attacks_this_turn = false
	assert_true(screen._has_a_legal_attacker(0))


func test_with_the_stop_on_nothing_to_send_still_waits_for_you() -> void:
	# The Stop is unconditional (`Duel.hlp`: "it cannot pass
	# automatically"), and the owner's default puts one on combat: an
	# empty board is offered the two buttons, not walked past.
	_mark_combat_stop(true)
	var g := _begin_combat(0)
	assert_false(screen._auto_skip_applies())
	screen._refresh()
	assert_eq(g.current_step(), Mtg.Step.COMBAT_BEGIN)
	assert_true(screen._skip_button.visible)


func test_a_run_to_that_rests_at_combat_is_offered_the_buttons_too() -> void:
	# Naming combat as a destination is standing there on purpose: no
	# automatic skip, the question instead.
	var g := _begin_combat(0)
	screen._rested_at = screen._phase_key()
	assert_false(screen._auto_pass_applies())
	assert_false(screen._auto_skip_applies())
	screen._refresh()
	assert_eq(g.current_step(), Mtg.Step.COMBAT_BEGIN)
	assert_true(screen._skip_offer_applies())


func test_the_default_stops_still_mark_combat() -> void:
	# *"Otherwise red dot is always on here by default."* — which
	# PhaseStops.DEFAULT_SLOTS has said since 2026-09-03.
	assert_has(PhaseStops.DEFAULT_SLOTS, 4, "your combat icon")
