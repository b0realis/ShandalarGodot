extends CardScript
## Impending Disaster — {1}{R} — Enchantment (rare, ulg).
## Oracle: At the beginning of your upkeep, if there are seven or more lands on the battlefield, sacrifice this enchantment and destroy all lands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Impending Disaster", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, if there are seven or more lands on the battlefield, sacrifice this enchantment and destroy all lands.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
