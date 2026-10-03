extends CardScript
## Longbow Archer — {W}{W} — Creature — Human Soldier Archer (uncommon, vis).
## Oracle: Reach (This creature can block creatures with flying.)
##         First strike
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Longbow Archer", "{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","soldier","archer"])
	c.with_keywords([Mtg.Keyword.REACH, Mtg.Keyword.FIRST_STRIKE])
	c.oracle("Reach (This creature can block creatures with flying.)\nFirst strike")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
