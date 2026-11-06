extends GutTest
## Pack 10 engine package E7 at the duel screen: an ability whose DIVIDED
## total is its source's counters (Serra's Hymn's shape —
## [method EffectBase.divided_by]) opens the `Select (1st of 3)` click
## loop with the source's X, one click per point, and closes on the last
## point; with no counters there is nothing to divide and nothing to aim.

var screen: DuelScreen
var me := 0


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	for _i in 20:
		if g.current_step() == Mtg.Step.MAIN1 and g.stack.is_empty():
			break
		g.pass_priority(g.priority_player)
	me = g.priority_player
	screen._refresh()


static func _hymn() -> CardData:
	var prevent := PreventDamageEffect.new(0).any_target()
	prevent.divided_by(EffectBase.source_counters("verse"))
	return CardData.new("Test Hymn", "{W}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("", false, [prevent],
			"Sacrifice this enchantment: Prevent the next X damage that would be dealt this turn to any number of targets, divided as you choose, where X is the number of verse counters on this enchantment.").with_sacrifice_cost())


func _put(pid: int, data: CardData) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func _activate(inst: CardInstance) -> void:
	screen._refresh()
	screen._open_ability_menu(inst)
	screen._ability_menu.hide()
	screen._on_ability_chosen(inst.cur_mana_abilities.size())


func test_the_hymn_dials_its_verses() -> void:
	var g: MtgGame = screen.game
	var hymn := _put(me, _hymn())
	var bear := _put(me, CardRegistry.get_card("Grizzly Bears"))
	g.add_counters(hymn, "verse", 3)
	_activate(hymn)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_eq(int(screen._pending_slots[0]["divided"]), 3, "the source's three verses")
	assert_eq(int(screen._pending_slots[0]["max"]), 3, "at most one target per point")
	screen._try_take_target(TargetRef.card(bear))
	screen._try_take_target(TargetRef.card(bear))
	assert_eq(screen._pending_slot, 0, "one point still owed")
	screen._try_take_target(TargetRef.player(me))
	assert_eq(hymn.zone, Mtg.Zone.GRAVEYARD,
		"the last point submitted the activation (%s)" % screen._prompt_label.text)
	if g.stack.is_empty():
		return
	var item: StackItem = g.stack.back()
	var shares := {}
	for ref in item.targets:
		shares[ref.is_player] = ref.amount
	assert_eq(int(shares.get(false, 0)), 2)
	assert_eq(int(shares.get(true, 0)), 1)


func test_no_verses_nothing_to_aim() -> void:
	var g: MtgGame = screen.game
	var hymn := _put(me, _hymn())
	_activate(hymn)
	assert_eq(hymn.zone, Mtg.Zone.GRAVEYARD,
		"X = 0: no slot to fill, the ability is activated (%s)" % screen._prompt_label.text)
	if not g.stack.is_empty():
		assert_true(g.stack.back().targets.is_empty())
