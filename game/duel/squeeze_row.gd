class_name SqueezeRow
extends Container
## ONE BATTLEFIELD ROW THAT NEVER WRAPS — `docs/duel-todo.md` §2.13.
##
## A territory row is a READING ORDER: lands, then the other permanents,
## then the creatures at the battle line (§4.2, and the arrange toggle in
## §2.3 exists to keep that order meaningful). An [HFlowContainer] breaks
## it the moment a row overflows: the eleventh land starts a second line,
## the row below is pushed down, and the three rows stop being three rows.
##
## s30 keeps one line and SHRINKS THE PITCH instead (`duel.go:1424-1434`):
##
##     maxSpacing := 35
##     if row == permRowCreature { maxSpacing = 120 }
##     availableW := duelBoardW - 30 - fieldCardW
##     spacing := maxSpacing
##     if total > 1 && (total-1)*spacing > availableW {
##         spacing = availableW / (total - 1)
##     }
##     pos := image.Pt(duelBoardX+30+idx*spacing, baseY)
##
## i.e. the last card keeps its whole width and everything before it slides
## under its neighbour. That is also what the ORIGINAL's territory does —
## `Duel.hlp`, topic **Territory**, offers **Arrange Cards**, which
## *"straightens up the cards in play"*, a verb that only means anything
## on a row whose cards can lie on top of one another.
##
## THE GENERALISATION we make over s30: s30 assumes every card in a row is
## the same width, so one `spacing` serves. Our non-creature rows group
## into the original's strip-stack piles ([CardPile]), which are wider than
## a single card, so the pitch here is computed from the ACTUAL widths —
## the row fits when the last child's full width plus (n-1) pitches fits.
##
## There is deliberately NO minimum pitch, which is s30's choice too: with
## enough permanents the pitch reaches zero and the row becomes one stack.
## That is the honest picture of a board with forty lands on it, and the
## piles keep it from happening in any real duel.

## Which end an under-full row hugs. The player's land and artifact rows
## hug the RIGHT in the owner's reference screenshots (the hand window
## sits at that side and the piles gather beside it); the creature rows
## start at the LEFT.
enum Align { BEGIN, END }

## Gap between children when the row is NOT overflowing. Once it is, the
## pitch is computed and this no longer applies.
const SEPARATION := 4.0

var align: int = Align.BEGIN:
	set(value):
		align = value
		queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_lay_out()


## The row is as tall as its tallest child and as wide as its WIDEST one —
## not as wide as all of them together. A row that demanded its full
## natural width would push the board's own container wider and undo the
## squeeze before it ever ran.
func _get_minimum_size() -> Vector2:
	var want := Vector2.ZERO
	for child in _laid_out_children():
		var m: Vector2 = child.get_combined_minimum_size()
		want.x = maxf(want.x, m.x)
		want.y = maxf(want.y, m.y)
	return want


func _laid_out_children() -> Array:
	var kids: Array = []
	for child in get_children():
		if child is Control and child.visible and not child.top_level:
			kids.append(child)
	return kids


func _lay_out() -> void:
	var kids := _laid_out_children()
	if kids.is_empty():
		return
	var widths: Array[float] = []
	var natural := 0.0
	for child in kids:
		var w: float = child.get_combined_minimum_size().x
		widths.append(w)
		natural += w
	natural += SEPARATION * (kids.size() - 1)

	# THE OVERFLOW TEST, s30's `(total-1)*spacing > availableW`. Under it,
	# the row lays out normally and only the alignment matters.
	var x := 0.0
	var pitch_mode := natural > size.x and kids.size() > 1
	if pitch_mode:
		# Room for every child but the last to slide under its neighbour;
		# the last one always shows in full, which is what makes the row
		# still readable as "there are N of these".
		var room: float = maxf(size.x - widths[-1], 0.0)
		var pitch: float = room / float(kids.size() - 1)
		for i in kids.size():
			_place(kids[i], i * pitch, widths[i])
		return
	if align == Align.END:
		x = maxf(size.x - natural, 0.0)
	for i in kids.size():
		_place(kids[i], x, widths[i])
		x += widths[i] + SEPARATION


## Put one child down at [param x], vertically centred in the row — cards
## in one row are not all the same height (a tapped permanent turns inside
## a taller holder) and a row of mixed heights reads as a line only when
## they share a centre.
##
## A child TALLER than the row keeps its full height and hangs off the
## BOTTOM rather than being centred (which would clip it at both ends) or
## squashed (which would deform a card). That is what [HFlowContainer] did
## before this class replaced it, and it matters at the board seam: the
## player's land row sits directly under the Situation Bar, and a tall
## strip-stack centred there loses its top card's name band behind the bar.
func _place(child: Control, x: float, width: float) -> void:
	var height: float = child.get_combined_minimum_size().y
	var y: float = maxf((size.y - height) * 0.5, 0.0)
	fit_child_in_rect(child, Rect2(Vector2(x, y), Vector2(width, height)))
