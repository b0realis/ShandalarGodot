extends CardScript
## Delirium — {1}{B}{R} — Instant (uncommon, mir).
## Oracle: Cast this spell only during an opponent's turn.
##         Tap target creature that player controls. That creature deals damage equal to its power to the player. Prevent all combat damage that would be dealt to and dealt by the creature this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Delirium", "{1}{B}{R}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during an opponent's turn.\nTap target creature that player controls. That creature deals damage equal to its power to the player. Prevent all combat damage that would be dealt to and dealt by the creature this turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
