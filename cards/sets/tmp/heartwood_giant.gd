extends CardScript
## Heartwood Giant — {3}{G}{G} — Creature — Giant (rare, tmp).
## Oracle: {T}, Sacrifice a Forest: This creature deals 2 damage to target player or planeswalker.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heartwood Giant", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["giant"])
	c.oracle("{T}, Sacrifice a Forest: This creature deals 2 damage to target player or planeswalker.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
