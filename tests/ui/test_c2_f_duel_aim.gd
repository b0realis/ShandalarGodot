extends GutTest
## NOTHING IS OFFERED THAT CANNOT BE AIMED (campaign 2026-10-12, findings
## r1-2 and r1-3).
##
## r1-2: a spell whose second target is bound to the first — Cannibalize's
## "two target creatures controlled by the SAME player", a
## [member TargetSpec.sibling_filter] — was lit and opened its target slot
## when no legal PAIR existed: the light counted candidates and never asked
## the pair. The duel soak's fuzzed player then clicked the refused partner
## forever (a false STALL). A card now lights only when a whole legal group
## exists, and the soak's clicker aims only at what the slot accepts and
## cancels a slot that has nothing left.
##
## r1-3: an ACTIVATED ability whose only target has no legal choice — Ali
## Baba with no Wall on the table — opened "Select target Wall." with
## nothing to click. It is now greyed in the ability menu, and refused with
## the reason if chosen anyway (CR 602.2b, 601.2c).

const SOAK := preload("res://tools/duel_soak.gd")

var screen: DuelScreen
var me := 0
var foe := 1


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	await _fresh_screen()


## A new duel screen at the first main phase, with priority.
func _fresh_screen() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	for _i in 20:
		if g.current_step() == Mtg.Step.MAIN1 and g.stack.is_empty():
			break
		g.pass_priority(g.priority_player)
	me = g.priority_player
	foe = g.opponent_of(me)
	screen._refresh()


func after_each() -> void:
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, false)


func _battlefield(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func _hand(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


## The ability menu's line for the first non-mana ability of [param inst].
func _ability_line(inst: CardInstance) -> int:
	return screen._ability_menu.get_item_index(inst.cur_mana_abilities.size())


# ---------------------------------------------------- r1-2, the pair --

func test_cannibalize_is_not_lit_with_one_creature_a_side() -> void:
	_battlefield(me, "Grizzly Bears")
	_battlefield(foe, "Hill Giant")
	screen.game.players[me].mana_pool.add(Mtg.ManaColor.B, 2)
	var spell := _hand(me, "Cannibalize")
	assert_false(screen._has_something_to_aim_at(spell),
		"no two creatures share a controller: Cannibalize has no legal pair")
	screen._on_card_clicked(spell)
	assert_ne(screen.mode, DuelScreen.Mode.TARGETING, "the cast is refused, not opened")
	assert_eq(screen._prompt_label.text, DuelScreen.NO_TARGET_PROMPT % "Cannibalize",
		"and the bar says why")
	assert_eq(screen.game.players[me].mana_pool.total(), 2, "nothing was spent")


func test_cannibalize_is_lit_when_one_player_has_two_creatures() -> void:
	_battlefield(me, "Grizzly Bears")
	_battlefield(foe, "Hill Giant")
	_battlefield(foe, "Savannah Lions")
	var spell := _hand(me, "Cannibalize")
	assert_true(screen._has_something_to_aim_at(spell),
		"the opponent's two creatures are a legal pair")


## Gauntlets of Chaos: the second target must share a type with the first.
## A creature of ours and an opponent's land share none.
func test_an_ability_with_no_legal_pair_is_greyed() -> void:
	var gauntlets := _battlefield(me, "Gauntlets of Chaos")
	_battlefield(me, "Grizzly Bears")
	_battlefield(foe, "Mountain")
	assert_false(screen._effects_aimable(
		gauntlets.cur_activated_abilities[0].effects, gauntlets),
		"no permanent of theirs shares a type with one of ours")
	screen._open_ability_menu(gauntlets)
	screen._ability_menu.hide()
	assert_true(screen._ability_menu.is_item_disabled(_ability_line(gauntlets)),
		"the trade is greyed")
	# ...and lit again once a partner exists: our artifact for theirs.
	_battlefield(foe, "Ivory Tower")
	assert_true(screen._effects_aimable(
		gauntlets.cur_activated_abilities[0].effects, gauntlets),
		"control: an artifact for an artifact is a legal pair")


## The duel soak's fuzzed player never sits in a target slot it cannot fill:
## with a pair on our side only, a first pick of the opponent's creature
## leaves the second slot nothing — and the clicker cancels.
func test_the_soak_clicker_never_stands_in_a_dead_end_slot() -> void:
	for seed_value in range(1, 13):
		if seed_value > 1:
			await _fresh_screen()
		_battlefield(me, "Grizzly Bears")
		_battlefield(me, "Hill Giant")
		_battlefield(foe, "Savannah Lions")
		screen.game.players[me].mana_pool.add(Mtg.ManaColor.B, 2)
		var spell := _hand(me, "Cannibalize")
		screen._on_card_clicked(spell)
		assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "control: seed %d opened the slot" % seed_value)
		var clicker = SOAK.HumanClicker.new(screen, seed_value)
		for _i in 60:
			if screen.mode != DuelScreen.Mode.TARGETING:
				break
			clicker.tick()
		assert_ne(screen.mode, DuelScreen.Mode.TARGETING,
			"seed %d: still targeting after 60 ticks (%s)" % [seed_value, screen._prompt_label.text])


# ---------------------------------------------- r1-3, the ability menu --

func test_ali_baba_with_no_wall_is_greyed_and_refused() -> void:
	var ali := _battlefield(me, "Ali Baba")
	_battlefield(foe, "Grizzly Bears")
	screen.game.players[me].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._refresh()
	screen._open_ability_menu(ali)
	screen._ability_menu.hide()
	var line := _ability_line(ali)
	assert_true(screen._ability_menu.is_item_disabled(line), "no Wall: the ability is greyed")
	assert_ne(screen._ability_menu.get_item_tooltip(line), "", "and says why on hover")
	# Chosen anyway (a stale menu, a pad, a script): refused with the reason.
	screen._on_ability_chosen(ali.cur_mana_abilities.size())
	assert_ne(screen.mode, DuelScreen.Mode.TARGETING,
		"no target slot opens (prompt: '%s')" % screen._prompt_label.text)
	assert_null(screen._pending_card, "nothing is pending")
	assert_eq(screen._prompt_label.text, DuelScreen.NO_TARGET_PROMPT % "Ali Baba")
	assert_eq(screen.game.players[me].mana_pool.amount_of(Mtg.ManaColor.R), 1,
		"the mana is untouched")


func test_ali_baba_with_a_wall_is_offered() -> void:
	var ali := _battlefield(me, "Ali Baba")
	_battlefield(foe, "Wall of Wood")
	screen.game.players[me].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._refresh()
	screen._open_ability_menu(ali)
	screen._ability_menu.hide()
	assert_false(screen._ability_menu.is_item_disabled(_ability_line(ali)),
		"control: a Wall to tap, the ability is offered")
	screen._on_ability_chosen(ali.cur_mana_abilities.size())
	assert_true(screen._pending_card == ali, "control: the activation started")
	screen._on_cancel()


## An ability whose target is judged at the X being paid (Plaguebearer's
## "nonblack creature with mana value X") is tried at the X values it
## could be activated for, as a spell's is — a two-drop is in reach.
func test_an_x_ability_is_judged_at_the_x_it_could_pay() -> void:
	var bearer := _battlefield(me, "Plaguebearer")
	_battlefield(foe, "Grizzly Bears")
	screen._open_ability_menu(bearer)
	screen._ability_menu.hide()
	assert_false(screen._ability_menu.is_item_disabled(_ability_line(bearer)),
		"a two-drop is a target at X = 2")
