extends CardScript
## Sigil of Sleep — {U} — Enchantment — Aura (common, uds).
## Oracle: Enchant creature
##         Whenever enchanted creature deals damage to a player, return target creature that player controls to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sigil of Sleep", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhenever enchanted creature deals damage to a player, return target creature that player controls to its owner's hand.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
