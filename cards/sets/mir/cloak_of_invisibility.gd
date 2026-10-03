extends CardScript
## Cloak of Invisibility — {U} — Enchantment — Aura (common, mir).
## Oracle: Enchant creature
##         Enchanted creature has phasing and can't be blocked except by Walls. (It phases in or out before its controller untaps during each of their untap steps. While it's phased out, it's treated as though it doesn't exist.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cloak of Invisibility", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has phasing and can't be blocked except by Walls. (It phases in or out before its controller untaps during each of their untap steps. While it's phased out, it's treated as though it doesn't exist.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
