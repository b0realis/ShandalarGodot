extends CardScript
## Twisted Experiment — {1}{B} — Enchantment — Aura (common, uds).
## Oracle: Enchant creature
##         Enchanted creature gets +3/-1.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Twisted Experiment", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +3/-1.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
