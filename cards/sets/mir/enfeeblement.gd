extends CardScript
## Enfeeblement — {B}{B} — Enchantment — Aura (common, mir).
## Oracle: Enchant creature (Target a creature as you cast this. This card enters attached to that creature.)
##         Enchanted creature gets -2/-2.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Enfeeblement", "{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature (Target a creature as you cast this. This card enters attached to that creature.)\nEnchanted creature gets -2/-2.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
