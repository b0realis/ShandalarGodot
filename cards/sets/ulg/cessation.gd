extends CardScript
## Cessation — {2}{W} — Enchantment — Aura (common, ulg).
## Oracle: Enchant creature
##         Enchanted creature can't attack.
##         When this Aura is put into a graveyard from the battlefield, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cessation", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature can't attack.\nWhen this Aura is put into a graveyard from the battlefield, return it to its owner's hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
