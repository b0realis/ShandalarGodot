extends CardScript
## Flowstone Blade — {R} — Enchantment — Aura (common, sth).
## Oracle: Enchant creature
##         {R}: Enchanted creature gets +1/-1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flowstone Blade", "{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\n{R}: Enchanted creature gets +1/-1 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
