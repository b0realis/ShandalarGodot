extends CardScript
## Granite Grip — {2}{R} — Enchantment — Aura (common, ulg).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+0 for each Mountain you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Granite Grip", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+0 for each Mountain you control.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
