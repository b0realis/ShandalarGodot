extends CardScript
## Reflexes — {R} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature (Target a creature as you cast this. This card enters attached to that creature.)
##         Enchanted creature has first strike. (It deals combat damage before creatures without first strike.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reflexes", "{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature (Target a creature as you cast this. This card enters attached to that creature.)\nEnchanted creature has first strike. (It deals combat damage before creatures without first strike.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
