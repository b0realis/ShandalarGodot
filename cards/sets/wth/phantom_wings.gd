extends CardScript
## Phantom Wings — {1}{U} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature
##         Enchanted creature has flying.
##         Sacrifice this Aura: Return enchanted creature to its owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phantom Wings", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has flying.\nSacrifice this Aura: Return enchanted creature to its owner's hand.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
