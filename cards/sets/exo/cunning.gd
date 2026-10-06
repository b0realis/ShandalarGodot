extends CardScript
## Cunning — {1}{U} — Enchantment — Aura (common, exo).
## Oracle: Enchant creature
##         Enchanted creature gets +3/+3.
##         When enchanted creature attacks or blocks, sacrifice this Aura at the beginning of the next cleanup step.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cunning", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +3/+3.\nWhen enchanted creature attacks or blocks, sacrifice this Aura at the beginning of the next cleanup step.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
