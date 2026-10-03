extends CardScript
## Coils of the Medusa — {1}{B} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature
##         Enchanted creature gets +1/-1.
##         Sacrifice this Aura: Destroy all non-Wall creatures blocking enchanted creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Coils of the Medusa", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/-1.\nSacrifice this Aura: Destroy all non-Wall creatures blocking enchanted creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
