extends CardScript
## Evincar's Justice — {2}{B}{B} — Sorcery (common, tmp).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Evincar's Justice deals 2 damage to each creature and each player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Evincar's Justice", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nEvincar's Justice deals 2 damage to each creature and each player.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
