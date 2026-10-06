extends CardScript
## Allay — {1}{W} — Instant (common, exo).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Destroy target enchantment.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Allay", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nDestroy target enchantment.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
