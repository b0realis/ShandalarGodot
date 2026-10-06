extends CardScript
## Maniacal Rage — {1}{R} — Enchantment — Aura (common, exo).
## Oracle: Enchant creature
##         Enchanted creature gets +2/+2 and can't block.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Maniacal Rage", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +2/+2 and can't block.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
