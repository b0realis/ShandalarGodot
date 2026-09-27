extends GutTest
## THE CARD UNDERNEATH SHOWED THROUGH — the owner's playtest, 2026-09-27:
## *"If you put one small card over the other in the playfield the title
## text and power and toughness and other is seen on the top card. I mean
## picked up small card should just cover what is in the bottom."*
##
## THE FREE LAYER WAS RIGHT AND STILL LOST. `DuelScreen._rebuild_placed`
## adds the cards the player moved by hand in the order they were last
## touched, so the one on top is the last child — and the canvas sorts by
## `z_index` BEFORE it sorts by order. A [MiniCard] used to give its own
## children a z of their own (the name and the `(T)` 2, the P/T, the mana
## stripes, the tap wash, the counter stones and the pending dagger 1, the
## highlight ring 2) to order them among themselves — and z is relative,
## so a name at 2 inside the card underneath stood above the whole face
## of the card on top, whose face sat at 0. The same escape put an
## enchanted host's face ([code]HOST_Z[/code], 3, gone with this) through
## a card placed over it, and a pile's or a fanned hand's name band over
## the card that covers it.
##
## THE RULE THIS PINS: a card is opaque. Nothing inside a [MiniCard]
## carries a z_index — its parts are ordered by the child list alone, so
## the whole card sorts as one thing against its neighbours, and whatever
## is drawn after it covers every pixel of it.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	screen.stops.clear_all()


func _mk(card_name: String, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	return inst


func _summon(card_name: String, pid: int, sick := false) -> CardInstance:
	var inst := _mk(card_name, pid)
	screen.game._put_on_battlefield(inst, pid)
	inst.summoning_sick = sick
	return inst


func _enchant(card_name: String, host: CardInstance, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var aura := _mk(card_name, pid)
	aura.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(aura)
	g.attach_aura_from_anywhere(aura, host, pid)
	return aura


## Every [MiniCard] the screen currently has on it, by instance id.
func _drawn() -> Dictionary:
	var out := {}
	var stack: Array = [screen]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MiniCard and (n as MiniCard).instance != null:
			out[(n as MiniCard).instance.id] = n
		for c in n.get_children():
			stack.append(c)
	return out


# ------------------------------------------ what the canvas sorts by --

## `z_index` summed up the tree to [param top], z being relative.
func _z_under(node: Node, top: Node) -> int:
	var z := 0
	var n: Node = node
	while n != null and n != top:
		if n is CanvasItem:
			z += (n as CanvasItem).z_index
		n = n.get_parent()
	return z


## Does [param over] draw over [param under]? The canvas's own order:
## the higher z wins, and at equal z the node later in the tree does.
func _draws_over(over: Node, under: Node, top: Node) -> bool:
	var a := _z_under(over, top)
	var b := _z_under(under, top)
	if a != b:
		return a > b
	return over.is_greater_than(under)


## Every CanvasItem in [param node]'s subtree, itself included.
func _parts(node: Node) -> Array:
	var out: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


## The parts of [param under] that [param over]'s own face fails to cover.
func _showing_through(over: CanvasItem, under: Node, top: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for part in _parts(under):
		if not _draws_over(over, part, top):
			out.append("%s (z %d)" % [part.name if part.name != "" else part.get_class(),
				_z_under(part, top)])
	return out


## The card [param inst] is drawn as, wearing everything a card can wear:
## a name, a P/T, the tap mark, counter stones, a pending dagger, a
## shield, every lazy overlay and a highlight ring — the things that used
## to carry a z of their own.
func _dress(w: MiniCard) -> void:
	w.instance.counters["+1/+1"] = 2
	w.instance.prevention = 3
	w.force_dying = true
	w.set_target_state(MiniCard.State.IS_TARGET)
	for state in MiniCard.LAZY_OVERLAYS:
		w._ensure_overlay(state)
	w.set_highlight(MiniCard.Highlight.OPTIONAL)
	w._refresh_highlight_ring(true)
	w.refresh()


# ====================================== THE TABLE THE REPORT DESCRIBES --

func test_a_card_placed_over_another_covers_every_pixel_of_it() -> void:
	var under := _summon("Savannah Lions", 0)
	under.tapped = true
	var over := _summon("Grizzly Bears", 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, under, layer.global_position + Vector2(40, 30))
	screen._place_card(0, over, layer.global_position + Vector2(60, 45))
	screen._refresh()
	await get_tree().process_frame
	var drawn := _drawn()
	var bottom: MiniCard = drawn.get(under.id)
	var top: MiniCard = drawn.get(over.id)
	assert_not_null(bottom, "the Lions are on the free layer")
	assert_not_null(top, "and so are the Bears, placed over them")
	assert_true(layer.is_ancestor_of(bottom), "the tapped Lions in their holder")
	assert_eq(top.get_parent(), layer)
	_dress(bottom)
	assert_true(bottom.get_parent() != top.get_parent() \
		or bottom.get_index() < top.get_index(),
		"the card touched last is added last")
	assert_eq(_showing_through(top, bottom, layer), PackedStringArray(),
		"and nothing of the card underneath — name, P/T, (T), stones, "
		+ "ring, cracks — shows through the face of the card on top")


func test_a_card_placed_over_an_enchanted_host_covers_the_host_too() -> void:
	# The host of a fan used to stand at HOST_Z (3) inside its wrap so it
	# covered its aura's ring — the same escape, one level up: three above
	# the face of any plain card placed over it afterwards.
	var elves := _summon("Llanowar Elves", 0)
	_enchant("Instill Energy", elves, 0)
	var over := _summon("Grizzly Bears", 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, elves, layer.global_position + Vector2(40, 30))
	screen._place_card(0, over, layer.global_position + Vector2(50, 40))
	screen._refresh()
	await get_tree().process_frame
	var drawn := _drawn()
	var host: MiniCard = drawn.get(elves.id)
	var top: MiniCard = drawn.get(over.id)
	assert_not_null(host, "the enchanted Elves are on the free layer")
	assert_not_null(top, "under the Bears")
	assert_eq(top.get_parent(), layer)
	assert_true(layer.is_ancestor_of(host), "the host's fan sits on the layer")
	_dress(host)
	assert_eq(_showing_through(top, host, layer), PackedStringArray(),
		"nothing of the host shows through the card placed over it")
	assert_eq(host.z_index, 0, "a host rests at 0 like any other card")


func test_the_host_still_covers_its_aura() -> void:
	# The 2026-09-07 defect this replaces the mechanism of: the aura's
	# yellow ring must not paint over the host's face. Child order alone
	# does it now, because the ring no longer carries a z of its own.
	var elves := _summon("Llanowar Elves", 0)
	var energy := _enchant("Instill Energy", elves, 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var drawn := _drawn()
	var host: MiniCard = drawn.get(elves.id)
	var back: MiniCard = drawn.get(energy.id)
	assert_not_null(host)
	assert_not_null(back)
	back.set_highlight(MiniCard.Highlight.OPTIONAL)
	back._refresh_highlight_ring(true)
	assert_not_null(back._highlight_ring, "the aura is ringed")
	assert_eq(_showing_through(host, back, back.get_parent()), PackedStringArray(),
		"and the host covers all of it, ring included")


# ================================================ THE CARD IS OPAQUE --

func test_nothing_inside_a_card_carries_a_z_of_its_own() -> void:
	var lion := _summon("Savannah Lions", 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var w: MiniCard = _drawn().get(lion.id)
	_dress(w)
	for part in _parts(w):
		assert_eq((part as CanvasItem).z_index, 0,
			"%s is ordered by the child list, not by z" % part.name)


func test_the_parts_are_ordered_by_the_child_list_as_the_z_used_to() -> void:
	# Bottom to top, as `_build_face` always meant: the art and its cues,
	# the lazy overlays (cracks, arrow, stamps) over the spiral, then the
	# stones, the dagger, the stripes, the wash, the P/T and the shield
	# over those, and the name, the (T) and the ring over everything.
	var lion := _summon("Savannah Lions", 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var w: MiniCard = _drawn().get(lion.id)
	_dress(w)
	var cracks: Node = w._overlays[MiniCard.State.DYING]
	var stamp: Node = w._overlays[MiniCard.State.IS_TARGET]
	assert_true(_draws_over(cracks, w._sick_spiral, w), "cracks over the spiral")
	assert_true(_draws_over(stamp, cracks, w), "the stamp over the cracks")
	assert_true(_draws_over(w._pt_label, stamp, w), "the P/T over the stamp")
	assert_true(_draws_over(w._pt_label, cracks, w), "and over the cracks")
	assert_true(_draws_over(w._counter_row, cracks, w), "the stones over the cracks")
	assert_true(_draws_over(w._shield_words, cracks, w), "the shield over the cracks")
	assert_true(_draws_over(w._tap_wash, w._stripes, w), "the wash over the stripes")
	assert_true(_draws_over(w._name_label, w._tap_wash, w), "the name over the wash")
	assert_true(_draws_over(w._tap_mark, w._tap_wash, w), "the (T) over the wash")
	assert_true(_draws_over(w._highlight_ring, w._name_label, w), "the ring over the name")
	for part in _parts(w):
		if part != w._highlight_ring and part != w:
			assert_true(_draws_over(w._highlight_ring, part, w),
				"the ring over %s" % part.name)
	# A lazy overlay built AFTER the ring still lands under the face parts.
	var late := _summon("Grizzly Bears", 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var w2: MiniCard = _drawn().get(late.id)
	w2.set_highlight(MiniCard.Highlight.OPTIONAL)
	w2._refresh_highlight_ring(true)
	w2.instance.prevention = 2
	w2.refresh()
	w2.force_dying = true
	w2.refresh()
	var late_cracks: Node = w2._overlays[MiniCard.State.DYING]
	assert_true(_draws_over(w2._pt_label, late_cracks, w2), "the P/T over late cracks")
	assert_true(_draws_over(w2._shield_words, late_cracks, w2), "the shield over late cracks")
	assert_true(_draws_over(w2._name_label, late_cracks, w2), "the name over late cracks")
	assert_true(_draws_over(w2._highlight_ring, late_cracks, w2), "the ring over late cracks")


func test_a_piled_land_covers_the_name_band_of_the_one_beneath() -> void:
	# A pile steps its holders by one z and cascades them by the title
	# bar's height, so the covered card's name band is the strip that
	# shows. Its name is no longer two z above its holder, so where the
	# next card does overlap it — the P/T corner, the art — it covers.
	var ids := {}
	for i in 3:
		ids[_summon("Mountain", 0).id] = true
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var pile: CardPile = null
	var faces: Array = []
	for w in _drawn().values():
		if ids.has(w.instance.id) and w.get_parent() != null \
				and w.get_parent().get_parent() is CardPile:
			pile = w.get_parent().get_parent()
			faces.append(w)
	assert_not_null(pile, "three Mountains make a pile")
	assert_eq(faces.size(), 3)
	faces.sort_custom(func(a, b): return a.get_parent().get_index() < b.get_parent().get_index())
	assert_eq(_showing_through(faces[1], faces[0], pile), PackedStringArray(),
		"the second card covers every part of the first it lies over")
	assert_eq(_showing_through(faces[2], faces[1], pile), PackedStringArray(),
		"and the third the second")
