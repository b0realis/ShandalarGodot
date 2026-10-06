extends CardScript
## Shield Mate — {W} — Creature — Human Soldier (common, exo).
## Oracle: Sacrifice this creature: Target creature gets +0/+4 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shield Mate", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","soldier"])
	c.oracle("Sacrifice this creature: Target creature gets +0/+4 until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
