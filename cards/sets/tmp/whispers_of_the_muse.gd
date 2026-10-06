extends CardScript
## Whispers of the Muse — {U} — Instant (uncommon, tmp).
## Oracle: Buyback {5} (You may pay an additional {5} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Whispers of the Muse", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {5} (You may pay an additional {5} as you cast this spell. If you do, put this card into your hand as it resolves.)\nDraw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
