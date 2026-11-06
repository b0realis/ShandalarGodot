extends CardScript
## Launch — {1}{U} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         Enchanted creature has flying.
##         When this Aura is put into a graveyard from the battlefield, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Launch", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has flying.\nWhen this Aura is put into a graveyard from the battlefield, return it to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
