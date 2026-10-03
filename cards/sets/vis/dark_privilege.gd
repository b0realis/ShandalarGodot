extends CardScript
## Dark Privilege — {1}{B} — Enchantment — Aura (common, vis).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+1.
##         Sacrifice a creature: Regenerate enchanted creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dark Privilege", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+1.\nSacrifice a creature: Regenerate enchanted creature.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
