extends CardScript
## Circle of Protection: Shadow — {1}{W} — Enchantment (common, tmp).
## Oracle: {1}: The next time a creature of your choice with shadow would deal damage to you this turn, prevent that damage.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Circle of Protection: Shadow", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{1}: The next time a creature of your choice with shadow would deal damage to you this turn, prevent that damage.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
