extends CardScript
## Disappear — {2}{U}{U} — Enchantment — Aura (uncommon, uds).
## Oracle: Enchant creature
##         {U}: Return enchanted creature and this Aura to their owners' hands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Disappear", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\n{U}: Return enchanted creature and this Aura to their owners' hands.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
