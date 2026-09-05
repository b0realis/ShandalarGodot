extends CardScript
## Wolverine Pack — {2}{G}{G} — Creature — Wolverine — 2/4 — (leg, common)
## Oracle: Rampage 2 (Whenever this creature becomes blocked, it gets
##         +2/+2 until end of turn for each creature blocking it beyond
##         the first.)
##
## Implementation: the engine's RAMPAGE field. The cheapest rampage body
## in the set, and the one that most often forces a bad block: two
## blockers turn a 2/4 into a 4/6.


func build() -> CardData:
	return CardData.new("Wolverine Pack", "{2}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["wolverine"]) \
		.with_rampage(2) \
		.oracle("Rampage 2 (Whenever this creature becomes blocked, it gets +2/+2 "
			+ "until end of turn for each creature blocking it beyond the first.)")
