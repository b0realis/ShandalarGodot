extends CardScript
## War Mammoth — {3}{G} — Creature — Elephant — 3/3 (Alpha, common)
## Oracle: Trample
##
## Implementation: printed TRAMPLE keyword; excess-damage carryover past a
## lethal blocker is the trample key of a damage division (CR 702.19).


func build() -> CardData:
	return CardData.new("War Mammoth", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["elephant"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.oracle("Trample")
