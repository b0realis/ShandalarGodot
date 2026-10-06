extends CardScript
## Seething Anger — {R} — Sorcery (common, sth).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Target creature gets +3/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Seething Anger", "{R}", Mtg.CardType.SORCERY)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nTarget creature gets +3/+0 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
