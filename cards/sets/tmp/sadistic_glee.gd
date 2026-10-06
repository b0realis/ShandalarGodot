extends CardScript
## Sadistic Glee — {B} — Enchantment — Aura (common, tmp).
## Oracle: Enchant creature
##         Whenever a creature dies, put a +1/+1 counter on enchanted creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sadistic Glee", "{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhenever a creature dies, put a +1/+1 counter on enchanted creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
