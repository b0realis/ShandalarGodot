extends CardScript
## Volrath's Curse — {1}{U} — Enchantment — Aura (common, tmp).
## Oracle: Enchant creature
##         Enchanted creature can't attack or block, and its activated abilities can't be activated. That creature's controller may sacrifice a permanent of their choice for that player to ignore this effect until end of turn.
##         {1}{U}: Return this Aura to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Volrath's Curse", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature can't attack or block, and its activated abilities can't be activated. That creature's controller may sacrifice a permanent of their choice for that player to ignore this effect until end of turn.\n{1}{U}: Return this Aura to its owner's hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
