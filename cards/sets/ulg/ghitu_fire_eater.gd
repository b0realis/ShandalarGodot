extends CardScript
## Ghitu Fire-Eater — {2}{R} — Creature — Human Nomad (uncommon, ulg).
## Oracle: {T}, Sacrifice this creature: It deals damage equal to its power to any target.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ghitu Fire-Eater", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","nomad"])
	c.oracle("{T}, Sacrifice this creature: It deals damage equal to its power to any target.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
