extends CardScript
## Rathi Dragon — {2}{R}{R} — Creature — Dragon (rare, tmp).
## Oracle: Flying (This creature can't be blocked except by creatures with flying or reach.)
##         When this creature enters, sacrifice it unless you sacrifice two Mountains.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rathi Dragon", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying (This creature can't be blocked except by creatures with flying or reach.)\nWhen this creature enters, sacrifice it unless you sacrifice two Mountains.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
