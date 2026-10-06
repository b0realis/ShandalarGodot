extends CardScript
## Anoint — {W} — Instant (common, tmp).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Prevent the next 3 damage that would be dealt to target creature this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Anoint", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nPrevent the next 3 damage that would be dealt to target creature this turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
