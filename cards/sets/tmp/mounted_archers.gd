extends CardScript
## Mounted Archers — {3}{W} — Creature — Human Soldier Archer (common, tmp).
## Oracle: Reach (This creature can block creatures with flying.)
##         {W}: This creature can block an additional creature this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mounted Archers", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["human","soldier","archer"])
	c.with_keywords([Mtg.Keyword.REACH])
	c.oracle("Reach (This creature can block creatures with flying.)\n{W}: This creature can block an additional creature this turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
