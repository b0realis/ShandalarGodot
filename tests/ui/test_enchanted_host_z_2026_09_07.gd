extends GutTest
## THE AURA THAT DREW OVER ITS HOST — the playtest defect of 2026-09-07.
##
## *"I have Llanowar Elves and on them enchantment Instill Energy. The
## yellow border from the enchantment Instill Energy is seen on top of
## Llanowar Elves mini card — it should be in the back."*
##
## CHILD ORDER WAS RIGHT AND STILL LOST. `DuelScreen._make_widget` draws
## an attachment as a whole card behind its host, offset by
## [constant DuelScreen.AURA_PEEK], and adds the host LAST so it overlaps
## everything behind it — and `tests/ui/test_card_dimensions.gd` pins
## exactly that order. But a [MiniCard] gives three of its own children a
## `z_index` of 2 — the name, the `(T)` and the highlight ring
## (`_build_face`, `_refresh_highlight_ring`) — and the canvas sorts by z
## BEFORE it sorts by order. Instill Energy has an ability of its own to
## offer ("untap enchanted creature"), so `DuelScreen._highlight_for` rang
## it [constant MiniCard.Highlight.OPTIONAL] — yellow — and a ring at z 2
## on the card BEHIND painted straight over the face of the card in front,
## whose own face sits at 0. What the player saw was a yellow frame around
## the Elves that belonged to the aura.
##
## THE RULE THIS PINNED FIRST was a `DuelScreen.HOST_Z` (3): the host of
## a fan stood one z above the highest z any card gave its own children.
## That was the same defect one level up — a host at 3 stood above the
## face of a plain card placed over it — and 2026-09-27 retired it with
## the z's it answered (`tests/ui/test_card_over_card_2026_09_27.gd`).
##
## THE RULE THIS PINS NOW: no part of a card carries a z, so the host,
## LAST in its wrap, covers all of an attachment but the strip that peeks
## out by child order alone; and the right-hold lift, which raises a card
## by z and puts it back, puts an enchanted host back at 0 like any card,
## which is still over its aura.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()


func _mk(card_name: String, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	return inst


func _summon(card_name: String, pid: int) -> CardInstance:
	var inst := _mk(card_name, pid)
	screen.game._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
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


## What the canvas actually sorts [param node] by: its `z_index` summed
## up the tree to [param top], z being relative to the parent's.
func _z_under(node: Node, top: Node) -> int:
	var z := 0
	var n: Node = node
	while n != null and n != top:
		if n is CanvasItem:
			z += (n as CanvasItem).z_index
		n = n.get_parent()
	return z


## The highest z anything in [param node]'s subtree reaches, under [param top].
func _top_z_in(node: Node, top: Node) -> int:
	var best := _z_under(node, top)
	for c in node.get_children():
		best = maxi(best, _top_z_in(c, top))
	return best


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


## Does [param over]'s own face draw over EVERY part of [param under]?
func _covers(over: CanvasItem, under: Node, top: Node) -> bool:
	for part in _parts(under):
		if not _draws_over(over, part, top):
			return false
	return true


## The fan the report describes, drawn. The aura's ring is put up by hand
## — `_refresh_highlight_ring(true)` — because it only ever exists on the
## skinned frame and the gate may run without the 1997 art imported;
## what is pinned here is the z it carries, which does not depend on art.
## Returns [host widget, aura widget, the wrap both sit in].
func _the_elves_and_their_energy(tapped := false) -> Array:
	var elves := _summon("Llanowar Elves", 0)
	elves.tapped = tapped
	var energy := _enchant("Instill Energy", elves, 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var drawn := _drawn()
	var host_w: MiniCard = drawn.get(elves.id)
	var back: MiniCard = drawn.get(energy.id)
	assert_not_null(host_w, "the Elves are on the board")
	assert_not_null(back, "so is the Instill Energy, behind them")
	back.set_highlight(MiniCard.Highlight.OPTIONAL)
	back._refresh_highlight_ring(true)
	return [host_w, back, back.get_parent()]


# ==================================== THE BOARD THE REPORT DESCRIBES --

func test_the_host_stands_above_every_pixel_of_its_attachment() -> void:
	var fan: Array = await _the_elves_and_their_energy()
	var host_w: MiniCard = fan[0]
	var back: MiniCard = fan[1]
	var wrap: Node = fan[2]
	assert_not_null(back._highlight_ring, "the aura is ringed — yellow, "
		+ "because Instill Energy has an untap to offer")
	# What the player saw: the ring two above the host's face. Now the
	# ring, like the name and the (T), carries no z at all...
	assert_eq(_z_under(back._highlight_ring, wrap), 0,
		"the ring rides at 0 inside the aura, as the name and (T) do")
	assert_eq(_top_z_in(back, wrap), 0, "nothing in the aura is above 0")
	assert_eq(host_w.z_index, 0, "and the host carries none either")
	# ...so child order is the whole of it, and it says the right thing.
	assert_lt(back.get_index(), host_w.get_index(),
		"the host is added after the aura")
	assert_true(_covers(host_w, back, wrap),
		"...and so stands above ALL of it, ring included")


func test_a_tapped_host_covers_its_aura_from_inside_its_holder() -> void:
	# Turned, the card sits inside its rotation holder and the holder is
	# the fan's last child — so the holder's place is what covers.
	var fan: Array = await _the_elves_and_their_energy(true)
	var host_w: MiniCard = fan[0]
	var back: MiniCard = fan[1]
	var wrap: Node = fan[2]
	assert_ne(host_w.get_parent(), wrap, "the tapped host is in a holder")
	assert_eq(host_w.z_index, 0, "the card inside rests at 0...")
	assert_eq(_z_under(host_w, wrap), 0, "...and so does its holder")
	assert_eq(host_w.get_parent().get_index(), wrap.get_child_count() - 1,
		"the holder is the fan's last child")
	assert_true(_covers(host_w, back, wrap),
		"and the turned host still covers the aura's ring")


func test_a_card_gives_none_of_its_children_a_z() -> void:
	# The rule is not free: a card whose parts carry a z of their own is a
	# card whose parts show through whatever lies on it, one row step or
	# one free-layer step notwithstanding — and a host lifted to clear
	# them showed through in turn. So the tallest thing on a card is the
	# card, at 0; a pile's last card is inside its row's step; and the
	# free layer is under the combat window and under a right-held card.
	var lion := _summon("Savannah Lions", 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var w: MiniCard = _drawn().get(lion.id)
	w.set_highlight(MiniCard.Highlight.OPTIONAL)
	w._refresh_highlight_ring(true)
	assert_eq(_top_z_in(w, w), 0, "nothing on a card is above the card")
	assert_lt(DuelScreen.PILE_SIZE - 1 + _top_z_in(w, w), DuelScreen.ROW_Z_STEP,
		"a pile's last card is still inside its row's step")
	assert_lt(DuelScreen.FREE_LAYER_Z + _top_z_in(w, w),
		screen._combat_window.z_index,
		"and a card on the free layer is still under the combat window")
	assert_gt(DuelScreen.LIFT_Z, DuelScreen.FREE_LAYER_Z + _top_z_in(w, w),
		"and under a right-held neighbour")


# ============================================ THE LIFT PUTS IT BACK --

func _right(pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = pressed
	return ev


func test_a_right_held_host_drops_back_onto_its_aura_not_under_it() -> void:
	# The lift is a z_index of LIFT_Z and a reset. A reset to 0 used to put
	# the Elves back UNDER the ring the moment the button was let go, until
	# the next rebuild — because the ring stood at 2. It stands at 0 now,
	# so 0 IS over the aura, by child order.
	var fan: Array = await _the_elves_and_their_energy()
	var host_w: MiniCard = fan[0]
	var back: MiniCard = fan[1]
	var wrap: Node = fan[2]
	screen._on_card_look(_right(true), host_w, host_w.instance)
	# LIFT_Z on the SCREEN's ladder: z is relative and the row stands on
	# a step of its own (ROW_Z_STEP), which the lift takes off.
	assert_eq(host_w.z_index + screen._z_under(host_w), DuelScreen.LIFT_Z,
		"held to the front")
	screen._on_card_look(_right(false), host_w, host_w.instance)
	assert_eq(host_w.z_index, 0,
		"and put back where it RESTED — 0, like any card")
	assert_true(_covers(host_w, back, wrap), "which is still over the aura")


func test_a_plain_card_still_drops_back_to_zero() -> void:
	var lion := _summon("Savannah Lions", 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var w: MiniCard = _drawn().get(lion.id)
	assert_eq(w.z_index, 0, "an unenchanted card rests at 0")
	screen._on_card_look(_right(true), w, lion)
	assert_eq(w.z_index + screen._z_under(w), DuelScreen.LIFT_Z)
	assert_eq(screen._z_under(w), DuelScreen.Row.CREATURES * DuelScreen.ROW_Z_STEP,
		"a creature's row is two steps up")
	screen._on_card_look(_right(false), w, lion)
	assert_eq(w.z_index, 0, "and goes back to 0, as it always did")
