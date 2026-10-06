extends CardScript
## Imps' Taunt — {1}{B} — Instant (uncommon, tmp).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Target creature attacks this turn if able.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Imps' Taunt", "{1}{B}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nTarget creature attacks this turn if able.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
