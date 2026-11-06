extends CardScript
## Fog of Gnats — {B}{B} — Creature — Insect (common, ulg).
## Oracle: Flying
##         {B}: Regenerate this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fog of Gnats", "{B}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{B}: Regenerate this creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
