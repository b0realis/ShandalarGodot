extends CardScript
## Sleeper's Guile — {2}{B} — Enchantment — Aura (common, ulg).
## Oracle: Enchant creature
##         Enchanted creature has fear. (It can't be blocked except by artifact creatures and/or black creatures.)
##         When this Aura is put into a graveyard from the battlefield, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sleeper's Guile", "{2}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has fear. (It can't be blocked except by artifact creatures and/or black creatures.)\nWhen this Aura is put into a graveyard from the battlefield, return it to its owner's hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
