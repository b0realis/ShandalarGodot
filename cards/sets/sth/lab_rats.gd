extends CardScript
## Lab Rats — {B} — Sorcery (common, sth).
## Oracle: Buyback {4} (You may pay an additional {4} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Create a 1/1 black Rat creature token.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lab Rats", "{B}", Mtg.CardType.SORCERY)
	c.oracle("Buyback {4} (You may pay an additional {4} as you cast this spell. If you do, put this card into your hand as it resolves.)\nCreate a 1/1 black Rat creature token.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
