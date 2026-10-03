extends CardScript
## Kithkin Armor — {W} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature
##         Enchanted creature can't be blocked by creatures with power 3 or greater.
##         Sacrifice this Aura: The next time a source of your choice would deal damage to enchanted creature this turn, prevent that damage.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kithkin Armor", "{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature can't be blocked by creatures with power 3 or greater.\nSacrifice this Aura: The next time a source of your choice would deal damage to enchanted creature this turn, prevent that damage.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
