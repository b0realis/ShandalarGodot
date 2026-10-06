extends CardScript
## Sudden Impact — {3}{R} — Instant (uncommon, tmp).
## Oracle: Sudden Impact deals damage to target player equal to the number of cards in that player's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sudden Impact", "{3}{R}", Mtg.CardType.INSTANT)
	c.oracle("Sudden Impact deals damage to target player equal to the number of cards in that player's hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
