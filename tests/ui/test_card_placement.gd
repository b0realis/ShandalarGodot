extends GutTest
## MOVING A CARD BY HAND — the owner's playtest, 2026-09-03: *"Summoned
## mini cards on the table should be freely movable on the table as per
## player choice — selected one over the others."*
##
## It is the table the 1997 game had: `Duel.hlp`, topic **Territory**,
## *"**Arrange Cards** STRAIGHTENS UP the cards in play in the territory
## where you right-clicked. This has no effect on the duel, it just makes
## things neater"* — nothing needs straightening unless it can be crooked,
## and *"this has no effect on the duel"* is why not one engine call
## happens anywhere in this feature.
##
## Before the fix a permanent was wherever its row put it and there was no
## placement, no free layer and no drag.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame


func _bear(pid := 0, id := 94001) -> CardInstance:
	var g: MtgGame = screen.game
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), id, pid)
	g._instances[bear.id] = bear
	g._put_on_battlefield(bear, pid)
	screen._refresh()
	return bear


# ---------------------------------------------------------- the placement --

func test_a_placed_card_leaves_its_row_for_the_free_layer() -> void:
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	assert_not_null(layer, "each half has an absolute layer over its rows")
	assert_eq(layer.get_child_count(), 0, "nothing is placed yet")
	screen._place_card(0, bear, layer.global_position + Vector2(120, 60))
	screen._refresh()
	assert_eq(layer.get_child_count(), 1, "the bear is drawn where it was put")
	var row: Container = screen._field_rows[0][DuelScreen.Row.CREATURES]
	assert_eq(row.get_child_count(), 0, "and no longer laid out by its row")


func test_the_placement_is_the_halfs_own_coordinates() -> void:
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, bear, layer.global_position + Vector2(100, 50))
	assert_eq(screen._placements[bear.id], Vector2(100, 50),
		"stored relative to the half, so a resize cannot strand a card")


func test_a_card_cannot_be_dropped_off_the_table() -> void:
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	var bounds: Rect2 = screen._placement_bounds(0)
	screen._place_card(0, bear, layer.global_position + Vector2(-500, -500))
	assert_eq(screen._placements[bear.id], bounds.position,
		"clamped to the inset the rows keep too, not to the raw half")
	screen._place_card(0, bear, layer.global_position + Vector2(99999, 99999))
	var placed: Vector2 = screen._placements[bear.id]
	assert_lt(placed.x, layer.size.x, "still inside its own territory")


func test_the_card_last_moved_draws_over_the_others() -> void:
	# The owner's "selected one over the others": the free layer adds its
	# children in the dictionary's insertion order, and a move re-inserts.
	var first := _bear(0, 94001)
	var second := _bear(0, 94002)
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, first, layer.global_position)
	screen._place_card(0, second, layer.global_position)
	assert_eq(screen._placements.keys(), [first.id, second.id])
	screen._place_card(0, first, layer.global_position + Vector2(10, 10))
	assert_eq(screen._placements.keys(), [second.id, first.id],
		"the one just moved is added LAST, and therefore drawn on top")


func test_a_card_that_leaves_the_table_drops_its_placement() -> void:
	var g: MtgGame = screen.game
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, bear, layer.global_position)
	g.destroy(bear)
	screen._refresh()
	assert_false(screen._placements.has(bear.id),
		"no seat is kept for a card that is not on the table")
	assert_eq(layer.get_child_count(), 0)


func test_the_opponents_cards_can_be_tidied_too() -> void:
	# `@MENU_TERRITORY` ships BOTH `Arrange your cards` and `Arrange
	# opponent's cards`, so both territories are the player's to straighten
	# — and therefore both are theirs to move.
	var theirs := _bear(1, 94010)
	assert_eq(screen._half_of(theirs), 1)
	var layer: Control = screen._free_layers[1]
	screen._place_card(1, theirs, layer.global_position + Vector2(30, 20))
	screen._refresh()
	assert_eq(layer.get_child_count(), 1)


# ------------------------------------------------------------- the drag --

func test_a_press_that_never_moves_is_still_a_click() -> void:
	# The drag must not steal the gesture that taps a land or takes a
	# target: *"you can simply click on the card to activate that primary
	# function"* (`Duel.hlp`, topic Territory).
	var bear := _bear()
	var w := MiniCard.new(bear)
	add_child_autofree(w)
	screen._begin_drag(w, bear)
	assert_false(screen._dragging, "an armed gesture is not yet a drag")
	screen._commit_drag()
	assert_false(screen._placements.has(bear.id),
		"nothing was moved, so nothing was placed")


func test_a_drag_only_starts_after_the_slop() -> void:
	assert_gt(DuelScreen.DRAG_SLOP, 0.0,
		"there is a threshold, or every click would move a card")
	assert_gt(DuelScreen.DRAG_Z, DuelScreen.LIFT_Z,
		"the card being dragged rides over a right-held one")


func test_a_committed_drag_writes_a_placement() -> void:
	var bear := _bear()
	var w := MiniCard.new(bear)
	w.size = MiniCard.SIZE
	screen._free_layers[0].add_child(w)
	screen._begin_drag(w, bear)
	screen._dragging = true                  # the pointer passed the slop
	w.global_position = screen._free_layers[0].global_position + Vector2(64, 32)
	screen._commit_drag()
	assert_true(screen._placements.has(bear.id))
	assert_eq(screen._placements[bear.id], Vector2(64, 32))
	assert_false(screen._dragging, "the gesture is over")


# -------------------------------- THE BOARD CASE, and why it did not work --
#
# The owner's SECOND playtest, 2026-09-03: *"Card on board still cannot be
# dragged across the board. My hand stack can."*
#
# The tests above all drive `_begin_drag` / `_commit_drag` directly, so
# they passed while no permanent on a real board could be moved. What they
# never touched is the only question that mattered: does a press ON A CARD
# reach anything that knows how to start a gesture? For a creature it did.
# For everything else it did not — lands, artifacts and enchantments group
# into a [CardPile] the moment there are two of them, and a pile's cards
# are `MOUSE_FILTER_IGNORE` pictures inside a holder `Button` that carried
# a `pressed` handler and nothing else. Since a real board is mostly
# lands, "nothing on the board moves" is exactly what that looks like.
#
# Verified end to end under Xvfb with synthesised press-move-release
# events before and after the fix (a throwaway probe, deleted): a piled
# land, a tapped piled land, a creature among three and a tapped creature.
# Only the two creatures moved before; all four move now.

func _lands(count: int) -> Array:
	var out: Array = []
	for i in count:
		var g: MtgGame = screen.game
		var land := CardInstance.new(CardRegistry.get_card("Forest"),
			94100 + i, 0)
		g._instances[land.id] = land
		g._put_on_battlefield(land, 0)
		out.append(land)
	screen._refresh()
	return out


## The pile ROW that draws [param inst] — the holder Button, which is the
## only node in a pile that takes the mouse.
func _pile_row(inst: CardInstance) -> Control:
	var row: Container = screen._field_rows[0][DuelScreen.Row.LANDS]
	for pile in row.get_children():
		if not (pile is CardPile):
			continue
		for holder in pile.get_children():
			for face in holder.get_children():
				if face is MiniCard and (face as MiniCard).instance == inst:
					return holder
	return null


func _click(pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	return ev


func test_a_land_is_drawn_in_a_pile_the_moment_there_are_two() -> void:
	# The premise, pinned, because it is what makes the defect universal.
	_lands(4)
	var row: Container = screen._field_rows[0][DuelScreen.Row.LANDS]
	assert_eq(row.get_child_count(), 1, "four lands, one pile")
	assert_true(row.get_child(0) is CardPile)


func test_a_piled_card_carries_the_drag_gesture() -> void:
	# THE DEFECT, pinned: the holder had a `pressed` handler and no
	# `gui_input`, so the press that arms a drag reached nothing.
	var lands := _lands(4)
	var holder := _pile_row(lands[0])
	assert_not_null(holder, "the pile draws a row per card")
	assert_gt(holder.gui_input.get_connections().size(), 0,
		"the row's holder listens for the gesture")


func test_a_press_on_a_piled_card_arms_the_drag_on_that_row() -> void:
	var lands := _lands(4)
	var holder := _pile_row(lands[1])
	screen._on_piled_card_input(_click(true), holder, lands[1])
	assert_eq(screen._drag_inst, lands[1], "the gesture armed")
	assert_eq(screen._drag_root, holder,
		"on the ROW, not on the pile — or one drag would carry five cards")
	screen._cancel_drag()


func test_a_travelled_press_pulls_that_one_card_out_of_the_pile() -> void:
	var lands := _lands(4)
	var holder := _pile_row(lands[2])
	var layer: Control = screen._free_layers[0]
	screen._on_piled_card_input(_click(true), holder, lands[2])
	screen._dragging = true                     # the pointer passed the slop
	holder.global_position = layer.global_position + Vector2(200, 90)
	screen._on_piled_card_input(_click(false), holder, lands[2])
	assert_true(screen._placements.has(lands[2].id), "it was placed")
	assert_eq(screen._placements[lands[2].id], Vector2(200, 90))
	screen._refresh()
	assert_eq(layer.get_child_count(), 1, "and it is drawn in the free layer")
	for other in [lands[0], lands[1], lands[3]]:
		assert_false(screen._placements.has(other.id),
			"the rest of the pile stayed where it was")


func test_a_press_on_a_piled_card_that_never_travels_is_still_a_click() -> void:
	# The pile's own `pressed` still taps the land: the drag adds a
	# gesture, it does not take one away.
	var lands := _lands(4)
	var holder := _pile_row(lands[0])
	screen._on_piled_card_input(_click(true), holder, lands[0])
	screen._on_piled_card_input(_click(false), holder, lands[0])
	assert_false(screen._placements.has(lands[0].id),
		"nothing travelled, so nothing was placed")
	assert_null(screen._drag_inst, "and the gesture forgot itself")


func test_a_dropped_card_is_clamped_by_the_CARD_not_by_the_node() -> void:
	# The clamp is measured from the INSTANCE, never from the widget that
	# happens to be under the pointer — a pile row has been a 17px title
	# strip and is now a whole card box, and neither is the room the card
	# will need once it is placed and can tap.
	var lands := _lands(4)
	var holder := _pile_row(lands[0])
	var layer: Control = screen._free_layers[0]
	assert_ne(holder.size, screen._placement_span(lands[0]).size,
		"the row's own box is not the footprint being reserved")
	screen._on_piled_card_input(_click(true), holder, lands[0])
	screen._dragging = true
	holder.global_position = layer.global_position + Vector2(0, 99999)
	screen._on_piled_card_input(_click(false), holder, lands[0])
	var placed: Vector2 = screen._placements[lands[0].id]
	var bounds: Rect2 = screen._placement_bounds(0)
	assert_almost_eq(placed.y,
		bounds.end.y - screen._placement_span(lands[0]).size.y, 1.0,
		"the whole card fits inside the half")
	assert_lt(placed.y, layer.size.y - MiniCard.SIZE.y,
		"and it is INSIDE the old bound, which only fitted an upright card")


func test_the_creature_path_is_unchanged() -> void:
	# The gesture creatures already had, through their own MiniCard, still
	# arms on the widget's layout root.
	var bear := _bear()
	var w := _find_board_card(bear)
	assert_not_null(w, "a creature is its own widget, never piled")
	screen._on_card_look(_click(true), w, bear)
	assert_eq(screen._drag_inst, bear)
	assert_eq(screen._drag_root, screen._layout_root(w))
	screen._cancel_drag()


## The MiniCard the creatures row drew for [param inst].
func _find_board_card(inst: CardInstance) -> MiniCard:
	var row: Container = screen._field_rows[0][DuelScreen.Row.CREATURES]
	for child in row.get_children():
		if child is MiniCard and (child as MiniCard).instance == inst:
			return child
	return null


# ---------------------------------------------------------- and ARRANGE --

func test_arrange_straightens_a_moved_card_back_into_its_row() -> void:
	# "Arrange Cards straightens up the cards in play." A card the player
	# dropped where they liked is exactly what needs straightening.
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, bear, layer.global_position + Vector2(200, 100))
	screen._refresh()
	assert_eq(layer.get_child_count(), 1)
	screen._on_arrange_toggled(true)
	assert_false(screen._placements.has(bear.id), "straightened up")
	assert_eq(layer.get_child_count(), 0)
	var row: Container = screen._field_rows[0][DuelScreen.Row.CREATURES]
	assert_eq(row.get_child_count(), 1, "back in its row")


func test_arranging_one_territory_leaves_the_other_alone() -> void:
	var mine := _bear(0, 94020)
	var theirs := _bear(1, 94021)
	screen._place_card(0, mine, screen._free_layers[0].global_position)
	screen._place_card(1, theirs, screen._free_layers[1].global_position)
	screen._arrange_seat(0, true)
	assert_false(screen._placements.has(mine.id))
	assert_true(screen._placements.has(theirs.id),
		"@MENU_TERRITORY straightens the territory you right-clicked")


func test_turning_arrange_off_does_not_re_place_anything() -> void:
	var bear := _bear()
	screen._place_card(0, bear, screen._free_layers[0].global_position)
	screen._on_arrange_toggled(true)
	screen._on_arrange_toggled(false)
	assert_false(screen._placements.has(bear.id),
		"a straightened card stays straightened; the toggle only restores "
		+ "the ROW order (see _display_order)")


# ----------------------------------- THE PLAYFIELD BOUNDARY (§2.3b) --
#
# The owner's playtest, 2026-09-04: *"The mini-cards can be moved out of
# the playfield and hide — make the playfield boundary for mini cards so
# they cannot possibly be moved and hidden out of the playfield!"*
#
# The first pass DID clamp, and the tests above proved it — against
# `layer.size - span`, with `span` read off the node being dragged. Every
# one of the holes below sits in that gap between "the node's size now"
# and "the room this card will ever need", which is why a clamp that
# tested green still let the owner lose cards off the table.


## The whole rectangle [param inst]'s widget occupies in the free layer.
func _placed_rect(inst: CardInstance, pid := 0) -> Rect2:
	var layer: Control = screen._free_layers[pid]
	for child in layer.get_children():
		if _draws(child, inst):
			return Rect2((child as Control).position, (child as Control).size)
	return Rect2()


func _draws(node: Node, inst: CardInstance) -> bool:
	if node is MiniCard and (node as MiniCard).instance == inst:
		return true
	for c in node.get_children():
		if _draws(c, inst):
			return true
	return false


func test_a_drag_past_any_edge_leaves_the_WHOLE_card_inside() -> void:
	# Not "its top-left is inside" — the corner test is what let a card be
	# shoved until only its left edge showed.
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	var bounds: Rect2 = screen._placement_bounds(0)
	var span: Rect2 = screen._placement_span(bear)
	screen.game.tap_permanent(bear)   # the bigger of the two footprints
	for shove in [Vector2(-9000, 0), Vector2(9000, 0), Vector2(0, -9000),
			Vector2(0, 9000), Vector2(9000, 9000), Vector2(-9000, -9000)]:
		screen._place_card(0, bear, layer.global_position + shove)
		var at: Vector2 = screen._placements[bear.id]
		var box := Rect2(at + span.position, span.size)
		assert_true(bounds.encloses(box),
			"shoved %s: %s must sit inside %s" % [shove, box, bounds])
		# ...and independently of the code under test: the widget the half
		# actually DRAWS, measured against the half's own rect.
		screen._refresh()
		assert_true(Rect2(Vector2.ZERO, layer.size).encloses(_placed_rect(bear)),
			"shoved %s: drawn at %s, half is %s"
			% [shove, _placed_rect(bear), layer.size])


func test_a_shoved_card_never_smuggles_itself_into_the_other_half() -> void:
	# A card in the opponent's territory would say something false about
	# who controls it, so the clamp is per SEAT and not per board.
	var theirs := _bear(1, 94030)
	var mine := _bear(0, 94031)
	screen._place_card(1, theirs,
		screen._free_layers[1].global_position + Vector2(0, 9000))
	screen._place_card(0, mine,
		screen._free_layers[0].global_position + Vector2(0, -9000))
	screen._refresh()
	var top: Control = screen._free_layers[1]
	var bottom: Control = screen._free_layers[0]
	var theirs_box := _placed_rect(theirs, 1)
	theirs_box.position += top.global_position
	var mine_box := _placed_rect(mine, 0)
	mine_box.position += bottom.global_position
	assert_true(Rect2(top.global_position, top.size).encloses(theirs_box),
		"the opponent's card stayed in the opponent's half")
	assert_true(Rect2(bottom.global_position, bottom.size).encloses(mine_box),
		"and mine stayed in mine")


func test_a_card_tapped_after_being_parked_at_an_edge_is_still_whole() -> void:
	# `MiniCard.turn_holder` is 114x140 against a card's 132x106: parked
	# flush with the bottom untapped, a card grew 34px DOWNWARD the moment
	# it tapped and the half's `clip_contents` ate the difference.
	var g: MtgGame = screen.game
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, bear, layer.global_position + Vector2(9000, 9000))
	screen._refresh()
	var upright := _placed_rect(bear)
	assert_true(Rect2(Vector2.ZERO, layer.size).encloses(upright),
		"upright and inside")
	g.tap_permanent(bear)
	screen._refresh()
	await get_tree().process_frame
	var turned := _placed_rect(bear)
	assert_eq(turned.size, MiniCard.TURN_HOLDER_SIZE,
		"the widget really is the taller rotation holder now")
	assert_true(Rect2(Vector2.ZERO, layer.size).encloses(turned),
		"and %s is STILL wholly inside the half %s" % [turned, layer.size])
	assert_eq(screen._placements[bear.id], upright.position,
		"and the card did not shuffle itself when it turned — the span "
		+ "reserves the turn's footprint whether or not it is tapped yet")


func test_an_enchanted_cards_aura_fan_stays_on_the_table() -> void:
	# The fan is drawn ABOVE the host's own box (_make_widget: it overflows
	# rather than reserving height), so a host parked at the top edge had
	# its auras cut off by the half's clip.
	var bear := _bear()
	var plain: Rect2 = screen._placement_span(bear)
	bear.attachments = [99001, 99002]
	var fanned: Rect2 = screen._placement_span(bear)
	assert_eq(fanned.position.y, -DuelScreen.AURA_PEEK.y * 2.0,
		"the span reaches up over the host by one band per aura")
	assert_gt(fanned.size.x, plain.size.x, "and out to the right")
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, bear, layer.global_position + Vector2(-9000, -9000))
	var at: Vector2 = screen._placements[bear.id]
	assert_gte(at.y + fanned.position.y, 0.0,
		"so the topmost aura still lands on the table")


func test_the_zone_column_and_the_phase_bar_need_no_bound() -> void:
	# Stated as a test because it is the reason the clamp is NOT shrunk for
	# them: they are SIBLINGS of the board in the root HBox, beside the
	# halves and never over them.
	for pid in 2:
		var layer: Control = screen._free_layers[pid]
		assert_gt(layer.global_position.x, CardPreview.SIZE.x,
			"the half starts to the right of the whole left column")


# ------------------------- THE HAND WINDOW MOVES NOTHING (§2.3b, §3.6) --
#
# The owner's playtest, 2026-09-04: *"When I move my hand stack, also
# other cards move on the table. They shouldn't."* — and the ruling that
# settles it: *"Yes, the hand stack can be present anywhere — only cast
# mini-cards are bound to the playfield."*
#
# The regression was the playfield clamp's own doing. It subtracted the
# floating hand window's band from the placeable area (`_hand_reserve`),
# and the window fired the re-clamp on `item_rect_changed` — which a
# Control emits when it MOVES, not only when it resizes. So every drag of
# the hand window narrowed the boundary and shoved the placements that
# now fell outside it. Measured under Xvfb with a real press-move-release
# on the window's grip (a throwaway probe, deleted): one 480px drag fired
# `_reclamp_placements` twelve times and moved two of three placed cards,
# collapsing both onto the same x — plus all four row-laid lands, which
# the rows' half of the same reserve slid 385px.
#
# THE POLICY NOW: the board never rearranges itself for the hand window.
# The window is chrome the player parks where they like; the clamp binds
# CAST CARDS to the playfield and nothing else. A card the window happens
# to cover is not lost — the player owns both and one more drag of either
# uncovers it.

func test_moving_the_hand_window_leaves_every_placement_alone() -> void:
	var stack: Control = screen._hand_rows[1]
	if not (stack is StackHand):
		pass_test("this build's hand is the fan, which never floats over "
			+ "the board and so can never have moved anything")
		return
	stack.visible = true
	# A KNOWN corner over the player's own half: `hand_stack_pos` persists
	# in user://settings.cfg, so a test that trusts the default is at the
	# mercy of wherever the last run left the window.
	stack.position = Vector2(screen.size.x - stack.size.x, 420)
	await get_tree().process_frame
	var bear := _bear(0, 94001)
	var edge := _bear(0, 94002)
	var layer: Control = screen._free_layers[0]
	# One in the middle and one shoved hard against the right edge, which
	# is the placement the old reserve pulled in first.
	screen._place_card(0, bear, layer.global_position + Vector2(120, 40))
	screen._place_card(0, edge, layer.global_position + Vector2(9000, 40))
	var before := {}
	for id in screen._placements:
		before[id] = screen._placements[id]
	assert_eq(before.size(), 2, "two cards are parked")

	# Carry the window right across the table. Setting `position` is what
	# a drag does and it emits `item_rect_changed` by itself, so this is
	# the same notification the real gesture sends.
	for x in [900.0, 700.0, 500.0, 300.0, 60.0]:
		stack.position = Vector2(x, stack.position.y)
		await get_tree().process_frame
		await get_tree().process_frame
	for id in before:
		assert_eq(screen._placements[id], before[id],
			"placement %d is where the player left it" % id)


func test_the_hand_window_is_not_subtracted_from_the_playfield() -> void:
	# The owner's ruling, stated as a boundary: the window may sit
	# anywhere, so it takes nothing off the area a cast card may occupy.
	# A card may be dropped under it, and the whole half stays placeable.
	var stack: Control = screen._hand_rows[1]
	if not (stack is StackHand):
		pass_test("fan hand: nothing floats over the board")
		return
	stack.visible = true
	var layer: Control = screen._free_layers[0]
	stack.position = Vector2(screen.size.x - stack.size.x, 420)
	await get_tree().process_frame
	var bounds := screen._placement_bounds(0)
	assert_almost_eq(bounds.end.x, layer.size.x - DuelScreen.BOARD_INSET, 0.5,
		"the playfield runs to the half's own inset edge, window or no window")
	# ...and a card really can be parked under the window.
	var bear := _bear(0, 94001)
	screen._place_card(0, bear, layer.global_position + Vector2(9000, 40))
	var right: float = screen._placements[bear.id].x \
		+ screen._placement_span(bear).size.x
	assert_almost_eq(right, bounds.end.x, 0.5,
		"it reaches the edge of the table rather than stopping at the window")


func test_the_board_rows_do_not_reflow_when_the_window_moves() -> void:
	# The other half of the same report, and the more visible one: the
	# rows used to give up the window's band too, so dragging the window
	# left slid every right-hugging pile with it.
	var stack: Control = screen._hand_rows[1]
	if not (stack is StackHand):
		pass_test("fan hand: nothing floats over the board")
		return
	stack.visible = true
	stack.position = Vector2(screen.size.x - stack.size.x, 420)
	await get_tree().process_frame
	await get_tree().process_frame
	var lands := _lands(3)
	assert_gt(lands.size(), 0, "the row has cards in it")
	# LET THE ROW LAY ITSELF OUT first: a Container positions its children
	# on the next frame, so reading the pile's rect straight after
	# `_refresh` reads where it has not been put yet.
	await get_tree().process_frame
	await get_tree().process_frame
	var pile := _pile_row(lands[0])
	assert_not_null(pile, "and they are drawn")
	var before: Vector2 = pile.global_position
	for x in [900.0, 500.0, 60.0]:
		stack.position = Vector2(x, stack.position.y)
		await get_tree().process_frame
		await get_tree().process_frame
	assert_eq(_pile_row(lands[0]).global_position, before,
		"the row is where it was before the window moved")


# ------------------------------------------------- AND ON RESIZE (§2.3b) --

func test_a_placement_made_wide_is_pulled_in_when_the_window_narrows() -> void:
	# Placements live for the whole duel. Park a card at the right edge of
	# a 1920 window, reopen at 1280, and the card is 320px out in the dark
	# under the half's `clip_contents` — the resize half of the defect.
	screen.size = Vector2(1920, 900)
	await get_tree().process_frame
	await get_tree().process_frame
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, bear, layer.global_position + Vector2(9000, 9000))
	var wide: Vector2 = screen._placements[bear.id]
	screen.size = Vector2(1024, 640)
	await get_tree().process_frame
	await get_tree().process_frame
	var narrow: Vector2 = screen._placements[bear.id]
	assert_lt(narrow.x, wide.x, "the card came back in with the right edge")
	assert_lt(narrow.y, wide.y, "and up with the bottom one")
	var bounds: Rect2 = screen._placement_bounds(0)
	var span: Rect2 = screen._placement_span(bear)
	assert_true(bounds.encloses(Rect2(narrow + span.position, span.size)),
		"%s is inside the narrow window's %s" % [narrow, bounds])
	screen._refresh()
	assert_true(Rect2(Vector2.ZERO, layer.size).encloses(_placed_rect(bear)),
		"and the widget really is drawn inside the half")


func test_the_half_asks_for_the_re_clamp_itself() -> void:
	# The invariant behind the test above, so it cannot be broken by a
	# refactor that only happens to keep the numbers right: every half
	# listens to its own rect.
	for pid in 2:
		var layer: Control = screen._free_layers[pid]
		var holder: Control = layer.get_parent()
		assert_gt(holder.resized.get_connections().size(), 0,
			"half %d re-measures itself when its rect changes" % pid)


func test_a_placement_written_before_the_first_layout_is_left_alone() -> void:
	# A zero-sized half has no bounds to clamp against, and inventing some
	# would collapse every placement into the corner on the frame the duel
	# opens. _placement_bounds returns an empty rect and the clamp passes
	# the value through.
	var fresh: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	autofree(fresh)
	assert_eq(fresh._placement_bounds(0), Rect2(),
		"no layer, no bounds")
	assert_eq(fresh._clamp_in_half(0, Vector2(700, 500), null),
		Vector2(700, 500), "and nothing is moved")


# ------------------------------- THE PRESS STILL REACHES THE CARD (§2.3b) --
#
# The invariant the two "it worked but no mouse could reach it" defects of
# this week both needed and neither had. A headless suite cannot route a
# real click (measured: under `--headless` a pushed mouse event reaches no
# Control at all), so what a test CAN pin is that the nodes are wired and
# transparent in the way a click needs. The end-to-end proof is a probe
# under Xvfb; this is the part that guards the wiring afterwards.

func test_a_placed_card_still_carries_the_press_that_starts_a_drag() -> void:
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, bear, layer.global_position + Vector2(120, 60))
	screen._refresh()
	assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the layer itself takes no clicks — only its cards do")
	var card := _card_in(layer, bear)
	assert_not_null(card, "the placed card is drawn")
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_STOP,
		"and it is the node that stops the press")
	assert_gt(card.gui_input.get_connections().size(), 0,
		"which is connected to the gesture")


func test_nothing_opaque_sits_over_a_placed_card() -> void:
	# The 2026-09-04 lettered-badge defect in one line: a bare `Control`
	# defaults to MOUSE_FILTER_STOP, and one laid over a card eats every
	# press before the card sees it.
	var bear := _bear()
	var layer: Control = screen._free_layers[0]
	screen._place_card(0, bear, layer.global_position + Vector2(120, 60))
	screen._refresh()
	var card := _card_in(layer, bear)
	for child in card.get_children():
		if child is Control:
			assert_ne((child as Control).mouse_filter,
				Control.MOUSE_FILTER_STOP,
				"%s would swallow the press meant for the card" % child.name)


func _card_in(layer: Control, inst: CardInstance) -> MiniCard:
	for child in layer.get_children():
		for n in _all(child):
			if n is MiniCard and (n as MiniCard).instance == inst:
				return n
	return null


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
