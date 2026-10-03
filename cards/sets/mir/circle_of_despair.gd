extends CardScript
## Circle of Despair — {1}{W}{B} — Enchantment (rare, mir).
## Oracle: {1}, Sacrifice a creature: The next time a source of your choice would deal damage to any target this turn, prevent that damage.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Circle of Despair", "{1}{W}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{1}, Sacrifice a creature: The next time a source of your choice would deal damage to any target this turn, prevent that damage.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
