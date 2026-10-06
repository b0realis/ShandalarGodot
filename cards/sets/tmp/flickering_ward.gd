extends CardScript
## Flickering Ward — {W} — Enchantment — Aura (uncommon, tmp).
## Oracle: Enchant creature
##         As this Aura enters, choose a color.
##         Enchanted creature has protection from the chosen color. This effect doesn't remove this Aura.
##         {W}: Return this Aura to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flickering Ward", "{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAs this Aura enters, choose a color.\nEnchanted creature has protection from the chosen color. This effect doesn't remove this Aura.\n{W}: Return this Aura to its owner's hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
