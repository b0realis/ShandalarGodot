extends GutTest
var screen: DuelScreen

func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.set_process(false)
	screen.game.active_player = 0
	screen.game.priority_player = 0
	screen.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	screen.game.awaiting_attackers = false
	screen.game.awaiting_blockers = false

func after_each() -> void:
	screen.queue_free()
	await get_tree().process_frame
	CardPacks.set_enabled(IceAgePack.ID, false)

func give(name: String) -> CardInstance:
	var g := screen.game
	var i := CardInstance.new(CardRegistry.get_card(name), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[i.id] = i
	i.zone = Mtg.Zone.HAND
	g.players[0].hand.append(i)
	return i

func test_fire_covenant_opens_a_life_budget_with_safe_zero_default() -> void:
	var covenant := give("Fire Covenant")
	# A creature to divide the damage among: with none the cast is refused
	# before its X is asked (campaign w5-5 — "any number of target
	# creatures" is at least one, and TargetPlan refuses an empty table).
	var bears := CardInstance.new(CardRegistry.get_card("Grizzly Bears"),
		screen.game._next_instance_id, 1)
	screen.game._next_instance_id += 1
	screen.game._instances[bears.id] = bears
	screen.game._put_on_battlefield(bears, 1)
	screen.game.players[0].life = 17
	screen._click_hand_card(covenant)
	assert_not_null(screen._x_dialog)
	assert_eq(int(screen._x_spin.max_value), 17)
	assert_eq(int(screen._x_spin.value), 0)
	var found := false
	for node in screen._x_dialog.body().get_children():
		if node is Label and node.text == "Life to pay (X):": found = true
	assert_true(found)

func test_graveyard_click_exposes_ashen_ghoul_activation_and_pays_it() -> void:
	var g := screen.game
	var ghoul := give("Ashen Ghoul")
	g.discard_cards(0, [ghoul])
	for _i in 3: g.discard_cards(0, [give("Grizzly Bears")])
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP)
	g.players[0].mana_pool.add(Mtg.ManaColor.B)
	screen._on_graveyard_card(ghoul)
	assert_eq(int(screen._ability_menu.get_meta("instance_id")), ghoul.id)
	assert_false(screen._ability_menu.is_item_disabled(0))
	screen._on_ability_chosen(0)
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack[0].kind, Mtg.StackKind.ABILITY)
	assert_eq(g.players[0].mana_pool.total(), 0)

func test_melee_human_attacker_can_choose_enemy_blocker_in_live_ui() -> void:
	var g := screen.game
	g._probing = true
	screen.config.pilots = [null, AiProfile.wizard()]
	var attacker := give("Hill Giant")
	var blocker := give("Grizzly Bears")
	g.put_from_hand_into_play(attacker, 0)
	g.put_from_hand_into_play(blocker, 1)
	attacker.summoning_sick = false
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	assert_eq(g.declare_attackers(0, [attacker.id]), "")
	var spell := give("Melee")
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 5)
	assert_eq(g.cast_spell(0, spell), "")
	g._resolve_top()
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS)
	g.awaiting_blockers = true
	g._probing = false
	screen._refresh()
	assert_eq(g.block_chooser(), 0)
	assert_eq(screen.mode, DuelScreen.Mode.BLOCKERS)
	screen._pick_block(blocker)
	assert_eq(screen._selected_blocker, blocker.id)
	screen._pick_block(attacker)
	assert_true(screen._block_map[blocker.id].has(attacker.id))
	screen._on_confirm()
	if g.awaiting_blockers: screen._on_confirm()
	assert_false(g.awaiting_blockers)
	assert_eq(g.combat.blocks.get(blocker.id), attacker.id)

func test_exile_click_casts_a_bottle_card_from_the_actual_exile_pile() -> void:
	var g := screen.game
	var bear := give("Grizzly Bears")
	g.put_from_hand_on_top_of_library(bear)
	g.exile_library_card(bear)
	g.grant_exile_play(bear, 0, true)
	g.players[0].mana_pool.add(Mtg.ManaColor.G, 2)
	screen._on_graveyard_card(bear)
	assert_eq(bear.zone, Mtg.Zone.STACK)
	assert_false(g.players[0].exile.has(bear))
	assert_eq(g.stack.back().card, bear)

func test_enemy_mercenaries_menu_activates_for_the_human_not_the_enemy() -> void:
	var g := screen.game
	var merc := give("Mercenaries")
	g._remove_from_zone(merc)
	g._put_on_battlefield(merc, 1)
	g.players[0].mana_pool.add(Mtg.ManaColor.C, 3)
	screen._open_ability_menu(merc)
	screen._on_ability_chosen(0)
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack[0].controller, 0)
	assert_eq(g.players[0].mana_pool.total(), 0)
