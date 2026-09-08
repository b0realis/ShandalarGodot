extends GutTest
## THE INSTANT WINDOWS — the owner's playtest, 2026-09-08: *"i have an
## instant like 'lightning bolt'. I cannot cast it during (my/opponent)
## battle turns. By the mtg rules: Yes, instant spells and flash cards
## can be played during the combat phase in Magic: The Gathering,
## provided you have priority."*
##
## The engine had the priority rounds all along (CR 117.3b: after every
## declaration and every damage step, for both seats) and the AI seat
## used them; the automatic pass of 2026-09-03 walked the HUMAN through
## them, because nothing on the Combat Bar is marked by default and the
## test for "something castable" was the floating pool. These pin the
## fix: `DuelScreen._instant_window_reason` names the moments, and the
## automatic pass — and a Done or Run to that travels into one — holds
## there exactly when `_could_respond` says the player has a fast effect
## they could pay for and aim.
##
## THE 1997 LICENCE. `Duel.hlp`, topic **Combat Bar**: *"the sword with
## rays — Fast Effects"* after Declare Attackers and *"the shield with
## rays — Fast Effects (2)"* after Declare Blockers, on either turn;
## `@PROMPT_CHECKFEPHASE` (UIStrings.txt:1024) names them `Assign
## Attackers` / `Assign Blockers` in the same table as every other phase
## the fast-effects question is asked in.

var screen: DuelScreen
var _saved_stops: Variant = null
var _next_id := 90500


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
# Every fixture change is made with the engine's `_probing` flag up, which
# is its own "emit nothing" switch (the AI's lookahead uses it): a bare
# `recalculate()` emits `state_changed`, `state_changed` is `_refresh`,
# and `_refresh` runs the automatic pass — which would pass the very
# window being set up while the hand was still empty. What the screen
# thinks of the finished position is then asked directly.

## Stand the duel in [param step] of [param active]'s turn with the human
## holding priority and every declaration already made — the fast-effects
## round of that step, which is what the windows are. On their turn the
## active seat has passed once already (that is how the human comes to
## hold priority there, CR 117.3b/117.4); on yours the round is fresh.
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


## Move the duel to [param step] of the same turn, declarations made.
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


func _hold(card_name: String, seat := 0) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), _next_id, seat)
	_next_id += 1
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[seat].hand.append(inst)
	return inst


## An attack in progress: [param seat]'s Gray Ogre, declared. After
## [method _window] — entering the declare-attackers step clears the
## combat record.
func _attack_with_an_ogre(seat: int) -> CardInstance:
	var ogre := _summon("Gray Ogre", seat)
	screen.game.combat.attackers[ogre.id] = true
	ogre.tapped = true
	return ogre


## The response the owner had: a Bolt in hand and a Mountain to pay for
## it — nothing floated, which is the whole point.
func _bolt_and_a_mountain() -> CardInstance:
	_summon("Mountain", 0)
	return _hold("Lightning Bolt")


func _pump(steps: int) -> void:
	for _i in steps:
		if screen.game.game_over:
			return
		var acting := screen._ai_seat_to_act()
		if acting != -1:
			screen._ais[acting].act(screen.game)
		else:
			screen._refresh()


# ============================================ the windows, on their turn --

func test_their_declared_attack_holds_for_a_bolt_you_can_pay_for() -> void:
	# The exact moment of the report: their creature is attacking, the
	# blocks are not yet asked for, and the player holds a Bolt with the
	# Mountain for it untapped.
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(1)
	assert_eq(screen._instant_window_reason(), "attackers are declared")
	assert_true(screen._auto_pass_applies(),
		"an empty hand: nothing to cast, and the window goes by itself")
	_bolt_and_a_mountain()
	g.priority_player = 0
	assert_false(screen._auto_pass_applies(),
		"a Bolt in hand and a Mountain untapped: the window WAITS")


func test_their_declared_blocks_hold_too() -> void:
	var g := _window(1, Mtg.Step.DECLARE_BLOCKERS)
	_attack_with_an_ogre(1)
	assert_eq(screen._instant_window_reason(), "blockers are declared")
	assert_true(screen._auto_pass_applies())
	_bolt_and_a_mountain()
	g.priority_player = 0
	assert_false(screen._auto_pass_applies(),
		"after blocks is where a Bolt at the blocked attacker goes")


func test_their_end_step_is_the_last_call_for_a_held_instant() -> void:
	# The classic: a Bolt at the end of THEIR turn, with your mana about
	# to untap. The AI seat already plays this (`_end_of_their_turn`); now
	# the human is given the same moment.
	var g := _window(1, Mtg.Step.END)
	assert_eq(screen._instant_window_reason(), "their turn is ending")
	assert_true(screen._auto_pass_applies(), "nothing held: it goes")
	_bolt_and_a_mountain()
	g.priority_player = 0
	assert_false(screen._auto_pass_applies())


func test_first_strike_damage_is_a_window_of_its_own() -> void:
	var g := _window(1, Mtg.Step.FIRST_STRIKE_DAMAGE)
	_attack_with_an_ogre(1)
	assert_eq(screen._instant_window_reason(),
		"first-strike damage has been dealt")
	_bolt_and_a_mountain()
	g.priority_player = 0
	assert_false(screen._auto_pass_applies())


# ============================================= the windows, on YOUR turn --

func test_your_own_declared_attack_and_blocks_hold_as_well() -> void:
	# "(my/opponent) battle turns" — both halves of the report. Your own
	# attack is declared, the engine has handed you the first priority of
	# the round (CR 117.3a), and a pump or a Bolt at a blocker is yours to
	# cast before the duel walks on.
	var g := _window(0, Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(0)
	assert_eq(screen._instant_window_reason(), "attackers are declared")
	assert_true(screen._auto_pass_applies(), "empty hand: it goes")
	_bolt_and_a_mountain()
	g.priority_player = 0
	assert_false(screen._auto_pass_applies(), "...and with a Bolt it waits")
	_on_to(Mtg.Step.DECLARE_BLOCKERS)
	assert_eq(screen._instant_window_reason(), "blockers are declared")
	assert_false(screen._auto_pass_applies())


func test_your_own_end_step_is_not_a_window() -> void:
	# A Bolt at your own end step is a Bolt you could have cast in Main 2;
	# the 2026-09-03 rule ("it should go automatically EVEN FOR ME") keeps
	# the quiet steps of your own turn quiet.
	var g := _window(0, Mtg.Step.END)
	_bolt_and_a_mountain()
	g.priority_player = 0
	assert_eq(screen._instant_window_reason(), "")
	assert_true(screen._auto_pass_applies())


func test_your_own_quiet_upkeep_still_runs_with_a_bolt_in_hand() -> void:
	# The 2026-09-03 behaviour, kept whole: outside the windows the test
	# is still the FLOATING pool, so a Bolt in hand with a Mountain
	# untapped does not stop your own upkeep, draw or main.
	var g := _window(0, Mtg.Step.UPKEEP)
	_bolt_and_a_mountain()
	g.priority_player = 0
	assert_true(screen._auto_pass_applies(), "upkeep goes")
	_on_to(Mtg.Step.DRAW)
	assert_true(screen._auto_pass_applies(), "draw goes")
	# ...and so does the opponent's quiet upkeep: only the windows and a
	# chain item hold their turn.
	_window(1, Mtg.Step.UPKEEP)
	assert_true(screen._auto_pass_applies(), "their upkeep goes")


# ====================================================== what is NOT a window --

func test_a_declaration_still_owed_is_not_a_window() -> void:
	# While the lineup is owed the step is a REQUIRED ACTION (the safety
	# rule), not a fast-effects round — the window opens once it is in.
	var g := _window(0, Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	assert_eq(screen._instant_window_reason(), "")
	assert_eq(screen._required_action_reason(), "attackers must be declared")
	_window(1, Mtg.Step.DECLARE_BLOCKERS)
	g.awaiting_blockers = true
	assert_eq(screen._instant_window_reason(), "")
	assert_eq(screen._required_action_reason(), "blockers must be declared")


func test_no_attack_no_window() -> void:
	# The owner's 2026-09-03 rule for combat: *"If no attackers are
	# declared the combat subphases should not show."* The engine skips
	# to the end of combat, and there is nothing in the step to answer.
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	assert_true(g.combat.attackers.is_empty())
	_bolt_and_a_mountain()
	g.priority_player = 0
	assert_eq(screen._instant_window_reason(), "")
	assert_true(screen._auto_pass_applies(),
		"a Bolt in hand does not hold a combat nobody is fighting")


func test_a_counterspell_over_an_empty_chain_is_no_response() -> void:
	# "Permits a response", read to the end: a spell with nothing legal to
	# aim at cannot be cast, so holding it is not holding a response.
	# Without this a Counterspell in hand would have stopped every window
	# of every turn — a click that carries no decision, which is the
	# thing the automatic pass exists to remove.
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(1)
	_summon("Island", 0)
	_summon("Island", 0)
	_hold("Counterspell")
	g.priority_player = 0
	assert_false(screen._could_respond(0), "UU up, nothing to counter")
	assert_true(screen._auto_pass_applies())
	# ...until there IS something on the chain.
	var bolt := _hold("Lightning Bolt", 1)
	bolt.zone = Mtg.Zone.STACK
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.card = bolt
	item.controller = 1
	g.stack.append(item)
	g.priority_player = 0
	assert_true(screen._could_respond(0), "now the Counterspell has a target")
	assert_false(screen._auto_pass_applies())
	g.stack.clear()


func test_a_giant_growth_with_no_creature_in_play_is_no_response() -> void:
	var g := _window(1, Mtg.Step.END)
	_summon("Forest", 0)
	_hold("Giant Growth")
	g.priority_player = 0
	assert_false(screen._could_respond(0), "no creature anywhere to grow")
	assert_true(screen._auto_pass_applies())
	_summon("Gray Ogre", 1)
	g.priority_player = 0
	assert_true(screen._could_respond(0), "theirs will do — the spec is any creature")
	assert_false(screen._auto_pass_applies())


func test_a_tapped_tap_ability_is_not_handy() -> void:
	# Manual p.112: "able to" means "a fast effect HANDY and the mana to
	# use it". An attacker with a {T} ability is tapped by attacking, and
	# a summoning-sick Tim cannot tap at all — neither is handy, and
	# neither holds a window.
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(1)
	var tim := _summon("Prodigal Sorcerer", 0)
	g.priority_player = 0
	assert_true(screen._could_respond(0), "an untapped Tim is a response")
	assert_false(screen._auto_pass_applies())
	tim.tapped = true
	g.priority_player = 0
	assert_false(screen._could_respond(0), "a tapped one is not")
	assert_true(screen._auto_pass_applies())
	tim.tapped = false
	tim.summoning_sick = true
	g.priority_player = 0
	assert_false(screen._could_respond(0), "nor a summoning-sick one")
	assert_true(screen._auto_pass_applies())
	assert_false(screen._has_affordable_fast_effect(0),
		"the Done-order predicate agrees")


# ================================================= the standing orders --

func test_a_done_order_that_travels_into_a_window_rests_there() -> void:
	# Manual p.116's Done: the duel runs on "until something happens
	# that requires your attention". Done pressed IN the attacker window
	# is the pass out of it; the order then carries the duel through the
	# opponent's blocks — and the blocker window, with a Bolt still in
	# hand, is where it must come to rest.
	var g := _window(0, Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(0)
	_bolt_and_a_mountain()
	g.priority_player = 0
	screen._order_done_advance()
	_pump(40)
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS,
		"stopped in %s" % Mtg.step_name(g.current_step()))
	assert_false(g.awaiting_blockers, "the (empty) block is in")
	assert_eq(g.priority_player, 0, "and the window is yours")
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE, "the order is spent")
	# (The order itself came to rest one moment earlier, at the opponent's
	# owed block — exception (1) reads every held declaration as required.
	# What keeps the duel here is the automatic pass making the same test
	# the order would have: a window, and a Bolt that can answer it.)
	_pump(20)
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS,
		"and the automatic pass does not eat the arrival")
	assert_eq(g.priority_player, 0)


func test_a_done_order_given_in_a_window_is_the_pass_out_of_it() -> void:
	# The order was given HERE, so this window is not one it travelled
	# into: the stop reason is empty and the pass goes through.
	var g := _window(1, Mtg.Step.DECLARE_BLOCKERS)
	_attack_with_an_ogre(1)
	_bolt_and_a_mountain()
	g.priority_player = 0
	screen._advance_mode = DuelScreen.Advance.DONE
	screen._advance_from = screen._phase_key()
	screen._advance_moved = false
	assert_eq(screen._advance_stop_reason(), "")
	screen._advance_moved = true
	assert_eq(screen._advance_stop_reason(), "blockers are declared",
		"...and the same window, arrived at, is a stop")
	screen._cancel_advance()


func test_a_run_to_stops_for_a_declared_attack_it_can_answer() -> void:
	# `Duel.hlp`, topic **Phase Bar**, exception (2), verbatim: *"if your
	# opponent does something that requires or permits a response (casts
	# a spell, uses a fast effect, DECLARES AN ATTACK, or whatever),
	# movement through phases stops so that you have a chance to
	# respond."*
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(1)
	_bolt_and_a_mountain()
	g.priority_player = 0
	screen._advance_mode = DuelScreen.Advance.RUN_TO
	screen._run_to = [PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 0]
	screen._advance_moved = true
	assert_eq(screen._advance_stop_reason(), "attackers are declared")
	screen.game.players[0].hand.clear()
	assert_eq(screen._advance_stop_reason(), "",
		"an attack you cannot answer permits no response")
	screen._cancel_advance()


# ======================================================= the Situation Bar --

func test_the_bar_asks_the_famous_question_in_your_own_windows() -> void:
	# The frame the original uses on every fast-effects round, filled
	# with `@PROMPT_CHECKFEPHASE`'s own names — on YOUR turn too now.
	var g := _window(0, Mtg.Step.DECLARE_ATTACKERS)
	_attack_with_an_ogre(0)
	g.priority_player = 0
	assert_eq(screen._status_message(), "Fast Effects?...Assign Attackers")
	_on_to(Mtg.Step.DECLARE_BLOCKERS)
	assert_eq(screen._status_message(), "Fast Effects?...Assign Blockers")


func test_the_beginning_of_combat_is_announced_not_asked_for() -> void:
	# The owner's playtest (2026-09-08): a Stop at the start of your own
	# combat read "Choose Attackers" — an instruction you could not yet
	# follow; the lineup is asked for one step later. *"So the first
	# message should be modified to only announcement: 'Begin combat'."*
	var g := _window(0, Mtg.Step.COMBAT_BEGIN)
	g.priority_player = 0
	assert_eq(screen._status_message(), "Begin Combat", "your own turn, the stop holding")
	_window(1, Mtg.Step.COMBAT_BEGIN)
	assert_eq(screen._status_message(), "Fast Effects?...Begin Combat",
		"their turn: the question, filled with the same name")
	g = _window(0, Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	assert_eq(screen._status_message(), "Combat phase: Choose attackers.",
		"and only then the instruction")


func test_the_bar_asks_for_the_lineup_while_it_is_owed() -> void:
	# `@PROMPT_MAIN` entries 5 and 8, UIStrings.txt:1063 — the instruction,
	# not the question. The attackers line used to be given AFTER the
	# lineup was in as well, which asked for an attack twice.
	var g := _window(0, Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	assert_eq(screen._status_message(), "Combat phase: Choose attackers.")
	_window(1, Mtg.Step.DECLARE_BLOCKERS)
	g.awaiting_blockers = true
	assert_eq(screen._status_message(), "Combat phase: Choose blockers.",
		"which the frame used to hide")


func test_the_damage_steps_take_the_originals_names() -> void:
	# `@PROMPT_SPECIALFEPHASE`, UIStrings.txt:1039 — the sibling table
	# the original fills the same blank with. These used to answer
	# "Main Phase".
	# The beginning of combat is an announcement, not an instruction: the
	# owner's playtest read "Choose Attackers" there as a step too early
	# (*"the first message should be modified to only announcement:
	# 'Begin combat'"*).
	assert_eq(DuelScreen._fe_phase_name(Mtg.Step.COMBAT_BEGIN), "Begin Combat")
	assert_eq(DuelScreen._fe_phase_name(Mtg.Step.FIRST_STRIKE_DAMAGE), "Damage Dealing")
	assert_eq(DuelScreen._fe_phase_name(Mtg.Step.COMBAT_DAMAGE), "Damage Dealing")
	assert_eq(DuelScreen._fe_phase_name(Mtg.Step.COMBAT_END), "End of Combat")
	assert_eq(DuelScreen._fe_phase_name(Mtg.Step.DECLARE_ATTACKERS), "Assign Attackers",
		"the two the first table names are as they were")


# ============================================== the whole of the report --

func test_a_bolt_is_cast_at_an_attacker_and_kills_it() -> void:
	# End to end, through the engine the screen drives: their Ogre
	# attacks, the window holds, the Bolt is paid for from the Mountain
	# and aimed at the attacker, the AI seat gets its say, and the Ogre
	# is in the graveyard before blockers are ever asked for.
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	var ogre := _attack_with_an_ogre(1)
	var bolt := _bolt_and_a_mountain()
	var mountain: CardInstance = null
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Mountain":
			mountain = inst
	g.priority_player = 0
	screen._refresh()
	assert_eq(g.priority_player, 0, "the window held for the Bolt")
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.tap_for_mana(0, mountain, 0), "")
	assert_eq(g.cast_spell(0, bolt, [TargetRef.card(ogre)]), "",
		"an instant is legal in the attacker fast-effects round")
	assert_eq(g.stack.size(), 1, "the Bolt is on the chain")
	_pump(40)
	assert_true(g.stack.is_empty(), "...and has resolved")
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD, "the attacker is dead")
	assert_false(g.combat.attackers.has(ogre.id) and ogre.zone == Mtg.Zone.BATTLEFIELD)
