extends CardScript
## Marble Titan — {3}{W} — Creature — Giant (rare, tmp).
## Oracle: Creatures with power 3 or greater don't untap during their controllers' untap steps.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Marble Titan", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["giant"])
	c.oracle("Creatures with power 3 or greater don't untap during their controllers' untap steps.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
