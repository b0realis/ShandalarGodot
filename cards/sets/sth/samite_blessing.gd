extends CardScript
## Samite Blessing — {W} — Enchantment — Aura (common, sth).
## Oracle: Enchant creature
##         Enchanted creature has "{T}: The next time a source of your choice would deal damage to target creature this turn, prevent that damage."
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Samite Blessing", "{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has \"{T}: The next time a source of your choice would deal damage to target creature this turn, prevent that damage.\"")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
