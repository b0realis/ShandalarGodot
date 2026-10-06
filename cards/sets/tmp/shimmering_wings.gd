extends CardScript
## Shimmering Wings — {U} — Enchantment — Aura (common, tmp).
## Oracle: Enchant creature (Target a creature as you cast this. This card enters attached to that creature.)
##         Enchanted creature has flying. (It can't be blocked except by creatures with flying or reach.)
##         {U}: Return this Aura to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shimmering Wings", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature (Target a creature as you cast this. This card enters attached to that creature.)\nEnchanted creature has flying. (It can't be blocked except by creatures with flying or reach.)\n{U}: Return this Aura to its owner's hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
