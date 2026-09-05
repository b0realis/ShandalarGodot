extends GameTest
## THE PILE — `game/duel/card_pile.gd`, the original's grouping device, and
## the widget the owner's *"they do not rotate 90 deg"* was really about:
## lands, artifacts and enchantments go into a `CardPile` the moment there
## are two of them, so a pile that cannot turn a card is a board on which
## most of what the player taps never looks tapped.
##
## What is pinned here is the geometry, because the geometry is the whole
## argument. [method CardPile.layout_boxes] is PURE — no widgets, no frame,
## no renderer — so the cascade can be measured exactly, over every
## arrangement of a full pile, in a headless run. Three invariants carry
## the design:
##
##   1. **A flat pile is laid out exactly as it always was.** Nothing about
##      an untapped board moved, and the hand window (which never turns
##      anything) is byte-for-byte the list it was.
##   2. **No row is ever hidden.** Every card keeps a full
##      [constant CardPile.OVERLAP] of its own TITLE EDGE clear of every
##      card drawn after it — the top edge flat, the right edge turned.
##   3. **The cost is bounded**, and the bound is small enough to pay out
##      of the slack the board already has.
##
## The one thing a headless run cannot see is a click: under `--headless`
## Godot does no GUI picking at all. So the mouse is pinned STRUCTURALLY
## here — which node takes it, and what every `mouse_filter` between the
## pile and the card is — and the live press was verified under Xvfb.


func _pile(cards: Array, hidden := false, collapsed := false) -> CardPile:
	var pile := CardPile.new()
	pile.collapsed = collapsed
	add_child_autofree(pile)
	pile.populate(cards, hidden, func(_i): pass,
		func(_i): return MiniCard.Highlight.NONE)
	return pile


func _rows(pile: CardPile) -> Array[Button]:
	var out: Array[Button] = []
	for child in pile.get_children():
		if child is Button:
			out.append(child)
	return out


## Exactly the walk `DuelScreen._arm_pile_drag` makes.
func _faces(pile: CardPile) -> Array[MiniCard]:
	var out: Array[MiniCard] = []
	for holder in _rows(pile):
		for face in holder.get_children():
			if face is MiniCard:
				out.append(face)
				break
	return out


func _flags(pattern: int, count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append((pattern >> i) & 1 == 1)
	return out


func _span(boxes: Array[Rect2]) -> Rect2:
	var span: Rect2 = boxes[0]
	for box in boxes:
		span = span.merge(box)
	return span


## The band of [param box] that must stay clear: the card's own title bar,
## which is its TOP edge flat and its RIGHT edge turned.
func _title_edge(box: Rect2, turned: bool) -> Rect2:
	if turned:
		return Rect2(box.position + Vector2(box.size.x - CardPile.OVERLAP, 0.0),
			Vector2(CardPile.OVERLAP, box.size.y))
	return Rect2(box.position, Vector2(box.size.x, CardPile.OVERLAP))


# ==================================================== the flat pile, kept ==

func test_a_pile_with_nothing_tapped_is_the_list_it_always_was() -> void:
	# THE COMPATIBILITY PIN. The cascade only bends where a card is turned;
	# an untapped board and every hand window must be untouched.
	var boxes := CardPile.layout_boxes(_flags(0, 5))
	assert_eq(boxes.size(), 5)
	for i in 5:
		assert_eq(boxes[i].position, Vector2(0.0, i * CardPile.OVERLAP),
			"row %d sits one OVERLAP below the last" % i)
		assert_eq(boxes[i].size, MiniCard.SIZE, "and is a whole card")
	assert_eq(_span(boxes).size,
		Vector2(CardPile.WIDTH, 4 * CardPile.OVERLAP + MiniCard.SIZE.y),
		"132 x 174, which is what a five-card pile has always measured")


func test_pile_height_and_the_cascade_are_the_same_arithmetic() -> void:
	# `StackHand` sizes its window from `pile_height` BEFORE the pile is
	# populated, so the two derivations have to agree or the hand window
	# and the list inside it drift apart.
	var pile := CardPile.new()
	add_child_autofree(pile)
	for count in range(1, 9):
		var flat := CardPile.layout_boxes(_flags(0, count))
		assert_eq(pile.pile_height(count), _span(flat).size.y,
			"%d flat cards" % count)
		var strips := CardPile.layout_boxes(_flags(0, count), true)
		assert_eq(pile.pile_height(count, true), _span(strips).size.y,
			"%d hidden cards" % count)
	assert_eq(pile.pile_height(0), 0.0, "an empty pile takes no room")


# ======================================================= §2.9c — the turn ==
#
# The owner, playtesting 2026-09-04: *"Upon tapping my lands — they show a
# blue tapped symbol — ok, they are darker — ok, but they do not rotate 90
# deg. Please fix this — they must look tapped! Make a smooth tapping tween
# anim."* And, on what happens to yesterday's substitute cue: *"Cards
# should tap even in the stack — and show tapped symbol along with being
# darker."*


func test_a_tapped_card_in_a_pile_turns() -> void:
	# THE DEFECT, pinned. Before 2026-09-04 a piled card read `tapped=true
	# rot=0.00 parent=Button` however tapped it was, because the pile left
	# it the default corner pivot and clipped its row to 17px.
	MiniCard._turn_book.clear()
	var loose := put_battlefield(0, "Forest")
	var tapped := put_battlefield(0, "Mountain")
	tapped.tapped = true
	var front := put_battlefield(0, "Island")
	var faces := _faces(_pile([loose, tapped, front]))
	assert_eq(faces.size(), 3, "one face per card")
	assert_eq(faces[0].rotation_degrees, 0.0, "the untapped row is square on")
	assert_eq(faces[1].rotation_degrees, 90.0, "the COVERED tapped row turns")
	assert_true(faces[1].turns_when_tapped(),
		"because the pile gave it a centre pivot, which is the contract")
	assert_eq(faces[1].pivot_offset, MiniCard.SIZE / 2.0)
	assert_eq(faces[1].size, MiniCard.SIZE,
		"turned, never resized — one card size on the whole table")


func test_the_pile_reuses_the_one_tween_rather_than_growing_a_second() -> void:
	# The angle, the timing and the curve belong to `MiniCard`; a pile only
	# says WHERE. This is the pin that stops a second animation appearing
	# here the next time someone wants a piled card to move.
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	MiniCard._turn_book[land.get_instance_id()] = \
		Time.get_ticks_msec() - int(MiniCard.TAP_TURN_SECONDS * 1000.0 / 2.0)
	var pile := _pile([put_battlefield(0, "Forest"), land])
	var face := _faces(pile)[1]
	face.animate_turn = true
	face.tap_turn()
	assert_almost_eq(face.rotation_degrees,
		MiniCard.turn_angle(MiniCard.TAP_TURN_SECONDS / 2.0), 4.0,
		"a row rebuilt mid-turn picks the sweep up where it was")
	assert_not_null(face._turn, "and carries the rest of it")


func test_a_turned_row_wears_the_wash_and_the_letters_as_well() -> void:
	# The owner's ruling: all three cues at once. They do different work at
	# different distances — the turn reads across the table, the wash down
	# a column of overlapping bars, the letters when a card is half
	# covered — and all three ride the card, so they turn with it.
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	var face := _faces(_pile([land, put_battlefield(0, "Forest")]))[0]
	assert_eq(face.rotation_degrees, 90.0, "turned...")
	assert_true(face._tap_wash.visible, "...and dark...")
	assert_true(face._tap_mark.visible, "...and lettered")
	assert_eq(face._tap_mark.text, MiniCard.TAPPED_MARK)


func test_a_card_in_a_hand_pile_never_turns() -> void:
	# `wants_rotation` asks the ZONE first: a card in hand has no tapped
	# state to draw, so the hand window keeps its flat list whatever
	# nonsense the instance carries.
	MiniCard._turn_book.clear()
	var one := give_hand(0, "Mountain")
	one.tapped = true
	var two := give_hand(0, "Forest")
	var faces := _faces(_pile([one, two]))
	assert_eq(faces[0].rotation_degrees, 0.0)
	assert_false(faces[0].turns_when_tapped(), "no centre pivot in a hand pile")


# ============================================== the cards are whole again ==

func test_a_battlefield_row_no_longer_clips_its_card() -> void:
	# THE OTHER HALF OF THE DEFECT. A 17px holder with `clip_contents` on
	# cannot show a rotation at all, whatever pivot the card is given. The
	# rows are whole cards now, occluded by the row in front of them —
	# 1997's own mechanism (`windows.c:1108-1178`).
	var pile := _pile([put_battlefield(0, "Forest"),
		put_battlefield(0, "Mountain"), put_battlefield(0, "Island")])
	for holder in _rows(pile):
		assert_false(holder.clip_contents, "no row is cropped")
		assert_eq(holder.size, MiniCard.SIZE, "every row is a whole card")
	var rows := _rows(pile)
	for i in rows.size():
		assert_eq(rows[i].z_index, i, "and the later row draws OVER it")


func test_a_hidden_or_collapsed_pile_is_still_a_list_of_strips() -> void:
	# Neither has a front card to end it, so the last row has nothing in
	# front of it to be occluded by and a whole card would spill out of the
	# window. Those two keep the clip — and nothing in them can turn.
	var backs := _pile([give_hand(1, "Forest"), give_hand(1, "Mountain")], true)
	for holder in _rows(backs):
		assert_true(holder.clip_contents, "a card back stays a strip")
		assert_eq(holder.size, Vector2(CardPile.WIDTH, CardPile.OVERLAP))
	assert_eq(backs.custom_minimum_size.y, 2 * CardPile.OVERLAP)
	var rolled := _pile([give_hand(0, "Forest"), give_hand(0, "Mountain")],
		false, true)
	for holder in _rows(rolled):
		assert_true(holder.clip_contents, "so does a collapsed hand row")


# ======================================================== §2.9c — the cascade ==

func test_the_stack_steps_along_the_cards_own_title_edge() -> void:
	# THE ONE RULE. A flat card wears its title bar across the TOP, so the
	# next card goes 17px DOWN. A turned card wears the same bar down its
	# RIGHT edge (`windows.c:637-647` un-rotates a tapped card's hit test
	# by exactly that map), so the next card goes 17px LEFT.
	var down := CardPile.layout_boxes([false, false])
	assert_eq(down[1].position - down[0].position,
		Vector2(0.0, CardPile.OVERLAP), "flat: straight down")
	var left := CardPile.layout_boxes([true, true])
	assert_eq(left[0].position - left[1].position,
		Vector2(CardPile.OVERLAP, 0.0), "turned: straight left")
	assert_eq(left[0].size, CardPile.TURNED_SIZE, "and the box swaps axes")
	assert_eq(CardPile.TURNED_SIZE, Vector2(MiniCard.SIZE.y, MiniCard.SIZE.x))


func test_an_all_tapped_pile_is_the_flat_pile_turned_ninety_degrees() -> void:
	# Which is what `Duel.hlp`, topic **Tap**, says tapping looks like:
	# *"Tapping a card means turning it sideways."* Say it of a whole pile
	# and this is the shape you get — the same list, the same 17px
	# overlap, read right to left instead of top to bottom.
	var flat := _span(CardPile.layout_boxes(_flags(0, 5))).size
	var turned := _span(CardPile.layout_boxes(_flags(31, 5))).size
	assert_eq(turned, Vector2(flat.y, flat.x),
		"the pile's own footprint transposes: 132x174 becomes 174x132")


func test_no_row_is_ever_hidden_however_the_pile_is_tapped() -> void:
	# THE READABILITY INVARIANT, over all 32 arrangements of five cards:
	# every card keeps a FULL 17px of its own title bar — name, mana
	# slashes, wash and mark — clear of every card drawn after it.
	for pattern in 32:
		var turned := _flags(pattern, 5)
		var boxes := CardPile.layout_boxes(turned)
		for i in 5:
			var edge := _title_edge(boxes[i], turned[i])
			for j in range(i + 1, 5):
				assert_false(edge.intersects(boxes[j]),
					"pattern %d: row %d covers row %d's title bar"
						% [pattern, j, i])


func test_the_cascade_costs_a_bounded_amount_of_room() -> void:
	# THE SPACE COST, measured rather than hoped for, over all 32
	# arrangements. A flat five-card pile is 132x174; the worst cascade is
	# 200x132 (the first four tapped) or 132x200 (only the front card
	# tapped) — at most 68px more in ONE direction, never in both. The
	# board was measured under Xvfb with seven lands and three creatures
	# out: the lands row is 670px wide with 264 in use, and there are 102px
	# of vertical slack under it before the creature row. Both directions
	# are paid for out of slack the board already has.
	var widest := 0.0
	var tallest := 0.0
	for pattern in 32:
		var span := _span(CardPile.layout_boxes(_flags(pattern, 5))).size
		widest = maxf(widest, span.x)
		tallest = maxf(tallest, span.y)
		assert_lt(span.x * span.y, 200.0 * 200.0,
			"pattern %d grew in both directions at once" % pattern)
	assert_eq(widest, 200.0, "the widest a five-card pile can get")
	assert_eq(tallest, 200.0, "and the tallest")


func test_the_cascade_never_starts_at_a_negative_offset() -> void:
	# The leftward steps run negative while they are being computed; the
	# pile slides the whole staircase back so its rectangle starts at its
	# own top-left corner, like every other Control on the board.
	for pattern in 32:
		var boxes := CardPile.layout_boxes(_flags(pattern, 5))
		var span := _span(boxes)
		assert_eq(span.position, Vector2.ZERO, "pattern %d" % pattern)


func test_a_real_pile_reserves_exactly_the_room_its_cascade_needs() -> void:
	MiniCard._turn_book.clear()
	var cards: Array = []
	for name in ["Forest", "Mountain", "Plains", "Island", "Swamp"]:
		cards.append(put_battlefield(0, name))
	cards[1].tapped = true
	cards[3].tapped = true
	var pile := _pile(cards)
	var boxes := CardPile.layout_boxes([false, true, false, true, false])
	assert_eq(pile.custom_minimum_size, _span(boxes).size,
		"the pile asks its row for the cascade's own footprint")
	var rows := _rows(pile)
	for i in rows.size():
		assert_eq(rows[i].position, boxes[i].position, "row %d" % i)
		assert_eq(rows[i].size, boxes[i].size, "row %d's box" % i)


# ============================================ the mouse, pinned structurally ==

func test_the_drag_hook_still_finds_every_row() -> void:
	# `DuelScreen._arm_pile_drag` walks this pile's children for `Button`s
	# and takes the `MiniCard` DIRECT CHILD of each. Any wrapper node
	# between the two would silently disarm the drag on every land on the
	# board, which is exactly the defect that walk was written to fix — so
	# the structure it depends on is pinned here, in the file that owns it.
	MiniCard._turn_book.clear()
	var cards: Array = []
	for name in ["Forest", "Mountain", "Plains"]:
		cards.append(put_battlefield(0, name))
	cards[1].tapped = true
	var pile := _pile(cards)
	pile.framed = true
	var rows := _rows(pile)
	assert_eq(rows.size(), 3, "one holder Button per card")
	for holder in rows:
		var face: MiniCard = null
		for child in holder.get_children():
			if child is MiniCard:
				face = child
				break
		assert_not_null(face, "the card is a DIRECT child of its holder")


func test_every_filter_between_the_pile_and_the_card_is_deliberate() -> void:
	# A bare `Control` defaults to STOP, and that default has eaten a press
	# three times this week. There is no bare `Control` on this path: the
	# pile PASSes (its empty corners belong to the board), the holder is a
	# `Button` and STOPs (it is the thing that takes the press), and the
	# card inside is IGNORE (it is a picture).
	MiniCard._turn_book.clear()
	var land := put_battlefield(0, "Mountain")
	land.tapped = true
	var pile := _pile([land, put_battlefield(0, "Forest")])
	assert_eq(pile.mouse_filter, Control.MOUSE_FILTER_PASS, "the pile")
	for holder in _rows(pile):
		assert_eq(holder.mouse_filter, Control.MOUSE_FILTER_STOP, "the holder")
		assert_gt(holder.gui_input.get_connections().size(), -1)
	for face in _faces(pile):
		assert_eq(face.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the card")


func test_the_lone_cards_turn_holder_takes_no_mouse_either() -> void:
	# The same default, in the other holder: `MiniCard.turn_holder` is a
	# bare `Control` 4px larger than the card on every side, and it used to
	# STOP — a ring of dead pixels round every tapped permanent on the
	# board. It is geometry; the card inside takes the mouse.
	var holder := MiniCard.turn_holder(MiniCard.new(put_battlefield(0, "Forest")))
	add_child_autofree(holder)
	assert_eq(holder.mouse_filter, Control.MOUSE_FILTER_IGNORE)
