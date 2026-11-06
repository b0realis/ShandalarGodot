extends CardScript
## Ghitu Encampment —  — Land (uncommon, ulg).
## Oracle: This land enters tapped.
##         {T}: Add {R}.
##         {1}{R}: This land becomes a 2/1 red Warrior creature with first strike until end of turn. It's still a land. (It deals combat damage before creatures without first strike.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ghitu Encampment", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {R}.\n{1}{R}: This land becomes a 2/1 red Warrior creature with first strike until end of turn. It's still a land. (It deals combat damage before creatures without first strike.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
