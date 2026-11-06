extends CardScript
## Cloak of Mists — {1}{U} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         Enchanted creature can't be blocked.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cloak of Mists", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature can't be blocked.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
