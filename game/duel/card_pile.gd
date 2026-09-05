class_name CardPile
extends Control
## The original's universal grouping device. Each covered card is
## represented by its OWN TOP BORDER: that strip of the card's frame as
## the row background, the card's name on it (YELLOW when you can cast it
## right now, WHITE when you can't), NO mana cost, and — for cards that
## make mana — one diagonal Manastripes band per colour they can produce.
## The front card extends that border into a full table card (border,
## name, mini art). The hand window is a CardPile under a title bar
## (StackHand); battlefield land/permanent groups are bare CardPiles.
##
## Every card on the table is the SAME SIZE — MiniCard.SIZE — whether
## it sits in a pile or alone on the battlefield; detail comes from
## hovering, which fills the big card in the sidebar.
##
## **THE CARDS ARE WHOLE, AND THE ONE ON TOP COVERS THE ONE BELOW.** Every
## row here is a full [MiniCard] drawn at its own place and OCCLUDED by the
## row after it (`z_index` ascending) — never a card cropped to a strip.
## That is 1997's own mechanism: `update_hand_window`
## (`shandalar-src/src/functions/windows.c:1108-1178`) `MoveWindow`s
## full-size card windows stepped by one global offset and z-orders them
## with `BringWindowToTop`, so what a covered card shows is whatever the
## card in front of it fails to cover. Until 2026-09-04 ours CLIPPED
## instead ([member Control.clip_contents] on a 17px holder), and that one
## difference is why a card in a pile could not tap: a rotation inside a
## 17px window is a rotation nobody can see. See [method layout_boxes] for
## the cascade a tapped row steps out into, and `docs/ROADMAP.md`, "THE
## TAPPED CARD IN A PILE".

const WIDTH := MiniCard.SIZE.x
## A covered card shows exactly its TITLE BAR. The reference's rows are
## ~13px on a 1280-wide screen; 17 keeps the 11px name legible while
## reading as the original's thin list.
##
## It is the overlap along the card's own TITLE EDGE, which is the top
## edge of a flat card and the RIGHT edge of a turned one — the same 17px
## either way, because it is the same band of the same card.
const OVERLAP := 17.0
## The visible last card is exactly a table card.
##
## There were two more constants here — `FACE_SCALE` and `FACE_HEIGHT` —
## which derived a 188px face by scaling [constant CardPreview.SIZE] down
## to a pile's width. **They were deleted in the fortieth pass.** Nothing
## read them: they dated from a pile whose last card was a shrunken
## ENLARGED card, and a pile has not drawn one of those since the twelfth
## pass made every card in the game a `MiniCard`. Left in place they
## implied a second card size that no longer exists, which is exactly the
## confusion this pass was opened to remove.
const COMPACT_FACE_HEIGHT := MiniCard.SIZE.y

## The footprint a TURNED card occupies: [constant MiniCard.SIZE] with its
## axes swapped, and not one pixel of slack. `MiniCard.TURN_HOLDER_SIZE`
## pads by 4 on every side because a lone card sits in a battlefield ROW
## and wants breathing room; inside a pile the box IS the overlap
## arithmetic, so it has to be the silhouette exactly.
const TURNED_SIZE := Vector2(MiniCard.SIZE.y, MiniCard.SIZE.x)

## Stripe geometry lives on MiniCard (which draws them); re-exported so
## tests and callers have one name to use.
const STRIPE_W := MiniCard.STRIPE_W

## The shared enlarged-card preview (owned by the DuelScreen, docked).
var preview: CardPreview = null

## When true only name bands render — no full last card (collapsed hand).
var collapsed := false

## Frame the pile in the original's tan window border (battlefield piles).
var framed := false


func _init() -> void:
	# A battlefield pile shares an `HFlowContainer` with lone cards and
	# with other piles, and a container STRETCHES a `SIZE_FILL` child to
	# the line height — see the note in [method MiniCard._init]. A pile's
	# rows are hand-positioned so stretching never distorted one, but it
	# did leave a short pile top-anchored in a tall row while the lone
	# cards beside it centred. One rule for both: shrink, and centre.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# PASS, not the `Control` default of STOP, and the cascade is why. A
	# pile whose rows all lie in one column filled its own rectangle, so
	# STOP never showed; a pile with a turned row in it is a STAIRCASE and
	# has real empty corners, and empty air over the battlefield belongs to
	# the battlefield (`DuelScreen`: "the row containers PASS so the empty
	# air between piles falls through"). The rows themselves are `Button`s
	# and still take every press that lands on a card.
	mouse_filter = Control.MOUSE_FILTER_PASS


## Rebuild the pile. [param click_cb] receives the CardInstance on click;
## [param highlight_cb] maps an instance to a MiniCard.Highlight value.
func populate(cards: Array, hidden: bool, click_cb: Callable,
		highlight_cb: Callable) -> void:
	# remove_child BEFORE queue_free. A freed-but-not-yet-collected child is
	# still in `get_children()` for the rest of the frame, so a second
	# populate in the same frame (collapse the hand, then the board's own
	# `_refresh`) left BOTH sets of rows in the pile — and any tree walk,
	# `TargetArrows._collect` among them, was handed a doomed widget to
	# resolve a position from a frame later. The same rule as
	# `DuelScreen._clear_children` and `MiniCard._rebuild_badges`.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if cards.is_empty():
		custom_minimum_size = Vector2.ZERO
		return
	if framed:
		var border := Panel.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.13, 0.11, 0.09, 0.55)
		box.border_color = Color(0.55, 0.45, 0.30)   # the tan window border
		box.set_border_width_all(2)
		border.add_theme_stylebox_override("panel", box)
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.offset_left = -3
		border.offset_top = -3
		border.offset_right = 3
		border.offset_bottom = 3
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.z_index = -1
		add_child(border)
	# A HIDDEN pile (the opponent's hand) and a COLLAPSED one (the player's,
	# rolled up) are lists of BARE STRIPS: there is no front card to end
	# them, so the last row has nothing behind it to be occluded by and a
	# whole card would spill out of the window. Those two keep the clipped
	# 17px row, and nothing in them can turn — a card in hand has no tapped
	# state to draw ([method MiniCard.wants_rotation]).
	var strips := hidden or collapsed
	var rows: Array[Button] = []
	var faces: Array = []
	var turned: Array = []
	for card in cards:
		var holder := _make_card(card, hidden, click_cb, highlight_cb)
		var face := _face_in(holder)
		rows.append(holder)
		faces.append(face)
		turned.append(not strips and face != null and face.wants_rotation())
	var boxes := layout_boxes(turned, strips)
	var span := boxes[0]
	for i in rows.size():
		var holder := rows[i]
		holder.position = boxes[i].position
		holder.size = boxes[i].size
		holder.clip_contents = strips
		# The row after this one is drawn OVER it — the whole of the
		# occlusion, and the reason a covered card needs no clip.
		holder.z_index = i
		var face: MiniCard = faces[i]
		if face != null:
			if turned[i]:
				# THE PIVOT IS THE PARENT'S TO GIVE, and this is a parent
				# that gives it: the card turns about its own middle inside
				# the swapped-axis box the cascade reserved, and
				# `MiniCard.tap_turn` (0.22s, ease-out, monotone, resumed
				# across the board's rebuilds) does the rest by itself.
				MiniCard.aim_turn(face, boxes[i].size)
			else:
				face.size = MiniCard.SIZE
				face.position = Vector2.ZERO
		add_child(holder)
		span = span.merge(boxes[i])
	custom_minimum_size = span.size


## **THE CASCADE.** Where each card in a pile of [param turned] flags sits,
## as a box in the pile's own coordinates, normalised so nothing lands at a
## negative offset. PURE — no widgets, no tree, no frame — so the geometry
## can be measured headless, which is the only way a layout question gets
## an answer a test can trust.
##
## **One rule: the stack steps along the card's own TITLE EDGE.** A flat
## card wears its title bar across the TOP, so the next card goes 17px
## DOWN and the bar stays showing — the list every pile has always been. A
## turned card wears the same bar down its RIGHT edge (rotate 90°
## clockwise and the card's top edge maps to the right-hand column —
## `windows.c:637-647` un-rotates a tapped card's hit test by exactly that
## map), so the next card goes 17px LEFT instead and the bar stays showing
## there. Cross-axis, the two cards share a centre line.
##
## The consequences are worth stating, because they are what makes this
## affordable:
##
## * a pile with nothing tapped is laid out EXACTLY as it always was —
##   one column, 17px apart, `(n-1)*17 + 106` tall;
## * a pile with everything tapped is that same pile TURNED 90° CLOCKWISE
##   — five cards stepping left, each showing its own title bar as a
##   vertical column, 174 wide by 132 tall. Which is what `Duel.hlp`,
##   topic **Tap**, says tapping looks like: *"turning it sideways"*;
## * a mixed pile is a staircase between the two, and it is BOUNDED. Over
##   all 32 arrangements of five cards the worst footprints are 200x132
##   (the first four tapped) and 132x200 (only the front card tapped)
##   against the 132x174 of a flat pile — at most 68px more in ONE
##   direction, never in both, because room spent going left is room not
##   spent going down. Measured on the live board under Xvfb with seven
##   lands and three creatures out: the lands row is 670px wide with 264
##   in use and has 102px of vertical slack under it, so both directions
##   are paid for out of slack the board already had;
## * NO CARD IS EVER HIDDEN. Every row keeps a full 17px of its own title
##   bar whichever way it faces, and the last card is whole, as before.
##
## [param strips] is the hidden/collapsed pile, which is a list of 17px
## bands and nothing else — see [method populate].
static func layout_boxes(turned: Array, strips := false) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	if turned.is_empty():
		return boxes
	var here := Vector2.ZERO
	for i in turned.size():
		var box := _box_size(turned[i], strips)
		boxes.append(Rect2(here, box))
		if i == turned.size() - 1:
			break
		var next := _box_size(turned[i + 1], strips)
		if turned[i] and not strips:
			# Title edge on the RIGHT: step LEFT, sharing the centre line.
			here = Vector2(here.x + box.x - OVERLAP - next.x,
				here.y + (box.y - next.y) / 2.0)
		else:
			# Title edge on TOP: step DOWN, sharing the centre line.
			here = Vector2(here.x + (box.x - next.x) / 2.0, here.y + OVERLAP)
	# The leftward steps run negative; slide the whole cascade back so the
	# pile's own rectangle starts at its top-left corner like any other.
	var origin := boxes[0].position
	for box in boxes:
		origin.x = minf(origin.x, box.position.x)
		origin.y = minf(origin.y, box.position.y)
	if origin != Vector2.ZERO:
		for i in boxes.size():
			boxes[i].position -= origin
	return boxes


static func _box_size(is_turned: bool, strips: bool) -> Vector2:
	if strips:
		return Vector2(WIDTH, OVERLAP)
	return TURNED_SIZE if is_turned else MiniCard.SIZE


## The pixel height a pile of [param count] FLAT cards needs — the
## `turned`-free case of [method layout_boxes], which is every hand window
## there has ever been (a card in hand has no tapped state to draw) and
## every battlefield pile with nothing tapped in it. `StackHand` sizes its
## window from this before the pile is populated, so it stays arithmetic
## rather than a layout pass; `tests/ui/test_card_pile.gd` pins the two
## against each other.
func pile_height(count: int, hidden := false) -> float:
	if count == 0:
		return 0.0
	if hidden or collapsed:
		return count * OVERLAP
	return (count - 1) * OVERLAP + COMPACT_FACE_HEIGHT


## Does a card in this pile show the "you may act on this" ring as well as
## the targeting ones? ON for the BATTLEFIELD piles and off everywhere
## else, and the difference is the manual's own: p.115/p.120/p.126 give a
## permanent you can use and a card you can cast the same one word,
## *highlighted*, but a pile of six affordable cards in the HAND window
## would be six rings and no information — the hand says it with the
## yellow NAME instead ([member MiniCard.castable]).
##
## The battlefield case is what needs it: while a cast waits for its mana
## ([constant DuelScreen.Mode.PAYING]) the sources that can pay for it are
## the whole prompt, and a land is almost always in a pile.
var glow_actionable := false


## The [MiniCard] a row draws, or null for a face-down (hidden) row. The
## same walk `DuelScreen._arm_pile_drag` makes over this pile's children,
## and it has to stay findable: the card is a DIRECT child of the holder
## `Button`, never wrapped, because that walk is how a piled card got its
## drag gesture.
static func _face_in(holder: Control) -> MiniCard:
	for child in holder.get_children():
		if child is MiniCard:
			return child
	return null


func _make_card(inst: CardInstance, hidden: bool, click_cb: Callable,
		highlight_cb: Callable) -> Button:
	# STOP — the `Button` default, and the one node in a pile that is meant
	# to take the mouse. The press that taps a land, the double-click that
	# casts it and the drag that carries it across the table all arrive
	# here; the picture inside is IGNORE so none of them stops short of it.
	var holder := Button.new()
	holder.flat = true
	if hidden:
		var back := ColorRect.new()
		back.color = Color(0.16, 0.10, 0.22)   # card-back purple, no info
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(back)
		holder.disabled = true
		return holder
	# EVERY card is a MiniCard, drawn whole, and a covered one is simply
	# the part of it the next card does not cover — so the pile reads as
	# the original's stack of overlapping cards, one component, one look.
	# ONE call to the highlight callback, not two: it reaches back into the
	# duel screen (`_highlight_for` -> `_can_act_on`, a legality question)
	# and a pile asks it once per card per rebuild.
	var highlight: int = highlight_cb.call(inst)
	var face := MiniCard.new(inst)
	# A card that is face down IN THE GAME is face down in the pile too —
	# the same one line `DuelScreen._make_card` carries, for the same
	# reason (`docs/card-states.md` §5.1). A pile is where lands and
	# artifacts live, so a face-down permanent reaches this path whenever
	# the board groups it.
	face.face_down = inst.face_down
	face.castable = highlight == MiniCard.Highlight.CASTABLE
	face.size = MiniCard.SIZE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.focus_mode = Control.FOCUS_NONE
	holder.add_child(face)
	if highlight == MiniCard.Highlight.TARGET \
			or highlight == MiniCard.Highlight.SELECTED \
			or (glow_actionable and (highlight == MiniCard.Highlight.OPTIONAL
				or highlight == MiniCard.Highlight.MANDATORY)):
		# FULL_RECT on the holder, which is the card's own silhouette
		# whichever way it faces — 132x106 flat, 106x132 turned — so the
		# ring is round the CARD and not round a strip of it.
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0, 0, 0, 0)
		glow.border_color = MiniCard.HIGHLIGHT_COLORS[highlight]
		glow.set_border_width_all(2)
		var glow_panel := Panel.new()
		glow_panel.add_theme_stylebox_override("panel", glow)
		glow_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(glow_panel)
	holder.pressed.connect(click_cb.bind(inst))
	holder.mouse_entered.connect(_on_card_hover.bind(inst, face))
	holder.mouse_exited.connect(_on_card_leave.bind(face))
	return holder


## The original's list lights the row under the pointer (lighter strip,
## YELLOW name — the owner's zoomed hand screenshot) and fills the docked
## enlarged card with it.
##
## [param face] is deliberately UNTYPED: the pile is rebuilt on every board
## refresh, so a queued mouse_exited can arrive carrying a row widget that
## has already been freed — and binding a freed object to a TYPED parameter
## is itself the error ("trying to assign invalid previously freed
## instance"). is_instance_valid is the guard.
func _on_card_hover(inst: CardInstance, face: Variant) -> void:
	if is_instance_valid(face):
		face.hovered = true
	if preview != null:
		preview.show_card(inst)


func _on_card_leave(face: Variant = null) -> void:
	if is_instance_valid(face):
		face.hovered = false
	# The centered examine popup clears when the pointer leaves; a docked
	# preview (if a layout ever docks one again) persists.
	if preview != null and not preview.docked:
		preview.visible = false
