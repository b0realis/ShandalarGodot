extends CardScript
## Pegasus Charger — {2}{W} — Creature — Pegasus (common, usg).
## Oracle: Flying (This creature can't be blocked except by creatures with flying or reach.)
##         First strike (This creature deals combat damage before creatures without first strike.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pegasus Charger", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["pegasus"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE])
	c.oracle("Flying (This creature can't be blocked except by creatures with flying or reach.)\nFirst strike (This creature deals combat damage before creatures without first strike.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
