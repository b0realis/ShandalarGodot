extends CardScript
## Festering Evil — {3}{B}{B} — Enchantment (uncommon, wth).
## Oracle: At the beginning of your upkeep, this enchantment deals 1 damage to each creature and each player.
##         {B}{B}, Sacrifice this enchantment: It deals 3 damage to each creature and each player.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Festering Evil", "{3}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, this enchantment deals 1 damage to each creature and each player.\n{B}{B}, Sacrifice this enchantment: It deals 3 damage to each creature and each player.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
