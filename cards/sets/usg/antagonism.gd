extends CardScript
## Antagonism — {3}{R} — Enchantment (rare, usg).
## Oracle: At the beginning of each player's end step, this enchantment deals 2 damage to that player unless one of their opponents was dealt damage this turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Antagonism", "{3}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's end step, this enchantment deals 2 damage to that player unless one of their opponents was dealt damage this turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
