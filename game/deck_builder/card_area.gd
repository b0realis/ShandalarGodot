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
## The bottom bar counts whole STEPS (a column of cards), so the wheel,
## the bar and the keyboard always land on the same page; before the fix
## the bar counted single cards and drifted out of step with the wheel.
## The side bar counted rows the same way until 2026-11-10, and counts
## PIXELS now — see the next paragraph.
##
## [QoL] SMOOTH SCROLLING ON THE DECK AREA. The owner, 2026-11-10: *"Deck
## builder smooth scrolling of cards and purple arrows at the right
## indicating that the deck is larger than window !!!! (Smooth scrolling
## i mean you can scroll continuously and show half a card in bottom row)
## - now some players miss bottom rows in large decks in deck builder."*
## At 1280x800 the deck area holds four rows EXACTLY, so a stepped page
## always ended on a clean edge and a 70-card deck looked like a 24-card
## one. A side-barred surface keeps where it stands in PIXELS ([member
## _scroll_px]): the wheel glides half a row a notch ([constant
## WHEEL_ROWS]), the bar and its thumb move by the pixel, the keyboard
## scrolls just far enough to show the cursor's row whole, and a row cut
## by the bottom edge is the cue that there is more. The PAGING above is
## kept, one row deeper: the widgets are the rows the view touches — the
## visible rows plus one at most — laid at the fraction of a row the
## surface stands at, and a row that leaves the top is rotated round to
## the bottom and rebound exactly as a stepped page's was. The quilt
## travels with its cards ([method _quilt]) and the keyboard ring rides
## the fraction with the card it frames.
##
## THE BOTTOM-BARRED SURFACES STILL STEP, decided rather than left. The
## Inventory and the sideboard strip are one card tall, so there is no
## "bottom row" to miss; the Inventory's block is centred on its teal
## field with an arrow at each end, a tally in the corner and a count line
## that letters which cards are showing, and every one of those reads a
## whole-column offset. Gliding it sideways would cut a card at both ends
## under the arrows for no question the player was asking.
##
## [QoL] THE PURPLE ARROWS — the same request's other half: the Deck
## area wears an up arrow at the top of its right edge while cards are
## hidden above, a down arrow at the bottom while cards are hidden below,
## and neither while the whole deck fits. See [member more_arrows].
##
## THE GESTURES are the manual's: *"To move a card from the inventory into
## your deck, simply double-click on it or drag it there with the mouse,
## then release"* and *"If you decide to remove a card from the deck, just
## double-click on it or drag it from this area into the Inventory area."*
## A SINGLE click does the same thing — a modern affordance we owe the
## player, since a double-click-only surface feels broken today — and a
## right-click takes the whole stack of copies at once.
##
## [QoL] THE KEYBOARD CURSOR. The owner, 2026-09-08: *"In the deck
## builder, left and right arrow should select cards in the below strip
## and scroll to new cards left and right. Enter button should add a card
## to the deck."* Nothing in 1997 did this — the original was a mouse
## program, and s30's only keys are `A`/`D` on the card under the pointer
## (`edit_deck.go:459-465`) — so it is written once, here, for all three
## surfaces: the arrows walk a ring along the cards, the page turns to
## keep the ring in view, and Enter is a click on the ringed card
## ([signal card_activated] — into the deck from the Inventory, out of it
## from the Deck). See [method handle_key].

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

## [QoL] SMOOTH SCROLLING (the class header, 2026-11-10). One notch of the
## wheel on a side-barred surface glides HALF A ROW: a whole row a notch
## was a jump the eye could not follow, and the half row a notch leaves
## at the bottom edge is exactly the "there is more" the owner asked for.
## A precise touchpad's fraction of a notch ([member
## InputEventMouseButton.factor]) moves that fraction of it.
const WHEEL_ROWS := 0.5
## How fast a glide closes on where it is going, per second — an
## exponential approach that covers nine tenths of a notch in about an
## eighth of a second: quick enough to feel like the wheel, slow enough to
## be seen as motion rather than as a jump.
const GLIDE_RATE := 18.0
## [QoL] THE PURPLE ARROWS' COLUMN, down the Deck area's right edge — the
## Inventory's own arrow width, so the two kinds of arrow on the screen
## are one size. The side bar runs down the middle of it, between them.
const MORE_W := ARROW_W
## How tall each one is — under half a card, so the two never meet over
## the bar on any window the screen lays out ([method _more_h]).
const MORE_H := 48.0
## THE PURPLE. The 1997 Deck Builder carries no purple of its own (navy
## slate, olive, Dekbar1's teal, grey stone), so the arrows wear the era's
## own BUTTON STONE ([method OriginalDialog.button]) tinted to the purple
## the original game DID paint: the lavender sky over the castle on the
## victory screen (`win_game.png`, 160,128,216 at its heart). On the 1997
## stone the tint lands on that sky, and its dark INK arrow reads on it
## the way the original letters every light-faced button. Hover lifts it,
## a press sinks it, like every other stone on the screen.
const MORE_TINT := Color(0.84, 0.66, 1.18)
## The same purple as a flat face, for a game run with no skin imported
## ([method OriginalDialog._flat_button]'s case).
const MORE_FLAT := Color8(150, 116, 208)

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
## A quilted surface also lays its cards out differently — see
## [method _lead] — so setting this is a relayout, not just a redraw.
var slot_plaques := false:
	set(value):
		if slot_plaques == value:
			return
		slot_plaques = value
		if _grid != null:
			_relayout()
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
## [QoL] THE PURPLE ARROWS on a side-barred surface's right edge (the
## owner, 2026-11-10 — the class header): an UP arrow at the top while
## cards are hidden above the view, a DOWN arrow at the bottom while cards
## are hidden below it, neither while the whole list fits. They are a
## signpost first — the thin bar alone was not enough of one, and players
## missed the bottom rows of large decks — and buttons second: a click
## glides one row, a hold keeps going ([constant ARROW_DELAY], the bottom
## bar's own feel). Only meaningful with a side bar; a bottom-barred
## surface has [member scroll_arrows] instead.
var more_arrows := false:
	set(value):
		if more_arrows == value or not _vertical_bar:
			return
		more_arrows = value
		if value:
			_build_more_arrows()
		else:
			_free_more_arrows()
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
## Optional `func(CardData) -> String` used by the Inventory to choose a
## displayed reprint. It affects artwork only; entries remain name-based.
var art_set_for := Callable()
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

## [QoL] RARITY MARKS — the owner's ask, 2026-09-06: *"on press each mini
## card (center bottom) would have C symbol (common), U (uncommon,
## silver), R (rare, gold) and L (legendary, purple)"*. A letter on a
## plate at the card's bottom centre, the one corner nothing else uses:
## the count disc is bottom-LEFT, the P/T bottom-RIGHT. Off by default and
## a setting rather than a session flag, because a player who wants the
## marks wants them every time.
##
## `[QoL]` and marked as one: the 1997 Deck Builder could FILTER by rarity
## (`@RARITY` — `&Common &Uncommon &Rare`, `Menus.txt:397`) but lettered
## nothing on the card. It matters more here than in a shop-bought
## format — in Shandalar a rare is something you have to go and WIN.
var show_rarity := false:
	set(value):
		if show_rarity != value:
			show_rarity = value
			for cell in _cells:
				_dress_rarity(cell)

## [QoL] COST OVERLAYS — the owner's ask, 2026-09-06: *"for the visual
## type players lets also add mana cost icons overlay (as in the top right
## of the large card) centered in the center of minicard … on the touch
## of a button named 'cost'"*. The 1997 mini card is art, name bar and
## P/T — the cost lives on the big card at the left, one card at a time.
## With the switch down every card on every surface wears its cost on a
## plate at dead centre, the 1997 mana symbols at the size the Load
## dialog's pips use, so a curve can be read off a whole page at once. A
## land wears nothing. Off by default and a setting, like the rarity
## marks and for the same reason.
var show_cost := false:
	set(value):
		if show_cost != value:
			show_cost = value
			for cell in _cells:
				_dress_cost(cell)

## The four marks, keyed by the word [method rarity_key] answers: the
## letter, the plate, and the ink on it. Common is the printed symbol's
## own black; uncommon silver and rare gold are the set symbols' colours
## since Exodus, the year after this game; legendary is a SUPERTYPE, not
## a printed rarity, and the owner's purple is its own so the four read
## apart at a glance. [DeckBuilderScreen] draws the Stats window's rarity
## bars in these same colours, so the window and the cards agree.
const RARITY_MARKS := {
	"common": ["C", Color8(44, 44, 48), Color8(214, 214, 208)],
	"uncommon": ["U", Color8(198, 202, 210), Color8(28, 24, 26)],
	"rare": ["R", Color8(222, 178, 64), Color8(28, 24, 26)],
	"legendary": ["L", Color8(122, 70, 176), Color8(242, 234, 250)],
}
## The plate under the letter: as tall as the count disc's letters, on
## the disc's own baseline.
const RARITY_PLATE := Vector2(18, 18)
## The cost plate's symbol size and the room around the row of them.
const COST_ICON := 16
const COST_PAD := Vector2(8, 6)
## [QoL] THE CURSOR'S RING is the duel table's own "you may act on this"
## ink — [constant MiniCard.HIGHLIGHT_COLORS] at `OPTIONAL` — so the one
## colour means the one thing on both screens: this is the card the next
## key acts on. At the duel's CHOSEN width rather than its "may" width:
## the strip's cards wear busy frames of every colour and two pixels of
## yellow vanished against a blue one (checked by looking, 2026-09-08).
## It stands half a gap OUTSIDE the card, framing the face rather than
## covering its rim (the deck's quilt leads by exactly that much, [method
## _lead], so the first column's ring is never clipped), and it is drawn
## over every cell — `z_index` above the pile marker's 3 — while taking
## no click at all.
const RING_WIDTH := 3
const RING_OUT := GAP.x / 2.0
const RING_Z := 4
## The keys [method handle_key] answers — what [method owns_key] tests.
const KEYS: Array[Key] = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
	KEY_PAGEUP, KEY_PAGEDOWN, KEY_HOME, KEY_END, KEY_ENTER, KEY_KP_ENTER]

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
## kept from the last [method _rebuild]. The column count is what keeps
## [method _draw]'s carvings cycling on the grid the cards sit on; the
## inset is kept so a test can say where the block stands.
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
## The purple pair — see [member more_arrows].
var _up_arrow: Button = null
var _down_arrow: Button = null
## Which way a held arrow is scrolling: -1, 0 or +1. See [method _process].
var _held := 0
## Seconds until the held arrow steps again.
var _repeat_in := 0.0
## [QoL] WHERE THE KEYBOARD CURSOR STANDS — an index into the list
## ([method _visible_entries]), or -1 for none. The LIST, not the page:
## the page turns under it and the ring is simply hidden while the cursor
## is off the page ([method _place_cursor]).
var _cursor := -1
## The ring round the cursor's card: one node, moved, never rebuilt.
var _cursor_ring: Panel = null
## How many cells the last [method _rebuild] left showing.
var _shown := 0
## [QoL] SMOOTH SCROLLING: how far down a side-barred surface stands, in
## pixels — the one source of truth there; [member _offset] is derived
## from it (the first card of the first row the view touches). Unused on
## a bottom-barred surface, which still steps.
var _scroll_px := 0.0
## Where a glide (the wheel, a purple arrow) is heading, while [member
## _gliding] is set. See [method _process].
var _glide_to := 0.0
var _gliding := false
## The first card of the top row as the player last LEFT it by scrolling —
## what a resize that changes the column count keeps on the top row
## ([method _keep_top_card]).
var _anchor := 0
## Set while this surface writes its own bar, so the bar's own
## `value_changed` (a range clamping its value as its maximum moves) does
## not scroll the surface from inside its own rebuild.
var _writing_bar := false
## WHERE THE POINTER STANDS over the cards, in [member _grid]'s
## coordinates, from the last motion or wheel event this surface or one
## of its cards received; [member _pointer_known] is cleared when the
## pointer leaves. A stepped page hands the hover to whatever card lands
## in the hovered SLOT; a smooth one moves its cards by the pixel, so the
## card under a still pointer is found by WHERE the pointer is ([method
## _settle_hover]).
var _pointer := Vector2.ZERO
var _pointer_known := false


func _init(vertical_bar := true) -> void:
	_vertical_bar = vertical_bar
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	_cell = MiniCard.SIZE
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_grid)
	_cursor_ring = _make_cursor_ring()
	_grid.add_child(_cursor_ring)
	# The ring is a promise about the NEXT KEY, and a surface without the
	# keyboard can make none — so it shows only while this one has it.
	focus_entered.connect(_place_cursor)
	focus_exited.connect(_place_cursor)
	_bar = VScrollBar.new() if vertical_bar else HScrollBar.new()
	# A side bar counts pixels ([method smooth]), so its value must not be
	# rounded to whole ones on the way through.
	if vertical_bar:
		_bar.step = 0.0
	_bar.value_changed.connect(_on_bar_moved)
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
	elif what == NOTIFICATION_MOUSE_EXIT:
		# The pointer has left the surface and every card on it: no card is
		# under it, whatever slides past next ([method _settle_hover]).
		_pointer_known = false


func _relayout() -> void:
	var pad := arrow_pad()
	var inner := _inner_size()
	# The cards start INSIDE the left arrow, never under it.
	_grid.position = Vector2(pad, 0.0)
	_grid.size = inner
	if _vertical_bar:
		# The bar runs down the middle of the right-hand column, and with
		# the purple arrows it runs BETWEEN them — they stand at its two
		# ends, where a scroll bar's own arrows would.
		var side := side_width()
		var reach := _more_h() + 2.0 if more_arrows else 0.0
		_bar.position = Vector2(size.x - side + (side - BAR_THICKNESS) / 2.0, reach)
		_bar.size = Vector2(BAR_THICKNESS, maxf(0.0, size.y - 2.0 * reach))
		if _up_arrow != null:
			var tall := _more_h()
			_up_arrow.position = Vector2(maxf(0.0, size.x - MORE_W), 0.0)
			_up_arrow.size = Vector2(MORE_W, tall)
			_down_arrow.position = Vector2(maxf(0.0, size.x - MORE_W), maxf(0.0, size.y - tall))
			_down_arrow.size = Vector2(MORE_W, tall)
		_keep_top_card()
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
		var edge := (side_width() if _vertical_bar else 0.0) + pad
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


## WHERE THE BLOCK OF CARDS STARTS, from the area's top-left. On a quilted
## surface the first carved frame stands ON the area's edge and the card
## sits half a gap inside it, exactly as every other card sits inside its
## own frame — so the quilt reaches the edge of the area and the area's
## edge is the quilt's. A plain surface starts its block at the edge and
## [method _rebuild] centres it.
##
## The owner's photo of a wide window, 2026-09-06: *"backgrounds still do
## not align from the left side"*. The deck's block of columns was CENTRED
## (a leftover strip split between both ends, which is right for the
## Inventory's teal field) and the quilt was laid from where the block
## started, so on a 2560-wide screen thirty pixels of bare weave stood
## between the sideboard's edge and the first carving. The quilt is laid
## edge to edge now, whatever the width, and the leftover is on the right
## under the last, partial column of carvings — which is what "laid edge
## to edge across the whole area" meant in the first place.
func _lead() -> Vector2:
	return GAP / 2.0 if slot_plaques else Vector2.ZERO


## The area minus the strip the scroll bar occupies, minus the two arrow
## columns when this surface has them, and minus the quilt's lead.
func _inner_size() -> Vector2:
	var pad := 2.0 * arrow_pad()
	var lead := _lead()
	if _vertical_bar:
		return Vector2(maxf(size.x - side_width() - 2.0 - pad - lead.x, 0.0),
			maxf(size.y - lead.y, 0.0))
	return Vector2(maxf(size.x - pad - lead.x, 0.0),
		maxf(size.y - BAR_THICKNESS - 2.0 - lead.y, 0.0))


## What a side-barred surface gives up down its right edge: the bar's own
## width, or the purple arrows' column when it has them ([constant
## MORE_W]) — reserved whether or not they are showing, so the deck's
## columns never jump as the deck grows past one screen.
func side_width() -> float:
	return MORE_W if more_arrows else BAR_THICKNESS


## How tall a purple arrow stands: [constant MORE_H], or a third of a very
## short area, so the pair and the bar between them always fit.
func _more_h() -> float:
	return minf(MORE_H, floorf(size.y / 3.0))


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
## sliding window. On a [method smooth] surface it is the first card of
## the first row the view touches, however little of that row shows.
func offset() -> int:
	return _offset


## The largest [method offset] that still fills the page — the last card
## always sits on the last page, never one row below it.
func max_offset() -> int:
	if smooth():
		return int(floorf(max_scroll_px() / row_pitch())) * columns()
	var step := scroll_step()
	var total: int = int(ceil(float(_visible_entries().size()) / float(step)))
	var visible: int = int(ceil(float(page_size()) / float(step)))
	return maxi(0, total - visible) * step


## Scroll so card [param card_index] is on the page — at the top of it, on
## a [method smooth] surface, its row's carving on the area's top edge.
func scroll_to(card_index: int) -> void:
	if smooth():
		scroll_px_to(float(maxi(0, card_index) / columns()) * row_pitch())
		return
	var step := scroll_step()
	var wanted: int = clampi(card_index - card_index % step, 0, max_offset())
	if wanted == _offset:
		return
	var moved := wanted - _offset
	_offset = wanted
	_rebuild(moved)
	scrolled.emit()


## [param steps] rows (or columns) on. A [method smooth] surface keeps the
## fraction of a row it stands at.
func scroll_by(steps: int) -> void:
	if smooth():
		scroll_px_to(_scroll_px + steps * row_pitch())
		return
	scroll_to(_offset + steps * scroll_step())


# ------------------------------------------- [QoL] smooth scrolling --
# The owner, 2026-11-10 — see the class header. Everything here is the
# side-barred surface's; [method smooth] says which surface that is.

## Does this surface scroll by the pixel? The side-barred one (the Deck
## area) does; the bottom-barred ones step whole columns — the class
## header says why.
func smooth() -> bool:
	return _vertical_bar


## One row of cards and its gap: the distance the quilt repeats down.
func row_pitch() -> float:
	return _cell.y + GAP.y


## How far down the surface stands, in pixels.
func scroll_px() -> float:
	return _scroll_px


## How tall the whole list stands laid out: every row and the gaps
## between, and the quilt's half gap above the first card and below the
## last — so the last carving's bottom edge meets the area's bottom edge.
func content_height() -> float:
	var count := _visible_entries().size()
	if count == 0:
		return 0.0
	var rows_total: int = int(ceil(float(count) / float(columns())))
	return rows_total * row_pitch() - GAP.y + 2.0 * _lead().y


## The furthest down the surface can stand: the last card's bottom on the
## bottom edge (half a gap inside it, on a quilt), never a pixel past.
func max_scroll_px() -> float:
	return maxf(0.0, content_height() - size.y)


## Stand the surface [param px] pixels down, at once — the bar, the keys,
## a resize. Stops any glide on the way.
func scroll_px_to(px: float) -> void:
	_gliding = false
	_apply_scroll_px(px)
	_sync_process()


## Finish a glide where it was going, now. Public: it is the seam the
## tests settle the wheel through, since a headless run has frames only
## when it asks for them.
func settle_scroll() -> void:
	if _gliding:
		_gliding = false
		_apply_scroll_px(_glide_to)
	_sync_process()


## Move the surface to [param px] (clamped) and lay the cards there. True
## when it moved. Crossing into a new first row ROTATES the page and
## rebinds the row that came in ([method _rebuild], as a stepped scroll
## does); a move inside the same row only slides the widgets ([method
## _slide]) — no card is redrawn for a pixel.
func _apply_scroll_px(px: float) -> bool:
	var target := clampf(px, 0.0, max_scroll_px())
	if is_equal_approx(target, _scroll_px):
		return false
	_scroll_px = target
	var wanted := _first_row() * columns()
	_anchor = wanted
	if wanted != _offset:
		var moved := wanted - _offset
		_offset = wanted
		_rebuild(moved)
	else:
		_slide()
	scrolled.emit()
	return true


## The first row the view touches.
func _first_row() -> int:
	return int(floorf(_scroll_px / row_pitch()))


## How far into that row the view starts, in pixels: the distance every
## card and carving is drawn ABOVE its stepped place.
func _frac() -> float:
	return fposmod(_scroll_px, row_pitch()) if smooth() else 0.0


## Start gliding [param delta] pixels on from wherever the last glide was
## heading, so a quick spin of the wheel adds up instead of restarting.
func _glide_by(delta: float) -> void:
	var from := _glide_to if _gliding else _scroll_px
	var target := clampf(from + delta, 0.0, max_scroll_px())
	if not _gliding and is_equal_approx(target, _scroll_px):
		return
	_glide_to = target
	_gliding = true
	_sync_process()


## Glide to the next row boundary [param facing] (-1 up, +1 down) — what a
## purple arrow does, so a click always leaves a row's carving on the top
## edge. False when there is no further to go.
func _glide_row(facing: int) -> bool:
	var pitch := row_pitch()
	var from := _glide_to if _gliding else _scroll_px
	var row := from / pitch
	var target: float
	if facing > 0:
		target = (floorf(row + 0.001) + 1.0) * pitch
	else:
		target = (ceilf(row - 0.001) - 1.0) * pitch
	target = clampf(target, 0.0, max_scroll_px())
	if is_equal_approx(target, from):
		return false
	_glide_to = target
	_gliding = true
	_sync_process()
	return true


## A RESIZE THAT CHANGES THE COLUMN COUNT REFLOWS EVERY ROW, so the same
## pixel offset would name a different card. The card that stood at the
## top-left when the player last scrolled ([member _anchor]) stays on the
## top row — the stepped offset's own promise — at the same fraction of a
## row. It is the card from the last SCROLL, not from the last layout, so
## a window dragged through a dozen widths does not walk the deck away
## one floored row at a time.
func _keep_top_card() -> void:
	if not smooth():
		return
	var cols := columns()
	if cols == _columns:
		return
	_scroll_px = float(_anchor / cols) * row_pitch() + _frac()


## Processing runs only while something needs a frame: a glide, or a held
## arrow ([method _process]).
func _sync_process() -> void:
	set_process(_gliding or _held != 0)


## The bar was moved by the player — dragged, or clicked in its track.
## A side bar counts pixels; a bottom bar counts steps.
func _on_bar_moved(value: float) -> void:
	if _writing_bar:
		return
	if smooth():
		scroll_px_to(value)
	else:
		scroll_to(int(value) * scroll_step())


## The last card on the bottom edge. On a [method smooth] surface that is
## [method max_scroll_px] itself — the row-floored [method max_offset]
## would stop short of it by the fraction of a row.
func scroll_to_end() -> void:
	if smooth():
		scroll_px_to(max_scroll_px())
		return
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
	_sync_process()


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
## has no pointer to hold it with. The same for both kinds of arrow: a
## step is a column on the bottom bar, a row's glide on a [method smooth]
## surface.
func press_arrow(facing: int) -> void:
	_held = facing
	_repeat_in = ARROW_DELAY
	_arrow_step(facing)
	_sync_process()


## Let it up again. A glide already under way finishes its row.
func release_arrow() -> void:
	_held = 0
	_sync_process()


## One step of a held or clicked arrow. False at the end of the list.
func _arrow_step(facing: int) -> bool:
	if smooth():
		return _glide_row(facing)
	var before := _offset
	scroll_by(facing)
	return _offset != before


## The two things that want frames: a glide closing on where it is going,
## and a held arrow's repeat. Neither running, nothing ticks.
func _process(delta: float) -> void:
	if _gliding and delta > 0.0:
		var gap := _glide_to - _scroll_px
		var next := _glide_to if absf(gap) <= 0.5 \
			else _scroll_px + gap * (1.0 - exp(-GLIDE_RATE * delta))
		# Arrived, or held back by the end of a list that shrank under it.
		if not _apply_scroll_px(next) or next == _glide_to:
			_gliding = false
	if _held != 0:
		_repeat_in -= delta
		if _repeat_in <= 0.0:
			_repeat_in = ARROW_REPEAT
			if not _arrow_step(_held):
				# The end of the list. Stop the repeat rather than spinning
				# on it; the button is about to be disabled (or, purple,
				# hidden) under the finger anyway.
				_held = 0
	_sync_process()


## Grey out the arrow that has nowhere left to go — and both of them when
## the whole list already fits on one page. The purple pair HIDE instead:
## each one is a signpost saying "more this way", and a signpost to
## nothing is a lie.
func _refresh_arrows() -> void:
	if _up_arrow != null:
		_up_arrow.visible = _scroll_px > 0.5
		_down_arrow.visible = _scroll_px < max_scroll_px() - 0.5
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
	## -1 points left (or up), +1 points right (or down).
	var facing := -1
	## Points up or down instead — the purple pair ([member
	## CardArea.more_arrows]).
	var vertical := false
	## How big the triangle is, against the button's narrower side.
	var reach := 0.28

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var half := minf(w, h) * reach
		var mid := Vector2(w * 0.5, h * 0.5)
		var points: PackedVector2Array
		if vertical:
			points = PackedVector2Array([Vector2(mid.x, mid.y + facing * half * 0.9),
				Vector2(mid.x - half, mid.y - facing * half * 0.7),
				Vector2(mid.x + half, mid.y - facing * half * 0.7)])
		else:
			points = PackedVector2Array([Vector2(mid.x + facing * half * 0.9, mid.y),
				Vector2(mid.x - facing * half * 0.7, mid.y - half),
				Vector2(mid.x - facing * half * 0.7, mid.y + half)])
		# The button face is the era's pale speckle, so the arrow is the
		# era's DARK INK on it — the same voice the original letters its
		# own light-faced buttons in ([method OriginalDialog.ink_label]).
		draw_colored_polygon(points, OriginalDialog.INK)


# ------------------------------------------ [QoL] the purple arrows --
# The owner, 2026-11-10: *"purple arrows at the right indicating that the
# deck is larger than window"* — see [member more_arrows].

func _build_more_arrows() -> void:
	if _up_arrow != null:
		return
	_up_arrow = _make_more_arrow(-1)
	_down_arrow = _make_more_arrow(1)
	add_child(_up_arrow)
	add_child(_down_arrow)


func _free_more_arrows() -> void:
	for button in [_up_arrow, _down_arrow]:
		if button != null:
			button.queue_free()
	_up_arrow = null
	_down_arrow = null
	_held = 0
	_sync_process()


## One purple arrow: the era's stone in the victory sky's purple
## ([constant MORE_TINT]) with an ink triangle on it, pointing up
## ([param facing] -1) or down (+1). FOCUS_NONE for the reason [method
## _make_arrow] gives. Hidden until [method _refresh_arrows] finds cards
## its way.
func _make_more_arrow(facing: int) -> Button:
	var button := OriginalDialog.button("", Vector2(MORE_W, MORE_W))
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = ("More cards above — click to scroll up, hold to keep going"
		if facing < 0 else "More cards below — click to scroll down, hold to keep going")
	_dress_purple(button)
	var glyph := Arrow.new()
	glyph.facing = facing
	glyph.vertical = true
	# Bolder than the bottom bar's: this one is a signpost first.
	glyph.reach = 0.36
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(glyph)
	button.button_down.connect(press_arrow.bind(facing))
	button.button_up.connect(release_arrow)
	# The arrows stand on the edge the bar used to have to itself, and the
	# bar scrolls under the wheel; so do they.
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and _wheel(event as InputEventMouseButton):
			button.accept_event())
	button.visible = false
	return button


## Tint every state of a stone button to the arrows' purple: the 1997
## stone itself where the skin is worn, a flat face where it is not.
## Hover lifts the tint and a press sinks it, as on every other stone.
static func _dress_purple(button: Button) -> void:
	var lift := {"normal": 1.0, "hover": 1.14, "pressed": 0.82,
		"hover_pressed": 0.82, "disabled": 0.7}
	for state: String in lift:
		var box := button.get_theme_stylebox(state)
		if box == null:
			continue
		box = box.duplicate()
		var by: float = lift[state]
		if box is StyleBoxTexture:
			(box as StyleBoxTexture).modulate_color = Color(MORE_TINT.r * by,
				MORE_TINT.g * by, MORE_TINT.b * by)
		elif box is StyleBoxFlat:
			(box as StyleBoxFlat).bg_color = Color(MORE_FLAT.r * by,
				MORE_FLAT.g * by, MORE_FLAT.b * by)
		button.add_theme_stylebox_override(state, box)


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
	var held := cursor_entry()
	_entries = entries
	_expanded.clear()
	# THE CURSOR FOLLOWS ITS CARD INTO THE NEW LIST. The Deck is relisted
	# on every add and remove ([method DeckBuilderScreen.refresh]), and a
	# cursor that went back to nothing on each Enter would make Enter a
	# one-shot. A card no longer listed — its last copy placed, or
	# filtered away — takes the cursor with it; the next arrow starts
	# again from the page's first card.
	_cursor = -1
	if held != null:
		var shown := _visible_entries()
		for i in shown.size():
			if shown[i][0].card_name == held.card_name:
				_cursor = i
				break
	_rebuild()


func entry_count() -> int:
	return _visible_entries().size()


## Copies on the surface, every entry's count together — what a sealed
## pool's Inventory counts, where a card's count is copies still in hand.
func copies_shown() -> int:
	var n := 0
	for entry in _visible_entries():
		n += int(entry[1])
	return n


## The first card on the surface in display order, or null when it shows
## none — what `Enter` in the Inventory's type-ahead adds.
func first_entry() -> CardData:
	var shown := _visible_entries()
	return shown[0][0] if not shown.is_empty() else null


## [QoL] Where the keyboard cursor stands in the list, or -1.
func cursor_index() -> int:
	return _cursor


## [QoL] The card under the keyboard cursor, or null.
func cursor_entry() -> CardData:
	var shown := _visible_entries()
	return shown[_cursor][0] if _cursor >= 0 and _cursor < shown.size() else null


## [QoL] Stand the keyboard cursor on card [param index] of the list
## (-1 clears it), turning the page so it is in view, and ring it.
## [param reveal] false leaves the page where it is — a CLICK's cursor: the
## player clicked the card they could see, and a half-shown card that
## scrolled itself whole would move under the pointer mid-click.
func set_cursor(index: int, reveal := true) -> void:
	_cursor = clampi(index, -1, _visible_entries().size() - 1)
	if _cursor >= 0 and reveal:
		_reveal(_cursor)
	_place_cursor()


## Is card [param index] on the page now showing? On a [method smooth]
## surface, any card of a row the view touches is.
func _on_page(index: int) -> bool:
	return index >= _offset and index < _offset + _shown


## [QoL] THE FIRST CARD THE KEYS ACT ON when the cursor is not on the page
## — *"the keys act on what is in view"* ([method handle_key]). On a
## stepped page that is its first card. On a [method smooth] surface it is
## the first card of the first row shown WHOLE: a row cut to a sliver at
## the top is not what the player is looking at, and landing on it would
## scroll the view back up to show it.
func _first_in_view() -> int:
	if not smooth():
		return _offset
	var skip: int = maxi(0, int(ceilf((_frac() - _lead().y) / row_pitch())))
	var first := _offset + skip * columns()
	var whole := _lead().y + skip * row_pitch() - _frac() + _cell.y <= size.y
	return first if whole and first < _visible_entries().size() else _offset


## Turn the page the shortest way that puts card [param index] on it —
## nothing when it already is. A [method smooth] surface scrolls just far
## enough to show the card's row WHOLE, carving and all, at whichever edge
## it was cut by.
func _reveal(index: int) -> void:
	if smooth():
		var top := float(index / columns()) * row_pitch()
		var bottom := top + _cell.y + 2.0 * _lead().y
		if top < _scroll_px:
			scroll_px_to(top)
		elif bottom > _scroll_px + size.y:
			scroll_px_to(bottom - size.y)
		return
	if index < _offset:
		scroll_to(index)
	elif index >= _offset + page_size():
		# The lowest step multiple that still shows it: `scroll_to` floors
		# to a step, and this is one step less than a page short of it.
		scroll_to(index - page_size() + scroll_step())


## Move the cursor AND show its card in the Showcase — the keyboard's
## way of *"whatever card the mouse cursor is hovering over"*. After the
## page has turned, so the Showcase ends on the cursor's card and not on
## whatever slid under the pointer ([method _settle_hover]).
func _step_to(index: int) -> void:
	set_cursor(index)
	var data := cursor_entry()
	if data != null:
		card_hovered.emit(data)


## [QoL] Is [param event] a key the surfaces answer — one of
## [constant KEYS], without Ctrl, Alt or Meta on it (Shift is Shift+Enter's)?
static func owns_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return key.keycode in KEYS and not key.ctrl_pressed \
		and not key.alt_pressed and not key.meta_pressed


## [QoL] THE KEYS, answered while this surface has the keyboard — and
## when the screen hands them over because nothing else reads them
## ([method DeckBuilderScreen._input]). True when the key was one of
## [constant KEYS]; false hands it back.
##
## THE ARROWS move the cursor by one card across the flow and by one
## STEP along the bar — a row on the Deck, a column on the Inventory — so
## on the one-row Inventory all four move one card and Left/Right are
## the pair that reads naturally. An arrow with no cursor on the page
## (none yet, or one the type-ahead has scrolled away from) stands it on
## the page's first card and moves nothing: the keys act on what is in
## view ([method _first_in_view] — the first WHOLE row, on a smooth
## surface). PageUp/PageDown turn the page and carry the cursor with it, in
## its slot; Home and End go to the ends of the list. Without a cursor
## the paging keys scroll as they always did — the manual's list-window
## words hold: *"You can use the up and down arrow keys and the scroll
## bar to move through the list."*
##
## ENTER is a click on the ringed card, Shift+Enter a Shift-click
## ([signal card_shifted]); with no cursor on the page it takes the
## page's first card, the type-ahead's own rule (*"what you see first is
## what you get"*). ONCE PER PRESS: a held arrow may run along the row,
## a held Enter must not pour copies in.
func handle_key(event: InputEventKey) -> bool:
	if not event.pressed:
		return false
	var count := _visible_entries().size()
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if event.is_echo() or count == 0:
				return true
			if not _on_page(_cursor):
				_step_to(_first_in_view())
			var data := cursor_entry()
			if data == null:
				return true
			if event.shift_pressed:
				card_shifted.emit(data.card_name)
			else:
				card_activated.emit(data.card_name)
			return true
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if count == 0:
				return true
			if not _on_page(_cursor):
				_step_to(_first_in_view())
				return true
			var along := scroll_step()
			var delta := 0
			match event.keycode:
				KEY_LEFT:
					delta = -1 if _vertical_bar else -along
				KEY_RIGHT:
					delta = 1 if _vertical_bar else along
				KEY_UP:
					delta = -along if _vertical_bar else -1
				KEY_DOWN:
					delta = along if _vertical_bar else 1
			_step_to(clampi(_cursor + delta, 0, count - 1))
			return true
		KEY_PAGEUP, KEY_PAGEDOWN:
			var was_on_page := _on_page(_cursor)
			var before := _offset
			if event.keycode == KEY_PAGEUP:
				page_up()
			else:
				page_down()
			if was_on_page:
				_step_to(clampi(_cursor + _offset - before, 0, count - 1))
			elif _cursor >= 0 and count > 0:
				_step_to(_first_in_view())
			return true
		KEY_HOME:
			if _cursor >= 0 and count > 0:
				_step_to(0)
			else:
				home()
			return true
		KEY_END:
			if _cursor >= 0 and count > 0:
				_step_to(count - 1)
			else:
				end()
			return true
	return false


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
	var cols := columns()
	_columns = cols
	if smooth():
		# The pixel position is the truth on a smooth surface; the offset
		# is read off it, so the two cannot drift apart either.
		_scroll_px = clampf(_scroll_px, 0.0, max_scroll_px())
		if _glide_to > max_scroll_px():
			_glide_to = max_scroll_px()
		_offset = _first_row() * cols
	else:
		var step := scroll_step()
		_offset = clampi(_offset - _offset % step, 0, max_offset())
	_write_bar()
	_refresh_arrows()
	# Centre the fixed block of columns in the area: the column count never
	# changes with the card count, so this is a stable margin, not a
	# shifting one, and it keeps the Inventory's leftover strip off one
	# end. A QUILTED surface does not centre — its block starts inside the
	# first carved frame and the leftover stays on the right, under the
	# carvings ([method _lead]).
	var lead := _lead()
	_inset = lead.x if slot_plaques \
		else maxf(0.0, (_inner_size().x - (cols * (_cell.x + GAP.x) - GAP.x)) / 2.0)
	queue_redraw()
	_lay_slots(_slots_wanted(entries.size()), 0)
	_settle_hover(_shown)
	_place_cursor()


## THE SAME PAGE, SLID A FEW PIXELS — a [method smooth] move that stays
## inside the first row the view touches. Every widget moves with the
## fraction; only the slots the move has just uncovered at the bottom are
## bound, and none already showing is touched — a glide redraws no card.
func _slide() -> void:
	_write_bar()
	_refresh_arrows()
	queue_redraw()
	_lay_slots(_slots_wanted(_visible_entries().size()), _shown)
	_settle_hover(_shown)
	_place_cursor()


## Write the bar from the surface. A bottom bar counts STEPS, and
## `_offset` is always a whole number of them, so bar and wheel can never
## drift apart; a side bar counts the PIXELS the surface stands at, its
## page the view's own height, so dragging its thumb moves the cards by
## the pixel.
func _write_bar() -> void:
	_writing_bar = true
	if smooth():
		var content := content_height()
		_bar.max_value = maxf(content, size.y)
		_bar.page = size.y
		_bar.set_value_no_signal(_scroll_px)
		_bar.visible = content > size.y
	else:
		var step := scroll_step()
		var total_steps: int = int(ceil(float(_visible_entries().size()) / float(step)))
		var visible_steps: int = int(ceil(float(page_size()) / float(step)))
		_bar.max_value = maxf(total_steps, visible_steps)
		_bar.page = visible_steps
		_bar.set_value_no_signal(float(_offset) / float(step))
		_bar.visible = total_steps > visible_steps
	_writing_bar = false


## How many slots the page shows: a page of [method page_size], or on a
## [method smooth] surface every card of every row the view touches —
## the rows in view, plus the one a fraction has pulled up from below.
func _slots_wanted(count: int) -> int:
	var room := page_size()
	if smooth():
		var rows_in_view: int = maxi(1, int(ceilf((size.y + _frac()) / row_pitch())))
		room = rows_in_view * columns()
	return mini(room, maxi(0, count - _offset))


## Show slots `0 .. shown-1` at their places and hide the rest, binding
## the slots from [param bind_from] on — all of them for a rebuild, only
## the newly uncovered ones for a slide ([method _slide]).
func _lay_slots(shown: int, bind_from: int) -> void:
	var entries := _visible_entries()
	for i in maxi(shown, _cells.size()):
		if i >= shown:
			_cells[i].visible = false
			continue
		if i >= bind_from or i >= _cells.size():
			var entry: Array = entries[_offset + i]
			var cell: Cell
			if i < _cells.size():
				cell = _cells[i]
			else:
				cell = _make_cell(entry[0])
				_cells.append(cell)
				_grid.add_child(cell)
			_bind_cell(cell, entry[0], int(entry[1]))
		_cells[i].position = _slot_position(i)
		_cells[i].visible = true
	_shown = shown


## Where slot [param i] of the page stands in [member _grid]. Row-major
## under a side bar, COLUMN-major under a bottom bar — and on a [method
## smooth] surface drawn the fraction of a row the surface stands at above
## its stepped place.
func _slot_position(i: int) -> Vector2:
	var cols := _columns
	var row_count := rows()
	var col := (i % cols) if _vertical_bar else (i / row_count)
	var row := (i / cols) if _vertical_bar else (i % row_count)
	return Vector2(_inset + col * (_cell.x + GAP.x),
		_lead().y + row * (_cell.y + GAP.y) - _frac())


## HAND THE HOVER TO WHOEVER IS IN THE SLOT NOW. The pointer has not moved,
## so Godot will send no `mouse_entered`; the widgets moved instead. The
## Showcase is only told when the card in the slot really changed, so a
## card click (which rebinds the whole page) says nothing.
##
## A [method smooth] surface asks WHERE the pointer is instead ([member
## _pointer]): its cards move by the pixel, so the card under a still
## pointer after half a notch is not the one in the slot it was over —
## and the pointer may now be over a gap, or a gap may have slid out from
## under it onto a card.
func _settle_hover(shown: int) -> void:
	if smooth() and _pointer_known:
		_hovered_slot = _slot_under(_pointer, shown)
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


## Which showing slot's card [param at] (in [member _grid]'s coordinates)
## is over, or -1 for a gap.
func _slot_under(at: Vector2, shown: int) -> int:
	for i in mini(shown, _cells.size()):
		if Rect2(_cells[i].position, _cell).has_point(at):
			return i
	return -1


## Note where the pointer is, from an event at [param at] in [member
## _grid]'s coordinates — see [member _pointer].
func _note_pointer(at: Vector2) -> void:
	_pointer = at
	_pointer_known = true


## The ring itself — see [constant RING_WIDTH].
func _make_cursor_ring() -> Panel:
	var ring := Panel.new()
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = MiniCard.HIGHLIGHT_COLORS[MiniCard.Highlight.OPTIONAL]
	box.set_border_width_all(RING_WIDTH)
	box.set_corner_radius_all(3)
	ring.add_theme_stylebox_override("panel", box)
	ring.size = _cell + Vector2(RING_OUT, RING_OUT) * 2.0
	ring.z_index = RING_Z
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	return ring


## Put the ring on the cursor's card, or hide it: no cursor, the cursor
## off the page, or the keyboard elsewhere.
func _place_cursor() -> void:
	if _cursor_ring == null:
		return
	var slot := _cursor - _offset
	if _cursor < 0 or not _on_page(_cursor) or slot >= _cells.size() \
			or not has_focus():
		_cursor_ring.visible = false
		return
	_cursor_ring.position = _cells[slot].position - Vector2(RING_OUT, RING_OUT)
	_cursor_ring.visible = true


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
## The carvings are laid on the CARD PITCH (cell + gap) from the area's
## own top-left corner, so they meet edge to edge with no seam and each
## one frames the card that sits half a gap inside it ([method _lead]) —
## the reference's quilt exactly. They cover the WHOLE area, not just the
## occupied slots and not just the block of columns: in 1997 an empty deck
## is a full grid of watermarks waiting to be filled, and on a wide window
## the strip past the last column is more quilt, cut by the area's edge,
## rather than bare weave.
func _draw() -> void:
	if not slot_plaques:
		return
	var sheet := GameSkin.texture("deck_slot_plaques")
	if sheet == null:
		return
	for laid: Array in _quilt():
		var art := _plaque(int(laid[1]))
		if art != null:
			draw_texture_rect(art, laid[0], false)


## Where every carving of the quilt goes and which one it is: `[[Rect2,
## index], ...]`, in this area's coordinates — what [method _draw] lays,
## kept apart so a test can read the quilt without a renderer.
##
## [QoL] THE QUILT SCROLLS WITH ITS CARDS (2026-11-10). On a [method
## smooth] surface it is drawn the same fraction of a row up as the cards
## are, and the cycle `index = (row * columns + col) % 5` counts the row
## from the TOP OF THE LIST rather than the top of the view — so each card
## keeps its own carving under it as it glides, instead of the carvings
## standing still and the cards sliding over them.
func _quilt() -> Array:
	var out: Array = []
	var pitch := _cell + GAP
	var pad := arrow_pad()
	var frac := _frac()
	var first := _first_row() if smooth() else 0
	var down: int = int(ceil((size.y + frac) / pitch.y))
	var across: int = int(ceil((size.x - 2.0 * pad) / pitch.x))
	for row in down:
		for col in across:
			var index: int = ((first + row) * _columns + col) % PLAQUE_COLUMNS
			out.append([Rect2(Vector2(pad + col * pitch.x, row * pitch.y - frac), pitch),
				index])
	return out


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
		if sheet.get_height() < 2 * PLAQUE.y:
			return null
		for i in PLAQUE_COLUMNS:
			if sheet.get_width() < (i + 1) * PLAQUE.x:
				break
			# Drawn size for the bounds, the sheet's own pixels for the cut
			# (GameSkin, THE 2x PICTURES).
			var rect := Rect2i(i * PLAQUE.x, PLAQUE.y, PLAQUE.x, PLAQUE.y)
			_plaque_cache[i] = GameSkin.texture_of(GameSkin.cut(sheet, rect), rect.size)
	return _plaque_cache[index] if index < _plaque_cache.size() else null


## ONE CARD on a surface: a MiniCard face at this area's card scale inside
## a fixed-size holder that carries the drag payload. A holder rather than
## a Button because Godot's drag gesture starts from `_get_drag_data`,
## which a Button's own press handling would swallow.
class Cell extends Control:
	var data: CardData = null
	var card_name := ""
	var printing_set := ""
	var source := ""
	## The card's face. EXACTLY ONE of these two is set: a cell holding a
	## real card has a [MiniCard], a cell holding a PROXY has a
	## [ProxyFace], and they are separate fields rather than one
	## `Control` because GDScript's static typing cannot reach
	## `.hovered` or `.instance` through a `Control`. [method set_hovered]
	## and [method CardArea._bind_cell] are the two places that care.
	var face: MiniCard = null
	var proxy: ProxyFace = null
	## The card [member face] was built for and has not been bound to
	## since — a [MiniCard] draws itself as it is built, so
	## [method CardArea._bind_cell] need not draw it again (h5-10 round 2).
	var fresh_for: CardData = null
	var badge: Control = null
	var badge_label: Label = null
	## [QoL] The pile marker — see [member CardArea.corner_tag].
	var tag: Control = null
	var tag_label: Label = null
	## [QoL] The rarity mark — see [member CardArea.show_rarity].
	var rarity: Control = null
	var rarity_label: Label = null
	## [QoL] The cost plate — see [member CardArea.show_cost].
	var cost: Control = null

	## [QoL] Owner's playtest #8, 2026-09-13. The default tooltip put
	## Animate Dead in a 1899px-wide popup inside a 1280px window. Give
	## Godot a wrapped, bounded label BEFORE it positions the popup; the
	## engine still owns its delay, theme, edge clamping and dismissal.
	## The shaping is [method UiChrome.shape_tooltip] since 2026-09-18,
	## when every stock tooltip in the game learned the same manners.
	func _make_custom_tooltip(for_text: String) -> Object:
		var label := Label.new()
		label.theme_type_variation = &"TooltipLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = for_text
		var font := get_theme_font("font", "TooltipLabel")
		var font_size := get_theme_font_size("font_size", "TooltipLabel")
		var spacing := get_theme_constant("line_spacing", "TooltipLabel")
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("line_spacing", spacing)
		UiChrome.shape_tooltip(label, get_viewport_rect().size, font, font_size, spacing,
			get_theme_stylebox("panel", "TooltipPanel"))
		return label

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
	var mark := _rarity_plate()
	holder.rarity = mark
	holder.rarity_label = mark.get_child(0)
	holder.add_child(mark)
	var plate := _cost_plate()
	holder.cost = plate
	holder.add_child(plate)
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
## measured is untouched for every other rebind. A [MiniCard] built here
## already shows [param data] ([member Cell.fresh_for]).
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
		cell.fresh_for = data
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
	var printing_set := String(art_set_for.call(data)) \
		if art_set_for.is_valid() else ""
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
			# A FACE BUILT FOR THIS CARD A MOMENT AGO ALREADY SHOWS IT
			# (h5-10 round 2): [method _make_cell] built it from this card,
			# unlit, without a chosen printing, and drew it. Giving it a
			# second instance and drawing it again cost every new page twice
			# its faces' drawing; only a chosen printing redraws it now.
			var fresh := cell.fresh_for == data
			var art := CardPrintings.texture(data.card_name, printing_set)
			if not fresh:
				cell.face.instance = CardInstance.new(data, -1, 0)
				cell.face.hovered = false
			if not fresh or art != null:
				cell.face.art_override = art
				cell.face.refresh()
			cell.tooltip_text = "%s\n%s" % [data.card_name, data.oracle_text]
	elif cell.face != null and cell.printing_set != printing_set:
		cell.face.art_override = CardPrintings.texture(data.card_name, printing_set)
		cell.face.refresh()
	cell.fresh_for = null
	cell.printing_set = printing_set
	cell.source = source_name
	_bind_badge(cell, count)
	_dress_rarity(cell)
	_dress_cost(cell)


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


func refresh_art() -> void:
	_rebuild()


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


## [QoL] Which mark a card wears — a key of [constant RARITY_MARKS], or
## `""` for a card the pool's data does not place. The decision is
## [method DeckStats.rarity_tier]'s (legendary first, then the printed
## rarity), so the letter on a card and the bar in the Stats window are
## the same count.
static func rarity_key(data: CardData) -> String:
	var tier := DeckStats.rarity_tier(data)
	return tier if RARITY_MARKS.has(tier) else ""


## The mark's plate, at the card's BOTTOM CENTRE: the same dark plate as
## the count disc and the pile marker, coloured per rarity by
## [method _dress_rarity]. Above the name label's `z_index = 2` for the
## reason [method _tag] gives.
func _rarity_plate() -> Control:
	var plate := Panel.new()
	var stone := StyleBoxFlat.new()
	stone.bg_color = Color(0, 0, 0, 0.78)
	stone.border_color = OriginalDialog.HIGHLIGHT
	stone.set_border_width_all(1)
	stone.set_corner_radius_all(3)
	plate.add_theme_stylebox_override("panel", stone)
	plate.size = RARITY_PLATE
	plate.position = Vector2((MiniCard.SIZE.x - RARITY_PLATE.x) * 0.5,
		MiniCard.SIZE.y - RARITY_PLATE.y - 3.0)
	plate.z_index = 3
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.visible = false
	var letter := Label.new()
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override("font_size", 12)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(letter)
	return plate


func _dress_rarity(cell: Cell) -> void:
	if cell == null or cell.rarity == null:
		return
	var key := rarity_key(cell.data) if show_rarity else ""
	cell.rarity.visible = key != ""
	if key == "":
		return
	var mark: Array = RARITY_MARKS[key]
	cell.rarity_label.text = String(mark[0])
	cell.rarity_label.add_theme_color_override("font_color", mark[2])
	var stone := cell.rarity.get_theme_stylebox("panel") as StyleBoxFlat
	if stone != null:
		stone.bg_color = mark[1]
		stone.border_color = Color(mark[2], 0.6)


## The cost's plate, at the card's CENTRE: the same dark stone as the
## other three plates, sized to its row of symbols by [method _dress_cost].
## Above the name label for the reason [method _tag] gives.
func _cost_plate() -> Control:
	var plate := Panel.new()
	var stone := StyleBoxFlat.new()
	stone.bg_color = Color(0, 0, 0, 0.72)
	stone.border_color = OriginalDialog.HIGHLIGHT
	stone.set_border_width_all(1)
	stone.set_corner_radius_all(4)
	plate.add_theme_stylebox_override("panel", stone)
	plate.z_index = 3
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.visible = false
	return plate


## The cost the card's centre plate shows, or `""` for nothing: a land, a
## proxy, or the switch up. `{0}` is a cost (Ornithopter wears its zero).
func cost_key(data: CardData) -> String:
	if not show_cost or data == null or data.cost == null:
		return ""
	return data.cost.text


func _dress_cost(cell: Cell) -> void:
	if cell == null or cell.cost == null:
		return
	for old in cell.cost.get_children():
		old.queue_free()
	var key := cost_key(cell.data)
	var row: Control = ManaIcons.cost_row(key, COST_ICON) if key != "" else null
	if row == null:
		cell.cost.visible = false
		return
	var symbols := row.get_child_count()
	var inner := Vector2(symbols * (COST_ICON + 1) - 1, COST_ICON)
	cell.cost.size = inner + COST_PAD
	cell.cost.position = ((MiniCard.SIZE - cell.cost.size) * 0.5).floor()
	row.position = (COST_PAD * 0.5).floor()
	row.size = inner
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.cost.add_child(row)
	cell.cost.visible = true


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
	# [QoL] Where the pointer is over the cards, for a smooth surface's
	# hover ([member _pointer]); the event is in the card's own coordinates.
	if event is InputEventMouse:
		_note_pointer(cell.position + (event as InputEventMouse).position)
	if _pan(event):
		accept_event()
		return
	if not (event is InputEventMouseButton):
		return
	if event.pressed:
		if _wheel(event as InputEventMouseButton):
			accept_event()
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()      # so the arrow keys walk the surface just clicked
		# [QoL] and the click stands the cursor on the card, BEFORE the
		# signal: the relist the signal causes keeps a cursor by name. It
		# leaves the page where it is ([method set_cursor]).
		set_cursor(_offset + _cells.find(cell), false)
		# [QoL] SHIFT sends the card to the other pile instead of moving it
		# in or out of this one — see [signal card_shifted].
		if event.shift_pressed:
			card_shifted.emit(cell.card_name)
		else:
			card_activated.emit(cell.card_name)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		grab_focus()
		set_cursor(_offset + _cells.find(cell), false)
		card_bulk.emit(cell.card_name)
		accept_event()


## One press of the wheel, from a card or from the surface between them.
## A stepped surface moves one step; a [method smooth] one glides
## [constant WHEEL_ROWS] of a row — the fraction of that a precise
## touchpad reports, when it reports one. True when it was the wheel.
func _wheel(event: InputEventMouseButton) -> bool:
	var down := event.button_index == MOUSE_BUTTON_WHEEL_DOWN
	if not down and event.button_index != MOUSE_BUTTON_WHEEL_UP:
		return false
	if smooth():
		var factor := event.factor if event.factor > 0.0 else 1.0
		_glide_by((1.0 if down else -1.0) * WHEEL_ROWS * row_pitch() * factor)
	else:
		scroll_by(1 if down else -1)
	return true


## [QoL] A touchpad's two-finger scroll, on a [method smooth] surface: the
## cards follow the fingers by the pixel, at the wheel's rate of half a
## row per unit, with no glide of their own — the fingers are the glide.
## True when it was taken.
func _pan(event: InputEvent) -> bool:
	if not smooth() or not (event is InputEventPanGesture):
		return false
	var delta := (event as InputEventPanGesture).delta.y
	scroll_px_to(_scroll_px + delta * WHEEL_ROWS * row_pitch())
	return true


## The wheel scrolls on either surface — by a step, or smoothly ([method
## _wheel]); the keys walk the cursor.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_note_pointer((event as InputEventMouse).position - _grid.position)
	if _pan(event):
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed:
		if _wheel(event as InputEventMouseButton):
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
		return
	# The manual's own list-window keys — *"You can use the up and down
	# arrow keys and the scroll bar to move through the list."* — and the
	# [QoL] cursor's: see [method handle_key].
	if event is InputEventKey and owns_key(event) and handle_key(event):
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
