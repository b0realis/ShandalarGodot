extends CardScript
## Invasion Plans — {2}{R} — Enchantment (rare, sth).
## Oracle: All creatures block each combat if able.
##         The attacking player chooses how each creature blocks each combat.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Invasion Plans", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("All creatures block each combat if able.\nThe attacking player chooses how each creature blocks each combat.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
