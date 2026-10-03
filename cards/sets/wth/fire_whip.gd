extends CardScript
## Fire Whip — {1}{R} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature you control
##         Enchanted creature has "{T}: This creature deals 1 damage to any target."
##         Sacrifice this Aura: It deals 1 damage to any target.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fire Whip", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature you control\nEnchanted creature has \"{T}: This creature deals 1 damage to any target.\"\nSacrifice this Aura: It deals 1 damage to any target.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
