extends CardScript
## Fanning the Flames — {X}{R}{R} — Sorcery (uncommon, sth).
## Oracle: Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Fanning the Flames deals X damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fanning the Flames", "{X}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Buyback {3} (You may pay an additional {3} as you cast this spell. If you do, put this card into your hand as it resolves.)\nFanning the Flames deals X damage to any target.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
