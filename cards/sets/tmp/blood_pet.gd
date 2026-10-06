extends CardScript
## Blood Pet — {B} — Creature — Thrull (common, tmp).
## Oracle: Sacrifice this creature: Add {B}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blood Pet", "{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["thrull"])
	c.oracle("Sacrifice this creature: Add {B}.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
