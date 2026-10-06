extends CardScript
## Death Pits of Rath — {3}{B}{B} — Enchantment (rare, tmp).
## Oracle: Whenever a creature is dealt damage, destroy it. It can't be regenerated.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Death Pits of Rath", "{3}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature is dealt damage, destroy it. It can't be regenerated.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
