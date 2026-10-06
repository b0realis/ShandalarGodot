extends CardScript
## Conviction — {1}{W} — Enchantment — Aura (common, sth).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+3.
##         {W}: Return this Aura to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Conviction", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+3.\n{W}: Return this Aura to its owner's hand.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
