extends CardScript
## Predatory Hunger — {G} — Enchantment — Aura (common, exo).
## Oracle: Enchant creature
##         Whenever an opponent casts a creature spell, put a +1/+1 counter on enchanted creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Predatory Hunger", "{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhenever an opponent casts a creature spell, put a +1/+1 counter on enchanted creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
