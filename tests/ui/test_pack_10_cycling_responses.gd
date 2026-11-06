extends GutTest
## CYCLING IS A RESPONSE (Pack 10 E2, CR 702.29a) — at the human duel
## screen's two "has a fast effect" questions. A cycling card is used at
## instant speed from the hand, classically at the opponent's end step, so:
##
##  * [method DuelScreen._could_respond] counts it whenever the engine would
##    take its activation now ([method MtgGame.activation_refusal], untapped
##    sources included) — the automatic pass used to walk a player holding
##    only a cycling card straight past that end step;
##  * [method DuelScreen._has_affordable_fast_effect] — the floated-mana
##    stop of the standing orders — counts it only with its cost FLOATING,
##    the rule every other fast effect follows there.
## The SGManalink half (`respond` / `floating`) is pinned in
## tests/ui/test_sgmanalink_pack_10_table.gd.

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


static func _is_enchantment(c: CardInstance) -> bool:
	return c.is_type(Mtg.CardType.ENCHANTMENT)


## Clear's shape: "Destroy target enchantment. Cycling {2}".
static func _clear() -> CardData:
	return CardData.new("Test Clear", "{1}{W}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment",
			_is_enchantment))) \
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


func _clear_the_table() -> void:
	var g: MtgGame = screen.game
	g._probing = true
	for p in g.players:
		for inst in p.battlefield.duplicate():
			p.battlefield.erase(inst)
	g._probing = false


func test_a_cycling_card_with_lands_to_tap_is_a_response_at_their_end_step() -> void:
	var g := _window(1, Mtg.Step.END)
	_clear_the_table()
	_make(0, _clear(), Mtg.Zone.HAND)
	assert_false(screen._could_respond(0), "control: nothing to pay {2} with")
	_make(0, CardRegistry.get_card("Plains"), Mtg.Zone.BATTLEFIELD)
	_make(0, CardRegistry.get_card("Plains"), Mtg.Zone.BATTLEFIELD)
	g.recalculate()
	assert_true(screen._could_respond(0),
		"two Plains to tap: cycling is a response (its own cast has no target)")


func test_a_cycling_card_holds_the_standing_orders_only_with_its_cost_floating() -> void:
	var g := _window(1, Mtg.Step.END)
	_clear_the_table()
	_make(0, _clear(), Mtg.Zone.HAND)
	_make(0, CardRegistry.get_card("Plains"), Mtg.Zone.BATTLEFIELD)
	_make(0, CardRegistry.get_card("Plains"), Mtg.Zone.BATTLEFIELD)
	g.recalculate()
	assert_false(screen._has_affordable_fast_effect(0), "untapped lands prepare nothing")
	g.players[0].mana_pool.add(Mtg.ManaColor.C, 2)
	assert_true(screen._has_affordable_fast_effect(0), "{2} floated for it does")
