extends CardScript
## Blood Vassal — {2}{B} — Creature — Thrull (common, usg).
## Oracle: Sacrifice this creature: Add {B}{B}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blood Vassal", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["thrull"])
	c.oracle("Sacrifice this creature: Add {B}{B}.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
