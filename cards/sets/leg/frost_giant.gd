extends CardScript
## Frost Giant — {3}{R}{R}{R} — Creature — Giant — 4/4 — (leg, uncommon)
## Oracle: Rampage 2 (Whenever this creature becomes blocked, it gets
##         +2/+2 until end of turn for each creature blocking it beyond
##         the first.)
##
## Implementation: the engine's RAMPAGE field (CR 702.23). A vanilla 4/4
## for six that punishes the double block — Legends' idea of a red fatty.


func build() -> CardData:
	return CardData.new("Frost Giant", "{3}{R}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["giant"]) \
		.with_rampage(2) \
		.oracle("Rampage 2 (Whenever this creature becomes blocked, it gets +2/+2 "
			+ "until end of turn for each creature blocking it beyond the first.)")
