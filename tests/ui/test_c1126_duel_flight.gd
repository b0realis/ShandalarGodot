extends GutTest
## THE SPELL FLIGHT LOOKS AT THE TABLE ONLY WHEN IT IS REDRAWN (campaign
## 2026-11-26, smoothness 5): no walk of the duel screen in every frame,
## and a frame of its own only while a flight waits to start.

var screen: DuelScreen
var _next_id := 97200


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	screen.config.pace = 1000.0
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	# The suite has no display; this is the layer as a player's screen runs it.
	screen._flight.samples = true


func _card(pid: int, card_name: String, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), _next_id, pid)
	_next_id += 1
	g._instances[inst.id] = inst
	inst.zone = zone
	if zone == Mtg.Zone.HAND:
		g.players[pid].hand.append(inst)
	else:
		g._put_on_battlefield(inst, pid)
	return inst


func test_no_frame_is_spent_while_nothing_flies() -> void:
	_card(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(screen._flight.is_processing(), "the layer sleeps between redraws")


func test_a_redraw_reads_where_the_cards_stand() -> void:
	var bear := _card(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	screen._refresh()
	assert_true(screen._flight._rects.has(bear.id), "the bear's place is known from the redraw")
	var read: Rect2 = screen._flight._rects[bear.id]
	# A second redraw in the same frame reads nothing: the cards the first
	# one built have not been laid out yet.
	screen._flight._rects[bear.id] = Rect2(1, 2, 3, 4)
	screen._refresh()
	assert_eq(screen._flight._rects[bear.id], Rect2(1, 2, 3, 4), "one reading a frame")
	await get_tree().process_frame
	screen._refresh()
	assert_eq(screen._flight._rects[bear.id], read, "and a fresh one in the next")


func test_a_cast_spell_flies_and_the_layer_sleeps_again() -> void:
	var bolt := _card(0, "Lightning Bolt", Mtg.Zone.HAND)
	screen._flight._rects[bolt.id] = Rect2(Vector2(600, 600), Vector2(132, 106))
	screen._flight._sampled_frame = Engine.get_process_frames()   # the reading above stands
	screen.game.players[0].hand.erase(bolt)
	bolt.zone = Mtg.Zone.STACK
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.controller = 0
	item.card = bolt
	item.description = "Lightning Bolt (test)"
	screen.game.stack.append(item)
	screen._refresh()
	assert_true(screen._flight.is_flying(bolt.id), "the spell is on its way to the chain")
	assert_true(screen._flight.is_processing(), "the layer wakes for the flight's start")
	for i in 4:
		await get_tree().process_frame
	assert_true(screen._flight._pending.is_empty(), "the flight started")
	assert_false(screen._flight.is_processing(), "and the layer sleeps while the card is in the air")
	await wait_seconds(SpellFlight.MOVE_SECONDS + 0.2)
	assert_false(screen._flight.is_flying(bolt.id), "it landed")
	screen.game.stack.clear()
	screen._refresh()
	await get_tree().process_frame
	await wait_seconds(SpellFlight.MOVE_SECONDS + 0.2)
