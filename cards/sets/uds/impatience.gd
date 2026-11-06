extends CardScript
## Impatience — {2}{R} — Enchantment (rare, uds).
## Oracle: At the beginning of each player's end step, if that player didn't cast a spell this turn, this enchantment deals 2 damage to that player.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Impatience", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's end step, if that player didn't cast a spell this turn, this enchantment deals 2 damage to that player.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
