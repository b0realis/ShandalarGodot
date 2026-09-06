extends GutTest
## Untamed Wilds at the table, the way the playtest of 2026-09-06 cast it:
## click the card, pick the land in the library picker, then PAY — by
## tapping lands one at a time, or by the double-click's auto-tap — and
## the found land must arrive on the battlefield when the spell resolves,
## asked ONCE. The engine-only version is tests/unit/test_untamed_wilds_*.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _hand(g: MtgGame, pid: int, card_name: String) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


func _land(g: MtgGame, pid: int, card_name: String) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func _library_top(g: MtgGame, pid: int, card_name: String) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.push_front(inst)
	return inst


func _lands_of(g: MtgGame, pid: int) -> int:
	var n := 0
	for perm in g.players[pid].battlefield:
		if perm.is_land():
			n += 1
	return n


func _main_phase(g: MtgGame) -> void:
	g.active_player = 0
	g.priority_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))


func _pick_in_picker(card_name: String) -> void:
	assert_not_null(screen._search_dialog, "the picker opened before the cast")
	for i in screen._search_list.item_count:
		if screen._search_list.get_item_text(i) == card_name:
			screen._search_list.select(i)
			screen._on_search_confirmed()
			return
	fail_test("%s is not in the picker" % card_name)


func _resolve(g: MtgGame) -> void:
	assert_eq(g.pass_priority(0), "")
	assert_eq(g.pass_priority(1), "", "both pass: the spell resolves")


func test_untamed_wilds_paid_one_land_at_a_time() -> void:
	var g: MtgGame = screen.game
	_main_phase(g)
	var forests: Array = [_land(g, 0, "Forest"), _land(g, 0, "Forest"),
		_land(g, 0, "Forest")]
	_library_top(g, 0, "Mountain")
	var wilds := _hand(g, 0, "Untamed Wilds")
	var lands_before := _lands_of(g, 0)
	screen._on_card_clicked(wilds)
	_pick_in_picker("Mountain")
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "held open for its mana")
	assert_null(screen._search_dialog, "the picker is gone")
	for forest in forests:
		screen._on_card_clicked(forest)
		# Each tap lands a `state_changed`, which is what `_refresh` and
		# its `_retry_payment` run on — the path that lost the pick.
		screen._refresh()
	assert_eq(wilds.zone, Mtg.Zone.STACK, "the cast went through")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_null(screen._search_dialog, "the picker did not come back")
	_resolve(g)
	assert_null(g.awaiting_choice, "the resolution did not ask again")
	assert_null(screen._choice_overlay, "and no overlay opened for it")
	assert_eq(wilds.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_lands_of(g, 0), lands_before + 1, "the Mountain arrived")
	assert_false(screen._humans[0].has_preselection(), "the pick is spent")


func test_untamed_wilds_by_double_click() -> void:
	var g: MtgGame = screen.game
	_main_phase(g)
	for _i in 3:
		_land(g, 0, "Forest")
	_library_top(g, 0, "Mountain")
	var wilds := _hand(g, 0, "Untamed Wilds")
	var lands_before := _lands_of(g, 0)
	screen._on_card_clicked(wilds)
	screen._auto_cast(wilds)   # the second click lands under the picker
	assert_not_null(screen._search_dialog, "the picker is the player's to answer")
	_pick_in_picker("Mountain")
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(wilds)
	screen._auto_cast(wilds)   # ...and double-clicking again auto-taps
	assert_eq(wilds.zone, Mtg.Zone.STACK, "the cast went through")
	_resolve(g)
	assert_null(g.awaiting_choice, "the resolution did not ask again")
	assert_eq(_lands_of(g, 0), lands_before + 1, "the Mountain arrived")
