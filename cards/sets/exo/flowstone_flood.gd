extends CardScript
## Flowstone Flood — {3}{R} — Sorcery (uncommon, exo).
## Oracle: Buyback—Pay 3 life, Discard a card at random. (You may pay 3 life and discard a card at random in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Destroy target land.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flowstone Flood", "{3}{R}", Mtg.CardType.SORCERY)
	c.oracle("Buyback—Pay 3 life, Discard a card at random. (You may pay 3 life and discard a card at random in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)\nDestroy target land.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
