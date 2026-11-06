extends CardScript
## Attrition — {1}{B}{B} — Enchantment (rare, uds).
## Oracle: {B}, Sacrifice a creature: Destroy target nonblack creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Attrition", "{1}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{B}, Sacrifice a creature: Destroy target nonblack creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
