extends CardScript
## Morgue Thrull — {2}{B} — Creature — Thrull (common, sth).
## Oracle: Sacrifice this creature: Mill three cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Morgue Thrull", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["thrull"])
	c.oracle("Sacrifice this creature: Mill three cards.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
