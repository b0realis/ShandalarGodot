extends CardScript
## No Quarter — {3}{R} — Enchantment (rare, tmp).
## Oracle: Whenever a creature becomes blocked by a creature with lesser power, destroy the blocking creature.
##         Whenever a creature blocks a creature with lesser power, destroy the attacking creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("No Quarter", "{3}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature becomes blocked by a creature with lesser power, destroy the blocking creature.\nWhenever a creature blocks a creature with lesser power, destroy the attacking creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
