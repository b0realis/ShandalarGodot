extends CardScript
## Trumpeting Armodon — {3}{G} — Creature — Elephant (uncommon, tmp).
## Oracle: {1}{G}: Target creature blocks this creature this turn if able.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Trumpeting Armodon", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elephant"])
	c.oracle("{1}{G}: Target creature blocks this creature this turn if able.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
