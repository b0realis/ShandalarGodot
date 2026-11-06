extends CardScript
## Phyrexian Broodlings — {1}{B}{B} — Creature — Phyrexian Minion (common, ulg).
## Oracle: {1}, Sacrifice a creature: Put a +1/+1 counter on this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Broodlings", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phyrexian","minion"])
	c.oracle("{1}, Sacrifice a creature: Put a +1/+1 counter on this creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
