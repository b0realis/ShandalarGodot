extends CardScript
## Slaughter — {2}{B}{B} — Instant (uncommon, exo).
## Oracle: Buyback—Pay 4 life. (You may pay 4 life in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Destroy target nonblack creature. It can't be regenerated.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Slaughter", "{2}{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("Buyback—Pay 4 life. (You may pay 4 life in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)\nDestroy target nonblack creature. It can't be regenerated.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
