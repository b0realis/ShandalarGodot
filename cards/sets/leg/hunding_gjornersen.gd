extends CardScript
## Hunding Gjornersen — {3}{W}{U}{U} — Legendary Creature — Human Warrior — 5/4 — (leg, uncommon)
## Oracle: Rampage 1 (Whenever this creature becomes blocked, it gets
##         +1/+1 until end of turn for each creature blocking it beyond
##         the first.)
##
## Implementation: the engine's RAMPAGE field on a 5/4 — the biggest
## printed power in the rampage cycle, so even rampage 1 makes double
## blocks costly.


func build() -> CardData:
	return CardData.new("Hunding Gjornersen", "{3}{W}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(5, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "warrior"]) \
		.with_rampage(1) \
		.oracle("Rampage 1 (Whenever this creature becomes blocked, it gets +1/+1 "
			+ "until end of turn for each creature blocking it beyond the first.)")
