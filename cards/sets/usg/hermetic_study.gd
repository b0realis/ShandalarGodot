extends CardScript
## Hermetic Study — {1}{U} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         Enchanted creature has "{T}: This creature deals 1 damage to any target."
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hermetic Study", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has \"{T}: This creature deals 1 damage to any target.\"")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
