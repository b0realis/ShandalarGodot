extends CardScript
## Spawning Pool —  — Land (uncommon, ulg).
## Oracle: This land enters tapped.
##         {T}: Add {B}.
##         {1}{B}: This land becomes a 1/1 black Skeleton creature with "{B}: Regenerate this creature" until end of turn. It's still a land. (If it regenerates, the next time it would be destroyed this turn, instead tap it, remove it from combat, and heal all damage on it.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spawning Pool", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {B}.\n{1}{B}: This land becomes a 1/1 black Skeleton creature with \"{B}: Regenerate this creature\" until end of turn. It's still a land. (If it regenerates, the next time it would be destroyed this turn, instead tap it, remove it from combat, and heal all damage on it.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
