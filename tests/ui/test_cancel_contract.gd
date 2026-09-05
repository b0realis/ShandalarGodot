extends GutTest
## THE BUTTON CONTRACT and the CANCEL LADDER — `docs/duel-todo.md` §3.1,
## §3.2 and §6.11.
##
## `Duel.hlp`, topic **Situation Bar**: *"At the rightmost end of this bar
## is a **Done** button, a **Cancel** button, or both, depending on the
## situation… Esc is just like Cancel · Return has the same effect as Done
## · Spacebar: if there is only one button, pressing this is the same as
## clicking that button."*
##
## Three separate items, one contract, so they are pinned together: which
## buttons the bar shows, what each key does, and what Escape peels off
## first.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _give(card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[0].hand.append(inst)
	return inst


func _put(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	return inst


## Start a real targeting session for a spell that wants several targets:
## Sylvan Paradise is "ONE OR MORE target creatures", so its slot stays
## open after every pick.
##
## It used to be Pyrotechnics, and §6.14 is why it no longer can be: a
## DIVIDED slot is the one place the original does not deselect. Its own
## rule is pinned below, in [method test_a_division_adds_a_point_instead_of_deselecting].
func _aim_many() -> Array:
	var victims: Array = [
		_put(1, "Grizzly Bears"), _put(1, "Hill Giant"), _put(1, "Sea Serpent")]
	screen.game.recalculate()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.G, 1)
	screen._click_hand_card(_give("Sylvan Paradise"))
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the picker opened")
	return victims


func _picked() -> Array:
	var out: Array = []
	for group in screen._pending_groups:
		for ref in group:
			out.append(ref.instance_id)
	return out


# ------------------------------------------------- §3.1 deselect / replace --

func test_clicking_a_chosen_target_again_takes_it_back() -> void:
	# It used to refuse the click ("Is a target, can't target again"), so a
	# misclick cost the whole cast — on a screen that had no Cancel button
	# to recover with either. s30 `selectTarget`, duel.go:2248-2266.
	var victims := _aim_many()
	screen._on_card_clicked(victims[0])
	screen._on_card_clicked(victims[1])
	assert_eq(_picked(), [victims[0].id, victims[1].id])
	screen._on_card_clicked(victims[0])
	assert_eq(_picked(), [victims[1].id], "the first pick came back off")
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "still aiming")


func test_taking_a_target_back_leaves_the_others_alone() -> void:
	var victims := _aim_many()
	for v in victims:
		screen._on_card_clicked(v)
	screen._on_card_clicked(victims[1])
	assert_eq(_picked(), [victims[0].id, victims[2].id])


func test_a_target_taken_back_can_be_picked_again() -> void:
	var victims := _aim_many()
	screen._on_card_clicked(victims[0])
	screen._on_card_clicked(victims[0])
	assert_eq(_picked(), [])
	screen._on_card_clicked(victims[0])
	assert_eq(_picked(), [victims[0].id])


# ------------------------------------------------------ §3.2 escape ladder --

func test_escape_drops_the_picks_before_it_drops_the_spell() -> void:
	# THE RUNG THAT WAS MISSING. s30 handleEscape (duel.go:1329-1350)
	# clears the selected targets and only leaves targeting on the NEXT
	# press; ours threw the whole pending cast away on the first.
	var victims := _aim_many()
	screen._on_card_clicked(victims[0])
	screen._on_card_clicked(victims[1])
	screen._on_escape()
	assert_eq(_picked(), [], "the picks went")
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the spell stayed")
	assert_not_null(screen._pending_card)
	screen._on_escape()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "the second press abandons it")
	assert_null(screen._pending_card)


func test_escape_peels_the_graveyard_view_first() -> void:
	var victims := _aim_many()
	screen._on_card_clicked(victims[0])
	screen._open_graveyard(0)
	screen._on_escape()
	assert_false(screen.graveyard_is_open(), "the view closed")
	assert_eq(_picked(), [victims[0].id], "and the picks survived it")


func test_escape_closes_the_x_question_instead_of_the_duel() -> void:
	# The X dialog is an OriginalDialog, not a Popup, so Escape used to
	# sail straight past it into _on_cancel — which did nothing, because
	# the mode is still NORMAL while the question is up. The dialog simply
	# would not close.
	screen._click_hand_card(_give("Fireball"))
	assert_not_null(screen._x_dialog, "Fireball asks for X first")
	screen._on_escape()
	assert_null(screen._x_dialog, "the question closed")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_escape_on_a_quiet_board_does_nothing() -> void:
	# "with nothing open, Escape does nothing (it never leaves the duel)".
	var turn := screen.game.turn_number
	var step := screen.game.current_step()
	screen._on_escape()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_eq(screen.game.turn_number, turn)
	assert_eq(screen.game.current_step(), step)


# --------------------------------------------------- §6.11 the two buttons --

func test_the_bar_carries_done_and_a_cancel() -> void:
	# `@DIALOGBUTTONS` (UIStrings.txt:172) / `@BUTTONLABELS` (:178) — the
	# original ships exactly three button words and the bar uses two.
	assert_not_null(screen._cancel_button)
	assert_eq(screen._cancel_button.text, "Cancel")
	assert_eq(screen._pass_button.text, "Done")
	assert_eq(screen._cancel_button.get_parent(),
		screen._pass_button.get_parent(), "both live on the Situation Bar")


func test_cancel_appears_only_when_there_is_something_to_cancel() -> void:
	screen._refresh()
	assert_false(screen._cancel_button.visible, "a quiet board shows Done alone")
	_aim_many()
	screen._refresh()
	assert_true(screen._cancel_button.visible, "a spell in flight can be cancelled")
	screen._on_escape()
	screen._on_escape()
	screen._refresh()
	assert_false(screen._cancel_button.visible)


func test_cancel_appears_over_the_graveyard_view() -> void:
	screen._open_graveyard(0)
	screen._refresh()
	assert_true(screen._cancel_button.visible)
	screen._close_graveyard()
	screen._refresh()
	assert_false(screen._cancel_button.visible)


func test_the_cancel_button_and_the_escape_key_are_one_action() -> void:
	# "Esc is just like Cancel" — so they must be the same door, not two
	# doors that happen to agree today.
	var victims := _aim_many()
	screen._on_card_clicked(victims[0])
	screen._cancel_button.pressed.emit()
	assert_eq(_picked(), [], "the button peeled the same one layer")
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)


func test_the_spacebar_acts_only_while_one_button_is_showing() -> void:
	# "Spacebar: if there is only one button, pressing this is the same as
	# clicking that button." Done is always on the bar, so Space is Done —
	# until Cancel joins it and the key becomes ambiguous.
	assert_false(screen._can_cancel(), "one button")
	_aim_many()
	assert_true(screen._can_cancel(), "two buttons: Space has no single meaning")


func test_return_reaches_done_in_every_mode() -> void:
	# "Return has the same effect as Done." It used to dead-end in
	# targeting, discard and damage division, because _on_pass_turn returns
	# at once unless the mode is NORMAL — so the one keystroke the manual
	# names could not answer the prompts that most need answering.
	var victims := _aim_many()
	screen._on_card_clicked(victims[0])
	_send_key(KEY_ENTER)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL,
		"Done closed the variable slot and submitted the spell")


func test_return_does_not_reach_past_an_open_dialog() -> void:
	# Return used to fast-forward several priority windows with the X
	# question still on screen.
	screen._click_hand_card(_give("Fireball"))
	var turn := screen.game.turn_number
	_send_key(KEY_ENTER)
	assert_not_null(screen._x_dialog, "the question is still up")
	assert_eq(screen.game.turn_number, turn, "and the duel did not move")


func _send_key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	screen._unhandled_key_input(ev)


# ---------------- §6.11 the fork Cancel used to walk straight through ------

## Declare two attackers, the way a player does — one click each through
## [method DuelScreen._toggle_attacker]. The step is set first because
## `_refresh` drops a declaration made outside the declare-attackers step
## as stale, the moment `_toggle_attacker` calls it (§3.5).
func _declare_two_attackers() -> Array:
	var g: MtgGame = screen.game
	var one := _put(g.active_player, "Savannah Lions")
	var two := _put(g.active_player, "Grizzly Bears")
	one.summoning_sick = false
	two.summoning_sick = false
	g.recalculate()
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	screen.mode = DuelScreen.Mode.ATTACKERS
	screen._toggle_attacker(one)
	screen._toggle_attacker(two)
	assert_eq(screen._selected_attackers.size(), 2, "both are declared")
	return [one, two]


func test_escape_takes_back_a_declaration_that_is_revocable() -> void:
	# The modern default, and the half that already worked.
	assert_true(screen.game.rules.attackers_revocable)
	_declare_two_attackers()
	assert_true(screen._can_cancel(), "there is a declaration to cancel")
	screen._on_escape()
	assert_eq(screen._selected_attackers, [], "and Escape took it back")


func test_escape_does_not_walk_around_the_1997_attackers_fork() -> void:
	# THE DEFECT, found by the fifth-edition audit (2026-09-02) and
	# ledgered rather than fixed. `_toggle_attacker` refuses to un-declare
	# ONE attacker under `attackers_revocable = false` (manual p.86 — the
	# prompt says "attackers are final") while `_on_cancel` cleared the
	# WHOLE list, so Escape un-declared every one of them and the fork had
	# a door straight through it.
	#
	# The rule was already written down: [method DuelScreen._can_cancel]'s
	# own doc comment says the declarations are cancellable *"because ours
	# are revocable up to Done (`RulesOptions.attackers_revocable`)"*. Only
	# the code did not read the flag that sentence names.
	screen.game.rules.attackers_revocable = false
	var declared := _declare_two_attackers()
	screen._on_escape()
	assert_eq(screen._selected_attackers.size(), 2,
		"a named attacker is committed — Escape is not a back door")
	assert_true(screen._selected_attackers.has(declared[0].id))
	assert_true(screen._selected_attackers.has(declared[1].id))
	# "Esc is just like Cancel", so the BUTTON is the same door and must
	# give the same answer — and the bar must not offer it at all.
	screen._refresh()
	assert_false(screen._can_cancel(), "nothing here can be cancelled")
	assert_false(screen._cancel_button.visible)
	screen._cancel_button.pressed.emit()
	assert_eq(screen._selected_attackers.size(), 2,
		"and pressing it anyway changes nothing")


func test_blockers_stay_revocable_under_the_attacker_fork() -> void:
	# The fork is about ATTACKERS and nothing else: manual p.86 is about
	# the attack declaration, and a half-made BLOCK is still the
	# *"situation"* `Duel.hlp` makes the Cancel button conditional on.
	screen.game.rules.attackers_revocable = false
	screen.mode = DuelScreen.Mode.BLOCKERS
	screen._block_map = {1: 2}
	assert_true(screen._can_cancel(), "a half-made block can still be undone")
	screen._on_escape()
	assert_eq(screen._block_map, {})


# ---------------- §1.3 the one popup that DOES have a way out (2026-09-02) --

func test_a_cost_question_can_be_withdrawn_with_escape() -> void:
	# Ashnod's Altar: one click asked "Select creature to sacrifice." and
	# the only ways out were a corpse or a concession — no `Cancel.` line
	# (a cost's sacrifice is not optional), no Escape, no engine door.
	# Nothing is paid while a cost is still being assembled (CR 601.2h),
	# so the ACTION can be retracted (CR 728.1): MtgGame.cancel_choice,
	# reached from here by Escape and by the bar's Cancel.
	var g: MtgGame = screen.game
	var me: int = g.priority_player
	var altar := _put(me, "Ashnod's Altar")
	var bear := _put(me, "Grizzly Bears")
	assert_eq(g.tap_for_mana(me, altar), "")
	assert_not_null(g.awaiting_choice, "held on the sacrifice")
	assert_true(g.awaiting_choice.is_cost)
	# Headless builds no overlay node; stand one in, as the prompts suite does.
	screen._choice_overlay = Control.new()
	screen.add_child(screen._choice_overlay)
	screen._refresh()
	assert_true(screen._can_cancel(), "a cost question has a way out")
	assert_true(screen._cancel_button.visible, "and the bar offers it")
	_send_key(KEY_ESCAPE)
	assert_null(g.awaiting_choice, "the question is withdrawn")
	assert_null(screen._choice_overlay, "and the overlay came down with it")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "nothing was sacrificed")
	assert_false(altar.tapped, "nothing was tapped")
	assert_eq(g.players[me].mana_pool.total(), 0, "nothing was made")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_eq(g.pass_priority(me), "", "and the duel plays on")


func test_an_adverse_question_still_has_no_way_out() -> void:
	# The exception is the player's OWN cost hold and nothing else: a
	# resolution's question must be answered (§1.3 — see test_duel_prompts'
	# test_the_overlay_cannot_be_escaped_only_answered), and so must a cost
	# question put to the OPPONENT ("of an opponent's choice").
	var g: MtgGame = screen.game
	var choice := PlayerChoice.new(PlayerChoice.Kind.CARD, 0, "Select a card.")
	choice.is_cost = true
	choice.adverse = true
	g.awaiting_choice = choice
	screen._choice_overlay = Control.new()
	screen.add_child(screen._choice_overlay)
	assert_false(screen._can_cancel(), "the opponent's question is theirs to answer")
	_send_key(KEY_ESCAPE)
	assert_not_null(g.awaiting_choice, "Escape does not withdraw it")
	assert_not_null(screen._choice_overlay)
	screen._choice_overlay.queue_free()
	screen._choice_overlay = null
	g.awaiting_choice = null


# --------------- §3.2 the rung the chain filled by itself (2026-09-02) --

## One spell of [param owner]'s onto the chain, bypassing priority — the
## same surgery as tests/ui/test_auto_target.gd's `_chain`.
func _chain_spell(owner: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, owner)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.STACK
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.card = inst
	item.controller = owner
	item.effects = inst.data.spell_effects.duplicate()
	item.description = "%s casts %s" % [
		g.players[owner].player_name, inst.data.card_name]
	g.stack.append(item)
	return inst


func test_escape_reaches_cancel_past_a_slot_the_chain_filled() -> void:
	# THE LONE COUNTER-TARGET (§3.3) is a pick the chain made, not the
	# player: clearing it re-runs the chain, which takes it straight
	# back. So for a spell whose FIRST slot auto-fills and whose second is
	# the player's, the "drop the picks" rung was true forever, and
	# Escape could never reach _on_cancel.
	var g: MtgGame = screen.game
	var me: int = g.priority_player
	var foe: int = g.opponent_of(me)
	_chain_spell(foe, "Lightning Bolt")
	_put(foe, "Grizzly Bears")
	var counter := CardInstance.new(CardRegistry.get_card("Counterspell"),
		g._next_instance_id, me)
	g._next_instance_id += 1
	g._instances[counter.id] = counter
	counter.zone = Mtg.Zone.HAND
	g.players[me].hand.append(counter)
	# No card in the pool wants a spell AND a creature, so the slots are
	# laid by hand, exactly as _build_target_slots lays them.
	screen._pending_card = counter
	screen._pending_pid = me
	screen._pending_ability_index = -1
	screen._pending_slots = [
		{"spec": TargetSpec.spell(), "min": 1, "max": 1, "divided": 0},
		{"spec": TargetSpec.creature(), "min": 1, "max": 1, "divided": 0}]
	screen._pending_groups = [[], []]
	screen._pending_slot = 0
	screen._advance_pending()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_eq(screen._pending_slot, 1,
		"the lone spell was taken for the player; the creature is theirs")
	screen._on_escape()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL,
		"nothing of the player's to drop, so Escape abandons the spell")
	assert_null(screen._pending_card)
	g.stack.clear()


# ---------------- the table under a window is not live (2026-09-02) --

## The engine's clock: anything a leaked Done or pass would move.
func _clock() -> Array:
	var g: MtgGame = screen.game
	return [g.turn_number, g.current_step(), g.priority_player, g._passes]


func test_return_and_space_do_not_reach_past_the_duels_own_windows() -> void:
	# The concede question is an OriginalDialog OUTSIDE _modal_open() —
	# its own OK must keep answering it (see _dialogs_open) — and Return
	# there handed the duel a standing Done order that ran the phases on
	# under the window; Space did the same. No dialog button holds focus,
	# so neither key was ever the window's own.
	screen._ask_to_concede()
	assert_not_null(screen._concede_dialog)
	var before := _clock()
	_send_key(KEY_ENTER)
	_send_key(KEY_SPACE)
	assert_eq(_clock(), before, "the duel did not move")
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE, "no standing order")
	assert_not_null(screen._concede_dialog, "and the question is still up")
	screen._concede_dialog.dismiss()


func test_a_centre_popup_owns_the_table_as_well_as_the_keyboard() -> void:
	# The X question is up for one Fireball; a click on a second card in
	# hand used to start ANOTHER cast under it, swapping _pending_card out
	# from under the window — whose OK then read the wrong card, or a
	# null one. The territory's `Go to:` orders passed priority under it
	# too. The board under a centre popup is not live.
	var bolt := _give("Lightning Bolt")
	var ball := _give("Fireball")
	screen._click_hand_card(ball)
	assert_not_null(screen._x_dialog, "Fireball asks for X first")
	assert_true(screen._modal_open())
	screen._on_card_clicked(bolt)
	assert_eq(screen._pending_card, ball,
		"the click under the window did not start another cast")
	assert_not_null(screen._x_dialog, "and the window is still up")
	var before := _clock()
	screen._order_next_phase()
	assert_eq(_clock(), before, "`Go to: next phase` is refused under it")
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE)
	# ...and the window's own OK with nothing left to confirm is a no-op,
	# not a crash.
	screen._pending_card = null
	screen._on_x_confirmed()
	assert_null(screen._x_dialog, "the window closes on a cast that is gone")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_nothing_answers_under_the_coin_toss() -> void:
	# The toss and the opening hand play over a table the engine has not
	# started (turn 0), and _toss_active only ever held back the AI's
	# timer: Return left a standing Done order, Space walked the steps, a
	# card in hand could be cast, and Concede ended a duel that had not
	# begun. Nothing answers until the toss is over.
	screen._toss_active = true
	var bolt := _give("Lightning Bolt")
	var before := _clock()
	_send_key(KEY_ENTER)
	_send_key(KEY_SPACE)
	screen._on_done()
	screen._on_pass_turn()
	screen._on_card_clicked(bolt)
	screen._order_next_phase()
	assert_eq(_clock(), before, "the table did not move")
	assert_eq(screen._advance_mode, DuelScreen.Advance.NONE, "no standing order")
	assert_null(screen._pending_card, "no cast began")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	screen._on_territory_input(click, 0)
	assert_eq(screen._territory_menu_pid, -1, "the territory menu did not open")
	screen._toss_active = false
