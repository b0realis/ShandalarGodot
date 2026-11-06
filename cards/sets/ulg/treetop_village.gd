extends CardScript
## Treetop Village —  — Land (uncommon, ulg).
## Oracle: This land enters tapped.
##         {T}: Add {G}.
##         {1}{G}: This land becomes a 3/3 green Ape creature with trample until end of turn. It's still a land. (It can deal excess combat damage to the player or planeswalker it's attacking.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Treetop Village", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {G}.\n{1}{G}: This land becomes a 3/3 green Ape creature with trample until end of turn. It's still a land. (It can deal excess combat damage to the player or planeswalker it's attacking.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
