extends CardScript
## Bottomless Pit — {1}{B}{B} — Enchantment (uncommon, sth).
## Oracle: At the beginning of each player's upkeep, that player discards a card at random.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bottomless Pit", "{1}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each player's upkeep, that player discards a card at random.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
