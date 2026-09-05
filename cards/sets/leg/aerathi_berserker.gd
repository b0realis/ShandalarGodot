extends CardScript
## Aerathi Berserker — {2}{R}{R}{R} — Creature — Human Berserker — 2/4 — (leg, uncommon)
## Oracle: Rampage 3 (Whenever this creature becomes blocked, it gets
##         +3/+3 until end of turn for each creature blocking it beyond
##         the first.)
##
## Implementation: the engine's RAMPAGE field at its highest value in the
## set. A 2/4 that becomes an 8/10 against a triple block — the defender's
## only sane answer is a single chump.


func build() -> CardData:
	return CardData.new("Aerathi Berserker", "{2}{R}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["human", "berserker"]) \
		.with_rampage(3) \
		.oracle("Rampage 3 (Whenever this creature becomes blocked, it gets +3/+3 "
			+ "until end of turn for each creature blocking it beyond the first.)")
