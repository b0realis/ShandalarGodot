extends CardScript
## Thawing Glaciers —  — Land (rare, all).
## Oracle: This land enters tapped.
##         {1}, {T}: Search your library for a basic land card, put that card onto the battlefield tapped, then shuffle. Return this land to its owner's hand at the beginning of the next cleanup step.
## Trusted optional Pack 5 implementation; ZIPs never provide scripts.
## The delayed cleanup-step effect is a trigger on the stack with a
## response window (CR 514.3a; Pack 8 lifted the old adaptation).

func build() -> CardData:
	var c := CardData.new("Thawing Glaciers", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{1}, {T}: Search your library for a basic land card, put that card onto the battlefield tapped, then shuffle. Return this land to its owner's hand at the beginning of the next cleanup step.")
	return load("res://cards/sets/all/_rules.gd").apply(c)
