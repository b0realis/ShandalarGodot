extends CardScript
## Searing Touch — {R} — Instant (uncommon, tmp).
## Oracle: Buyback {4} (You may pay an additional {4} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Searing Touch deals 1 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Searing Touch", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {4} (You may pay an additional {4} as you cast this spell. If you do, put this card into your hand as it resolves.)\nSearing Touch deals 1 damage to any target.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
