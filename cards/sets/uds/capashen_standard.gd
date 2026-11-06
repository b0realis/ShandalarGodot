extends CardScript
## Capashen Standard — {W} — Enchantment — Aura (common, uds).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+1.
##         {2}, Sacrifice this Aura: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Capashen Standard", "{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+1.\n{2}, Sacrifice this Aura: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
