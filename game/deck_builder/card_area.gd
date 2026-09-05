class_name CardArea
extends Control
## THE DECK AREA AND THE INVENTORY AREA — the two card surfaces of the
## 1997 Deck Builder, which are the same widget twice. The manual's own
## nouns (ch.10, "Using the Deck Builder"): *"The largest area of the
## screen contains the deck you're working on. Cards are represented in
## miniature."* and *"Along the bottom of the screen, in the Inventory
## area, is every card you can put into a deck."*
##
## Every card here is a [MiniCard] — the project's ONE small-card
## generator (frame texture, art, name, mana stripes, badges, P/T). This
## widget only arranges them, scales them and puts the count badge on
## them; it draws no card art of its own.
##
## PAGING, not an 800-card scene. s30's ScrollableList renders only the
## window between `currentOffset` and `currentOffset+visibleCount`
## (`edit_deck.go:895-932`), and so do we: a page of `columns x rows`
## widgets is built, and scrolling REBINDS that page. Building all 800
## MiniCards at once would be ten thousand nodes for twenty visible cards.
## The second audit pass added the other half of that idea: the page's
## widgets are also SLID ALONG as it scrolls ([method _rotate_cells]), so
## the ones that already hold the right card are not rebound at all.
##
## WHICH WAY THE CARDS FLOW follows the SCROLL BAR, and that is the audit
## pass's correction (2026-08-31). A bar down the side moves the surface
## up and down, so the Deck reads left-to-right then down. A bar *along
## the bottom* moves it sideways — *"At the bottom of the Inventory area
## is a scroll bar you can use to move through your inventory"* — so the
## Inventory reads top-to-bottom then across, the way a card rack does.
## Both bars count whole STEPS (a row or a column of cards), so the wheel,
## the bar and the keyboard always land on the same page; before the fix
## the bar counted single cards and drifted out of step with the wheel.
##
## THE GESTURES are the manual's: *"To move a card from the inventory into
## your deck, simply double-click on it or drag it there with the mouse,
## then release"* and *"If you decide to remove a card from the deck, just
## double-click on it or drag it from this area into the Inventory area."*
## A SINGLE click does the same thing — a modern affordance we owe the
## player, since a double-click-only surface feels broken today — and a
## right-click takes the whole stack of copies at once.

## One copy in or out (click, double-click, or the keyboard).
signal card_activated(card_name: String)
## The whole column of copies at once (right-click).
signal card_bulk(card_name: String)
## [QoL] SHIFT-CLICK — "send this one to the OTHER pile". The three
## surfaces read it as the same sentence: from the Inventory a copy goes
## straight to the sideboard, from the Deck a copy crosses into the
## sideboard, and from the Sideboard it crosses back. Drag-and-drop is the
## manual's own gesture and does the same job; this is the one-handed
## route, because a fifteen-card sideboard is fifteen drags otherwise.
signal card_shifted(card_name: String)
## A card was DROPPED on this area, having been dragged from another one.
signal card_dropped(card_name: String, source: String)
## The pointer moved onto a card — the Showcase follows it.
signal card_hovered(data: CardData)
## [QoL] The page moved. The screen letters which slice of the list is on
## screen, which it can only do if it hears about the move.
signal scrolled

## ONE CARD SIZE, EVERYWHERE. [constant MiniCard.SIZE] is the project's
## only card dimension and its own doc names this surface — *"table, hand,
## piles, graveyard, exile, ante, the deck builder's grid: one dimension
## everywhere, never rescaled"*. The DECK area used to draw its faces at
## 0.85 inside 112x90 holders, which put a second card size on the one
## screen that shows two card surfaces at once; the third audit pass
## (2026-09-01) took it out. Both surfaces are 1:1 and a cell is a card.
##
## WHAT IT COST, stated rather than hidden: at 1280x800 the deck area holds
## 7x5 = 35 slots a page instead of 8x6 = 48, so a 200-card deck is six
## pages rather than five. The scroll bar, the wheel, PageUp/PageDown and
## `Consolidate duplicate cards` are what the 1997 screen expected you to
## reach for, and a card you cannot read is worth less than a card you have
## to page to.
const GAP := Vector2(6, 6)
const BAR_THICKNESS := 12.0
## How much of a bottom-bar area's own bar row a [member title] takes.
## The heading rides ON the scroll-bar row rather than above it, so
## naming a surface costs the CARDS nothing — which matters, because the
## sideboard strip is carved out of the deck area's height.
const TITLE_W := 132.0
## The same again at the OTHER end of that row, for [member tally] — and
## it is a RATIO of a card rather than a number, for the same reason
## [constant TALLY_FONT_RATIO] is: the two have to move together or the
## count runs off its own end of the bar row.
##
## `1.3` is what "899 cards" needs at [method tally_font_size]: nine
## glyphs of about half the font size, plus the outline's own two pixels a
## side and a little air.
const TALLY_W := MiniCard.SIZE.x * 1.3
## THE TALLY'S SIZE, AS A FRACTION OF THE CARD IT SITS ON. The owner's
## playtest, 2026-09-04: *"Lower right number of cards — make much bigger,
## as it is not seen now."* It shipped at 14px, which is the lettering of
## the bar row it rides and not the lettering of a number a player is
## meant to WATCH while the filters move.
##
## A RATIO, NOT A FEEL, and the ratio is of the thing the number sits on —
## the same rule the duel screen's own numbers are sized by (the life
## numeral is 44 on a 76px panel, the coin's letter is
## `int(COIN * 0.5)`, `game/duel/coin_toss.gd`). Here the thing under the
## number is a card: [constant MiniCard.SIZE] is 132x106 everywhere in
## this game, so 0.26 of a card's height is 27px — a number that reads
## from across the room, and one that cannot drift when a card size
## changes, because there is only one card size to drift with.
const TALLY_FONT_RATIO := 0.26
## [QoL] THE TWO SCROLL ARROWS, one at each end of the card row. The
## owner's playtest, 2026-09-04: *"Add arrows to the left and right of
## cards to help scroll, beside the scrollbar at the bottom."* They flank
## the CARDS and run the full height of the area, so they are beside the
## bar row as well as beside the row of cards — one control answering both
## halves of the sentence.
const ARROW_W := 20.0
## HELD DOWN KEEPS SCROLLING. A click is one step; hold the button and the
## surface runs, after a beat long enough that a deliberate single click
## never turns into two. The numbers are the platform's own key-repeat
## feel rather than an invention.
const ARROW_DELAY := 0.35
const ARROW_REPEAT := 0.07

## THE DECK AREA'S EMPTY-SLOT WATERMARKS. `deck_slot_plaques` (Bldr_sheet,
## 5 cells of 117 x 2 rows of 100) is the 1997 carving that makes the deck
## area a QUILT of slots rather than a plain field: the owner's screenshot
## lays these edge to edge across the whole area, cycling
## `index = (row * columns + col) % 5`, which is what produces the diagonal
## drift of tree / drop / skull / sun / dragon. Column order B W R G U;
## the BOTTOM row (cool blue slate) is the one that belongs on the navy
## `deck_tile_slate` ground, the top row (warm gold) on the olive one.
const PLAQUE := Vector2i(117, 100)
const PLAQUE_COLUMNS := 5

## Names this area's drag payloads so a drop can tell where a card came
## from ("deck" / "inventory" / "sideboard"), the way s30's
## `deckCardDragIDPrefix` does.
var source_name := "deck"
## [QoL] A HEADING ON THE BAR ROW, for a surface that would otherwise be
## an unlabelled band of cards. Only meaningful with a bottom bar. The
## Deck area and the Inventory are named by the manual's own figure and
## need none; the SIDEBOARD strip is new furniture and must say so.
var title := "":
	set(value):
		# A NO-OP WRITE IS FREE. The screen letters the sideboard's count
		# into this on every card click ([method
		# DeckBuilderScreen._refresh_sideboard_area]) and `_relayout()` is
		# a full page rebuild, so an unguarded setter would have made every
		# click on the Inventory pay for the sideboard strip.
		if title == value:
			return
		var was_named := title != ""
		title = value
		if _title_label != null:
			_title_label.text = value
			_title_label.visible = value != ""
		# Only the bar's width depends on it, and only the first and last
		# word actually move it.
		if was_named != (value != ""):
			_relayout()
## [QoL] HOW MANY CARDS THIS SURFACE HOLDS, lettered into the BOTTOM-RIGHT
## CORNER of the area itself — the far end of the same bar row [member
## title] starts. The 2026-09-03 playtest: *"The number of cards in the
## bottom row should be displayed in the bottom right — if you filter you
## immediately see this number get smaller and see the effect of the
## filter!"* The Inventory's `X cards are in the list` already stood in
## the left column, three regions away from the cards it counts; a filter
## you can only check by looking somewhere else is a filter you cannot
## feel. Empty on a surface that sets none, exactly like [member title].
##
## The number itself is the CALLER's to compose — see [method
## DeckBuilderScreen._update_count_line] for what the Inventory counts and
## why it is not the page.
var tally := "":
	set(value):
		# A no-op write is free, for the same reason [member title]'s is:
		# this is written on every scroll notch and every filter change.
		if tally == value:
			return
		var was_shown := tally != ""
		tally = value
		if _tally_label != null:
			_tally_label.text = value
			_tally_label.visible = value != ""
		# Only the scroll bar's width depends on it, and only the first
		# and last word actually move it.
		if was_shown != (value != ""):
			_relayout()
## [QoL] A SHORT TAG ON EVERY CELL OF THIS AREA — "SB" on the sideboard.
## A card in the sideboard must never be confusable at a glance with a
## card in the deck, and the strip's own position and ground are only two
## of the three answers to that; this is the third, on the card itself.
var corner_tag := "":
	set(value):
		corner_tag = value
		for cell in _cells:
			_dress_tag(cell)
## Lay the 1997 slot carvings under the cards (the Deck area does; the
## Inventory sits on Dekbar1's plain teal field, as it does in 1997).
var slot_plaques := false:
	set(value):
		slot_plaques = value
		queue_redraw()
## [QoL] Flank the cards with the two scroll arrows — see [constant
## ARROW_W]. Only meaningful on a surface with a BOTTOM bar, which is the
## surface the owner asked for them on; a side-barred area is scrolled by
## its own bar down the edge the arrows would stand on.
var scroll_arrows := false:
	set(value):
		if scroll_arrows == value:
			return
		scroll_arrows = value
		if value:
			_build_arrows()
		else:
			_free_arrows()
		_relayout()
## [QoL] The smallest count that earns a badge. The Deck area badges
## DUPLICATES (2+), which is the manual's *"tiny number on the single
## representative card"*; the Inventory badges ANY copy already in the
## deck (1+), so "how many of these have I got?" is answered where the
## question is asked instead of by scanning the deck area.
var badge_min := 2
## [QoL] Where a cell's badge number comes from, when it is not the entry's
## own count: `func(card_name) -> int`. The Inventory sets this to the
## deck's count. It is called PER VISIBLE CELL, never per pool card, so
## the deck changing costs ten dictionary lookups and not an 800-card walk
## — which is what keeps the audit pass's `DeckFilter.revision` gate
## meaningful.
var count_source := Callable()
## `&Consolidate duplicate cards` — *"toggles whether multiple copies of
## the same card are displayed separately or grouped together. If they're
## together, a tiny number on the single representative card notes how
## many copies of that card are actually in your deck."*
var consolidated := true:
	set(value):
		if consolidated != value:
			consolidated = value
			_expanded.clear()
			if _grid != null:
				_rebuild()

var _entries: Array = []          ## [[CardData, count], ...] in display order
## [member _entries] with every copy on its own face, built only while
## [member consolidated] is off. Cached so `_rebuild` does not re-expand a
## 500-card deck on every wheel notch.
var _expanded: Array = []
var _offset := 0
var _grid: Control
var _bar: ScrollBar
var _vertical_bar := true
## One card, and it is [constant MiniCard.SIZE] on both surfaces.
var _cell := Vector2.ZERO
## Where the page's block of columns starts, and how many columns it has —
## kept from the last [method _rebuild] so [method _draw] lays the slot
## carvings on exactly the grid the cards sit on.
var _inset := 0.0
var _columns := 1
## The page's widgets, built once and REBOUND as the surface scrolls.
var _cells: Array[Cell] = []
## WHICH SLOT OF THE PAGE THE POINTER IS ON, or -1 — and it is the SLOT,
## not the widget. The Showcase shows *"whatever card the mouse cursor is
## hovering over"*, the WHEEL moves cards under a cursor that has not
## moved, and Godot only re-runs its enter/exit test when the pointer
## ITSELF moves. So after a notch the Showcase went on displaying a card
## that had scrolled off, and the lit card was somewhere else on the row
## (third audit pass, 2026-09-01). [method _rebuild] hands the hover to
## whatever card lands in this slot.
var _hovered_slot := -1
## The card last reported to the Showcase, so a rebuild that does not
## change what is under the pointer says nothing.
var _hovered_card := ""
var _title_label: Label = null
var _tally_label: Label = null
var _left_arrow: Button = null
var _right_arrow: Button = null
## Which way a held arrow is scrolling: -1, 0 or +1. See [method _process].
var _held := 0
## Seconds until the held arrow steps again.
var _repeat_in := 0.0


func _init(vertical_bar := true) -> void:
	_vertical_bar = vertical_bar
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	_cell = MiniCard.SIZE
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_grid)
	_bar = VScrollBar.new() if vertical_bar else HScrollBar.new()
	_bar.value_changed.connect(func(value: float) -> void:
		scroll_to(int(value) * scroll_step()))
	add_child(_bar)
	_title_label = OriginalDialog.label("", 12, true)
	_title_label.visible = false
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)
	_tally_label = _make_tally_label()
	add_child(_tally_label)
	# NOTHING TICKS UNTIL AN ARROW IS HELD. `_process` exists only for the
	# arrows' repeat, and a card surface that ran a frame handler for the
	# life of the screen to do nothing would be paying for a feature it is
	# not using ([method press_arrow] turns it on).
	set_process(false)


func _ready() -> void:
	_relayout()


## Godot delivers a resize as a notification; connecting to the `resized`
## signal in `_init` is not enough, because a Control sized before it
## enters the tree emits it before this node's children exist.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _relayout() -> void:
	var pad := arrow_pad()
	var inner := _inner_size()
	# The cards start INSIDE the left arrow, never under it.
	_grid.position = Vector2(pad, 0.0)
	_grid.size = inner
	if _vertical_bar:
		_bar.position = Vector2(size.x - BAR_THICKNESS, 0)
		_bar.size = Vector2(BAR_THICKNESS, size.y)
	else:
		# The heading, when there is one, takes the left of the bar row,
		# the [member tally] takes the right of it, and the bar takes what
		# is left — so a named or counted surface is exactly as tall as a
		# bare one, and neither label ever sits ON the bar. The arrows take
		# their own column off each end before any of that.
		var left := (TITLE_W if title != "" else 0.0) + pad
		var right := (TALLY_W if tally != "" else 0.0) + pad
		_bar.position = Vector2(left, size.y - BAR_THICKNESS)
		_bar.size = Vector2(maxf(0.0, size.x - left - right), BAR_THICKNESS)
	if _title_label != null:
		_title_label.position = Vector2(2.0 + pad, size.y - 16.0)
		_title_label.size = Vector2(TITLE_W - 6.0, 14)
	if _tally_label != null:
		# A VERTICAL bar owns the right edge, so the tally steps in off it;
		# a bottom bar has already given up [constant TALLY_W] above.
		var edge := (BAR_THICKNESS if _vertical_bar else 0.0) + pad
		# TALL ENOUGH FOR THE FONT IT NOW CARRIES. At [constant
		# TALLY_FONT_RATIO] of a card the number is 27px, so a 17px box
		# clipped its own descenders; it is sized off the font for the same
		# reason the font is sized off the card.
		var box := tally_font_size() + 6
		_tally_label.position = Vector2(size.x - TALLY_W - edge + 2.0,
			size.y - box - 2.0)
		_tally_label.size = Vector2(TALLY_W - 6.0, box)
	if _left_arrow != null:
		_left_arrow.position = Vector2.ZERO
		_left_arrow.size = Vector2(ARROW_W, size.y)
		_right_arrow.position = Vector2(maxf(0.0, size.x - ARROW_W), 0.0)
		_right_arrow.size = Vector2(ARROW_W, size.y)
	_rebuild()
	# A RESIZE MOVES THE PAGE: it changes how many cards fit and it can
	# clamp the offset, and neither went through [method scroll_to], so
	# nothing told the screen. The Inventory's `(1-9)` therefore went on
	# naming a page the player was not looking at (third audit pass,
	# 2026-09-01). Emitting here is the one place both cases pass through.
	scrolled.emit()


## THE TALLY'S VOICE. It is the lettering already on this row — the
## [member title]'s pale [constant OriginalDialog.HIGHLIGHT] — with a hard
## dark OUTLINE under it rather than the era's one-pixel shadow. That is
## the house rule the zone column settled the same day (duel_screen.gd,
## [constant DuelScreen.PILE_COUNT_INK]): a number over busy art needs a
## FLOOR, not a new hue, and this corner is the busiest ground the screen
## has — Dekbar1's dithered teal, the scroll bar's stone, and the bottom
## edge of whatever card art the last column happens to hold.
func _make_tally_label() -> Label:
	var label := OriginalDialog.label("", tally_font_size())
	label.add_theme_color_override("font_outline_color", OriginalDialog.INK)
	# THE FLOOR GROWS WITH THE LETTERS. 3px under 14px type is the same
	# proportion 4px is under 27px, and it is the duel's own number outline
	# ([constant DuelScreen.PILE_COUNT_OUTLINE_SIZE]) — a number over busy
	# art needs a floor, not a new hue.
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## What one end of the row gives up to a scroll arrow — zero when there
## are none. Public because the layout, the quilt and the tests all have
## to agree about it.
func arrow_pad() -> float:
	return ARROW_W if scroll_arrows else 0.0


## The area minus the strip the scroll bar occupies, and minus the two
## arrow columns when this surface has them.
func _inner_size() -> Vector2:
	var pad := 2.0 * arrow_pad()
	if _vertical_bar:
		return Vector2(maxf(size.x - BAR_THICKNESS - 2.0 - pad, 0.0), size.y)
	return Vector2(maxf(size.x - pad, 0.0),
		maxf(size.y - BAR_THICKNESS - 2.0, 0.0))


## The tally's font size — see [constant TALLY_FONT_RATIO].
static func tally_font_size() -> int:
	return int(MiniCard.SIZE.y * TALLY_FONT_RATIO)


func columns() -> int:
	return maxi(1, int((_inner_size().x + GAP.x) / (_cell.x + GAP.x)))


func rows() -> int:
	return maxi(1, int((_inner_size().y + GAP.y) / (_cell.y + GAP.y)))


func page_size() -> int:
	return columns() * rows()


# ------------------------------------------------------------ scrolling --

## How many cards one notch of the wheel, one click of the bar or one
## press of an arrow key moves: a ROW when the bar is down the side, a
## COLUMN when it lies along the bottom.
func scroll_step() -> int:
	return columns() if _vertical_bar else rows()


## Index of the first card on the page. Always a multiple of
## [method scroll_step], so the surface reads as a grid rather than a
## sliding window.
func offset() -> int:
	return _offset


## The largest [method offset] that still fills the page — the last card
## always sits on the last page, never one row below it.
func max_offset() -> int:
	var step := scroll_step()
	var total: int = int(ceil(float(_visible_entries().size()) / float(step)))
	var visible: int = int(ceil(float(page_size()) / float(step)))
	return maxi(0, total - visible) * step


func scroll_to(card_index: int) -> void:
	var step := scroll_step()
	var wanted: int = clampi(card_index - card_index % step, 0, max_offset())
	if wanted == _offset:
		return
	var moved := wanted - _offset
	_offset = wanted
	_rebuild(moved)
	scrolled.emit()


func scroll_by(steps: int) -> void:
	scroll_to(_offset + steps * scroll_step())


func scroll_to_end() -> void:
	scroll_to(max_offset())


func reset_scroll() -> void:
	scroll_to(0)


func page_down() -> void:
	scroll_by(maxi(1, page_size() / scroll_step()))


func page_up() -> void:
	scroll_by(-maxi(1, page_size() / scroll_step()))


func home() -> void:
	scroll_to(0)


func end() -> void:
	scroll_to_end()


# ------------------------------------------------- [QoL] the two arrows --
# *"Add arrows to the left and right of cards to help scroll, beside the
# scrollbar at the bottom."* (owner's playtest, 2026-09-04)
#
# THREE THINGS THE ASK NAMES, and all three are load-bearing:
#
#   FLANKING THE CARDS. A column at each end of the area, full height, so
#     they are beside the row of cards AND beside the bar row under it.
#     The cards give up [constant ARROW_W] at each end for them — see
#     [method _inner_size]; nothing is drawn under an arrow.
#   HELD DOWN KEEPS SCROLLING. A Godot [Button] has no auto-repeat, so a
#     press arms [member _repeat_in] and [method _process] steps the
#     surface until the button comes up. One click is still exactly one
#     step, because the first step happens on the press itself and the
#     repeat only starts [constant ARROW_DELAY] later.
#   DISABLED AT ITS OWN END. *"Disable an arrow at its end of the list
#     rather than letting it do nothing silently."* [method
#     _refresh_arrows] runs from [method _rebuild], which is every scroll,
#     every resize and every new list — so the state can never lag the
#     surface it describes.

func _build_arrows() -> void:
	if _left_arrow != null:
		return
	_left_arrow = _make_arrow(-1)
	_right_arrow = _make_arrow(1)
	add_child(_left_arrow)
	add_child(_right_arrow)


func _free_arrows() -> void:
	for button in [_left_arrow, _right_arrow]:
		if button != null:
			button.queue_free()
	_left_arrow = null
	_right_arrow = null
	_held = 0
	set_process(false)


## One arrow: the era's own stone button with a triangle painted on it.
##
## FOCUS_NONE, deliberately. The surface itself takes the keyboard
## ([method _gui_input] answers the arrow keys and PageUp/PageDown), and a
## button that stole focus on every click would take those keys away from
## the cards the moment a player used the mouse.
func _make_arrow(facing: int) -> Button:
	var button := OriginalDialog.button("", Vector2(ARROW_W, ARROW_W))
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Scroll %s — hold to keep scrolling" \
		% ("left" if facing < 0 else "right")
	var glyph := Arrow.new()
	glyph.facing = facing
	# A BARE Control DEFAULTS TO MOUSE_FILTER_STOP, and one inside a
	# button swallows the press that button exists for. Four defects in
	# this project came from that one default; this is not the fifth.
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(glyph)
	button.button_down.connect(press_arrow.bind(facing))
	button.button_up.connect(release_arrow)
	return button


## Take one arrow down — one step now, and the repeat armed. Public: it is
## the seam the tests hold the button down through, since a headless run
## has no pointer to hold it with.
func press_arrow(facing: int) -> void:
	_held = facing
	_repeat_in = ARROW_DELAY
	scroll_by(facing)
	set_process(true)


## Let it up again.
func release_arrow() -> void:
	_held = 0
	set_process(false)


func _process(delta: float) -> void:
	if _held == 0:
		set_process(false)
		return
	_repeat_in -= delta
	if _repeat_in > 0.0:
		return
	_repeat_in = ARROW_REPEAT
	var before := _offset
	scroll_by(_held)
	if _offset == before:
		# The end of the list. Stop the repeat rather than spinning on it;
		# the button is about to be disabled under the finger anyway.
		release_arrow()


## Grey out the arrow that has nowhere left to go — and both of them when
## the whole list already fits on one page.
func _refresh_arrows() -> void:
	if _left_arrow == null:
		return
	_left_arrow.disabled = _offset <= 0
	_right_arrow.disabled = _offset >= max_offset()
	# The stone gets Godot's `disabled` box on its own; the TRIANGLE is a
	# child that draws itself and would otherwise stay full-strength ink
	# on a greyed-out button, which reads as enabled.
	for button in [_left_arrow, _right_arrow]:
		var glyph: Node = button.get_child(0)
		if glyph is CanvasItem:
			(glyph as CanvasItem).modulate.a = 0.3 if button.disabled else 1.0


## The triangle on an arrow button. A drawn shape rather than a glyph,
## because the skin's own face is a 1997 bitmap font and a `◀` it does not
## carry is a tofu box on the one control whose whole job is to be
## unmistakable.
class Arrow extends Control:
	## -1 points left, +1 points right.
	var facing := -1

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var half := minf(w, h) * 0.28
		var mid := Vector2(w * 0.5, h * 0.5)
		var tip := Vector2(mid.x + facing * half * 0.9, mid.y)
		var points := PackedVector2Array([tip,
			Vector2(mid.x - facing * half * 0.7, mid.y - half),
			Vector2(mid.x - facing * half * 0.7, mid.y + half)])
		# The button face is the era's pale speckle, so the arrow is the
		# era's DARK INK on it — the same voice the original letters its
		# own light-faced buttons in ([method OriginalDialog.ink_label]).
		draw_colored_polygon(points, OriginalDialog.INK)


# -------------------------------------------------------------- content --

## What the area shows, in display order: `[[CardData, count], ...]`.
## Counts above one become the badge when [member consolidated] is set,
## and separate faces when it is not.
##
## The scroll position SURVIVES by default. The Inventory is the whole
## card pool and does not depend on the deck, so putting a card in the
## deck must not throw the player back to the first card — s30 resets its
## carousel only when a FILTER changes (`edit_deck.go:391-396`), and so do
## we, by calling [method reset_scroll] there and nowhere else.
func set_entries(entries: Array) -> void:
	_entries = entries
	_expanded.clear()
	_rebuild()


func entry_count() -> int:
	return _visible_entries().size()


## The page's live widgets, in display order. For tests and for the
## keyboard, which needs the card under the cursor.
func cell_nodes() -> Array[Cell]:
	var out: Array[Cell] = []
	for cell in _cells:
		if cell.visible:
			out.append(cell)
	return out


## Expand or keep the entries per [member consolidated].
func _visible_entries() -> Array:
	if consolidated:
		return _entries
	if _expanded.is_empty() and not _entries.is_empty():
		for entry in _entries:
			for _i in int(entry[1]):
				_expanded.append([entry[0], 1])
	return _expanded


## Lay the page out. [param shifted] is how many CARDS the surface has just
## scrolled by, and it is the second audit pass's optimisation: see
## [method _rotate_cells]. Zero (a resize, a new list) rebinds everything.
func _rebuild(shifted := 0) -> void:
	if shifted != 0:
		_rotate_cells(shifted)
	var entries := _visible_entries()
	var per_page := page_size()
	var cols := columns()
	var row_count := rows()
	var step := scroll_step()
	_offset = clampi(_offset - _offset % step, 0, max_offset())
	# The bar counts STEPS, and `_offset` is always a whole number of them,
	# so bar and wheel can never drift apart.
	var total_steps: int = int(ceil(float(entries.size()) / float(step)))
	var visible_steps: int = int(ceil(float(per_page) / float(step)))
	_bar.max_value = maxf(total_steps, visible_steps)
	_bar.page = visible_steps
	_bar.set_value_no_signal(float(_offset) / float(step))
	_bar.visible = total_steps > visible_steps
	_refresh_arrows()
	# Centre the fixed block of columns in the area: the column count never
	# changes with the card count, so this is a stable margin, not a
	# shifting one, and it keeps the Inventory's leftover strip off one end.
	var inset := maxf(0.0, (_inner_size().x - (cols * (_cell.x + GAP.x) - GAP.x)) / 2.0)
	_inset = inset
	_columns = cols
	queue_redraw()
	var shown: int = mini(per_page, maxi(0, entries.size() - _offset))
	for i in maxi(shown, _cells.size()):
		if i >= shown:
			_cells[i].visible = false
			continue
		var entry: Array = entries[_offset + i]
		var cell: Cell
		if i < _cells.size():
			cell = _cells[i]
		else:
			cell = _make_cell(entry[0])
			_cells.append(cell)
			_grid.add_child(cell)
		_bind_cell(cell, entry[0], int(entry[1]))
		# Row-major under a side bar, COLUMN-major under a bottom bar.
		var col := (i % cols) if _vertical_bar else (i / row_count)
		var row := (i / cols) if _vertical_bar else (i % row_count)
		cell.position = Vector2(inset + col * (_cell.x + GAP.x),
			row * (_cell.y + GAP.y))
		cell.visible = true
	_settle_hover(shown)


## HAND THE HOVER TO WHOEVER IS IN THE SLOT NOW. The pointer has not moved,
## so Godot will send no `mouse_entered`; the widgets moved instead. The
## Showcase is only told when the card in the slot really changed, so a
## card click (which rebinds the whole page) says nothing.
func _settle_hover(shown: int) -> void:
	# Exactly one card is lit, and it is the one in the hovered slot: the
	# widget that used to be there has moved somewhere else on the page and
	# would otherwise stay lit under no pointer at all. `MiniCard.hovered`
	# ignores a write that does not change it, so this loop is free.
	var lit: int = _hovered_slot if _hovered_slot < shown else -1
	for i in _cells.size():
		_cells[i].set_hovered(i == lit)
	if lit < 0:
		return
	var cell := _cells[lit]
	if cell.data != null and cell.card_name != _hovered_card:
		_hovered_card = cell.card_name
		card_hovered.emit(cell.data)


## SLIDE THE PAGE'S WIDGETS ALONG INSTEAD OF REFILLING THEM — the second
## audit pass's optimisation (2026-08-31), on top of the first's decision
## to rebind a fixed page rather than rebuild it.
##
## Cell `i` of the page always shows `entries[_offset + i]`, so after the
## surface scrolls by N cards the widget that already holds the right card
## for slot `i` is the one that was in slot `i + N`. Rotating the array by
## N puts every one of them where it belongs, and [method _bind_cell]'s
## `cell.data != data` guard then does nothing for all but the N slots that
## really are new.
##
## It matters because rebinding a cell means [method MiniCard.refresh] —
## art, frame, mana stripes, badges — at about 0.3 ms each. One wheel notch
## on the deck area is 8 new cards in a page of 40, and it was paying for
## all 40: measured 11.8 ms a notch before this, 2.6 ms after. The widgets
## are the same objects either way; only their order in [member _cells]
## changes, and nothing outside this class depends on that order.
func _rotate_cells(shift: int) -> void:
	var count := _cells.size()
	if count == 0:
		return
	var by: int = ((shift % count) + count) % count
	if by == 0:
		return
	var rotated: Array[Cell] = []
	rotated.resize(count)
	for i in count:
		rotated[i] = _cells[(i + by) % count]
	_cells = rotated


## THE QUILT. A Control draws before its children, so the carvings land
## under every card without a node of their own — which matters, because
## the whole point of the audit pass's paging is that this surface holds a
## page of widgets and not a field of them.
##
## The carvings are laid on the CARD PITCH (cell + gap) and start half a
## gap earlier, so they meet edge to edge with no seam and each one frames
## the card that sits in it — the reference's quilt exactly. They cover the
## WHOLE area, not just the occupied slots: in 1997 an empty deck is a full
## grid of watermarks waiting to be filled.
func _draw() -> void:
	if not slot_plaques:
		return
	var sheet := GameSkin.texture("deck_slot_plaques")
	if sheet == null:
		return
	var pitch := _cell + GAP
	var inner := _inner_size()
	var down: int = int(ceil(inner.y / pitch.y))
	var across: int = int(ceil((inner.x - _inset) / pitch.x))
	for row in down:
		for col in across:
			var index: int = (row * _columns + col) % PLAQUE_COLUMNS
			var art := _plaque(index)
			if art == null:
				continue
			draw_texture_rect(art, Rect2(
				Vector2(arrow_pad() + _inset - GAP.x / 2.0 + col * pitch.x,
					-GAP.y / 2.0 + row * pitch.y), pitch), false)


## One carved slot, from the sheet's BOTTOM row (cool blue slate — the row
## that belongs on the navy ground). Cached: five textures for the life of
## the process, not one per redraw.
static var _plaque_cache: Array[Texture2D] = []

static func _plaque(index: int) -> Texture2D:
	if _plaque_cache.is_empty():
		_plaque_cache.resize(PLAQUE_COLUMNS)
		var sheet := GameSkin.texture("deck_slot_plaques")
		if sheet == null:
			return null
		var image := sheet.get_image()
		if image.get_height() < 2 * PLAQUE.y:
			return null
		for i in PLAQUE_COLUMNS:
			if image.get_width() < (i + 1) * PLAQUE.x:
				break
			_plaque_cache[i] = ImageTexture.create_from_image(
				image.get_region(Rect2i(i * PLAQUE.x, PLAQUE.y, PLAQUE.x, PLAQUE.y)))
	return _plaque_cache[index] if index < _plaque_cache.size() else null


## ONE CARD on a surface: a MiniCard face at this area's card scale inside
## a fixed-size holder that carries the drag payload. A holder rather than
## a Button because Godot's drag gesture starts from `_get_drag_data`,
## which a Button's own press handling would swallow.
class Cell extends Control:
	var data: CardData = null
	var card_name := ""
	var source := ""
	## The card's face. EXACTLY ONE of these two is set: a cell holding a
	## real card has a [MiniCard], a cell holding a PROXY has a
	## [ProxyFace], and they are separate fields rather than one
	## `Control` because GDScript's static typing cannot reach
	## `.hovered` or `.instance` through a `Control`. [method set_hovered]
	## and [method CardArea._bind_cell] are the two places that care.
	var face: MiniCard = null
	var proxy: ProxyFace = null
	var badge: Control = null
	var badge_label: Label = null
	## [QoL] The pile marker — see [member CardArea.corner_tag].
	var tag: Control = null
	var tag_label: Label = null

	## Whichever face this cell is holding, for the callers that only need
	## to position or free it.
	func face_node() -> Control:
		return face if face != null else proxy

	## Light the card under the pointer, whichever kind it is.
	func set_hovered(on: bool) -> void:
		if is_instance_valid(face):
			face.hovered = on
		elif is_instance_valid(proxy):
			proxy.hovered = on

	## The strip of card the pointer carries while a card is in flight —
	## the card's own title bar with its name on it.
	const GHOST := Vector2(120, 20)

	func _get_drag_data(_at: Vector2) -> Variant:
		# A PROXY DRAGS AS PAPER. `MiniCard.frame_strip` picks a frame by
		# COLOUR and a proxy has none to pick with, so it would come back
		# `card_frame_artifact` — a coloured frame on the one card that
		# must never wear one. It gets [constant ProxyFace.PAPER] and dark
		# ink instead, which is what it looks like on the surface it came
		# from.
		var proxied := ProxyCard.is_proxy_data(data)
		var ground: Control
		if proxied:
			var paper := ColorRect.new()
			paper.color = ProxyFace.PAPER
			ground = paper
		else:
			var ghost := TextureRect.new()
			ghost.texture = MiniCard.frame_strip(data)
			ground = ghost
		ground.custom_minimum_size = GHOST
		ground.size = GHOST
		var label := Label.new()
		label.text = card_name
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color",
			ProxyFace.INK if proxied else Color(1, 1, 0.95))
		if not proxied:
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var holder := Control.new()
		holder.custom_minimum_size = GHOST
		holder.size = GHOST
		holder.add_child(ground)
		holder.add_child(label)
		set_drag_preview(holder)
		return {"card_name": card_name, "source": source}


## An EMPTY page widget. Built once per visible slot and rebound by
## [method _bind_cell] as the surface scrolls: a MiniCard is some twenty
## nodes, so freeing and rebuilding the whole page on every wheel notch
## was the screen's largest single cost (measured 37.7 ms per notch).
func _make_cell(first: CardData) -> Cell:
	var holder := Cell.new()
	holder.source = source_name
	holder.custom_minimum_size = _cell
	holder.size = _cell
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_dress_face(holder, first)
	var badge := _badge()
	holder.badge = badge
	holder.badge_label = badge.get_child(0)
	holder.add_child(badge)
	var tag := _tag()
	holder.tag = tag
	holder.tag_label = tag.get_child(0)
	holder.add_child(tag)
	_dress_tag(holder)
	holder.gui_input.connect(_on_cell_input.bind(holder))
	holder.mouse_entered.connect(func() -> void:
		_hovered_slot = _cells.find(holder)
		_hovered_card = holder.card_name
		holder.set_hovered(true)
		if holder.data != null:
			card_hovered.emit(holder.data))
	holder.mouse_exited.connect(func() -> void:
		# Godot tracks the WIDGET it last called hovered, not the slot, so
		# the exit can arrive on a widget the scroll has since moved
		# elsewhere — and it still means "the pointer has left". It is
		# safe to clear unconditionally: on a move between two cards the
		# exit is delivered before the new card's enter.
		_hovered_slot = -1
		_hovered_card = ""
		holder.set_hovered(false))
	return holder


## GIVE A CELL THE RIGHT KIND OF FACE — a [MiniCard] for a real card, a
## [ProxyFace] for a proxy ([ProxyCard]). Called once by
## [method _make_cell] and again by [method _bind_cell] only when a cell
## has to change KIND, which is the rare case: proxies sort together
## ([method DeckModel._sort_rank] ranks them last), so a page is almost
## always all one kind or has one boundary in it.
##
## The old face is freed. That is the one place this surface still pays
## the ~0.3 ms a face costs to build, and it is paid per KIND CHANGE
## rather than per scroll — the paging optimisation the second audit pass
## measured is untouched for every other rebind.
func _dress_face(cell: Cell, data: CardData) -> void:
	var wanted_proxy := ProxyCard.is_proxy_data(data)
	if wanted_proxy and cell.proxy != null:
		return
	if not wanted_proxy and cell.face != null:
		return
	var old := cell.face_node()
	if old != null:
		cell.remove_child(old)
		old.queue_free()
	cell.face = null
	cell.proxy = null
	var face: Control
	if wanted_proxy:
		var paper := ProxyFace.new(data.card_name)
		cell.proxy = paper
		face = paper
	else:
		var card := MiniCard.new(CardInstance.new(data, -1, 0))
		cell.face = card
		face = card
	face.size = MiniCard.SIZE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.focus_mode = Control.FOCUS_NONE
	# The holder takes every click. `Button.disabled` on both kinds —
	# ProxyFace is a Button for the same reason MiniCard is.
	(face as Button).disabled = true
	# BEHIND the badge and the tag, which were added after the face was in
	# `_make_cell` and must stay on top when a face is swapped in later.
	cell.add_child(face)
	cell.move_child(face, 0)


## Point one page widget at a different card.
func _bind_cell(cell: Cell, data: CardData, count: int) -> void:
	if cell.data != data:
		cell.data = data
		cell.card_name = data.card_name
		_dress_face(cell, data)
		if cell.proxy != null:
			cell.proxy.hovered = false
			cell.proxy.set_proxy_name(data.card_name)
			# A proxy says what it is where a card says what it does.
			cell.tooltip_text = cell.proxy.tooltip_text
		else:
			cell.face.instance = CardInstance.new(data, -1, 0)
			cell.face.hovered = false
			cell.face.refresh()
			cell.tooltip_text = "%s\n%s" % [data.card_name, data.oracle_text]
	cell.source = source_name
	_bind_badge(cell, count)


func _bind_badge(cell: Cell, count: int) -> void:
	var shown := count
	if count_source.is_valid() and cell.data != null:
		shown = int(count_source.call(cell.card_name))
	cell.badge.visible = shown >= badge_min
	if cell.badge.visible:
		cell.badge_label.text = str(shown)


## [QoL] Re-read every VISIBLE cell's badge without touching the entries.
## The Inventory's badge says how many copies are already in the deck, so
## it has to follow the deck; walking the page (ten cells) rather than
## re-filtering the pool (800 cards) is what lets it.
func refresh_counts() -> void:
	if not count_source.is_valid():
		return
	for cell in _cells:
		if cell.visible:
			_bind_badge(cell, 0)


## [QoL] THE PILE MARKER, at the card's TOP-LEFT so it can never be read
## as the count disc at the bottom-right. Same furniture as that disc — a
## dark plate in the era's highlight ink — squared off rather than round,
## because it is a label and not a number.
func _tag() -> Control:
	var plate := Panel.new()
	var stone := StyleBoxFlat.new()
	stone.bg_color = Color(0, 0, 0, 0.78)
	stone.border_color = OriginalDialog.HIGHLIGHT
	stone.set_border_width_all(1)
	stone.set_corner_radius_all(2)
	plate.add_theme_stylebox_override("panel", stone)
	plate.size = Vector2(26, 16)
	# BOTTOM-LEFT, and the corner is chosen rather than convenient: the
	# count disc is bottom-RIGHT and so is the P/T, the mana stripes run
	# along the top, and [MiniCard] gives its name label `z_index = 2` —
	# so a plate in the top-left corner is drawn UNDER the card's own name
	# and is invisible. (It was, until a screenshot showed it: the plate
	# was there, `visible` was true and a test said so.) The explicit
	# z_index clears the name label as well, so no future MiniCard layer
	# can swallow it again.
	plate.position = Vector2(3, MiniCard.SIZE.y - 19)
	plate.z_index = 3
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.visible = false
	var word := Label.new()
	word.set_anchors_preset(Control.PRESET_FULL_RECT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.add_theme_font_size_override("font_size", 10)
	word.add_theme_color_override("font_color", OriginalDialog.HIGHLIGHT)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(word)
	return plate


func _dress_tag(cell: Cell) -> void:
	if cell == null or cell.tag == null:
		return
	cell.tag.visible = corner_tag != ""
	cell.tag_label.text = corner_tag


## s30's count overlay (`drawCountOverlay`, edit_deck.go:1075): a dark
## disc with the number on it — the manual's *"tiny number on the single
## representative card"*.
##
## BOTTOM LEFT, NOT BOTTOM RIGHT, and that is a deliberate `[QoL]`
## departure from s30. The bottom-right corner of a mini card is where
## [MiniCard] paints POWER/TOUGHNESS, so on a creature the two numbers
## landed on each other and neither could be read — reported from a real
## deck build, 2026-09-05: *"the multiples number collides with creature
## power/defense"*. s30 can put it right because its editor cards carry no
## P/T there; ours do, so the badge takes the free corner instead. Nothing
## else occupies bottom-left: the mana stripes run down the LEFT EDGE
## above it and the badge clears them at this size.
func _badge() -> Control:
	var badge := Panel.new()
	var disc := StyleBoxFlat.new()
	disc.bg_color = Color(0, 0, 0, 0.78)
	disc.border_color = OriginalDialog.HIGHLIGHT
	disc.set_border_width_all(1)
	disc.set_corner_radius_all(11)
	badge.add_theme_stylebox_override("panel", disc)
	badge.size = Vector2(22, 22)
	badge.position = Vector2(3.0, _cell.y - 25.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	var number := Label.new()
	number.set_anchors_preset(Control.PRESET_FULL_RECT)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 13)
	number.add_theme_color_override("font_color", OriginalDialog.HIGHLIGHT)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(number)
	return badge


## Cards act on RELEASE, not press: a press is also how a DRAG starts
## (Godot begins one when the pointer moves while held), so acting on the
## press would move the card twice — once by click and once by drop.
## The WHEEL is handled here too, because a Cell covers most of the
## surface and a wheel event it ignored would scroll nothing.
func _on_cell_input(event: InputEvent, cell: Cell) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_by(-1)
			accept_event()
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()      # so the arrow keys page the surface just clicked
		# [QoL] SHIFT sends the card to the other pile instead of moving it
		# in or out of this one — see [signal card_shifted].
		if event.shift_pressed:
			card_shifted.emit(cell.card_name)
		else:
			card_activated.emit(cell.card_name)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		card_bulk.emit(cell.card_name)
		accept_event()


## The wheel scrolls one step of cards on either surface.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_by(-1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
		return
	# The manual's own list-window keys: *"You can use the up and down
	# arrow keys and the scroll bar to move through the list."*
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_UP:
				scroll_by(-1)
			KEY_RIGHT, KEY_DOWN:
				scroll_by(1)
			KEY_PAGEUP:
				page_up()
			KEY_PAGEDOWN:
				page_down()
			KEY_HOME:
				home()
			KEY_END:
				end()
			_:
				return
		accept_event()


# ------------------------------------------------------ drag and drop --
# s30 registers a DropArea per surface and routes the payload by an id
# prefix (`deck:`); Godot's own drag protocol does the same job, so the
# payload carries the card name and the surface it left.

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("card_name") \
		and data.get("source", "") != source_name


func _drop_data(_at: Vector2, data: Variant) -> void:
	card_dropped.emit(String(data["card_name"]), String(data.get("source", "")))
