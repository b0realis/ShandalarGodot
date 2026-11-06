extends CardScript
## No Mercy — {2}{B}{B} — Enchantment (rare, ulg).
## Oracle: Whenever a creature deals damage to you, destroy it.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("No Mercy", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature deals damage to you, destroy it.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
