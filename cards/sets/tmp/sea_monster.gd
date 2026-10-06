extends CardScript
## Sea Monster — {4}{U}{U} — Creature — Serpent (common, tmp).
## Oracle: This creature can't attack unless defending player controls an Island.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sea Monster", "{4}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(6, 6)
	c.with_subtypes(["serpent"])
	c.oracle("This creature can't attack unless defending player controls an Island.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
