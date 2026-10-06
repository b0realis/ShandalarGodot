extends CardScript
## Killer Whale — {3}{U}{U} — Creature — Whale (uncommon, exo).
## Oracle: {U}: This creature gains flying until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Killer Whale", "{3}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 5)
	c.with_subtypes(["whale"])
	c.oracle("{U}: This creature gains flying until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
