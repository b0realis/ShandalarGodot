extends CardScript
## Crown of Flames — {R} — Enchantment — Aura (common, tmp).
## Oracle: Enchant creature
##         {R}: Enchanted creature gets +1/+0 until end of turn.
##         {R}: Return this Aura to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crown of Flames", "{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\n{R}: Enchanted creature gets +1/+0 until end of turn.\n{R}: Return this Aura to its owner's hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
