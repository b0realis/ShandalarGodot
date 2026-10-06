extends CardScript
## Brush with Death — {2}{B} — Sorcery (common, sth).
## Oracle: Buyback {2}{B}{B} (You may pay an additional {2}{B}{B} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Target opponent loses 2 life. You gain 2 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Brush with Death", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Buyback {2}{B}{B} (You may pay an additional {2}{B}{B} as you cast this spell. If you do, put this card into your hand as it resolves.)\nTarget opponent loses 2 life. You gain 2 life.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
