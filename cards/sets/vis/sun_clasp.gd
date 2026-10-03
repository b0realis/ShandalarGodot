extends CardScript
## Sun Clasp — {1}{W} — Enchantment — Aura (common, vis).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+3.
##         {W}: Return enchanted creature to its owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sun Clasp", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+3.\n{W}: Return enchanted creature to its owner's hand.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
