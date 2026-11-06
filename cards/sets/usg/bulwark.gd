extends CardScript
## Bulwark — {3}{R}{R} — Enchantment (rare, usg).
## Oracle: At the beginning of your upkeep, this enchantment deals X damage to target opponent, where X is the number of cards in your hand minus the number of cards in that player's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bulwark", "{3}{R}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, this enchantment deals X damage to target opponent, where X is the number of cards in your hand minus the number of cards in that player's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
