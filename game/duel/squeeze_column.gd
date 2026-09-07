class_name SqueezeColumn
extends Container
## THE ROWS OF A TERRITORY NEVER LEAVE THEIR HALF — the vertical twin of
## [SqueezeRow] (`docs/duel-todo.md` §2.13).
##
## Each board half stacks its rows in reading order: lands, the other
## permanents, then the creatures at the battle line. The stack used to be
## a [VBoxContainer], and a VBox has one answer to rows that want more
## height than the half has: it GROWS. A Control's size can never be less
## than its minimum, anchors or no anchors, so the moment a turned pile
## (140) sat over a tapped artifact (140) and a row of attackers (140) the
## box was 431 tall in a 388 half and the creature row ran out through the
## half's `clip_contents` — the opponent's through the seam, the player's
## off the bottom of the screen. The owner's *"cards sometimes
## automatically go outside the playfield for me or the opponent"*
## (2026-09-07). That is not a rare board: any tapped permanent turns
## inside a 140 holder and a five-card pile is 174.
##
## So the column does what the row does. While the rows fit it lays them
## out exactly as the VBox did, the spacer taking the slack so the creatures
## hug the far edge of the half. Once they do not, the overflow is shared
## out over the seams between the [member squeezed] rows and each earlier
## row slides UNDER the next by that much; the last of them — the
## creatures, the cards a duel is decided by — always shows in full, and the
## rows that are not cards (the opponent's hand plate, the fan) keep their
## whole height. s30's rule for a row is a uniform pitch with the last card
## whole (`duel.go:1424-1434`); for equal heights this is the same rule.
## Our rows are not equal — a full pile is 174 tall and a row of untapped
## creatures 106 — and a uniform pitch would put the whole overlap on one
## seam and leave the other with a gap.
##
## Sliding under means DRAWING under: a later row sits over an earlier one
## only if its z is higher than everything the earlier row draws (a pile's
## fifth card is at z 4 and its name band at 6). The steps are the
## screen's business — `DuelScreen.ROW_Z_STEP`.
##
## **[QoL]** — the 1997 game has no answer here either; its territory is
## a fixed grid that a big board simply overflows (`Duel.hlp`, topic
## Territory, offers **Arrange Cards** to tidy the result).

## Gap between children while the column is NOT overflowing — the VBox's
## old `separation`.
const SEPARATION := 2.0

## The rows that may slide under one another, in reading order. The LAST of
## them always shows in full. A child that is not here keeps its whole
## height, unless it EXPANDS (the spacer), in which case it has nothing to
## keep.
var squeezed: Array[Control] = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_lay_out()


## As wide as its widest child and NO taller than nothing: a column that
## reported its natural height as its minimum would be given it, which is
## exactly how the VBox it replaced grew out of the half.
func _get_minimum_size() -> Vector2:
	var want := Vector2.ZERO
	for child in _laid_out_children():
		want.x = maxf(want.x, child.get_combined_minimum_size().x)
	return want


## Total height the children would take laid out without overlap — what
## the old VBox demanded.
func natural_height() -> float:
	var kids := _laid_out_children()
	if kids.is_empty():
		return 0.0
	var total := 0.0
	for child in kids:
		total += child.get_combined_minimum_size().y
	return total + SEPARATION * (kids.size() - 1)


func _laid_out_children() -> Array:
	var kids: Array = []
	for child in get_children():
		if child is Control and child.visible and not child.top_level:
			kids.append(child)
	return kids


func _expands(child: Control) -> bool:
	return (child.size_flags_vertical & SIZE_EXPAND) != 0


func _lay_out() -> void:
	var kids := _laid_out_children()
	if kids.is_empty():
		return
	var heights: Array[float] = []
	for child in kids:
		heights.append(child.get_combined_minimum_size().y)
	var natural := natural_height()
	var y := 0.0

	# THE FIT: the VBox it replaced — the slack goes to the expanding
	# children, which is how the creature row ends up at the far edge.
	if natural <= size.y:
		var expanders := 0
		for child in kids:
			if _expands(child):
				expanders += 1
		var share: float = (size.y - natural) / float(expanders) \
			if expanders > 0 else 0.0
		for i in kids.size():
			var h: float = heights[i] + (share if _expands(kids[i]) else 0.0)
			_place(kids[i], y, h)
			y += h + SEPARATION
		return

	# THE OVERFLOW: shared out evenly over the seams between the squeezed
	# rows that are present, which now touch — the gap is for rows that
	# fit. A row that is not cards keeps its gap and its height; the
	# spacer, which expands, has nothing to keep. With one squeezed row
	# (or none) there is no seam to take the overflow and the column
	# overflows as the VBox did — that is a half with a single row taller
	# than itself, which no real board produces.
	var slide: Array[Control] = []
	for child in kids:
		if squeezed.has(child):
			slide.append(child)
	var need := 0.0
	for i in kids.size():
		var child: Control = kids[i]
		if _expands(child) and not slide.has(child):
			continue
		need += heights[i]
		if not slide.has(child) and i > 0:
			need += SEPARATION
	var seams := slide.size() - 1
	var under: float = (need - size.y) / float(seams) if seams > 0 else 0.0
	for i in kids.size():
		var child: Control = kids[i]
		var h: float = heights[i]
		if _expands(child) and not slide.has(child):
			_place(child, y, 0.0)
			continue
		if not slide.has(child) and i > 0:
			y += SEPARATION
		_place(child, y, h)
		y += h
		if slide.has(child) and child != slide[-1]:
			y -= under


## Put one child down at [param y], the column's full width. The child's
## own size flags still apply inside that rect, as in any container.
func _place(child: Control, y: float, height: float) -> void:
	fit_child_in_rect(child, Rect2(Vector2(0.0, y), Vector2(size.x, height)))
