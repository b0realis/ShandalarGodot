extends CardScript
## Dark Hatchling — {4}{B}{B} — Creature — Horror (rare, usg).
## Oracle: Flying
##         When this creature enters, destroy target nonblack creature. It can't be regenerated.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dark Hatchling", "{4}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["horror"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, destroy target nonblack creature. It can't be regenerated.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
