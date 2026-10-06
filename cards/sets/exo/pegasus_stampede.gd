extends CardScript
## Pegasus Stampede — {1}{W} — Sorcery (uncommon, exo).
## Oracle: Buyback—Sacrifice a land. (You may sacrifice a land in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Create a 1/1 white Pegasus creature token with flying.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pegasus Stampede", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("Buyback—Sacrifice a land. (You may sacrifice a land in addition to any other costs as you cast this spell. If you do, put this card into your hand as it resolves.)\nCreate a 1/1 white Pegasus creature token with flying.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
