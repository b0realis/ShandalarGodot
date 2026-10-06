extends CardScript
## Frog Tongue — {G} — Enchantment — Aura (common, tmp).
## Oracle: Enchant creature
##         When this Aura enters, draw a card.
##         Enchanted creature has reach. (It can block creatures with flying.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Frog Tongue", "{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen this Aura enters, draw a card.\nEnchanted creature has reach. (It can block creatures with flying.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
