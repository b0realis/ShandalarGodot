extends CardScript
## Servant of Volrath — {2}{B} — Creature — Minion (common, tmp).
## Oracle: When this creature leaves the battlefield, sacrifice a creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Servant of Volrath", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["minion"])
	c.oracle("When this creature leaves the battlefield, sacrifice a creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
