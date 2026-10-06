extends CardScript
## Disturbed Burial — {1}{B} — Sorcery (common, tmp).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Return target creature card from your graveyard to your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Disturbed Burial", "{1}{B}", Mtg.CardType.SORCERY)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nReturn target creature card from your graveyard to your hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
