extends CardScript
## Shattering Pulse — {1}{R} — Instant (common, exo).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Destroy target artifact.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shattering Pulse", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nDestroy target artifact.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
