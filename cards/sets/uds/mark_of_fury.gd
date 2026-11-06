extends CardScript
## Mark of Fury — {R} — Enchantment — Aura (common, uds).
## Oracle: Enchant creature
##         Enchanted creature has haste.
##         At the beginning of the end step, return this Aura to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mark of Fury", "{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has haste.\nAt the beginning of the end step, return this Aura to its owner's hand.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
