extends CardScript
## Death Watch — {B} — Enchantment — Aura (common, vis).
## Oracle: Enchant creature
##         When enchanted creature dies, its controller loses life equal to its power and you gain life equal to its toughness.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Death Watch", "{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen enchanted creature dies, its controller loses life equal to its power and you gain life equal to its toughness.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
