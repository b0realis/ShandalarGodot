extends CardScript
## Mind Games — {U} — Instant (common, sth).
## Oracle: Buyback {2}{U} (You may pay an additional {2}{U} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Tap target artifact, creature, or land.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mind Games", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {2}{U} (You may pay an additional {2}{U} as you cast this spell. If you do, put this card into your hand as it resolves.)\nTap target artifact, creature, or land.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
