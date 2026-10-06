extends CardScript
## Manta Riders — {U} — Creature — Merfolk (common, tmp).
## Oracle: {U}: This creature gains flying until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Manta Riders", "{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["merfolk"])
	c.oracle("{U}: This creature gains flying until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
