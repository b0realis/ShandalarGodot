extends CardScript
## Rivalry — {2}{R} — Enchantment (rare, ulg).
## Oracle: At the beginning of each player's upkeep, if that player controls more lands than each other player, this enchantment deals 2 damage to them.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rivalry", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's upkeep, if that player controls more lands than each other player, this enchantment deals 2 damage to them.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
