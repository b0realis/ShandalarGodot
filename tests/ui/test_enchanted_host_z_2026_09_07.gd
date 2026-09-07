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
## THE RULE THIS PINS: the host of a fan stands one z above the highest z
## any card gives its own children ([constant DuelScreen.HOST_Z]), so it
## covers all of an attachment but the strip that peeks out; and the
## right-hold lift, which raises a card by z and puts it back, puts an
## enchanted host back at HOST_Z and not at 0.

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
	# What the player saw: the ring two above the host's face.
	assert_eq(_z_under(back._highlight_ring, wrap), 2,
		"the ring rides at z 2 inside the aura, as the name and (T) do")
	assert_gt(_z_under(host_w, wrap), _top_z_in(back, wrap),
		"...and the host stands above ALL of it, ring included")
	assert_eq(host_w.z_index, DuelScreen.HOST_Z,
		"the untapped host carries HOST_Z itself")
	assert_lt(back.get_index(), host_w.get_index(),
		"child order still says the same thing")


func test_a_tapped_host_is_lifted_by_its_holder() -> void:
	# Turned, the card sits inside its rotation holder and the holder is
	# the fan's last child — so the holder is what carries the z.
	var fan: Array = await _the_elves_and_their_energy(true)
	var host_w: MiniCard = fan[0]
	var back: MiniCard = fan[1]
	var wrap: Node = fan[2]
	assert_ne(host_w.get_parent(), wrap, "the tapped host is in a holder")
	assert_eq(host_w.z_index, 0, "the card inside rests at 0...")
	assert_eq(_z_under(host_w, wrap), DuelScreen.HOST_Z,
		"...its holder at HOST_Z")
	assert_gt(_z_under(host_w, wrap), _top_z_in(back, wrap),
		"and the turned host still covers the aura's ring")


func test_host_z_is_one_above_a_cards_own_children() -> void:
	# The number is not free: one above the highest z a card gives its own
	# children, or the fix is by luck; and under the combat window's 10,
	# or an attacker wearing an aura draws through the window it stands in.
	var lion := _summon("Savannah Lions", 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var w: MiniCard = _drawn().get(lion.id)
	w.set_highlight(MiniCard.Highlight.OPTIONAL)
	w._refresh_highlight_ring(true)
	assert_eq(DuelScreen.HOST_Z, _top_z_in(w, w) + 1,
		"HOST_Z is exactly one above the tallest thing on a card")
	assert_lt(DuelScreen.HOST_Z + _top_z_in(w, w), 10,
		"and a host's tallest child is still under the combat window")
	assert_gt(DuelScreen.LIFT_Z, DuelScreen.HOST_Z + _top_z_in(w, w),
		"and under a right-held neighbour")


# ============================================ THE LIFT PUTS IT BACK --

func _right(pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = pressed
	return ev


func test_a_right_held_host_drops_back_onto_its_aura_not_under_it() -> void:
	# The lift is a z_index of LIFT_Z and a reset — and a reset to 0 would
	# have put the Elves back UNDER the ring the moment the button was let
	# go, until the next rebuild.
	var fan: Array = await _the_elves_and_their_energy()
	var host_w: MiniCard = fan[0]
	screen._on_card_look(_right(true), host_w, host_w.instance)
	assert_eq(host_w.z_index, DuelScreen.LIFT_Z, "held to the front")
	screen._on_card_look(_right(false), host_w, host_w.instance)
	assert_eq(host_w.z_index, DuelScreen.HOST_Z,
		"and put back where it RESTED — over the aura, not at 0")


func test_a_plain_card_still_drops_back_to_zero() -> void:
	var lion := _summon("Savannah Lions", 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	var w: MiniCard = _drawn().get(lion.id)
	assert_eq(w.z_index, 0, "an unenchanted card rests at 0")
	screen._on_card_look(_right(true), w, lion)
	assert_eq(w.z_index, DuelScreen.LIFT_Z)
	screen._on_card_look(_right(false), w, lion)
	assert_eq(w.z_index, 0, "and goes back to 0, as it always did")
