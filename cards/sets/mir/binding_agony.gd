extends CardScript
## Binding Agony — {1}{B} — Enchantment — Aura (common, mir).
## Oracle: Enchant creature
##         Whenever enchanted creature is dealt damage, this Aura deals that much damage to that creature's controller.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Binding Agony", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhenever enchanted creature is dealt damage, this Aura deals that much damage to that creature's controller.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
