extends CardScript
## Mortal Wound — {G} — Enchantment — Aura (common, vis).
## Oracle: Enchant creature
##         When enchanted creature is dealt damage, destroy it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mortal Wound", "{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen enchanted creature is dealt damage, destroy it.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
