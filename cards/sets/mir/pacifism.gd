extends CardScript
## Pacifism — {1}{W} — Enchantment — Aura (common, mir).
## Oracle: Enchant creature
##         Enchanted creature can't attack or block.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pacifism", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature can't attack or block.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
