extends GutTest
## THE HUMAN CAST CHAIN (whole-game campaign, fix-ui: w5-1, w5-2, w5-3,
## w5-5, w5-6, w5-11).
##
## w5-1 — targets the CASTER does not name (an opponent's choice: Cuombajj
## Witches; the game's roll: Orcish Catapult) were asked of the player, and
## the engine refused the submission ("takes N target(s), got M").
## w5-2 — "mana value X" targets (Detonate, Spell Blast) were judged at
## X = 0 while aiming.
## w5-3 — OK on the tutor picker with nothing selected re-opened it, so a
## tutor with nothing to find could only be cancelled.
## w5-5 — a spell with nothing to aim at was lit castable, and its
## double-click tapped the lands before finding no target.
## w5-6 — a cast aimed during the other seat's priority was dropped at the
## last click ("you don't have priority") with the double-click's mana
## floating.
## w5-11 — Abandon Hope's X window ignored "discard X cards".

var screen: DuelScreen
var _id := 932000


func before_each() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]   # seat 1 is the computer
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	# The three default Stops (your main phases, your combat): your own main
	# phase holds, as a fresh profile's does, so nothing passes it while a
	# cast is staged.
	screen.stops.from_masks(PhaseStops.default_masks())


func after_each() -> void:
	CardPacks.set_enabled("pack-9", false)


## Seat 0's own main phase, priority seat 0's, empty table and hands, the
## computer's beat held.
func _stage() -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g.stack.clear()
	for p in g.players:
		p.hand.clear()
		p.battlefield.clear()
		p.mana_pool.clear()
	g._probing = false
	screen._ai_pending = true
	screen.mode = DuelScreen.Mode.NORMAL
	return g


func _bf(card_name: String, seat: int) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "%s is in the pool" % card_name)
	var inst := CardInstance.new(data, _id, seat)
	_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, seat)
	inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


func _hand(card_name: String, seat := 0) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "%s is in the pool" % card_name)
	var inst := CardInstance.new(data, _id, seat)
	_id += 1
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[seat].hand.append(inst)
	return inst


func _float(seat: int, colors: Array, each := 10) -> void:
	for c in colors:
		screen.game.players[seat].mana_pool.add(c, each)


func _tapped_lands(seat: int) -> int:
	var n := 0
	for perm in screen.game.players[seat].battlefield:
		if perm.is_land() and perm.tapped:
			n += 1
	return n


# ==================================== w5-1: targets the caster doesn't name --

func test_cuombajj_witches_asks_only_for_the_activators_target() -> void:
	var g := _stage()
	_bf("Grizzly Bears", 1)
	var witches := _bf("Cuombajj Witches", 0)
	screen._refresh()
	screen._open_ability_menu(witches)
	screen._ability_menu.hide()
	screen._on_ability_chosen(witches.cur_mana_abilities.size())
	assert_eq(screen._pending_slots.size(), 1,
		"one target is the activator's; the other is the opponent's choice")
	screen._on_life_clicked(1)
	assert_eq(g.stack.size(), 1, "the computer names its target and the activation goes on (prompt: %s)"
		% screen._prompt_label.text)


func test_at_a_hotseat_the_witches_second_target_is_the_other_seats_question() -> void:
	# Both seats are people here, so the OPPONENT names its target — a held
	# question for seat 1, not a slot for seat 0 (the probe's "Process
	# Cuombajj Witches" is this question, and it is the right one).
	var config := DuelConfig.hotseat_default()
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.from_masks(PhaseStops.default_masks())
	var g := _stage()
	_bf("Grizzly Bears", 1)
	var witches := _bf("Cuombajj Witches", 0)
	screen._refresh()
	screen._open_ability_menu(witches)
	screen._ability_menu.hide()
	screen._on_ability_chosen(witches.cur_mana_abilities.size())
	assert_eq(screen._pending_slots.size(), 1, "seat 0 is asked for one target only")
	screen._on_life_clicked(1)
	assert_not_null(g.awaiting_choice, "the second target is asked of the other seat")
	if g.awaiting_choice == null:
		return
	assert_eq(g.awaiting_choice.pid, 1, "...the opponent's choice")
	screen._on_choice_option(0)
	for _i in 3:
		if g.awaiting_choice == null:
			break
		screen._on_choice_option(0)
	assert_eq(g.stack.size(), 1, "answered, the activation goes on (prompt: %s)"
		% screen._prompt_label.text)


func test_orcish_catapult_asks_for_no_target() -> void:
	var g := _stage()
	_bf("Grizzly Bears", 1)
	_float(0, [Mtg.ManaColor.R, Mtg.ManaColor.C])
	var catapult := _hand("Orcish Catapult")
	screen._refresh()
	screen._on_card_clicked(catapult)
	assert_not_null(screen._x_dialog, "X is asked")
	screen._x_spin.value = 2
	screen._on_x_confirmed()
	assert_eq(screen._pending_slots.size(), 0, "the targets are the game's roll")
	assert_eq(g.stack.size(), 1, "the Catapult goes on the chain (prompt: %s)"
		% screen._prompt_label.text)


# =================================== w5-2: "mana value X" while aiming --

func test_detonate_for_two_is_aimed_at_a_two_drop_and_not_a_zero_drop() -> void:
	var g := _stage()
	var ankh := _bf("Ankh of Mishra", 1)
	var thopter := _bf("Ornithopter", 1)
	_float(0, [Mtg.ManaColor.R, Mtg.ManaColor.C])
	var detonate := _hand("Detonate")
	screen._refresh()
	screen._on_card_clicked(detonate)
	screen._x_spin.value = 2
	screen._on_x_confirmed()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_eq(screen._highlight_for(ankh), MiniCard.Highlight.TARGET_LEGAL, "mana value 2")
	assert_ne(screen._highlight_for(thopter), MiniCard.Highlight.TARGET_LEGAL, "mana value 0")
	screen._try_take_target(TargetRef.card(thopter))
	assert_string_contains(screen._prompt_label.text, "Illegal target", "refused at X = 2")
	screen._try_take_target(TargetRef.card(ankh))
	assert_eq(g.stack.size(), 1, "Detonate for 2 at the Ankh is cast (prompt: %s)"
		% screen._prompt_label.text)


func test_spell_blast_for_two_takes_the_lone_two_mana_spell() -> void:
	var g := _stage()
	g._probing = true
	g.active_player = 1
	g.priority_player = 1
	g._probing = false
	g.players[1].mana_pool.add(Mtg.ManaColor.G, 2)
	var bears := _hand("Grizzly Bears", 1)
	screen._advancing = true
	assert_eq(g.cast_spell(1, bears, [], 0, 0), "")
	assert_eq(g.pass_priority(1), "")
	screen._advancing = false
	assert_eq(g.priority_player, 0)
	var blast := _hand("Spell Blast")
	_float(0, [Mtg.ManaColor.U], 3)
	screen._refresh()
	screen._on_card_clicked(blast)
	screen._x_spin.value = 2
	screen._on_x_confirmed()
	assert_eq(g.stack.size(), 2, "Spell Blast for 2 goes on the chain over the Bears (prompt: %s)"
		% screen._prompt_label.text)


# ============================================ w5-3: the tutor may find nothing --

func test_tutor_ok_with_nothing_selected_casts_it_and_finds_nothing() -> void:
	var g := _stage()
	_float(0, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	var tutor := _hand("Demonic Tutor")
	screen._refresh()
	screen._on_card_clicked(tutor)
	assert_not_null(screen._search_dialog, "the picker opens before the cast")
	screen._search_list.deselect_all()
	screen._on_search_confirmed()
	assert_null(screen._search_dialog, "OK with no row goes on with the cast")
	assert_eq(g.stack.size(), 1, "the Tutor is cast")
	var hand_before := g.players[0].hand.size()
	screen._advancing = true
	g.pass_priority(0)
	g.pass_priority(1)
	screen._advancing = false
	assert_true(g.stack.is_empty(), "it resolved")
	assert_null(g.awaiting_choice, "the declined search is not asked again")
	assert_eq(g.players[0].hand.size(), hand_before, "and nothing was found")


func test_untamed_wilds_with_no_basic_land_left_can_be_cast() -> void:
	var g := _stage()
	g.players[0].library = g.players[0].library.filter(
		func(i: CardInstance) -> bool: return not i.data.is_land())
	_float(0, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	var wilds := _hand("Untamed Wilds")
	screen._refresh()
	screen._on_card_clicked(wilds)
	assert_not_null(screen._search_dialog, "the picker opens (empty)")
	assert_eq(screen._search_list.item_count, 0, "nothing to find")
	screen._on_search_confirmed()
	assert_null(screen._search_dialog, "the empty picker does not come back")
	assert_eq(g.stack.size(), 1, "Untamed Wilds is cast")


func test_a_declined_search_is_served_as_no_card() -> void:
	var human := HumanAgent.new()
	human.decline_search()
	assert_true(human.has_preselection(), "the decline is an answer")
	var g: MtgGame = screen.game
	var forest := CardInstance.new(CardRegistry.get_card("Forest"), _id, 0)
	_id += 1
	var picked := human.answer_card(g, 0, [forest] as Array[CardInstance], "Search")
	assert_null(picked, "a declined search finds nothing")
	assert_false(human.has_preselection(), "served once")


# =================================== w5-5: nothing to aim at, nothing lit --

func test_a_spell_with_nothing_to_aim_at_is_not_lit_and_taps_nothing() -> void:
	var g := _stage()
	_bf("Swamp", 0)
	_bf("Swamp", 0)
	var terror := _hand("Terror")
	screen._refresh()
	assert_ne(screen._highlight_for(terror), MiniCard.Highlight.OPTIONAL,
		"Terror with no creature anywhere is not useable (Duel.hlp, Hands)")
	screen._auto_cast(terror)
	assert_eq(_tapped_lands(0), 0, "the double-click taps nothing for it")
	assert_eq(g.players[0].mana_pool.total(), 0, "and floats nothing")
	assert_null(screen._pending_card, "the cast is refused before it starts")
	assert_string_contains(screen._prompt_label.text, "no legal target")
	_bf("Grizzly Bears", 1)
	screen._refresh()
	assert_eq(screen._highlight_for(terror), MiniCard.Highlight.OPTIONAL,
		"control: a creature to aim at")


func test_an_aura_with_nothing_to_enchant_and_a_counter_over_an_empty_chain_are_not_lit() -> void:
	_stage()
	_bf("Plains", 0)
	_bf("Island", 0)
	_bf("Island", 0)
	var aura := _hand("Holy Strength")
	var counter := _hand("Counterspell")
	screen._refresh()
	assert_ne(screen._highlight_for(aura), MiniCard.Highlight.OPTIONAL, "nothing to enchant")
	assert_ne(screen._highlight_for(counter), MiniCard.Highlight.OPTIONAL, "an empty chain")


func test_a_modal_spell_is_lit_when_one_of_its_modes_has_a_target() -> void:
	var g := _stage()
	_bf("Island", 0)
	var blast := _hand("Blue Elemental Blast")
	g.priority_player = 0
	screen._refresh()
	assert_ne(screen._highlight_for(blast), MiniCard.Highlight.OPTIONAL,
		"no red spell and no red permanent: neither mode has a target")
	var goblin := _bf("Mons's Goblin Raiders", 1)
	screen._refresh()
	assert_eq(screen._highlight_for(blast), MiniCard.Highlight.OPTIONAL,
		"a red permanent: the destroy mode has its target")
	screen._on_card_clicked(blast)
	assert_not_null(screen._mode_overlay, "the mode is asked")
	var greyed: Array = []
	for button in screen._mode_overlay.find_children("*", "Button", true, false):
		if button.text != "Cancel" and button.disabled:
			greyed.append(button.text)
	assert_eq(greyed.size(), 1, "the counter mode, with no red spell, is greyed: %s" % str(greyed))
	assert_not_null(goblin)
	screen._on_mode_canceled()


func test_two_targets_wanted_need_two_to_aim_at() -> void:
	CardPacks.set_enabled("pack-9", true)      # Death's Duet, Exodus
	var g := _stage()
	_float(0, [Mtg.ManaColor.B, Mtg.ManaColor.C], 3)
	var duet := _hand("Death's Duet")
	var first := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), _id, 0)
	_id += 1
	g._instances[first.id] = first
	first.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(first)
	screen._refresh()
	assert_ne(screen._highlight_for(duet), MiniCard.Highlight.OPTIONAL,
		"\"two target creature cards\" with one in the graveyard")
	var second := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), _id, 0)
	_id += 1
	g._instances[second.id] = second
	second.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(second)
	screen._refresh()
	assert_eq(screen._highlight_for(duet), MiniCard.Highlight.OPTIONAL, "two: lit")


func test_an_orcish_catapult_needs_no_creature_at_x_zero() -> void:
	var g := _stage()
	_float(0, [Mtg.ManaColor.R], 2)
	var catapult := _hand("Orcish Catapult")
	screen._refresh()
	screen._on_card_clicked(catapult)
	assert_not_null(screen._x_dialog, "not refused: at X = 0 it rolls nothing and takes no target")
	if screen._x_dialog == null:
		return
	screen._x_spin.value = 0
	screen._on_x_confirmed()
	assert_eq(g.stack.size(), 1, "cast for X = 0 (prompt: %s)" % screen._prompt_label.text)


func test_detonate_facing_only_a_two_drop_is_lit() -> void:
	var g := _stage()
	# The lands first: an Ankh of Mishra already in play would bite each one.
	_bf("Mountain", 0)
	_bf("Mountain", 0)
	_bf("Mountain", 0)
	_bf("Ankh of Mishra", 1)
	assert_true(g.stack.is_empty(), "control: a quiet main phase")
	var detonate := _hand("Detonate")
	screen._refresh()
	assert_eq(screen._highlight_for(detonate), MiniCard.Highlight.OPTIONAL,
		"no zero-drop artifact, but Detonate for 2 has the Ankh")


func test_the_double_click_x_that_leaves_nothing_to_aim_at_taps_nothing() -> void:
	var g := _stage()
	for _i in 4:
		_bf("Mountain", 0)
	_bf("Ankh of Mishra", 1)
	assert_true(g.stack.is_empty(), "control: a quiet main phase")
	var detonate := _hand("Detonate")
	screen._refresh()
	screen._auto_cast(detonate)        # X = all the mana: 3, no artifact of 3
	assert_eq(_tapped_lands(0), 0, "nothing tapped for an unaimable X")
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(screen._pending_card, detonate, "the cast stays open for Cancel")
	screen._on_cancel()


# ====================== w5-6: a cast aimed during the other seat's priority --

func _early_aim(edition: String) -> void:
	var g: MtgGame = screen.game
	g._probing = true
	g.rules.set_edition(edition)
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1                  # the computer is still finishing
	g.stack.clear()
	for p in g.players:
		p.hand.clear()
		p.battlefield.clear()
		p.mana_pool.clear()
	g._probing = false
	screen._ai_pending = true
	screen.mode = DuelScreen.Mode.NORMAL
	var bolt := _hand("Lightning Bolt")
	_bf("Mountain", 0)
	screen._auto_cast(bolt)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "%s: aiming has started" % edition)
	assert_eq(_tapped_lands(0), 0, "%s: no land is tapped without priority" % edition)
	screen._on_life_clicked(1)
	assert_eq(screen._pending_card, bolt, "%s: the finished cast waits for priority" % edition)
	assert_eq(g.stack.size(), 0)
	assert_eq(g.players[0].mana_pool.total(), 0, "%s: nothing floats while it waits" % edition)
	# The computer passes: priority comes to seat 0, and the held cast goes
	# (the refresh that pass raises hands it to the engine).
	assert_eq(g.pass_priority(1), "")
	screen._refresh()
	assert_eq(g.stack.size(), 1, "%s: the Bolt is cast when priority arrives (prompt: %s)"
		% [edition, screen._prompt_label.text])
	assert_eq(g.stack.back().card, bolt, "%s: and it is the Bolt" % edition)
	assert_eq(_tapped_lands(0), 1, "%s: the double-click's land is tapped then" % edition)
	assert_null(screen._pending_card)


func test_a_cast_aimed_early_is_held_for_priority_under_the_1997_rules() -> void:
	_early_aim("fifth")


func test_a_cast_aimed_early_is_held_for_priority_under_the_modern_rules() -> void:
	_early_aim("modern")


# ========================================= w5-11: X that also counts cards --

func test_abandon_hope_x_is_bounded_by_the_cards_to_discard() -> void:
	CardPacks.set_enabled("pack-9", true)
	var g := _stage()
	_float(0, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	var hope := _hand("Abandon Hope")
	screen._refresh()
	screen._on_card_clicked(hope)
	assert_not_null(screen._x_dialog, "X is asked")
	assert_eq(int(screen._x_spin.max_value), 0, "nothing else in hand to discard")
	screen._on_x_canceled()
	_hand("Grizzly Bears")
	_hand("Forest")
	screen._refresh()
	screen._on_card_clicked(hope)
	assert_eq(int(screen._x_spin.max_value), 2, "two other cards: X up to 2, not 18")
	screen._x_spin.value = 0
	screen._on_x_confirmed()
	screen._on_life_clicked(1)           # "target opponent"
	assert_eq(g.stack.size(), 1, "Abandon Hope at X = 0 is cast (prompt: %s)"
		% screen._prompt_label.text)
