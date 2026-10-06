extends CardScript
## Mox Diamond — {0} — Artifact (rare, sth).
## Oracle: If this artifact would enter, you may discard a land card instead. If you do, put this artifact onto the battlefield. If you don't, put it into its owner's graveyard.
##         {T}: Add one mana of any color.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mox Diamond", "{0}", Mtg.CardType.ARTIFACT)
	c.oracle("If this artifact would enter, you may discard a land card instead. If you do, put this artifact onto the battlefield. If you don't, put it into its owner's graveyard.\n{T}: Add one mana of any color.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
