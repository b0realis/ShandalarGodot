extends CardScript
## Elvish Fury — {G} — Instant (common, tmp).
## Oracle: Buyback {4} (You may pay an additional {4} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Target creature gets +2/+2 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elvish Fury", "{G}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {4} (You may pay an additional {4} as you cast this spell. If you do, put this card into your hand as it resolves.)\nTarget creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
