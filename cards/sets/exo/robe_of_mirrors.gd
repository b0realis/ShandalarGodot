extends CardScript
## Robe of Mirrors — {U} — Enchantment — Aura (common, exo).
## Oracle: Enchant creature (Target a creature as you cast this. This card enters attached to that creature.)
##         Enchanted creature has shroud. (It can't be the target of spells or abilities.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Robe of Mirrors", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature (Target a creature as you cast this. This card enters attached to that creature.)\nEnchanted creature has shroud. (It can't be the target of spells or abilities.)")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
