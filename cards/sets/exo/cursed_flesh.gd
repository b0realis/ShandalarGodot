extends CardScript
## Cursed Flesh — {B} — Enchantment — Aura (common, exo).
## Oracle: Enchant creature
##         Enchanted creature gets -1/-1 and has fear. (It can't be blocked except by artifact creatures and/or black creatures.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cursed Flesh", "{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets -1/-1 and has fear. (It can't be blocked except by artifact creatures and/or black creatures.)")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
