extends GutTest
## Pack 10 engine package E2 — CYCLING AT THE HUMAN DUEL SCREEN. A card
## whose ability works from the hand (cycling, CR 702.29a) is clicked and
## asks which: "Cast <name>" (or "Play <name>" for a cycling land) or
## "Cycling {2}" — the hand action menu Circling Vultures opened in Pack 8.
## The right-click mini-menu offers the same entry. The ability is greyed
## with the engine's own reason, uses the chain, and waits for its mana in
## Mode.PAYING like any other activation.

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
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

static func _is_enchantment(c: CardInstance) -> bool:
	return c.is_type(Mtg.CardType.ENCHANTMENT)


## Clear's shape: "Destroy target enchantment. Cycling {2}".
static func _clear() -> CardData:
	return CardData.new("Test Clear", "{1}{W}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment",
			_is_enchantment))) \
		.with_cycling()


## Blasted Landscape's shape.
static func _landscape() -> CardData:
	return CardData.new("Test Landscape", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1)) \
		.with_cycling()


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


func _stop_here() -> void:
	var here: Array = screen._phase_key()
	screen.stops.set_marked(here[0], here[1], here[2], true)


func _make(pid: int, data: CardData, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	match zone:
		Mtg.Zone.HAND:
			inst.zone = Mtg.Zone.HAND
			g.players[pid].hand.append(inst)
		Mtg.Zone.BATTLEFIELD:
			g._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
			inst.tapped = false
	g._probing = false
	return inst


static func _cycling_index(inst: CardInstance) -> int:
	for i in inst.cur_activated_abilities.size():
		if inst.cur_activated_abilities[i].is_cycling:
			return i
	return -1


# ================================================================ the click --

func test_the_click_offers_cast_and_cycling_and_cycling_goes_on_the_chain() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var clear := _make(0, _clear(), Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.C, 2)
	screen._click_hand_card(clear)
	var menu: PopupMenu = screen._hand_action_menu
	assert_true(menu.visible, "a small menu at the pointer")
	var cast_at := menu.get_item_index(DuelScreen.HAND_ACTION_CAST)
	var cycle_id := DuelScreen.HAND_ACTION_ABILITY_BASE + _cycling_index(clear)
	var cycle_at := menu.get_item_index(cycle_id)
	assert_eq(menu.get_item_text(cast_at), "Cast Test Clear")
	assert_eq(menu.get_item_text(cycle_at), "Cycling {2}")
	assert_false(menu.is_item_disabled(cycle_at))
	assert_eq(menu.get_item_index(DuelScreen.HAND_ACTION_DISCARD), -1,
		"no special-action discard on a cycling card")
	menu.hide()
	screen._on_hand_action_chosen(cycle_id)
	assert_eq(clear.zone, Mtg.Zone.GRAVEYARD, "discarded as the cost")
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack.back().kind, Mtg.StackKind.ABILITY)
	assert_null(screen._pending_card, "nothing left pending")


func test_cycling_is_offered_at_instant_speed_where_the_cast_is_not() -> void:
	var g := _window(1, Mtg.Step.UPKEEP)
	_stop_here()
	var land := _make(0, _landscape(), Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.C, 2)
	screen._click_hand_card(land)
	var menu: PopupMenu = screen._hand_action_menu
	var play_at := menu.get_item_index(DuelScreen.HAND_ACTION_CAST)
	assert_eq(menu.get_item_text(play_at), "Play Test Landscape")
	assert_true(menu.is_item_disabled(play_at), "no land drop in their upkeep")
	var cycle_id := DuelScreen.HAND_ACTION_ABILITY_BASE + _cycling_index(land)
	assert_false(menu.is_item_disabled(menu.get_item_index(cycle_id)), "but it cycles now")
	menu.hide()
	screen._on_hand_action_chosen(cycle_id)
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.stack.size(), 1)


func test_a_cycling_land_is_still_played_from_the_menu() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var land := _make(0, _landscape(), Mtg.Zone.HAND)
	screen._click_hand_card(land)
	var menu: PopupMenu = screen._hand_action_menu
	assert_eq(land.zone, Mtg.Zone.HAND, "the click asks first")
	assert_false(menu.is_item_disabled(menu.get_item_index(DuelScreen.HAND_ACTION_CAST)),
		"its main phase, the drop unspent")
	assert_gte(menu.get_item_index(DuelScreen.HAND_ACTION_ABILITY_BASE + _cycling_index(land)), 0)
	menu.hide()
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_CAST)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "played as the turn's land")
	assert_false(g.land_drop_available(0))


func test_cycling_waits_for_its_mana_and_a_land_tapped_by_hand_pays_it() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()   # the refresh's automatic pass leaves the window to the player
	var clear := _make(0, _clear(), Mtg.Zone.HAND)
	var first := _make(0, CardData.new("Test Wastes", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1)), Mtg.Zone.BATTLEFIELD)
	var second := _make(0, CardData.new("Test Wastes", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1)), Mtg.Zone.BATTLEFIELD)
	screen._refresh()
	screen._start_hand_ability(clear, _cycling_index(clear))
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "the activation waits for its mana")
	assert_eq(clear.zone, Mtg.Zone.HAND, "nothing paid yet")
	screen._on_card_clicked(first)
	screen._on_card_clicked(second)
	assert_eq(clear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.stack.size(), 1)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_the_right_click_mini_menu_offers_cycling_too() -> void:
	var g := _window(1, Mtg.Step.DRAW)
	_stop_here()
	var clear := _make(0, _clear(), Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.C, 2)
	screen._open_card_menu(clear, Vector2(100, 100))
	var menu: PopupMenu = screen._card_menu
	var id := DuelScreen.CARD_MENU_HAND_ABILITY_BASE + _cycling_index(clear)
	var at := menu.get_item_index(id)
	assert_gte(at, 0, "the entry is on the card's own menu")
	assert_eq(menu.get_item_text(at), "Cycling {2}")
	assert_false(menu.is_item_disabled(at))
	menu.hide()
	screen._on_card_menu_chosen(id)
	assert_eq(clear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.stack.size(), 1)
	# A plain card's menu has no such entry, nor has a cycling land on the table.
	var bear := _make(0, CardData.new("Test Bear", "{G}", Mtg.CardType.CREATURE).pt(2, 2),
		Mtg.Zone.HAND)
	screen._open_card_menu(bear, Vector2(100, 100))
	assert_eq(menu.get_item_index(DuelScreen.CARD_MENU_HAND_ABILITY_BASE), -1)
	menu.hide()
	var placed := _make(0, _landscape(), Mtg.Zone.BATTLEFIELD)
	screen._open_card_menu(placed, Vector2(100, 100))
	assert_eq(menu.get_item_index(DuelScreen.CARD_MENU_HAND_ABILITY_BASE + _cycling_index(placed)), -1)
	menu.hide()


func test_the_entry_is_greyed_with_the_engines_reason() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var clear := _make(0, _clear(), Mtg.Zone.HAND)
	screen._click_hand_card(clear)
	var menu: PopupMenu = screen._hand_action_menu
	var at := menu.get_item_index(DuelScreen.HAND_ACTION_ABILITY_BASE + _cycling_index(clear))
	menu.hide()
	# No mana anywhere: the engine's announce reading allows the start (the
	# mana is the payment's business), so the entry is live and the chain
	# says what is missing.
	assert_false(menu.is_item_disabled(at))
	# Without priority it is greyed, and the reason is said.
	g.priority_player = 1
	screen._click_hand_card(clear)
	at = menu.get_item_index(DuelScreen.HAND_ACTION_ABILITY_BASE + _cycling_index(clear))
	assert_true(menu.is_item_disabled(at))
	assert_string_contains(menu.get_item_tooltip(at), "priority")
	menu.hide()


func test_a_plain_land_is_still_played_at_once() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var wastes := _make(0, CardData.new("Test Wastes", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1)), Mtg.Zone.HAND)
	screen._click_hand_card(wastes)
	assert_eq(wastes.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(screen._hand_action_menu.visible)
	assert_false(g.land_drop_available(0))
