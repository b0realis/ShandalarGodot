extends CardScript
## Fungus Elemental — {3}{G} — Creature — Fungus Elemental (rare, wth).
## Oracle: {G}, Sacrifice a Forest: Put a +2/+2 counter on this creature. Activate only if this creature entered this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fungus Elemental", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["fungus","elemental"])
	c.oracle("{G}, Sacrifice a Forest: Put a +2/+2 counter on this creature. Activate only if this creature entered this turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
