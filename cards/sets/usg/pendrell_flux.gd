extends CardScript
## Pendrell Flux — {1}{U} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         Enchanted creature has "At the beginning of your upkeep, sacrifice this creature unless you pay its mana cost."
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pendrell Flux", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has \"At the beginning of your upkeep, sacrifice this creature unless you pay its mana cost.\"")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
