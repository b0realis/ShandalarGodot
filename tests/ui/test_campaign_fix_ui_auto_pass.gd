extends GutTest
## THE AUTOMATIC PASS, THE DONE ORDER AND THE ACTIONABLE LIGHTS against the
## abilities a seat holds (whole-game campaign, fix-ui: w5-4, w5-7, w5-8,
## w5-9, w5-10).
##
## w5-4 — the floated-mana stop ([method DuelScreen._has_affordable_fast_effect])
## priced ABILITIES through `can_afford_cost`, whose plan taps untapped
## lands, and counted an ability that costs no mana at all as "prepared":
## a Shivan Dragon beside one open Mountain, an untapped Prodigal Sorcerer
## or a Mogg Fanatic held every quiet step of both turns, and Return (the
## manual's Done) was refused on the spot. The documented rule is the
## FLOATING pool.
##
## w5-10 — the light, the response test and the floated-mana stop read the
## mana and nothing else: a Goblin Bombardment with no creature to
## sacrifice, a Hand of Justice with no white creature to tap, were lit and
## held windows the engine then refused. Now they read the engine's whole
## verdict, `MtgGame.activation_refusal`.
##
## w5-7 — "any player may activate" / "only your opponents may" abilities
## on the OTHER seat's permanent were unreachable (the click gate swallowed
## them, nothing lit), and the seat's own Clergy of the Holy Nimbus — whose
## ability only an opponent may use — was lit.
##
## w5-8 — the 1997 damage-prevention window (fifth) held the human every
## time, even with nothing of theirs usable in it; it now holds only while
## they hold a prevention / regeneration effect they could use.
##
## w5-9 — an AI attack into a board that cannot block asked for blockers;
## the empty declaration now makes itself, with a moment on the bar.

var screen: DuelScreen
var _saved_stops: Variant = null
var _next_id := 931000


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]   # seat 1 is the computer
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()


func after_each() -> void:
	CardPacks.set_enabled("pack-9", false)
	CardPacks.set_enabled("pack-2", false)
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


# ---------------------------------------------------------------- fixture --

## [param active]'s [param step], the human holding priority, an empty
## table and empty hands — every change under `_probing`, so no refresh
## passes the window before it is asked about.
func _window(active: int, step: int) -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._passes = 0 if active == 0 else 1
	g.stack.clear()
	for p in g.players:
		p.battlefield.clear()
		p.hand.clear()
		p.mana_pool.clear()
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	screen._ai_pending = true    # the computer's beat waits on the test
	return g


func _summon(card_name: String, seat: int) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "%s is in the pool" % card_name)
	var inst := CardInstance.new(data, _next_id, seat)
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
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "%s is in the pool" % card_name)
	var inst := CardInstance.new(data, _next_id, seat)
	_next_id += 1
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[seat].hand.append(inst)
	return inst


# ================================================= w5-4: the floating pool --

func test_an_ability_payable_only_from_an_untapped_land_does_not_hold_a_quiet_step() -> void:
	_window(0, Mtg.Step.UPKEEP)
	_summon("Mountain", 0)
	_summon("Shivan Dragon", 0)
	assert_false(screen._has_affordable_fast_effect(0),
		"nothing floated: the Done/auto-pass rule reads the floating pool")
	assert_true(screen._auto_pass_applies(), "the quiet upkeep runs itself")
	var g := _window(1, Mtg.Step.DRAW)
	_summon("Mountain", 0)
	_summon("Shivan Dragon", 0)
	g.priority_player = 0
	assert_true(screen._auto_pass_applies(), "their quiet draw step runs itself too")


func test_floated_mana_for_an_ability_still_holds_the_step() -> void:
	var g := _window(0, Mtg.Step.UPKEEP)
	_summon("Shivan Dragon", 0)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_true(screen._has_affordable_fast_effect(0),
		"{R} floated for the firebreathing IS a prepared fast effect")
	assert_false(screen._auto_pass_applies(), "and the step waits for it")


func test_an_ability_that_costs_no_mana_is_not_a_prepared_effect() -> void:
	var g := _window(1, Mtg.Step.UPKEEP)
	_summon("Prodigal Sorcerer", 0)
	g.priority_player = 0
	assert_false(screen._has_affordable_fast_effect(0), "a free {T} is nothing floated")
	assert_true(screen._auto_pass_applies(), "their quiet upkeep runs itself")
	_window(1, Mtg.Step.UPKEEP)
	_summon("Mogg Fanatic", 0)
	assert_true(screen._auto_pass_applies(), "nor is a free sacrifice")


func test_a_free_ability_is_still_a_response_in_a_window_for_one() -> void:
	# The other half of the contract, untouched: where a window IS for a
	# response (the opponent's end step), a free {T} still holds it.
	var g := _window(1, Mtg.Step.END)
	var sorcerer := _summon("Prodigal Sorcerer", 0)
	g.priority_player = 0
	assert_true(screen._could_respond(0), "a ping is a response")
	assert_false(screen._auto_pass_applies(), "their end step waits for it")
	assert_eq(screen._highlight_for(sorcerer), MiniCard.Highlight.OPTIONAL, "and it is lit")


func test_return_passes_with_an_untapped_sorcerer_on_the_table() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_summon("Prodigal Sorcerer", 0)
	var before := [g.current_step(), g.priority_player, g._passes]
	screen._on_pass_turn()
	assert_ne([g.current_step(), g.priority_player, g._passes], before,
		"Done passes priority at least once (prompt: %s)" % screen._prompt_label.text)


# ========================================= w5-10: costs that are not mana --

func test_an_ability_whose_sacrifice_cannot_be_paid_is_neither_lit_nor_a_response() -> void:
	var g := _window(1, Mtg.Step.END)
	var bombardment := _summon("Goblin Bombardment", 0)
	g.priority_player = 0
	assert_false(screen._can_act_on(bombardment), "no creature to sacrifice")
	assert_eq(screen._highlight_for(bombardment), MiniCard.Highlight.NONE)
	assert_false(screen._could_respond(0), "and it is no response")
	assert_true(screen._auto_pass_applies(), "their end step runs itself")
	_summon("Grizzly Bears", 0)
	assert_true(screen._can_act_on(bombardment), "control: a creature to sacrifice")
	assert_true(screen._could_respond(0))
	assert_false(screen._auto_pass_applies())


func test_an_ability_that_taps_another_permanent_needs_one() -> void:
	CardPacks.set_enabled("pack-2", true)      # Hand of Justice, Fallen Empires
	var g := _window(0, Mtg.Step.MAIN1)
	var hand := _summon("Hand of Justice", 0)
	_summon("Plains", 0)
	_summon("Plains", 0)
	g.priority_player = 0
	assert_false(screen._can_act_on(hand),
		"no untapped white creature to tap besides it: refused by the engine")
	assert_ne(g.activation_refusal(0, hand, 0), "", "the engine's own verdict")


func test_the_engine_verdict_prices_floating_and_untapped_mana() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var shivan := _summon("Shivan Dragon", 0)
	assert_true(MtgGame.is_unpaid_refusal(g.activation_refusal(0, shivan, 0)), "no mana at all")
	_summon("Mountain", 0)
	assert_eq(g.activation_refusal(0, shivan, 0), "", "an untapped Mountain pays it")
	assert_true(MtgGame.is_unpaid_refusal(g.activation_refusal(0, shivan, 0, {}, true)),
		"...but nothing is floating")
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	assert_eq(g.activation_refusal(0, shivan, 0, {}, true), "", "floated {R} pays it")


# ======================================= w5-7: abilities a card hands out --

func test_the_opponents_clergy_is_lit_and_its_ability_offered() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var clergy := _summon("Clergy of the Holy Nimbus", 1)
	_summon("Plains", 0)
	g.players[0].mana_pool.add(Mtg.ManaColor.W, 1)
	screen._refresh()
	assert_eq(screen._highlight_for(clergy), MiniCard.Highlight.OPTIONAL,
		"an ability seat 0 may activate right now is lit")
	screen._on_card_clicked(clergy)
	assert_true(screen._ability_menu.visible, "the click opens its menu")
	var mana_count := clergy.cur_mana_abilities.size()
	assert_false(screen._ability_menu.is_item_disabled(
		screen._ability_menu.get_item_index(mana_count)), "its ability is offered")
	screen._ability_menu.hide()
	screen._on_ability_chosen(mana_count)
	assert_eq(screen._pending_pid, 0, "the activation is seat 0's")
	assert_eq(g.stack.size(), 1, "and goes on the chain (prompt: %s)" % screen._prompt_label.text)


func test_your_own_clergy_is_not_lit_and_its_ability_is_greyed() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var clergy := _summon("Clergy of the Holy Nimbus", 0)
	g.players[0].mana_pool.add(Mtg.ManaColor.W, 1)
	assert_false(screen._can_act_on(clergy), "only your opponents may activate it")
	screen._open_ability_menu(clergy)
	var at := screen._ability_menu.get_item_index(clergy.cur_mana_abilities.size())
	assert_true(screen._ability_menu.is_item_disabled(at), "greyed in your own menu")
	screen._ability_menu.hide()


func test_an_any_player_ability_on_their_permanent_is_a_response_and_their_mana_is_not_yours() -> void:
	var g := _window(1, Mtg.Step.END)
	var efreet := _summon("Ifh-Bíff Efreet", 1)
	var forest := _summon("Forest", 1)
	g.priority_player = 0
	assert_false(screen._could_respond(0), "control: nothing to pay {G} with")
	_summon("Forest", 0)
	assert_true(screen._could_respond(0),
		"any player may activate the Efreet, and a Forest of ours pays it")
	assert_true(screen._can_act_on(efreet), "lit for the seat holding priority")
	screen._on_card_clicked(forest)
	assert_false(screen._ability_menu.visible, "their Forest is not ours to tap")
	screen._open_ability_menu(efreet)
	screen._ability_menu.hide()
	assert_true(bool(screen._ability_menu.get_meta("foreign", false)))


# ============================== w5-8: the 1997 damage-prevention window --

## The computer's Bolt at the human, under the fifth rules, waiting in the
## damage-prevention window with the human holding priority. The computer
## holds a Healing Salve so the window opens whatever the engine's rule for
## opening it is — the screen's decision must not depend on that hand.
func _bolted_in_the_window() -> MtgGame:
	var g := _window(1, Mtg.Step.MAIN1)
	g.rules.set_edition("fifth")
	g.priority_player = 1
	_hold("Healing Salve", 1)
	var bolt := _hold("Lightning Bolt", 1)
	g.players[1].mana_pool.add(Mtg.ManaColor.R, 1)
	# The screen's own drivers are held (its re-entrancy guard) while the
	# engine is walked to the window, so nothing passes it before it is
	# asked about.
	screen._advancing = true
	assert_eq(g.cast_spell(1, bolt, [TargetRef.player(0)]), "")
	for _i in 6:
		if g.awaiting_damage_prevention or g.stack.is_empty():
			break
		g.pass_priority(g.priority_player)
	screen._advancing = false
	assert_true(g.awaiting_damage_prevention, "control: the window is open")
	g.priority_player = 0
	return g


func test_a_window_the_human_cannot_use_is_passed_for_them() -> void:
	var g := _bolted_in_the_window()
	assert_eq(screen._required_action_reason(), "", "nothing of ours is usable in it")
	assert_true(screen._auto_pass_applies(), "the window passes itself")
	# A Bolt in hand with a Mountain is no prevention effect.
	_hold("Lightning Bolt", 0)
	_summon("Mountain", 0)
	g.priority_player = 0
	assert_false(screen._could_respond(0), "the window takes prevention only")
	assert_true(screen._auto_pass_applies())


func test_a_window_the_human_can_use_holds() -> void:
	var g := _bolted_in_the_window()
	_summon("Circle of Protection: Red", 0)
	_summon("Plains", 0)
	g.priority_player = 0
	assert_true(screen._could_respond(0), "the Circle can take the Bolt's damage")
	assert_eq(screen._required_action_reason(), "damage prevention is waiting")
	assert_false(screen._auto_pass_applies(), "the window waits for the player")


func test_a_prevention_instant_in_hand_holds_the_window() -> void:
	var g := _bolted_in_the_window()
	_hold("Healing Salve", 0)
	_summon("Plains", 0)
	g.priority_player = 0
	assert_false(screen._auto_pass_applies(), "the Salve's prevention mode fits the window")


# ========================================= w5-9: the empty block declares --

func _their_attack(attacker: String, mine: Array) -> MtgGame:
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	var a := _summon(attacker, 1)
	for n in mine:
		_summon(n, 0)
	g._probing = true
	g.combat.attackers[a.id] = true
	a.tapped = true
	g.recalculate()
	g._probing = false
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS))
	screen._refresh()
	return g


func test_nothing_to_block_with_declares_no_blockers() -> void:
	var g := _their_attack("Grizzly Bears", [])
	assert_false(g.awaiting_blockers, "the empty block was declared for the player")
	assert_ne(screen.mode, DuelScreen.Mode.BLOCKERS)


func test_ground_creatures_against_a_flyer_declare_no_blockers() -> void:
	var g := _their_attack("Mahamoti Djinn", ["Grizzly Bears"])
	assert_false(g.awaiting_blockers, "a Grizzly Bears cannot block a flyer")


func test_a_creature_that_can_block_still_asks() -> void:
	var g := _their_attack("Grizzly Bears", ["Grizzly Bears"])
	assert_true(g.awaiting_blockers, "a real choice is the player's")
	assert_eq(screen.mode, DuelScreen.Mode.BLOCKERS)


func test_a_stop_on_the_blockers_icon_still_asks() -> void:
	screen.stops.set_marked(PhaseStops.Half.OPPONENTS, PhaseStops.Bar.COMBAT,
		CombatBar.Slot.DECLARE_BLOCKERS, true)
	var g := _their_attack("Grizzly Bears", [])
	assert_true(g.awaiting_blockers, "a Stop means it cannot pass automatically")
	assert_eq(screen.mode, DuelScreen.Mode.BLOCKERS)
