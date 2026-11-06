extends CardScript
## Martyr's Cause — {2}{W} — Enchantment (uncommon, ulg).
## Oracle: Sacrifice a creature: The next time a source of your choice would deal damage to any target this turn, prevent that damage.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Martyr's Cause", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Sacrifice a creature: The next time a source of your choice would deal damage to any target this turn, prevent that damage.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
