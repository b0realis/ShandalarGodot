class_name BoardOrder
extends RefCounted
## ARRANGE CARDS — the reading order the duel table falls into when the
## player asks for it.
##
## THE CONTROL IS 1997's. The original has no automatic sort of anything:
## its hand window only scrolls (`Duel.hlp`, topic **Hands**: *"Each window
## has a maximum size… use the scroll arrows at the top to see the rest.
## This is a revolving scroll"*), and its board is straightened only when
## you ask, from the territory mini-menu — `@MENU_TERRITORY`
## (`shandalar-src/Program/UIStrings.txt:908`) entries 15-16,
## `Arrange your cards\tDblClk` / `Arrange opponent's cards\tDblClk`, which
## `Duel.hlp`, topic **Territory**, explains verbatim:
##
##   *"**Arrange Cards** straightens up the cards in play in the territory
##   where you right-clicked. This has no effect on the duel, it just makes
##   things neater. (You can also double-click on a territory to do this.)"*
##
## So an on-demand arrange is `[1997]`. What the original never says is what
## "straightened" LOOKS like — no source we hold records the resulting
## order — so the order itself is taken from the 30th-anniversary remake,
## which sorts the same three groups (`[s30]`, `duel.go:1438-1544`,
## pinned by its own `duel_card_sort_test.go`):
##
## | group | keys, in order |
## |---|---|
## | hand | lands before spells · *if both lands, name only, stop* · colour rank · mana value · name |
## | creatures | power **desc** · toughness **desc** · name |
## | lands | name · **untapped before tapped** |
## | other permanents | none — they keep play order |
##
## Colour rank is WUBRG then gold then colourless (s30 `manaCostColorRank`
## over `mage-go/pkg/mage/core/color.go:8-16`, where `White` is 1 and
## `Green` is 5). `{X}` contributes 0 to a mana value (CR 203.3b), so
## Fireball arranges as a red one-drop — s30's own fixture says so.
##
## PURE, AND NON-MUTATING. Every function hands back a NEW array and leaves
## its input alone; s30 pins that contractually
## (`duel_card_sort_test.go:106-115`) and here it is load-bearing for a
## second reason: the arrays these functions are handed are the ENGINE's own
## zone arrays. Sorting one in place would reorder the battlefield itself,
## which is a rules change (`MtgGame` owns that order) rather than a view.
## That is also what makes the arrange TOGGLE exact — see
## `DuelScreen._on_arrange_toggled`.
##
## STABLE. `Array.sort_custom` is not a stable sort, so every comparator
## here ends on the instance id: two identical untapped Forests keep the
## same two seats across a rebuild instead of trading places on every
## refresh. The reference has no such key because it re-sorts a snapshot it
## rebuilds anyway; ours re-sorts the live arrays sixty times a second.
##
## Lives in `game/` because only the presentation asks for it, but it is a
## plain [RefCounted] with static methods, so it unit-tests without a scene
## and the future territory mini-menu (`docs/duel-todo.md` §6.3) can reuse
## it unchanged.

## The colour rank of a card that is one colour, keyed by the single bit of
## its colour mask — WUBRG, exactly the 1..5 of s30's `core.Color`.
const COLOR_RANK := {
	Mtg.ManaColor.W: 1,
	Mtg.ManaColor.U: 2,
	Mtg.ManaColor.B: 3,
	Mtg.ManaColor.R: 4,
	Mtg.ManaColor.G: 5,
}

## What a multicoloured card ranks, and what a colourless one ranks — the
## two ranks past Green (`manaCostColorRank`: `int(core.Green) + 1` and
## `+ 2`).
const RANK_GOLD := 6
const RANK_COLORLESS := 7


## One card's colour rank: 1-5 for mono-coloured, [constant RANK_GOLD] for
## multicoloured, [constant RANK_COLORLESS] for colourless.
##
## Reads [method CardData.color_mask] — the PRINTED colour — and not
## `cur_colors`, because this is a HAND order and a card in hand has no
## live characteristics to read.
static func color_rank(data: CardData) -> int:
	if data == null:
		return RANK_COLORLESS
	var mask := data.color_mask()
	var rank := RANK_COLORLESS
	var found := 0
	for color in COLOR_RANK:
		if mask & color:
			found += 1
			rank = COLOR_RANK[color]
	if found == 0:
		return RANK_COLORLESS
	if found > 1:
		return RANK_GOLD
	return rank


## The hand, arranged: lands first by name, then spells by colour rank,
## mana value and name. A sorted COPY; the input is untouched.
static func hand(cards: Array) -> Array:
	var out := cards.duplicate()
	out.sort_custom(_hand_less)
	return out


## The creature row, arranged: strongest first — power descending, then
## toughness descending, then name.
##
## Reads the LIVE power and toughness (CONTRIBUTING.md rule 5). s30 reads its
## snapshot's base numbers, so a Crusade'd 2/2 sorts behind a printed 3/3
## there; that is its bug, not the order's definition.
static func creatures(cards: Array) -> Array:
	var out := cards.duplicate()
	out.sort_custom(_creature_less)
	return out


## The land row, arranged: by name, and untapped before tapped inside a
## name, *"so tapping visibly walks the group"* (s30's stated intent).
static func lands(cards: Array) -> Array:
	var out := cards.duplicate()
	out.sort_custom(_land_less)
	return out


# ------------------------------------------------------------ comparators --

static func _hand_less(a: CardInstance, b: CardInstance) -> bool:
	var a_land := a.data.is_land()
	var b_land := b.data.is_land()
	if a_land != b_land:
		return a_land          # lands lead
	if a_land:
		# ...and stop there. The early exit is s30's own
		# (`lessCardSortKey`: `if a.isLand { return a.name < b.name }`) —
		# a land never consults colour rank or mana value.
		if a.data.card_name != b.data.card_name:
			return a.data.card_name < b.data.card_name
		return a.id < b.id
	var a_rank := color_rank(a.data)
	var b_rank := color_rank(b.data)
	if a_rank != b_rank:
		return a_rank < b_rank
	var a_mv := a.data.cost.mana_value()
	var b_mv := b.data.cost.mana_value()
	if a_mv != b_mv:
		return a_mv < b_mv
	if a.data.card_name != b.data.card_name:
		return a.data.card_name < b.data.card_name
	return a.id < b.id


static func _creature_less(a: CardInstance, b: CardInstance) -> bool:
	if a.cur_power != b.cur_power:
		return a.cur_power > b.cur_power
	if a.cur_toughness != b.cur_toughness:
		return a.cur_toughness > b.cur_toughness
	if a.data.card_name != b.data.card_name:
		return a.data.card_name < b.data.card_name
	return a.id < b.id


static func _land_less(a: CardInstance, b: CardInstance) -> bool:
	if a.data.card_name != b.data.card_name:
		return a.data.card_name < b.data.card_name
	if a.tapped != b.tapped:
		return not a.tapped    # untapped first
	# A stable last key so two identical untapped Forests never swap places
	# between refreshes (Array.sort_custom is NOT a stable sort).
	return a.id < b.id
