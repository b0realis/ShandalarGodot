extends CardScript
## Grave Pact — {1}{B}{B}{B} — Enchantment (rare, sth).
## Oracle: Whenever a creature you control dies, each other player sacrifices a creature of their choice.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Grave Pact", "{1}{B}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature you control dies, each other player sacrifices a creature of their choice.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
