extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: three things the table
## drew or did wrong with cards that are not simply standing in a row.
##
##   1. DRAGGING THE WRONG CARD. `DuelScreen._layout_root` handed back the
##      widget itself when it found no table row above it, and the drag
##      wrote its placement for whatever card the widget showed. An
##      ability's card on the chain shows its source permanent, so a 5 px
##      slip while clicking a Prodigal Sorcerer's ping on the chain moved
##      the Sorcerer on the table to where the chain card was let go (the
##      Combat window's cards the same). An Aura's band carried its host's
##      wrap, but the drop was written for the Aura, which the free layer
##      never draws: the stack snapped back. NOW only a card on the table
##      is dragged, and an attachment carries its host.
##   2. AN AURA CLIPPED. Headroom above a territory's first row was kept
##      for a Magical Hack's reminder only; a real Aura on a land there
##      (Wild Growth, Psychic Venom) lost 12 of its band's 18 px — and its
##      name — to the half's clip, in either half.
##   3. A PILE'S FACES KNEW NO DUEL. `CardPile` built them with no game, so
##      under Winter Orb a tapped land in a pile promised "This card will
##      untap" (a land standing alone does not), and a piled permanent a
##      spell on the chain names never wore `Is a target`.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	screen.set_deferred("size", Vector2(1280, 800))
	await get_tree().process_frame
	await get_tree().process_frame
	var g: MtgGame = screen.game
	g._probing = true
	for p in g.players:
		p.hand.clear()
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g._probing = false


func after_each() -> void:
	# The refresh drops old card widgets at once and frees them at frame end.
	await get_tree().process_frame
	await get_tree().process_frame


func _put(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func _enchant(host: CardInstance, aura_name: String, controller: int) -> CardInstance:
	var g: MtgGame = screen.game
	var aura := CardInstance.new(CardRegistry.get_card(aura_name), g._next_instance_id, controller)
	g._next_instance_id += 1
	g._instances[aura.id] = aura
	g.attach_aura_from_anywhere(aura, host, controller)
	return aura


func _faces(root: Node, inst: CardInstance) -> Array:
	var out: Array = []
	for node in root.find_children("*", "MiniCard", true, false):
		if (node as MiniCard).instance == inst and not node.is_queued_for_deletion():
			out.append(node)
	return out


## A press on [param w], the pointer past the slop, and the release.
func _drag(w: MiniCard, inst: CardInstance) -> void:
	screen._begin_drag(w, inst, w.global_position)
	if screen._drag_root == null:
		return
	screen._dragging = true
	screen._drag_root.global_position += Vector2(40, 10)
	screen._commit_drag()


func _redraw() -> void:
	screen._refresh()
	for _frame in 3:
		await get_tree().process_frame


# ------------------------------------------------- 1. dragging the wrong card --

func test_an_auras_band_carries_its_host() -> void:
	var bear := _put(0, "Grizzly Bears")
	var aura := _enchant(bear, "Holy Strength", 0)
	screen._refresh()
	var bands := _faces(screen, aura)
	assert_eq(bands.size(), 1, "control: the Aura is drawn in its host's fan")
	if bands.is_empty():
		return
	_drag(bands[0], aura)
	assert_false(screen._placements.has(aura.id), "no placement the free layer would never draw")
	assert_true(screen._placements.has(bear.id), "the host is what was carried, and it stays put")


func test_an_auras_band_on_the_other_seats_card_carries_that_card() -> void:
	# Psychic Venom's shape: the Aura is the opponent's, the land is yours.
	var forest := _put(0, "Forest")
	var aura := _enchant(forest, "Wild Growth", 1)
	screen._refresh()
	var bands := _faces(screen, aura)
	if bands.is_empty():
		fail_test("the Aura is not drawn")
		return
	_drag(bands[0], aura)
	assert_true(screen._placements.has(forest.id), "placed in the land's own half")


func test_an_abilitys_chain_card_is_not_its_source_on_the_table() -> void:
	var sorcerer := _put(0, "Prodigal Sorcerer")
	assert_eq(screen.game.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]), "")
	screen._refresh()
	var on_chain := _faces(screen._chain_box, sorcerer)
	assert_eq(on_chain.size(), 1, "control: the ping's card on the chain")
	if on_chain.is_empty():
		return
	_drag(on_chain[0], sorcerer)
	assert_null(screen._drag_root, "a card off the table arms no drag")
	assert_false(screen._placements.has(sorcerer.id), "the Sorcerer on the table did not move")


func test_a_card_on_the_table_still_moves() -> void:
	var bear := _put(0, "Grizzly Bears")
	screen._refresh()
	var faces := _faces(screen, bear)
	if faces.is_empty():
		fail_test("the Bears are not drawn")
		return
	_drag(faces[0], bear)
	assert_true(screen._placements.has(bear.id))


# ------------------------------------------------------- 2. an aura clipped --

func test_an_aura_on_a_first_row_land_is_whole_in_either_half() -> void:
	for pid in [0, 1]:
		var aura := _enchant(_put(pid, "Forest"), "Wild Growth", pid)
		await _redraw()
		var half: Rect2 = screen._free_layers[pid].get_global_rect()
		var bands := _faces(screen, aura)
		assert_eq(bands.size(), 1)
		for band in bands:
			assert_true(half.encloses((band as Control).get_global_rect()),
				"seat %d: the band shows whole inside its territory" % pid)


func test_a_creatures_aura_reserves_nothing() -> void:
	_enchant(_put(0, "Grizzly Bears"), "Holy Strength", 0)
	await _redraw()
	assert_eq(screen._half_rows[0].offset_top, DuelScreen.BOARD_INSET_V,
		"the creatures' row overflows into empty board")


# ---------------------------------------------------- 3. a pile's faces --

func test_a_piled_tapped_land_under_winter_orb_promises_no_untap() -> void:
	_put(0, "Winter Orb")
	var a := _put(0, "Mountain")
	var b := _put(0, "Mountain")
	a.tapped = true
	b.tapped = true
	screen.game.recalculate()
	assert_false(screen.game.untap_caps.is_empty(), "control: the Orb caps the untap")
	screen._refresh()
	var faces := _faces(screen, a)
	assert_eq(faces.size(), 1)
	if faces.is_empty():
		return
	assert_true((faces[0] as Node).get_parent().get_parent() is CardPile, "control: in a pile")
	assert_false((faces[0] as MiniCard).active_states().has(MiniCard.State.WILL_UNTAP),
		"no 'This card will untap' under Winter Orb")


func test_a_piled_tapped_land_with_no_orb_still_promises_it() -> void:
	var a := _put(0, "Mountain")
	var b := _put(0, "Mountain")
	a.tapped = true
	b.tapped = true
	screen._refresh()
	var faces := _faces(screen, a)
	if faces.is_empty():
		fail_test("not drawn")
		return
	assert_true((faces[0] as MiniCard).active_states().has(MiniCard.State.WILL_UNTAP))


func test_a_piled_land_a_spell_names_is_a_target() -> void:
	var g: MtgGame = screen.game
	var a := _put(1, "Mountain")
	_put(1, "Mountain")
	var rain := CardInstance.new(CardRegistry.get_card("Stone Rain"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[rain.id] = rain
	rain.zone = Mtg.Zone.HAND
	g.players[0].hand.append(rain)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 3)
	assert_eq(g.cast_spell(0, rain, [TargetRef.card(a)]), "", "control: Stone Rain at the Mountain")
	screen._refresh()
	var faces := _faces(screen, a)
	if faces.is_empty():
		fail_test("not drawn")
		return
	assert_true((faces[0] as Node).get_parent().get_parent() is CardPile, "control: in a pile")
	assert_true((faces[0] as MiniCard).active_states().has(MiniCard.State.IS_TARGET),
		"the piled Mountain wears 'Is a target'")
