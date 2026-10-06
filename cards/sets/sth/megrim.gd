extends CardScript
## Megrim — {2}{B} — Enchantment (uncommon, sth).
## Oracle: Whenever an opponent discards a card, this enchantment deals 2 damage to that player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Megrim", "{2}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent discards a card, this enchantment deals 2 damage to that player.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
