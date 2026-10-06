extends CardScript
## Change of Heart — {W} — Instant (common, sth).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Target creature can't attack this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Change of Heart", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nTarget creature can't attack this turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
