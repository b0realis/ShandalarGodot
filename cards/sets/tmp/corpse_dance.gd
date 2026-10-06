extends CardScript
## Corpse Dance — {2}{B} — Instant (rare, tmp).
## Oracle: Buyback {2} (You may pay an additional {2} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Return the top creature card of your graveyard to the battlefield. That creature gains haste until end of turn. Exile it at the beginning of the next end step.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Corpse Dance", "{2}{B}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {2} (You may pay an additional {2} as you cast this spell. If you do, put this card into your hand as it resolves.)\nReturn the top creature card of your graveyard to the battlefield. That creature gains haste until end of turn. Exile it at the beginning of the next end step.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
