extends CardScript
## Slow Motion — {2}{U} — Enchantment — Aura (common, ulg).
## Oracle: Enchant creature
##         At the beginning of the upkeep of enchanted creature's controller, that player sacrifices that creature unless they pay {2}.
##         When this Aura is put into a graveyard from the battlefield, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Slow Motion", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAt the beginning of the upkeep of enchanted creature's controller, that player sacrifices that creature unless they pay {2}.\nWhen this Aura is put into a graveyard from the battlefield, return it to its owner's hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
