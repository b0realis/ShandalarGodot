class_name FanHand
extends Control
## The 1997 fanned hand: cards overlap in an arc, tilting outward from the
## center, and rise on hover. A plain Control (NOT a Container — containers
## reset child rotation, the tapped-card lesson) that lays out its
## MiniCard children whenever [method relayout] is called.

## THE CARD SIZE IS NOT THE FAN'S TO CHOOSE. This constant used to read
## `Vector2(96, 120)` — TALLER than wide, where [constant MiniCard.SIZE] is
## `132 x 106`, WIDER than tall — and `relayout` forced it onto every card
## it dealt. That is the same defect `graveyard_view.gd` carried with its
## own `Vector2(96, 134)`: a mini card anchors its name band, its mana
## stripes, its badges, its damage marker and its P/T as FRACTIONS of its
## own face, so squashing the widget into another aspect puts every one of
## them somewhere else. The fan was the hand the owner was looking at when
## they said the hand cards and the table cards were different dimensions.
##
## The name is kept (callers and `tests/ui/test_fan_hand.gd` measure by
## it) but it is now an ALIAS, not a number: there is one card size.
const CARD_SIZE := MiniCard.SIZE
const MAX_TILT_DEGREES := 9.0
const ARC_DROP := 14.0
const HOVER_RAISE := 22.0

## The tightest overlap a card may be dealt at and still READ. Measured,
## not guessed: at 39px of exposure a card shows about five characters of
## its name ("Savan|White|Serra|Crusad") and the row is a smear; 56 leaves
## the name legible. It is an ABSOLUTE figure and so it survived the card
## growing from 96 to 132 wide — the exposed strip is name, the name font
## is one fixed size ([constant MiniCard.NAME_FONT_SIZE]), and the name
## starts 6px inside the card whatever the card's width. Once one row
## cannot hold the hand at this spacing the overflow goes to a SECOND ROW
## BEHIND the first — the owner's call: the fan may be truncated, but a
## big hand grows backwards rather than squeezing.
const MIN_SPACING := 56.0

## The LOOSEST a small hand is dealt at: three quarters of a card, so even
## a two-card hand still reads as a fan of overlapping cards rather than a
## gapped row. (It was a bare `72.0` while a card was 96 wide — the same
## three quarters, written as a number that then went stale.)
const MAX_SPACING := MiniCard.SIZE.x * 0.75

## How far the back row sits above the front one, so its card tops peek
## out behind — a whole title bar's worth ([constant MiniCard.SIZE]'s band
## runs to y 18) plus room to read it. Also how much taller the whole fan
## gets when it opens.
const BACK_ROW_RISE := 32.0

## What ONE row of the fan costs in height, and every term is derived:
## the top margin, the deepest the arc drops a card ([constant ARC_DROP]
## at the ends), the card itself, and the bleed the ±9° tilt sweeps below
## the pivot (`SIZE.x / 2 * sin 9°` ≈ 10). Nothing here is a measured
## constant that can go stale when the card changes size.
const ONE_ROW_HEIGHT := 8.0 + ARC_DROP + MiniCard.SIZE.y + 12.0

## Z-range base for the FRONT row. The back row uses 0..n and the front
## 100..100+n, so the two never interleave. Both stay POSITIVE on
## purpose: a Control's z_index is relative to its parent, so a negative
## value puts the card behind the parent's siblings — the first attempt
## used -100 and the back row vanished behind the table itself.
const FRONT_Z := 100


func _init() -> void:
	custom_minimum_size = Vector2(0, ONE_ROW_HEIGHT)
	clip_contents = false


## How many cards one row can hold at [param width] before the overlap
## gets tighter than MIN_SPACING.
static func row_capacity(width: float) -> int:
	var usable := width - CARD_SIZE.x - 20.0
	if usable <= 0.0:
		return 1
	return maxi(1, int(usable / MIN_SPACING) + 1)


func relayout() -> void:
	var cards := get_children()
	var n := cards.size()
	_raised = null   # every card is about to be put back on the arc
	if n == 0:
		return
	# Split into rows: one while the hand fits, two when it does not. The
	# BACK row takes the first (older) cards and is drawn behind, so the
	# cards you drew most recently are the ones fully in front.
	var capacity := row_capacity(size.x)
	var back_count := 0
	if n > capacity:
		back_count = n / 2 + n % 2     # the larger half goes behind
	var wanted := ONE_ROW_HEIGHT + (BACK_ROW_RISE if back_count > 0 else 0.0)
	if not is_equal_approx(custom_minimum_size.y, wanted):
		custom_minimum_size.y = wanted   # re-entrant resize is idempotent
	# With two rows the fan is BACK_ROW_RISE taller, so the front row moves
	# down by exactly that much and stays where a one-row fan sits; the
	# back row occupies the new space above it.
	var front_top := 8.0 + (BACK_ROW_RISE if back_count > 0 else 0.0)
	_lay_row(cards.slice(0, back_count), 8.0, true)
	_lay_row(cards.slice(back_count), front_top, false)


## Deal one row of the fan at [param top]. [param behind] drops it below
## the front row's whole z-range so the rows never interleave.
func _lay_row(cards: Array, top: float, behind: bool) -> void:
	var n := cards.size()
	if n == 0:
		return
	# Overlapping spread, centered; never wider than the row itself.
	var spacing: float = minf(MAX_SPACING,
		(size.x - CARD_SIZE.x - 20.0) / maxf(n - 1, 1))
	var total: float = spacing * (n - 1) + CARD_SIZE.x
	var start_x: float = (size.x - total) / 2.0
	for i in n:
		var card: Control = cards[i]
		var t := 0.5 if n == 1 else float(i) / (n - 1)
		card.size = CARD_SIZE
		card.pivot_offset = Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y)
		card.rotation_degrees = lerpf(-MAX_TILT_DEGREES, MAX_TILT_DEGREES, t)
		card.position = Vector2(start_x + i * spacing,
			top + ARC_DROP * 4.0 * (t - 0.5) * (t - 0.5))
		card.z_index = i if behind else FRONT_Z + i
		if card is BaseButton and not card.mouse_entered.is_connected(_raise):
			card.mouse_entered.connect(_raise.bind(card))
			card.mouse_exited.connect(_settle.bind(card))


## The one card currently lifted by the pointer, or null. See [method _raise].
var _raised: Control = null


## Lift the card under the pointer clear of its neighbours.
##
## Two defects were fixed here together, both of them only visible with a
## hand big enough to fan:
##
##   1. **The card crept.** `mouse_entered` can fire more than once
##      without an intervening `mouse_exited` — `relayout` moves cards
##      about UNDER the pointer, and every move re-enters the one it lands
##      on — and each fire subtracted another [constant HOVER_RAISE]. The
##      raised card is remembered so a card can only be up once.
##   2. **Hovering a front card pushed it BACK.** The lift set `z_index =
##      100`, which is exactly [constant FRONT_Z], i.e. the z of the
##      LEFTMOST front card — so hovering any card but that one moved it
##      UNDER its right-hand neighbours instead of over them. The raised
##      card now goes above the whole front row.
func _raise(card: Control) -> void:
	if _raised == card or not is_instance_valid(card):
		return
	_raised = card
	card.position.y -= HOVER_RAISE
	card.z_index = FRONT_Z + get_child_count() + 1


func _settle(_card: Control) -> void:
	_raised = null
	relayout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		relayout()
