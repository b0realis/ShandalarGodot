extends CardScript
## Illuminated Wings — {1}{U} — Enchantment — Aura (common, uds).
## Oracle: Enchant creature
##         Enchanted creature has flying.
##         {2}, Sacrifice this Aura: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Illuminated Wings", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has flying.\n{2}, Sacrifice this Aura: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
