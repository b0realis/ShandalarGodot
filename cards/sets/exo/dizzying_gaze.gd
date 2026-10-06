extends CardScript
## Dizzying Gaze — {R} — Enchantment — Aura (common, exo).
## Oracle: Enchant creature you control
##         {R}: Enchanted creature deals 1 damage to target creature with flying.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dizzying Gaze", "{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature you control\n{R}: Enchanted creature deals 1 damage to target creature with flying.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
