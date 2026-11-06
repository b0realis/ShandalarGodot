extends CardScript
## Forbidding Watchtower —  — Land (uncommon, ulg).
## Oracle: This land enters tapped.
##         {T}: Add {W}.
##         {1}{W}: This land becomes a 1/5 white Soldier creature until end of turn. It's still a land.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Forbidding Watchtower", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {W}.\n{1}{W}: This land becomes a 1/5 white Soldier creature until end of turn. It's still a land.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
