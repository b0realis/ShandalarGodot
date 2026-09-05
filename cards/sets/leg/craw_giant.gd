extends CardScript
## Craw Giant — {3}{G}{G}{G}{G} — Creature — Giant — 6/4 — (leg, uncommon)
## Oracle: Trample
##         Rampage 2 (Whenever this creature becomes blocked, it gets
##         +2/+2 until end of turn for each creature blocking it beyond
##         the first.)
##
## Implementation: printed trample plus the engine's RAMPAGE field
## (CR 702.23) — MtgGame applies +2/+2 per extra blocker right after
## blockers are declared. Trample and rampage together mean gang-blocking
## a Craw Giant actually takes MORE damage to the face, not less.


func build() -> CardData:
	return CardData.new("Craw Giant", "{3}{G}{G}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(6, 4) \
		.with_subtypes(["giant"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.with_rampage(2) \
		.oracle("Trample\nRampage 2 (Whenever this creature becomes blocked, it gets "
			+ "+2/+2 until end of turn for each creature blocking it beyond the first.)")
