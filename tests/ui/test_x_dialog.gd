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


# --------------------------------- the bound is POTENTIAL mana, not the pool --
#
# THE DEFECT (playtest, 2026-09-06): *"Disintegrate makes a dialog and asks
# for generic mana to put into the spell. However it does not let me tap
# the lands to put into the spell, or select any mana at the dialog!"*
#
# Both halves of that sentence are one bug. 1997 pays for a spell AFTER it
# is chosen — *"Once you've selected a spell to cast, you must draw enough
# mana… to power the spell"* (`Duel.hlp`, topic **Hands**) — so at the
# moment this question is asked the floating pool is EMPTY and the lands
# are still untapped. The bound was read off that empty pool, so the field
# was 0..0 with nothing to select; and the window is modal
# ([method DuelScreen._modal_open]), so the lands could not be tapped
# either. X was 0 and every {X} spell in the pool was uncastable by hand.
#
# The bound is the same number the double-click already knew:
# *"ALL of the mana you have available in your pool AND FROM LAND SOURCES"*
# (`Duel.hlp`, topic **Hands**, and again under **Spells**) —
# `DuelScreen._auto_x_budget`, whose own doc comment described itself as
# "[method _open_x_dialog]'s own budget loop, asked of potential mana
# instead of the floating pool". Now they are one function.

func test_the_bound_counts_the_untapped_lands_not_only_the_pool() -> void:
	# Six Mountains, nothing floating: the {R} takes one and the other five
	# are X. Before the fix `max_value` was 0 and OK cast Disintegrate for
	# X = 0.
	for _n in 6:
		_put(0, "Mountain")
	_put(1, "Grizzly Bears")
	screen.game.recalculate()
	_main_phase()
	assert_eq(screen.game.players[0].mana_pool.total(), 0,
		"nothing is floating — the lands are the whole budget")
	screen._click_hand_card(_give("Disintegrate"))
	assert_not_null(screen._x_dialog, "the X question is up")
	assert_eq(int(screen._x_spin.max_value), 5,
		"six Mountains less the one that pays the {R}")


func test_the_x_spell_can_actually_be_cast_from_untapped_lands() -> void:
	# End to end, the way the player meets it: click, dial X to the max the
	# window offers, aim, then tap the lands the cast is waiting for.
	for _n in 6:
		_put(0, "Mountain")
	var victim := _put(1, "Grizzly Bears")
	screen.game.recalculate()
	_main_phase()
	screen._click_hand_card(_give("Disintegrate"))
	screen._x_spin.value = screen._x_spin.max_value
	screen._on_x_confirmed()
	assert_eq(screen._pending_x, 5, "five damage, not nothing")
	screen._on_card_clicked(victim)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING,
		"the cast is held open for its mana, as 1997 holds it")
	for land in screen.game.players[0].battlefield:
		screen._on_card_clicked(land)
	assert_eq(screen.game.stack.size(), 1, "the cast went through")
	assert_eq(screen.game.stack[0].x_value, 5)


func test_the_pool_and_the_lands_are_added_together() -> void:
	# A resolved Dark Ritual in the pool is a source like any other
	# (`ManaPlanner.sources` lists floating mana first).
	for _n in 3:
		_put(0, "Mountain")
	screen.game.recalculate()
	_main_phase()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.C, 2)
	screen._click_hand_card(_give("Disintegrate"))
	assert_eq(int(screen._x_spin.max_value), 4,
		"three lands and two floating, one of the lands for the {R}")


func test_an_ability_x_counts_the_lands_too() -> void:
	# The same question is asked for an activated ability's {X}
	# (Candelabra of Tawnos, Voodoo Doll's {X}{X}), through the same door.
	var lamp := _put(0, "Aladdin's Lamp")
	for _n in 4:
		_put(0, "Mountain")
	screen.game.recalculate()
	_main_phase()
	lamp.summoning_sick = false
	screen._open_ability_menu(lamp)
	screen._on_ability_chosen(0)
	assert_not_null(screen._x_dialog, "the ability asks for its X")
	assert_eq(int(screen._x_spin.max_value), 4, "four untapped Mountains")


# ------------------------------------------------------- the whole {X} class --

func _basics(each: int) -> void:
	for land in ["Plains", "Island", "Swamp", "Mountain", "Forest"]:
		for _n in each:
			_put(0, land)
	screen.game.recalculate()


func test_every_x_spell_in_the_pool_offers_a_bound_it_can_pay() -> void:
	# THE CLASS, not the one card the playtest named: every card whose CAST
	# cost carries an {X} is dealt to a seat with four of each basic and
	# clicked. Each must offer a field the player can actually move —
	# twenty lands less its own coloured pips — or it is as unplayable as
	# an unimplemented card.
	_basics(4)
	_main_phase()
	var seen := 0
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if not data.cost.has_x:
			continue
		seen += 1
		var pips := data.cost.mana_value()   # {X} counts as 0 (CR 202.3b)
		screen._click_hand_card(_give(card_name))
		if data.is_modal():
			# Alabaster Potion is the pool's one modal {X} spell: the mode
			# is asked first and the X question comes after it
			# (`_on_mode_chosen` -> `_continue_cast_chain`).
			assert_not_null(screen._mode_overlay, "%s asks its mode" % card_name)
			screen._on_mode_chosen(0)
		assert_not_null(screen._x_dialog, "%s asks for X" % card_name)
		if screen._x_dialog == null:
			continue
		var want: int = 20 - pips
		# A doubled {X}{X} (Part Water, Recall) is rounded down to a whole
		# point of X; Fireball's per-target surcharge keeps every unit.
		if data.extra_cost_per_target <= 0:
			want -= want % maxi(data.cost.x_count, 1)
		assert_eq(int(screen._x_spin.max_value), want,
			"%s (%s) offers its lands" % [card_name, data.cost.text])
		screen._on_x_canceled()
	assert_eq(seen, 24, "the pool's {X} spells, all of them asked")


func test_every_x_ability_in_the_pool_offers_a_bound_it_can_pay() -> void:
	# The other half of the class: an activated ability whose cost carries
	# an {X} comes through the same window (`_open_ability_menu` ->
	# `_open_x_dialog`), and had the same empty bound.
	_basics(4)
	_main_phase()
	var seen := 0
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		for i in data.activated_abilities.size():
			var ability: ActivatedAbility = data.activated_abilities[i]
			if not ability.cost.has_x:
				continue
			seen += 1
			var source := _put(0, card_name)
			screen.game.recalculate()
			source.summoning_sick = false
			screen._pending_card = source
			screen._pending_pid = 0
			screen._pending_ability_index = i
			screen._open_x_dialog()
			assert_not_null(screen._x_dialog, "%s asks for X" % card_name)
			if screen._x_dialog == null:
				continue
			assert_gt(int(screen._x_spin.max_value), 0,
				"%s — %s offers its lands" % [card_name, ability.text])
			screen._on_x_canceled()
	assert_eq(seen, 10, "the pool's {X} abilities, all of them asked")
