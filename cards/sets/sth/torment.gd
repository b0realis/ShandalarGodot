extends CardScript
## Torment — {1}{B} — Enchantment — Aura (common, sth).
## Oracle: Enchant creature
##         Enchanted creature gets -3/-0.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Torment", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets -3/-0.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
