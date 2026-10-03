extends CardScript
## Scorched Ruins —  — Land (rare, wth).
## Oracle: If this land would enter, sacrifice two untapped lands instead. If you do, put this land onto the battlefield. If you don't, put it into its owner's graveyard.
##         {T}: Add {C}{C}{C}{C}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scorched Ruins", "", Mtg.CardType.LAND)
	c.oracle("If this land would enter, sacrifice two untapped lands instead. If you do, put this land onto the battlefield. If you don't, put it into its owner's graveyard.\n{T}: Add {C}{C}{C}{C}.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
