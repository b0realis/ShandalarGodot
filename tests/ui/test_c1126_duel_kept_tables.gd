extends GameTest
## THE LAN TABLE, THE REPLAY TABLE AND THE SPELL CHAIN ARE KEPT BETWEEN
## REDRAWS (campaign 2026-11-26, smoothness 3 and 4): a card that did not
## change keeps its widget from one received table (or one shown step) to
## the next, a chain object keeps its entry, and what is kept reads exactly
## as what would be built anew.

var referee: SgPracticeMatch
var revision := 1
var _next_id := 96100


func before_each() -> void:
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func _room() -> Dictionary:
	return {"id": "r1", "name": "Friendly duel", "seat": 0,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(0),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _lan() -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.present(_room(), true, false)
	return screen


func _again(screen: SgDuelView) -> void:
	revision += 1
	screen.present(_room(), true, false)
	await get_tree().process_frame


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(0, card)))


func _widget_of(screen: DuelScreen, inst: CardInstance) -> MiniCard:
	for found: MiniCard in screen.find_children("*", "MiniCard", true, false):
		if found.instance == inst and not found.is_queued_for_deletion():
			return found
	return null


## What a player could read off the table: every control's kind, words,
## tint, turn and place.
func _reading(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child.is_queued_for_deletion() or not (child is Control):
			continue
		var c := child as Control
		# A hidden control reads as nothing, whatever it was last dressed in
		# (a cue made for an earlier step and put away again).
		if not c.visible:
			continue
		var line: Array = [c.get_class(), c.visible, c.tooltip_text, c.modulate,
			snappedf(c.rotation_degrees, 0.01), c.position.round(), c.size.round()]
		if c is Label or c is Button:
			line.append(c.get("text"))
		if c is BaseButton:
			line.append((c as BaseButton).disabled)
		if c is TextureRect:
			line.append((c as TextureRect).texture)
		out.append(line)
		_reading(c, out)


func _table_reading(screen: DuelScreen) -> Array:
	var out: Array = []
	for pid in 2:
		for row in screen._field_rows[pid]:
			_reading(screen._field_rows[pid][row], out)
		_reading(screen._free_layers[pid], out)
	for hand in screen._hand_rows:
		_reading(hand, out)
	_reading(screen._chain_box, out)
	return out


## The same table drawn kept and drawn anew reads the same.
func _assert_reads_alike(screen: DuelScreen, what: String) -> void:
	screen.keep_table_widgets = true
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var kept := _table_reading(screen)
	screen.keep_table_widgets = false
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var rebuilt := _table_reading(screen)
	screen.keep_table_widgets = true
	assert_eq(kept.size(), rebuilt.size(), "%s: as many controls kept as rebuilt" % what)
	if kept.size() == rebuilt.size():
		for i in kept.size():
			if kept[i] != rebuilt[i]:
				assert_eq(str(kept[i]), str(rebuilt[i]), "%s, control %d" % [what, i])
				break
	assert_eq(kept.hash(), rebuilt.hash(), "%s: the kept table reads as the rebuilt one" % what)
	screen._refresh()
	await get_tree().process_frame


# ------------------------------------------------------------ the LAN table --

func _lan_board() -> Dictionary:
	advance_to_step(Mtg.Step.MAIN1)
	var out := {"lands": []}
	for i in 4:
		out["lands"].append(put_battlefield(0, "Forest"))
	out["bear"] = put_battlefield(0, "Grizzly Bears")
	out["angel"] = put_battlefield(0, "Serra Angel")
	out["lion"] = put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "Plains")
	out["held"] = give_hand(0, "Giant Growth")
	return out


func test_a_lan_table_keeps_an_unchanged_card_over_a_received_table() -> void:
	var board := _lan_board()
	var screen := _lan()
	for i in 6: await get_tree().process_frame
	var bear := _widget_of(screen, _local(screen, board["bear"]))
	var lion := _widget_of(screen, _local(screen, board["lion"]))
	assert_not_null(bear, "control: the bear is drawn")
	assert_not_null(lion, "control: the other side's card is drawn")
	var built := screen.slots_built
	(board["lands"][0] as CardInstance).tapped = true
	await _again(screen)
	assert_eq(_widget_of(screen, _local(screen, board["bear"])), bear, "the bear's own widget stands")
	assert_eq(_widget_of(screen, _local(screen, board["lion"])), lion, "the other side's card too")
	assert_gt(screen.slots_kept, 0, "slots were kept")
	assert_lte(screen.slots_built - built, 1, "only the pile whose land turned was built again")


func test_a_kept_lan_table_reads_as_a_rebuilt_one_after_each_change() -> void:
	var board := _lan_board()
	var screen := _lan()
	for i in 6: await get_tree().process_frame
	var bear: CardInstance = board["bear"]
	var angel: CardInstance = board["angel"]
	var changes: Array[Callable] = [
		func() -> void: (board["lands"][1] as CardInstance).tapped = true,
		func() -> void: bear.damage = 1,
		func() -> void: angel.tapped = true,
		func() -> void: bear.counters["+1/+1"] = 2,
		func() -> void: (board["lion"] as CardInstance).face_down = true,
		func() -> void: (board["lion"] as CardInstance).face_down = false,
		func() -> void: put_battlefield(1, "Hill Giant"),
		func() -> void: angel.tapped = false,
	]
	for at in changes.size():
		changes[at].call()
		g.recalculate()
		await _again(screen)
		await _assert_reads_alike(screen, "change %d" % at)


func test_a_lan_chain_object_keeps_its_entry() -> void:
	var board := _lan_board()
	add_mana(0, Mtg.ManaColor.G, 1)
	assert_ok(g.cast_spell(0, board["held"] as CardInstance, [TargetRef.card(board["bear"] as CardInstance)]))
	var screen := _lan()
	for i in 6: await get_tree().process_frame
	assert_eq(screen._chain_box.get_child_count(), 1, "control: the spell is on the chain")
	var entry := screen._chain_box.get_child(0)
	(board["lands"][0] as CardInstance).tapped = true
	await _again(screen)
	assert_eq(screen._chain_box.get_child_count(), 1)
	assert_eq(screen._chain_box.get_child(0), entry, "the entry stands over a received table")
	await _assert_reads_alike(screen, "a spell on the chain")


# --------------------------------------------------------- the replay table --

func _row(handle: String, title: String, owner := 0, land := false) -> Dictionary:
	return {"id": handle, "name": title, "owner": owner, "controller": owner,
		"zone": "battlefield", "face_down": false, "tapped": false, "creature": not land,
		"power": 0 if land else 2, "toughness": 0 if land else 2, "damage": 0,
		"counters": {}, "types": ["land" if land else "creature"]}


func _headers() -> Dictionary:
	return {"Player.P1": "Red Wizard", "Player.P2": "Green Wizard"}


func _state() -> Dictionary:
	var objects := {}
	for i in 4:
		objects["f%d" % i] = _row("f%d" % i, "Forest", 0, true)
	objects["bear"] = _row("bear", "Grizzly Bears", 0)
	objects["angel"] = _row("angel", "Serra Angel", 0)
	objects["lion"] = _row("lion", "Savannah Lions", 1)
	return {"turn": 3, "step": "main1", "active": 0,
		"players": [{"life": 20, "poison": 0, "hand": 5, "library": 40, "mana": {}},
			{"life": 20, "poison": 0, "hand": 6, "library": 40, "mana": {}}],
		"objects": objects, "stack": [], "combat": {"attackers": [], "blocks": []}}


func _replay(state: Dictionary) -> MpnDuelTable:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var table := MpnDuelTable.new()
	viewport.add_child(table)
	table.present(state, _headers())
	return table


func _shown(table: MpnDuelTable, handle: String) -> MiniCard:
	return _widget_of(table, table.projection.find_instance(table.projection.local_id(handle)))


func test_a_replay_keeps_an_unchanged_card_over_a_step() -> void:
	var state := _state()
	var table := _replay(state)
	for i in 4: await get_tree().process_frame
	var bear := _shown(table, "bear")
	var lion := _shown(table, "lion")
	assert_not_null(bear, "control: the bear is drawn")
	var built := table.slots_built
	state.objects.f0.tapped = true
	table.present(state, _headers())
	await get_tree().process_frame
	assert_eq(_shown(table, "bear"), bear, "the bear's own widget stands")
	assert_eq(_shown(table, "lion"), lion, "the other side's card too")
	assert_lte(table.slots_built - built, 1, "only the pile whose land turned was built again")


func test_a_kept_replay_reads_as_a_rebuilt_one_forward_and_back() -> void:
	var state := _state()
	var table := _replay(state)
	for i in 4: await get_tree().process_frame
	var steps: Array[Callable] = [
		func() -> void: state.objects.f1.tapped = true,
		func() -> void: state.objects.bear.damage = 1,
		func() -> void: state.objects.bear.counters = {"+1/+1": 2},
		func() -> void: state.objects.angel.tapped = true,
		func() -> void: state.objects["giant"] = _row("giant", "Hill Giant", 1),
		func() -> void: state.combat.attackers = ["angel"],
		func() -> void: state.objects.lion.face_down = true,
		# ...and back again: nothing of a later step stays on the table.
		func() -> void: state.objects.lion.face_down = false,
		func() -> void: state.combat.attackers = [],
		func() -> void: state.objects.erase("giant"),
		func() -> void: state.objects.angel.tapped = false,
		func() -> void: state.objects.bear.counters = {},
		func() -> void: state.objects.bear.damage = 0,
		# A handle that names another card is another card.
		func() -> void: state.objects.bear.name = "Gray Ogre",
	]
	for at in steps.size():
		steps[at].call()
		table.present(state, _headers())
		await get_tree().process_frame
		await _assert_reads_alike(table, "step %d" % at)
	assert_null(_shown(table, "giant") if table.projection.rows.has("giant") else null, "the card of a later step is gone")
	var bear := table.projection.find_instance(table.projection.local_id("bear"))
	assert_eq(bear.data.card_name, "Gray Ogre")
	assert_eq(bear.damage, 0, "and nothing of the earlier card is left on the new one")


# ----------------------------------------------------------- the Spell Chain --

func _duel() -> DuelScreen:
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	screen.config.pace = 1000.0
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


func _push(screen: DuelScreen, card_name: String, controller := 0) -> StackItem:
	var inst := CardInstance.new(CardRegistry.get_card(card_name), _next_id, controller)
	_next_id += 1
	inst.zone = Mtg.Zone.STACK
	screen.game._instances[inst.id] = inst
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.controller = controller
	item.card = inst
	item.description = "%s (test)" % card_name
	screen.game.stack.append(item)
	return item


func test_a_chain_object_keeps_its_entry_over_a_redraw() -> void:
	var screen := await _duel()
	_push(screen, "Giant Growth")
	_push(screen, "Lightning Bolt", 1)
	screen._refresh()
	await get_tree().process_frame
	var entries := screen._chain_box.get_children()
	assert_eq(entries.size(), 2, "control: one entry an object")
	var built := screen.chain_entries_built
	var third := _push(screen, "Counterspell")
	screen._refresh()
	await get_tree().process_frame
	assert_eq(screen._chain_box.get_child_count(), 3)
	assert_eq(screen._chain_box.get_child(0), entries[0], "the first entry stands")
	assert_eq(screen._chain_box.get_child(1), entries[1], "and the second")
	assert_eq(screen.chain_entries_built - built, 1, "only the new object's entry was built")
	screen.game.stack.erase(third)
	screen.game.stack.remove_at(0)
	screen._refresh()
	await get_tree().process_frame
	assert_eq(screen._chain_box.get_child_count(), 1, "a resolved object's entry goes")
	assert_eq(screen._chain_box.get_child(0), entries[1])
	screen.game.stack.clear()
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame


func test_a_kept_chain_reads_as_a_rebuilt_one() -> void:
	var screen := await _duel()
	var growth := _push(screen, "Giant Growth")
	_push(screen, "Lightning Bolt", 1)
	screen._refresh()
	await get_tree().process_frame
	await _assert_reads_alike(screen, "two spells")
	growth.description = "Giant Growth (retargeted)"
	growth.x_value = 2
	await _assert_reads_alike(screen, "a spell whose words changed")
	_push(screen, "Counterspell")
	await _assert_reads_alike(screen, "a third spell")
	screen.game.stack.remove_at(1)
	await _assert_reads_alike(screen, "one resolved from the middle")
	screen.game.stack.clear()
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
