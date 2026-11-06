extends CardScript
## Planar Collapse — {1}{W} — Enchantment (rare, ulg).
## Oracle: At the beginning of your upkeep, if there are four or more creatures on the battlefield, sacrifice this enchantment and destroy all creatures. They can't be regenerated.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Planar Collapse", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, if there are four or more creatures on the battlefield, sacrifice this enchantment and destroy all creatures. They can't be regenerated.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
