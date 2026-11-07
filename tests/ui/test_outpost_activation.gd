extends GutTest
## Playtest: choose Kjeldoran Outpost's Soldier ability before drawing mana.

var screen: DuelScreen
var outpost: CardInstance
var plains: CardInstance
var forest: CardInstance


func before_each() -> void:
	CardPacks.set_enabled("pack-5", true)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.set_process(false)
	screen.stops.clear_all()
	screen._toss_active = false
	var g := screen.game
	g.active_player = 0
	g.priority_player = 0
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	g.interactive_choices = false
	g.set_agent(0, DecisionAgent.new())
	_put("Plains") # paid on entry, separate from the two activation sources
	outpost = _put("Kjeldoran Outpost")
	plains = _put("Plains")
	forest = _put("Forest")
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	screen._refresh()


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	CardPacks.set_enabled("pack-5", false)


func _put(name: String) -> CardInstance:
	var g := screen.game
	var card := CardInstance.new(CardRegistry.get_card(name), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[card.id] = card
	g._put_on_battlefield(card, 0)
	return card


func _choose_soldier() -> void:
	screen._on_card_clicked(outpost)
	assert_true(screen._ability_menu.visible)
	assert_eq(screen._ability_menu.item_count, 2)
	screen._ability_menu.hide()
	screen._ability_menu.id_pressed.emit(1)


func _assert_soldier_resolves() -> void:
	var g := screen.game
	assert_eq(g.stack.size(), 1, "one Soldier ability, not a double submission")
	assert_true(outpost.tapped, "Outpost taps as the activation cost")
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(g.pass_priority(g.priority_player), "")
	assert_eq(g.pass_priority(g.priority_player), "")
	var soldiers: Array[CardInstance] = []
	for card in g.players[0].battlefield:
		if card.data.card_name == "Soldier": soldiers.append(card)
	assert_eq(soldiers.size(), 1)
	if soldiers.is_empty(): return
	assert_eq(soldiers[0].cur_power, 1)
	assert_eq(soldiers[0].cur_toughness, 1)
	assert_true(soldiers[0].has_subtype("soldier"))


func test_choose_soldier_first_then_tap_other_lands() -> void:
	_choose_soldier()
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	assert_eq(screen._pending_card, outpost)
	assert_true(screen._prompt_label.text.begins_with("ACTIVATING: Kjeldoran Outpost, Tap {"),
		"1997's line for an ability: @PROMPT_ACTION's ACTIVATING, then the mana owed — %s"
		% screen._prompt_label.text)
	assert_false(outpost.tapped, "reserve its tap until the mana is paid")
	screen._on_card_clicked(forest)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(plains)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	_assert_soldier_resolves()


func test_floating_mana_before_choosing_soldier_still_works() -> void:
	screen._on_card_clicked(plains)
	screen._on_card_clicked(forest)
	_choose_soldier()
	_assert_soldier_resolves()


func test_outpost_cannot_supply_its_own_soldier_mana() -> void:
	screen.game.tap_permanent(plains)
	_choose_soldier()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL,
		"one Forest plus Outpost cannot pay {1}{W} and tap Outpost again")
	assert_null(screen._pending_card, "do not leave an impossible activation waiting")
	assert_false(outpost.tapped)
	assert_false(forest.tapped)


func test_outpost_is_not_offered_as_mana_while_its_tap_is_reserved() -> void:
	_choose_soldier()
	assert_eq(screen._highlight_for(outpost), MiniCard.Highlight.NONE)
	screen._on_card_clicked(outpost)
	assert_false(outpost.tapped, "a payment click must not consume the ability's reserved tap")
	assert_eq(screen._pending_card, outpost)
	screen._on_card_clicked(plains)
	screen._on_card_clicked(forest)
	_assert_soldier_resolves()


func test_cancel_releases_outpost_for_ordinary_white_mana() -> void:
	_choose_soldier()
	screen._on_cancel()
	screen._on_card_clicked(outpost)
	screen._ability_menu.hide()
	screen._ability_menu.id_pressed.emit(0)
	assert_true(outpost.tapped)
	assert_eq(screen.game.players[0].mana_pool.total_of(Mtg.ManaColor.W), 1)
	assert_true(screen.game.stack.is_empty())


func test_already_tapped_for_white_cannot_also_make_a_soldier() -> void:
	assert_eq(screen.game.tap_for_mana(0, outpost), "")
	screen._on_card_clicked(plains)
	screen._on_card_clicked(forest)
	_choose_soldier()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_null(screen._pending_card)
	assert_true(screen.game.stack.is_empty())
	assert_string_contains(screen._prompt_label.text, "already tapped")
	assert_eq(screen.game.players[0].mana_pool.total(), 3, "refusal spends no mana")


func test_non_tapping_activation_can_still_use_its_own_mana() -> void:
	var factory := _put("Mishra's Factory")
	screen._on_card_clicked(factory)
	screen._ability_menu.hide()
	screen._ability_menu.id_pressed.emit(factory.cur_mana_abilities.size())
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	assert_eq(screen._highlight_for(factory), MiniCard.Highlight.OPTIONAL)
	screen._on_card_clicked(factory)
	assert_true(factory.tapped)
	assert_eq(screen.game.stack.size(), 1)
	assert_eq(screen.game.pass_priority(screen.game.priority_player), "")
	assert_eq(screen.game.pass_priority(screen.game.priority_player), "")
	assert_true(factory.is_creature(), "Factory may tap to pay for its own animation")


func test_mana_menu_reserves_only_conflicting_abilities_on_the_source() -> void:
	# A card with both tapping and non-tapping mana must keep its legal
	# option. Do not change shared registry data to build this fixture.
	var data := CardData.new("Mixed mana test source", "", Mtg.CardType.ARTIFACT)
	data.mana(ManaAbility.new(Mtg.ManaColor.W))
	data.mana(ManaAbility.new(Mtg.ManaColor.W).without_tap())
	data.activated(outpost.cur_activated_abilities[0])
	var g := screen.game
	var mixed := CardInstance.new(data, g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[mixed.id] = mixed
	g._put_on_battlefield(mixed, 0)
	screen._on_card_clicked(mixed)
	screen._ability_menu.hide()
	screen._ability_menu.id_pressed.emit(2)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(mixed)
	assert_true(screen._ability_menu.is_item_disabled(0))
	assert_false(screen._ability_menu.is_item_disabled(1))
	screen._ability_menu.hide()
	screen._ability_menu.id_pressed.emit(0) # stale/keyboard selection cannot bypass the guard
	assert_false(mixed.tapped)
	screen._ability_menu.id_pressed.emit(1)
	assert_false(mixed.tapped, "non-tapping mana remains legal during payment")
	screen._on_card_clicked(forest)
	assert_true(mixed.tapped, "tap finally paid for the Soldier activation")
	assert_eq(g.stack.size(), 1)
