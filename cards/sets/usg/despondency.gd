extends CardScript
## Despondency — {1}{B} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         Enchanted creature gets -2/-0.
##         When this Aura is put into a graveyard from the battlefield, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Despondency", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets -2/-0.\nWhen this Aura is put into a graveyard from the battlefield, return it to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
