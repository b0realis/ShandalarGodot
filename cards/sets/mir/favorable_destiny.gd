extends CardScript
## Favorable Destiny — {1}{W} — Enchantment — Aura (uncommon, mir).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+2 as long as it's white.
##         Enchanted creature has shroud as long as its controller controls another creature. (It can't be the target of spells or abilities.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Favorable Destiny", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+2 as long as it's white.\nEnchanted creature has shroud as long as its controller controls another creature. (It can't be the target of spells or abilities.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
