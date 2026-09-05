extends GutTest
## THE X DIALOG — `@DIALOG_FIREBALL` (`Program/UIStrings.txt:657`),
## `docs/duel-todo.md` §6.14.
##
## The item called this dialog "a divided-damage dial" and it is not one:
## its seven strings are X, the TARGET COUNT and the arithmetic between
## them. The real divided-damage dial is `@PYROTECHNICS` and it is a click
## loop — pinned in `test_situation_bar.gd` and `test_stack_hand.gd`.
##
## The bug these tests exist for: X used to be asked before the targets and
## priced without them, so Fireball offered the whole pool as X and then
## refused the cast the moment a second target was picked.


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


func _main_phase() -> void:
	var g: MtgGame = screen.game
	g.active_player = 0
	g.priority_player = 0
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	g.awaiting_attackers = false
	g.awaiting_blockers = false


# ------------------------------------------------------- the seven strings --

func test_the_dialog_carries_the_1997_table_verbatim() -> void:
	assert_eq(FireballDialog.ASK_MANA, "Generic mana to put into the spell:")
	assert_eq(FireballDialog.MAX_MANA, "(max: %d)")
	assert_eq(FireballDialog.X_COST, "X cost:")
	assert_eq(FireballDialog.EXTRA_COST, "Cost for additional targets:")
	assert_eq(FireballDialog.ASK_TARGETS, "# Targets:")
	# Entry 6 has NO colon where entry 2 does — the table's own
	# inconsistency, reproduced rather than tidied.
	assert_eq(FireballDialog.MAX_TARGETS, "(max %d)")
	assert_eq(FireballDialog.EACH_TARGET,
		"Amount of damage to be done each target:")


# ---------------------------------------------------------- the arithmetic --

func test_the_pot_is_divided_between_x_and_the_extra_targets() -> void:
	# Six generic in, three targets: two of them bought the second and
	# third target at Fireball's "{1} more for each target beyond the
	# first", the other four are X, and X divides evenly among three.
	var seen := FireballDialog.plan(6, 6, 3, 1)
	assert_eq(int(seen["extra"]), 2)
	assert_eq(int(seen["x_cost"]), 4)
	assert_eq(int(seen["x"]), 4)
	assert_eq(int(seen["each"]), 1, "4 divided by 3, rounded down")


func test_one_target_spends_the_whole_pot_on_x() -> void:
	var seen := FireballDialog.plan(6, 6, 1, 1)
	assert_eq(int(seen["extra"]), 0)
	assert_eq(int(seen["x"]), 6)
	assert_eq(int(seen["each"]), 6)


func test_the_target_bound_moves_with_the_mana() -> void:
	# Dial two mana in and only three targets are reachable; dial six in
	# and seven are. That trade is why the original put both fields in one
	# window.
	assert_eq(int(FireballDialog.plan(6, 2, 1, 1)["max_targets"]), 3)
	assert_eq(int(FireballDialog.plan(6, 6, 1, 1)["max_targets"]), 7)
	# With no surcharge there is no second field and no bound to move.
	assert_eq(int(FireballDialog.plan(6, 6, 1, 0)["max_targets"]), 1)


func test_two_x_symbols_halve_the_mana() -> void:
	# Part Water is {X}{X}{U}: six generic buys X = 3.
	assert_eq(int(FireballDialog.plan(6, 6, 1, 0, 2)["x"]), 3)


# --------------------------------------------------------- the two windows --

func test_a_plain_x_spell_gets_only_the_first_two_strings() -> void:
	var win := FireballDialog.window("Braingeyser", 4, 0, 1)
	add_child_autofree(win)
	assert_true(win.has_meta("mana"), "the question")
	assert_false(win.has_meta("targets"), "and nothing else")


func test_fireball_gets_the_whole_table() -> void:
	var win := FireballDialog.window("Fireball", 6, 1, 4)
	add_child_autofree(win)
	assert_true(win.has_meta("mana"))
	assert_true(win.has_meta("targets"))
	var spin: SpinBox = win.get_meta("targets")
	assert_eq(int(spin.min_value), 1)
	assert_eq(int(spin.max_value), 4, "capped by what is on the table")


func test_the_target_field_is_capped_by_the_legal_targets() -> void:
	# "Any number of targets" is bounded by what exists (CR 601.2c), and
	# `(max %d)` is where the player reads it.
	var win := FireballDialog.window("Fireball", 20, 1, 2)
	add_child_autofree(win)
	assert_eq(int(win.get_meta("targets").max_value), 2)


# ------------------------------------------------ end to end, on the screen --

func test_fireball_opens_the_full_dialog_and_the_cast_is_payable() -> void:
	# THE BUG. Seven mana, three targets: the old dialog offered X = 6,
	# the player picked three targets, and the engine refused the cast
	# because the two extra targets had nothing to pay them with.
	var victims: Array = [_put(1, "Grizzly Bears"), _put(1, "Hill Giant"),
		_put(1, "Sea Serpent")]
	screen.game.recalculate()
	_main_phase()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.C, 6)
	screen._click_hand_card(_give("Fireball"))
	assert_not_null(screen._x_dialog, "the X question is up")
	assert_true(screen._x_dialog.has_meta("targets"),
		"and it is the full @DIALOG_FIREBALL")
	assert_eq(int(screen._x_spin.max_value), 6,
		"the generic the pool can cover on top of the {R}")
	screen._x_dialog.get_meta("targets").value = 3
	screen._on_x_confirmed()
	assert_eq(screen._pending_x, 4, "6 mana less the 2 the extra targets ate")
	assert_eq(screen._pending_slots[0]["min"], 3, "and three targets exactly")
	assert_eq(screen._pending_slots[0]["max"], 3)
	for v in victims:
		screen._on_card_clicked(v)
	assert_eq(screen.game.stack.size(), 1, "the cast was NOT refused")
	assert_eq(screen.game.stack[0].targets.size(), 3)
	assert_eq(screen.game.stack[0].x_value, 4)


func test_a_plain_x_spell_still_asks_the_short_question() -> void:
	_main_phase()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.U, 2)
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.C, 3)
	screen._click_hand_card(_give("Braingeyser"))
	assert_not_null(screen._x_dialog)
	assert_false(screen._x_dialog.has_meta("targets"),
		"no target count on a spell that buys none")
	assert_eq(int(screen._x_spin.max_value), 3)
	screen._on_x_confirmed()
	assert_eq(screen._pending_x, 3)


func test_cancelling_the_dialog_abandons_the_cast() -> void:
	_main_phase()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.R, 3)
	screen._click_hand_card(_give("Fireball"))
	screen._on_x_canceled()
	assert_null(screen._x_dialog)
	assert_null(screen._pending_card)
	assert_eq(screen._pending_target_count, -1, "and the count with it")


func test_a_doubled_x_cost_steps_the_field_so_no_mana_is_wasted() -> void:
	# Part Water is {X}{X}{U}: the engine charges the chosen X twice
	# (`ManaCost.x_count`), so only EVEN amounts of generic buy a whole
	# point of X. Entry 1 asks for the MANA, so the field steps by the
	# count and every value on it is spendable.
	_put(1, "Grizzly Bears")
	_put(1, "Hill Giant")
	screen.game.recalculate()
	_main_phase()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.U, 1)
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.C, 5)
	screen._click_hand_card(_give("Part Water"))
	assert_not_null(screen._x_dialog)
	assert_eq(int(screen._x_spin.step), 2, "one point of X costs two mana")
	assert_eq(int(screen._x_spin.max_value), 4,
		"five spare generic buys two points of X, not two and a half")
	screen._on_x_confirmed()
	assert_eq(screen._pending_x, 2)
	assert_eq(screen._pending_slots[0]["max"], 2, "X targets, and X is 2")
