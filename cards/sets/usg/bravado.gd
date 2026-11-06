extends CardScript
## Bravado — {1}{R} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+1 for each other creature you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bravado", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+1 for each other creature you control.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
