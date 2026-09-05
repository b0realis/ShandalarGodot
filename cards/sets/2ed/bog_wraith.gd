extends CardScript
## Bog Wraith — {3}{B} — Creature — Wraith — 3/3 (2ed, uncommon)
## Oracle: Swampwalk (This creature can't be blocked as long as defending
##         player controls a Swamp.)
##
## Implementation: the reference LANDWALK card — with_landwalk(["swamp"]).
## Block legality checks the defending player's lands by SUBTYPE, so an
## Underground Sea or Bayou also opens the door. When the defender controls
## no swamp, it's just a vanilla 3/3 that anyone can block.


func build() -> CardData:
	return CardData.new("Bog Wraith", "{3}{B}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["wraith"]) \
		.with_landwalk(["swamp"]) \
		.oracle("Swampwalk")
