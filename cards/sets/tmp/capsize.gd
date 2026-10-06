extends CardScript
## Capsize — {1}{U}{U} — Instant (common, tmp).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Return target permanent to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Capsize", "{1}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nReturn target permanent to its owner's hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
