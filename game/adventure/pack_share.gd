class_name PackShare
extends RefCounted
## THE PACK SHARE (0.60.14, the owner's pack rulings of 2026-11-03: "Each
## pack gets 20% and then as more are added, the percentage is divided
## amongst them from the cap of 60 %. 3 packs each 20%. More packs, that
## gets smaller!") [ours]. In every RANDOM card draw of a campaign with card
## packs — a shop's place ([CardShop]), a duel's cards won and the artifact
## for the next duel ([DuelSpoils]), a lair's treasure, rares, thieves,
## Pyramids and duel hoard ([LairEvent], [LairDuels]) — the activated packs
## ([method AdventurePacks.campaign_packs]) together take
## `min(20% × N, 60%)` of the draws, each pack alike, `min(20%, 60% / N)`:
## 1 pack 20%, 2 packs 40%, 3 or more 60% (8 packs 7.5% each); the rest are
## base cards, which stay the larger part. A pack that has no card for the
## draw (its colour, rarity, type) leaves its share to the packs that have;
## no pack card fits, the base card is drawn, and no base card fits, a pack
## card — so a place is never left empty for want of one side. Choice lists
## (trades, the castle's pick, "any card of your choice", a quest's reward)
## are not draws: they list every card.
##
## A campaign without packs casts no die of its own: with no pack the draw
## is the one die over the base cards it always was ([method pick]).

## Each activated pack's share, in hundredths, while the packs are few.
const PER_PACK := 20
## All the packs together never more (base cards 40% at least).
const MOST := 60
## [method side]'s answers besides a pack's index.
const BASE := -1
const NONE := -2


## The packs' share of the draws, in hundredths, with [param packs]
## activated: `min(20 × packs, 60)`.
static func share(packs: int) -> int:
	return mini(PER_PACK * maxi(packs, 0), MOST)


## WHICH SIDE ONE DRAW TAKES: [param base] how many base cards fit it,
## [param packs] how many of each activated pack's cards fit it (one entry
## per pack, none fitting or some). [constant BASE], the index of a pack
## among [param packs], or [constant NONE] when nothing fits. The share's
## die (`below(100)`) is cast only when both sides have a card; the pack is
## then one of those that have, alike.
static func side(dice: MsvcRandom, base: int, packs: Array) -> int:
	var live: Array[int] = []
	for i in packs.size():
		if int(packs[i]) > 0:
			live.append(i)
	if live.is_empty():
		return BASE if base > 0 else NONE
	if base > 0 and dice.below(100) >= share(packs.size()):
		return BASE
	return live[dice.below(live.size())]


## ONE CARD of [param base] or of one of [param packs] (lists of names, one
## per activated pack) by the share ([method side]), then alike among the
## side's; "" when none fits. With no pack, `base[dice.below(base.size())]`
## — the draw as it was.
static func pick(dice: MsvcRandom, base: Array, packs: Array) -> String:
	var sizes: Array[int] = []
	for list in packs:
		sizes.append((list as Array).size())
	var at := side(dice, base.size(), sizes)
	if at == NONE:
		return ""
	var list: Array = base if at == BASE else packs[at]
	return String(list[dice.below(list.size())])
