extends CardScript
## Briar Shield — {G} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+1.
##         Sacrifice this Aura: Enchanted creature gets +3/+3 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Briar Shield", "{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+1.\nSacrifice this Aura: Enchanted creature gets +3/+3 until end of turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
