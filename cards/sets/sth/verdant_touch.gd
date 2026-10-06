extends CardScript
## Verdant Touch — {1}{G} — Sorcery (rare, sth).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Target land becomes a 2/2 creature that's still a land. (This effect lasts indefinitely.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Verdant Touch", "{1}{G}", Mtg.CardType.SORCERY)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nTarget land becomes a 2/2 creature that's still a land. (This effect lasts indefinitely.)")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
